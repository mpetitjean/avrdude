;
; PROJECT
; EnigmAssembly
;
; Created: 08/03/2017 17:00:00
; Author : Mathieu Petitjean & Cedric Hannotier

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

;Joystick
.equ JOYSTICK_DDR 	= DDRB
.equ JOYSTICK_PORT	= PORTB
.equ JOYSTICK_PIN 	= PINB
.equ JOYSTICK_P  	= 2

;SCREEN
.equ SCREEN_DDR		= DDRB
.equ SCREEN_PORT	= PORTB
.equ SCREEN_PIN		= PINB
.equ SCREEN_SDI		= 3
.equ SCREEN_CLK		= 5
.equ SCREEN_LE		= 4

;TCNT 1 RESET VALUE
.EQU TCNT2_RESET_480    = 245
.EQU TCNT0_RESET_1M     = 55

;Define some Register name
.DEF zero       = r0    ; Just a 0
.DEF switch     = r1    ; To alternate low and high part of byte (for keyboard)
.DEF cleareg  	= r2 	; Value offset to space ASCII character 
.DEF eof		= r3 	; Value offset to EOF ASCII character
.DEF pushapop	= r4 	; Push and Pop register (avoid to access RAM)
.DEF temp       = r16   ; Register for temp value
.DEF asciiof    = r17   ; To store the offset for ASCII table
.DEF stepreg	= r18 	; Write or XOR (0 = Write)
.DEF state      = r19 	; Encryption or Decryption (0 = Encryption)
.DEF stateJoy	= r20 	; Joystick pressed or not (0 = Pressed)
.DEF rowselect  = r21   ; Know the row to switch on
.DEF rowoffset  = r22   ; Select the column corresponding to the right row

;Memory
.DSEG
Cell: .BYTE 16; ASCII offset/cell
.CSEG

;--------
; MACROS
;--------

; Fill in the shift register for screen
.MACRO shiftReg 
	SBI SCREEN_PORT, SCREEN_SDI
	SBRS @0, @1			    		; Set to 0 if needed
	CBI SCREEN_PORT, SCREEN_SDI
	SBI SCREEN_PIN,SCREEN_CLK   	; Push value
	SBI SCREEN_PIN,SCREEN_CLK
.ENDMACRO

; Store part of ASCII offset in low or high part of asciiof register
; if switch(0) = 1 → low part, else high
.MACRO HexToASCII
SBR asciiof, @0
SBRS switch, 0
LDI asciiof, @0<<4
.ENDMACRO

; Wait
.MACRO Loop
CLR temp
begin@0:
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
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    DEC temp
    BRNE begin@0
.ENDMACRO

; Detect key pressed from keyboard (step 2 of two-steps method)
.MACRO keyboardStep2
    ; Switch in/out for rows and columns
    LDI temp,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
    OUT KEYB_PORT,temp
    LDI temp,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
    OUT KEYB_DDR,temp
    Loop key2
    ; Check which row is LOW
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

; Write one column configuration of one cell
.MACRO writeColumns
LDI ZL, low(Cell)
LDI ZH, high(Cell)     
ADIW ZL, @0             ; Point to the correct cell
LD temp, Z            	; Store in temp ASCII offset
LDI ZH, high(ASCII<<1)  ; ASCII table adress
LDI ZL, low(ASCII<<1)
LSL temp
ADD ZL, temp            ; Point to the correct ASCII character
ADC ZH, zero
LPM temp, Z+            ; Store the high part of the adress of the character configuration (columns)
LPM ZH, Z               ; Same with the low part
MOV ZL, temp
ADD ZL, rowoffset       ; Point to the correct column regarding to the row
ADC ZH, zero
LPM temp, Z             ; Store in temp the column configuration

shiftReg temp, 0        ; Write in shift register (display) the column configuration for that cell
shiftReg temp, 1
shiftReg temp, 2
shiftReg temp, 3
shiftReg temp, 4
.ENDMACRO

;-------
; CODE
;-------

.ORG 0x0000
rjmp init

.ORG 0x0012
rjmp timer2_ovf

