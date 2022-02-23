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
;   Última modificación:    17/02/2022

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
PSECT udata_bank0	    ; variables normales
    CONT_1:	    DS 2
    CONT_2:	    DS 2
    
PSECT udata_shr		    ; variables para ISR
    W_TEMP:	    DS 1
    STATUS_TEMP:    DS 1
    
PSECT resetVec, class=CODE, abs, delta=2
ORG 00h
    
;-------------------- RESET VECTOR -------------------- 
resetVec:   
    PAGESEL MAIN
    goto    MAIN
    
PSECT intVECT, class=CODE, abs, delta=2
ORG 04h

;-------------------- INTERRUPCIONES -------------------- 
PUSH:
    movwf   W_TEMP
    swapf   STATUS, W
    movwf   STATUS_TEMP
    
ISR:
    ; Contador del prelab
    btfsc   RBIF	
    call    INT_TMR
    
    ; Contador del lab y postlab
    btfsc   T0IF
    call    INT_T0

POP:
    swapf   STATUS_TEMP, W
    movwf   STATUS
    swapf   W_TEMP, F
    swapf   W_TEMP, W
    retfie

;-------------------- INTERRUPT SUBROUTINES --------------------     

; Contador del prelab
INT_TMR:   
    btfss   PORTB, 0
    incf    PORTA
    btfss   PORTB, 1
    decf    PORTA
    bcf	    RBIF
    return
    
; Contador del lab y postlab
INT_T0:
    ; REINICIO TIMER 0
    movlw   135
    movwf   TMR0
    bcf	    T0IF
    
    ; CONTADOR TIMER 0 -> DISPLAY_1
    incf    CONT_1
    movf    CONT_1, W
    sublw   10
    btfss   ZERO
    goto    $+2
    clrf    CONT_1
    incf    PORTC, 0
    andlw   0x0F
;    call    DISPLAY
    movwf   PORTC
    
    ; DISPLAY_2
    incf    CONT_2, 0
    sublw   100
    btfss   ZERO
    goto    $+2
    clrf    CONT_2
    incf    PORTD, 0
    andlw   0x0F
;    call    DISPLAY
    movwf   PORTD
    
    return
    
;-------------------- TABLA --------------------        
 
PSECT code, delta=2, abs
ORG 100h
    
DISPLAY:
    clrf    PCLATH
    bsf     PCLATH, 0
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
    call    CONFIG_INT
    call    CONFIG_IO
    call    CONFIG_CLOCK
    call    CONFIG_TMR0
    call    CONFIG_IOCB
    
LOOP:
    goto    LOOP
    
;-------------------- SUBROUTINES --------------------
CONFIG_IOCB:
    banksel TRISA
    bsf	    IOCB, 0
    bsf	    IOCB, 1
    bsf	    WPUB, 0
    bsf	    WPUB, 1
    
    banksel PORTA
    bcf	    RBIF
    return
    
CONFIG_IO:
    banksel ANSEL
    clrf    ANSEL
    clrf    ANSELH
    
    banksel TRISA
    bsf	    TRISB,  0
    bsf	    TRISB,  1
    
    clrf    TRISA   ; Utilizar PORTA como salida.
    clrf    TRISC   ; Utilizar PORTC como salida.
    clrf    TRISD   ; Utilizar PORTD como salida.
    
    banksel PORTA
    
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
    BCF     OPTION_REG, 7
    
    banksel TMR0	; Para hallar el 135:
    movlw   135		; 135 -> 100ms, con: temporizador=4*tosc*TMR0*prescaler
    movwf   TMR0	; tosc = 1 / frecuencia, siendo frecuencia 4Mhz
    bcf	    T0IF	; prescaler 256, y TMR0 = (256 - N)
    return		; Despejar N, y queda N = 135.
    
CONFIG_INT:
    banksel INTCON
    bsf	    GIE
    bsf	    T0IE
    bcf	    T0IF
    bsf	    RBIE
    bcf	    RBIF
    return
	
END
