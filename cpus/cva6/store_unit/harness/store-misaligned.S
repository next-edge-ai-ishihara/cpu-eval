#include "model_test.h"

    .section .text.init
    .option norvc
    .globl rvtest_entry_point
rvtest_entry_point:
    la      t0, trap
    csrw    mtvec, t0
    li      a0, 0
    la      a1, word
    li      a2, 0x11223344
    sw      a2, 0(a1)
    lw      t0, 0(a1)
    bne     t0, a2, fail
    li      a3, 0x55667788
faulting_store:
    sw      a3, 1(a1)
    j       fail
resume:
    li      t0, 1
    bne     a0, t0, fail
    lw      t0, 0(a1)
    bne     t0, a2, fail
    lw      t0, 4(a1)
    li      t1, 0x77665544
    bne     t0, t1, fail
    li      a4, 1
    j       halt
fail:
    li      a4, 3
halt:
    la      t1, result
    sw      a4, 0(t1)
    lw      t1, 0(t1)
    li      a4, 1
    sw      a4, tohost, t0
    j       halt

    .balign 4
trap:
    csrr    t0, mcause
    li      t1, 6
    bne     t0, t1, fail
    csrr    t0, mepc
    la      t1, faulting_store
    bne     t0, t1, fail
    addi    a0, a0, 1
    la      t0, resume
    csrw    mepc, t0
    mret

    .section .data
RVMODEL_DATA_BEGIN
word:
    .word 0
    .word 0x77665544
result:
    .word 0
RVMODEL_DATA_END