init:

	; Screen configuration
    ; Set SDI, CLK, LE as output - set them at LOW
    LDI temp, (1<<SCREEN_SDI)|(1<<SCREEN_CLK)|(1<<SCREEN_LE)
    OUT SCREEN_PORT, temp
    OUT SCREEN_DDR, temp

    ; Configure LEDs as outputs - set to HIGH to be off
    SBI LED_DDR,LEDUP_P
    SBI LED_DDR,LEDDOWN_P
    SBI LED_PORT,LEDUP_P
    SBI LED_PORT,LEDDOWN_P

    ; Configure joystick stick
    CBI JOYSTICK_DDR,JOYSTICK_P
    SBI JOYSTICK_PORT,JOYSTICK_P

    ; Clear useful registers
    CLR zero
    CLR switch
    CLR stepreg
    CLR state
    
    ; Reg initial values
    LDI rowoffset, 6			; Number of rows
    LDI rowselect, 1<<6 		; Selection of the first row
    LDI temp, 8
    MOV cleareg, temp 			; Offset to blank space
    LDI temp, 3
    MOV eof, temp 				; Offset to EOF
    LDI stateJoy, 1 			; Joystick not pressed

    ; Store Cell table adress in Y, point to the next cell we need to configure
    LDI YH, high(Cell)
    LDI YL, low(Cell)

    ; Clear Screen (put spaces everywhere)
    LDI temp, 32
    ST Y, temp
    STD Y+1, temp
    STD Y+2, temp
    STD Y+3, temp
    STD Y+4, temp
    STD Y+5, temp
    STD Y+6, temp
    STD Y+7, temp
    STD Y+8, temp
    STD Y+9, temp
    STD Y+10, temp
    STD Y+11, temp
    STD Y+12, temp
    STD Y+13, temp
    STD Y+14, temp
    STD Y+15, temp

    ; TIMER 2 - each line needs to be refreshed at 60Hz
    ; configure timer 2 in normal mode (count clk signals)
    ; WGM20 = 0   WGM21 = 0
    LDS temp,TCCR2A
    CBR temp,(1<<WGM20)|(1<<WGM21)
    STS TCCR2A,temp

    ; configure prescaler to 1024
    ; CS12=0 CS11=0 CS10=1
    LDS temp,TCCR2B
    CBR temp,(1<<WGM22)
    SBR temp,(1<<CS22)|(1<<CS21)|(1<<CS20)
    STS TCCR2B,temp

    ; activate overflow interrupt timer 2
    ; set TOIE12
    LDS temp,TIMSK2
    SBR temp,(1<<TOIE2)
    STS TIMSK2,temp

    ; Activate global interrupt
 	SEI

    ; clear T register
    CLT

    RJMP main

