#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  li t3, 1
  li t0, 64
1:
  beqz t3, 4f
  addi t4, t4, 7
4:
  andi t1, t0, 1
  beqz t1, 2f
  addi t2, t2, 3
  j 3f
2:
  addi t2, t2, 5
3:
  addi t0, t0, -1
  bnez t0, 1b

  li t0, 256
  csrr s2, mcycle
1:
  beqz t3, 4f
  addi t4, t4, 7
4:
  andi t1, t0, 1
  beqz t1, 2f
  addi t2, t2, 3
  j 3f
2:
  addi t2, t2, 5
3:
  addi t0, t0, -1
  bnez t0, 1b
  csrr s3, mcycle
  sub x20, s3, s2

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
