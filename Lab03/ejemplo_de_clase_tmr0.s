; ----------------------------------------------------
; Universidad del Valle de Guatemala
; Programación de Microcontroladores
; Christopher Chiroy
; 31 Enero 2022
; TMR0 y contador en PORTD con incrementos cada 50ms
; ----------------------------------------------------
    
PROCESSOR 16F887
    

; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_CLKOUT   ; Oscillator Selection bits (INTOSC oscillator: CLKOUT function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>

PSECT resVect, class=CODE, abs, delta=2
ORG 00h	    ; posición 0000h para el reset
;------------ VECTOR RESET --------------
resetVec:
    PAGESEL MAIN	; Cambio de banco
    GOTO    MAIN
    
PSECT code, delta=2, abs
ORG 100h    ; posición 100h para el codigo
;------------- CONFIGURACION ------------
MAIN:
    CALL    CONFIG_PORTS    ; Configuración de I/O
    CALL    CONFIG_RELOJ    ; Configuración de Oscilador
    CALL    CONFIG_TMR0	    ; Configuración de TMR0
    BANKSEL PORTD	    ; Cambio a banco 00
    
LOOP:
    BTFSS   T0IF	    ; Revisamos si ya pasó el tiempo del TMR0
    GOTO    LOOP	    ; Si aún no ha pasado el tiempo, evaluamos bandera nuevamente
    
    ; Cuando se activa la bandera de interrupción del TMR0 se ejectun estas instrucciones
    CALL    REINICIO_TMR0   ; Reinicio del TMR0
    INCF    PORTD	    ; Incrementamos en 1 el PORTD (Extra de lo visto en clase)
    GOTO    LOOP
    
;------------- SUBRUTINAS ---------------
; Se agregó esta subrutina, además de las que trabajamos en clase
; para demostrar el funcionamiento del TMR0.
; Únicamente se configura el PORTD como salida para usarlo como contador. 
CONFIG_PORTS:
    BANKSEL ANSEL	    ; Cambio de banco
    CLRF    ANSEL	    ; I/O digitales
    CLRF    ANSELH	    ; I/O digitales
    BANKSEL TRISD
    CLRF    TRISD	    ; PORTD como salida
    BANKSEL PORTD   
    CLRF    PORTD	    ; APAGAR PORTD 
    RETURN

; Configuramos el uC para usar un oscilador interno a 4MHz    
CONFIG_RELOJ:
    BANKSEL OSCCON
    BSF	    OSCCON, 0; Reloj interno
    BCF	    OSCCON, 4   ; IRCF1
    BSF	    OSCCON, 5	; IRCF2
    BSF	    OSCCON, 6   ; IRCF3 -> IRCF<1:3> = 111 -> 4MHz 
    return
    
; Configuramos el TMR0 para obtener un retardo de 50ms
CONFIG_TMR0:
    BANKSEL OPTION_REG
    BCF	    PSA		; prescaler a TMR0 (NOTA: En clase olvidamos asignar el Prescaler al TMR0)
    BSF	    PS2
    BSF	    PS1
    BSF	    PS0		; prescaler 1 : 256
    BCF	    T0CS	; Incremento con pulsos del reloj interno
    
    BANKSEL TMR0
    MOVLW   61		; Valor calculado en el ejemplo de clase para obtener 50ms 
    MOVWF   TMR0	; Cargamos valor inicial
    BCF	    T0IF	; Limpiamos bandera de TMR0
    return
    
; Cada vez que se cumple el tiempo del TMR0 es necesario reiniciarlo.
REINICIO_TMR0:
    BANKSEL TMR0
    MOVLW   61		; 50ms 
    MOVWF   TMR0	; Cargamos valor inicial
    BCF	    T0IF	; Limpiamos bandera
    return
    
    
    