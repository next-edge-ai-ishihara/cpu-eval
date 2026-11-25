// SPDX-License-Identifier: Apache-2.0
module testbench;
  import ariane_pkg::*;
  localparam config_pkg::cva6_cfg_t CVA6Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  typedef logic [CVA6Cfg.TRANS_ID_BITS-1:0] transaction_id_t;

  logic clk = 0;
  logic rst_n = 0;
  logic input_valid = 0;
  logic output_valid;
  transaction_id_t input_id = '0;
  transaction_id_t output_id;
  fu_op operation = MUL;
  logic [31:0] a = '0;
  logic [31:0] b = '0;
  logic [31:0] result;

  multiplier #(.CVA6Cfg(CVA6Cfg)) dut (
    .clk_i(clk), .rst_ni(rst_n), .trans_id_i(input_id), .mult_valid_i(input_valid),
    .operation_i(operation), .operand_a_i(a), .operand_b_i(b), .result_o(result),
    .mult_valid_o(output_valid), .mult_trans_id_o(output_id)
  );

  task automatic advance_clock();
    #1 clk = 1;
    #1 clk = 0;
  endtask

  task automatic check_response(input string phase, input transaction_id_t id, input logic [31:0] value);
    if (output_valid !== 1'b1 || output_id !== id || result !== value)
      $fatal(1, "FAIL: %s valid=%b id=%h expected_id=%h result=%h expected_result=%h",
             phase, output_valid, output_id, id, result, value);
  endtask

  task automatic drive(input transaction_id_t id, input fu_op op,
                       input logic [31:0] operand_a, input logic [31:0] operand_b);
    input_valid = 1;
    input_id = id;
    operation = op;
    a = operand_a;
    b = operand_b;
    #1;
  endtask

  initial begin
    advance_clock();
    rst_n = 1;
    drive(1, MUL, 7, 11);
    advance_clock();
    check_response("first request after its sampling edge", 1, 77);
    drive(2, CLMULH, 32'h80000000, 32'h80000000);
    advance_clock();
    check_response("second request after immediately following edge", 2, 32'h40000000);
    $display("PASS: multiplier response timing and transaction IDs");
    $finish;
  end
endmodule
