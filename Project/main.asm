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

;Define some Rd name
.DEF zero       = r0
.DEF switch     = r1
.DEF temp       = r16
.DEF rowselect  = r21
.DEF rowoffset  = r22
.DEF asciiof    = r17

;Memory
.DSEG
Cell: .BYTE 16; LED cell
.CSEG
;--------
; MACROS
;--------
.MACRO shiftReg
    SBI SCREEN_PORT, SCREEN_SDI
    SBRS @0, @1
    CBI SCREEN_PORT, SCREEN_SDI
    SBI SCREEN_PIN,SCREEN_CLK
    SBI SCREEN_PIN,SCREEN_CLK
.ENDMACRO

.MACRO HexToASCII
SBRS switch, 0
LDI asciiof, @0<<4
SBR asciiof, @0
.ENDMACRO

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

.MACRO writeColumns
MOVW ZL,XL
ADIW ZL, @0
LPM temp, Z
LDI ZH, high(ASCII)
LDI ZL, low(ASCII)
ADD ZL, temp
ADC ZH, zero
LPM temp, Z+
LPM ZL, Z
MOV ZH, temp
ADD ZL, rowoffset
ADC ZH, zero
LPM temp, Z

shiftReg temp, 0
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

    ;Clear Mem
    CLR zero
    CLR switch
    LDI YH, high(Cell)
    LDI YL, low(Cell)
    LDI XH, high(Cell)
    LDI XL, low(Cell)

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

    SEI

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
            BRTC main
            INC switch
            CLT
            SBRS switch, 0
            ST Y+, asciiof
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
            CBI LED_PORT,LEDUP_P
            HexToASCII $C
            SET
            RJMP main



timer0_ovf:
    PUSH temp
    LDI temp,TCNT0_RESET_1M
    STS TCNT0,temp

    SBI SCREEN_PIN,SCREEN_LE

    LDS temp,TCCR0B
    CBR temp,(1<<WGM02)
    CBR temp,(1<<CS02)|(1<<CS01)|(1<<CS00)
    STS TCCR0B,temp
    POP temp

    RETI



timer2_ovf:
    ; interruption routine
    PUSH temp
    LDI temp,TCNT2_RESET_480
    STS TCNT2,temp
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

    CBI SCREEN_PORT,SCREEN_SDI
    SBI SCREEN_PIN,SCREEN_CLK
    SBI SCREEN_PIN,SCREEN_CLK

    shiftReg rowselect, 6
    shiftReg rowselect, 5
    shiftReg rowselect, 4
    shiftReg rowselect, 3
    shiftReg rowselect, 2
    shiftReg rowselect, 1
    shiftReg rowselect, 0
    DEC rowoffset
    LSR rowselect
    BRNE end
    LDI rowselect, 1<<6
    LDI rowoffset, 6
    ; set PB4 HIGH, wait 100 µs
    end:
        SBI SCREEN_PIN,SCREEN_LE
        LDS temp,TCCR2B
        SBR temp,(1<<CS02)|(1<<CS01)|(1<<CS00)
        STS TCCR0B,temp
        POP temp
        RETI

.ORG 0x800

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
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty
    .dw Character0, Character1, Character2, Character3, Character4, Character5, Character6
    .dw Character7, Character8, Character9
    .dw CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty, CharacterEmpty
    .dw CharacterEmpty, CharacterEmpty
    .dw CharacterA, CharacterB, CharacterC, CharacterD, CharacterE, CharacterF, CharacterF
    .dw CharacterF, CharacterF, CharacterF, CharacterF, CharacterF, CharacterF, CharacterF
    .dw CharacterF, CharacterF, CharacterF, CharacterF, CharacterF, CharacterF, CharacterF
    .dw CharacterF, CharacterF, CharacterF, CharacterF, CharacterF, 

CharacterEmpty:
    .db 0, 0, 0, 0, 0, 0, 0, 0

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