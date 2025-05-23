;
; Lab4.asm
;
; Created: 2025-05-14 13:23:48
; Author : andan346
;


	.equ	VMEM_SZ     = 5		; #rows on display
	.equ	AD_CHAN_X   = 0		; ADC0=PA0, PORTA bit 0 X-led
	.equ	AD_CHAN_Y   = 1		; ADC1=PA1, PORTA bit 1 Y-led
	.equ	GAME_SPEED  = 70	; inter-run delay (millisecs)
	.equ	PRESCALE    = 3		; AD-prescaler value
	.equ	BEEP_PITCH  = 30	; Victory beep pitch
	.equ	BEEP_LENGTH = 250	; Victory beep length
	
	; ---------------------------------------
	; --- Memory layout in SRAM
	.dseg
	.org	SRAM_START
POSX:	.byte	1	; Own position
POSY:	.byte 	1
TPOSX:	.byte	1	; Target position
TPOSY:	.byte	1
LINE:	.byte	1	; Current line	
VMEM:	.byte	VMEM_SZ ; Video MEMory
SEED:	.byte	1	; Seed for Random

	; ---------------------------------------
	; --- Macros for inc/dec-rementing
	; --- a byte in SRAM
	.macro INCSRAM	; inc byte in SRAM
		lds	r16,@0
		inc	r16
		sts	@0,r16
	.endmacro

	.macro DECSRAM	; dec byte in SRAM
		lds	r16,@0
		dec	r16
		sts	@0,r16
	.endmacro

	; ---------------------------------------
	; --- Code
	.cseg
	.org 	$0
	jmp	START
	.org	$2
	jmp	MUX


START:
	; S�tt stackpekaren
	ldi r16, HIGH(RAMEND)
	out SPH, r16
	ldi r16, LOW(RAMEND)
	out SPL, r16

	; Initialisera h�rdvara
	call	HW_INIT	
	; Initialisera spelet
	call	WARM

; --- Game loop ---
RUN:
	call	JOYSTICK
	call	ERASE_VMEM
	call	UPDATE

; --- Delay ---
	ldi r16,GAME_SPEED
	call	DELAY_MS

; --- Tr�ff? ---
	lds  r16, POSX
	lds  r17, TPOSX
	cp   r16, r17
	brne NO_HIT

	lds  r16, POSY
	lds  r17, TPOSY
	cp   r16, r17
	brne NO_HIT	

; --- Tr�ff ---
	ldi	r16,BEEP_LENGTH
	call	BEEP
	call	WARM

; --- Ej tr�ff ---
NO_HIT:
	jmp	RUN

	; ---------------------------------------
	; --- Multiplex display
MUX:	
	; --- Spara kontext
	push r16		; Spara undan r16.
	in   r16, SREG	; L�s in statusregistret
	push r16		; och spara undan det som r16;
	push r17		; Spara undan r17.
	push r18		; Spara undan r18.
	push r19		; Spara undan r19.
	push ZL			; Spara undan ZL.
	push ZH			; Spara undan ZH.

	; --- Initiera pekare
	ldi ZL, LOW(VMEM)
	ldi ZH, HIGH(VMEM)

	; --- L�s LINE
	lds r16, LINE

	; --- Sl�ck DISP[LINE]
	; V�lj rad
	mov  r17, r16			; r17 = LINE
	lsl	 r17				; * flytta bitarna till de pinnar de kommer sitta p�
	lsl  r17				; *
	lsl	 r17				; * bit0 -> PD3
	in	 r18, PORTD			; kopiera PORTD
	andi r18, 0b11000111	; maskera PD3-PD5
	or   r18, r17			; r18 = PD3-PD5
	out  PORTD, r18			; PD3-PD5 best�mmer rad p� matrismodulen
	; Sl�ck kolumner
	in   r18, PORTB			; kopiera PORTB
	andi r18, 0b10000000	; beh�ll PB7, sl�ck resten
	out  PORTB, r18			; PB0-PB6 inneh�ller en kolumn p� matrismodulen

	; --- LINE++ (0-4 loop)
	inc  r16
	cpi  r16, VMEM_SZ
	brlo storeLine
	clr  r16

	; --- Spara LINE
