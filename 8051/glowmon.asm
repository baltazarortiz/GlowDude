
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

.inc mpu9250.asm
.inc IS31FL3218.asm
