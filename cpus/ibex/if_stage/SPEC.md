# Implement `ibex_if_stage`

Implement the complete `ibex_if_stage` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_if_stage` definition in a single SystemVerilog code block, with no text outside the block.

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

  typedef enum integer {
    RegFileFF    = 0,
    RegFileFPGA  = 1,
    RegFileLatch = 2
  } regfile_e;

  typedef enum integer {
    RV32MNone        = 0,
    RV32MSlow        = 1,
    RV32MFast        = 2,
    RV32MSingleCycle = 3
  } rv32m_e;

  typedef enum integer {
    RV32BNone       = 0,
    RV32BBalanced   = 1,
    RV32BOTEarlGrey = 2,
    RV32BFull       = 3
  } rv32b_e;

  typedef enum integer {
    RV32Zca        = 0,
    RV32ZcaZcb     = 1,
    RV32ZcaZcmp    = 2,
    RV32ZcaZcbZcmp = 3
  } rv32zc_e;
// ...
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
  // 0 indicates the configuration data structure does not exist. Ibex implementers may wish to
  // alter this to point to their system specific configuration data structure.
  localparam logic [31:0] CSR_MCONFIGPTR_VALUE = 32'b0;

  // These LFSR parameters have been generated with
  // $ opentitan/util/design/gen-lfsr-seed.py --width 32 --seed 2480124384 --prefix ""
  parameter int LfsrWidth = 32;
  typedef logic [LfsrWidth-1:0] lfsr_seed_t;
  typedef logic [LfsrWidth-1:0][$clog2(LfsrWidth)-1:0] lfsr_perm_t;
  parameter lfsr_seed_t RndCnstLfsrSeedDefault = 32'hac533bf4;
  parameter lfsr_perm_t RndCnstLfsrPermDefault = {
    160'h1e35ecba467fd1b12e958152c04fa43878a8daed
  };
  parameter logic [SCRAMBLE_KEY_W-1:0]   RndCnstIbexKeyDefault =
      128'h14e8cecae3040d5e12286bb3cc113298;
  parameter logic [SCRAMBLE_NONCE_W-1:0] RndCnstIbexNonceDefault =
      64'hf79780bc735f3843;

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

### rtl/ibex_cheriot_pkg.sv

```systemverilog
  parameter int unsigned ADDR_W    = 32;
  parameter int unsigned CBOUND_W  = 9;   // 9-bit compressed bound (T or B)
  parameter int unsigned CEXP_W    = 4;   // 4-bit compressed exponent
  parameter int unsigned EXP_W     = 5;   // 5-bit expanded exponent
  parameter int unsigned OTYPE_W   = 3;   // 3-bit object type (sealing)
  parameter int unsigned CPERMS_W  = 6;   // 6-bit compressed permissions
  parameter int unsigned PERMS_W   = 12;  // 12-bit expanded permissions
  // Width of the compressed capability type (cap_t) as a flat vector used for ECC protection.
  parameter int unsigned REGCAP_W = 35;

  // Capability typedefs
  typedef logic [CBOUND_W-1:0] cbound_t;  // 9-bit compressed bound (T or B)
  typedef logic [CEXP_W-1:0]   cexp_t;    // 4-bit compressed exponent
  typedef logic [EXP_W-1:0]    exp_t;     // 5-bit expanded exponent
  typedef logic [OTYPE_W-1:0]  otype_t;   // 3-bit object type (sealing)
  typedef logic [CPERMS_W-1:0] cperms_t;  // 6-bit compressed permissions
  typedef logic [1:0]          cap_cor_t; // 2-bit correction: [1]=top_hi^addr_hi, [0]=addr_hi

  // Expanded 12-bit permissions (spec v1.0, chapter 7.13.1)
  typedef struct packed {
    logic U0;  // [11] user permission (software-defined)
    logic SE;  // [10] seal
    logic US;  // [9]  unseal
    logic EX;  // [8]  execute
    logic SR;  // [7]  access system registers
    logic MC;  // [6]  load/store capability
    logic LD;  // [5]  load
    logic SL;  // [4]  store local capability
    logic LM;  // [3]  load mutable
    logic SD;  // [2]  store
    logic LG;  // [1]  load global
    logic GL;  // [0]  global
  } perms_t;

  // Sealing types (spec v1.0, chapter 7.13.2)
  parameter otype_t OTYPE_UNSEALED        = 3'd0; // unsealed
  parameter otype_t OTYPE_SENTRY_II_FWD   = 3'd1; // interrupt-inheriting forward sentry
  parameter otype_t OTYPE_SENTRY_ID_FWD   = 3'd2; // interrupt disabling forward sentry
  parameter otype_t OTYPE_SENTRY_IE_FWD   = 3'd3; // interrupt enabling forward sentry
  parameter otype_t OTYPE_SENTRY_ID_BKWD  = 3'd4; // interrupt disabling backward sentry
  parameter otype_t OTYPE_SENTRY_IE_BKWD  = 3'd5; // interrupt enabling backward sentry

  // Exponent (spec v1.0, chapter 7.13.3)
  parameter cexp_t MAXCEXP = 4'd15; // compressed maximum exponent encoding
  parameter exp_t  MAXEXP  = 5'd24; // expanded maximum exponent

  // -----------------------------------------------------------------------------------------------
  // Capability types
  // -----------------------------------------------------------------------------------------------
  // The CHERIoT ISA defines the capability format (spec v1.0, chapter 7.13, Figure 7.2).
  // Two types are used in the RTL:
  //
  //  cap_t          - The primary compressed form defined by the spec and used everywhere a
  //                   capability is stored (register file, CSR registers, load/store ports,
  //                   ECC/lockstep vectors). Its lower 33 bits (cap[32:0]) are a 1:1 match with the
  //                   spec so writing to memory is a simple truncation and a direct cast.
  //                   Bits [34:33] store the correction factors that are not in the spec but kept
  //                   in the register file to save recomputation costs. See the
  //                   `cheriot_compute_corrections` function below.
  //
  //  decoded_cap_t  - The uncompressed capability type used inside the core. Created by
  //                   `cheriot_decode_cap` and `cheriot_encode_cap`. Its lower 35 bits are the same
  //                   as cap_t so encode is simpley a cast. The upper bits add the decompressed
  //                   bounds and permissions.
  // -----------------------------------------------------------------------------------------------

  // Compressed capability + correction factors
  typedef struct packed {
    cap_cor_t cap_cor; // [34:33] correction factors
    // Capability according to spec v1.0, chapter 7.13
    logic     valid;   // [32]    tag bit
    logic     rsvd;    // [31]    reserved R
    cperms_t  cperms;  // [30:25] compressed permissions
    otype_t   otype;   // [24:22] object type
    cexp_t    cexp;    // [21:18] 4-bit compressed exponent
    cbound_t  top;     // [17:9]  top mantissa T
    cbound_t  base;    // [8:0]   base mantissa B
  } cap_t;  // 2+1+1+6+3+4+9+9 = 35 bits = REGCAP_W

  // Uncompressed capability
  typedef struct packed {
    logic [ADDR_W:0]   top33;  // 33 bits absolute top
    logic [ADDR_W-1:0] base32; // 32 bits absolute base
    perms_t            perms;  // 12 bits expanded permissions
    // Identical layout to cap_t from here
    cap_cor_t cap_cor; // [34:33] correction factors
    logic     valid;   // [32]    tag bit
    logic     rsvd;    // [31]    reserved R
    cperms_t  cperms;  // [30:25] compressed permissions
    otype_t   otype;   // [24:22] object type
    cexp_t    cexp;    // [21:18] 4-bit compressed exponent
    cbound_t  top;     // [17:9]  top mantissa T
    cbound_t  base;    // [8:0]   base mantissa B
  } decoded_cap_t;  // 33+32+12+35 = 112 bits


  // Types for bound computation in CHERIoT EX Stage
  typedef struct packed {
    logic [32:0]    top33req; // requested top = addr + length (33-bit)
    exp_t           exp1;     // exponent candidate from length (no overflow)
    exp_t           exp2;     // exp1 + 1 (used when exp1 path overflows)
    logic [EXP_W:0] explen;   // MSB position of length[31:9] (6-bit, can be 32)
    logic [EXP_W:0] expb;     // trailing-zero count of base address (6-bit)
    logic           in_bound; // addr..addr+length lies within parent bounds
  } bound_req_t;

  // The decoded capability plus the alignment mask and representable length.
  typedef struct packed {
    decoded_cap_t cap;   // resulting capability
    logic [31:0]  maska; // alignment mask    (CRAM result)
    logic [31:0]  rlen;  // representable len (CRRL result)
  } bound_result_t;

  // Permission-clearing control for capability loads (CLC instruction).
  // Each field corresponds to one CLC clearing rule from the spec.
  typedef struct packed {
    logic CTAG;   // [2] clear tag (valid) bit (loading cap lacks MC)
    logic SD_LM;  // [1] clear SD and LM       (loading cap lacks LM)
    logic GL_LG;  // [0] clear GL and LG       (loading cap lacks LG)
  } cap_clrperm_t;
