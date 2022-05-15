/*
 * File:        main.c
 * Author:      Andrea Barrientos Pineda
 *
 * Creado:      9 de mayo 2022
 * Modificado:  14 de mayo 2022
 * 
 * Laboratorio 11
 * Código para "Slave 1"
 */

//-------------------- Config 1 ------------------------------------------------
//------------------------------------------------------------------------------
#pragma config FOSC = INTRC_NOCLKOUT
#pragma config WDTE = OFF
#pragma config PWRTE = OFF
#pragma config MCLRE = OFF
#pragma config CP = OFF
#pragma config CPD = OFF
#pragma config BOREN = OFF
#pragma config IESO = OFF
#pragma config FCMEN = OFF
#pragma config LVP = ON

//-------------------- Config 2 ------------------------------------------------
//------------------------------------------------------------------------------
#pragma config BOR4V = BOR40V
#pragma config WRT = OFF

//-------------------- Librerias -----------------------------------------------
//------------------------------------------------------------------------------
#include <xc.h>
#include <stdint.h>

//-------------------- Constantes ----------------------------------------------
//------------------------------------------------------------------------------
#define _XTAL_FREQ 1000000

//-------------------- Variables -----------------------------------------------
//------------------------------------------------------------------------------
uint8_t counter = 0;

//-------------------- Declaración de funciones --------------------------------
//------------------------------------------------------------------------------
void setup(void);

//-------------------- Interrupciones ------------------------------------------
//------------------------------------------------------------------------------
void __interrupt() isr (void)
{
    if (PIR1bits.SSPIF)
    {
        PIR1bits.SSPIF = 0;         // Limpiar bandera de interrupcion
    }
    
    if (INTCONbits.RBIF)
    {
        if (!PORTBbits.RB0)         // Aumentar contador
        {
            counter++;
            PORTD++;
        }
        
        else if (!PORTBbits.RB1)    // Decrecer contador
        {
            counter--;
            PORTD--;
        }
        
        INTCONbits.RBIF = 0;        // Limpiar bandera de interrupcion
    }
    
    return;
}

//-------------------- Programa principal --------------------------------------
//------------------------------------------------------------------------------
void main(void)
{
    setup();
    
    while (1)
    {
        SSPBUF = counter;           // Enviar contador
    }
    
    return;
}

void setup(void)
{
    // I/O
    ANSEL = 0;
    ANSELH = 0;
    
    // Entradas y salidas
    TRISA = 0x20;
    TRISB = 0x03;
    TRISC = 0x18;
    TRISD = 0x00;
    TRISE = 0x00;
    
    PORTA = 0;
    PORTB = 0;
    PORTC = 0;
    PORTD = 0;
    PORTE = 0;
    
    // Oscilador
    OSCCONbits.IRCF = 0b100;        // 1MHz
    OSCCONbits.SCS = 1;             // Reloj interno
    
    // PORTB
    OPTION_REGbits.nRBPU = 0;      // Resistencias pull-up
    WPUBbits.WPUB0 = 1;            // Resistencias pull-up en RB0
    WPUBbits.WPUB1 = 1;            // Resistencias pull-up en RB1
    
    // SPI
    SSPCONbits.SSPM = 0b0100;       // SPI: Slave mode, Clock: Fosc/4
    SSPCONbits.CKP = 0;             // Reloj inactivo al inicio
    SSPCONbits.SSPEN = 1;           // Habilitar pines del SPI
    SSPSTATbits.CKE = 1;            // Transmitir en flanco positivo
    SSPSTATbits.SMP = 1;            // Enviar al final del pulso de reloj
    
    // Interrupciones
    INTCONbits.GIE = 1;             // Globales
    INTCONbits.PEIE = 1;            // Perifericas
    INTCONbits.RBIE = 1;            // PORTB
    IOCBbits.IOCB0 = 1;             // On-change RB0
    IOCBbits.IOCB1 = 1;             // On-change RB1
    PIE1bits.SSPIE = 1;             // SPI
    
    // Banderas
    INTCONbits.RBIF = 0;            // PORTB
    PIR1bits.SSPIF = 0;             // SPI
}