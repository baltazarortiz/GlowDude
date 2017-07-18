; Read whoami from IMU

;------------------------------    
; Init i2c ports first
.equ IMU_ADDR, 0xd0

	lcall i2cinit
	
    ; turn off sleep mode
    mov acc, #IMU_ADDR 
	mov b, #0x6B ; PWR_MGMT_1 reg address 
	mov r7, #0x00 ; turn off sleep mode
	
	acall i2c_writebyte
	
; -------------------------
	
	; Read one byte from WHOAMI
	; acc has IMU_ADDR
	mov b, #0x75 ; WHOAMI reg address
	acall i2c_readbyte
	
testdone:
cpl p1.7
sjmp testdone

.inc i2c.h.asm