```

## Module declaration

```systemverilog
module ibex_if_stage import ibex_pkg::*; import ibex_cheriot_pkg::*; #(
  parameter base_isa_e   BaseIsa              = BaseIsaRV32I,
  parameter int unsigned DmHaltAddr           = 32'h1A110800,
  parameter int unsigned DmExceptionAddr      = 32'h1A110808,
  parameter bit          DummyInstructions    = 1'b0,
  parameter bit          ICache               = 1'b0,
  parameter rv32zc_e     RV32ZC               = RV32ZcaZcbZcmp,
  parameter bit          ICacheECC            = 1'b0,
  parameter bit          ICacheTweakInfection = 1'b0,
  parameter int unsigned BusSizeECC           = BUS_SIZE,
  parameter int unsigned TagSizeECC           = IC_TAG_SIZE,
  parameter int unsigned LineSizeECC          = IC_LINE_SIZE,
  parameter bit          PCIncrCheck          = 1'b0,
  parameter bit          ResetAll             = 1'b0,
  parameter lfsr_seed_t  RndCnstLfsrSeed      = RndCnstLfsrSeedDefault,
  parameter lfsr_perm_t  RndCnstLfsrPerm      = RndCnstLfsrPermDefault,
  parameter bit          BranchPredictor      = 1'b0,
  parameter bit          MemECC               = 1'b0,
  parameter int unsigned MemDataWidth         = MemECC ? 32 + 7 : 32
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  ibex_mubi_t                   cheriot_enable_i,
  input  logic [31:0]                  boot_addr_i,              // also used for mtvec
  input  logic                         req_i,                    // instruction request control
  input  logic                         debug_mode_i,

  // instruction cache interface
  output logic                        instr_req_o,
  output logic [31:0]                 instr_addr_o,
  input  logic                        instr_gnt_i,
  input  logic                        instr_rvalid_i,
  input  logic [MemDataWidth-1:0]     instr_rdata_i,
  input  logic                        instr_bus_err_i,
  output logic                        instr_intg_err_o,

  // ICache RAM IO
  output logic [IC_NUM_WAYS-1:0]      ic_tag_req_o,
  output logic                        ic_tag_write_o,
  output logic [IC_INDEX_W-1:0]       ic_tag_addr_o,
  output logic [TagSizeECC-1:0]       ic_tag_wdata_o,
  input  logic [TagSizeECC-1:0]       ic_tag_rdata_i [IC_NUM_WAYS],
  output logic [IC_NUM_WAYS-1:0]      ic_data_req_o,
  output logic                        ic_data_write_o,
  output logic [IC_INDEX_W-1:0]       ic_data_addr_o,
  output logic [LineSizeECC-1:0]      ic_data_wdata_o,
  input  logic [LineSizeECC-1:0]      ic_data_rdata_i [IC_NUM_WAYS],
  input  logic                        ic_scr_key_valid_i,
  output logic                        ic_scr_key_req_o,

  // output of ID stage
  output logic                        instr_valid_id_o,         // instr in IF-ID is valid
  output logic                        instr_new_id_o,           // instr in IF-ID is new
  output logic [31:0]                 instr_rdata_id_o,         // instr for ID stage
  output logic [31:0]                 instr_rdata_alu_id_o,     // replicated instr for ID stage
                                                                // to reduce fan-out
  output logic [15:0]                 instr_rdata_c_id_o,       // compressed instr for ID stage
                                                                // (mtval), meaningful only if
                                                                // instr_is_compressed_id_o = 1'b1
  output logic                        instr_is_compressed_id_o, // compressed decoder thinks this
                                                                // is a compressed instr
  output instr_exp_e                  instr_gets_expanded_id_o, // this instruction comes from one
                                                                // that gets expanded by the
                                                                // compressed decoder
  output logic [15:0]                 instr_expanded_id_o,      // the instruction that is currently
                                                                // getting expanded
  output logic                        instr_bp_taken_o,         // instruction was predicted to be
                                                                // a taken branch
  output logic                        instr_fetch_err_o,        // bus error on fetch
  output logic                        instr_fetch_err_plus2_o,  // bus error misaligned
  output logic                        illegal_c_insn_id_o,      // compressed decoder thinks this
                                                                // is an invalid instr
  output logic                        instr_fetch_cheriot_acc_vio_o,
  output logic                        instr_fetch_cheriot_bound_vio_o,
  output logic                        dummy_instr_id_o,         // Instruction is a dummy
  output logic [31:0]                 pc_if_o,
  output logic [31:0]                 pc_id_o,
  input  logic                        pmp_err_if_i,
  input  logic                        pmp_err_if_plus2_i,

  // control signals
  input  logic                        instr_valid_clear_i,      // clear instr valid bit in IF-ID
  input  logic                        pc_set_i,                 // set the PC to a new value
  input  pc_sel_e                     pc_mux_i,                 // selector for PC multiplexer
  input  logic                        nt_branch_mispredict_i,   // Not-taken branch in ID/EX was
                                                                // mispredicted (predicted taken)
  input  logic [31:0]                 nt_branch_addr_i,         // Not-taken branch address in ID/EX
  input  exc_pc_sel_e                 exc_pc_mux_i,             // selects ISR address
  input  exc_cause_t                  exc_cause,                // selects ISR address for
                                                                // vectorized interrupt lines
  input  logic                        dummy_instr_en_i,
  input  logic [2:0]                  dummy_instr_mask_i,
  input  logic                        dummy_instr_seed_en_i,
  input  logic [31:0]                 dummy_instr_seed_i,
  input  logic                        icache_enable_i,
  input  logic                        icache_inval_i,
  output logic                        icache_ecc_error_o,

  // jump and branch target
  input  logic [31:0]                 branch_target_ex_i,       // branch/jump target address

  // CSRs
  input  logic [31:0]                 csr_mepc_i,               // PC to restore after handling
                                                                // the interrupt/exception
  input  logic [31:0]                 csr_depc_i,               // PC to restore after handling
                                                                // the debug request
  input  logic [31:0]                 csr_mtvec_i,              // base PC to jump to on exception
  output logic                        csr_mtvec_init_o,         // tell CS regfile to init mtvec

  // pipeline stall
  input  logic                        id_in_ready_i,            // ID stage is ready for new instr

  // misc signals
  output logic                        pc_mismatch_alert_o,
  output logic                        if_busy_o,                // IF stage is busy fetching instr
  input  decoded_cap_t                pcc_cap_i
);
```

## Parent instantiation

### rtl/ibex_core.sv

```systemverilog
  ibex_if_stage #(
    .DmHaltAddr           (DmHaltAddr),
    .DmExceptionAddr      (DmExceptionAddr),
    .DummyInstructions    (DummyInstructions),
    .ICache               (ICache),
    .RV32ZC               (RV32ZC),
    .ICacheECC            (ICacheECC),
    .ICacheTweakInfection (ICacheTweakInfection),
    .BusSizeECC           (BusSizeECC),
    .TagSizeECC           (TagSizeECC),
    .LineSizeECC          (LineSizeECC),
    .PCIncrCheck          (PCIncrCheck),
    .ResetAll             (ResetAll),
    .RndCnstLfsrSeed      (RndCnstLfsrSeed),
    .RndCnstLfsrPerm      (RndCnstLfsrPerm),
    .BranchPredictor      (BranchPredictor),
    .MemECC               (MemECC),
    .MemDataWidth         (MemDataWidth),
    .BaseIsa              (BaseIsa)
  ) if_stage_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    .cheriot_enable_i (cheriot_enable_i),
    .boot_addr_i      (boot_addr_i),
    .req_i            (instr_req_gated),  // instruction request control
    .debug_mode_i     (debug_mode),

    // instruction cache interface
    .instr_req_o       (instr_req_o),
    .instr_addr_o      (instr_addr_o),
    .instr_gnt_i       (instr_gnt_i),
    .instr_rvalid_i    (instr_rvalid_i),
    .instr_rdata_i     (instr_rdata_i),
    .instr_bus_err_i   (instr_err_i),
    .instr_intg_err_o  (instr_intg_err),

    .ic_tag_req_o      (ic_tag_req_o),
    .ic_tag_write_o    (ic_tag_write_o),
    .ic_tag_addr_o     (ic_tag_addr_o),
    .ic_tag_wdata_o    (ic_tag_wdata_o),
    .ic_tag_rdata_i    (ic_tag_rdata_i),
    .ic_data_req_o     (ic_data_req_o),
    .ic_data_write_o   (ic_data_write_o),
    .ic_data_addr_o    (ic_data_addr_o),
    .ic_data_wdata_o   (ic_data_wdata_o),
    .ic_data_rdata_i   (ic_data_rdata_i),
    .ic_scr_key_valid_i(ic_scr_key_valid_i),
    .ic_scr_key_req_o  (ic_scr_key_req_o),

    // outputs to ID stage
    .instr_valid_id_o                (instr_valid_id),
    .instr_new_id_o                  (instr_new_id),
    .instr_rdata_id_o                (instr_rdata_id),
    .instr_rdata_alu_id_o            (instr_rdata_alu_id),
    .instr_rdata_c_id_o              (instr_rdata_c_id),
    .instr_is_compressed_id_o        (instr_is_compressed_id),
    .instr_gets_expanded_id_o        (instr_gets_expanded_id),
    .instr_expanded_id_o             (instr_expanded_id),
    .instr_bp_taken_o                (instr_bp_taken_id),
    .instr_fetch_err_o               (instr_fetch_err),
    .instr_fetch_err_plus2_o         (instr_fetch_err_plus2),
    .instr_fetch_cheriot_acc_vio_o   (instr_fetch_cheriot_acc_vio),
    .instr_fetch_cheriot_bound_vio_o (instr_fetch_cheriot_bound_vio),

    .illegal_c_insn_id_o     (illegal_c_insn_id),
    .dummy_instr_id_o        (dummy_instr_id),
    .pc_if_o                 (pc_if),
    .pc_id_o                 (pc_id),
    .pmp_err_if_i            (pmp_req_err[PMP_I]),
    .pmp_err_if_plus2_i      (pmp_req_err[PMP_I2]),

    // control signals
    .instr_valid_clear_i   (instr_valid_clear),
    .pc_set_i              (pc_set),
    .pc_mux_i              (pc_mux_id),
    .nt_branch_mispredict_i(nt_branch_mispredict),
    .exc_pc_mux_i          (exc_pc_mux_id),
    .exc_cause             (exc_cause),
    .dummy_instr_en_i      (dummy_instr_en),
    .dummy_instr_mask_i    (dummy_instr_mask),
    .dummy_instr_seed_en_i (dummy_instr_seed_en),
    .dummy_instr_seed_i    (dummy_instr_seed),
    .icache_enable_i       (icache_enable),
    .icache_inval_i        (icache_inval),
    .icache_ecc_error_o    (icache_ecc_error),

    // branch targets
    .branch_target_ex_i(branch_target_ex),
    .nt_branch_addr_i  (nt_branch_addr),

    // CSRs
    .csr_mepc_i      (csr_mepc),  // exception return address
    .csr_depc_i      (csr_depc),  // debug return address
    .csr_mtvec_i     (csr_mtvec),  // trap-vector base address
    .csr_mtvec_init_o(csr_mtvec_init),

    // pipeline stalls
    .id_in_ready_i(id_in_ready),

    .pc_mismatch_alert_o(pc_mismatch_alert),
    .if_busy_o          (if_busy),
    .pcc_cap_i          (pcc_cap_r)
  );
