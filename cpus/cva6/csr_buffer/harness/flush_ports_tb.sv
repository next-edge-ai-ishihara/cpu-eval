// SPDX-License-Identifier: Apache-2.0 AND SHL-0.51
// The functional-unit data fields follow CVA6 core/cva6.sv.
// Copyright 2018 ETH Zurich and University of Bologna.
module testbench;
  import ariane_pkg::*;
  localparam config_pkg::cva6_cfg_t Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  typedef struct packed {
    fu_t fu;
    fu_op operation;
    logic [Cfg.XLEN-1:0] operand_a, operand_b, imm;
    logic [Cfg.TRANS_ID_BITS-1:0] trans_id;
  } fu_data_t;

  bit clk, rst_n, flush, valid;
  fu_data_t data;
  logic ready;
  logic [11:0] address;

  csr_buffer #(.CVA6Cfg(Cfg), .fu_data_t(fu_data_t)) dut (
    .clk_i(clk), .rst_ni(rst_n), .flush_i(flush), .fu_data_i(data),
    .csr_ready_o(ready), .csr_valid_i(valid), .csr_result_o(),
    .csr_commit_i(1'b0), .csr_addr_o(address)
  );

  task automatic step;
    #1 clk = 1;
    #1 clk = 0;
    #1;
  endtask

  initial begin
    step();
    rst_n = 1;
    valid = 1;
    data.operand_b = 'h340;
    step();
    valid = 0;
    #1;
    $display("BEFORE_FLUSH ready=%b address=%h", ready, address);
    if (ready !== 1'b0 || address !== 12'h340) begin
      $display("FAIL: CSR address was not pending before flush");
    end else begin
      flush = 1;
      step();
      flush = 0;
      #1;
      $display("AFTER_FLUSH ready=%b", ready);
      if (ready === 1'b1)
        $display("PASS: flush without commit released the CSR buffer");
      else
        $display("FAIL: flush without commit did not release the CSR buffer");
    end
    $finish;
  end
endmodule
