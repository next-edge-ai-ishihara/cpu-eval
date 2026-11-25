#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64U
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  la x10, miss_data
  ld x20,   0(x10)
  ld x21,  64(x10)
  ld x22, 128(x10)
  ld x23, 192(x10)
  ld x24, 256(x10)
  ld x25, 320(x10)
  ld x26, 384(x10)
  ld x27, 448(x10)

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
  .balign 64
miss_data:
  .dword 0x0123456789abcdef
  .zero 56
  .dword 0x1123456789abcdef
  .zero 56
  .dword 0x2123456789abcdef
  .zero 56
  .dword 0x3123456789abcdef
  .zero 56
  .dword 0x4123456789abcdef
  .zero 56
  .dword 0x5123456789abcdef
  .zero 56
  .dword 0x6123456789abcdef
  .zero 56
  .dword 0x7123456789abcdef
RVTEST_DATA_END
