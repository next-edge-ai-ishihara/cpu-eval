# Implement `issue_read_operands`

Implement the complete `issue_read_operands` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module issue_read_operands` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(32),
      FpgaEn: bit'(0),
      FpgaAlteraEn: bit'(0),
// ...
      SuperscalarEn: bit'(0),
      ALUBypass: bit'(0),
      NrCommitPorts: unsigned'(1),
// ...
      RVF: bit'(0),
      RVD: bit'(0),
      XF16: bit'(0),
      XF16ALT: bit'(0),
      XF8: bit'(0),
// ...
      ZKN: bit'(0),
      RVV: bit'(0),
// ...
      RVH: bit'(0),
      RVZCMT: bit'(0),
// ...
      CvxifEn: bit'(1),
      CoproType: config_pkg::COPRO_EXAMPLE,
// ...
      NrScoreboardEntries: unsigned'(4),
// ...
      RVS: bit'(0),
```

### core/include/build_config_pkg.sv

```systemverilog
  function automatic config_pkg::cva6_cfg_t build_config(config_pkg::cva6_user_cfg_t CVA6Cfg);
    bit IS_XLEN32 = (CVA6Cfg.XLEN == 32) ? 1'b1 : 1'b0;
    bit IS_XLEN64 = (CVA6Cfg.XLEN == 32) ? 1'b0 : 1'b1;
    bit FpPresent = CVA6Cfg.RVF | CVA6Cfg.RVD | CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8;
// ...
    int unsigned FLen = CVA6Cfg.RVD ? 64 :  // D ext.
    CVA6Cfg.RVF ? 32 :  // F ext.
    CVA6Cfg.XF16 ? 16 :  // Xf16 ext.
    CVA6Cfg.XF16ALT ? 16 :  // Xf16alt ext.
    CVA6Cfg.XF8 ? 8 :  // Xf8 ext.
    1;  // Unused in case of no FP
// ...
    bit EnableAccelerator = CVA6Cfg.RVV;  // Currently only used by V extension (Ara)
    int unsigned NrWbPorts = (CVA6Cfg.CvxifEn || EnableAccelerator) ? 5 : 4;
// ...
    cfg.XLEN = CVA6Cfg.XLEN;
    cfg.VLEN = CVA6Cfg.VLEN;
// ...
    cfg.FpgaEn = CVA6Cfg.FpgaEn;
    cfg.FpgaAlteraEn = CVA6Cfg.FpgaAlteraEn;
// ...
    cfg.SuperscalarEn = CVA6Cfg.SuperscalarEn;
    cfg.NrCommitPorts = CVA6Cfg.SuperscalarEn ? unsigned'(2) : CVA6Cfg.NrCommitPorts;
    cfg.NrIssuePorts = unsigned'(CVA6Cfg.SuperscalarEn ? 2 : 1);
    cfg.SpeculativeSb = CVA6Cfg.SuperscalarEn;

    cfg.NrALUs = CVA6Cfg.SuperscalarEn ? unsigned'(2) : unsigned'(1);
    cfg.ALUBypass = CVA6Cfg.SuperscalarEn ? bit'(CVA6Cfg.ALUBypass) : bit'(0);
// ...
    cfg.ZKN = CVA6Cfg.ZKN;
// ...
    cfg.RVH = CVA6Cfg.RVH;
// ...
    cfg.RVZCMT = CVA6Cfg.RVZCMT;
// ...
    cfg.CvxifEn = CVA6Cfg.CvxifEn;
// ...
    cfg.NR_SB_ENTRIES = CVA6Cfg.NrScoreboardEntries;
    cfg.TRANS_ID_BITS = $clog2(CVA6Cfg.NrScoreboardEntries);
// ...
    cfg.FpPresent = bit'(FpPresent);
// ...
    cfg.FLen = unsigned'(FLen);
// ...
    // Can take 2 or 3 in single issue. 4 or 6 in dual issue.
    cfg.NrRgprPorts = unsigned'(CVA6Cfg.SuperscalarEn ? 4 : 2);
    // cfg.NrRgprPorts = unsigned'(CVA6Cfg.SuperscalarEn ? 6 : 3);
    cfg.NrWbPorts = unsigned'(NrWbPorts);
// ...
    cfg.RVS = CVA6Cfg.RVS;
// ...
    cfg.X_NUM_RS = cfg.NrRgprPorts / cfg.NrIssuePorts;
    cfg.X_ID_WIDTH = cfg.TRANS_ID_BITS;
    cfg.X_RFR_WIDTH = cfg.XLEN;
    cfg.X_RFW_WIDTH = cfg.XLEN;
    cfg.X_NUM_HARTS = 1;
    cfg.X_HARTID_WIDTH = cfg.XLEN;
    cfg.X_DUALREAD = 0;
    cfg.X_DUALWRITE = 0;
    cfg.X_ISSUE_REGISTER_SPLIT = 0;
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
  typedef struct packed {
    logic rs1_from_rd;
    logic rs2_from_rd;
  } alu_bypass_t;
```

