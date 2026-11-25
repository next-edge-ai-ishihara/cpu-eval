# Implement `issue_stage`

Implement the complete `issue_stage` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module issue_stage` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

```systemverilog
module issue_stage
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bp_resolve_t = logic,
    parameter type branchpredict_sbe_t = logic,
    parameter type exception_t = logic,
    parameter type fu_data_t = logic,
    parameter type scoreboard_entry_t = logic,
    parameter type writeback_t = logic,
    parameter type x_issue_req_t = logic,
    parameter type x_issue_resp_t = logic,
    parameter type x_register_t = logic,
    parameter type x_commit_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Is scoreboard full - PERF_COUNTERS
    output logic sb_full_o,
    // Prevent from issuing - CONTROLLER
    input logic flush_unissued_instr_i,
    // Flush whole scoreboard - CONTROLLER
    input logic flush_i,
    // Stall inserted by Acc dispatcher - ACC_DISPATCHER
    input logic stall_i,
    // Handshake's data with decode stage - ID_STAGE
    input scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0] decoded_instr_i,
    input scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0] decoded_instr_i_prev,
    // instruction value - ID_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0][31:0] orig_instr_i,
    // Handshake's valid with decode stage - ID_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] decoded_instr_valid_i,
    // Is instruction a control flow instruction - ID_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] is_ctrl_flow_i,
    // Handshake's acknowledge with decode stage - ID_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] decoded_instr_ack_o,
    // rs1 forwarding - EX_STAGE
    output [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs1_forwarding_o,
    // rs2 forwarding - EX_STAGE
    output [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs2_forwarding_o,
    // FU data useful to execute instruction - EX_STAGE
    output fu_data_t [CVA6Cfg.NrIssuePorts-1:0] fu_data_o,
    // ALU to ALU bypass control - EX_STAGE
    output alu_bypass_t alu_bypass_o,
    // Program Counter - EX_STAGE
    output logic [CVA6Cfg.VLEN-1:0] pc_o,
    // Is zcmt instruction - EX_STAGE
    output logic is_zcmt_o,
    // Is compressed instruction - EX_STAGE
    output logic is_compressed_instr_o,
    // Transformed trap instruction - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0][31:0] tinst_o,
    // Fixed Latency Unit is ready - EX_STAGE
    input logic flu_ready_i,
    // ALU output is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] alu_valid_o,
    // AES output is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] aes_valid_o,
    // Branch unit is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] branch_valid_o,
    // Information of branch prediction - EX_STAGE
    output branchpredict_sbe_t branch_predict_o,
    // Signaling that we resolved the branch - EX_STAGE
    input logic resolve_branch_i,
    // Load store unit FU is ready - EX_STAGE
    input logic lsu_ready_i,
    // Load store unit FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] lsu_valid_o,
    // Mult FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] mult_valid_o,
    // FPU FU is ready - EX_STAGE
    input logic fpu_ready_i,
    // FPU FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] fpu_valid_o,
    // FPU fmt field - EX_STAGE
    output logic [1:0] fpu_fmt_o,
    // FPU rm field - EX_STAGE
    output logic [2:0] fpu_rm_o,
    // FPU early valid - EX_STAGE
    input logic fpu_early_valid_i,
    // ALU2 FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] alu2_valid_o,
    // CSR is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] csr_valid_o,
    // CVXIF FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] xfu_valid_o,
    // CVXIF is FU ready - EX_STAGE
    input logic xfu_ready_i,
    // CVXIF offloader instruction value - EX_STAGE
    output logic [31:0] x_off_instr_o,
    // CVA6 Hart ID - SUBSYSTEM
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    // CVXIF Issue interface - EX_STAGE
    input logic x_issue_ready_i,
    // TO_BE_COMPLETED - EX_STAGE
    input x_issue_resp_t x_issue_resp_i,
    // TO_BE_COMPLETED - EX_STAGE
    output logic x_issue_valid_o,
    // TO_BE_COMPLETED - EX_STAGE
    output x_issue_req_t x_issue_req_o,
    // CVXIF Register interface - EX_STAGE
    input logic x_register_ready_i,
    // TO_BE_COMPLETED - EX_STAGE
    output logic x_register_valid_o,
    // TO_BE_COMPLETED - EX_STAGE
    output x_register_t x_register_o,
    // CVXIF Commit interface - EX_STAGE
    output logic x_commit_valid_o,
    // TO_BE_COMPLETED - EX_STAGE
    output x_commit_t x_commit_o,
    // CVXIF Transaction rejected -> instruction is illegal - EX_STAGE
    output logic x_transaction_rejected_o,
    // Issue scoreboard entry - ACC_DISPATCHER
    output scoreboard_entry_t issue_instr_o,
    // TO_BE_COMPLETED - ACC_DISPATCHER
    output logic issue_instr_hs_o,
    // Transaction ID - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_i,
    // Result from branch unit - EX_STAGE
    input bp_resolve_t resolved_branch_i,
    // Results to write back - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.XLEN-1:0] wbdata_i,
    // exception from execute stage or CVXIF - EX_STAGE
    input exception_t [CVA6Cfg.NrWbPorts-1:0] ex_ex_i,
    // Indicates valid results - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0] wt_valid_i,
    // CVXIF write enable - EX_STAGE
    input logic x_we_i,
    // CVXIF destination register - EX_STAGE
    input logic [4:0] x_rd_i,
    // Destination register in register file - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0][4:0] waddr_i,
    // Value to write to register file - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.XLEN-1:0] wdata_i,
    // GPR write enable - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] we_gpr_i,
    // FPR write enable - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] we_fpr_i,
    // Instructions to commit - COMMIT_STAGE
    output scoreboard_entry_t [CVA6Cfg.NrCommitPorts-1:0] commit_instr_o,
    // Instruction is cancelled - COMMIT_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0] commit_drop_o,
    // Commit acknowledge - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] commit_ack_i,
    // Issue stall - PERF_COUNTERS
    output logic stall_issue_o,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] rvfi_issue_pointer_o,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] rvfi_commit_pointer_o,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] rvfi_rs1_o,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] rvfi_rs2_o,
    // Original instruction bits for AES
    output logic [5:0] orig_instr_aes_bits
);
```

## Parent instantiation

### core/cva6.sv

```systemverilog
  issue_stage #(
      .CVA6Cfg(CVA6Cfg),
      .bp_resolve_t(bp_resolve_t),
      .branchpredict_sbe_t(branchpredict_sbe_t),
      .exception_t(exception_t),
      .fu_data_t(fu_data_t),
      .scoreboard_entry_t(scoreboard_entry_t),
      .writeback_t(writeback_t),
      .x_issue_req_t(x_issue_req_t),
      .x_issue_resp_t(x_issue_resp_t),
      .x_register_t(x_register_t),
      .x_commit_t(x_commit_t)
  ) issue_stage_i (
      .clk_i,
      .rst_ni,
      .sb_full_o               (sb_full),
      .flush_unissued_instr_i  (flush_unissued_instr_ctrl_id),
      .flush_i                 (flush_ctrl_id),
      .stall_i                 (stall_acc_id),
      // ID Stage
      .decoded_instr_i         (issue_entry_id_issue),
      .decoded_instr_i_prev    (issue_entry_id_issue_prev),
      .orig_instr_i            (orig_instr_id_issue),
      .decoded_instr_valid_i   (issue_entry_valid_id_issue),
      .is_ctrl_flow_i          (is_ctrl_fow_id_issue),
      .decoded_instr_ack_o     (issue_instr_issue_id),
      // Functional Units
      .rs1_forwarding_o        (rs1_forwarding_id_ex),
      .rs2_forwarding_o        (rs2_forwarding_id_ex),
      .fu_data_o               (fu_data_id_ex),
      .alu_bypass_o            (alu_bypass_id_ex),
      .pc_o                    (pc_id_ex),
      .is_zcmt_o               (zcmt_id_ex),
      .is_compressed_instr_o   (is_compressed_instr_id_ex),
      .tinst_o                 (tinst_ex),
      // fixed latency unit ready
      .flu_ready_i             (flu_ready_ex_id),
      // ALU
      .alu_valid_o             (alu_valid_id_ex),
      .aes_valid_o             (aes_valid_id_ex),
      // Branches and Jumps
      .branch_valid_o          (branch_valid_id_ex),            // branch is valid
      .branch_predict_o        (branch_predict_id_ex),          // branch predict to ex
      .resolve_branch_i        (resolve_branch_ex_id),          // in order to resolve the branch
      // LSU
      .lsu_ready_i             (lsu_ready_ex_id),
      .lsu_valid_o             (lsu_valid_id_ex),
      // Multiplier
      .mult_valid_o            (mult_valid_id_ex),
      // FPU
      .fpu_ready_i             (fpu_ready_ex_id),
      .fpu_valid_o             (fpu_valid_id_ex),
      .fpu_fmt_o               (fpu_fmt_id_ex),
      .fpu_rm_o                (fpu_rm_id_ex),
      .fpu_early_valid_i       (fpu_early_valid_ex_id),
      // ALU2
      .alu2_valid_o            (alu2_valid_id_ex),
      // CSR
      .csr_valid_o             (csr_valid_id_ex),
      // CVXIF
      .xfu_valid_o             (x_issue_valid_id_ex),
      .xfu_ready_i             (x_issue_ready_ex_id),
      .x_off_instr_o           (x_off_instr_id_ex),
      .hart_id_i               (hart_id_i),
      .x_issue_ready_i         (x_issue_ready),
      .x_issue_resp_i          (x_issue_resp),
      .x_issue_valid_o         (x_issue_valid),
      .x_issue_req_o           (x_issue_req),
      .x_register_ready_i      (x_register_ready),
      .x_register_valid_o      (x_register_valid),
      .x_register_o            (x_register),
      .x_commit_valid_o        (x_commit_valid),
      .x_commit_o              (x_commit),
      .x_transaction_rejected_o(x_transaction_rejected),
      // Accelerator
      .issue_instr_o           (issue_instr_id_acc),
      .issue_instr_hs_o        (issue_instr_hs_id_acc),
      // Commit
      .trans_id_i              (trans_id_ex_id),
      .resolved_branch_i       (resolved_branch),
      .wbdata_i                (wbdata_ex_id),
      .ex_ex_i                 (ex_ex_ex_id),
      .wt_valid_i              (wt_valid_ex_id),
      .x_we_i                  (x_we_ex_id),
      .x_rd_i                  (x_rd_ex_id),

      .waddr_i              (waddr_commit_id),
      .wdata_i              (wdata_commit_id),
      .we_gpr_i             (we_gpr_commit_id),
      .we_fpr_i             (we_fpr_commit_id),
      .commit_instr_o       (commit_instr_id_commit),
      .commit_drop_o        (commit_drop_id_commit),
      .commit_ack_i         (commit_ack_commit_id),
      // Performance Counters
      .stall_issue_o        (stall_issue),
      //RVFI
      .rvfi_issue_pointer_o (rvfi_issue_pointer),
      .rvfi_commit_pointer_o(rvfi_commit_pointer),
      .rvfi_rs1_o           (rvfi_rs1),
      .rvfi_rs2_o           (rvfi_rs2),
      .orig_instr_aes_bits  (orig_instr_aes)
  );
