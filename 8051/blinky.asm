; Make an LED blink with the 8253 to make sure we can program it

.org 100h
loop:
    cpl P0.0
    lcall nops
sjmp loop

; Routine which runs the nop command in loops to generate a ~0.5 second delay
nops:
    ; save regs
    push acc
    push 0
    push 1

    ; 3 nested loops needed to generate a long enough delay
    ; 256*256*8 nops = ~0.5 second delay
    mov R1, #4d
        nop_loop1:
        mov R0, #255d
            nop_loop2:
            mov A, #255d
            nop_loop3:
                nop
                djnz acc,nop_loop3
            djnz R0,nop_loop2
        djnz R1,nop_loop3

    ; restore regs
    pop 1
    pop 0
    pop acc
    ret
