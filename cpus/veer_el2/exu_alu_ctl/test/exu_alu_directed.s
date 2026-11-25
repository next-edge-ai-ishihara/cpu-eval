// SPDX-License-Identifier: Apache-2.0
// Bit-manipulation results not covered by the generated program, then JALR
// targets that the fetch prediction gets wrong.

#define STDOUT 0xd0580000

#define CHECK(expected) li t1, expected; bne t0, t1, fail

.section .text
.global _start
_start:
    csrw minstret, zero
    csrw minstreth, zero
    li   x1, 0x5f555555
    csrw 0x7c0, x1
    la   x1, _trap
    csrw mtvec, x1

    li   a0, 0x12345678
    li   a1, 0x80f0000f
    li   a2, 0x7f018f80
    li   a3, 33
    li   a4, 31

    rev8   t0, a0
    CHECK(0x78563412)
    orc.b  t0, a2
    CHECK(0xffffffff)
    orc.b  t0, a1
    CHECK(0xffff00ff)
    zext.h t0, a2
    CHECK(0x00008f80)
    xnor   t0, a0, a1
    CHECK(0x6d3ba988)
    sext.b t0, a2
    CHECK(0xffffff80)
    sext.b t0, a0
    CHECK(0x00000078)
    sext.h t0, a2
    CHECK(0xffff8f80)
    sext.h t0, a1
    CHECK(0x0000000f)
    sh1add t0, a0, a1
    CHECK(0xa558acff)
    sh2add t0, a0, a1
    CHECK(0xc9c159ef)
    sh3add t0, a0, a1
    CHECK(0x1292b3cf)
    bset   t0, a0, a3
    CHECK(0x1234567a)
    bclr   t0, a1, a4
    CHECK(0x00f0000f)
    binv   t0, a2, a3
    CHECK(0x7f018f82)
    bext   t0, a1, a3
    CHECK(1)
    bext   t0, a0, zero
    CHECK(0)
    bseti  t0, a0, 31
    CHECK(0x92345678)
    bclri  t0, a2, 15
    CHECK(0x7f010f80)
    binvi  t0, a1, 0
    CHECK(0x80f0000e)
    bexti  t0, a0, 4
    CHECK(1)

    // Each call returns to a different address than the one it was called from.
    li   s0, 0
    li   s1, 3
call_loop:
    jal  ra, redirect_return
    j    fail
return_target:
    addi s0, s0, 1
    blt  s0, s1, call_loop

    // An indirect jump whose target changes between iterations.
    li   s0, 0
    la   s2, jump_a
    la   s3, jump_b
jump_loop:
    jalr zero, 0(s2)
    j    fail
jump_a:
    addi s0, s0, 1
    mv   s2, s3
    j    jump_loop
jump_b:
    li   t1, 1
    bne  s0, t1, fail

pass_test:
    li   a0, 0xff
_finish:
    li   x3, STDOUT
    sb   a0, 0(x3)
    beq  x0, x0, _finish
    .rept 100
    nop
    .endr

.balign 4
redirect_return:
    la   ra, return_target
    ret

fail:
    li   a0, 0x1
    j    _finish

.balign 4
_trap:
    j    fail
