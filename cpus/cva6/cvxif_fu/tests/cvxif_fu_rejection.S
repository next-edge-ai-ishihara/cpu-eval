#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV32I")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    la t3, cvxif_rejection_trap
    csrw mtvec, t3
    li s1, 0
    li t0, 5
    li t1, 7
    li t2, 3

    .word 0x0000007b  # CUS_NOP
    .word 0x0062957b  # CUS_ADD a0, t0, t1
    .word 0x026295fb  # CUS_DOUBLE_RS1 a1, t0, t1
    .word 0x0462967b  # CUS_DOUBLE_RS2 a2, t0, t1
    .word 0x066296fb  # CUS_ADD_MULTI a3, t0, t1
    .word 0x38628743  # CUS_ADD_RS3_MADD a4, t0, t1, t2
    .word 0x386287c7  # CUS_ADD_RS3_MSUB a5, t0, t1, t2
    .word 0x3862884f  # CUS_ADD_RS3_NMADD a6, t0, t1, t2
    .word 0x386288cb  # CUS_ADD_RS3_NMSUB a7, t0, t1, t2
    .word 0x0862957b  # CUS_ADD_RS3_RTYPE t0, t1, a0
    addi s0, a0, 1
    .word 0x0000002b  # Unsupported custom opcode: illegal-instruction exception
    addi s1, s1, 1
RVTEST_CODE_END
RVMODEL_HALT

.balign 4
cvxif_rejection_trap:
    csrr s2, mcause
    csrr s3, mepc
    addi t3, s3, 4
    jr t3

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
