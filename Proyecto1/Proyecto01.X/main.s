;   ARCHIVO:		main.s
;   DISPOSITIVO:	PIC16F887
;   AUTOR:		Andrea Barrientos Pineda (Carnet: 20575)
;   COMPILADOR:		pic-as (v2.32), MPLABX v6.00
;
;   CREADO:		05/03/2022
;   MODIFICADO:		21/03/2022
;
;   PROGRAMA:		Proyecto 1: Reloj digital
;   HARDWARE:
;
;	- DISPOSITIVO: PIC16F887
;
;	- ENTRADAS:
;	    - Pushbutton 01 - Modo de edicion		    (PORTB: RB0)
;	    - Pushbutton 02 - Funcion/Display		    (PORTB: RB1)
;	    - Pushbutton 03 - Incrementar/decrementar	    (PORTB: RB2)
;	    - Pushbutton 04 - Iniciar/Detener		    (PORTB: RB4)
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
CONFIG LVP=ON
    
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
    
RESET_COUNT MACRO COUNTER, LIMIT    ; RESET COUNTER AT SELECTEC LIMIT
    MOVF    COUNTER, W		    ; Move counter reg to W
    SUBLW   LIMIT		    ; Subtract Limit (N-1), for a desired value.
    BTFSS   STATUS, 0		    ; If W > LIMIT, clear counter
    CLRF    COUNTER		    ; Clear counter reg
    ENDM
    
INVERT_BITS MACRO REG, BITS	    ; INVERT VALUE OF SELECTED BITS
    MOVF    REG, W		    ; Move selected register to W
    XORLW   BITS		    ; XOR to invert selected values of W
    MOVWF   REG			    ; Move W back to the selected register
    ENDM
    
NAVIGATE_REG MACRO REG, LIMIT	    ; NAVIGATE BIT BY BIT IN A REGISTER
    RLF	    REG			    ; Rotate bits through the left
    BCF	    REG, 0		    ; Clear first bit
    BTFSC   REG, LIMIT		    ; Check last desired bit
    BSF	    REG, 0		    ; Set first bit to reset the rotation.
    ENDM
    
INCREMENT_VALUE MACRO DISPLAY	    ; INCREMENT SELECTED DISPLAY VALUE
    INCF    DISPLAY, W		    ; Increment register value and save in W
    MOVWF   DISPLAY		    ; Move W back to register
    ENDM
    
DECREASE_VALUE MACRO DISPLAY	    ; DECREASE SELECTED DISPLAY VALUE
    DECF    DISPLAY, W		    ; Decrease register value and save in W
    MOVWF   DISPLAY		    ; Move W back to register
    ENDM
    
DECIMAL_COUNTER MACRO COUNTER, UNITS, DECADES
 
    GET_DECADES:
    GET_UNITS:
	
    ENDM
    
;-------------------- VARIABLES ------------------------------------------------

PSECT udata_shr			; INTERRUPTION VARIABLES
    W_TEMP:	    DS 1	; Temporal W
    STATUS_TEMP:    DS 1	; Temporal STATUS
    
