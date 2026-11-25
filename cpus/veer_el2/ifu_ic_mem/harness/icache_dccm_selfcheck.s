// SPDX-License-Identifier: Apache-2.0

#define STDOUT      0xd0580000
#define MRAC        0x7c0
#define DCCM_BASE   0xf0040000
#define CALL_COUNT  64

.section .text
.global _start
_start:
    la x2, _spurious_trap
    csrw mtvec, x2

    // Make only region 8 (0x80000000, which holds this code) cacheable.
    li x1, 0x00010000
    csrw MRAC, x1
    fence.i

    // --- Phase 1: DCCM store/load correctness ---

    li x3, DCCM_BASE
    li x4, 0x1234abcd
    sw x4, 0(x3)
    lw x5, 0(x3)
    bne x4, x5, fail
    addi x3, x3, 4
    sw x5, 0(x3)
    lw x6, 0(x3)
    bne x5, x6, fail

    // --- Phase 2: icache content correctness (miss, then repeated hits) ---

    li a0, 0
    csrr s2, mcycle
    jal ra, body                 // call #1 (compulsory miss)
    csrr s3, mcycle
    sub s2, s3, s2

    .rept CALL_COUNT - 2
    jal ra, body                  // unmeasured middle call (unrolled)
    .endr

    csrr s4, mcycle
    jal ra, body                 // call #CALL_COUNT (should be a hit)
    csrr s5, mcycle
    sub s4, s5, s4

    li t0, CALL_COUNT
    bne a0, t0, fail              // every call must have retired addi a0,a0,1

    mv a1, s2
    call print_hex32
    li x3, STDOUT
    li a1, ' '
    sb a1, 0(x3)
    mv a1, s4
    call print_hex32
    li x3, STDOUT
    li a1, '\n'
    sb a1, 0(x3)

    // --- Phase 3: icache hit/miss timing ---
    // Compare the first and final call intervals within the same run.
    // The intervals include the distinct calling instructions.

    slli t1, s4, 1
    bge t1, s2, fail

    j pass_test

// 'body' occupies a separate 64-byte-aligned cache line. The trap handler,
// printing routine and mailbox writers are outside that line.

.balign 64
body:
    addi a0, a0, 1
    ret
.balign 64

// void print_hex32(uint32_t a1) -- prints a1 as 8 hex digits to STDOUT.
// Clobbers a1, x3, t1, t2, t3. Returns via ra.
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

.balign 4
_spurious_trap:
    j fail
