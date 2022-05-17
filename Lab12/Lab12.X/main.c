/*
 * File:        main.c
 * Author:      Andrea Barrientos Pineda, 20575
 *
 * Creado:      16 de mayo 2022
 * Modificado:  16 de mayo 2022
 * 
 * Laboratorio 12: EEPROM
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

//-------------------- Librerías -----------------------------------------------
//------------------------------------------------------------------------------
#include <xc.h>
#include <stdint.h>

//-------------------- Constantes ----------------------------------------------
//------------------------------------------------------------------------------
#define _XTAL_FREQ 4000000          // Constante para __delay_us

//-------------------- Variables -----------------------------------------------
//------------------------------------------------------------------------------
uint8_t data_ADC = 0;

//-------------------- Declaracion de funciones --------------------------------
//------------------------------------------------------------------------------
void setup(void);
void write_EEPROM(uint8_t address, uint8_t data);

uint8_t read_EEPROM(uint8_t address);

//-------------------- Interrupciones ------------------------------------------
//------------------------------------------------------------------------------
void __interrupt() isr (void)
{
    if (PIR1bits.ADIF)
    {
        data_ADC = ADRESH;
        PORTD = data_ADC;
        PIR1bits.ADIF = 0;
    }
    
    if (INTCONbits.RBIF)
    {
        if (!PORTBbits.RB0)
        {
            write_EEPROM(0, data_ADC);
            SLEEP();
        }
        
        INTCONbits.RBIF = 0;
    }
}

//-------------------- Programa principal --------------------------------------
//------------------------------------------------------------------------------
void main(void) 
{
    setup();
    
    while (1)
    {
        if (!ADCON0bits.GO)
        {
            ADCON0bits.GO = 1;
        }
        
        PORTC = read_EEPROM(0);
        __delay_ms(10);
    }
    
    return;
}

void setup(void)
{
    // I/O
    ANSEL = 0x01;                   // Entrada analogica en pin 0
    ANSELH = 0x00; 
    
    // Entradas y salida
    TRISA = 0x01;                   // Entrada en RA0
    TRISB = 0x01;                   // Entrada en RB0
    TRISC = 0x00;                   // Salida
    TRISD = 0x00;                   // Salida
    
    PORTA = 0;                      // Limpiar PORTA
    PORTB = 0;                      // Limpiar PORTB
    PORTC = 0;                      // Limpiar PORTC
    PORTD = 0;                      // Limpiar PORTD
    
    // Oscilador
    OSCCONbits.IRCF = 0b0110;       // 4MHz
    OSCCONbits.SCS = 1;             // Reloj interno
    
    // PORTB
    OPTION_REGbits.nRBPU = 0;      // Resistencias pull-up
    WPUBbits.WPUB0 = 1;            // Resistencias pull-up en RB0
    WPUBbits.WPUB1 = 1;            // Resistencias pull-up en RB1
    
    // ADC
    ADCON0bits.ADON = 1;            // Habilitar ADC
    ADCON0bits.CHS = 0b0000;        // Canal para pin AN0
    ADCON0bits.ADCS = 0b01;         // Reloj de conversión: Fosc/8
    
    ADCON1bits.VCFG0 = 0;           // Ref: VDD
    ADCON1bits.VCFG1 = 1;           // Ref: VSS
    ADCON1bits.ADFM = 0;            // Justificado a la izquierda
    
    // Interrupciones
    INTCONbits.GIE = 1;             // Globales
    INTCONbits.PEIE = 1;            // Perifericas
    PIE1bits.ADIE = 1;              // ADC
    INTCONbits.RBIE = 1;            // PORTB
    IOCBbits.IOCB0 = 1;             // On-change RB0
    IOCBbits.IOCB1 = 1;             // On-change RB1
    
    // Banderas
    INTCONbits.RBIF = 0;            // PORTB
    PIR1bits.ADIF = 0;              // ADC
    PIR1bits.SSPIF = 0;             // MSSP
}

void write_EEPROM(uint8_t address, uint8_t data)
{
    EEADR = address;
    EEDAT = data;
    
    EECON1bits.EEPGD = 0;           // Escribir EEPROM
    EECON1bits.WREN = 1;            // Habilitar escritura EEPROM
    
    INTCONbits.GIE = 0;             // Deshabilitar interrupciones
    EECON2 = 0x55;
    EECON2 = 0xAA;
    
    EECON1bits.WR = 1;              // Iniciar escritura
    
    EECON1bits.WREN = 0;            // Deshabilitar escritura EEPROM
    INTCONbits.RBIF = 0;            // Limpiar bandera de interrupcion
    INTCONbits.GIE = 1;             // Habilitar interrupciones
    
    return;
}

uint8_t read_EEPROM(uint8_t address)
{
    EEADR = address;
    EECON1bits.EEPGD = 0;           // Lectura EEPROM
    EECON1bits.RD = 1;              // Obtener dato de la EEPROM
    
    return EEDAT;                   // Retornar valor leido
}