# Implement `decoder`

Implement the complete `decoder` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module decoder` definition in a single SystemVerilog code block, with no text outside the block.

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
package ariane_pkg;
// ...
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
// ...
  typedef enum logic [7:0] {  // basic ALU op
    ADD,
    SUB,
    ADDW,
    SUBW,
    // logic operations
    XORL,
    ORL,
    ANDL,
    // shifts
    SRA,
    SRL,
    SLL,
    SRLW,
    SLLW,
    SRAW,
    // comparisons
    LTS,
    LTU,
    GES,
    GEU,
    EQ,
    NE,
    // jumps
    JALR,
    BRANCH,
    // set lower than operations
    SLTS,
    SLTU,
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
    // LSU functions
    LD,
    SD,
    LW,
    LWU,
    SW,
    LH,
    LHU,
    SH,
    LB,
    SB,
    LBU,
    // Hypervisor Virtual-Machine Load and Store Instructions
    HLV_B,
    HLV_BU,
    HLV_H,
    HLV_HU,
    HLVX_HU,
    HLV_W,
    HLVX_WU,
    HSV_B,
    HSV_H,
    HSV_W,
    HLV_WU,
    HLV_D,
    HSV_D,
    // Atomic Memory Operations
    AMO_LRW,
    AMO_LRD,
    AMO_SCW,
    AMO_SCD,
    AMO_SWAPW,
    AMO_ADDW,
    AMO_ANDW,
    AMO_ORW,
    AMO_XORW,
    AMO_MAXW,
    AMO_MAXWU,
    AMO_MINW,
    AMO_MINWU,
    AMO_SWAPD,
    AMO_ADDD,
    AMO_ANDD,
    AMO_ORD,
    AMO_XORD,
    AMO_MAXD,
    AMO_MAXDU,
    AMO_MIND,
    AMO_MINDU,
    // cache block operations (CBO)
    CBO_CLEAN,
    CBO_FLUSH,
    CBO_INVAL,
    CBO_NONE,
    // Multiplications
    MUL,
    MULH,
    MULHU,
    MULHSU,
    MULW,
    // Divisions
    DIV,
    DIVU,
    DIVW,
    DIVUW,
    REM,
    REMU,
    REMW,
    REMUW,
    // Floating-Point Load and Store Instructions
    FLD,
    FLW,
    FLH,
    FLB,
    FSD,
    FSW,
    FSH,
    FSB,
    // Floating-Point Computational Instructions
    FADD,
    FSUB,
    FMUL,
    FDIV,
    FMIN_MAX,
    FSQRT,
    FMADD,
    FMSUB,
    FNMSUB,
    FNMADD,
    // Floating-Point Conversion and Move Instructions
    FCVT_F2I,
    FCVT_I2F,
    FCVT_F2F,
    FSGNJ,
    FMV_F2X,
    FMV_X2F,
    // Floating-Point Compare Instructions
    FCMP,
    // Floating-Point Classify Instruction
    FCLASS,
    // Vectorial Floating-Point Instructions that don't directly map onto the scalar ones
    VFMIN,
    VFMAX,
    VFSGNJ,
    VFSGNJN,
    VFSGNJX,
    VFEQ,
    VFNE,
    VFLT,
    VFGE,
    VFLE,
    VFGT,
    VFCPKAB_S,
    VFCPKCD_S,
    VFCPKAB_D,
    VFCPKCD_D,
    // Offload Instructions to be directed into cv_x_if
    OFFLOAD,
    // Or-Combine and REV8
    ORCB,
    REV8,
    // Bitwise Rotation
    ROL,
    ROLW,
    ROR,
    RORI,
    RORIW,
    RORW,
    // Sign and Zero Extend
    SEXTB,
    SEXTH,
    ZEXTH,
    // Count population
    CPOP,
    CPOPW,
    // Count Leading/Training Zeros
    CLZ,
    CLZW,
    CTZ,
    CTZW,
    // Carry less multiplication Op's
    CLMUL,
    CLMULH,
    CLMULR,
    // Single bit instructions Op's
    BCLR,
    BCLRI,
    BEXT,
    BEXTI,
    BINV,
    BINVI,
    BSET,
    BSETI,
    // Integer minimum/maximum
    MAX,
    MAXU,
    MIN,
    MINU,
    // Shift with Add Unsigned Word and Unsigned Word Op's (Bitmanip)
    SH1ADDUW,
    SH2ADDUW,
    SH3ADDUW,
    ADDUW,
    SLLIUW,
    // Shift with Add (Bitmanip)
    SH1ADD,
    SH2ADD,
    SH3ADD,
    // Bitmanip Logical with negate op (Bitmanip)
    ANDN,
    ORN,
    XNOR,
    // Accelerator operations
    ACCEL_OP,
    ACCEL_OP_FS1,
    ACCEL_OP_FD,
    ACCEL_OP_LOAD,
    ACCEL_OP_STORE,
    // Zicond instruction
    CZERO_EQZ,
    CZERO_NEZ,
    // Pack instructions
    PACK,
    PACK_H,
    PACK_W,
    // Brev8 instruction
    BREV8,
    // Zip instructions
    UNZIP,
    ZIP,
    // Xperm instructions
    XPERM8,
    XPERM4,
    // AES Encryption instructions
    AES32ESI,
    AES32ESMI,
    AES64ES,
    AES64ESM,
    // AES Decryption instructions
    AES32DSI,
    AES32DSMI,
    AES64DS,
    AES64DSM,
    AES64IM,
    // AES Key-Schedule instructions
    AES64KS1I,
    AES64KS2,
    // Hashing instructions
    SHA256SIG0,
    SHA256SIG1,
    SHA256SUM0,
    SHA256SUM1,
    SHA512SIG0H,
    SHA512SIG0L,
    SHA512SIG1H,
    SHA512SIG1L,
    SHA512SUM0R,
    SHA512SUM1R,
    SHA512SIG0,
    SHA512SIG1,
    SHA512SUM0,
    SHA512SUM1
  } fu_op;

```

### `core/include/riscv_pkg.sv`

