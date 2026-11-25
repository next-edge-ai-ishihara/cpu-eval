#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  la x10, forwarding_data
  li x11, 0x1111111111111111
  li x12, 0x2222222222222222
  li x13, 0x3333333333333333
  li x14, 0x4444444444444444
  li x15, 0x5555555555555555
  li x16, 0x6666666666666666
  li x17, 0x7777777777777777
  li x18, 0x8888888888888888

  sd x11, 0(x10)
  sd x12, 0(x10)
  sd x13, 0(x10)
  sd x14, 0(x10)
  sd x15, 0(x10)
  sd x16, 0(x10)
  sd x17, 0(x10)
  sd x18, 0(x10)
  ld x20, 0(x10)

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
  .balign 64
forwarding_data:
  .dword 0
RVTEST_DATA_END