PSECT udata_bank0		; PROGRAM VARIABLES
    
    ; Counter registers for all functions
    
    CLK_HRS:	    DS 1	; Clock: Hours
    CLK_MIN:	    DS 1	; Clock: Minutes
    CLK_SEC:	    DS 1	; Clock: Seconds
    
    DATE_DAY:	    DS 1	; Date: day
    DATE_MON_:	    DS 1	; Date: month
    
    TMR_MIN:	    DS 1	; Timer: minutes
    TMR_SEC:	    DS 1	; Timer: seconds
				    
    DISP_0:	    DS 1	; Display 0 value
    DISP_1:	    DS 1	; Display 1 value
    DISP_2:	    DS 1	; Display 2 value
    DISP_3:	    DS 1	; Display 3 value
    
    UNITS_TEMP:	    DS 1	; Temporal register for units
    DECADES_TEMP:   DS 1	; Temporal register for decades
    CURRENT_DISPLAY:   DS 1	; Temporal register for current display value
    
    ; Enables and flags
    
    MODE_EN:	    DS 1	; MODE/FUNCTION ENABLES
    
		    ; Bits	  | 7  | 6  | 5  | 4    | 3  | 2  | 1  | 0  |
		    ; Content	  |    |    |    |TMR_ON|EDIT|TMR |DATE|CLK |
		    
		    ; 0-2: Function (Only one set at a time)
		    ; 3	 : Edit mode
			; 1: enabled
			; 0: disabled
		    ; 4  : Start/Stop TMR
			; 1: start
			; 0: stop
		    
    DISPLAY_EN:     DS 1	; DISPLAY ENABLES: SELECTOR FOR DISPLAYS
		    
		    ; Bits	  | 7  | 6  | 5  | 4  | 3  | 2  | 1  | 0  |
		    ; Content	  |    |    |    |    |D3  |D2  |D1  |D0  |
		    
		    ; 0-3: Enable Display 1-4, respectively
    
		    ; In all cases: 1 is on, and 0 is off.
		    
		    
    PB_FLAG:	    DS 1	; PUSHBUTTON FLAGS: INDICATE ACTION TO DO
		    
		    ; Bits	  | 7  | 6  | 5  | 4  | 3  | 2  | 1  | 0  |
		    ; Content	  |    |    |    |    |PB3 |PB2 |PB1 |PB0 |
		    
		    ; 0: Edition mode flag
			; 1: Edition mode activated
			; 0: Edition mode desactivated
		    ; 1: Navigation mode flag
			; 1: Navigate displays: 1-4 
			; 0: Navigate functions: CLK, DATE, TMR and ALRM
		    ; 2: Action 1 flag
			; 1: Increment current display value
			; 0: Decrement current display value
		    ; 3: Action 2 flag
			; 1: Start TMR
			; 0: Stop TMR
				
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
    
INT_TMR0:			; TMR0 INTERRUPTIONS: VALUE CONTROL AND OUTPUTS
    
    RESET_TMR0			; Reset TMR0
    
    ; Check values of enables and flags
    BTFSC   PB_FLAG, 0		; If flag is set, enable edit mode
    CALL    SET_EDIT_MODE
    BTFSS   PB_FLAG, 0		; If flag is clear, enable normal mode
    CALL    SET_NORMAL_MODE
    
    ; Set output values
    CALL    SET_LEDS		; Set values of all LEDs
    CALL    SELECT_DISPLAY_EDIT	; Select display to edit
    
    RETURN
    
