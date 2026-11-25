/* Copyright CPU-Eval contributors. SPDX-License-Identifier: Apache-2.0 */
.section .text
.globl main
main:
  li t0, -1
  li t1, 2
  mulhsu t2, t0, t1
  li t1, 0x80000000
  mulhsu t2, t0, t1
  li a0, 0
  ret