```

## Dependency declarations

### core/issue_read_operands.sv

```systemverilog
module issue_read_operands
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type branchpredict_sbe_t = logic,
    parameter type fu_data_t = logic,
    parameter type scoreboard_entry_t = logic,
    parameter type forwarding_t = logic,
    parameter type writeback_t = logic,
    parameter type rs3_len_t = logic,
    parameter type x_issue_req_t = logic,
    parameter type x_issue_resp_t = logic,
    parameter type x_register_t = logic,
    parameter type x_commit_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Prevent from issuing - CONTROLLER
    input logic flush_i,
    // Stall inserted by Acc dispatcher - ACC_DISPATCHER
    input logic stall_i,
    // Entry about the instruction to issue - SCOREBOARD
    input scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0] issue_instr_i,
    input scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0] issue_instr_i_prev,
    // Instruction to issue - SCOREBOARD
    input logic [CVA6Cfg.NrIssuePorts-1:0][31:0] orig_instr_i,
    // Is there an instruction to issue - SCOREBOARD
    input logic [CVA6Cfg.NrIssuePorts-1:0] issue_instr_valid_i,
    // Issue stage acknowledge - SCOREBOARD
    output logic [CVA6Cfg.NrIssuePorts-1:0] issue_ack_o,
    // Forwarding - SCOREBOARD
    input forwarding_t fwd_i,
    // FU data useful to execute instruction - EX_STAGE
    output fu_data_t [CVA6Cfg.NrIssuePorts-1:0] fu_data_o,
    // ALU to ALU bypass control - EX_STAGE
    output alu_bypass_t alu_bypass_o,
    // Unregistered version of fu_data_o.operanda - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs1_forwarding_o,
    // Unregistered version of fu_data_o.operandb - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs2_forwarding_o,
    // Program Counter - EX_STAGE
    output logic [CVA6Cfg.VLEN-1:0] pc_o,
    // Is zcmt - EX_STAGE
    output logic is_zcmt_o,
    // Is compressed instruction - EX_STAGE
    output logic is_compressed_instr_o,
    // Fixed Latency Unit is ready - EX_STAGE
    input logic flu_ready_i,
    // ALU output is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] alu_valid_o,
    // AES output is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] aes_valid_o,
    // Branch unit is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] branch_valid_o,
    // Transformed trap instruction - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0][31:0] tinst_o,
    // Information of branch prediction - EX_STAGE
    output branchpredict_sbe_t branch_predict_o,
    // Load store unit FU is ready - EX_STAGE
    input logic lsu_ready_i,
    // Load store unit FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] lsu_valid_o,
    // Mult FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] mult_valid_o,
    // FPU FU is ready - EX_STAGE
    input logic fpu_ready_i,
    // FPU FU will perform a writeback in the next cycle - EX_STAGE
    input logic fpu_early_valid_i,
    // FPU FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] fpu_valid_o,
    // FPU fmt field - EX_STAGE
    output logic [1:0] fpu_fmt_o,
    // FPU rm field - EX_STAGE
    output logic [2:0] fpu_rm_o,
    // ALU2 FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] alu2_valid_o,
    // CSR is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] csr_valid_o,
    // CVXIF FU is valid - EX_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] cvxif_valid_o,
    // CVXIF is FU ready - EX_STAGE
    input logic cvxif_ready_i,
    // CVXIF offloader instruction value - EX_STAGE
    output logic [31:0] cvxif_off_instr_o,
    // CVA6 Hart ID - SUBSYSTEM
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    // CVXIF Issue interface
    input logic x_issue_ready_i,
    input x_issue_resp_t x_issue_resp_i,
    output logic x_issue_valid_o,
    output x_issue_req_t x_issue_req_o,
    // CVXIF Register interface
    input logic x_register_ready_i,
    output logic x_register_valid_o,
    output x_register_t x_register_o,
    // CVXIF Commit interface
    output logic x_commit_valid_o,
    output x_commit_t x_commit_o,
    // Writeback Handling of CVXIF
    output logic x_transaction_accepted_o,
    output logic x_transaction_rejected_o,
    output logic x_issue_writeback_o,
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] x_id_o,
    // Destination register in the register file - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0][4:0] waddr_i,
    // Value to write to register file - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.XLEN-1:0] wdata_i,
    // GPR write enable - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] we_gpr_i,
    // FPR write enable - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] we_fpr_i,
    // Issue stall - PERF_COUNTERS
    output logic stall_issue_o,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] rvfi_rs1_o,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.XLEN-1:0] rvfi_rs2_o,
    // Original instruction bits for AES
    output logic [5:0] orig_instr_aes_bits
);
```

### core/scoreboard.sv

```systemverilog
module scoreboard #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bp_resolve_t = logic,
    parameter type exception_t = logic,
    parameter type scoreboard_entry_t = logic,
    parameter type forwarding_t = logic,
    parameter type writeback_t = logic,
    parameter type rs3_len_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input  logic                                          clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input  logic                                          rst_ni,
    // Is scoreboard full - PERF_COUNTERS
    output logic                                          sb_full_o,
    // Prevent from issuing - CONTROLLER
    input  logic                                          flush_unissued_instr_i,
    // Flush whole scoreboard - CONTROLLER
    input  logic                                          flush_i,
    // Writeback Handling of CVXIF
    // TO_BE_COMPLETED - ISSUE_READ_OPERANDS
    input  logic                                          x_transaction_accepted_i,
    // TO_BE_COMPLETED - ISSUE_READ_OPERANDS
    input  logic                                          x_issue_writeback_i,
    // TO_BE_COMPLETED - ISSUE_READ_OPERANDS
    input  logic              [CVA6Cfg.TRANS_ID_BITS-1:0] x_id_i,
    // advertise instruction to commit stage, if commit_ack_i is asserted advance the commit pointer
    // Instructions to commit - COMMIT_STAGE
    output scoreboard_entry_t [CVA6Cfg.NrCommitPorts-1:0] commit_instr_o,
    // Instruction is cancelled - COMMIT_STAGE
    output logic              [CVA6Cfg.NrCommitPorts-1:0] commit_drop_o,
    // Commit acknowledge - COMMIT_STAGE
    input  logic              [CVA6Cfg.NrCommitPorts-1:0] commit_ack_i,

    // instruction to put on top of scoreboard e.g.: top pointer
    // we can always put this instruction to the top unless we signal with asserted full_o
    // Handshake's data with decode stage - ID_STAGE
    input  scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0]       decoded_instr_i,
    // instruction value - ID_STAGE
    input  logic              [CVA6Cfg.NrIssuePorts-1:0][31:0] orig_instr_i,
    // Handshake's valid with decode stage - ID_STAGE
    input  logic              [CVA6Cfg.NrIssuePorts-1:0]       decoded_instr_valid_i,
    // Handshake's acknowledge with decode stage - ID_STAGE
    output logic              [CVA6Cfg.NrIssuePorts-1:0]       decoded_instr_ack_o,

    // instruction to issue logic, if issue_instr_valid and issue_ready is asserted, advance the issue pointer
    // Entry about the instruction to issue - ISSUE_READ_OPERANDS
    output scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0]       issue_instr_o,
    // Instruction to issue - ISSUE_READ_OPERANDS
    output logic              [CVA6Cfg.NrIssuePorts-1:0][31:0] orig_instr_o,
    // Is there an instruction to issue - ISSUE_READ_OPERANDS
    output logic              [CVA6Cfg.NrIssuePorts-1:0]       issue_instr_valid_o,
    // Issue stage acknowledge - ISSUE_READ_OPERANDS
    input  logic              [CVA6Cfg.NrIssuePorts-1:0]       issue_ack_i,
    // Forwarding - ISSUE_READ_OPERANDS
    output forwarding_t                                        fwd_o,

    // Result from branch unit - EX_STAGE
    input bp_resolve_t resolved_branch_i,
    // Transaction ID at which to write the result back - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_i,
    // Results to write back - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.XLEN-1:0] wbdata_i,
    // Exception from a functional unit (e.g.: ld/st exception) - EX_STAGE
    input exception_t [CVA6Cfg.NrWbPorts-1:0] ex_i,
    // Indicates valid results - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0] wt_valid_i,
    // Cvxif we for writeback - EX_STAGE
    input logic x_we_i,
    // CVXIF destination register - ISSUE_STAGE
    input logic [4:0] x_rd_i,

    // Issue pointer - RVFI
    output logic [ CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] rvfi_issue_pointer_o,
    // Commit pointer - RVFI
    output logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] rvfi_commit_pointer_o
);
```

## Related source code

### core/scoreboard.sv

```systemverilog
  // this is the FIFO struct of the issue queue
  typedef struct packed {
    logic issued;  // this bit indicates whether we issued this instruction e.g.: if it is valid
    logic cancelled;  // this instruction was cancelled (speculative scoreboard)
    logic is_rd_fpr_flag;  // redundant meta info, added for speed
    scoreboard_entry_t sbe;  // this is the score board entry we will send to ex
  } sb_mem_t;
  sb_mem_t [CVA6Cfg.NR_SB_ENTRIES-1:0] mem_q, mem_n;
  logic [CVA6Cfg.NR_SB_ENTRIES-1:0] still_issued;
