# Implement `commit_stage`

Implement the complete `commit_stage` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module commit_stage` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
      NrCommitPorts: unsigned'(1),
// ...
      RVF: bit'(0),
      RVD: bit'(0),
      XF16: bit'(0),
      XF16ALT: bit'(0),
      XF8: bit'(0),
      RVA: bit'(0),
// ...
      RVH: bit'(0),
      RVZCMT: bit'(0),
      RVZCB: bit'(1),
      RVZCMP: bit'(0),
// ...
      RVS: bit'(0),
// ...
      TvalEn: bit'(0),
// ...
      Sdtrig: bit'(0),
      SdtrigMcontrol6: bit'(0),
      SdtrigMcontrol6ExecAddr: bit'(0),
      SdtrigMcontrol6ExecData: bit'(0),
      SdtrigMcontrol6Store: bit'(0),
      SdtrigMcontrol6LoadAddr: bit'(0),
      SdtrigMcontrol6LoadData: bit'(0),
      SdtrigIcount: bit'(0),
      SdtrigEtrigger: bit'(0),
      SdtrigItrigger: bit'(0),
// ...
      DCacheType: config_pkg::HPDCACHE_WT,
```

### core/include/build_config_pkg.sv

```systemverilog
    bit FpPresent = CVA6Cfg.RVF | CVA6Cfg.RVD | CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8;
```

## Package and imports

### core/include/ariane_pkg.sv

```systemverilog
  typedef enum logic [3:0] {
    NONE,       // 0
    LOAD,       // 1
    STORE,      // 2
    ALU,        // 3
    CTRL_FLOW,  // 4
    MULT,       // 5
    CSR,        // 6
    FPU,        // 7
    FPU_VEC,    // 8
    CVXIF,      // 9
    ACCEL,      // 10
    AES         // 11
  } fu_t;
// ...
  typedef enum logic [7:0] {  // basic ALU op
    ADD,
// ...
    // CSR functions
    MRET,
    SRET,
    DRET,
    ECALL,
    WFI,
    FENCE,
    FENCE_I,
    SFENCE_VMA,
    HFENCE_VVMA,
    HFENCE_GVMA,
    CSR_WRITE,
    CSR_READ,
    CSR_SET,
    CSR_CLEAR,
// ...
  } fu_op;
// ...
  function automatic logic is_amo(fu_op op);
    case (op) inside
      [AMO_LRW : AMO_MINDU]: begin
        return 1'b1;
      end
      default: return 1'b0;
    endcase
  endfunction
// ...
  // AMO response coming from cache.
  typedef struct packed {
    logic        ack;     // response is valid
    logic [63:0] result;  // sign-extended, result
  } amo_resp_t;
```

## Module declaration

