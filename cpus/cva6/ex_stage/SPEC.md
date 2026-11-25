# Implement `ex_stage`

Implement the complete `ex_stage` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ex_stage` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv32a60x_config_pkg.sv`

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
  localparam config_pkg::cva6_user_cfg_t cva6_cfg = '{
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(32),
      FpgaEn: bit'(0),
      FpgaAlteraEn: bit'(0),
      TechnoCut: bit'(1),
      SuperscalarEn: bit'(0),
// ...
      RVF: bit'(0),
      RVD: bit'(0),
      XF16: bit'(0),
      XF16ALT: bit'(0),
      XF8: bit'(0),
      RVA: bit'(0),
      RVB: bit'(1),
      ZKN: bit'(0),
      RVV: bit'(0),
      RVC: bit'(1),
      RVH: bit'(0),
      RVZCMT: bit'(0),
      RVZCB: bit'(1),
      RVZCMP: bit'(0),
      XFVec: bit'(0),
      CvxifEn: bit'(1),
      CoproType: config_pkg::COPRO_EXAMPLE,
      RVZiCond: bit'(0),
      RVZiCbom: bit'(0),
// ...
      RVS: bit'(0),
      RVU: bit'(0),
      SoftwareInterruptEn: bit'(0),
// ...
      TvalEn: bit'(0),
