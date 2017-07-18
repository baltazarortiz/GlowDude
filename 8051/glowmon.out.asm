
;   *************************************************
;   *                                               *
;   *  Glowmon - The Minimal 8051 Monitor Program   *
;   *       Modified for GlowDude
;   *                                               *
;   *  Portions of this program are courtesy of     *
;   *  Rigel Corporation, of Gainesville, Florida   *
;   *                                               *
;   *  Modified for 6.115                           *
;   *  Massachusetts Institute of Technology        *
;   *  January, 2001  Steven B. Leeb                *
;   *                                               *
;   *************************************************
.equ stack, 2fh           ; bottom of stack
                          ; - stack starts at 30h -
.equ errorf, 0            ; bit 0 is error status
;=================================================================
; 8032 hardware vectors
;=================================================================
   .org 00h               ; power up and reset vector
   ljmp start
   .org 03h               ; interrupt 0 vector
   ljmp start
   .org 0bh               ; timer 0 interrupt vector
   ljmp start
   .org 13h               ; interrupt 1 vector
   ljmp start
   .org 1bh               ; timer 1 interrupt vector
   ljmp start
   .org 23h               ; serial port interrupt vector
   ljmp start
   .org 2bh               ; 8052 extra interrupt vector
   ljmp start
;=================================================================
; begin main program
;=================================================================
   .org     100h
start:
   clr     ea             ; disable interrupts
   lcall   init
; initialize hardware
   lcall   print          ; print welcome message
   .db 0ah, 0dh,"GLOWMON> ", 0h
monloop:
   mov     sp,#stack      ; reinitialize stack pointer
   clr     ea             ; disable all interrupts
   clr     errorf         ; clear the error flag
   lcall   print          ; print prompt
   .db "*", 0h
   clr     ri             ; flush the serial input buffer
   lcall   getcmd         ; read the single-letter command
   mov     r2, a          ; put the command number in R2
   ljmp    nway           ; branch to a monitor routine
endloop:                  ; come here after command has finished
   sjmp monloop           ; loop forever in monitor loop
;=================================================================
; subroutine init
; this routine initializes the hardware
; set up serial port with a 11.0592 MHz crystal,
; use timer 1 for 9600 baud serial communications
;=================================================================
init:
   mov   tmod, #20h       ; set timer 1 for auto reload - mode 2
   mov   tcon, #41h       ; run counter 1 and set edge trig ints
   mov   th1,  #0fdh      ; set 9600 baud with xtal=11.059mhz
   mov   scon, #50h       ; set serial control reg for 8 bit data
                          ; and mode 1
   lcall i2cinit          ; ready the i2c bus
   ret
;=================================================================
; monitor jump table
;=================================================================
jumtab:
   .dw badcmd             ; command '@' 00
   .dw readaccel             ; command 'a' 01 used
   .dw setbiases             ; command 'b' 02 used
   .dw startcal             ; command 'c' 03 used
   .dw badcmd             ; command 'd' 04
   .dw ledenable             ; command 'e' 05 used
   .dw badcmd             ; command 'f' 06
   .dw readgyro             ; command 'g' 07 used
   .dw badcmd             ; command 'h' 08
   .dw initperipherals            ; command 'i' 09 used
   .dw badcmd             ; command 'j' 0a
   .dw badcmd             ; command 'k' 0b
   .dw badcmd             ; command 'l' 0c
   .dw badcmd             ; command 'm' 0d
   .dw badcmd             ; command 'n' 0e
   .dw badcmd             ; command 'o' 0f
   .dw ledpwm             ; command 'p' 10 used
   .dw badcmd             ; command 'q' 11
   .dw resetimu            ; command 'r' 12 used
   .dw badcmd             ; command 's' 13
   .dw badcmd             ; command 't' 14
   .dw ledupdate             ; command 'u' 15
   .dw badcmd             ; command 'v' 16
   .dw whoami           ; command 'w' 17 used
   .dw badcmd             ; command 'x' 18
   .dw badcmd             ; command 'y' 19
   .dw readtest             ; command 'z' 1a used

;*****************************************************************
; monitor command routines
;*****************************************************************
initperipherals:
    lcall mpu_9250_init
    lcall IS31FL3218_init_all
