// SPDX-License-Identifier: Apache-2.0
`include "cvxif_types.svh"

module tb;
  import cvxif_instr_pkg::*;

  localparam config_pkg::cva6_cfg_t Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  typedef `READREGFLAGS_T(Cfg) readregflags_t;
  typedef `WRITEREGFLAGS_T(Cfg) writeregflags_t;
  typedef `ID_T(Cfg) id_t;
  typedef `HARTID_T(Cfg) hartid_t;
  typedef `X_ISSUE_REQ_T(Cfg, hartid_t, id_t) issue_req_t;
  typedef `X_ISSUE_RESP_T(Cfg, writeregflags_t, readregflags_t) issue_resp_t;
  typedef `X_REGISTER_T(Cfg, hartid_t, id_t, readregflags_t) register_t;
  typedef logic [Cfg.NrRgprPorts-1:0][Cfg.XLEN-1:0] registers_t;

  logic clk = 0;
  logic rst_n = 0;
  logic issue_valid = 0;
  logic issue_ready;
  issue_req_t request;
  issue_resp_t response;
  register_t operands;
  registers_t selected_operands;
  opcode_t opcode;
  hartid_t hart;
  id_t id;
  logic [4:0] destination;
  int checks = 0;
  int errors = 0;

  instr_decoder #(
    .copro_issue_resp_t(copro_issue_resp_t), .opcode_t(opcode_t),
    .NbInstr(NbInstr), .CoproInstr(CoproInstr), .NrRgprPorts(Cfg.NrRgprPorts),
    .hartid_t(hartid_t), .id_t(id_t), .x_issue_req_t(issue_req_t),
    .x_issue_resp_t(issue_resp_t), .x_register_t(register_t), .registers_t(registers_t)
  ) dut (
    .clk_i(clk), .rst_ni(rst_n),
    .issue_valid_i(issue_valid), .issue_req_i(request),
    .issue_ready_o(issue_ready), .issue_resp_o(response),
    .register_valid_i(issue_valid), .register_i(operands), .registers_o(selected_operands),
    .opcode_o(opcode), .hartid_o(hart), .id_o(id), .rd_o(destination)
  );

  task automatic check(input logic correct, input string label);
    checks++;
    if (correct !== 1'b1) begin
      errors++;
      $display("MISMATCH %s", label);
    end
  endtask

  task automatic tick;
    #1; clk = 1;
    #1; clk = 0;
    #1;
  endtask

  task automatic wait_ready;
    #1;
    for (int attempts = 0; attempts < 16 && issue_ready !== 1'b1; attempts++)
      tick();
  endtask

  task automatic test_instruction(input int row, input readregflags_t available);
    copro_issue_resp_t entry;
    readregflags_t required_operands;
    logic operands_ready;
    string label;
    entry = CoproInstr[row];
    required_operands = readregflags_t'(entry.resp.register_read);
    operands_ready = (required_operands & available) == required_operands;
    label = $sformatf("row=%0d opcode=%0d available=%0b", row, entry.opcode, available);

    issue_valid = 0;
    tick();
    request.instr = entry.instr | (32'hb5e1_8c80 & ~entry.mask);
    request.id = id_t'(row ^ 3);
    operands.id = request.id;
    operands.rs_valid = available;
    issue_valid = 1;
    if (!operands_ready) begin
      logic accepted_early;
      accepted_early = 0;
      #1;
      repeat (2) begin
        accepted_early |= (issue_ready !== 1'b0);
        tick();
      end
      check(!accepted_early, {label, " issue_ready before required operands"});
      operands.rs_valid |= required_operands;
    end
    wait_ready();
    check(issue_ready === 1'b1, {label, " issue_ready with required operands"});
    if (issue_ready === 1'b1) begin
      check(response.accept === entry.resp.accept, {label, " accept"});
      check(response.writeback === entry.resp.writeback, {label, " writeback"});
      check(response.register_read === required_operands, {label, " register_read"});
      check(opcode === entry.opcode, {label, " decoded opcode"});
      check({hart, id} === {request.hartid, request.id}, {label, " transaction metadata"});
      if (entry.resp.writeback)
        check(destination === request.instr[11:7], {label, " destination register"});
      for (int reg_index = 0; reg_index < Cfg.NrRgprPorts; reg_index++)
        if (required_operands[reg_index])
          check(selected_operands[reg_index] === operands.rs[reg_index], {label, " selected operand"});
    end
    tick();
  endtask

  initial begin
    request = '0;
    operands = '0;
    operands.rs = '{32'h93e7_c521, 32'h570a_86bf};
    repeat (2) tick();
    rst_n = 1;
    for (int row = 0; row < NbInstr; row++)
      for (int available = 0; available < (1 << Cfg.NrRgprPorts); available++)
        test_instruction(row, readregflags_t'(available));

    issue_valid = 0;
    tick();
    request.instr = 32'h0000_707b;
    request.id = '1;
    operands.id = request.id;
    operands.rs_valid = '0;
    issue_valid = 1;
    wait_ready();
    check(issue_ready === 1'b1, "unmatched instruction rejection handshake");
    check(response.accept === 1'b0, "unmatched instruction accept");

    $display("SUMMARY checks=%0d errors=%0d", checks, errors);
    $display("INSTR_DECODER_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
