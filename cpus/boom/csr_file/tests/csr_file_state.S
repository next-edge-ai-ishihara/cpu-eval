#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  TEST_CASE(2, x20, 0x123456789abcdef0, \
    li x5, 0x123456789abcdef0; \
    csrw mscratch, x5; \
    csrr x20, mscratch)

  TEST_CASE(3, x21, 0x123456789abcdef0, \
    li x6, 0x00000000000000ff; \
    csrrs x21, mscratch, x6)

  TEST_CASE(4, x22, 0x123456789abcdeff, \
    csrr x22, mscratch)

  TEST_CASE(5, x23, 0x123456789abcdeff, \
    li x6, 0x00000000000000f0; \
    csrrc x23, mscratch, x6)

  TEST_CASE(6, x24, 0x123456789abcde0f, \
    csrr x24, mscratch)

  li TESTNUM, 7
  la x5, trap_handler
  csrw mtvec, x5
do_ecall:
  ecall
after_ecall:
  li x5, 11
  bne x25, x5, fail
  la x5, do_ecall
  bne x26, x5, fail

  TEST_PASSFAIL

  .align 2
trap_handler:
  li x28, 93
  bne x17, x28, 1f
  j trap_vector
1:
  csrr x25, mcause
  csrr x26, mepc
  addi x27, x26, 4
  csrw mepc, x27
  mret

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