// ...
      DebugEn: bit'(0),
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
      SdtrigNrTriggers: int'(4),
      SdtrigTriggerChaining: bit'(0),
      SdtrigSupportedActions: {2{2'b01}},
      SdtrigSupportedMatch: {10{10'b00_0000_0001}},
      SdtrigSupportTextra: bit'(0),
```

### `core/include/build_config_pkg.sv`

```systemverilog
  function automatic config_pkg::cva6_cfg_t build_config(config_pkg::cva6_user_cfg_t CVA6Cfg);
    bit IS_XLEN32 = (CVA6Cfg.XLEN == 32) ? 1'b1 : 1'b0;
    bit IS_XLEN64 = (CVA6Cfg.XLEN == 32) ? 1'b0 : 1'b1;
    bit FpPresent = CVA6Cfg.RVF | CVA6Cfg.RVD | CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8;
    bit NSX = CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8 | CVA6Cfg.XFVec;  // Are non-standard extensions present?
    int unsigned FLen = CVA6Cfg.RVD ? 64 :  // D ext.
    CVA6Cfg.RVF ? 32 :  // F ext.
    CVA6Cfg.XF16 ? 16 :  // Xf16 ext.
    CVA6Cfg.XF16ALT ? 16 :  // Xf16alt ext.
    CVA6Cfg.XF8 ? 8 :  // Xf8 ext.
    1;  // Unused in case of no FP

    // Transprecision floating-point extensions configuration
    bit RVFVec     = CVA6Cfg.RVF     & CVA6Cfg.XFVec & FLen>32; // FP32 vectors available if vectors and larger fmt enabled
    bit XF16Vec    = CVA6Cfg.XF16    & CVA6Cfg.XFVec & FLen>16; // FP16 vectors available if vectors and larger fmt enabled
    bit XF16ALTVec = CVA6Cfg.XF16ALT & CVA6Cfg.XFVec & FLen>16; // FP16ALT vectors available if vectors and larger fmt enabled
    bit XF8Vec     = CVA6Cfg.XF8     & CVA6Cfg.XFVec & FLen>8;  // FP8 vectors available if vectors and larger fmt enabled

    bit EnableAccelerator = CVA6Cfg.RVV;  // Currently only used by V extension (Ara)
// ...
    cfg.XLEN = CVA6Cfg.XLEN;
    cfg.VLEN = CVA6Cfg.VLEN;
    cfg.PLEN = IS_XLEN32 ? 34 : 56;
    cfg.GPLEN = IS_XLEN32 ? 34 : 41;
    cfg.IS_XLEN32 = IS_XLEN32;
    cfg.IS_XLEN64 = IS_XLEN64;
    cfg.XLEN_ALIGN_BYTES = $clog2(CVA6Cfg.XLEN / 8);
```

## Package and imports

### `core/include/ariane_pkg.sv`

```systemverilog
  typedef enum logic [2:0] {
    NoCF,    // No control flow prediction
    Branch,  // Branch
    Jump,    // Jump to address from immediate
    JumpR,   // Jump to address from registers
    Return   // Return Address Prediction
  } cf_t;

  typedef struct packed {
    logic valid;
    logic taken;
  } bht_prediction_t;

  typedef struct packed {
    logic       valid;
    logic [1:0] saturation_counter;
  } bht_t;

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
```

## Module declaration

### `core/ex_stage.sv`

```systemverilog
module ex_stage
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bp_resolve_t = logic,
    parameter type branchpredict_sbe_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter type exception_t = logic,
    parameter type fu_data_t = logic,
    parameter type icache_areq_t = logic,
    parameter type icache_arsp_t = logic,
    parameter type icache_dreq_t = logic,
    parameter type icache_drsp_t = logic,
    parameter type lsu_ctrl_t = logic,
    parameter type x_result_t = logic,
    parameter type acc_mmu_req_t = logic,
    parameter type acc_mmu_resp_t = logic,
    parameter type cbo_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Fetch flush request - CONTROLLER
    input logic flush_i,
    // Debug mode is enabled - CSR_REGFILE
    input logic debug_mode_i,
    // rs1 forwarding - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs1_forwarding_i,
    // rs2 forwarding - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] rs2_forwarding_i,
    // FU data useful to execute instruction - ISSUE_STAGE
    input fu_data_t [CVA6Cfg.NrIssuePorts-1:0] fu_data_i,
    // ALU to ALU bypass control - ISSUE_STAGE
    input alu_bypass_t alu_bypass_i,
    // PC of the current instruction - ISSUE_STAGE
    input logic [CVA6Cfg.VLEN-1:0] pc_i,
    // Is_zcmt instruction - ISSUE_STAGE
    input logic is_zcmt_i,
    // Report whether instruction is compressed - ISSUE_STAGE
    input logic is_compressed_instr_i,
    // Report instruction encoding - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0][31:0] tinst_i,
    // Fixed Latency Unit result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] flu_result_o,
    // ID of the scoreboard entry at which a=to write back - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] flu_trans_id_o,
    // Fixed Latency Unit exception - ISSUE_STAGE
    output exception_t flu_exception_o,
    // FLU is ready - ISSUE_STAGE
    output logic flu_ready_o,
    // FLU result is valid - ISSUE_STAGE
    output logic flu_valid_o,
    // ALU instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] alu_valid_i,
    // AES instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] aes_valid_i,
    // Branch unit instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] branch_valid_i,
    // Information of branch prediction - ISSUE_STAGE
    input branchpredict_sbe_t branch_predict_i,
    // The branch engine uses the write back from the ALU - several_modules
    output bp_resolve_t resolved_branch_o,
    // Signaling that we resolved the branch - ISSUE_STAGE
    output logic resolve_branch_o,
    // CSR instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] csr_valid_i,
    // CSR address to write - COMMIT_STAGE
    output logic [11:0] csr_addr_o,
    // CSR commit - COMMIT_STAGE
    input logic csr_commit_i,
    // MULT instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] mult_valid_i,
    // LSU is ready - ISSUE_STAGE
    output logic lsu_ready_o,
    // LSU instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] lsu_valid_i,
    // Load result is valid - ISSUE_STAGE
    output logic load_valid_o,
    // Load result valid - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] load_result_o,
    // Load instruction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] load_trans_id_o,
    // Exception generated by load instruction - ISSUE_STAGE
    output exception_t load_exception_o,
    // Store result is valid - ISSUe_STAGE
    output logic store_valid_o,
    // Store result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] store_result_o,
    // Store instruction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] store_trans_id_o,
    // Exception generated by store instruction - ISSUE_STAGE
    output exception_t store_exception_o,
    // LSU commit - COMMIT_STAGE
    input logic lsu_commit_i,
    // Commit queue ready to accept another commit request - COMMIT_STAGE
    output logic lsu_commit_ready_o,
    // Commit transaction ID - COMMIT_STAGE
    input logic [CVA6Cfg.TRANS_ID_BITS-1:0] commit_tran_id_i,
    // TO_BE_COMPLETED - ACC_DISPATCHER
    input logic stall_st_pending_i,
    // TO_BE_COMPLETED - COMMIT_STAGE
    output logic no_st_pending_o,
    // Shared TLB is busy processing a multi-cycle flush
    output logic shared_tlb_flush_busy_o,
    // Atomic result is valid - COMMIT_STAGE
    input logic amo_valid_commit_i,
    // FU is ready - ISSUE_STAGE
    output logic fpu_ready_o,
    // FPU instruction is ready - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] fpu_valid_i,
    // FPU format - ISSUE_STAGE
    input logic [1:0] fpu_fmt_i,
    // FPU rm - ISSUE_STAGE
    input logic [2:0] fpu_rm_i,
    // FPU frm - ISSUE_STAGE
    input logic [2:0] fpu_frm_i,
    // FPU precision control - CSR_REGFILE
    input logic [6:0] fpu_prec_i,
    // FPU transaction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] fpu_trans_id_o,
    // FPU result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] fpu_result_o,
    // FPU valid - ISSUE_STAGE
    output logic fpu_valid_o,
    // FPU exception - ISSUE_STAGE
    output exception_t fpu_exception_o,
    // FPU early valid - ISSUE_STAGE
    output logic fpu_early_valid_o,
    // ALU2 instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] alu2_valid_i,
    // CVXIF instruction is valid - ISSUE_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] x_valid_i,
    // CVXIF is ready - ISSUE_STAGE
    output logic x_ready_o,
    // CVXIF undecoded instruction
    input logic [31:0] x_off_instr_i,
    // CVXIF transaction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] x_trans_id_o,
    // CVXIF exception - ISSUE_STAGE
    output exception_t x_exception_o,
    // CVXIF result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] x_result_o,
    // CVXIF result valid - ISSUE_STAGE
    output logic x_valid_o,
    // CVXIF write enable - ISSUE_STAGE
    output logic x_we_o,
    // CVXIF destination register - ISSUE_STAGE
    output logic [4:0] x_rd_o,
    // CVXIF Result interface - SUBSYSTEM
    input logic x_result_valid_i,
    input x_result_t x_result_i,
    output logic x_result_ready_o,
    // CVXIF Issue transaction rejected -> illegal instruction - ISSUE_STAGE
    input logic x_transaction_rejected_i,
    // accelerate port result is valid - ACC_DISPATCHER
    input logic acc_valid_i,
    // Accelerator MMU access
    input acc_mmu_req_t acc_mmu_req_i,
    output acc_mmu_resp_t acc_mmu_resp_o,
    // Enable virtual memory translation - CSR_REGFILE
    input logic enable_translation_i,
    // Enable G-Stage memory translation - CSR_REGFILE
    input logic enable_g_translation_i,
    // Enable virtual memory translation for load/stores - CSR_REGFILE
    input logic en_ld_st_translation_i,
    // Enable G-Stage memory translation for load/stores - CSR_REGFILE
    input logic en_ld_st_g_translation_i,
    // Flush TLB - CONTROLLER
    input logic flush_tlb_i,
    input logic flush_tlb_vvma_i,
    input logic flush_tlb_gvma_i,
    // Privilege mode - CSR_REGFILE
    input riscv::priv_lvl_t priv_lvl_i,
    // Data endianness - CSR REGFILE
    input logic mbe_i,
    // Virtualization mode - CSR_REGFILE
    input logic v_i,
    // Privilege level at which load and stores should happen - CSR_REGFILE
    input riscv::priv_lvl_t ld_st_priv_lvl_i,
    // Virtualization mode at which load and stores should happen - CSR_REGFILE
    input logic ld_st_v_i,
    // Instruction is hypervisor load/store - CSR_REGFILE
    output logic csr_hs_ld_st_inst_o,
    // Supervisor user memory - CSR_REGFILE
    input logic sum_i,
    // Virtual Supervisor user memory - CSR_REGFILE
    input logic vs_sum_i,
    // Make executable readable - CSR_REGFILE
    input logic mxr_i,
    // Make executable readable Virtual Supervisor - CSR_REGFILE
    input logic vmxr_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.PPNW-1:0] satp_ppn_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.ASID_WIDTH-1:0] asid_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.PPNW-1:0] vsatp_ppn_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.ASID_WIDTH-1:0] vs_asid_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.PPNW-1:0] hgatp_ppn_i,
    // TO_BE_COMPLETED - CSR_REGFILE
    input logic [CVA6Cfg.VMID_WIDTH-1:0] vmid_i,
    // icache translation response - CACHE
    input icache_arsp_t icache_areq_i,
    // icache translation request - CACHE
    output icache_areq_t icache_areq_o,
    // Data cache request output - CACHE
    input dcache_req_o_t [2:0] dcache_req_ports_i,
    // Data cache request input - CACHE
    output dcache_req_i_t [2:0] dcache_req_ports_o,
    // Write buffer is empty - CACHE
    input logic dcache_wbuffer_empty_i,
    // TO_BE_COMPLETED - CACHE
    input logic dcache_wbuffer_not_ni_i,
    // AMO request - CACHE
    output amo_req_t amo_req_o,
    // AMO response - CACHE
    input amo_resp_t amo_resp_i,
    // To count the instruction TLB misses - PERF_COUNTERS
    output logic itlb_miss_o,
    // To count the data TLB misses - PERF_COUNTERS
    output logic dtlb_miss_o,
    // Report the PMP configuration - CSR_REGFILE
    input riscv::pmpcfg_t [avoid_neg(CVA6Cfg.NrPMPEntries-1):0] pmpcfg_i,
    // Report the PMP addresses - CSR_REGFILE
    input logic [avoid_neg(CVA6Cfg.NrPMPEntries-1):0][CVA6Cfg.PLEN-3:0] pmpaddr_i,
    // Information dedicated to RVFI - RVFI
    output lsu_ctrl_t rvfi_lsu_ctrl_o,
    // Information dedicated to RVFI - RVFI
    output [CVA6Cfg.PLEN-1:0] rvfi_mem_paddr_o,
    // Original instruction AES bits
    input logic [5:0] orig_instr_aes_i,
    //Trigger module communication
    output logic [CVA6Cfg.VLEN-1:0] sdtrig_lsu_inputs_operand_a_o,
    output logic [CVA6Cfg.XLEN-1:0] sdtrig_lsu_inputs_operand_c_o,
    output logic sdtrig_lsu_inputs_we_o,
    output logic sdtrig_lsu_inputs_valid_o,
    input logic sdtrig_load_stall_i,
    input logic sdtrig_load_cancel_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_load_action_i,
    input logic sdtrig_store_stall_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_store_action_i
);
```

## Parent instantiation

### `core/cva6.sv`

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

    // All information needed to determine whether we need to associate an interrupt
    // with the corresponding instruction or not.
    localparam type irq_ctrl_t = struct packed {
      logic [CVA6Cfg.XLEN-1:0] mie;
      logic [CVA6Cfg.XLEN-1:0] mip;
      logic [CVA6Cfg.XLEN-1:0] mideleg;
      logic [CVA6Cfg.XLEN-1:0] hideleg;
      logic                    sie;
      logic                    global_enable;
    },

    localparam type lsu_ctrl_t = struct packed {
      logic                             valid;
      logic [CVA6Cfg.VLEN-1:0]          vaddr;
      logic [31:0]                      tinst;
      logic                             hs_ld_st_inst;
      logic                             hlvx_inst;
      logic                             overflow;
      logic                             g_overflow;
      logic [CVA6Cfg.XLEN-1:0]          data;
      logic [(CVA6Cfg.XLEN/8)-1:0]      be;
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
      logic                             is_speculative_load;
      logic                             is_speculative_load_miss;
    },


    localparam type cbo_t = logic [7:0],

    localparam type fu_data_t = struct packed {
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.XLEN-1:0]          operand_a;
      logic [CVA6Cfg.XLEN-1:0]          operand_b;
      logic [CVA6Cfg.XLEN-1:0]          imm;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
    },
// ...
  logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_ex_id;
  logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.XLEN-1:0] wbdata_ex_id;
  exception_t [CVA6Cfg.NrWbPorts-1:0] ex_ex_ex_id;  // exception from execute, ex_stage to id_stage
  logic [CVA6Cfg.NrWbPorts-1:0] wt_valid_ex_id;

  assign trans_id_ex_id[FLU_WB] = flu_trans_id_ex_id;
  assign wbdata_ex_id[FLU_WB]   = flu_result_ex_id;
  assign ex_ex_ex_id[FLU_WB]    = flu_exception_ex_id;
  assign wt_valid_ex_id[FLU_WB] = flu_valid_ex_id;

  assign trans_id_ex_id[STORE_WB] = store_trans_id_ex_id;
  assign wbdata_ex_id[STORE_WB]   = store_result_ex_id;
  assign ex_ex_ex_id[STORE_WB]    = store_exception_ex_id;
  assign wt_valid_ex_id[STORE_WB] = store_valid_ex_id;

  assign trans_id_ex_id[LOAD_WB] = load_trans_id_ex_id;
  assign wbdata_ex_id[LOAD_WB]   = load_result_ex_id;
  assign ex_ex_ex_id[LOAD_WB]    = load_exception_ex_id;
  assign wt_valid_ex_id[LOAD_WB] = load_valid_ex_id;

  assign trans_id_ex_id[FPU_WB] = fpu_trans_id_ex_id;
  assign wbdata_ex_id[FPU_WB]   = fpu_result_ex_id;
  assign ex_ex_ex_id[FPU_WB]    = fpu_exception_ex_id;
  assign wt_valid_ex_id[FPU_WB] = fpu_valid_ex_id;

  if (CVA6Cfg.CvxifEn) begin
    always_comb begin : gen_cvxif_input_assignment
      x_compressed_ready = cvxif_resp_i.compressed_ready;
      x_compressed_resp  = cvxif_resp_i.compressed_resp;
      x_issue_ready      = cvxif_resp_i.issue_ready;
      x_issue_resp       = cvxif_resp_i.issue_resp;
      x_register_ready   = cvxif_resp_i.register_ready;
      x_result_valid     = cvxif_resp_i.result_valid;
      x_result           = cvxif_resp_i.result;
    end

    always_comb begin : gen_cvxif_output_assignment
      cvxif_req.compressed_valid = x_compressed_valid;
      cvxif_req.compressed_req   = x_compressed_req;
      cvxif_req.issue_valid      = x_issue_valid;
      cvxif_req.issue_req        = x_issue_req;
      cvxif_req.register_valid   = x_register_valid;
      cvxif_req.register         = x_register;
      cvxif_req.commit_valid     = x_commit_valid;
      cvxif_req.commit           = x_commit;
      cvxif_req.result_ready     = x_result_ready;
    end
    assign trans_id_ex_id[X_WB] = x_trans_id_ex_id;
    assign wbdata_ex_id[X_WB]   = x_result_ex_id;
    assign ex_ex_ex_id[X_WB]    = x_exception_ex_id;
    assign wt_valid_ex_id[X_WB] = x_valid_ex_id;
  end else if (CVA6Cfg.EnableAccelerator) begin
    assign cvxif_req = '0;
    assign trans_id_ex_id[ACC_WB] = acc_trans_id_ex_id;
    assign wbdata_ex_id[ACC_WB]   = acc_result_ex_id;
    assign ex_ex_ex_id[ACC_WB]    = acc_exception_ex_id;
    assign wt_valid_ex_id[ACC_WB] = acc_valid_ex_id;
  end else begin
    assign cvxif_req = '0;
    assign x_compressed_ready = '0;
    assign x_compressed_resp = '0;
    assign x_issue_ready = '0;
    assign x_issue_resp = '0;
    assign x_register_ready = '0;
    assign x_result_valid = '0;
    assign x_result = '0;
// ...
  ex_stage #(
      .CVA6Cfg   (CVA6Cfg),
      .bp_resolve_t(bp_resolve_t),
      .branchpredict_sbe_t(branchpredict_sbe_t),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .exception_t(exception_t),
      .fu_data_t(fu_data_t),
      .icache_areq_t(icache_areq_t),
      .icache_arsp_t(icache_arsp_t),
      .icache_dreq_t(icache_dreq_t),
      .icache_drsp_t(icache_drsp_t),
      .lsu_ctrl_t(lsu_ctrl_t),
      .x_result_t(x_result_t),
      .acc_mmu_req_t(acc_mmu_req_t),
      .acc_mmu_resp_t(acc_mmu_resp_t),
      .cbo_t(cbo_t)
  ) ex_stage_i (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .debug_mode_i(debug_mode),
      .flush_i(flush_ctrl_ex),
      .rs1_forwarding_i(rs1_forwarding_id_ex),
      .rs2_forwarding_i(rs2_forwarding_id_ex),
      .fu_data_i(fu_data_id_ex),
      .alu_bypass_i(alu_bypass_id_ex),
      .pc_i(pc_id_ex),
      .is_zcmt_i(zcmt_id_ex),
      .is_compressed_instr_i(is_compressed_instr_id_ex),
      .tinst_i(tinst_ex),
      // fixed latency units
      .flu_result_o(flu_result_ex_id),
      .flu_trans_id_o(flu_trans_id_ex_id),
      .flu_valid_o(flu_valid_ex_id),
      .flu_exception_o(flu_exception_ex_id),
      .flu_ready_o(flu_ready_ex_id),
      // ALU
      .alu_valid_i(alu_valid_id_ex),
      .orig_instr_aes_i(orig_instr_aes),
      .aes_valid_i(aes_valid_id_ex),
      // Branches and Jumps
      .branch_valid_i(branch_valid_id_ex),
      .branch_predict_i(branch_predict_id_ex),  // branch predict to ex
      .resolved_branch_o(resolved_branch),
      .resolve_branch_o(resolve_branch_ex_id),
      // CSR
      .csr_valid_i(csr_valid_id_ex),
      .csr_addr_o(csr_addr_ex_csr),
      .csr_commit_i(csr_commit_commit_ex),  // from commit
      .csr_hs_ld_st_inst_o(csr_hs_ld_st_inst_ex),  // signals a Hypervisor Load/Store Instruction
      // MULT
      .mult_valid_i(mult_valid_id_ex),
      // LSU
      .lsu_ready_o(lsu_ready_ex_id),
      .lsu_valid_i(lsu_valid_id_ex),

      .load_result_o   (load_result_ex_id),
      .load_trans_id_o (load_trans_id_ex_id),
      .load_valid_o    (load_valid_ex_id),
      .load_exception_o(load_exception_ex_id),

      .store_result_o   (store_result_ex_id),
      .store_trans_id_o (store_trans_id_ex_id),
      .store_valid_o    (store_valid_ex_id),
      .store_exception_o(store_exception_ex_id),

      .lsu_commit_i                 (lsu_commit_commit_ex),           // from commit
      .lsu_commit_ready_o           (lsu_commit_ready_ex_commit),     // to commit
      .commit_tran_id_i             (lsu_commit_trans_id),            // from commit
      .stall_st_pending_i           (stall_st_pending_ex),
      .shared_tlb_flush_busy_o      (shared_tlb_flush_busy_ex),
      .no_st_pending_o              (no_st_pending_ex),
      // FPU
      .fpu_ready_o                  (fpu_ready_ex_id),
      .fpu_valid_i                  (fpu_valid_id_ex),
      .fpu_fmt_i                    (fpu_fmt_id_ex),
      .fpu_rm_i                     (fpu_rm_id_ex),
      .fpu_frm_i                    (frm_csr_id_issue_ex),
      .fpu_prec_i                   (fprec_csr_ex),
      .fpu_trans_id_o               (fpu_trans_id_ex_id),
      .fpu_result_o                 (fpu_result_ex_id),
      .fpu_valid_o                  (fpu_valid_ex_id),
      .fpu_exception_o              (fpu_exception_ex_id),
      .fpu_early_valid_o            (fpu_early_valid_ex_id),
      // ALU2
      .alu2_valid_i                 (alu2_valid_id_ex),
      .amo_valid_commit_i           (amo_valid_commit),
      .amo_req_o                    (amo_req),
      .amo_resp_i                   (amo_resp),
      // CoreV-X-Interface
      .x_valid_i                    (x_issue_valid_id_ex),
      .x_ready_o                    (x_issue_ready_ex_id),
      .x_off_instr_i                (x_off_instr_id_ex),
      .x_transaction_rejected_i     (x_transaction_rejected),
      .x_trans_id_o                 (x_trans_id_ex_id),
      .x_exception_o                (x_exception_ex_id),
      .x_result_o                   (x_result_ex_id),
      .x_valid_o                    (x_valid_ex_id),
      .x_we_o                       (x_we_ex_id),
      .x_rd_o                       (x_rd_ex_id),
      .x_result_valid_i             (x_result_valid),
      .x_result_i                   (x_result),
      .x_result_ready_o             (x_result_ready),
      // Accelerator
      .acc_valid_i                  (acc_valid_acc_ex),
      // Accelerator MMU access
      .acc_mmu_req_i                (acc_mmu_req),
      .acc_mmu_resp_o               (acc_mmu_resp),
      // Performance counters
      .itlb_miss_o                  (itlb_miss_ex_perf),
      .dtlb_miss_o                  (dtlb_miss_ex_perf),
      // Memory Management
      .enable_translation_i         (enable_translation_csr_ex),      // from CSR
      .enable_g_translation_i       (enable_g_translation_csr_ex),    // from CSR
      .en_ld_st_translation_i       (en_ld_st_translation_csr_ex),
      .en_ld_st_g_translation_i     (en_ld_st_g_translation_csr_ex),
      .flush_tlb_i                  (flush_tlb_ctrl_ex),
      .flush_tlb_vvma_i             (flush_tlb_vvma_ctrl_ex),
      .flush_tlb_gvma_i             (flush_tlb_gvma_ctrl_ex),
      .priv_lvl_i                   (priv_lvl),                       // from CSR
      .mbe_i                        (mbe),                            // from CSR
      .v_i                          (v),                              // from CSR
      .ld_st_priv_lvl_i             (ld_st_priv_lvl_csr_ex),          // from CSR
      .ld_st_v_i                    (ld_st_v_csr_ex),                 // from CSR
      .sum_i                        (sum_csr_ex),                     // from CSR
      .vs_sum_i                     (vs_sum_csr_ex),                  // from CSR
      .mxr_i                        (mxr_csr_ex),                     // from CSR
      .vmxr_i                       (vmxr_csr_ex),                    // from CSR
      .satp_ppn_i                   (satp_ppn_csr_ex),                // from CSR
      .asid_i                       (asid_csr_ex),                    // from CSR
      .vsatp_ppn_i                  (vsatp_ppn_csr_ex),               // from CSR
      .vs_asid_i                    (vs_asid_csr_ex),                 // from CSR
      .hgatp_ppn_i                  (hgatp_ppn_csr_ex),               // from CSR
      .vmid_i                       (vmid_csr_ex),                    // from CSR
      .icache_areq_i                (icache_areq_cache_ex),
      .icache_areq_o                (icache_areq_ex_cache),
      // DCACHE interfaces
      .dcache_req_ports_i           (dcache_req_ports_cache_ex),
      .dcache_req_ports_o           (dcache_req_ports_ex_cache),
      .dcache_wbuffer_empty_i       (dcache_commit_wbuffer_empty),
      .dcache_wbuffer_not_ni_i      (dcache_commit_wbuffer_not_ni),
      // PMP
      .pmpcfg_i                     (pmpcfg),
      .pmpaddr_i                    (pmpaddr),
      //RVFI
      .rvfi_lsu_ctrl_o              (rvfi_lsu_ctrl),
      .rvfi_mem_paddr_o             (rvfi_mem_paddr),
      //Trigger module command signals
      .sdtrig_load_stall_i          (sdtrig_load_stall),
      .sdtrig_load_cancel_i         (sdtrig_load_cancel),
      .sdtrig_load_action_i         (sdtrig_load_action),
      .sdtrig_store_stall_i         (sdtrig_store_stall),
      .sdtrig_store_action_i        (sdtrig_store_action),
      .sdtrig_lsu_inputs_operand_a_o(sdtrig_lsu_inputs_operand_a),
      .sdtrig_lsu_inputs_operand_c_o(sdtrig_lsu_inputs_operand_c),
      .sdtrig_lsu_inputs_we_o       (sdtrig_lsu_inputs_we),
      .sdtrig_lsu_inputs_valid_o    (sdtrig_lsu_inputs_valid)
  );
```

