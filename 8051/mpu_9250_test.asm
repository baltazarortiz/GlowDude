lcall i2cinit

;acall delay100
;lcall mpu_9250_ping
    mov acc, #IMU_ADDR  ; slave addr
    mov b, #WHO_AM_I    ; reg addr 
    acall i2c_readbyte  ; read value -> r7
    
    ; check if read value != WHOAMI_VAL
    cjne r7, #WHOAMI_VAL, imu_ping_failed
    ; else read value = WHOAMI_VAL, so ping is successful
        mov r7, #1d
        sjmp imu_ping_done
    
    imu_ping_failed:
        mov r7, #0d
        ; sjmp imu_ping_done
        
    imu_ping_done:
        
;----------------
;lcall mpu_9250_init
mov acc, #IMU_ADDR ; stays the same for all i2c writes
    
    ; clear sleep mode 
    mov b, #PWR_MGMT_1
    mov r7, #0x00
    acall i2c_writebyte
    
    acall delay100
    
    ; get stable time source
    mov b, #PWR_MGMT_1
    mov r7, #0x01 ; auto select PLL or internal oscillator
    acall i2c_writebyte
    
    acall delay100
    acall delay100
    
    ; Configure Gyro and Thermometer
    ; Disable FSYNC and set thermometer and gyro bandwidth
    ; to 41 and 42 Hz, respectively
    mov b, #CONFIG
    mov r7, #0x03
    acall i2c_writebyte
    
    ; Set sample rate = gyroscope output rate/(1 + SMPLRT_DIV)
    mov b, #SMPLRT_DIV
    mov r7, #0x04
    acall i2c_writebyte
    
    ; Set gyroscope full scale range
    ; need to mask to leave reserved bits unchanged
    mov b, #GYRO_CONFIG
    acall i2c_readbyte ; r7 -> current config value
    
    ; mask
    xch a, r7 ; swap config/slave addr
    anl a, #0xe4 ; clear Fchoice bits [1:0] and AFS bits [4:3]
    orl a, #GYRO_FS_250 ; add full scale range
    xch a, r7 ; swap config/slave addr
        
    acall i2c_writebyte
    
    ; set accelerometer full scale range
    ; need to mask to leave reserved bits unchanged
    mov b, #ACCEL_CONFIG
    acall i2c_readbyte ; r7 -> current config value
    
    ; mask
    xch a, r7 ; swap config/slave addr
    anl a, #0xe7   ; clear AFS bits[4:3]
    orl a, #AFS_2G  ; add full scale range
    xch a, r7 ; swap config/slave addr
    
    acall i2c_writebyte
    
    ; set accelerometer sample rate
    ; need to mask to leave reserved bits unchanged
    mov b, #ACCEL_CONFIG2
    acall i2c_readbyte ; r7 -> current config value
    
    ; mask
    xch a, r7 ; swap config/slave addr
    anl a, #0xf0 ; Clear accel_fchoice_b (bit 3) 
                  ; and A_DLPFG (bits [2:0])
                  
    orl a, 0x03
    xch a, r7 ; swap config/slave addr
    
    acall i2c_writebyte
    
    ; configure interrupts and bypass enable:
    ; Set interrupt pin active high, push-pull, hold interrupt
    ; pin level HIGH until interrupt cleared,
    ; clear on read of INT_STATUS, and enable I2C_BYPASS_EN 
    ; so additional chips can join the I2C bus and all 
    ; can be controlled by the 8051 directly
    mov b, INT_PIN_CFG
    mov r7, #0x22
    acall i2c_writebyte
    
    mov b, INT_ENABLE
    mov r7, #0x01 ; Enable data ready (bit 0) interrupt
    acall i2c_writebyte
    
    acall delay100
    

;lcall mpu_mag_ping
   ; read the register 
    mov acc, #0x18  ; slave addr
    mov b, #WIA    ; reg addr 
    acall i2c_readbyte  ; read value -> r7
    
    ; check if read value != WHOAMI_VAL
    cjne r7, #MAG_WHOAMI_VAL, mag_ping_failed
    ; else read value = WHOAMI_VAL, so ping is successful
        mov r7, #1d
        sjmp mag_ping_done
    
    mag_ping_failed:
        mov r7, #0d
        ; sjmp mag_ping_done
         
    mag_ping_done:
    
; read accel
    ; read the register 
    mov acc, #IMU_ADDR  ; slave addr
    mov b, #ACCEL_XOUT_H    ; reg addr 
    lcall i2c_readbyte  ; read value -> r7
    mov b, #ACCEL_XOUT_L  
    lcall i2c_readbyte 
    mov b, #ACCEL_YOUT_H 
    lcall i2c_readbyte
    mov b, #ACCEL_YOUT_L
    lcall i2c_readbyte
    mov b, #ACCEL_ZOUT_H
    lcall i2c_readbyte
    mov b, #ACCEL_ZOUT_L
    lcall i2c_readbyte
    
testdone:
cpl p1.7
;acall delay100
sjmp testdone

;delay ~100ms (100,000us)
; 100*255*4 loops ~ 102,000 us
delay100:
    push 0
    push 1
    push 2
    
        mov r0, #255d
        mov r1, #100d
        mov r2, #2d
        
        delay100_loop:
            delay100_loop2:
                delay100_loop3:
                    djnz r0, delay100_loop3 ; 255 loops

                mov r0, #255d                                
                djnz r1, delay100_loop2 ; 100 loops
            
            mov r1, #100d 
            djnz r2, delay100_loop ; 2 loops                
                
    pop 2
    pop 1
    pop 0
ret

.inc mpu9250_registers.asm
.inc i2c.h.asm
