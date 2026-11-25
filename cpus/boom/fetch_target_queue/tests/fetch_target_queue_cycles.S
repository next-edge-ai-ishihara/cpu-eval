#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 1

  li x5, 64
1:
  andi x6, x5, 1
  beqz x6, 2f
  addi x7, x7, 3
  j 3f
2:
  addi x7, x7, 5
3:
  addi x5, x5, -1
  bnez x5, 1b

  li x5, 256
  csrr x18, mcycle
4:
  andi x6, x5, 1
  beqz x6, 5f
  addi x7, x7, 3
  j 6f
5:
  addi x7, x7, 5
6:
  addi x5, x5, -1
  bnez x5, 4b
  csrr x19, mcycle
  sub x20, x19, x18

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