### core/include/cvxif_types.svh

```systemverilog
`define X_ISSUE_REQ_T(Cfg, hartid_t, id_t) struct packed { \
    logic [31:0] instr; /*Offloaded instruction*/ \
    hartid_t hartid; /*Identification of the hart offloading the instruction*/ \
    id_t id; /*Identification of the offloaded instruction*/ \
}
`define X_ISSUE_RESP_T(Cfg, writeregflags_t, readregflags_t) struct packed { \
    logic accept; /*Is the offloaded instruction (id) accepted by the coprocessor?*/ \
    writeregflags_t writeback; /*Will the coprocessor perform a writeback in the core to rd?*/ \
    readregflags_t register_read; /*Will the coprocessor perform require specific registers to be read?*/ \
}

`define X_REGISTER_T(Cfg, hartid_t, id_t, readregflags_t) struct packed { \
    hartid_t hartid;  /*Identification of the hart offloading the instruction*/ \
    id_t id;  /*Identification of the offloaded instruction*/ \
    logic [Cfg.X_NUM_RS-1:0][Cfg.X_RFR_WIDTH-1:0] rs;  /*Register file source operands for the offloaded instruction.*/ \
    readregflags_t rs_valid; /*Validity of the register file source operand(s).*/ \
}

`define X_COMMIT_T(Cfg, hartid_t, id_t) struct packed { \
    hartid_t hartid;  /*Identification of the hart offloading the instruction*/ \
    id_t id;  /*Identification of the offloaded instruction*/ \
    logic commit_kill;  /*Shall an offloaded instruction be killed?*/ \
}
```

## Module declaration

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

## Parent instantiation

### core/cva6.sv

```systemverilog
    // branchpredict scoreboard entry
    // this is the struct which we will inject into the pipeline to guide the various
    // units towards the correct branch decision and resolve
    localparam type branchpredict_sbe_t = struct packed {
      cf_t                     cf;               // type of control flow prediction
      logic [CVA6Cfg.VLEN-1:0] predict_address;  // target address at which to jump, or not
    },
// ...
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
    localparam type writeback_t = struct packed {
      logic valid;  // wb data is valid
      logic [CVA6Cfg.XLEN-1:0] data;  //wb data
      logic ex_valid;  // exception from WB
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;  //transaction ID
    },
// ...
    localparam type fu_data_t = struct packed {
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.XLEN-1:0]          operand_a;
      logic [CVA6Cfg.XLEN-1:0]          operand_b;
      logic [CVA6Cfg.XLEN-1:0]          imm;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
    },
// ...
    // CVXIF Types
    parameter type readregflags_t = `READREGFLAGS_T(CVA6Cfg),
    parameter type writeregflags_t = `WRITEREGFLAGS_T(CVA6Cfg),
    parameter type id_t = `ID_T(CVA6Cfg),
    parameter type hartid_t = `HARTID_T(CVA6Cfg),
// ...
    parameter type x_issue_req_t = `X_ISSUE_REQ_T(CVA6Cfg, hartid_t, id_t),
    parameter type x_issue_resp_t = `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t),
    parameter type x_register_t = `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t),
    parameter type x_commit_t = `X_COMMIT_T(CVA6Cfg, hartid_t, id_t),
```

