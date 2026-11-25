#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UF
RVTEST_CODE_BEGIN

  la x10, test_data
  li x11, 7

  li TESTNUM, 1
  fld f10, 0(x10)
  fcvt.d.w f11, x11
  nop; nop; nop; nop; nop; nop; nop; nop
  fmv.x.d x12, f10
  li x13, 0x400921fb54442d18
  bne x12, x13, fail
  fmv.x.d x12, f11
  li x13, 0x401c000000000000
  bne x12, x13, fail

#define TEST_COLLISION(testnum, gap) \
  li TESTNUM, testnum; \
  fld f10, 0(x10); \
  gap; \
  fcvt.d.w f11, x11; \
  nop; nop; nop; nop; nop; nop; nop; nop; \
  fmv.x.d x12, f10; \
  li x13, 0x400921fb54442d18; \
  bne x12, x13, fail; \
  fmv.x.d x12, f11; \
  li x13, 0x401c000000000000; \
  bne x12, x13, fail

  TEST_COLLISION(2, nop)
  TEST_COLLISION(3, nop; nop)
  TEST_COLLISION(4, nop; nop; nop)
  TEST_COLLISION(5, nop; nop; nop; nop)
  TEST_COLLISION(6, nop; nop; nop; nop; nop)
  TEST_COLLISION(7, nop; nop; nop; nop; nop; nop)
  TEST_COLLISION(8, nop; nop; nop; nop; nop; nop; nop)
  TEST_COLLISION(9, nop; nop; nop; nop; nop; nop; nop; nop)

  li TESTNUM, 10
  fld f0, 0(x10)
  fcvt.d.w f8, x11
  fld f1, 0(x10)
  fcvt.d.w f9, x11
  nop; nop; nop; nop; nop; nop; nop; nop

  fmv.x.d x12, f0
  fmv.x.d x13, f1

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
  .align 3
test_data:
  .dword 0x400921fb54442d18

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
