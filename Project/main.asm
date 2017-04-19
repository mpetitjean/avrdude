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
.equ KEYB_PIN   = PIND
.equ KEYB_DDR   = DDRD
.equ KEYB_PORT  = PORTD
.equ ROW1       = 7
.equ ROW2       = 6
.equ ROW3       = 5
.equ ROW4       = 4
.equ COL1       = 3
.equ COL2       = 2
.equ COL3       = 1
.equ COL4       = 0

;LEDs
.equ LEDUP_P    = 2
.equ LEDDOWN_P  = 3
.equ LED_DDR    = DDRC
.equ LED_PORT   = PORTC
.equ LED_PIN    = PINC

;SCREEN
.equ SCREEN_DDR     = DDRB
.equ SCREEN_PORT    = PORTB
.equ SCREEN_PIN     = PINB
.equ SCREEN_SDI     = 3
.equ SCREEN_CLK     = 5
.equ SCREEN_LE      = 4

;TCNT 1 RESET VALUE
.EQU TCNT2_RESET_480    = 223
.EQU TCNT0_RESET_1M     = 255

;Define some Register name
.DEF zero       = r0    ; just a 0
.DEF switch     = r1    ; to alternate low and high part of byte (for keyboard)
.DEF temp       = r16   ; register for temp. value
.DEF rowselect  = r21   ; to know the row to switch on
.DEF rowoffset  = r22   ; select the column corresponding to the right row
.DEF asciiof    = r17   ; to store the offset for ASCII table

;Memory
.DSEG
Cell: .BYTE 16; ASCII offset by cell
.CSEG
;--------
; MACROS
;--------

; for shift register (display)
.MACRO shiftReg
    SBI SCREEN_PORT, SCREEN_SDI
    SBRS @0, @1
    CBI SCREEN_PORT, SCREEN_SDI
    SBI SCREEN_PIN,SCREEN_CLK
    SBI SCREEN_PIN,SCREEN_CLK
.ENDMACRO

;to store part of ASCII ofset in low or high part of asciiof register, if switch(0) = 1 → low part, else high
.MACRO HexToASCII
SBRS switch, 0
LDI asciiof, @0<<4
SBR asciiof, @0
.ENDMACRO

; To detect key pressed from keyboard
.MACRO keyboardStep2
    ; switch in/out for rows and columns
    LDI temp,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
    OUT KEYB_PORT,temp
    LDI temp,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
    OUT KEYB_DDR,temp
    NOP
    NOP
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

; Write column patterns in shift register (display)
.MACRO writeColumns
MOVW ZL,XL              ; XL, XH → ZL, ZH, Cell table adress
ADIW ZL, @0             ; to point to the correct cell
LPM temp, Z             ; store in temp ASCII offset
LDI ZH, high(ASCII<<1)  ;  ASCII table adress
LDI ZL, low(ASCII<<1)
ADD ZL, temp            ; to point to the correct ASCII character
ADC ZH, zero
LPM temp, Z+            ; store the high part of the adress of the character configuration (columns)
LPM ZL, Z               ; same with the low part
MOV ZH, temp            
ADD ZL, rowoffset       ; to point to the correct column regarding to the row
ADC ZH, zero
LPM temp, Z             ; store in temp the column configuration

shiftReg temp, 0        ; write in shift register (display) the column configuration for that cell
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

.ORG 0x0010
rjmp timer0_ovf

.ORG 0x0012
rjmp timer2_ovf

