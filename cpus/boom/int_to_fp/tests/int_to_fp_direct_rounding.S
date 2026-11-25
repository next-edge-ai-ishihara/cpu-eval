/* SPDX-License-Identifier: Apache-2.0 */
#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UF
RVTEST_CODE_BEGIN

  /* 2^53 + 2^29 + 1 is above a single-precision midpoint. */
  li TESTNUM, 2
  li a0, 9007199791611905
  fcvt.s.l f0, a0, rne
  fmv.x.w t0, f0
  li t1, 0x5a000001
  bne t0, t1, fail

  /* Both single and double round 2^53 + 1 to 2^53, but both raise NX. */
  li TESTNUM, 3
  fsflags x0
  li a0, 9007199254740993
  fcvt.s.l f0, a0, rne
  frflags t0
  li t1, 1
  bne t0, t1, fail
  fmv.x.w t0, f0
  li t1, 0x5a000000
  bne t0, t1, fail

  li TESTNUM, 4
  fsflags x0
  fcvt.d.l f0, a0, rne
  frflags t0
  li t1, 1
  bne t0, t1, fail
  fmv.x.d t0, f0
  li t1, 0x4340000000000000
  bne t0, t1, fail

  li TESTNUM, 5
  fsflags x0
  li a0, 16777217
  fcvt.s.l f0, a0, rup
  fmv.x.w t0, f0
  li t1, 0x4b800001
  bne t0, t1, fail

  li TESTNUM, 6
  fsflags x0
  li a0, 1
  fcvt.s.w f0, a0, rne
  fcvt.d.w f1, a0
  frflags t0
  bnez t0, fail

  TEST_PASSFAIL

RVTEST_CODE_END
.data
RVTEST_DATA_BEGIN
RVTEST_DATA_END
