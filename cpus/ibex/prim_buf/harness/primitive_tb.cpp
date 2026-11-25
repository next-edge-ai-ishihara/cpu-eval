#include "Vprim_buf.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>

static bool matches(Vprim_buf &dut, std::uint32_t input) {
  dut.in_i = input;
  dut.eval();
  if (dut.out_o == input) return true;
  std::printf("MISMATCH input=%08x output=%08x\n", input,
              static_cast<std::uint32_t>(dut.out_o));
  return false;
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Vprim_buf dut;
#ifdef CPU_EVAL_PRIM_BUF_WIDTH_4
  for (std::uint32_t input = 0; input < 16; ++input) {
    if (!matches(dut, input)) return 1;
  }
#else
  const std::uint32_t inputs[] = {
      0x00000000U,
      0xffffffffU,
      0x00000797U,
      0x06478793U,
      0xa5a55a5aU,
  };

  for (const std::uint32_t input : inputs) {
    if (!matches(dut, input)) return 1;
  }
#endif
  std::puts("PASS");
  return 0;
}
