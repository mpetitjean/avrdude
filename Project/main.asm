;
; task10
;
; Created: 08/03/2017 17:00:00
; Author : Mathieu Petitjean

.include "m328pdef.inc"





;------------
; CONSTANTS
;------------

;KEYBOARD - MATRIX LIKE NUMEROTATION
.equ KEYB_PIN	= PIND
.equ KEYB_DDR	= DDRD
.equ KEYB_PORT	= PORTD
.equ ROW1		= 7
.equ ROW2		= 6
.equ ROW3		= 5
.equ ROW4		= 4
.equ COL1		= 3
.equ COL2		= 2
.equ COL3		= 1
.equ COL4		= 0

;LEDs
.equ LEDUP_P	= 2
.equ LEDDOWN_P	= 3
.equ LED_DDR	= DDRC
.equ LED_PORT	= PORTC
.equ LED_PIN	= PINC

;SCREEN
.equ SCREEN_DDR		= DDRB
.equ SCREEN_PORT	= PORTB
.equ SCREEN_PIN		= PINB
.equ SCREEN_SDI		= 3
.equ SCREEN_CLK		= 5
.equ SCREEN_LE		= 4

;TCNT 1 RESET VALUE
.EQU TCNT2_RESET_480 = 223
.EQU TCNT0_RESET_1M = 255

;Define some Rd name

.DEF temp=r16
.DEF rowselect=r21
.DEF rowoffset=r22


;Memory
.DSEG
Cell: .BYTE 16; LED cell
.CSEG
;--------
; MACROS
;--------
.MACRO shiftReg
	SBI SCREEN_PORT, SCREEN_SDI
	SBRS @0, @1
	CBI SCREEN_PORT, SCREEN_SDI
	SBI SCREEN_PIN,SCREEN_CLK
	SBI SCREEN_PIN,SCREEN_CLK
.ENDMACRO

.MACRO charToSram
LDI temp, low(@0<<1)
ST Y, temp
LDI temp, high(@0<<1)
STD Y+1, temp
.ENDMACRO

.MACRO keyboardStep2
	; switch in/out for rows and columns
	LDI temp,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
	OUT KEYB_PORT,temp
	LDI temp,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
	OUT KEYB_DDR,temp
	NOP
	NOP
	NOP
	; check which row is LOW
	SBIS KEYB_PIN,ROW1
	RJMP @0
	SBIS KEYB_PIN,ROW2
	RJMP @1
	SBIS KEYB_PIN,ROW3
	RJMP @2
	SBIS KEYB_PIN,ROW4
	RJMP @3
	RJMP reset
.ENDMACRO

.MACRO writeColumns
LDS ZL, @0
LDS ZH, @0+1
ADD ZL,rowoffset
LPM temp, Z

shiftReg temp, 0
shiftReg temp, 1
shiftReg temp, 2
shiftReg temp, 3
shiftReg temp, 4
.ENDMACRO

;-------
; CODE
;-------

.ORG 0x0000
rjmp init

.ORG 0x0010
rjmp timer0_ovf

.ORG 0x0012
rjmp timer2_ovf

