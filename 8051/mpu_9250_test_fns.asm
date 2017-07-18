lcall i2cinit

lcall delay500

lcall mpu_9250_ping
lcall mpu_9250_init
lcall mpu_mag_ping
    
lcall mpu_9250_readaccel

testdone:
sjmp testdone

.inc mpu9250.asm
