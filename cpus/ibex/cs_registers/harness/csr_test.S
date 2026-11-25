  .section .text
  .globl main

main:
  li   t0, 0x13579bdf
  csrw mscratch, t0
  csrr t1, mscratch
  li   t2, 0x2468ace0
  csrw mscratch, t2
  csrr t3, mscratch
  csrrw t4, mscratch, t0
  csrr t5, mscratch
  li   t6, 0x20
  csrrs t1, mscratch, t6
  csrr t2, mscratch
  li   t6, 0x80
  csrrc t3, mscratch, t6
  csrr t4, mscratch
  ret
