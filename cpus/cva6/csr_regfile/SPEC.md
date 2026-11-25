# Implement `csr_regfile`

Implement the complete `csr_regfile` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module csr_regfile` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
package cva6_config_pkg;

  localparam CVA6ConfigXlen = 32;

// ...

  localparam config_pkg::cva6_user_cfg_t cva6_cfg = '{
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(32),
      FpgaEn: bit'(0),
      FpgaAlteraEn: bit'(0),
      TechnoCut: bit'(1),
      SuperscalarEn: bit'(0),
      ALUBypass: bit'(0),
      NrCommitPorts: unsigned'(1),

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
      RVZicntr: bit'(0),
      RVZihpm: bit'(0),

// ...

      PerfCounterEn: bit'(0),
      MmuPresent: bit'(0),
      RVS: bit'(0),
      RVU: bit'(0),
      SoftwareInterruptEn: bit'(0),

// ...

      TvalEn: bit'(0),
      DirectVecOnly: bit'(1),
      NrPMPEntries: unsigned'(0),
      PMPCfgRstVal: {64{64'h0}},
      PMPAddrRstVal: {64{64'h0}},
      PMPEntryReadOnly: 64'd0,
      PMPNapotEn: bit'(0),

// ...

      DebugEn: bit'(0),
      Sdtrig: bit'(0),

// ...

      DCacheType: config_pkg::HPDCACHE_WT,

// ...

      DcacheEccEnable: bit'(0),
      DcacheEccScrubberEnable: bit'(0),
```

### core/include/build_config_pkg.sv

```systemverilog
  function automatic config_pkg::cva6_cfg_t build_config(config_pkg::cva6_user_cfg_t CVA6Cfg);
    bit IS_XLEN32 = (CVA6Cfg.XLEN == 32) ? 1'b1 : 1'b0;
    bit IS_XLEN64 = (CVA6Cfg.XLEN == 32) ? 1'b0 : 1'b1;
    bit FpPresent = CVA6Cfg.RVF | CVA6Cfg.RVD | CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8;

// ...

    bit EnableAccelerator = CVA6Cfg.RVV;  // Currently only used by V extension (Ara)
```

## Module declaration

```systemverilog
module csr_regfile
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg            = config_pkg::cva6_cfg_empty,
    parameter type                   exception_t        = logic,
    parameter type                   jvt_t              = logic,
    parameter type                   irq_ctrl_t         = logic,
    parameter type                   scoreboard_entry_t = logic,
    parameter type                   rvfi_probes_csr_t  = logic,
    parameter int                    VmidWidth          = 1,
    parameter int unsigned           MHPMCounterNum     = 6,
    parameter int unsigned           N_Triggers         = 4
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Timer threw an interrupt - SUBSYSTEM
    input logic time_irq_i,
    // send a flush request out when a CSR with a side effect changes - CONTROLLER
    output logic flush_o,
    // halt requested - CONTROLLER
    output logic halt_csr_o,
    // Instruction to be committed - ID_STAGE
    input scoreboard_entry_t commit_instr_i,
    // Commit acknowledged an instruction -> increase instret CSR - COMMIT_STAGE
    input logic [CVA6Cfg.NrCommitPorts-1:0] commit_ack_i,
    // Address from which to start booting, mtvec is set to the same address - SUBSYSTEM
    input logic [CVA6Cfg.VLEN-1:0] boot_addr_i,
    // Hart id in a multicore environment (reflected in a CSR) - SUBSYSTEM
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    // We've got an exception from the commit stage, take it - COMMIT_STAGE
    input exception_t ex_i,
    // Operation to perform on the CSR file - COMMIT_STAGE
    input fu_op csr_op_i,
    // Address of the register to read/write - EX_STAGE
    input logic [11:0] csr_addr_i,
    // Write data in - COMMIT_STAGE
    input logic [CVA6Cfg.XLEN-1:0] csr_wdata_i,
    // Read data out - COMMIT_STAGE
    output logic [CVA6Cfg.XLEN-1:0] csr_rdata_o,
    // Mark the FP state as dirty - COMMIT_STAGE
    input logic dirty_fp_state_i,
    // Write fflags register e.g.: we are retiring a floating point instruction - COMMIT_STAGE
    input logic csr_write_fflags_i,
    // Mark the V state as dirty - ACC_DISPATCHER
    input logic dirty_v_state_i,
    // PC of instruction accessing the CSR - COMMIT_STAGE
    input logic [CVA6Cfg.VLEN-1:0] pc_i,
    // attempts to access a CSR without appropriate privilege - COMMIT_STAGE
    output exception_t csr_exception_o,
    // Output the exception PC to PC Gen, the correct CSR (mepc, sepc) is set accordingly - FRONTEND
    output logic [CVA6Cfg.VLEN-1:0] epc_o,
    // Return from exception, set the PC of epc_o - FRONTEND
    output logic eret_o,
    // Output base of exception vector, correct CSR is output (mtvec, stvec) - FRONTEND
    output logic [CVA6Cfg.VLEN-1:0] trap_vector_base_o,
    // Current privilege level the CPU is in - EX_STAGE
    output riscv::priv_lvl_t priv_lvl_o,
    // Data Endian mode
    output logic mbe_o,
    // Current virtualization mode state the CPU is in - EX_STAGE
    output logic v_o,
    // Imprecise FP exception from the accelerator (fcsr.fflags format) - ACC_DISPATCHER
    input logic [4:0] acc_fflags_ex_i,
    // An FP exception from the accelerator occurred - ACC_DISPATCHER
    input logic acc_fflags_ex_valid_i,
    // Floating point extension status - ID_STAGE
    output riscv::xs_t fs_o,
    // Floating point extension virtual status - ID_STAGE
    output riscv::xs_t vfs_o,
    // Floating-Point Occurred Exceptions - COMMIT_STAGE
    output logic [4:0] fflags_o,
    // Floating-Point Dynamic Rounding Mode - EX_STAGE
    output logic [2:0] frm_o,
    // Floating-Point Precision Control - EX_STAGE
    output logic [6:0] fprec_o,
    // Vector extension status - ID_STAGE
    output riscv::xs_t vs_o,
    // interrupt management to id stage - ID_STAGE
    output irq_ctrl_t irq_ctrl_o,
    // Enable virtual address translation - EX_STAGE
    output logic en_translation_o,
    // Enable G-Stage address translation - EX_STAGE
    output logic en_g_translation_o,
    // Enable virtual address translation for load and stores - EX_STAGE
    output logic en_ld_st_translation_o,
    // Enable G-Stage address translation for load and stores - EX_STAGE
    output logic en_ld_st_g_translation_o,
    // Privilege level at which load and stores should happen - EX_STAGE
    output riscv::priv_lvl_t ld_st_priv_lvl_o,
    // Virtualization mode at which load and stores should happen - EX_STAGE
    output logic ld_st_v_o,
    // Current instruction is a Hypervisor Load/Store Instruction - EX_STAGE
    input logic csr_hs_ld_st_inst_i,
    // Supervisor User Memory - EX_STAGE
    output logic sum_o,
    // Virtual Supervisor User Memory - EX_STAGE
    output logic vs_sum_o,
    // Make Executable Readable - EX_STAGE
    output logic mxr_o,
    // Make Executable Readable for VS-mode - EX_STAGE
    output logic vmxr_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.PPNW-1:0] satp_ppn_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.ASID_WIDTH-1:0] asid_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.PPNW-1:0] vsatp_ppn_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.ASID_WIDTH-1:0] vs_asid_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.PPNW-1:0] hgatp_ppn_o,
    // TO_BE_COMPLETED - EX_STAGE
    output logic [CVA6Cfg.VMID_WIDTH-1:0] vmid_o,
    // machine-mode cache block invalidate enable - ID_STAGE
    output riscv::cbie_t mcbie_o,
    // supervisor-mode cache block invalidate enable - ID_STAGE
    output riscv::cbie_t scbie_o,
    // hypervisor-mode cache block invalidate enable - ID_STAGE
    output riscv::cbie_t hcbie_o,
    // machine-mode clean/flush cache block invalidate enable - ID_STAGE
    output logic mcbcfe_o,
    // supervisor-mode clean/flush cache block invalidate enable - ID_STAGE
    output logic scbcfe_o,
    // hypervisor-mode clean/flush cache block invalidate enable - ID_STAGE
    output logic hcbcfe_o,
    // external interrupt in - SUBSYSTEM
    input logic [1:0] irq_i,
    // inter processor interrupt -> connected to machine mode sw - SUBSYSTEM
    input logic ipi_i,
    // debug request in - ID_STAGE
    input logic debug_req_i,
    // TO_BE_COMPLETED - FRONTEND
    output logic set_debug_pc_o,
    // trap virtual memory - ID_STAGE
    output logic tvm_o,
    // timeout wait - ID_STAGE
    output logic tw_o,
    // virtual timeout wait - ID_STAGE
    output logic vtw_o,
    // trap sret - ID_STAGE
    output logic tsr_o,
    // hypervisor user mode - ID_STAGE
    output logic hu_o,
    // we are in debug mode -> that will change some decoding - EX_STAGE
    output logic debug_mode_o,
    // we are in single-step mode - COMMIT_STAGE
    output logic single_step_o,
    // L1 ICache Enable - CACHE
    output logic icache_en_o,
    // L1 DCache Enable - CACHE
    output logic dcache_en_o,
    output logic dcache_scrub_en_o,
    output logic [5:0] dcache_scrub_period_o,
    input logic dcache_scrub_cycle_i,
    input logic dcache_dat_cor_err_i,
    input logic dcache_dat_unc_err_i,
    input logic dcache_dir_cor_err_i,
    input logic dcache_dir_unc_err_i,
    // Accelerator memory consistent mode - ACC_DISPATCHER
    output logic acc_cons_en_o,
    // read/write address to performance counter module - PERF_COUNTERS
    output logic [11:0] perf_addr_o,
    // write data to performance counter module - PERF_COUNTERS
    output logic [CVA6Cfg.XLEN-1:0] perf_data_o,
    // read data from performance counter module - PERF_COUNTERS
    input logic [CVA6Cfg.XLEN-1:0] perf_data_i,
    // TO_BE_COMPLETED - PERF_COUNTERS
    output logic perf_we_o,
    // PMP configuration containing pmpcfg for max 64 PMPs - ACC_DISPATCHER
    output riscv::pmpcfg_t [avoid_neg(CVA6Cfg.NrPMPEntries-1):0] pmpcfg_o,
    // PMP addresses - ACC_DISPATCHER
    output logic [avoid_neg(CVA6Cfg.NrPMPEntries-1):0][CVA6Cfg.PLEN-3:0] pmpaddr_o,
    // TO_BE_COMPLETED - PERF_COUNTERS
    output logic [31:0] mcountinhibit_o,
    // RVFI
    output rvfi_probes_csr_t rvfi_csr_o,
    //jvt output
    output jvt_t jvt_o,
    // trigger module signals
    input logic [CVA6Cfg.VLEN-1:0] sdtrig_lsu_inputs_vaddr_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_lsu_inputs_data_i,
    input logic sdtrig_lsu_inputs_fu_i,
    input logic sdtrig_lsu_inputs_valid_i,
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_load_data_i,
    input logic sdtrig_load_valid_i,

    //LSU <-> trigger module commmunication
    output logic sdtrig_load_stall_o,
    output logic sdtrig_load_cancel_o,
    output logic [CVA6Cfg.XLEN-1:0] sdtrig_load_action_o,
    output logic sdtrig_store_stall_o,
    output logic [CVA6Cfg.XLEN-1:0] sdtrig_store_action_o,

    //Decoder/fetch <-> trigger module communication
    input logic [CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.VLEN-1:0] fetch_sdtrig_pc_i,
    input logic [CVA6Cfg.NrIssuePorts-1:0][31:0] fetch_sdtrig_instr_i,
    output logic [CVA6Cfg.XLEN-1:0] sdtrig_decoder_action_o[CVA6Cfg.NrIssuePorts],

    //Commit <- trigger module
    output logic sdtrig_commit_icount_valid_o,
    output logic [$clog2(CVA6Cfg.NrCommitPorts)-1:0] sdtrig_commit_icount_nr_instr_o,
    output logic [CVA6Cfg.XLEN-1:0] sdtrig_commit_action_o,
    output logic sdtrig_commit_std_exception_valid_o
);
```

