; Invensense MPU-9250 IMU driver for 8051.
; https://github.com/kriswiner/MPU-9250/blob/master/MPU9250BasicAHRS.ino
; used as a reference

.inc mpu9250_registers.asm

; read the WHO_AM_I register to make sure we're correctly
; connected. 
; Returns 1 in r7 if the read value is correct, else 0
mpu_9250_ping:
    push acc
    push b
    
    mov acc, #IMU_ADDR  ; slave addr
    
    ; reset IMU
;    mov b, #PWR_MGMT_1
;    mov r7, #0x80
;    lcall i2c_writebyte
    
;    lcall delay100
    
    ; read the register 
    mov b, #WHO_AM_I    ; reg addr 
    lcall i2c_readbyte  ; read value -> r7
    
    ; check if read value != WHOAMI_VAL
    cjne r7, #WHOAMI_VAL, imu_ping_checkother
    ; else read value = WHOAMI_VAL, so ping is successful
        mov r7, #1d
        sjmp imu_ping_done
       
    ; sketchy chips off amazon don't always match spec
    imu_ping_checkother:
    cjne r7, #0x73, imu_ping_failed
    ; lol why does the other chip have this as the id
        ; else read value = 0x73, so ping is successful
        mov r7, #1d
        sjmp imu_ping_done
        
    imu_ping_failed:
        mov r7, #0d
        ; sjmp imu_ping_done
         
    imu_ping_done:
    
    pop b
    pop acc
ret

; read the WHO_AM_I register of the magnetometer. 
; This won't work until the MPU has been initialized
mpu_mag_ping:
    push acc
    push b
    
    ; read the register 
    mov acc, #MAG_ADDR  ; slave addr
    mov b, #WIA    ; reg addr 
    lcall i2c_readbyte  ; read value -> r7
    
    ; check if read value != WHOAMI_VAL
    cjne r7, #MAG_WHOAMI_VAL, mag_ping_failed
    ; else read value = WHOAMI_VAL, so ping is successful
        mov r7, #1d
        sjmp mag_ping_done
    
    mag_ping_failed:
        mov r7, #0d
        ; sjmp mag_ping_done
         
    mag_ping_done:
    
    pop b
    pop acc
ret

; get the IMU ready to use
mpu_9250_init:
    push acc
    push b
    push 7
    
    mov acc, #IMU_ADDR ; stays the same for all i2c writes
    
    ; reset IMU
    ; mov b, #PWR_MGMT_1
    ; mov r7, #0x80
    ; lcall i2c_writebyte

    lcall delay100
    
    ; clear sleep mode 
    mov b, #PWR_MGMT_1
    mov r7, #0x00
    lcall i2c_writebyte
    
    lcall delay100
    
    ; get stable time source
    mov b, #PWR_MGMT_1
    mov r7, #0x01 ; auto select PLL or internal oscillator
    lcall i2c_writebyte
    
    lcall delay100
    lcall delay100
    
    ; Configure Gyro and Thermometer
    ; Disable FSYNC and set thermometer and gyro bandwidth
    ; to 41 and 42 Hz, respectively
    mov b, #CONFIG
    mov r7, #0x03
    lcall i2c_writebyte
    
    ; Set sample rate = gyroscope output rate/(1 + SMPLRT_DIV)
    mov b, #SMPLRT_DIV
    mov r7, #0x04
    lcall i2c_writebyte
    
    ; Set gyroscope full scale range
    ; need to mask to leave reserved bits unchanged
    mov b, #GYRO_CONFIG
    lcall i2c_readbyte ; r7 -> current config value
    
    ; mask
    xch a, r7 ; swap config/slave addr
    anl a, #0xe4 ; clear Fchoice bits [1:0] and AFS bits [4:3]
    orl a, #GYRO_FS_250 ; add full scale range
    xch a, r7 ; swap config/slave addr
        
    lcall i2c_writebyte
    
    ; set accelerometer full scale range
    ; need to mask to leave reserved bits unchanged
    mov b, #ACCEL_CONFIG
    lcall i2c_readbyte ; r7 -> current config value
    
    ; mask
    xch a, r7 ; swap config/slave addr
    anl a, #0xe7   ; clear AFS bits[4:3]
    orl a, #AFS_2G  ; add full scale range
    xch a, r7 ; swap config/slave addr
    
    lcall i2c_writebyte
    
    ; set accelerometer sample rate
    ; need to mask to leave reserved bits unchanged
    mov b, #ACCEL_CONFIG2
    lcall i2c_readbyte ; r7 -> current config value
    
    ; mask
    xch a, r7 ; swap config/slave addr
    anl a, #0xf0 ; Clear accel_fchoice_b (bit 3) 
                  ; and A_DLPFG (bits [2:0])
                  
    orl a, 0x03
    xch a, r7 ; swap config/slave addr
    
    lcall i2c_writebyte
    
    ; configure interrupts and bypass enable:
    ; Set interrupt pin active high, push-pull, hold interrupt
    ; pin level HIGH until interrupt cleared,
    ; clear on read of INT_STATUS, and enable I2C_BYPASS_EN 
    ; so additional chips can join the I2C bus and all 
    ; can be controlled by the 8051 directly
    mov b, INT_PIN_CFG
    mov r7, #0x22
    lcall i2c_writebyte
    
    mov b, INT_ENABLE
    mov r7, #0x01 ; Enable data ready (bit 0) interrupt
    lcall i2c_writebyte
    
    lcall delay100
    
    pop 7
    pop b
    pop acc
