/* Standalone program for lowRISC Ibex examples/sw/simple_system crt0.S and link.ld. */

  .section .data
  .align 2
buf:
  .word 0
  .word 0

  .section .text
  .globl main

main:
  la    t0, buf

  li    t1, 0x12345678
  sw    t1, 1(t0)
  lw    t2, 1(t0)

  li    t3, 0xdead
  sh    t3, 3(t0)
  lh    t4, 3(t0)
  lhu   t5, 3(t0)

  ret
