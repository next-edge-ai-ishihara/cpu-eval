#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  la x10, test_data
  ld x20, 0(x10)
  add x11, x10, x20
  addi x11, x11, 1
  addi x11, x11, -1
  addi x11, x11, 1
  addi x11, x11, -1
  addi x11, x11, 1
  addi x11, x11, -1
  addi x11, x11, 1
  addi x11, x11, -1
  addi x11, x11, 1
  addi x11, x11, -1
  addi x11, x11, 1
  addi x11, x11, -1
  addi x11, x11, 1
  addi x11, x11, -1
  addi x11, x11, 1
  addi x11, x11, -1
  ld x21, 0(x11)
  xor x22, x21, x0

  li x14, 4096
  la x15, test_array
1:
  sd x14, 0(x15)
  addi x15, x15, 8
  addi x14, x14, -1
  bnez x14, 1b
  li x14, 4096
  la x15, test_array
2:
  ld x21, 0(x15)
  xor x22, x21, x0
  addi x15, x15, 8
  addi x14, x14, -1
  bnez x14, 2b

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
  .align 3
test_data:
  .dword 0
  .align 12
test_array:
  .zero 32768
RVTEST_DATA_END
