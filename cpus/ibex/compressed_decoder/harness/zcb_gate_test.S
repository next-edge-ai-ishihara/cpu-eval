/* Standalone program for lowRISC Ibex examples/sw/simple_system crt0.S and link.ld.
 * RV32ZC=ibex_pkg::RV32Zca disables Zcb. Encoding 0x8000 is c.lbu x8, 0(x8)
 * under Zcb and is illegal under RV32Zca; see SPEC.md.
 */

  .section .text
  .globl main

main:
  li    t0, 1
  li    t1, 2
  add   t2, t0, t1
  .half 0x8000        /* would be c.lbu x8, 0(x8) if Zcb were enabled */
  li    t3, 3
  ret
