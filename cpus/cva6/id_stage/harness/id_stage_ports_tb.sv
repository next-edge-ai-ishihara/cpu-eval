// SPDX-License-Identifier: Apache-2.0
`include "cvxif_types.svh"

module id_stage_ports_tb;
  import ariane_pkg::*;
  localparam config_pkg::cva6_cfg_t CVA6Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  `include "parent_types.svh"
  typedef `HARTID_T(CVA6Cfg) hartid_t;
  typedef `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t) x_compressed_req_t;
  typedef `X_COMPRESSED_RESP_T(CVA6Cfg) x_compressed_resp_t;

  logic clk = 0, reset_n = 0, flush = 0;
  logic [0:0] fetch_valid = '0, fetch_ready, issue_valid, issue_ack = '0;
  logic [0:0] rvfi_compressed, control_flow;
  logic [0:0][31:0] original_instruction;
  logic [31:0] fetch_pc = '0, fetch_instruction = '0;
  fetch_entry_t [0:0] fetch_entry;
  scoreboard_entry_t [0:0] issue_entry;
  logic compressed_ready = 1, compressed_valid;
  x_compressed_req_t compressed_request;
  x_compressed_resp_t compressed_response = '0;
  assign fetch_entry[0] = '{address: fetch_pc, instruction: fetch_instruction, default:'0};

  id_stage #(
      .CVA6Cfg(CVA6Cfg), .branchpredict_sbe_t(branchpredict_sbe_t),
      .exception_t(exception_t), .fetch_entry_t(fetch_entry_t), .jvt_t(jvt_t),
      .irq_ctrl_t(irq_ctrl_t), .scoreboard_entry_t(scoreboard_entry_t),
      .interrupts_t(interrupts_t), .x_compressed_req_t(x_compressed_req_t),
      .x_compressed_resp_t(x_compressed_resp_t)
  ) dut (
      .clk_i(clk), .rst_ni(reset_n), .flush_i(flush), .debug_req_i(1'b0),
      .fetch_entry_i(fetch_entry), .fetch_entry_valid_i(fetch_valid), .fetch_entry_ready_o(fetch_ready),
      .issue_entry_o(issue_entry), .issue_entry_o_prev(), .orig_instr_o(original_instruction),
      .issue_entry_valid_o(issue_valid), .is_ctrl_flow_o(control_flow), .issue_instr_ack_i(issue_ack),
      .rvfi_is_compressed_o(rvfi_compressed), .priv_lvl_i(riscv::PRIV_LVL_M), .v_i(1'b0),
      .fs_i(riscv::Off), .vfs_i(riscv::Off), .frm_i('0), .vs_i(riscv::Off), .irq_i('0),
      .irq_ctrl_i('0), .debug_mode_i(1'b0), .tvm_i(1'b0), .tw_i(1'b0), .vtw_i(1'b0),
      .tsr_i(1'b0), .hu_i(1'b0), .mcbie_i(riscv::cbie_t'(0)), .scbie_i(riscv::cbie_t'(0)),
      .hcbie_i(riscv::cbie_t'(0)), .mcbcfe_i(1'b0), .scbcfe_i(1'b0), .hcbcfe_i(1'b0),
      .hart_id_i('0), .compressed_ready_i(compressed_ready), .jvt_i('0),
      .compressed_resp_i(compressed_response), .compressed_valid_o(compressed_valid),
      .compressed_req_o(compressed_request), .sdtrig_decoder_action_i('{default:'0}),
      .dcache_req_ports_i('0), .dcache_req_ports_o()
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

  task automatic transfer_fetch(input logic expect_compressed);
    #1;
    for (int cycle = 0; cycle < 16; cycle++) begin
      if (fetch_ready[0]) begin
        if (rvfi_compressed[0] !== expect_compressed)
          $display("instruction=%08x expected=%b observed=%b",
                   fetch_entry[0].instruction, expect_compressed, rvfi_compressed[0]);
        check(rvfi_compressed[0] == expect_compressed, "RVFI compressed attribute at fetch transfer");
        tick();
        fetch_valid = '0;
        return;
      end
      tick();
    end
    check(1'b0, "fetch did not transfer");
  endtask

  task automatic inspect_issue(input logic [31:0] pc, input logic [31:0] instruction,
                               input logic compressed);
    for (int cycle = 0; cycle < 16 && !issue_valid[0]; cycle++) tick();
    check(issue_valid[0], "accepted fetch did not reach issue");
    check(issue_entry[0].pc == pc && issue_entry[0].is_compressed == compressed, "issue PC or compressed attribute");
    check(original_instruction[0] == instruction, "original instruction at valid issue");
  endtask

  initial begin
    tick();
    reset_n = 1;
    check(!issue_valid[0], "reset clears issue valid");

    fetch_pc = 32'h80000100;
    fetch_instruction = 32'hdead0505;  // c.addi a0, 1
    fetch_valid = '1;
    transfer_fetch(1'b1);
    inspect_issue(32'h80000100, 32'h00000505, 1'b1);
    repeat (3) begin
      tick();
      check(issue_valid[0] && issue_entry[0].pc == 32'h80000100 &&
            original_instruction[0] == 32'h00000505, "unacknowledged issue changed");
    end
    issue_ack = '1;
    tick();
    issue_ack = '0;
    check(!issue_valid[0], "acknowledged issue remained valid");

    fetch_pc = 32'h80000102;
    fetch_instruction = 32'h00100593;  // addi a1, x0, 1
    fetch_valid = '1;
    transfer_fetch(1'b0);
    inspect_issue(32'h80000102, 32'h00100593, 1'b0);
    flush = 1;
    tick();
    flush = 0;
    check(!issue_valid[0], "flush did not discard the unacknowledged issue");

    fetch_pc = 32'h80000106;
    fetch_instruction = 32'hbaad0004;  // reserved c.addi4spn with zero immediate
    fetch_valid = '1;
    compressed_ready = 0;
    #1;
    repeat (3) begin
      check(compressed_valid && compressed_request.instr == 16'h0004, "CV-X-IF compressed request while pending");
      check(!fetch_ready[0] && !issue_valid[0], "unresolved CV-X-IF fetch advanced");
      tick();
    end
    compressed_response.accept = 1;
    compressed_response.instr = 32'h00100593;
    compressed_ready = 1;
    transfer_fetch(1'b1);
    inspect_issue(32'h80000106, 32'h00100593, 1'b0);
    $display("PASS: ID transport, flush, and CV-X-IF stall");
    $finish;
  end
endmodule
