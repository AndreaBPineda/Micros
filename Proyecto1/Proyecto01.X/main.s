;   ARCHIVO:		main.s
;   DISPOSITIVO:	PIC16F887
;   AUTOR:		Andrea Barrientos Pineda (Carnet: 20575)
;   COMPILADOR:		pic-as (v2.32), MPLABX v6.00
;
;   CREADO:		05/03/2022
;   MODIFICADO:		14/03/2022
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

;-------------------- DISPOSITIVO Y LIBRERIAS --------------------
PROCESSOR 16F887
#include <xc.inc>
    
;-------------------- CONFIG 1 --------------------
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
    
;-------------------- CONFIG 2 --------------------
CONFIG WRT=OFF
CONFIG BOR4V=BOR40V
    
;-------------------- MACROS --------------------    
RESET_TMR0 MACRO		; RESET TMR0
    BANKSEL TMR0		; Bank 0
    MOVLW   255			; Interruption time
    MOVWF   TMR0		; Set interruption time in TMR0
    BCF	    T0IF		; Clear interruption flag TMR0
    ENDM
    
RESET_COUNT MACRO COUNTER, LIMIT
    MOVF    COUNTER, W		; Move counter reg to W
    SUBLW   LIMIT		; Subtract Limit (N-1), for a desired value N.
    BTFSS   STATUS, 0		; If W > LIMIT, clear counter
    CLRF    COUNTER		; Clear counter reg
    ENDM

;-------------------- VARIABLES --------------------

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
    
		    ; Bits	  | 7  | 6  | 5     | 4  | 3  | 2  | 1  | 0  |
		    ; Content	  |EN_2|EN_1|ALRM_ON|EDIT|ALRM|TMR |DATE|CLK |
		    
		    ; 0-3: Function (Only one set at a time)
		    ; 4	 : Edit mode
			; 1: enabled
			; 0: disabled
		    ; 5  : Control Timer
			; 1: start
			; 0: stop
		    ; 6  : Control Alarm
			; 1: start
			; 0: stop
		    ; 7  : Active alarm indicator
			; 0: alarm off
			; Blinking: alarm on
		    
    DISPLAY_EN:     DS 1	; DISPLAY ENABLES: SELECTOR FOR DISPLAYS
		    
		    ; Bits	  | 7  | 6  | 5  | 4  | 3  | 2  | 1  | 0  |
		    ; Content	  |    |    |    |DOTS|D3  |D2  |D1  |D0  |
		    
		    ; 0-3: Enable Display 1-4, respectively
		    ; 4  : Enable center dots of the display module.
    
		    ; In all cases: 1 is on, and 0 is off.
		    
		    
    PB_FLAG:	    DS 1	; PUSHBUTTON FLAGS: INDICATE ACTION TO DO
		    
		    ; Bits	  | 7  | 6  | 5  | 4  | 3  | 2  | 1  | 0  |
		    ; Content	  |    |    |    |    |PB3 |PB2 |PB1 |PB0 |
		    
		    ; 0: Edition
			; 1: Edition mode activated
			; 0: Edition mode desactivated
		    ; 1: Function
			; 1: Navigate functions: CLK, DATE, TMR and ALRM
			; 0: Navigate displays: 1-4
		    ; 2: Action 1
			; 1: Increment current display value
			; 0: Start TMR or ALRM (whichever is currently selected)
		    ; 3: Action 2
			; 1: Decrement current display value
			; 0: Stop TMR or ALRM (whichever is currently selected)
				
PSECT resVect, class=CODE, abs, delta=2
ORG 00h				; Posicion 0000h: Vector Reset
    
;-------------------- VECTOR RESET --------------------

resetVec:
    PAGESEL MAIN
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h				; Posicion 0004h: Interruptions
    
;-------------------- INTERRUPTIONS --------------------
    
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
    
;-------------------- SUBRUTINAS DE INTERRUPCION --------------------
    
INT_TMR0:			; TMR0 INTERRUPTIONS: CONTROL AND OUTPUTS
    
    RESET_TMR0			; Reset TMR0
    
    ; Check values of enables and flags
    CALL    CHECK_EDIT_MODE	; Check status of edit mode (active/disabled)
    
    ; Set output values
    CALL    SET_LEDS		; Set values of all LEDs
    
    RETURN
    
