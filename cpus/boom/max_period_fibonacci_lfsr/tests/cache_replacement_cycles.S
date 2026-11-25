#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  la x5, cache_lines
  li x6, 4096

  mv x7, x5
  .rept 10
    ld x8, 0(x7)
    add x7, x7, x6
  .endr

  rdcycle x20
  .rept 64
    mv x7, x5
    .rept 10
      ld x8, 0(x7)
      add x7, x7, x6
    .endr
  .endr
  rdcycle x21
  sub x20, x21, x20

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .balign 4096
cache_lines:
  .dword 1
  .space 4088
  .dword 2
  .space 4088
  .dword 3
  .space 4088
  .dword 4
  .space 4088
  .dword 5
  .space 4088
  .dword 6
  .space 4088
  .dword 7
  .space 4088
  .dword 8
  .space 4088
  .dword 9
  .space 4088
  .dword 10
RVTEST_DATA_END
