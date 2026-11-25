// SPDX-License-Identifier: Apache-2.0

module check_pmp_csr
  import el2_pkg::*;
#(
`include "el2_param.vh"
  ) ();
  logic clk = 0, free_l2clk = 0, csr_wr_clk = 0, rst_l = 1;
  logic dec_csr_wen_r_mod = 0;
  logic [11:0] dec_csr_wraddr_r = 0, dec_csr_rdaddr_d = 0;
  logic [31:0] dec_csr_wrdata_r = 0, dec_pmp_rddata_d;
  logic csr_pmpcfg = 0, csr_pmpaddr0 = 0;
  logic csr_pmpaddr16 = 0, csr_pmpaddr32 = 0, csr_pmpaddr48 = 0;
  logic dec_pause_state = 0, dec_tlu_pmu_fw_halted = 0;
  logic internal_dbg_halt_timers = 0, scan_mode = 0, dec_pmp_read_d;
  el2_pmp_cfg_pkt_t pmp_pmpcfg[pt.PMP_ENTRIES];
  logic [31:0] pmp_pmpaddr[pt.PMP_ENTRIES];

  el2_dec_pmp_ctl #(.pt(pt)) dut (.*);

  task automatic write_csr(input logic [11:0] address,
                           input logic [31:0] value, input logic enable = 1);
    dec_csr_wraddr_r = address;
    dec_csr_wrdata_r = value;
    dec_csr_wen_r_mod = enable;
    #1;
    free_l2clk = 1;
    #1;
    free_l2clk = 0;
    dec_csr_wen_r_mod = 0;
  endtask

  int mismatches = 0;

  task automatic read_csr(input logic [11:0] address, input logic [31:0] expected);
    dec_csr_rdaddr_d = address;
    csr_pmpcfg = address[11:4] == 8'h3a;
    csr_pmpaddr0 = address[11:4] == 8'h3b;
    #1;
    if (!dec_pmp_read_d || dec_pmp_rddata_d !== expected) begin
      mismatches++;
      $display("CSR %h expected %h, got %h (read %b)", address, expected, dec_pmp_rddata_d, dec_pmp_read_d);
    end
  endtask

  initial begin
    if (pt.PMP_ENTRIES != 16) $fatal(1, "Selected target must have 16 entries");
    #1;
    rst_l = 0;
    #1;
    rst_l = 1;
    read_csr(12'h3a3, 0);
    read_csr(12'h3bf, 0);
    write_csr(12'h3bf, 32'hd2345678);
    read_csr(12'h3bf, 32'h12345678);
    if (pmp_pmpaddr[15] !== 32'h12345678) begin
      mismatches++;
      $display("Address output differs from stored CSR");
    end
    write_csr(12'h3bf, 0, 0);
    read_csr(12'h3bf, 32'h12345678);
    write_csr(12'h3a3, 32'h00626001);
    read_csr(12'h3a3, 32'h00000001);
    if (pmp_pmpcfg[12] !== 8'h01) begin
      mismatches++;
      $display("Configuration output differs from stored CSR");
    end
    #1;
    rst_l = 0;
    read_csr(12'h3a3, 0);
    read_csr(12'h3bf, 0);
    $display("PMP_CSR_CHECK_COMPLETE errors=%0d", mismatches);
    $finish;
  end
endmodule
