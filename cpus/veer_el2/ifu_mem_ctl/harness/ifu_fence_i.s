// SPDX-License-Identifier: Apache-2.0

    .section .text
    .option norvc
    .global _start
_start:
    la   t0, fail
    csrw mtvec, t0
    li   t0, 0x10000
    csrw 0x7c0, t0
    fence.i
    la   s0, cached_function

    li   t0, 2
    csrw mhpmevent3, t0
    csrci mcountinhibit, 8
    csrw mhpmcounter3, zero
    li   s1, 8
1:
    jalr ra, 0(s0)
    li   t0, 1
    bne  a0, t0, fail
    addi s1, s1, -1
    bnez s1, 1b
    csrsi mcountinhibit, 8
    csrr t0, mhpmcounter3
    beqz t0, fail

    // Replace the first instruction with addi a0, zero, 2.
    li   t0, 0x00200513
    sw   t0, 0(s0)
    fence rw, rw
    fence.i
    jalr ra, 0(s0)
    li   t0, 2
    bne  a0, t0, fail

    li   t1, 0xd0580000
    li   t0, 0xff
    sb   t0, 0(t1)
2:  j    2b

    .balign 4
fail:
    li   t1, 0xd0580000
    li   t0, 1
    sb   t0, 0(t1)
3:  j    3b

    .balign 64
cached_function:
    addi a0, zero, 1
    ret
