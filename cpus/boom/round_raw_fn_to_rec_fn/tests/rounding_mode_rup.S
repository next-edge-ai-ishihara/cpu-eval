#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UF
RVTEST_CODE_BEGIN
  la a1, operands

  li TESTNUM, 2
  fld f1, 0(a1)
  fld f2, 8(a1)
  fsflags zero
  fadd.d f3, f1, f2, rup
  fmv.x.d a2, f3
  li a3, 0x3ff0000000000001
  bne a2, a3, fail
  fsflags a2, zero
  li a3, 1
  bne a2, a3, fail

  li TESTNUM, 3
  fld f5, 16(a1)
  fsflags zero
  fcvt.s.d f6, f5, rup
  fmv.x.w a2, f6
  li a3, 0x3f800001
  bne a2, a3, fail
  fsflags a2, zero
  li a3, 1
  bne a2, a3, fail
  TEST_PASSFAIL
RVTEST_CODE_END

  .data
  .align 3
operands:
  .dword 0x3ff0000000000000
  .dword 0x3ca0000000000000
  .dword 0x3ff0000010000000
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