```systemverilog
module commit_stage
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type exception_t = logic,
    parameter type scoreboard_entry_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Request to halt the core - CONTROLLER
    input logic halt_i,
    // request to flush dcache, also flush the pipeline - CACHE
    input logic flush_dcache_i,
    // TO_BE_COMPLETED - EX_STAGE
    output exception_t exception_o,
    // Mark the F state as dirty - CSR_REGFILE
    output logic dirty_fp_state_o,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic single_step_i,
    // The instruction we want to commit - ISSUE_STAGE
    input scoreboard_entry_t [CVA6Cfg.NrCommitPorts-1:0] commit_instr_i,
    // The instruction is cancelled - ISSUE_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] commit_drop_i,
    // Acknowledge that we are indeed committing - ISSUE_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0] commit_ack_o,
    // Acknowledge that we are indeed committing - CSR_REGFILE
    output logic [CVA6Cfg.NrCommitPorts-1:0] commit_macro_ack_o,
    // Register file write address - ISSUE_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0][4:0] waddr_o,
    // Register file write data - ISSUE_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.XLEN-1:0] wdata_o,
    // Register file write enable - ISSUE_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0] we_gpr_o,
    // Floating point register enable - ISSUE_STAGE
    output logic [CVA6Cfg.NrCommitPorts-1:0] we_fpr_o,
    // Result of AMO operation - CACHE
    input amo_resp_t amo_resp_i,
    // TO_BE_COMPLETED - FRONTEND_CSR_REGFILE
    output logic [CVA6Cfg.VLEN-1:0] pc_o,
    // Decoded CSR operation - CSR_REGFILE
    output fu_op csr_op_o,
    // Data to write to CSR - CSR_REGFILE
    output logic [CVA6Cfg.XLEN-1:0] csr_wdata_o,
    // Data to read from CSR - CSR_REGFILE
    input logic [CVA6Cfg.XLEN-1:0] csr_rdata_i,
    // Write the fflags CSR - CSR_REGFILE
    output logic csr_write_fflags_o,
    // Exception or interrupt occurred in CSR stage (the same as commit) - CSR_REGFILE
    input exception_t csr_exception_i,
    // Commit the pending store - EX_STAGE
    output logic commit_lsu_o,
    // Commit buffer of LSU is ready - EX_STAGE
    input logic commit_lsu_ready_i,
    // Transaction id of first commit port - ID_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] commit_tran_id_o,
    // Valid AMO in commit stage - EX_STAGE
    output logic amo_valid_commit_o,
    // No store is pending - EX_STAGE
    input logic no_st_pending_i,
    // Commit the pending CSR instruction - EX_STAGE
    output logic commit_csr_o,
    // Flush I$ and pipeline - CONTROLLER
    output logic fence_i_o,
    // Flush D$ and pipeline - CONTROLLER
    output logic fence_o,
    // Request a pipeline flush - CONTROLLER
    output logic flush_commit_o,
    // Flush TLBs and pipeline - CONTROLLER
    output logic sfence_vma_o,
    // TO_BE_COMPLETED - CONTROLLER
    output logic hfence_vvma_o,
    // TO_BE_COMPLETED - CONTROLLER
    output logic hfence_gvma_o,
    // Shared TLB is still processing a multi-cycle flush
    input logic shared_tlb_flush_busy_i,
    // Trigger module
    input logic sdtrig_commit_icount_valid_i,
    input logic [$clog2(CVA6Cfg.NrCommitPorts)-1:0] sdtrig_commit_icount_nr_instr_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_commit_action_i,
    input logic sdtrig_commit_std_exception_valid_i
);
```

## Parent instantiation

### core/cva6.sv

