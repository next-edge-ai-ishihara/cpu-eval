#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 1

  li x10, 200
1:
  andi x11, x10, 1
  beqz x11, 2f
  addi x12, x12, 1
2:
  andi x11, x10, 2
  bnez x11, 3f
  addi x13, x13, 1
3:
  addi x10, x10, -1
  bnez x10, 1b

  csrr x20, mcycle
  li x10, 4000
4:
  andi x11, x10, 1
  beqz x11, 5f
  addi x12, x12, 1
5:
  andi x11, x10, 2
  bnez x11, 6f
  addi x13, x13, 1
6:
  addi x10, x10, -1
  bnez x10, 4b
  csrr x21, mcycle
  sub x22, x21, x20

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
