/*
 * File:   main.c
 * Author: Andrea Barrientos Pineda, 20575
 *
 * Created on 12 de abril de 2022, 09:39 PM
 * 
 * Laboratorio 08: ADC y DAC
 * - Prelab: Leer entrada analógica y mostrar resultado en un contador con LEDs
 * - Lab: Usar interrupciones para controlar dos contador con entrada analógica
 * - Postlab: Contador con entrada analógica, DAC y displays en salida
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

int selector = 0;                   // Display selector indicator
int decimal_counter[3] = {0,0,0};   // Contador en decimal
int display_values[3] = {0,0,0};    // Arreglo para valores de los displays

int adc_temp = 0;

//-------------------- Declaración de funciones --------------------------------
//------------------------------------------------------------------------------

void setup(void);                       // Configuración del PIC
void reset_TMR0(void);                  // Reset del TMR0
void select_display(void);              // Seleccionar display activo
void display_table(int decimal_value);  // Obtener valor para displays

//-------------------- Interrupciones ------------------------------------------
//------------------------------------------------------------------------------

void __interrupt() isr (void)
{
    if (PIR1bits.ADIF == 1)                 // Interrupción del ADC
    {
        if (ADCON0bits.CHS == 0b0000)       // Asignar contador 1 en PORTB
            PORTB = ADRESH;
        
        else if (ADCON0bits.CHS == 0b0001)   // Guardar contador 2
            adc_temp = (int)((ADRESH)*((5.0/255))*100); 
        
        PIR1bits.ADIF = 0;                  // Limpiar bandera del ADC
    }
    
    if (INTCONbits.T0IF)
    {
        reset_TMR0();                       // Reiniciar TMR0
        select_display();                   // Seleccionar display actual
        
        // Convertir adc_temp a valores decimales
        
        if (adc_temp > 100)
        {
            decimal_counter[2] = adc_temp / 100;    // Obtener centenas
            adc_temp -= decimal_counter[2] * 100;
        }
        
        else if (adc_temp > 10)
        {
            decimal_counter[1] = adc_temp / 10;     // Obtener decenas
            adc_temp -= decimal_counter[1] * 10;
        }
        
        else if (adc_temp < 10)
            decimal_counter[0] = adc_temp;          // Obtener unidades
        
        // Asignar valores a displays
        
        if (selector == 1)                      // Display 1: Unidades
            display_table(decimal_counter[0]);
        
        else if (selector == 2)                 // Display 2: Decenas
            display_table(decimal_counter[1]);
        
        else if (selector == 3)                 // Display 3: Centenas
            display_table(decimal_counter[2]);

        INTCONbits.T0IF = 0;    // Limpiar bandera de interrupción T0IF
    }
}

//-------------------- Programa principal --------------------------------------
//------------------------------------------------------------------------------

void main(void)
{
    setup();                        // Configuración del PIC
    __delay_us(40);                 // Delay inicial para el ADC
    
    // Main loop
    while (1)
    {
        if (ADCON0bits.GO == 0)     // Ejecutar si no hay conversión en proceso
        {
            if (ADCON0bits.CHS == 0b0000)       // Canal 0000 -> 0001
                ADCON0bits.CHS = 0b0001;
            
            else if (ADCON0bits.CHS == 0b0001)  // Canal 0001 -> 0000
                ADCON0bits.CHS = 0b0000;
            
            __delay_us(40);         // Delay
            ADCON0bits.GO = 1;      // Iniciar conversión ADC
        }
    }
    
    return;
}

//-------------------- Funciones -----------------------------------------------
//------------------------------------------------------------------------------

void setup(void)                    // Configuración del PIC
{
    // I/O
    ANSEL = 0b00000011;             // ANSEL, Bit 0 como entrada analógica
    ANSELH = 0;                     // I/O digitales
    
    // Oscilador
    OSCCONbits.IRCF = 0b0110;       // 4MHz
    OSCCONbits.SCS = 1;             // Oscilador interno
    
    // Entradas
    TRISA = 0b00000011;             // AN0 y AN1 como entradas
    
    // Salidas
    TRISB = 0;                      // PORTB como salida
    TRISC = 0;                      // PORTC como salida
    TRISD = 0;                      // PORTD como salida
    
    // ADC
    ADCON0bits.ADON = 1;            // Habilitar ADC
    ADCON0bits.CHS = 0b0000;        // Canal para pin AN0
    ADCON0bits.ADCS = 0b01;         // Reloj de conversión: Fosc/8
    
    ADCON1bits.VCFG0 = 0;           // Ref: VDD
    ADCON1bits.VCFG1 = 1;           // Ref: VSS
    ADCON1bits.ADFM = 0;            // Justificado a la izquierda
    
    // Interrupciones
    INTCONbits.GIE = 1;             // Habilitar interrupciones globales
    INTCONbits.PEIE = 1;            // Habilitar interrupciones de perifericos
    
    PIE1bits.ADIE = 1;              // Habilitar interrupciones del ADC
    PIR1bits.ADIF = 0;              // Limpiar bandera del ADC
    
    // Interrupciones de TMR0
    INTCONbits.T0IF = 0;        // Limpiar bandera de interrupción del TMR0
    INTCONbits.T0IE = 1;        // Habilitar interrupciones del TMR0
    OPTION_REGbits.T0CS = 0;    // Limpiar registro T0CS
    OPTION_REGbits.PSA = 0;     // Modo contador del TMR0
    OPTION_REGbits.PS2 = 1;     // 1
    OPTION_REGbits.PS1 = 1;     // 1            -> Prescaler 1:256
    OPTION_REGbits.PS0 = 1;     // 1
    
    // Limpiar puertos
    PORTA = 0;                      // Limpiar PORTA
    PORTB = 0;                      // Limpiar PORTB
    PORTC = 0;                      // Limpiar PORTC
    PORTD = 0;                      // Limpiar PORTD
    
    return;
}

void reset_TMR0(void)           // Reset TMR0
{
    TMR0 = 0;                   // Valor de precarga en TMR0
    INTCONbits.T0IF = 0;        // Limpiar bandera de interrupción de TMR0
    return;
}

void select_display(void)       // Seleccionar display activo
{
    selector++;                 // Incrementar valor del selector
    
    if (selector > 3)           // Reiniciar selector al llegar a 3.
        selector = 0;           
    
    switch (selector)           // Seleccionar display activo
    {
        case 1:                 // Display 1 - Unidades
            PORTD = 4;          // PORTD = 0000 0100
            break;

        case 2:                 // Display 2 - Decenas
            PORTD = 2;          // PORTD = 0000 0010
            break;

        case 3:                 // Display 3 - Centenas
            PORTD = 1;          // PORTD = 0000 0001
            break;
    }
    
    return;
}

void display_table(int decimal_value)   // Valores de segmentos de display
{
    switch (decimal_value)      // Revisar valor en decimal seleccionado
    {
        case 0:                 
            PORTC = 63;         // PORTC: 0011 1111
            break;
            
        case 1:
            PORTC = 6;          // PORTC: 0000 0110
            break;
            
        case 2:
            PORTC = 91;         // PORTC: 0101 1011
            break;
            
        case 3:
            PORTC = 79;         // PORTC: 0100 1111
            break;
            
        case 4:
            PORTC = 102;        // PORTC: 0110 0110
            break;
            
        case 5:
            PORTC = 109;        // PORTC: 0110 1101
            break;
            
        case 6:
            PORTC = 125;        // PORTC: 0111 1101
            break;
            
        case 7:
            PORTC = 7;          // PORTC: 0000 0111
            break;
            
        case 8:
            PORTC = 127;        // PORTC: 0111 1111
            break;
            
        case 9:
            PORTC = 111;        // PORTC: 0110 1111
            break;
    }
    
    return;
}