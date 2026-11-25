/* SPDX-License-Identifier: Apache-2.0 */

    .section .text
    .global main
main:
    csrci mstatus, 8
    li t0, 0x30000
    li t1, -1
    sw t1, 12(t0)
    li t1, 2048
    sw t1, 8(t0)
    sw zero, 12(t0)
    li t1, 0x80
    csrs mie, t1

    csrr s2, mcause
    csrr s3, mip
    .global timer_wait
timer_wait:
    wfi
    .global timer_resumed
timer_resumed:
    csrr s4, mcause
    csrr s5, mip

    csrc mie, t1
    li a0, 0
    ret
