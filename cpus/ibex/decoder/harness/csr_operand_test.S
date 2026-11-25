/* Copyright CPU-Eval contributors. SPDX-License-Identifier: Apache-2.0 */
.section .text
.globl main
main:
  li t0, 0x120
  csrrw t1, mscratch, t0
  csrrwi t2, mscratch, 9
  csrrw t3, mscratch, t1
  li a0, 0
  ret