```systemverilog
package riscv;
// ...
  typedef enum logic [1:0] {
    PRIV_LVL_M  = 2'b11,
    PRIV_LVL_HS = 2'b10,
    PRIV_LVL_S  = 2'b01,
    PRIV_LVL_U  = 2'b00
  } priv_lvl_t;

  // type which holds xlen
  typedef enum logic [1:0] {
    XLEN_NA  = 2'b00,  // Used for mstatus.{S/U}XL when {S/U} not implemented
    XLEN_32  = 2'b01,
    XLEN_64  = 2'b10,
    XLEN_128 = 2'b11
  } xlen_e;

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
  // --------------------
  // Instruction Types
  // --------------------
  typedef struct packed {
    logic [31:25] funct7;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:12] funct3;
    logic [11:7]  rd;
    logic [6:0]   opcode;
  } rtype_t;

  typedef struct packed {
    logic [31:27] rs3;
    logic [26:25] funct2;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:12] funct3;
    logic [11:7]  rd;
    logic [6:0]   opcode;
  } r4type_t;

  typedef struct packed {
    logic [31:27] funct5;
    logic [26:25] fmt;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:12] rm;
    logic [11:7]  rd;
    logic [6:0]   opcode;
  } rftype_t;  // floating-point

  typedef struct packed {
    logic [31:30] funct2;
    logic [29:25] vecfltop;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:14] repl;
    logic [13:12] vfmt;
    logic [11:7]  rd;
    logic [6:0]   opcode;
  } rvftype_t;  // vectorial floating-point

  typedef struct packed {
    logic [31:20] imm;
    logic [19:15] rs1;
    logic [14:12] funct3;
    logic [11:7]  rd;
    logic [6:0]   opcode;
  } itype_t;

  typedef struct packed {
    logic [31:25] imm;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:12] funct3;
    logic [11:7]  imm0;
    logic [6:0]   opcode;
  } stype_t;

  typedef struct packed {
    logic [31:12] imm;
    logic [11:7]  rd;
    logic [6:0]   opcode;
  } utype_t;

  // atomic instructions
  typedef struct packed {
    logic [31:27] funct5;
    logic         aq;
    logic         rl;
    logic [24:20] rs2;
    logic [19:15] rs1;
    logic [14:12] funct3;
    logic [11:7]  rd;
    logic [6:0]   opcode;
  } atype_t;

  typedef union packed {
    logic [31:0] instr;
    rtype_t      rtype;
    r4type_t     r4type;
    rftype_t     rftype;
    rvftype_t    rvftype;
    itype_t      itype;
    stype_t      stype;
    utype_t      utype;
    atype_t      atype;
  } instruction_t;

  // --------------------
  // Opcodes
  // --------------------
  // RV32/64G listings:
  // Quadrant 0
  localparam OpcodeLoad = 7'b00_000_11;
  localparam OpcodeLoadFp = 7'b00_001_11;
  localparam OpcodeCustom0 = 7'b00_010_11;
  localparam OpcodeMiscMem = 7'b00_011_11;
  localparam OpcodeOpImm = 7'b00_100_11;
  localparam OpcodeAuipc = 7'b00_101_11;
  localparam OpcodeOpImm32 = 7'b00_110_11;
  // Quadrant 1
  localparam OpcodeStore = 7'b01_000_11;
  localparam OpcodeStoreFp = 7'b01_001_11;
  localparam OpcodeCustom1 = 7'b01_010_11;
  localparam OpcodeAmo = 7'b01_011_11;
  localparam OpcodeOp = 7'b01_100_11;
  localparam OpcodeLui = 7'b01_101_11;
  localparam OpcodeOp32 = 7'b01_110_11;
  // Quadrant 2
  localparam OpcodeMadd = 7'b10_000_11;
  localparam OpcodeMsub = 7'b10_001_11;
  localparam OpcodeNmsub = 7'b10_010_11;
  localparam OpcodeNmadd = 7'b10_011_11;
  localparam OpcodeOpFp = 7'b10_100_11;
  localparam OpcodeVec = 7'b10_101_11;
  localparam OpcodeCustom2 = 7'b10_110_11;
  // Quadrant 3
  localparam OpcodeBranch = 7'b11_000_11;
  localparam OpcodeJalr = 7'b11_001_11;
  localparam OpcodeRsrvd2 = 7'b11_010_11;
  localparam OpcodeJal = 7'b11_011_11;
  localparam OpcodeSystem = 7'b11_100_11;
  localparam OpcodeRsrvd3 = 7'b11_101_11;
  localparam OpcodeCustom3 = 7'b11_110_11;
// ...
  // ----------------------
  // Exception Cause Codes
  // ----------------------
  localparam logic [XLEN-1:0] INSTR_ADDR_MISALIGNED = 0;
  localparam logic [XLEN-1:0] INSTR_ACCESS_FAULT    = 1;  // Illegal access as governed by PMPs and PMAs
  localparam logic [XLEN-1:0] ILLEGAL_INSTR = 2;
  localparam logic [XLEN-1:0] BREAKPOINT = 3;
  localparam logic [XLEN-1:0] LD_ADDR_MISALIGNED = 4;
  localparam logic [XLEN-1:0] LD_ACCESS_FAULT = 5;  // Illegal access as governed by PMPs and PMAs
  localparam logic [XLEN-1:0] ST_ADDR_MISALIGNED = 6;
  localparam logic [XLEN-1:0] ST_ACCESS_FAULT = 7;  // Illegal access as governed by PMPs and PMAs
  localparam logic [XLEN-1:0] ENV_CALL_UMODE = 8;  // environment call from user mode or virtual user mode
  localparam logic [XLEN-1:0] ENV_CALL_SMODE = 9;  // environment call from hypervisor-extended supervisor mode
  localparam logic [XLEN-1:0] ENV_CALL_VSMODE = 10; // environment call from virtual supervisor mode
  localparam logic [XLEN-1:0] ENV_CALL_MMODE = 11;  // environment call from machine mode
  localparam logic [XLEN-1:0] INSTR_PAGE_FAULT = 12;  // Instruction page fault
  localparam logic [XLEN-1:0] LOAD_PAGE_FAULT = 13;  // Load page fault
  localparam logic [XLEN-1:0] STORE_PAGE_FAULT = 15;  // Store page fault
  localparam logic [XLEN-1:0] HARDWARE_ERROR = 19;  // Transient error (e.g., bit-flip error in caches' SRAMs)
  localparam logic [XLEN-1:0] INSTR_GUEST_PAGE_FAULT = 20;  // Instruction guest-page fault
  localparam logic [XLEN-1:0] LOAD_GUEST_PAGE_FAULT = 21;  // Load guest-page fault
  localparam logic [XLEN-1:0] VIRTUAL_INSTRUCTION = 22;  // virtual instruction
  localparam logic [XLEN-1:0] STORE_GUEST_PAGE_FAULT = 23;  // Store guest-page fault
  localparam logic [XLEN-1:0] DEBUG_REQUEST = 24;  // Debug request

  localparam int unsigned IRQ_S_SOFT = 1;
  localparam int unsigned IRQ_VS_SOFT = 2;
  localparam int unsigned IRQ_M_SOFT = 3;
  localparam int unsigned IRQ_S_TIMER = 5;
  localparam int unsigned IRQ_VS_TIMER = 6;
  localparam int unsigned IRQ_M_TIMER = 7;
  localparam int unsigned IRQ_S_EXT = 9;
  localparam int unsigned IRQ_VS_EXT = 10;
  localparam int unsigned IRQ_M_EXT = 11;
  localparam int unsigned IRQ_HS_EXT = 12;

```

## Module declaration

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

## Parent instantiation

### `core/id_stage.sv`

```systemverilog
  always_comb begin
    // No CVXIF, No ZCMP, No ZCMT => Connect directly compressed decoder to decoder
    is_illegal_deco    = is_illegal_rvc;
    instruction_deco   = instruction_rvc;
    is_compressed_deco = is_compressed_rvc;
    if (CVA6Cfg.RVC) begin
      if (CVA6Cfg.CvxifEn) begin
        is_illegal_deco[0]    = is_illegal_cvxif_o;
        instruction_deco[0]   = instruction_cvxif_o;
        is_compressed_deco[0] = is_compressed_cvxif_o;
      end else if (CVA6Cfg.RVZCMP || CVA6Cfg.RVZCMT) begin
        is_illegal_deco[0]    = is_illegal_cvxif_i;
        instruction_deco[0]   = instruction_cvxif_i;
        is_compressed_deco[0] = is_compressed_cvxif_i;
      end
    end
  end

  assign rvfi_is_compressed_o = is_compressed_rvc;

  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    decoder #(
        .CVA6Cfg(CVA6Cfg),
        .branchpredict_sbe_t(branchpredict_sbe_t),
        .exception_t(exception_t),
        .irq_ctrl_t(irq_ctrl_t),
        .scoreboard_entry_t(scoreboard_entry_t),
        .interrupts_t(interrupts_t),
        .INTERRUPTS(INTERRUPTS)
    ) decoder_i (
        .debug_req_i,
        .irq_ctrl_i,
        .irq_i,
        .pc_i                      (fetch_entry_i[i].address),
        .is_compressed_i           (is_compressed_deco[i]),
        .is_macro_instr_i          (is_macro_instr[i]),
        .is_zcmt_i                 (is_zcmt_instr[i]),
        .is_last_macro_instr_i     (is_last_macro_instr),
        .is_double_rd_macro_instr_i(is_double_rd_macro_instr),
        .jump_address_i            (jump_address),
        .is_illegal_i              (is_illegal_deco[i]),
        .instruction_i             (instruction_deco[i]),
        .compressed_instr_i        (fetch_entry_i[i].instruction[15:0]),
        .branch_predict_i          (fetch_entry_i[i].branch_predict),
        .ex_i                      (fetch_entry_i[i].ex),
        .priv_lvl_i                (priv_lvl_i),
        .v_i                       (v_i),
        .debug_mode_i              (debug_mode_i),
        .fs_i,
        .vfs_i,
        .frm_i,
        .vs_i,
        .tvm_i,
        .tw_i,
        .vtw_i,
        .tsr_i,
        .hu_i,
        .mcbie_i,
        .scbie_i,
        .hcbie_i,
        .mcbcfe_i,
        .scbcfe_i,
        .hcbcfe_i,
        .instruction_o             (decoded_instruction[i]),
        .orig_instr_o              (orig_instr[i]),
        .is_control_flow_instr_o   (is_control_flow_instr[i]),
        .sdtrig_decoder_action_i   (sdtrig_decoder_action_i[i])
    );

```

