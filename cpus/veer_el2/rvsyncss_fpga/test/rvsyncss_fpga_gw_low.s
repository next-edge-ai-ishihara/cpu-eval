// SPDX-License-Identifier: Apache-2.0
// Both request lines are low: inverted-polarity line 6 must pend and win over line 7.
// The handler disables both lines and jumps to the result check without mret.

#define STDOUT      0xd0580000
#define PIC_BASE    0xf00c0000
#define PIC_MEIE    (PIC_BASE + 0x2000)
#define PIC_GWCTRL  (PIC_BASE + 0x4000)
#define MEIVT       0xbc8
#define MEIPT       0xbc9
#define MIE_MEIE    0x800
#define MSTATUS_MIE 0x8
#define UNSET       0xffffffff
#define POLL_LIMIT  100000

.section .text
.global _start
_start:
    csrw minstret, zero
    csrw minstreth, zero
    li x2, 0x5f555555
    csrw 0x7c0, x2

    la x2, vec_table
    csrw MEIVT, x2
    csrw MEIPT, zero

    j main

.balign 4
main:
    la x10, claim_result
    li x11, UNSET
    sw x11, 0(x10)

    // Both physical request lines are low. Line 6 has inverted polarity
    // and must pend; line 7 has normal polarity and must not pend.
    // Expected winner: line 6.
    li x5, PIC_BASE
    li x6, 8
    sw x6, 6*4(x5)          // meipl[6] = 8
    li x6, 2
    sw x6, 7*4(x5)          // meipl[7] = 2
    li x8, PIC_MEIE
    li x6, 1
    sw x6, 6*4(x8)          // meie[6] = 1
    sw x6, 7*4(x8)          // meie[7] = 1
    li x9, PIC_GWCTRL
    li x6, 1
    sw x6, 6*4(x9)          // meigwctrl[6] = 1 (inverted polarity, level type)
    sw zero, 7*4(x9)        // meigwctrl[7] = 0

    li x3, STDOUT
    li x7, 0x90
    sw x7, 0(x3)             // clear all interrupt request signals

    li x6, MIE_MEIE
    csrs mie, x6
    csrs mstatus, MSTATUS_MIE

    li x20, 0
1:
    lw x12, 0(x10)
    li x13, UNSET
    bne x12, x13, 2f
    addi x20, x20, 1
    li x21, POLL_LIMIT
    blt x20, x21, 1b
    j fail
2:
    lw x12, 0(x10)
    li x13, 6
    bne x12, x13, fail

pass_test:
    li x3, STDOUT
    li x5, 0xff
    sb x5, 0(x3)
pass_spin:
    j pass_spin

fail:
    li x3, STDOUT
    li x5, 0x1
    sb x5, 0(x3)
fail_spin:
    j fail_spin

// Whichever line wins, both are disabled before the result check -- see the
// file header for the test's handler policy.
h6:
    la x28, claim_result
    li x29, 6
    sw x29, 0(x28)
    li x28, PIC_MEIE
    sw zero, 6*4(x28)
    sw zero, 7*4(x28)
    j 2b

h7:
    la x28, claim_result
    li x29, 7
    sw x29, 0(x28)
    li x28, PIC_MEIE
    sw zero, 6*4(x28)
    sw zero, 7*4(x28)
    j 2b

// Safety net for an unexpected claim id.
h_spurious:
    la x28, claim_result
    li x29, 0xdeadbeef
    sw x29, 0(x28)
    j 2b

.section .data
.balign 1024
vec_table:
    .rept 6
    .word h_spurious
    .endr
    .word h6           // 6
    .word h7           // 7
    .rept 24
    .word h_spurious
    .endr

claim_result:
    .word 0xffffffff
