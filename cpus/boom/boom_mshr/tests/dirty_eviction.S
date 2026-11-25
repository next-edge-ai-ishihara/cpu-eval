#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  li t0, 4096
  li t1, 0x80400000
  li t2, 16
  li t3, 257
1:
  sd t3, 0(t1)
  add t1, t1, t0
  addi t3, t3, 1
  addi t2, t2, -1
  bnez t2, 1b

  fence rw, rw
  li t1, 0x80400000
  li t2, 16
2:
  ld t4, 0(t1)
  add t1, t1, t0
  addi t2, t2, -1
  bnez t2, 2b

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
