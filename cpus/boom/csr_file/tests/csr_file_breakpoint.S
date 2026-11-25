#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 2
  li x20, 0
  la t0, breakpoint_handler
  csrw mtvec, t0
breakpoint_site:
  .option push
  .option norvc
  ebreak
  .option pop
after_breakpoint:
  li t0, 3
  bne x20, t0, fail
  TEST_PASSFAIL

  .align 2
breakpoint_handler:
  li t0, 93
  beq x17, t0, trap_vector
  csrr t0, mcause
  li t1, 3
  bne t0, t1, fail
  csrr t0, mepc
  la t1, breakpoint_site
  bne t0, t1, fail
  addi t0, t0, 4
  csrw mepc, t0
  li x20, 3
  mret

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
