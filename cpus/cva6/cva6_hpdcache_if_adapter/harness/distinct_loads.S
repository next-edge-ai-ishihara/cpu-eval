#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I_Zicsr")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    la t0, load_lines
    la t1, load_lines + 1024
    la t2, load_lines + 2048
    la t3, load_lines + 3072
    lw a0, 0(t0)
    lw a1, 0(t1)
    lw a2, 0(t2)
    lw a3, 0(t3)

    li t4, 16
1:
    lw a0, 0(t0)
    lw a1, 0(t1)
    lw a2, 0(t2)
    lw a3, 0(t3)
    addi t4, t4, -1
    bnez t4, 1b
RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
.balign 4096
load_lines:
    .word 0x10203040
    .space 1020
    .word 0x50607080
    .space 1020
    .word 0x90a0b0c0
    .space 1020
    .word 0xd0e0f001
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