ljmp endloop

readtest:
    push b
    push 7
    push acc

    ; set accelerometer sample rate
    ; need to mask to leave reserved bits unchanged
    mov acc, #IMU_ADDR
    mov b, #ACCEL_CONFIG
    lcall i2c_readbyte ; r7 -> current config value

    pop acc
    pop 7
    pop b
ljmp endloop

ledupdate:
    lcall IS31FL3218_update
ljmp endloop


; enable or disable specific driver outputs
; syntax: e[0x13->0x15][XX = pattern for enable/disable]
ledenable:
    push acc
    push b
    push 7

    ; get 0x13->0x15 (IS31FL3218_ctl will ignore other values)
    lcall getbyt
    mov b, acc

    ; get hex pattern
    lcall getbyt

    lcall IS31FL3218_ctl

    pop 7
    pop b
    pop acc
ljmp endloop

; set pwm for specific led
; syntax: p[0x01->0x12][XX = pwm value]
ledpwm:
    push acc
    push b
    push 7

    ; get 0x01->0x12 (IS31FL3218_setpwm will ignore other values)
    lcall getbyt
    mov b, acc

    ; get pwm value
    lcall getbyt

    lcall IS31FL3218_setpwm

    pop 7
    pop b
    pop acc
ljmp endloop

; reset IMU
resetimu:
    push acc
    push b
    push 7

    mov acc, #IMU_ADDR
    mov b, #PWR_MGMT_1
    mov r7, #0x80
    lcall i2c_writebyte

    pop 7
    pop b
    pop acc
ljmp endloop

; make sure we're connected to the IMU.
; prints 1 for success, 0 for failure
whoami:
    lcall mpu_9250_ping
    mov acc, r7 ; put ping result into acc
    lcall prthex
ljmp endloop

readaccel:
    push acc

    mov acc, #ACCEL_XOUT_H
    lcall readsensor

    pop acc
ljmp endloop

readgyro:
    push acc

    mov acc, #GYRO_XOUT_H
    lcall readsensor

    pop acc
ljmp endloop

; get data for calibration and output to the serial console
startcal:
    push acc
    push b
    push 7
    push 0
    push 1

    lcall mpu_9250_get_calibration_data

    ; after this function call, the FIFO is filled with gyro/accel reads
    ; read FIFO sample count
    mov acc, #IMU_ADDR
    mov b, #FIFO_COUNTH
    lcall i2c_readbyte

    mov acc, r7
    mov r0, acc ; r0 = count high byte

    mov b, #FIFO_COUNTL
    lcall i2c_readbyte

    mov acc, r7
    mov r1, acc ; r1 = count low byte

    mov acc, #FIFO_R_W
    ; print the contents of the FIFO
    cal_lsb_loop:
        lcall readsensor ; accel data
        lcall readsensor ; gyro data
    djnz r1, cal_lsb_loop

    cal_msb_loop:
        cjne r0, #0d, cal_loopcont ; if msb != 0, continue
                         ; (check here because djnz decrements first)
        sjmp cal_loopdone  ; else we're done

    cal_loopcont:
        djnz r0, cal_lsb_loop ; count down msb and loop back to lsb

    cal_loopdone:

   ; lcall crlf

    ; transmit factory-set accelerometer biases
    mov acc, #XA_OFFSET_H
    lcall readsensor

    pop 1
    pop 0
    pop 7
    pop b
    pop acc
ljmp endloop