## Parent instantiation

```systemverilog
  csr_regfile #(
      .CVA6Cfg           (CVA6Cfg),
      .exception_t       (exception_t),
      .jvt_t             (jvt_t),
      .irq_ctrl_t        (irq_ctrl_t),
      .scoreboard_entry_t(scoreboard_entry_t),
      .rvfi_probes_csr_t (rvfi_probes_csr_t),
      .MHPMCounterNum    (MHPMCounterNum)
  ) csr_regfile_i (
      .clk_i,
      .rst_ni,
      .time_irq_i,
      .flush_o                            (flush_csr_ctrl),
      .halt_csr_o                         (halt_csr_ctrl),
      .commit_instr_i                     (commit_instr_id_commit[0]),
      .commit_ack_i                       (commit_ack),
      .boot_addr_i                        (boot_addr_i[CVA6Cfg.VLEN-1:0]),
      .hart_id_i                          (hart_id_i[CVA6Cfg.XLEN-1:0]),
      .ex_i                               (ex_commit),
      .csr_op_i                           (csr_op_commit_csr),
      .csr_addr_i                         (csr_addr_ex_csr),
      .csr_wdata_i                        (csr_wdata_commit_csr),
      .csr_rdata_o                        (csr_rdata_csr_commit),
      .dirty_fp_state_i                   (dirty_fp_state),
      .csr_write_fflags_i                 (csr_write_fflags_commit_cs),
      .dirty_v_state_i                    (dirty_v_state),
      .pc_i                               (pc_commit),
      .csr_exception_o                    (csr_exception_csr_commit),
      .epc_o                              (epc_commit_pcgen),
      .eret_o                             (eret),
      .trap_vector_base_o                 (trap_vector_base_commit_pcgen),
      .priv_lvl_o                         (priv_lvl),
      .mbe_o                              (mbe),
      .v_o                                (v),
      .acc_fflags_ex_i                    (acc_resp_fflags),
      .acc_fflags_ex_valid_i              (acc_resp_fflags_valid),
      .fs_o                               (fs),
      .vfs_o                              (vfs),
      .fflags_o                           (fflags_csr_commit),
      .frm_o                              (frm_csr_id_issue_ex),
      .fprec_o                            (fprec_csr_ex),
      .vs_o                               (vs),
      .irq_ctrl_o                         (irq_ctrl_csr_id),
      .en_translation_o                   (enable_translation_csr_ex),
      .en_g_translation_o                 (enable_g_translation_csr_ex),
      .en_ld_st_translation_o             (en_ld_st_translation_csr_ex),
      .en_ld_st_g_translation_o           (en_ld_st_g_translation_csr_ex),
      .ld_st_priv_lvl_o                   (ld_st_priv_lvl_csr_ex),
      .ld_st_v_o                          (ld_st_v_csr_ex),
      .csr_hs_ld_st_inst_i                (csr_hs_ld_st_inst_ex),
      .sum_o                              (sum_csr_ex),
      .vs_sum_o                           (vs_sum_csr_ex),
      .mxr_o                              (mxr_csr_ex),
      .vmxr_o                             (vmxr_csr_ex),
      .satp_ppn_o                         (satp_ppn_csr_ex),
      .asid_o                             (asid_csr_ex),
      .vsatp_ppn_o                        (vsatp_ppn_csr_ex),
      .vs_asid_o                          (vs_asid_csr_ex),
      .hgatp_ppn_o                        (hgatp_ppn_csr_ex),
      .vmid_o                             (vmid_csr_ex),
      .irq_i,
      .ipi_i,
      .debug_req_i,
      .set_debug_pc_o                     (set_debug_pc),
      .tvm_o                              (tvm_csr_id),
      .tw_o                               (tw_csr_id),
      .vtw_o                              (vtw_csr_id),
      .tsr_o                              (tsr_csr_id),
      .hu_o                               (hu),
      .debug_mode_o                       (debug_mode),
      .single_step_o                      (single_step_csr_commit),
      .icache_en_o                        (icache_en_csr),
      .dcache_en_o                        (dcache_en_csr),
      .dcache_scrub_en_o                  (dcache_scrub_en_csr),
      .dcache_scrub_period_o              (dcache_scrub_period_csr),
      .dcache_scrub_cycle_i               (dcache_scrub_cycle_csr),
      .dcache_dat_cor_err_i               (dcache_dat_cor_err_csr),
      .dcache_dat_unc_err_i               (dcache_dat_unc_err_csr),
      .dcache_dir_cor_err_i               (dcache_dir_cor_err_csr),
      .dcache_dir_unc_err_i               (dcache_dir_unc_err_csr),
      .acc_cons_en_o                      (acc_cons_en_csr),
      .perf_addr_o                        (addr_csr_perf),
      .perf_data_o                        (data_csr_perf),
      .perf_data_i                        (data_perf_csr),
      .perf_we_o                          (we_csr_perf),
      .pmpcfg_o                           (pmpcfg),
      .pmpaddr_o                          (pmpaddr),
      .mcountinhibit_o                    (mcountinhibit_csr_perf),
      .mcbie_o                            (mcbie),
      .scbie_o                            (scbie),
      .hcbie_o                            (hcbie),
      .mcbcfe_o                           (mcbcfe),
      .scbcfe_o                           (scbcfe),
      .hcbcfe_o                           (hcbcfe),
      .jvt_o                              (jvt),
      //RVFI
      .rvfi_csr_o                         (rvfi_csr),
      // Trigger Signals
      .sdtrig_commit_std_exception_valid_o(sdtrig_commit_std_exception_valid),
      //Decoder/FE <-> Trigger Module
      .fetch_sdtrig_pc_i                  (fetch_sdtrig_pc),
      .fetch_sdtrig_instr_i               (fetch_sdtrig_instr),
      .sdtrig_decoder_action_o            (sdtrig_decoder_action),
      //Load/Store Unit <-> Trigger Module
      .sdtrig_lsu_inputs_vaddr_i          (sdtrig_lsu_inputs_operand_a),
      .sdtrig_lsu_inputs_data_i           (sdtrig_lsu_inputs_operand_c),
      .sdtrig_lsu_inputs_fu_i             (sdtrig_lsu_inputs_we),
      .sdtrig_lsu_inputs_valid_i          (sdtrig_lsu_inputs_valid),
      .sdtrig_load_data_i                 (load_result_ex_id),
      .sdtrig_load_valid_i                (load_valid_ex_id),
      .sdtrig_load_stall_o                (sdtrig_load_stall),
      .sdtrig_load_cancel_o               (sdtrig_load_cancel),
      .sdtrig_load_action_o               (sdtrig_load_action),
      .sdtrig_store_stall_o               (sdtrig_store_stall),
      .sdtrig_store_action_o              (sdtrig_store_action),
      //Commit <- Trigger module
      .sdtrig_commit_icount_valid_o       (sdtrig_commit_icount_valid),
      .sdtrig_commit_action_o             (sdtrig_commit_action),
      .sdtrig_commit_icount_nr_instr_o    (sdtrig_commit_icount_nr_instr)
  );
```

