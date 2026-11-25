// SPDX-License-Identifier: Apache-2.0
// Two pending lines with unequal, then equal, priority. The fast-redirect
// handler records the claim id selected by el2_cmp_and_mux.

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

    // Line 4: priority 5, normal gateway polarity/type.
    // Line 5: priority 10, normal gateway polarity/type.
    // Expected winner: line 5 (10 > 5).
    li x5, PIC_BASE
    li x6, 5
    sw x6, 4*4(x5)          // meipl[4] = 5
    li x6, 10
    sw x6, 5*4(x5)          // meipl[5] = 10
    li x8, PIC_MEIE
    li x6, 1
    sw x6, 4*4(x8)          // meie[4] = 1
    sw x6, 5*4(x8)          // meie[5] = 1
    li x9, PIC_GWCTRL
    sw zero, 4*4(x9)        // meigwctrl[4] = 0 (normal polarity, level type)
    sw zero, 5*4(x9)        // meigwctrl[5] = 0

    li x3, STDOUT
    li x7, (4<<8)|0x81
    sw x7, 0(x3)             // set extintsrc_req[4]
    li x7, (5<<8)|0x81
    sw x7, 0(x3)             // set extintsrc_req[5]
    fence iorw, iorw

    li x6, MIE_MEIE
    csrs mie, x6
    li x22, 5
    li x23, 'U'
    csrs mstatus, MSTATUS_MIE
    jal x1, wait_for_claim

    // Both external requests remain asserted. Their handlers disabled
    // both lines at the PIC. Install the tie before re-enabling either.
    csrc mstatus, MSTATUS_MIE
    li x11, UNSET
    sw x11, 0(x10)
    li x5, PIC_BASE
    li x6, 10
    sw x6, 4*4(x5)          // meipl[4] = meipl[5] = 10
    li x8, PIC_MEIE
    li x6, 1
    sw x6, 4*4(x8)
    sw x6, 5*4(x8)
    fence iorw, iorw
    lw x14, 4*4(x5)
    li x13, 10
    bne x14, x13, fail
    lw x14, 5*4(x5)
    bne x14, x13, fail
    li x22, 4
    li x23, 'T'
    csrs mstatus, MSTATUS_MIE
    jal x1, wait_for_claim
    j pass_test

wait_for_claim:
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
    sb x23, 0(x3)
    li x14, '?'
    li x13, 10
    bgeu x12, x13, 3f
    addi x14, x12, '0'
3:
    sb x14, 0(x3)
    li x14, '\n'
    sb x14, 0(x3)
    bne x12, x22, fail
    ret

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

// Disable both lines at the PIC before mret so the other pending line
// cannot cause a second fast-interrupt redirect before the test returns.

h4:
    la x28, claim_result
    li x29, 4
    sw x29, 0(x28)
    li x28, PIC_MEIE
    sw zero, 4*4(x28)
    sw zero, 5*4(x28)
    fence iorw, iorw
    mret

h5:
    la x28, claim_result
    li x29, 5
    sw x29, 0(x28)
    li x28, PIC_MEIE
    sw zero, 4*4(x28)
    sw zero, 5*4(x28)
    fence iorw, iorw
    mret

h_spurious:
    la x28, claim_result
    li x29, 0xdeadbeef
    sw x29, 0(x28)
    li x28, PIC_MEIE
    sw zero, 4*4(x28)
    sw zero, 5*4(x28)
    fence iorw, iorw
    mret

.section .data
.balign 1024
vec_table:
    .word h_spurious   // 0 -- documented spurious/no-interrupt case
    .word h_spurious   // 1
    .word h_spurious   // 2
    .word h_spurious   // 3
    .word h4           // 4
    .word h5           // 5
    .rept 26
    .word h_spurious
    .endr

claim_result:
    .word 0xffffffff
