;
; TestProject1.asm
;
; Created: 2/22/2017 3:00:04 PM
; Author : channoti
;

.include "m328pdef.inc"


.org 0x0000
	rjmp init


init:
		CBI DDRB,2 ; Set Joystick click as input (not mandatory, default value)
		SBI PORTB,2 ; Avoid floating point
		SBI DDRC,2 ; Set LED switch as output
		SBI PORTC,2 ; Set LED off
		rjmp main


main:
		IN R0,PINB
		BST R0,2
		BRTS JoyNotPressed
		BRTC JoyPressed
		rjmp main

JoyNotPressed:
		SBI PORTC,2 ; Set LED off
		rjmp main

JoyPressed:
		CBI PORTC,2 ; Set LED on
		rjmp main