## Dependency declarations

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
```

### core/include/ariane_pkg.sv

```systemverilog
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
```

### core/include/riscv_pkg.sv

```systemverilog
  typedef enum logic [1:0] {
    PRIV_LVL_M  = 2'b11,
    PRIV_LVL_HS = 2'b10,
    PRIV_LVL_S  = 2'b01,
    PRIV_LVL_U  = 2'b00
  } priv_lvl_t;

// ...

  typedef enum logic [1:0] {
    Off     = 2'b00,
    Initial = 2'b01,
    Clean   = 2'b10,
    Dirty   = 2'b11
  } xs_t;

  typedef enum logic [1:0] {
    CBIE_ILLEGAL = 2'b00, // execution of CBO.INVAL in lower privilege mode causes illegal instruction / virtual instruction exception
    CBIE_FLUSH = 2'b01,  // CBO.INVAL causes flush
    CBIE_RSVD = 2'b10,  // reserved
    CBIE_INVAL = 2'b11  // CBO.INVAL causes invalidate
  } cbie_t;

// ...

  typedef enum logic [1:0] {
    OFF   = 2'b00,
    TOR   = 2'b01,
    NA4   = 2'b10,
    NAPOT = 2'b11
  } pmp_addr_mode_t;

  // PMP Access Type
  typedef enum logic [2:0] {
    ACCESS_NONE  = 3'b000,
    ACCESS_READ  = 3'b001,
    ACCESS_WRITE = 3'b010,
    ACCESS_EXEC  = 3'b100
  } pmp_access_t;

  typedef struct packed {
    logic x;
    logic w;
    logic r;
  } pmpcfg_access_t;

  // packed struct of a PMP configuration register (8bit)
  typedef struct packed {
    logic           locked;       // lock this configuration
    logic [1:0]     reserved;
    pmp_addr_mode_t addr_mode;    // Off, TOR, NA4, NAPOT
    pmpcfg_access_t access_type;
  } pmpcfg_t;