; receive biases from serial port and update
; IMU registers with the new values
;
; Expected input order (one byte per line):
;   (accel)
;   X_H
;   X_L
;   Y_H
;   Y_L
;   Z_H
;   Z_L
; then same pattern for gyro.
; we have to do 6 writes at a time since the gyro and accel bias
; regs are not next to each other
setbiases:
    push acc
    push b
    push 7
    push 0

    mov r7, #IMU_ADDR

    mov b, #XA_OFFSET_H ; starting point for accel writes
    mov r0, #6d ; 6 iterations for  x/y/z h/l bytes

    setbiases_loop1:
       ; TODO: send something back to signal next value is needed?
        lcall getbyt        ; read new bias from serial port -> acc

        xch a, r7           ; a = imu addr
                            ; r7 = new bias
        lcall i2c_writebyte
        xch a, r7           ; a = new bias (no longer needed,
                            ; will be overwritten next cycle)
                            ; r7 = imu addr

        inc b ; move to next bias register
    djnz r0, setbiases_loop1

    mov b, #XG_OFFSET_H ; starting point for gyro writes
    mov r0, #6d ; 6 iterations for  x/y/z h/l bytes

    setbiases_loop2:
       ; TODO: send something back to signal next value is needed?
        lcall getbyt        ; read new bias from serial port -> acc

        xch a, r7           ; a = imu addr
                            ; r7 = new bias
        lcall i2c_writebyte
        xch a, r7           ; a = new bias (no longer needed,
                            ; will be overwritten next cycle)
                            ; r7 = imu addr

        inc b ; move to next bias register
    djnz r0, setbiases_loop2

    pop 0
    pop 7
    pop b
    pop acc
ljmp endloop

;*****************************************************************
; monitor support routines
;*****************************************************************
badcmd:
   lcall print
   .db 0dh, 0ah," bad command ", 0h
   ljmp endloop
badpar:
   lcall print
   .db 0dh, 0ah," bad parameter ", 0h
   ljmp endloop

;===============================================================
; Subroutine getword
; Take in a 4 digit number over the serial port
; and store the binary representation in dptr
;===============================================================
getword:
	; Save register values
	push 0

	; high byte
	lcall getchr    ; get first digit
;	lcall sndchr	; echo digit to screen
	lcall ascbin	; convert ascii into binary representation

	; shift 4 to the left
	rl a
	rl a
	rl a
	rl a
	mov R0, A ; store in R0 (low nibble = 0)

	lcall getchr    ; get second digit
;	lcall sndchr	; echo digit to screen
	lcall ascbin	; convert ascii into binary representation

	add A, R0		; Combine high and low nibble
	mov DPH, A		; and store result in DPH

	;-------------------------------
	; low byte

	lcall getchr    ; Get third digit
;	lcall sndchr	; echo digit to screen
	lcall ascbin  ; and convert to binary
	; shift 4 to the left
	rl a
	rl a
	rl a
	rl a
	mov R0, A		; Store in R0 (low nibble = 0)

	lcall getchr	; Get fourth digit
;	lcall sndchr	; echo digit to screen
	lcall ascbin	; convert to binary

	add A, R0		; Combine high and low nibble
	mov DPL, A		; and store result in DPL

	; Now DPTR (the concatenation of DPH and DPL)
	; contains the address entered by the user, so we're done.

	; Restore register values
	pop 0
	ret

;===============================================================
; subroutine getbyt
; this routine reads in an 2 digit ascii hex number from the
; serial port. the result is returned in the acc.
;===============================================================
getbyt:
    push b

    lcall getchr           ; get msb ascii chr
;    lcall sndchr           ; echo command
    lcall ascbin           ; conv it to binary
    swap  a                ; move to most sig half of acc
    mov   b,  a            ; save in b
    lcall getchr           ; get lsb ascii chr
;    lcall sndchr           ; echo command
    lcall ascbin           ; conv it to binary
    orl   a,  b            ; combine two halves

    pop b
ret
;===============================================================
; subroutine getcmd
; this routine gets the command line.  currently only a
; single-letter command is read - all command line parameters
; must be parsed by the individual routines.
;
;===============================================================
getcmd:
   lcall getchr           ; get the single-letter command
   clr   acc.5            ; make upper case
;   lcall sndchr           ; echo command
   clr   C                ; clear the carry flag
   subb  a, #'@'          ; convert to command number
   jnc   cmdok1           ; letter command must be above '@'
   lcall badpar
cmdok1:
   push  acc              ; save command number
   subb  a, #1Bh          ; command number must be 1Ah or less
   jc    cmdok2
   lcall badpar           ; no need to pop acc since badpar
                          ; initializes the system
cmdok2:
   pop   acc              ; recall command number
   ret