main:
	; Check state of the joystick
	IN temp, JOYSTICK_PIN
	; If pressed, bit is cleared → skip
	SBRS temp, JOYSTICK_P
	RJMP pressed
	; Skip if coming from pressed state
	CPSE stateJoy, zero
	RJMP keyboard
	LDI stateJoy, 1
	; Skip if coming from encryption
	CPSE state, zero
	RJMP bigclear
	; Point to the first cell
	LDI YL, low(Cell)
	LDI YH, high(Cell)
	; Set to XOR and decryption state
	LDI stepreg, 1
	LDI state,1
	; Turn on the LED (PC3)
	CBI LED_PORT,LEDDOWN_P
	; Go to keyboard detection 
	RJMP keyboard

	; Clear the screen and go back to first cell
	bigclear: 
		LDI YL, low(Cell)
		LDI YH, high(Cell)
		LDI temp, 32
	    ST Y, temp
	    STD Y+1, temp
	    STD Y+2, temp
	    STD Y+3, temp
	    STD Y+4, temp
	    STD Y+5, temp
	    STD Y+6, temp
	    STD Y+7, temp
	    STD Y+8, temp
	    STD Y+9, temp
	    STD Y+10, temp
	    STD Y+11, temp
	    STD Y+12, temp
	    STD Y+13, temp
	    STD Y+14, temp
	    STD Y+15, temp
	    LDI stepreg, 0
	    LDI state, 0
	    RJMP keyboard

	; Joystick was pressed    
	pressed:
		LDI stateJoy, 0 			; Change state of the Joystick
		SBI LED_PORT,LEDDOWN_P
		RJMP keyboard 				; Go to keyboard detection
		tempmain: RJMP main
	

	; STEP 1 of Keyboard check
	; Check if all COL are HIGH
    ; First set all rows to LOW as output and cols as inputs
    keyboard: 
	    LDI temp,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
	    OUT KEYB_PORT,temp
	    LDI temp,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
	    OUT KEYB_DDR,temp
	    Loop key1
	    ; COLx is LOW => check for the rows (step2)
	    SBIS KEYB_PIN,COL1
	    RJMP C1Pressed
	    SBIS KEYB_PIN,COL2
	    RJMP C2Pressed
	    SBIS KEYB_PIN,COL3
	    RJMP C3Pressed
	    SBIS KEYB_PIN,COL4
	    RJMP C4Pressed
	    RJMP reset

    ; No COL is detected to be pressed, rows are not checked
    reset:
        BRTC tempmain               ; If T = 0 → no key pressed → jump to main
        INC switch              	; If T = 1 → key pressed → increment the switch(select if low or high part of a byte)
        SBI LED_PIN,LEDUP_P
        CLT                 	    ; Clear T
        CPSE eof, asciiof
        RJMP pwdencode 				; Go to pwdencode if NOT eof as last character
        INC stepreg					; Switch step state
        LDI YL, low(Cell)			; Go back to first cell
		LDI YH, high(Cell)
        RJMP main

    pwdencode: 
        SBRS stepreg, 0 			; Skip if in XOR
        RJMP clear
        SBRC switch, 0				; Skip if byte is full (second key pressed)
        RJMP main
        LD temp, Y 					; Load current offset
        EOR asciiof, temp
        ST Y+, asciiof
        RJMP main

    clear:
		CPSE cleareg, asciiof		; Skip if typed a clear (backspace)
		RJMP messagein
		ST -Y, asciiof
		RJMP main

        messagein: SBRS switch, 0   ; Skip if switch(0) = 1 (meaning that we only have written the high part of the ASCII offset)
        ST Y+, asciiof          	; If ASCCI offset written → store it in the correct part of the cell table
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
        HexToASCII $7
        SET
        RJMP main

    C1R2Pressed:
        ; 4 pressed ->
        HexToASCII $4
        SET
        RJMP main

    C1R3Pressed:
        ; 1 pressed ->
        HexToASCII $1
        SET
        RJMP main

    C1R4Pressed:
        ; A pressed ->
        HexToASCII $A
        SET
        RJMP main

    C2R1Pressed:
        ; 8 pressed ->
        HexToASCII $8
        SET
        RJMP main

    C2R2Pressed:
        ; 5 pressed ->
        HexToASCII $5
        SET
        RJMP main

    C2R3Pressed:
        ; 2 pressed ->
        HexToASCII $2
        SET
        RJMP main

    C2R4Pressed:
        ; 0 pressed ->
        HexToASCII $0
        SET
        RJMP main

    C3R1Pressed:
        ; 9 pressed ->
        HexToASCII $9
        SET
        RJMP main

    C3R2Pressed:
        ; 6 pressed ->
        HexToASCII $6
        SET
        RJMP main

    C3R3Pressed:
        ; 3 pressed ->
        HexToASCII $3
        SET
        RJMP main

    C3R4Pressed:
        ; B pressed ->
        HexToASCII $B
        SET
        RJMP main

    C4R1Pressed:
        ; F pressed ->
        HexToASCII $F
        SET
        RJMP main

    C4R2Pressed:
        ; E pressed ->
        HexToASCII $E
        SET
        RJMP main

    C4R3Pressed:
        ; D pressed ->
        HexToASCII $D
        SET
        RJMP main

    C4R4Pressed:
        ; C pressed ->
        HexToASCII $C
        SET
        RJMP main

