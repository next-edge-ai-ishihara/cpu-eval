/* Run under the Ibex simple system startup code and linker script. */

  .section .text
  .globl main

main:
  li    t0, -7
  li    t1, 3
  rem   t2, t0, t1
  div   t3, t0, zero
  rem   t4, t0, zero

  li    t1, 5
  divu  t2, t0, t1
  remu  t3, t0, t1
  divu  t4, t0, zero
  remu  t5, t0, zero

  li    t0, 0x80000000
  li    t1, -1
  div   t2, t0, t1
  rem   t3, t0, t1
  li    a0, 0
  ret
