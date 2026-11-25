// SPDX-License-Identifier: Apache-2.0

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UF
RVTEST_CODE_BEGIN
  li TESTNUM, 2
  la a1, operands
  flw f0, 0(a1)
  flw f1, 4(a1)
  flw f2, 8(a1)
  fsflags zero
  fmadd.s f3, f0, f1, f2, rne
  fmv.x.w a2, f3
  li a3, -0x57800000
  bne a2, a3, fail
  frflags a2
  bnez a2, fail

  li TESTNUM, 3
  fld f0, 16(a1)
  fld f1, 24(a1)
  fld f2, 32(a1)
  fld f4, 40(a1)
  fld f5, 48(a1)
  fsflags zero
  fmadd.d f3, f0, f1, f2, rne
  fmv.x.d a2, f3
  li a3, 0xb970000000000000
  bne a2, a3, fail
  frflags a2
  bnez a2, fail

  li TESTNUM, 4
  fsflags zero
  fmadd.d f8, f0, f1, f2, rne
  fmadd.d f9, f0, f1, f4, rne
  fmadd.d f10, f0, f1, f5, rne
  fmadd.d f11, f0, f1, f2, rne
  fmadd.d f12, f0, f1, f4, rne
  fmadd.d f13, f0, f1, f5, rne
  li a3, 0xb970000000000000
  fmv.x.d a2, f8
  bne a2, a3, fail
  fmv.x.d a2, f11
  bne a2, a3, fail
  li a3, 0x3ff0000000000000
  fmv.x.d a2, f9
  bne a2, a3, fail
  fmv.x.d a2, f12
  bne a2, a3, fail
  li a3, 0x4000000000000000
  fmv.x.d a2, f10
  bne a2, a3, fail
  fmv.x.d a2, f13
  bne a2, a3, fail
  frflags a2
  li a3, 1
  bne a2, a3, fail
  TEST_PASSFAIL
RVTEST_CODE_END

  .data
  .balign 8
operands:
  # (1 + 2^-23) * (1 - 2^-23) - 1 is exactly -2^-46.
  .word 0x3f800001, 0x3f7ffffe, 0xbf800000, 0
  # (1 + 2^-52) * (1 - 2^-52) - 1 is exactly -2^-104.
  .dword 0x3ff0000000000001, 0x3feffffffffffffe, 0xbff0000000000000
  .dword 0x0000000000000000, 0x3ff0000000000000
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
