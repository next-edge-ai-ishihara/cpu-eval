# Implement `ibex_controller`

Implement the complete `ibex_controller` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_controller` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### ibex_configs.yaml

```yaml
small:
  BaseIsa                  : "ibex_pkg::BaseIsaRV32I"
  RV32E                    : 0
  RV32M                    : "ibex_pkg::RV32MFast"
  RV32B                    : "ibex_pkg::RV32BNone"
  RV32ZC                   : "ibex_pkg::RV32Zca"
  RegFile                  : "ibex_pkg::RegFileFF"
  BranchTargetALU          : 0
  WritebackStage           : 0
  ICache                   : 0
  ICacheECC                : 0
  ICacheScramble           : 0
  BranchPredictor          : 0
  DbgTriggerEn             : 0
  SecureIbex               : 0
  PMPEnable                : 0
  PMPGranularity           : 0
  PMPNumRegions            : 4
  MHPMCounterNum           : 0
  MHPMCounterWidth         : 40
```

## Package and imports

### rtl/ibex_pkg.sv

```systemverilog
  typedef enum integer {
    BaseIsaRV32I          = 0, // only RV32I
    BaseIsaRV32IorCHERIoT = 1  // dual base ISA: RV32I/CHERIoT runtime switchable
  } base_isa_e;

  // ...

  // Privileged mode
  typedef enum logic[1:0] {
    PRIV_LVL_M = 2'b11,
    PRIV_LVL_H = 2'b10,
    PRIV_LVL_S = 2'b01,
    PRIV_LVL_U = 2'b00
  } priv_lvl_e;

  // ...

  // Controller FSM state encoding
  typedef enum logic [3:0] {
    RESET,
    BOOT_SET,
    WAIT_SLEEP,
    SLEEP,
    FIRST_FETCH,
    DECODE,
    FLUSH,
    IRQ_TAKEN,
    DBG_TAKEN_IF,
    DBG_TAKEN_ID
  } ctrl_fsm_e;

  //////////////
  // IF stage //
  //////////////

  // PC mux selection
  typedef enum logic [2:0] {
    PC_BOOT,
    PC_JUMP,
    PC_EXC,
    PC_ERET,
    PC_DRET,
    PC_BP
  } pc_sel_e;

  // Compressed instruction expansion
  typedef enum logic [1:0] {
    INSTR_NOT_EXPANDED,
    INSTR_EXPANDED,        // Executing micro-ops of an expanded instruction
    INSTR_EXPANDED_COMMIT, // Micro-ops need to be committed atomically with successor micro-ops
    INSTR_EXPANDED_LAST    // Last micro-op of an expanded instruction
  } instr_exp_e;

  // Exception PC mux selection
  typedef enum logic [1:0] {
    EXC_PC_EXC,
    EXC_PC_IRQ,
    EXC_PC_DBD,
    EXC_PC_DBG_EXC // Exception while in debug mode
  } exc_pc_sel_e;

  // Interrupt requests
  typedef struct packed {
    logic        irq_software;
    logic        irq_timer;
    logic        irq_external;
    logic [14:0] irq_fast; // 15 fast interrupts,
                          // one interrupt is reserved for NMI (not visible through mip/mie)
  } irqs_t;

  typedef struct packed {
    logic       irq_int;
    logic       irq_ext;
    logic [4:0] lower_cause;
  } exc_cause_t;

  localparam exc_cause_t ExcCauseIrqSoftwareM =
    '{irq_ext: 1'b1, irq_int: 1'b0, lower_cause: 5'd03};
  localparam exc_cause_t ExcCauseIrqTimerM =
    '{irq_ext: 1'b1, irq_int: 1'b0, lower_cause: 5'd07};
  localparam exc_cause_t ExcCauseIrqExternalM =
    '{irq_ext: 1'b1, irq_int: 1'b0, lower_cause: 5'd11};
  localparam exc_cause_t ExcCauseIrqNm =
    '{irq_ext: 1'b1, irq_int: 1'b0, lower_cause: 5'd31};

  localparam exc_cause_t ExcCauseInsnAddrMisa =
    '{irq_ext: 1'b0, irq_int: 1'b0, lower_cause: 5'd00};
  localparam exc_cause_t ExcCauseInstrAccessFault =
    '{irq_ext: 1'b0, irq_int: 1'b0, lower_cause: 5'd01};
  localparam exc_cause_t ExcCauseIllegalInsn =
    '{irq_ext: 1'b0, irq_int: 1'b0, lower_cause: 5'd02};
  localparam exc_cause_t ExcCauseBreakpoint =
    '{irq_ext: 1'b0, irq_int: 1'b0, lower_cause: 5'd03};
  localparam exc_cause_t ExcCauseLoadAddrMisaligned  =
    '{irq_ext: 1'b0, irq_int: 1'b0, lower_cause: 5'd04};
  localparam exc_cause_t ExcCauseLoadAccessFault  =
    '{irq_ext: 1'b0, irq_int: 1'b0, lower_cause: 5'd05};
  localparam exc_cause_t ExcCauseStoreAddrMisaligned  =
    '{irq_ext: 1'b0, irq_int: 1'b0, lower_cause: 5'd06};
  localparam exc_cause_t ExcCauseStoreAccessFault =
    '{irq_ext: 1'b0, irq_int: 1'b0, lower_cause: 5'd07};
  localparam exc_cause_t ExcCauseEcallUMode =
    '{irq_ext: 1'b0, irq_int: 1'b0, lower_cause: 5'd08};
  localparam exc_cause_t ExcCauseEcallMMode =
    '{irq_ext: 1'b0, irq_int: 1'b0, lower_cause: 5'd11};
  localparam exc_cause_t ExcCauseCheriFault =
    '{irq_ext: 1'b0, irq_int: 1'b0, lower_cause: 5'd28};

  // Internal NMI cause
  typedef enum logic [4:0] {
    NMI_INT_CAUSE_ECC = 5'b0
  } nmi_int_cause_e;

  // Debug cause
  typedef enum logic [2:0] {
    DBG_CAUSE_NONE    = 3'h0,
    DBG_CAUSE_EBREAK  = 3'h1,
    DBG_CAUSE_TRIGGER = 3'h2,
    DBG_CAUSE_HALTREQ = 3'h3,
    DBG_CAUSE_STEP    = 3'h4
  } dbg_cause_e;

  // ...

  // Multi-bit signal used for security hardening. For non-secure implementation all bits other than
  // the bottom bit are ignored.
  parameter int IbexMuBiWidth = 4;
  typedef logic [IbexMuBiWidth-1:0] ibex_mubi_t;

  // Note that if adjusting these parameters it is assumed the bottom bit is set for On and unset
  // for Off. This allows the use of IbexMuBiOn/IbexMuBiOff to work for both secure and non-secure
  // Ibex. If this assumption is broken the RTL that uses ibex_mubi_t types such as the fetch_enable
  // and core_busy signals within `ibex_core` may need adjusting.
  parameter ibex_mubi_t IbexMuBiOn  = 4'b0101;
  parameter ibex_mubi_t IbexMuBiOff = 4'b1010;
