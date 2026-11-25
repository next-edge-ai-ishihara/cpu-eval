  .section .text
  .globl main

main:
  csrw mcycle, zero
  csrw mcycleh, zero
  csrw minstret, zero
  csrw minstreth, zero
  csrr t0, mcycle
  nop
  nop
  csrr t1, mcycle
  sub  t2, t1, t0
  csrr t3, minstret
  nop
  csrr t4, minstret
  sub  t5, t4, t3
  ret
