// SPDX-License-Identifier: Apache-2.0
// The testbench routes ICCM accesses from the core LSU to the DMA slave port.

#define STDOUT 0xd0580000
#define ICCM_BASE 0xee000000

.section .text
.global _start
_start:
    csrw minstret, zero
    csrw minstreth, zero
    la   x1, _trap
    csrw mtvec, x1

    li   x5, 0xa5a51234
    li   x6, ICCM_BASE
    sw   x5, 0(x6)
    fence
    lw   x7, 0(x6)
    bne  x7, x5, fail

    li   x5, 0x1234a5a5
    li   x6, ICCM_BASE
    addi x6, x6, 4
    sw   x5, 0(x6)
    fence
    lw   x7, 0(x6)
    bne  x7, x5, fail

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
_trap:
    li   a0, 1
    j    _finish
