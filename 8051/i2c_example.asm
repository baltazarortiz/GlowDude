;*****************************************
; Write to slave device with
; slave address e.g. say 0x20
;*****************************************
	; Init i2c ports first
	lcall i2cinit
	; Send start condition
	lcall startc
	; Send slave address
	mov a,#20H
	acall send
	; after send call Carry flag has ACK bit
	; If you want to check if send was a
	; success or failure
	; Send data
	mov a,#07H
	acall send
	; Send another data
	mov a,#10
	acall send
	; Send stop condition
	acall stop
 
;*****************************************
; Read from slave device with
; slave address e.g. say 0x20
;*****************************************
	; Init i2c ports first
	lcall i2cinit
	; Send start condition
	lcall startc
	; Send slave address with Read bit set
	; So address is 0x20 | 1 = 0x21
	mov a,#21H
	acall send
	; Read one byte
	acall recv
	; Send ack
	acall ack
	; Read last byte
	acall recv
	; Send nak for last byte to indicate
	; End of transmission
	acall nak
	; Send stop condition
	acall stop
