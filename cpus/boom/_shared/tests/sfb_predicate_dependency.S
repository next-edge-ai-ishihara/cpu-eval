#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  .option push
  .option norvc

  li TESTNUM, 1
  li s0, 16
  li s1, 1
  li s3, 0

.balign 64
sfb_loop:
  div t0, s0, s1
  beq t0, zero, sfb_after_shadow
  addi s3, s3, 1
sfb_after_shadow:
  beq t0, zero, sfb_done
  addi s0, s0, -1
  j sfb_loop

sfb_done:
  li t1, 16
  bne s3, t1, fail
  .option pop
  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
