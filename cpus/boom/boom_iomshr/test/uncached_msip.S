  .section .text.init
  .globl _start
_start:
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  li t0, 0x02000000
  li t1, 1
  sw t1, 0(t0)
  lw t2, 0(t0)
  sw zero, 0(t0)
  li gp, 1
finish:
  la t0, tohost
  sd gp, 0(t0)
1:
  j 1b

  .section .tohost,"aw",@progbits
  .balign 64
  .globl tohost
tohost:
  .dword 0
  .globl fromhost
fromhost:
  .dword 0
