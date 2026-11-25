#include "model_test.h"
#include "arch_test.h"
RVTEST_ISA("RV64IA")

.macro cached_amo instruction, slot, offset, operand
    la t0, \slot
    ld t1, 0(t0)
    addi t5, t0, \offset
    li t2, \operand
    \instruction t3, t2, (t5)
    ld t4, 0(t0)
.endm

.macro cached_lr instruction, slot, offset
    la t0, \slot
    ld t1, 0(t0)
    addi t5, t0, \offset
    \instruction t3, (t5)
    ld t4, 0(t0)
.endm

.macro cached_sc load, store, slot, offset, operand
    la t0, \slot
    ld t1, 0(t0)
    addi t5, t0, \offset
    li t2, \operand
    \load t6, (t5)
    \store t3, t2, (t5)
    ld t4, 0(t0)
.endm

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN
    la t0, amo_add_word
    ld t1, 0(t0)
    li t2, 5
    amoadd.d t3, t2, (t0)
    ld t4, 0(t0)

    la t0, amo_xor_word
    ld t1, 0(t0)
    li t2, 0x0f
    amoxor.d t3, t2, (t0)
    ld t4, 0(t0)

    cached_amo amomin.d,  min_d_data,  0, 5
    cached_amo amomax.d,  max_d_data,  0, 5
    cached_amo amominu.d, minu_d_data, 0, 5
    cached_amo amomaxu.d, maxu_d_data, 0, 5
    cached_amo amoand.d,  and_d_data,  0, 0x0f
    cached_amo amoor.d,   or_d_data,   0, 0x0f
    cached_amo amoswap.d, swap_d_data, 0, -7

    cached_amo amoadd.w,  add_w_data,  0, 1
    cached_amo amoand.w,  and_w_data,  4, 0x0f0f0f0f
    cached_amo amoor.w,   or_w_data,   0, 0x0f
    cached_amo amoxor.w,  xor_w_data,  4, 0x0f
    cached_amo amoswap.w, swap_w_data, 0, -7
    cached_amo amomin.w,  min_w_data,  4, 5
    cached_amo amomax.w,  max_w_data,  0, 5
    cached_amo amominu.w, minu_w_data, 4, 5
    cached_amo amomaxu.w, maxu_w_data, 0, 5

    cached_lr lr.d, lr_d_data, 0
    cached_lr lr.w, lr_w_data, 4
    cached_sc lr.d, sc.d, sc_d_data, 0, 23
    cached_sc lr.w, sc.w, sc_w_data, 4, -7
RVTEST_CODE_END
RVMODEL_HALT

RVTEST_DATA_BEGIN
.balign 64
amo_add_word:
    .dword 7
amo_xor_word:
    .dword 0xaa
min_d_data:  .dword -3
max_d_data:  .dword -3
minu_d_data: .dword -3
maxu_d_data: .dword -3
and_d_data:  .dword 0xaa
or_d_data:   .dword 0xaa
swap_d_data: .dword 17

add_w_data:  .dword 0x13579bdf7fffffff
and_w_data:  .dword 0xaaaaaaaa13579bdf
or_w_data:   .dword 0x13579bdf000000aa
xor_w_data:  .dword 0x000000aa13579bdf
swap_w_data: .dword 0x13579bdf00000011
min_w_data:  .dword 0xfffffffd13579bdf
max_w_data:  .dword 0x13579bdffffffffd
minu_w_data: .dword 0xfffffffd13579bdf
maxu_w_data: .dword 0x13579bdffffffffd

lr_d_data:   .dword 0x1122334455667788
lr_w_data:   .dword 0x8000076513579bdf
sc_d_data:   .dword 17
sc_w_data:   .dword 0x0000001113579bdf
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
