// SPDX-License-Identifier: Apache-2.0
// Trigger 0 execute-address match: no trap with tdata1.m=0 (phase 1) or a .data
// address (phase 2); a trap with mcause=3, mscause=1 and mepc at the match (phase 3).

#define STDOUT   0xd0580000
#define MRAC_VAL 0x5f555555

.section .text
.global _start
_start:
    csrw minstret, zero
    csrw minstreth, zero
    li   x2, MRAC_VAL
    csrw 0x7c0, x2

    la   x2, trap_handler
    csrw mtvec, x2

    li   x2, 0x8
    csrs mstatus, x2        // MIE=1: breakpoint triggers fire only with MIE set
    j phase1_m_gate

.balign 4
phase1_m_gate:
    la   x2, phase1_target
    csrw tdata2, x2
    li   x3, 0x04            // m=0, execute=1: address matches, M-mode disabled
    csrw mcontrol, x3
phase1_target:
    nop
    j phase2_addr_mismatch

phase2_addr_mismatch:
    la   x2, negctrl_addr    // .data address, never an instruction-fetch PC here
    csrw tdata2, x2
    li   x3, 0x44            // m=1, execute=1: enabled, but address will never match
    csrw mcontrol, x3
    nop
    nop
    nop
    j phase3_posctrl

phase3_posctrl:
    la   x8, expected_pc
    la   x9, phase3_target
    sw   x9, 0(x8)
    la   x8, continue_pc
    la   x9, pass_test
    sw   x9, 0(x8)
    la   x2, phase3_target
    csrw tdata2, x2
    li   x3, 0x44            // m=1, execute=1: enabled, address matches
    csrw mcontrol, x3
phase3_target:
    nop
    j fail                   // must not fall through: the trigger must
                             // redirect control before this instruction

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
negctrl_addr:
    .word 0xdeadbeef
expected_pc:
    .word 0xffffffff
continue_pc:
    .word 0