;===============================================================
; subroutine nway
; this routine branches (jumps) to the appropriate monitor
; routine. the routine number is in r2
;================================================================
nway:
   mov   dptr, #jumtab    ;point dptr at beginning of jump table
   mov   a, r2            ;load acc with monitor routine number
   rl    a                ;multiply by two.
   inc   a                ;load first vector onto stack
   movc  a, @a+dptr       ;         "          "
   push  acc              ;         "          "
   mov   a, r2            ;load acc with monitor routine number
   rl    a                ;multiply by two
   movc  a, @a+dptr       ;load second vector onto stack
   push  acc              ;         "          "
   ret                    ;jump to start of monitor routine


;*****************************************************************
; general purpose routines
;*****************************************************************
chrtonum:
; convert ascii character in acc into its binary equivalent
; For ascii #, results in 0x0# in acc
	add A, #0xd0
	;anl A, #0x0f         ; mask off top nibble
	ret

numtochr:
; convert binary number in acc into its ascii equivalent
	add A, #0x30
	;anl A, #0x0f   ;mask off top nibble
	ret
;===============================================================
; subroutine sndchr
; this routine takes the chr in the acc and sends it out the
; serial port.
;===============================================================
sndchr:
   clr  scon.1            ; clear the tx  buffer full flag.
   mov  sbuf,a            ; put chr in sbuf
txloop:
   jnb  scon.1, txloop    ; wait till chr is sent
   ret
;===============================================================
; subroutine getchr
; this routine reads in a chr from the serial port and saves it
; in the accumulator.
;===============================================================
getchr:
   jnb  ri, getchr        ; wait till character received
   mov  a,  sbuf          ; get character
   anl  a,  #7fh          ; mask off 8th bit
   clr  ri                ; clear serial status bit
   ret
;===============================================================
; subroutine print
; print takes the string immediately following the call and
; sends it out the serial port.  the string must be terminated
; with a null. this routine will ret to the instruction
; immediately following the string.
;===============================================================
print:
   pop   dph              ; put return address in dptr
   pop   dpl
prtstr:
   clr  a                 ; set offset = 0
   movc a,  @a+dptr       ; get chr from code memory
   cjne a,  #0h, mchrok   ; if termination chr, then return
   sjmp prtdone
mchrok:
   lcall sndchr           ; send character
   inc   dptr             ; point at next character
   sjmp  prtstr           ; loop till end of string
prtdone:
   mov   a,  #1h          ; point to instruction after string
   jmp   @a+dptr          ; return
;===============================================================
; subroutine crlf
; crlf sends a carriage return line feed out the serial port
;===============================================================
crlf:
   push acc  ; backup acc
   mov   a,  #0ah         ; print lf
   lcall sndchr
cret:
   mov   a,  #0dh         ; print cr
   lcall sndchr
   pop acc ;restore acc
   ret
;===============================================================
; subroutine prthex
; this routine takes the contents of the acc and prints it out
; as a 2 digit ascii hex number.
;===============================================================
prthex:
   push acc
   lcall binasc           ; convert acc to ascii
   lcall sndchr           ; print first ascii hex digit
   mov   a,  r2           ; get second ascii hex digit
   lcall sndchr           ; print it
   pop acc
   ret
;===============================================================
; subroutine binasc
; binasc takes the contents of the accumulator and converts it
; into two ascii hex numbers.  the result is returned in the
; accumulator and r2.
;===============================================================
binasc:
   mov   r2, a            ; save in r2
   anl   a,  #0fh         ; convert least sig digit.
   add   a,  #0f6h        ; adjust it
   jnc   noadj1           ; if a-f then readjust
   add   a,  #07h
noadj1:
   add   a,  #3ah         ; make ascii
   xch   a,  r2           ; put result in reg 2
   swap  a                ; convert most sig digit
   anl   a,  #0fh         ; look at least sig half of acc
   add   a,  #0f6h        ; adjust it
   jnc   noadj2           ; if a-f then re-adjust
   add   a,  #07h
noadj2:
   add   a,  #3ah         ; make ascii
   ret

;===============================================================
; subroutine ascbin
; this routine takes the ascii character passed to it in the
; acc and converts it to a 4 bit binary number which is returned
; in the acc.
;===============================================================
ascbin:
   clr   errorf
   add   a,  #0d0h        ; if chr < 30 then error
   jnc   notnum
   clr   c                ; check if chr is 0-9
   add   a,  #0f6h        ; adjust it
   jc    hextry           ; jmp if chr not 0-9
   add   a,  #0ah         ; if it is then adjust it
   ret
