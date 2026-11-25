// SPDX-License-Identifier: Apache-2.0 AND BSD-3-Clause
// Architectural-test boilerplate: Copyright (c) 2020. RISC-V International.
#include "model_test.h"
#include "arch_test.h"
#include "test_macros.h"
RVTEST_ISA("RV32I_Zicsr")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN

  RVTEST_SIGBASE(s1, signature_uncached)
  li t0, 0x02000000
  li s0, -1
  lw s0, 0(t0)
  RVTEST_SIGUPD(s1, s0, 0)

RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
RVTEST_DATA_END

RVMODEL_DATA_BEGIN
rvtest_sig_begin:
sig_begin_canary:
CANARY;
signature_uncached:
    .fill 1, 4, 0xdeadbeef
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
