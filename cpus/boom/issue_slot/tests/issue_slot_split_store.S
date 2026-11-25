#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  la t0, issue_slot_data

  # The address is ready before the store data.
  li t1, 0x1122334455667788
  li t2, 1
  div t3, t1, t2
  sd t3, 0(t0)
  ld t4, 0(t0)
  bne t3, t4, fail

  # The store data is ready before the address.
  li t5, 8
  add t6, t0, t5
  li a0, 1
  div a1, t6, a0
  li a2, 0x8877665544332211
  sd a2, 0(a1)
  ld a3, 8(t0)
  bne a2, a3, fail


  ld a4, 16(t0)
  bnez a4, fail

  TEST_PASSFAIL

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
  .balign 64
issue_slot_data:
  .dword 0
  .dword 0
  .dword 0
RVTEST_DATA_END
