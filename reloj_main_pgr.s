/*	
    Archivo:		reloj_main_pgr.s
    Dispositivo:	PIC16F887
    Autor:		Gerardo Paz 20173
    Compilador:		pic-as (v2.30), MPLABX V6.00

    Programa:		Proyecto No. 1 (Reloj) 
    Hardware:		LEDS de modos y puntos del reloj en puerto A
			Botones en el puerto B con pull ups internos
			Alarmas del timer y de la hora en el puerto B
			Leds indicadores de estado para el timer y la alarma en puerto E
			Selectores de displays en puerto D
			Displays de 7 segmentos en puerto C

    Creado:			09/03/2022
    Última modificación:	17/03/2022	    
*/
    
PROCESSOR 16F887
#include <xc.inc>

; CONFIG1
CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
CONFIG  LVP = OFF              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)   

 /*----------------- Librería de Macros --------------------*/
 reset_timer0 macro
    BANKSEL TMR0
    MOVLW   236		    // Cargamos N en W
    MOVWF   TMR0	    // Cargamos N en el TMR0, listo el retardo
    BCF	    T0IF	    // Limpiar bandera de interrupción
    ENDM
    
 reset_timer1 macro
    BANKSEL T1CON
    MOVLW   0x0B
    MOVWF   TMR1H	// B en parte alta
    MOVLW   0xDC	
    MOVWF   TMR1L	// DC en parte baja - cargado .3036
    BCF	    TMR1IF	// Limpiar bandera
    ENDM 
    
 set_display macro x1, x2, x3, x4
    MOVF    x1, W
    CALL    tabla_7seg	    // Codificación
    MOVWF   DISPLAY	    // Preparar display1 con unidades
    
    MOVF    x2, W
    CALL    tabla_7seg
    MOVWF   DISPLAY+1	    // Preparar display2 con decenas
    
    MOVF    x3, W
    CALL    tabla_7seg
    MOVWF   DISPLAY+2	    // Preparar display3 con unidades
    
    MOVF    x4, W
    CALL    tabla_7seg
    MOVWF   DISPLAY+3	    // Preparar display4 con unidades
 
    ENDM
    
 /*---------------- RESET ----------------*/
 PSECT resVect, class=CODE, abs, delta=2	
 ORG 00h					
 resVect:
       PAGESEL main
       GOTO    main
       
 /*--------------- Variables --------------*/ 
 
 LED_ALARMA	EQU 3
 LED_TIMER	EQU 2
 LED_FECHA	EQU 1
 LED_HORA	EQU 0
	
 LED_EDIT1	EQU 7
 LED_EDIT2	EQU 6
	
 LED_DOT1	EQU 4
 LED_DOT2	EQU 5

 LED_ALARMA_ON	EQU 0
 LED_TIMER_ON	EQU 1

 ALARMA_TIMER	EQU 6
 ALARMA_ALARMA	EQU 7
	
 SEL0	EQU 0
 SEL1	EQU 1
 SEL2	EQU 2
 SEL3	EQU 3
	
 BMODO	EQU 0
 UP	EQU 1
 DOWN	EQU 2
 EDIT	EQU 3
 PLAY	EQU 4
 
 PSECT udata_bank0
 MODO:	    DS  1   
 MODO_EDIT: DS  1   
    
 W_TEMP:	DS  1	    
 STATUS_TEMP:	DS  1
    
 SEGUNDOS1:	DS  1
 SEGUNDOS2:	DS  1
 MINUTOS1:	DS  1
 MINUTOS2:	DS  1
 HORAS1:	DS  1
 HORAS2:	DS  1
 DIAS1:		DS  1	//  0x33
 DIAS2:		DS  1	//  0x34
 MES1:		DS  1	//  0x35
 MES2:		DS  1	//  0x36    Dos variables para cada uno (unidades y decenas)
    
 TEMP_TABLA_DIAS:   DS	1   //	0x37
 TEMP_SUMA:	    DS  1   //	0x38
 TEMP_DIAS1_DIAS2:  DS	1   //	0x39
 TEMP_MES1_MES2:    DS	1
    
 TEMP:		    DS  1
 TEMP_VALOR_TIMER:  DS	1
 PLAY_TIMER:	    DS	1
 TIMER_BANDERA:	    DS	1
    
 PLAY_ALARMA:	    DS	1
 ALARMA_BANDERA:    DS	1
 ALARMA_DIGITS:	    DS	1
    
 W_TABLA:	DS  1
    
 TSEGUNDOS1:	DS  1
 TSEGUNDOS2:	DS  1
 TMINUTOS1:	DS  1
 TMINUTOS2:	DS  1	    // Variables para el timer
    
 AMINUTOS1:	DS  1
 AMINUTOS2:	DS  1
 AHORAS1:	DS  1
 AHORAS2:	DS  1	    // Variables para la alarma
    
 CONTT2_2:	DS  1	    // decenas
 CONTT2:	DS  1	    // cuenta hasta 10
 CONTT1:	DS  1
 CONTPUNTOS:	DS  1
 CONT_ALARMA:	DS  1
    
 BANDERA_UNDERFLOW: DS	1
    	
 //PSECT udata_bank0
 VALOR:	    DS	1
 SELECTOR:  DS	1	
 DISPLAY:   DS	4  
 TEMP_DISP: DS	1
    
    
 /*-------------- Interrupciones ---------------*/   
 PSECT intVect, class=CODE, abs, delta=2    
 ORG 04h
 
 push:
    MOVWF   W_TEMP	    // Movemos W en la temporal
    SWAPF   STATUS, W	    // Pasar el SWAP de STATUS a W
    MOVWF   STATUS_TEMP	    // Guardar STATUS SWAP en W	
    
 isr:    
    BANKSEL PORTA
    
    BTFSC   RBIF	    // Revisar la interrupción de puerto B
    CALL    int_ocb
    
    BTFSC   T0IF	    // Revisa bandera de interrupción timer0 - 1 ms
    CALL    int_timer0
    
    BTFSC   TMR1IF	    // Revisar bandera Timer1 - 500 ms
    CALL    int_timer1
    
    BTFSC   TMR2IF	    // revisar interrupción Timer2 - 50 ms
    CALL    int_timer2
    
 pop:
    SWAPF   STATUS_TEMP, W  // Regresamos STATUS a su orden original y lo guaramos en W
    MOVWF   STATUS	    // Mover W a STATUS
    SWAPF   W_TEMP, F	    // Invertimos W_TEMP y se guarda en F
    SWAPF   W_TEMP, W	    // Volvemos a invertir W_TEMP para llevarlo a W
    RETFIE
      
 /*------------ Subrutinas de interrupción ------------*/
 int_ocb:
    BTFSS   PORTB, EDIT
    CALL    inc_edit		// incrementar edit
    
    BTFSS   PORTB, BMODO    // revisar boton
    CALL    inc_modo
    
    MOVF    MODO, W
    BCF	    ZERO
    XORLW   2		// MODO TIMER		
    BTFSC   ZERO
    CALL    boton_play_timer
    
    MOVF    MODO, W
    BCF	    ZERO
    XORLW   3		// MODO ALARMA		
    BTFSC   ZERO
    CALL    no_play_modo_editar_alarma
    
    BCF	    RBIF	    // limpiar bandera
    RETURN
    
 no_play_modo_editar_alarma:
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   0			// MODO TIMER		
    BTFSC   ZERO
    CALL    boton_play_alarma	// permitir presionar boton solo si el modo editar es 0
    RETURN
    
 boton_play_timer:
    BTFSS   PORTB, PLAY
    CALL    inc_play		// incrementar edit
    RETURN
    
 boton_play_alarma:
    BTFSS   PORTB, PLAY
    CALL    inc_play_alarma		// incrementar edit
    RETURN
    
 inc_play:
    INCF    PLAY_TIMER
    MOVF    PLAY_TIMER, W
    SUBLW   2
    BTFSC   ZERO
    CLRF    PLAY_TIMER		// PLAY cambia entre 1 y 0
    BSF	    TIMER_BANDERA, 0	// permitir un botonazo
    RETURN
    
 inc_play_alarma:
    INCF    PLAY_ALARMA
    MOVF    PLAY_ALARMA, W
    SUBLW   2
    BTFSC   ZERO
    CLRF    PLAY_ALARMA		// PLAY cambia entre 1 y 0
    RETURN
    
 inc_edit:
    INCF    MODO_EDIT
    MOVF    MODO_EDIT, W
    SUBLW   3		    // que ocurra overflow de modos (max 3)
    BTFSC   ZERO
    CLRF    MODO_EDIT
    RETURN
  
 inc_modo:
    /*BTFSS   PORTB, BMODO
    GOTO    $-1*/
    BANKSEL PORTB
    INCF    MODO
    MOVF    MODO, W
    SUBLW   4		// que ocurra overflow de modos (max 4)
    BTFSC   ZERO
    CLRF    MODO
    RETURN
    
 int_timer1:
    reset_timer1  
    
    INCF    CONTT1
    MOVF    CONTT1, W
    SUBLW   120		// N * 500ms = 1 min		    ********  TIEMPO PARA QUE TARDE 1 MINUTO EL RELOJ ********
    BTFSC   ZERO	// ya llegó al minuto
    CALL    inc_min
    
    BTFSC   PORTB, ALARMA_ALARMA	// ver si está activado el contador de la alarma
    CALL    contador_alarma		// llamar al contador de alarma
 
    BTFSC   PORTE, LED_ALARMA_ON	// si está activada la alarma
    CALL    comparar_alarma		// ver si son iguales
 
    CALL    puntos
    RETURN
    
 contador_alarma:
    INCF    CONT_ALARMA
    MOVF    CONT_ALARMA, W
    SUBLW   120			    // N * 500ms = 1 min	   ********  TIEMPO QUE PASA LA ALARMA DE LA ALARMA ACTIVA ********
    BTFSC   ZERO		    // ya llegó al minuto
    CALL    apagar_alarma_1minuto
    RETURN
    
 apagar_alarma_1minuto:
    BCF	    PORTB, ALARMA_ALARMA
    BCF	    PORTE, LED_ALARMA_ON
    CLRF    PLAY_ALARMA		    // PLAY cambia a 0
    CLRF    ALARMA_BANDERA	    // Se apaga el contador del minuto de alarma
    CLRF    CONT_ALARMA		    // Se reinicia el contador de alarma 1 minuto
    RETURN
 
 comparar_alarma:
    CLRF    ALARMA_DIGITS
    
    MOVF    HORAS2, W
    SUBWF   AHORAS2, W		// restar unidades de minutos de alarma y de hora
    BTFSC   ZERO		// se prende ZERO si son iguales
    INCF    ALARMA_DIGITS	// sumamos (1 digito igual)
    
    MOVF    HORAS1, W
    SUBWF   AHORAS1, W		// restar unidades de horas de alarma y de hora
    BTFSC   ZERO		// se prende ZERO si son iguales
    INCF    ALARMA_DIGITS	// sumamos (2 digitos iguales)
    
    MOVF    MINUTOS2, W
    SUBWF   AMINUTOS2, W	// restar decenas de minutos de alarma y de hora
    BTFSC   ZERO		// se prende ZERO si son iguales
    INCF    ALARMA_DIGITS	// sumamos (3 digitos iguales)
    
    MOVF    MINUTOS1, W
    SUBWF   AMINUTOS1, W	// restar unidades de minutos de alarma y de hora
    BTFSC   ZERO		// se prende ZERO si son iguales
    INCF    ALARMA_DIGITS	// sumamos (4 digitos iguales)
    
    MOVF    ALARMA_DIGITS, W
    SUBLW   4			// asegurarme que los 4 dígitos son 0
    BTFSC   ZERO
    CALL    alarma_on		// si todo es igual, activa la alarma
    
    fin_comparar:
    RETURN
    
 alarma_on:
    BSF	    PORTB, ALARMA_ALARMA
    BCF	    PORTE, LED_ALARMA_ON
    MOVLW   1
    MOVF    ALARMA_BANDERA	    //la bandera de alarma se activa para comenzar a contar 1 minuto
    CLRF    PLAY_ALARMA
    CLRF    CONT_ALARMA
    RETURN
    
 inc_min:
    CLRF    CONTT1
    INCF    MINUTOS1
    MOVF    MINUTOS1, W
    SUBLW   10		    //cuando cuente 10 segundos incrementa decenas
    BTFSC   ZERO
    CLRF    MINUTOS1	    // limpiar unidades
    BTFSC   ZERO
    INCF    MINUTOS2	    // incrementar decenas
    
    MOVF    MINUTOS2, W
    SUBLW   6		    // cuando las decenas sean 6, incrementa minutos
    BTFSC   ZERO
    CLRF    MINUTOS2	    // limpiar decenas
    BTFSC   ZERO
    CALL    inc_hrs	    // incrementar horas
    
    RETURN
    
 inc_hrs:
    INCF    HORAS1
    MOVF    HORAS1, W
    SUBLW   10		    //cuando cuente 10 incrementa decenas
    BTFSC   ZERO
    CLRF    HORAS1	    // limpiar unidades
    BTFSC   ZERO
    INCF    HORAS2	    // incrementar decenas
    
    MOVF    HORAS2, W
    SUBLW   2		    // cuando las decenas sean 2, verifica que sea 24hrs
    BTFSC   ZERO
    CALL    verificar_24
    
    RETURN
    
 verificar_24:
    MOVF    HORAS1, W
    SUBLW   4			// al cumplir la hora 24 limpiar reloj
    BTFSC   ZERO
    CALL    reiniciar_reloj1 
    RETURN
    
 reiniciar_reloj1:
    CLRF    HORAS1
    CLRF    HORAS2
    CLRF    MINUTOS1
    CLRF    MINUTOS2	    // limpiar reloj a 0
    
    GOTO    inc_dia	    // ya pasó un día
    pos1:
    GOTO    isr
    
 inc_dia:
    INCF    DIAS1	    // mem: 0x31
    MOVF    DIAS1, W
    SUBLW   10		    // cuando cuente 10 veces incrementa decenas
    BTFSC   ZERO
    CLRF    DIAS1	    // en 10 veces limpia unidades
    BTFSC   ZERO
    INCF    DIAS2	    // en 10 veces incrementa decenas
    
    CLRF    TEMP_MES1_MES2
    CLRF    TEMP_SUMA
    MOVF    MES1, W
    ADDWF   TEMP_MES1_MES2, 1	// sumar unidades de los meses sobre la variable
    MOVF    MES2, W
    ADDWF   TEMP_MES1_MES2, 1	// sumar decenas sobre sí misma
    
    INCF    TEMP_SUMA
    MOVF    TEMP_SUMA, W
    SUBLW   10			// contar 10 veces
    BTFSS   ZERO
    GOTO    $-6
    
    MOVF    TEMP_MES1_MES2, W
    CALL    tabla_dias		    // entra W (sumado) y regresa a W la cantidad de dias correspondiente para la resta +1
    MOVWF   TEMP_TABLA_DIAS	    // guardamos el valor de la tabla    mem: 0x35
    
    CLRF    TEMP_DIAS1_DIAS2
    CLRF    TEMP_SUMA
    MOVF    DIAS1, W
    ADDWF   TEMP_DIAS1_DIAS2, 1	    // guardar en F
    MOVF    DIAS2, W
    ADDWF   TEMP_DIAS1_DIAS2, 1		// sumar unidades y decenas de los dias, se guarda en W (con el cero)
    
    INCF    TEMP_SUMA
    MOVF    TEMP_SUMA, w
    SUBLW   10
    BTFSS   ZERO
    GOTO    $-6		    // va a sumar el valor de las decenas 10 veces
    
    MOVF    TEMP_DIAS1_DIAS2, W
    SUBWF   TEMP_TABLA_DIAS, 0	// GUARDA EN W si los dias son iguales a la codificacion de la tabla, se incrementa el mes
    BTFSC   ZERO
    GOTO    reiniciar_dias
    pos2:
    MOVF    TEMP_DIAS1_DIAS2, W
    SUBWF   TEMP_TABLA_DIAS, 0	// GUARDA EN W si los dias son iguales a la codificacion de la tabla, se incrementa el mes
    BTFSC   ZERO
    GOTO    inc_mes
    pos3:
    GOTO    pos1
    
 reiniciar_dias:
    CLRF    DIAS1
    CLRF    DIAS2
    MOVLW   1
    MOVWF   DIAS1
    MOVLW   0
    MOVF    DIAS2	// empezar en día 01
    GOTO    pos2
    
 inc_mes:
    INCF    MES1
    MOVF    MES1, W
    SUBLW   10
    BTFSC   ZERO	// decenas+1 cuando unidades sea 10
    CLRF    MES1	// limpiar unidades
    BTFSC   ZERO
    INCF    MES2
    
    
    CLRF    TEMP_MES1_MES2
    CLRF    TEMP_SUMA
    MOVF    MES1, W
    ADDWF   TEMP_MES1_MES2, 1		// guardar en F las unidades del mes
    MOVF    MES2, W
    ADDWF   TEMP_MES1_MES2, 1		// sumar unidades y decenas de los meses, se guarda en la variable temporal
    
    INCF    TEMP_SUMA		// contador para sumar 10 veces las decenas
    MOVF    TEMP_SUMA, w
    SUBLW   10
    BTFSS   ZERO
    GOTO    $-6			// va a sumar el valor de las decenas 10 veces
    
    MOVF    TEMP_MES1_MES2, W
    SUBLW   13			// cuando se pase de los 12 meses se reinicia la fecha
    BTFSC   ZERO
    GOTO    reiniciar_fecha
    pos4:
    GOTO    pos3
    
 reiniciar_fecha:
    CLRF    MES1
    CLRF    MES2
    MOVLW   1
    MOVWF   MES1
    MOVLW   0
    MOVF    MES2	//e empezar meses en 01
    
    CLRF    DIAS1
    CLRF    DIAS2
    MOVLW   1
    MOVWF   DIAS1
    MOVLW   0
    MOVF    DIAS2	// empezar en mes 01 y día 01
    GOTO    pos4
    
 puntos:
    INCF    CONTPUNTOS		    // contador de vueltas
    BSF	    PORTA, LED_DOT1
    BSF	    PORTA, LED_DOT2	    // Encender puntos
    
    MOVF    CONTPUNTOS, W
    SUBLW   2		    // en la segunda vuelta se cambia el estado de los puntos
    BTFSC   ZERO
    GOTO    cambio_puntos
    RETURN
 
 cambio_puntos:
    BCF	    PORTA, LED_DOT1
    BCF	    PORTA, LED_DOT2	    // Apagamos puntos
    CLRF    CONTPUNTOS		    // limpiamos vueltas de puntos
    RETURN
   
 int_timer0:
    reset_timer0
    
    // código para alternar los selectores con el contador
    CLRF    PORTD
    MOVF    SELECTOR, W
    XORLW   0
    BTFSC   ZERO
    CALL    display0
    
    MOVF    SELECTOR, W
    XORLW   1
    BTFSC   ZERO
    CALL    display1
    
    MOVF    SELECTOR, W
    XORLW   2
    BTFSC   ZERO
    CALL    display2
    
    MOVF    SELECTOR, W
    XORLW   3
    BTFSC   ZERO
    CALL    display3   
    
    INCF    SELECTOR
    MOVF    SELECTOR, W
    SUBLW   4			// Son 4 selectores
    BTFSC   ZERO
    CLRF    SELECTOR		// volver a empezar con el selector en RD0
    RETURN
    
 display0:
    MOVF    DISPLAY, W
    MOVWF   PORTC
    MOVF    SELECTOR, W
    CALL    tabla_selector	// configuración 1 hot para selector
    MOVWF   PORTD		// encender el selector
    RETURN
    
 display1:
    MOVF    DISPLAY+1, W
    MOVWF   PORTC
    MOVF    SELECTOR, W
    CALL    tabla_selector	// configuración 1 hot para selector
    MOVWF   PORTD		// encender el selector
    RETURN
    
 display2:
    MOVF    DISPLAY+2, W
    MOVWF   PORTC
    MOVF    SELECTOR, W
    CALL    tabla_selector	// configuración 1 hot para selector
    MOVWF   PORTD		// encender el selector	
    RETURN
    
 display3:
    MOVF    DISPLAY+3, W
    MOVWF   PORTC
    MOVF    SELECTOR, W
    CALL    tabla_selector	// configuración 1 hot para selector
    MOVWF   PORTD		// encender el selector
    RETURN
    
 int_timer2:
    BCF	    TMR2IF
    
    BTFSC   PORTB, ALARMA_TIMER
    GOTO    tiempo_timer
    
    CLRF    TIMER_BANDERA
    CLRF    TEMP_VALOR_TIMER
    MOVF    TSEGUNDOS1, W
    ADDWF   TSEGUNDOS2, W
    ADDWF   TMINUTOS1, W
    ADDWF   TMINUTOS2, W	    // sumar todos los dígitos del timer en W (si es 0, no debe empezar)
    MOVWF   TEMP_VALOR_TIMER	
    BCF	    ZERO
    MOVF    TEMP_VALOR_TIMER, W	    // se activa ZERO si los dígitos son todos 0
    
    BTFSC   ZERO
    GOTO    activar_alarma_timer   // si el timer llegó a tiempo cero activa alarma
    
    tiempo_timer:
    BTFSC   PORTB, ALARMA_TIMER
    GOTO    conteo_timer
    
    INCF    CONTT2				// contador de vueltas del timer2
    MOVF    CONTT2, W
    SUBLW   20					// 20 * 50ms = 1 seg		********  TIEMPO PARA QUE DECREMENTE 1 SEGUNDO EL TIMER ********
    BTFSC   ZERO				// ya llegó al tiempo
    CALL    int_underflow_timer_segundos 
    
    seguir:
    RETURN
    
 conteo_timer:
    INCF    CONTT2
    MOVF    CONTT2, W
    SUBLW   120				    // N * 50ms = 6 seg		********  TIEMPO QUE PASA LA ALARMA DEL TIMER ACTIVA ********
    BTFSC   ZERO			    // ya llegó al tiempo
    CLRF    CONTT2
    BTFSC   ZERO
    INCF    CONTT2_2
    
    MOVF    CONTT2_2, W
    SUBLW   10			// 6 seg * 10 = 1min
    BTFSC   ZERO
    GOTO    apagar_alarma_timer_tiempo
    GOTO    seguir
    
 activar_alarma_timer:
    BSF	    PORTB, ALARMA_TIMER		    // apagar indicador de que el timer está contando
    BCF	    PORTE, LED_TIMER_ON
    CLRF    CONTT2
    CLRF    CONTT2_2
    GOTO    seguir
 
 apagar_alarma_timer_tiempo:
    CLRF    CONTT2			// limpiar variable contadora de segundos
    CLRF    CONTT2_2
    BCF	    PORTB, ALARMA_TIMER		// apagar alarma
    BCF	    PORTE, LED_TIMER_ON		// apagar led de timer
    BANKSEL T2CON
    BCF	    TMR2ON			// apagar timer1 para que deje de contar
    BANKSEL IOCB
    BTFSS   IOCB, EDIT
    BSF	    IOCB, EDIT			// Encender EDIT al estar en modo timer
    BANKSEL PORTB
    BSF	    TIMER_BANDERA, 0		// permitir un botonazo
    CLRF    PLAY_TIMER			
    GOTO    seguir

    
 int_underflow_timer_segundos:
    CLRF    CONTT2
    DECF    TSEGUNDOS1
    BCF	    ZERO
    MOVLW   -1
    SUBWF   TSEGUNDOS1, W	 // ver si las unidades son menores a 0
    BTFSS   ZERO
    RETURN
    DECF    TSEGUNDOS2		// si es ZERO, restar decenas
    MOVLW   9			// empezar unidades en 9
    MOVWF   TSEGUNDOS1
    
    BCF	    ZERO
    MOVLW   -1
    SUBWF   TSEGUNDOS2, W	    // ver si decenas son menores a 0
    BTFSS   ZERO
    RETURN	
    CALL    int_underflow_timer_minutos	// si es ZERO decrementamos minutos
    RETURN
    
 int_underflow_timer_minutos:
    MOVLW   5		    // empezar en 59 
    MOVWF   TSEGUNDOS2
    
    DECF    TMINUTOS1
    BCF	    ZERO
    MOVLW   -1
    SUBWF   TMINUTOS1, W    // ver si las unidades son menores a 0
    BTFSS   ZERO
    RETURN
    DECF    TMINUTOS2	    // restar decenas
    MOVLW   9		    // empezar unidades en 9
    MOVWF   TMINUTOS1
    
    BCF	    ZERO
    MOVLW   -1
    SUBWF   TMINUTOS2, W	    // ver si decenas son menores a 0
    BTFSS   ZERO
    RETURN
    CALL    int_underflow_99min	    // comenzar reloj en 24 
    RETURN
    
 int_underflow_99min:
    CLRF    TMINUTOS1
    CLRF    TMINUTOS2
    CLRF    TSEGUNDOS1
    CLRF    TSEGUNDOS2		// timer en 00:00
    BCF	    TMR2ON		// Pausar Timer2 para dejar de decrementar
    CLRF    PLAY_TIMER		// PLAY en 0 (modo pausa)
    BSF	    TIMER_BANDERA, 0	// permitir un botonazo
    RETURN
    
 /*----------------- COONFIGURACIÓN uC --------------------*/
 PSECT code, delta=2, abs	
 ORG 200h			// Dirección 100% seguro que terminó interrupciones y reseteo
  
 /*----------------- Tablas --------------------*/ 
 tabla_7seg:
    CLRF    PCLATH
    BSF	    PCLATH, 1	// LATH en posición 01
    
    ANDLW   0x0F	// No sobrepasar el tamaño de la tabla (<16)
    ADDWF   PCL		// PC = PCLATH + PCL 
    
    RETLW   00111111B	// 0
    RETLW   00000110B	// 1
    RETLW   01011011B	// 2
    RETLW   01001111B	// 3
    RETLW   01100110B	// 4
    RETLW   01101101B	// 5
    RETLW   01111101B	// 6
    RETLW   00000111B	// 7
    RETLW   01111111B	// 8
    RETLW   01101111B	// 9     
    
 tabla_selector:
    CLRF    PCLATH
    BSF	    PCLATH, 1	// LATH en posición 10
    
    ANDLW   0x0F	// No sobrepasar el tamaño de la tabla (<16)
    ADDWF   PCL		// PC = PCLATH + PCL 
    
    RETLW   00000001B	// 1
    RETLW   00000010B	// 2
    RETLW   00000100B	// 3
    RETLW   00001000B	// 4  
    
 tabla_dias:
    CLRF    PCLATH
    BSF	    PCLATH, 1	//LATH en posición 10
    
    ANDLW   0x0F	//No sobrepasar el tamaño de la tabla (<16)
    ADDWF   PCL		//PC = PCLATH + PCL 
    
    RETLW   31	// no debería entrar, no hay mes 0
    RETLW   32	// enero
    RETLW   29	// febrero
    RETLW   32	// marzo
    RETLW   31	// abril
    RETLW   32	// mayo
    RETLW   31	// junio
    RETLW   32	// julio
    RETLW   32	// agosto
    RETLW   31	// septiembre
    RETLW   32	// octubre
    RETLW   31	// noviembre
    RETLW   32	// diciembre 
    
 /*---------------------------------------------*/
 main:
    CALL    setup_io
    CALL    setup_clk
    CALL    setup_timer0
    CALL    setup_timer1
    CALL    setup_timer2
    CALL    setup_int
    CALL    setup_int_ocb	// se realizan todas las configuraciones
    BANKSEL PORTA
   
 loop_estados:
    BANKSEL IOCB
    BTFSS   IOCB, BMODO
    BSF	    IOCB, BMODO		// Volver a encender onchange de BMODO al salir del modo edición
    
    BANKSEL PORTB
    
    MOVF    MODO, W
    BCF	    ZERO
    XORLW   0		//En el XOR si los valores son iguales da 0, de lo contrario es 1
    BTFSC   ZERO
    GOTO    hora
    
    MOVF    MODO, W
    BCF	    ZERO
    XORLW   1		// compara el modo con la literal deseada
    BTFSC   ZERO
    GOTO    fecha
    
    MOVF    MODO, W
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO
    GOTO    timer
    
    MOVF    MODO, W
    BCF	    ZERO
    XORLW   3		
    BTFSC   ZERO
    GOTO    alarma
    
    GOTO    loop_estados

 /*----------------- Subrutinas de configuración -----------------*/
 setup_io:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH  // i/o digitales
    
    BANKSEL TRISA
    CLRF    TRISA
    CLRF    TRISC   //Puertos A C D out
    
    BCF	TRISE, LED_ALARMA_ON
    BCF	TRISE, LED_TIMER_ON
    
    BSF	TRISB, BMODO
    BSF	TRISB, UP
    BSF	TRISB, DOWN
    BSF	TRISB, EDIT
    BSF	TRISB, PLAY	// Botones como entradas
    
    BCF	TRISB, ALARMA_TIMER
    BCF	TRISB, ALARMA_ALARMA	// alarmas como salidas en B
    
    BCF	TRISD, SEL0
    BCF	TRISD, SEL1
    BCF	TRISD, SEL2
    BCF	TRISD, SEL3	// pines selectores out
    
    BCF	    OPTION_REG, 7   // pull up puerto B habilitado
    
    CLRF    WPUB
    BSF	    WPUB, BMODO
    BSF	    WPUB, UP
    BSF	    WPUB, DOWN
    BSF	    WPUB, EDIT
    BSF	    WPUB, PLAY	// Pull up de los botones
    
    BANKSEL PORTA
    CLRF    PORTA
    CLRF    PORTB
    CLRF    PORTC
    CLRF    PORTD
    CLRF    PORTE	// puertos limpios
    
    CLRF    SEGUNDOS1	// Asegurarse que las variables empiezan en 0
    CLRF    SEGUNDOS2
    
    CLRF    MINUTOS1
    CLRF    MINUTOS2
    MOVLW   0
    MOVWF   MINUTOS1
    MOVLW   5
    MOVWF   MINUTOS2	// empieza en valor definido
    
    CLRF    HORAS1
    CLRF    HORAS2
    MOVLW   0
    MOVWF   HORAS1   
    MOVLW   2
    MOVWF   HORAS2	// empieza en valor definido
    
    CLRF    TSEGUNDOS1
    CLRF    TSEGUNDOS2
    MOVLW   1
    MOVWF   TSEGUNDOS1   
    MOVLW   0
    MOVWF   TSEGUNDOS2   // No hay día 00 - empieza en valor definido
    
    CLRF    TMINUTOS1
    CLRF    TMINUTOS2
    MOVLW   0
    MOVWF   TMINUTOS1
    MOVLW   0
    MOVWF   TMINUTOS2	// empieza en valor definido
    
    BSF	    TIMER_BANDERA, 0	// EMPIEZA PERMITIENDO UN BOTONAZO
    
    CLRF    AMINUTOS1
    CLRF    AMINUTOS2
    MOVLW   0
    MOVWF   AMINUTOS1
    MOVLW   0
    MOVWF   AMINUTOS2	// empieza en valor definido
    
    CLRF    AHORAS1
    CLRF    AHORAS2	
    MOVLW   1
    MOVWF   AHORAS1
    MOVLW   2
    MOVWF   AHORAS2	// empieza en valor definido
    
    CLRF    DIAS1
    CLRF    DIAS2
    MOVLW   1
    MOVWF   DIAS1   
    MOVLW   0
    MOVWF   DIAS2   // No hay día 00 - empieza en valor definido
    
    CLRF    MES1
    CLRF    MES2
    MOVLW   1
    MOVWF   MES1   
    MOVLW   1
    MOVWF   MES2   // No hay mes 00 - empieza en valor definido
    
    CLRF    MODO
    CLRF    MODO_EDIT
    CLRF    VALOR
    CLRF    PLAY_TIMER
    CLRF    PLAY_ALARMA

    CLRF    SELECTOR	//empezar selector en pin 1 del puerto D
    
    CLRF    DISPLAY
    CLRF    CONTT1
    CLRF    CONTT2
    CLRF    CONTT2_2
    CLRF    CONTPUNTOS
    RETURN
 
 setup_int:
    BANKSEL TRISA
    BSF	    TMR1IE  // interrupción Timer1 ON
    BSF	    TMR2IE  // interrupción Timer2 ON 
    
    BANKSEL PORTA
    BSF	    GIE	    // interrupciones globales ON
    BSF	    PEIE    // interrupciones de periféricos ON
    BSF	    T0IE    // interrupciones del Timer1 ON
    
    BSF	    RBIE    // PORTB change interrupt enabled
    BCF	    RBIF    // Limpiar bandera Puerto B 
    
    BCF	    T0IF    // limpiar bandera Timer0
    BCF	    TMR1IF  // limpiar bandera Timer1
    BCF	    TMR2IF  // limpiar bandera Timer2
    RETURN
    
 setup_int_ocb:
    BANKSEL IOCB
    BSF	    IOCB, BMODO	    // onchange en boton MODO
    BSF	    IOCB, EDIT	    // onchange en boton EDIT
    BSF	    IOCB, PLAY	    // onchange en boton PLAY
    
    BANKSEL PORTA
    MOVF    PORTB, W	//Se termina la condición de mismatch
    BCF	    RBIF	//Limpiar bandera
    RETURN 
    
 setup_clk:
    BANKSEL OSCCON
    BSF	    SCS		//Activar oscilador interno
    
    BSF	IRCF2		// 4 MHz	
    BSF IRCF1		
    BCF IRCF0		
    RETURN
    
 setup_timer0:	    // 5 ms
    BANKSEL OPTION_REG
    
    BCF T0CS	    // Funcionar como temporizador (usando reloj interno)
    BCF PSA	    // Asignar Prescaler al Timer0
    
    BSF PS2	    // Prescaler de 1:256
    BSF PS1	    
    BSF PS0	    
   
    BANKSEL PORTA
    reset_timer0    // Asignar retardo
    RETURN   
 
 setup_timer1:	    // 500 ms
    BANKSEL T1CON
    BCF	TMR1GE	    // Siempre va a estar contando
   
    BSF	T1CKPS1	    // Prescaler 1:8
    BSF	T1CKPS0
    
    BCF	T1OSCEN		// Low power oscillator apagado
    BCF	TMR1CS		// reloj interno
    
    BSF	TMR1ON		// Timer 1 encendido
    reset_timer1	// Asignar valores iniciales 
    RETURN
 
  setup_timer2:	    // 50 ms
    BANKSEL PORTA

    BSF	TOUTPS3	    // Postscaler 1:16
    BSF	TOUTPS2
    BSF	TOUTPS1
    BSF	TOUTPS0

    BSF	T2CKPS1	    // Prescaler 1:16
    BSF	T2CKPS0
    
    BCF	TMR2ON	    // empezar con el Timer2 APAGADO
    
    BANKSEL TRISA
    MOVLW   195	    
    MOVWF   PR2	    // mover W al PR2
    CLRF    TMR2    // limpiar el valor del timer2
    BANKSEL PORTA   // Cambio al puerto de las banderas
    BCF	    TMR2IF  // limpiar bandera timer2  
    RETURN
    
 /*---------------------------- Subrutinas de estados  ---------------------------*/   
 
 /*------------------- HORA ----------------------*/
 hora:
    BANKSEL IOCB
    BTFSC   IOCB, PLAY
    BCF	    IOCB, PLAY		// si PLAY está activado, desactivarlo
    
    BANKSEL IOCB
    BTFSS   IOCB, EDIT
    BSF	    IOCB, EDIT		// permitir editar
    
    BANKSEL PORTA
    BTFSS   TMR1ON
    BSF	    TMR1ON		// Timer 1 encendido
    
    BSF	    PORTA, LED_HORA
    BCF	    PORTA, LED_FECHA
    BCF	    PORTA, LED_TIMER
    BCF	    PORTA, LED_ALARMA
    BCF	    PORTA, LED_EDIT1
    BCF	    PORTA, LED_EDIT2	// encender led del modo y apagar los demás
    
    CLRF    DISPLAY
    set_display	MINUTOS1, MINUTOS2, HORAS1, HORAS2  // codificar display 
    
    // ver a que modo de edición entra
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   1		
    BTFSC   ZERO
    GOTO    set_hora_min
    
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO
    GOTO    set_hora_hrs
   
    GOTO    loop_estados
 
 set_hora_min:
    BANKSEL IOCB
    BCF	    IOCB, BMODO		// apagar onchange BMODO para no cambiar mientras edito
    BANKSEL T1CON
    BCF	    TMR1ON		// Pausar Timer1
    
    BSF	    PORTA, LED_EDIT1
    BCF	    PORTA, LED_EDIT2	// led de edición
    
    BTFSS   PORTB, UP
    GOTO    inc_hora_min
    
    BTFSS   PORTB, DOWN
    GOTO    dec_hora_min
    
    CLRF    DISPLAY
    set_display	MINUTOS1, MINUTOS2, HORAS1, HORAS2  // codificar displays
    
    // ver a que modo de edición entra
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO
    GOTO    set_hora_hrs
    
    GOTO    set_hora_min
    
 inc_hora_min:
    BTFSS   PORTB, UP
    GOTO    $-1		    // antirrebotes
    CALL    ainc_min
    
    GOTO    set_hora_min
    
 dec_hora_min:
    BTFSS   PORTB, DOWN
    GOTO    $-1			// antirrebotes
    CALL    underflow_minutos
    
    GOTO    set_hora_min   
 
 set_hora_hrs:
    BANKSEL IOCB
    BCF	    IOCB, BMODO		// apagar onchange BMODO para no cambiar mientras edito
    BANKSEL T1CON
    BCF	    TMR1ON		// Pausar Timer1
    
    BCF	    PORTA, LED_EDIT1
    BSF	    PORTA, LED_EDIT2
    
    BTFSS   PORTB, UP
    GOTO    inc_hora_hrs
    
    BTFSS   PORTB, DOWN
    GOTO    dec_hora_hrs
    
    CLRF    DISPLAY
    set_display	MINUTOS1, MINUTOS2, HORAS1, HORAS2  // codificación
    
    // si cambia de modo, regresa al modo original
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   0		
    BTFSC   ZERO
    GOTO    hora
    
    GOTO    set_hora_hrs 
    
 inc_hora_hrs:
    BTFSS   PORTB, UP
    GOTO    $-1		    // antirrebotes
    CALL    ainc_hrs		
    
    GOTO    set_hora_min
    
 dec_hora_hrs:
    BTFSS   PORTB, DOWN	
    GOTO    $-1			// antirrebotes
    CALL    underflow_horas
    
    GOTO    set_hora_hrs
    
   
 /*------------------ FECHA ----------------------*/
 fecha:
    BANKSEL IOCB
    BTFSC   IOCB, PLAY
    BCF	    IOCB, PLAY		// si PLAY está activado, desactivarlo
    
    BANKSEL IOCB
    BTFSS   IOCB, EDIT
    BSF	    IOCB, EDIT		// permitir editar
    
    BANKSEL PORTA
    BTFSS   TMR1ON
    BSF	    TMR1ON		// Timer 1 encendido
    
    BCF	    PORTA, LED_HORA
    BSF	    PORTA, LED_FECHA
    BCF	    PORTA, LED_TIMER
    BCF	    PORTA, LED_ALARMA
    BCF	    PORTA, LED_EDIT1
    BCF	    PORTA, LED_EDIT2	// activar led del modo
    
    CLRF    DISPLAY
    set_display	MES1, MES2, DIAS1, DIAS2    // codificación
    
    // ver a qué modo de edición entra
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO
    GOTO    set_fecha_dia
    
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   1		
    BTFSC   ZERO
    GOTO    set_fecha_mes
    
    GOTO    loop_estados
 
 set_fecha_dia:
    BANKSEL IOCB
    BCF	    IOCB, BMODO		// apagar onchange BMODO para no cambiar mientras edito
    BANKSEL T1CON
    BCF	    TMR1ON		// Pausar Timer1
    
    BCF	    PORTA, LED_EDIT1
    BSF	    PORTA, LED_EDIT2	// led de modo de edición 
    
    BTFSS   PORTB, UP
    GOTO    inc_fecha_dia
    
    BTFSS   PORTB, DOWN
    GOTO    dec_fecha_dia
    
    CLRF    DISPLAY
    set_display	MES1, MES2, DIAS1, DIAS2    // codificación
    
    // regresa al modo original cuando sea 0
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   0		
    BTFSC   ZERO
    GOTO    fecha
    
    GOTO    set_fecha_dia
    
 inc_fecha_dia:
    BTFSS   PORTB, UP
    GOTO    $-1		    // antirrebotes
    CALL    ainc_dia
    
    GOTO    set_fecha_dia
    
 dec_fecha_dia:
    BTFSS   PORTB, DOWN
    GOTO    $-1		    // antirrebotes
    CALL    underflow_dias
    
    GOTO    set_fecha_dia
    
 set_fecha_mes:
    BANKSEL IOCB
    BCF	    IOCB, BMODO		// apagar onchange BMODO para no cambiar mientras edito
    BANKSEL T1CON
    BCF	    TMR1ON		// Pausar Timer1
    
    BSF	    PORTA, LED_EDIT1
    BCF	    PORTA, LED_EDIT2
    
    BTFSS   PORTB, UP
    GOTO    inc_fecha_mes
    
    BTFSS   PORTB, DOWN
    GOTO    dec_fecha_mes
    
    CLRF    DISPLAY
    set_display	MES1, MES2, DIAS1, DIAS2    // codificar display
    
    // cambia al modo de edición siguiente si es necesario
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO
    GOTO    set_fecha_dia
    
    GOTO    set_fecha_mes
    
 inc_fecha_mes:
    BTFSS   PORTB, UP
    GOTO    $-1 
    CALL    ainc_mes
    
    GOTO    set_fecha_mes
    
 dec_fecha_mes:
    BTFSS   PORTB, DOWN
    GOTO    $-1 
    CALL    underflow_meses
    
    GOTO    set_fecha_mes
  
 /*------------------ TIMER ----------------------*/
 apagar_edit:
    BANKSEL IOCB
    BTFSC   IOCB, EDIT
    BCF	    IOCB, EDIT		// apagar onchange EDIT 
    BANKSEL PORTB
    RETURN
 
 alarma_timer:
    BTFSS   PORTB, UP		    // boton UP para apagar alarma
    GOTO    apagar_alarma_timer    
    GOTO    pos_timer
    
 apagar_alarma_timer:
    BTFSS   PORTB, DOWN
    GOTO    $-1  
    BTFSC   TMR2ON
    BCF	    TMR2ON		// Apagar manualmente timer2
    CLRF    CONTT2
    CLRF    CONTT2_2
    CLRF    TIMER_BANDERA
    CLRF    PLAY_TIMER
    BCF	    PORTB, ALARMA_TIMER	// APAGAR ALARMA
    BCF	    PORTE, LED_TIMER_ON	// APAGAR LED TIMER ENCENDIDO
    BANKSEL IOCB
    BTFSS   IOCB, EDIT
    BSF	    IOCB, EDIT		// Encender EDIT de nuevo
    BANKSEL PORTB
    GOTO    timer
    
    
 timer:
    BANKSEL IOCB
    BTFSS   IOCB, PLAY
    BSF	    IOCB, PLAY		// Encender PLAY al estar en modo timer
    
    BANKSEL PORTA
    BTFSS   TMR1ON
    BSF	    TMR1ON		// Timer 1 encendido
    
    BTFSC   PORTE, 1
    CALL    apagar_edit
    
    BCF	    PORTA, LED_HORA
    BCF	    PORTA, LED_FECHA
    BSF	    PORTA, LED_TIMER
    BCF	    PORTA, LED_ALARMA
    BCF	    PORTA, LED_EDIT1
    BCF	    PORTA, LED_EDIT2	// leds del modo
    
    CLRF    DISPLAY
    set_display	TSEGUNDOS1, TSEGUNDOS2, TMINUTOS1, TMINUTOS2	// codificación
    
    BTFSC   PORTB, ALARMA_TIMER	    
    GOTO    alarma_timer	    // si se encendió la alarma hace esto
    
    pos_timer:
    BANKSEL IOCB
    BTFSC   IOCB, PLAY
    GOTO    evaluar_edit    // si el botón de play está eapagado, permite editar
    GOTO    seguir_timer    // no se edita si el tiempo está corriendo
    
	evaluar_edit:
	BANKSEL PORTB
	BTFSC   PORTE, 1	// NO ENTRAR A EDIT CON TIMER ON
	GOTO	seguir_timer
	
	// ver a qué modo de editar entra
	MOVF    MODO_EDIT, W
	BCF	ZERO
	XORLW   1		
	BTFSC   ZERO
	GOTO    set_timer_seg

	MOVF    MODO_EDIT, W
	BCF	ZERO
	XORLW   2		
	BTFSC   ZERO
	GOTO    set_timer_min
    
    seguir_timer:  
    BTFSS   TIMER_BANDERA, 0
    GOTO    fin_timer		// si no permite botonazo ya no ejecuta el resto del código
     
    // varía entre si se activa o no el conteo del timer
    MOVF    PLAY_TIMER, W
    BCF	    ZERO
    XORLW   0		
    BTFSC   ZERO
    GOTO    stop_timer	    // parar el timer
    
    MOVF    PLAY_TIMER, W
    BCF	    ZERO
    XORLW   1		
    BTFSC   ZERO    
    GOTO    play_timer	    // activar el timer
    
    fin_timer:
    GOTO    loop_estados
    
 play_timer:
    CLRF    TIMER_BANDERA
    CLRF    TEMP_VALOR_TIMER
    MOVF    TSEGUNDOS1, W
    ADDWF   TSEGUNDOS2, W
    ADDWF   TMINUTOS1, W
    ADDWF   TMINUTOS2, W	// sumar todos los dígitos del timer (si es 0, no debe empezar)
    MOVWF   TEMP_VALOR_TIMER	
    BCF	    ZERO
    MOVF    TEMP_VALOR_TIMER, W	// se activa ZERO si los dígitos son todos 0
    
    BTFSC   ZERO
    GOTO    stop_timer		// si es cero, no activa el timer
    
    BSF	    PORTE, LED_TIMER_ON
    
    /* aquí empieza el código de activar */
    BANKSEL T2CON
    BTFSS   TMR2ON
    BSF	    TMR2ON		// reactivar Timer2
    
    BANKSEL IOCB
    BTFSC   IOCB, EDIT
    BCF	    IOCB, EDIT		// Si el timer está prendido, no permitir editar
    GOTO    fin_play_timer
	
    fin_play_timer:
    GOTO    fin_timer
    
 stop_timer:   
    BANKSEL T2CON
    BTFSC   TMR2ON
    BCF	    TMR2ON		// Pausar Timer2
    
    BANKSEL IOCB
    BTFSS   IOCB, EDIT
    BSF	    IOCB, EDIT		// permitir editar
    
    CLRF    TIMER_BANDERA
    BCF	    PORTE, LED_TIMER_ON	// se apaga el led que indica conteo del timer
    GOTO    fin_timer
    
 set_timer_seg:
    BANKSEL IOCB
    BCF	    IOCB, BMODO		// apagar onchange BMODO para no cambiar mientras edito
    
    BTFSC   IOCB, PLAY
    BCF	    IOCB, PLAY		// APAGAR PLAY al estar en editar
    
    BANKSEL T1CON
    BCF	    TMR1ON		// Pausar Timer1
    
    BSF	    PORTA, LED_EDIT1
    BCF	    PORTA, LED_EDIT2
    
    BTFSS   PORTB, UP
    GOTO    inc_timer_seg
    
    BTFSS   PORTB, DOWN
    GOTO    dec_timer_seg
    
    CLRF    DISPLAY
    set_display	TSEGUNDOS1, TSEGUNDOS2, TMINUTOS1, TMINUTOS2	// codificación
    
    // verifica si cambia o no de modo
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO
    GOTO    set_timer_min
    
    GOTO    set_timer_seg
    
 inc_timer_seg:
    BTFSS   PORTB, UP
    GOTO    $-1 
    CALL    ainc_tseg
    GOTO    set_timer_seg
    
 dec_timer_seg:
    BTFSS   PORTB, DOWN
    GOTO    $-1 
    CALL    underflow_timer_segundos
    GOTO    set_timer_seg
    
 set_timer_min:
    BANKSEL IOCB
    BCF	    IOCB, BMODO		// apagar onchange BMODO para no cambiar mientras edito
    
    BTFSC   IOCB, PLAY
    BCF	    IOCB, PLAY		// APAGAR PLAY al estar en editar
    
    BANKSEL T1CON
    BCF	    TMR1ON		// Pausar Timer1
    
    BCF	    PORTA, LED_EDIT1
    BSF	    PORTA, LED_EDIT2
    
    BTFSS   PORTB, UP
    GOTO    inc_timer_min
    
    BTFSS   PORTB, DOWN
    GOTO    dec_timer_min
    
    CLRF    DISPLAY
    set_display	TSEGUNDOS1, TSEGUNDOS2, TMINUTOS1, TMINUTOS2	// codificación
    
    // verifica si regresa al modo original
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   0		
    BTFSC   ZERO
    GOTO    timer
    
    GOTO    set_timer_min
    
 inc_timer_min:
    BTFSS   PORTB, UP
    GOTO    $-1 
    CALL    ainc_tmin
    GOTO    set_timer_min
    
 dec_timer_min:
    BTFSS   PORTB, DOWN
    GOTO    $-1 
    CALL    underflow_timer_minutos
    GOTO    set_timer_min
    
 /*------------------ ALARMA ----------------------*/   
 alarma_boton:
    BTFSS   PORTB, UP		    // boton UP para apagar alarma
    GOTO    apagar_alarma_alarma    
    GOTO    pos_alarma
    
 apagar_alarma_alarma:
    BCF	    PORTB, ALARMA_ALARMA
    CLRF    PLAY_ALARMA		    // PLAY cambia a 0
    CLRF    ALARMA_BANDERA	    // Se apaga el contador del minuto de alarma
    CLRF    CONT_ALARMA		    // Se reinicia el contador de alarma 1 minuto
    GOTO    alarma
    
    
 alarma:
    BANKSEL IOCB
    BTFSS   IOCB, EDIT
    BSF	    IOCB, EDIT		// permitir editar
    
    BANKSEL PORTA
    BTFSS   TMR1ON
    BSF	    TMR1ON		// Timer 1 encendido
    
    BCF	    PORTA, LED_HORA
    BCF	    PORTA, LED_FECHA
    BCF	    PORTA, LED_TIMER
    BSF	    PORTA, LED_ALARMA
    BCF	    PORTA, LED_EDIT1
    BCF	    PORTA, LED_EDIT2	
    
    CLRF    DISPLAY
    set_display	AMINUTOS1, AMINUTOS2, AHORAS1, AHORAS2
    
    BTFSC   PORTB, ALARMA_ALARMA	    
    GOTO    alarma_boton	    // si se encendió la alarma hace esto
    
    pos_alarma:
    // verificar el modo de edición
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   1			// configurar minutos
    BTFSC   ZERO
    GOTO    set_alarma_min
    
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   2			// configurar horas
    BTFSC   ZERO
    GOTO    set_alarma_hrs
    
    // verificar estado de botón de alarma
    MOVF    PLAY_ALARMA, W
    BCF	    ZERO
    XORLW   0			    // PLAY ALARMA solo tiene 1 o 0
    BTFSC   ZERO
    GOTO    desactivar_alarma	    
    
    MOVF    PLAY_ALARMA, W
    BCF	    ZERO
    XORLW   1		
    BTFSC   ZERO    
    GOTO    activar_alarma	    
    
    fin_alarma:
    GOTO    loop_estados
    
 activar_alarma:
    BSF	    PORTE, LED_ALARMA_ON    // se enciende que la alarma está activa
    GOTO    fin_alarma
    
 desactivar_alarma:
    BCF	    PORTE, LED_ALARMA_ON    // se apaga para indicar que la alarma no está activa
    GOTO    fin_alarma
 
 set_alarma_min:
    BANKSEL IOCB
    BCF	    IOCB, BMODO		// apagar onchange BMODO para no cambiar mientras edito
    BANKSEL T1CON
    BCF	    TMR1ON		// Pausar Timer1
    
    BSF	    PORTA, LED_EDIT1
    BCF	    PORTA, LED_EDIT2
    
    BTFSS   PORTB, UP
    GOTO    inc_alarma_min
    
    BTFSS   PORTB, DOWN
    GOTO    dec_alarma_min
    
    CLRF    DISPLAY
    set_display	AMINUTOS1, AMINUTOS2, AHORAS1, AHORAS2	// codificación
    
    // evalúa si entra al otro modo
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   2		
    BTFSC   ZERO
    GOTO    set_alarma_hrs
    
    GOTO    set_alarma_min
    
 inc_alarma_min:
    BTFSS   PORTB, UP
    GOTO    $-1 
    CALL    ainc_min_alarma
    GOTO    set_alarma_min
    
 dec_alarma_min:
    BTFSS   PORTB, DOWN
    GOTO    $-1 
    CALL    underflow_minutos_alarma
    GOTO    set_alarma_min
    
 set_alarma_hrs:
    BANKSEL IOCB
    BCF	    IOCB, BMODO		// apagar onchange BMODO para no cambiar mientras edito
    BANKSEL T1CON
    BCF	    TMR1ON		// Pausar Timer1
    
    BCF	    PORTA, LED_EDIT1
    BSF	    PORTA, LED_EDIT2
    
    BTFSS   PORTB, UP
    GOTO    inc_alarma_hrs
    
    BTFSS   PORTB, DOWN
    GOTO    dec_alarma_hrs
    
    CLRF    DISPLAY
    set_display	AMINUTOS1, AMINUTOS2, AHORAS1, AHORAS2 // codificación
    
    MOVF    MODO_EDIT, W
    BCF	    ZERO
    XORLW   0		
    BTFSC   ZERO
    GOTO    alarma
    
    GOTO    set_alarma_hrs
    
 inc_alarma_hrs:
    BTFSS   PORTB, UP
    GOTO    $-1 
    CALL    ainc_hrs_alarma
    GOTO    set_alarma_hrs
    
 dec_alarma_hrs:
    BTFSS   PORTB, DOWN
    GOTO    $-1 
    CALL    underflow_horas_alarma
    GOTO    set_alarma_hrs
    
 /*---------------------------------------- INCREMENTOS Y DECREMENTOS MANUALES  ---------------------------------------------*/
 /*------------- HORA -------------*/
 underflow_minutos:
    DECF    MINUTOS1
    BCF	    ZERO
    MOVLW   -1
    SUBWF   MINUTOS1, W	    // ver si las unidades son menores a 0
    BTFSS   ZERO
    RETURN
    DECF    MINUTOS2	    // restar decenas
    MOVLW   9		    // empezar unidades en 9
    MOVWF   MINUTOS1
    
    BCF	    ZERO
    MOVLW   -1
    SUBWF   MINUTOS2, W	    // ver si decenas son menores a 0
    BTFSS   ZERO
    RETURN
    MOVLW   5		    // empezar en 59 
    MOVWF   MINUTOS2  
    RETURN
    
 underflow_horas:
    DECF    HORAS1
    BCF	    ZERO
    MOVLW   -1
    SUBWF   HORAS1, W	    // ver si las unidades son menores a 0
    BTFSS   ZERO
    RETURN
    DECF    HORAS2	    // restar decenas
    MOVLW   9		    // empezar unidades en 9
    MOVWF   HORAS1
    
    BCF	    ZERO
    MOVLW   -1
    SUBWF   HORAS2, W	    // ver si decenas son menores a 0
    BTFSS   ZERO
    RETURN
    CALL    underflow_hrs24 // comenzar reloj en 24 
    RETURN
    
 underflow_hrs24:
    MOVLW   2
    MOVWF   HORAS2
    MOVLW   3
    MOVWF   HORAS1	// al hacer underflow las horas regresan a 23
    RETURN
    
 ainc_min:
    INCF    MINUTOS1
    MOVF    MINUTOS1, W
    SUBLW   10		    //cuando cuente 10 segundos incrementa decenas
    BTFSC   ZERO
    CLRF    MINUTOS1
    BTFSC   ZERO
    INCF    MINUTOS2
    
    MOVF    MINUTOS2, W
    SUBLW   6		    // cuando las decenas sean 6, incrementa minutos
    BTFSC   ZERO
    CLRF    MINUTOS2
    RETURN
    
 ainc_hrs:
    INCF    HORAS1
    MOVF    HORAS1, W
    SUBLW   10		    //cuando cuente 10 incrementa decenas
    BTFSC   ZERO
    CLRF    HORAS1
    BTFSC   ZERO
    INCF    HORAS2
    
    MOVF    HORAS2, W
    SUBLW   2		    // cuando las decenas sean 2, verifica que sea 24hrs
    BTFSC   ZERO
    CALL    averificar_24
    RETURN
    
 averificar_24:
    MOVF    HORAS1, W
    SUBLW   4
    BTFSC   ZERO
    CALL    areiniciar_reloj1	// si las decenas son 2 y las horas son 4 se reinicia el reloj
    RETURN
    
 areiniciar_reloj1:
    CLRF    HORAS1
    CLRF    HORAS2
    CLRF    MINUTOS1
    CLRF    MINUTOS2
    RETURN
    
 /*------------- FECHA -------------*/
 underflow_dias:
    DECF    DIAS1
    
    CLRF    TEMP_MES1_MES2
    CLRF    TEMP_SUMA
    MOVF    MES1, W
    ADDWF   TEMP_MES1_MES2, 1	// sumar unidades de los meses sobre la variable
    MOVF    MES2, W
    ADDWF   TEMP_MES1_MES2, 1	// sumar decenas sobre sí misma
    
    INCF    TEMP_SUMA
    MOVF    TEMP_SUMA, W
    SUBLW   10			// contar 10 veces
    BTFSS   ZERO
    GOTO    $-6
    
    MOVF    TEMP_MES1_MES2, W
    CALL    tabla_dias		    // entra W (sumado) y regresa a W la cantidad de dias correspondiente para la resta +1
    MOVWF   TEMP_TABLA_DIAS	    // guardamos el valor de la tabla    mem: 0x35
   
    //	CON ESTO YA TENEMOS LOS DÍAS QUE DEBE TENER EL MES EN QUE VAMOS    
    BCF	    BANDERA_UNDERFLOW, 0
    MOVLW   10
    SUBWF   TEMP_MES1_MES2, W	    // MES - 10 EN W	
    BTFSC   CARRY		    // MAYOR O IGUAL A 10 ENCIENDE CARRY
    CALL    underflow_mayores10
    BTFSS   BANDERA_UNDERFLOW, 0
    CALL    underflow_menores10
    BTFSS   ZERO
    RETURN
    CALL    revisar_tabla
    RETURN
   
 underflow_menores10:
    BCF	    ZERO
    MOVF    DIAS2, W
    BTFSC   ZERO
    MOVF    DIAS1, W	    // condición de underflow con decenas mayores a 0
    BTFSC   ZERO
    GOTO    $+10		    // cambiar condición de underflow para que quede un día cuando decenas = 0
    MOVLW   -1
    SUBWF   DIAS1, W	    // ver si las unidades son menores a 0
    
    BTFSS   ZERO
    RETURN
    DECF    DIAS2	    // restar decenas
    MOVLW   9		    // empezar unidades en 9
    MOVWF   DIAS1
    
    BCF	    ZERO
    MOVLW   -1
    SUBWF   MES2, W	    // ver si decenas son menores a 0
    RETURN
    
 underflow_mayores10:
    BSF	    BANDERA_UNDERFLOW, 0
    
    BCF	    ZERO
    MOVF    DIAS2, W
    BTFSC   ZERO
    MOVF    DIAS1, W	    // condición de underflow con decenas mayores a 0
    BTFSC   ZERO
    GOTO    $+10		    // cambiar condición de underflow para que quede un día cuando decenas = 0
    MOVLW   -1
    SUBWF   DIAS1, W	    // ver si las unidades son menores a 0
    
    BTFSS   ZERO
    RETURN
    DECF    DIAS2	    // restar decenas
    MOVLW   9		    // empezar unidades en 9
    MOVWF   DIAS1
    BCF	    ZERO
    MOVLW   -1
    SUBWF   DIAS2, W	    // ver si decenas son menores a 0
    RETURN
 
 revisar_tabla:
    MOVF    TEMP_TABLA_DIAS, W
    BCF	    ZERO
    XORLW   32			// si la tabla tiene 32 reinicia a 31
    BTFSC   ZERO
    GOTO    reset_32
    
    MOVF    TEMP_TABLA_DIAS, W
    BCF	    ZERO
    XORLW   31			// si la tabla tiene 31 reinicia a 30
    BTFSC   ZERO
    GOTO    reset_31
    
    MOVF    TEMP_TABLA_DIAS, W
    BCF	    ZERO
    XORLW   29			// si la tabla tiene 29 reinicia a 28
    BTFSC   ZERO
    GOTO    reset_29
    fin_revisar_tabla:
    RETURN
  
 reset_32:
    MOVLW   1
    MOVWF   DIAS1
    MOVLW   3
    MOVWF   DIAS2		// setear los días de acuerdo al mes en que esté
    GOTO    fin_revisar_tabla
    
 reset_31:
    MOVLW   0
    MOVWF   DIAS1
    MOVLW   3
    MOVWF   DIAS2		// setear los días de acuerdo al mes en que esté
    GOTO    fin_revisar_tabla
    
 reset_29:			// Febrero
    MOVLW   8
    MOVWF   DIAS1
    MOVLW   2
    MOVWF   DIAS2		// setear los días de acuerdo al mes en que esté
    GOTO    fin_revisar_tabla
    
 underflow_meses:
    DECF    MES1
    BCF	    ZERO
    MOVF    MES2, W
    BTFSC   ZERO
    MOVF    MES1, W	    // condición de underflow con decenas mayores a 0
    BTFSC   ZERO
    GOTO    $+10		    // cambiar condición de underflow para que quede un día cuando decenas = 0
    MOVLW   -1
    SUBWF   MES1, W	    // ver si las unidades son menores a 0
    
    BTFSS   ZERO
    RETURN
    DECF    MES2	    // restar decenas
    MOVLW   9		    // empezar unidades en 9
    MOVWF   MES1
    
    BCF	    ZERO
    MOVLW   -1
    SUBWF   MES2, W	    // ver si decenas son menores a 0
    BTFSS   ZERO
    RETURN
    CALL    underflow_12meses // comenzar reloj en 24 
    RETURN
    
 underflow_12meses:
    MOVLW   1
    MOVWF   MES2
    MOVLW   2
    MOVWF   MES1	// regresa a diciembre luego de decrementar en enero
    RETURN
    
    
 ainc_dia:
    INCF    DIAS1	    // mem: 0x31
    MOVF    DIAS1, W
    SUBLW   10		    // cuando cuente 10 veces incrementa decenas
    BTFSC   ZERO
    CLRF    DIAS1	    // en 10 veces limpia unidades
    BTFSC   ZERO
    INCF    DIAS2	    // en 10 veces incrementa decenas
    
    CLRF    TEMP_MES1_MES2
    CLRF    TEMP_SUMA
    MOVF    MES1, W
    ADDWF   TEMP_MES1_MES2, 1	// sumar unidades de los meses sobre la variable
    MOVF    MES2, W
    ADDWF   TEMP_MES1_MES2, 1	// sumar decenas sobre sí misma
    
    INCF    TEMP_SUMA
    MOVF    TEMP_SUMA, W
    SUBLW   10			// contar 10 veces
    BTFSS   ZERO
    GOTO    $-6
    
    MOVF    TEMP_MES1_MES2, W
    CALL    tabla_dias		    // entra W (sumado) y regresa a W la cantidad de dias correspondiente para la resta +1
    MOVWF   TEMP_TABLA_DIAS	    // guardamos el valor de la tabla    mem: 0x35
    
    
    CLRF    TEMP_DIAS1_DIAS2
    CLRF    TEMP_SUMA
    MOVF    DIAS1, W
    ADDWF   TEMP_DIAS1_DIAS2, 1	    // guardar en F
    MOVF    DIAS2, W
    ADDWF   TEMP_DIAS1_DIAS2, 1		// sumar unidades y decenas de los dias, se guarda en W (con el cero)
    
    INCF    TEMP_SUMA
    MOVF    TEMP_SUMA, w
    SUBLW   10
    BTFSS   ZERO
    GOTO    $-6		    // va a sumar el valor de las decenas 10 veces
    
    MOVF    TEMP_DIAS1_DIAS2, W
    SUBWF   TEMP_TABLA_DIAS, 0	// GUARDA EN W si los dias son iguales a la codificacion de la tabla, se incrementa el mes
    BTFSC   ZERO
    CALL    areiniciar_dias
    RETURN
    
 areiniciar_dias:
    CLRF    DIAS1
    CLRF    DIAS2
    MOVLW   1
    MOVWF   DIAS1
    MOVLW   0
    MOVF    DIAS2	// empezar en día 01
    RETURN
    
 ainc_mes:
    INCF    MES1
    MOVF    MES1, W
    SUBLW   10
    BTFSC   ZERO	// incrementar decenas si llega a 10 y limpiar unidades
    CLRF    MES1
    BTFSC   ZERO
    INCF    MES2
    
    
    CLRF    TEMP_MES1_MES2
    CLRF    TEMP_SUMA
    MOVF    MES1, W
    ADDWF   TEMP_MES1_MES2, 1		// guardar en F
    MOVF    MES2, W
    ADDWF   TEMP_MES1_MES2, 1		// sumar unidades y decenas de los MESES, se guarda en W (con el cero)
    
    INCF    TEMP_SUMA
    MOVF    TEMP_SUMA, w
    SUBLW   10
    BTFSS   ZERO
    GOTO    $-6			    // va a sumar el valor de las decenas 10 veces
    
    MOVF    TEMP_MES1_MES2, W
    SUBLW   13			// cuando se pase de los 12 meses se reinicia la fecha
    BTFSC   ZERO
    CALL    areiniciar_fecha
    CALL    limpiar_dias
    
    RETURN
    
 limpiar_dias:
    CLRF    DIAS1
    CLRF    DIAS2
    MOVLW   1
    MOVWF   DIAS1
    MOVLW   0
    MOVF    DIAS2	// empezar en mes 01 y día 01
    RETURN
    
 areiniciar_fecha:
    CLRF    MES1
    CLRF    MES2
    MOVLW   1
    MOVWF   MES1
    MOVLW   0
    MOVF    MES2
    
    CLRF    DIAS1
    CLRF    DIAS2
    MOVLW   1
    MOVWF   DIAS1
    MOVLW   0
    MOVF    DIAS2	// empezar en mes 01 y día 01
    RETURN
    
 /*-----------------------TIMER -------------------------*/   
 underflow_timer_segundos:
    DECF    TSEGUNDOS1
    BCF	    ZERO
    MOVLW   -1
    SUBWF   TSEGUNDOS1, W	    // ver si las unidades son menores a 0
    BTFSS   ZERO
    RETURN
    DECF    TSEGUNDOS2	    // restar decenas
    MOVLW   9		    // empezar unidades en 9
    MOVWF   TSEGUNDOS1
    
    BCF	    ZERO
    MOVLW   -1
    SUBWF   TSEGUNDOS2, W	    // ver si decenas son menores a 0
    BTFSS   ZERO
    RETURN
    MOVLW   5		    // empezar en 59 
    MOVWF   TSEGUNDOS2  
    RETURN
    
 underflow_timer_minutos:
    DECF    TMINUTOS1
    BCF	    ZERO
    MOVLW   -1
    SUBWF   TMINUTOS1, W	    // ver si las unidades son menores a 0
    BTFSS   ZERO
    RETURN
    DECF    TMINUTOS2	    // restar decenas
    MOVLW   9		    // empezar unidades en 9
    MOVWF   TMINUTOS1
    
    BCF	    ZERO
    MOVLW   -1
    SUBWF   TMINUTOS2, W	    // ver si decenas son menores a 0
    BTFSS   ZERO
    RETURN
    CALL    underflow_99min // comenzar reloj en 24 
    RETURN
    
 underflow_99min:
    MOVLW   9
    MOVWF   TMINUTOS2
    MOVLW   9
    MOVWF   TMINUTOS1
    RETURN
    
 ainc_tseg:
    INCF    TSEGUNDOS1
    MOVF    TSEGUNDOS1, W
    SUBLW   10		    //cuando cuente 10 segundos incrementa decenas
    BTFSC   ZERO
    CLRF    TSEGUNDOS1
    BTFSC   ZERO
    INCF    TSEGUNDOS2
	
    MOVF    TSEGUNDOS2, W
    SUBLW   6		    // cuando las decenas sean 6, incrementa minutos
    BTFSC   ZERO
    CLRF    TSEGUNDOS2
    RETURN
    
 ainc_tmin:
    INCF    TMINUTOS1
    MOVF    TMINUTOS1, W
    SUBLW   10		    //cuando cuente 10 incrementa decenas
    BTFSC   ZERO
    CLRF    TMINUTOS1
    BTFSC   ZERO
    INCF    TMINUTOS2
    
    MOVF    TMINUTOS2, W
    SUBLW   10			// cuando las decenas sean 2, verifica que sea 24hrs
    BTFSC   ZERO
    GOTO    areiniciar_timer
    GOTO    fin_ainc_min
    
	areiniciar_timer:   
	CLRF    TMINUTOS1
	CLRF    TMINUTOS2	// subestado para reiniciar el timer 
	RETURN
	
    fin_ainc_min:
    RETURN
	
 underflow_timer_seg:
    RETURN
    
 /*---------------- ALARMA ----------------*/
 underflow_minutos_alarma:
    DECF    AMINUTOS1
    BCF	    ZERO
    MOVLW   -1
    SUBWF   AMINUTOS1, W	    // ver si las unidades son menores a 0
    BTFSS   ZERO
    RETURN
    DECF    AMINUTOS2	    // restar decenas
    MOVLW   9		    // empezar unidades en 9
    MOVWF   AMINUTOS1
    
    BCF	    ZERO
    MOVLW   -1
    SUBWF   AMINUTOS2, W	    // ver si decenas son menores a 0
    BTFSS   ZERO
    RETURN
    MOVLW   5		    // empezar en 59 
    MOVWF   AMINUTOS2  
    RETURN
    
 underflow_horas_alarma:
    DECF    AHORAS1
    BCF	    ZERO
    MOVLW   -1
    SUBWF   AHORAS1, W	    // ver si las unidades son menores a 0
    BTFSS   ZERO
    RETURN
    DECF    AHORAS2	    // restar decenas
    MOVLW   9		    // empezar unidades en 9
    MOVWF   AHORAS1
    
    BCF	    ZERO
    MOVLW   -1
    SUBWF   AHORAS2, W	    // ver si decenas son menores a 0
    BTFSS   ZERO
    RETURN
    CALL    underflow_hrs24_alarma // comenzar reloj en 24 
    RETURN
    
 underflow_hrs24_alarma:
    MOVLW   2
    MOVWF   AHORAS2
    MOVLW   3
    MOVWF   AHORAS1	    // regresar las horas a 23 
    RETURN
    
 ainc_min_alarma:
    INCF    AMINUTOS1
    MOVF    AMINUTOS1, W
    SUBLW   10		    //cuando cuente 10 segundos incrementa decenas
    BTFSC   ZERO
    CLRF    AMINUTOS1
    BTFSC   ZERO
    INCF    AMINUTOS2
    
    MOVF    AMINUTOS2, W
    SUBLW   6		    // cuando las decenas sean 6, incrementa minutos
    BTFSC   ZERO
    CLRF    AMINUTOS2 
    RETURN
    
 ainc_hrs_alarma:
    INCF    AHORAS1
    MOVF    AHORAS1, W
    SUBLW   10		    //cuando cuente 10 incrementa decenas
    BTFSC   ZERO
    CLRF    AHORAS1
    BTFSC   ZERO
    INCF    AHORAS2
    
    MOVF    AHORAS2, W
    SUBLW   2		    // cuando las decenas sean 2, verifica que sea 24hrs
    BTFSC   ZERO
    CALL    averificar_24_alarma
    RETURN
    
 averificar_24_alarma:
    MOVF    AHORAS1, W
    SUBLW   4
    BTFSC   ZERO
    CALL    areiniciar_reloj_alarma 
    RETURN
    
 areiniciar_reloj_alarma:
    CLRF    AHORAS1
    CLRF    AHORAS2
    RETURN
	
 END