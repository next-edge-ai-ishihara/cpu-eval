#include "riscv_test.h"
#include "test_macros.h"

#if (DRAM_BASE & 0x1fffff) != 0
#error DRAM_BASE must be aligned to a 2 MiB page
#endif

RVTEST_RV64M
RVTEST_CODE_BEGIN
  la t0, level_one
  srli t0, t0, RISCV_PGSHIFT - PTE_PPN_SHIFT
  ori t0, t0, PTE_V
  la t1, root
  sd t0, 0(t1)
  srli t1, t1, RISCV_PGSHIFT
  li t0, (SATP_MODE & ~(SATP_MODE << 1)) * SATP_MODE_SV39
  or t1, t1, t0
  csrw satp, t1
  sfence.vma

  la t0, payload
  li t1, DRAM_BASE
  sub t0, t0, t1
  li TESTNUM, 2
  li t1, MSTATUS_MPP
  csrc mstatus, t1
  li t1, ((MSTATUS_MPP & ~(MSTATUS_MPP << 1)) * PRV_S) | MSTATUS_MPRV
  csrs mstatus, t1
  ld a2, 0(t0)
  li t1, MSTATUS_MPRV
  csrc mstatus, t1
  li a3, 0x123456789abcdeff
  bne a2, a3, fail
  RVTEST_PASS
  TEST_PASSFAIL
RVTEST_CODE_END

.data
RVTEST_DATA_BEGIN
TEST_DATA

.balign 4096
root:
  .zero 4096
level_one:
  .dword (DRAM_BASE / RISCV_PGSIZE << PTE_PPN_SHIFT) | PTE_V | PTE_R | PTE_X | PTE_A
  .zero 4088
payload:
  .dword 0x123456789abcdeff

RVTEST_DATA_END
