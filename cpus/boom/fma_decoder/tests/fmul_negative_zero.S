#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UF
RVTEST_CODE_BEGIN

  fsrmi 0
  TEST_FP_OP2_S(2, fmul.s, 0, -0.0, -0.0, 1.0);
  TEST_FP_OP2_D(3, fmul.d, 0, -0.0, -0.0, 1.0);
  TEST_PASSFAIL

RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
