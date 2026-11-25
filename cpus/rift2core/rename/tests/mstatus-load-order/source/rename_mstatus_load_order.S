#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN
  la a0, payload
  li t0, MSTATUS_MPRV | MSTATUS_MPP
  li t1, MSTATUS_MPRV
  li TESTNUM, 2

  .balign 8
  csrs mstatus, t0
  ld a1, 0(a0)
  csrc mstatus, t1

  li a2, 0x123456789abcdef
  bne a1, a2, fail
  RVTEST_PASS
  TEST_PASSFAIL
RVTEST_CODE_END

.data
RVTEST_DATA_BEGIN
TEST_DATA
.balign 8
payload:
  .dword 0x123456789abcdef
RVTEST_DATA_END
