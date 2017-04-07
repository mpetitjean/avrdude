;
; task10
;
; Created: 08/03/2017 17:00:00
; Author : Mathieu Petitjean

.include "m328pdef.inc"





;------------
; CONSTANTS 
;------------

;SCREEN
.equ SCREEN_DDR		= DDRB
.equ SCREEN_PORT	= PORTB
.equ SCREEN_PIN		= PINB
.equ SCREEN_DATA	= 3
.equ SCREEN_CLK		= 5

;TCNT 1 RESET VALUE
.EQU TCNT2_RESET_480 = 223


;--------
; MACROS
;--------
.MACRO shiftReg
	SBI SCREEN_PORT, SCREEN_DATA
	SBRS @0, @1
	CBI SCREEN_PORT, SCREEN_DATA
	SBI SCREEN_PIN,SCREEN_CLK
	SBI SCREEN_PIN,SCREEN_CLK
.ENDMACRO


;-------
; CODE 
;-------
.CSEG

.ORG 0x0000
rjmp init

.ORG 0x0012
rjmp timer2_ovf

init:
	; Set PB3,4,5 as output
	; Set them at LOW
	LDI r17, (1<<3)|(1<<4)|(1<<5)
	OUT SCREEN_PORT, r17
	OUT SCREEN_DDR, r17

	; configure timer 1 in normal mode (count clk signals)
	; WGM20 = 0   WGM21 = 0      
	; p155 datasheet
	LDS r16,TCCR2A
	CBR r16,(1<<WGM20)|(1<<WGM21)
	STS TCCR1A,r16
	
	; configure prescaler to 1024
	; CS12=0 CS11=0 CS10=1
	LDS r16,TCCR2B
	CBR r16,(1<<WGM22)
	SBR r16,(1<<CS22)|(1<<CS21)|(1<<CS20)
	STS TCCR2B,r16
	
	; activate overflow interrupt timer 1
	; set TOIE12
	LDS r16,TIMSK2
	SBR r16,(1<<TOIE2)
	STS TIMSK2,r16
	LDI r22, 7
	
	
	SEI
	
	
	RJMP main

main:
	
	RJMP main



timer2_ovf: 
	SBI SCREEN_PIN, 4
	; interruption routine
	LDI r16,TCNT2_RESET_480
	STS TCNT2,r16

	loop:
		LDI ZL, low(CharacterA<<1)
		DEC r22
		BRNE notreset
		LDI r22, 6
		notreset: ADD ZL,r22
		LPM r1, Z


		LDI r18,0x10
		columns:
			shiftReg r1, 0
			shiftReg r1, 1
			shiftReg r1, 2
			shiftReg r1, 3
			shiftReg r1, 4
			DEC r18
			BRNE columns
		
		CBI SCREEN_PORT,SCREEN_DATA
		SBI SCREEN_PIN,SCREEN_CLK
		SBI SCREEN_PIN,SCREEN_CLK

		shiftReg r21, 6
		shiftReg r21, 5
		shiftReg r21, 4
		shiftReg r21, 3
		shiftReg r21, 2
		shiftReg r21, 1
		shiftReg r21, 0

		LSR r21
		BRNE end
		LDI r21, 0b1000000


		; set PB4 HIGH, wait 100 µs
		end:
			SBI SCREEN_PIN,4
			RETI


CharacterA: 
	.db 0b00110, 0b01001, 0b01001, 0b01001, 0b01111, 0b01001, 0b01001, 0;.db 0b11111, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001, 0