#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 1

  li x5, 64
1:
  jal ra, leaf
  addi x5, x5, -1
  bnez x5, 1b

  li x5, 256
  csrr x18, mcycle
2:
  jal ra, leaf
  addi x5, x5, -1
  bnez x5, 2b
  csrr x19, mcycle
  sub x20, x19, x18

  TEST_PASSFAIL

leaf:
  addi x7, x7, 1
  ret

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
