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
.EQU TCNT0_RESET_1M = 240


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

.ORG 0x0010
rjmp timer0_ovf

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
	STS TCCR2A,r16
	
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

	; configure timer0 in normal mode
	LDS r16,TCCR0A
	CBR r16,(1<<WGM00)|(1<<WGM01)
	STS TCCR0A,r16

	; set prescaler to 0 (disable) timer0
	LDS r16,TCCR0B
	CBR r16,(1<<WGM02)
	CBR r16,(1<<CS02)|(1<<CS01)|(1<<CS00)
	STS TCCR0B,r16

	; activate overflow interrupt timer 0
	LDS r16,TIMSK0
	SBR r16,(1<<TOIE0)
	STS TIMSK0,r16

	LDI r22, 7
	LDI r21, 0b1000000
	
	SEI
	
	
	RJMP main

main:
	
	RJMP main



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


timer0_ovf:
	LDI r16,TCNT0_RESET_1M
	STS TCNT0,r16

	SBI SCREEN_PIN,4

	LDS r16,TCCR0B
	CBR r16,(1<<WGM02)
	CBR r16,(1<<CS02)|(1<<CS01)|(1<<CS00)
	STS TCCR0B,r16

	RETI



timer2_ovf: 
	; interruption routine
	LDI r16,TCNT2_RESET_480
	STS TCNT2,r16

	loop:
		LDI ZL, low(CharacterB<<1)	
		DEC r22
		BRPL notreset
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
			LDS r16,TCCR2B
			SBR r16,(1<<CS02)|(1<<CS01)|(1<<CS00)
			STS TCCR0B,r16
			RETI
