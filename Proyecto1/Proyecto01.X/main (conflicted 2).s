;   ARCHIVO:		main.s
;   DISPOSITIVO:	PIC16F887
;   AUTOR:		Andrea Barrientos Pineda (Carnet: 20575)
;   COMPILADOR:		pic-as (v2.32), MPLABX v6.00
;
;   CREADO:		05/03/2022
;   MODIFICADO:		19/03/2022
;
;   PROGRAMA:		Proyecto 1: Reloj digital
;   HARDWARE:
;
;	- DISPOSITIVO: PIC16F887
;
;	- ENTRADAS:
;	    - Pushbutton 01 - Modo de edicion		    (PORTB: RB0)
;	    - Pushbutton 02 - Funcion/Display		    (PORTB: RB1)
;	    - Pushbutton 03 - Incrementar/iniciar	    (PORTB: RB2)
;	    - Pushbutton 04 - Decrementar/detener	    (PORTB: RB3)
;
;	- SALIDAS:
;	    - LEDs (x4)	    - Indicadores de función	    (PORTA: RA0-RA3)
;	    - LEDs (x1)     - Indicador de edición          (PORTA: RA4)
;	    - LEDs (x1)	    - Alarma			    (PORTA: RA5)
;	    - Display (7seg, 4digits) - Pantalla de reloj
;	      (displays 0-3 de izquierda a derecha)
;		- Segmentos de displays			    (PORTC: RC0-RC7)
;		- Selectores de displays		    (PORTD: RD0-RD3)
;		- Segmento de puntos centrales		    (PORTD: RD4)

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
RESET_TMR0 MACRO		; RESET TMR0
    BANKSEL TMR0		; Bank 0
    MOVLW   255			; Interruption time
    MOVWF   TMR0		; Set interruption time in TMR0
    BCF	    T0IF		; Clear interruption flag TMR0
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
    
REG_NAVI MACRO REG, LIMIT	; NAVIGATE SELECTED BITS OF A REGISTER
    MOVF    REG, W		; Move selected register to W
    RLF	    REG			; Disable current function, enable next one
    BTFSS   REG, LIMIT		; End subroutine if 0 (not in the last function)
    RETURN			
    BCF	    REG, LIMIT		; Disable current function (last function)
    BSF	    REG, 0		; Enable first function again
    MOVWF   REG			; Move W back to the selected register
    ENDM
    
;-------------------- VARIABLES ------------------------------------------------

PSECT udata_shr			; INTERRUPTION VARIABLES
    W_TEMP:	    DS 1	; Temporal W
    STATUS_TEMP:    DS 1	; Temporal STATUS
    
PSECT udata_bank0		; PROGRAM VARIABLES
    
    ; Counter registers for all functions
    
    CLK_HRS:	    DS 1	; Clock: hours
    CLK_MIN:	    DS 1	; Clock: minutes
    CLK_SEC:	    DS 1	; Clock: seconds
    
    DATE_DAY:	    DS 1	; Date: day
    DATE_MON:	    DS 1	; Date: month
    
    TMR_MIN:	    DS 1	; Timer: minutes
    TMR_SEC:	    DS 1	; Timer: seconds
    
    ALRM_HRS:	    DS 1	; Alarm: hours
    ALRM_MIN:	    DS 1	; Alarm: minutes
				    
    DISP_0:	    DS 1	; Display 0 value
    DISP_1:	    DS 1	; Display 1 value
    DISP_2:	    DS 1	; Display 2 value
    DISP_3:	    DS 1	; Display 3 value
    DOTS:	    DS 1	; Central dots value
    
    ; Enables and flags
    
    MODE_EN:	    DS 1	; MODE/FUNCTION ENABLES
    
		    ; Bits	  | 7  | 6     | 5    | 4  | 3  | 2  | 1  | 0  |
		    ; Content	  |    |ALRM_ON|TMR_ON|EDIT|ALRM|TMR |DATE|CLK |
		    
		    ; 0-3: Function (Only one set at a time)
		    ; 4	 : Edit mode
			; 1: enabled
			; 0: disabled
		    ; 5  : Start/Stop TMR
			; 1: start
			; 0: stop
		    ; 6  : Start/Stop ALRM
			; 1: start
			; 0: stop
		    
    DISPLAY_EN:     DS 1	; DISPLAY ENABLES: SELECTOR FOR DISPLAYS
		    
		    ; Bits	  | 7  | 6  | 5  | 4  | 3  | 2  | 1  | 0  |
		    ; Content	  |    |    |    |DOTS|D3  |D2  |D1  |D0  |
		    
		    ; 0-3: Enable Display 1-4, respectively
		    ; 4  : Enable center dots of the display module.
    
		    ; In all cases: 1 is on, and 0 is off.
		    
		    
    PB_FLAG:	    DS 1	; PUSHBUTTON FLAGS: INDICATE ACTION TO DO
		    
		    ; Bits	  | 7  | 6  | 5  | 4  | 3  | 2  | 1  | 0  |
		    ; Content	  |F3  |F2  |F1  |F0  |PB3 |PB2 |PB1 |PB0 |
		    
		    ; Bits 0-3: Pushbutton values
		    ; Bits 4-6: Pushbutton flags
		    
		    ; 0-3: Pushbuttons 1-3 input values, respectively.
			; 1: Pressed
			; 0: Not pressed
		    ; 4: Edition mode flag
			; 1: Edition mode activated
			; 0: Edition mode desactivated
		    ; 5: Navigation mode flag
			; 1: Navigate displays: 1-4 
			; 0: Navigate functions: CLK, DATE, TMR and ALRM
		    ; 6: Action 1 flag
			; 1: Increment current display value
			; 0: Enable start for TMR/ALRM
		    ; 7: Action 2 flag
			; 1: Decrement current display value
			; 0: Enable stop for TMR/ALRM
				
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
    BCF	    INTF
    BSF	    INTE
    
