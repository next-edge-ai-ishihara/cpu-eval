#include "Vibex_csr.h"
#include "verilated.h"

#include <cstdint>
#include <cstdio>

int main(int argc, char **argv) {
  VerilatedContext context;
  context.commandArgs(argc, argv);
  Vibex_csr dut{&context};
  constexpr unsigned width = CSR_WIDTH;
  constexpr std::uint32_t mask = width == 32 ? UINT32_MAX : (UINT32_C(1) << width) - 1;
  constexpr std::uint32_t reset = CSR_RESET_VALUE & mask;
  constexpr bool mtvec = width == 32 && reset == 1;
  constexpr unsigned first_bit = mtvec ? 8 : 0;
  std::uint32_t expected = reset;
  unsigned observations = 0;
  auto input_value = [](std::uint32_t value) {
    return mtvec ? (value & UINT32_C(0xffffff00)) | UINT32_C(1) : value & mask;
  };

  auto sample = [&](const char *phase) {
    dut.eval();
    if (context.gotFinish()) {
      std::printf("CSR_PORT_INCOMPLETE phase=%s\n", phase);
      return false;
    }
    ++observations;
    if (dut.rd_data_o != expected || dut.rd_error_o != 0) {
      std::printf("CSR_PORT_MISMATCH width=%u reset=%08x phase=%s clk=%u rst_n=%u "
                  "wr_en=%u wr_data=%08x expected=%08x actual=%08x error=%u\n",
                  width, reset, phase, dut.clk_i, dut.rst_ni, dut.wr_en_i,
                  static_cast<std::uint32_t>(dut.wr_data_i), expected,
                  static_cast<std::uint32_t>(dut.rd_data_o), dut.rd_error_o);
      return false;
    }
    return true;
  };

  dut.clk_i = 0;
  dut.rst_ni = 1;
  dut.wr_en_i = 0;
  dut.wr_data_i = 0;
  dut.eval();
  if (context.gotFinish()) {
    std::puts("CSR_PORT_INCOMPLETE initial evaluation");
    return 2;
  }
  dut.rst_ni = 0;
  if (!sample("asynchronous-reset-low-clock")) return 1;
  dut.wr_en_i = 1;
  dut.wr_data_i = input_value(mask ^ reset);
  dut.clk_i = 1;
  if (!sample("reset-priority-over-write")) return 1;
  dut.rst_ni = 1;
  if (!sample("reset-release-without-edge")) return 1;

  auto write = [&](std::uint32_t value) {
    dut.clk_i = 0;
    dut.wr_en_i = 1;
    dut.wr_data_i = input_value(value);
    if (!sample("write-before-rising-edge")) return false;
    dut.clk_i = 1;
    expected = input_value(value);
    return sample("write-at-rising-edge");
  };
  auto hold = [&](std::uint32_t value) {
    dut.clk_i = 0;
    dut.wr_en_i = 0;
    dut.wr_data_i = input_value(value);
    if (!sample("hold-at-falling-edge")) return false;
    dut.clk_i = 1;
    return sample("hold-at-rising-edge");
  };

  if (!write(0) || !hold(mask) || !write(mask) || !hold(0)) return 1;
  if (!write(UINT32_C(0xa5a55a5a)) || !hold(UINT32_C(0x5a5aa5a5))) return 1;
  for (unsigned bit = first_bit; bit < width; ++bit) {
    const auto single = UINT32_C(1) << bit;
    if (!write(single) || !hold(mask ^ single)) return 1;
    if (!write(mask ^ single) || !hold(single)) return 1;
  }

  if (!write(0)) return 1;
  for (unsigned bit = first_bit; bit < width; ++bit) {
    if (!write(expected | (UINT32_C(1) << bit))) return 1;
  }
  for (unsigned bit = first_bit; bit < width; ++bit) {
    if (!write(expected & ~(UINT32_C(1) << bit))) return 1;
  }

  if (!write(mask ^ reset)) return 1;
  dut.wr_en_i = 1;
  dut.wr_data_i = input_value(mask ^ reset);
  dut.rst_ni = 0;
  expected = reset;
  if (!sample("asynchronous-reset-high-clock")) return 1;
  dut.clk_i = 0;
  if (!sample("reset-held-falling-edge")) return 1;
  dut.clk_i = 1;
  if (!sample("reset-held-rising-edge")) return 1;
  dut.rst_ni = 1;
  if (!sample("second-reset-release-without-edge")) return 1;
  if (!write(mask) || !hold(0)) return 1;

  dut.final();
  std::printf("CSR_PORT_PASS width=%u reset=%08x observations=%u\n", width, reset,
              observations);
  return 0;
}
