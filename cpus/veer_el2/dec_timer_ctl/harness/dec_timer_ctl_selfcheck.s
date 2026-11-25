// SPDX-License-Identifier: Apache-2.0

#define STDOUT      0xd0580000
#define MITCNT0     0x7d2
#define MITB0       0x7d3
#define MITCTL0     0x7d4
#define MITCNT1     0x7d5
#define MITB1       0x7d6
#define MITCTL1     0x7d7
#define MITCTL1_RUN_CASCADE 0x9
#define MSTATUS_MIE 0x8
// Timer 0 interrupt enable in mie.
#define MIE_MITIE0  (1 << 29)
#define TIMER0_CAUSE 0x8000001d
#define UNSET       0xffffffff
#define PHASE1_NOPS  2000
#define BOUND_THRESHOLD 3000
#define SHORT_LIMIT  300
#define POLL_LIMIT   20000
#define CASCADE_BOUND 0x40000000

.section .text
.global _start
_start:
    csrw minstret, zero
    csrw minstreth, zero

    li x1, 0x5f555555
    csrw 0x7c0, x1

    la x1, _spurious_trap
    csrw mtvec, x1

    j phase1

// Phase 1: mitcnt0 counts once per cycle while mitb0 is out of reach.
.balign 4
phase1:
    csrci mstatus, MSTATUS_MIE

    li x1, UNSET
    csrw MITB0, x1

    csrw MITCNT0, zero

    li x1, 1
    csrw MITCTL0, x1

    // Sample both counters in the same order at each end so read latency cancels.

    csrr s1, mcycle
    csrr s4, MITCNT0
    .rept PHASE1_NOPS
    addi x0, x0, 0
    .endr
    csrr s2, mcycle
    csrr s5, MITCNT0
    sub  s2, s2, s1
    sub  s5, s5, s4

    mv   a1, s2
    call print_hex32
    li   x3, STDOUT
    li   a1, ' '
    sb   a1, 0(x3)
    mv   a1, s5
    call print_hex32
    li   x3, STDOUT
    li   a1, '\n'
    sb   a1, 0(x3)

    bne  s2, s5, fail

// Phase 2: reaching mitb0 raises the timer-0 interrupt, which must trap.
phase2:
    la x1, _timer_trap
    csrw mtvec, x1

    li x1, BOUND_THRESHOLD
    csrw MITB0, x1
    csrw MITCNT0, zero
    li x1, 1
    csrw MITCTL0, x1

    la x10, pass_flag
    li x11, UNSET
    sw x11, 0(x10)

    li x6, MIE_MITIE0
    csrs mie, x6
    csrsi mstatus, MSTATUS_MIE

    // ---- checkpoint A: must NOT have fired yet after a short delay ----
    li x20, 0
short_wait:
    addi x20, x20, 1
    li x21, SHORT_LIMIT
    blt x20, x21, short_wait

    lw x12, 0(x10)
    li x13, UNSET
    bne x12, x13, fail        // fired before the bound was reached -> bug

    // ---- checkpoint B: must fire within a bounded poll window ----
    li x20, 0
poll_wait:
    lw x12, 0(x10)
    li x13, UNSET
    bne x12, x13, phase2_fired
    addi x20, x20, 1
    li x21, POLL_LIMIT
    blt x20, x21, poll_wait
    j fail                    // never fired within the bound -> bug

phase2_fired:
    li x13, 1
    bne x12, x13, fail        // handler ran but did not set the expected value

// Phase 3: independently check timer 1 against the live cycle counter.
phase3:
    csrci mstatus, MSTATUS_MIE
    li x1, UNSET
    csrw MITB1, x1
    csrw MITCNT1, zero
    li x1, 1
    csrw MITCTL1, x1
    csrr s1, mcycle
    csrr s4, MITCNT1
    .rept PHASE1_NOPS
    addi x0, x0, 0
    .endr
    csrr s2, mcycle
    csrr s5, MITCNT1
    sub s2, s2, s1
    sub s5, s5, s4
    mv a1, s2
    call print_hex32
    li x3, STDOUT
    li a1, ' '
    sb a1, 0(x3)
    mv a1, s5
    call print_hex32
    li x3, STDOUT
    li a1, '\n'
    sb a1, 0(x3)
    bne s2, s5, fail

// Phase 4: with cascade enabled, timer 1 stays at zero below the timer-0
// bound. Writing timer 0 above its bound creates one event before timer 0
// clears. The high bound keeps the next event beyond the whole simulation.
phase4:
    csrw MITCTL0, zero
    csrw MITCTL1, zero
    li x1, CASCADE_BOUND
    csrw MITB0, x1
    csrw MITCNT0, zero
    csrw MITCNT1, zero
    li x1, 1
    csrw MITCTL0, x1
    li x1, MITCTL1_RUN_CASCADE
    csrw MITCTL1, x1

    // The first snapshot precedes the only bound event.
    csrr s4, MITCNT1
    li x1, CASCADE_BOUND + 1
    csrw MITCNT0, x1
    // Keep the post-event read separate from the CSR writeback.
    .rept 8
    nop
    .endr
    csrr s5, MITCNT1
    mv a1, s4
    call print_hex32
    li x3, STDOUT
    li a1, ' '
    sb a1, 0(x3)
    mv a1, s5
    call print_hex32
    li x3, STDOUT
    li a1, '\n'
    sb a1, 0(x3)
    bnez s4, fail
    li x1, 1
    bne s5, x1, fail

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

// void print_hex32(uint32_t a1) -- prints a1 as 8 hex digits to STDOUT.
// Clobbers a1, x3, t1, t2, t3. Returns via ra.
.balign 4
print_hex32:
    mv   t3, a1
    li   t2, 28
print_hex32_loop:
    srl  a1, t3, t2
    andi a1, a1, 0xf
    li   t1, 10
    blt  a1, t1, print_hex32_digit
    addi a1, a1, ('a' - '0' - 10)
print_hex32_digit:
    addi a1, a1, '0'
    li   x3, STDOUT
    sb   a1, 0(x3)
    addi t2, t2, -4
    bgez t2, print_hex32_loop
    ret

.balign 4
_timer_trap:
    csrr x28, mcause
    li   x29, TIMER0_CAUSE
    bne  x28, x29, fail        // any other trap cause here is a genuine bug

    li   x28, 0
    csrw MITCTL0, x28          // stop counting so it cannot refire
    la   x28, pass_flag
    li   x29, 1
    sw   x29, 0(x28)
    mret

.balign 4
_spurious_trap:
    j fail

.section .data
.balign 4
pass_flag:
    .word 0xffffffff
