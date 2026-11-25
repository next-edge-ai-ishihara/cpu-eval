/* RV32ZC=ibex_pkg::RV32Zca disables Zcmp, so 0xb842 (cm.push with a
 * non-reserved rlist=4) must be illegal; see SPEC.md. */

  .section .text
  .globl main

main:
  li    t0, 1
  li    t1, 2
  add   t2, t0, t1
  .half 0xb842        /* would be cm.push (rlist=4) if Zcmp were enabled */
  li    t3, 3
  ret