hextry:
   clr   acc.5            ; convert to upper
   clr   c                ; check if chr is a-f
   add   a,  #0f9h        ; adjust it
   jnc   notnum           ; if not a-f then error
   clr   c                ; see if char is 46 or less.
   add   a,  #0fah        ; adjust acc
   jc    notnum           ; if carry then not hex
   anl   a,  #0fh         ; clear unused bits
   ret
notnum:
   setb  errorf           ; if not a valid digit
   ljmp  endloop

; read 6 addresses from sensor address in acc (x/y/z h/l)
readsensor:
    push acc
    push b
    push 7
    push 0
    push 1

    mov b, #IMU_ADDR
    xch a, b ; b = reg address
             ; a = imu address

    mov r0, #3d ; 3 iterations for x/y/z
    readsensor_loop_outer:
        ;lcall crlf
        mov r1, #2d ; 2 iterations for h/l

        readsensor_loop_inner:
            lcall i2c_readbyte  ; read value -> r7
            xch a, r7           ; acc = read value
                                ; r7 = slave address
            lcall prthex        ; send to screen
            xch a, r7           ; acc = slave address
                                ; r7 = read value
            inc b               ; move to next register
        djnz r1, readsensor_loop_inner
    djnz r0, readsensor_loop_outer

    pop 1
    pop 0
    pop 7
    pop b
    pop acc
ret


;===============================================================
; mon_return is not a subroutine.
; it simply jumps to address 0 which resets the system and
; invokes the monitor program.
; A jump or a call to mon_return has the same effect since
; the monitor initializes the stack.
;===============================================================
mon_return:
   ljmp  0
; end of MINMON

; ==== Included from "mpu9250.asm" by AS115: ====
; Invensense MPU-9250 IMU driver for 8051.
; https://github.com/kriswiner/MPU-9250/blob/master/MPU9250BasicAHRS.ino
; used as a reference

; ==== Included from "mpu9250_registers.asm" by AS115: ====
; Other constants
.equ IMU_ADDR, 0xd0

.equ GYRO_FS_250, 0x00
.equ AFS_2G, 0x00

