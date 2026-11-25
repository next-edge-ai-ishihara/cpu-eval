// SPDX-License-Identifier: Apache-2.0
`include "cvxif_types.svh"

module issue_stage_ports_tb;
  import ariane_pkg::*;
  localparam config_pkg::cva6_cfg_t CVA6Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  `include "parent_types.svh"
  typedef `HARTID_T(CVA6Cfg) hartid_t;
  typedef `ID_T(CVA6Cfg) id_t;
  typedef `READREGFLAGS_T(CVA6Cfg) readregflags_t;
  typedef `WRITEREGFLAGS_T(CVA6Cfg) writeregflags_t;
  typedef `X_ISSUE_REQ_T(CVA6Cfg, hartid_t, id_t) x_issue_req_t;
  typedef `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t) x_issue_resp_t;
  typedef `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t) x_register_t;
  typedef `X_COMMIT_T(CVA6Cfg, hartid_t, id_t) x_commit_t;
  typedef logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_t;

  logic clk = 0, reset_n = 0, flush = 0, flush_unissued = 0;
  logic lsu_ready = 0, decode_valid = 0, decode_ack, alu_valid, lsu_valid, sb_full;
  logic [31:0] orig_instr;
  scoreboard_entry_t [0:0] decoded;
  scoreboard_entry_t [CVA6Cfg.NrCommitPorts-1:0] commit_entry;
  logic [CVA6Cfg.NrCommitPorts-1:0] commit_ack = '0;
  fu_data_t [0:0] fu_data;
  logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] wb_id = '0;
  logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.XLEN-1:0] wb_data = '0;
  logic [CVA6Cfg.NrWbPorts-1:0] wb_valid = '0;

  issue_stage #(
      .CVA6Cfg(CVA6Cfg), .bp_resolve_t(bp_resolve_t), .branchpredict_sbe_t(branchpredict_sbe_t),
      .exception_t(exception_t), .fu_data_t(fu_data_t), .scoreboard_entry_t(scoreboard_entry_t),
      .writeback_t(writeback_t), .x_issue_req_t(x_issue_req_t), .x_issue_resp_t(x_issue_resp_t),
      .x_register_t(x_register_t), .x_commit_t(x_commit_t)
  ) dut (
      .clk_i(clk), .rst_ni(reset_n), .sb_full_o(sb_full),
      .flush_unissued_instr_i(flush_unissued), .flush_i(flush), .stall_i(1'b0),
      .decoded_instr_i(decoded), .decoded_instr_i_prev('0), .orig_instr_i(orig_instr),
      .decoded_instr_valid_i(decode_valid), .is_ctrl_flow_i('0), .decoded_instr_ack_o(decode_ack),
      .fu_data_o(fu_data), .flu_ready_i(1'b1), .alu_valid_o(alu_valid), .resolve_branch_i(1'b0),
      .lsu_ready_i(lsu_ready), .lsu_valid_o(lsu_valid),
      .fpu_ready_i(1'b1), .fpu_early_valid_i(1'b0), .xfu_ready_i(1'b1),
      .hart_id_i('0), .x_issue_ready_i(1'b0), .x_issue_resp_i('0), .x_register_ready_i(1'b0),
      .trans_id_i(wb_id), .resolved_branch_i('0), .wbdata_i(wb_data), .ex_ex_i('0),
      .wt_valid_i(wb_valid), .x_we_i(1'b0), .x_rd_i('0),
      .waddr_i('0), .wdata_i('0), .we_gpr_i('0), .we_fpr_i('0),
      .commit_instr_o(commit_entry), .commit_ack_i(commit_ack)
  );

  always #5 clk = ~clk;

  task automatic tick();
    @(negedge clk);
  endtask

  task automatic check(input logic condition, input string message);
    if (condition !== 1'b1) begin
      $display("FAIL: %s", message);
      $finish;
    end
  endtask

  task automatic drive_add(input logic [31:0] pc);
    decoded[0] = '{pc: pc, fu: ALU, op: ADD, rd: 1, result: 1, use_imm: 1, default:'0};
    orig_instr = 32'h00100093;
    decode_valid = 1;
    #1;
  endtask

  task automatic accept_add(input trans_id_t id, input logic [31:0] pc);
    drive_add(pc);
    check(decode_ack, "available ALU instruction was not acknowledged");
    tick();
    decode_valid = 0;
    check(alu_valid && fu_data[0].trans_id == id, "ALU issue or transaction ID incorrect");
  endtask

  task automatic writeback(input int port, input trans_id_t id, input logic [31:0] result);
    wb_id[port] = id;
    wb_data[port] = result;
    wb_valid[port] = 1;
    tick();
    wb_valid = '0;
  endtask

  initial begin
    decoded = '0;
    orig_instr = '0;
    tick();
    reset_n = 1;
    decoded[0] = '{pc: 32'h80000000, fu: LOAD, op: LW, rd: 2, use_imm: 1, default:'0};
    orig_instr = 32'h00002103;
    decode_valid = 1;
    #1;
    check(!decode_ack, "decode acknowledged while the load unit was busy");
    tick();
    check(!lsu_valid, "load instruction dispatched while the load unit was busy");
    lsu_ready = 1;
    #1;
    check(decode_ack, "available load instruction was not acknowledged");
    tick();
    decode_valid = 0;
    check(lsu_valid && fu_data[0].trans_id == 0, "load issue or transaction ID incorrect");

    flush_unissued = 1;
    drive_add(32'h80000004);
    tick();
    $display("OBS unissued_flush=%0b scoreboard_flush=%0b alu_valid=%0b",
             flush_unissued, flush, alu_valid);
    check(!alu_valid, "flush of unissued instructions dispatched a decoded instruction");
    decode_valid = 0;
    flush_unissued = 0;
    accept_add(1, 32'h80000008);

    writeback(FLU_WB, 1, 32'h22);
    check(!commit_entry[0].valid, "younger writeback made the oldest instruction ready");
    writeback(LOAD_WB, 0, 32'h11);
    check(commit_entry[0].valid && commit_entry[0].trans_id == 0 &&
          commit_entry[0].pc == 32'h80000000 && commit_entry[0].result == 32'h11,
          "flush of unissued instructions lost the oldest instruction or its result");
    commit_ack[0] = 1;
    tick();
    commit_ack = '0;
    check(commit_entry[0].valid && commit_entry[0].trans_id == 1 &&
          commit_entry[0].pc == 32'h80000008 && commit_entry[0].result == 32'h22,
          "commit did not advance to the younger instruction and its result");

    flush = 1;
    flush_unissued = 1;
    tick();
    flush = 0;
    flush_unissued = 0;
    check(!commit_entry[0].valid, "scoreboard flush left a completed instruction");
    for (int entry = 0; entry < CVA6Cfg.NR_SB_ENTRIES; entry++) begin
      check(!sb_full, "scoreboard reported full before its last free entry");
      accept_add(trans_id_t'(entry), 32'h80000100 + (entry << 2));
      wb_id[FLU_WB] = trans_id_t'(entry);
      wb_data[FLU_WB] = 1;
      wb_valid[FLU_WB] = 1;
    end
    drive_add(32'h80000200);
    $display("OBS outstanding=%0d scoreboard_full=%0b decode_ack=%0b",
             CVA6Cfg.NR_SB_ENTRIES, sb_full, decode_ack);
    check(sb_full && !decode_ack, "full scoreboard did not backpressure decode");
    tick();
    wb_valid = '0;
    check(!alu_valid, "ALU instruction dispatched with a full scoreboard");
    $display("PASS: issue and scoreboard port contract");
    $finish;
  end
endmodule
