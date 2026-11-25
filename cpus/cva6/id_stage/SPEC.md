# Implement `id_stage`

Implement the complete `id_stage` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module id_stage` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv32a60x_config_pkg.sv`

```systemverilog
  localparam config_pkg::cva6_user_cfg_t cva6_cfg = '{
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(32),
      FpgaEn: bit'(0),
      FpgaAlteraEn: bit'(0),
      TechnoCut: bit'(1),
      SuperscalarEn: bit'(0),
      ALUBypass: bit'(0),
      NrCommitPorts: unsigned'(1),
      AxiAddrWidth: unsigned'(CVA6ConfigAxiAddrWidth),
      AxiDataWidth: unsigned'(CVA6ConfigAxiDataWidth),
      AxiIdWidth: unsigned'(CVA6ConfigAxiIdWidth),
      AxiUserWidth: unsigned'(CVA6ConfigDataUserWidth),
      MemTidWidth: unsigned'(CVA6ConfigAxiIdWidth),
      NrLoadBufEntries: unsigned'(2),
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
```

### `core/include/build_config_pkg.sv`

```systemverilog
    cfg.FpgaEn = CVA6Cfg.FpgaEn;
    cfg.FpgaAlteraEn = CVA6Cfg.FpgaAlteraEn;
    cfg.TechnoCut = CVA6Cfg.TechnoCut;

    cfg.SuperscalarEn = CVA6Cfg.SuperscalarEn;
    cfg.NrCommitPorts = CVA6Cfg.SuperscalarEn ? unsigned'(2) : CVA6Cfg.NrCommitPorts;
    cfg.NrIssuePorts = unsigned'(CVA6Cfg.SuperscalarEn ? 2 : 1);
    cfg.SpeculativeSb = CVA6Cfg.SuperscalarEn;

    cfg.NrALUs = CVA6Cfg.SuperscalarEn ? unsigned'(2) : unsigned'(1);
    cfg.ALUBypass = CVA6Cfg.SuperscalarEn ? bit'(CVA6Cfg.ALUBypass) : bit'(0);
```

## Module declaration

### `core/id_stage.sv`

