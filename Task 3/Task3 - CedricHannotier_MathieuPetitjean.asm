;
; Task 3.asm
;
; Created: 2/26/2017
; Author : channoti
;


.include "m328pdef.inc"


.org 0x0000
	rjmp init


init:
		SBI DDRC,2 ; Set LED switch as output
		SBI PORTC,2 ; Set LED off
		rjmp main


main:
		loop:
			NOP
			loop2:
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				NOP
				;loop3:
				;	INC R18
				;	brne loop3
				INC R17
				brne loop2
			INC R16
			brne loop
		SBI PINC,2
		rjmp main
