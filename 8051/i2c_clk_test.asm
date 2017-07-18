i2c_halfdelay:
; wait long enough that i2c doesn't break
                                             ; # of machine cycles
    push 0                                            ; 2
    mov r0, #110d                                     ; 2
    halfdelay_loop:
    	djnz r0, halfdelay_loop ; dec until r0 = 0  ; 2 * 255

    mov r0, #110d                                     ; 2
    halfdelay_loop1:
    	djnz r0, halfdelay_loop1 ; dec until r0 = 0  ; 2 * 207


    pop 0                                             ; 2
    nop
    nop                                               ; 2
                                              ; = 934 cycles
                                                ; * 1.08 us/cy
    cpl P1.0    ; so toggle P1.0.
sjmp i2c_halfdelay    ; and start over again.