POP:				; RECOVER W AND STATUS VALUES
    
    SWAPF   STATUS_TEMP, W	; Swap STATUS_TEMP, save in W
    MOVWF   STATUS		; Move W to STATUS
    SWAPF   W_TEMP, F		; Swap W_TEMP, save in register F
    SWAPF   W_TEMP, W		; Swap W_TEMP again, save in W
    RETFIE			; End interruptions
    
;-------------------- SUBRUTINAS DE INTERRUPCION --------------------
    
INT_TMR0:			; TMR0 INTERRUPTIONS: VALUE CONTROL AND OUTPUTS
    
    RESET_TMR0			; Reset TMR0
    
    ; Check values of enables and flags
    BTFSC   PB_FLAG, 0		; If flag is set, enable edit mode
    CALL    SET_EDIT_MODE
    BTFSS   PB_FLAG, 0		; If flag is clear, enable normal mode
    CALL    SET_NORMAL_MODE
    
    ; Set output values
    CALL    SET_LEDS		; Set values of all LEDs
    
    RETURN
    
INT_PORTB:			; PORTB INTERRUPTION: CHECK ALL INPUTS
    
    ; Pushbutton 0: Edition mode control
    BTFSC   PORTB, 0		; Check pushbutton 0
    RETURN			; If not pressed, end interruption
    INVERT_BITS PB_FLAG, 0x01	; Invert value of edit mode flag
    
    ; Pushbutton 1: Navigation of functions/displays
    BTFSC   PORTB, 1		; Check pushbutton 1
    RETURN			; If not pressed, end interruption
    ;REG_NAVI MODE_EN, 3		; Navigate function bits when button is pressed
    BSF	    PORTA, 0
    
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
    
;-------------------- MAIN PROGRAM --------------------
MAIN:				; PROGRAM SETUP
    CALL    CONFIG_IO		; I/O config
    CALL    CONFIG_CLOCK	; Oscilator config
    CALL    CONFIG_TMR0		; TMR0 config
    CALL    CONFIG_IOCB		; PORTB interruptions config
    CALL    CONFIG_INT		; Interruptions config
    
    RESET_TMR0			; Reset TMR0
    
    BANKSEL PORTA		; Bank 0
    
LOOP:				; MAIN LOOP
    
    GOTO    LOOP
    
;-------------------- CONFIGURATION SUBROUTINES --------------------

CONFIG_IO:			; I/O CONFIG
    
    BANKSEL ANSEL		; Bank 3
    CLRF    ANSEL		; Digital I/O
    CLRF    ANSELH		; Digital I/O
    
    BANKSEL TRISA		; Bank 1
    
    ; Clean all TRIS registers
    CLRF    TRISA
    CLRF    TRISB
    CLRF    TRISC
    CLRF    TRISD
    CLRF    TRISE
    
    ; Set TRIS registers as inputs
    BSF	    TRISB, 0		; Pushbutton 0 (Edit mode)
    BSF	    TRISB, 1		; Pushbutton 1 (Functions)
    BSF	    TRISB, 2		; Pushbutton 2 (Increment/start)
    BSF	    TRISB, 3		; Pushbutton 3 (Decrement/stop)
    
    ; Clean ports:
    BANKSEL PORTA		; Bank 0
    CLRF    PORTA		
    CLRF    PORTB		
    CLRF    PORTC		
    CLRF    PORTD
    CLRF    PORTE
    
    ; Clean registers:
    CLRF    PB_FLAG		; Clear pushbutton flags
    CLRF    MODE_EN		; Clear functions flags
    CLRF    DISP_0		; Clear display 0
    CLRF    DISP_1		; Clear display 1
    CLRF    DISP_2		; Clear display 2
    CLRF    DISP_3		; Clear display 3
    CLRF    DOTS		; Clear central dots flag
    
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
    
    ; Enable weak pull-up
    CLRF    WPUB
    BSF	    WPUB, 0
    BSF	    WPUB, 1
    BSF	    WPUB, 2
    BSF	    WPUB, 3
    
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
    BCF     INTF
    BSF     INTE
   
    RETURN

