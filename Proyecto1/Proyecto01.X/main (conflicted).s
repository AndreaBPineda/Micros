;   ARCHIVO:		main.s
;   DISPOSITIVO:	PIC16F887
;   AUTOR:		Andrea Barrientos Pineda (Carnet: 20575)
;   COMPILADOR:		pic-as (v2.32), MPLABX v6.00
;
;   PROGRAMA:		Proyecto 1: Reloj digital
;   HARDWARE:		    
;	- ENTRADAS:
;	    - Pushbutton 01 - Modo de edicion		(PORTB: RB0)
;	    - Pushbutton 02 - Navegacion		(PORTB: RB1)
;	    - Pushbutton 03 - Incrementar/iniciar	(PORTB: RB2)
;	    - Pushbutton 04 - Decrementar/detener	(PORTB: RB3)
;	- SALIDAS:
;	    - Display de 7 segmentos y 4 digitos - Pantalla del reloj
;		- Segmentos de displays			(PORTC: RC0-RC7)
;		- Selectores de displays		(PORTD: RD0-RD4)
;		- Segmento de puntos centrales		(PORTD: RD5)
;	    - Buzzer - alarma				(PORTE: RE0-RE2)
;
;   CREADO:		05/03/2022
;   MODIFICADO:		05/03/2022