```systemverilog
// Description: Instruction decode, contains the logic for decode,
//              issue and read operands.

module id_stage #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type branchpredict_sbe_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter type exception_t = logic,
    parameter type fetch_entry_t = logic,
    parameter type jvt_t = logic,
    parameter type irq_ctrl_t = logic,
    parameter type scoreboard_entry_t = logic,
    parameter type interrupts_t = logic,
    parameter interrupts_t INTERRUPTS = '0,
    parameter type x_compressed_req_t = logic,
    parameter type x_compressed_resp_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Fetch flush request - CONTROLLER
    input logic flush_i,
    // Debug (async) request - SUBSYSTEM
    input logic debug_req_i,
    // Handshake's data between fetch and decode - FRONTEND
    input fetch_entry_t [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_i,
    // Handshake's valid between fetch and decode - FRONTEND
    input logic [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_valid_i,
    // Handshake's ready between fetch and decode - FRONTEND
    output logic [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_ready_o,
    // Handshake's data between decode and issue - ISSUE
    output scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0] issue_entry_o,
    output scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0] issue_entry_o_prev,
    // Instruction value - ISSUE
    output logic [CVA6Cfg.NrIssuePorts-1:0][31:0] orig_instr_o,
    // Handshake's valid between decode and issue - ISSUE
    output logic [CVA6Cfg.NrIssuePorts-1:0] issue_entry_valid_o,
    // Report if instruction is a control flow instruction - ISSUE
    output logic [CVA6Cfg.NrIssuePorts-1:0] is_ctrl_flow_o,
    // Handshake's acknowledge between decode and issue - ISSUE
    input logic [CVA6Cfg.NrIssuePorts-1:0] issue_instr_ack_i,
    // Information dedicated to RVFI - RVFI
    output logic [CVA6Cfg.NrIssuePorts-1:0] rvfi_is_compressed_o,
    // Current privilege level - CSR_REGFILE
    input riscv::priv_lvl_t priv_lvl_i,
    // Current virtualization mode - CSR_REGFILE
    input logic v_i,
    // Floating point extension status - CSR_REGFILE
    input riscv::xs_t fs_i,
    // Floating point extension virtual status - CSR_REGFILE
    input riscv::xs_t vfs_i,
    // Floating point dynamic rounding mode - CSR_REGFILE
    input logic [2:0] frm_i,
    // Vector extension status - CSR_REGFILE
    input riscv::xs_t vs_i,
    // Level sensitive (async) interrupts - SUBSYSTEM
    input logic [1:0] irq_i,
    // Interrupt control status - CSR_REGFILE
    input irq_ctrl_t irq_ctrl_i,
    // Is current mode debug ? - CSR_REGFILE
    input logic debug_mode_i,
    // Trap virtual memory - CSR_REGFILE
    input logic tvm_i,
    // Timeout wait - CSR_REGFILE
    input logic tw_i,
    // Virtual timeout wait - CSR_REGFILE
    input logic vtw_i,
    // Trap sret - CSR_REGFILE
    input logic tsr_i,
    // Hypervisor user mode - CSR_REGFILE
    input logic hu_i,
    // machine-mode cache block invalidate enable - CSR_REGFILE
    input riscv::cbie_t mcbie_i,
    // supervisor-mode cache block invalidate enable - CSR_REGFILE
    input riscv::cbie_t scbie_i,
    // hypervisor-mode cache block invalidate enable - CSR_REGFILE
    input riscv::cbie_t hcbie_i,
    // machine-mode clean/flush cache block invalidate enable - CSR_REGFILE
    input logic mcbcfe_i,
    // supervisor-mode clean/flush cache block invalidate enable - CSR_REGFILE
    input logic scbcfe_i,
    // hypervisor-mode clean/flush cache block invalidate enable - CSR_REGFILE
    input logic hcbcfe_i,
    // CVXIF Compressed interface
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    input logic compressed_ready_i,
    //JVT
    input jvt_t jvt_i,
    input x_compressed_resp_t compressed_resp_i,
    output logic compressed_valid_o,
    output x_compressed_req_t compressed_req_o,
    // mcontrol6 address match breakpoint exc. generation request from trigg. module
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_decoder_action_i[CVA6Cfg.NrIssuePorts],
    // Data cache request ouput - CACHE
    input dcache_req_o_t dcache_req_ports_i,
    // Data cache request input - CACHE
    output dcache_req_i_t dcache_req_ports_o
);
```

## Parent instantiation

### `core/cva6.sv`

