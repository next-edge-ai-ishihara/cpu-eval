// SPDX-License-Identifier: Apache-2.0

#define STDOUT   0xd0580000

.section .text
.option norelax          // Keep label offsets fixed.
.global _start
_start:
    csrw minstret, zero
    csrw minstreth, zero

    la   x2, trap_handler
    csrw mtvec, x2

    li   x2, 0x8
    csrs mstatus, x2        // MIE=1 enables action-0 breakpoints
    j phase1_exact

.balign 4
phase1_exact:
    li   x8, 0xffffffff
    la   x9, expected_pc
    sw   x8, 0(x9)
    li   x2, 0
    csrw tselect, x2
    la   x2, phase1_target
    csrw tdata2, x2
    li   x3, 0x44            // m=1, match=0 (exact), execute=1
    csrw mcontrol, x3
    la   x8, expected_pc
    la   x9, phase1_target
    sw   x9, 0(x8)
    la   x8, continue_pc
    la   x9, phase2_setup
    sw   x9, 0(x8)
phase1_target:
    nop
    j fail                   // must not fall through: the trigger must
                             // redirect control before this instruction

phase2_setup:
    la   x8, expected_pc
    li   x9, 0xffffffff
    sw   x9, 0(x8)
    la   x2, phase2_target
    andi x2, x2, -4          // clear bits[1:0]
    ori  x2, x2, 1           // bit0=1, bit1=0: the mask covers bits 0-1
    csrw tdata2, x2
    li   x3, 0xc4            // m=1, match=1 (masked), execute=1
    csrw mcontrol, x3
    la   x8, expected_pc
    la   x9, phase2_target
    sw   x9, 0(x8)
    la   x8, continue_pc
    la   x9, phase3_setup
    sw   x9, 0(x8)

    .option push
    .option norvc
    j    phase2_target
    .option pop
phase2_target:
    nop
    j fail

phase3_setup:
    la   x8, expected_pc
    li   x9, 0xffffffff
    sw   x9, 0(x8)
    .balign 4
    nop
phase3_setup_aligned:
    la   x2, phase3_target
    andi x2, x2, -4          // clear bits[1:0]
    ori  x2, x2, 1           // same 2-low-bit mask as phase 2
    xori x2, x2, 0x400       // flip bit 10: outside the mask, no code at that address
    csrw tdata2, x2
    li   x3, 0xc4            // m=1, match=1 (masked), execute=1
    csrw mcontrol, x3
phase3_target:
    nop
    j phase4_exact_miss

phase4_exact_miss:
    // Reuse the two-bit mask encoding, but disable masking. The target's
    // bit 1 differs from tdata2 even after the decoder supplies data bit 0.
    csrw mcontrol, zero
    la   x2, phase4_target
    andi x2, x2, -4
    ori  x2, x2, 1
    csrw tdata2, x2
    li   x3, 0x44
    csrw mcontrol, x3
    .balign 4
    .option push
    .option norvc
    j    phase4_target
    .option pop
    .2byte 0x0001       // Unreached c.nop. The target address is 2 mod 4.
phase4_target:
    nop
    j phase5_all_ones

phase5_all_ones:
    csrw mcontrol, zero
    li   x2, -1
    csrw tdata2, x2
    li   x3, 0xc4
    csrw mcontrol, x3
    nop
    j phase6_wider_mask

phase6_wider_mask:
    // Compare with the first zero at bit 2. The target's bit 1 is zero,
    // whereas tdata2 bit 1 is one. Both bits lie inside the masked range.
    csrw mcontrol, zero
    la   x2, phase6_target
    andi x2, x2, -8
    ori  x2, x2, 3
    csrw tdata2, x2
    la   x8, expected_pc
    la   x9, phase6_target
    sw   x9, 0(x8)
    la   x8, continue_pc
    la   x9, pass_test
    sw   x9, 0(x8)
    .balign 8
    li   x3, 0xc4
    csrw mcontrol, x3
phase6_target:
    nop
    j fail

.balign 8                // Resume outside the trigger's eight-byte range.
pass_test:
    li   x3, STDOUT
    li   x5, 0xff
    sb   x5, 0(x3)
pass_spin:
    j pass_spin

fail:
    li   x3, STDOUT
    li   x5, 0x1
    sb   x5, 0(x3)
fail_spin:
    j fail_spin

.balign 4
trap_handler:
    csrr x6, mcause
    li   x7, 0x3
    bne  x6, x7, fail

    csrr x6, 0x7ff           // mscause
    li   x7, 0x1
    bne  x6, x7, fail

    csrr x6, mepc
    la   x8, expected_pc
    lw   x7, 0(x8)
    bne  x6, x7, fail

    la   x8, continue_pc
    lw   x7, 0(x8)
    csrw mepc, x7
    mret

.section .data
.balign 8
expected_pc:
    .word 0xffffffff
continue_pc:
    .word 0
