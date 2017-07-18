; 8051 bitbanged I2C implementation
; modified from 
; https://www.8051projects.net/wiki/I2C_Implementation_on_8051
; to have an API similar to the Arduino Wire library

;***************************************
; Ports Used for I2C Communication
;***************************************
.define sda P1.0
.define scl P1.1

; Other constants
.equ READ_BIT, 0x01
 
;***************************************
; Initializing I2C Bus Communication
;***************************************
i2cinit:
	setb sda
	setb scl
	ret
 
;****************************************
; Restart Condition for I2C Communication
; uses slave address in acc
;****************************************
i2c_restart:
	clr scl                 ; scl low
	lcall i2c_quarterdelay
	setb sda                ; sda high
	lcall i2c_quarterdelay
	setb scl                ; scl high
	lcall i2c_quarterdelay
	clr sda                 ; sda low
	lcall i2c_quarterdelay
    nop
	lcall i2c_write      ; send slave address
	ret
 
;****************************************
; Start Condition for I2C Communication
; uses slave address in acc
; Compare to Wire.beginTransmission()
;****************************************
i2c_start:
	setb scl                ; scl high
	setb sda                ; sda high
	lcall i2c_halfdelay
	clr sda                 ; sda low 
	lcall i2c_halfdelay      
	nop
	lcall i2c_write      ; send slave address
	ret
 
;*****************************************
; Stop Condition For I2C Bus
; Compare to Wire.endTransmisison()
;*****************************************
i2c_stop:
	clr scl                 ; scl low
	lcall i2c_quarterdelay
	clr sda                 ; sda low
	lcall i2c_quarterdelay
	setb scl                ; scl high
	lcall i2c_quarterdelay
	setb sda                ; sda high
	lcall i2c_quarterdelay
	ret
 
;*****************************************
; Sending Data to slave on I2C bus
; data sent from acc
; i2c_start must be called before using this
; method. Compare to Wire.write()
;*****************************************
i2c_write:
    push acc
    push 7

	mov r7,#08
i2c_write_back:             ; repeat for 8 bits
	clr scl                 ; scl low
	lcall i2c_quarterdelay
	rlc a                   ; top bit of acc -> carry             
	mov sda,c               ; carry -> sda
	lcall i2c_quarterdelay
	setb scl                ; toggle scl pin so that slave can
	                        ; latch data bit

	djnz r7,i2c_write_back  ; loop through bits

	; get ack from slave after 8 bits have been sent
	clr scl                 ; scl low
	setb sda                ; sda high
	lcall i2c_quarterdelay
	setb scl                ; scl high
	lcall i2c_quarterdelay

	mov c, sda
	;clr scl
	
	pop 7
	pop acc
	ret
 
;*********************************************
; ACK and NAK for I2C Bus (use when reading)
;*********************************************
i2c_ack:
	setb scl                ; scl low
	lcall i2c_quarterdelay
	clr sda                 ; sda low
	lcall i2c_quarterdelay
    setb scl                ; scl high
    lcall i2c_halfdelay
	ret
 
i2c_nak:
	setb scl                ; scl low
	lcall i2c_quarterdelay
	setb sda                ; sda high
	lcall i2c_quarterdelay
	setb scl                ; scl high
	lcall i2c_halfdelay
	ret
 
;*****************************************
; Receiving Data from slave on I2C bus
; data stored in acc
;*****************************************
i2c_recv:
    push 7
	mov r7,#08
i2c_recv_back:
	clr scl
	setb scl
	mov c,sda
	rlc a
	djnz r7,i2c_recv_back
	clr scl
	setb sda
	pop 7
	ret
	
; Helper functions (written for 6.115, based on example code
; and Wire library API)

;*****************************************
; Full start/write to register/stop sequence
; slave address in acc
; register address in B
; data in r7
;*****************************************
i2c_writebyte:
    push acc
    push B
    push 7
    
    lcall i2c_start         ; start(address in acc)
    xch a, B              ; acc = reg address
    lcall i2c_write      ; send reg address
    
    xch a, r7             ; acc = data
    lcall i2c_write      ; send data
    lcall i2c_stop          ; stop
    
    pop 7
    pop B
    pop acc 
ret

;*****************************************
; Full start/read from register/stop sequence
; slave address in acc
; register address in B
; received data put into r7
;*****************************************
i2c_readbyte:
    push acc
    push B
   
    lcall i2c_start      ; start(slave addr)
    
    xch a, B                ; acc = reg address
                            ; B   = slave address
                            
    lcall i2c_write      ; send reg address
 
    xch a, B    ; acc = slave address
                ; B   = reg address
    orl a, #00000001b ; add read bit to slave address
   
                
    lcall i2c_restart       ; restart(slave addr w/ read bit)
 
    lcall i2c_recv          ; read one byte
    
    ; Send nack to indicate end of read
	lcall i2c_nak               ; NACK
	
	lcall i2c_stop              ; stop
	
    ; recv puts data in acc
    mov r7, acc ; r7 -> read data

    pop B
    pop acc
ret

;delay ~461us
i2c_halfdelay:
    lcall i2c_quarterdelay
    lcall i2c_quarterdelay
ret

; delay ~231 us
i2c_quarterdelay:
    push 0
  
       ; mov r0, #231d
        mov r0, #1d
        
        quarterdelay_loop:
            djnz r0, quarterdelay_loop              
            
    pop 0
ret
