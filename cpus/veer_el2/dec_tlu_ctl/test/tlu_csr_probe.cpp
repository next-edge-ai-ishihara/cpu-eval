#include "Vtlu_csr_probe.h"
#include "verilated.h"

#include <cstdio>

static Vtlu_csr_probe probe;
static unsigned failures;

static void cycle() {
    probe.clk = 0;
    probe.eval();
    probe.clk = 1;
    probe.eval();
    probe.clk = 0;
    probe.eval();
    Verilated::timeInc(1);
}

static void write_csr(unsigned address, unsigned value) {
    probe.addr = address;
    probe.wdata = value;
    probe.wen = 1;
    cycle();
    probe.wen = 0;
    probe.eval();
}

static void check(const char* name, unsigned actual, unsigned expected) {
    if (actual == expected) {
        std::printf("TLU_CSR_OK %s\n", name);
    } else {
        std::printf("TLU_CSR_MISMATCH %s actual=0x%08x expected=0x%08x\n", name, actual, expected);
        ++failures;
    }
}

static void read_csr(const char* name, unsigned address, unsigned expected) {
    probe.addr = address;
    probe.wen = 0;
    probe.eval();
    check(name, probe.csr_read, expected);
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    probe.clk = 0;
    probe.rst_l = 0;
    probe.halt_req = 0;
    probe.wen = 0;
    probe.addr = 0;
    probe.wdata = 0;
    probe.eval();
    if (probe.config_ways != 2 || probe.config_tag_lo != 13 || probe.config_ecc != 1 ||
        probe.config_readback || probe.config_fpga) {
        std::puts("TLU_CSR_INVALID configuration");
        return 2;
    }
    for (int i = 0; i < 4; ++i) {
        cycle();
    }
    probe.rst_l = 1;
    for (int i = 0; i < 8; ++i) {
        cycle();
    }
    constexpr unsigned mfdc = 0x7f9, dicawics = 0x7c8, dicad0 = 0x7c9, dicad1 = 0x7ca, dicago = 0x7cb;
    read_csr("MFDC_reset", mfdc, 0x00070040);
    write_csr(mfdc, 0);
    read_csr("MFDC_zero", mfdc, 0);

    probe.addr = dicawics;
    probe.eval();
    check("diagnostic_illegal_outside_debug", probe.legal, 0);
    probe.halt_req = 1;
    for (int i = 0; i < 80 && !probe.halted; ++i) {
        cycle();
    }
    check("debug_halt_handshake", probe.halted, 1);
    if (!probe.halted) {
        probe.final();
        return 1;
    }
    probe.addr = dicawics;
    probe.eval();
    check("diagnostic_legal_in_debug", probe.legal, 1);
    if (!probe.legal) {
        probe.final();
        return 1;
    }
    write_csr(dicawics, 0x01000000);
    read_csr("tag_selection_legal", dicawics, 0x01000000);
    write_csr(dicawics, 0);
    write_csr(dicad0, 0xffffffff);
    write_csr(dicad1, 0xffffffff);
    read_csr("data_array_keeps_all_32_bits", dicad0, 0xffffffff);
    read_csr("data_ECC_keeps_7_bits", dicad1, 0x7f);
    write_csr(dicago, 1);
    check("DICAGO_write_one", probe.diag_write, 1);
    cycle();
    write_csr(dicawics, 0x01000000);
    write_csr(dicad0, 0x00123011);
    read_csr("legal_tag_fields", dicad0, 0x00123011);
    write_csr(dicad1, 0x1a);
    read_csr("legal_tag_ECC", dicad1, 0x1a);
    std::puts(failures ? "TLU_CSR_FAIL" : "TLU_CSR_PASS");
    probe.final();
    return failures ? 1 : 0;
}