```

## Related source code

### core/cva6_rvfi.sv

```systemverilog
  localparam logic [CVA6Cfg.XLEN-1:0] IsaCode =
    (CVA6Cfg.XLEN'(CVA6Cfg.RVA) << 0)   // A - Atomic Instructions extension
  | (CVA6Cfg.XLEN'(CVA6Cfg.RVB) << 1)  // C - Bitmanip extension
  | (CVA6Cfg.XLEN'(CVA6Cfg.RVC) << 2)  // C - Compressed extension
  | (CVA6Cfg.XLEN'(CVA6Cfg.RVD) << 3)  // D - Double precision floating-point extension
  | (CVA6Cfg.XLEN'(CVA6Cfg.RVF) << 5)  // F - Single precision floating-point extension
  | (CVA6Cfg.XLEN'(CVA6Cfg.RVH) << 7)  // H - Hypervisor extension
  | (CVA6Cfg.XLEN'(1) << 8)  // I - RV32I/64I/128I base ISA
  | (CVA6Cfg.XLEN'(1) << 12)  // M - Integer Multiply/Divide extension
  | (CVA6Cfg.XLEN'(0) << 13)  // N - User level interrupts supported
  | (CVA6Cfg.XLEN'(CVA6Cfg.RVS) << 18)  // S - Supervisor mode implemented
  | (CVA6Cfg.XLEN'(CVA6Cfg.RVU) << 20)  // U - User mode implemented
  | (CVA6Cfg.XLEN'(CVA6Cfg.RVV) << 21)  // V - Vector extension
  | (CVA6Cfg.XLEN'(CVA6Cfg.NSX) << 23)  // X - Non-standard extensions present
  | ((CVA6Cfg.IS_XLEN64 ? 2 : 1) << CVA6Cfg.XLEN - 2);  // MXL
```

### core/cva6.sv

```systemverilog
  // ------------------------
  // Performance Counters
  // ------------------------
  if (CVA6Cfg.PerfCounterEn) begin : gen_perf_counter
    perf_counters #(
        .CVA6Cfg(CVA6Cfg),
        .bp_resolve_t(bp_resolve_t),
        .exception_t(exception_t),
        .scoreboard_entry_t(scoreboard_entry_t),
        .icache_dreq_t(icache_dreq_t),
        .dcache_req_i_t(dcache_req_i_t),
        .dcache_req_o_t(dcache_req_o_t),
        .NumPorts(NumPorts)
    ) perf_counters_i (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .debug_mode_i  (debug_mode),
        .addr_i        (addr_csr_perf),
        .we_i          (we_csr_perf),
        .data_i        (data_csr_perf),
        .data_o        (data_perf_csr),
        .commit_instr_i(commit_instr_id_commit),
        .commit_ack_i  (commit_ack),

        .l1_icache_miss_i   (icache_miss_cache_perf),
        .l1_dcache_miss_i   (dcache_miss_cache_perf),
        .itlb_miss_i        (itlb_miss_ex_perf),
        .dtlb_miss_i        (dtlb_miss_ex_perf),
        .sb_full_i          (sb_full),
        // TODO this is more complex that that
        // If superscalar then we additionally have to check [1] when transaction 0 succeeded
        .if_empty_i         (~fetch_valid_if_id[0]),
        .ex_i               (ex_commit),
        .eret_i             (eret),
        .resolved_branch_i  (resolved_branch),
        .branch_exceptions_i(flu_exception_ex_id),
        .l1_icache_access_i (icache_dreq_if_cache),
        .l1_dcache_access_i (dcache_req_ports_ex_cache),
        .miss_vld_bits_i    (miss_vld_bits),
        .i_tlb_flush_i      (flush_tlb_ctrl_ex),
        .stall_issue_i      (stall_issue),
        .mcountinhibit_i    (mcountinhibit_csr_perf)
    );
  end : gen_perf_counter
  else begin : gen_no_perf_counter
    assign data_perf_csr = '0;
  end : gen_no_perf_counter

// ...

  end else if (
        CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT ||
        CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WB ||
        CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT_WB
  )
  begin : gen_cache_hpd
    cva6_hpdcache_subsystem #(
        .CVA6Cfg   (CVA6Cfg),
        .icache_areq_t(icache_areq_t),
        .icache_arsp_t(icache_arsp_t),
        .icache_dreq_t(icache_dreq_t),
        .icache_drsp_t(icache_drsp_t),
        .icache_req_t(icache_req_t),
        .icache_rtrn_t(icache_rtrn_t),
        .dcache_req_i_t(dcache_req_i_t),
        .dcache_req_o_t(dcache_req_o_t),
        .NumPorts  (NumPorts),
        .axi_ar_chan_t(axi_ar_chan_t),
        .axi_aw_chan_t(axi_aw_chan_t),
        .axi_w_chan_t (axi_w_chan_t),
        .axi_b_chan_t (b_chan_t),
        .axi_r_chan_t (r_chan_t),
        .noc_req_t (noc_req_t),
        .noc_resp_t(noc_resp_t)
    ) i_cache_subsystem (
        .clk_i (clk_i),
        .rst_ni(rst_ni),

        .icache_en_i   (icache_en_csr),
        .icache_flush_i(icache_flush_ctrl_cache),
        .icache_miss_o (icache_miss_cache_perf),
        .icache_areq_i (icache_areq_ex_cache),
        .icache_areq_o (icache_areq_cache_ex),
        .icache_dreq_i (icache_dreq_if_cache),
        .icache_dreq_o (icache_dreq_cache_if),

        .dcache_enable_i      (dcache_en_csr),
        .dcache_flush_i       (dcache_flush_ctrl_cache),
        .dcache_flush_ack_o   (dcache_flush_ack_cache_ctrl),
        .dcache_miss_o        (dcache_miss_cache_perf),
        .dcache_scrub_enable_i(dcache_scrub_en_csr),
        .dcache_scrub_period_i(dcache_scrub_period_csr),
        .dcache_scrub_cycle_o (dcache_scrub_cycle_csr),
        .dcache_dat_cor_err_o (dcache_dat_cor_err_csr),
        .dcache_dat_unc_err_o (dcache_dat_unc_err_csr),
        .dcache_dir_cor_err_o (dcache_dir_cor_err_csr),
        .dcache_dir_unc_err_o (dcache_dir_unc_err_csr),
```

## Documentation

### docs/csr-from-ip-xact/cv32a60x/cv32a60mx_csr.md

```text
# CSR REGISTERS : CV32A6 
### Unimplemented CSR accessing generates an illegal instruction exception.
### Read-Only CSR write access generates an illegal instruction exception.

...

## MSTATUS : Machine Status Register 
### *AddressOffset*: 'h300 
### *Description*:
The ``mstatus`` register keeps track of and controls the hart’s current operating state.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31 | SD | State dirty | 0x0 | read-only,WARL  | The SD bit is a read\-only bit\.``Legal Values``:0\. // ``Enumerated Values``( "Not_Dirty" :0 ) ( "Dirty" :1 ) |
| 30:23 | reserved_0 | Reserved | 0x0 | read-write,WPRI  | Reserved|
| 22 | TSR | Trap sret | 0x0 | read-write,WARL  | The TSR bit supports intercepting the supervisor exception return instruction, SRET\. // ``Enumerated Values``( "Permitted" :0 ) ( "Not_Permitted" :1 ) |
| 21 | TW | Timeout wait | 0x0 | read-write,WARL  | The TW bit supports intercepting the WFI instruction\. // ``Enumerated Values``( "Permitted" :0 ) ( "Not_Permitted" :1 ) |
| 20 | TVM | Trap virtual memory | 0x0 | read-write,WARL  | The TVM bit supports intercepting supervisor virtual\-memory management operations\. // ``Enumerated Values``( "Permitted" :0 ) ( "Not_Permitted" :1 ) |
| 19 | MXR | Make executable readable | 0x0 | read-write  | The MXR bit modifies the privilege with which loads access virtual memory\. // ``Enumerated Values``( "Not_Executable" :0 ) ( "Executable" :1 ) |
| 18 | SUM | Supervisor user memory | 0x0 | read-write  | The SUM bit modifies the privilege with which S\-mode loads and stores access virtual memory\. // ``Enumerated Values``( "Not_Permitted" :0 ) ( "Permitted" :1 ) |
| 17 | MPRV | Modify privilege | 0x0 | read-write  | The MPRV bit modifies the privilege mode at which loads and stores execute\. // ``Enumerated Values``( "Normal" :0 ) ( "Protected" :1 ) |
| 16:15 | XS | Extension state | 0x0 | read-only,WARL  | The XS field encodes the status of the additional user\-mode extensions and associated state\.``Legal Values``:0\. // ``Enumerated Values``( "Off" :0 ) ( "Initial" :1 ) ( "Clean" :2 ) ( "Dirty" :3 ) |
| 14:13 | FS | Floating-point unit state | 0x0 | read-only,WARL  | FS extension is not supported\.``Legal Values``:0\. // ``Enumerated Values``( "Off" :0 ) ( "Initial" :1 ) ( "Clean" :2 ) ( "Dirty" :3 ) |
| 12:11 | MPP | Machine mode prior privilege | 0x0 | read-write  | Holds the previous privilege mode for machine mode\. // ``Enumerated Values``( "U-mode" :0 ) ( "S-mode" :1 ) ( "Reserved" :2 ) ( "M-mode" :3 ) |
| 10:9 | VS | Vector extension state | 0x0 | read-only,WARL  | V extension is not supported\.``Legal Values``:0\.|
| 8 | SPP | Supervisor mode prior privilege | 0x0 | read-write  | Holds the previous privilege mode for supervisor mode\. // ``Enumerated Values``( "U-mode" :0 ) ( "Otherwise" :1 ) |
| 7 | MPIE | Machine mode prior interrupt enable | 0x0 | read-write  | Indicates whether machine interrupts were enabled prior to trapping into machine mode\. // ``Enumerated Values``( "Disabled" :0 ) ( "Enabled" :1 ) |
| 6 | UBE | User mode bit endianness | 0x0 | read-write,WARL  | UBE controls whether explicit load and store memory accesses made from U\-mode are little\-endian or big\-endian\.``Legal Values``:0\. // ``Enumerated Values``( "Little-endian" :0 ) ( "Big-endian" :1 ) |
| 5 | SPIE | Supervisor mode prior interrupt enable | 0x0 | read-write  | Indicates whether supervisor interrupts were enabled prior to trapping into supervisor mode\. // ``Enumerated Values``( "Disabled" :0 ) ( "Enabled" :1 ) |
| 4 | reserved_1 | Reserved | 0x0 | read-write,WPRI  | Reserved|
| 3 | MIE | Machine mode interrupt enable | 0x0 | read-write  | Global interrupt\-enable bit for Machine mode\. // ``Enumerated Values``( "Disabled" :0 ) ( "Enabled" :1 ) |
| 2 | reserved_2 | Reserved | 0x0 | read-write,WPRI  | Reserved|
| 1 | SIE | Supervisor mode interrupt enable | 0x0 | read-write  | Global interrupt\-enable bit for Supervisor mode\. // ``Enumerated Values``( "Disabled" :0 ) ( "Enabled" :1 ) |
| 0 | reserved_3 | Reserved | 0x0 | read-write,WPRI  | Reserved|

...

## MIE : Machine Interrupt Enable Register 
### *AddressOffset*: 'h304 
### *Description*:
This register contains machine interrupt enable bits.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 15:12 | Reserved_12 | Reserved | 0x0 | read-write,WARL  | Reserved\.``Legal Values:``0\.|
| 11 | MEIE | M-mode external interrupt enable | 0x0 | read-write,WARL  | Enables machine mode external interrupts\.|
| 10 | Reserved_10 | Reserved | 0x0 | read-write,WARL  | Reserved\.``Legal Values:``0\.|
| 9 | SEIE | S-mode external interrupt enable | 0x0 | read-write,WARL  | Enables supervisor mode external interrupts\.|
| 8 | UEIE |  | 0x0 | read-write,WARL  | enables U\-mode external interrupts\.``Legal Values:``0\.|
| 7 | MTIE | M-mode timer interrupt enable | 0x0 | read-write,WARL  | Enables machine mode timer interrupts\.|
| 6 | Reserved_6 | Reserved | 0x0 | read-write,WARL  | Reserved\.``Legal Values:``0\.|
| 5 | STIE | S-mode timer interrupt enable | 0x0 | read-write,WARL  | Enables supervisor mode timer interrupts\.|
| 4 | UTIE |  | 0x0 | read-write,WARL  | timer interrupt\-enable bit for U\-mode\.``Legal Values:``0\.|
| 3 | MSIE | M-mode software interrupt enable | 0x0 | read-write  | Enables machine mode software interrupts\.|
| 2 | Reserved_2 | Reserved | 0x0 | read-write,WARL  | Reserved\.``Legal Values:``0\.|
| 1 | SSIE | S-mode software interrupt enable | 0x0 | read-write,WARL  | Enables supervisor mode software interrupts\.|
| 0 | USIE |  | 0x0 | read-write,WARL  | enable U\-mode software interrupts\.``Legal Values:``0\.|

## MTVEC : Machine Trap Vector Register 
### *AddressOffset*: 'h305 
### *Description*:
This register holds trap vector configuration, consisting of a vector base address and a vector mode.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:2 | BASE |  | 0x0 | read-write,WARL  | The BASE field in mtvec is a WARL field that can hold any valid virtual or physical address, subject to the following alignment constraints: when MODE=Direct the address must be 4\-byte aligned, and when MODE=Vectored the address must be 256\-byte aligned\.|
| 1:0 | MODE |  | 0x0 | read-write,WARL  | Imposes additional alignment constraints on the value in the BASE field\.``Legal Values :``0,1\. // ``Enumerated Values``( "Direct" :0 ) ( "Vectored" :1 ) ( "Reserved_2" :2 ) ( "Reserved_3" :3 ) |

## MSTATUSH : Upper 32-bits of Machine Status Register 
### *AddressOffset*: 'h310 
### *Description*:
The ``mstatush`` is the upper 32-bits of Machine status only for RV32.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 3:0 | reserved_0 | Reserved | 0x0 | read-write,WPRI  | Reserved|
| 4 | SBE | Supervisor mode bit endianness | 0x0 | read-write,WARL  | SBE controls whether explicit load and store memory accesses made from S\-mode are little\-endian or big\-endian\.``Legal Values``:0\. // ``Enumerated Values``( "Little-endian" :0 ) ( "Big-endian" :1 ) |
| 5 | MBE | Machine mode bit endianness | 0x0 | read-write,WARL  | MBE controls whether explicit load and store memory accesses made from M\-mode are little\-endian or big\-endian\.``Legal Values``:0\. // ``Enumerated Values``( "Little-endian" :0 ) ( "Big-endian" :1 ) |
| 31:6 | reserved_1 | Reserved | 0x0 | read-write,WPRI  | Reserved|

## MHPMEVENT3 : Machine Hardware Performance-Monitoring Event Selector Register 
### *AddressOffset*: 'h323 
### *Description*:
This register controls which event causes the corresponding counter to increment.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | mhpmevent |  | 0x0 | WARL  | Event selector CSRs\.``Legal Values``:0\.|

...

## MSCRATCH : Machine Scratch Register 
### *AddressOffset*: 'h340 
### *Description*:
This register is used to hold a value dedicated to Machine mode. Attempts to access without Machine mode level raise illegal instruction exception.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | mscratch | Machine scratch | 0x0 | read-write  | Holds a value dedicated to Machine mode\.|

## MEPC : Machine Exception Program Counter Register 
### *AddressOffset*: 'h341 
### *Description*:
This register must be able to hold all valid virtual addresses.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | mepc | Machine exception program counter | 0x0 | read-write,WARL  | When a trap is taken into M\-mode, ``mepc`` is written with the virtual address of the instruction that was interrupted or that encountered the exception\.|

## MCAUSE : Machine Cause Register 
### *AddressOffset*: 'h342 
### *Description*:
When a trap is taken into M-mode, mcause is written with a code indicating the event that caused the trap.
Machine cause register (``mcause``) values after trap are shown in the following table.
|Interrupt|Exception Code|Description|
|---------|--------------|-----------|
|1|0|*Reserved*|
|1|1|Supervisor software interrupt|
|1|2-4|*Reserved*|
|1|5|Supervisor timer interrupt|
|1|6-8|*Reserved*|
|1|9|Supervisor external interrupt|
|1|10-15|*Reserved*|
|1|≥16|*Designated for platform use*|
|0|0|Instruction address misaligned|
|0|1|Instruction access fault|
|0|2|Illegal instruction|
|0|3|Breakpoint|
|0|4|Load address misaligned|
|0|5|Load access fault|
|0|6|Store/AMO address misaligned|
|0|7|Store/AMO access fault|
|0|8|Environment call from U-mode|
|0|9|Environment call from S-mode|
|0|10-11|*Reserved*|
|0|12|Instruction page fault|
|0|13|Load page fault|
|0|14|*Reserved*|
|0|15|Store/AMO page fault|
|0|16-23|*Reserved*|
|0|24-31|*Designated for custom use*|
|0|32-47|*Reserved*|
|0|48-63|*Designated for custom use*|
|0|≥64|*Reserved*|

| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31 | Interrupt | Interrupt | 0x0 | read-write  | This bit is set if the trap was caused by an interrupt\.|
| 30:0 | exception_code | Exception code | 0x0 | read-write,WLRL  | This field contains a code identifying the last exception or interrupt\.|

## MTVAL : Machine Trap Value Register 
### *AddressOffset*: 'h343 
### *Description*:
When a trap is taken into M-mode, mtval is either set to zero or written with exception-specific information to assist software in handling the trap.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | mtval | Machine trap value | 0x0 | read-write,WARL  | If ``mtval`` is written with a nonzero value when a breakpoint, address\-misaligned, access\-fault, or page\-fault exception occurs on an instruction fetch, load, or store, then mtval will contain the faulting virtual address\. If ``mtval`` is written with a nonzero value when a misaligned load or store causes an access\-fault or page\-fault exception, then ``mtval`` will contain the virtual address of the portion of the access that caused the fault\. If ``mtval`` is written with a nonzero value when an instruction access\-fault or page\-fault exception occurs on a system with variable\-length instructions, then ``mtval`` will contain the virtual address of the portion of the instruction that caused the fault, while ``mepc`` will point to the beginning of the instruction\.|

## MIP : Machine Interrupt Pending Register 
### *AddressOffset*: 'h344 
### *Description*:
This register contains machine interrupt pending bits.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 15:12 | Reserved_12 | Reserved | 0x0 | read-write,WARL  | Reserved\.``Legal Values:``0\.|
| 11 | MEIP | M-mode external interrupt pending | 0x0 | read-only  | The interrupt\-pending bit for machine\-level external interrupts\.|
| 10 | Reserved_10 | Reserved | 0x0 | read-write,WARL  | Reserved\.``Legal Values:``0\.|
| 9 | SEIP | S-mode external interrupt pending | 0x0 | read-write  | The interrupt\-pending bit for supervisor\-level external interrupts\.|
| 8 | UEIP |  | 0x0 | read-write  | enables external interrupts\.``Legal Values:``0\.|
| 7 | MTIP | M-mode timer interrupt pending | 0x0 | read-only  | The interrupt\-pending bit for machine\-level timer interrupts\.|
| 6 | Reserved_6 | Reserved | 0x0 | read-write,WARL  | Reserved\.``Legal Values:``0\.|
| 5 | STIP | S-mode timer interrupt pending | 0x0 | read-write  | The interrupt\-pending bit for supervisor\-level timer interrupts\.|
| 4 | UTIP |  | 0x0 | read-write  | Correspond to timer interrupt\-pending bits for user interrupt\.``Legal Values:``0\.|
| 3 | MSIP | M-mode software interrupt pending | 0x0 | read-only  | The interrupt\-pending bit for machine\-level software interrupts\.|
| 2 | Reserved_2 | Reserved | 0x0 | read-write,WARL  | Reserved\.``Legal Values:``0\.|
| 1 | SSIP | S-mode software interrupt pending | 0x0 | read-write  | The interrupt\-pending bit for supervisor\-level software interrupts\.|
| 0 | USIP |  | 0x0 | read-write  | A hart to directly write its own USIP bits when running in the appropriate mode\.``Legal Values:``0\.|

...

## ICACHE : Instruction Cache Register 
### *AddressOffset*: 'h7C0 
### *Description*:
Custom Register to enable/disable for Icache [bit 0]
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:1 | reserved_0 | Reserved | 0x0 | read-only  | Reserved|
| 0 | icache | Instruction cache | 0x1 | read-write  | Custom Register|

## MCYCLE : M-mode Cycle counter Register 
### *AddressOffset*: 'hB00 
### *Description*:
Counts the number of clock cycles executed by the processor core on which the hart is running.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | count | Count | 0x0 | read-write  | Counts the number of clock cycles executed by the processor core\.|

## MINSTRET : Machine Instruction Retired counter Register 
### *AddressOffset*: 'hB02 
### *Description*:
Counts the number of instructions the hart has retired.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | count | Count | 0x0 | read-write  | Counts the number of instructions the hart has retired\.|

## MCYCLEH : Upper 32-bits of M-mode Cycle counter Register 
### *AddressOffset*: 'hB80 
### *Description*:
Counts the number of clock cycles executed by the processor core on which the hart is running.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | count | Count | 0x0 | read-write  | Counts the number of clock cycles executed by the processor core\.|

## MINSTRETH : Upper 32-bits of Machine Instruction Retired counter Register 
### *AddressOffset*: 'hB82 
### *Description*:
Counts the number of instructions the hart has retired.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | count | Count | 0x0 | read-write  | Counts the number of instructions the hart has retired\.|

...

## MHPMCOUNTER3 : Machine Hardware Performance Monitoring Counter Register 
### *AddressOffset*: 'hb03 
### *Description*:
Hardware performance event counter.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | count | Count | 0x0 | WARL  | ``Legal Values``: 0\.|

...

## MVENDORID : Machine Vendor ID Register 
### *AddressOffset*: 'hF11 
### *Description*:
This register provides the JEDEC manufacturer ID of the provider of the core.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:7 | bank | Bank | 0xC | read-only  | Contain encoding for number of one\-byte continuation codes discarding the parity bit\.|
| 6:0 | offset | Offset | 0x2 | read-only  | Contain encoding for the final byte discarding the parity bit\.|

## MARCHID : Machine Architecture ID Register 
### *AddressOffset*: 'hF12 
### *Description*:
This register encodes the base microarchitecture of the hart.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | architecture_id | Architecture id | 0x3 | read-only  | Provide Encoding the base microarchitecture of the hart\.|

## MIMPID : Machine Implementation ID Register 
### *AddressOffset*: 'hF13 
### *Description*:
Provides a unique encoding of the version of the processor implementation.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | implementation | Implementation | 0x0 | read-only  | Provides unique encoding of the version of the processor implementation\.|

## MHARTID : Machine Hardware Thread ID Register 
### *AddressOffset*: 'hF14 
### *Description*:
This register contains the integer ID of the hardware thread running the code.
| BIT |  NAME       | displayName        |Reset| RIGHT  | Description                                                          |
| --- | ----------- | ------------       |-----| ------ | -------------------------------------------------------------------- |
| 31:0 | hart_id | Hart id | 0x0 | read-only  | Contains the integer ID of the hardware thread running the code\.|
```

### docs/csr-from-ip-xact/cv32a60x/csr_list.rst

```text
CSR list
========

.. csv-table::
   :widths: auto
   :align: left
   :header: "Name", "Display Name", "Address Offset"

   "``MSTATUS``", "Machine Status Register", "0x300"
   "``MISA``", "Machine ISA Register", "0x301"
   "``MIE``", "Machine Interrupt Enable Register", "0x304"
   "``MTVEC``", "Machine Trap Vector Register", "0x305"
   "``MSTATUSH``", "Upper 32-bits of Machine Status Register", "0x310"
   "``MHPMEVENT3-31``", "Machine HW Perf Monitoring Event Selector", "0x323-0x33f"
   "``MSCRATCH``", "Machine Scratch", "0x340"
   "``MEPC``", "Machine Exception Program Counter", "0x341"
   "``MCAUSE``", "Machine Cause", "0x342"
   "``MTVAL``", "Machine Trap Value", "0x343"
   "``MIP``", "Machine Interrupt Pending", "0x344"
   "``PMPCFG0-3``", "Physical Memory Protection Config 0", "0x3a0-0x3a3"
   "``PMPADDR0-15``", "Physical Memory Protection Address", "0x3b0-0x3bf"
   "``ICACHE``", "Instruction Cache", "0x7C0"
   "``MCYCLE``", "M-mode Cycle counter", "0xB00"
   "``MINSTRET``", "Machine Instruction Retired counter", "0xB02"
   "``MCYCLEH``", "Upper 32-bits of M-mode Cycle counter", "0xB80"
   "``MINSTRETH``", "Upper 32-bits of Machine Instruction Retired counter", "0xB82"
   "``MHPMCOUNTER3-31``", "Machine HW Performance Monitoring Counter", "0xb03-0xb1f"
   "``MHPMCOUNTERH3-31``", "Upper 32 bits of Machine HW Perf Monitoring Counter", "0xb83-0xb9f"
   "``CYCLE``", "Cycle counter", "0xC00"
   "``INSTRET``", "Instruction Retired counter", "0xC02"
   "``CYCLEH``", "Upper 32-bits of Cycle counter", "0xC80"
   "``INSTRETH``", "Upper 32-bits of Instruction Retired counter", "0xC82"
   "``MVENDORID``", "Machine Vendor ID", "0xF11"
   "``MARCHID``", "Machine Architecture ID", "0xF12"
   "``MIMPID``", "Machine Implementation ID", "0xF13"
   "``MHARTID``", "Machine HW Thread ID", "0xF14"
```

### docs/01_cva6_user/RISCV_Instructions_RVZicsr.rst

```text
*Applicability of this chapter to configurations:*

This chapter is applicable to all CVA6 configurations.

**Note**: RV32Zicsr and RV64Zicsr are identical.

RVZicsr Control and Status Register Instructions
---------------------------------------------------

All CSR instructions atomically read-modify-write a single CSR, whose CSR specifier is encoded in the 12-bit csr field of the instruction held in bits 31–20. The immediate forms use a 5-bit zero-extended immediate encoded in the rs1 field.

- **CSRRW**: Control and Status Register Read and Write

    **Format**: csrrw rd, csr, rs1

    **Description**: reads the old value of the CSR, zero-extends the value to 32 bits, then writes it to integer register rd, the initial value in rs1 is written to the CSR. If rd=x0, then the instruction shall not read the CSR and shall not cause any of the side-effects that might occur on a CSR read.

    **Pseudocode**: t = CSRs[csr]; CSRs[csr] = x[rs1]; x[rd] = t

    **Invalid values**: NONE

    **Exception raised**: attempts to access a non-existent CSR raise an illegal instruction exception, attempts to access a CSR without appropriate privilege level or to write a read-only register also raise illegal instruction exceptions.

- **CSRRS**: Control and Status Register Read and Set

    **Format**: csrrs rd, csr, rs1

    **Description**: reads the value of the CSR, zero-extends the value to 32 bits, and writes it to integer register rd, the initial value in integer register rs1 is treated as a bit mask that specifies bit positions to be set in the CSR. Any bit that is high in rs1 will cause the corresponding bit to be set in the CSR, if that CSR bit is writable. Other bits in the CSR are unaffected (though CSRs might have side effects when written), if rs1=x0, then the instruction will not write to the CSR at all, and so shall not cause any of the side effects that might otherwise occur on a CSR write, such as raising illegal instruction exceptions on accesses to read-only CSRs.

    **Pseudocode**: t = CSRs[csr]; CSRs[csr] = t | x[rs1]; x[rd] = t

    **Invalid values**: NONE

    **Exception raised**: attempts to access a non-existent CSR raise an illegal instruction exception, attempts to access a CSR without appropriate privilege level or to write a read-only register also raise illegal instruction exceptions.

- **CSRRC**: Control and Status Register Read and Clear

    **Format**: csrrc rd, csr, rs1

    **Description**: reads the value of the CSR, zero-extends the value to 32 bits, and writes it to integer register rd, the initial value in integer register rs1 is treated as a bit mask that specifies bit positions to be cleared in the CSR. Any bit that is high in rs1 will cause the corresponding bit to be set in the CSR, if that CSR bit is writable. Other bits in the CSR are unaffected (though CSRs might have side effects when written), if rs1=x0, then the instruction will not write to the CSR at all, and so shall not cause any of the side effects that might otherwise occur on a CSR write, such as raising illegal instruction exceptions on accesses to read-only CSRs.

    **Pseudocode**: t = CSRs[csr]; CSRs[csr] = t & ∼x[rs1]; x[rd] = t

    **Invalid values**: NONE

    **Exception raised**: attempts to access a non-existent CSR raise an illegal instruction exception, attempts to access a CSR without appropriate privilege level or to write a read-only register also raise illegal instruction exceptions.

- **CSRRWI**: Control and Status Register Read and Write Immediate

    **Format**: csrrwi rd, csr, uimm[4:0]

    **Description**: reads the old value of the CSR, zero-extends the value to 32 bits, then writes it to integer register rd. The zero-extends immediate is written to the CSR. If rd=x0, then the instruction shall not read the CSR and shall not cause any of the side-effects that might occur on a CSR read.

    **Pseudocode**: x[rd] = CSRs[csr]; CSRs[csr] = zext(uimm[4:0])

    **Invalid values**: NONE

    **Exception raised**: attempts to access a non-existent CSR raise an illegal instruction exception, attempts to access a CSR without appropriate privilege level or to write a read-only register also raise illegal instruction exceptions.

- **CSRRSI**: Control and Status Register Read and Set Immediate

    **Format**: csrrsi rd, csr, uimm[4:0]

    **Description**: reads the value of the CSR, zero-extends the value to 32 bits, and writes it to integer register rd. The zero-extends immediate value is treated as a bit mask that specifies bit positions to be set in the CSR. Any bit that is high in zero-extends immediate will cause the corresponding bit to be set in the CSR, if that CSR bit is writable. Other bits in the CSR are unaffected (though CSRs might have side effects when written), if the uimm[4:0] field is zero, then these instructions will not write to the CSR, and shall not cause any of the side effects that might otherwise occur on a CSR write.

    **Pseudocode**: t = CSRs[csr]; CSRs[csr] = t | zext(uimm[4:0]); x[rd] = t

    **Invalid values**: NONE

    **Exception raised**: attempts to access a non-existent CSR raise an illegal instruction exception, attempts to access a CSR without appropriate privilege level or to write a read-only register also raise illegal instruction exceptions.

- **CSRRCI**: Control and Status Register Read and Clear Immediate

    **Format**: csrrci rd, csr, uimm[4:0]

    **Description**: reads the value of the CSR, zero-extends the value to 32 bits, and writes it to integer register rd. The zero-extends immediate value is treated as a bit mask that specifies bit positions to be cleared in the CSR. Any bit that is high in zero-extends immediate will cause the corresponding bit to be set in the CSR, if that CSR bit is writable. Other bits in the CSR are unaffected (though CSRs might have side effects when written), if the uimm[4:0] field is zero, then these instructions will not write to the CSR, and shall not cause any of the side effects that might otherwise occur on a CSR write.

    **Pseudocode**: t = CSRs[csr]; CSRs[csr] = t & ∼zext(uimm[4:0]); x[rd] = t

    **Invalid values**: NONE

    **Exception raised**: attempts to access a non-existent CSR raise an illegal instruction exception, attempts to access a CSR without appropriate privilege level or to write a read-only register also raise illegal instruction exceptions.
```

### config/gen_from_riscv_config/cv32a65x/csr/csr.rst

```text
.. .. _ICACHE:::
ICACHE
~~~~~~

:Address: 0x7c0
:Reset Value: 0x00000001
:Privilege: MRW
:Description: the register controls the operation of the i-cache unit.

+--------+--------------+---------------+--------+----------------+-------------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values   | Description                               |
+========+==============+===============+========+================+===========================================+
| 0      | ICACHE       | 0x1           | RW     | 0x1            | bit for cache-enable of instruction cache |
+--------+--------------+---------------+--------+----------------+-------------------------------------------+
| [31:1] | RESERVED_1   | 0x0           | WPRI   |                | *Reserved*                                |
+--------+--------------+---------------+--------+----------------+-------------------------------------------+


.. .. _DCACHE:::
DCACHE
~~~~~~

:Address: 0x7c1
:Reset Value: 0x00000001
:Privilege: MRW
:Description: the register controls the operation of the d-cache unit.

+--------+--------------+---------------+--------+----------------+------------------------------------+
| Bits   | Field Name   | Reset Value   | Type   | Legal Values   | Description                        |
+========+==============+===============+========+================+====================================+
| 0      | DCACHE       | 0x1           | RW     | 0x1            | bit for cache-enable of data cache |
+--------+--------------+---------------+--------+----------------+------------------------------------+
| [31:1] | RESERVED_1   | 0x0           | WPRI   |                | *Reserved*                         |
+--------+--------------+---------------+--------+----------------+------------------------------------+
```

### docs/01_cva6_user/Traps_Interrupts_Exceptions.rst

```text
Traps are composed of interrupts and exceptions.
Interrupts are asynchronous events whereas exceptions are synchronous ones.
On one hand, interrupts are occurring independently of the instructions
(mainly raised by peripherals or debug module).
On the other hand, an instruction may raise exceptions synchronously.

Raising Traps
-------------
When a trap is raised, the behaviour of the CVA6 core depends on
several CSRs and some CSRs are modified.

Configuration CSRs
~~~~~~~~~~~~~~~~~~
CSRs having an effect on the core behaviour when a trap occurs are:

* ``mstatus`` and ``sstatus``: several fields control the core behaviour like interrupt enable (``MIE``, ``SIE``)
* ``mtvec`` and ``stvec``: specifies the address of trap handler.
* ``medeleg``: specifies which exceptions can be handled by a lower privileged mode (S-mode)
* ``mideleg``: specifies which interrupts can be handled by a lower privileged mode (S-mode)

Modified CSRs
~~~~~~~~~~~~~
CSRs (or fields) updated by the core when a trap occurs are:

* ``mstatus`` or ``sstatus``: several fields are updated like previous privilege mode (``MPP``, ``SPP``), previous interrupt enabled (``MPIE``, SPIE``)
* ``mepc`` or ``sepc``: updated with the virtual address of the interrupted instruction or the instruction raising the exception.
* ``mcause`` or ``scause``: updated with a code indicating the event causing the trap.
* ``mtval`` or ``stval``: updated with exception specific information like the faulting virtual address

Supported exceptions
~~~~~~~~~~~~~~~~~~~~
The following exceptions are supported by the CVA6:

* instruction address misaligned

  * control flow instruction with misaligned target

* instruction access fault

  * access to PMP region without execute permissions

* illegal instruction:

  * unimplemented CSRs
  * unsupported extensions

* breakpoint (``EBREAK``)
* load address misaligned:

  * ``LH`` at 2n+1 address
  * ``LW`` at 4n+1, 4n+2, 4n+3 address

* load access fault

  * access to PMP region without read permissions

* store/AMO address misaligned

  * ``SH`` at 2n+1 address
  * ``SW`` at 4n+1, 4n+2, 4n+3 address

* store/AMO access fault

  * access to PMP region without write permissions

* environment call (``ECALL``) from U-mode
* environment call (``ECALL``) from S-mode
* environment call (``ECALL``) from M-mode
* instruction page fault
* load page fault

  * access to effective address without read permissions

* store/AMO page fault

  * access to effective address without write permissions

* debug request (custom) via debug interface

Note: all exceptions are supported except the ones linked to the hypervisor extension

Trap return
-----------
Trap handler ends with trap return instruction (``MRET``, ``SRET``). The behaviour of the CVA6 core depends on several CSRs.

Configuration CSRs
~~~~~~~~~~~~~~~~~~
CSRs having an effect on the core behaviour when returning from a trap are:

* ``mstatus``: several fields control the core behaviour like previous privilege mode (``MPP``, ``SPP``), previous interrupt enabled (``MPIE``, ``SPIE``)

Modified CSRs
~~~~~~~~~~~~~
CSRs (or fields) updated by the core when returning from a trap are:

* ``mstatus``: several fields are updated like interrupt enable (``MIE``, ``SIE``), modify privilege (``MPRV``)

Interrupts
----------
* external interrupt: ``irq_i`` signal
* software interrupt (inter-processor interrupt): ``ipi_i`` signal
* timer interrupt: ``time_irq_i`` signal
* debug interrupt: ``debug_req_i`` signal

These signals are level sensitive. It means the interrupt is raised until it is cleared.

The exception code field (``mcause`` CSR) depends on the interrupt source.

Wait for Interrupt
------------------
* CVA6 implementation: ``WFI`` stalls the core. The instruction is not available in U-mode (raise illegal instruction exception). Such exception is also raised when ``TW=1`` in ``mstatus``.
```

### src/machine.adoc

```text
The WFI instruction can also be executed when interrupts are disabled.
The operation of WFI must be unaffected by the global interrupt bits in
`mstatus` (MIE and SIE) and the delegation register `mideleg` (i.e.,
the hart must resume if a locally enabled interrupt becomes pending,
even if it has been delegated to a less-privileged mode), but should
honor the individual interrupt enables (e.g, MTIE) (i.e.,
implementations should avoid resuming the hart if the interrupt is
pending but not individually enabled). WFI is also required to resume
execution for locally enabled interrupts pending at any privilege level,
regardless of the global interrupt enable at each privilege level.
```

### src/zicsr.adoc

```text
Some CSRs, such as the instructions-retired counter, `instret`, may be
modified as side effects of instruction execution. In these cases, if a
CSR access instruction reads a CSR, it reads the value prior to the
execution of the instruction. If a CSR access instruction writes such a
CSR, the explicit write is done instead of the update from the side effect.
In particular, a value
written to `instret` by one instruction will be the value read by the
following instruction.
```
