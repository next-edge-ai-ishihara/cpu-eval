#include "defines.h"

#define STDOUT 0xd0580000

.section .text
.global _start
_start:
    csrw minstret, zero
    csrw minstreth, zero

    la   x1, _trap
    csrw mtvec, x1

    li   x1, 0x5f555555
    csrw 0x7c0, x1

    // ---- warmup: 20 iterations, not measured ----
    li   s2, 20
warmup_loop:
    mv   a0, s2
    call branch_block
    addi s2, s2, -1
    bnez s2, warmup_loop

    // ---- measurement: 100 iterations ----
    csrr s3, mcycle
    li   s2, 100
meas_loop:
    mv   a0, s2
    call branch_block
    addi s2, s2, -1
    bnez s2, meas_loop
    csrr s4, mcycle
    sub  s4, s4, s3

    // ---- print s4 as 8 hex digits ----
    li   s5, 28
print_loop:
    srl  a1, s4, s5
    andi a1, a1, 0xf
    li   t1, 10
    blt  a1, t1, print_digit
    addi a1, a1, ('a' - '0' - 10)
print_digit:
    addi a1, a1, '0'
    li   x3, STDOUT
    sb   a1, 0(x3)
    addi s5, s5, -4
    bgez s5, print_loop

    li   x3, STDOUT
    li   a1, '\n'
    sb   a1, 0(x3)

    li   a0, 0xff  // success
_finish:
    li   x3, STDOUT
    sb   a0, 0(x3)
    beq  x0, x0, _finish

.align 4
_trap:
    li a0, 1 # failure
    j _finish

// a0 selects the branch directions; clobbers a1, t2 and t3.
// Uncompressible .4byte NOPs spread the eight branches over three 1 KiB pc[14:10] regions.
.align 4
.global branch_block
branch_block:
    andi t2, a0, 1
    la   a1, counters
    bnez t2, bb_1
    lw   t3, 0(a1)
    addi t3, t3, 1
    sw   t3, 0(a1)
    j    bb_1_done
bb_1:
    lw   t3, 0(a1)
    addi t3, t3, 2
    sw   t3, 0(a1)
bb_1_done:
    .rept 90
    .4byte 0x00000013
    .endr

    andi t2, a0, 2
    la   a1, counters
    addi a1, a1, 4
    bnez t2, bb_2
    lw   t3, 0(a1)
    addi t3, t3, 1
    sw   t3, 0(a1)
    j    bb_2_done
bb_2:
    lw   t3, 0(a1)
    addi t3, t3, 2
    sw   t3, 0(a1)
bb_2_done:
    .rept 90
    .4byte 0x00000013
    .endr

    andi t2, a0, 4
    la   a1, counters
    addi a1, a1, 8
    bnez t2, bb_3
    lw   t3, 0(a1)
    addi t3, t3, 1
    sw   t3, 0(a1)
    j    bb_3_done
bb_3:
    lw   t3, 0(a1)
    addi t3, t3, 2
    sw   t3, 0(a1)
bb_3_done:
    .rept 90
    .4byte 0x00000013
    .endr

    andi t2, a0, 8
    la   a1, counters
    addi a1, a1, 12
    bnez t2, bb_4
    lw   t3, 0(a1)
    addi t3, t3, 1
    sw   t3, 0(a1)
    j    bb_4_done
bb_4:
    lw   t3, 0(a1)
    addi t3, t3, 2
    sw   t3, 0(a1)
bb_4_done:
    .rept 90
    .4byte 0x00000013
    .endr

    andi t2, a0, 16
    la   a1, counters
    addi a1, a1, 16
    bnez t2, bb_5
    lw   t3, 0(a1)
    addi t3, t3, 1
    sw   t3, 0(a1)
    j    bb_5_done
bb_5:
    lw   t3, 0(a1)
    addi t3, t3, 2
    sw   t3, 0(a1)
bb_5_done:
    .rept 90
    .4byte 0x00000013
    .endr

    andi t2, a0, 32
    la   a1, counters
    addi a1, a1, 20
    bnez t2, bb_6
    lw   t3, 0(a1)
    addi t3, t3, 1
    sw   t3, 0(a1)
    j    bb_6_done
bb_6:
    lw   t3, 0(a1)
    addi t3, t3, 2
    sw   t3, 0(a1)
bb_6_done:
    .rept 90
    .4byte 0x00000013
    .endr

    andi t2, a0, 64
    la   a1, counters
    addi a1, a1, 24
    bnez t2, bb_7
    lw   t3, 0(a1)
    addi t3, t3, 1
    sw   t3, 0(a1)
    j    bb_7_done
bb_7:
    lw   t3, 0(a1)
    addi t3, t3, 2
    sw   t3, 0(a1)
bb_7_done:
    .rept 90
    .4byte 0x00000013
    .endr

    andi t2, a0, 128
    la   a1, counters
    addi a1, a1, 28
    bnez t2, bb_8
    lw   t3, 0(a1)
    addi t3, t3, 1
    sw   t3, 0(a1)
    j    bb_8_done
bb_8:
    lw   t3, 0(a1)
    addi t3, t3, 2
    sw   t3, 0(a1)
bb_8_done:
    ret

.data
.align 4
counters:
    .word 0,0,0,0,0,0,0,0
