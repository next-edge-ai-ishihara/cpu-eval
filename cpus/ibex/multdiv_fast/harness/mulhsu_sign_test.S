/* mulhsu(0x80000000, 0xffff8000) = 0x80004000, from test 7 of the
 * Ibex-vendored riscv-tests isa/rv32um/mulhsu.S.
 * mulh(-3, 0x80000000) = 0x00000001 and mulhu(-3, 0x80000000) = 0x7ffffffe. */

  .section .text
  .globl main

main:
  li     t1, 0x80000000
  li     t2, 0xffff8000
  mulhsu t3, t1, t2

  li     t1, -3
  li     t2, 0x80000000
  mulh   t4, t1, t2
  mulhu  t5, t1, t2

  ret
