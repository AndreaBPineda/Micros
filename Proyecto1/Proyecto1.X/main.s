;   ARCHIVO:		main.s
;   DISPOSITIVO:	PIC16F887
;   AUTOR:		Andrea Barrientos Pineda (Carnet: 20575)
;   COMPILADOR:		pic-as (v2.32), MPLABX v6.00
;
;   CREADO:		05/03/2022
;   MODIFICADO:		26/03/2022
;
;   PROGRAMA:		Proyecto 1: Reloj digital
;   HARDWARE:
;
;	- DISPOSITIVO: PIC16F887
;
;	- ENTRADAS:
;	    - Pushbutton 01 - Modo de edicion		    (PORTB: RB0)
;	    - Pushbutton 02 - Funcion/Display		    (PORTB: RB1)
;	    - Pushbutton 03 - Incrementar/Start		    (PORTB: RB2)
;	    - Pushbutton 04 - Decrementar/Stop		    (PORTB: RB4)
;
;	- SALIDAS:
;	    - LEDs (x4)	    - Indicadores de función	    (PORTA: RA0-RA3)
;	    - LEDs (x1)     - Indicador de edición          (PORTA: RA4)
;	    - Display de 7 segmentos (x4) - Pantalla del reloj
;		- Segmentos de displays			    (PORTC: RC0-RC7)
;		- Selectores de displays		    (PORTD: RD0-RD3)

;-------------------- DISPOSITIVO Y LIBRERIAS ----------------------------------
PROCESSOR 16F887
#include <xc.inc>
    
;-------------------- CONFIG 1 -------------------------------------------------
CONFIG FOSC=INTRC_NOCLKOUT
CONFIG WDTE=OFF
CONFIG PWRTE=ON
CONFIG MCLRE=OFF
CONFIG CP=OFF
CONFIG CPD=OFF    
CONFIG BOREN=OFF
CONFIG IESO=OFF
CONFIG FCMEN=OFF
CONFIG LVP=OFF
    
;-------------------- CONFIG 2 -------------------------------------------------
CONFIG WRT=OFF
CONFIG BOR4V=BOR40V

;-------------------- MACROS ---------------------------------------------------
RESET_TMR0 MACRO		    ; RESET TMR0
    
    BANKSEL TMR0		    ; Bank 0
    MOVLW   255			    ; Interruption time
    MOVWF   TMR0		    ; Set interruption time in TMR0
    BCF	    T0IF		    ; Clear interruption flag TMR0
    
    ENDM
    
INVERT_BITS MACRO REG, BITS
    MOVF    REG
    XORLW   BITS
    MOVWF   REG
    ENDM
    
NAVIGATE_REG MACRO REG, LIMIT	    ; NAVIGATE BIT BY BIT IN A REGISTER
    
    RLF	    REG			    ; Rotate bits through the left
    BCF	    REG, 0		    ; Clear first bit
    BTFSC   REG, LIMIT		    ; Check last desired bit
    BSF	    REG, 0		    ; Set first bit to reset the rotation.
    BCF	    REG, LIMIT		    ; Clear last bit of the rotation.
    
    ENDM
    
DECIMAL_COUNTER MACRO REG_1, REG_2, LIMIT
    MOVF    REG_1, W
    SUBLW   LIMIT
    BTFSC   STATUS, 0
    RETURN
    INCF    REG_2
    CLRF    REG_1
    ENDM
    
RESET_COUNT MACRO REG_1, REG_2, LIMIT_1, LIMIT_2, FLAG
    MOVF    REG_1, W
    SUBLW   LIMIT_1
    BTFSC   STATUS, 0
    RETURN
    MOVF    REG_2, W
    SUBLW   LIMIT_2
    BTFSC   STATUS, 0
    RETURN
    BSF	    FLAG, 0
    ENDM
 
;-------------------- VARIABLES ------------------------------------------------

PSECT udata_shr			; INTERRUPTION VARIABLES
    W_TEMP:	    DS 1	; Temporal W
    STATUS_TEMP:    DS 1	; Temporal STATUS
    
