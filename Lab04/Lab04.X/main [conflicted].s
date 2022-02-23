;   Archivo:		    main.s
;   Dispositivo:	    PIC16F887
;   Autor:		    Andrea Barrientos Pineda, 20575
;   Compilador:		    pic-as (v2.32), MPLABX v6.00
;
;   Programa:		    Contadores con 7-seg displays en segundos y
;			    decenas de segundos.
;   Hardware:		    
;	- PORTA: Pushbuttons
;	    - Pushbuttons (x2)		    -> Pines: RA0 y RA1
;	- PORTB: Contador de 4 bits (Timer0)
;	    - LEDS (x4)			    -> Pines: RB0, RB1, RB2 y RB3
;	- PORTC: Contador de botones
;	    - LEDS (x4)			    -> RC0, RC1, RC2 y RC3
;	- PORTD: Display de 7 segmentos
;	    - Todos los pines
;	- PORTE: Display de 7 segmentos
;	    - Todos los pines
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
PSECT udata_shr
    W_TEMP:	    DS 1
    STATUS_TEMP:    DS 1
    
PSECT resetVec, class=CODE, abs, delta=2
ORG 04h
    
;-------------------- RESET VECTOR -------------------- 
resetVec:   
    PAGESEL MAIN
    goto    MAIN
    
PSECT intVECT, class=CODE, abs, delta=2
ORG 100h

;-------------------- INTERRUPCIONES -------------------- 
PUSH:
    movwf   W_TEMP
    swapf   STATUS, W
    movwf   STATUS_TEMP
    
ISR:
    

POP:
    swapf   STATUS_TEMP, W
    movwf   STATUS
    swapf   W_TEMP, F
    swapf   W_TEMP, W
    retfie
    
;-------------------- MAIN PROGRAM -------------------- 
MAIN:
    call    CONFIG_IO
    call    CONFIG_CLOCK
    call    CONFIG_TMR0
    banksel PORTB
    
    clrf    TRISB
    
LOOP:
    
    
;-------------------- SUBROUTINES --------------------
    
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
    
    banksel PORTA
    
    clrf    PORTA   ; Limpiar PORTA
    clrf    PORTB   ; Limpiar PORTB
    
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
    
CONFIG_INT:
    banksel INTCON
    bsf	    GIE
    bsf	    T0IE
    bsf	    T0IF
    return
	
END
