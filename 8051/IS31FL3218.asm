; IS31FL3218 LED Driver
; Uses I2C - i2c.h.asm must be included
; in the same project. Uncomment below
; if not used anywhere else.

; Constants
.define SDB P0.0
.equ IS31FL3218_i2c_addr, 0xa8
.equ SHUTDOWN, 0x00
; individual PWM duty cycle registers are 0x01 -> 0x12
.equ CTL1, 0x13 ; Channel 1 to 6 enable bit
.equ CTL2, 0x14 ; Channel 7 to 12 enable bit
.equ CTL3, 0x15 ; Channel 13 to 18 enable bit
.equ UPDATE, 0x16
.equ RESET, 0x17

; Functions
IS31FL3218_init:
; Disable HW and SW shutdown (less instructions and more
; readable than doing each separately when setting things
; up). Don't enable any outputs.

    mov acc, #IS31FL3218_i2c_addr
    
    mov b, #RESET
    lcall i2c_writebyte
    
    ; turn on chip
    mov b, #SHUTDOWN
    mov r7, #0x01 ; 1 for chip on
    lcall i2c_writebyte

    setb SDB
ret

IS31FL3218_init_all:
; Init and enable all outputs.
    push acc
    push b
    push 7
    
    mov acc, #IS31FL3218_i2c_addr
    
    lcall IS31FL3218_init
    
    ; enable all LEDs
    mov r7, #0xff ; all on

    mov b, #CTL1
    lcall i2c_writebyte

    mov b, #CTL2
    lcall i2c_writebyte

    mov b, #CTL3
    lcall i2c_writebyte

    pop 7
    pop b
    pop acc
ret

IS31FL3218_ctl:
; Set CTL{B} = Acc value to enable or disable
; specific driver outputs.
; B must be in the range [0x13,0x15] or this method
; does nothing.
    push acc
    push b
    push 7

    xch a, b ; put b value into acc for range check

; check if b within 0x13 and 0x15 (inclusive)
    ctl_chk13:
        cjne   a, #13h, ctl_gt   ; If B is not 0x13, check >
        ljmp   ctl_chk_valid      ; A = 0x13, valid 

        ctl_gt: ; check if B is greater than 0x55
            jnc ctl_chk15 ; carry = 0 if B > 0x13, 
                          ; so now check if <= 0x15
            
            ; else a < 0x13, so do nothing
            sjmp ctl_chk_invalid
            

    ctl_chk15:
        cjne   a, #15h, ctl_lt   ; If B is not 0x15, check <
        ljmp   ctl_chk_valid      ; A = 0x15, valid 

        ctl_lt: ; check if B is greater than 0x55
            jc ctl_chk_valid ; carry = 1 if B < 0x15,
                               ;  and we've checked 
                               ; >= 0x13, so it's valid
            
            ; else a > 0x15, so do nothing
            sjmp ctl_chk_invalid


    ctl_chk_valid:
        xch a, b ; restore a and b

        mov r7, #IS31FL3218_i2c_addr
        xch a, r7 ; a = i2c addr
                  ; r7 = desired enabled setting
  
        ; b = register address
        
        lcall i2c_writebyte

    ctl_chk_invalid: ; if B is not in range, do nothing
        ; TODO: status bit somewhere?
        
    pop 7
    pop b
    pop acc
ret

IS31FL3218_update:
    push acc
    push b
    
    mov acc, #IS31FL3218_i2c_addr
    mov b, #UPDATE
    ; any r7 value is fine

    lcall i2c_writebyte
    
    pop b
    pop acc
ret

; Set pwmreg{B} = Acc value to change
; an output's duty cycle.
; B must be in the range [0x01,0x12] or this method
; does nothing. 
IS31FL3218_setpwm:
    push acc
    push b
    push 7

    xch a, b ; put b value into acc for range check
    
; check if b within 0x1 and 0x12 (inclusive)
    pwm_chk1:
        cjne   a, #1h, pwm_gt   ; If B is not 0x1, check >
        ljmp   pwm_check_valid      ; A = 0x1, valid 

        pwm_gt: ; check if B is greater than 0x1
            jnc pwm_chk12 ; carry = 0 if B > 0x1, 
                          ; so now check if <= 0x12
            
            ; else a < 0x1, so do nothing
            sjmp pwm_chk_invalid
            
    pwm_chk12:
        cjne   a, #12h, pwm_lt   ; If B is not 0x12, check <
        ljmp   pwm_check_valid      ; A = 0x12, valid 

        pwm_lt: ; check if B is greater than 0x12
            jc pwm_check_valid ; carry = 1 if B < 0x12,
                               ;  and we've checked 
                               ; >= 0x1, so it's valid
            
            ; else a > 0x12, so do nothing
            sjmp pwm_chk_invalid

    pwm_check_valid:
        xch a, b ; restore a and b

        mov r7, #IS31FL3218_i2c_addr
        xch a, r7 ; a = i2c addr
                  ; r7 = desired pwm setting
  
        ; b = register address
        
        lcall i2c_writebyte

    pwm_chk_invalid: ; if B is not in range, do nothing
        ; TODO: status bit somewhere?
        
    pop 7
    pop b
    pop acc
ret

; Enable software shutdown.
; Registers retain data, but
; no output (lower power usage)
IS31FL3218_sw_shutdown:
    push acc
    push b
    push 7
    
    mov acc, #IS31FL3218_i2c_addr
    
    ; turn on chip
    mov b, #SHUTDOWN
    mov r7, #0x00 ; 0 for chip off
    lcall i2c_writebyte
    
    pop 7
    pop b
    pop acc
ret

; Disable software shutdown
IS31FL3218_sw_poweron:
    push acc
    push b
    push 7
    
    mov acc, #IS31FL3218_i2c_addr
    
    ; turn on chip
    mov b, #SHUTDOWN
    mov r7, #0x01 ; 1 for chip on
    lcall i2c_writebyte
    
    pop 7
    pop b
    pop acc
ret 

; Enable hardware shutdown
IS31FL3218_hw_shutdown:
    clr SDB
ret

; Disable hardware shutdown
IS31FL3218_hw_poweron:
    setb SDB
ret
