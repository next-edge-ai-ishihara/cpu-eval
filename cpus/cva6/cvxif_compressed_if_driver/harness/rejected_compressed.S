// SPDX-License-Identifier: Apache-2.0 AND BSD-3-Clause
// Architectural-test boilerplate: Copyright (c) 2020. RISC-V International.
#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    la t0, rejected_compressed_trap
    csrw mtvec, t0
    li s2, -1
    .2byte 0x0000
    addi a0, s2, 1
RVTEST_CODE_END
RVMODEL_HALT

.balign 64
rejected_compressed_trap:
    csrr s2, mcause
    csrr t1, mepc
    addi t1, t1, 2
    csrw mepc, t1
    mret

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