PSECT udata_bank0		; PROGRAM VARIABLES
    
    CLK_OVERFLOW_FLAG:   DS 1
    CLK_SEC:		 DS 1
    
    DATE_DAY_UNITS:	DS 1
    DATE_DAY_DECS:	DS 1
    DATE_MON_UNITS:	DS 1
    DATE_MON_DECS:	DS 1
    DATE_MONTH_FLAG:	DS 1
    DATE_MONTH:		DS 1
	
    TMR_SEC_UNITS:	DS 1
    TMR_SEC_DECS:	DS 1
    TMR_MIN_UNITS:	DS 1
    TMR_MIN_DECS:	DS 1
    
    UNITS_1:	    DS 1	
    DECS_1:	    DS 1
    UNITS_2:	    DS 1
    DECS_2:	    DS 1
    
    ; Display values after the table (hexadecimal)
    DISP_0:	    DS 1
    DISP_1:	    DS 1
    DISP_2:	    DS 1
    DISP_3:	    DS 1
    
    ; Flags and enables
    MODE_EN:	    DS 1
		    ; Bits:	|7|6|5|4|3   |2  |1   |0  |
		    ; Content:  |-|-|-|-|EDIT|TMR|DATE|CLK|
		    ; 0: CLK
		    ; 1: DATE
		    ; 2: TMR
		    ; 3: EDIT
		    
    DISPLAY_EN:	    DS 1
		    ; Bits:	|7|6|5|4   |3 |2 |1 |0 |
		    ; Content:	|-|-|-|DOTS|D3|D2|D1|D0|
		    ; 0: Display 0
		    ; 1: Display 1
		    ; 2: Display 2
		    ; 3: Display 3
		    ; 4: Central dots
		    
    PB_FLAG:	    DS 1
		    ; Bits:	|7|6|5|4|3       |2       |1  |0   |
		    ; Content:  |-|-|-|-|ACTION_2|ACTION_1|NAV|EDIT|
		    ; 1: Navigation - 1: displays, 0: functions/modes
		    ; 2: Action	    - 1: increment display, 0: start TMR
		    ; 3: Action	    - 1: decrement display, 0: stop TMR
				
PSECT resVect, class=CODE, abs, delta=2
ORG 00h				; Posicion 0000h: Vector Reset
    
;-------------------- VECTOR RESET ---------------------------------------------

resetVec:
    PAGESEL MAIN
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h				; Posicion 0004h: Interruptions
    
;-------------------- INTERRUPTIONS --------------------------------------------
    
PUSH:				; SAVE W AND STATUS VALUES
    
    MOVWF   W_TEMP		; W -> W_TEMP
    SWAPF   STATUS, W		; Swap STATUS, and save in W
    MOVWF   STATUS_TEMP		; W -> STATUS_TEMP
    
ISR:				; INTERRUPTIONS
    
    BANKSEL PORTA		; Bank 0
    BTFSC   RBIF		; Check PORTB interruption flag
    CALL    INT_PORTB		; Execute PORTB interruption on RBIF = 1
    BTFSC   T0IF		; Check TMR0 interruption flag
    CALL    INT_TMR0		; Execute TMR0 interruption on T0IF = 1
    
POP:				; RECOVER W AND STATUS VALUES
    
    SWAPF   STATUS_TEMP, W	; Swap STATUS_TEMP, save in W
    MOVWF   STATUS		; Move W to STATUS
    SWAPF   W_TEMP, F		; Swap W_TEMP, save in register F
    SWAPF   W_TEMP, W		; Swap W_TEMP again, save in W
    RETFIE			; End interruptions
    
;-------------------- SUBRUTINAS DE INTERRUPCION -------------------------------

INT_TMR0:			; TIMER 0 INTERRUPTION
    
    RESET_TMR0
    
    CALL    SELECT_DISPLAY
    
    ; Check CLK function flag
    BTFSC   MODE_EN, 0
    CALL    CLK
    
    ; Check DATE function flag
    BTFSC   MODE_EN, 1
    CALL    DATE

	; Check TMR function flag    
    BTFSC   MODE_EN, 2
    CALL    SET_DISPLAY_TMR
    
    RETURN
    
INT_PORTB:			; PORTB INTERRUPTION
    
    PB0:
    BTFSC   PORTB, 0		; If pushbutton 0 pressed
    GOTO    PB1
    INVERT_BITS MODE_EN, 0X08
    
    PB1:
    BTFSC   PORTB, 1
    GOTO    CLR
    NAVIGATE_REG MODE_EN, 3	; If pressed, navigate display selectors
    
    CLR:
    BCF	    RBIF
    RETURN
    
PSECT code, delta=2, abs
ORG 100h			; Posicion 0100h: tables and main
 
