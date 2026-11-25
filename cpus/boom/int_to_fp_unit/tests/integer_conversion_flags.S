#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UF
RVTEST_CODE_BEGIN

  li TESTNUM, 2
  fsflags x0
  li a0, 16777217
  fcvt.s.l f0, a0, rne
  frflags t0
  li t1, 1
  bne t0, t1, fail
  fmv.x.w t2, f0
  li t3, 0x4b800000
  bne t2, t3, fail

  li TESTNUM, 3
  fsflags x0
  li a0, 1
  fcvt.s.w f0, a0, rne
  frflags t0
  bnez t0, fail

  li TESTNUM, 4
  fsflags x0
  li a0, 9007199254740993
  fcvt.d.l f0, a0, rne
  frflags t0
  li t1, 1
  bne t0, t1, fail
  fmv.x.d t2, f0
  li t3, 0x4340000000000000
  bne t2, t3, fail

  li TESTNUM, 5
  fsflags x0
  li a0, 1
  fcvt.d.w f0, a0
  frflags t0
  bnez t0, fail

  # The integer is halfway between adjacent single-precision results.
  # The instruction's static mode overrides the CSR's upward rounding.
  li TESTNUM, 6
  li a0, 16777217
  fsrmi 3
  fsflags zero
  fcvt.s.l f0, a0, rne
  fmv.x.w t2, f0
  li t3, 0x4b800000
  bne t2, t3, fail
  frflags t0
  li t1, 1
  bne t0, t1, fail

  li TESTNUM, 7
  fsflags zero
  fcvt.s.l f0, a0, dyn
  fmv.x.w t2, f0
  li t3, 0x4b800001
  bne t2, t3, fail
  frflags t0
  bne t0, t1, fail

  TEST_PASSFAIL

RVTEST_CODE_END
.data
RVTEST_DATA_BEGIN
RVTEST_DATA_END
