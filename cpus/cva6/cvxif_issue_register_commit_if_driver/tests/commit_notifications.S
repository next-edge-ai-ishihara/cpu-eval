#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I")
.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    .option norvc
    la t2, rejected_instruction
    csrw mtvec, t2
    li t0, 3
    li t1, 5
    .word 0x0062807b
    .word 0xfe62807b
    csrw mtvec, zero
    j notifications_done
    .align 2
rejected_instruction:
    csrr s0, mcause
    csrr t3, mepc
    addi t3, t3, 4
    csrw mepc, t3
    mret
notifications_done:
RVTEST_CODE_END
RVMODEL_HALT
RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVMODEL_DATA_BEGIN
rvtest_sig_begin:
sig_begin_canary:
CANARY;
sig_end_canary:
CANARY;
rvtest_sig_end:
RVMODEL_DATA_END
