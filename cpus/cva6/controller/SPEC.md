# Implement `controller`

Implement the complete `controller` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module controller` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam config_pkg::cva6_user_cfg_t cva6_cfg = '{
// ...
      RVA: bit'(0),
// ...
      RVH: bit'(0),
// ...
      RVS: bit'(0),
      RVU: bit'(0),
// ...
      DebugEn: bit'(0),
// ...
      DcacheFlushOnFence: bit'(0),
      DcacheFlushOnFenceI: bit'(0),
```

## Module declaration

```systemverilog
module controller
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bp_resolve_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Virtualization mode - CSR_REGFILE
    input logic v_i,
    // Set PC om PC Gen - FRONTEND
    output logic set_pc_commit_o,
    // Flush the IF stage - FRONTEND
    output logic flush_if_o,
    // Flush un-issued instructions of the scoreboard - FRONTEND
    output logic flush_unissued_instr_o,
    // Flush ID stage - ID_STAGE
    output logic flush_id_o,
    // Flush EX stage - EX_STAGE
    output logic flush_ex_o,
    // Flush branch predictors - FRONTEND
    output logic flush_bp_o,
    // Flush ICache - CACHE
    output logic flush_icache_o,
    // Flush DCache - CACHE
    output logic flush_dcache_o,
    // Acknowledge the whole DCache Flush - CACHE
    input logic flush_dcache_ack_i,
    // Flush TLBs - EX_STAGE
    output logic flush_tlb_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic flush_tlb_vvma_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic flush_tlb_gvma_o,
    // Halt request from CSR (WFI instruction) - CSR_REGFILE
    input logic halt_csr_i,
    // Halt request from accelerator dispatcher - ACC_DISPATCHER
    input logic halt_acc_i,
    // Halt frontend during fence.i to prevent fetching stale instructions
    output logic halt_frontend_o,
    // Halt signal to commit stage - COMMIT_STAGE
    output logic halt_o,
    // Return from exception - CSR_REGFILE
    input logic eret_i,
    // We got an exception, flush the pipeline - FRONTEND
    input logic ex_valid_i,
    // set the debug pc from CSR - FRONTEND
    input logic set_debug_pc_i,
    // We got a resolved branch, check if we need to flush the front-end - EX_STAGE
    input bp_resolve_t resolved_branch_i,
    // We got an instruction which altered the CSR, flush the pipeline - CSR_REGFILE
    input logic flush_csr_i,
    // fence.i in - ACC_DISPATCH
    input logic fence_i_i,
    // fence in - ACC_DISPATCH
    input logic fence_i,
    // We got an instruction to flush the TLBs and pipeline - COMMIT_STAGE
    input logic sfence_vma_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic hfence_vvma_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic hfence_gvma_i,
    // Flush request from commit stage - COMMIT_STAGE
    input logic flush_commit_i,
    // Flush request from accelerator - ACC_DISPATCHER
    input logic flush_acc_i
);
```

## Parent instantiation

### core/cva6.sv

