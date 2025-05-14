;
; Lab3.asm
;
; Created: 2025-05-05 15:16:39
; Author : andan346
;


	.dseg
	.org SRAM_START
TIME:
	.byte 4		; TIME+0 = sek-enheter, TIME+1 = sek-tiotal
				; TIME+2 = min-enheter,  TIME+3 = min-tiotal
POS:
	.byte 1

	.cseg
		.org $0000
	jmp	MAIN
		.org $0002
	jmp	MUX
		.org $0004
	jmp	BCD
		.org INT_VECTORS_SIZE

SEGTAB:
	.db 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F

MUX:
	push r16
	push r17
	push r18

	lds r17, POS

	ldi ZH, HIGH(TIME)
    ldi ZL, LOW(TIME)
	add	ZL, r17
	adc ZH, r1
	ld	r18, Z
	out PORTB, r17

	; get segment from SEGTAB
	ldi	XH, HIGH(SEGTAB)
	ldi	XL, LOW(SEGTAB)
	add XL, r18
	adc XH, r1
	ld r16, X
	out PORTA, r16

	inc     r17
    cpi     r17, 4
	breq	reset_pos
	rjmp	MUX_END
reset_pos:
    clr     r17

MUX_END:
    sts     POS, r17

	pop	r18
	pop r17
	pop	 r16
	reti

BCD:
	push r16
	push r17
	push r18

	; Seconds (0-9)
	lds	r16, TIME+0
	inc r16
	cpi r16, 10
	brsh BCD_S0_CLEAR
	sts	TIME+0, r16
	rjmp BCD_RESTORE

BCD_S0_CLEAR:
	clr	r16
	sts TIME+0, r16

	; Seconds tens (0-5)
	lds	r16, TIME+1
	inc r16
	cpi r16, 6
	brsh BCD_S1_CLEAR
	sts	TIME+1, r16
	rjmp BCD_RESTORE

BCD_S1_CLEAR:
	clr	r16
	sts TIME+1, r16

	; Minutes (0-9)
	lds	r16, TIME+2
	inc r16
	cpi r16, 10
	brsh BCD_S2_CLEAR
	sts	TIME+2, r16
	rjmp BCD_RESTORE

BCD_S2_CLEAR:
	clr	r16
	sts TIME+2, r16

	; Minutes tens (0-5)
	lds	r16, TIME+3
	inc r16
	cpi r16, 6
	brsh BCD_S3_CLEAR
	sts	TIME+3, r16
	rjmp BCD_RESTORE

BCD_S3_CLEAR:
	clr	r16
	sts TIME+3, r16

BCD_RESTORE:
	pop r18
	pop r17
	pop	 r16
	reti

MAIN:
	clr r1
	clr   r16
	sts   POS,   r16

	; Init SP
	ldi	r16, HIGH(RAMEND)
	out	SPH, r16
	ldi r16, LOW(RAMEND)
	out	SPL, r16

	; Init interrupts
	ldi	r16, (1<<ISC01)|(1<<ISC00)|(1<<ISC11)|(1<<ISC10)	; Stigande flank
    out	MCUCR, r16

    ldi	r16, (1<<INT0)|(1<<INT1)
    out	GICR, r16

	; Enable interrupts globally
	sei

MAIN_WAIT:
	jmp MAIN_WAIT