ret


mpu_9250_get_calibration_data:
    push acc
    push b
    push 7
    
    mov acc, #IMU_ADDR ; set up slave addr
    
    ; reset IMU
    mov b, #PWR_MGMT_1
    mov r7, #0x80
    lcall i2c_writebyte

    lcall delay100
    
    ; get stable time source
    ; auto select PLL or internal oscillator
    mov b, #PWR_MGMT_1
    mov r7, #0x01
    lcall i2c_writebyte
    
    mov b, #PWR_MGMT_2
    mov r7, #0x00 
    lcall i2c_writebyte
    
    lcall delay100
    lcall delay100
    
    ; Configure device for bias calculation
    ; disable all interrupts
    mov b, #INT_ENABLE
    mov r7, #0x00
    lcall i2c_writebyte
    
    ; disable fifo
    mov b, #FIFO_EN
    mov r7, #0x00
    lcall i2c_writebyte
    
    ; turn on internal clock source
    mov b, #PWR_MGMT_1
    mov r7, #0x00
    lcall i2c_writebyte
    
    ; disable i2c master
    mov b, #I2C_MST_CTRL
    mov r7, #0x00
    lcall i2c_writebyte
    
    ; disable FIFO and i2c master modes
    mov b, #USER_CTRL
    mov r7, #0x00
    lcall i2c_writebyte
    
    ; reset fifo and dmp
    mov b, #USER_CTRL
    mov r7, #0x0c
    lcall i2c_writebyte
    
    lcall delay100
    
    ; Configure MPU6050 gyro and accelerometer
    ; for bias calculation
   
    ; set lpf to 188hz
    mov b, #CONFIG
    mov r7, #0x01
    lcall i2c_writebyte
    
    ; set sample rate to 1khz
    mov b, #SMPLRT_DIV
    mov r7, #0x00
    lcall i2c_writebyte
    
    ; set gyro full scale to 250 deg/s (max)
    mov b, #GYRO_CONFIG
    mov r7, #0x00
    lcall i2c_writebyte
    
    ; set accel full scale to 2g (max)
    mov b, #ACCEL_CONFIG
    mov r7, #0x00
    lcall i2c_writebyte
    
    ; Configure FIFO to capture accelerometer 
    ; and gyro data for bias calculation
    
    ; enable FIFO
    mov b, #USER_CTRL
    mov r7, #0x40
    lcall i2c_writebyte
    
    ; enable gyro and accelerometer sensors for FIFO 
    ; (max size 512 bytes)
    mov b, #FIFO_EN
    mov r7, #0x78
    lcall i2c_writebyte
    
    lcall delay40 ; accumulate 40 samples in 40 milliseconds = 480 bytes
    
    ; At end of sample accumulation, turn off FIFO sensor read
    ; Disable gyro and accelerometer sensors for FIFO
    mov b, #FIFO_EN
    mov r7, #0x00
    lcall i2c_writebyte
    
    pop 7
    pop b
    pop acc
ret

mpu_9250_readaccel:
    push acc
    push b
    
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
        
    pop b
    pop acc
ret

mpu_9250_readgyro:

ret

mpu_9250_readcompass:

ret

imu_i2c_read:

ret

; read 6 bytes starting at address in acc
imu_i2c_burstread:

ret

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

;delay ~500ms (100,000us)
; 100*255*4 loops ~ 102,000 us
delay500:
    push 0
    push 1
    push 2
    
        mov r0, #255d
        mov r1, #100d
        mov r2, #5d
        
        delay500_loop:
            delay500_loop2:
                delay500_loop3:
                    djnz r0, delay500_loop3 ; 255 loops

                mov r0, #255d                                
                djnz r1, delay500_loop2 ; 100 loops
            
            mov r1, #100d 
            djnz r2, delay500_loop ; 2 loops                
                
    pop 2
    pop 1
    pop 0
ret

; delay ~40ms = 40,000us
; 255*79*2 = 40290us
delay40:
    push 0
    push 1
    push 2
    
        mov r0, #255d
        mov r1, #79d
        mov r2, #2d
        
        delay40_loop:
            delay40_loop2:
                delay40_loop3:
                    djnz r0, delay40_loop3 ; 255 loops

                mov r0, #255d                                
                djnz r1, delay40_loop2 ; 100 loops
            
            mov r1, #100d 
            djnz r2, delay40_loop ; 2 loops                
                
    pop 2
    pop 1
    pop 0
ret












.inc i2c.h.asm