; Register map for accelerometer and gyroscope in the mpu-9250
.equ SELF_TEST_X_GYRO,  0x00
.equ SELF_TEST_Y_GYRO,  0x01
.equ SELF_TEST_Z_GYRO,  0x02
.equ SELF_TEST_X_ACCEL, 0x0d
.equ SELF_TEST_Y_ACCEL, 0x0e
.equ SELF_TEST_Z_ACCEL, 0x0f
.equ XG_OFFSET_H, 0x13
.equ XG_OFFSET_L, 0x14
.equ YG_OFFSET_H, 0x15
.equ YG_OFFSET_L, 0x16
.equ ZG_OFFSET_H, 0x17
.equ ZG_OFFSET_L, 0x18
.equ SMPLRT_DIV, 0x19
.equ CONFIG, 0x1a
.equ GYRO_CONFIG, 0x1b
.equ ACCEL_CONFIG, 0x1c
.equ ACCEL_CONFIG2, 0x1d
.equ LP_ACCEL_ODR, 0x1e
.equ WOM_THR, 0x1f
.equ FIFO_EN, 0x23
.equ I2C_MST_CTRL, 0x24
.equ I2C_SLV0_ADDR, 0x25
.equ I2C_SLV0_REG, 0x26
.equ I2C_SLV0_CTRL, 0x27
.equ I2C_SLV1_ADDR, 0x28
.equ I2C_SLV1_REG, 0x29
.equ I2C_SLV1_CTRL, 0x2a
.equ I2C_SLV2_ADDR, 0x2b
.equ I2C_SLV2_REG, 0x2c
.equ I2C_SLV2_CTRL, 0x2d
.equ I2C_SLV3_ADDR, 0x2e
.equ I2C_SLV3_REG, 0x2f
.equ I2C_SLV3_CTRL, 0x30
.equ I2C_SLV4_ADDR, 0x31
.equ I2C_SLV4_REG, 0x32
.equ I2C_SLV4_DO, 0x33
.equ I2C_SLV4_CTRL, 0x34
.equ I2C_SLV4_DI, 0x35
.equ I2C_MST_STATUS, 0x36
.equ INT_PIN_CFG, 0x37
.equ INT_ENABLE, 0x38
.equ INT_STATUS, 0x3a
.equ ACCEL_XOUT_H, 0x3b
.equ ACCEL_XOUT_L, 0x3c
.equ ACCEL_YOUT_H, 0x3d
.equ ACCEL_YOUT_L, 0x3e
.equ ACCEL_ZOUT_H, 0x3f
.equ ACCEL_ZOUT_L, 0x40
.equ TEMP_OUT_H, 0x41
.equ TEMP_OUT_L, 0x42
.equ GYRO_XOUT_H, 0x43
.equ GYRO_XOUT_L, 0x44
.equ GYRO_YOUT_H, 0x45
.equ GYRO_YOUT_L, 0x46
.equ GYRO_ZOUT_H, 0x47
.equ GYRO_ZOUT_L, 0x48
.equ EXT_SENS_DATA_00, 0x49
.equ EXT_SENS_DATA_01, 0x4a
.equ EXT_SENS_DATA_02, 0x4b
.equ EXT_SENS_DATA_03, 0x4c
.equ EXT_SENS_DATA_04, 0x4d
.equ EXT_SENS_DATA_05, 0x4e
.equ EXT_SENS_DATA_06, 0x4f
.equ EXT_SENS_DATA_07, 0x50
.equ EXT_SENS_DATA_08, 0x51
.equ EXT_SENS_DATA_09, 0x52
.equ EXT_SENS_DATA_10, 0x53
.equ EXT_SENS_DATA_11, 0x53
.equ EXT_SENS_DATA_12, 0x55
.equ EXT_SENS_DATA_13, 0x56
.equ EXT_SENS_DATA_14, 0x57
.equ EXT_SENS_DATA_15, 0x58
.equ EXT_SENS_DATA_16, 0x59
.equ EXT_SENS_DATA_17, 0x5a
.equ EXT_SENS_DATA_18, 0x5b
.equ EXT_SENS_DATA_19, 0x5c
.equ EXT_SENS_DATA_20, 0x5d
.equ EXT_SENS_DATA_21, 0x5e
.equ EXT_SENS_DATA_22, 0x5f
.equ EXT_SENS_DATA_23, 0x60
.equ I2C_SLV0_DO, 0x63
.equ I2C_SLV1_DO, 0x64
.equ I2C_SLV2_DO, 0x65
.equ I2C_SLV3_DO, 0x66
.equ I2C_MST_DELAY_CTRL, 0x67
.equ SIGNAL_PATH_RESET, 0x68
.equ MOT_DETECT_CTRL, 0x69
.equ USER_CTRL, 0x6a
.equ PWR_MGMT_1, 0x6b
.equ PWR_MGMT_2, 0x6c
.equ FIFO_COUNTH, 0x72
.equ FIFO_COUNTL, 0x73
.equ FIFO_R_W, 0x74
.equ WHO_AM_I, 0x75
.equ WHOAMI_VAL, 0x71 ; expected output when reading WHOAMI reg
.equ XA_OFFSET_H, 0x77
.equ XA_OFFSET_L, 0x78
.equ YA_OFFSET_H, 0x7a
.equ YA_OFFSET_L, 0x7b
.equ ZA_OFFSET_H, 0x7d
.equ ZA_OFFSET_L, 0x7e

; magnetometer i2c address
. equ MAG_ADDR, 0x18

; Register map for the magnetometer in the imu-9250
.equ WIA, 0x00
.equ MAG_WHOAMI_VAL, 0x48

.equ INFO, 0x01
.equ ST1, 0x02
.equ HXL, 0x03
.equ HXH, 0x04
.equ HYL, 0x05
.equ HYH, 0x06
.equ HZL, 0x07
.equ HZH, 0x08
.equ ST2, 0x09
.equ CNTL, 0x0a
; .equ RSV, 0x0b ; do not access
.equ ASTC, 0x0c
; .equ TS1, 0x0d ; do not access
; .equ TS2, 0x0e ; do not access
.equ I2CDIS, 0x0f
.equ ASAX, 0x10
.equ ASAY, 0x11
.equ ASAZ, 0x12

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












