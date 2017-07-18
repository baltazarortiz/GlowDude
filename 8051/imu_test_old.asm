; Read whoami from IMU

;------------------------------    
; Init i2c ports first

	lcall i2cinit
	
	; Send start condition
;	lcall startc
	
	; Send slave address with Read bit set
	; b1101000 + 0 (lsb grounded)
	;
	; -> 0x68
	; a <- i2c addr
	
;	mov a, #0xd0 ; imu address
;	acall send
	
;	mov a, #0x6B ; PWR_MGMT_1 reg address
;	acall send 
	
;	mov a, #0x00 ; turn off sleep mode
;	acall send 
	
;	acall stop
	
	; -------------------------
	
	; Read one byte from WHOAMI
	acall startc ; start condition

	mov a, #0xd0 ; send i2c address with write bit
	acall send 

	mov a, #0x75 ; whoami ; and register address that is going to be read
	acall send
    
    acall rstart ; send restart
	
	mov a, #0xd1 ; send imu address with read bit
	acall send
	
    ; Read one byte
	acall recv
	; Send nak for last byte to indicate
	; End of transmission
	acall nak
	; Send stop condition
	acall stop

testdone:
cpl p1.7
sjmp testdone

.inc i2c.h.asm

