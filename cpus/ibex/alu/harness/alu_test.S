/* ALU operations with operand pairs from the Ibex-vendored riscv-arch-tests
 * rv32i_m/I/src/{add,sub,and,or,xor,sll,srl,sra,slt,sltu,addi,andi,ori,xori,slli,srli,srai,slti,sltiu}-01.S. */

  .section .text
  .globl main

main:
  li    t1, 0x7fffffff
  li    t2, 0x1
  add   t3, t1, t2

  li    t1, 0x55555554
  li    t2, 0x6
  sub   t3, t1, t2

  li    t1, 0x4000
  li    t2, 0x7
  and   t3, t1, t2

  li    t1, 0x100000
  li    t2, 0x10
  or    t3, t1, t2

  li    t1, 0x66666665
  li    t2, 0x3
  xor   t3, t1, t2

  li    t1, -0x81
  li    t2, 0xa
  sll   t3, t1, t2

  li    t2, 0x21
  sll   t3, t1, t2

  li    t1, -0x400001
  li    t2, 0xf
  srl   t3, t1, t2

  li    t1, -0x80000000
  li    t2, 0x8
  sra   t3, t1, t2

  li    t1, 0x80000000
  li    t2, 0x1
  slt   t3, t1, t2
  sltu  t3, t1, t2

  li    t1, 0x20000000
  addi  t3, t1, -0x800

  li    t1, -0x2
  andi  t3, t1, -0x800

  li    t1, -0x201
  ori   t3, t1, -0x800

  li    t1, 0x33333334
  xori  t3, t1, -0x800

  li    t1, -0x40000001
  slli  t3, t1, 0x1d

  li    t1, -0xb504
  srli  t3, t1, 0x2

  li    t1, -0x9
  srai  t3, t1, 0x9

  li    t1, 0x80000000
  slti  t3, t1, 0x1
  sltiu t3, t1, 0x1

  li    t0, 0

  li    t1, 0x55555555
  li    t2, 0x55555555
  beq   t1, t2, 1f
  addi  t0, t0, 0x100
1:
  li    t1, 0x1
  li    t2, 0x2
  beq   t1, t2, 2f
  addi  t0, t0, 0x1
2:

  li    t1, 0x1
  li    t2, 0x2
  bne   t1, t2, 3f
  addi  t0, t0, 0x200
3:
  li    t1, 0x5
  li    t2, 0x5
  bne   t1, t2, 4f
  addi  t0, t0, 0x2
4:

  li    t1, -0x1
  li    t2, 0x1
  blt   t1, t2, 5f
  addi  t0, t0, 0x400
5:
  li    t1, 0x1
  li    t2, -0x1
  blt   t1, t2, 6f
  addi  t0, t0, 0x4
6:

  li    t1, 0x1
  li    t2, -0x1
  bltu  t1, t2, 7f
  addi  t0, t0, 0x480
7:
  li    t1, -0x1
  li    t2, 0x1
  bltu  t1, t2, 8f
  addi  t0, t0, 0x8
8:

  li    t1, 0x1
  li    t2, -0x1
  bge   t1, t2, 9f
  addi  t0, t0, 0x500
9:
  li    t1, -0x1
  li    t2, 0x1
  bge   t1, t2, 10f
  addi  t0, t0, 0x10
10:

  li    t1, -0x1
  li    t2, 0x1
  bgeu  t1, t2, 11f
  addi  t0, t0, 0x580
11:
  li    t1, 0x1
  li    t2, -0x1
  bgeu  t1, t2, 12f
  addi  t0, t0, 0x20
12:

  ret