## Dependency declarations

### `core/alu_wrapper.sv`

```systemverilog
module alu_wrapper
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type fu_data_t = logic
) (
    input  logic                                               clk_i,
    input  logic                                               rst_ni,
    input  alu_bypass_t                                        alu_bypass_i,
    input  fu_data_t    [CVA6Cfg.NrALUs-1:0]                   fu_data_i,
    output logic        [CVA6Cfg.NrALUs-1:0][CVA6Cfg.XLEN-1:0] result_o,
    output logic                                               alu_branch_res_o
);
```

### `core/branch_unit.sv`

```systemverilog
module branch_unit #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bp_resolve_t = logic,
    parameter type branchpredict_sbe_t = logic,
    parameter type exception_t = logic,
    parameter type fu_data_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Virtualization mode state - CSR_REGFILE
    input logic v_i,
    // Debug mode state - CSR_REGFILE
    input logic debug_mode_i,
    // FU data needed to execute instruction - ISSUE_STAGE
    input fu_data_t fu_data_i,
    // Instruction PC - ISSUE_STAGE
    input logic [CVA6Cfg.VLEN-1:0] pc_i,
    // Is zcmt instruction - ISSUE_STAGE
    input logic is_zcmt_i,
    // Instruction is compressed - ISSUE_STAGE
    input logic is_compressed_instr_i,
    // Branch unit instruction is valid - ISSUE_STAGE
    input logic branch_valid_i,
    // ALU branch compare result - ALU
    input logic branch_comp_res_i,
    // Brach unit result - ISSUE_STAGE
    output logic [CVA6Cfg.VLEN-1:0] branch_result_o,
    // Information of branch prediction - ISSUE_STAGE
    input branchpredict_sbe_t branch_predict_i,
    // Signaling that we resolved the branch - ISSUE_STAGE
    output bp_resolve_t resolved_branch_o,
    // Branch is resolved, new entries can be accepted by scoreboard - ID_STAGE
    output logic resolve_branch_o,
    // Branch exception out - TO_BE_COMPLETED
    output exception_t branch_exception_o
);
```

