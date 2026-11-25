// SPDX-License-Identifier: Apache-2.0

#include <cstdint>
#include <cstdio>
#include "Vibex_prefetch_buffer.h"

static void tick(Vibex_prefetch_buffer& dut) {
    dut.clk_i = 1;
    dut.eval();
    dut.clk_i = 0;
    dut.eval();
}

int main() {
    Vibex_prefetch_buffer dut;
    constexpr uint32_t initial_pc = 0x100;
    dut.clk_i = 0;
    dut.rst_ni = 0;
    dut.req_i = 0;
    dut.branch_i = 0;
    dut.addr_i = 0;
    dut.ready_i = 1;
    dut.cheriot_force_uc_i = 0;
    dut.instr_gnt_i = 0;
    dut.instr_rvalid_i = 0;
    dut.instr_rdata_i = 0;
    dut.instr_err_i = 0;
    dut.eval();
    tick(dut);

    dut.rst_ni = 1;
    dut.req_i = 1;
    dut.branch_i = 1;
    dut.addr_i = initial_pc;
    dut.eval();
    for (int cycle = 0; !dut.instr_req_o && cycle < 12; ++cycle) {
        tick(dut);
        dut.branch_i = 0;
        dut.addr_i = 0;
        dut.eval();
    }
    if (!dut.instr_req_o) {
        std::puts("No request observed in the port test");
        return 2;
    }
    const uint32_t issued_address = dut.instr_addr_o;

    tick(dut);
    dut.branch_i = 0;
    dut.addr_i = 0;
    for (int delay = 1; delay <= 3; ++delay) {
        dut.eval();
        if (!dut.instr_req_o || dut.instr_addr_o != issued_address) {
            std::printf("PREFETCH_PORT_MISMATCH delayed grant cycle=%d request=%d address=%08x expected=%08x\n",
                        delay, dut.instr_req_o, dut.instr_addr_o, issued_address);
            return 1;
        }
        if (delay < 3) tick(dut);
    }
    dut.instr_gnt_i = 1;
    dut.eval();
    if (!dut.instr_req_o || dut.instr_addr_o != issued_address) {
        std::printf("PREFETCH_PORT_MISMATCH grant cycle request=%d address=%08x expected=%08x\n",
                    dut.instr_req_o, dut.instr_addr_o, issued_address);
        return 1;
    }
    tick(dut);
    std::puts("PASS prefetch request held until grant");
}