// ...
  logic [CVA6Cfg.NrIssuePorts-1:0] num_issue;
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] issue_pointer_n, issue_pointer_q;
  logic [CVA6Cfg.NrIssuePorts:0][CVA6Cfg.TRANS_ID_BITS-1:0] issue_pointer;
// ...
  // Forwarding logic
  writeback_t [CVA6Cfg.NrWbPorts-1:0] wb;
  for (genvar i = 0; i < CVA6Cfg.NrWbPorts; i++) begin
    assign wb[i].valid = wt_valid_i[i];
    assign wb[i].data = wbdata_i[i];
    assign wb[i].ex_valid = ex_i[i].valid;
    assign wb[i].trans_id = trans_id_i[i];
  end

  assign fwd_o.still_issued = still_issued;
  assign fwd_o.issue_pointer = issue_pointer[0];
  assign fwd_o.wb = wb;
  for (genvar i = 0; i < CVA6Cfg.NR_SB_ENTRIES; i++) begin
    assign fwd_o.sbe[i] = mem_q[i].sbe;
  end
```

## Documentation

### docs/design/design-manual/source/cva6_issue_stage.adoc

```text
ISSUE_STAGE issues instructions (1), reorders their results (2) and sends completed instructions in-order to COMMIT_STAGE (3).

