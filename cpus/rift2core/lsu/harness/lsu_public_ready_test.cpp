#include "VLsu.h"
#include "verilated.h"

#include <cstdlib>
#include <iostream>

namespace {

void tick(VLsu &dut) {
  dut.clock = 0;
  dut.eval();
  dut.clock = 1;
  dut.eval();
}

bool expect_signal(const char *scenario, bool observed, bool expected) {
  if (observed == expected) {
    return true;
  }
  std::cerr << "CPU_EVAL_PUBLIC_OUTPUT_MISMATCH " << scenario
            << " expected=" << expected << " observed=" << observed << '\n';
  return false;
}

// The fixed MMU raises lsu_mmu.ready only with a response accepted in the same cycle.
bool expect_ready(VLsu &dut, bool downstream_ready, bool expected) {
  dut.io_mmu_lsu_valid = downstream_ready;
  dut.eval();
  if (downstream_ready &&
      !expect_signal("MMU response transfer", dut.io_mmu_lsu_ready, true)) {
    return false;
  }
  dut.io_lsu_mmu_ready = downstream_ready && dut.io_mmu_lsu_ready;
  dut.eval();
  const bool observed = dut.io_lsu_iss_exe_ready;
  if (observed == expected) {
    return true;
  }
  std::cerr << "CPU_EVAL_PUBLIC_OUTPUT_MISMATCH "
            << "Lsu.io.lsu_iss_exe.ready downstream_ready="
            << downstream_ready << " expected=" << expected
            << " observed=" << observed << '\n';
  return false;
}

void reset_request_state(VLsu &dut) {
  dut.reset = 1;
  dut.io_flush = 0;
  dut.io_lsu_iss_exe_valid = 0;
  dut.io_lsu_iss_exe_bits_fun_lb = 0;
  dut.io_lsu_iss_exe_bits_fun_sb = 0;
  dut.io_lsu_iss_exe_bits_fun_ld = 0;
  dut.io_lsu_iss_exe_bits_fun_fence = 0;
  dut.io_lsu_mmu_ready = 0;
  dut.io_mmu_lsu_valid = 0;
  dut.io_lsu_exe_iwb_ready = 0;
  for (int cycle = 0; cycle < 4; ++cycle) {
    tick(dut);
  }
  dut.reset = 0;
}

bool check_fence_backpressure(VLsu &dut) {
  reset_request_state(dut);
  dut.io_lsu_iss_exe_valid = 1;
  dut.io_lsu_iss_exe_bits_fun_fence = 1;
  dut.eval();
  if (!expect_signal("first fence acceptance", dut.io_lsu_iss_exe_ready, true)) {
    return false;
  }
  tick(dut);
  // Hold off integer write-back so the first fence completion stays queued.
  if (!expect_signal("queued fence completion", dut.io_lsu_exe_iwb_valid, true) ||
      !expect_signal("second fence while completion is blocked", dut.io_lsu_iss_exe_ready, false)) {
    return false;
  }
  std::cout << "CPU_EVAL_PUBLIC_OUTPUT_CASE fence_backpressure\n";
  return true;
}

bool check_pending_fault(VLsu &dut) {
  reset_request_state(dut);
  dut.io_lsu_iss_exe_valid = 1;
  dut.io_lsu_iss_exe_bits_fun_ld = 1;
  dut.io_lsu_iss_exe_bits_param_dat_op1 = 1;
  dut.io_mmu_lsu_valid = 1;
  dut.io_mmu_lsu_bits_paddr = 1;
  dut.io_lsu_exe_iwb_ready = 1;
  dut.eval();
  if (!expect_signal("misaligned load response transfer", dut.io_mmu_lsu_ready, true) ||
      !expect_ready(dut, true, true)) {
    return false;
  }
  tick(dut);
  if (!expect_signal("pending load misalignment", dut.io_lsu_cmm_is_misAlign, true)) {
    return false;
  }

  dut.io_lsu_iss_exe_bits_fun_ld = 0;
  dut.io_lsu_iss_exe_bits_fun_lb = 1;
  dut.io_lsu_iss_exe_bits_param_dat_op1 = 0;
  dut.io_mmu_lsu_bits_paddr = 0;
  dut.eval();
  if (!expect_signal("MMU response can transfer while the fault is pending", dut.io_mmu_lsu_ready, true) ||
      !expect_signal("issue ready while the fault is pending", dut.io_lsu_iss_exe_ready, false)) {
    return false;
  }
  std::cout << "CPU_EVAL_PUBLIC_OUTPUT_CASE pending_misalignment\n";
  return true;
}

}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Verilated::randReset(0);
  VLsu dut;

  dut.reset = 1;
  dut.io_flush = 0;
  dut.io_lsu_iss_exe_valid = 1;
  dut.io_lsu_iss_exe_bits_fun_lb = 1;
  dut.io_lsu_iss_exe_bits_fun_fence = 0;
  dut.io_lsu_iss_exe_bits_fun_fence_i = 0;
  dut.io_lsu_iss_exe_bits_fun_sfence_vma = 0;
  for (int cycle = 0; cycle < 4; ++cycle) {
    tick(dut);
  }
  dut.reset = 0;

  // Issue ready follows lsu_mmu.ready for a byte load and a byte store.
  for (int store = 0; store < 2; ++store) {
    dut.io_lsu_iss_exe_bits_fun_lb = !store;
    dut.io_lsu_iss_exe_bits_fun_sb = store;
    if (!expect_ready(dut, false, false) || !expect_ready(dut, true, true)) {
      return EXIT_FAILURE;
    }
  }
  if (!check_fence_backpressure(dut) || !check_pending_fault(dut)) {
    return EXIT_FAILURE;
  }

  std::cout << "CPU_EVAL_PUBLIC_OUTPUT_PASS Lsu.io.lsu_iss_exe.ready\n";
  return EXIT_SUCCESS;
}
