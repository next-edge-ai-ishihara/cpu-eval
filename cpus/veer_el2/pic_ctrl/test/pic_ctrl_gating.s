// SPDX-License-Identifier: Apache-2.0
// Directed el2_pic_ctrl test of enable gating and priority-threshold masking.

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
#define SHORT_LIMIT 200

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

    // Phase 1: disabled line 4 (priority 15) must lose to enabled line 5 (priority 5).
    li x5, PIC_BASE
    li x6, 15
    sw x6, 4*4(x5)          // meipl[4] = 15
    fence iorw, iorw
    li x6, 5
    sw x6, 5*4(x5)          // meipl[5] = 5
    fence iorw, iorw
    li x8, PIC_MEIE
    li x6, 1
    sw x6, 5*4(x8)          // meie[5] = 1 (line 4 left disabled)
    fence iorw, iorw
    li x9, PIC_GWCTRL
    sw zero, 4*4(x9)        // meigwctrl[4] = 0 (normal polarity, level type)
    fence iorw, iorw
    sw zero, 5*4(x9)        // meigwctrl[5] = 0
    fence iorw, iorw

    li x3, STDOUT
    li x7, (4<<8)|0x81
    sw x7, 0(x3)             // set extintsrc_req[4] (pending but disabled)
    li x7, (5<<8)|0x81
    sw x7, 0(x3)             // set extintsrc_req[5]

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
    li x13, 5
    bne x12, x13, fail

    // Phase 2: line 6 (priority 8) must stay blocked at meipt=8 and fire at meipt=7.
    li x11, UNSET
    sw x11, 0(x10)

    li x6, 8
    sw x6, 6*4(x5)           // meipl[6] = 8
    fence iorw, iorw
    li x6, 1
    sw x6, 6*4(x8)           // meie[6] = 1
    fence iorw, iorw
    sw zero, 6*4(x9)         // meigwctrl[6] = 0
    fence iorw, iorw

    li x6, 8
    csrw MEIPT, x6           // threshold == priority: must stay blocked

    li x7, (6<<8)|0x81
    sw x7, 0(x3)             // set extintsrc_req[6]

    li x20, 0
3:
    addi x20, x20, 1
    li x21, SHORT_LIMIT
    blt x20, x21, 3b

    lw x12, 0(x10)
    li x13, UNSET
    bne x12, x13, fail        // any redirect here is premature -> bug

    li x6, 7
    csrw MEIPT, x6            // lower threshold below the pending priority

    li x20, 0
4:
    lw x12, 0(x10)
    li x13, UNSET
    bne x12, x13, 5f
    addi x20, x20, 1
    li x21, POLL_LIMIT
    blt x20, x21, 4b
    j fail
5:
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

// Disable the request before mret to prevent another fast redirect.
h4:
    la x28, claim_result
    li x29, 4
    sw x29, 0(x28)
    li x28, PIC_MEIE
    sw zero, 4*4(x28)
    fence iorw, iorw
    sw zero, 5*4(x28)
    fence iorw, iorw
    mret

h5:
    la x28, claim_result
    li x29, 5
    sw x29, 0(x28)
    li x28, PIC_MEIE
    sw zero, 4*4(x28)
    fence iorw, iorw
    sw zero, 5*4(x28)
    fence iorw, iorw
    mret

h6:
    la x28, claim_result
    li x29, 6
    sw x29, 0(x28)
    li x28, PIC_MEIE
    sw zero, 6*4(x28)
    fence iorw, iorw
    mret

h_spurious:
    la x28, claim_result
    li x29, 0xdeadbeef
    sw x29, 0(x28)
    mret

.section .data
.balign 1024
vec_table:
    .word h_spurious   // 0
    .word h_spurious   // 1
    .word h_spurious   // 2
    .word h_spurious   // 3
    .word h4           // 4
    .word h5           // 5
    .word h6           // 6
    .rept 25
    .word h_spurious
    .endr

claim_result:
    .word 0xffffffff
