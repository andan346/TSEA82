;
; Lab3.asm
;
; Created: 2025-05-05 15:16:39
; Author : andan346
;

; ----- DATA SEGMENT ----- ;
	.dseg
	.org SRAM_START
TIME:	.byte 4		; TIME+0 = sek, TIME+1 = 10sek, TIME+2 = min, TIME+3 = 10min
POS:	.byte 1

; ----- CODE SEGMENT ----- ;
	.cseg
		.org $0000
	jmp	MAIN
		.org $0002	; INT0 (PD2 -> MUX @ 1kHz)
	jmp	MUX
		.org $0004	; INT1 (PD3 -> BCD @ 1Hz)
	jmp	BCD
		.org INT_VECTORS_SIZE

; ----- SEGMENT TABLE ----- ;
SEGTAB:
	.db 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F ; (tack chatgpt)

; ----- MAIN ----- ;
MAIN:
	; Init SP
	ldi	r16, HIGH(RAMEND)
	out	SPH, r16
	ldi r16, LOW(RAMEND)
	out	SPL, r16

	; Init interrupts
	ldi	r16, (1<<ISC01)|(1<<ISC00)|(1<<ISC11)|(1<<ISC10) ; Stigande flank
    out	MCUCR, r16

    ldi	r16, (1<<INT0)|(1<<INT1)
    out	GICR, r16

	; Enable interrupts globally
	sei

MAIN_LOOP:
	jmp MAIN_LOOP

; ----- MUX ----- ;
MUX:
	; Spara kontext
	push r0
	push r16
	push r17
	push r18

	; 0-register
	clr r0

	; H�mta POS (0..3)
	lds  r16, POS
	andi r16, 3

	; S�tt PORTB till POS
	out PORTB, r16

	; Pekare till TIME + POS
	ldi ZH, HIGH(TIME)
    ldi ZL, LOW(TIME)
	add	ZL, r16
	adc ZH, r0

	ld	r17, Z ; BCD-siffra

	; Pekare till SEGTAB + BCD
	ldi	XH, HIGH(SEGTAB)
	ldi	XL, LOW(SEGTAB)
	add XL, r17
	adc XH, r0

	ld r18, X ; Segmentkod

	; S�tt PORTA tll segmentkod
	out PORTA, r18

	; N�sta position
	inc r16
	sts POS, r16

	; �terst�ll kontext
	pop	r18
	pop r17
	pop	r16
	pop r0

	reti

; ----- BCD ----- ;
BCD:
	; Spara kontext
	push r16
	push r17

	; Pekare till TIME
	ldi ZH, HIGH(TIME)
	ldi ZL, LOW(TIME)

	; Nollst�ll r�knaren
	clr r17

BCD_LOOP:
	; L�s TIME och inkrementera siffer-v�rdet
	ld r16, Z
	inc r16
	cpi r16, 10
	brlt BCD_STORE
	; Nollst�ll siffer-v�rdet
	clr r16
	st Z, r16
	; G� till n�sta siffra p� displayen
	inc r17
	cpi r17, 4
	brlt BCD_NEXT
	rjmp BCD_DONE

BCD_NEXT:
	; Flytta Z-pekaren framm�t (Z+1 = TIME+1)
	adiw ZL, 1
	rjmp BCD_LOOP

BCD_STORE:
	; Sparar det nya sifferv�rdet i (Z = TIME)
	st Z, r16

BCD_DONE:
	pop r17
	pop	r16

	reti