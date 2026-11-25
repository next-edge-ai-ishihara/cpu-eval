/* Division and remainder by zero with operand pairs from the Ibex-vendored
 * riscv-arch-tests rv32i_m/M/src/{div,divu,rem,remu}-01.S. */

  .section .text
  .globl main

main:
  /* div(-0x55555555, 0) = -1 (0xffffffff): riscv-arch-tests div-01.S:2946 */
  li    t1, -0x55555555
  li    t2, 0x0
  div   t3, t1, t2

  /* divu(0xaaaaaaaa, 0) = 0xffffffff: riscv-arch-tests divu-01.S:48 */
  li    t1, 0xaaaaaaaa
  li    t2, 0x0
  divu  t3, t1, t2

  /* rem(0x200000, 0) = 0x200000 (dividend): riscv-arch-tests rem-01.S:68 */
  li    t1, 0x200000
  li    t2, 0x0
  rem   t3, t1, t2

  /* remu(0xfffffbff, 0) = 0xfffffbff (dividend): riscv-arch-tests remu-01.S:48 */
  li    t1, 0xfffffbff
  li    t2, 0x0
  remu  t3, t1, t2

  /* MULHSU uses a signed first operand and an unsigned second operand. */
  li    t1, -3
  li    t2, 0x80000000
  mulhsu t3, t1, t2

  ret