### `core/csr_buffer.sv`

```systemverilog
module csr_buffer
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type fu_data_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Flush CSR - CONTROLLER
    input logic flush_i,
    // FU data needed to execute instruction - ISSUE_STAGE
    input fu_data_t fu_data_i,
    // CSR FU is ready - ISSUE_STAGE
    output logic csr_ready_o,
    // CSR instruction is valid - ISSUE_STAGE
    input logic csr_valid_i,
    // CSR buffer result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] csr_result_o,
    // commit the pending CSR OP - TO_BE_COMPLETED
    input logic csr_commit_i,
    // CSR address to write - COMMIT_STAGE
    output logic [11:0] csr_addr_o
);
```

### `core/cvxif_fu.sv`

```systemverilog
module cvxif_fu
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type exception_t = logic,
    parameter type x_result_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input  logic                                   clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input  logic                                   rst_ni,
    // Virtualization mode state - CSR_REGFILE
    input  logic                                   v_i,
    // CVXIF instruction is valid - ISSUE_STAGE
    input  logic                                   x_valid_i,
    // Transaction ID - ISSUE_STAGE
    input  logic       [CVA6Cfg.TRANS_ID_BITS-1:0] x_trans_id_i,
    // Instruction is illegal, determined during CVXIF issue transaction - ISSUE_STAGE
    input  logic                                   x_illegal_i,
    // Offloaded instruction - ISSUE_STAGE
    input  logic       [                     31:0] x_off_instr_i,
    // CVXIF is ready - ISSUE_STAGE
    output logic                                   x_ready_o,
    // CVXIF result transaction ID - ISSUE_STAGE
    output logic       [CVA6Cfg.TRANS_ID_BITS-1:0] x_trans_id_o,
    // CVXIF exception - ISSUE_STAGE
    output exception_t                             x_exception_o,
    // CVXIF FU result - ISSUE_STAGE
    output logic       [         CVA6Cfg.XLEN-1:0] x_result_o,
    // CVXIF result valid - ISSUE_STAGE
    output logic                                   x_valid_o,
    // CVXIF write enable - ISSUE_STAGE
    output logic                                   x_we_o,
    // CVXIF destination register - ISSUE_STAGE
    output logic       [                      4:0] x_rd_o,
    // CVXIF result interface
    input  logic                                   result_valid_i,
    input  x_result_t                              result_i,
    output logic                                   result_ready_o
);
```

