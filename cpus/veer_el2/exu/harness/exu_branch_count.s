// SPDX-License-Identifier: Apache-2.0

    .section .text
    .option norvc
    .global _start
_start:
    la   t0, fail
    csrw mtvec, t0

    // VeeR EL2 event 26 counts retired taken branches.
    li   t0, 26
    csrw mhpmevent3, t0
    csrci mcountinhibit, 8
    csrw mhpmcounter3, zero

    li   a0, 0
    beq  a0, zero, first_taken
    j    fail
first_taken:
    bne  a0, zero, fail
    addi a0, a0, 1
    bne  a0, zero, second_taken
    j    fail
second_taken:
    beq  a0, zero, fail
    csrsi mcountinhibit, 8
    csrr a1, mhpmcounter3
    li   t0, 2
    bne  a1, t0, fail

    li   t1, 0xd0580000
    li   t0, 0xff
    sb   t0, 0(t1)
1:  j    1b

    .balign 4
fail:
    li   t1, 0xd0580000
    li   t0, 1
    sb   t0, 0(t1)
2:  j    2b