```systemverilog
    // branch-predict
    // this is the struct we get back from ex stage and we will use it to update
    // all the necessary data structures
    // bp_resolve_t
    localparam type bp_resolve_t = struct packed {
      logic                    valid;           // prediction with all its values is valid
      logic [CVA6Cfg.VLEN-1:0] pc;              // PC of predict or mis-predict
      logic [CVA6Cfg.VLEN-1:0] target_address;  // target address at which to jump, or not
      logic                    is_mispredict;   // set if this was a mis-predict
      logic                    is_taken;        // branch is taken
      cf_t                     cf_type;         // Type of control flow change
    },
// ...
  ) i_frontend (
      .clk_i,
      .rst_ni,
      .boot_addr_i        (boot_addr_i[CVA6Cfg.VLEN-1:0]),
      .flush_bp_i         ((CVA6Cfg.RVU || CVA6Cfg.RVS) ? flush_ctrl_bp : 1'b0),
      // below line is not entirely correct
      .flush_i            (flush_ctrl_if),
      .halt_i             (halt_ctrl),
      .halt_frontend_i    (halt_frontend),
      .set_pc_commit_i    (set_pc_ctrl_pcgen),
// ...
  ) ex_stage_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .debug_mode_i(debug_mode),
      .flush_i(flush_ctrl_ex),
      .rs1_forwarding_i(rs1_forwarding_id_ex),
// ...
  controller #(
      .CVA6Cfg(CVA6Cfg),
      .bp_resolve_t(bp_resolve_t)
  ) controller_i (
      .clk_i,
      .rst_ni,
      // virtualization mode
      .v_i                   (v),
      // flush ports
      .set_pc_commit_o       (set_pc_ctrl_pcgen),
      .flush_if_o            (flush_ctrl_if),
      .flush_unissued_instr_o(flush_unissued_instr_ctrl_id),
      .flush_id_o            (flush_ctrl_id),
      .flush_ex_o            (flush_ctrl_ex),
      .flush_bp_o            (flush_ctrl_bp),
      .flush_icache_o        (icache_flush_ctrl_cache),
      .flush_dcache_o        (dcache_flush_ctrl_cache),
      .flush_dcache_ack_i    (dcache_flush_ack_cache_ctrl),
      .flush_tlb_o           (flush_tlb_ctrl_ex),
      .flush_tlb_vvma_o      (flush_tlb_vvma_ctrl_ex),
      .flush_tlb_gvma_o      (flush_tlb_gvma_ctrl_ex),
      .halt_csr_i            (halt_csr_ctrl),
      .halt_acc_i            (halt_acc_ctrl),
      .halt_frontend_o       (halt_frontend),
      .halt_o                (halt_ctrl),
      // control ports
      .eret_i                (eret),
      .ex_valid_i            (ex_commit.valid),
      .set_debug_pc_i        (set_debug_pc),
      .resolved_branch_i     (resolved_branch),
      .flush_csr_i           (flush_csr_ctrl),
      .fence_i_i             (fence_i_commit_controller),
      .fence_i               (fence_commit_controller),
      .sfence_vma_i          (sfence_vma_commit_controller),
      .hfence_vvma_i         (hfence_vvma_commit_controller),
      .hfence_gvma_i         (hfence_gvma_commit_controller),
      .flush_commit_i        (flush_commit),
      .flush_acc_i           (flush_acc)
  );
```

## Related source code

### core/branch_unit.sv

