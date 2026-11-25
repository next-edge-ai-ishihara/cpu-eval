#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN
  .option norvc
  la s0, pmp_data
  la t0, pmp_trap_handler
  csrw mtvec, t0
  li s4, 0
  li s6, 0
  csrw satp, zero

  # Nonlocked permissions do not restrict an M-mode access.
  li TESTNUM, 1
  srli t0, s0, 2
  csrw pmpaddr0, t0
  li t0, 0x10
  csrw pmpcfg0, t0
  sfence.vma
  lw t1, 0(s0)
  li t0, 0x11111111
  bne t1, t0, fail

  # MPRV selects S or U for these data accesses, while code remains in M.
  li TESTNUM, 2
  li s5, 5
  csrr s7, mstatus
  li t0, 0x21800
  csrc mstatus, t0
  li t0, 0x20800
  csrs mstatus, t0
  lw t1, 0(s0)
  csrw mstatus, s7
  li t0, 1
  bne s4, t0, fail

  li TESTNUM, 3
  li t0, 0x21800
  csrc mstatus, t0
  li t0, 0x20000
  csrs mstatus, t0
  lw t1, 0(s0)
  csrw mstatus, s7
  li t0, 2
  bne s4, t0, fail

  # No matching entry denies an S-mode data access when entries exist.
  li TESTNUM, 4
  li t0, 0x21800
  csrc mstatus, t0
  li t0, 0x20800
  csrs mstatus, t0
  lw t1, 32(s0)
  csrw mstatus, s7
  li t0, 3
  bne s4, t0, fail

  # Entry zero supplies the TOR lower bound even when its A field is OFF.
  li TESTNUM, 5
  srli t0, s0, 2
  csrw pmpaddr0, t0
  addi t0, t0, 4
  csrw pmpaddr1, t0
  li t0, 0x0900
  csrw pmpcfg0, t0
  sfence.vma
  li t0, 0x21800
  csrc mstatus, t0
  li t0, 0x20800
  csrs mstatus, t0
  lw t1, 12(s0)
  csrw mstatus, s7
  li t0, 0x44444444
  bne t1, t0, fail
  li t0, 3
  bne s4, t0, fail

  li TESTNUM, 6
  li s5, 7
  li t0, 0x21800
  csrc mstatus, t0
  li t0, 0x20800
  csrs mstatus, t0
  sw zero, 0(s0)
  csrw mstatus, s7
  li t0, 4
  bne s4, t0, fail

  li TESTNUM, 7
  li s5, 5
  li t0, 0x21800
  csrc mstatus, t0
  li t0, 0x20800
  csrs mstatus, t0
  lw t1, 16(s0)
  csrw mstatus, s7
  li t0, 5
  bne s4, t0, fail

  # A 16-byte NAPOT region has one trailing one in pmpaddr.
  li TESTNUM, 8
  srli t0, s0, 2
  ori t0, t0, 1
  csrw pmpaddr0, t0
  li t0, 0x19
  csrw pmpcfg0, t0
  sfence.vma
  li t0, 0x21800
  csrc mstatus, t0
  li t0, 0x20800
  csrs mstatus, t0
  lw t1, 12(s0)
  csrw mstatus, s7
  li t0, 0x44444444
  bne t1, t0, fail
  li t0, 5
  bne s4, t0, fail

  li TESTNUM, 9
  li t0, 0x21800
  csrc mstatus, t0
  li t0, 0x20800
  csrs mstatus, t0
  lw t1, 16(s0)
  csrw mstatus, s7
  li t0, 6
  bne s4, t0, fail

  # The lower-index matching entry wins, both for denial and permission.
  li TESTNUM, 10
  srli t0, s0, 2
  csrw pmpaddr0, t0
  ori t0, t0, 1
  csrw pmpaddr1, t0
  li t0, 0x1910
  csrw pmpcfg0, t0
  sfence.vma
  li t0, 0x21800
  csrc mstatus, t0
  li t0, 0x20800
  csrs mstatus, t0
  lw t1, 0(s0)
  csrw mstatus, s7
  li t0, 7
  bne s4, t0, fail

  li TESTNUM, 11
  li t0, 0x1811
  csrw pmpcfg0, t0
  sfence.vma
  li t0, 0x21800
  csrc mstatus, t0
  li t0, 0x20800
  csrs mstatus, t0
  lw t1, 0(s0)
  csrw mstatus, s7
  li t0, 0x11111111
  bne t1, t0, fail
  li t0, 7
  bne s4, t0, fail

  # A locked NAPOT entry lacking X also restricts M-mode instruction fetch.
  li TESTNUM, 12
  la t0, pmp_execute_denied
  srli t0, t0, 2
  ori t0, t0, 7
  csrw pmpaddr0, t0
  li t0, 0x99
  csrw pmpcfg0, t0
  sfence.vma
  li s5, 1
  la s6, pmp_execute_return
  la t0, pmp_execute_denied
  jr t0
pmp_execute_return:
  li s6, 0
  li t0, 8
  bne s4, t0, fail
  TEST_PASSFAIL

  .option rvc
.balign 4
  .option norvc
pmp_trap_handler:
  li t0, 93
  beq x17, t0, trap_vector
  csrr t0, mcause
  bne t0, s5, fail
  addi s4, s4, 1
  bnez s6, pmp_jump_trap
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
pmp_jump_trap:
  csrw mepc, s6
  mret

.balign 64
pmp_execute_denied:
  j fail
  .space 60
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
  .balign 64
pmp_data:
  .word 0x11111111, 0x22222222, 0x33333333, 0x44444444
  .space 48
RVTEST_DATA_END