### `core/load_store_unit.sv`

```systemverilog
module load_store_unit
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter type exception_t = logic,
    parameter type fu_data_t = logic,
    parameter type icache_areq_t = logic,
    parameter type icache_arsp_t = logic,
    parameter type icache_dreq_t = logic,
    parameter type icache_drsp_t = logic,
    parameter type lsu_ctrl_t = logic,
    parameter type acc_mmu_req_t = logic,
    parameter type acc_mmu_resp_t = logic,
    parameter type cbo_t = logic,
    parameter type bp_resolve_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic flush_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic stall_st_pending_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic no_st_pending_o,
    // Shared TLB is busy processing a multi-cycle flush
    output logic shared_tlb_flush_busy_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic amo_valid_commit_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input logic [31:0] tinst_i,
    // FU data needed to execute instruction - ISSUE_STAGE
    input fu_data_t fu_data_i,
    // Load Store Unit is ready - ISSUE_STAGE
    output logic lsu_ready_o,
    // Load Store Unit instruction is valid - ISSUE_STAGE
    input logic lsu_valid_i,
    // Signals speculative loads for non-idempotent load handling - EX_STAGE
    input logic speculative_load_i,

    // Load transaction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] load_trans_id_o,
    // Load result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] load_result_o,
    // Load result is valid - ISSUE_STAGE
    output logic load_valid_o,
    // Load exception - ISSUE_STAGE
    output exception_t load_exception_o,

    // Store transaction ID - ISSUE_STAGE
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] store_trans_id_o,
    // Store result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] store_result_o,
    // Store result is valid - ISSUE_STAGE
    output logic store_valid_o,
    // Store exception - ISSUE_STAGE
    output exception_t store_exception_o,

    // Commit the first pending store - TO_BE_COMPLETED
    input logic commit_i,
    // Commit queue is ready to accept another commit request - TO_BE_COMPLETED
    output logic commit_ready_o,
    // Commit transaction ID - TO_BE_COMPLETED
    input logic [CVA6Cfg.TRANS_ID_BITS-1:0] commit_tran_id_i,
    // Result from branch unit - EX_STAGE
    input bp_resolve_t resolved_branch_i,
    // Enable virtual memory translation - TO_BE_COMPLETED
    input logic enable_translation_i,
    // Enable G-Stage memory translation - TO_BE_COMPLETED
    input logic enable_g_translation_i,
    // Enable virtual memory translation for load/stores - TO_BE_COMPLETED
    input logic en_ld_st_translation_i,
    // Enable G-Stage memory translation for load/stores - TO_BE_COMPLETED
    input logic en_ld_st_g_translation_i,

    // Accelerator request for CVA6's MMU
    input  acc_mmu_req_t  acc_mmu_req_i,
    output acc_mmu_resp_t acc_mmu_resp_o,

    // Instruction cache input request - CACHES
    input  icache_arsp_t icache_areq_i,
    // Instruction cache output request - CACHES
    output icache_areq_t icache_areq_o,

    // Current privilege mode - CSR_REGFILE
    input  riscv::priv_lvl_t                          priv_lvl_i,
    // Data Endian mode - CSR_REGFILE
    input  logic                                      mbe_i,
    // Current virtualization mode - CSR_REGFILE
    input  logic                                      v_i,
    // Privilege level at which load and stores should happen - CSR_REGFILE
    input  riscv::priv_lvl_t                          ld_st_priv_lvl_i,
    // Virtualization mode at which load and stores should happen - CSR_REGFILE
    input  logic                                      ld_st_v_i,
    // Instruction is a hyp load/store - CSR_REGFILE
    output logic                                      csr_hs_ld_st_inst_o,
    // Supervisor User Memory - CSR_REGFILE
    input  logic                                      sum_i,
    // Virtual Supervisor User Memory - CSR_REGFILE
    input  logic                                      vs_sum_i,
    // Make Executable Readable - CSR_REGFILE
    input  logic                                      mxr_i,
    // Make Executable Readable Virtual Supervisor - CSR_REGFILE
    input  logic                                      vmxr_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [      CVA6Cfg.PPNW-1:0] satp_ppn_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [CVA6Cfg.ASID_WIDTH-1:0] asid_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [      CVA6Cfg.PPNW-1:0] vsatp_ppn_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [CVA6Cfg.ASID_WIDTH-1:0] vs_asid_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [      CVA6Cfg.PPNW-1:0] hgatp_ppn_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [CVA6Cfg.VMID_WIDTH-1:0] vmid_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [CVA6Cfg.ASID_WIDTH-1:0] asid_to_be_flushed_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [CVA6Cfg.VMID_WIDTH-1:0] vmid_to_be_flushed_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [      CVA6Cfg.VLEN-1:0] vaddr_to_be_flushed_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic             [     CVA6Cfg.GPLEN-1:0] gpaddr_to_be_flushed_i,
    // TLB flush - CONTROLLER
    input  logic                                      flush_tlb_i,
    input  logic                                      flush_tlb_vvma_i,
    input  logic                                      flush_tlb_gvma_i,
    // Instruction TLB miss - PERF_COUNTERS
    output logic                                      itlb_miss_o,
    // Data TLB miss - PERF_COUNTERS
    output logic                                      dtlb_miss_o,

    // Data cache request output - CACHES
    input  dcache_req_o_t [2:0] dcache_req_ports_i,
    // Data cache request input - CACHES
    output dcache_req_i_t [2:0] dcache_req_ports_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic                dcache_wbuffer_empty_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic                dcache_wbuffer_not_ni_i,
    // AMO request - CACHE
    output amo_req_t            amo_req_o,
    // AMO response - CACHE
    input  amo_resp_t           amo_resp_i,

    // PMP configuration - CSR_REGFILE
    input riscv::pmpcfg_t [avoid_neg(CVA6Cfg.NrPMPEntries-1):0]                   pmpcfg_i,
    // PMP address - CSR_REGFILE
    input logic           [avoid_neg(CVA6Cfg.NrPMPEntries-1):0][CVA6Cfg.PLEN-3:0] pmpaddr_i,

    // RVFI information - RVFI
    output lsu_ctrl_t                    rvfi_lsu_ctrl_o,
    // RVFI information - RVFI
    output logic      [CVA6Cfg.PLEN-1:0] rvfi_mem_paddr_o,
    //Trigger module communication
    input  logic                         sdtrig_load_stall_i,
    input  logic                         sdtrig_load_cancel_i,
    input  logic      [CVA6Cfg.XLEN-1:0] sdtrig_load_action_i,
    input  logic                         sdtrig_store_stall_i,
    input  logic      [CVA6Cfg.XLEN-1:0] sdtrig_store_action_i
);
```