### core/issue_stage.sv

```systemverilog
  // ---------------------------------------------------
  // Scoreboard (SB) <-> Issue and Read Operands (IRO)
  // ---------------------------------------------------
  typedef logic [(CVA6Cfg.NrRgprPorts == 3 ? CVA6Cfg.XLEN : CVA6Cfg.FLen)-1:0] rs3_len_t;
  typedef struct packed {
    logic [CVA6Cfg.NR_SB_ENTRIES-1:0] still_issued;
    logic [CVA6Cfg.TRANS_ID_BITS-1:0] issue_pointer;
    writeback_t [CVA6Cfg.NrWbPorts-1:0] wb;
    scoreboard_entry_t [CVA6Cfg.NR_SB_ENTRIES-1:0] sbe;
  } forwarding_t;

  forwarding_t                                        fwd;
  scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0]       issue_instr_sb_iro;
  logic              [CVA6Cfg.NrIssuePorts-1:0][31:0] orig_instr_sb_iro;
  logic              [CVA6Cfg.NrIssuePorts-1:0]       issue_instr_valid_sb_iro;
  logic              [CVA6Cfg.NrIssuePorts-1:0]       issue_ack_iro_sb;

  assign issue_instr_o    = issue_instr_sb_iro[0];
  assign issue_instr_hs_o = issue_instr_valid_sb_iro[0] & issue_ack_iro_sb[0];
// ...
  // ---------------------------------------------------------
  // 3. Issue instruction and read operand, also commit
  // ---------------------------------------------------------
  issue_read_operands #(
      .CVA6Cfg(CVA6Cfg),
      .branchpredict_sbe_t(branchpredict_sbe_t),
      .fu_data_t(fu_data_t),
      .scoreboard_entry_t(scoreboard_entry_t),
      .rs3_len_t(rs3_len_t),
      .writeback_t(writeback_t),
      .forwarding_t(forwarding_t),
      .x_issue_req_t(x_issue_req_t),
      .x_issue_resp_t(x_issue_resp_t),
      .x_register_t(x_register_t),
      .x_commit_t(x_commit_t)
  ) i_issue_read_operands (
      .clk_i,
      .rst_ni,
      .flush_i                 (flush_unissued_instr_i),
      .stall_i,
      .issue_instr_i           (issue_instr_sb_iro),
      .issue_instr_i_prev      (decoded_instr_i_prev),
      .orig_instr_i            (orig_instr_sb_iro),
      .issue_instr_valid_i     (issue_instr_valid_sb_iro),
      .issue_ack_o             (issue_ack_iro_sb),
      .fwd_i                   (fwd),
      .fu_data_o               (fu_data_o),
      .alu_bypass_o            (alu_bypass_o),
      .rs1_forwarding_o        (rs1_forwarding_o),
      .rs2_forwarding_o        (rs2_forwarding_o),
      .pc_o,
      .is_zcmt_o,
      .is_compressed_instr_o,
      .flu_ready_i             (flu_ready_i),
      .alu_valid_o             (alu_valid_o),
      .aes_valid_o             (aes_valid_o),
      .branch_valid_o          (branch_valid_o),
      .tinst_o                 (tinst_o),
      .branch_predict_o,
      .lsu_ready_i,
      .lsu_valid_o,
      .mult_valid_o,
      .fpu_ready_i,
      .fpu_valid_o,
      .fpu_fmt_o,
      .fpu_rm_o,
      .fpu_early_valid_i,
      .alu2_valid_o,
      .csr_valid_o,
      .cvxif_valid_o           (xfu_valid_o),
      .cvxif_ready_i           (xfu_ready_i),
      .cvxif_off_instr_o       (x_off_instr_o),
      .hart_id_i               (hart_id_i),
      .x_issue_ready_i         (x_issue_ready_i),
      .x_issue_resp_i          (x_issue_resp_i),
      .x_issue_valid_o         (x_issue_valid_o),
      .x_issue_req_o           (x_issue_req_o),
      .x_register_ready_i      (x_register_ready_i),
      .x_register_valid_o      (x_register_valid_o),
      .x_register_o            (x_register_o),
      .x_commit_valid_o        (x_commit_valid_o),
      .x_commit_o              (x_commit_o),
      .x_transaction_accepted_o(x_transaction_accepted_iro_sb),
      .x_transaction_rejected_o(x_transaction_rejected_o),
      .x_issue_writeback_o     (x_issue_writeback_iro_sb),
      .x_id_o                  (x_id_iro_sb),
      .waddr_i,
      .wdata_i,
      .we_gpr_i,
      .we_fpr_i,
      .stall_issue_o,
      .rvfi_rs1_o              (rvfi_rs1_o),
      .rvfi_rs2_o              (rvfi_rs2_o),
      .orig_instr_aes_bits     (orig_instr_aes_bits)
  );
```

