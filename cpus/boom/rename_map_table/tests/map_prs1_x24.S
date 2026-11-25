#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  TEST_CASE(1, x14, 14,
    li x24, 5;
    li x7, 9;
    TEST_INSERT_NOPS_8;
    add x14, x24, x7;
  )

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
