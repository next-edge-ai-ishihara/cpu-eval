// SPDX-License-Identifier: Apache-2.0
// Phases A-E: load and store address triggers, then byte, halfword and masked-word
// data triggers. Mismatches must not trap; matches trap with mscause=1 at the access.

#define STDOUT   0xd0580000
#define MRAC_VAL 0x5f555555
#define STORE_DATA_EXACT  0x80042
#define STORE_DATA_MASKED 0x800c2

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
    csrs mstatus, x2        // MIE=1: required for action=0 (breakpoint) triggers

    j phaseA_negctrl

.balign 4
phaseA_negctrl:
    la   x2, load_target_word
    csrw tdata2, x2
    li   x3, 0x41            // m=1, load=1
    csrw mcontrol, x3
    la   x11, load_decoy_word
    lw   x12, 0(x11)         // address does not match tdata2: must not trap
    j phaseA_posctrl

phaseA_posctrl:
    la   x8, expected_pc
    la   x9, phaseA_target
    sw   x9, 0(x8)
    la   x8, continue_pc
    la   x9, phaseB_negctrl
    sw   x9, 0(x8)
    la   x11, load_target_word
    la   x2, load_target_word
    csrw tdata2, x2
    li   x3, 0x41
    csrw mcontrol, x3
phaseA_target:
    lw   x12, 0(x11)         // address matches tdata2: must trap
    j fail

phaseB_negctrl:
    la   x8, expected_pc
    li   x9, 0xffffffff
    sw   x9, 0(x8)
    la   x2, store_target_word
    csrw tdata2, x2
    li   x3, 0x42            // m=1, store=1
    csrw mcontrol, x3
    la   x11, store_decoy_word
    li   x13, 0x12345678
    sw   x13, 0(x11)         // address does not match tdata2: must not trap
    j phaseB_posctrl

phaseB_posctrl:
    la   x8, expected_pc
    la   x9, phaseB_target
    sw   x9, 0(x8)
    la   x8, continue_pc
    la   x9, phaseC
    sw   x9, 0(x8)
    la   x11, store_target_word
    la   x2, store_target_word
    csrw tdata2, x2
    li   x3, 0x42
    csrw mcontrol, x3
phaseB_target:
    sw   x13, 0(x11)         // address matches tdata2: must trap
    j fail

.macro check_store_data phase, next, slot, op, control, match, negative, positive
\phase:
    csrw mcontrol, zero
    li   x2, \slot
    csrw tselect, x2
    la   x8, expected_pc
    la   x9, .Ltarget\@
    sw   x9, 0(x8)
    la   x8, continue_pc
    la   x9, \next
    sw   x9, 0(x8)
    la   x11, store_decoy_word
    li   x2, \match
    csrw tdata2, x2
    li   x3, \control
    csrw mcontrol, x3
    li   x13, \negative
    \op  x13, 0(x11)        // different data: must not trap
    li   x13, \positive
.Ltarget\@:
    \op  x13, 0(x11)        // matching data: must trap at this PC
    j fail
.endm

    check_store_data phaseC, phaseD, 1, sb, STORE_DATA_EXACT, 0x80, 0xffffff81, 0xffffff80
    check_store_data phaseD, phaseE, 2, sh, STORE_DATA_EXACT, 0x8080, 0xffff8180, 0xffff8080
    check_store_data phaseE, pass_test, 3, sw, STORE_DATA_MASKED, 0x81234567, 0x81234572, 0x81234562

pass_test:
    csrw mcontrol, zero
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
load_target_word:
    .word 0x1
load_decoy_word:
    .word 0x2
store_target_word:
    .word 0x0
store_decoy_word:
    .word 0x0
expected_pc:
    .word 0xffffffff
continue_pc:
    .word 0
