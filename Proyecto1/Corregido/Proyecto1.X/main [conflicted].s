;   ARCHIVO:		main.s
;   DISPOSITIVO:	PIC16F887
;   AUTOR:		Andrea Barrientos Pineda (Carnet: 20575)
;   COMPILADOR:		pic-as (v2.32), MPLABX v6.00
;
;   CREADO:		05/03/2022
;   MODIFICADO:		22/03/2022
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

RESET_COUNT MACRO REG, LIMIT	    ; RESET COUNT OF SELECTED REGISTER
    
    MOVF    REG, W		    ; Move selected register to W
    ANDLW   LIMIT		    ; revisar esto :v
    MOVWF   REG
    
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
    
INCREASE_COUNT MACRO REG, PREV_REG  ; INCREMENT UNITS OF A COUNTER
    
    INCF    REG			    ; Increase value of the next unit's register
    CLRF    PREV_REG		    ; Clear previous units register
    ENDM
 
;-------------------- VARIABLES ------------------------------------------------

PSECT udata_shr			; INTERRUPTION VARIABLES
    W_TEMP:	    DS 1	; Temporal W
    STATUS_TEMP:    DS 1	; Temporal STATUS
    
PSECT udata_bank0		; PROGRAM VARIABLES
    
    ; CLK registers
    CLK_HRS_UNITS:  DS 1
    CLK_HRS_DECS:   DS 1
    CLK_MIN_UNITS:  DS 1
    CLK_MIN_DECS:   DS 1
    CLK_SEC:	    DS 1
    
    ; DATE registers
    DATE_DAY_UNITS: DS 1
    DATE_DAY_DECS:  DS 1
    DATE_MON_UNITS: DS 1
    DATE_MON_DECS:  DS 1
    
    ; Display values previous to the table (binary)
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
		    ; Content:  | | | | |EDIT|TMR|DATE|CLK|
		    ; 0: CLK
		    ; 1: DATE
		    ; 2: TMR
		    ; 3: EDIT
		    
    DISPLAY_EN:	    DS 1
		    ; Bits:	|7|6|5|4   |3 |2 |1 |0 |
		    ; Content:	| | | |DOTS|D3|D2|D1|D0|
		    ; 0: Display 0
		    ; 1: Display 1
		    ; 2: Display 2
		    ; 3: Display 3
		    ; 4: Central dots
				
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
    
    CALL    CLK			; Run CLK function
    
    CALL    LEDS		; Set values for each LED
    
    CALL    SET_DIGITS
    CALL    SELECT_DISPLAY	; Select active display
    CALL    SET_DISPLAY		; Set values for each display
    CALL    DISPLAY_0		; Set Display 0 if active
    CALL    DISPLAY_1		; Set Display 1 if active
    CALL    DISPLAY_2		; Set Display 2 if active
    CALL    DISPLAY_3		; Set Display 3 if active
    
    RETURN
    
INT_PORTB:			; PORTB INTERRUPTION
    
    CALL    PB1_FUNCTIONS
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
    CLRF    CLK_MIN_UNITS
    CLRF    CLK_MIN_DECS
    CLRF    CLK_HRS_UNITS
    CLRF    CLK_HRS_DECS
    CLRF    DATE_DAY_UNITS
    CLRF    DATE_DAY_DECS
    CLRF    DATE_MON_UNITS
    CLRF    DATE_MON_DECS
    CLRF    UNITS_1
    CLRF    DECS_1
    CLRF    UNITS_2
    CLRF    DECS_2
    CLRF    DISP_0
    CLRF    DISP_1
    CLRF    DISP_2
    CLRF    DISP_3
    
    ; Initial values:
    BSF	    DISPLAY_EN, 0	; First display to set: Display 0
    BSF	    MODE_EN, 0		; Default function: CLK
    BSF	    DATE_MON_UNITS, 0	; Default month: 1
    BSF	    DATE_DAY_UNITS, 0	; Default day: 1
    
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
    
;-------------------- INPUTS SUBROUTINES ---------------------------------------
    
PB0:				; PUSHBUTTON 0: ENABLE/DISABLE EDITION MODE
    
    BTFSC   PORTB, 0		; Check pushbutton 0
    BCF	    RBIF		; If not pressed, end interruption
    INVERT_BITS REG, 0X01	; If pressed, invert edit mode enable
    
    RETURN
    
PB1_DISPLAYS:			; PUSHBUTTON 1 IN EDITION MODE
    
    BTFSC   PORTB, 1		; Check pushbutton 1
    BCF	    RBIF		; If not pressed, end interruption
    NAVIGATE_REG, DISPLAY_EN, 3	; If pressed, navigate display selectors
    
    RETURN
    
PB1_FUNCTIONS:			; PUSHBUTTON 1 IN NORMAL MODE OF USE
    
    BTFSC   PORTB, 1		; Check pushbutton 1
    BCF	    RBIF		; If not pressed, end interruption
    NAVIGATE_REG MODE_EN, 3	; If pressed, navigate functions
    
    RETURN

PB2_INCREMENT:			; PUSHBUTTON 2 IN EDITION MODE
    RETURN	
    
