;   ARCHIVO:		main.s
;   DISPOSITIVO:	PIC16F887
;   AUTOR:		Andrea Barrientos Pineda (Carnet: 20575)
;   COMPILADOR:		pic-as (v2.32), MPLABX v6.00
;
;   PROGRAMA:		Contador de segundos en TIMER1 y TIMER2 del PIC
;   HARDWARE:		    
;	- SALIDAS:
;	    - PORTA:	LED			    (PINES: RA0)
;	    - PORTC:	Display de 7 segmentos (x2) (PINES: RC0-RC7)
;	    - PORTE:	Transistores		    (PINES: RE0-RE1)
;
;   CREADO:		26/02/2022
;   MODIFICADO:		02/03/2022
    
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
    MOVLW   TMR0_VAR		; Tiempo de interrupción
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
    
RESET_TMR2 MACRO PR2_VAR	; Macro para reinicio de TMR2
    BANKSEL PR2			; Banco 1
    MOVLW   PR2_VAR		; Tiempo de interrupción
    MOVWF   PR2
    
    BANKSEL INTCON
    BCF	    TMR2IF		; Limpiar bandera de interrupciones
    ENDM
    
;-------------------- VARIABLES --------------------

PSECT udata_shr			; Variables para interrupciones
    W_TEMP:	    DS 1	; Registro temporal para W
    STATUS_TEMP:    DS 1	; Registro temporal para STATUS
    
PSECT udata_bank0		; Variables para el programa
    SEGUNDOS:	    DS 1	; Contar segundos
    SELECTOR:	    DS 1	; Selectores para los displays
    VALOR:	    DS 1	; Valor para el display
    NIBBLES:	    DS 2	; Nibbles de VALOR
    DISPLAY:	    DS 2	; Nibbles para los displays
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h				; Posición 0000h: Vector Reset
    
;-------------------- VECTOR RESET --------------------

resetVec:
    PAGESEL MAIN
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h				; Posición 0004h: Interrupcinoes
    
;-------------------- INTERRUPCIONES --------------------
    
PUSH:				
    MOVWF   W_TEMP		; Mover W al registro temporal W_TEMP
    SWAPF   STATUS, W		; Swap en STATUS y guardar en W
    MOVWF   STATUS_TEMP		; Mover STATUS de W hacia STATUS_TEMP
    
ISR:
    BTFSC   T0IF		; Revisar interrupción de TMR0
    CALL    INT_TMR0		; Ejecutar subrutina de TMR0
    BTFSC   TMR1IF		; Revisar interrupción de TMR1
    CALL    INT_TMR1		; Ejecutar subrutina de TMR1
    BTFSC   TMR2IF		; Revisar interrupción de TMR2
    CALL    INT_TMR2		; Ejecutar subrutina de TMR2
    
POP:
    SWAPF   STATUS_TEMP, W	; Swap en STATUS_TEMP y guardar en W
    MOVWF   STATUS		; Mover STATUS_TEMP de W a STATUS
    SWAPF   W_TEMP, F		; Swap en W_TEMP y guardar en regitro F
    SWAPF   W_TEMP, W		; Swap en W_TEMP y guardar en W
    RETFIE
    
;-------------------- SUBRUTINAS DE INTERRUPCION --------------------
    
INT_TMR0:			; Muxeo de displays
    RESET_TMR0 255		; Reiniciar TMR0
    RETURN
    
INT_TMR1:			; Aumentar variable SEGUNDOS cada segundo
    RESET_TMR1 0x0B, 0xDC	; Reiniciar TMR1
    INCF    SEGUNDOS		; Incrementar PORTC
    RETURN
    
INT_TMR2:			; Enceder y apagar un LED intermitente
    RESET_TMR2 244		; Reiniciar TMR2
    INCF    PORTA		; Incrementar PORTA
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
    CALL    CONFIG_IO		; Configuración de I/O
    CALL    CONFIG_CLOCK	; Configuración de Oscilador
    CALL    CONFIG_TMR0		; Configuración de TMR0
    CALL    CONFIG_TMR1		; Configuración de TMR1
    CALL    CONFIG_TMR2		; Configuración de TMR2
    CALL    CONFIG_INT		; Configuración de interrupciones
    
    BANKSEL PORTA		; Banco 0
    
LOOP:
    CALL    GET_NIBBLES		; Obtener nibbles en VALOR
    CALL    SET_DISPLAY		; Colocar nibbles en los displays
    CALL    MOSTRAR_VALOR	; Mostrar valores en los displays
    GOTO    LOOP
    
;-------------------- SUBRUTINAS DE CONFIGURACION --------------------

CONFIG_IO:			; Configuración de I/O
    BANKSEL ANSEL		; Banco 3
    CLRF    ANSEL		; I/O digitales
    CLRF    ANSELH		; I/O digitales
    
    BANKSEL TRISA		; Banco 1
    BCF	    PORTA, 0		; PORTA, Bit 0: Salida	    (Led)
    CLRF    TRISC		; PORTC: Salida		    (Displays)
    BCF	    TRISD, 0		; PORTD, Bit 0: Salida	    (Selector Display 0)
    BCF	    TRISD, 1		; PORTD, Bit 1: Salida	    (Selector Display 1)
    
    BANKSEL PORTA		; Banco 0
    CLRF    PORTA		; Limpiar PORTA
    CLRF    PORTC		; Limpiar PORTC
    CLRF    PORTD		; Limpiar PORTD
    
    RETURN
    
