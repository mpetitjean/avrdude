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
.equ SCREEN_DATA	= 3
.equ SCREEN_CLK		= 5

;TCNT 1 RESET VALUE
.EQU TCNT2_RESET_480 = 223
.EQU TCNT0_RESET_1M = 255


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

.MACRO keyboardStep2
	; switch in/out for rows and columns
	LDI r17,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
	LDI r19,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
	OUT KEYB_PORT,r17
	OUT KEYB_DDR,r19
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

	; configure LEDs as outputs - set to HIGH to be off
	SBI LED_DDR,LEDUP_P
	SBI LED_DDR,LEDDOWN_P
	SBI LED_PORT,LEDUP_P
	SBI LED_PORT,LEDDOWN_P

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
	

	LDI YH, high(0x0100)
	LDI YL, low(0x0100)

	LDI r18, low(Character7<<1)
	ST Y, r18
	LDI r18, high(Character7<<1)
	STD Y+1, r18
	CLT
	RJMP main


main:
	; Check if all COL are HIGH
		; First set all rows to LOW as output and cols as inputs
		LDI r17,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
		LDI r19,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
		OUT KEYB_PORT,r17
		OUT KEYB_DDR,r19
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
			LDI r18, low(Character7<<1)
			ST Y, r18
			LDI r18, high(Character7<<1)
			STD Y+1, r18
			SET
			RJMP main

		C1R2Pressed:
			; 4 pressed -> 
			LDI r18, low(Character4<<1)
			ST Y, r18
			LDI r18, high(Character4<<1)
			STD Y+1, r18
			SET
			RJMP main

		C1R3Pressed:
			; 1 pressed -> 
			LDI r18, low(Character1<<1)
			ST Y, r18
			LDI r18, high(Character1<<1)
			STD Y+1, r18
			SET
			RJMP main

		C1R4Pressed:
			; A pressed -> 
			LDI r18, low(CharacterA<<1)
			ST Y, r18
			LDI r18, high(CharacterA<<1)
			STD Y+1, r18
			SET
			RJMP main

		C2R1Pressed:
			; 8 pressed -> 
			LDI r18, low(Character8<<1)
			ST Y, r18
			LDI r18, high(Character8<<1)
			STD Y+1, r18
			SET
			RJMP main

		C2R2Pressed:
			; 5 pressed -> 
			LDI r18, low(Character5<<1)
			ST Y, r18
			LDI r18, high(Character5<<1)
			STD Y+1, r18
			SET
			RJMP main

		C2R3Pressed:
			; 2 pressed -> 
			LDI r18, low(Character2<<1)
			ST Y, r18
			LDI r18, high(Character2<<1)
			STD Y+1, r18
			SET
			RJMP main

		C2R4Pressed:
			; 0 pressed -> 
			LDI r18, low(Character0<<1)
			ST Y, r18
			LDI r18, high(Character0<<1)
			STD Y+1, r18
			SET
			RJMP main

		C3R1Pressed:
			; 9 pressed -> 
			LDI r18, low(Character9<<1)
			ST Y, r18
			LDI r18, high(Character9<<1)
			STD Y+1, r18
			SET
			RJMP main

		C3R2Pressed:
			; 6 pressed -> 
			LDI r18, low(Character6<<1)
			ST Y, r18
			LDI r18, high(Character6<<1)
			STD Y+1, r18
			SET
			RJMP main

		C3R3Pressed:
			; 3 pressed -> 
			LDI r18, low(Character3<<1)
			ST Y, r18
			LDI r18, high(Character3<<1)
			STD Y+1, r18
			SET
			RJMP main

		C3R4Pressed:
			; B pressed -> 
			LDI r18, low(CharacterB<<1)
			ST Y, r18
			LDI r18, high(CharacterB<<1)
			STD Y+1, r18
			SET
			RJMP main

		C4R1Pressed:
			; F pressed -> 
			LDI r18, low(CharacterF<<1)
			ST Y, r18
			LDI r18, high(CharacterF<<1)
			STD Y+1, r18
			SET
			RJMP main

		C4R2Pressed:
			; E pressed -> 
			LDI r18, low(CharacterE<<1)
			ST Y, r18
			LDI r18, high(CharacterE<<1)
			STD Y+1, r18
			SET
			RJMP main

		C4R3Pressed:
			; D pressed -> 
			LDI r18, low(CharacterD<<1)
			ST Y, r18
			LDI r18, high(CharacterD<<1)
			STD Y+1, r18
			SET
			RJMP main

		C4R4Pressed:
			; C pressed -> 
			CBI LED_PORT,LEDUP_P
			LDI r18, low(CharacterC<<1)
			ST Y, r18
			LDI r18, high(CharacterC<<1)
			STD Y+1, r18
			SET
			RJMP main



timer0_ovf:
	LDI r23,TCNT0_RESET_1M
	STS TCNT0,r23

	SBI SCREEN_PIN,4

	LDS r23,TCCR0B
	CBR r23,(1<<WGM02)
	CBR r23,(1<<CS02)|(1<<CS01)|(1<<CS00)
	STS TCCR0B,r23

	RETI



timer2_ovf: 
	; interruption routine
	LDI r16,TCNT2_RESET_480
	STS TCNT2,r16

	loop:
		DEC r22
		BRPL notreset
		LDI r22, 6
		notreset:
		LDS ZL, 0x0100
		LDS ZH, 0x0101
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4
		
		LDS ZL, 0x0102
		LDS ZH, 0x0103
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0104
		LDS ZH, 0x0105
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0106
		LDS ZH, 0x0107
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0108
		LDS ZH, 0x0109
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0110
		LDS ZH, 0x0111
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0112
		LDS ZH, 0x0113
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0114
		LDS ZH, 0x0115
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0116
		LDS ZH, 0x0117
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0118
		LDS ZH, 0x0119
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0120
		LDS ZH, 0x0121
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0122
		LDS ZH, 0x0123
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0124
		LDS ZH, 0x0125
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0126
		LDS ZH, 0x0127
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0128
		LDS ZH, 0x0129
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

		LDS ZL, 0x0130
		LDS ZH, 0x0131
		ADD ZL,r22
		LPM r1, Z

		shiftReg r1, 0
		shiftReg r1, 1
		shiftReg r1, 2
		shiftReg r1, 3
		shiftReg r1, 4

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

.ORG 0x800

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