#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I_Zicsr")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    la t0, cached_line
    lw a0, 0(t0)

    li t1, 256
    csrr s2, mcycle
1:
    lw a0, 0(t0)
    addi t1, t1, -1
    bnez t1, 1b
    csrr s3, mcycle
    sub s4, s3, s2
RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
.balign 64
cached_line:
    .word 0x13579bdf
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