init:
	; Set PB3,4,5 as output
	; Set them at LOW
	LDI temp, (1<<3)|(1<<4)|(1<<5)
	OUT SCREEN_PORT, temp
	OUT SCREEN_DDR, temp

	; configure LEDs as outputs - set to HIGH to be off
	SBI LED_DDR,LEDUP_P
	SBI LED_DDR,LEDDOWN_P
	SBI LED_PORT,LEDUP_P
	SBI LED_PORT,LEDDOWN_P

	;Clear Mem
	LDI YH, high(Cell)
	LDI YL, low(Cell)

	LDI temp, low(CharacterEmpty<<1)
	ST Y, temp
	STD Y+2, temp
	STD Y+4, temp
	STD Y+6, temp
	STD Y+8, temp
	STD Y+10, temp
	STD Y+12, temp
	STD Y+14, temp
	STD Y+16, temp
	STD Y+18, temp
	STD Y+20, temp
	STD Y+22, temp
	STD Y+24, temp
	STD Y+26, temp
	STD Y+28, temp
	STD Y+30, temp
	LDI temp, high(CharacterEmpty<<1)
	STD Y+1, temp
	STD Y+3, temp
	STD Y+5, temp
	STD Y+7, temp
	STD Y+9, temp
	STD Y+11, temp
	STD Y+13, temp
	STD Y+15, temp
	STD Y+17, temp
	STD Y+19, temp
	STD Y+21, temp
	STD Y+23, temp
	STD Y+25, temp
	STD Y+27, temp
	STD Y+29, temp
	STD Y+31, temp


	; configure timer 1 in normal mode (count clk signals)
	; WGM20 = 0   WGM21 = 0
	; p155 datasheet
	LDS temp,TCCR2A
	CBR temp,(1<<WGM20)|(1<<WGM21)
	STS TCCR2A,temp

	; configure prescaler to 1024
	; CS12=0 CS11=0 CS10=1
	LDS temp,TCCR2B
	CBR temp,(1<<WGM22)
	SBR temp,(1<<CS22)|(1<<CS21)|(1<<CS20)
	STS TCCR2B,temp

	; activate overflow interrupt timer 1
	; set TOIE12
	LDS temp,TIMSK2
	SBR temp,(1<<TOIE2)
	STS TIMSK2,temp

	; configure timer0 in normal mode
	LDS temp,TCCR0A
	CBR temp,(1<<WGM00)|(1<<WGM01)
	STS TCCR0A,temp

	; set prescaler to 0 (disable) timer0
	LDS temp,TCCR0B
	CBR temp,(1<<WGM02)
	CBR temp,(1<<CS02)|(1<<CS01)|(1<<CS00)
	STS TCCR0B,temp

	; activate overflow interrupt timer 0
	LDS temp,TIMSK0
	SBR temp,(1<<TOIE0)
	STS TIMSK0,temp


	;Row offset + Row select
	LDI rowoffset, 6
	LDI rowselect, 1<<6

	SEI

	CLT
	RJMP main


main:
	; Check if all COL are HIGH
		; First set all rows to LOW as output and cols as inputs
		LDI temp,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
		OUT KEYB_PORT,temp
		LDI temp,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
		OUT KEYB_DDR,temp
		NOP
		NOP
		NOP
		; COL1 is LOW => button 11 pressed
		SBIS KEYB_PIN,COL1
		RJMP C1Pressed
		SBIS KEYB_PIN,COL2
		RJMP C2Pressed
		SBIS KEYB_PIN,COL3
		RJMP C3Pressed
		SBIS KEYB_PIN,COL4
		RJMP C4Pressed
		RJMP reset

		reset:
			SBI LED_PORT,LEDUP_P
			SBI LED_PORT,LEDDOWN_P
			BRTS noend
			RJMP main
			noend: ADIW YL, 2
			CLT
			RJMP main


		C1Pressed:
			keyboardStep2 C1R1Pressed,C1R2Pressed,C1R3Pressed,C1R4Pressed

		C2Pressed:
			keyboardStep2 C2R1Pressed,C2R2Pressed,C2R3Pressed,C2R4Pressed

		C3Pressed:
			keyboardStep2 C3R1Pressed,C3R2Pressed,C3R3Pressed,C3R4Pressed

		C4Pressed:
			keyboardStep2 C4R1Pressed,C4R2Pressed,C4R3Pressed,C4R4Pressed

		C1R1Pressed:
			; 7 pressed ->
			charToSram Character7
			SET
			RJMP main

		C1R2Pressed:
			; 4 pressed ->
			charToSram Character4
			SET
			RJMP main

		C1R3Pressed:
			; 1 pressed ->
			charToSram Character1
			SET
			RJMP main

		C1R4Pressed:
			; A pressed ->
			charToSram CharacterA
			SET
			RJMP main

		C2R1Pressed:
			; 8 pressed ->
			charToSram Character8
			SET
			RJMP main

		C2R2Pressed:
			; 5 pressed ->
			charToSram Character5
			SET
			RJMP main

		C2R3Pressed:
			; 2 pressed ->
			charToSram Character2
			SET
			RJMP main

		C2R4Pressed:
			; 0 pressed ->
			charToSram Character2
			SET
			RJMP main

		C3R1Pressed:
			; 9 pressed ->
			charToSram Character9
			SET
			RJMP main

		C3R2Pressed:
			; 6 pressed ->
			charToSram Character6
			SET
			RJMP main

		C3R3Pressed:
			; 3 pressed ->
			charToSram Character3
			SET
			RJMP main

		C3R4Pressed:
			; B pressed ->
			charToSram CharacterB
			SET
			RJMP main

		C4R1Pressed:
			; F pressed ->
			charToSram CharacterF
			SET
			RJMP main

		C4R2Pressed:
			; E pressed ->
			charToSram CharacterE
			SET
			RJMP main

		C4R3Pressed:
			; D pressed ->
			charToSram CharacterD
			SET
			RJMP main

		C4R4Pressed:
			; C pressed ->
			CBI LED_PORT,LEDUP_P
			charToSram CharacterC
			SET
			RJMP main



