;
; Task 2.asm
;
; Created: 2/22/2017 4:47:54 PM
; Author : channoti
;


.include "m328pdef.inc"


.org 0x0000
	rjmp init


init:
		CBI DDRC,1 ; Set Joystick Y-axis as input (not mandatory, default value)
		CBI PORTC,1 ; 
		SBI DDRC,2 ; Set LED switch as output
		SBI PORTC,2 ; Set LED off
		rjmp main


main:
		IN R0,PINC
		BST R0,1
		BRTS JoyDowm
		BRTC Joyup
		rjmp main

JoyDowm:
		SBI PORTC,2 ; Set LED off
		rjmp main

JoyUp:
		CBI PORTC,2 ; Set LED on
		rjmp main
