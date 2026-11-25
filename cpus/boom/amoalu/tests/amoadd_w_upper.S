#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  la a0, operand
  addi a1, a0, 4
  li a2, 2
  TEST_CASE(2, a3, 1, amoadd.w a3, a2, (a1))
  TEST_CASE(3, a4, 0x000000035a5a5a5a, ld a4, (a0))

  TEST_PASSFAIL
RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  .balign 8
operand:
  .word 0x5a5a5a5a, 1
RVTEST_DATA_END