## Dependency declarations

### core/raw_checker.sv

```systemverilog
module raw_checker
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Register source of the instruction to check RAW dependencies - SCOREBOARD
    input logic [REG_ADDR_SIZE-1:0] rs_i,
    // Type of register source (FPR or GPR) - SCOREBOARD
    input logic rs_fpr_i,
    // Registers of destination of the instructions already issued in the scoreboard - SCOREBOARD 
    input logic [CVA6Cfg.NR_SB_ENTRIES-1:0][REG_ADDR_SIZE-1:0] rd_i,
    // Type of registers of destination (FPR or GPR) - SCOREBOARD
    input logic [CVA6Cfg.NR_SB_ENTRIES-1:0] rd_fpr_i,
    // Instructions in the scoreboard are still issued - SCOREBOARD
    input logic [CVA6Cfg.NR_SB_ENTRIES-1:0] still_issued_i,
    // Issue pointer - SCOREBOARD
    input logic [CVA6Cfg.TRANS_ID_BITS-1:0] issue_pointer_i,

    // Index in the scoreboard of the most recent RAW dependency - SCOREBOARD
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] idx_o,
    // Indicates if there is a RAW dependency - SCOREBOARD
    output logic valid_o
);
```

### core/ariane_regfile_ff.sv

```systemverilog
// Description:    Register file with 31 or 15x 32 bit wide registers.
//                 Register 0 is fixed to 0. This register file is based on
//                 flip flops.
//

module ariane_regfile #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg       = config_pkg::cva6_cfg_empty,
    parameter int unsigned           DATA_WIDTH    = 32,
    parameter int unsigned           NR_READ_PORTS = 2,
    parameter bit                    ZERO_REG_ZERO = 0
) (
    // clock and reset
    input  logic                                             clk_i,
    input  logic                                             rst_ni,
    // disable clock gates for testing
    input  logic                                             test_en_i,
    // read port
    input  logic [        NR_READ_PORTS-1:0][           4:0] raddr_i,
    output logic [        NR_READ_PORTS-1:0][DATA_WIDTH-1:0] rdata_o,
    // write port
    input  logic [CVA6Cfg.NrCommitPorts-1:0][           4:0] waddr_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0][DATA_WIDTH-1:0] wdata_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0]                 we_i
);
```

### core/cvxif_issue_register_commit_if_driver.sv

