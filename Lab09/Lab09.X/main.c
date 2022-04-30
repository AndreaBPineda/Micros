/*
 * File:            main.c
 * Author:          Andrea Barrientos Pineda, 20575
 *
 * Creado:          24 de abril de 2022
 * Modificado:      24 de abril de 2022
 * 
 * Laboratorio 09:  PWM
 *      - Prelab: Generar PWM para controloar todo el movimiento de un servo.
 *      - Lab: Generar un PWM para controlar también un segundo servo.
 *      - Postlab:
 *          - Utilizar un tercer PWM manual para regular el brillo de un LED
 *          - PWM: utilizar un timer para interrupciones y aumentar un contador.
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

#define _XTAL_FREQ  4000000             // Constante para __delay_us
#define IN_MIN      0                   // Min. entrada del potenciómetro
#define IN_MAX      255                 // Max. entrada del potenciómetro
#define OUT_MIN     0                   // Min. ancho de pulso del PWM
#define OUT_MAX     500                 // Max. ancho de pulso del PWM

//-------------------- Variables --------------------------------
//------------------------------------------------------------------------------

uint8_t conversion = 0;                 // Conversion ADC para el valor del LED
uint8_t counter = 0;                    // Contador para el PWM manual

//-------------------- Declaración de funciones --------------------------------
//------------------------------------------------------------------------------

void setup(void);                      // Configuración del PIC
void reset_TMR0(void);                     // Resetear TMR0

//-------------------- Interrupciones ------------------------------------------
//------------------------------------------------------------------------------

void __interrupt() isr (void)           // Interrupciones
{
    if (PIR1bits.ADIF)                  // Interrupción del ADC
    {
        if (ADCON0bits.CHS == 0b0000)
        {
            CCPR1L = (ADRESH>>1)+123;
            CCP1CONbits.DC1B = (ADRESH & 0b01);
            CCP1CONbits.DC1B0 = (ADRESL>>7);
        }
        
        else if (ADCON0bits.CHS == 0b0001)
        {
            CCPR2L = (ADRESH>>1)+123;
            CCP1CONbits.DC1B = (ADRESH & 0b01);
            CCP1CONbits.DC1B0 = (ADRESL>>7);
        }
        
        else if (ADCON0bits.CHS == 0b0010)
        {
            conversion = ADRESH;
        }
        
        PIR1bits.ADIF = 0;              // Limpiar bandera de interrupción
    }
    
    if (INTCONbits.T0IF)                // Interrupcion del TMR0
    {
        reset_TMR0();                   // Resetear TMR0
        counter++;                      // Aumentar contador
        PORTB = counter;
        
        if (counter == 0)
        {
            PORTDbits.RD0 = 1;   // Encender el bit si el contador es 0
        }
        
        if (counter == conversion) // Apagar al llegar al valor del ADC
        {
            PORTDbits.RD0 = 0;
        }
        
        INTCONbits.T0IF = 0;
    }
}

void main(void)                         // Main program
{
    setup();                            // Configuración del PIC
    reset_TMR0();                       // Resetear el TMR0
    __delay_us(50);                     // Delay inicial para el ADC
    
    while (1)                           // Main loop
    {
        if (ADCON0bits.GO == 0)         // Si no hay conversión en proceso
        {
            if (ADCON0bits.CHS == 0b0000)       // Canal 0000 -> 0001
            {
                ADCON0bits.CHS = 0b0001;
            }
            
            else if (ADCON0bits.CHS == 0b0001)  // Canal 0001 -> 0000
            {
                ADCON0bits.CHS = 0b0010;
            }
            
            else if (ADCON0bits.CHS == 0b0010)   // Canal 0010 -> 0000
            {
                ADCON0bits.CHS = 0b0000;
            }
            
            __delay_us(50);             // Delay
            ADCON0bits.GO = 1;          // Iniciar conversión ADC
        }
    }
    
    return;
}

void setup(void)                        // Configuración del PIC
{
    // I/O
    ANSEL = 0b00000111;                 // Entradas analógicas (1) 
    ANSELH = 0;                         // I/O digitales
    
    // Oscilador
    OSCCONbits.IRCF = 0b0111;           // 4MHz
    OSCCONbits.SCS = 1;                 // Oscilador interno
    
    // Entradas
    TRISA = 0b00000111;                 // Bit 1 de PORTA como entrada
    PORTA = 0;                          // Limpiar PORTA
    
    TRISB = 0;                          // PORTB como salida digital
    PORTB = 0;                          // Limpiar PORTB
    
    TRISD = 0;                          // PORTD como salida digital
    PORTD = 0;                          // Limpiar PORTD
    
    // ADC
    ADCON0bits.ADCS = 0b01;             // Reloj de conversión: Fosc/8
    ADCON0bits.CHS = 0b0000;            // Canal para pin AN0
    ADCON1bits.VCFG0 = 0;               // Ref: VDD
    ADCON1bits.VCFG1 = 0;               // Ref: VSS
    ADCON1bits.ADFM = 0;                // Justificado a la izquierda
    ADCON0bits.ADON = 1;                // Habilitar ADC

    TRISCbits.TRISC2 = 1;               // Deshabilitar salida en CCP1
    CCP1CONbits.P1M = 0;                // Modo Single Output
    CCP1CONbits.CCP1M = 0b1100;         // PWM 1
    CCP2CONbits.CCP2M = 0b1111;         // PWM 2 
    
    CCPR1L = 0x0F;                    
    CCP1CONbits.DC1B = 0;     
    CCPR2L = 0x0F;
    
    PORTC = 0;
    TRISC = 0xFF;
    PR2 = 250;               
    
    T2CONbits.T2CKPS = 0b11;
    T2CONbits.TMR2ON = 1;
    PIR1bits.TMR2IF = 0;

    while(PIR1bits.TMR2IF == 0);
        PIR1bits.TMR2IF = 0;
        TRISC = 0;
    
    TRISCbits.TRISC2 = 0;               // Habilitar salida de PWM
    
    // TMR0
    OPTION_REGbits.T0CS = 0;            // Reloj interno para el TMR0
    OPTION_REGbits.T0SE = 0;            // Flanco de reloj ascendente
    OPTION_REGbits.PS2 = 1;             // 
    OPTION_REGbits.PS1 = 1;             //    -> Prescaler: 1:256
    OPTION_REGbits.PS0 = 1;             //
    
    // Interrupciones
    INTCONbits.GIE = 1;                 // Habilitar interrupciones globales
    INTCONbits.PEIE = 1;                // Habilitar interrupciones perifericas
    
    PIE1bits.ADIE = 1;                  // Habilitar interrupciones del ADC
    PIR1bits.ADIF = 0;                  // Limpiar bandera del ADC
    
    INTCONbits.T0IF = 0;                // Limpiar bandera de interrupción TMR0
    INTCONbits.T0IE = 1;                // Habilitar interrupciones del TMR0
    
    return;
}

void reset_TMR0(void)           // Resetear TMR0
{
    TMR0 = 0;                   // Valor de precarga en TMR0
    INTCONbits.T0IF = 0;        // Limpiar bandera de interrupción de TMR0
    return;
}