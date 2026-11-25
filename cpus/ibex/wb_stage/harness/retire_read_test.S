
.section .text
.globl main
main:
  csrr t0, minstret
  addi t1, zero, 1
  addi t1, t1, 1
  csrr t2, minstret
  sub t3, t2, t0
  ret