```

## Module declaration

```verilog
module ibex_controller import ibex_pkg::*; #(
  parameter base_isa_e BaseIsa  = BaseIsaRV32I,
  parameter bit WritebackStage  = 1'b0,
  parameter bit BranchPredictor = 1'b0,
  parameter bit MemECC          = 1'b0
 ) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  ibex_mubi_t            cheriot_enable_i,

  output logic                  ctrl_busy_o,             // core is busy processing instrs

  // decoder related signals
  input  logic                  illegal_insn_i,          // decoder has an invalid instr
  input  logic                  ecall_insn_i,            // decoder has ECALL instr
  input  logic                  mret_insn_i,             // decoder has MRET instr
  input  logic                  dret_insn_i,             // decoder has DRET instr
  input  logic                  wfi_insn_i,              // decoder has WFI instr
  input  logic                  ebrk_insn_i,             // decoder has EBREAK instr
  input  logic                  csr_pipe_flush_i,        // do CSR-related pipeline flush
  input  logic                  csr_access_i,            // decoder has CSR access instr
  input  logic                  csr_cheriot_always_ok_i,   // cheriot safe-listed CSR registers

  // instr from IF-ID pipeline stage
  input  logic                  instr_valid_i,           // instr is valid
  input  logic [31:0]           instr_i,                 // uncompressed instr data for mtval
  input  logic [15:0]           instr_compressed_i,      // instr compressed data for mtval
  input  logic                  instr_is_compressed_i,   // instr is compressed
  input  ibex_pkg::instr_exp_e  instr_gets_expanded_i,   // instr expansion state
  input  logic                  instr_bp_taken_i,        // instr was predicted taken branch
  input  logic                  instr_fetch_err_i,       // instr has error
  input  logic                  instr_fetch_err_plus2_i, // instr error is x32
  input  logic                  instr_fetch_cheriot_acc_vio_i,
  input  logic                  instr_fetch_cheriot_bound_vio_i,

  input  logic [31:0]           pc_id_i,                 // instr address

  // to IF-ID pipeline stage
  output logic                  instr_valid_clear_o,     // kill instr in IF-ID reg
  output logic                  id_in_ready_o,           // ID stage is ready for new instr
  output logic                  controller_run_o,        // Controller is in standard instruction
                                                         // run mode
  input  logic                  instr_exec_i,            // Execution control, when clear ID/EX
                                                         // stage stops accepting instructions from
                                                         // IF
  // to prefetch
  output logic                  instr_req_o,             // start fetching instructions
  output logic                  pc_set_o,                // jump to address set by pc_mux
  output ibex_pkg::pc_sel_e     pc_mux_o,                // IF stage fetch address selector
                                                         // (boot, normal, exception...)
  output logic                  nt_branch_mispredict_o,  // Not-taken branch in ID/EX was
                                                         // mispredicted (predicted taken)
  output ibex_pkg::exc_pc_sel_e exc_pc_mux_o,            // IF stage selector for exception PC
  output ibex_pkg::exc_cause_t  exc_cause_o,             // for IF stage, CSRs

  // LSU
  input  logic [31:0]           lsu_addr_last_i,         // for mtval
  input  logic                  load_err_i,
  input  logic                  store_err_i,
  input  logic                  mem_resp_intg_err_i,
  input  logic                  lsu_err_is_cheriot_i,
  output logic                  wb_exception_o,          // Instruction in WB taking an exception
  output logic                  id_exception_o,          // Instruction in ID taking an exception
  output logic                  id_exception_nc_o,       // no-cheriot

  // jump/branch signals
  input  logic                  branch_set_i,            // branch set signal (branch definitely
                                                         // taken)
  input  logic                  branch_not_set_i,        // branch is definitely not taken
  input  logic                  jump_set_i,              // jump taken set signal

  // interrupt signals
  input  logic                  csr_mstatus_mie_i,       // M-mode interrupt enable bit
  input  logic                  irq_pending_i,           // interrupt request pending
  input  ibex_pkg::irqs_t       irqs_i,                  // interrupt requests qualified with
                                                         // mie CSR
  input  logic                  irq_nm_ext_i,            // non-maskable interrupt
  output logic                  nmi_mode_o,              // core executing NMI handler

  // debug signals
  input  logic                  debug_req_i,
  output ibex_pkg::dbg_cause_e  debug_cause_o,
  output logic                  debug_csr_save_o,
  output logic                  debug_mode_o,
  output logic                  debug_mode_entering_o,
  input  logic                  debug_single_step_i,
  input  logic                  debug_ebreakm_i,
  input  logic                  debug_ebreaku_i,
  input  logic                  trigger_match_i,

  output logic                  csr_save_if_o,
  output logic                  csr_save_id_o,
  output logic                  csr_save_wb_o,
  output logic                  csr_restore_mret_id_o,
  output logic                  csr_restore_dret_id_o,
  output logic                  csr_save_cause_o,
  output logic                  csr_mepcc_clrtag_o,

  output logic [31:0]           csr_mtval_o,
  input  ibex_pkg::priv_lvl_e   priv_mode_i,
  input  logic                  csr_pcc_perm_sr_i,

  // stall & flush signals
  input  logic                  stall_id_i,
  input  logic                  stall_wb_i,
  output logic                  flush_id_o,
  input  logic                  ready_wb_i,

  // performance monitors
  output logic                  perf_jump_o,             // we are executing a jump
                                                         // instruction (j, jr, jal, jalr)
  output logic                  perf_tbranch_o,          // we are executing a taken branch
                                                         // instruction
  input  logic                  instr_is_cheriot_i,        // from decoder
  input  logic                  cheriot_ex_valid_i,        // from cheriot EX
  input  logic                  cheriot_ex_err_i,
  input  logic                  cheriot_wb_err_i,
  input  logic  [11:0]          cheriot_ex_err_info_i,
  input  logic  [15:0]          cheriot_wb_err_info_i,
  input  logic                  cheriot_branch_req_i,
  input  logic [31:0]           cheriot_branch_target_i
);
```

## Parent instantiation

### rtl/ibex_id_stage.sv

```verilog
  ibex_controller #(
    .BaseIsa        (BaseIsa),
    .WritebackStage (WritebackStage),
    .BranchPredictor(BranchPredictor),
    .MemECC(MemECC)
  ) controller_i (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),
    .cheriot_enable_i(cheriot_enable_i),
    .ctrl_busy_o     (ctrl_busy_o),

    // decoder related signals
    .illegal_insn_i         (illegal_insn_o),
    .ecall_insn_i           (ecall_insn_dec),
    .mret_insn_i            (mret_insn_dec),
    .dret_insn_i            (dret_insn_dec),
    .wfi_insn_i             (wfi_insn_dec),
    .ebrk_insn_i            (ebrk_insn),
    .csr_pipe_flush_i       (csr_pipe_flush),
    .csr_access_i           (csr_access_o),
    .csr_cheriot_always_ok_i(csr_cheriot_always_ok),

    // from IF-ID pipeline
    .instr_valid_i                  (instr_valid_i),
    .instr_i                        (instr_rdata_i),
    .instr_compressed_i             (instr_rdata_c_i),
    .instr_is_compressed_i          (instr_is_compressed_i),
    .instr_gets_expanded_i          (instr_gets_expanded_i),
    .instr_bp_taken_i               (instr_bp_taken_i),
    .instr_fetch_err_i              (instr_fetch_err_i),
    .instr_fetch_err_plus2_i        (instr_fetch_err_plus2_i),
    .instr_fetch_cheriot_acc_vio_i  (instr_fetch_cheriot_acc_vio_i),
    .instr_fetch_cheriot_bound_vio_i(instr_fetch_cheriot_bound_vio_i),

    .pc_id_i                (pc_id_i),

    // to IF-ID pipeline
    .instr_valid_clear_o(instr_valid_clear_o),
    .id_in_ready_o      (id_in_ready_o),
    .controller_run_o   (controller_run),
    .instr_exec_i       (instr_exec_i),

    // to prefetch
    .instr_req_o           (instr_req_o),
    .pc_set_o              (pc_set_o),
    .pc_mux_o              (pc_mux_o),
    .nt_branch_mispredict_o(nt_branch_mispredict_o),
    .exc_pc_mux_o          (exc_pc_mux_o),
    .exc_cause_o           (exc_cause_o),

    // LSU
    .lsu_addr_last_i      (lsu_addr_last_i),
    .load_err_i           (lsu_load_err_i),
    .lsu_err_is_cheriot_i (lsu_err_is_cheriot_i),
    .mem_resp_intg_err_i  (mem_resp_intg_err),
    .store_err_i          (lsu_store_err_i),
    .wb_exception_o       (wb_exception),
    .id_exception_o       (unused_id_exception),
    .id_exception_nc_o    (id_exception_nc),

    // jump/branch control
    .branch_set_i     (branch_set),
    .branch_not_set_i (branch_not_set),
    .jump_set_i       (jump_set),

    // interrupt signals
    .csr_mstatus_mie_i(csr_mstatus_mie_i),
    .irq_pending_i    (irq_pending_i),
    .irqs_i           (irqs_i),
    .irq_nm_ext_i     (irq_nm_i),
    .nmi_mode_o       (nmi_mode_o),

    // CSR Controller Signals
    .csr_save_if_o        (csr_save_if_o),
    .csr_save_id_o        (csr_save_id_o),
    .csr_save_wb_o        (csr_save_wb_o),
    .csr_restore_mret_id_o(csr_restore_mret_id_o),
    .csr_restore_dret_id_o(csr_restore_dret_id_o),
    .csr_save_cause_o     (csr_save_cause_o),
    .csr_mepcc_clrtag_o   (csr_mepcc_clrtag_o),
    .csr_mtval_o          (csr_mtval_o),
    .priv_mode_i          (priv_mode_i),
    .csr_pcc_perm_sr_i    (csr_pcc_perm_sr_i),

    // Debug Signal
    .debug_mode_o         (debug_mode_o),
    .debug_mode_entering_o(debug_mode_entering_o),
    .debug_cause_o        (debug_cause_o),
    .debug_csr_save_o     (debug_csr_save_o),
    .debug_req_i          (debug_req_i),
    .debug_single_step_i  (debug_single_step_i),
    .debug_ebreakm_i      (debug_ebreakm_i),
    .debug_ebreaku_i      (debug_ebreaku_i),
    .trigger_match_i      (trigger_match_i),

    .stall_id_i(stall_id),
    .stall_wb_i(stall_wb),
    .flush_id_o(flush_id),
    .ready_wb_i(ready_wb_i),

    // Performance Counters
    .perf_jump_o   (perf_jump_o),
    .perf_tbranch_o(perf_tbranch_o),

    .instr_is_cheriot_i      (instr_is_cheriot_id_o),
    .cheriot_ex_valid_i      (cheriot_ex_valid_i),
    .cheriot_ex_err_i        (cheriot_ex_err_i),
    .cheriot_ex_err_info_i   (cheriot_ex_err_info_i),
    .cheriot_wb_err_i        (cheriot_wb_err_i),
    .cheriot_wb_err_info_i   (cheriot_wb_err_info_i),
    .cheriot_branch_req_i    (cheriot_branch_req_i),
    .cheriot_branch_target_i (cheriot_branch_target_i)
  );
