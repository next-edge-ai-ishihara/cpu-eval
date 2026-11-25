# See LICENSE for license details.

#include "riscv_test.h"
#include "test_macros.h"

/* Rift2330 runs one hardware thread and does not implement Smrnmi mnstatus. */
#undef RISCV_MULTICORE_DISABLE
#define RISCV_MULTICORE_DISABLE
#undef INIT_RNMI
#define INIT_RNMI

RVTEST_RV64U
RVTEST_CODE_BEGIN

  li TESTNUM, 2
  li t3, 256
1:
  call ras_level_one
  addi t3, t3, -1
  bnez t3, 1b

  la sp, ras_stack_end
  call ras_deep_1
  call ras_deep_1

#ifndef DEPTH_ONLY
  li t4, 256
  li t5, 0
3:
  call ras_flush_probe
  addi t4, t4, -1
  bnez t4, 3b

  /* jalr x5, ra returns to 5f and pushes its own continuation. */
  jal ra, ras_coroutine
5:
  jalr x0, x5, 0
6:
  /* The coroutine consumed its replacement. The stack is now empty. */
  la ra, 7f
  jalr x0, ra, 0
7:
#endif

  fence
  li TESTNUM, 1
  ecall

ras_level_one:
  mv s0, ra
  call ras_level_two
  mv ra, s0
  ret

ras_level_two:
  ret

ras_deep_1:
  addi sp, sp, -16
  sd ra, 8(sp)
  call ras_deep_2
  ld ra, 8(sp)
  addi sp, sp, 16
  ret

ras_deep_2:
  addi sp, sp, -16
  sd ra, 8(sp)
  call ras_deep_3
  ld ra, 8(sp)
  addi sp, sp, 16
  ret

ras_deep_3:
  addi sp, sp, -16
  sd ra, 8(sp)
  call ras_deep_4
  ld ra, 8(sp)
  addi sp, sp, 16
  ret

ras_deep_4:
  addi sp, sp, -16
  sd ra, 8(sp)
  call ras_deep_5
  ld ra, 8(sp)
  addi sp, sp, 16
  ret

ras_deep_5:
  addi sp, sp, -16
  sd ra, 8(sp)
  call ras_deep_6
  ld ra, 8(sp)
  addi sp, sp, 16
  ret

ras_deep_6:
  addi sp, sp, -16
  sd ra, 8(sp)
  call ras_deep_7
  ld ra, 8(sp)
  addi sp, sp, 16
  ret

ras_deep_7:
  ret

#ifndef DEPTH_ONLY
ras_flush_probe:
  xori t5, t5, 1
  beqz t5, 4f
  nop
4:
  ret

  .option push
  .option rvc
  .balign 4
  c.nop
ras_coroutine:
  jalr x5, ra, 0
  j 6b
  .option pop
#endif

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

  .align 4
ras_stack:
  .space 8192
ras_stack_end:

RVTEST_DATA_END
