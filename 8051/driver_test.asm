; turn on an LED over i2c

;------------------------------    
clr p3.2

clr p3.4
setb p3.4

lcall i2cinit

; turn off sw shutdown
; don't worry about ack checking anymore

acall startc ; start

mov acc, #0xa8 ; slave address
acall send

mov acc, #0x00 ; shutdown address
acall send

mov acc, #0x01 ; 1 for chip on
acall send

acall stop ; stop
;------------------------------    

; enable LED 1
acall startc ; start

mov acc, #0xa8 ; slave address
acall send


mov acc, #0x13 ; ctl1 address
acall send


mov acc, #0xff ; leds 1-6 on
acall send


acall stop ; stop
;------------------------------    

; led 1 pwm = 128
acall startc ; start

mov acc, #0xa8 ; slave address
acall send


mov acc, #0x01 ; led 1 pwm address
acall send


mov acc, #127d ; pwm = 128
acall send


acall stop ; stop

; --------------
; update to commit changes
acall startc ; start

mov acc, #0xa8 ; slave address
acall send


mov acc, #0x16 ; update address
acall send


mov acc, #0xff ; any value triggers the update
acall send

acall stop ; stop

testdone:
cpl p1.7
sjmp testdone

.inc i2c.h.asm

