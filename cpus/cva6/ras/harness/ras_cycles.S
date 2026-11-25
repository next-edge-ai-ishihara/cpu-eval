#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I_Zicsr")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN

  li x5, 256
1:
  andi x6, x5, 1
  beqz x6, 2f
  jal x1, 4f
  j 3f
2:
  addi x7, x7, 1
3:
  addi x5, x5, -1
  bnez x5, 1b
  j 5f
4:
  addi x7, x7, 3
  jalr x0, 0(x1)

5:
  li x5, 4096
  csrr x18, mcycle
6:
  andi x6, x5, 1
  beqz x6, 7f
  jal x1, 9f
  j 8f
7:
  addi x7, x7, 1
8:
  addi x5, x5, -1
  bnez x5, 6b
  j 10f
9:
  addi x7, x7, 3
  jalr x0, 0(x1)
10:
  csrr x19, mcycle
  sub x20, x19, x18

RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
RVTEST_DATA_END

RVMODEL_DATA_BEGIN
rvtest_sig_begin:
sig_begin_canary:
CANARY;
#ifdef rvtest_mtrap_routine
tsig_begin_canary:
CANARY;
mtrap_sigptr:
    .fill 64*(XLEN/32),4,0xdeadbeef
tsig_end_canary:
CANARY;
#endif
#ifdef rvtest_gpr_save
gpr_save:
    .fill 32*(XLEN/32),4,0xdeadbeef
#endif
sig_end_canary:
CANARY;
rvtest_sig_end:
RVMODEL_DATA_END
