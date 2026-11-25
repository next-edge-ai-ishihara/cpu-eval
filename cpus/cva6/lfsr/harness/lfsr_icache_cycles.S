#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I_Zicsr")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN

  li x5, 128
1:
  jal x1, lfsr_slot0
  jal x1, lfsr_slot1
  jal x1, lfsr_slot2
  addi x5, x5, -1
  bnez x5, 1b

  csrr x18, mcycle
  jal x1, lfsr_slot0
  csrr x19, mcycle
  sub x20, x19, x18
  addi x20, x20, 100
  csrr x18, mcycle
  jal x1, lfsr_slot1
  csrr x19, mcycle
  sub x21, x19, x18
  addi x21, x21, 100
  csrr x18, mcycle
  jal x1, lfsr_slot2
  csrr x19, mcycle
  sub x22, x19, x18
  addi x22, x22, 100
  csrr x18, mcycle
  jal x1, lfsr_slot0
  csrr x19, mcycle
  sub x23, x19, x18
  addi x23, x23, 100
  csrr x18, mcycle
  jal x1, lfsr_slot1
  csrr x19, mcycle
  sub x24, x19, x18
  addi x24, x24, 100

RVTEST_CODE_END
RVMODEL_HALT

.balign 1024
lfsr_slot0:
  addi x7, x7, 1
  jalr x0, 0(x1)

.balign 1024
lfsr_slot1:
  addi x7, x7, 3
  jalr x0, 0(x1)

.balign 1024
lfsr_slot2:
  addi x7, x7, 5
  jalr x0, 0(x1)

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
