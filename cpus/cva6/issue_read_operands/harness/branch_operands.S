/* SPDX-License-Identifier: Apache-2.0 AND BSD-3-Clause
 * Architectural-test boilerplate copyright (c) 2020 RISC-V International.
 */
#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    .option push
    .option norvc
    addi a0, zero, 37
    addi a1, zero, 37
    addi a2, zero, 0
    beq  a0, a1, 1f
    addi a2, zero, 9
1:
    addi a1, a1, 1
    beq  a0, a1, 2f
    addi a2, a2, 1
2:
    .option pop
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
