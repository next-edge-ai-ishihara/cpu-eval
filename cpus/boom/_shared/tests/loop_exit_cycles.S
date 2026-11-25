#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  li a0, 32
  jal ra, run_loop
  csrr s2, mcycle
  li a0, 64
  jal ra, run_loop
  csrr s3, mcycle
  sub x20, s3, s2

  TEST_PASSFAIL

  # Runs a 100-iteration, 12-instruction loop a0 times; its exit exceeds the global history.
  .balign 64
run_loop:
1:
  li t0, 100
  .balign 16
2:
  addi t0, t0, -1
  addi t1, t1, 1
  addi t2, t2, 1
  addi t3, t3, 1
  addi t4, t4, 1
  addi t5, t5, 1
  addi t6, t6, 1
  addi a1, a1, 1
  addi a2, a2, 1
  addi a3, a3, 1
  addi a4, a4, 1
  bnez t0, 2b
  addi a0, a0, -1
  bnez a0, 1b
  ret

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
