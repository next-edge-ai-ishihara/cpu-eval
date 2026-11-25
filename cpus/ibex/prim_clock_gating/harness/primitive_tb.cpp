#include "Vprim_clock_gating.h"
#include "verilated.h"

#include <cstdio>

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Vprim_clock_gating dut;

  for (int enable = 0; enable <= 1; ++enable) {
    for (int test_enable = 0; test_enable <= 1; ++test_enable) {
      dut.en_i = enable;
      dut.test_en_i = test_enable;
      dut.clk_i = 0;
      dut.eval();
      if (dut.clk_o != 0) {
        std::printf("MISMATCH clock=0 enable=%d test_enable=%d output=%d\n",
                    enable, test_enable, static_cast<int>(dut.clk_o));
        return 1;
      }
      dut.clk_i = 1;
      dut.eval();
      const int expected = enable || test_enable;
      if (dut.clk_o != expected) {
        std::printf(
            "MISMATCH clock=1 enable=%d test_enable=%d expected=%d output=%d\n",
            enable, test_enable, expected, static_cast<int>(dut.clk_o));
        return 1;
      }
      dut.en_i = !enable;
      dut.eval();
      if (dut.clk_o != expected) {
        std::printf("MISMATCH high phase functional enable transition output=%d expected=%d\n",
                    static_cast<int>(dut.clk_o), expected);
        return 1;
      }
      dut.clk_i = 0;
      dut.eval();
      if (dut.clk_o != 0) {
        std::puts("MISMATCH low phase after functional enable transition");
        return 1;
      }
      dut.clk_i = 1;
      dut.eval();
      const int next_expected = !enable || test_enable;
      if (dut.clk_o != next_expected) {
        std::printf("MISMATCH next high phase output=%d expected=%d\n",
                    static_cast<int>(dut.clk_o), next_expected);
        return 1;
      }
      dut.clk_i = 0;
      dut.eval();
      dut.en_i = enable;
      dut.eval();
      if (dut.clk_o != 0) {
        std::puts("MISMATCH output rose while input clock was low");
        return 1;
      }
      dut.clk_i = 1;
      dut.eval();
      if (dut.clk_o != expected) {
        std::printf("MISMATCH rising edge after low-phase enable change output=%d expected=%d\n",
                    static_cast<int>(dut.clk_o), expected);
        return 1;
      }
    }
  }
  std::puts("PASS");
  return 0;
}