```systemverilog
    resolve_branch_o = 1'b0;
    resolved_branch_o.target_address = {CVA6Cfg.VLEN{1'b0}};
    resolved_branch_o.is_taken = 1'b0;
    resolved_branch_o.valid = branch_valid_i;
    resolved_branch_o.is_mispredict = 1'b0;
    resolved_branch_o.cf_type = branch_predict_i.cf;
    // calculate next PC, depending on whether the instruction is compressed or not this may be different
    // TODO(zarubaf): We already calculate this a couple of times, maybe re-use?
    next_pc                          = pc_i + ((is_compressed_instr_i) ? {{CVA6Cfg.VLEN-2{1'b0}}, 2'h2} : {{CVA6Cfg.VLEN-3{1'b0}}, 3'h4});
    // calculate target address simple 64 bit addition
    target_address = $unsigned($signed(jump_base) + $signed(fu_data_i.imm[CVA6Cfg.VLEN-1:0]));
    // on a JALR we are supposed to reset the LSB to 0 (according to the specification)
    if (fu_data_i.operation == ariane_pkg::JALR) target_address[0] = 1'b0;
    // we need to put the branch target address into rd, this is the result of this unit
    branch_result_o = next_pc;
    resolved_branch_o.pc = pc_i;
    // There are only three sources of mispredicts:
    // 1. Branches
    // 2. Jumps to register addresses
    // 3. Zcmt instructions
    if (branch_valid_i) begin
      // write target address which goes to PC Gen or select target address if zcmt
      resolved_branch_o.target_address = (branch_comp_res_i) ? target_address : next_pc;
      resolved_branch_o.is_taken = branch_comp_res_i;
      if (CVA6Cfg.RVZCMT) begin
        if (is_zcmt_i) begin
          // Unconditional jump handling
          resolved_branch_o.is_mispredict = 1'b1;  // miss prediction for ZCMT 
          resolved_branch_o.cf_type = ariane_pkg::JumpR;
        end
      end
      // check the outcome of the branch speculation
      if (ariane_pkg::op_is_branch(fu_data_i.operation)) begin
        // Set the `cf_type` of the output as `branch`, this will update the BHT.
        resolved_branch_o.cf_type = ariane_pkg::Branch;
        // If the ALU comparison does not agree with the BHT prediction set the resolution as mispredicted.
        resolved_branch_o.is_mispredict  = branch_comp_res_i != (branch_predict_i.cf == ariane_pkg::Branch);
      end
      if (fu_data_i.operation == ariane_pkg::JALR
          // check if the address of the jump register is correct and that we actually predicted
          && (branch_predict_i.cf == ariane_pkg::NoCF || target_address != branch_predict_i.predict_address)) begin
        resolved_branch_o.is_mispredict = 1'b1;
        // update BTB only if this wasn't a return
        if (branch_predict_i.cf != ariane_pkg::Return)
          resolved_branch_o.cf_type = ariane_pkg::JumpR;
      end
      // to resolve the branch in ID
      resolve_branch_o = 1'b1;
```

### core/commit_stage.sv

```systemverilog
        // FENCE.I Logic
        // ------------------
        // fence.i is idempotent so we can safely re-execute it after returning
        // from interrupt service routine
        // Fence synchronizes data and instruction streams. That means that we need to flush the private icache
        // and the private dcache. This is the most expensive instruction.
        if (commit_instr_i[0].op == FENCE_I || (flush_dcache_i && CVA6Cfg.DCacheType == config_pkg::WB && commit_instr_i[0].fu != STORE)) begin
          if (!commit_drop_i[0]) begin
            commit_ack_o[0] = no_st_pending_i;
            // tell the controller to flush the I$
            fence_i_o = no_st_pending_i;
          end
        end
        // ------------------
        // FENCE Logic
        // ------------------
        // fence is idempotent so we can safely re-execute it after returning
        // from interrupt service routine
        if (commit_instr_i[0].op == FENCE) begin
          if (!commit_drop_i[0]) begin
            commit_ack_o[0] = no_st_pending_i;
            // tell the controller to flush the D$
            fence_o = no_st_pending_i;
          end
```

### core/frontend/frontend.sv

```systemverilog
  assign is_mispredict = resolved_branch_i.valid & resolved_branch_i.is_mispredict;

  // Cache interface
  // Gate ICache requests and NPC updates during fence.i
  assign icache_dreq_o.req = instr_queue_ready & ~halt_frontend_i;
  assign if_ready = icache_dreq_i.ready & instr_queue_ready & ~halt_frontend_i;
  // We need to flush the cache pipeline if:
  // 1. We mispredicted
  // 2. Want to flush the whole processor front-end
  // 3. Need to replay an instruction because the fetch-fifo was full
  assign icache_dreq_o.kill_s1 = is_mispredict | flush_i | replay;
  // if we have a valid branch-prediction we need to only kill the last cache request
  // also if we killed the first stage we also need to kill the second stage (inclusive flush)
  assign icache_dreq_o.kill_s2 = icache_dreq_o.kill_s1 | bp_valid;
// ...
    if (ex_valid_i) begin
      npc_d = trap_vector_base_i;
    end
    // 6. Pipeline Flush because of CSR side effects
    // On a pipeline flush start fetching from the next address
    // of the instruction in the commit stage
    // we either came here from a flush request of a CSR instruction or AMO,
    // so as CSR or AMO instructions do not exist in a compressed form
    // we can unconditionally do PC + 4 here
    // or if the commit stage is halted, just take the current pc of the
    // instruction in the commit stage
    // TODO(zarubaf) This adder can at least be merged with the one in the csr_regfile stage
    if (set_pc_commit_i) begin
      npc_d = pc_commit_i + (halt_i ? '0 : {{CVA6Cfg.VLEN - 3{1'b0}}, 3'b100});
    end
```

