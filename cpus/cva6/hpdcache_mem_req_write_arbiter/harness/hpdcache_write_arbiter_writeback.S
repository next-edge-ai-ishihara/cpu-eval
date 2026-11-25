#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV64I")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    la t0, writeback_data
    li t1, 0x89abcdef
    sw t1, 0(t0)
    fence.i
    lw t2, 0(t0)
    lwu t3, 0(t0)
RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
.balign 4096
writeback_data:
    .word 0x10203040
    .fill 15, 4, 0
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
