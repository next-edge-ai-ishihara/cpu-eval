// SPDX-License-Identifier: Apache-2.0
module copro_alu_destination_test;
  timeunit 1ns;
  timeprecision 1ns;
  import cvxif_instr_pkg::*;

  typedef logic [1:0][31:0] registers_t;
  typedef logic [31:0] hartid_t;
  typedef logic [1:0] id_t;
  localparam int MaxCycles = 2_000_000;

  logic clk = 0;
  logic rst_n = 0;
  opcode_t opcode = ILLEGAL;
  id_t id = '0, result_id;
  logic [4:0] rd = '0, result_rd;
  logic result_valid, write_enable;
  bit destinations_match = 1;

  always #5 clk = ~clk;

  copro_alu #(
    .NrRgprPorts(2), .XLEN(32), .hartid_t(hartid_t), .id_t(id_t), .registers_t(registers_t)
  ) dut (
    .clk_i(clk), .rst_ni(rst_n), .registers_i({32'd13, 32'd4}),
    .opcode_i(opcode), .hartid_i('0), .id_i(id), .rd_i(rd),
    .result_o(), .hartid_o(), .id_o(result_id), .rd_o(result_rd),
    .valid_o(result_valid), .we_o(write_enable)
  );

  task automatic check_destination(opcode_t operation, id_t transaction,
                                   logic [4:0] requested, logic [4:0] expected);
    @(negedge clk);
    opcode = operation;
    id = transaction;
    rd = requested;
    @(negedge clk);
    opcode = ILLEGAL;
    repeat (MaxCycles) begin
      if (result_valid && write_enable && result_id == transaction) begin
        $display("DESTINATION %s id=%0d input=x%0d expected=x%0d observed=x%0d",
                 operation.name(), transaction, requested, expected, result_rd);
        destinations_match &= result_rd === expected;
        return;
      end
      @(negedge clk);
    end
    $display("DESTINATION %s id=%0d input=x%0d expected=x%0d observed=no writeback",
             operation.name(), transaction, requested, expected);
    destinations_match = 0;
  endtask

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1;
    check_destination(ADD, 2'd0, 5'd7, 5'd7);
    check_destination(ADD_RS3_R, 2'd1, 5'd7, 5'd10);
    check_destination(ADD, 2'd2, 5'd19, 5'd19);
    check_destination(ADD_RS3_R, 2'd3, 5'd19, 5'd10);
    if (destinations_match) $display("COPRO_ALU_DESTINATION_PASS");
    else $display("COPRO_ALU_DESTINATION_FAIL");
    $finish;
  end
endmodule