```

## Dependency declarations

### rtl/ibex_compressed_decoder.sv

```systemverilog
module ibex_compressed_decoder import ibex_pkg::*; #(
  parameter ibex_pkg::rv32zc_e   RV32ZC   = ibex_pkg::RV32ZcaZcbZcmp,
  parameter bit                  ResetAll = 1'b0,
  parameter ibex_pkg::base_isa_e BaseIsa  = ibex_pkg::BaseIsaRV32IorCHERIoT
) (
  input  logic                 clk_i,
  input  logic                 rst_ni,
  input  logic                 valid_i,
  input  logic                 id_in_ready_i,
  input  logic [31:0]          instr_i,
  input  ibex_mubi_t           cheriot_enable_i,
  output logic [31:0]          instr_o,
  output logic                 is_compressed_o,
  output ibex_pkg::instr_exp_e gets_expanded_o,
  input  logic                 flush_expanded_i,
  output logic                 illegal_instr_o
);
```

### rtl/ibex_prefetch_buffer.sv

```systemverilog
module ibex_prefetch_buffer #(
  parameter bit ResetAll        = 1'b0
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic        req_i,

  input  logic        branch_i,
  input  logic [31:0] addr_i,

  input  logic        ready_i,
  output logic        valid_o,
  output logic [31:0] rdata_o,
  output logic [31:0] addr_o,
  output logic        err_o,
  output logic        err_plus2_o,

  input  logic        cheriot_force_uc_i,

  // goes to instruction memory / instruction cache
  output logic        instr_req_o,
  input  logic        instr_gnt_i,
  output logic [31:0] instr_addr_o,
  input  logic [31:0] instr_rdata_i,
  input  logic        instr_err_i,
  input  logic        instr_rvalid_i,

  // Prefetch Buffer Status
  output logic        busy_o
);
```

### vendor/lowrisc_ip/ip/prim_generic/rtl/prim_buf.sv

```systemverilog
module prim_buf #(
  parameter int Width = 1
) (
  input        [Width-1:0] in_i,
  output logic [Width-1:0] out_o
);
```

### rtl/ibex_icache.sv

```systemverilog
module ibex_icache import ibex_pkg::*; #(
  parameter bit          ICacheECC       = 1'b0,
  parameter bit          ResetAll        = 1'b0,
  parameter int unsigned BusSizeECC      = BUS_SIZE,
  parameter int unsigned TagSizeECC      = IC_TAG_SIZE,
  parameter int unsigned LineSizeECC     = IC_LINE_SIZE,
  // Only cache branch targets
  parameter bit          BranchCache     = 1'b0,
  parameter bit          TweakInfection  = 1'b0
) (
  // Clock and reset
  input  logic                           clk_i,
  input  logic                           rst_ni,

  // Signal that the core would like instructions
  input  logic                           req_i,

  // Set the cache's address counter
  input  logic                           branch_i,
  input  logic [31:0]                    addr_i,

  // IF stage interface: Pass fetched instructions to the core
  input  logic                           ready_i,
  output logic                           valid_o,
  output logic [31:0]                    rdata_o,
  output logic [31:0]                    addr_o,
  output logic                           err_o,
  output logic                           err_plus2_o,

  // Instruction memory / interconnect interface: Fetch instruction data from memory
  output logic                           instr_req_o,
  input  logic                           instr_gnt_i,
  output logic [31:0]                    instr_addr_o,
  input  logic [BUS_SIZE-1:0]            instr_rdata_i,
  input  logic                           instr_err_i,
  input  logic                           instr_rvalid_i,

  // RAM IO
  output logic [IC_NUM_WAYS-1:0]         ic_tag_req_o,
  output logic                           ic_tag_write_o,
  output logic [IC_INDEX_W-1:0]          ic_tag_addr_o,
  output logic [TagSizeECC-1:0]          ic_tag_wdata_o,
  input  logic [TagSizeECC-1:0]          ic_tag_rdata_i [IC_NUM_WAYS],
  output logic [IC_NUM_WAYS-1:0]         ic_data_req_o,
  output logic                           ic_data_write_o,
  output logic [IC_INDEX_W-1:0]          ic_data_addr_o,
  output logic [LineSizeECC-1:0]         ic_data_wdata_o,
  input  logic [LineSizeECC-1:0]         ic_data_rdata_i [IC_NUM_WAYS],
  input  logic                           ic_scr_key_valid_i,
  output logic                           ic_scr_key_req_o,

  // Cache status
  input  logic                           icache_enable_i,
  input  logic                           icache_inval_i,
  output logic                           busy_o,
  output logic                           ecc_error_o
);
```

### rtl/ibex_dummy_instr.sv

```systemverilog
module ibex_dummy_instr import ibex_pkg::*; #(
    parameter lfsr_seed_t RndCnstLfsrSeed = RndCnstLfsrSeedDefault,
    parameter lfsr_perm_t RndCnstLfsrPerm = RndCnstLfsrPermDefault
) (
  // Clock and reset
  input  logic        clk_i,
  input  logic        rst_ni,

  // Interface to CSRs
  input  logic        dummy_instr_en_i,
  input  logic [2:0]  dummy_instr_mask_i,
  input  logic        dummy_instr_seed_en_i,
  input  logic [31:0] dummy_instr_seed_i,

  // Interface to IF stage
  input  logic        fetch_valid_i,
  input  logic        id_in_ready_i,
  output logic        insert_dummy_instr_o,
  output logic [31:0] dummy_instr_data_o
);
```

### rtl/ibex_branch_predict.sv

```systemverilog
module ibex_branch_predict (
  input  logic clk_i,
  input  logic rst_ni,

  // Instruction from fetch stage
  input  logic [31:0] fetch_rdata_i,
  input  logic [31:0] fetch_pc_i,
  input  logic        fetch_valid_i,

  // Prediction for supplied instruction
  output logic        predict_branch_taken_o,
  output logic [31:0] predict_branch_pc_o
);
```

### vendor/lowrisc_ip/ip/prim/rtl/prim_secded_inv_39_32_dec.sv

```systemverilog
module prim_secded_inv_39_32_dec (
  input        [38:0] data_i,
  output logic [31:0] data_o,
  output logic [6:0] syndrome_o,
  output logic [1:0] err_o
);
```

## Related source code

### rtl/ibex_core.sv

```systemverilog
      // When the pipeline has emptied in preparation for handling a new interrupt send
      // a notification up the RVFI pipeline. This is used by the cosim to deal with cases where an
      // interrupt occurs before another interrupt or debug request but both occur before the first
      // instruction of the handler is executed and retired (where the cosim will see all the
      // interrupts and debug requests at once with no way to determine which occurred first).
      if (~instr_valid_id & ~new_debug_req & (new_irq | new_nmi | new_nmi_int) & ready_wb &
          ~captured_valid) begin
        rvfi_irq_valid <= 1'b1;
      end else begin
        rvfi_irq_valid <= 1'b0;
      end

      // Capture cleared out as soon as a new instruction appears in ID
      if (if_stage_i.instr_valid_id_d) begin
        captured_valid <= 1'b0;
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