init:
    ; Set PB3,4,5 as output
    ; Set them at LOW
    LDI temp, (1<<3)|(1<<4)|(1<<5)
    OUT SCREEN_PORT, temp
    OUT SCREEN_DDR, temp

    ; configure LEDs as outputs - set to HIGH to be off
    SBI LED_DDR,LEDUP_P
    SBI LED_DDR,LEDDOWN_P
    SBI LED_PORT,LEDUP_P
    SBI LED_PORT,LEDDOWN_P

    ;Clear Register
    CLR zero
    CLR switch

    ; Store Cell table adress in X and Y, Y will be use to point to the next cell we need to configure, X will store the adress of the Cell table
    LDI YH, high(Cell)
    LDI YL, low(Cell)
    LDI XH, high(Cell)
    LDI XL, low(Cell)

    ; Clear Memory
    ST Y, zero
    STD Y+1, zero
    STD Y+2, zero
    STD Y+3, zero
    STD Y+4, zero
    STD Y+5, zero
    STD Y+6, zero
    STD Y+7, zero
    STD Y+8, zero
    STD Y+9, zero
    STD Y+10, zero
    STD Y+11, zero
    STD Y+12, zero
    STD Y+13, zero
    STD Y+14, zero
    STD Y+15, zero


    ; configure timer 1 in normal mode (count clk signals)
    ; WGM20 = 0   WGM21 = 0
    ; p155 datasheet
    LDS temp,TCCR2A
    CBR temp,(1<<WGM20)|(1<<WGM21)
    STS TCCR2A,temp

    ; configure prescaler to 1024
    ; CS12=0 CS11=0 CS10=1
    LDS temp,TCCR2B
    CBR temp,(1<<WGM22)
    SBR temp,(1<<CS22)|(1<<CS21)|(1<<CS20)
    STS TCCR2B,temp

    ; activate overflow interrupt timer 1
    ; set TOIE12
    LDS temp,TIMSK2
    SBR temp,(1<<TOIE2)
    STS TIMSK2,temp

    ; configure timer0 in normal mode
    LDS temp,TCCR0A
    CBR temp,(1<<WGM00)|(1<<WGM01)
    STS TCCR0A,temp

    ; set prescaler to 0 (disable) timer0
    LDS temp,TCCR0B
    CBR temp,(1<<WGM02)
    CBR temp,(1<<CS02)|(1<<CS01)|(1<<CS00)
    STS TCCR0B,temp

    ; activate overflow interrupt timer 0
    LDS temp,TIMSK0
    SBR temp,(1<<TOIE0)
    STS TIMSK0,temp


    ;Row offset + Row select
    LDI rowoffset, 6
    LDI rowselect, 1<<6

    ; activate timer interrupt
    SEI

    ; clear T register
    CLT

    RJMP main


main:


    ; Check if all COL are HIGH
        ; First set all rows to LOW as output and cols as inputs
        LDI temp,(1<<COL1)|(1<<COL2)|(1<<COL3)|(1<<COL4)
        OUT KEYB_PORT,temp
        LDI temp,(1<<ROW1)|(1<<ROW2)|(1<<ROW3)|(1<<ROW4)
        OUT KEYB_DDR,temp
        NOP
        NOP
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
            BRTC main               ; if T = 0 → no key pressed → jump to main
            INC switch              ; if T = 1 → key pressed → increment the swicht (select if low or high part of a byte)
            CLT                     ; clear T
            SBRS switch, 0          ; skip if switch(0) = 1 (meaning that we only have written the high part of the ASCII offset)
            ST Y+, asciiof          ; if ASCCI offset written → store it in the correct part of the cell table
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
            HexToASCII $7<<1
            SET
            RJMP main

        C1R2Pressed:
            ; 4 pressed ->
            HexToASCII $4<<1
            SET
            RJMP main

        C1R3Pressed:
            ; 1 pressed ->
            HexToASCII $1<<1
            SET
            RJMP main

        C1R4Pressed:
            ; A pressed ->
            HexToASCII $A<<1
            SET
            RJMP main

        C2R1Pressed:
            ; 8 pressed ->
            HexToASCII $8<<1
            SET
            RJMP main

        C2R2Pressed:
            ; 5 pressed ->
            HexToASCII $5<<1
            SET
            RJMP main

        C2R3Pressed:
            ; 2 pressed ->
            HexToASCII $2<<1
            SET
            RJMP main

        C2R4Pressed:
            ; 0 pressed ->
            HexToASCII $0<<1
            SET
            RJMP main

        C3R1Pressed:
            ; 9 pressed ->
            HexToASCII $9<<1
            SET
            RJMP main

        C3R2Pressed:
            ; 6 pressed ->
            HexToASCII $6<<1
            SET
            RJMP main

        C3R3Pressed:
            ; 3 pressed ->
            HexToASCII $3<<1
            SET
            RJMP main

        C3R4Pressed:
            ; B pressed ->
            HexToASCII $B<<1
            SET
            RJMP main

        C4R1Pressed:
            ; F pressed ->
            HexToASCII $F<<1
            SET
            RJMP main

        C4R2Pressed:
            ; E pressed ->
            HexToASCII $E<<1
            SET
            RJMP main

        C4R3Pressed:
            ; D pressed ->
            HexToASCII $D<<1
            SET
            RJMP main

        C4R4Pressed:
            ; C pressed ->
            CBI LED_PORT,LEDUP_P
            HexToASCII $C<<1
            SET
            RJMP main


