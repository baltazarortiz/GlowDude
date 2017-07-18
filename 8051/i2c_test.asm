; Check if we get an ack as expected when we poke the driver
; P0.0 high for success, P0.7 high for failure

;clr P1.6
;clr P1.7
mov P1, #0x00

; turn on chip
clr p3.4
setb p3.4

; Init i2c ports
; i2c uses P1.0 = sda and P1.1 = scl
lcall i2cinit


; Send start condition
lcall startc

; Send slave address
mov a,#0xd0
acall send

; after send call Carry flag has ACK bit
; If you want to check if send was a
; success or failure

jc gotack
; else no carry
    setb P1.6 ; high if failure
    sjmp stop_i2c

gotack:
    setb P1.7 ; high if success
        
stop_i2c:
    acall stop ; stop condition
testdone:
sjmp testdone
    
.inc i2c.h.asm