(1) ISSUE_STAGE issues instructions in-order.
It makes sure that instructions from ID_STAGE have everything they need to run.
It waits until all requirements are met.
Once an instruction is ready to run, ISSUE_STAGE sends it to EX_STAGE with its operands.

(2) ISSUE_STAGE reorders instructions results.
It gets results of instruction executions out-of-order from EX_STAGE.
ISSUE_STAGE stores these results reordered.

(3) ISSUE_STAGE sends completed instructions in-order to COMMIT_STAGE.
This is where architectural state is modified.

Scoreboard module keeps track of instructions and their results.
Issue_read_operands module contains all the issue logic and the register file.

The module is connected to:

* CONTROLLER module can request to flush the pipeline buffer at the end of ISSUE_STAGE.
  CONTROLLER module can also request to flush the whole Scoreboard.
* ID_STAGE module delivers decoded instructions to ISSUE_STAGE.
* EX_STAGE module gets instructions issued by ISSUE_STAGE to execute them.
  EX_STAGE module also returns results to ISSUE_STAGE.
* COMMIT_STAGE module delivers ISSUE_STAGE clearance to remove the oldest instruction from Scoreboard.
...
ISSUE_STAGE has three functionalities.

(1) ISSUE_STAGE issues instructions.
Instructions from ID_STAGE are sent to Scoreboard module, which forwards them to Issue_read_operands module.
Issue_read_operands queries Scoreboard module for data dependencies (Scoreboard is also able to return forwarded values) and gets the list of busy functional units from EX_STAGE.
Issue_read_operands sends to EX_STAGE the instructions to execute and acknowledges to Scoreboard so that it stores them: the instruction is issued.
Issued instructions are acknowledged to ID_STAGE.
Each of these steps can block its successors.
The flush signal from CONTROLLER module is also sent to Scoreboard module to prevent from issuing.
Instructions are issued in-order: an instruction cannot be issued unless all its predecessors are issued.

