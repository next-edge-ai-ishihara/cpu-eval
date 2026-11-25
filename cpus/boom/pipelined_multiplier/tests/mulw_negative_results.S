#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  TEST_RR_OP(2, mulw, 0xffffffffffffffff, 0xffffffffffffffff, 1)
  TEST_RR_OP(3, mulw, 0xffffffff80000000, 0x0000000080000000, 1)
  TEST_RR_OP(4, mulw, 0xffffffffffffffff, 0x12345678ffffffff, 1)

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