```systemverilog
    // this is the struct which we will inject into the pipeline to guide the various
    // units towards the correct branch decision and resolve
    localparam type branchpredict_sbe_t = struct packed {
      cf_t                     cf;               // type of control flow prediction
      logic [CVA6Cfg.VLEN-1:0] predict_address;  // target address at which to jump, or not
    },

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
    // IF/ID Stage
    // store the decompressed instruction
    localparam type fetch_entry_t = struct packed {
      logic [CVA6Cfg.VLEN-1:0] address;  // the address of the instructions from below
      logic [31:0] instruction;  // instruction word
      branchpredict_sbe_t     branch_predict; // this field contains branch prediction information regarding the forward branch path
      exception_t             ex;             // this field contains exceptions which might have happened earlier, e.g.: fetch exceptions
    },
    //JVT struct{base,mode}
    localparam type jvt_t = struct packed {
      logic [CVA6Cfg.XLEN-7:0] base;
      logic [5:0] mode;
    },

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
  id_stage #(
      .CVA6Cfg(CVA6Cfg),
      .branchpredict_sbe_t(branchpredict_sbe_t),
      .dcache_req_i_t(dcache_req_i_t),
      .dcache_req_o_t(dcache_req_o_t),
      .exception_t(exception_t),
      .fetch_entry_t(fetch_entry_t),
      .jvt_t(jvt_t),
      .irq_ctrl_t(irq_ctrl_t),
      .scoreboard_entry_t(scoreboard_entry_t),
      .interrupts_t(interrupts_t),
      .INTERRUPTS(INTERRUPTS),
      .x_compressed_req_t(x_compressed_req_t),
      .x_compressed_resp_t(x_compressed_resp_t)
  ) id_stage_i (
      .clk_i,
      .rst_ni,
      .flush_i(flush_ctrl_if),
      .debug_req_i,

      .fetch_entry_i      (fetch_entry_if_id),
      .fetch_entry_valid_i(fetch_valid_if_id),
      .fetch_entry_ready_o(fetch_ready_id_if),

      .issue_entry_o      (issue_entry_id_issue),
      .issue_entry_o_prev (issue_entry_id_issue_prev),
      .orig_instr_o       (orig_instr_id_issue),
      .issue_entry_valid_o(issue_entry_valid_id_issue),
      .is_ctrl_flow_o     (is_ctrl_fow_id_issue),
      .issue_instr_ack_i  (issue_instr_issue_id),

      .rvfi_is_compressed_o(rvfi_is_compressed),

      .priv_lvl_i             (priv_lvl),
      .v_i                    (v),
      .fs_i                   (fs),
      .vfs_i                  (vfs),
      .frm_i                  (frm_csr_id_issue_ex),
      .vs_i                   (vs),
      .irq_i                  (irq_i),
      .irq_ctrl_i             (irq_ctrl_csr_id),
      .debug_mode_i           (debug_mode),
      .tvm_i                  (tvm_csr_id),
      .tw_i                   (tw_csr_id),
      .vtw_i                  (vtw_csr_id),
      .tsr_i                  (tsr_csr_id),
      .hu_i                   (hu),
      .mcbie_i                (mcbie),
      .scbie_i                (scbie),
      .hcbie_i                (hcbie),
      .mcbcfe_i               (mcbcfe),
      .scbcfe_i               (scbcfe),
      .hcbcfe_i               (hcbcfe),
      .hart_id_i              (hart_id_i),
      .compressed_ready_i     (x_compressed_ready),
      .compressed_resp_i      (x_compressed_resp),
      .compressed_valid_o     (x_compressed_valid),
      .compressed_req_o       (x_compressed_req),
      .jvt_i                  (jvt),
      // DCACHE interfaces
      .dcache_req_ports_i     (dcache_req_ports_cache_id),
      .dcache_req_ports_o     (dcache_req_ports_id_cache),
      //Trigger Module command signal
      .sdtrig_decoder_action_i(sdtrig_decoder_action)
  );
// ...
  //RVFI INSTR
  logic [CVA6Cfg.NrIssuePorts-1:0][31:0] rvfi_fetch_instr;
  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    assign rvfi_fetch_instr[i] = fetch_entry_if_id[i].instruction;
  end

  cva6_rvfi_probes #(
      .CVA6Cfg            (CVA6Cfg),
      .exception_t        (exception_t),
      .scoreboard_entry_t (scoreboard_entry_t),
      .lsu_ctrl_t         (lsu_ctrl_t),
      .bp_resolve_t       (bp_resolve_t),
      .rvfi_probes_instr_t(rvfi_probes_instr_t),
      .rvfi_probes_csr_t  (rvfi_probes_csr_t),
      .rvfi_probes_t      (rvfi_probes_t)
  ) i_cva6_rvfi_probes (

      .flush_i            (flush_ctrl_if),
      .issue_instr_ack_i  (issue_instr_issue_id),
      .fetch_entry_valid_i(fetch_valid_if_id),
      .instruction_i      (rvfi_fetch_instr),
      .is_compressed_i    (rvfi_is_compressed),
```

## Dependency declarations

### `core/compressed_decoder.sv`

```systemverilog
module compressed_decoder #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    // Input instruction coming from fetch stage - FRONTEND
    input  logic [31:0] instr_i,
    // Output instruction in uncompressed format - decoder
    output logic [31:0] instr_o,
    // Input instruction is illegal - decoder
    output logic        illegal_instr_o,
    // Output instruction is macro - decoder
    output logic        is_macro_instr_o,
    // Output instruction is compressed - decoder
    output logic        is_compressed_o,
    // Output instruction is macro - decoder
    output logic        is_zcmt_instr_o
);
```

### `core/cvxif_compressed_if_driver.sv`