; ==== Included from "i2c.h.asm" by AS115: ====
; 8051 bitbanged I2C implementation
; modified from
; https://www.8051projects.net/wiki/I2C_Implementation_on_8051
; to have an API similar to the Arduino Wire library

;***************************************
; Ports Used for I2C Communication
;***************************************

; Other constants
.equ READ_BIT, 0x01

;***************************************
; Initializing I2C Bus Communication
;***************************************
i2cinit:
	setb P1.0 ; sda = P1.0
	setb P1.1 ; scl = P1.1
	ret

;****************************************
; Restart Condition for I2C Communication
; uses slave address in acc
;****************************************
i2c_restart:
	clr P1.1                 ; scl low ; scl = P1.1
	lcall i2c_quarterdelay
	setb P1.0                ; sda high ; sda = P1.0
	lcall i2c_quarterdelay
	setb P1.1                ; scl high ; scl = P1.1
	lcall i2c_quarterdelay
	clr P1.0                 ; sda low ; sda = P1.0
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
	setb P1.1                ; scl high ; scl = P1.1
	setb P1.0                ; sda high ; sda = P1.0
	lcall i2c_halfdelay
	clr P1.0                 ; sda low ; sda = P1.0
	lcall i2c_halfdelay
	nop
	lcall i2c_write      ; send slave address
	ret

;*****************************************
; Stop Condition For I2C Bus
; Compare to Wire.endTransmisison()
;*****************************************
i2c_stop:
	clr P1.1                 ; scl low ; scl = P1.1
	lcall i2c_quarterdelay
	clr P1.0                 ; sda low ; sda = P1.0
	lcall i2c_quarterdelay
	setb P1.1                ; scl high ; scl = P1.1
	lcall i2c_quarterdelay
	setb P1.0                ; sda high ; sda = P1.0
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
	clr P1.1                 ; scl low ; scl = P1.1
	lcall i2c_quarterdelay
	rlc a                   ; top bit of acc -> carry
	mov P1.0,c               ; carry -> sda ; sda = P1.0
	lcall i2c_quarterdelay
	setb P1.1                ; toggle scl pin so that slave can ; scl = P1.1
	                        ; latch data bit

	djnz r7,i2c_write_back  ; loop through bits

	; get ack from slave after 8 bits have been sent
	clr P1.1                 ; scl low ; scl = P1.1
	setb P1.0                ; sda high ; sda = P1.0
	lcall i2c_quarterdelay
	setb P1.1                ; scl high ; scl = P1.1
	lcall i2c_quarterdelay

	mov c, P1.0 ; sda = P1.0
	;clr scl

	pop 7
	pop acc
	ret

;*********************************************
; ACK and NAK for I2C Bus (use when reading)
;*********************************************
i2c_ack:
	setb P1.1                ; scl low ; scl = P1.1
	lcall i2c_quarterdelay
	clr P1.0                 ; sda low ; sda = P1.0
	lcall i2c_quarterdelay
    setb P1.1                ; scl high ; scl = P1.1
    lcall i2c_halfdelay
	ret

i2c_nak:
	setb P1.1                ; scl low ; scl = P1.1
	lcall i2c_quarterdelay
	setb P1.0                ; sda high ; sda = P1.0
	lcall i2c_quarterdelay
	setb P1.1                ; scl high ; scl = P1.1
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
	clr P1.1 ; scl = P1.1
	setb P1.1 ; scl = P1.1
	mov c,P1.0 ; sda = P1.0
	rlc a
	djnz r7,i2c_recv_back
	clr P1.1 ; scl = P1.1
	setb P1.0 ; sda = P1.0
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

; ==== Included from "IS31FL3218.asm" by AS115: ====
; IS31FL3218 LED Driver
; Uses I2C - i2c.h.asm must be included
; in the same project. Uncomment below
; if not used anywhere else.

; Constants
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

    setb P0.0 ; SDB = P0.0
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
    clr P0.0 ; SDB = P0.0
ret

; Disable hardware shutdown
IS31FL3218_hw_poweron:
    setb P0.0 ; SDB = P0.0
ret
