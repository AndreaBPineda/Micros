/*
 * File:   main.c
 * Author: Andrea Barrientos Pineda, 20575
 *
 * Created on 4 de abril de 2022, 12:16 PM
 * 
 * Laboratorio 07: Programación en C
 * - Prelab: Contador con botones
 * - Lab: Contador en TMR0
 * - Postlab: Contador de PORTA en displays de 7 segmentos
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

#define PB0 PORTBbits.RB0           // Pushbutton 1: Aumentar contador
#define PB1 PORTBbits.RB1           // Pushbutton 2: Decrecer contador

//------------------- Variables ------------------------------------------------
//------------------------------------------------------------------------------

int selector = 0;                   // Display selector indicator
int decimal_counter[3] = {0,0,0};   // Arreglo para guardar contador decimal
int display_values[3] = {0,0,0};    // Arreglo para valores de los displays

int counter_temp = 0;               // Variable temporal para PORTA.

//-------------------- Declaración de funciones --------------------------------
//------------------------------------------------------------------------------

void setup(void);                       // Configuración del PIC
void reset_TMR0(void);                  // Reset del TMR0
void select_display(void);              // Seleccionar display activo
void display_table(int decimal_value);  // Obtener valor para displays

//-------------------- Interrupciones ------------------------------------------
//------------------------------------------------------------------------------

void __interrupt() isr (void)       // Interrupciones
{
    // Interrupción de PORTB:
    
    if (INTCONbits.RBIF)            // Ejecutar si la bandera RBIF está activa
    {
        if (!PB0)                   // Revisar si se presionó el botón 1
        {
            decimal_counter[0]++;   // Aumentar unidades del contador decimal
            PORTA++;                // Aumentar contador en PORTA
        }
   
        else if (!PB1)              // Revisar si se presionó el botón 2
        {
            decimal_counter[0]--;   // Decrecer unidades del contador decimal
            PORTA--;                // Decrecer contador en PORTA
        }
        
        INTCONbits.RBIF = 0;        // Limpiar bandera de interrupción RBIF
    }
    
    // Interrupción de TMR0:
    
    if (INTCONbits.T0IF)        // Ejecutar si la bandera está activa.
    {
        reset_TMR0();                           // Reiniciar TMR0
        select_display();                       // Seleccionar display activo
        
        // Overflow del contador:
        
        if (decimal_counter[0] > 9)             // Overflow de unidades
        {
            decimal_counter[0] = 0;             // Regresar unidades a 0
            decimal_counter[1]++;               // Aumentar decenas
        }
        
        else if (decimal_counter[1] > 9)        // Overflow de decenas
        {
            decimal_counter[1] = 0;             // Regresar decenas a 0
            decimal_counter[2]++;               // Aumentar centenas
        }
        
        else if (decimal_counter[2] > 9)        // Overflow de centenas
        {
            decimal_counter[0] = 0;             // Regresar unidades a 0
            decimal_counter[1] = 0;             // Regresar decenas a 0
            decimal_counter[2] = 0;             // Regresar centenas a 0
        }
        
        // Underflow del contador:
        
        if (decimal_counter[0] < 0)             // Underflow de unidades
        {
            decimal_counter[0] = 9;             // Regresar unidades a 9
            decimal_counter[1]--;               // Decrecer decenas
            
            if (decimal_counter[1] < 0)         // Underflow de decenas
            {
                decimal_counter[1] = 9;         // Regresar decenas a 9
                decimal_counter[2]--;           // Decrecer centenas
            }
            
            else if (decimal_counter[2] < 0)    // Underflow de centenas 
                decimal_counter[2] = 9;         // Regresar centenas a 9
        }
        
        // Asignar valores a displays
        
        if (selector == 1)                      // Display 1: Unidades
            display_table(decimal_counter[0]);
        
        else if (selector == 2)                 // Display 2: Decenas
            display_table(decimal_counter[1]);
        
        else if (selector == 3)                 // Display 3: Centenas
            display_table(decimal_counter[2]);

        INTCONbits.T0IF = 0;    // Limpiar bandera de interrupción T0IF
    }
    
    return;
}

//-------------------- Programa principal --------------------------------------
//------------------------------------------------------------------------------

void main(void)
{
    setup();                    // Configuración del PIC
    
    // Main loop
    while (1) {}
    
    return;
}

//-------------------- Funciones -----------------------------------------------
//------------------------------------------------------------------------------

void setup(void)                // Configuración del PIC
{
    // I/O
    ANSEL = 0;                  // Entradas/salidas digitales
    ANSELH = 0;                 // Entradas/salidas digitales
    
    // Oscilador
    OSCCONbits.IRCF = 0b0111;   // 4MHz
    OSCCONbits.SCS = 1;         // Oscilador interno
    
    // Entradas
    TRISBbits.TRISB0 = 1;       // RB0 como entrada
    TRISBbits.TRISB1 = 1;       // RB1 como entrada
    
    // Salidas
    TRISA = 0;                  // PORTA como salida
    TRISC = 0;                  // PORTC como salida
    TRISD = 0;                  // PORTD como salida
    
    // Puertos
    OPTION_REGbits.nRBPU = 0;   // Habilitar resistencias pull-up en PORTB
    WPUBbits.WPUB0 = 1;         // Habilitar resistencia pull-up de RB0
    WPUBbits.WPUB1 = 1;         // Habilitar resistencia pull-up de RB1
    
    // Interrupciones generales
    INTCONbits.GIE = 1;         // Habilitar interrupciones globales
    
    // Interrupciones de PORTB
    INTCONbits.RBIE = 1;        // Habilitar interrupciones de PORTB
    IOCBbits.IOCB0 = 1;         // Habilitar interrupción on-change en RB0
    IOCBbits.IOCB1 = 1;         // Habilitar interrupción on-change en RB1
    INTCONbits.RBIF = 0;        // Limpiar bandera de interrupción
    INTCONbits.PEIE = 1;        // Habilitar interrupciones de perifericos
    
    // Interrupciones de TMR0
    INTCONbits.T0IF = 0;        // Limpiar bandera de interrupción del TMR0
    INTCONbits.T0IE = 1;        // Habilitar interrupciones del TMR0
    OPTION_REGbits.T0CS = 0;    // Limpiar registro T0CS
    OPTION_REGbits.PSA = 0;     // Modo contador del TMR0
    OPTION_REGbits.PS2 = 1;     // 1
    OPTION_REGbits.PS1 = 1;     // 1            -> Prescaler 1:256
    OPTION_REGbits.PS0 = 1;     // 1
    
    // Limpiar puertos
    PORTA = 0;                  // Clean PORTA
    PORTB = 0;                  // Clean PORTB
    PORTC = 0;                  // Clean PORTC
    PORTD = 0;                  // Clean PORTD
    
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