#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV64M
RVTEST_CODE_BEGIN

  li TESTNUM, 1
  la s0, pmp_data
  srli t0, s0, 2
  csrw pmpaddr0, t0
  addi t0, t0, 2
  csrw pmpaddr1, t0
  li t0, 0x9391
  csrw pmpcfg0, t0

  la t0, pmp_trap_handler
  csrw mtvec, t0
  li s4, 0

  li t1, 0x22222222
  sw t1, 0(s0)
  li t0, 1
  bne s4, t0, fail
  lw t1, 0(s0)
  li t0, 0x11111111
  bne t1, t0, fail

  li t1, 0x55555555
  sd t1, 8(s0)
  li t0, 2
  bne s4, t0, fail
  lw t1, 8(s0)
  li t0, 0x33333333
  bne t1, t0, fail
  lw t1, 12(s0)
  li t0, 0x44444444
  bne t1, t0, fail

  TEST_PASSFAIL

.balign 4
pmp_trap_handler:
  li t0, 93
  beq x17, t0, trap_vector
  csrr t0, mcause
  li t1, 7
  bne t0, t1, fail
  addi s4, s4, 1
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  TEST_DATA
  .balign 8
pmp_data:
  .word 0x11111111
  .word 0x22222222
  .word 0x33333333
  .word 0x44444444
RVTEST_DATA_END
