#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV64IA")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    la t0, amo_add_word
    li t1, 5
    amoadd.d t2, t1, (t0)
    ld t3, 0(t0)

    la t0, amo_xor_word
    li t1, 0x0f
    amoxor.d t2, t1, (t0)
    ld t3, 0(t0)
RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
.balign 64
amo_add_word:
    .dword 7
amo_xor_word:
    .dword 0xaa
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
