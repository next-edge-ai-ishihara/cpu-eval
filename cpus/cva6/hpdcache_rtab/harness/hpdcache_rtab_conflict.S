#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    la t0, cache_line_a
    lw a0, 0(t0)
    la t0, cache_line_b
    lw a1, 0(t0)
    la t0, cache_line_a
    lw a2, 0(t0)
    la t0, cache_line_c
    lw a3, 0(t0)
RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
.balign 1024
cache_line_a:
    .word 0x13579bdf
    .space 1020
cache_line_b:
    .word 0x2468ace0
    .space 1020
cache_line_c:
    .word 0x55aa33cc
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
