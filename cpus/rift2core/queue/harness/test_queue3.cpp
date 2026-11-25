// SPDX-License-Identifier: Apache-2.0

#include "VCpuEvalQueue3.h"

#include <cstdint>
#include <deque>
#include <iostream>

namespace {
constexpr unsigned capacity = 3;

void compare(const char* label, const char* field, uint32_t expected, uint32_t actual) {
    if (actual != expected) {
        std::cout << "CPU_EVAL_OBSERVATION_MISMATCH Queue3 " << label << ' ' << field
                  << " expected=" << expected << " actual=" << actual << '\n';
    }
}

void step(VCpuEvalQueue3& dut, std::deque<uint32_t>& fifo, const char* label,
          bool input_valid, uint32_t input, bool output_ready) {
    const bool empty = fifo.empty();
    const bool ready = fifo.size() < capacity;
    const bool valid = !empty || input_valid;
    const uint32_t output = empty ? input : fifo.front();

    dut.clock = 0;
    dut.enqValid = input_valid;
    dut.enqBits = input;
    dut.deqReady = output_ready;
    dut.eval();
    std::cout << "CPU_EVAL_QUEUE3 " << label << " ready=" << unsigned(dut.enqReady)
              << " valid=" << unsigned(dut.deqValid) << " count=" << unsigned(dut.count)
              << " bits=" << (dut.deqValid ? dut.deqBits : 0) << '\n';
    compare(label, "ready", ready, dut.enqReady);
    compare(label, "valid", valid, dut.deqValid);
    compare(label, "count", fifo.size(), dut.count);
    if (valid && dut.deqValid) {
        compare(label, "bits", output, dut.deqBits);
    }
    dut.clock = 1;
    dut.eval();

    const bool take = valid && output_ready;
    if (!empty && take) {
        fifo.pop_front();
    }
    if (input_valid && ready && !(empty && take)) {
        fifo.push_back(input);
    }
}

void reset(VCpuEvalQueue3& dut, std::deque<uint32_t>& fifo) {
    dut.clock = 0;
    dut.reset = 1;
    dut.enqValid = 0;
    dut.enqBits = 0;
    dut.deqReady = 0;
    dut.eval();
    dut.clock = 1;
    dut.eval();
    dut.reset = 0;
    fifo.clear();
}
}  // namespace

int main() {
    VCpuEvalQueue3 dut;
    std::deque<uint32_t> fifo;
    reset(dut, fifo);
    step(dut, fifo, "empty", false, 0, true);
    step(dut, fifo, "bypass", true, 17, true);
    step(dut, fifo, "store_first", true, 33, false);
    step(dut, fifo, "store_second", true, 35, false);
    step(dut, fifo, "store_third", true, 39, false);
    step(dut, fifo, "full_stall", true, 43, false);
    step(dut, fifo, "full_dequeue", true, 43, true);
    step(dut, fifo, "wrap_replace", true, 43, true);
    step(dut, fifo, "drain_third", false, 0, true);
    step(dut, fifo, "drain_fourth", false, 0, true);
    step(dut, fifo, "drained", false, 0, true);
    step(dut, fifo, "store_before_reset", true, 57, false);
    reset(dut, fifo);
    step(dut, fifo, "after_reset", false, 0, true);
    dut.final();
    std::cout << "CPU_EVAL_QUEUE3_COMPLETE\nPass!\n";
    return 0;
}
