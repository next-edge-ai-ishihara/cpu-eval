// SPDX-License-Identifier: Apache-2.0
module testbench;
  import ariane_pkg::*;
  localparam config_pkg::cva6_cfg_t CVA6Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  typedef struct packed {
    fu_t fu;
    fu_op operation;
    logic [CVA6Cfg.XLEN-1:0] operand_a, operand_b, imm;
    logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
  } fu_data_t;
  typedef logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_t;

  logic clk = 0, reset_n = 0, flush = 0;
  logic input_valid = 0, result_valid, ready;
  logic [31:0] result;
  trans_id_t result_id;
  fu_data_t request = '0;

  mult #(.CVA6Cfg(CVA6Cfg), .fu_data_t(fu_data_t)) dut (
    .clk_i(clk), .rst_ni(reset_n), .flush_i(flush), .fu_data_i(request),
    .mult_valid_i(input_valid), .result_o(result), .mult_valid_o(result_valid),
    .mult_ready_o(ready), .mult_trans_id_o(result_id)
  );

  task automatic tick();
    #1 clk = 1;
    #1 clk = 0;
    #1;
  endtask

  task automatic wait_ready_without_result();
    for (int step = 0; step < 80; step++) begin
      if (result_valid)
        $fatal(1, "FAIL: unexpected result for transaction %0d", result_id);
      if (ready) return;
      tick();
    end
    $fatal(1, "FAIL: multiplier did not become ready within the observation budget");
  endtask

  task automatic issue(input fu_op op, input logic [31:0] a, b, input trans_id_t id);
    wait_ready_without_result();
    request = '{fu:MULT, operation:op, operand_a:a, operand_b:b, imm:'0, trans_id:id};
    input_valid = 1;
    tick();
    input_valid = 0;
    #1;
  endtask

  task automatic expect_result(input logic [31:0] value, input trans_id_t id);
    for (int step = 0; step < 80; step++) begin
      if (result_valid) begin
        if (result_id != id || result != value)
          $fatal(1, "FAIL: expected transaction %0d value=%h, got transaction %0d value=%h",
                 id, value, result_id, result);
        tick();
        return;
      end
      tick();
    end
    $fatal(1, "FAIL: result not observed within the observation budget");
  endtask

  initial begin
    tick();
    reset_n = 1;
    #1;
    issue(DIVU, 32'hffffff00, 32'd3, trans_id_t'(1));
    if (result_valid || ready)
      $fatal(1, "FAIL: division finished or the unit was ready right after issue, before flush");
    flush = 1;
    tick();
    flush = 0;
    #1;
    wait_ready_without_result();
    $display("MULT_FLUSH_ABORTED id=1");

    issue(DIVU, 32'd29, 32'd6, trans_id_t'(2));
    expect_result(32'd4, trans_id_t'(2));
    $display("MULT_DIV_RESULT id=2 value=00000004");
    issue(MUL, 32'd7, 32'd9, trans_id_t'(3));
    expect_result(32'd63, trans_id_t'(3));
    wait_ready_without_result();
    $display("MULT_MUL_RESULT id=3 value=0000003f");
    $display("PASS: flushed division does not produce a result");
    $finish;
  end
endmodule
