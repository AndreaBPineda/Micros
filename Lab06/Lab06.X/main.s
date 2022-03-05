;   ARCHIVO:		main.s
;   DISPOSITIVO:	PIC16F887
;   AUTOR:		Andrea Barrientos Pineda (Carnet: 20575)
;   COMPILADOR:		pic-as (v2.32), MPLABX v6.00
;
;   PROGRAMA:		Contador de segundos en TMR1 y displays de 7 segmentos
;			(Lab 06 - Postlab)
;   HARDWARE:		    
;	- ENTRADAS:	TMR0 y TMR1 del PIC
;	- SALIDAS:
;	    - PORTC:	Display de 7 segmentos (x2) (PINES: RC0-RC7)
;	    - PORTD:	Transistores (x2)	    (PINES: RD0-RD1)
;
;   CREADO:		26/02/2022
;   MODIFICADO:		05/03/2022
    
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
RESET_TMR0 MACRO TMR0_VAR	; Macro para reinicio de TMR0
    BANKSEL TMR0		; Banco 0
    MOVLW   TMR0_VAR		; Tiempo de interrupci�n
    MOVWF   TMR0		
    BCF	    T0IF		; Limpiar bandera de interrupciones
    ENDM
    
RESET_TMR1 MACRO TMR1_H, TMR1_L	; Macro para reinicio de TMR1
    BANKSEL TMR0		; Banco 0
    MOVLW   TMR1_H		; Valor en el registro alto
    MOVLW   TMR1H
    MOVLW   TMR1_L		; Valor en el registro bajo
    MOVLW   TMR1L
    BCF	    TMR1IF		; Limpiar bandera de interrupciones
    ENDM
    
;-------------------- VARIABLES --------------------

PSECT udata_shr			; Variables para interrupciones
    W_TEMP:	    DS 1	; Registro temporal para W
    STATUS_TEMP:    DS 1	; Registro temporal para STATUS
    
PSECT udata_bank0		; Variables para el programa
    UNIDADES:	    DS 1	; Contar unidades de segundos
    DECENAS:	    DS 1	; Contar decenas de segundos
    SELECTOR:	    DS 1	; Selector de display activo
    VALOR_0:	    DS 1	; Valor para display 0
    VALOR_1:	    DS 1	; Valor para display 1
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h				; Posici�n 0000h: Vector Reset
    
;-------------------- VECTOR RESET --------------------

resetVec:
    PAGESEL MAIN
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h				; Posici�n 0004h: Interrupcinoes
    
;-------------------- INTERRUPCIONES --------------------
    
PUSH:				
    MOVWF   W_TEMP		; Mover W al registro temporal W_TEMP
    SWAPF   STATUS, W		; Swap en STATUS y guardar en W
    MOVWF   STATUS_TEMP		; Mover STATUS de W hacia STATUS_TEMP
    
ISR:
    BTFSC   TMR1IF		; Revisar interrupci�n de TMR1
    CALL    INT_TMR1		; Ejecutar subrutina de TMR1
    BTFSC   T0IF		; Revisar interrupci�n de TMR0
    CALL    INT_TMR0		; Ejecutar subrutina de TMR0
    
POP:
    SWAPF   STATUS_TEMP, W	; Swap en STATUS_TEMP y guardar en W
    MOVWF   STATUS		; Mover STATUS_TEMP de W a STATUS
    SWAPF   W_TEMP, F		; Swap en W_TEMP y guardar en regitro F
    SWAPF   W_TEMP, W		; Swap en W_TEMP y guardar en W
    RETFIE
    
;-------------------- SUBRUTINAS DE INTERRUPCION --------------------
    
INT_TMR0:			; Muxeo de displays
    RESET_TMR0 255		; Reiniciar TMR0
    MOVF    PORTD, W		; Mover PORTD a W
    XORLW   0x03		; Voltear bits 0 y 1 (invertir selectores)
    MOVWF   PORTD		; Regresar valores a PORTD para cambiar display
    CALL    DISPLAY_0		; Mostrar valores en los displays
    CALL    DISPLAY_1		; Mostrar valores en los displays
    RETURN
    
INT_TMR1:			; Aumentar variable SEGUNDOS cada segundo
    RESET_TMR1 0x0B, 0xDC	; Reiniciar TMR1
    INCF    UNIDADES		; Incrementar contador
    CALL    CONTADOR_DECIMAL	; Convertir contador a decenas y unidades
    CALL    RESET_COUNTER	; Resetear contador al llegar a 60
    RETURN
    
PSECT code, delta=2, abs
ORG 100h
 
DISPLAY_7SEG:			; Tabla de valor del display de 7 segmentos
    CLRF    PCLATH		; Limpiar registro PCLATH
    BSF     PCLATH, 0		; Activar bit 0 de PCLATH
    ANDLW   0x0F		; Obtener 4 bits del valor en W.
    ADDWF   PCL, F		; Sumar valor de PCL a W.
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
    
;-------------------- PROGRAMA PRINCIPAL --------------------
MAIN:
    CALL    CONFIG_IO		; Configuraci�n de I/O
    CALL    CONFIG_CLOCK	; Configuraci�n de Oscilador
    CALL    CONFIG_TMR0		; Configuraci�n de TMR0
    CALL    CONFIG_TMR1		; Configuraci�n de TMR1
    CALL    CONFIG_INT		; Configuraci�n de interrupciones
    
    BANKSEL PORTA		; Banco 0
    
LOOP:
    CALL    SET_DISPLAY		; Colocar nibbles en los displays
    GOTO    LOOP
    
