// SPDX-License-Identifier: Apache-2.0
#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32IM")
.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    RVTEST_SIGBASE(x5, signature_results)
    li x20, 0x7fffffff
    li x21, 3
    div x10, x20, x21
    div x11, x20, x21
    divu x12, x20, x21
    divu x13, x20, x21
    rem x14, x20, x21
    rem x15, x20, x21
    remu x16, x20, x21
    remu x17, x20, x21
    RVTEST_SIGUPD(x5, x10, 0)
    RVTEST_SIGUPD(x5, x11, 4)
    RVTEST_SIGUPD(x5, x12, 8)
    RVTEST_SIGUPD(x5, x13, 12)
    RVTEST_SIGUPD(x5, x14, 16)
    RVTEST_SIGUPD(x5, x15, 20)
    RVTEST_SIGUPD(x5, x16, 24)
    RVTEST_SIGUPD(x5, x17, 28)
RVTEST_CODE_END
RVMODEL_HALT
RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVMODEL_DATA_BEGIN
rvtest_sig_begin:
sig_begin_canary:
CANARY;
signature_results:
    .fill 8, 4, 0xdeadbeef
#ifdef rvtest_mtrap_routine
tsig_begin_canary:
CANARY;
mtrap_sigptr:
    .fill 64*(XLEN/32), 4, 0xdeadbeef
tsig_end_canary:
CANARY;
#endif
#ifdef rvtest_gpr_save
gpr_save:
    .fill 32*(XLEN/32), 4, 0xdeadbeef
#endif
sig_end_canary:
CANARY;
rvtest_sig_end:
RVMODEL_DATA_END
