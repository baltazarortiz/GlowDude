;$INCLUDE(reg_c51.INC)
; software flag
;.define transmit_completed, 20H.1 
.equ serial_data, 08H
.equ data_save, 09H
.equ data_example, 0AH
.equ SPDAT, 86H
.equ SPSTA, 0xaa

.equ SPCR, 0xD5
.equ IEN1, 0xB1

.org 000h
ljmp begin
.org 4Bh
ljmp it_SPI

;/**
; * FUNCTION_PURPOSE: This file set up spi in master mode with
; * Fclk Periph/128 as baud rate and without slave select pin
; * FUNCTION_INPUTS: P1.5(MISO) serial input
; * FUNCTION_OUTPUTS: P1.7(MOSI) serial output
; * P1.1
; */

.org 0100h
begin:

;init
;MOV #data_example, #55h  ; /* data example */
ORL SPCR,#10h         ; /* Master mode */
ORL SPCR,#20h         ; /* P1.1 is available as standard I/O pin */
ORL SPCR,#82h         ; /* Fclk Periph/128 */
ANL SPCR,#0F7h        ; /* CPOL=0; transmit mode example */
ORL SPCR,#04h         ; /* CPHA=1; transmit mode example */
ORL IEN1,#04h          ; /* enable spi interrupt */
ORL SPCR,#40h          ; /* run spi */
CLR 20H.1  ; /* clear software transfert flag */
SETB EA                 ; /* enable interrupts */

loop: ;/* endless */
    CPL P1.1; /* P1.1 is available as standard I/O pin */
    MOV SPDAT,#data_example; /* send an example data */
    
    spi_transmit_wait1:
        JNB 20H.1, spi_transmit_wait1 ; /* wait end of transmition */
    
    CLR 20H.1; /* clear software transfert flag */
    MOV SPDAT,#00h; /* data is send to generate SCK signal */
    
    spi_transmit_wait2:
        JNB 20H.1, spi_transmit_wait2 ; /* wait end of transmition */
        
    CLR 20H.1; /* clear software transfert flag */
    ;MOV #data_save, serial_data; /* save receive data */
LJMP loop

;/**
; * FUNCTION_PURPOSE:interrupt
; * FUNCTION_INPUTS: void
; * FUNCTION_OUTPUTS: transmit_complete is software transfert flag
; */it_SPI:; /* interrupt address is 0x004B */
it_SPI:
MOV R7,SPSTA;
MOV ACC,R7

JNB ACC.7, break1    ;case 0x80:

MOV serial_data,SPDAT; /* read receive data */
SETB 20H.1; /* set software flag */

break1:
JNB ACC.4,break2    ;case 0x10:

;/* put here for mode fault tasking */
break2:;
JNB ACC.6,break3;case 0x40:
;/* put here for overrun tasking */
break3:;
RETI

