.ORG 0x0012
rjmp timer2_ovf

.EQU TCNT2_RESET_480 = 223

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


SEI

timer2_ovf: 
	; interruption routine
	LDI r16,TCNT2_RESET_480
	STS TCNT2,r16

	RETI