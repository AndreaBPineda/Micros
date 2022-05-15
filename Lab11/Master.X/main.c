/*
 * File:        main.c
 * Author:      Andrea Barrientos Pineda
 *
 * Creado:      9 de mayo 2022
 * Modificado:  14 de mayo 2022
 * 
 * Laboratorio 11
 * Codigo para PIC: "Master"
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
#pragma config LVP = OFF

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
uint8_t data_ADC = 0;

//-------------------- Declaración de funciones --------------------------------
//------------------------------------------------------------------------------
void setup(void);

//-------------------- Interrupciones ------------------------------------------
//------------------------------------------------------------------------------
void __interrupt() isr (void)
{
    // Interrupcion ADC
    if (PIR1bits.ADIF)
    {
       data_ADC = ADRESH;               // Almacenar valor del ADC
       PIR1bits.ADIF = 0;               // Limpiar bandera de interrupcion
    }
    
    // Interrupcion SPI
    if (PIR1bits.SSPIF)
    {
        PIR1bits.SSPIF = 0;             // Limpiar bandera de interrupcion
    }
    
    return;
}

//-------------------- Programa principal --------------------------------------
//------------------------------------------------------------------------------
void main(void)
{
    setup();
    __delay_us(50);
    
    while (1)
    {
        // Iniciar conversion ADC
        if (ADCON0bits.GO == 0)
        {
            __delay_us(50);
            ADCON0bits.GO = 1;
        } 
        
        // SPI
        PORTAbits.RA7 = 0;              // Activar Esclavo 1
        PORTAbits.RA6 = 1;              // Desactivar Esclavo 2
        __delay_ms(10);
        
        if (!PORTAbits.RA7)
        {
            while(!SSPSTATbits.BF);     // Esperar a terminar lectura de datos
            PORTD = SSPBUF;             // Enviar datos recibidos a PORTB
        }
        
        __delay_ms(10);
        PORTAbits.RA7 = 1;              // Desactivar Esclavo 1
        PORTAbits.RA6 = 0;              // Activar Esclavo 2
        __delay_ms(10);
        
        if (!PORTAbits.RA6)
        {
            SSPBUF = data_ADC;          // Transmitir valor del ADC
        }
    }
    
    return;
}

void setup(void)
{
    // I/O
    ANSEL = 0x01;
    ANSELH = 0x00;
    
    // Entradas y salidas
    TRISA = 0x01;
    TRISB = 0x00;
    TRISC = 0x10;
    TRISD = 0x00;
    
    // Limpiar puertos
    PORTA = 0;
    PORTB = 0;
    PORTC = 0;
    PORTD = 0;
    
    // Oscilador
    OSCCONbits.IRCF = 0b100;        // 1MHz
    OSCCONbits.SCS = 1;             // Reloj interno
    
    // ADC
    ADCON0bits.ADCS = 0b01;         // Reloj de conversión: Fosc/8
    ADCON0bits.CHS = 0b0000;        // Canal para pin AN0
    ADCON1bits.VCFG0 = 0;           // Ref: VDD
    ADCON1bits.VCFG1 = 0;           // Ref: VSS
    ADCON1bits.ADFM = 0;            // Justificado a la izquierda
    ADCON0bits.ADON = 1;            // Habilitar ADC
    
    // SPI
    SSPCONbits.SSPM = 0b0000;       // SPI: Master mode, Clock: Fosc/4
    SSPCONbits.CKP = 0;             // Reloj inactivo al inicio
    SSPCONbits.SSPEN = 1;           // Habilitar pines del SPI
    SSPSTATbits.CKE = 1;            // Transmitir en flanco positivo
    SSPSTATbits.SMP = 1;            // Transmitir al final del pulso de reloj
    
    // Interrupciones
    INTCONbits.GIE = 1;             // Globales
    INTCONbits.PEIE = 1;            // Perifericas
    PIE1bits.ADIE = 1;              // ADC
    PIE1bits.SSPIE = 1;             // SPI
    
    // Banderas
    PIR1bits.ADIF = 0;              // ADC
    PIR1bits.SSPIF = 0;             // SPI
    
    SSPBUF = 0x00;                  // Valor inicial
}