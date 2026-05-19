    .section .text.startup, "ax", @progbits
    .globl _start
    .align 2

_start:
    la   sp, __stack_top
    call bootrom_main

1:
    jal  zero, 1b