storeLine:
	sts LINE, r16

	; Allt funkar ovan ^^^^

	; --- L�s VMEM[LINE]
	clr r17
	add ZL, r16
	adc ZH, r17
	ld  r17, Z

	; -- T�nd DISP[LINE]
	; V�lj rad
	mov  r18, r16			; r18 = LINE
	lsl  r18				; * flytta bitarna till de pinnar de kommer sitta p�
	lsl  r18				; *
	lsl  r18				; * bit0 -> PD3
	in   r19, PORTD			; kopiera PORTD
	andi r19, 0b11000111	; maskera PD3-PD5
	or   r19, r18			; r19 = PD3-PD5
	out  PORTD, r19			; PD3-PD5 best�mmer rad p� matrismodulen
	; T�nd rad enligt r17 = VMEM[LINE]
	in   r18, PORTB			; kopiera PORTB
	andi r18, 0b10000000	; beh�ll PB7
	or   r17, r18			; s�tt resten till r17 = VMEM[LINE]
	out  PORTB, r17			; PB0-PB6 inneh�ller en kolumn p� matrismodulen

	;ldi r17, $FF
	;out PORTB, r17

	; --- SEED++
	INCSRAM SEED

	; --- �terst�ll kontext
MUX_EXIT:
	pop ZH			; �terst�ll ZH.
	pop ZL			; �terst�ll ZL.
	pop r19			; �terst�ll r19.
	pop r18			; �terst�ll r18.
	pop r17			; �terst�ll r17.
	pop r16			; Ta fram statusregistret
	out SREG, r16	; fr�n r16 och �terst�ll det.
	pop r16			; �terst�ll r16.

	reti
		
	; ---------------------------------------
	; --- JOYSTICK Sense stick and update POSX, POSY
	; --- Uses r16
JOYSTICK:	

;*** 	skriv kod som �kar eller minskar POSX beroende 	***
;*** 	p� insignalen fr�n A/D-omvandlaren i X-led...	***
	push r16		; r16 p� stacken
	in r16, SREG
	push r16		; SREG p� stacken
	push r17

JOY_X:
	ldi r16, (1<<REFS0) | AD_CHAN_X
	call ADC10
JOY_DEC_X:
	cpi r17, 0b00
	brne JOY_INC_X
	DECSRAM POSX
JOY_INC_X:
	cpi r17, 0b11
	brne JOY_Y
	INCSRAM POSX
JOY_Y:
	ldi r16, (1<<REFS0) | AD_CHAN_Y
	call ADC10
JOY_DEC_Y:
	cpi r17, 0b00
	brne JOY_INC_Y
	DECSRAM POSY
JOY_INC_Y:
	cpi r17, 0b11
	brne JOY_LIM
	INCSRAM POSY
JOY_LIM:
	call	LIMITS		; don't fall off world!
	pop r17
	pop r16
	out SREG, r16
	pop r16
	ret

	; ---------------------------------------
	; --- LIMITS Limit POSX,POSY coordinates	
	; --- Uses r16,r17
LIMITS:
	lds	r16,POSX	; variable
	ldi	r17,7		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSX,r16
	lds	r16,POSY	; variable
	ldi	r17,5		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSY,r16
	ret

POS_LIM:
	ori	r16,0		; negative?
	brmi	POS_LESS	; POSX neg => add 1
	cp	r16,r17		; past edge
	brne	POS_OK
	subi	r16,2
POS_LESS:
	inc	r16	
POS_OK:
	ret

