#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV64U
RVTEST_CODE_BEGIN
  TEST_RR_OP(2, divuw, -1, 7, 1 << 32);
  TEST_PASSFAIL
RVTEST_CODE_END
.data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