```systemverilog
    parameter type exception_t = struct packed {
      logic [CVA6Cfg.XLEN-1:0] cause;  // cause of exception
      logic [CVA6Cfg.XLEN-1:0] tval;  // additional information of causing exception (e.g.: instruction causing it),
      // address of LD/ST fault
      logic [CVA6Cfg.GPLEN-1:0] tval2;  // additional information when the causing exception in a guest exception
      logic [31:0] tinst;  // transformed instruction information
      logic gva;  // signals when a guest virtual address is written to tval
      logic valid;
      //timing of exception, timing = 0 : break immediately or timing = 1 break immediatemy AFTER (let current instruction commit but only this one)
      logic timing;
    },
// ...
    // ID/EX/WB Stage
    localparam type scoreboard_entry_t = struct packed {
      logic [CVA6Cfg.VLEN-1:0] pc;  // PC of instruction
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;      // this can potentially be simplified, we could index the scoreboard entry
      // with the transaction id in any case make the width more generic
      fu_t fu;  // functional unit to use
      fu_op op;  // operation to perform in each functional unit
      logic [REG_ADDR_SIZE-1:0] rs1;  // register source address 1
      logic [REG_ADDR_SIZE-1:0] rs2;  // register source address 2
      logic [REG_ADDR_SIZE-1:0] rd;  // register destination address
      logic [CVA6Cfg.XLEN-1:0] result;  // for unfinished instructions this field also holds the immediate,
      // for unfinished floating-point that are partly encoded in rs2, this field also holds rs2
      // for unfinished floating-point fused operations (FMADD, FMSUB, FNMADD, FNMSUB)
      // this field holds the address of the third operand from the floating-point register file
      logic valid;  // is the result valid
      logic use_imm;  // should we use the immediate as operand b?
      logic use_zimm;  // use zimm as operand a
      logic use_pc;  // set if we need to use the PC as operand a, PC from exception
      exception_t ex;  // exception has occurred
      branchpredict_sbe_t bp;  // branch predict scoreboard data structure
      logic                     is_compressed; // signals a compressed instructions, we need this information at the commit stage if
                                               // we want jump accordingly e.g.: +4, +2
      logic is_macro_instr;  // is an instruction executed as predefined sequence of instructions called macro definition
      logic is_last_macro_instr;  // is last decoded 32bit instruction of macro definition
      logic is_double_rd_macro_instr;  // is double move decoded 32bit instruction of macro definition
      logic vfp;  // is this a vector floating-point instruction?
      logic is_zcmt;  //is a zcmt instruction
    },
// ...
  commit_stage #(
      .CVA6Cfg(CVA6Cfg),
      .exception_t(exception_t),
      .scoreboard_entry_t(scoreboard_entry_t)
  ) commit_stage_i (
      .clk_i,
      .rst_ni,
      .halt_i                             (halt_ctrl),
      .flush_dcache_i                     (dcache_flush_ctrl_cache),
      .exception_o                        (ex_commit),
      .dirty_fp_state_o                   (dirty_fp_state),
      .single_step_i                      (single_step_csr_commit || single_step_acc_commit),
      .commit_instr_i                     (commit_instr_id_commit),
      .commit_drop_i                      (commit_drop_id_commit),
      .commit_ack_o                       (commit_ack_commit_id),
      .commit_macro_ack_o                 (commit_macro_ack),
      .waddr_o                            (waddr_commit_id),
      .wdata_o                            (wdata_commit_id),
      .we_gpr_o                           (we_gpr_commit_id),
      .we_fpr_o                           (we_fpr_commit_id),
      .amo_resp_i                         (amo_resp),
      .pc_o                               (pc_commit),
      .csr_op_o                           (csr_op_commit_csr),
      .csr_wdata_o                        (csr_wdata_commit_csr),
      .csr_rdata_i                        (csr_rdata_csr_commit),
      .csr_write_fflags_o                 (csr_write_fflags_commit_cs),
      .csr_exception_i                    (csr_exception_csr_commit),
      .commit_lsu_o                       (lsu_commit_commit_ex),
      .commit_lsu_ready_i                 (lsu_commit_ready_ex_commit),
      .commit_tran_id_o                   (lsu_commit_trans_id),
      .amo_valid_commit_o                 (amo_valid_commit),
      .no_st_pending_i                    (no_st_pending_commit),
      .shared_tlb_flush_busy_i            (shared_tlb_flush_busy_ex),
      .commit_csr_o                       (csr_commit_commit_ex),
      .fence_i_o                          (fence_i_commit_controller),
      .fence_o                            (fence_commit_controller),
      .flush_commit_o                     (flush_commit),
      .sfence_vma_o                       (sfence_vma_commit_controller),
      .hfence_vvma_o                      (hfence_vvma_commit_controller),
      .hfence_gvma_o                      (hfence_gvma_commit_controller),
      .sdtrig_commit_std_exception_valid_i(sdtrig_commit_std_exception_valid),
      .sdtrig_commit_icount_valid_i       (sdtrig_commit_icount_valid),
      .sdtrig_commit_action_i             (sdtrig_commit_action),
      .sdtrig_commit_icount_nr_instr_i    (sdtrig_commit_icount_nr_instr)
  );

  assign commit_ack = commit_macro_ack & ~commit_drop_id_commit;
```

## Documentation

### docs/design/design-manual/source/cva6_commit_stage.adoc

```text
The COMMIT_STAGE module implements the commit stage, which is the last
stage in the processor’s pipeline. For the instructions for which the
execution is completed, it updates the architectural state: writing CSR
registers, committing stores and writing back data to the register file.
The commit stage controls the stalling and the flushing of the
processor.

The commit stage also manages the exceptions. An exception can occur
during the first four pipeline stages (PCgen cannot generate an
exception) or happen in commit stage, coming from the CSR_REGFILE or
from an interrupt. Exceptions are precise: they are considered during
the commit only and associated with the related instruction.
```

### docs/03_cva6_design/commit_stage.rst

```text
We can distinguish two categories of retiring instructions. The first
category just write the architectural register file. The second might as
well write the register file but needs some further business logic to
happen. At the time of this writing the only two places where this is
necessary it the store unit where the commit stage needs to tell the
store unit to actually commit the store to memory and the CSR buffer
which needs to be freed as soon as the corresponding CSR instruction
retires.
...
Furthermore commit stage controls the overall stalling of the processor.
If the halt signal is asserted it will not commit any new instruction
which will generate back-pressure and eventually stall the pipeline.
Commit stage also communicates heavily with the controller to execute
fence instructions (cache flushes) and other pipeline re-sets.
```