; to toggle SCREEN_LE after a certain amount of time
timer0_ovf:
    PUSH temp ; to keep current value of temp

    ; reset the timer counter
    LDI temp,TCNT0_RESET_1M
    STS TCNT0,temp

    ; toggle SCREEN_LE
    SBI SCREEN_PIN,SCREEN_LE

    ; stop the timer
    LDS temp,TCCR0B
    CBR temp,(1<<WGM02)
    CBR temp,(1<<CS02)|(1<<CS01)|(1<<CS00)
    STS TCCR0B,temp

    ; retreive temp value
    POP temp

    ;return
    RETI



timer2_ovf:
    ; interruption routine
    PUSH temp ; to keep current value of temp

    ; reset timer counter
    LDI temp,TCNT2_RESET_480
    STS TCNT2,temp

    ; write column configurations of each cell
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

    ; useless row
    CBI SCREEN_PORT,SCREEN_SDI
    SBI SCREEN_PIN,SCREEN_CLK
    SBI SCREEN_PIN,SCREEN_CLK

    ; write row configuration (switch on a row)
    shiftReg rowselect, 6
    shiftReg rowselect, 5
    shiftReg rowselect, 4
    shiftReg rowselect, 3
    shiftReg rowselect, 2
    shiftReg rowselect, 1
    shiftReg rowselect, 0

    ; prepare for the next iteration (upper row)
    DEC rowoffset
    LSR rowselect
    BRNE end        ; if we did all the rows → jump to the bottom (row)
    LDI rowselect, 1<<6
    LDI rowoffset, 6

    ; set PB4 HIGH, wait 100 µs
    end:
        SBI SCREEN_PIN,SCREEN_LE ; toggle SCREEN_LE

        ; switch on the other timer
        LDS temp,TCCR2B
        SBR temp,(1<<CS02)|(1<<CS01)|(1<<CS00)
        STS TCCR0B,temp

        ;retreive the temp value
        POP temp

        ;return
        RETI


;-------
; TABLE
;-------

ASCII:
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw Character0, Character1, Character2, Character3, Character4, Character5, Character6
    .dw Character7, Character8, Character9
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty
    .dw CharacterA, CharacterB, CharacterC, CharacterD, CharacterE, CharacterF, CharacterG
    .dw CharacterH, CharacterI, CharacterJ, CharacterK, CharacterL, CharacterM, CharacterN
    .dw CharacterO, CharacterP, CharacterQ, CharacterR, CharacterS, CharacterT, CharacterU
    .dw CharacterV, CharacterW, CharacterX, CharacterY, CharacterZ
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty


CharacterEmpty:
    .db 0, 0, 0, 0, 0, 0, 0, 0

CharacterA:
    .db 0b0110, 0b1001, 0b1001, 0b1001, 0b1111, 0b1001, 0b1001, 0

CharacterB:
    .db 0b1110, 0b1001, 0b1001, 0b1110, 0b1001, 0b1001, 0b1110, 0

CharacterC:
    .db 0b0111, 0b1000, 0b1000, 0b1000, 0b1000, 0b1000, 0b0111, 0