### core/issue_stage.sv

```systemverilog
    // Is scoreboard full - PERF_COUNTERS
    output logic sb_full_o,
    // Prevent from issuing - CONTROLLER
    input logic flush_unissued_instr_i,
    // Flush whole scoreboard - CONTROLLER
    input logic flush_i,
    // Stall inserted by Acc dispatcher - ACC_DISPATCHER
    input logic stall_i,
```

### core/scoreboard.sv

```systemverilog
  // maintain a FIFO with issued instructions
  // keep track of all issued instructions
  always_comb begin : issue_fifo
    // default assignment
    mem_n     = mem_q;
    num_issue = '0;

    // if we got an acknowledge from the issue stage, put this scoreboard entry in the queue
    for (int unsigned i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
      if (decoded_instr_valid_i[i] && decoded_instr_ack_o[i] && !flush_unissued_instr_i) begin
        // the decoded instruction we put in there is valid (1st bit)
        // increase the issue counter and advance issue pointer
        num_issue += 'd1;
        mem_n[issue_pointer[i]] = '{
            issued: 1'b1,
            cancelled: 1'b0,
            is_rd_fpr_flag: CVA6Cfg.FpPresent && ariane_pkg::is_rd_fpr(decoded_instr_i[i].op),
            sbe: decoded_instr_i[i]
        };
// ...
    // ------
    // Flush
    // ------
    if (flush_i) begin
      for (int unsigned i = 0; i < CVA6Cfg.NR_SB_ENTRIES; i++) begin
        // set all valid flags for all entries to zero
        mem_n[i].issued       = 1'b0;
        mem_n[i].cancelled    = 1'b0;
        mem_n[i].sbe.valid    = 1'b0;
        mem_n[i].sbe.ex.valid = 1'b0;
```

### core/id_stage.sv

```systemverilog
      if (flush_i) begin
        issue_n[0].valid = 1'b0;
        issue_n[1].valid = 1'b0;
      end
```

### core/acc_dispatcher.sv

```systemverilog
  // On a store barrier (i.e. any barrier that requires preceding stores to complete
  // before continuing execution), halt execution while there are pending stores in
  // the accelerator pipeline.
  logic wait_acc_store_d, wait_acc_store_q;
  `FF(wait_acc_store_q, wait_acc_store_d, '0)

  // Set on store barrier. Clear when no store is pending.
  assign wait_acc_store_d = (wait_acc_store_q | commit_st_barrier_i) & acc_resp_i.acc_resp.store_pending;
  assign ctrl_halt_o = wait_acc_store_q;
// ...
  /**************************
   * Tie Off Unused Signals *
   **************************/

  assign acc_stall_st_pending_o = 1'b0;
  assign flush_pipeline_o       = 1'b0;
  assign single_step_o          = 1'b0;
```

### core/csr_regfile.sv

```systemverilog
  // -------------------
  // Wait for Interrupt
  // -------------------
  always_comb begin : wfi_ctrl
    // wait for interrupt register
    wfi_d = wfi_q;
    // if there is any (enabled) interrupt pending un-stall the core
    // also un-stall if we want to enter debug mode
    if (|(mip_q & mie_q) || (CVA6Cfg.DebugEn && debug_req_i) || irq_i[1]) begin
      wfi_d = 1'b0;
      // or alternatively if there is no exception pending and we are not in debug mode wait here
      // for the interrupt
    end else if (((CVA6Cfg.DebugEn && !debug_mode_q) && csr_op_i == WFI && !ex_i.valid) || (!CVA6Cfg.DebugEn && csr_op_i == WFI && !ex_i.valid)) begin
      wfi_d = 1'b1;
    end
  end
```

### core/ex_stage.sv

```systemverilog
  // 3. CSR (sequential)
  csr_buffer #(
      .CVA6Cfg  (CVA6Cfg),
      .fu_data_t(fu_data_t)
  ) csr_buffer_i (
      .clk_i,
      .rst_ni,
      .flush_i,
      .fu_data_i   (one_cycle_data),
      .csr_valid_i (|csr_valid_i),
      .csr_ready_o (csr_ready),
      .csr_result_o(csr_result),
      .csr_commit_i,
      .csr_addr_o
  );
