#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64UF
RVTEST_CODE_BEGIN

  fsrmi 2

  li TESTNUM, 2
  li t0, 0x3f800000
  fmv.w.x f0, t0
  li t0, 0x40400000
  fmv.w.x f1, t0
  fsflags x0, x0
  fdiv.s f2, f0, f1, rup
  fmv.x.s t0, f2
  li t1, 0x3eaaaaab
  sext.w t1, t1
  bne t0, t1, fail
  fsflags t2, x0
  li t3, 1
  bne t2, t3, fail

  li TESTNUM, 3
  li t0, 0x3f800000
  fmv.w.x f0, t0
  li t0, 0x40400000
  fmv.w.x f1, t0
  fsflags x0, x0
  fdiv.s f2, f0, f1, dyn
  fmv.x.s t0, f2
  li t1, 0x3eaaaaaa
  sext.w t1, t1
  bne t0, t1, fail
  fsflags t2, x0
  li t3, 1
  bne t2, t3, fail

  li TESTNUM, 4
  li t0, 0x3ff0000000000000
  fmv.d.x f0, t0
  li t0, 0x4008000000000000
  fmv.d.x f1, t0
  fsflags x0, x0
  fdiv.d f2, f0, f1, rup
  fmv.x.d t0, f2
  li t1, 0x3fd5555555555556
  bne t0, t1, fail
  fsflags t2, x0
  li t3, 1
  bne t2, t3, fail

  li TESTNUM, 5
  li t0, 0x3ff0000000000000
  fmv.d.x f0, t0
  li t0, 0x4008000000000000
  fmv.d.x f1, t0
  fsflags x0, x0
  fdiv.d f2, f0, f1, dyn
  fmv.x.d t0, f2
  li t1, 0x3fd5555555555555
  bne t0, t1, fail
  fsflags t2, x0
  li t3, 1
  bne t2, t3, fail

  li TESTNUM, 6
  li t0, 0x40000000
  fmv.w.x f0, t0
  fsflags x0, x0
  fsqrt.s f2, f0, rup
  fmv.x.s t0, f2
  li t1, 0x3fb504f4
  sext.w t1, t1
  bne t0, t1, fail
  fsflags t2, x0
  li t3, 1
  bne t2, t3, fail

  li TESTNUM, 7
  li t0, 0x40000000
  fmv.w.x f0, t0
  fsflags x0, x0
  fsqrt.s f2, f0, dyn
  fmv.x.s t0, f2
  li t1, 0x3fb504f3
  sext.w t1, t1
  bne t0, t1, fail
  fsflags t2, x0
  li t3, 1
  bne t2, t3, fail

  li TESTNUM, 8
  li t0, 0x4000000000000000
  fmv.d.x f0, t0
  fsflags x0, x0
  fsqrt.d f2, f0, rup
  fmv.x.d t0, f2
  li t1, 0x3ff6a09e667f3bcd
  bne t0, t1, fail
  fsflags t2, x0
  li t3, 1
  bne t2, t3, fail

  li TESTNUM, 9
  li t0, 0x4000000000000000
  fmv.d.x f0, t0
  fsflags x0, x0
  fsqrt.d f2, f0, dyn
  fmv.x.d t0, f2
  li t1, 0x3ff6a09e667f3bcc
  bne t0, t1, fail
  fsflags t2, x0
  li t3, 1
  bne t2, t3, fail

  fsrmi 0
  TEST_PASSFAIL

RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
