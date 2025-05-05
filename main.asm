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

DIGTAB:
	.db 0b0001, 0b0010, 0b0100, 0b1000

MUX:
	push r16
	in	 r16, SREG
	push r16

	; r18 = TIME[POS]
	lds r17, POS

	ldi   r31, high(TIME)
    ldi   r30, low(TIME)

	add r30, r17
	adc r31, r1

	ld	r18, Z

	; get segment from SEGTAB
	ldi	r31, HIGH(SEGTAB)
	ldi	r30, LOW(SEGTAB)
	add r30, r18
	lpm r16, Z
	out PORTA, r16

	; activate digit[POS]
	ldi     r31, high(DIGTAB)
    ldi     r30, low(DIGTAB)
    add     r30, r17        ; Z = &DIGTAB + POS
    lpm     r16, Z
    out     PORTB, r16

	; go to next pos
	inc     r17
    cpi     r17, 4
    brlo    no_wrap
    clr     r17
no_wrap:
    sts     POS, r17

	pop	 r16
	out	 SREG, r16
	pop  r16
	reti

BCD:
	push r16
	in	 r16, SREG
	push r16

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
	pop	 r16
	out	 SREG, r16
	pop  r16
	reti

MAIN:
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