PB2_START:			; PUSHBUTTON 2 IN NORMAL MODE OF USE
    RETURN
    
PB3_DECREMENT:			; PUSHBUTTON 3 IN EDITION MODE
    RETURN
    
PB3_STOP:			; PUSHBUTTON 3 IN NORMAL MODE OF USE
    RETURN
    
;-------------------- CLK FUNCTION SUBROUTINES  --------------------------------
    
CLK:
    
    ; Increase seconds
    INCF    CLK_SEC
    
    ; Increase 1 unit of minutes when reaching 59 seconds
    MOVF    CLK_SEC
    SUBLW   59
    BTFSC   STATUS, 2
    RETURN
    INCREASE_COUNT CLK_MIN_UNITS, CLK_SEC
    
    ; Increase 1 decade of minutes when reaching 9 units of minutes
    MOVF    CLK_MIN_UNITS
    SUBLW   9
    BTFSC   STATUS, 2
    RETURN
    INCREASE_COUNT CLK_MIN_DECS, CLK_MIN_UNITS
    
    ; Increase 1 unit of hours when reaching 5 decades of minutes
    MOVF    CLK_MIN_DECS
    SUBLW   5
    BTFSC   STATUS, 2
    RETURN
    INCREASE_COUNT CLK_HRS_UNITS, CLK_MIN_DECS
    
    ; Increase 1 decade of hours when reaching 9 units of hours
    MOVF    CLK_HRS_UNITS
    SUBLW   9
    BTFSC   STATUS, 2
    RETURN
    INCREASE_COUNT CLK_HRS_DECS, CLK_HRS_UNITS
    
    ; CLK overflow (Hours: 24 -> 0)
    MOVF    CLK_HRS_UNITS
    ADDLW   CLK_HRS_DECS
    SUBLW   23
    BTFSS   STATUS, 2			; CHECK STATUS 2
    CALL    CLK_OVERFLOW		; IF IT DOESN'T WORK, USE STATUS 0
    
    RETURN
    
CLK_OVERFLOW:
    CLRF    CLK_SEC
    CLRF    CLK_MIN_UNITS
    CLRF    CLK_MIN_DECS
    CLRF    CLK_HRS_UNITS
    CLRF    CLK_HRS_DECS
    RETURN
    
CLK_UNDERFLOW:			; MAKE FLAGS FOR ACTIVATING THIS
    MOVLW   59
    MOVWF   CLK_SEC
    MOVLW   9
    MOVWF   CLK_MIN_UNITS
    MOVLW   5
    MOVLW   CLK_MIN_DECS
    MOVLW   9
    MOVWF   CLK_HRS_UNITS
    MOVLW   5
    MOVWF   CLK_HRS_DECS
    RETURN
    
;-------------------- DATE FUNCTION SUBROUTINES  -------------------------------
    
DATE:
    RETURN
    
DATE_OVERFLOW:
    RETURN
    
DATE_UNDERFLOW:
    RETURN
    
;-------------------- CONTROL SUBROUTINES  -------------------------------------
    
SET_DIGITS:			; SELECT VALUES TO USE SEND TO DISPLAYS
    
    BTFSC   MODE_EN, 0		; If CLK is enabled:
    CALL    SET_CLK		; Set CLK values to use in displays
    
    BTFSC   MODE_EN, 1		; If DATE is enabled:
    CALL    SET_DATE		; Set DATE values to use in displays
    
    RETURN

SET_CLK:			; MOVE CLK VALUES TO PREPARE DISPLAY VALUES
    
    ;		    Display distribution
    ; | Display 3 | Display 2 | Display 1 | Display 0 |
    
    ; Display 0
    MOVF    CLK_MIN_UNITS
    MOVWF   UNITS_1
    
    ; Display 1
    MOVF    CLK_MIN_DECS
    MOVWF   DECS_1
    
    ; Display 2
    MOVF    CLK_HRS_UNITS
    MOVWF   UNITS_2
    
    ; Display 3
    MOVF    CLK_HRS_DECS
    MOVWF   DECS_2
    
    RETURN
    
SET_DATE:			; MOVE DATE VALUES TO PREPARE DISPLAY VALUES
    
    ; Display 0
    MOVF    DATE_DAY_UNITS
    MOVWF   UNITS_1
    
    ; Display 1
    MOVF    DATE_DAY_DECS
    MOVWF   DECS_1
    
    ; Display 2
    MOVF    DATE_MON_UNITS
    MOVWF   UNITS_2
    
    ; Display 3
    MOVF    DATE_MON_DECS
    MOVWF   DECS_2
    
    RETURN
    
SELECT_DISPLAY:			; ACTIVATE SELECTOR OF CURRENT/ACTIVE DISPLAY
    
    NAVIGATE_REG DISPLAY_EN, 4	; Macro for navigating bits
    
    MOVF    DISPLAY_EN, W	; Move display enables to W
    MOVWF   PORTD		; Move W to PORTD
    
    RETURN
    
SET_DISPLAY:			; MOVE COUNTER VALUES TO THE DISPLAY TABLE
    
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