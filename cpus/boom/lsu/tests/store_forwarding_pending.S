#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  la a0, value
  li a1, 0x11
  li a2, 0x22
  li a3, 0x33
  li a4, -1
  li a5, 7

  # Keep the older divide in flight while the stores and load execute.
  divu a6, a4, a5
  sd a1, 0(a0)
  sd a2, 0(a0)
  sd a3, 0(a0)
  ld x20, 0(a0)

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
  .balign 64
value:
  .dword 0
RVTEST_DATA_END
