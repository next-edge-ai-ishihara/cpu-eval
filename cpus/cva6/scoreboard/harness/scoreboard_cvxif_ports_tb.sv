// SPDX-License-Identifier: Apache-2.0
module scoreboard_cvxif_ports_tb;
  import ariane_pkg::*;
  localparam config_pkg::cva6_cfg_t CVA6Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  `include "parent_types.svh"
  typedef logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_t;

  logic clk = 0, reset_n = 0;
  logic decoded_valid = 0, decoded_ack, issue_valid, issue_ack = 0;
  logic accepted = 0, issue_writeback = 0;
  logic sb_full, commit_ack = 0;
  logic commit_drop;
  trans_id_t accepted_id;
  scoreboard_entry_t [0:0] decoded, issue_entry, commit_entry;
  logic [31:0] instruction;
  forwarding_t forwarding;
  logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] wb_id = '0;
  logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.XLEN-1:0] wb_data = '0;
  logic [CVA6Cfg.NrWbPorts-1:0] wb_valid = '0;
  logic wb_we = 0;
  logic [4:0] wb_rd = '0;

  scoreboard #(
      .CVA6Cfg(CVA6Cfg), .bp_resolve_t(bp_resolve_t), .exception_t(exception_t),
      .scoreboard_entry_t(scoreboard_entry_t), .forwarding_t(forwarding_t),
      .writeback_t(writeback_t), .rs3_len_t(rs3_len_t)
  ) dut (
      .clk_i(clk), .rst_ni(reset_n), .sb_full_o(sb_full), .flush_unissued_instr_i(1'b0),
      .flush_i(1'b0), .x_transaction_accepted_i(accepted), .x_issue_writeback_i(issue_writeback),
      .x_id_i(accepted_id), .commit_instr_o(commit_entry), .commit_drop_o(commit_drop),
      .commit_ack_i(commit_ack), .decoded_instr_i(decoded), .orig_instr_i(instruction),
      .decoded_instr_valid_i(decoded_valid), .decoded_instr_ack_o(decoded_ack),
      .issue_instr_o(issue_entry), .orig_instr_o(), .issue_instr_valid_o(issue_valid),
      .issue_ack_i(issue_ack), .fwd_o(forwarding), .resolved_branch_i('0), .trans_id_i(wb_id),
      .wbdata_i(wb_data), .ex_i('0), .wt_valid_i(wb_valid), .x_we_i(wb_we), .x_rd_i(wb_rd),
      .rvfi_issue_pointer_o(), .rvfi_commit_pointer_o()
  );

  always #5 clk = ~clk;

  task automatic tick();
    @(negedge clk);
  endtask

  task automatic check(input logic condition, input string description);
    if (condition !== 1'b1) begin
      $display("FAIL: %s", description);
      $finish;
    end
  endtask

  task automatic accept_and_complete(
      input logic [31:0] pc, input logic [31:0] word, input logic writes,
      input logic [31:0] value
  );
    logic [4:0] rd;
    trans_id_t id;
    rd = word[11:7];
    decoded[0] = '{pc: pc, fu: CVXIF, op: OFFLOAD, rs1: word[19:15],
                   rs2: word[24:20], rd: rd, default:'0};
    instruction = word;
    decoded_valid = 1;
    #1;
    check(!sb_full && issue_valid, "available CVXIF instruction was not offered");
    id = issue_entry[0].trans_id;
    accepted_id = id;
    issue_writeback = writes;
    accepted = 1;
    issue_ack = 1;
    #1;
    check(decoded_ack, "accepted coprocessor instruction was not acknowledged");
    tick();
    accepted = 0;
    issue_ack = 0;
    decoded_valid = 0;
    #1;
    if (writes) begin
      $display("OBS cvxif_writeback=1 encoded_rd=%0d forwarded_rd=%0d", rd, forwarding.sbe[id].rd);
      check(forwarding.still_issued[id] && forwarding.sbe[id].rd == rd,
            "writeback-enabled coprocessor instruction lost its destination");
    end else begin
      $display("OBS cvxif_writeback=0 encoded_rd=%0d forwarded_rd=%0d", rd, forwarding.sbe[id].rd);
      check(!forwarding.still_issued[id] || forwarding.sbe[id].rd == 5'd0,
            "accepted coprocessor instruction without writeback retained a register dependency");
    end
    check(!commit_entry[0].valid, "accepted coprocessor instruction committed before completion");
    wb_id[X_WB] = id;
    wb_data[X_WB] = value;
    wb_valid[X_WB] = 1;
    wb_rd = writes ? rd : 5'd0;
    wb_we = writes;
    tick();
    wb_valid = '0;
    #1;
    check(commit_entry[0].valid && !commit_drop && commit_entry[0].trans_id == id &&
          commit_entry[0].pc == pc && commit_entry[0].rd == (writes ? rd : 5'd0),
          "completed coprocessor instruction did not preserve its transaction or register decision");
    if (writes) check(commit_entry[0].result == value, "coprocessor writeback result changed");
    commit_ack = 1;
    tick();
    commit_ack = 0;
    #1;
    check(!commit_entry[0].valid, "commit acknowledgement left the completed instruction queued");
  endtask

  initial begin
    accepted_id = '0;
    instruction = '0;
    decoded = '0;
    tick();
    reset_n = 1;
    accept_and_complete(32'h80000000, 32'h000002fb, 0, 0);  // Custom Nop, encoded x5
    accept_and_complete(32'h80000004, 32'h0020937b, 1, 32'h44);  // Custom Add x6,x1,x2
    $display("PASS: CVXIF issue-time register dependency and commit");
    $finish;
  end
endmodule