(2) ISSUE_STAGE reorders instructions results.
Results from EX_STAGE are sent to Scoreboard module so that they are stored.

(3) ISSUE_STAGE sends completed instructions in-order to COMMIT_STAGE.
The oldest instructions from Scoreboard are exposed to COMMIT_STAGE.
When COMMIT_STAGE acknowledges a commit, the committed instruction is removed from Scoreboard and the register file in Issue_read_operands is updated with the instruction result.
...
Scoreboard contains a FIFO which contains an entry for each issued instruction.
Each entry is removed once the instruction is committed.
Instruction results are inserted into Scoreboard when they are ready.
The FIFO is flushed when requested by CONTROLLER.

Scoreboard is used in all three functionalities of ISSUE_STAGE.

(1) ISSUE_STAGE issues instructions.
Up to {issue-width} instruction(s) can be received from ID_STAGE each cycle.
They are transmitted to Issue_read_operands with incremental transaction IDs which wrap at {NrScoreboardEntries}.
The result buses and Scoreboard entries are also transmitted to Issue_read_operands for it to detect data dependencies and perform operand forwarding.
When Issue_read_operands acknowledges an instruction, it is inserted into the FIFO.

Scoreboard has a capacity of {NrScoreboardEntries} entries.
Instructions which would make Scoreboard overflow are not transmitted to Issue_read_operands (ISSUE_STAGE stalls).

The flush signal from CONTROLLER module removes all entries from the Scoreboard and prevents from issuing.
The transaction ID of the next issued instruction is 0.
...
(2) ISSUE_STAGE reorders instructions results.
Results are returned from functional units in the EX_STAGE to Scoreboard via result buses, with their transaction IDs.
Scoreboard stores this result into the entry associated with this transaction ID.
If an exception is returned, it is stored too.
...
(3) ISSUE_STAGE sends completed instructions in-order to COMMIT_STAGE.
Each of the {commit-width} oldest entry(ies) in Scoreboard are exposed to COMMIT_STAGE, one per commit port.
This makes commit happen in-order.
When COMMIT_STAGE acknowledges on a commit port, the entry is removed from Scoreboard.
```
