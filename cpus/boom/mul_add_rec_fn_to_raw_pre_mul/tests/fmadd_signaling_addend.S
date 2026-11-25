#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UF
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  la t0, operands
  fld f0, 0(t0)
  fld f1, 8(t0)
  fld f2, 16(t0)
  fld f4, 24(t0)

  csrwi fflags, 0
  fmadd.d f3, f0, f1, f2
  frflags x20
  fmv.x.d x21, f3

  csrwi fflags, 0
  fmadd.d f3, f0, f1, f4
  frflags x22
  fmv.x.d x23, f3

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
  .balign 8
operands:
  .dword 0x3ff8000000000000
  .dword 0x4000000000000000
  .dword 0x7ff0000000000001
  .dword 0x7ff8000000000001
RVTEST_DATA_END
