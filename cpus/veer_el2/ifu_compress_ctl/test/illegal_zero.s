# SPDX-License-Identifier: Apache-2.0
# A zero compressed halfword must raise an illegal-instruction exception.

.option norvc
.section .text
.global _start
_start:
    la t0, trap
    csrw mtvec, t0
    j zero_halfword

.balign 4
trap:
    csrr t0, mcause
    li t1, 2
    bne t0, t1, fail
    csrr t0, mepc
    la t1, zero_halfword
    bne t0, t1, fail
    li a0, 0xff
    j finish

fail:
    li a0, 1
finish:
    li t0, 0xd0580000
    sb a0, 0(t0)
    j finish

zero_halfword:
    .2byte 0x0000
    j fail