```systemverilog
module cvxif_compressed_if_driver #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type x_compressed_req_t = logic,
    parameter type x_compressed_resp_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic                    clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic                    rst_ni,
    input logic                    flush_i,
    // CVA6 Hart id
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,

    input logic        is_compressed_i,
    input logic        is_illegal_i,
    input logic [31:0] instruction_i,

    output logic                      is_compressed_o,
    output logic                      is_illegal_o,
    output logic               [31:0] instruction_o,
    input  logic                      stall_i,
    output logic                      stall_o,
    // CVXIF Compressed interface
    input  logic                      compressed_ready_i,
    input  x_compressed_resp_t        compressed_resp_i,
    output logic                      compressed_valid_o,
    output x_compressed_req_t         compressed_req_o
);


  always_comb begin
    is_illegal_o            = is_illegal_i;
    instruction_o           = instruction_i;
    is_compressed_o         = is_compressed_i;
    compressed_valid_o      = 1'b0;
    compressed_req_o.instr  = '0;
    compressed_req_o.hartid = hart_id_i;
    stall_o                 = stall_i;
    if (is_illegal_i) begin
      compressed_valid_o = is_illegal_i;
      compressed_req_o.instr = instruction_i[15:0];
      is_illegal_o = ~compressed_resp_i.accept;
      instruction_o = compressed_resp_i.accept ? compressed_resp_i.instr : instruction_i;
      is_compressed_o = compressed_resp_i.accept ? 1'b0 : is_compressed_i;
      if (~stall_i) begin
        // Propagate stall from macro decoder or wait for compressed ready if compressed transaction is happening.
        stall_o = (compressed_valid_o && ~compressed_ready_i);
      end
    end
    if (flush_i) begin
      compressed_valid_o      = 1'b0;
      compressed_req_o.instr  = '0;
      compressed_req_o.hartid = hart_id_i;
    end
  end
```

### `core/decoder.sv`

```systemverilog
module decoder
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type branchpredict_sbe_t = logic,
    parameter type exception_t = logic,
    parameter type irq_ctrl_t = logic,
    parameter type scoreboard_entry_t = logic,
    parameter type interrupts_t = logic,
    parameter interrupts_t INTERRUPTS = '0
) (
    // Debug (async) request - SUBSYSTEM
    input logic debug_req_i,
    // PC from fetch stage - FRONTEND
    input logic [CVA6Cfg.VLEN-1:0] pc_i,
    // Is a compressed instruction - compressed_decoder
    input logic is_compressed_i,
    // Compressed form of instruction - FRONTEND
    input logic [15:0] compressed_instr_i,
    // Illegal compressed instruction - compressed_decoder
    input logic is_illegal_i,
    // Instruction from fetch stage - FRONTEND
    input logic [31:0] instruction_i,
    // Is a macro instruction - macro_decoder
    input logic is_macro_instr_i,
    // Is a last macro instruction - macro_decoder
    input logic is_last_macro_instr_i,
    // Is mvsa01/mva01s macro instruction - macro_decoder
    input logic is_double_rd_macro_instr_i,
    // Zcmt instruction - FRONTEND
    input logic is_zcmt_i,
    // Jump address - zcmt_decoder
    input logic [CVA6Cfg.XLEN-1:0] jump_address_i,
    // Is a branch predict instruction - FRONTEND
    input branchpredict_sbe_t branch_predict_i,
    // If an exception occurred in fetch stage - FRONTEND
    input exception_t ex_i,
    // Level sensitive (async) interrupts - SUBSYSTEM
    input logic [1:0] irq_i,
    // Interrupt control status - CSR_REGFILE
    input irq_ctrl_t irq_ctrl_i,
    // Current privilege level - CSR_REGFILE
    input riscv::priv_lvl_t priv_lvl_i,
    // Current virtualization mode - CSR_REGFILE
    input logic v_i,
    // Is debug mode - CSR_REGFILE
    input logic debug_mode_i,
    // Floating point extension status - CSR_REGFILE
    input riscv::xs_t fs_i,
    // Virtual floating point extension status - CSR_REGFILE
    input riscv::xs_t vfs_i,
    // Floating-point dynamic rounding mode - CSR_REGFILE
    input logic [2:0] frm_i,
    // Vector extension status - CSR_REGFILE
    input riscv::xs_t vs_i,
    // Trap virtual memory - CSR_REGFILE
    input logic tvm_i,
    // Timeout wait - CSR_REGFILE
    input logic tw_i,
    // Virtual timeout wait - CSR_REGFILE
    input logic vtw_i,
    // Trap sret - CSR_REGFILE
    input logic tsr_i,
    // Hypervisor user mode - CSR_REGFILE
    input logic hu_i,
    // machine-mode cache block invalidate enable - CSR_REGFILE
    input riscv::cbie_t mcbie_i,
    // supervisor-mode cache block invalidate enable - CSR_REGFILE
    input riscv::cbie_t scbie_i,
    // hypervisor-mode cache block invalidate enable - CSR_REGFILE
    input riscv::cbie_t hcbie_i,
    // machine-mode clean/flush cache block invalidate enable - CSR_REGFILE
    input logic mcbcfe_i,
    // supervisor-mode clean/flush cache block invalidate enable - CSR_REGFILE
    input logic scbcfe_i,
    // hypervisor-mode clean/flush cache block invalidate enable - CSR_REGFILE
    input logic hcbcfe_i,
    // Instruction to be added to scoreboard entry - ISSUE_STAGE
    output scoreboard_entry_t instruction_o,
    // Instruction - ISSUE_STAGE
    output logic [31:0] orig_instr_o,
    // Is a control flow instruction - ISSUE_STAGE
    output logic is_control_flow_instr_o,
    // Exception request - TRIGGER MODULE
    input logic [CVA6Cfg.XLEN-1:0] sdtrig_decoder_action_i
);
```

