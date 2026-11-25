// SPDX-License-Identifier: Apache-2.0

#define DCCM_ADDR    0xf0040000
#define MRAC         0x7c0
#define CALL_COUNT   64

.section .text
.global _start
_start:
    la   x1, _trap
    csrw mtvec, x1

    li   x2, 0x00010000
    csrw MRAC, x2
    fence.i

    li   a0, 0
    csrr s2, mcycle
    jal  ra, body                 // call #1 (compulsory miss)
    csrr s3, mcycle
    sub  s2, s3, s2

    .rept CALL_COUNT - 2
    jal  ra, body                  // unmeasured middle call (unrolled)
    .endr

    csrr s4, mcycle
    jal  ra, body                 // call #CALL_COUNT (should be a hit)
    csrr s5, mcycle
    sub  s4, s5, s4

    li   x6, DCCM_ADDR
    sw   a0, 0(x6)                 // +0x0: icache call total
    addi x6, x6, 4
    sw   s2, 0(x6)                 // +0x4: call #1 cycles
    addi x6, x6, 4
    sw   s4, 0(x6)                 // +0x8: call #CALL_COUNT cycles
    fence
    li   t0, 0xf0040030
    li   t1, 1
    sw   t1, 0(t0)
    fence

halt_loop:
    j    halt_loop

// 'body' must occupy a separate 64-byte-aligned cache line.
.balign 64
body:
    addi a0, a0, 1
    ret
.balign 64

.align 4
_trap:
    j    halt_loop