DISPLAY_TABLE:			; 7Seg Display values table
    
    ; Config:
    CLRF    PCLATH		; Clean PCLATH
    BSF     PCLATH, 0		; Enable Bit 0
    ANDLW   0x0F		; Turn W to 4 Bits
    ADDWF   PCL, F		; Sum PCL to W, save in F
    
    ; Values:
    ;       pgfedcba		hexadecimal
    RETLW   00111111B		; 0
    RETLW   00000110B		; 1
    RETLW   01011011B		; 2
    RETLW   01001111B		; 3
    RETLW   01100110B		; 4
    RETLW   01101101B		; 5
    RETLW   01111101B		; 6
    RETLW   00000111B		; 7
    RETLW   01111111B		; 8
    RETLW   01101111B		; 9
    RETLW   01110111B		; A
    RETLW   01111100B		; B
    RETLW   00111001B		; C
    RETLW   01011110B		; D
    RETLW   01111001B		; E
    RETLW   01110001B		; F
    
;-------------------- MAIN PROGRAM ---------------------------------------------
MAIN:				; PROGRAM SETUP
    CALL    CONFIG_IO		; I/O config
    CALL    CONFIG_CLOCK	; Oscilator config
    CALL    CONFIG_TMR0		; TMR0 config
    CALL    CONFIG_IOCB		; PORTB interruptions config
    CALL    CONFIG_INT		; Interruptions config
    
    BANKSEL PORTA		; Bank 0
    
    BSF	    MODE_EN, 0
    
LOOP:				; MAIN LOOP
    BTFSC   MODE_EN, 0
    CALL    SET_DISPLAY_CLK
    
    BTFSC   MODE_EN, 1
    CALL    SET_DISPLAY_DATE
    
    CALL    DISPLAY_0
    CALL    DISPLAY_1
    CALL    DISPLAY_2
    CALL    DISPLAY_3
    CALL    LEDS
    
    GOTO    LOOP
    
;-------------------- PIC CONFIGURATION SUBROUTINES ----------------------------

CONFIG_IO:			; I/O CONFIG
    
    BANKSEL ANSEL		; Bank 3
    CLRF    ANSEL		; Digital I/O
    CLRF    ANSELH		; Digital I/O
    
    BANKSEL TRISA		; Bank 1
    
    ; Clean TRIS registers
    CLRF    TRISA		
    CLRF    TRISB
    CLRF    TRISC
    CLRF    TRISD
    
    ; Set input ports
    BSF	    TRISB, 0		; Pushbutton 0
    BSF	    TRISB, 1		; Pushbutton 1
    BSF	    TRISB, 2		; Pushbutton 2
    BSF	    TRISB, 3		; Pushbutton 3
    
    ; Clean ports:
    BANKSEL PORTA		; Bank 0
    CLRF    PORTA		
    CLRF    PORTB
    CLRF    PORTC
    CLRF    PORTD
    
    ; Clean registers:
    CLRF    MODE_EN
    CLRF    DISPLAY_EN
    CLRF    CLK_SEC    
    CLRF    UNITS_1
    CLRF    DECS_1
    CLRF    UNITS_2
    CLRF    DECS_2
    CLRF    DATE_DAY_UNITS
    CLRF    DATE_DAY_DECS
    CLRF    DATE_MON_UNITS
    CLRF    DATE_MON_DECS
    CLRF    TMR_SEC_UNITS
    CLRF    TMR_SEC_DECS
    CLRF    TMR_MIN_UNITS
    CLRF    TMR_MIN_DECS
    CLRF    DISP_0
    CLRF    DISP_1
    CLRF    DISP_2
    CLRF    DISP_3
    CLRF    CLK_OVERFLOW_FLAG
    
    ; Initial values:
    BSF	    DISPLAY_EN, 0	; First display to set: Display 0
    RETURN
    
CONFIG_CLOCK:			; OSCILATOR CONFIGURATION
   
    BANKSEL OSCCON		; Bank 2
    BSF	    OSCCON, 0		; Enable internal clock
    BCF	    OSCCON, 6		; 0
    BSF	    OSCCON, 5		; 1	   -> Freq: 500kHz
    BSF	    OSCCON, 4		; 1
    
    RETURN
    
CONFIG_TMR0:			; TMR0 CONFIGURATION
    
    BANKSEL OPTION_REG		; Bank 0
    BCF	    T0CS		; Clean T0CS
    BCF	    PSA			; Enable counter
    BSF	    PS2			; 1
    BSF	    PS1			; 1	    -> Prescaler 1:256
    BSF	    PS0			; 1
    
    RETURN
    
