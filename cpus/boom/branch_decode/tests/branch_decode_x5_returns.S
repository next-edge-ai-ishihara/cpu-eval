#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 1

  li x28, 64
1:
  .rept 4
  jal ra, leaf
  .endr
  addi x28, x28, -1
  bnez x28, 1b

  li x28, 256
  csrr x18, mcycle
2:
  .rept 4
  jal ra, leaf
  .endr
  addi x28, x28, -1
  bnez x28, 2b
  csrr x19, mcycle
  sub x20, x19, x18

  TEST_PASSFAIL

leaf:
  addi x7, x7, 1
  mv x5, ra
  jalr zero, 0(x5)

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