```

## Related source code

### rtl/ibex_core.sv

```verilog
  // When an instruction takes a trap the `rvfi_trap` signal will be set. Instructions that take
  // traps flush the pipeline so ordinarily wouldn't be seen to be retire. The RVFI tracking
  // pipeline is kept going for flushed instructions that trapped so they are still visible on the
  // RVFI interface.

  // Factor in exceptions taken in ID so RVFI tracking picks up flushed instructions that took
  // a trap
  // Suppress ID-stage exception tracing when WB already faulted for the same instruction,
  // e.g. illegal_insn in ID with cheriot_wb_err in WB: only emit one RVFI trap entry.
  assign rvfi_id_done = instr_id_done | (id_stage_i.controller_i.rvfi_flush_next &
                                         id_stage_i.controller_i.id_exception_o &
                                         ~id_stage_i.controller_i.wb_exception_o);

  // ...

    assign rvfi_trap_id = id_stage_i.controller_i.id_exception_o &
      ~(id_stage_i.ebrk_insn & id_stage_i.controller_i.ebreak_into_debug);

    assign rvfi_trap_wb = id_stage_i.controller_i.exc_req_wb;
    // WB is instantly done in the tracking pipeline when a trap is progress through the pipeline
    assign rvfi_wb_done = rvfi_stage_valid[0] & (instr_done_wb | rvfi_stage_trap[0]);
  end else begin : gen_rvfi_no_wb_stage
    // Without writeback stage first RVFI stage is output stage so simply valid the cycle after
    // instruction leaves ID/EX (and so has retired)
    assign rvfi_stage_valid_d[0] = rvfi_id_done & ~dummy_instr_id;
    // Without writeback stage signal new instr_new_wb when instruction enters ID/EX to correctly
    // setup register write signals
    assign rvfi_instr_new_wb = instr_new_id;
    assign rvfi_trap_id =
      (id_stage_i.controller_i.exc_req_d | id_stage_i.controller_i.exc_req_lsu) &
      ~(id_stage_i.ebrk_insn & id_stage_i.controller_i.ebreak_into_debug);

  // ...

  // For interrupts and debug Ibex will take the relevant trap as soon as whatever instruction in ID
  // finishes or immediately if the ID stage is empty. The rvfi_ext interface provides the DV
  // environment with information about the irq/debug_req/nmi state that applies to a particular
  // instruction.
  //
  // When a irq/debug_req/nmi appears the ID stage will finish whatever instruction it is currently
  // executing (if any) then take the trap the cycle after that instruction leaves the ID stage. The
  // trap taken depends upon the state of irq/debug_req/nmi on that cycle. In the cycles following
  // that before the first instruction of the trap handler enters the ID stage the state of
  // irq/debug_req/nmi could change but this has no effect on the trap handler (e.g. a higher
  // priority interrupt might appear but this wouldn't stop the lower priority interrupt trap
  // handler executing first as it's already being fetched). To provide the DV environment with the
  // correct information for it to verify execution we need to capture the irq/debug_req/nmi state
  // the cycle the trap decision is made. Which the captured_X signals below do.
  //
  // The new_X signals take the raw irq/debug_req/nmi inputs and factor in the enable terms required
  // to determine if a trap will actually happen.
  //
  // These signals and the comment above are referred to in the documentation (cosim.rst). If
  // altering the names or meanings of these signals or this comment please adjust the documentation
  // appropriately.
  assign new_debug_req = (debug_req_i & ~debug_mode);
  assign new_nmi = irq_nm_i & ~nmi_mode & ~debug_mode;
  assign new_nmi_int = id_stage_i.controller_i.irq_nm_int & ~nmi_mode & ~debug_mode;
  assign new_irq = irq_pending_o & (csr_mstatus_mie || (priv_mode_id == PRIV_LVL_U)) & ~nmi_mode &
                   ~debug_mode;

  // ...

      // Capture when ID stage has emptied out and something occurs that will cause a trap and we
      // haven't yet captured
      //
      // When we already captured a trap, and there is upcoming nmi interrupt or
      // a debug request then recapture as nmi or debug request are supposed to
      // be serviced.
      if (~instr_valid_id & (new_debug_req | new_irq | new_nmi | new_nmi_int) &
          ((~captured_valid) |
           (new_debug_req & ~captured_debug_req) |
           (new_nmi & ~captured_nmi & ~captured_debug_req))) begin
        captured_valid     <= 1'b1;
        captured_nmi       <= irq_nm_i;
        captured_nmi_int   <= id_stage_i.controller_i.irq_nm_int;
        captured_mip       <= cs_registers_i.mip;
        captured_debug_req <= debug_req_i;
      end

  // ...

  // Pass the captured irq/debug_req/nmi state to the rvfi_ext interface tracking pipeline.
  //
  // To correctly capture we need to factor in various enable terms, should there be a fault in this
  // logic we won't tell the DV environment about a trap that should have been taken. So if there's
  // no valid capture we grab the raw values of the irq/debug_req/nmi inputs whatever they are and
  // the DV environment will see if a trap should have been taken but wasn't.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rvfi_ext_stage_pre_mip[0]       <= '0;
      rvfi_ext_stage_nmi[0]       <= '0;
      rvfi_ext_stage_nmi_int[0]   <= '0;
      rvfi_ext_stage_debug_req[0] <= '0;
      rvfi_ext_stage_irq_valid[0] <= '0;
    end else if ((if_stage_i.instr_valid_id_d & if_stage_i.instr_new_id_d) | rvfi_irq_valid) begin
      rvfi_ext_stage_pre_mip[0]   <= instr_valid_id | ~captured_valid ? cs_registers_i.mip :
                                                                        captured_mip;
      rvfi_ext_stage_nmi[0]       <= instr_valid_id | ~captured_valid ? irq_nm_i :
                                                                        captured_nmi;
      rvfi_ext_stage_nmi_int[0]   <=
        instr_valid_id | ~captured_valid ? id_stage_i.controller_i.irq_nm_int :
                                           captured_nmi_int;
      rvfi_ext_stage_debug_req[0] <= instr_valid_id | ~captured_valid ? debug_req_i        :
                                                                        captured_debug_req;
      rvfi_ext_stage_irq_valid[0] <= rvfi_irq_valid;
    end
  end