INT_PORTB:			; PORTB INTERRUPTION: INPUT SUBROUTINES
    
    ; Pushbutton 0: Edition mode control
    
    BTFSC   PORTB, 0		; Check pushbutton 0
    RETURN			; If not pressed, end interruption
    MOVF    PB_FLAG, W		; If pressed, invert value of flag
    XORLW   0X01		
    MOVWF   PB_FLAG
    
    ; Pushbutton 1: Navigation of functions/displays
    
    ; Aquí empieza la buggeación :v
    ; Al llamar el pushbutton 1, enloquece el led del pushbutton 0.
    ;BTFSC   PORTB, 1		; Check pushbutton 1
    ;RETURN			; If not pressed, end interruption
    ;BTFSC   PB_FLAG, 1		; Check action flag, if 1, navigate displays.
    ;CALL    NAV_DISPLAYS	
    ;BTFSS   PB_FLAG, 1		; Check action flag, if 0, navigate functions.
    ;CALL    NAV_FUNCTIONS	
    
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
    
    ; Input ports:
    BSF	    TRISB, 0		; RB0 - Pushbutton 0 (Edit mode)
    BSF	    TRISB, 1		; RB1 - Pushbutton 1 (Functions)
    BSF	    TRISB, 2		; RB2 - Pushbutton 2 (Increment/start)
    BSF	    TRISB, 3		; RD3 - Pushbutton 3 (Decrement/stop)
    
    ; Output ports:
    BCF	    TRISA, 0		; RA0 - LED hour function
    BCF	    TRISA, 1		; RA1 - LED date function
    BCF	    TRISA, 2		; RA2 - LED timer function
    BCF	    TRISA, 3		; RA3 - LED alarm function
    BCF	    TRISA, 4		; RA5 - LED alarm set
    BCF	    TRISA, 5		; RA6 - LED edit mode indicator
    
    CLRF    TRISC		; PORTC - Display segments
    
    BCF	    TRISD, 0		; RD0 - Display 0 selector
    BCF	    TRISD, 1		; RD1 - Display 1 selector
    BCF	    TRISD, 2		; RD2 - Display 2 selector
    BCF	    TRISD, 3		; RD3 - Display 3 selector
    BCF	    TRISD, 4		; RD4 - Central dots selector
    
    ; Clean ports:
    BANKSEL PORTA		; Bank 0
    CLRF    PORTA		
    CLRF    PORTB		
    CLRF    PORTC		
    CLRF    PORTD
    
    ; Clean registers:
    CLRF    PB_FLAG
    CLRF    MODE_EN
    CLRF    DISP_0
    CLRF    DISP_1
    CLRF    DISP_2
    CLRF    DISP_3
    CLRF    DOTS
    
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
    BSF	    IOCB, 0
    BSF	    IOCB, 1
    BSF	    IOCB, 2
    BSF	    IOCB, 3
    
    ; Enable weak pull-up
    BSF	    WPUB, 0
    BSF	    WPUB, 1
    BSF	    WPUB, 2
    BSF	    WPUB, 3
    
    BCF	    OPTION_REG, 7	; Enable PORTB internal pull-ups
    
    BANKSEL PORTA
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
    
;-------------------- CONTROL SUBROUTINES --------------------

CHECK_EDIT_MODE:		; CHECK IF EDIT MODE IS ACTIVATED/DESACTIVATED
    BTFSC   PB_FLAG, 0		; If set, activate edit mode
    CALL    ENABLE_EDIT_MODE
    BTFSS   PB_FLAG, 0		; If clear, activate normal mode
    CALL    ENABLE_NORMAL_MODE
    RETURN
    
ENABLE_EDIT_MODE:		; SET FLAG VALUES TO USE EDIT MODE
    BSF	    PB_FLAG, 1		; Enable display navigation
    BSF	    PB_FLAG, 2		; Enable display value increment
    BSF	    PB_FLAG, 3		; Enable display value decrement
    BSF	    MODE_EN, 4		; Enable edit mode for functions
    RETURN
    
ENABLE_NORMAL_MODE:		; CLEAR FLAG VALUES TO USE NORMAL MODE
    BCF	    PB_FLAG, 1		; Enable function navigation
    BCF	    PB_FLAG, 2		; Enable TMR and ALRM start function
    BCF	    PB_FLAG, 3		; Enable TMR and ALRM stop function
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
    
;-------------------- CONTROL SUBROUTINES --------------------

RESET_CLK:			; RESET HRS, MINUTES AND SECONDS OF CLOCK
    RESET_COUNT	CLK_HRS, 23	; Reset hours at 24 (Count goes 0-23)
    RESET_COUNT CLK_MIN, 59	; Reset minutes at 60 (Count goes 0-59)
    RESET_COUNT CLK_SEC, 59	; Reset seconds at 60 (Count goes 0-59)
    RETURN
    
;RESET_DATE:			; RESET DAYS AND MONTHS OF DATE
    ; PENDIENTE
    ;RETURN

;RESET_TMR:			; RESET HRS, MINUTES AND SECONDS OF CLOCK
    ;RETURN
    
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