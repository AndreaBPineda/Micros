;   Archivo:		    main.s
;   Dispositivo:	    PIC16F887
;   Autor:		    Andrea Barrientos Pineda, 20575
;   Compilador:		    pic-as (v2.32), MPLABX v6.00
;
;   Programa:		    Contador de 4 bits con pushbuttons.
;   Hardware:		    LED en el puerto A, pushbuttons en RB0 y RB1.
;
;   Creado:		    31/01/2022
;   Última modificación:    04/02/2022

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
    SUM:	DS 1	; Tamaño: 1 byte
    
;-------------------- RESET VECTOR INSTRUCTIONS --------------------
PSECT resetVec, class=CODE, abs, delta=2
    
ORG 00h
resetVec:   ;retornar a cierta posición default al resetear el vector
    PAGESEL MAIN
    goto    MAIN
    
;-------------------- CONFIGURATION --------------------
MAIN:			 ;definir valores a utilizar
    call    CONFIG_IO	 ; Llamar la configuración del PIC
    call    CONFIG_CLOCK ; Llamar la configuración del reloj del PIC
    banksel PORTA	 ; Obtener banco de memoria en PORTA
    clrf    PORTA	 ; Limpiar banco de memoria en PORTA
    banksel PORTC
    clrf    PORTC
	
;-------------------- MAIN LOOP --------------------
LOOP:			 ; Ejecución del programa
    call    COUNTER_1
    call    COUNTER_2
    call    ADD_PORTS
    goto    LOOP
	
;-------------------- SUBROUTINES --------------------
COUNTER_1:		; Primer contador.
    btfsc   PORTB, 0	; Revisar bit 0 de PORTB
    call    INC_PORTA	; Incrementar PORTA
    btfsc   PORTB, 1	; Revisar bit 1 de PORTB
    call    DEC_PORTA	; Decrementar PORTA
    goto    LOOP	; Volver al LOOP para continuar el programa
    
COUNTER_2:		; Misma estructura que COUNTER_1; solo cambia el puerto de A a C.
    btfsc   PORTB, 2	; Notar: Se revisan bits 2 y 3 de PORTB...
    call    INC_PORTC	; ...Con esos bits, COUNTER_2 no sobreescribe a COUNTER_1
    btfsc   PORTB, 3	; ...lo anterior, permite sumar luego los contadores.
    call    DEC_PORTC 
    goto    LOOP	; Volver al LOOP para continuar el programa.

ADD_PORTS:  ; Para sumar los puertos de cada contador (a través de W).
    btfsc   PORTB, 5	; Revisar un pushbutton en el puerto RB5
    bcf	    PORTE, 0    ; Asignar 0 a PORTE
    movf    PORTA, 0	; Colocar el valor actual de PORTA en W
    addwf   PORTC, 0	; Sumar el valor actual de PORTC al contenido de W
    movwf   SUM		; El resultado de la suma se guarda en SUM
    btfsc   SUM, 4	; Revisar el bit 4 (en total, el quinto bit) de SUM.
    bsf	    PORTE, 0    ; En caso el bit 4 es 1, guardarlo en PORTE (es el carry).
    andlw   0x0F	; W AND 15 (0000 1111), para dejar solo 4 bits.
    movwf   PORTD	; Guardar en PORTD, el resultado del and anterior.
    return
    
INC_PORTA:  ; Incrementar valor en PORTA
    call    DELAY_SMALL ; Ejecutar un delay corto
    btfsc   PORTB, 0	; Si está en 1, se ejecuta lo siguiente.
    goto    $-1		; Volver a btfsc, hasta que este sea 0.
    incf    PORTA	; Siendo 0, se ejecuta el incremento.
    return
    
DEC_PORTA:  ; Decrementar valor en PORTA
    call    DELAY_SMALL	; Mismo proceso que en INC_PORTA
    btfsc   PORTB, 1	; La diferencia: se revisa el bit 1 para 
    goto    $-1		; Esto es así porque se busca reducir su valor.
    decf    PORTA	; Si btfsc resulta en 0, se ejecuta el decremento.
    return
    
; INC_PORTC tiene la misma estructura y funcionamiento que INC_PORTA.
; Igual ocurre con DEC_PORTC y DEC_PORTA.

INC_PORTC:  ; Incrementar valor en PORTC
    call    DELAY_SMALL
    btfsc   PORTB, 2
    goto    $-1
    incf    PORTC
    return
    
DEC_PORTC:  ; Decrementar valor el PORTC
    call    DELAY_SMALL
    btfsc   PORTB, 3
    goto    $-1
    decf    PORTC
    return
	 
CONFIG_IO:  ; Configuración a utilizar en MAIN
    bsf	    STATUS, 5
    bsf	    STATUS, 6
    clrf    ANSEL
    clrf    ANSELH
	
    bsf	    STATUS, 5
    bcf	    STATUS, 6
    clrf    TRISA	; Definir como una salida
    
    bsf	    STATUS, 5
    bcf	    STATUS, 6
    bsf	    TRISB, 0    ; Definir bits de B como una salida.
    bsf	    TRISB, 1
    bsf	    TRISB, 2
    bsf	    TRISB, 3
    bsf	    TRISB, 5
    
    bsf	    STATUS, 5
    bcf	    STATUS, 6
    clrf    TRISB	; Definir como una salida
    
    bsf	    STATUS, 5
    bcf	    STATUS, 6
    clrf    TRISC	; Definir como una salida
    
    bsf	    STATUS, 5
    bcf	    STATUS, 6
    clrf    TRISD	; Definir como una salida
    
    bsf	    STATUS, 5
    bcf	    STATUS, 6
    clrf    TRISE	; Definir como una salida
	
    bcf	    STATUS, 5
    bcf	    STATUS, 6
    clrf    PORTA	; Limpiar cada puerto (A, B, C, D y E)
    clrf    PORTB
    clrf    PORTC
    clrf    PORTD
    clrf    PORTE
    
    return

CONFIG_CLOCK: ; Configuración a utilizar en el reloj del PIC
    banksel OSCCON
    bsf	    IRCF2
    bcf	    IRCF1
    bcf	    IRCF0
    bsf	    SCS
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