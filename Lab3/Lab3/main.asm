;
; Lab3.asm
;
; Created: 2025-05-05 15:16:39
; Author : andan346
;

; --- DATA SEGMENT
.dseg
.org SRAM_START
TIME: .byte 4
POS:  .byte 1

; --- CODE SEGMENT
.cseg
.org $0000
	jmp MAIN
.org $0002 ; INT0
	jmp MUX
.org $0004 ; INT1
	jmp BCD
.org INT_VECTORS_SIZE

; --- TABLES
SEGTAB: 
	.db $3F,$06,$5B,$4F,$66,$6D,$7D,$07,$7F,$6F

; --- CLEAR TIME
CLEAR_TIME:
	clr r18
	ldi r17, 4 ; TIME = 4 bytes
	ldi XL, LOW(TIME)
	ldi XH, HIGH(TIME)
CLEAR_LOOP:
	st X+, r18
	dec r17
	brne CLEAR_LOOP
	ret

; --- MUX
MAIN:
	; Initiera hårdvara
	ldi r18, $FF
	out DDRA, r18 ; Väljer segment
	out DDRB, r18 ; Väljer display

	; Initiera stackpekare
	ldi r18, HIGH(RAMEND)
	out SPH, r18
	ldi r18, LOW(RAMEND)
	out SPL, r18

	; Nollställ TIME
	rcall CLEAR_TIME

	; Initiera avbrott på INT0, INT1
	ldi r18,(1<<ISC01)|(1<<ISC00)|(1<<ISC11)|(1<<ISC10) ; Stigande flank
	out MCUCR,r18

	ldi r18,(1<<INT1)|(1<<INT0)
	out GICR,r18
	
	sei ; enable interrupts

MAIN_LOOP:
	jmp MAIN_LOOP

; --- MUX
MUX:
	; Spara kontext
	push r18
	in r18, SREG
	push r18
	push XL
	push XH

	clr r18
	out PORTA, r18

	; Ladda r18 med POS
	ldi XL, LOW(POS)
	ldi XH, HIGH(POS)
	ld r18, X

	; Sätt PORTB = POS
	out PORTB, r18

	; Ladda r18 med TIME + POS
	ldi XL, LOW(TIME)
	ldi XH, HIGH(TIME)
	add XL, r18
	ld r18, X

	; Ladda r18 med segmentet i TIME + POS
	ldi ZL, LOW(SEGTAB*2)
	ldi ZH, HIGH(SEGTAB*2)
	add ZL, r18
	lpm r18, Z

	; Sätt PORTA = SEGTAB[TIME+POS]
	out PORTA, r18
	
	; Inkrementera POS
	ldi XL, LOW(POS)
	ldi XH, HIGH(POS)
	ld r18, X 
	inc r18
	andi r18, 0b11
	st X, r18

	; Återställ kontext
	pop XH
	pop XL
	pop r18
	out SREG, r18
	pop r18
	reti

; --- BCD
BCD:
	; Spara kontext
	push r17
	push r18
	in r18, SREG
	push r18
	push XL
	push XH

	; Ladda X med TIME
	ldi XL, LOW(TIME)
	ldi XH, HIGH(TIME)

	; Loopa r17 = 2 gånger
	ldi r17, 2
BCD_LOOP:
	; Inkrementera ental
	ld r18, X
	inc r18
	st X, r18
	cpi r18, 10 ; har nått 10?
	brne BCD_EXIT
	; Nollställ och gå till nästa position
	clr r18
	st X+, r18
	; Inkrementera tiotal
	ld r18, X
	inc r18
	st X, r18
	cpi r18, 6 ; har nått 6?
	brne BCD_EXIT
	; Nollställ och gå till nästa position
	clr r18
	st X+, r18

	dec r17
	brne BCD_LOOP
BCD_EXIT:
	; Återställ kontext
	pop XH
	pop XL
	pop r18
	out SREG, r18
	pop r18
	pop r17
	reti