## Related source code

### `core/frontend/instr_queue.sv`

```systemverilog
      pop_instr[0] = fetch_entry_valid_o[0] & fetch_entry_ready_i[0];
    end
  end

  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    assign fetch_entry_is_cf[i] = fetch_entry_o[i].branch_predict.cf != ariane_pkg::NoCF;
    assign fetch_entry_fire[i]  = fetch_entry_valid_o[i] & fetch_entry_ready_i[i];
```

### `core/issue_stage.sv`

```systemverilog
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
```

### `core/cva6_rvfi.sv`

```systemverilog
  assign flush = instr.flush;
  assign issue_instr_ack = instr.issue_instr_ack;
  assign fetch_entry_valid = instr.fetch_entry_valid;
  assign instruction = instr.instruction;
  assign is_compressed = instr.is_compressed;
// ...
  //ID STAGE

  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    assign truncated[i] = (is_compressed[i]) ? {16'b0, instruction[i][15:0]} : instruction[i];
  end

  typedef struct packed {
    logic        valid;
    logic [31:0] instr;
    logic        is_compressed;
  } issue_struct_t;
  issue_struct_t [CVA6Cfg.NrIssuePorts-1:0] issue_n, issue_q;
  logic took0;

  always_comb begin
    issue_n = issue_q;
    took0   = 1'b0;

    for (int unsigned i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
      if (issue_instr_ack[i]) begin
        issue_n[i].valid = 1'b0;
      end
    end

    if (!issue_n[CVA6Cfg.NrIssuePorts-1].valid) begin
      issue_n[CVA6Cfg.NrIssuePorts-1].valid = fetch_entry_valid[0];
      issue_n[CVA6Cfg.NrIssuePorts-1].instr = truncated[0];
      issue_n[CVA6Cfg.NrIssuePorts-1].is_compressed = is_compressed[0];
      took0 = 1'b1;
    end
```

## Documentation

### `docs/design/design-manual/source/cva6_id_stage.adoc`

```text
The ID_STAGE module implements the decode stage of the pipeline. Its
main purpose is to decode RISC-V instructions coming from FRONTEND
module (fetch stage) and send them to the ISSUE_STAGE module (issue
stage).

The compressed_decoder module checks whether the incoming instruction is
compressed and output the corresponding uncompressed instruction. Then
the decoder module decodes the instruction and send it to the issue
stage.

The module is connected to:

* CONTROLLER module can request to flush the buffer at the end of ID_STAGE
* FRONTEND module sends instructions to ID_STAGE module
* ISSUE module receives the decoded instructions from ID_STAGE module
* CSR_REGFILE module sends status information about privilege mode,
traps, extension support.

include::port_id_stage.adoc[]

[[id_stage-functionality]]
Functionality
^^^^^^^^^^^^^

ID_STAGE transforms each instruction into a scoreboard entry whose fields indicate what the instruction does.
It receives external interrupts and, according to the interrupts configuration from CSR_REGFILE, it inserts exceptions in the pipeline.
ifeval::[{SuperscalarEn} == true]
It outputs scoreboard entries via a FIFO of depth 2, which can push and pull up to 2 instructions each cycle.
endif::[]
```