```systemverilog
module cvxif_issue_register_commit_if_driver #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type x_issue_req_t = logic,
    parameter type x_issue_resp_t = logic,
    parameter type x_register_t = logic,
    parameter type x_commit_t = logic
) (
    // CVA6 inputs
    input logic clk_i,
    input logic rst_ni,
    input logic flush_i,
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    // CVXIF Issue interface
    input logic issue_ready_i,
    input x_issue_resp_t issue_resp_i,
    output logic issue_valid_o,
    output x_issue_req_t issue_req_o,
    // CVXIF Register interface
    input logic register_ready_i,
    output logic register_valid_o,
    output x_register_t register_o,
    // CVXIF Commit interface
    output logic commit_valid_o,
    output x_commit_t commit_o,
    // IRO in/out
    input logic valid_i,
    input logic [31:0] x_off_instr_i,
    input logic [CVA6Cfg.TRANS_ID_BITS-1:0] x_trans_id_i,
    input [(CVA6Cfg.NrRgprPorts/CVA6Cfg.NrIssuePorts)-1:0][CVA6Cfg.XLEN-1:0] register_i,
    input logic [(CVA6Cfg.NrRgprPorts/CVA6Cfg.NrIssuePorts)-1:0] rs_valid_i
);
```

## Related source code

### core/alu.sv

```systemverilog
  assign operand_a = fu_data_i.operand_a;
  assign operand_b = fu_data_i.operand_b;
// ...
  assign adder_op_b_negate = fu_data_i.operation inside {EQ, NE, SUB, SUBW, ANDN, ORN, XNOR};
// ...
  // prepare operand a
  assign adder_in_a         = {operand_a_bitmanip, 1'b1};

  // prepare operand b
  assign operand_b_neg      = {operand_b, 1'b0} ^ {CVA6Cfg.XLEN + 1{adder_op_b_negate}};
  assign adder_in_b         = operand_b_neg;

  // actual adder
  assign adder_result_ext_o = adder_in_a + adder_in_b;
  assign adder_result       = adder_result_ext_o[CVA6Cfg.XLEN:1];
  assign adder_z_flag       = ~|adder_result;

  // get the right branch comparison result
  if (HasBranch) begin
    always_comb begin : branch_resolve
      // set comparison by default
      case (fu_data_i.operation)
        EQ:       alu_branch_res_o = adder_z_flag;
        NE:       alu_branch_res_o = ~adder_z_flag;
        LTS, LTU: alu_branch_res_o = less;
        GES, GEU: alu_branch_res_o = ~less;
        default:  alu_branch_res_o = 1'b1;
      endcase
    end
  end else begin
    assign alu_branch_res_o = 1'b0;
  end
```

### core/branch_unit.sv

```systemverilog
    jump_base = (fu_data_i.operation == ariane_pkg::JALR) ? fu_data_i.operand_a[CVA6Cfg.VLEN-1:0] : pc_i;
// ...
    target_address = $unsigned($signed(jump_base) + $signed(fu_data_i.imm[CVA6Cfg.VLEN-1:0]));
```

### core/cva6.sv

```systemverilog
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
```

### core/load_store_unit.sv

```systemverilog
  assign vaddr_xlen = $unsigned($signed(fu_data_i.imm) + $signed(fu_data_i.operand_a));
// ...
  lsu_ctrl_t lsu_req_i;

  assign lsu_req_i = {
    lsu_valid_i,
    vaddr_i,
    tinst_i,
    hs_ld_st_inst,
    hlvx_inst,
    overflow,
    g_overflow,
    fu_data_i.operand_b,
    be_i,
    fu_data_i.fu,
    fu_data_i.operation,
    fu_data_i.trans_id,
    speculative_load_i,
    1'b0
  };
```

## Documentation

### docs/design/design-manual/source/cva6_issue_stage.adoc