CharacterD:
    .db 0b1110, 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b1110, 0

CharacterE:
    .db 0b1111, 0b1000, 0b1000, 0b1110, 0b1000, 0b1000, 0b1111, 0

CharacterF:
    .db 0b1111, 0b1000, 0b1000, 0b1110, 0b1000, 0b1000, 0b1000, 0

CharacterG:
    .db 0b1111, 0b1000, 0b1000, 0b1000, 0b1011, 0b1001, 0b1111, 0

CharacterH:
    .db 0b1001, 0b1001, 0b1001, 0b1111, 0b1001, 0b1001, 0b1001, 0

CharacterI:
    .db 0b11111, 0b0100, 0b0100, 0b0100, 0b0100, 0b0100, 0b11111, 0

CharacterJ:
    .db 0b1111, 0b0010, 0b0010, 0b0010, 0b0010, 0b0010, 0b1110, 0

CharacterK:
    .db 0b1001, 0b1010, 0b1100, 0b1000, 0b1100, 0b1010, 0b1001, 0

CharacterL:
    .db 0b1000, 0b1000, 0b1000, 0b1000, 0b1000, 0b1000, 0b1111, 0

CharacterM:
    .db 0b1001, 0b1111, 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0

CharacterN:
    .db 0b1001, 0b1101, 0b1011, 0b1001, 0b1001, 0b1001, 0b1001, 0

CharacterO:
    .db 0b1111, 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b1111, 0

CharacterP:
    .db 0b1111, 0b1001, 0b1001, 0b1111, 0b1000, 0b1000, 0b1000, 0

CharacterQ:
    .db 0b0110, 0b1001, 0b1001, 0b1001, 0b1111, 0b1011, 0b1001, 0

CharacterR:
    .db 0b1111, 0b1001, 0b1001, 0b1111, 0b1100, 0b1010, 0b1001, 0

CharacterS:
    .db 0b0111, 0b1000, 0b1000, 0b0110, 0b0001, 0b0001, 0b0111, 0

CharacterT:
    .db 0b11111, 0b0100, 0b0100, 0b0100, 0b0100, 0b0100, 0b0100, 0

CharacterU:
    .db 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b1111, 0

CharacterV:
    .db 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b0110, 0

CharacterW:
    .db 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b1111, 0b1001, 0

CharacterX:
    .db 0b1001, 0b1001, 0b1001, 0b0110, 0b1001, 0b1001, 0b1001, 0

CharacterY:
    .db 0b1001, 0b1001, 0b1001, 0b1111, 0b0010, 0b0100, 0b1000, 0

CharacterZ:
    .db 0b1111, 0b0001, 0b0001, 0b0110, 0b1000, 0b1000, 0b1111, 0

Character0:
    .db 0b1111, 0b1001, 0b1001, 0b1001, 0b1001, 0b1001, 0b1111, 0

Character1:
    .db 0b0010, 0b0110, 0b1010, 0b0010, 0b0010, 0b0010, 0b0010, 0

Character2:
    .db 0b1111, 0b0001, 0b0001, 0b1111, 0b1000, 0b1000, 0b1111, 0

Character3:
    .db 0b1111, 0b0001, 0b0001, 0b0111, 0b0001, 0b0001, 0b1111, 0

Character4:
    .db 0b1001, 0b1001, 0b1001, 0b1111, 0b0001, 0b0001, 0b0001, 0

Character5:
    .db 0b1111, 0b1000, 0b1000, 0b1111, 0b0001, 0b0001, 0b1111, 0

Character6:
    .db 0b1111, 0b1000, 0b1000, 0b1111, 0b1001, 0b1001, 0b1111, 0

Character7:
    .db 0b1111, 0b0001, 0b0001, 0b0010, 0b0100, 0b0100, 0b0100, 0

Character8:
    .db 0b1111, 0b1001, 0b1001, 0b1111, 0b1001, 0b1001, 0b1111, 0

Character9:
    .db 0b1111, 0b1001, 0b1001, 0b1111, 0b0001, 0b0001, 0b1111, 0