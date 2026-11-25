// SPDX-License-Identifier: Apache-2.0
#include "Vel2_dec_ib_ctl.h"
#include "verilated.h"
#include <cstdint>
#include <iostream>

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Vel2_dec_ib_ctl dut;
    dut.dbg_cmd_valid = 0;
    dut.dbg_cmd_write = 0;
    dut.dbg_cmd_type = 0;
    dut.dbg_cmd_addr = 0;
    dut.ifu_i0_valid = 0;
    dut.ifu_i0_instr = 0x13579bdf;
    auto check = [&](const char *name, uint32_t actual, uint32_t expected) {
        if (actual == expected) return true;
        std::cerr << "DEBUG_COMMAND_MISMATCH " << name << " actual=0x"
                  << std::hex << actual << " expected=0x" << expected << '\n';
        return false;
    };
    // The presented upstream decoder emits types 0, 1 and 2 only.
    for (unsigned type = 0; type < 2; ++type) {
        for (unsigned write = 0; write < 2; ++write) {
            for (uint32_t reg : {0u, 13u, 31u}) {
                const uint32_t address = type == 0 ? reg
                    : (reg == 0 ? 0x300u : reg == 13 ? 0x305u : 0x7c4u);
                dut.dbg_cmd_valid = 1;
                dut.dbg_cmd_write = write;
                dut.dbg_cmd_type = type;
                dut.dbg_cmd_addr = address;
                dut.eval();
                const uint32_t csr = address & 0xfffu;
                const uint32_t instruction = type == 0
                    ? (write ? (0x6033u | (reg << 7)) : (0x6033u | (reg << 15)))
                    : ((csr << 20) | (write ? 0x1073u : 0x2073u));
                if (!check("instruction", dut.dec_i0_instr_d, instruction) ||
                    !check("valid", dut.dec_ib0_valid_d, 1) ||
                    !check("debug_valid", dut.dec_debug_valid_d, 1) ||
                    !check("write_data", dut.dec_debug_wdata_rs1_d, write) ||
                    !check("fence", dut.dec_debug_fence_d,
                           type == 1 && write && csr == 0x7c4)) return 1;
            }
        }
    }
    // The selected configuration maps the DCCM at 0xf0040000.
    dut.dbg_cmd_type = 2;
    dut.dbg_cmd_addr = 0xf0040000u;
    for (unsigned write = 0; write < 2; ++write) {
        dut.dbg_cmd_write = write;
        dut.eval();
        if (!check("memory_decode_valid", dut.dec_ib0_valid_d, 0) ||
            !check("memory_debug_valid", dut.dec_debug_valid_d, 0) ||
            !check("memory_write_data", dut.dec_debug_wdata_rs1_d, 0) ||
            !check("memory_fence", dut.dec_debug_fence_d, 0)) return 1;
    }
    dut.dbg_cmd_valid = 0;
    dut.ifu_i0_valid = 1;
    dut.ifu_i0_instr = 0x89abcdef;
    dut.eval();
    if (!check("ordinary_instruction", dut.dec_i0_instr_d, 0x89abcdef) ||
        !check("ordinary_valid", dut.dec_ib0_valid_d, 1) ||
        !check("debug_idle", dut.dec_debug_valid_d, 0) ||
        !check("idle_write_data", dut.dec_debug_wdata_rs1_d, 0) ||
        !check("idle_fence", dut.dec_debug_fence_d, 0)) return 1;
    std::cout << "DEBUG_COMMANDS_PASS\n";
    return 0;
}
