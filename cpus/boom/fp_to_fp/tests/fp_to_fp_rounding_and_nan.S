/* SPDX-License-Identifier: Apache-2.0 */

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UF
RVTEST_CODE_BEGIN

  // A signaling NaN keeps its payload and signaling bit when its sign is copied.
  li t0, 0x7f812345
  fmv.w.x f0, t0
  li t0, 0xbf800000
  fmv.w.x f1, t0
  fsflags zero
  TEST_CASE(2, a0, 0xffffffffff812345,
    fsgnj.s f3, f0, f1;
    fmv.x.w a0, f3;
  )
  TEST_CASE(3, a0, 0, frflags a0;)

  // The double-precision input is exactly halfway between 1 and the next float.
  li t0, 0x3ff0000010000000
  fmv.d.x f0, t0
  fsrmi 0
  TEST_CASE(4, a0, 0x3f800001,
    fcvt.s.d f3, f0, rup;
    fmv.x.w a0, f3;
  )
  TEST_CASE(5, a0, 1, fsflags a0, zero;)

  fsrmi 3
  TEST_CASE(6, a0, 0x3f800000,
    fcvt.s.d f3, f0, rne;
    fmv.x.w a0, f3;
  )
  TEST_CASE(7, a0, 1, fsflags a0, zero;)

  TEST_CASE(8, a0, 0x3f800001,
    fcvt.s.d f3, f0, dyn;
    fmv.x.w a0, f3;
  )
  TEST_CASE(9, a0, 1, fsflags a0, zero;)

  TEST_PASSFAIL

RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