```

## Documentation

### doc/03_reference/instruction_decode_execute.rst

```text
Controller
----------
Source File: :file:`rtl/ibex_controller.sv`

The Controller contains the state machine that controls the overall execution of the processor.
It is responsible for:

* Handling core startup from reset
* Setting the PC for the IF stage on jump/branch
* Dealing with exceptions/interrupts (jump to appropriate PC, set relevant CSR values)
* Controlling sleep/wakeup on WFI
* Debugging control
```

### doc/03_reference/pipeline_details.rst

```text
Instruction Fetch (IF)
  Fetches instructions from memory via a prefetch buffer, capable of fetching 1 instruction per cycle if the instruction side memory system allows. See :ref:`instruction-fetch` for details.

Instruction Decode and Execute (ID/EX)
  Decodes fetched instruction and immediately executes it, register read and write all occurs in this stage.
  Multi-cycle instructions will stall this stage until they are complete See :ref:`instruction-decode-execute` for details.

All instructions require two cycles minimum to pass down the pipeline.
One cycle in the IF stage and one in the ID/EX stage.
Not all instructions can complete in the ID/EX stage in one cycle so will stall there until they complete.
This means the maximum IPC (Instructions per Cycle) Ibex can achieve is 1 when multi-cycle instructions aren't used.
See Multi- and Single-Cycle Instructions below for the details.

