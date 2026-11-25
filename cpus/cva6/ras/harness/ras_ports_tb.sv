// SPDX-License-Identifier: Apache-2.0
module testbench;
  localparam config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  typedef struct packed { logic valid; logic [Cfg.VLEN-1:0] ra; } ras_t;
  bit clk, rst_n, push, pop;
  logic [Cfg.VLEN-1:0] address;
  ras_t prediction;

  ras #(.CVA6Cfg(Cfg), .ras_t(ras_t), .DEPTH(Cfg.RASDepth)) dut (
    .clk_i(clk), .rst_ni(rst_n), .flush_bp_i(1'b0), .push_i(push), .pop_i(pop),
    .data_i(address), .data_o(prediction)
  );

  task automatic step(input string operation, input bit reset_n, push_i, pop_i,
                      input logic [Cfg.VLEN-1:0] new_address,
                      input bit expected_valid, input logic [Cfg.VLEN-1:0] expected_address,
                      input bit compare_prediction = 1);
    rst_n = reset_n;
    push = push_i;
    pop = pop_i;
    address = new_address;
    #1;
    clk = 1;
    #1;
    if (compare_prediction && (prediction.valid !== expected_valid ||
        (expected_valid && prediction.ra !== expected_address)))
      $fatal(1, "FAIL: %s valid=%b address=%h expected valid=%b address=%h",
             operation, prediction.valid, prediction.ra, expected_valid, expected_address);
    clk = 0;
    #1;
  endtask

  initial begin
    step("reset",           0, 0, 0, '0,   0, '0);
    step("outer call",      1, 1, 0, 'h102, 1, 'h102);
    step("nested call",     1, 1, 0, 'h204, 1, 'h204);
    step("pop then push",   1, 1, 1, 'h308, 1, 'h308);
    step("nested return",   1, 0, 1, '0,   1, 'h102);
    step("hold prediction", 1, 0, 0, '0,   1, 'h102);
    step("outer return",    1, 0, 1, '0,   0, '0);
    // Returning twice drains any two retained predictions.
    step("first push",      1, 1, 0, 'h100, 0, '0, 0);
    step("second push",     1, 1, 0, 'h204, 0, '0, 0);
    step("third push",      1, 1, 0, 'h308, 0, '0, 0);
    step("first drain pop", 1, 0, 1, '0,   0, '0, 0);
    step("depth-two drain", 1, 0, 1, '0,   0, '0);
    $display("PASS: nested calls, coroutine pop then push, and returns");
    $finish;
  end
endmodule