### `core/mult.sv`

```systemverilog
module mult
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type fu_data_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input  logic                                 clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input  logic                                 rst_ni,
    // Flush - CONTROLLER
    input  logic                                 flush_i,
    // FU data needed to execute instruction - ISSUE_STAGE
    input  fu_data_t                             fu_data_i,
    // Mult instruction is valid - ISSUE_STAGE
    input  logic                                 mult_valid_i,
    // Mult result - ISSUE_STAGE
    output logic     [         CVA6Cfg.XLEN-1:0] result_o,
    // Mult result is valid - ISSUE_STAGE
    output logic                                 mult_valid_o,
    // Mutl is ready - ISSUE_STAGE
    output logic                                 mult_ready_o,
    // Mult transaction ID - ISSUE_STAGE
    output logic     [CVA6Cfg.TRANS_ID_BITS-1:0] mult_trans_id_o
);
```

## Related source code

### `core/issue_read_operands.sv`

```systemverilog
  // select the right busy signal
  // this obviously depends on the functional unit we need
  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    always_comb begin
      unique case (issue_instr_i[i].fu)
        NONE: fu_busy[i] = fus_busy[i].none;
        ALU: begin
          if (CVA6Cfg.SuperscalarEn && use_alu2[i]) begin
            fu_busy[i] = fus_busy[i].alu2;
          end else begin
            fu_busy[i] = fus_busy[i].alu;
          end
        end
        CTRL_FLOW: fu_busy[i] = fus_busy[i].ctrl_flow;
        CSR: fu_busy[i] = fus_busy[i].csr;
        MULT: fu_busy[i] = fus_busy[i].mult;
        LOAD: fu_busy[i] = fus_busy[i].load;
        STORE: fu_busy[i] = fus_busy[i].store;
        CVXIF: fu_busy[i] = fus_busy[i].cvxif;
        AES: fu_busy[i] = fus_busy[i].aes;
        default:
        if (CVA6Cfg.FpPresent) begin
          unique case (issue_instr_i[i].fu)
            FPU: fu_busy[i] = fus_busy[i].fpu;
            FPU_VEC: fu_busy[i] = fus_busy[i].fpu_vec;
            default: fu_busy[i] = 1'b0;
          endcase
        end else begin
          fu_busy[i] = 1'b0;
        end
      endcase
// ...
    for (int unsigned i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
      if (!issue_instr_i[i].ex.valid && issue_instr_valid_i[i] && issue_ack_o[i]) begin
        case (issue_instr_i[i].fu)
          ALU: begin
            if (CVA6Cfg.SuperscalarEn && use_alu2[i]) begin
              alu2_valid_n[i] = 1'b1;
            end else begin
              alu_valid_n[i] = 1'b1;
            end
          end
          CTRL_FLOW: begin
            branch_valid_n[i] = 1'b1;
          end
          MULT: begin
            mult_valid_n[i] = 1'b1;
          end
          LOAD, STORE: begin
            lsu_valid_n[i] = 1'b1;
          end
          CSR: begin
            csr_valid_n[i] = 1'b1;
          end
          AES: begin
            aes_valid_n[i] = 1'b1;
          end
          default: begin
            if (issue_instr_i[i].fu == FPU && CVA6Cfg.FpPresent) begin
              fpu_valid_n[i] = 1'b1;
              fpu_fmt_n      = orig_instr[i].rftype.fmt;  // fmt bits from instruction
              fpu_rm_n       = orig_instr[i].rftype.rm;  // rm bits from instruction
            end else if (issue_instr_i[i].fu == FPU_VEC && CVA6Cfg.FpPresent) begin
              fpu_valid_n[i] = 1'b1;
              fpu_fmt_n      = orig_instr[i].rvftype.vfmt;  // vfmt bits from instruction
              fpu_rm_n       = {2'b0, orig_instr[i].rvftype.repl};  // repl bit from instruction
            end
          end
        endcase
      end
    end
    // if we got a flush request, de-assert the valid flag, otherwise we will start this
    // functional unit with the wrong inputs
    if (flush_i) begin
      alu_valid_n    = '0;
      aes_valid_n    = '0;
      lsu_valid_n    = '0;
      mult_valid_n   = '0;
      fpu_valid_n    = '0;
      alu2_valid_n   = '0;
      csr_valid_n    = '0;
      branch_valid_n = '0;
    end
  end
  // FU select, assert the correct valid out signal (in the next cycle)
  // This needs to be like this to make verilator happy. I know it's ugly.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      alu_valid_q    <= '0;
      aes_valid_q    <= '0;
      lsu_valid_q    <= '0;
      mult_valid_q   <= '0;
      fpu_valid_q    <= '0;
      fpu_fmt_q      <= '0;
      fpu_rm_q       <= '0;
      alu2_valid_q   <= '0;
      csr_valid_q    <= '0;
      branch_valid_q <= '0;
    end else begin
      alu_valid_q    <= alu_valid_n;
      aes_valid_q    <= aes_valid_n;
      lsu_valid_q    <= lsu_valid_n;
      mult_valid_q   <= mult_valid_n;
      fpu_valid_q    <= fpu_valid_n;
      fpu_fmt_q      <= fpu_fmt_n;
      fpu_rm_q       <= fpu_rm_n;
      alu2_valid_q   <= alu2_valid_n;
      csr_valid_q    <= csr_valid_n;
      branch_valid_q <= branch_valid_n;
    end
  end

  if (CVA6Cfg.CvxifEn) begin
    always_comb begin
      cvxif_valid_n = '0;
      cvxif_off_instr_n = 32'b0;
      for (int unsigned i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
        if (!issue_instr_i[i].ex.valid && issue_instr_valid_i[i] && issue_ack_o[i]) begin
          case (issue_instr_i[i].fu)
            CVXIF: begin
              cvxif_valid_n[i]  = 1'b1;
              cvxif_off_instr_n = orig_instr_i[i];
            end
            default: ;
          endcase
        end
      end
      if (flush_i) begin
        cvxif_valid_n = '0;
        cvxif_off_instr_n = 32'b0;
      end
```