## Dependency declarations

### `core/cva6.sv`

```systemverilog
    // branchpredict scoreboard entry
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

## Related source code

### `core/issue_read_operands.sv`

```systemverilog
  end

  // TODO check only for 1st instruction ??
  // Allow a cvxif transaction if we WaW condition are ok.
  assign cvxif_req_allowed = (issue_instr_i[0].fu == CVXIF);
  assign cvxif_instruction_valid = !issue_instr_i[0].ex.valid && issue_instr_valid_i[0] && cvxif_req_allowed;
  assign x_transaction_accepted_o = x_issue_valid_o && x_issue_ready_i && x_issue_resp_i.accept;
  assign x_transaction_rejected = x_issue_valid_o && x_issue_ready_i && ~x_issue_resp_i.accept;
  assign x_issue_writeback_o = x_issue_resp_i.writeback;
  assign x_id_o = x_issue_req_o.id;

  // ID <-> EX registers

  for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
    assign rs1_forwarding_o[i] = fu_data_n[i].operand_a[CVA6Cfg.VLEN-1:0];  //forwarding or unregistered rs1 value
    assign rs2_forwarding_o[i] = fu_data_n[i].operand_b[CVA6Cfg.VLEN-1:0];  //forwarding or unregistered rs2 value
    assign rvfi_rs1_o[i] = fu_data_n[i].operand_a;
    assign rvfi_rs2_o[i] = fu_data_n[i].operand_b;
  end

  assign alu_bypass_o = alu_bypass_q;
  assign fu_data_o = fu_data_q;
  assign alu_valid_o = alu_valid_q;
  assign aes_valid_o = aes_valid_q;
  assign branch_valid_o = branch_valid_q;
  assign lsu_valid_o = lsu_valid_q;
  assign csr_valid_o = csr_valid_q;
  assign mult_valid_o = mult_valid_q;
  assign fpu_valid_o = fpu_valid_q;
  assign fpu_fmt_o = fpu_fmt_q;
  assign fpu_rm_o = fpu_rm_q;
  assign alu2_valid_o = alu2_valid_q;
  assign cvxif_valid_o = CVA6Cfg.CvxifEn ? cvxif_valid_q : '0;
