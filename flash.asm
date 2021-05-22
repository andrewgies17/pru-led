    .cdecls "main.c"
    .clink
    .global start
    .asg 50000000, DELAY

start:
    JMP on

on:
    SET r30.t5 ; P9_27
    LDI32 r0, DELAY
wait_on:
    SUB r0, r0, 1
    QBNE wait_on, r0, 0
off:
    CLR r30.t5 ; P9_27
    LDI32 r0, DELAY
wait_off:
    SUB r0, r0, 1
    QBNE wait_off, r0, 0
    JMP on