timer2_ovf:
    ; Interruption routine at around 60Hz/line
    MOV pushapop, temp ; Save current value of temp, faster than stack

    ; Reset timer counter
    LDI temp,TCNT2_RESET_480
    STS TCNT2,temp

    ; Write column configurations of each cell
    writeColumns 15
    writeColumns 14
    writeColumns 13
    writeColumns 12
    writeColumns 11
    writeColumns 10
    writeColumns 9
    writeColumns 8
    writeColumns 7
    writeColumns 6
    writeColumns 5
    writeColumns 4
    writeColumns 3
    writeColumns 2
    writeColumns 1
    writeColumns 0

    ; Useless row of the shift register
    CBI SCREEN_PORT,SCREEN_SDI
    SBI SCREEN_PIN,SCREEN_CLK
    SBI SCREEN_PIN,SCREEN_CLK

    ; Write row configuration (switch on a row)
    shiftReg rowselect, 6
    shiftReg rowselect, 5
    shiftReg rowselect, 4
    shiftReg rowselect, 3
    shiftReg rowselect, 2
    shiftReg rowselect, 1
    shiftReg rowselect, 0

    ; Prepare for the next iteration (upper row)
    DEC rowoffset
    LSR rowselect
    BRNE end        	; If we did all the rows → jump to the bottom (row)
    LDI rowselect, 1<<6
    LDI rowoffset, 6

    ; Set SCREEN_LE HIGH, wait a suficient amount of time
    end:
        SBI SCREEN_PIN,SCREEN_LE
        Loop screenLoop
        SBI SCREEN_PIN,SCREEN_LE
        
        ; Retrieve the temp value
        MOV temp, pushapop
    
        ; Return
        RETI

;-------
; TABLES
;-------

ASCII:
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterSpace<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterSpace<<1
    .dw CharacterExclam<<1
    .dw CharacterQuote<<1
    .dw CharacterHash<<1
    .dw CharacterDollar<<1
    .dw CharacterPercent<<1
    .dw CharacterAnd<<1
    .dw CharacterPrime<<1
    .dw CharacterParLeft<<1
    .dw CharacterParRight<<1
    .dw CharacterStar<<1
    .dw CharacterPlus<<1
    .dw CharacterComma<<1
    .dw CharacterLine<<1
    .dw CharacterDot<<1
    .dw CharacterSlash<<1
    .dw Character0<<1
    .dw Character1<<1
    .dw Character2<<1
    .dw Character3<<1
    .dw Character4<<1
    .dw Character5<<1
    .dw Character6<<1
    .dw Character7<<1
    .dw Character8<<1
    .dw Character9<<1
    .dw CharacterDoubleDot<<1
    .dw CharacterSemiCol<<1
    .dw CharacterLower<<1
    .dw CharacterEqual<<1
    .dw CharacterGreater<<1
    .dw CharacterInterrogation<<1
    .dw CharacterAt<<1
    .dw CharacterA<<1
    .dw CharacterB<<1
    .dw CharacterC<<1
    .dw CharacterD<<1
    .dw CharacterE<<1
    .dw CharacterF<<1
    .dw CharacterG<<1
    .dw CharacterH<<1
    .dw CharacterI<<1
    .dw CharacterJ<<1
    .dw CharacterK<<1
    .dw CharacterL<<1
    .dw CharacterM<<1
    .dw CharacterN<<1
    .dw CharacterO<<1
    .dw CharacterP<<1
    .dw CharacterQ<<1
    .dw CharacterR<<1
    .dw CharacterS<<1
    .dw CharacterT<<1
    .dw CharacterU<<1
    .dw CharacterV<<1
    .dw CharacterW<<1
    .dw CharacterX<<1
    .dw CharacterY<<1
    .dw CharacterZ<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1
    .dw CharacterEmpty<<1

CharacterEmpty:
    .db 0, 0, 0, 0b100, 0, 0, 0, 0

CharacterSpace:
    .db 0, 0, 0, 0, 0, 0, 0, 0

CharacterExclam:
	.db 0b100, 0b100, 0b100, 0b100, 0b100, 0, 0b100, 0

CharacterQuote:
	.db 0, 0b01010, 0b01010, 0, 0, 0, 0, 0

CharacterHash:
	.db 0, 0b01010, 0b11111, 0b01010, 0b11111, 0b01010, 0, 0

CharacterDollar:
	.db 0b0111, 0b1100, 0b1100, 0b0110, 0b0101, 0b0101, 0b1110, 0

CharacterPercent:
	.db 0b11000, 0b11001, 0b00010, 0b00100, 0b01000, 0b10011, 0b11, 0

CharacterAnd:
	.db 0b110, 0b1001, 0b1010, 0b100, 0b1010, 0b1001, 0b0100, 0

CharacterPrime:
	.db 0, 0b00100, 0b00100, 0, 0, 0, 0, 0

CharacterParLeft:
	.db 0b00100, 0b1000, 0b1000, 0b1000, 0b1000, 0b1000, 0b100, 0