// ...
        fu_data_n[i].imm = imm_forward_rs3[i];
      end

      // use the PC as operand a
      if (issue_instr_i[i].use_pc) begin
        fu_data_n[i].operand_a = {
          {CVA6Cfg.XLEN - CVA6Cfg.VLEN{issue_instr_i[i].pc[CVA6Cfg.VLEN-1]}}, issue_instr_i[i].pc
        };
      end

      // use the zimm as operand a
      if (issue_instr_i[i].use_zimm) begin
        // zero extend operand a
        fu_data_n[i].operand_a = {{CVA6Cfg.XLEN - 5{1'b0}}, issue_instr_i[i].rs1[4:0]};
      end
      // or is it an immediate (including PC), this is not the case for a store, control flow, and accelerator instructions
      // also make sure operand B is not already used as an FP operand
      if (issue_instr_i[i].use_imm && (issue_instr_i[i].fu != STORE) && (issue_instr_i[i].fu != CTRL_FLOW) && (issue_instr_i[i].fu != ACCEL) && !(CVA6Cfg.FpPresent && is_rs2_fpr(
              issue_instr_i[i].op
          ))) begin
        fu_data_n[i].operand_b = issue_instr_i[i].result;
      end
    end
  end

  always_comb begin
    alu_valid_n    = '0;
// ...
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

### `core/csr_buffer.sv`

```systemverilog
    // if we got a valid from the scoreboard
    // store the CSR address
    if (csr_valid_i) begin
      csr_reg_n.csr_address = fu_data_i.operand_b[11:0];
      csr_reg_n.valid       = 1'b1;
    end

```

### `core/csr_regfile.sv`

```systemverilog
    // ---------------------
    // External Interrupts
    // ---------------------
    // Machine Mode External Interrupt Pending
    mip_d[riscv::IRQ_M_EXT] = irq_i[0];
    // Machine software interrupt
    mip_d[riscv::IRQ_M_SOFT] = CVA6Cfg.SoftwareInterruptEn && ipi_i;
    // Timer interrupt pending, coming from platform timer
    mip_d[riscv::IRQ_M_TIMER] = time_irq_i;

    // -----------------------
// ...
  always_comb begin : csr_op_logic
    csr_wdata = csr_wdata_i;
    csr_we    = 1'b1;
    csr_read  = 1'b1;
    mret      = 1'b0;
    sret      = 1'b0;
    dret      = 1'b0;

    unique case (csr_op_i)
      CSR_WRITE: csr_wdata = csr_wdata_i;
      CSR_SET:   csr_wdata = csr_wdata_i | csr_rdata;
      CSR_CLEAR: csr_wdata = (~csr_wdata_i) & csr_rdata;
      CSR_READ:  csr_we = 1'b0;
      MRET: begin
        // the return should not have any write or read side-effects
        csr_we   = 1'b0;
        csr_read = 1'b0;
        mret     = 1'b1;  // signal a return from machine mode
      end
      default: begin
        if (CVA6Cfg.RVS && csr_op_i == SRET) begin
          // the return should not have any write or read side-effects
          csr_we   = 1'b0;
          csr_read = 1'b0;
          sret     = 1'b1;  // signal a return from supervisor mode
        end else if (CVA6Cfg.DebugEn && csr_op_i == DRET) begin
          // the return should not have any write or read side-effects
          csr_we   = 1'b0;
          csr_read = 1'b0;
          dret     = 1'b1;  // signal a return from debug mode
        end else begin
          csr_we   = 1'b0;
          csr_read = 1'b0;
        end
      end
    endcase
    // if we are violating our privilges do not update the architectural state
    if (privilege_violation) begin
      csr_we   = 1'b0;
      csr_read = 1'b0;
    end
  end

  assign irq_ctrl_o.mie = mie_q;
  assign irq_ctrl_o.mip = mip_q;
  if (CVA6Cfg.RVH) begin
    assign irq_ctrl_o.sie = (v_q) ? vsstatus_q.sie : mstatus_q.sie;
  end else begin
    assign irq_ctrl_o.sie = mstatus_q.sie;
  end
  assign irq_ctrl_o.mideleg = (CVA6Cfg.RVS) ? mideleg_q : '0;
  assign irq_ctrl_o.hideleg = (CVA6Cfg.RVH) ? hideleg_q : '0;
  assign irq_ctrl_o.global_enable = ~(CVA6Cfg.DebugEn & debug_mode_q)
      // interrupts are enabled during single step or we are not stepping
      // No need to check interrupts during single step if we don't support DEBUG mode
      & (~CVA6Cfg.DebugEn | (~dcsr_q.step | dcsr_q.stepie))
                                    & ((mstatus_q.mie & (priv_lvl_o == riscv::PRIV_LVL_M))
                                    | (CVA6Cfg.RVU & priv_lvl_o != riscv::PRIV_LVL_M));

```

### `core/cva6.sv`

```systemverilog
  localparam type interrupts_t = struct packed {
    logic [CVA6Cfg.XLEN-1:0] S_SW;
    logic [CVA6Cfg.XLEN-1:0] VS_SW;
    logic [CVA6Cfg.XLEN-1:0] M_SW;
    logic [CVA6Cfg.XLEN-1:0] S_TIMER;
    logic [CVA6Cfg.XLEN-1:0] VS_TIMER;
    logic [CVA6Cfg.XLEN-1:0] M_TIMER;
    logic [CVA6Cfg.XLEN-1:0] S_EXT;
    logic [CVA6Cfg.XLEN-1:0] VS_EXT;
    logic [CVA6Cfg.XLEN-1:0] M_EXT;
    logic [CVA6Cfg.XLEN-1:0] HS_EXT;
  };

  localparam interrupts_t INTERRUPTS = '{
      S_SW: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_SOFT),
      VS_SW: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_VS_SOFT),
      M_SW: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_SOFT),
      S_TIMER: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_TIMER),
      VS_TIMER: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_VS_TIMER),
      M_TIMER: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_TIMER),
      S_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_S_EXT),
      VS_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_VS_EXT),
      M_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_M_EXT),
      HS_EXT: (CVA6Cfg.XLEN'(1) << (CVA6Cfg.XLEN - 1)) | CVA6Cfg.XLEN'(riscv::IRQ_HS_EXT)
  };

```

### `core/commit_stage.sv`

```systemverilog
  // Exception & Interrupt Logic
  // -----------------------------
  // here we know for sure that we are taking the exception
  always_comb begin : exception_handling
    // Multiple simultaneous interrupts and traps at the same privilege level are handled in the following decreasing
    // priority order: external interrupts, software interrupts, timer interrupts, then finally any synchronous traps. (1.10 p.30)
    // interrupts are correctly prioritized in the CSR reg file, exceptions are prioritized here
    exception_o.valid = 1'b0;

```

### `verif/tests/custom/env/encoding.h`

```c
#define MATCH_BEQ 0x63
#define MASK_BEQ  0x707f
#define MATCH_BNE 0x1063
#define MASK_BNE  0x707f
#define MATCH_BLT 0x4063
#define MASK_BLT  0x707f
#define MATCH_BGE 0x5063
#define MASK_BGE  0x707f
#define MATCH_BLTU 0x6063
#define MASK_BLTU  0x707f
#define MATCH_BGEU 0x7063
#define MASK_BGEU  0x707f
#define MATCH_JALR 0x67
#define MASK_JALR  0x707f
#define MATCH_JAL 0x6f
#define MASK_JAL  0x7f
#define MATCH_LUI 0x37
#define MASK_LUI  0x7f
#define MATCH_AUIPC 0x17
#define MASK_AUIPC  0x7f
#define MATCH_ADDI 0x13
#define MASK_ADDI  0x707f
#define MATCH_SLLI 0x1013
#define MASK_SLLI  0xfc00707f
#define MATCH_SLTI 0x2013
#define MASK_SLTI  0x707f
#define MATCH_SLTIU 0x3013
#define MASK_SLTIU  0x707f
#define MATCH_XORI 0x4013
#define MASK_XORI  0x707f
#define MATCH_SRLI 0x5013
#define MASK_SRLI  0xfc00707f
#define MATCH_SRAI 0x40005013
#define MASK_SRAI  0xfc00707f
#define MATCH_ORI 0x6013
#define MASK_ORI  0x707f
#define MATCH_ANDI 0x7013
#define MASK_ANDI  0x707f
#define MATCH_ADD 0x33
#define MASK_ADD  0xfe00707f
#define MATCH_SUB 0x40000033
#define MASK_SUB  0xfe00707f
#define MATCH_SLL 0x1033
#define MASK_SLL  0xfe00707f
#define MATCH_SLT 0x2033
#define MASK_SLT  0xfe00707f
#define MATCH_SLTU 0x3033
#define MASK_SLTU  0xfe00707f
#define MATCH_XOR 0x4033
#define MASK_XOR  0xfe00707f
#define MATCH_SRL 0x5033
#define MASK_SRL  0xfe00707f
#define MATCH_SRA 0x40005033
#define MASK_SRA  0xfe00707f
#define MATCH_OR 0x6033
#define MASK_OR  0xfe00707f
#define MATCH_AND 0x7033
#define MASK_AND  0xfe00707f
#define MATCH_LB 0x3
#define MASK_LB  0x707f
#define MATCH_LH 0x1003
#define MASK_LH  0x707f
#define MATCH_LW 0x2003
#define MASK_LW  0x707f
#define MATCH_LBU 0x4003
#define MASK_LBU  0x707f
#define MATCH_LHU 0x5003
#define MASK_LHU  0x707f
#define MATCH_SB 0x23
#define MASK_SB  0x707f
#define MATCH_SH 0x1023
#define MASK_SH  0x707f
#define MATCH_SW 0x2023
#define MASK_SW  0x707f
#define MATCH_FENCE 0xf
#define MASK_FENCE  0x707f
#define MATCH_FENCE_I 0x100f
#define MASK_FENCE_I  0x707f
// ...
#define MATCH_MUL 0x2000033
#define MASK_MUL  0xfe00707f
#define MATCH_MULH 0x2001033
#define MASK_MULH  0xfe00707f
#define MATCH_MULHSU 0x2002033
#define MASK_MULHSU  0xfe00707f
#define MATCH_MULHU 0x2003033
#define MASK_MULHU  0xfe00707f
#define MATCH_DIV 0x2004033
#define MASK_DIV  0xfe00707f
#define MATCH_DIVU 0x2005033
#define MASK_DIVU  0xfe00707f
#define MATCH_REM 0x2006033
#define MASK_REM  0xfe00707f
#define MATCH_REMU 0x2007033
#define MASK_REMU  0xfe00707f
// ...
#define MATCH_ECALL 0x73
#define MASK_ECALL  0xffffffff
#define MATCH_EBREAK 0x100073
#define MASK_EBREAK  0xffffffff
#define MATCH_URET 0x200073
#define MASK_URET  0xffffffff
#define MATCH_SRET 0x10200073
#define MASK_SRET  0xffffffff
#define MATCH_MRET 0x30200073
#define MASK_MRET  0xffffffff
#define MATCH_DRET 0x7b200073
#define MASK_DRET  0xffffffff
#define MATCH_SFENCE_VMA 0x12000073
#define MASK_SFENCE_VMA  0xfe007fff
#define MATCH_WFI 0x10500073
#define MASK_WFI  0xffffffff
#define MATCH_CSRRW 0x1073
#define MASK_CSRRW  0x707f
#define MATCH_CSRRS 0x2073
#define MASK_CSRRS  0x707f
#define MATCH_CSRRC 0x3073
#define MASK_CSRRC  0x707f
#define MATCH_CSRRWI 0x5073
#define MASK_CSRRWI  0x707f
#define MATCH_CSRRSI 0x6073
#define MASK_CSRRSI  0x707f
#define MATCH_CSRRCI 0x7073
#define MASK_CSRRCI  0x707f

```

## Documentation

### `docs/03_cva6_design/id_stage.md`

```text
#### Compressed Decoder

As mentioned earlier we also need to decompress all the compressed
instructions. This is done by a small combinatorial circuit which takes
a 16-bit compressed instruction and expands it to its 32-bit equivalent.
All compressed instructions have a 32-bit equivalent.

#### Decoder

The decoder either takes the raw instruction data or the uncompressed
equivalent of the 16-bit instruction and decodes them accordingly. It
transforms the raw bits to the most fundamental control structure in
Ariane, a scoreboard entry:

-   **PC**: PC of instruction
-   **FU**: functional unit to use
-   **OP**: operation to perform in each functional unit
-   **RS1**: register source address 1
-   **RS2**: register source address 2
-   **RD**: register destination address
-   **Result**: for unfinished instructions this field also holds the
    immediate
-   **Valid**: is the result valid
-   **Use I Immediate**: should we use the immediate as operand b?
-   **Use Z Immediate**: use zimm as operand a
-   **Use PC**: set if we need to use the PC as operand a, PC from
    exception
-   **Exception**: exception has occurred
-   **Branch predict**: branch predict scoreboard data structure
-   **Is compressed**: signals a compressed instructions, we need this
    information at the commit stage if we want jump accordingly e.g.:
    `+4`, `+2`

It gets incrementally processed further down the pipeline. The
scoreboard entry controls operand selection, dispatch and the execution.
Furthermore it contains an exception entry which strongly ties the
particular instruction to its potential exception. As the first time an
exception could have occurred was already in the IF stage the decoder
also makes sure that this exception finds its way into the scoreboard
entry. A potential illegal instruction exception can occur during
decoding. If this is the case and no previous exception has happened the
decoder will set the corresponding exceptions field along with the
faulting bits (in `[s|m]tval`). As this is not the only point in which
illegal instruction exception can happen and an illegal instruction
exception always asks for the faulting address in the `[s|m]tval` field
this field gets set here anyway. But only if instruction fetch didn't
throw an exception for this instruction yet.

```

### `docs/design/design-manual/source/cva6_id_stage.adoc`

```text
Decoder
+++++++

The decoder module takes the output of compressed_decoder module and
decodes it. It transforms the instruction to the most fundamental
control structure in pipeline, a scoreboard entry.

The scoreboard entry contains an exception entry which is composed of a
valid field, a cause and a value called TVAL. As TVALEn configuration
parameter is zero, the TVAL field is not implemented.

A potential illegal instruction exception can be detected during
decoding. If no exception has happened previously in fetch stage, the
decoder will valid the exception and add the cause and tval value to the
scoreboard entry.

A potential interrupt can be sent to the decoder.
If no exception has happened previously in fetch stage, the exception is inserted to into the scoreboard entry.

include::port_decoder.adoc[]

```

### `docs/design/design-manual/source/CVX_Interface_Coprocessor.adoc`

```text
Illegal instruction decoding
++++++++++++++++++++++++++++

The CVA6 decoder module detects illegal instructions for the CVA6, prepares exception field
with relevant information (exception code "ILLEGAL INSTRUCTION", instruction value).

The exception valid flag is raised in CVA6 decoder when CV-X-IF is disabled. Otherwise
it is not raised at this stage because the decision belongs to the coprocessor
after the offload process.

[[rs3-support]]
RS3 support
+++++++++++

The number of source registers used by the CV-X-IF coprocessor is configurable with 2 or
3 source registers.

If CV-X-IF is enabled and configured with 3 source registers,
a third read port is added to the CVA6 general purpose register file.

[[description-of-interface-connections-between-cva6-and-coprocessor]]

```

### `src/rv32.adoc`

```text
=== Programmers' Model for Base Integer ISA

<<gprs>> shows the unprivileged state for the base
integer ISA. For RV32I, the 32 `x` registers are each 32 bits wide,
i.e., `XLEN=32`. Register `x0` is hardwired with all bits equal to 0.
General purpose registers `x1-x31` hold values that various
instructions interpret as a collection of Boolean values, or as two's
complement signed binary integers or unsigned binary integers.

There is one additional unprivileged register: the program counter `pc`
holds the address of the current instruction.
...
==== Integer Register-Immediate Instructions

include::images/wavedrom/integer-computational.edn[]
//.Integer Computational Instructions

ADDI adds the sign-extended 12-bit immediate to register _rs1_.
Arithmetic overflow is ignored and the result is simply the low XLEN
bits of the result. ADDI _rd, rs1, 0_ is used to implement the MV _rd,
rs1_ assembler pseudoinstruction.

SLTI (set less than immediate) places the value 1 in register _rd_ if
register _rs1_ is less than the sign-extended immediate when both are
treated as signed numbers, else 0 is written to _rd_. SLTIU is similar
but compares the values as unsigned numbers (i.e., the immediate is
first sign-extended to XLEN bits then treated as an unsigned number).
Note, SLTIU _rd, rs1, 1_ sets _rd_ to 1 if _rs1_ equals zero, otherwise
sets _rd_ to 0 (assembler pseudoinstruction SEQZ _rd, rs_).

ANDI, ORI, XORI are logical operations that perform bitwise AND, OR, and
XOR on register _rs1_ and the sign-extended 12-bit immediate and place
the result in _rd_. Note, XORI _rd, rs1, -1_ performs a bitwise logical
inversion of register _rs1_ (assembler pseudoinstruction NOT _rd, rs_).

include::images/wavedrom/int-comp-slli-srli-srai.edn[]
[[int-comp-slli-srli-srai]]
//.Integer register-immediate, SLLI, SRLI, SRAI

Shifts by a constant are encoded as a specialization of the I-type
format. The operand to be shifted is in _rs1_, and the shift amount is
encoded in the lower 5 bits of the I-immediate field. The right shift
type is encoded in bit 30. SLLI is a logical left shift (zeros are
shifted into the lower bits); SRLI is a logical right shift (zeros are
shifted into the upper bits); and SRAI is an arithmetic right shift (the
original sign bit is copied into the vacated upper bits).

include::images/wavedrom/int-comp-lui-aiupc.edn[]
[[int-comp-lui-aiupc]]
//.Integer register-immediate, U-immediate

LUI (load upper immediate) is used to build 32-bit constants and uses
the U-type format. LUI places the 32-bit U-immediate value into the
destination register _rd_, filling in the lowest 12 bits with zeros.

AUIPC (add upper immediate to `pc`) is used to build `pc`-relative
addresses and uses the U-type format. AUIPC forms a 32-bit offset from
the U-immediate, filling in the lowest 12 bits with zeros, adds this
offset to the address of the AUIPC instruction, then places the result
in register _rd_.
...
==== Integer Register-Register Operations

RV32I defines several arithmetic R-type operations. All operations read
the _rs1_ and _rs2_ registers as source operands and write the result
into register _rd_. The _funct7_ and _funct3_ fields select the type of
operation.

include::images/wavedrom/int-reg-reg.edn[]
[[int-reg-reg]]
//.Integer register-register

ADD performs the addition of _rs1_ and _rs2_. SUB performs the
subtraction of _rs2_ from _rs1_. Overflows are ignored and the low XLEN
bits of results are written to the destination _rd_. SLT and SLTU
perform signed and unsigned compares respectively, writing 1 to _rd_ if
_rs1_ < _rs2_, 0 otherwise. Note, SLTU _rd_, _x0_, _rs2_ sets _rd_ to 1 if
_rs2_ is not equal to zero, otherwise sets _rd_ to zero (assembler
pseudoinstruction SNEZ _rd, rs_). AND, OR, and XOR perform bitwise
logical operations.

SLL, SRL, and SRA perform logical left, logical right, and arithmetic
right shifts on the value in register _rs1_ by the shift amount held in
the lower 5 bits of register _rs2_.

==== NOP Instruction

include::images/wavedrom/nop.edn[]
[[nop]]
//.NOP instructions

The NOP instruction does not change any architecturally visible state,
except for advancing the `pc` and incrementing any applicable
performance counters. NOP is encoded as ADDI _x0, x0, 0_.
...
==== Unconditional Jumps
The jump and link (JAL) instruction uses the J-type format, where the
J-immediate encodes a signed offset in multiples of 2 bytes. The offset
is sign-extended and added to the address of the jump instruction to
form the jump target address. Jumps can therefore target a
&#177;1 MiB range. JAL stores the address of the instruction
following the jump ('pc'+4) into register _rd_. The standard software
calling convention uses 'x1' as the return address register and 'x5' as
an alternate link register.

[NOTE]
====
The alternate link register supports calling millicode routines (e.g.,
those to save and restore registers in compressed code) while preserving
the regular return address register. The register `x5` was chosen as the
alternate link register as it maps to a temporary in the standard
calling convention, and has an encoding that is only one bit different
than the regular link register.
====

Plain unconditional jumps (assembler pseudoinstruction J) are encoded as
a JAL with _rd_=`x0`.

include::images/wavedrom/ct-unconditional.edn[]
[[ct-unconditional]]
//.The unconditional-jump instruction, JAL

The indirect jump instruction JALR (jump and link register) uses the
I-type encoding. The target address is obtained by adding the
sign-extended 12-bit I-immediate to the register _rs1_, then setting the
least-significant bit of the result to zero. The address of the
instruction following the jump (`pc`+4) is written to register _rd_.
Register `x0` can be used as the destination if the result is not
required.

Plain unconditional indirect jumps (assembler pseudoinstruction JR) are
encoded as a JALR with _rd_=`x0`.
Procedure returns in the standard calling convention (assembler
pseudoinstruction RET) are encoded as a JALR with _rd_=`x0`, _rs1_=`x1`, and
_imm_=0.

include::images/wavedrom/ct-unconditional-2.edn[]
[[ct-unconditional-2]]
//.The indirect unconditional-jump instruction, JALR
...
Return-address prediction stacks are a common feature of
high-performance instruction-fetch units, but require accurate detection
of instructions used for procedure calls and returns to be effective.
For RISC-V, hints as to the instructions' usage are encoded implicitly
via the register numbers used. A JAL instruction should push the return
address onto a return-address stack (RAS) only when _rd_ is 'x1' or
`x5`. JALR instructions should push/pop a RAS as shown in <<rashints>>.

[[rashints]]
.Return-address stack prediction hints encoded in the register operands of a JALR instruction.
[%autowidth,float="center",align="center",cols="^,^,^,<",options="header"]
|===
|_rd_ is _x1/x5_ |_rs1_ is _x1/x5_ |_rd_=_rs1_ |RAS action

|No |No |-- |None

|No |Yes |-- |Pop

|Yes |No |-- |Push

|Yes |Yes |No |Pop, then push

|Yes |Yes |Yes |Push
|===
...
==== Conditional Branches

All branch instructions use the B-type instruction format. The 12-bit
B-immediate encodes signed offsets in multiples of 2 bytes. The offset
is sign-extended and added to the address of the branch instruction to
give the target address. The conditional branch range is
&#177;4 KiB.

include::images/wavedrom/ct-conditional.edn[]
[[ct-conditional]]
//.Conditional branches

Branch instructions compare two registers. BEQ and BNE take the branch
if registers _rs1_ and _rs2_ are equal or unequal respectively. BLT and
BLTU take the branch if _rs1_ is less than _rs2_, using signed and
unsigned comparison respectively. BGE and BGEU take the branch if _rs1_
is greater than or equal to _rs2_, using signed and unsigned comparison
respectively. Note, BGT, BGTU, BLE, and BLEU can be synthesized by
reversing the operands to BLT, BLTU, BGE, and BGEU, respectively.
...
=== Load and Store Instructions
RV32I is a load-store architecture, where only load and store
instructions access memory and arithmetic instructions only operate on
CPU registers. RV32I provides a 32-bit address space that is
byte-addressed. The EEI will define what portions of the address space
are legal to access with which instructions (e.g., some addresses might
be read only, or support word access only). Loads with a destination of
`x0` must still raise any exceptions and cause any other side effects
even though the load value is discarded.

The EEI will define whether the memory system is little-endian or
big-endian. In RISC-V, endianness is byte-address invariant.

[NOTE]
====
In a system for which endianness is byte-address invariant, the
following property holds: if a byte is stored to memory at some address
in some endianness, then a byte-sized load from that address in any
endianness returns the stored value.

In a little-endian configuration, multibyte stores write the
least-significant register byte at the lowest memory byte address,
followed by the other register bytes in ascending order of their
significance. Loads similarly transfer the contents of the lesser memory
byte addresses to the less-significant register bytes.

In a big-endian configuration, multibyte stores write the
most-significant register byte at the lowest memory byte address,
followed by the other register bytes in descending order of their
significance. Loads similarly transfer the contents of the greater
memory byte addresses to the less-significant register bytes.
====

include::images/wavedrom/load-store.edn[]
[[load-store,load and store]]
//.Load and store instructions

Load and store instructions transfer a value between the registers and
memory. Loads are encoded in the I-type format and stores are S-type.
The effective address is obtained by adding register _rs1_ to the
sign-extended 12-bit offset. Loads copy a value from memory to register
_rd_. Stores copy the value in register _rs2_ to memory.

The LW instruction loads a 32-bit value from memory into _rd_. LH loads
a 16-bit value from memory, then sign-extends to 32-bits before storing
in _rd_. LHU loads a 16-bit value from memory but then zero extends to
32-bits before storing in _rd_. LB and LBU are defined analogously for
8-bit values. The SW, SH, and SB instructions store 32-bit, 16-bit, and
8-bit values from the low bits of register _rs2_ to memory.
...
=== Memory Ordering Instructions

include::images/wavedrom/mem-order.edn[]
[[mem-order]]
//.Memory ordering instructions

The FENCE instruction is used to order device I/O and memory accesses as
viewed by other RISC-V harts and external devices or coprocessors. Any
combination of device input (I), device output (O), memory reads \(R),
and memory writes (W) may be ordered with respect to any combination of
the same. Informally, no other RISC-V hart or external device can
observe any operation in the _successor_ set following a FENCE before
any operation in the _predecessor_ set preceding the FENCE.

```

### `src/m-st-ext.adoc`

```text
=== Multiplication Operations

include::images/wavedrom/m-st-ext-for-int-mult.edn[]
[[m-st-ext-for-int-mult]]
//.Multiplication operation instructions
(((MUL, MULH)))
(((MUL, MULHU)))
(((MUL, MULHSU)))

MUL performs an XLEN-bit×XLEN-bit multiplication of
_rs1_ by _rs2_ and places the lower XLEN bits in the destination
register. MULH, MULHU, and MULHSU perform the same multiplication but
return the upper XLEN bits of the full 2×XLEN-bit
product, for signed×signed,
unsigned×unsigned, and _rs1_×unsigned _rs2_ multiplication, respectively.
If both the high and low bits of the same product are required, then the recommended code sequence is: MULH[[S]U] _rdh, rs1, rs2_; MUL _rdl, rs1, rs2_ (source register specifiers must be in same order and _rdh_ cannot be the same as _rs1_ or _rs2_). Microarchitectures can then fuse these into a single multiply operation instead of performing two separate multiplies.

[NOTE]
====
MULHSU is used in multi-word signed multiplication to multiply the
most-significant word of the multiplicand (which contains the sign bit)
with the less-significant words of the multiplier (which are unsigned).
====

MULW is an RV64 instruction that multiplies the lower 32 bits of the
source registers, placing the sign extension of the lower 32 bits of the
result into the destination register.

[NOTE]
====
In RV64, MUL can be used to obtain the upper 32 bits of the 64-bit
product, but signed arguments must be proper 32-bit signed values,
whereas unsigned arguments must have their upper 32 bits clear. If the
arguments are not known to be sign- or zero-extended, an alternative is
to shift both arguments left by 32 bits, then use MULH[[S]U].
====

=== Division Operations

include::images/wavedrom/division-op.edn[]
[[division-op]]
//.Division operation instructions
(((MUL, DIV)))
(((MUL, DIVU)))

DIV and DIVU perform an XLEN bits by XLEN bits signed and unsigned
integer division of _rs1_ by _rs2_, rounding towards zero. REM and REMU
provide the remainder of the corresponding division operation. For REM,
the sign of a nonzero result equals the sign of the dividend.

[NOTE]
====
For both signed and unsigned division, except in the case of overflow, it holds
that
latexmath:[$\textrm{dividend} = \textrm{divisor} \times \textrm{quotient} + \textrm{remainder}$].
====

If both the quotient and remainder are required from the same division,
the recommended code sequence is: DIV[U] _rdq, rs1, rs2_; REM[U] _rdr,
rs1, rs2_ (_rdq_ cannot be the same as _rs1_ or _rs2_).
Microarchitectures can then fuse these into a single divide operation
instead of performing two separate divides.

DIVW and DIVUW are RV64 instructions that divide the lower 32 bits of
_rs1_ by the lower 32 bits of _rs2_, treating them as signed and
unsigned integers respectively, placing the 32-bit quotient in _rd_,
sign-extended to 64 bits. REMW and REMUW are RV64 instructions that
provide the corresponding signed and unsigned remainder operations
respectively. Both REMW and REMUW always sign-extend the 32-bit result
to 64 bits, including on a divide by zero.
(((MUL, div by zero)))

The semantics for division by zero and division overflow are summarized
in <<divby0>>. The quotient of division by zero has all bits
set, and the remainder of division by zero equals the dividend. Signed
division overflow occurs only when the most-negative integer is divided
by latexmath:[$-1$]. The quotient of a signed division with overflow is
equal to the dividend, and the remainder is zero. Unsigned division
overflow cannot occur.

```

### `src/b-st-ext.adoc`

```text
==== andn

Synopsis::
AND with inverted operand

Mnemonic::
andn _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x7, attr: ['ANDN']},
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x20, attr: ['ANDN'] },
]}
....
...
==== bclr

Synopsis::
Single-Bit Clear (Register)

Mnemonic::
bclr _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['BCLR'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x24, attr: ['BCLR/BEXT'] },
]}
....
...
==== bclri

Synopsis::
Single-Bit Clear (Immediate)

Mnemonic::
bclri _rd_, _rs1_, _shamt_

Encoding (RV32)::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['BCLRI'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'shamt' },
    { bits:  7, name: 0x24, attr: ['BCLRI'] },
]}
....
...
==== bext

Synopsis::
Single-Bit Extract (Register)
// Should we describe this as a Set-if-bit-is-set?

Mnemonic::
bext _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x5, attr: ['BEXT'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x24, attr: ['BCLR/BEXT'] },
]}
....
...
==== bexti

Synopsis::
Single-Bit Extract (Immediate)

Mnemonic::
bexti _rd_, _rs1_, _shamt_

Encoding (RV32)::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x5, attr: ['BEXTI'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'shamt' },
    { bits:  7, name: 0x24, attr: ['BEXTI/BCLRI'] },
]}
....
...
==== binv

Synopsis::
Single-Bit Invert (Register)

Mnemonic::
binv _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['BINV'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x34, attr: ['BINV'] },
]}
....
...
==== binvi

Synopsis::
Single-Bit Invert (Immediate)

Mnemonic::
binvi _rd_, _rs1_, _shamt_

Encoding (RV32)::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['BINV'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'shamt' },
    { bits:  7, name: 0x34, attr: ['BINVI'] },
]}
....
...
==== bset

Synopsis::
Single-Bit Set (Register)

Mnemonic::
bset _rd_, _rs1_,_rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['BSET'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x14, attr: ['BSET'] },
]}
....
...
==== bseti

Synopsis::
Single-Bit Set (Immediate)

Mnemonic::
bseti _rd_, _rs1_,_shamt_

Encoding (RV32)::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['BSETI'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'shamt' },
    { bits:  7, name: 0x14, attr: ['BSETI'] },
]}
....
...
==== clmul

Synopsis::
Carry-less multiply (low-part)

Mnemonic::
clmul _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['CLMUL'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x5, attr: ['MINMAX/CLMUL'] },
]}
....
...
==== clmulh

Synopsis::
Carry-less multiply (high-part)

Mnemonic::
clmulh _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x3, attr: ['CLMULH'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x5, attr: ['MINMAX/CLMUL'] },
]}
....
...
==== clmulr

Synopsis::
Carry-less multiply (reversed)

Mnemonic::
clmulr _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x2, attr: ['CLMULR'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x5, attr: ['MINMAX/CLMUL'] },
]}
....
...
==== clz

Synopsis::
Count leading zero bits

Mnemonic::
clz _rd_, _rs_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['CLZ']  },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 0x0, attr: ['CLZ'] },
    { bits:  7, name: 0x30, attr: ['CLZ']  },
]}
....
...
==== cpop

Synopsis::
Count set bits

Mnemonic::
cpop _rd_, _rs_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['CPOP'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 0x2, attr: ['CPOP'] },
    { bits:  7, name: 0x30, attr: ['CPOP'] },
]}
....
...
==== ctz

Synopsis::
Count trailing zeros

Mnemonic::
ctz _rd_, _rs_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['CTZ/CTZW'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 0x1, attr: ['CTZ/CTZW'] },
    { bits:  7, name: 0x30, attr: ['CTZ/CTZW'] },
]}
....
...
==== max

Synopsis::
Maximum 

Mnemonic::
max _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x6, attr: ['MAX']},
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x05, attr: ['MINMAX/CLMUL'] },
]}
....
...
==== maxu

Synopsis::
Unsigned maximum

Mnemonic::
maxu _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x7, attr: ['MAXU']},
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x05, attr: ['MINMAX/CLMUL'] },
]}
....
...
==== min

Synopsis::
Minimum

Mnemonic::
min _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x4, attr: ['MIN']},
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x05, attr: ['MINMAX/CLMUL'] },
]}
....
...
==== minu

Synopsis::
Unsigned minimum

Mnemonic::
minu _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x5, attr: ['MINU']},
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x05, attr: ['MINMAX/CLMUL'] },
]}
....
...
==== orc.b

Synopsis::
Bitwise OR-Combine, byte granule

Mnemonic::
orc.b _rd_, _rs_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x5 },
    { bits:  5, name: 'rs' },
    { bits: 12, name: 0x287 }
]}
....
...
==== orn

Synopsis::
OR with inverted operand

Mnemonic::
orn _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x6, attr: ['ORN']},
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x20, attr: ['ORN'] },
]}
....
...
==== rev8

Synopsis::
Byte-reverse register

Mnemonic::
rev8 _rd_, _rs_

Encoding (RV32)::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x5 },
    { bits:  5, name: 'rs' },
    { bits: 12, name: 0x698 }
]}
....
...
==== rol

Synopsis::
Rotate Left (Register)

Mnemonic::
rol _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['ROL']},
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x30, attr: ['ROL'] },
]}
....
...
==== ror

Synopsis::
Rotate Right

Mnemonic::
ror _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x5, attr: ['ROR']},
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x30, attr: ['ROR'] },
]}
....
...
==== rori

Synopsis::
Rotate Right (Immediate)

Mnemonic::
rori _rd_, _rs1_, _shamt_

Encoding (RV32)::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x5, attr: ['RORI']},
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'shamt' },
    { bits:  7, name: 0x30, attr: ['RORI'] },
]}
....
...
==== sext.b

Synopsis::
Sign-extend byte

Mnemonic::
sext.b _rd_, _rs_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['SEXT.B/SEXT.H'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 0x04, attr: ['SEXT.B'] },
    { bits:  7, name: 0x30 },
]}
....
...
==== sext.h

Synopsis::
Sign-extend halfword

Mnemonic::
sext.h _rd_, _rs_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x13, attr: ['OP-IMM'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x1, attr: ['SEXT.B/SEXT.H'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 0x05, attr: ['SEXT.H'] },
    { bits:  7, name: 0x30 },
]}
....
...
==== sh1add

Synopsis::
Shift left by 1 and add

Mnemonic::
sh1add _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x2, attr: ['SH1ADD'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x10, attr: ['SH1ADD'] },
]}
....
...
==== sh2add

Synopsis::
Shift left by 2 and add

Mnemonic::
sh2add _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x4, attr: ['SH2ADD'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x10, attr: ['SH2ADD'] },
]}
....
...
==== sh3add

Synopsis::
Shift left by 3 and add

Mnemonic::
sh3add _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x6, attr: ['SH3ADD'] },
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x10, attr: ['SH3ADD'] },
]}
....
...
==== xnor

Synopsis::
Exclusive NOR

Mnemonic::
xnor _rd_, _rs1_, _rs2_

Encoding::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x4, attr: ['XNOR']},
    { bits:  5, name: 'rs1' },
    { bits:  5, name: 'rs2' },
    { bits:  7, name: 0x20, attr: ['XNOR'] },
]}
....
...
==== zext.h

Synopsis::
Zero-extend halfword

Mnemonic::
zext.h _rd_, _rs_

Encoding (RV32)::
[wavedrom, , svg]
....
{reg:[
    { bits:  7, name: 0x33, attr: ['OP'] },
    { bits:  5, name: 'rd' },
    { bits:  3, name: 0x4, attr: ['ZEXT.H']},
    { bits:  5, name: 'rs' },
    { bits:  5, name: 0x00 },
    { bits:  7, name: 0x04 },
]}
....

```

### `src/zicsr.adoc`

```text
=== CSR Instructions

All CSR instructions atomically read-modify-write a single CSR, whose
CSR specifier is encoded in the 12-bit _csr_ field of the instruction
held in bits 31-20. The immediate forms use a 5-bit zero-extended
immediate encoded in the _rs1_ field.

include::images/wavedrom/csr-instr.edn[]

The CSRRW (Atomic Read/Write CSR) instruction atomically swaps values in
the CSRs and integer registers. CSRRW reads the old value of the CSR,
zero-extends the value to XLEN bits, then writes it to integer register
_rd_. The initial value in _rs1_ is written to the CSR. If _rd_=`x0`,
then the instruction shall not read the CSR and shall not cause any of
the side effects that might occur on a CSR read.

The CSRRS (Atomic Read and Set Bits in CSR) instruction reads the value
of the CSR, zero-extends the value to XLEN bits, and writes it to
integer register _rd_. The initial value in integer register _rs1_ is
treated as a bit mask that specifies bit positions to be set in the CSR.
Any bit that is high in _rs1_ will cause the corresponding bit to be set
in the CSR, if that CSR bit is writable.

The CSRRC (Atomic Read and Clear Bits in CSR) instruction reads the
value of the CSR, zero-extends the value to XLEN bits, and writes it to
integer register _rd_. The initial value in integer register _rs1_ is
treated as a bit mask that specifies bit positions to be cleared in the
CSR. Any bit that is high in _rs1_ will cause the corresponding bit to
be cleared in the CSR, if that CSR bit is writable.

For both CSRRS and CSRRC, if _rs1_=`x0`, then the instruction will not
write to the CSR at all, and so shall not cause any of the side effects
that might otherwise occur on a CSR write, nor raise illegal-instruction
exceptions on accesses to read-only CSRs. Both CSRRS and CSRRC always
read the addressed CSR and cause any read side effects regardless of
_rs1_ and _rd_ fields.
Note that if _rs1_ specifies a register other than `x0`, and that register
holds a zero value, the instruction will not action any attendant per-field
side effects, but will action any side effects caused by writing to the entire
CSR.

A CSRRW with _rs1_=`x0` will attempt to write zero to the destination CSR.

The CSRRWI, CSRRSI, and CSRRCI variants are similar to CSRRW, CSRRS, and
CSRRC respectively, except they update the CSR using an XLEN-bit value
obtained by zero-extending a 5-bit unsigned immediate (uimm[4:0]) field
encoded in the _rs1_ field instead of a value from an integer register.
For CSRRSI and CSRRCI, if the uimm[4:0] field is zero, then these
instructions will not write to the CSR, and shall not cause any of the
side effects that might otherwise occur on a CSR write, nor raise
illegal-instruction exceptions on accesses to read-only CSRs. For
CSRRWI, if _rd_=`x0`, then the instruction shall not read the CSR and
shall not cause any of the side effects that might occur on a CSR read.
Both CSRRSI and CSRRCI will always read the CSR and cause any read side
effects regardless of _rd_ and _rs1_ fields.

[[csrsideeffects]]
.Conditions determining whether a CSR instruction reads or writes the specified CSR.
[%autowidth,float="center",align="center",cols="<,^,^,^,^",options="header",]
|===
5+^|*Register operand* 
|Instruction |_rd_ is `x0` |_rs1_ is `x0` |Reads CSR |Writes CSR

|CSRRW |Yes |- |No |Yes

|CSRRW |No |- |Yes |Yes

|CSRRS/CSRRC |- |Yes |Yes |No

|CSRRS/CSRRC |- |No |Yes |Yes

5+^|*Immediate operand* 

|Instruction |_rd_ is `x0` |__uimm__latexmath:[$=$]0 |Reads CSR |Writes
CSR

|CSRRWI |Yes |- |No |Yes

|CSRRWI |No |- |Yes |Yes

|CSRRSI/CSRRCI |- |Yes |Yes |No

|CSRRSI/CSRRCI |- |No |Yes |Yes
|===

<<csrsideeffects>> summarizes the behavior of the CSR
instructions with respect to whether they read and/or write the CSR.

In addition to side effects that occur as a consequence of reading or
writing a CSR, individual fields within a CSR might have side effects
when written.  The CSRRW[I] instructions action side effects for all
such fields within the written CSR.  The CSRRS[I] an CSRRC[I] instructions
only action side effects for fields for which the _rs1_ or _uimm_ argument
has at least one bit set corresponding to that field.
[NOTE]
====
As of this writing, no standard CSRs have side effects on field writes.
Hence, whether a standard CSR access has any side effects can be determined
solely from the opcode.

Defining CSRs with side effects on field writes is not recommended.
====

For any event or consequence that occurs due to a CSR having a
particular value, if a write to the CSR gives it that value, the
resulting event or consequence is said to be an _indirect effect_ of the
write. Indirect effects of a CSR write are not considered by the RISC-V
ISA to be side effects of that write.
[NOTE]
====
An example of side effects for CSR accesses would be if reading from a
specific CSR causes a light bulb to turn on, while writing an odd value
to the same CSR causes the light to turn off. Assume writing an even
value has no effect. In this case, both the read and write have side
effects controlling whether the bulb is lit, as this condition is not
determined solely from the CSR value. (Note that after writing an odd
value to the CSR to turn off the light, then reading to turn the light
on, writing again the same odd value causes the light to turn off again.
Hence, on the last write, it is not a change in the CSR value that turns
off the light.)

On the other hand, if a bulb is rigged to light whenever the value of a
particular CSR is odd, then turning the light on and off is not
considered a side effect of writing to the CSR but merely an indirect
effect of such writes.

More concretely, the RISC-V privileged architecture defined in Volume II
specifies that certain combinations of CSR values cause a trap to occur.
When an explicit write to a CSR creates the conditions that trigger the
trap, the trap is not considered a side effect of the write but merely
an indirect effect.

Standard CSRs do not have any side effects on reads. Standard CSRs may
have side effects on writes. Custom extensions might add CSRs for which
accesses have side effects on either reads or writes.
====
Some CSRs, such as the instructions-retired counter, `instret`, may be
modified as side effects of instruction execution. In these cases, if a
CSR access instruction reads a CSR, it reads the value prior to the
execution of the instruction. If a CSR access instruction writes such a
CSR, the explicit write is done instead of the update from the side effect.
In particular, a value
written to `instret` by one instruction will be the value read by the
following instruction.

The assembler pseudoinstruction to read a CSR, CSRR _rd, csr_, is
encoded as CSRRS _rd, csr, x0_. The assembler pseudoinstruction to write
a CSR, CSRW _csr, rs1_, is encoded as CSRRW _x0, csr, rs1_, while CSRWI
_csr, uimm_, is encoded as CSRRWI _x0, csr, uimm_.

Further assembler pseudoinstructions are defined to set and clear bits
in the CSR when the old value is not required: CSRS/CSRC _csr, rs1_;
CSRSI/CSRCI _csr, uimm_.

```
