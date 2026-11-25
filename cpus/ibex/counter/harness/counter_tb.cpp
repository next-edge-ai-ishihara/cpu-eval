// SPDX-License-Identifier: Apache-2.0
#include "Vibex_counter.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <initializer_list>

int main(int argc, char **argv) {
  VerilatedContext context;
  context.commandArgs(argc, argv);
  Vibex_counter dut{&context};
  uint64_t expected = 0;
  unsigned observations = 0;
  auto check = [&](const char *phase) {
    dut.eval();
    if (context.gotFinish()) {
      std::fprintf(stderr, "COUNTER_PORT_INCOMPLETE %s\n", phase);
      std::exit(2);
    }
    const uint64_t updated = COUNTER_PROVIDE_VAL_UPD ? expected + uint64_t{1} : 0;
    ++observations;
    if (dut.counter_val_o != expected || dut.counter_val_upd_o != updated) {
      std::fprintf(stderr,
        "COUNTER_PORT_MISMATCH %s observation=%u value=%016llx expected=%016llx upd=%016llx expected_upd=%016llx\n",
        phase, observations, (unsigned long long)dut.counter_val_o,
        (unsigned long long)expected, (unsigned long long)dut.counter_val_upd_o,
        (unsigned long long)updated);
      std::exit(1);
    }
  };
  dut.clk_i = 0; dut.rst_ni = 0; dut.counter_inc_i = 0;
  dut.counter_we_i = 0; dut.counterh_we_i = 0; dut.counter_val_i = 0;
  dut.eval(); dut.clk_i = 1; dut.eval(); dut.clk_i = 0; dut.rst_ni = 1; dut.eval();

  dut.counterh_we_i = 1; dut.counter_val_i = 0x12345678;
  dut.eval(); dut.clk_i = 1; dut.eval(); dut.clk_i = 0;
  dut.counterh_we_i = 0; dut.counter_we_i = 1; dut.counter_val_i = 0xfffffffe;
  dut.eval(); dut.clk_i = 1; dut.eval(); dut.clk_i = 0;
  dut.counter_we_i = 0; expected = UINT64_C(0x12345678fffffffe);
  check("established");
  auto cycle = [&](bool inc, bool high, bool low, uint32_t data) {
    dut.clk_i = 0; dut.counter_inc_i = inc;
    dut.counterh_we_i = high; dut.counter_we_i = low; dut.counter_val_i = data;
    check("before-edge");
    if (high) expected = (uint64_t{data} << 32) | uint32_t(expected);
    else if (low) expected = (expected & UINT64_C(0xffffffff00000000)) | data;
    else if (inc) ++expected;
    dut.clk_i = 1; check("after-edge");
    dut.clk_i = 0; check("falling-edge");
  };
  cycle(false, false, false, 0);
  cycle(true, false, false, 0);
  cycle(true, false, false, 0);
  cycle(false, false, false, 0);
  cycle(false, true, false, 0xffffffff);
  cycle(false, false, true, 0xffffffff);
  cycle(true, false, false, 0);
  cycle(false, false, false, 0);
  const uint32_t patterns[] = {0, 1, 0x7fffffff, 0x80000000, 0xffffffff, 0x55555555, 0xaaaaaaaa};
  for (uint32_t data : patterns) {
    for (bool inc : {false, true}) {
      cycle(inc, false, true, data);
      cycle(false, false, false, 0);
      cycle(inc, true, false, ~data);
      cycle(true, false, false, 0);
    }
  }
  dut.final();
  std::printf("COUNTER_PORT_PASS width=64 provide=%d observations=%u\n",
              COUNTER_PROVIDE_VAL_UPD, observations);
  return 0;
}
