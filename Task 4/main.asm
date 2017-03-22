;
; Task 4.asm
;
; Created: 2/26/2017
; Author : channoti
;


.include "m328pdef.inc"


.org 0x0000
	rjmp init


init:
		SBI DDRB,1 ; Set buzzer as output
		CBI PORTB,1 ; Set buzzer off (not mandatory)
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
		SBI PINB,1
		rjmp main
