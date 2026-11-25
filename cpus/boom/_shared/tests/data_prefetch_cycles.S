#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  la t0, test_data
  li t1, 128
  li s5, 0
  csrr s2, mcycle
1:
  ld t2, 0(t0)
  xor s5, s5, t2
  fence rw, rw
  li t3, 64
2:
  addi t3, t3, -1
  bnez t3, 2b
  addi t0, t0, 64
  addi t1, t1, -1
  bnez t1, 1b
  csrr s3, mcycle
  sub x20, s3, s2
  bnez s5, fail

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
  .balign 64
test_data:
  .fill 1024, 8, 0x0123456789abcdef
RVTEST_DATA_END