```

### core/cache_subsystem/cva6_icache.sv

```systemverilog
  always_comb begin : p_fsm
    // default assignment
    state_d = state_q;
    cache_en_d   = cache_en_q & en_i;// disabling the cache is always possible, enable needs to go via flush
    flush_en = 1'b0;
    cmp_en_d = 1'b0;
    cache_rden = 1'b0;
    cache_wren = 1'b0;
    inv_en = 1'b0;
    flush_d = flush_q | flush_i;  // register incoming flush
```

## Documentation

### docs/03_cva6_design/pcgen_stage.md

```markdown
The next PC can originate from the following sources (listed in order of
precedence):

1.  **Default assignment**: The default assignment is to fetch PC + 4.
    PC Gen always fetches on a word boundary (32-bit). Compressed
    instructions are handled in a later pipeline step.

2.  **Branch Predict**: If the BHT and BTB predict a branch on a certain
    PC, PC Gen sets the next PC to the predicted address and also
    informs the IF stage that it performed a prediction on the PC. This
    is needed in various places further down the pipeline (for example
    to correct prediction). Branch information which is passed down the
    pipeline is encapsulated in a structure called `branchpredict_sbe_t`.
    In contrast to branch prediction information which is passed up the
    pipeline which is just called `bp_resolve_t`. This is used for
    corrective actions (see next bullet point). This naming convention
    should make it easy to detect the flow of branch information in the source code.

3.  **Control flow change request**: A control flow change request
    occurs from the fact that the branch predictor mis-predicted. This
    can either be a 'real' mis-prediction or a branch which was not
    recognized as one. In any case we need to correct our action and
    start fetching from the correct address.

4.  **Return from environment call**: A return from an environment call
    performs corrective action of the PC in terms of setting the
    successive PC to the one stored in the `[m|s]epc` register.

5.  **Exception/Interrupt**: If an exception (or interrupt, which is in
    the context of RISC-V systems quite similar) occurs PC Gen will
    generate the next PC as part of the trap vector base address. The
    trap vector base address can be different depending on whether the
    exception traps to S-Mode or M-Mode (user mode exceptions are
    currently not supported). It is the purpose of the CSR Unit to
    figure out where to trap to and present the correct address to PC Gen.

6.  **Pipeline Flush because of CSR side effects**: When a CSR
    with side-effects gets written we need to flush the whole pipeline
    and start fetching from the next instruction again in order to take
    the up-dated information into account (for example virtual memory base pointer changes).

7.  **Debug**: Debug has the highest order of precedence as it can
    interrupt any control flow requests. It also the only source of
    control flow change which can actually happen simultaneously to any
    other of the forced control flow changes. The debug unit reports the
    request to change the PC and the PC which the CPU should change to.

This unit also takes care of a signal called `fetch_enable` which
purpose is to prevent fetching if not asserted. Also note that no
flushing takes place in this unit. All the flush information is
distributed by the controller. Actually the controller's only purpose is
to flush different pipeline stages.
```

### docs/03_cva6_design/commit_stage.rst

```rst
Furthermore commit stage controls the overall stalling of the processor.
If the halt signal is asserted it will not commit any new instruction
which will generate back-pressure and eventually stall the pipeline.
Commit stage also communicates heavily with the controller to execute
fence instructions (cache flushes) and other pipeline re-sets.
```
