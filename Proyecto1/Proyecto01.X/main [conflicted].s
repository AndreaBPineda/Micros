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
;	    - Pushbutton 01 - Modo de edicion		    (PORTB: RB7)
;	    - Pushbutton 02 - Navegacion		    (PORTB: RB2)
;	    - Pushbutton 03 - Incrementar/iniciar	    (PORTB: RB1)
;	    - Pushbutton 04 - Decrementar/detener	    (PORTB: RD6)
;
;	- SALIDAS:
;	    - LEDs (x4)	    - Indicadores de función	    (PORTA: RA0-RA3)
;	    - LEDs (x2)	    - Alarma			    (PORTA: RA5-RA6)
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
    
    ; Hora/Reloj
    CLK_HRS:	    DS 1	; Hora actual
    CLK_MIN:	    DS 1	; Minutos de la hora actual
    CLK_SEC:	    DS 1	; Segundos de la hora actual
    
    ; Fecha
    DATE_MON:	    DS 1	; Mes actual
    DATE_DAY:	    DS 1	; Día actual
    
    ; Timer
    TMR_MIN:	    DS 1	; Minutos en el timer
    TMR_SEC:	    DS 1	; Minutor en el timer
    
    ; Alarma
    ALRM_HRS:	    DS 1	; Hora de la alarma
    ALRM_MIN:	    DS 1	; Minutos de la alarma
    
    ; Control de funciones 
    MODE_FLAG:	    DS 1	; Banderas de modo (1: activo, 0: desactivado)
				; Bit 0: hora/reloj
				; Bit 1: fecha
				; Bit 2: timer
				; Bit 3: alarma
				
    EDITION_FLAG:   DS 1	
    
    ; Display de 7 segmentos y 4 digitos
    DISP_0:	    DS 1	; Valor del display 0
    DISP_1:	    DS 1	; Valor del display 1
    DISP_2:	    DS 1	; Valor del display 2
    DISP_3:	    DS 1	; Valor del display 3
    DISP_FLAG:	    DS 1	; Bandera de display activo
    DOTS_VAR:	    DS 1	; Valor de los puntos centrales en el display
    
    ; Pushbuttons
    PB_FLAG:	    DS 1	; Banderas de pushbuttons
				; Bit 0: Pushbutton 0 -> 1: edición, 0: no
				; Bit 1: Pushbutton 1 -> 1: display, 0: función
				; Bit 2: Pushbutton 2 -> 1: incf,    0: iniciar
				; Bit 3: Pushbutton 3 -> 1: decf,    0: detener
				
    ; *NOTA: Si el modo no está en timer/alarma, no se realiza ninguna acción.
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h				; Posición 0000h: Vector Reset
    
;-------------------- VECTOR RESET --------------------

resetVec:
    PAGESEL MAIN
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h				; Posición 0004h: Interrupcinoes
    
;-------------------- INTERRUPTIONS --------------------
    
PUSH:				; Respaldar valor de W y STATUS		
    MOVWF   W_TEMP		; Mover W a W_TEMP
    SWAPF   STATUS, W		; Swap en STATUS, guardar en W
    MOVWF   STATUS_TEMP		; Mover W (STATUS con swap) a STATUS_TEMP
    
ISR:				; Ejecutar interrupciones
    BTFSC   T0IF		; Revisar bandera de interrupción TMR0
    CALL    INT_TMR0		; T0IF = 1: Ejecutar interrupción TMR0
    
POP:				; Recuperar valores de W y STATUS
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
    
    ; Tabla de valores:
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
MAIN:				; Setup del programa
    CALL    CONFIG_IO		; Configuración I/O
    CALL    CONFIG_CLOCK	; Configuración del Oscilador
    CALL    CONFIG_TMR0		; Configuración del TMR0
    CALL    CONFIG_INT		; Configuración de interrupciones
    
    BANKSEL PORTA		; Banco 0
    
LOOP:				; Ciclo principal del programa
    GOTO    LOOP
    
;-------------------- CONFIGURATION SUBROUTINES --------------------

CONFIG_IO:			; Configuración I/O
    
    ; Tipo de entradas y salidas
    BANKSEL ANSEL		; Banco 3
    CLRF    ANSEL		; I/O digitales
    CLRF    ANSELH		; I/O digitales
    
    ; Puertos de entrada y salida
    BANKSEL TRISA		; Banco 1
    
    BCF	    TRISA, 0		; PORTA, Bit 0: Salida - LED indicador: hora
    BCF	    TRISA, 1		; PORTA, Bit 1: Salida - LED indicador: fecha
    BCF	    TRISA, 2		; PORTA, Bit 2: Salida - LED indicador: timer
    BCF	    TRISA, 3		; PORTA, Bit 3: Salida - LED indicador: alarma
    BCF	    TRISA, 5		; PORTA, Bit 5: Salida - LED 0 de alarma
    BCF	    TRISA, 6		; PORTA, Bit 6: Salida - LED 1 de alarma
    
    BCF	    TRISB, 0		; PORTB, Bit 0: Salida - Pushbutton 0 (Editar)
    BCF	    TRISB, 1		; PORTB, Bit 1: Salida - Pushbutton 1 (Modo)
    BCF	    TRISB, 2		; PORTB, Bit 2: Salida - Pushbutton 2 (Acción 1)
    BCF	    TRISB, 3		; PORTB, Bit 3: Salida - Pushbutton 3 (Acción 2)
    
    CLRF    TRISC		; PORTC:	Salida - Segmentos de displays
    
    BCF	    TRISD, 0		; PORTD, Bit 0: Salida - Selector DISP_0
    BCF	    TRISD, 1		; PORTD, Bit 1: Salida - Selector DISP_1
    BCF	    TRISD, 2		; PORTD, Bit 2:	Salida - Selector DISP_2
    BCF	    TRISD, 3		; PORTD, Bit 3:	Salida - Selector DISP_3
    BCF	    TRISD, 4		; PORTD, Bit 4: Salida - Selector DOTS
    
    ; Limpiar puertos a utilizar
    BANKSEL PORTA		; Banco 0
    CLRF    PORTA		; Limpiar PORTA
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
    BSF	    GIE			; Habilitar interrupciones globales
    BSF	    PEIE		; Habilitar interrupciones periféricas
    BCF	    T0IF		; Limpiar bandera de interrupciones TMR0
    BSF	    T0IE		; Habilitar interrupciones TMR0
   
    RETURN

