;
; testKeyboard.asm
;
; Created: 08/03/2017 17:00:00
; Author : Mathieu Petitjean

.include "m328pdef.inc"


;------------
; CONSTANTS 
;------------

;BUZZER
.equ BUZZER_P		= 1
.equ BUZZER_DDR		= DDRB
.equ BUZZER_PORT	= PORTB
.equ BUZZER_PIN		= PINB

;TCNT 1 RESET VALUE
.equ TCNT1_RESET_880	= 47354

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

;--------
; MACROS
;--------
.MACRO keyboardStep2
	; switch in/out for rows and columns
	LDI r16,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
	OUT KEYB_PORT,r16
	LDI r16,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
	OUT KEYB_DDR,r16
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

;-------
; CODE 
;-------
.CSEG
.ORG 0x0000
rjmp init

.ORG 0X001A
rjmp timer1_ovf

init:
	
	; configure LEDs as outputs - set to HIGH to be off
	SBI LED_DDR,LEDUP_P
	SBI LED_DDR,LEDDOWN_P
	SBI LED_PORT,LEDUP_P
	SBI LED_PORT,LEDDOWN_P

	; configure buzzer as output
	SBI BUZZER_DDR,BUZZER_P
	SBI BUZZER_PORT,BUZZER_P

	; configure timer 1 in normal mode (count clk signals)
	; WGM10 = 0   WGM11 = 0
	LDS r16,TCCR1A
	CBR r16,(1<<WGM10)|(1<<WGM11)
	STS TCCR1A,r16

	; configure prescaler to 1
	; WGM12=0 WGM13=0 CS12=0 CS11=0 CS10=1
	LDS r16,TCCR1B
	CBR r16,(1<<WGM12)|(1<<WGM13)|(1<<CS12)|(1<<CS11)
	SBR r16,(1<<CS10)
	STS TCCR1B,r16

	; activate overflow interrupt timer 1
	; TOIE1
	LDS r16,TIMSK1
	SBR r16,(1<<TOIE1)
	STS TIMSK1,r16
	
	rjmp main


main:
	; Check if all COL are HIGH
		; First set all rows to LOW as output and cols as inputs
		LDI r16,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
		LDI r17,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
		OUT KEYB_PORT,r16
		OUT KEYB_DDR,r17
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
			CLI
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
			; 7 pressed -> 2 LEDS on and buzzer off
			CBI LED_PORT,LEDUP_P
			CBI LED_PORT,LEDDOWN_P
			;disable interrupt
			CLI
			RJMP main

		C1R2Pressed:
			; 4 pressed -> LED up OFF, LED down ON
			SBI LED_PORT,LEDUP_P
			CBI LED_PORT,LEDDOWN_P
			CLI
			RJMP main

		C1R3Pressed:
			; 1 pressed -> buzzer
			SEI
			RJMP main

		C1R4Pressed:
			; A pressed -> buzzer
			SEI
			RJMP main

		C2R1Pressed:
			; 8 pressed -> LED up ON, LED down OFF, buzzer OFF
			CBI LED_PORT,LEDUP_P
			SBI LED_PORT,LEDDOWN_P
			CLI
			RJMP main

		C2R2Pressed:
			; 5 pressed -> buzzer
			SEI
			RJMP main

		C2R3Pressed:
			; 2 pressed -> buzzer
			SEI
			RJMP main

		C2R4Pressed:
			; 0 pressed -> buzzer
			SEI
			RJMP main

		C3R1Pressed:
			; 9 pressed -> buzzer
			SEI
			RJMP main

		C3R2Pressed:
			; 6 pressed -> buzzer
			SEI
			RJMP main

		C3R3Pressed:
			; 3 pressed -> buzzer
			SEI
			RJMP main

		C3R4Pressed:
			; B pressed -> buzzer
			SEI
			RJMP main

		C4R1Pressed:
			; F pressed -> buzzer
			SEI
			RJMP main

		C4R2Pressed:
			; E pressed -> buzzer
			SEI
			RJMP main

		C4R3Pressed:
			; D pressed -> buzzer
			SEI
			RJMP main

		C4R4Pressed:
			; C pressed -> buzzer
			SEI
			RJMP main

timer1_ovf: 
	; interruption routine
	LDI r16,HIGH(TCNT1_RESET_880)
	LDI r17,LOW(TCNT1_RESET_880)
	STS TCNT1H,r16
	STS TCNT1L,r17
	SBI BUZZER_PIN,BUZZER_P
	RETI