CONFIG_CLOCK:			; Configuración de Oscilador
    BANKSEL OSCCON		; Banco 1
    BSF	    OSCCON, 0		; Usar reloj interno
    BCF	    OSCCON, 6		; 0
    BSF	    OSCCON, 5		; 1	   -> Frecuencia: 500kHz
    BSF	    OSCCON, 4		; 1
    RETURN
    
CONFIG_TMR0:			; Configuración de TMR0
    BANKSEL OPTION_REG		; Banco 0
    BCF	    T0CS		; Limpiar registro T0CS
    BCF	    PSA			; Modo contador
    BSF	    PS2			; 1
    BSF	    PS1			; 1	    -> Prescaler 1:256
    BSF	    PS0			; 1
    
    RESET_TMR0 255		; Reiniciar TMR0
    
    RETURN
    
CONFIG_TMR1:			; Configuración de TMR1
    BANKSEL T1CON		; Banco 0
    BCF	    TMR1GE		; Contar siempre con el TMR1
    BSF	    T1CKPS1		; 1	     
    BSF	    T1CKPS1		; 1	   -> Prescaler 1:8	  
    BCF	    T1OSCEN		; Deshabilitar oscilador LP
    BCF	    TMR1CS		; Utilizar reloj interno
    BSF	    TMR1ON		; Encender TMR1
    
    RESET_TMR1 0x0B, 0xDC	; Reiniciar TMR1
    RETURN
    
CONFIG_TMR2:			; Configuración de TMR2
    BANKSEL PR2			; Banco 1
    MOVLW   244			; Interrupciones cada 500ms
    MOVWF   PR2			
    
    BANKSEL T2CON		; Banco 0
    BSF	    T2CKPS1		; 1
    BSF	    T2CKPS0		; 1	   -> Prescaler: 1:16
    
    BSF	    TOUTPS3		; 1
    BSF	    TOUTPS2		; 1
    BSF	    TOUTPS1		; 1
    BSF	    TOUTPS0		; 1	   -> Postscaler: 1:16
    
    BSF	    TMR2ON		; Encender TMR2
    RETURN
    
CONFIG_INT:			; Configuración de interrupciones
    BANKSEL PIE1		; Banco 1
    BSF	    TMR1IE		; Habilitar interrupciones de TMR1
    BSF	    TMR2IE		; Habilitar interrupciones de TMR2
    
    BANKSEL INTCON		; Banco 0
    BSF	    GIE			; Habilitar interrupciones en general
    BSF	    PEIE		; Habilitar interrupciones de periféricos
    BCF	    T0IF		; Limpiar bandera de TMR0
    BSF	    T0IE		; Habilitar interrupciones de TMR0
    BCF	    TMR1IF		; Limpiar bandera de TMR1
    BCF	    TMR2IF
    RETURN
    
;-------------------- SUBRUTINAS DE DISPLAYS --------------------
    
GET_NIBBLES:			; Obtener nibbles bajo y alto de VALOR
    
    ; Nibble bajo
    MOVLW   0x0F		; Colocar 0x0F en W
    ANDWF   SEGUNDOS, W		; Obtener nibble bajo de SEGUNDOS
    MOVWF   NIBBLES		; Mover nibble bajo a NIBBLES
    
    ; Nibble alto
    MOVLW   0xF0		; Colocar 0xF0 en W
    ANDWF   SEGUNDOS, W		; Obtener nibble alto de SEGUNDOS
    MOVWF   NIBBLES+1		; Mover nibble alto a NIBBLES
    SWAPF   NIBBLES+1, F	; Swap en los bits de NIBBLES+1
    
    RETURN
    
SET_DISPLAY:			; Escoger valor de la tabla para cada display
    
    ; Display 0
    MOVF    NIBBLES, W		; Mover NIBBLES a W
    CALL    DISPLAY_7SEG	; Ejecutar tabla de valores de display
    MOVWF   DISPLAY		; Mover valor resultante a DISPLAY
    
    ; Display 1
    MOVF    NIBBLES+1, W	; Mover NIBBLES+1 a W
    CALL    DISPLAY_7SEG	; Ejecutar tabla de valores de display
    MOVWF   DISPLAY+1		; Mover valor resultante a DISPLAY+1
    
    RETURN

MOSTRAR_VALOR:			; Mostrar valor en los displays de 7 segmentos
    BCF	    PORTD, 0		; Limpiar selector del Display 0
    BCF	    PORTD, 1		; Limpiar selector del Display 1
    BTFSC   SELECTOR, 0		; Revisar selector del Display 0
    CALL    DISPLAY_0		; Si el selector es 1, correr Display 0
    CALL    DISPLAY_1		; Si el selector es 0, correr Display 1
    
DISPLAY_0:			; Mostrar valor en el primer display (0)
    MOVF    DISPLAY, W		; Mover DISPLAY a W
    MOVWF   PORTC		; Mover W a PORTC
    BSF	    PORTD, 1		; Activar salida hacia el Display 1
    BCF	    SELECTOR, 0		; Limpiar selector del Display 0
    RETURN
    
DISPLAY_1:			; Mostrar valor en el segundo display (1)
    MOVF    DISPLAY+1, W	; Mover DISPLAY+1 a W
    MOVWF   PORTC		; Mover W a PORTC
    BSF	    PORTD, 0		; Activar salida hacia el Display 0
    BSF	    SELECTOR, 0		; Activar selector del Display 0
    RETURN

END
