#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UF
RVTEST_CODE_BEGIN
  li TESTNUM, 2
  fsflags x0, x0
  li t0, 0x3f800000
  fmv.w.x f0, t0
  li t0, 0x00800000
  fmv.w.x f1, t0
  li t0, 0x7f800000
  fmv.w.x f2, t0

  # Round 1 + 2^-126 to 1 (NX), then subtract infinity from itself (NV).
  fadd.s f3, f0, f1, rne
  frflags x20
  li t1, 0x1
  bne x20, t1, fail
  fsub.s f4, f2, f2, rne
  frflags x21
  li t1, 0x11
  bne x21, t1, fail

  # An exact result must leave accrued flags unchanged.
  fadd.s f5, f0, f0, rne
  frflags x22
  bne x22, t1, fail
  fsflags x23, x0
  bne x23, t1, fail
  frflags x24
  bnez x24, fail

  TEST_PASSFAIL
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
