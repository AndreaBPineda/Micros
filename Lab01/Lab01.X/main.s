;   Archivo:		    main.s
;   Dispositivo:	    PIC16F887
;   Autor:		    Andrea Barrientos Pineda, 20575
;   Compilador:		    pic-as, MPLABX v6.00
;
;   Programa:		    Contador con incremento y decremento en el puerto A
;   Hardware:		    LED en el puerto A; pushbuttons en RBO y RB1
;
;   Creado:		    29 enero, 2022
;   Última modificación:    29 enero, 2022
    
PROCESSOR 16F887 ;definir el tipo de PIC a utilizar
#include <xc.inc>

;configuration word 1
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
    
;configuration word 2
    CONFIG WRT=OFF
    CONFIG BOR4V=BOR40V
    
;variables
    PSECT udata_bank0
	cont_small: DS 1 ;apartar un bit
	cont_big:   DS 1 ;apartar un bit
    
;reset vector instrucctions
    PSECT resVect, class=CODE, abs, delta=2 ;retomar datos del vector
    
    ORG 00h
    resetVec: ;retornar a cierta posición default al resetear el vector
	PAGESEL main
	goto main
	
;configuration
    main: ;definir valores a utilizar
	bsf STATUS, 5
	bsf STATUS, 6
	clrf ANSEL
	clrf ANSELH
	
	bsf STATUS, 5
	bcf STATUS, 6
	clrf TRISA
	
	bcf STATUS, 5
	bcf STATUS, 6
	
;main loop
    loop: ;añadir valor al puerto A, luego llamar delay y reiniciar el loop
	incf PORTA, 1
	call delay_big
	goto loop
	
;subrutinas
    delay_big: ;detalles del delay largo, utilizado en el main loop
	movlw 50
	movwf cont_big
	call delay_small
	decfsz cont_big, 1
	goto $-2
	return
	
    delay_small: ;detalles del delay corto
	movlw 150
	movwf cont_small
	decfsz cont_small, 1
	goto $-1
	return
	
    END


