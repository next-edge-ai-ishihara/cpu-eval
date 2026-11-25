// SPDX-License-Identifier: Apache-2.0

.section .text
.global _start
_start:
    li x1, 0x5f555555
    csrw 0x7c0, x1

    li s0, 0xf0040000        // contention word address (bank 0) -- kept in
                              // s0 (x8), never used as a load destination
    li s1, 0xdeadbeef
    sw s1, 0(s0)

    li s2, 0xf0040010         // target word (bank 0, distinct from s0)
    li s3, 0x1234
    li s4, 0x5678

    sh s3, 0(s2)              // write 1: lower half -> allocates stbuf entry

    // Keep bank-0 loads contiguous so DCCM reads block store-buffer drainage.

    lw a0, 0(s0)
    lw a1, 0(s0)

    sh s4, 2(s2)               // write 2: upper half -> should coalesce
                                // into the same entry if it is still valid

    // more contention, so the commit race at write 2's own R-stage cycle
    // is also blocked
    lw s5, 0(s0)
    lw s6, 0(s0)

    // Save the CPU load result for the OpenOCD reader.

    lw s7, 0(s2)
    li s8, 0xf0040020
    sw s7, 0(s8)

    // Completion flag polled by OpenOCD.
    li t0, 0xf0040030
    li t1, 1
    sw t1, 0(t0)

spin:
    jal x0, spin
