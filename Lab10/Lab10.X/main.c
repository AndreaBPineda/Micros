/*
 * File:            main.c
 * Author:          Andrea Barrientos Pineda, 20575
 *
 * Creado:          2 de mayo 2022
 * Modificado:      7 de mayo 2022
 * 
 * Laboratorio 10: Comunicación serial
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
char value_prev;                        // Valor previo del mensjae
char mensaje[5] = "ASCII";           // Mensaje a enviar

int conversion = 0;                 // Valor de conversion ADC
uint8_t indice = 0;                     // Indice del mensaje
uint8_t data = 0;                       // Valor recibido en comunicación serial

//-------------------- Funciones -----------------------------------------------
//------------------------------------------------------------------------------

void setup(void);
void print(char str[]);

//-------------------- Interrupciones ------------------------------------------
//------------------------------------------------------------------------------

void __interrupt() isr (void)
{    
    // ADC: Interrupción
    if (PIR1bits.ADIF)
    {
        conversion = ADRESH;
        PIR1bits.ADIF = 0;
    }
    
    // Comunicación serial: Interrupción
    if (PIR1bits.RCIF)               // Recepción de datos
    { 
        data = RCREG;
    }
    
    return;
}

//-------------------- Programa principal --------------------------------------
//------------------------------------------------------------------------------
void main(void)
{
    setup();                        // Configuracio? del PIC
    __delay_us(50);                 // Delay inicial
    
    while(1)
    {   
        // ADC: Iniciar conversión si no hay una en proceso
        if (ADCON0bits.GO == 0)
        {
            __delay_us(50);
            ADCON0bits.GO = 1;
        }
        
        // Comunicación serial: Mandar valor a la terminal
        if (value_prev != ' ')
        {   
            print("\r Menu principal: \r");
            print("1. Leer potenciometro \r");
            print("2. Leer ASCII \r");
            
            while(PIR1bits.RCIF == 0);
            
            switch (data)
            {
                case '1':
                    print((char*)conversion);
                    print("\r");
                    break;
                    
                case '2':
                    print(mensaje);
                    print("\r");
                    break;
            }
                
            break;
        }
    }
    
    return;
}

void setup(void)
{
    // I/O 
    ANSEL = 0b00000001;
    ANSELH = 0;                 // I/O digitales
    
    // Oscilador
    OSCCONbits.IRCF = 0b100;    // 1MHz
    OSCCONbits.SCS = 1;         // Oscilador interno
    
    // Entradas
    TRISA = 0b00000001;         // Entrada analógica en Bit 0 (RA0).
    PORTA = 0;                  // Limpiar PORTA
    
    // Salidas
    TRISB = 0;
    PORTB = 0;                  // PORTD como salida
    
    // ADC
    ADCON0bits.ADCS = 0b01;     // Reloj de conversión: Fosc/8
    ADCON0bits.CHS = 0b0000;    // Canal a utilizar
    ADCON1bits.VCFG0 = 0;       // Ref: VDD 
    ADCON1bits.VCFG1 = 0;       // Ref: VSS
    ADCON1bits.ADFM = 0;        // Justificado a la izquierda
    ADCON0bits.ADON = 0;        // Habilitar ADC
    
    // Comunicación serial
    TXSTAbits.SYNC = 0;         // Comunicación ascincrona (full-duplex)
    TXSTAbits.BRGH = 1;         // Baud rate de alta velocidad 
    BAUDCTLbits.BRG16 = 1;      // 16-bits para generar el baud rate
    
    SPBRG = 25;
    SPBRGH = 0;                 // Baud rate ~9600, error -> 0.16%
    
    RCSTAbits.SPEN = 1;         // Habilitar comunicación
    TXSTAbits.TX9 = 0;          // Utilizar solo 8 bits
    TXSTAbits.TXEN = 1;         // Habilitar transmisor
    RCSTAbits.CREN = 1;         // Habilitar receptor
    
    // Interrupciones
    INTCONbits.GIE = 1;         // Habilitar interrupciones globales
    INTCONbits.PEIE = 1;        // Habilitar interrupciones de perifericos
    PIE1bits.RCIE = 1;          // Habilitar Interrupciones de recepción
}

void print(char str[])
{   
    uint8_t index = 0;
    
    while (str[index]!= '\0')
    {
        if (PIR1bits.TXIF)
        {             
            TXREG = str[index];    
            index++;                   
        }
    }
}