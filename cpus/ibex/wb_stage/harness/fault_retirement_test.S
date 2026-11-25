/* Use the Ibex simple system data bus and exception vector. */

  .section .text
  .globl main
main:
  la    t2, fault_handler
  csrw  mtvec, t2
  li    t0, 0x40000
  csrr  t3, minstret
  lw    t1, 0(t0)
resume:
  sub   a0, t4, t3
  ret

  .balign 256
fault_handler:
  csrr  t4, minstret
  csrr  t5, mcause
  csrr  t6, mtval
  la    t2, resume
  csrw  mepc, t2
  mret
