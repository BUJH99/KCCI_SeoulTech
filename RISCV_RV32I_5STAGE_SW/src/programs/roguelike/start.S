    .section .text.start
    .globl _start
    .globl __bss_start
    .globl __bss_end
    .globl __stack_top

_start:
    lui     sp, %hi(__stack_top)
    addi    sp, sp, %lo(__stack_top)

    lui     t0, %hi(__bss_start)
    addi    t0, t0, %lo(__bss_start)
    lui     t1, %hi(__bss_end)
    addi    t1, t1, %lo(__bss_end)

.Lclear_bss:
    bgeu    t0, t1, .Lcall_main
    sw      zero, 0(t0)
    addi    t0, t0, 4
    jal     zero, .Lclear_bss

.Lcall_main:
    jal     ra, main

.Lhalt:
    jal     zero, .Lhalt
