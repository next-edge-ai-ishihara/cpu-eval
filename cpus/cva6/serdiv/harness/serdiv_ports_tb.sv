// SPDX-License-Identifier: Apache-2.0
module testbench;
  localparam config_pkg::cva6_cfg_t CVA6Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  typedef logic [CVA6Cfg.TRANS_ID_BITS-1:0] transaction_id_t;

  logic clk = 0;
  logic rst_n = 0;
  logic request_valid = 0;
  logic request_ready;
  logic response_valid;
  logic response_ready = 1;
  transaction_id_t request_id = 2;
  transaction_id_t response_id;
  logic [31:0] result;

  serdiv #(.CVA6Cfg(CVA6Cfg), .WIDTH(32)) dut (
    .clk_i(clk), .rst_ni(rst_n), .id_i(request_id), .op_a_i(32'd63),
    .op_b_i(32'd7), .opcode_i(2'b00), .in_vld_i(request_valid),
    .in_rdy_o(request_ready), .flush_i(1'b0), .out_vld_o(response_valid),
    .out_rdy_i(response_ready), .id_o(response_id), .res_o(result)
  );

  task automatic advance_clock();
    #1 clk = 1;
    #1 clk = 0;
  endtask

  task automatic check_response(input string phase);
    if (response_valid !== 1'b1 || response_id !== 2 || result !== 9)
      $fatal(1, "FAIL: %s valid=%b id=%0d result=%0d expected_id=2 expected_result=9",
             phase, response_valid, response_id, result);
  endtask

  initial begin
    int cycle;
    advance_clock();
    rst_n = 1;
    #1;
    for (cycle = 0; cycle < 96 && !request_ready; cycle++)
      advance_clock();
    if (request_ready !== 1'b1)
      $fatal(1, "FAIL: divider did not offer to accept a request");
    response_ready = 0;
    request_valid = 1;
    advance_clock();
    request_valid = 0;
    request_id = 3;
    #1;
    for (cycle = 0; cycle < 96 && !response_valid; cycle++)
      advance_clock();
    check_response("completed division before the stalled edge");
    advance_clock();
    check_response("division retained across the stalled edge");
    response_ready = 1;
    advance_clock();
    $display("PASS: unaccepted division result and ID retained");
    $finish;
  end
endmodule
