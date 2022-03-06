;   ARCHIVO:		main.s
;   DISPOSITIVO:	PIC16F887
;   AUTOR:		Andrea Barrientos Pineda (Carnet: 20575)
;   COMPILADOR:		pic-as (v2.32), MPLABX v6.00
;
;   CREADO:		05/03/2022
;   MODIFICADO:		05/03/2022
;
;   PROGRAMA:		Proyecto 1: Reloj digital
;   HARDWARE:
;
;	- DISPOSITIVO: PIC16F887
;
;	- ENTRADAS:
;	    - Pushbutton 01 - Modo de edicion		    (PORTB: RB0)
;	    - Pushbutton 02 - Navegacion		    (PORTB: RB1)
;	    - Pushbutton 03 - Incrementar/iniciar	    (PORTB: RB2)
;	    - Pushbutton 04 - Decrementar/detener	    (PORTB: RB3)
;
;	- SALIDAS:
;	    - LEDs (x6) - Alarma			    (PORTE: RA0-RA5)
;	    - Display (7seg, 4digits) - Pantalla de reloj
;	      (displays 0-3 de izquierda a derecha)
;		- Segmentos de displays			    (PORTC: RC0-RC7)
;		- Selectores de displays		    (PORTD: RD0-RD4)
;		- Segmento de puntos centrales		    (PORTD: RD5)
; 
;   VARIABLES:
;	- Funciones del reloj:
;	    - Hora:		    CLK_
;	    - Fecha:		    DATE_
;	    - Timer:		    TMR_
;	    - Alarma:		    ALRM_
;	- Programa:
;	    - Variable temporal:    _TEMP

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
    BANKSEL TMR0		; Banco 0
    MOVLW   255			; Tiempo de interrupción
    MOVWF   TMR0		; Ingresar tiempo de interrupción
    BCF	    T0IF		; Limpiar bandera de interrupciones
    ENDM

;-------------------- VARIABLES --------------------

PSECT udata_shr			; Variables de interrupciones
    W_TEMP:	    DS 1	; Registro temporal para W
    STATUS_TEMP:    DS 1	; Registro temporal para STATUS
    
PSECT udata_bank0		; Variables del programa
    
    ; Variables: Función 01 - Hora/Reloj			(CLK)
    CLK_HRS:	    DS 1	; Hora actual
    CLK_MIN:	    DS 1	; Minutos de la hora actual
    CLK_SEC:	    DS 1	; Segundos de la hora actual
    
    ; Variables: Función 02 - Fecha				(DATE)
    DATE_MON:	    DS 1	; Mes actual
    DATE_DAY:	    DS 1	; Día actual
    
    ; Variables: Función 03 - Timer				(TMR)
    TMR_MIN:	    DS 1	; Minutos en el timer
    TMR_SEC:	    DS 1	; Minutor en el timer
    
    ; Variables: Función 04 - Alarma				(ALRM)
    ALRM_HRS:	    DS 1	; Hora de la alarma
    ALRM_MIN:	    DS 1	; Minutos de la alarma
    
    ; Variables: Display de 7seg, 4digitos, puntos centrales	(DISP_X, DOTS)
    DISP_0_VAR:	    DS 1	; Valor del display 0
    DISP_1_VAR:	    DS 1	; Valor del display 1
    DISP_2_VAR:	    DS 1	; Valor del display 2
    DISP_3_VAR:	    DS 1	; Valor del display 3
    DOTS_VAR:	    DS 1	; Valor de los puntos centrales en el display
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h				; Posición 0000h: Vector Reset
    
;-------------------- VECTOR RESET --------------------

resetVec:
    PAGESEL MAIN
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h				; Posición 0004h: Interrupcinoes
    
;-------------------- INTERRUPTIONS --------------------
    
PUSH:				
    MOVWF   W_TEMP		; Mover W a W_TEMP
    SWAPF   STATUS, W		; Swap en STATUS, guardar en W
    MOVWF   STATUS_TEMP		; Mover W (STATUS con swap) a STATUS_TEMP
    
ISR:
    BTFSC   T0IF		; Revisar bandera de interrupción TMR0
    CALL    INT_TMR0		; T0IF = 1: Ejecutar interrupción TMR0
    
