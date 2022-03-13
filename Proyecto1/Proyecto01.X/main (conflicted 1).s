;   ARCHIVO:		main.s
;   DISPOSITIVO:	PIC16F887
;   AUTOR:		Andrea Barrientos Pineda (Carnet: 20575)
;   COMPILADOR:		pic-as (v2.32), MPLABX v6.00
;
;   CREADO:		05/03/2022
;   MODIFICADO:		12/03/2022
;
;   PROGRAMA:		Proyecto 1: Reloj digital
;   HARDWARE:
;
;	- DISPOSITIVO: PIC16F887
;
;	- ENTRADAS:
;	    - Pushbutton 01 - Modo de edicion		    (PORTB: RB7)
;	    - Pushbutton 02 - Funcion/Display		    (PORTB: RB2)
;	    - Pushbutton 03 - Incrementar/iniciar	    (PORTB: RB1)
;	    - Pushbutton 04 - Decrementar/detener	    (PORTB: RD6)
;
;	- SALIDAS:
;	    - LEDs (x4)	    - Indicadores de función	    (PORTA: RA0-RA3)
;	    - LEDs (x1)     - Indicador de edición          (PORTA: RA5)
;	    - LEDs (x1)	    - Alarma			    (PORTA: RA6)
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
    
RESET_COUNT MACRO VALUE, LIMIT	; CHECK IF VALUE REACHED COUNTER LIMIT
    MOVF    VALUE, W		; Move selected value to W
    SUBLW   LIMIT		; Substract LIMIT
    ENDM
    
PUSHBUTTON MACRO PORT, BIT	; MACRO FOR ALL PUSHBUTTONS
    BANKSEL TRISA		; Move to bank 0
    BTFSC   PORT, BIT		; Check if pushbutton was pressed
    BTFSC   PORT, BIT		; Keep checking until pushbutton is not pressed
    GOTO    $-1
    ENDM
    
INVERT_FLAG MACRO FLAG, HEX_VAL	; MACRO FOR SETTING/CLEARING FLAGS
    MOVF    FLAG, W		; Move flag to W
    XORLW   HEX_VAL		; Invert selected bits with a XOR
    MOVWF   FLAG		; Return value to flag register
    ENDM

;-------------------- VARIABLES --------------------

PSECT udata_shr			; INTERRUPTION VARIABLES
    W_TEMP:	    DS 1	; Temporal W
    STATUS_TEMP:    DS 1	; Temporal STATUS
    
PSECT udata_bank0		; PROGRAM VARIABLES
    
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
    
    MODE_EN:	    DS 1	; MODE/FUNCTION ENABLES
    
		    ; Bits	  | 7  | 6  | 5  | 4  | 3  | 2  | 1  | 0  |
		    ; Content	  |    |EN_2|EN_1|EDIT|ALRM|TMR |DATE|CLK |
		    
		    ; 0-3: Function        (Only one can be enabled at a time)
		    ; 4	 : Edit mode	   (1: enabled, 0: disabled).
		    ; 5  : Control Timer    (1: start, 0: stop)
		    ; 6  : Control Alarm    (1: start, 0: stop)
		    
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
		    
    LED_FLAG:	    DS 1	; LED FLAGS: INDICATE WHICH IF ON OR OFF
		    
		    ; Bits	  | 7  | 6  | 5      | 4  | 3  | 2  | 1  | 0  |
		    ; Content	  |    |    |ALRM_LED|EDIT|ALRM|TMR |DATE|CLK |
		    
		    ; 0-3: Indicator LEDs for clock, date, timer and alarm.
		    ; 4  : Edit mode LED indicator.
		    ; 5  : LED to indicate the alarm is activated.
		    
		    ; In all cases: 1 is on, and 0 is off.
		    
    EN_TEMP:	    DS 1	; TEMPORAL REGISTER FOR ENABLE REGISTERS
    DISP_TEMP:	    DS 1	; TEMPORAL REGISTER FOR DISPLAY VALUES
    
    UPPER_LIMIT:    DS 1	; VARIABLE FOR HIGHEST VALUE OF A DISPLAY
    LOWER_LIMIT:    DS 1	; VARIABLE FOR LOWEST VALUE OF A DISPLAY
				
PSECT resVect, class=CODE, abs, delta=2
ORG 00h				; Posicionn 0000h: Vector Reset
    
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
    BTFSC   T0IF		; Check TMR0 interruption flag
    CALL    INT_TMR0		; Execute TMR0 interruption on T0IF = 1
    
POP:				; RECOVER W AND STATUS VALUES
    SWAPF   STATUS_TEMP, W	; Swap STATUS_TEMP, save in W
    MOVWF   STATUS		; Move W to STATUS
    SWAPF   W_TEMP, F		; Swap W_TEMP, save in register F
    SWAPF   W_TEMP, W		; Swap W_TEMP again, save in W
    RETFIE			; End interruptions
    