CharacterParRight:
	.db 0b00100, 0b10, 0b10, 0b10, 0b10, 0b10, 0b100, 0

CharacterStar:
	.db 0b100, 0b100, 0b11111, 0b100, 0b1010, 0b10001, 0, 0

CharacterPlus:
	.db 0, 0b100, 0b100, 0b11111, 0b100, 0b100, 0, 0

CharacterComma:
	.db 0, 0, 0, 0, 0b100, 0b100, 0b1000, 0

CharacterLine:
	.db 0, 0, 0, 0b1110, 0, 0, 0, 0

CharacterDot:
	.db 0, 0, 0, 0, 0, 0, 0b100, 0

CharacterSlash:
	.db 0, 1, 2, 4, 8, 16, 0, 0

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
    .db 0b1111, 0b1000, 0b1000, 0b1110, 0b1000, 0b1000, 0b1000, 0

CharacterG:
    .db 0b1111, 0b1000, 0b1000, 0b1000, 0b1011, 0b1001, 0b1111, 0

CharacterH:
    .db 0b1001, 0b1001, 0b1001, 0b1111, 0b1001, 0b1001, 0b1001, 0

CharacterI:
    .db 0b01110, 0b0100, 0b0100, 0b0100, 0b0100, 0b0100, 0b01110, 0

CharacterJ:
    .db 0b1111, 0b0001, 0b0001, 0b0001, 0b0001, 0b1001, 0b0110, 0

CharacterK:
    .db 0b1001, 0b1010, 0b1100, 0b1000, 0b1100, 0b1010, 0b1001, 0

CharacterL:
    .db 0b1000, 0b1000, 0b1000, 0b1000, 0b1000, 0b1000, 0b1111, 0

CharacterM:
    .db 0b1001, 0b1111, 0b1111, 0b1001, 0b1001, 0b1001, 0b1001, 0

CharacterN:
    .db 0b1001, 0b1101, 0b1011, 0b1001, 0b1001, 0b1001, 0b1001, 0

CharacterO:
    .db 0b1111, 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b1111, 0

CharacterP:
    .db 0b1111, 0b1001, 0b1001, 0b1111, 0b1000, 0b1000, 0b1000, 0

CharacterQ:
    .db 0b0110, 0b1001, 0b1001, 0b1001, 0b0111, 0b0010, 0b0001, 0

CharacterR:
    .db 0b1111, 0b1001, 0b1001, 0b1111, 0b1100, 0b1010, 0b1001, 0

CharacterS:
    .db 0b0111, 0b1000, 0b1000, 0b0110, 0b0001, 0b0001, 0b1110, 0

CharacterT:
    .db 0b11111, 0b0100, 0b0100, 0b0100, 0b0100, 0b0100, 0b0100, 0

CharacterU:
    .db 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b1111, 0

CharacterV:
    .db 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b0110, 0

CharacterW:
    .db 0b1001, 0b1001, 0b1001, 0b1001, 0b1111, 0b1111, 0b1001, 0

CharacterX:
    .db 0b1001, 0b1001, 0b1001, 0b0110, 0b1001, 0b1001, 0b1001, 0

CharacterY:
    .db 0b1001, 0b1001, 0b1001, 0b0111, 0b0010, 0b0100, 0b1000, 0

CharacterZ:
    .db 0b1111, 0b0001, 0b0001, 0b0110, 0b1000, 0b1000, 0b1111, 0

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

CharacterDoubleDot:
	.db 0, 0, 0b00100, 0, 0b00100, 0, 0, 0

CharacterSemiCol:
	.db 0, 0, 0b00100, 0, 0b00100, 0b00100, 0b01000, 0

CharacterLower:
	.db 0, 0b00010, 0b00100, 0b01000, 0b00100, 0b00010, 0, 0

CharacterEqual:
	.db 0, 0, 0b01110, 0, 0b01110, 0, 0, 0

CharacterGreater:
	.db 0, 0b01000, 0b00100, 0b00010, 0b00100, 0b01000, 0, 0

CharacterInterrogation:
	.db 0b01110, 0b01010, 0b00010, 0b00110, 0b00100, 0, 0b00100, 0

CharacterAt:
	.db 0, 0b11111, 0b00001, 0b01101, 0b01101, 0b01001, 0b01111, 0