ADC10:
	out ADMUX, r16
	ldi r16, (1<<ADEN)
	ori r16, (1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
	out ADCSRA, r16
ADC10_CONVERT:
	in r16, ADCSRA
	ori r16, (1<<ADSC)
	out ADCSRA, r16
ADC10_WAIT:
	in r16, ADCSRA
	sbrc r16, ADSC
	rjmp ADC10_WAIT
	in r16, ADCL
	in r17, ADCH
	ret

	; ---------------------------------------
	; --- UPDATE VMEM
	; --- with POSX/Y, TPOSX/Y
	; --- Uses r16, r17
UPDATE:	
	clr	ZH 
	ldi	ZL,LOW(POSX)
	call 	SETPOS
	clr	ZH
	ldi	ZL,LOW(TPOSX)
	call	SETPOS
	ret

	; --- SETPOS Set bit pattern of r16 into *Z
	; --- Uses r16, r17
	; --- 1st call Z points to POSX at entry and POSY at exit
	; --- 2nd call Z points to TPOSX at entry and TPOSY at exit
SETPOS:
	ld	r17,Z+  	; r17=POSX
	call	SETBIT		; r16=bitpattern for VMEM+POSY
	ld	r17,Z		; r17=POSY Z to POSY
	ldi	ZL,LOW(VMEM)
	add	ZL,r17		; *(VMEM+T/POSY) ZL=VMEM+0..4
	ld	r17,Z		; current line in VMEM
	or	r17,r16		; OR on place
	st	Z,r17		; put back into VMEM
	ret
	
	; --- SETBIT Set bit r17 on r16
	; --- Uses r16, r17
SETBIT:
	ldi	r16,$01		; bit to shift
SETBIT_LOOP:
	dec 	r17			
	brmi 	SETBIT_END	; til done
	lsl 	r16		; shift
	jmp 	SETBIT_LOOP
SETBIT_END:
	ret

	; ---------------------------------------
	; --- Hardware init
	; --- Uses r16
HW_INIT:

	; Initiera INT0
	ldi	r16, (1<<INT0)
	out	GICR, r16
	; Stigande flank: ISC01=1, ISC00=1
    ldi r16, (1<<ISC01) | (1<<ISC00)
    out MCUCR, r16

	; S�tt PB0-PB7 output (PB0-PB6 display, PB7 h�gtalare)
	ldi r16, $FF
	out DDRB, r16

	; S�tt PD3-PD5 output, resten input
	;		 PD76543210
	ldi r16, 0b00111000
	out DDRD, r16
	
	sei			; display on
	ret

	; ---------------------------------------
	; --- WARM start. Set up a new game
WARM:

	; S�tt startposition (POSX,POSY)=(0,2)
	ldi r16, 0
	sts POSX, r16
	ldi r16, 2
	sts POSY, r16

	; H�mta "random" nummer
	push	r0		
	push	r0		
	call	RANDOM		; RANDOM returns x,y on stack, x �verst, y underst

	; S�tt startposition (TPOSX,POSY)
	pop r16
	sts TPOSX, r16

	pop r16
	sts TPOSY, r16

	call	ERASE_VMEM
	ret

	; ---------------------------------------
	; --- RANDOM generate TPOSX, TPOSY
	; --- in variables passed on stack.
	; --- Usage as:
	; ---	push r0 
	; ---	push r0 
	; ---	call RANDOM
	; ---	pop TPOSX 
	; ---	pop TPOSY
	; --- Uses r16
RANDOM:
	clr r0
	; Kopiera stackpekare till Z-pekare
	in	r16, SPH
	mov	ZH, r16
	in	r16, SPL
	mov	ZL, r16

	; Kopiera SEED till r16 och r17
	lds	r16, SEED
	mov r17, r16
	; S�tt r16 och r17 till olika delar av SEED
	andi r16, 0b00000111
	andi r17, 0b00001110
	lsr r17
	; Normalisera v�rdena p� X och Y (0..7 => 0..4)
NORMAL_X:
	cpi r16, 5
	brlt NORMAL_Y
	subi r16, 4
NORMAL_Y:
	cpi r17, 5
	brlt NORMAL_DONE
	subi r17, 4
NORMAL_DONE:
	; Justera X (0..4 => 2..6)
	subi r16, -2

	; L�gg X och Y r�tt p� stacken
	std Z+3, r16 ; X
	std Z+4, r17 ; Y
	ret


	; ---------------------------------------
	; --- Erase Videomemory bytes
	; --- Clears VMEM..VMEM+4
	
ERASE_VMEM:

	ldi ZL, LOW(VMEM)
	ldi ZH, HIGH(VMEM)

	ldi r16, VMEM_SZ
	clr r1

eraseLoop:
	st Z+, r1
	dec r16
	brne eraseLoop

	ret

	; ---------------------------------------
	; --- BEEP(r16) r16 half cycles of BEEP-PITCH
BEEP:
    ; Toggla h�gtalarpinne
    in  r18, PORTB
    ldi r19, (1<<PB7)
    eor r18, r19
    out PORTB, r18

    ; V�nta BEEP_PITCH cykler
    ldi r18, BEEP_PITCH
BEEP_DELAY:
    nop
    dec r18
    brne BEEP_DELAY

    ; En halvcykel klar
    dec r16
    brne BEEP

    ret

	; ---------------------------------------
	; --- DELAY_MS(r16) v�ntar r16 ms.
	; --- OBS!) Antar att klockfrekvensen �r 1 MHz
	; --- Anv�nder r16, r17
DELAY_MS:

	ldi r17, $FF		; 1 * 1 = 1
delayWait1:
	dec r17				; 1 * 255 = 255
	brne delayWait1		; 2 * 254 + 1 * 1 = 509

	ldi r17, $4C		; 1 * 1 = 1
delayWait2:
	dec r17				; 1 * 76 = 76
	brne delayWait2 	; 2 * 75 + 1 * 1 = 151

; H�rvid 993 cykler
	dec r16				; +1
	brne delayNotLast	; +2 (tagen) eller +1 (ej tagen)

; H�rvid 995 cykler
	nop					; +1
	ret					; +4 => 1000 cykler, KLAR!

; H�rvid 996 cykler
delayNotLast:
	nop					; +1
	nop					; +1
	rjmp DELAY_MS		; +2 => 1000 cykler