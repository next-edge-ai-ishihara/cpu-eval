// SPDX-License-Identifier: Apache-2.0
`include "cvxif_types.svh"

module cvxif_fu_result_ready_test;
  timeunit 1ns;
  timeprecision 1ns;

  localparam config_pkg::cva6_cfg_t Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  typedef logic [Cfg.X_HARTID_WIDTH-1:0] hartid_t;
  typedef logic [Cfg.X_ID_WIDTH-1:0] id_t;
  typedef `WRITEREGFLAGS_T(Cfg) write_enable_t;
  typedef `X_RESULT_T(Cfg, hartid_t, id_t, write_enable_t) result_t;
  typedef struct packed {
    logic [Cfg.XLEN-1:0] cause;
    logic [Cfg.XLEN-1:0] tval;
    logic [Cfg.GPLEN-1:0] tval2;
    logic [31:0] tinst;
    logic gva;
    logic valid;
    logic timing;
  } exception_t;

  logic clk = 0;
  logic rst_n = 0;
  logic illegal = 0;
  logic result_valid = 0;
  logic result_ready;
  bit ready_always = 1;
  result_t result = '0;

  always #5 clk = ~clk;

  cvxif_fu #(.CVA6Cfg(Cfg), .exception_t(exception_t), .x_result_t(result_t)) dut (
    .clk_i(clk), .rst_ni(rst_n), .v_i(1'b0), .x_valid_i(illegal),
    .x_trans_id_i(id_t'(1)), .x_illegal_i(illegal), .x_off_instr_i(32'h0000002b),
    .x_ready_o(), .x_trans_id_o(), .x_exception_o(), .x_result_o(),
    .x_valid_o(), .x_we_o(), .x_rd_o(), .result_valid_i(result_valid),
    .result_i(result), .result_ready_o(result_ready)
  );

  task automatic observe(string state);
    #1;
    $display("RESULT_READY %s expected=1 observed=%b", state, result_ready);
    ready_always &= result_ready === 1'b1;
  endtask

  initial begin
    @(negedge clk);
    rst_n = 1;
    observe("idle");
    @(negedge clk);
    result = '{hartid: '0, id: id_t'(2), data: 32'd17, rd: 5'd9, we: 1'b1};
    result_valid = 1;
    observe("writeback");
    @(negedge clk);
    result.we = 0;
    observe("no-writeback");
    @(negedge clk);
    result_valid = 0;
    illegal = 1;
    observe("rejected");
    if (ready_always) $display("CVXIF_FU_RESULT_READY_PASS");
    else $display("CVXIF_FU_RESULT_READY_FAIL");
    $finish;
  end
endmodule
