#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  TEST_CASE(1, x14, 4,
    li x5, 13;
    li x26, 9;
    TEST_INSERT_NOPS_8;
    sub x14, x5, x26;
  )

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