INT_PORTB:			; PORTB INTERRUPTION: CHECK ALL INPUTS
    
    PB0:
    BTFSC   PORTB, 0		; Check pushbutton 0  
    GOTO    PB1
    INVERT_BITS PB_FLAG, 0X01	; If pressed, invert edit mode flag.
    
    PB1:
    BTFSC   PORTB, 1		; Check pushbutton 1
    GOTO    PB2			; If not pressed, go to Pushbutton 2
    BTFSC   PB_FLAG, 1		; If flag is set, navigate displays.
    NAVIGATE_REG DISPLAY_EN, 4
    BTFSS   PB_FLAG, 1		; If flag is clear, navigate functions.
    NAVIGATE_REG MODE_EN, 3
    
    PB2:			; Check pushbutton 2
    BTFSC   PORTB, 2		; If not pressed, go to clr
    GOTO    PB3			
    BTFSC   PB_FLAG, 2		; If flag is set, increment display value
    INCREMENT_VALUE CURRENT_DISPLAY
    BTFSS   PB_FLAG, 2		; If flag is clear, decrease display value
    DECREASE_VALUE CURRENT_DISPLAY
    
    PB3:	
    BTFSC   PORTB, 4		; Check pushbutton 3 (though it's bit 4 :v)
    GOTO    CLR
    BTFSC   PB_FLAG, 3		; If flag is set, start timer.
    
    
    
    CLR:
    BCF	    RBIF		; Clean PORTB interruption flag
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
    CALL    DEFAULT_VALUES	; Set default values
    
    RESET_TMR0			; Reset TMR0
    
    BANKSEL PORTA		; Bank 0
    
LOOP:				; MAIN LOOP
    GOTO    LOOP
    
;-------------------- CONFIGURATION SUBROUTINES --------------------------------

CONFIG_IO:			; I/O CONFIG
    
    BANKSEL ANSEL		; Bank 3
    CLRF    ANSEL		; Digital I/O
    CLRF    ANSELH		; Digital I/O
    
    BANKSEL TRISA		; Bank 1
    
    ; Clean all TRIS registers
    CLRF    TRISA		; Set TRISA as output
    CLRF    TRISB		
    CLRF    TRISC		; Set TRISC as output
    CLRF    TRISD		; Set TRISD as output
    
    ; Set TRIS registers as inputs
    BSF	    TRISB, 0		; Pushbutton 0 (Edit mode)
    BSF	    TRISB, 1		; Pushbutton 1 (Functions)
    BSF	    TRISB, 2		; Pushbutton 2 (Increment/decrement)
    BSF	    TRISB, 3		; Pin defectuoso
    BSF	    TRISB, 4		; Pushbutton 3 (Start/stop)
    
    BCF	    TRISD, 0
    BCF	    TRISD, 1
    BCF	    TRISD, 2
    BCF	    TRISD, 3
    
    ; Clean ports:
    BANKSEL PORTA		; Bank 0
    CLRF    PORTA		
    CLRF    PORTB
    CLRF    PORTC
    CLRF    PORTD
    
    ; Clean registers:
    CLRF    PB_FLAG		; Clear pushbutton flags
    CLRF    MODE_EN		; Clear functions flags
    CLRF    DISPLAY_EN		; Clear display enables
    
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
    
    ; Enable interruptions on change
    CLRF    IOCB
    BSF	    IOCB, 0
    BSF	    IOCB, 1
    BSF	    IOCB, 2
    BSF	    IOCB, 3
    BSF	    IOCB, 4
    
    ; Enable weak pull-up
    CLRF    WPUB
    BSF	    WPUB, 0
    BSF	    WPUB, 1
    BSF	    WPUB, 2
    BSF	    WPUB, 3
    BSF	    WPUB, 4
    
    BCF	    OPTION_REG, 7	; Enable PORTB internal pull-ups
    BCF	    OPTION_REG, 6	; Enable falling edge of INT pin interrupt
    
    BANKSEL PORTB
    MOVF    PORTB
    BCF	    RBIF		; Limpiar bandera de PORTB.
    RETURN
    
CONFIG_INT:			; INTERRUPTIONS CONFIGURATION

    BANKSEL INTCON		; Bank 0
    BSF	    GIE			; Enable global interruptions
    BSF	    PEIE		; Enable periferic interruptions
    BCF	    T0IF		; Clean TMR0 interruption flag
    BSF	    T0IE		; Enable TMR0 interruptions
    MOVF    PORTB		; Read PORTB
    BCF	    RBIF		; Clean PORTB interruption flag
    BSF	    RBIE		; Enable PORTB interruptions
   
    RETURN

;-------------------- SETUP SUBROUTINES ----------------------------------------
    
SET_EDIT_MODE:			; SET FLAG VALUES TO USE EDIT MODE
    
    BSF	    PB_FLAG, 1		; Enable display navigation
    BSF	    MODE_EN, 3		; Enable edit mode
    BCF	    MODE_EN, 0
    
    RETURN
    
SET_NORMAL_MODE:		; CLEAR FLAG VALUES TO USE NORMAL MODE
    
    BCF	    PB_FLAG, 1		; Enable function navigation
    BCF	    MODE_EN, 3		; Disable edit mode
    
    
    RETURN
    
DEFAULT_VALUES:			; INITIAL VALUES OF FUNCTIONS AND DISPLAY
    BSF	    MODE_EN, 0
    BSF	    DISPLAY_EN, 0
    RETURN
    
;-------------------- CONTROL SUBROUTINES --------------------------------------

;;SHOW_FUNCTION:			; SET VALUES TO SHOW FOR EACH FUNCTION
;;    BTFSC   MODE_EN, 0
;;    GOTO    SET_CLK
;;    BTFSC   MODE_EN, 1
;;    GOTO    SET_DATE
;;    BTFSC   MODE_EN, 2
;;    GOTO    SET_TMR
;;    
;;    SET_CLK:
;;	MOVF	CLK_MIN_UNITS, W
;;	MOVWF	DISP_0
;;	MOVF	CLK_MIN_DECS, W
;;	MOVWF	DISP_1
;;	MOVF	CLK_HRS_UNITS, W
;;	MOVWF	DISP_2
;;	MOVF	CLK_HRS_DECS, W
;;	MOVWF	DISP_3
;;	
;;    SET_DATE:
;;	MOVF	DATE_DAY_UNITS, W
;;	MOVWF	DISP_0
;;	MOVF	DATE_DAY_DECS, W
;;	MOVWF	DISP_1
;;	MOVF	DATE_MON_UNITS, W
;;	MOVWF	DISP_2
;;	MOVF	DATE_MON_DECS, W
;;	
;;    SET_TMR:
;;	MOVF	TMR_SEC_UNITS, W
;;	MOVWF	DISP_0
;;	MOVF	TMR_SEC_DECS, W
;;	MOVWF	DISP_1
;;	MOVF	TMR_MIN_UNITS, W
;;	MOVWF	DISP_2
;;	MOVF	TMR_MIN_DECS, W
;;	MOVWF	DISP_3
;;	
;;    RETURN
	
DISPLAY_VALUES:			; PREPARE VALUES FOR DISPLAYS
    
    ; Display 0
    MOVF    DISP_0, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_0
    
    ; Display 1
    MOVF    DISP_1, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_1
    
    ; Display 2
    MOVF    DISP_2, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_2
    
    ; Display 3
    MOVF    DISP_3, W
    CALL    DISPLAY_TABLE
    MOVWF   DISP_3
    
    RETURN
    
;-------------------- OUTPUT SUBROUTINES ---------------------------------------
    
SET_LEDS:			; PREPARE VALUES FOR LEDS
    MOVF    MODE_EN, W		; Move function enables to W.
    ANDLW   0X3F		; 0011 1111: Bits 0-5 are LEDs, avoid the rest.
    MOVWF   PORTA		; Send value to PORTA for updating all LEDs
   
    RETURN
    
SELECT_DISPLAY_EDIT:		; UPDATE DISPLAY SELECTORS
    MOVF    DISPLAY_EN, W	; Move Display (and Dots) enables to W
    ANDLW   0X0F		; 0000 1111: Bits 0-3 are display selectors.
    MOVWF   PORTD		; Move W to PORTD, to update enables
    RETURN
    
DISPLAY_0:			; SHOW DISPLAY 0
    BTFSS   PORTD, 0
    RETURN
    MOVF    DISP_0, W
    MOVWF   PORTC
    RETURN
    
DISPLAY_1:			; SHOW DISPLAY 1
    BTFSS   PORTD, 1
    RETURN
    MOVF    DISP_1, W
    MOVWF   PORTC
    RETURN
    
DISPLAY_2:			; SHOW DISPLAY 2
    BTFSS   PORTD, 2
    RETURN
    MOVF    DISP_2, W
    MOVWF   PORTC
    RETURN
    
DISPLAY_3:			; SHOW DISPLAY 3
    BTFSS   PORTD, 3
    RETURN
    MOVF    DISP_3, W
    MOVWF   PORTC
    
END