  .section .text
  .globl main

main:
  li   t0, 0x2a
  csrw minstret, t0
  csrr t1, minstret
  li   t2, 0x7
  csrw minstreth, t2
  csrr t3, minstreth
  csrr t4, minstret
  ret
