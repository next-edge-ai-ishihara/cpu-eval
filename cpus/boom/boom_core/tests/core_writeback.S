#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  li x20, 0x0ff00ff0
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  addi x21, x20, 0
  xor x22, x21, x0

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