Third Pipeline Stage
--------------------
Ibex can be configured to have a third pipeline stage (Writeback) which has major effects on performance and instruction behaviour.
The details of its impact are not yet documented here.
All of the information presented below applies only to the two stage pipeline provided in the default configurations.

Multi- and Single-Cycle Instructions
------------------------------------

In the table below when an instruction stalls for X cycles X + 1 cycles pass before a new instruction enters the ID/EX stage.
Some instructions stall for a variable time, this is indicated as a range e.g. 1 - N means the instruction stalls a minimum of 1 cycle with an indeterminate maximum cycles.
Read the description for more information.

+-----------------------+--------------------------------------+-------------------------------------------------------------+
|   Instruction Type    |             Stall Cycles             |                         Description                         |
+=======================+======================================+=============================================================+
| Integer Computational | 0                                    | Integer Computational Instructions are defined in the       |
|                       |                                      | RISCV-V RV32I Base Integer Instruction Set.                 |
+-----------------------+--------------------------------------+-------------------------------------------------------------+
| CSR Access            | 0                                    | CSR Access Instruction are defined in 'Zicsr' of the        |
|                       |                                      | RISC-V specification. Note that most CSR *writes* flush the |
|                       |                                      | pipeline, so the instruction immediately following a CSR    |
|                       |                                      | write incurs an additional fetch-latency. This is mainly to |
|                       |                                      | ensure ePMP updates are taken into account for the next     |
|                       |                                      | instruction fetch check. Writes to ``mscratch`` and         |
|                       |                                      | ``mepc`` are exempt and do not flush the pipeline.          |
+-----------------------+--------------------------------------+-------------------------------------------------------------+
| Load/Store            | 1 - N                                | Both loads and stores stall for at least one cycle to await |
|                       |                                      | a response.  For loads this response is the load data       |
|                       |                                      | (which is written directly to the register file the same    |
|                       |                                      | cycle it is received).  For stores this is whether an error |
|                       |                                      | was seen or not.  The longer the data side memory interface |
|                       |                                      | takes to receive a response the longer loads and stores     |
|                       |                                      | will stall.                                                 |
+-----------------------+--------------------------------------+-------------------------------------------------------------+
| Multiplication        | 0/1 (Single-Cycle Multiplier)        | 0 for MUL, 1 for MULH.                                      |
|                       |                                      |                                                             |
|                       | 2/3 (Fast Multi-Cycle Multiplier)    | 2 for MUL, 3 for MULH.                                      |
|                       |                                      |                                                             |
|                       | clog2(``op_b``)/32 (Slow Multi-Cycle | clog2(``op_b``) for MUL, 32 for MULH.                       |
|                       | Multiplier)                          | See details in :ref:`mult-div`.                             |
+-----------------------+--------------------------------------+-------------------------------------------------------------+
| Division              | 1 or 37                              | 1 stall cycle if divide by 0, otherwise full long division. |
|                       |                                      | See details in :ref:`mult-div`                              |
| Remainder             |                                      |                                                             |
+-----------------------+--------------------------------------+-------------------------------------------------------------+
| Jump                  | 1 - N                                | Minimum one cycle stall to flush the prefetch counter and   |
|                       |                                      | begin fetching from the new Program Counter (PC).  The new  |
|                       |                                      | PC request will appear on the instruction-side memory       |
|                       |                                      | interface the same cycle the jump instruction enters ID/EX. |
|                       |                                      | The longer the instruction-side memory interface takes to   |
|                       |                                      | receive data the longer the jump will stall.                |
+-----------------------+--------------------------------------+-------------------------------------------------------------+
| Branch (Not-Taken)    | 0                                    | Any branch where the condition is not met will              |
|                       |                                      | not stall.                                                  |
+-----------------------+--------------------------------------+-------------------------------------------------------------+
| Branch (Taken)        | 2 - N                                | Any branch where the condition is met will stall for 2      |
|                       |                                      | cycles as in the first cycle the branch is in ID/EX the ALU |
|                       | 1 - N (Branch Target                 | is used to calculate the branch condition.  The following   |
|                       | ALU enabled)                         | cycle the ALU is used again to calculate the branch target  |
|                       |                                      | where it proceeds as Jump does above (Flush IF stage and    |
|                       |                                      | prefetch buffer, new PC on instruction-side memory          |
|                       |                                      | interface the same cycle it is calculated).  The longer the |
|                       |                                      | instruction-side memory interface takes to receive data the |
|                       |                                      | longer the branch will stall. With the parameter            |
|                       |                                      | ``BranchTargetALU`` set to ``1`` a separate ALU calculates  |
|                       |                                      | the branch target simultaneously to calculating the branch  |
|                       |                                      | condition with the main ALU so 1 less stall cycle is        |
|                       |                                      | required.                                                   |
+-----------------------+--------------------------------------+-------------------------------------------------------------+
| Instruction Fence     | 1 - N                                | The FENCE.I instruction as defined in 'Zifencei' of the     |
|                       |                                      | RISC-V specification. Internally it is implemented as a     |
|                       |                                      | jump (which does the required flushing) so it has the same  |
|                       |                                      | stall characteristics (see above).                          |
+-----------------------+--------------------------------------+-------------------------------------------------------------+
| Zcmp Push/Pop         | 2 - N                                | The cm.push/pop instructions as defined in 'Zcmp' of the    |
|                       |                                      | RISC-V specification. Internally, they expand to multiple   |
|                       |                                      | register load/store operations combined with stack pointer  |
|                       |                                      | adjustments, so their latency corresponds to the total      |
|                       |                                      | number of instructions issued and the memory latency.       |
+-----------------------+--------------------------------------+-------------------------------------------------------------+
| Zcmp Move             | 2                                    | The `cm.mvsa01` and `cm.mva01s` instruction as defined in   |
|                       |                                      | 'Zcmp' of the RISC-V specification. Internally, they are    |
|                       |                                      | implemented as two `addi rd, rs1, 0` instructions.          |
+-----------------------+--------------------------------------+-------------------------------------------------------------+
```

### doc/03_reference/exception_interrupts.rst

```text
.. _exceptions-interrupts:

