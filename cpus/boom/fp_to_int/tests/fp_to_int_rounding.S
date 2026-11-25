// SPDX-License-Identifier: Apache-2.0
#include "riscv_test.h"
#include "test_macros.h"

.macro check_conversion number, instruction, mode, integer, flags
  li TESTNUM, \number
  fsflags x0, x0
  \instruction x20, f0, \mode
  frflags x21
  li t0, \integer
  bne x20, t0, fail
  li t0, \flags
  bne x21, t0, fail
.endm

RVTEST_RV64UF
RVTEST_CODE_BEGIN
  # 1.5 separates nearest-even from truncation for a single-precision word result.
  li t0, 0x3fc00000
  fmv.w.x f0, t0
  check_conversion 2, fcvt.w.s, rne, 2, 1
  check_conversion 3, fcvt.w.s, rtz, 1, 1

  # The 2.5 tie rounds away from zero under RMM.
  li t0, 0x4004000000000000
  fmv.d.x f0, t0
  check_conversion 4, fcvt.l.d, rmm, 3, 1

  # Dynamic RUP maps 0.25 to 1 in an unsigned doubleword conversion.
  li t0, 0x3fd0000000000000
  fmv.d.x f0, t0
  csrwi frm, 3
  check_conversion 5, fcvt.lu.d, dyn, 1, 1

  # Dynamic RDN would make -0.5 negative, while static RTZ yields zero in range.
  li t0, 0xbf000000
  fmv.w.x f0, t0
  csrwi frm, 2
  check_conversion 6, fcvt.wu.s, dyn, 0, 16
  check_conversion 7, fcvt.wu.s, rtz, 0, 1

  # Both cases return INT32_MAX, with NV after rounding past the boundary and NX otherwise.
  li t0, 0x41dfffffffe00000
  fmv.d.x f0, t0
  check_conversion 8, fcvt.w.d, rne, 0x7fffffff, 16
  check_conversion 9, fcvt.w.d, rtz, 0x7fffffff, 1
  csrwi frm, 0

  TEST_PASSFAIL
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
