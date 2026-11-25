/* Run under the Ibex simple system startup code and linker script. */

  .section .text
  .globl main

main:
  .2byte 0x72fd       /* c.lui t0, -1: t0 must receive 0xfffff000. */
  li     a0, 0
  ret
