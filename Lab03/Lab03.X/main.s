;   Archivo:		    main.s
;   Dispositivo:	    PIC16F887
;   Autor:		    Andrea Barrientos Pineda, 20575
;   Compilador:		    pic-as (v2.32), MPLABX v6.00
;
;   Programa:		    Displayde 7 segmentos, contador timer0, y contador
;			    de 4 bits en segundos con led de alarma.
;   Hardware:		    
;	- PORTA: Pushbuttons
;	    - Pushbuttons (x2)		    -> Pines: RA0 y RA1
;	- PORTB: Contador de 4 bits (Timer0)
;	    - LEDS (x4)			    -> Pines: RB0, RB1, RB2 y RB3
;	- PORTC: Display
;	    - Display de 7 segmentos (x1)   -> Todos los pines de PORTC
;	- PORTD: Contador en segundos + LED de alarma
;	    - LEDS del contador (x4)	    -> RD0, RD1, RD2 y RD3
;	    - LED de alarma (x1)	    -> RD7
;
;   Creado:		    07/02/2022
;   Última modificación:    07/02/2022

PROCESSOR 16F887 ;definir el tipo de PIC a utilizar
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

;-------------------- VARIABLES --------------------
PSECT udata_bank0
    CONT_SMALL: DS 1	; Tamaño: 1 byte
    CONT_BIG:   DS 1	; Tamaño: 1 byte
    X:		DS 1	; Tamaño: 1 byte; guarda el contador del display.
    Y:		DS 1	; Tamaño: 1 byte; guarda el valor del otro contador.
    
;-------------------- RESET VECTOR INSTRUCTIONS --------------------
PSECT resetVec, class=CODE, abs, delta=2
    
ORG 00h
resetVec:   ;retornar a cierta posición default al resetear el vector
    PAGESEL MAIN
    goto    MAIN
    
PSECT code, delta=2, abs
ORG 100h

DISPLAY:
    clrf    PCLATH
    bsf	    PCLATH, 0
    andlw   0x0F
    addwf   PCL, F
    retlw   00111111B	; 0
    retlw   00000110B	; 1
    retlw   01011011B	; 2
    retlw   01001111B	; 3
    retlw   01100110B	; 4
    retlw   01101101B	; 5
    retlw   01111101B	; 6
    retlw   00000111B	; 7
    retlw   01111111B	; 8
    retlw   01101111B	; 9
    retlw   01110111B	; A
    retlw   01111100B	; B
    retlw   00111001B	; C
    retlw   01011110B	; D
    retlw   01111001B	; E
    retlw   01110001B	; F
 
;-------------------- MAIN PROGRAM --------------------
MAIN:
    call    CONFIG_IO	    ; Configuración de puertos del PIC
    call    CONFIG_CLOCK    ; Configuración del reloj del PIC
    call    CONFIG_TMR0	    ; Configuración del timer0
    banksel PORTB
    
    clrf TRISB
    
LOOP:
    
    ; Contador de 4 bits con timer0
    btfss   T0IF
    goto    LOOP
    call    REINICIO_TMR0
    incf    PORTB
    incf    Y
    movf    PORTB, 0
    andlw   0x0F
    movwf   PORTB
    
    ; Contador de 4 bits: aumenta cuando timer0 llega a 10, y reinicia timer0.
    movf    Y, 0
    andlw   0x0F    ; Convertir a 4 bits y guardar de nuevo en W.
    xorlw   1010B   ; Revisar que Y = 1010 = A = 10 en decimal.
    btfsc   STATUS, 2    ; Si Y=0, se ejecuta la siguiente línea; de lo contrario no.
    incf    PORTD, 0
    andlw   0x0F    ; Convertir PORTD a 4 bits, guardar de nuevo en W.
    movwf   PORTD   ; Mandar contenido de W al PORTD para ver la salida.
    call    REINICIO_TMR0   ; Reiniciar Timer0, y de paso, su contador.
    
    ; Display de 7 segmentos
    btfsc   PORTA, 0
    call    INC_PORTA
    btfsc   PORTA, 1
    call    DEC_PORTA
    movf    X, 0
    call    DISPLAY
    movwf   PORTC
    
    ; LED de alarma y reinicio de contador de 4 bits.
    movf    X, 0
    xorlw   PORTD   ; Revisar si los valores de display y contador son iguales.
    btfss   STATUS, 2
    goto    $+2	    ; Si no son iguales los valores, se salta lineas: 127 y 128
    xorwf   0x4F    ; Voltear bit del LED de alarma.
    clrf    PORTD   ; Reiniciar el PORTD del contador de segundos.
    
    goto    LOOP
    
;-------------------- SUBROUTINES    --------------------
    
CONFIG_IO:
    banksel ANSEL
    bsf	    STATUS, 5
    bsf	    STATUS, 6
    clrf    ANSEL
    clrf    ANSELH
    
    bsf	    STATUS, 5
    bcf	    STATUS, 6
    bsf	    TRISA,  0
    bsf	    TRISA,  1
    
    banksel TRISB
    clrf    TRISB   ; Utilizar PORTB como salida.
    
    bsf	    STATUS, 5
    bcf	    STATUS, 6
    clrf    TRISC   ; Utilizar PORTC como salida.
    clrf    TRISD   ; Utilizar PORTD como salida.
    
    banksel PORTA
    
    clrf    X	    ; Limpiar X
    clrf    Y	    ; Limpiar Y
    clrf    PORTA   ; Limpiar PORTA
    clrf    PORTB   ; Limpiar PORTB
    clrf    PORTC   ; Limpiar PORTC
    clrf    PORTD   ; Limpiar PORTD
    
    return
    
CONFIG_CLOCK:
    banksel OSCCON
    bsf	    OSCCON, 0	; Utilizar reloj interno
    bcf	    OSCCON, 4	; IRCF1
    bcf	    OSCCON, 5	; IRCF2
    bsf	    OSCCON, 6	; IRCF3
    return

CONFIG_TMR0:
    banksel OPTION_REG
    bcf	    PSA
    bsf	    PS2
    bsf	    PS1
    bsf	    PS0		; Prescaler 1 : 256
    bcf	    T0CS
    bcf	    T0SE
    
    banksel TMR0	; Para hallar el 135:
    movlw   0		; 135 -> 100ms, con: temporizador=4*tosc*TMR0*prescaler
    movwf   TMR0	; tosc = 1 / frecuencia, siendo frecuencia 4Mhz
    bcf	    T0IF	; prescaler 256, y TMR0 = (256 - N)
    return		; Despejar N, y queda N = 135.
    
REINICIO_TMR0:
    banksel TMR0
    movlw   0
    movwf   TMR0
    bcf	    T0IF
    return
    
INC_PORTA:
    btfsc   PORTA, 0
    goto    $-1
    incf    X, W
    andlw   0x0F 
    movwf   X
    return
    
DEC_PORTA:
    btfsc   PORTA, 1
    goto    $-1
    decf    X, W
    andlw   0x0F
    movwf   X
    return
   
DELAY_BIG:  ; Delay grande/largo
    movlw   50
    movwf   CONT_BIG
    call    DELAY_SMALL
    decfsz  CONT_BIG, 1
    goto    $-2
    return
	
DELAY_SMALL: ; Delay pequeño/corto
    movlw   150
    movwf   CONT_SMALL
    decfsz  CONT_SMALL, 1
    goto    $-1
    return
	
END