CONFIG_IOCB:			; PORTB CONFIGURATION FOR PUSHBUTTONS
   
    BANKSEL TRISA
    
    ; Enable interruption on change for selected bits
    CLRF    IOCB
    BSF	    IOCB, 0
    BSF	    IOCB, 1
    BSF	    IOCB, 2
    BSF	    IOCB, 3
    
    ; Enable weak pull-up for selected bits
    CLRF    WPUB
    BSF	    WPUB, 0
    BSF	    WPUB, 1
    BSF	    WPUB, 2
    BSF	    WPUB, 3
    
    BCF	    OPTION_REG, 7	; PORTB internal pull-ups
    BCF	    OPTION_REG, 6	; Falling-edge of INT pin interrupt
    
    BANKSEL PORTB
    BCF	    RBIF		; Limpiar bandera de PORTB.
    RETURN
    
CONFIG_INT:			; INTERRUPTIONS CONFIGURATION

    BANKSEL INTCON		; Bank 0
    BSF	    GIE			; Enable global interruptions
    BSF	    PEIE		; Enable periferic interruptions
    BCF	    T0IF		; Clean TMR0 interruption flag
    BSF	    T0IE		; Enable TMR0 interruptions
    BCF	    RBIF		; Clean PORTB interruption flag
    BSF	    RBIE		; Enable PORTB interruptions
   
    RETURN
    
;-------------------- FUNCTION SUBROUTINES  --------------------------------
    
CLK:
    INCF    CLK_SEC
    DECIMAL_COUNTER CLK_SEC, UNITS_1, 59    ; Increase units of minutes
    DECIMAL_COUNTER UNITS_1, DECS_1, 9	    ; Increase decades of minutes
    DECIMAL_COUNTER DECS_1, UNITS_2, 5	    ; Increase units of hours
    DECIMAL_COUNTER UNITS_2, DECS_2, 9	    ; Increase decades of hours
    
    ; Reset CLK when reaching 24 hours
    RESET_COUNT DECS_2, DECS_1, 2, 4, CLK_OVERFLOW_FLAG
    BTFSC   CLK_OVERFLOW_FLAG, 0
    CALL    CLK_OVERFLOW
    
    RETURN
    
DATE:
    
    ; Increase day
    BTFSC   CLK_OVERFLOW_FLAG, 0
    RETURN
    INCF    DATE_DAY_UNITS
    DECIMAL_COUNTER DATE_DAY_UNITS, DATE_DAY_DECS, 9
    
    ; Month: 01
    MOVF    DATE_MONTH 				; Check value of month counter
    SUBLW   1						; In each case, select the subroutine with the right amount of days.
    BTFSC   STATUS, 0
    CALL    MONTH_31_DAYS			; Days counter, limited to a specific amount of days depending on the month.
    
    ; Month: 02
    MOVF    DATE_MONTH
    SUBLW   2
    BTFSC   STATUS, 0
    CALL    MONTH_28_DAYS
    
    ; Month: 03
    MOVF    DATE_MONTH
    SUBLW   3
    BTFSC   STATUS, 0
    CALL    MONTH_31_DAYS
    
    ; Month: 04
    MOVF    DATE_MONTH
    SUBLW   4
    BTFSC   STATUS, 0
    CALL    MONTH_30_DAYS
    
    ; Month: 05
    MOVF    DATE_MONTH
    SUBLW   5
    BTFSC   STATUS, 0
    CALL    MONTH_31_DAYS
    
    ; Month: 06
    MOVF    DATE_MONTH
    SUBLW   6
    BTFSC   STATUS, 0
    CALL    MONTH_30_DAYS
    
    ; Month: 07
    MOVF    DATE_MONTH
    SUBLW   7
    BTFSC   STATUS, 0
    CALL    MONTH_31_DAYS
    
    ; Month: 08
    MOVF    DATE_MONTH
    SUBLW   8
    BTFSC   STATUS, 0
    CALL    MONTH_31_DAYS
    
    ; Month: 09
    MOVF    DATE_MONTH
    SUBLW   9
    BTFSC   STATUS, 0
    CALL    MONTH_30_DAYS
    
    ; Month: 10
    MOVF    DATE_MONTH
    SUBLW   10
    BTFSC   STATUS, 0
    CALL    MONTH_31_DAYS
    
    ; Month: 11
    MOVF    DATE_MONTH
    SUBLW   11
    BTFSC   STATUS, 0
    CALL    MONTH_30_DAYS
    
    ; Month: 12
    MOVF    DATE_MONTH
    SUBLW   12
    BTFSC   STATUS, 0
    CALL    MONTH_31_DAYS
    
    ; Clear month counter
    MOVF    DATE_MONTH
    SUBLW   12
    CLRF    DATE_MONTH
    
    RETURN
    
; Month counters

