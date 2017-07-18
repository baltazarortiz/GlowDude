; Check if we get an ack as expected when we poke the driver
; P0.0 high for success, P0.7 high for failure

;clr P1.6
;clr P1.7
mov P1, #0x00

; Init i2c ports first
; i2c uses P1.0 = sda and P1.1 = scl
lcall i2cinit

mov a,#128d

; loop through 0->255 and ping
; Send start condition
scan:
    lcall startc

    ; Send slave address
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

    mov r6, #0xff    
    stall:
        djnz r6, stall
    

djnz acc, scan

testdone:
sjmp testdone
    
.inc i2c.h.asm

