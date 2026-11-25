// SPDX-License-Identifier: Apache-2.0

#include "VCpuEvalLfsr16.h"

#include <bitset>
#include <cstdint>
#include <iostream>

namespace {
constexpr unsigned state_count = 1U << 16;
constexpr unsigned maximal_period = state_count - 1;
constexpr uint16_t seed = 1;

void tick(VCpuEvalLfsr16& dut) {
    dut.clock = 0;
    dut.eval();
    dut.clock = 1;
    dut.eval();
}

void check_reset(VCpuEvalLfsr16& dut, const char* phase) {
    dut.reset = 1;
    tick(dut);
    dut.reset = 0;
    const uint16_t actual = dut.value;
    std::cout << "CPU_EVAL_LFSR16_RESET phase=" << phase << " value=" << actual << "\n";
    if (actual != seed) {
        std::cout << "CPU_EVAL_OBSERVATION_MISMATCH LFSR16 reset seed\n";
    }
}

void check_hold(VCpuEvalLfsr16& dut) {
    dut.advance = 0;
    const uint16_t held = dut.value;
    constexpr unsigned hold_cycles = 4;
    bool matches = true;
    for (unsigned cycle = 0; cycle < hold_cycles; ++cycle) {
        tick(dut);
        matches &= dut.value == held;
    }
    std::cout << "CPU_EVAL_LFSR16_HOLD cycles=" << hold_cycles << " start=" << held
              << " end=" << dut.value << "\n";
    if (!matches) {
        std::cout << "CPU_EVAL_OBSERVATION_MISMATCH LFSR16 state changed without advance\n";
    }
}

void check_period(VCpuEvalLfsr16& dut) {
    dut.advance = 1;
    std::bitset<state_count> seen;
    std::bitset<state_count> feedback;
    uint16_t previous = dut.value;
    bool shift_matches = true;
    seen.set(dut.value);
    for (unsigned cycle = 1; cycle <= maximal_period; ++cycle) {
        tick(dut);
        const uint16_t actual = dut.value;
        feedback[previous] = actual & 1;
        if (shift_matches && (actual >> 1) != (previous & 0x7fff)) {
            shift_matches = false;
            std::cout << "CPU_EVAL_OBSERVATION_MISMATCH LFSR16 Fibonacci shift previous="
                      << previous << " value=" << actual << "\n";
        }
        if (actual == 0 || seen.test(actual) || cycle == maximal_period) {
            std::cout << "CPU_EVAL_LFSR16_PERIOD advance_cycles=" << cycle
                      << " distinct_states=" << seen.count() << " value=" << actual << "\n";
            if (cycle != maximal_period || seen.count() != maximal_period || actual != seed) {
                std::cout << "CPU_EVAL_OBSERVATION_MISMATCH LFSR16 nonzero period\n";
                return;
            }
            break;
        }
        seen.set(actual);
        previous = actual;
    }
    if (!shift_matches) {
        return;
    }

    uint16_t taps = 0;
    for (unsigned bit = 0; bit < 16; ++bit) {
        if (feedback[1U << bit]) {
            taps |= 1U << bit;
        }
    }
    for (unsigned state = 1; state < state_count; ++state) {
        const bool expected = std::bitset<16>(state & taps).count() & 1;
        if (feedback[state] != expected) {
            std::cout << "CPU_EVAL_OBSERVATION_MISMATCH LFSR16 nonlinear feedback state="
                      << state << " expected=" << expected << " actual=" << feedback[state] << "\n";
            return;
        }
    }
    std::cout << "CPU_EVAL_LFSR16_FIBONACCI taps=" << taps << "\n";
}
}  // namespace

int main() {
    VCpuEvalLfsr16 dut;
    dut.advance = 0;
    check_reset(dut, "initial");
    check_period(dut);
    for (unsigned step = 0; step < 7; ++step) {
        tick(dut);
    }
    check_hold(dut);
    check_reset(dut, "after_progress");
    dut.final();
    std::cout << "CPU_EVAL_LFSR16_COMPLETE\n";
    std::cout << "Pass!\n";
    return 0;
}
