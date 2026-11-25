// Check the branch-misprediction counter after 60 repeated call/return pairs.
#include "defines.h"

#define STDOUT 0xd0580000
#define MHPMEVENT3 0x323
#define MHPMCOUNTER3 0xb03
#define MHPMCOUNTER3H 0xb83
#define MCOUNTINHIBIT 0x320
#define MHPME_BRANCH_MP 25

.section .text
.global _start
_start:
    csrw minstret, zero
    csrw minstreth, zero

    la   x1, _trap
    csrw mtvec, x1

    li   x1, 0x5f555555
    csrw 0x7c0, x1

    csrw MCOUNTINHIBIT, zero
    li   x5, MHPME_BRANCH_MP
    csrw MHPMEVENT3, x5
    csrw MHPMCOUNTER3, zero
    csrw MHPMCOUNTER3H, zero

    // ---- 60 iterations of the identical call/return pair ----
    li   s2, 60
loop:
    call sub
    addi s2, s2, -1
    bnez s2, loop

    csrr s3, MHPMCOUNTER3   // s3 = branches mispredicted, whole run

    // ---- print s3 as 8 hex digits, then PASS/FAIL ----
    li   s5, 28
print_loop:
    srl  a1, s3, s5
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

    li   s4, 30
    bgt  s3, s4, fail

pass_test:
    li   a0, 0xff
_finish:
    li   x3, STDOUT
    sb   a0, 0(x3)
    beq  x0, x0, _finish
    .rept 100
    nop
    .endr

fail:
    li   a0, 1
    j    _finish

.align 4
.global sub
sub:
    ret

.align 4
_trap:
    li a0, 1
    j _finish