Exceptions and Interrupts
=========================

Ibex implements trap handling for interrupts and exceptions according to the RISC-V Privileged Specification, version 1.11.

When entering an interrupt/exception handler, the core sets the ``mepc`` CSR to the current program counter and saves ``mstatus``.MIE to ``mstatus``.MPIE.
All exceptions cause the core to jump to the base address of the vector table in the ``mtvec`` CSR.
Interrupts are handled in vectored mode, i.e., the core jumps to the base address plus four times the interrupt ID.
Upon executing an MRET instruction, the core jumps to the program counter previously saved in the ``mepc`` CSR and restores ``mstatus``.MPIE to ``mstatus``.MIE.

The base address of the vector table is initialized to the boot address (must be aligned to 256 bytes, i.e., its least significant byte must be 0x00) when the core is booting.
The base address can be changed after boot-up by writing to the ``mtvec`` CSR.
For more information, see the :ref:`cs-registers` documentation.

The core starts fetching at the address made by concatenating the most significant 3 bytes of the boot address and the reset value (0x80) as the least significant byte.
It is assumed that the boot address is supplied via a register to avoid long paths to the instruction fetch unit.

Privilege Modes
---------------

Ibex supports operation in Machine Mode (M-Mode) and User Mode (U-Mode).
The core resets into M-Mode and will jump to M-Mode on any interrupt or exception.
On execution of an MRET instruction, the core will return to the Privilege Mode stored in ``mstatus``.MPP.
```

### doc/03_reference/debug.rst

```text
+-----------------+-----------+-----------------------------+
| Signal          | Direction | Description                 |
+=================+===========+=============================+
| ``debug_req_i`` | input     | Request to enter Debug Mode |
+-----------------+-----------+-----------------------------+

