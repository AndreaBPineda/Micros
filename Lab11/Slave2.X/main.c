/*
 * File:        main.c
 * Author:      Andrea Barrientos Pineda
 *
 * Creado:      14 de mayo 2022
 * Modificado:  14 de mayo 2022
 * 
 * Laboratorio 11
 * Código para "Slave 2"
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
    
    return;
}

//-------------------- Programa principal --------------------------------------
//------------------------------------------------------------------------------
void main(void)
{
    setup();
    
    while (1)
    {
        CCPR1L = (SSPBUF>>1) + 123;
        CCP1CONbits.DC1B = (SSPBUF & 0b01);
        CCP1CONbits.DC1B0 = (ADRESL>>7);
        
        PORTD = SSPBUF;
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
    TRISB = 0x00;
    TRISC = 0x1C;
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
    
    // CCP1
    CCP1CONbits.P1M = 0;
    CCP1CONbits.CCP1M = 0b1100;
    CCPR1L = 0x0F;
    CCP1CONbits.DC1B = 0;
    
    // SPI
    SSPCONbits.SSPM = 0b0100;       // SPI: Slave mode, Clock: Fosc/4
    SSPCONbits.CKP = 0;             // Reloj inactivo al inicio
    SSPCONbits.SSPEN = 1;           // Habilitar pines del SPI
    SSPSTATbits.CKE = 1;            // Transmitir en flanco positivo
    SSPSTATbits.SMP = 1;            // Enviar al final del pulso de reloj
    
    // Interrupciones
    INTCONbits.GIE = 1;             // Globales
    INTCONbits.PEIE = 1;            // Perifericas
    PIE1bits.SSPIE = 1;             // SPI
    
    // Banderas
    PIR1bits.SSPIF = 0;             // SPI
}