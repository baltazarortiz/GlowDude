; turn on an LED over i2c

;------------------------------    
clr p3.2

; toggle HW shutdown
clr p3.4
setb p3.4

lcall i2cinit

mov acc, #0xa8 ; slave address

; turn off sw shutdown
; don't worry about ack checking anymore
mov b, #0x00 ; shutdown address
mov r7, #0x01 ; 1 for chip on
acall i2c_writebyte

;------------------------------    

; enable LEDs

mov r7, #0xff ; all on

mov b, #0x13 ; ctl1 address
lcall i2c_writebyte

mov b, #0x14 ;ctl2
lcall i2c_writebyte

mov b, #0x15 ;ctl3
lcall i2c_writebyte

mov r7, #5d ; pwm = 128
testdone:
    ; led pwm = 128
    mov r3, #0x12 ; led 18 first
    led_loop:
        mov b, r3
        lcall i2c_writebyte
    djnz r3, led_loop ; count down

    ; --------------
    ; update to commit changes
    mov b, #0x16 ; update address
    ; any r7 value triggers the update
    acall i2c_writebyte
    
    lcall delay100
    lcall delay100
    lcall delay100
    lcall delay100
    lcall delay100

    ; if r7 != 5, set = 5
    cjne r7, #5d, turnon
        ; else set = 0
        mov r7, #1d
        sjmp testdone
    
    turnon:
        mov r7, #5d
    
sjmp testdone

.inc i2c.h.asm

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