;-------------------- INPUT SUBROUTINES --------------------
    
PB0:				; Pushbutton 0: Edición
    ; IF, pushbutton oprimido:
    ; invertir valor de PB_FLAG 0
    RETURN
    
PB1:				; Pushbutton 1: Modo
    ; IF, pushbutton oprimido:
    ; aumentar selector de display/funcion
    RETURN
    
PB2:				; Pushbutton 2: Acción 1
    ; 
    RETURN
    
PB3:				; Pushbutton 3: Acción 2
    
    RETURN
    
;-------------------- CONTROL/STATE SUBROUTINES --------------------

S0:				; Estado inicial: Revisar modo edición
    BTFSC   PB_FLAG, 0		; Revisar bandera del pushbutton 0
    CALL    S1			; Si PB0_FLAG = 1: activar modo de edición
    BTFSS   PB_FLAG, 0		; Revisar bandera del pushbutton 0
    CALL    S2			; Si PB0_FLAG = 0: desactivar modo de edición
    RETURN
    
S1:				; Estado 1: Modo de edición activado
    BSF	    PB_FLAG, 1		; Pushbutton 2, modo: navegar entre displays
    BSF	    PB_FLAG, 2		; Pushbutton 3, acción: incrementar display
    BSF	    PB_FLAG, 3		; Pushbutton 4, acción: decrementar display
    RETURN
    
S2:				; Estado 2: Modo de edición desactivado
    BCF	    PB_FLAG, 1		; Pushbutton 2, modo: navegar entre funciones
    BCF	    PB_FLAG, 2		; Pushbutton 3, acción: activar timer/alarma
    BCF	    PB_FLAG, 3		; Pushbutton 4, acción: desactivar timer/alarma
    RETURN
    
;-------------------- FUNCTION SUBROUTINES --------------------
    
CLK:				; Función 1: Hora/Reloj
    BTFSS   MODE_FLAG, 0	; Revisar la bandera de función
    RETURN
    ;...
    ;RETURN  
DATE:				; Función 2: Fecha
    BTFSS   MODE_FLAG, 1	; Revisar la bandera de función
    RETURN
    ;...
    ;RETURN
TMR:				; Función 3: Timer
    BTFSS   MODE_FLAG, 2	; Revisar la bandera de función
    RETURN
    ;...
    ;RETURN
ALRM:				; Función 4: Alarma
    BTFSS   MODE_FLAG, 3	; Revisar la bandera de función
    RETURN
    ;...
    ;RETURN
    
;-------------------- OUTPUT SUBROUTINES --------------------

SET_DISPLAYS:			; Definir valores para cada display
    
    ; Valor del Display 0
    MOVF    DISP_0, W		; Mover valor de la variable a W
    CALL    DISPLAY_TABLE	; Convertir W a carácter a desplegar
    MOVWF   DISP_0		; Mover de regreso el valor a la variable
    
    ; Valor del Display 1
    MOVF    DISP_1, W		; Mover valor de la variable a W
    CALL    DISPLAY_TABLE	; Convertir W a carácter a desplegar
    MOVWF   DISP_1		; Mover de regreso el valor a la variable
    
    ; Valor del Display 2
    MOVF    DISP_2, W		; Mover valor de la variable a W
    CALL    DISPLAY_TABLE	; Convertir W a carácter a desplegar
    MOVWF   DISP_2		; Mover de regreso el valor a la variable
    
    ; Valor del Display 3
    MOVF    DISP_3, W		; Mover valor de la variable a W
    CALL    DISPLAY_TABLE	; Convertir W a carácter a desplegar
    MOVWF   DISP_3		; Mover de regreso el valor a la variable
    
    RETURN
    
ACTIVE_DISPLAY:
    
    RETURN
    
DISPLAY_0:
    BTFSS   PORTD, 0		; Revisar bit selector del Display 0
    RETURN			; Si no está activo, terminar subrutina
    MOVF    DISP_0, W		; Mover valor del Display 0 a W
    MOVWF   PORTC		; Mover W a PORTC, para desplegar el valor
    RETURN	
    
DISPLAY_1:
    BTFSS   PORTD, 1		; Revisar bit selector del Display 1
    RETURN			; Si no está activo, terminar subrutina
    MOVF    DISP_1, W		; Mover valor del Display 1 a W
    MOVWF   PORTC		; Mover W a PORTC, para desplegar el valor
    RETURN

DISPLAY_2:
    BTFSS   PORTD, 2		; Revisar bit selector del Display 2
    RETURN			; Si no está activo, terminar subrutina
    MOVF    DISP_2, W		; Mover valor del Display 2 a W
    MOVWF   PORTC		; Mover W a PORTC, para desplegar el valor
    RETURN
    
DISPLAY_3:
    BTFSS   PORTD, 3		; Revisar bit selector del Display 3
    RETURN			; Si no está activo, terminar subrutina
    MOVF    DISP_3, W		; Mover valor del Display 3 a W
    MOVWF   PORTC		; Mover W a PORTC, para desplegar el valor
    RETURN
    
END
