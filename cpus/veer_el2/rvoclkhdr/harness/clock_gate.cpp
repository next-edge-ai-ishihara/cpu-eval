// SPDX-License-Identifier: Apache-2.0
#include "Vrvoclkhdr.h"
#include "verilated.h"
#include <cstdio>

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Vrvoclkhdr dut;
  unsigned checks = 0;
  dut.scan_mode = 0;
  auto observe = [&](unsigned clk, unsigned en, unsigned expected, const char *phase) {
    dut.clk = clk;
    dut.en = en;
    Verilated::timeInc(10);
    dut.eval();
    std::printf("clock_observation phase=%s clk=%u en=%u expected=%u actual=%u\n",
                phase, clk, en, expected, unsigned(dut.l1clk));
    ++checks;
    return unsigned(dut.l1clk) == expected;
  };
  for (unsigned low = 0; low != 2; ++low) {
    for (unsigned high = 0; high != 2; ++high) {
      if (!observe(0, low, 0, "low")) return 1;
      if (!observe(1, low, low, "rise")) return 1;
      if (!observe(1, high, low, "high_enable_change")) return 1;
      if (!observe(0, high, 0, "fall")) return 1;
      if (!observe(0, !high, 0, "low_enable_change")) return 1;
      if (!observe(1, !high, !high, "rise_after_low_change")) return 1;
    }
  }
  dut.final();
  std::printf("clock_gate_port_test PASS observations=%u\n", checks);
  return 0;
}
