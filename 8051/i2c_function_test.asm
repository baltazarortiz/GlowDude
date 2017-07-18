; test i2c with functions

; Init i2c ports
; i2c uses P1.0 = sda and P1.1 = scl
lcall i2cinit

; Send slave address
mov a,#0xd0
lcall i2c_sendbyte

testdone:
sjmp testdone
    
.inc i2c.h.asm