```text
(1) ISSUE_STAGE issues instructions in-order.
It makes sure that instructions from ID_STAGE have everything they need to run.
It waits until all requirements are met.
Once an instruction is ready to run, ISSUE_STAGE sends it to EX_STAGE with its operands.
...
(1) ISSUE_STAGE issues instructions.
Instructions from ID_STAGE are sent to Scoreboard module, which forwards them to Issue_read_operands module.
Issue_read_operands queries Scoreboard module for data dependencies (Scoreboard is also able to return forwarded values) and gets the list of busy functional units from EX_STAGE.
Issue_read_operands sends to EX_STAGE the instructions to execute and acknowledges to Scoreboard so that it stores them: the instruction is issued.
Issued instructions are acknowledged to ID_STAGE.
Each of these steps can block its successors.
The flush signal from CONTROLLER module is also sent to Scoreboard module to prevent from issuing.
Instructions are issued in-order: an instruction cannot be issued unless all its predecessors are issued.
...
[[issue_read_operands]]
Issue_read_operands
+++++++++++++++++++

Issue_read_operands tracks hazards and gets the input operands for the instructions to execute.
The following hazards can prevent instructions from being issued.

* Data hazards: ISSUE_STAGE checks that the instruction operands are available.

** [[raw_hazard]] Read-After-Write (RAW): if one of the source registers of the instruction to issue is the destination register of one of the instructions in the Scoreboard, issue is blocked.
However, CVA6 implements operand forwarding: instead of blocking the instruction, the operand is taken from either +
a) a functional unit which returns a result which is not an exception, with a transaction ID which points to a Scoreboard entry whose destination register is the requested source register; +
b) a Scoreboard entry whose destination register is the requested source register has a result which is not an exception. +
Forwarding is not possible from CSR instructions.
...
** Special case: there are no data hazards on `x0`.

...
* Structural hazards: ISSUE_STAGE checks that a functional unit (FU) and its result bus (RB) are ready to execute the instruction.

** Integer division instructions and some^[FIXME{sp}which?]^ CSR instructions have an unknown latency.
When EX_STAGE reports that such an instruction is running, instructions using ALU, BRANCH, CSR or MULT are blocked.
This is to avoid conflicts on the RB shared by these four FUs.
...
** Multiplications have a fixed latency of 2 cycles.
Instructions using ALU, BRANCH or CSR are blocked if an instruction using MULT was issued one cycle earlier.
This is to avoid conflicts on the RB shared by these four FUs.
...
Instructions using MULT are not blocked because the multiplier is pipelined and can accept one instruction each cycle.
...
** Instructions using LSU are blocked if LSU is not ready.
...
Data hazards are ignored when an exception occurred earlier in the pipeline.
As no FU is involved, there are no structural hazards either.

Instructions are issued in-order, which means that when an instruction makes ISSUE_STAGE stall, next instructions are blocked.
...
The input operands provided to EX_STAGE come from the register file by default.
However, when one of the source registers has a RAW dependence, the corresponding input operand is replaced by the forwarded value (see <<raw_hazard,Data hazards/RAW hazards>> above).
The register file is an instance of `ariane_regfile` where ach register stores {XLEN} bits and the register at index 0 is wired to zero.
...
Instructions are sent to EX_STAGE via a register so they are visible in EX_STAGE one cycle after being issued.
```

### docs/source/x_ext.rst