;-------------------- SUBRUTINAS DE CONFIGURACION --------------------

CONFIG_IO:			; Configuraci�n de I/O
    BANKSEL ANSEL		; Banco 3
    CLRF    ANSEL		; I/O digitales
    CLRF    ANSELH		; I/O digitales
    
    BANKSEL TRISA		; Banco 1
    CLRF    TRISC		; PORTC: Salida		    (Displays)
    BCF	    TRISD, 0		; PORTD, Bit 0: Salida	    (Selector Display 0)
    BCF	    TRISD, 1		; PORTD, Bit 1: Salida	    (Selector Display 1)
    
    BANKSEL PORTA		; Banco 0
    CLRF    PORTC		; Limpiar PORTC
    BCF	    PORTD, 0		; Limpiar selector de Display 0
    BSF	    PORTD, 1		; Activar selector de Display 1
    
    CLRF    UNIDADES		; Limpiar variable de unidades de segundos
    CLRF    DECENAS		; Limpiar variable de decenas de segundos
    CLRF    SELECTOR		; Limpiar variable de display activo
    
    RETURN
    
CONFIG_CLOCK:			; Configuraci�n de Oscilador
    BANKSEL OSCCON		; Banco 1
    BSF	    OSCCON, 0		; Usar reloj interno
    BSF	    OSCCON, 6		; 0
    BCF	    OSCCON, 5		; 1	   -> Frecuencia: 1MHz
    BCF	    OSCCON, 4		; 1
    RETURN
    
CONFIG_TMR0:			; Configuraci�n de TMR0
    BANKSEL OPTION_REG		; Banco 0
    BCF	    T0CS		; Limpiar registro T0CS
    BCF	    PSA			; Modo contador
    BSF	    PS2			; 1
    BSF	    PS1			; 1	    -> Prescaler 1:256
    BSF	    PS0			; 1
    
    RESET_TMR0 255		; Reiniciar TMR0
    
    RETURN
    
CONFIG_TMR1:			; Configuraci�n de TMR1
    BANKSEL T1CON		; Banco 0
    BCF	    TMR1GE		; Contar siempre con el TMR1
    BSF	    T1CKPS1		; 1	     
    BSF	    T1CKPS1		; 1	   -> Prescaler 1:8	  
    BCF	    T1OSCEN		; Deshabilitar oscilador LP
    BCF	    TMR1CS		; Utilizar reloj interno
    BSF	    TMR1ON		; Encender TMR1
    
    RESET_TMR1 0x0B, 0xDC	; Reiniciar TMR1
    RETURN
    
CONFIG_INT:			; Configuraci�n de interrupciones
    BANKSEL PIE1		; Banco 1
    BSF	    TMR1IE		; Habilitar interrupciones de TMR1
    
    BANKSEL INTCON		; Banco 0
    BSF	    GIE			; Habilitar interrupciones en general
    BSF	    PEIE		; Habilitar interrupciones de perif�ricos
    BCF	    T0IF		; Limpiar bandera de TMR0
    BSF	    T0IE		; Habilitar interrupciones de TMR0
    BCF	    TMR1IF		; Limpiar bandera de TMR1
    RETURN
    
;-------------------- SUBRUTINAS DE DISPLAYS --------------------
    
CONTADOR_DECIMAL:		; Contador con unidades y decenas combinadas
    MOVF    UNIDADES, W		; Mover UNIDADES a W
    SUBLW   9			; Restarle 9 a W, para ver si hay decenas
    BTFSC   STATUS, 0		; Revisar si la bandera de carry C es 1
    RETURN			
    BTFSS   STATUS, 0		; Revisar si la bandera de carry C es 0
    CALL    OBTENER_DECENAS	; Pasar a obtener las decenas
    RETURN
    
OBTENER_DECENAS:		; Obtener decenas de segundos
    INCF    DECENAS		; Incrementar decenas
    CLRF    UNIDADES		; Limpiar unidades; vuelven a ser 0
    RETURN
    
RESET_COUNTER:			; Reiniciar el contador al llegar a 60
    MOVF    DECENAS, W		; Mover DECENAS a W
    SUBLW   5			; Restar 5 a W, para limitar las decenas a 6
    BTFSS   STATUS, 0		; Revisar bandera de Carry C
    CLRF    DECENAS		; Al ejecutar la resta, limpiar las decenas
    RETURN
    
SET_DISPLAY:			; Escoger valor de la tabla para cada display
    
    ; Display 0 (decenas, display de la izquierda)
    MOVF    DECENAS, W		; Mover DECENAS a W
    CALL    DISPLAY_7SEG	; Ejecutar tabla de valores de display
    MOVWF   VALOR_0		; Mover valor resultante a VALOR_0
    
    ; Display 1 (unidades, display de la derecha)
    MOVF    UNIDADES, W		; Mover UNIDADES a W
    CALL    DISPLAY_7SEG	; Ejecutar tabla de valores de display
    MOVWF   VALOR_1		; Mover valor resultante a VALOR_1
    
    RETURN
    
DISPLAY_0:			; Mostrar valor en el display de decenas
    BTFSS   PORTD, 0		; Revisar el selector del Display 0
    RETURN
    MOVF    VALOR_0, W		; Mover valor del Display 0 a W
    MOVWF   PORTC		; Mover W a PORTC
    RETURN
    
DISPLAY_1:			; Mostrar valor en el display de unidades
    BTFSS   PORTD, 1		; Revisar el selector del Display 1
    RETURN
    MOVF    VALOR_1, W		; Mover valor del Display 1 a W
    MOVWF   PORTC		; Mover W a PORTC
    RETURN

END
