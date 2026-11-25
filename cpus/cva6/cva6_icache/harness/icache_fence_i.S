/* SPDX-License-Identifier: Apache-2.0 */

#include "model_test.h"
#include "arch_test.h"

RVTEST_ISA("RV32I_Zifencei")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    .option push
    .option norvc
    .option norelax
    jal     ra, cached_instruction
    mv      s0, a0
    la      t0, cached_instruction
    li      t1, 0x00200513
    sw      t1, 0(t0)
    fence   rw, rw
    fence.i
    jal     ra, cached_instruction
    mv      s1, a0

    .pushsection .text.icache_fence_i, "ax"
    .balign 16
cached_instruction:
    addi    a0, zero, 1
    ret
    .popsection

    .option pop
RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
RVTEST_DATA_END

RVMODEL_DATA_BEGIN
rvtest_sig_begin:
rvtest_sig_end:
RVMODEL_DATA_END