;-------------------- SETUP SUBROUTINES ----------------------------------------
    
SET_NAVIGATION:			; SET NAVIGATION OF DISPLAYS OR FUNCTIONS
    BTFSC   PB_FLAG, 1		; If set, enable display navigation
    CALL    NAV_DISPLAYS
    BTFSS   PB_FLAG, 1		; If clear, enable function navigation
    CALL    NAV_FUNCTIONS
    RETURN
    
SET_ACTION_1:			; SET VALUE INCREMENT OR START FUNCTION
    BTFSC   PB_FLAG, 2		; If set, enable increment of display value
    CALL    DISPLAY_INC
    BTFSS   PB_FLAG, 2		; If clear, enable start action for TMR
    CALL    FUNC_START
    RETURN
    
SET_ACTION_2:			; SET VALUE DECREMENT OR STOP FUNCTION
    BTFSC   PB_FLAG, 3		; If set, enable decrement of display value
    CALL    DISPLAY_DEC		
    BTFSS   PB_FLAG, 3		; If clear, enable stop action for TMR
    CALL    FUNC_STOP
    RETURN
    
SET_EDIT_MODE:			; SET FLAG VALUES TO USE EDIT MODE
    
    ; Pushbutton flags
    BSF	    PB_FLAG, 1		; Enable display navigation
    BSF	    PB_FLAG, 2		; Enable display value increment
    BSF	    PB_FLAG, 3		; Enable display value decrement
    
    ; Mode enables
    BSF	    MODE_EN, 4		; Enable edit mode for functions
    
    RETURN
    
SET_NORMAL_MODE:		; CLEAR FLAG VALUES TO USE NORMAL MODE
    
    ; Pushbutton flags
    BCF	    PB_FLAG, 1		; Enable function navigation
    BCF	    PB_FLAG, 2		; Enable TMR and ALRM start function
    BCF	    PB_FLAG, 3		; Enable TMR and ALRM stop function
    
    ; Mode enables
    BCF	    MODE_EN, 4		; Disable edit mode for functions
    
    RETURN
    
NAV_FUNCTIONS:			; NAVIGATE FUNCTIONS (IN NORMAL MODE)
    RLF	    MODE_EN		; Disable current function, enable next one
    BTFSS   MODE_EN, 3		; End subroutine if 0 (not in the last function)
    RETURN			
    BCF	    MODE_EN, 3		; Disable current function (last function)
    BSF	    MODE_EN, 0		; Enable first function again
    
    RETURN
    
NAV_DISPLAYS:			; NAVIGATE DISPLAYS (IN EDIT MODE)
    RLF	    DISPLAY_EN		; Disable current display, enable next display
    BTFSS   DISPLAY_EN, 3	; End subroutine if 0 (not in display 3)
    RETURN
    BCF	    DISPLAY_EN, 3	; Disable current display (display 3)
    BSF	    DISPLAY_EN, 0	; Enable display 0 again
    
    RETURN
    
DISPLAY_INC:
    
    RETURN
    
FUNC_START:
    
    RETURN
    
FUNC_STOP:
    
    RETURN
    
DISPLAY_DEC:
    
    RETURN
    
;-------------------- CONTROL SUBROUTINES --------------------

RESET_CLK:			; RESET HRS, MINUTES AND SECONDS OF CLOCK
    RESET_COUNT	CLK_HRS, 23	; Reset hours at 24 (Count goes 0-23)
    RESET_COUNT CLK_MIN, 59	; Reset minutes at 60 (Count goes 0-59)
    RESET_COUNT CLK_SEC, 59	; Reset seconds at 60 (Count goes 0-59)
    RETURN
    
;-------------------- OUTPUT SUBROUTINES --------------------
       
SET_LEDS:			; PREPARE VALUES FOR LEDS
    MOVF    MODE_EN, W		; Move function enables to W.
    ANDLW   0X3F		; 0011 1111: Bits 0-5 are LEDs, avoid the rest.
    MOVWF   PORTA		; Send value to PORTA for updating all LEDs
   
    RETURN
    
SET_DISPLAYS:			; PREPARE VALUES FOR DISPLAYS
    
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
    
SET_DOTS:			; SET VALUES FOR CENTRAL DOTS
    MOVF    DOTS, W		; Move DOTS value to W
    MOVWF   PORTC		; Move W to PORTC
    RETURN
    
SELECT_DISPLAY:			; UPDATE DISPLAY SELECTORS
    MOVF    DISPLAY_EN, W	; Move Display (and Dots) enables to W
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
    RETURN
    
END