POP:
    SWAPF   STATUS_TEMP, W	; Swap en STATUS_TEMP, guardar en W
    MOVWF   STATUS		; Mover W (STATUS_TEMP con swap) a STATUS
    SWAPF   W_TEMP, F		; Swap en W_TEMP, guardar en F
    SWAPF   W_TEMP, W		; Swap en W_TEMP, guardar en W
    RETFIE
    
;-------------------- SUBRUTINAS DE INTERRUPCION --------------------
    
INT_TMR0:			; Interrupción TMR0
    RESET_TMR0			; Reiniciar TMR0
    RETURN
    
PSECT code, delta=2, abs
ORG 100h
 
DISPLAY_TABLE:			; Tabla de valores - Displays de 7 segmentos
    
    ; Configuración:
    CLRF    PCLATH		; Limpiar PCLATH
    BSF     PCLATH, 0		; Activar PCLATH, Bit 0
    ANDLW   0x0F		; Convertir W a 4 Bits
    ADDWF   PCL, F		; Sumar PCL a W, guardar en F
    
    ; Tabla:
    ;	    PINES		CARÁCTERES
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
MAIN:
    CALL    CONFIG_IO		; Configuración I/O
    CALL    CONFIG_CLOCK	; Configuración del Oscilador
    CALL    CONFIG_TMR0		; Configuración del TMR0
    CALL    CONFIG_INT		; Configuración de interrupciones
    
    BANKSEL PORTA		; Banco 0
    
LOOP:
    GOTO    LOOP
    
;-------------------- CONFIGURATION SUBROUTINES --------------------

CONFIG_IO:			; Configuración I/O
    
    ; Tipo de entradas y salidas
    BANKSEL ANSEL		; Banco 3
    CLRF    ANSEL		; I/O digitales
    CLRF    ANSELH		; I/O digitales
    
    ; Puertos de entrada y salida
    BANKSEL TRISA		; Banco 1
    
    BCF	    TRISB, 0		; PORTB, Bit 0: Salida - Pb 0 (Modo)
    BCF	    TRISB, 1		; PORTB, Bit 1: Salida - Pb 1 (Edición)
    BCF	    TRISB, 2		; PORTB, Bit 2: Salida - Pb 2 (Aumento/activar)
    BCF	    TRISB, 3		; PORTB, Bit 3: Salida - Pb 3 (Reducir/detener)
    
    CLRF    TRISC		; PORTC:	Salida - Segmentos de displays
    
    BCF	    TRISD, 0		; PORTD, Bit 0: Salida - Selector DISP_0
    BCF	    TRISD, 1		; PORTD, Bit 1: Salida - Selector DISP_1
    BCF	    TRISD, 2		; PORTD, Bit 2:	Salida - Selector DISP_2
    BCF	    TRISD, 3		; PORTD, Bit 3:	Salida - Selector DISP_3
    BCF	    TRISD, 4		; PORTD, Bit 4: Salida - Selector DOTS
    
    ; Limpiar puertos a utilizar
    BANKSEL PORTA		; Banco 0
    CLRF    PORTB		; Limpiar PORTB
    CLRF    PORTC		; Limpiar PORTC
    CLRF    PORTD		; Limpiar PORTD
    
    RETURN
    
CONFIG_CLOCK:			; Configuración del Oscilador
   
    BANKSEL OSCCON		; Banco 1
    BSF	    OSCCON, 0		; Activar reloj interno
    BSF	    OSCCON, 6		; 0
    BCF	    OSCCON, 5		; 1	   -> Frecuencia: 1MHz
    BCF	    OSCCON, 4		; 1
    
    RETURN
    
CONFIG_TMR0:			; Configuración del TMR0
    
    BANKSEL OPTION_REG		; Banco 0
    BCF	    T0CS		; Limpiar registro T0CS
    BCF	    PSA			; Modo contador
    BSF	    PS2			; 1
    BSF	    PS1			; 1	    -> Prescaler 1:256
    BSF	    PS0			; 1
    
    RETURN
    
CONFIG_INT:			; Configuración de interrupciones
   
    BANKSEL INTCON		; Banco 0
    BSF	    GIE			; Enable interrupciones globales
    BSF	    PEIE		; Enable interrupciones periféricas
    BCF	    T0IF		; Limpiar bandera de interrupciones TMR0
    BSF	    T0IE		; Enable interrupciones TMR0
   
    RETURN


    
END