## Documentation

### `docs/design/design-manual/source/cva6_execute.adoc`

```text
Description
^^^^^^^^^^^

The EX_STAGE module is a logical stage which implements the execute stage.
It encapsulates the following functional units: ALU, Branch Unit, CSR buffer, Mult, load and store and CVXIF.

The module is connected to:

* ID_STAGE module provides scoreboard entry.
...
[[alu]]
alu
+++

The arithmetic logic unit (ALU) is a small piece of hardware which performs 32 and 64-bit arithmetic and bitwise operations: subtraction, addition, shifts, comparisons...
It always completes its operation in a single cycle.

include::port_alu.adoc[]

[[branch_unit]]
branch_unit
+++++++++++

The branch unit module manages all kinds of control flow changes i.e.: conditional and unconditional jumps.
It calculates the target address and decides whether to take the branch or not.
It also decides if a branch was mis-predicted or not and reports corrective actions to the pipeline stages.

include::port_branch_unit.adoc[]

[[csr_buffer]]
CSR_buffer
++++++++++

The CSR buffer module stores the CSR address at which the instruction is going to read/write.
As the CSR instruction alters the processor architectural state, this instruction has to be buffered until the commit stage decides to execute the instruction.

include::port_csr_buffer.adoc[]

[[mult]]
mult
++++

The multiplier module supports the division and multiplication operations.

image:mult_modules.png[mult submodules]

include::port_mult.adoc[]
...
[[load_store_unit-lsu]]
load_store_unit (LSU)
+++++++++++++++++++++

The load store module interfaces with the data cache (D$) to manage the load and store operations.

The LSU does not handle misaligned accesses.
Misaligned accesses are double word accesses which are not aligned to a 64-bit boundary, word accesses which are not aligned to a 32-bit boundary and half word accesses which are not aligned on 16-bit boundary.
If the LSU encounters a misaligned load or store, it throws a misaligned exception.
```