MONTH_30_DAYS:						; 30 day month counter
    RESET_COUNT DATE_DAY_DECS, DATE_DAY_UNITS, 3, 0, DATE_MONTH_FLAG ; Decimal counter for days
    BTFSC   DATE_MONTH_FLAG, 0							; If flag is set, the limit of the current month was reached.
    RETURN
    CALL    NEXT_MONTH									; Go to the following month.
    
    RETURN
    
MONTH_31_DAYS:											; 31 day counter
    RESET_COUNT DATE_DAY_DECS, DATE_DAY_UNITS, 3, 1, DATE_MONTH_FLAG	; Decimal counter for days
    BTFSC   DATE_MONTH_FLAG, 0							; If flag is set, the limit of the month has been reached
    RETURN
    CALL    NEXT_MONTH									; Go to the following month
    
    RETURN
    
MONTH_28_DAYS:											; 28 day counter
    RESET_COUNT DATE_DAY_DECS, DATE_DAY_UNITS, 2, 8, DATE_MONTH_FLAG ; Decimal counter of days
    BTFSC   DATE_MONTH_FLAG, 0								; If flag is set, the limit of the month was reached
    RETURN
    CALL    NEXT_MONTH										; Go to the following month.
    RETURN
    
CLK_OVERFLOW:				; CLK overflow: clear all registers with clk values to return to 00:00
    
    CLRF    CLK_SEC
    CLRF    UNITS_1
    CLRF    DECS_1
    CLRF    UNITS_2
    CLRF    DECS_2
    
    RETURN
    
NEXT_MONTH:					; set next month
    
    BCF	DATE_MONTH_FLAG, 0				; clear flag 
    INCF    DATE_MON_UNITS				; Increase month counter
    DECIMAL_COUNTER DATE_MON_UNITS, DATE_MON_DECS, 9 ; Set decimal counter of months
    
    RETURN
    
;-------------------- CONTROL SUBROUTINES  -------------------------------------
    
SELECT_DISPLAY:			; ACTIVATE SELECTOR OF CURRENT/ACTIVE DISPLAY
    
    NAVIGATE_REG DISPLAY_EN, 4	; Macro for navigating bits
    
    MOVF    DISPLAY_EN, W	; Move display enables to W
    MOVWF   PORTD		; Move W to PORTD
    
    RETURN
    
SET_DISPLAY_CLK:		; MOVE COUNTER VALUES TO THE DISPLAY TABLE
    
    ; Display 0
    MOVF    UNITS_1, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_0
    
    ; Display 1
    MOVF    DECS_1, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_1
    
    ; Display 2
    MOVF    UNITS_2, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_2
    
    ; Display 3
    MOVF    DECS_2, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_3
    
    RETURN
    
SET_DISPLAY_DATE:		; MOVE COUNTER VALUES TO THE DISPLAY TABLE
    
    ; Display 0
    MOVF    DATE_MON_UNITS, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_0
    
    ; Display 1
    MOVF    DATE_MON_DECS, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_1
    
    ; Display 2
    MOVF    DATE_DAY_UNITS, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_2
    
    ; Display 3
    MOVF    DATE_DAY_DECS, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_3
    
    RETURN
    
SET_DISPLAY_TMR:
    
    ; Display 0
    MOVF    TMR_SEC_UNITS, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_0
    
    ; Display 1
    MOVF    TMR_SEC_DECS, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_1
    
    ; Display 2
    MOVF    TMR_MIN_UNITS, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_2
    
    ; Display 3
    MOVF    TMR_MIN_DECS, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_3
    
    RETURN
    
;-------------------- OUTPUTS SUBROUTINES --------------------------------------
    
DISPLAY_0:			; ACTIVATE DISPLAY 0 IF SELECTED
    BTFSS   PORTD, 0
    RETURN
    MOVF    DISP_0, W
    MOVWF   PORTC
    RETURN
    
DISPLAY_1:			; ACTIVATE DISPLAY 1 IF SELECTED
    BTFSS   PORTD, 1
    RETURN
    MOVF    DISP_1, W
    MOVWF   PORTC
    RETURN
    
DISPLAY_2:			; ACTIVATE DISPLAY 2 IF SELECTED
    BTFSS   PORTD, 2
    RETURN
    MOVF    DISP_2, W
    MOVWF   PORTC
    RETURN
    
DISPLAY_3:			; ACTIVATE DISPLAY 3 IF SELECTED
    BTFSS   PORTD, 3
    RETURN
    MOVF    DISP_3, W
    MOVWF   PORTC
    RETURN
    
LEDS:				; ACTIVATED SELECTED LEDS
    MOVF    MODE_EN, W
    ANDLW   0X0F
    MOVWF   PORTA
    RETURN
    
END