### doc/03_reference/instruction_fetch.rst

```text
Instruction Fetch
=================
:file:`rtl/ibex_if_stage.sv.`

.. figure:: images/if_stage.svg
   :name: if_stage
   :align: center

   Instruction Fetch (IF) stage

The Instruction Fetch (IF) stage of the core is able to supply one instruction to the Instruction-Decode (ID) stage per cycle if the instruction cache or the instruction memory is able to serve one instruction per cycle.

Instructions are fetched into a prefetch buffer (:file:`rtl/ibex_prefetch_buffer.sv`) for optimal performance and timing closure reasons.
This buffer simply fetches instructions linearly until it is full.
The instructions themselves are stored along with the Program Counter (PC) they came from in the fetch FIFO (:file:`rtl/ibex_fetch_fifo.sv`).
The fetch FIFO has a feedthrough path so when empty a new instruction entering the FIFO is immediately made available on the FIFO output.
A localparam ``DEPTH`` gives a configurable depth which is set to 3 by default.

The top-level of the instruction fetch controls the prefetch buffer (in particular flushing it on branches/jumps/exception and beginning prefetching from the appropriate new PC) and supplies new instructions to the ID/EX stage along with their PC.
Compressed instructions are expanded by the IF stage so the decoder can always deal with uncompressed instructions (the ID stage still receives the compressed instruction for placing into ``mtval`` on an illegal instruction exception).

If Ibex has been configured with an instruction cache (parameter ICache == 1), then the prefetch buffer is replaced by the icache module (:ref:`icache`).
The interfaces of the icache module are the same as the prefetch buffer with two additions.
Firstly, a signal to enable the cache which is driven from a custom CSR.
Secondly a signal to the flush the cache which is set every time a ``fence.i`` instruction is executed.
```

### doc/03_reference/exception_interrupts.rst

```text
All exceptions cause the core to jump to the base address of the vector table in the ``mtvec`` CSR.
Interrupts are handled in vectored mode, i.e., the core jumps to the base address plus four times the interrupt ID.
Upon executing an MRET instruction, the core jumps to the program counter previously saved in the ``mepc`` CSR and restores ``mstatus``.MPIE to ``mstatus``.MIE.

The base address of the vector table is initialized to the boot address (must be aligned to 256 bytes, i.e., its least significant byte must be 0x00) when the core is booting.
The base address can be changed after boot-up by writing to the ``mtvec`` CSR.
For more information, see the :ref:`cs-registers` documentation.

The core starts fetching at the address made by concatenating the most significant 3 bytes of the boot address and the reset value (0x80) as the least significant byte.
It is assumed that the boot address is supplied via a register to avoid long paths to the instruction fetch unit.
```

## Additional requirement

The fixed `ibex_core` reads `if_stage_i.instr_valid_id_d` and `if_stage_i.instr_new_id_d`, so the module must declare these signals with the values that `instr_valid_id_o` and `instr_new_id_o` take in the next cycle.