``debug_req_i`` is the "debug interrupt", issued by the debug module when the core should enter Debug Mode.

Parameters
----------

+---------------------+-----------------------------------------------------------------+
| Parameter           | Description                                                     |
+=====================+=================================================================+
| ``DmBaseAddr``      | Base address of the Debug Module                                |
+---------------------+-----------------------------------------------------------------+
| ``DmAddrMask``      | Address mask of the Debug Module                                |
+---------------------+-----------------------------------------------------------------+
| ``DmHaltAddr``      | Address to jump to when entering Debug Mode                     |
+---------------------+-----------------------------------------------------------------+
| ``DmExceptionAddr`` | Address to jump to when an exception occurs while in Debug Mode |
+---------------------+-----------------------------------------------------------------+
| ``DbgTriggerEn``    | Enable support for debug triggers                               |
+---------------------+-----------------------------------------------------------------+
| ``DbgHwBreakNum``   | Number of debug triggers                                        |
+---------------------+-----------------------------------------------------------------+

Core Debug Registers
--------------------

Ibex implements four core debug registers, namely :ref:`csr-dcsr`, :ref:`csr-dpc`, and two debug scratch registers.
If the ``DbgTriggerEn`` parameter is set, debug trigger registers are available.
See :ref:`csr-tselect`, :ref:`csr-tdata1` and :ref:`csr-tdata2` for details.
All those registers are accessible from Debug Mode only.
If software tries to access them without the core being in Debug Mode, an illegal instruction exception is triggered.
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

If the event that causes the hart to resume execution does not cause an
interrupt to be taken, execution will resume at `pc` + 4, and software
must determine what action to take, including looping back to repeat the
WFI if there was no actionable event.
```
