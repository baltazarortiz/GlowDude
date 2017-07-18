lcall i2cinit
lcall IS31FL3218_init_all
 
mov a, #0x19
mov b, #0x07
lcall IS31FL3218_setpwm
 
lcall IS31FL3218_update

testdone:
sjmp testdone

 
.inc i2c.h.asm
.inc IS31FL3218.asm