;-------------------- SUBRUTINAS DE INTERRUPCION --------------------
    
INT_TMR0:			; TMR0 INTERRUPTION
    RESET_TMR0			; Reset TMR0
    RETURN
    
PSECT code, delta=2, abs
ORG 100h			; Posicion 0100h: tables and main
 
DISPLAY_TABLE:			; 7Seg Display values table
    
    ; Config:
    CLRF    PCLATH		; Limpiar PCLATH
    BSF     PCLATH, 0		; Activar PCLATH, Bit 0
    ANDLW   0x0F		; Convertir W a 4 Bits
    ADDWF   PCL, F		; Sumar PCL a W, guardar en F
    
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
    CALL    CONFIG_INT		; Interruptions config
    
    BANKSEL PORTA		; Bank 0
    
LOOP:				; MAIN LOOP
    BSF	    PB_FLAG, 0
    CALL    SET_LEDS
    GOTO    LOOP
    
;-------------------- CONFIGURATION SUBROUTINES --------------------

CONFIG_IO:			; I/O CONFIG
    
    BANKSEL ANSEL		; Bank 3
    CLRF    ANSEL		; Digital I/O
    CLRF    ANSELH		; Digital I/O
    
    
    BANKSEL TRISA		; Bank 1
    
    ; Input ports:
    BSF	    TRISB, 7		; RB7 - Pushbutton 0 (Edit mode)
    BSF	    TRISB, 2		; RB2 - Pushbutton 1 (Functions)
    BSF	    TRISB, 1		; RB1 - Pushbutton 2 (Increment/start)
    BSF	    TRISD, 6		; RD6 - Pushbutton 3 (Decrement/stop)
    
    ; Output ports:
    BCF	    TRISA, 0		; RA0 - LED hour function
    BCF	    TRISA, 1		; RA1 - LED date function
    BCF	    TRISA, 2		; RA2 - LED timer function
    BCF	    TRISA, 3		; RA3 - LED alarm function
    BCF	    TRISA, 5		; RA5 - LED alarm set
    BCF	    TRISA, 6		; RA6 - LED edit mode indicator
    
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
    
    RETURN
    
CONFIG_CLOCK:			; OSCILATOR CONFIGURATION
   
    BANKSEL OSCCON		; Bank 2
    BSF	    OSCCON, 0		; Enable internal clock
    BSF	    OSCCON, 6		; 0
    BCF	    OSCCON, 5		; 1	   -> Freq: 1MHz
    BCF	    OSCCON, 4		; 1
    
    RETURN
    
CONFIG_TMR0:			; TMR0 CONFIGURATION
    
    BANKSEL OPTION_REG		; Bank 0
    BCF	    T0CS		; Clean T0CS
    BCF	    PSA			; Enable counter
    BSF	    PS2			; 1
    BSF	    PS1			; 1	    -> Prescaler 1:256
    BSF	    PS0			; 1
    
    RETURN
    
CONFIG_INT:			; INTERRUPTIONS CONFIGURATION
   
    BANKSEL INTCON		; Bank 0
    BSF	    GIE			; Enable global interruptions
    BSF	    PEIE		; Enable periferic interruptions
    BCF	    T0IF		; Clean TMR0 interruption flag
    BSF	    T0IE		; Enable TMR0 interruptions
   
    RETURN

;-------------------- INPUT SUBROUTINES --------------------
    
PB0:				; ACTIVATE/DESACTIVATE EDITION MODE
    PUSHBUTTON	PORTB, 7	; Check pushbutton 0
    INVERT_FLAG PB_FLAG, 0X01	; Invert PB_FLAG, 0
    RETURN
    
PB1:				; NAVIGATE DISPLAYS/FUNCTIONS
    
    RETURN
    
PB2:				; Pushbutton 2: Increment/Start
    RETURN
    
PB3:				; Pushbutton 3: Decrement/Stop
    RETURN
    
;-------------------- CONTROL SUBROUTINES --------------------

CHECK_EDIT_MODE:		; CHECK IF EDIT MODE IS ACTIVATED/DESACTIVATED
    BTFSC   PB_FLAG, 0		; If set, call 
    CALL    ENABLE_EDIT_MODE	; Setup edit mode
    BTFSS   PB_FLAG, 0		; If clear, call S2
    CALL    ENABLE_NORMAL_MODE	; Setup normal use
    
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
    
;-------------------- FUNCTION SUBROUTINES --------------------

    
;-------------------- OUTPUT SUBROUTINES --------------------
    
SET_LEDS:
    
    BTFSC   PB_FLAG, 0
    BSF	    PORTA, 0
    RETURN
    
END