;   ARCHIVO:		main.s
;   DISPOSITIVO:	PIC16F887
;   AUTOR:		Andrea Barrientos Pineda (Carnet: 20575)
;   COMPILADOR:		pic-as (v2.32), MPLABX v6.00
;
;   PROGRAMA:		Contador de 8-Bits con 3 displays de 7 segmentos.
;   HARDWARE:		    
;	- ENTRADAS:
;	    - PORTA:	Pushbuttons	    (PINES: RA0,RA1)
;	- SALIDAS:
;	    - PORTB:	Leds		    (PINES: RB0-RB7)
;	    - PORTC:	7-Segment Displays  (PINES: RC0-RC7)
;
;   CREADO:		19/02/2022
;   MODIFICADO:		19/02/2022
    
;-------------------- DISPOSITIVO Y LIBRERIAS --------------------
PROCESSOR 16F887
#include <xc.inc>
    
;-------------------- CONFIGURATION WORD 1 --------------------
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
    
;-------------------- CONFIGURATION WORD 2 --------------------
CONFIG WRT=OFF
CONFIG BOR4V=BOR40V

PSECT udata_shr
    W_TEMP:	    DS 1	; Variable temporal para el acumulador W.
    STATUS_TEMP:    DS 1	; Variable temporal para guardar nibbles.
    
PSECT udata_bank0
    VALOR:	    DS 1	; Valor de los displays.
    BANDERAS:	    DS 1	; Indicador de display a utilizar.
    NIBBLES:	    DS 2	; Nibbles alto y bajo de VALOR
    DISPLAY:	    DS 2	; Representación de nibbles en los displays.
    
PSECT resetVec, class=CODE, abs, delta=2
ORG 00h

;-------------------- RESET VECTOR -------------------- 
resetVec:
    PAGESEL MAIN
    GOTO    MAIN
    
PSECT intVECT, class=CODE, abs, delta=2
ORG 04h   
    
;-------------------- INTERRUPTIONS --------------------
    
PUSH:
    MOVWF   W_TEMP	    
    SWAPF   STATUS, W	    
    MOVWF   STATUS_TEMP	    
    
ISR:
    BANKSEL PORTA
    
    ; Contador de 8 Bits
    BTFSC   RBIF	    
    CALL    INT_TIMER	
    
    ; Displays de 7 segmentos
    BTFSC   T0IF
    CALL    INT_TMR0
    BTFSC   RBIF
    CALL    INT_PORTB
    
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE
    
;-------------------- INTERRUPTION SUBROUTINES --------------------    

INT_TIMER:
    BTFSS   PORTB, 0	    ; Revisar si el botón en RB0 está activo.
    INCF    PORTC	    ; Incrementar PORTA.
    BTFSS   PORTB, 1	    ; Revisar si el botón en RB1 está activo.
    DECF    PORTC	    ; Decrementar PORTA.
    BCF	    RBIF	    ; Limpiar bandera de PORTB.
    RETURN 
    
INT_TMR0:
    
    ; Reinicio
    ;BANKSEL TMR0	
    MOVLW   135		
    MOVWF   TMR0	
    BCF	    T0IF
    
    ; Correr función para mostrar valor.
    CALL    MOSTRAR_VALOR
    
    RETURN
    
INT_PORTB:
    BTFSS   PORTB, 0
    INCF    PORTC
    BTFSS   PORTB, 1
    DECF    PORTC
    BCF	    RBIF
    RETURN

PSECT code, delta=2, abs
ORG 100h
 
DISPLAY_7SEG:
    CLRF    PCLATH
    BSF     PCLATH, 0
    ANDLW   0x0F
    ADDWF   PCL, F
    RETLW   00111111B	; 0
    RETLW   00000110B	; 1
    RETLW   01011011B	; 2
    RETLW   01001111B	; 3
    RETLW   01100110B	; 4
    RETLW   01101101B	; 5
    RETLW   01111101B	; 6
    RETLW   00000111B	; 7
    RETLW   01111111B	; 8
    RETLW   01101111B	; 9
    RETLW   01110111B	; A
    RETLW   01111100B	; B
    RETLW   00111001B	; C
    RETLW   01011110B	; D
    RETLW   01111001B	; E
    RETLW   01110001B	; F
    
;-------------------- MAIN PROGRAM --------------------
    
MAIN:
    
    CALL    CONFIG_IOCB	    ; Configuraicón de interrupciones en PORTB.
    CALL    CONFIG_IO	    ; Configuración de puertos y entradas/salidas.
    CALL    CONFIG_CLK	    ; Configuración de reloj.
    CALL    CONFIG_TMR0	    ; Configuración del TIMER 0
    CALL    CONFIG_INT	    ; Configuración de banderas y enables.
    
    BANKSEL PORTA
    
