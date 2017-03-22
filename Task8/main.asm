;
; task8
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

;TCNT 1 RESET VALUE
.equ TCNT1_RESET_880	= 47354
.equ TCNT1_RESET_1760	= 56444

;--------
; MACROS
;--------

;-------
; CODE 
;-------
.CSEG
.ORG 0x0000
rjmp init

init:

	; Set PB3,4,5 as output
	; Set them at LOW
	LDI r17, (1<<3)|(1<<4)|(1<<5)
	OUT SCREEN_PORT, r17
	OUT SCREEN_DDR, r17

	RJMP main

main:
	; loop for 80 columns
	LDI r18,0x50
	; Set PB3 as HIGH
	SBI SCREEN_PIN,3
	
	loopCol :
		SBI SCREEN_PIN,5
		SBI SCREEN_PIN,5
		DEC r18
		BRNE loopCol

	; loop for 8 rows
	LDI r18, 0x08
	loopRow :
		SBI SCREEN_PIN,5
		SBI SCREEN_PIN,5
		DEC r18
		BRNE loopRow

	; set PB4 HIGH, wait 100 µs
	SBI SCREEN_PIN,4

	; Finite loop - wait
	LDI R17,0xFF
	MyLoop: 
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		DEC R17
		BRNE MyLoop
	SBI SCREEN_PIN,4

	RJMP main