```text
Issue interface
~~~~~~~~~~~~~~~
:numref:`Issue interface signals` describes the issue interface signals.

.. table:: Issue interface signals
  :name: Issue interface signals
  :class: no-scrollbar-table
  :widths: 20 20 10 50

  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | Signal                    | Type            | Direction       | Description                                                                                                                  |
  |                           |                 | (|processor|)   |                                                                                                                              |
  +===========================+=================+=================+==============================================================================================================================+
  | ``issue_valid``           | logic           | output          | Issue request valid. Indicates that |processor| wants to offload an instruction.                                             |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``issue_ready``           | logic           | input           | Issue request ready. The transaction signaled via ``issue_req`` and ``issue_resp`` is accepted when                          |
  |                           |                 |                 | ``issue_valid`` and  ``issue_ready`` are both 1.                                                                             |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``issue_req``             | x_issue_req_t   | output          | Issue request packet.                                                                                                        |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``issue_resp``            | x_issue_resp_t  | input           | Issue response packet.                                                                                                       |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+

:numref:`Issue request type` describes the ``x_issue_req_t`` type.

.. table:: Issue request type
  :name: Issue request type
  :class: no-scrollbar-table
  :widths: 20 20 60

  +------------------------+----------------------------------------+-----------------------------------------------------------------------------------------------------------------+
  | Signal                 | Type                                   | Description                                                                                                     |
  +========================+========================================+=================================================================================================================+
  | ``instr``              | logic [31:0]                           | Offloaded instruction.                                                                                          |
  +------------------------+----------------------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``hartid``             | :ref:`hartid_t <hartid>`               | Identification of the hart offloading the instruction.                                                          |
  +------------------------+----------------------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``id``                 | :ref:`id_t <id>`                       | Identification of the offloaded instruction.                                                                    |
  |                        |                                        |                                                                                                                 |
  |                        |                                        |                                                                                                                 |
  +------------------------+----------------------------------------+-----------------------------------------------------------------------------------------------------------------+

An issue request transaction is defined as the combination of all ``issue_req`` signals during which ``issue_valid`` is 1, and the ``id`` and ``hartid`` remain unchanged.
A |processor| is allowed to retract its issue request transaction before it is accepted with ``issue_ready`` = 1 and it can do so in the following ways:

* Set ``issue_valid`` = 0.
* Keep ``issue_valid`` = 1, but change the ``id`` or ``hartid`` signal (and if desired change the other signals in ``issue_req``).

The ``instr``, ``hartid``, and ``id`` signals are valid when ``issue_valid`` is 1.
...
:numref:`Issue response type` describes the ``x_issue_resp_t`` type.

.. table:: Issue response type
  :name: Issue response type
  :class: no-scrollbar-table
  :widths: 20 20 60

  +------------------------+------------------------+------------------------------------------------------------------------------------------------------------------+
  | Signal                 | Type                   | Description                                                                                                      |
  +========================+========================+==================================================================================================================+
  | ``accept``             | logic                  | Is the offloaded instruction (``id`` and ``hartid``) accepted (1) by the |coprocessor| or rejected (0)?          |
  +------------------------+------------------------+------------------------------------------------------------------------------------------------------------------+
  | ``writeback``          | :ref:`writeregflags_t  | Will the |coprocessor| perform a write-back in the |processor| to ``rd``?                                        |
  |                        | <writeregflags>`       | Write-back to ``x0`` or the ``x0``, ``x1`` pair is allowed by the |coprocessor|,                                 |
  |                        |                        | but will be ignored by the |processor|.                                                                          |
  |                        |                        | Write-back to a register pair is only allowed if ``X_DUALWRITE`` = 1 and instruction bits ``[11:7]`` are even.   |
  +------------------------+------------------------+------------------------------------------------------------------------------------------------------------------+
  | ``register_read``      | :ref:`readregflags_t   | Will the |coprocessor| perform require specific registers to be read?                                            |
  |                        | <readregflags>`        | A |coprocessor| may only request an odd register of a pair, if it also requests the even register of a pair.     |
  +------------------------+------------------------+------------------------------------------------------------------------------------------------------------------+
...
The |processor| shall attempt to offload instructions via the issue interface for the following two main scenarios:

* The instruction is originally non-compressed and it is not recognized as a valid instruction by the |processor|'s non-compressed instruction decoder.
* The instruction is originally compressed and the |coprocessor| accepted the compressed instruction and provided a 32-bit uncompressed instruction.
  In this case the 32-bit uncompressed instruction will be attempted for offload even if it matches in the |processor|'s non-compressed instruction decoder.

Apart from the above two main scenarios a |processor| may also attempt to offload
(compressed/uncompressed) instructions that it does recognize as legal instructions itself. In case that both the |processor| and the |coprocessor| accept the same instruction as being valid,
the instruction will cause an illegal instruction fault upon execution.

In all cases, the |processor| must decode the instruction.
The |processor| shall cause an illegal instruction fault when attempting to execute (commit) an instruction that:

* is considered to be valid by the |processor| and accepted by the |coprocessor| (``accept`` = 1).
* is considered neither to be valid by the |processor| nor accepted by the |coprocessor| (``accept`` = 0).

A |coprocessor| can delay accept accepting an instruction via ``issue_ready`` in the presence of structural hazards that would prevent execution.
A |coprocessor| can (only) accept an offloaded instruction when it can handle the instruction (based on decoding ``instr``).

A transaction is considered offloaded/accepted on the positive edge of ``clk`` when ``issue_valid``, ``issue_ready`` are asserted and ``accept`` is 1.
A transaction is considered not offloaded/rejected on the positive edge of ``clk`` when ``issue_valid`` and ``issue_ready`` are asserted while ``accept`` is 0.

The signals in ``issue_resp`` are valid when ``issue_valid`` and ``issue_ready`` are both 1. There are no stability requirements.
...
Register interface
~~~~~~~~~~~~~~~~~~
:numref:`Register interface signals` describes the register interface signals.

.. table:: Register interface signals
  :name: Register interface signals
  :class: no-scrollbar-table
  :widths: 20 20 10 50

  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | Signal                    | Type            | Direction       | Description                                                                                                                  |
  |                           |                 | (|processor|)   |                                                                                                                              |
  +===========================+=================+=================+==============================================================================================================================+
  | ``register_valid``        | logic           | output          | Register request valid. Indicates that |processor| provides register contents related to an instruction.                     |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``register_ready``        | logic           | input           | Register request ready. The transaction signaled via ``register_req`` is accepted when                                       |
  |                           |                 |                 | ``register_valid`` and  ``register_ready`` are both 1.                                                                       |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``register``              | x_register_t    | output          | Register packet.                                                                                                             |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+

:numref:`Register type` describes the ``x_register_t`` type.

.. table:: Register type
  :name: Register type
  :class: no-scrollbar-table
  :widths: 20 20 60

  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+
  | Signal                 | Type                     | Description                                                                                                     |
  +========================+==========================+=================================================================================================================+
  | ``hartid``             | :ref:`hartid_t <hartid>` | Identification of the hart offloading the instruction.                                                          |
  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``id``                 | :ref:`id_t <id>`         | Identification of the offloaded instruction.                                                                    |
  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``rs[X_NUM_RS-1:0]``   | logic [X_RFR_WIDTH-1:0]  | Register file source operands for the offloaded instruction.                                                    |
  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``rs_valid``           | :ref:`readregflags_t     | Validity of the register file source operand(s). If register pairs are supported, the validity is signaled for  |
  |                        | <readregflags>`          | each register within the pair individually.                                                                     |
  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+
...
There are two main scenarios, in how the register interface will be used. They are selected by ``X_ISSUE_REGISTER_SPLIT``:

1. ``X_ISSUE_REGISTER_SPLIT`` = 0: A register transaction can be started in the same clock cycle as the issue transaction (``issue_valid = register_valid``, ``issue_ready = register_ready``, ``issue_req.hartid = register.hartid`` and ``issue_req.id = register.id``).
   In this case, the |processor| will speculatively provide all possible source registers via ``register.rs`` when they become available (signalled via the respective ``rs_valid`` signals).
   The |coprocessor| will delay accepting the instruction until all necessary registers are provided, and only then assert ``issue_ready`` and ``register_ready``.
   The ``rs_valid`` bits are not required to be stable during the transaction.
   Each bit can transition from 0 to 1, but is not allowed to transition back to 0 during a transaction.
   A |coprocessor| is not expected to wait for all ``rs_valid`` bits to be 1, but only for those registers it intends to read.
   The ``rs`` signals are only required to be stable during the part of a transaction in which these signals are considered to be valid.
```