timer0_ovf:
	PUSH temp
	LDI temp,TCNT0_RESET_1M
	STS TCNT0,temp

	SBI SCREEN_PIN,SCREEN_LE

	LDS temp,TCCR0B
	CBR temp,(1<<WGM02)
	CBR temp,(1<<CS02)|(1<<CS01)|(1<<CS00)
	STS TCCR0B,temp
	POP temp

	RETI



timer2_ovf:
	; interruption routine
	PUSH temp
	LDI temp,TCNT2_RESET_480
	STS TCNT2,temp
	writeColumns Cell+30
	writeColumns Cell+28
	writeColumns Cell+26
	writeColumns Cell+24
	writeColumns Cell+22
	writeColumns Cell+20
	writeColumns Cell+18
	writeColumns Cell+16
	writeColumns Cell+14
	writeColumns Cell+12
	writeColumns Cell+10
	writeColumns Cell+8
	writeColumns Cell+6
	writeColumns Cell+4
	writeColumns Cell+2
	writeColumns Cell


	CBI SCREEN_PORT,SCREEN_SDI
	SBI SCREEN_PIN,SCREEN_CLK
	SBI SCREEN_PIN,SCREEN_CLK

	shiftReg rowselect, 6
	shiftReg rowselect, 5
	shiftReg rowselect, 4
	shiftReg rowselect, 3
	shiftReg rowselect, 2
	shiftReg rowselect, 1
	shiftReg rowselect, 0
	DEC rowoffset
	LSR rowselect
	BRNE end
	LDI rowselect, 1<<6
	LDI rowoffset, 6
	; set PB4 HIGH, wait 100 µs
	end:
		SBI SCREEN_PIN,SCREEN_LE
		LDS temp,TCCR2B
		SBR temp,(1<<CS02)|(1<<CS01)|(1<<CS00)
		STS TCCR0B,temp
		POP temp
		RETI

.ORG 0x800
CharacterEmpty:
	.db 0, 0, 0, 0, 0, 0, 0, 0

CharacterA:
	.db 0b00110, 0b01001, 0b01001, 0b01001, 0b01111, 0b01001, 0b01001, 0

CharacterB:
	.db 0b01110, 0b01001, 0b01001, 0b01110, 0b01001, 0b01001, 0b01110, 0

CharacterC:
	.db 0b00111, 0b01000, 0b01000, 0b01000, 0b01000, 0b01000, 0b00111, 0

CharacterD:
	.db 0b01110, 0b01001, 0b01001, 0b01001, 0b01001, 0b01001, 0b01110, 0

CharacterE:
	.db 0b01111, 0b01000, 0b01000, 0b01110, 0b01000, 0b01000, 0b01111, 0

CharacterF:
	.db 0b01111, 0b01000, 0b01000, 0b01110, 0b01000, 0b01000, 0b01000, 0

Character0:
	.db 0b01111, 0b01001, 0b01001, 0b01001, 0b01001, 0b01001, 0b01111, 0

Character1:
	.db 0b00010, 0b00110, 0b01010, 0b00010, 0b00010, 0b00010, 0b00010, 0

Character2:
	.db 0b01111, 0b00001, 0b00001, 0b01111, 0b01000, 0b01000, 0b01111, 0

Character3:
	.db 0b01111, 0b00001, 0b00001, 0b00111, 0b00001, 0b00001, 0b01111, 0

Character4:
	.db 0b01001, 0b01001, 0b01001, 0b01111, 0b00001, 0b00001, 0b00001, 0

Character5:
	.db 0b01111, 0b01000, 0b01000, 0b01111, 0b00001, 0b00001, 0b01111, 0

Character6:
	.db 0b01111, 0b01000, 0b01000, 0b01111, 0b01001, 0b01001, 0b01111, 0

Character7:
	.db 0b01111, 0b00001, 0b00001, 0b00010, 0b00100, 0b00100, 0b00100, 0

Character8:
	.db 0b01111, 0b01001, 0b01001, 0b01111, 0b01001, 0b01001, 0b01111, 0

Character9:
	.db 0b01111, 0b01001, 0b01001, 0b01111, 0b00001, 0b00001, 0b01111, 0