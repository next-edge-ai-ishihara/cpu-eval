#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    la t0, refill_words
    lw t1, 0(t0)
    lw t2, 64(t0)
    lw t3, 128(t0)
    lw t4, 0(t0)
RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
.balign 4096
refill_words:
    .word 0x10203040
    .word 0x50607080
    .word 0x90a0b0c0
    .word 0xd0e0f000
    .fill 12, 4, 0
line_at_64:
    .word 0x11223344
    .fill 15, 4, 0
line_at_128:
    .word 0x55667788
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