LOOP:
    MOVF    PORTC, W
    MOVWF   VALOR
    CALL    GET_NIBBLE
    CALL    SET_DISPLAY
    GOTO    LOOP
    
;-------------------- CONFIGURATION SUBROUTINES --------------------

CONFIG_IOCB:		    ; Configuración de interrupciones en PORTB.
    BANKSEL TRISA
    BSF	    IOCB, 0
    BSF	    IOCB, 1
    BSF	    WPUB, 0
    BSF	    WPUB, 1
    
    BANKSEL PORTA
    BCF	    RBIF	    ; Limpiar bandera de PORTB.
    RETURN
    
CONFIG_IO:		    ; Configuración de puertos y entradas/salidas.
    BANKSEL ANSEL	    ; Banco 3
    CLRF    ANSEL	    ; Entradas digitales.
    CLRF    ANSELH	    ; Entradas digitales.
    
    BANKSEL TRISA	    ; Banco 1
    BSF	    TRISB, 0	    ; Bit 0 de PORTB como entrada (Pushbutton 1).
    BSF	    TRISB, 1	    ; Bit 1 de PORTB como entrada (Pushbutton 2).
    CLRF    TRISC	    ; Utilizar PORTC como salida (Leds del contador).
    CLRF    TRISD	    ; Utilizar PORTD como salida (Displays).
    BCF	    TRISE, 0	    ; Bit 0 de PORTE como salida.
    BCF	    TRISE, 1	    ; Bit 1 de PORTE como salida.
    BCF	    OPTION_REG, 7
    
    BANKSEL PORTA	    ; Banco 0
    CLRF    PORTB	    ; Limpiar PORTB
    CLRF    PORTC	    ; Limpiar PORTC
    CLRF    PORTD	    ; Limpiar PORTD
    CLRF    PORTE	    ; Limpiar PORTE
    
    RETURN
    
CONFIG_CLK:		    ; Configuración del reloj (interno)
    BANKSEL OSCCON	    ; Banco 1
    BSF	    OSCCON, 0	    ; Bit 0 de OSCCON: Utilizar reloj interno.
    BCF	    OSCCON, 4	    ; Bit selector de frecuencia
    BSF	    OSCCON, 5	    ; Bit selector de frecuencia
    BSF	    OSCCON, 6	    ; Bit selector de frecuencia
    RETURN
    
CONFIG_TMR0:		    ; Configuración del TIMER 0 (Prescaler 1:256)
    
    ; Configuración
    BANKSEL OPTION_REG
    BCF	    T0CS
    BCF	    PSA
    BSF	    PS2
    BSF	    PS1
    BSF	    PS0		    
    
    ; Reinicio
    BANKSEL TMR0	
    MOVLW   135		
    MOVWF   TMR0	
    BCF	    T0IF	
    RETURN
    
CONFIG_INT:
    BANKSEL PORTA
    BSF	    GIE		    ; Activar enable global.
    BCF	    T0IF	    ; Limpiar bandera del TIMER 0
    BSF	    T0IE	    ; Activar enable del TIMER 0
    BCF	    RBIF	    ; Limpiar bandera de PORTB
    BSF	    RBIE	    ; Activar enable del TIMER 0
    
    RETURN
    
GET_NIBBLE:		    ; Obtener nibbles para el valor de cada display.
    
    ; Nibble bajo
    MOVLW   0X0F
    ANDWF   VALOR, W
    MOVWF   NIBBLES
    
    ; Nibble alto
    MOVLW   0XF0
    ANDWF   VALOR, W
    MOVWF   NIBBLES+1
    SWAPF   NIBBLES+1, F
    
    RETURN
    
SET_DISPLAY:		    ; Colocar en cada display el valor a utilizar.
    
    ; Display 1
    MOVF    NIBBLES, W
    CALL    DISPLAY_7SEG
    MOVWF   DISPLAY
    
    ; Display 2
    MOVF    NIBBLES+1, W
    CALL    DISPLAY_7SEG
    MOVWF   DISPLAY+1
    
    RETURN
    
MOSTRAR_VALOR:
    BCF	    PORTE, 0
    BCF	    PORTE, 1
    BTFSC   BANDERAS, 0
    GOTO    DISPLAY_1
    
DISPLAY_0:
    MOVF    DISPLAY, W
    MOVWF   PORTD
    BSF	    PORTE, 1
    BSF	    BANDERAS, 0
    RETURN
    
DISPLAY_1:
    MOVF    DISPLAY+1, W
    MOVWF   PORTD
    BSF	    PORTE, 0
    BCF	    BANDERAS, 0
    RETURN

END
    