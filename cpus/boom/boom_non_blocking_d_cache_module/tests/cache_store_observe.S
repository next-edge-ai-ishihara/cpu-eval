#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  la x10, cache_data
  li x20, 0x123456789abcdef0
  sd x20, 0(x10)
  ld x21, 0(x10)

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
  .balign 64
cache_data:
  .dword 0
RVTEST_DATA_END
