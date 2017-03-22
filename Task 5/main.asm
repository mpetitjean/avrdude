;
; Task 5.asm
;
; Created: 08/03/2017 14:56:08
; Author : mpetitje
;
; exercise 5

;------------
; CONSTANTS 
;------------

.include "m328pdef.inc"

;BUZZER
.equ BUZZER_P		= 1
.equ BUZZER_DDR		= DDRB
.equ BUZZER_PORT	= PORTB
.equ BUZZER_PIN		= PINB

;TCNT 1 RESET VALUE
.equ TCNT1_RESET	= 47354

;-------
; DATA 
;-------
;.DSEG
;Speed: .BYTE 1

;-------
; CODE 
;-------
.CSEG
.ORG 0x0000
rjmp init
.ORG 0X001A
rjmp timer1_ovf

init:
	; enable interrupt
	SEI
	
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
	
	rjmp main

timer1_ovf:
	
	LDI r16,high(TCNT1_RESET)
	LDI r17,low(TCNT1_RESET)
	STS TCNT1H,r16
	STS TCNT1L,r17

	SBI BUZZER_PIN,BUZZER_P
	RETI