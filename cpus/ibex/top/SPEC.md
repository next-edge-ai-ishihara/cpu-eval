# Implement `ibex_top`

Implement the complete `ibex_top` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_top` definition in a single SystemVerilog code block, with no text outside the block.

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
  typedef struct packed {
    logic [31:0] current_pc;
    logic [31:0] next_pc;
    logic [31:0] last_data_addr;
    logic [31:0] exception_pc;
    logic [31:0] exception_addr;
  } crash_dump_t;
// ...
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
  // ICache constants
  parameter int unsigned ADDR_W           = 32;
  parameter int unsigned BUS_SIZE         = 32;
  parameter int unsigned BUS_BYTES        = BUS_SIZE/8;
  parameter int unsigned BUS_W            = $clog2(BUS_BYTES);
  parameter int unsigned IC_SIZE_BYTES    = 4096;
  parameter int unsigned IC_NUM_WAYS      = 2;
  parameter int unsigned IC_LINE_SIZE     = 64;
  parameter int unsigned IC_LINE_BYTES    = IC_LINE_SIZE/8;
  parameter int unsigned IC_LINE_W        = $clog2(IC_LINE_BYTES);
  parameter int unsigned IC_NUM_LINES     = IC_SIZE_BYTES / IC_NUM_WAYS / IC_LINE_BYTES;
  parameter int unsigned IC_LINE_BEATS    = IC_LINE_BYTES / BUS_BYTES;
  parameter int unsigned IC_LINE_BEATS_W  = $clog2(IC_LINE_BEATS);
  parameter int unsigned IC_INDEX_W       = $clog2(IC_NUM_LINES);
  parameter int unsigned IC_INDEX_HI      = IC_INDEX_W + IC_LINE_W - 1;
  parameter int unsigned IC_TAG_SIZE      = ADDR_W - IC_INDEX_W - IC_LINE_W + 1; // 1 valid bit
  parameter int unsigned IC_OUTPUT_BEATS  = (BUS_BYTES / 2); // number of halfwords
  parameter int unsigned IC_DATA_ECC_SIZE = 7;
  parameter int unsigned IC_TAG_ECC_SIZE  = 6;
  // ICache Scrambling Parameters
  parameter int unsigned SCRAMBLE_KEY_W   = 128;
  parameter int unsigned SCRAMBLE_NONCE_W = 64;

  // PMP constants
  parameter int unsigned PMP_MAX_REGIONS      = 16;
  parameter int unsigned PMP_CFG_W            = 8;
  // For RV32 the most significant bit of PMP address refers to the physical
  // address bit index 33.
  parameter int unsigned PMP_ADDR_MSB         = 33;
  // For RV32 the least significant bit of the PMP CSRs refers to the physical
  // address bit index 2.
  parameter int unsigned PMP_ADDR_LSB         = 2;

  // PMP access type
  parameter int unsigned PMP_I  = 0;
  parameter int unsigned PMP_I2 = 1;
  parameter int unsigned PMP_D  = 2;

  typedef enum logic [1:0] {
    PMP_ACC_EXEC    = 2'b00,
    PMP_ACC_WRITE   = 2'b01,
    PMP_ACC_READ    = 2'b10
  } pmp_req_e;

  // PMP cfg structures
  typedef enum logic [1:0] {
    PMP_MODE_OFF   = 2'b00,
    PMP_MODE_TOR   = 2'b01,
    PMP_MODE_NA4   = 2'b10,
    PMP_MODE_NAPOT = 2'b11
  } pmp_cfg_mode_e;

  typedef struct packed {
    logic          lock;
    pmp_cfg_mode_e mode;
    logic          exec;
    logic          write;
    logic          read;
  } pmp_cfg_t;

  // Machine Security Configuration (ePMP)
  typedef struct packed {
    logic rlb;  // Rule Locking Bypass
    logic mmwp; // Machine Mode Whitelist Policy
    logic mml;  // Machine Mode Lockdown
  } pmp_mseccfg_t;
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

  // Default reset values for PMP CSRs. Where the number of regions
  // (PMPNumRegions) is less than 16 the reset values for the higher numbered
  // regions are ignored.
  //
  // See the Ibex Reference Guide (Custom Reset Values under Physical Memory
  // Protection) for more information.

  parameter pmp_cfg_t PmpCfgRst[PMP_MAX_REGIONS] = '{
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 0
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 1
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 2
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 3
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 4
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 5
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 6
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 7
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 8
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 9
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 10
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 11
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 12
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 13
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}, // region 14
    '{lock: 1'b0, mode: PMP_MODE_OFF, exec: 1'b0, write: 1'b0, read: 1'b0}  // region 15
  };

  // Addresses are given in byte granularity for readability. A minimum of two
  // bits will be stripped off the bottom (PMPGranularity == 0) with more stripped
  // off at coarser granularities.
  parameter logic [PMP_ADDR_MSB:0] PmpAddrRst[PMP_MAX_REGIONS] = '{
    34'h0, // region 0
    34'h0, // region 1
    34'h0, // region 2
    34'h0, // region 3
    34'h0, // region 4
    34'h0, // region 5
    34'h0, // region 6
    34'h0, // region 7
    34'h0, // region 8
    34'h0, // region 9
    34'h0, // region 10
    34'h0, // region 11
    34'h0, // region 12
    34'h0, // region 13
    34'h0, // region 14
    34'h0  // region 15
  };

  parameter pmp_mseccfg_t PmpMseccfgRst = '{rlb : 1'b0, mmwp: 1'b0, mml: 1'b0};
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

```verilog
module ibex_top import ibex_pkg::*; import ibex_cheriot_pkg::*; #(
  parameter ibex_pkg::base_isa_e    BaseIsa                      = ibex_pkg::BaseIsaRV32I,
  parameter bit                     PMPEnable                    = 1'b0,
  parameter int unsigned            PMPGranularity               = 0,
  parameter int unsigned            PMPNumRegions                = 4,
  parameter int unsigned            MHPMCounterNum               = 0,
  parameter int unsigned            MHPMCounterWidth             = 40,
  parameter ibex_pkg::pmp_cfg_t     PMPRstCfg[PMP_MAX_REGIONS]   = ibex_pkg::PmpCfgRst,
  parameter logic [PMP_ADDR_MSB:0]  PMPRstAddr[PMP_MAX_REGIONS]  = ibex_pkg::PmpAddrRst,
  parameter ibex_pkg::pmp_mseccfg_t PMPRstMsecCfg                = ibex_pkg::PmpMseccfgRst,
  parameter int unsigned            CheriotRevBitmapAddrWidth    = 32'd11,
  parameter int unsigned            CheriotRevBitmapBaseAddr     = 32'h0,
  parameter bit                     RV32E                        = 1'b0,
  parameter rv32m_e                 RV32M                        = RV32MFast,
  parameter rv32b_e                 RV32B                        = RV32BNone,
  parameter rv32zc_e                RV32ZC                       = RV32ZcaZcbZcmp,
  parameter regfile_e               RegFile                      = RegFileFF,
  parameter bit                     BranchTargetALU              = 1'b0,
  parameter bit                     WritebackStage               = 1'b0,
  parameter bit                     ICache                       = 1'b0,
  parameter bit                     ICacheECC                    = 1'b0,
  parameter bit                     BranchPredictor              = 1'b0,
  parameter bit                     DbgTriggerEn                 = 1'b0,
  parameter int unsigned            DbgHwBreakNum                = 1,
  parameter bit                     SecureIbex                   = 1'b0,
  parameter int unsigned            LockstepOffset               = 1,
  parameter bit                     MemECC                       = SecureIbex,
  parameter int unsigned            MemDataWidth                 = MemECC ? 32 + 7 : 32,
  parameter bit                     ICacheScramble               = 1'b0,
  parameter int unsigned            ICacheScrNumPrinceRoundsHalf = 2,
  parameter bit                     ICacheTweakInfection         = SecureIbex,
  parameter lfsr_seed_t             RndCnstLfsrSeed              = RndCnstLfsrSeedDefault,
  parameter lfsr_perm_t             RndCnstLfsrPerm              = RndCnstLfsrPermDefault,
  parameter int unsigned            DmBaseAddr                   = 32'h1A110000,
  parameter int unsigned            DmAddrMask                   = 32'h00000FFF,
  parameter int unsigned            DmHaltAddr                   = 32'h1A110800,
  parameter int unsigned            DmExceptionAddr              = 32'h1A110808,
  // Default seed and nonce for scrambling
  parameter logic [SCRAMBLE_KEY_W-1:0]   RndCnstIbexKey          = RndCnstIbexKeyDefault,
  parameter logic [SCRAMBLE_NONCE_W-1:0] RndCnstIbexNonce        = RndCnstIbexNonceDefault,
  // mvendorid: encoding of manufacturer/provider
  // 0 indicates this field is not implemented. Ibex implementers may wish to set their
  // own JEDEC ID here.
  parameter logic [31:0]            CsrMvendorId                 = 32'b0,
  // mimpid: encoding of processor implementation version
  // 0 indicates this field is not implemented. Ibex implementers may wish to indicate an
  // RTL/netlist version here using their own unique encoding (e.g. 32 bits of the git hash of the
  // implemented commit).
  parameter logic [31:0]            CsrMimpId                    = 32'b0
) (
  // Clock and Reset
  input  logic                                                         clk_i,
  input  logic                                                         rst_ni,

  // enable all clock gates for testing
  input  logic                                                         test_en_i,
  input  prim_ram_1p_pkg::ram_1p_cfg_req_t [ibex_pkg::IC_NUM_WAYS-1:0] ram_cfg_icache_tag_i,
  output prim_ram_1p_pkg::ram_1p_cfg_rsp_t [ibex_pkg::IC_NUM_WAYS-1:0] ram_cfg_icache_tag_o,
  input  prim_ram_1p_pkg::ram_1p_cfg_req_t [ibex_pkg::IC_NUM_WAYS-1:0] ram_cfg_icache_data_i,
  output prim_ram_1p_pkg::ram_1p_cfg_rsp_t [ibex_pkg::IC_NUM_WAYS-1:0] ram_cfg_icache_data_o,

  input  ibex_mubi_t                                                   cheriot_enable_i,

  input  logic [31:0]                                                  hart_id_i,
  input  logic [31:0]                                                  boot_addr_i,

  input  logic [31:0]                                                  trvk_heap_base_addr_i,

  // Instruction memory interface
  output logic                                                         instr_req_o,
  input  logic                                                         instr_gnt_i,
  input  logic                                                         instr_rvalid_i,
  output logic [31:0]                                                  instr_addr_o,
  input  logic [31:0]                                                  instr_rdata_i,
  input  logic [6:0]                                                   instr_rdata_intg_i,
  input  logic                                                         instr_err_i,

  // Data memory interface
  output logic                                                         data_req_o,
  input  logic                                                         data_gnt_i,
  input  logic                                                         data_rvalid_i,
  output logic                                                         data_we_o,
  output logic [3:0]                                                   data_be_o,
  output logic [31:0]                                                  data_addr_o,
  output logic [31:0]                                                  data_wdata_o,
  output logic [6:0]                                                   data_wdata_intg_o,
  output logic                                                         data_tag_o,
  input  logic [31:0]                                                  data_rdata_i,
  input  logic [6:0]                                                   data_rdata_intg_i,
  input  logic                                                         data_tag_i,
  input  logic                                                         data_err_i,

  // TRVK revocation bitmap read interface
  output logic                                                         trvk_revbm_req_o,
  input  logic                                                         trvk_revbm_gnt_i,
  input  logic                                                         trvk_revbm_rvalid_i,
  output logic [31:0]                                                  trvk_revbm_addr_o,
  input  logic [31:0]                                                  trvk_revbm_rdata_i,
  input  logic [6:0]                                                   trvk_revbm_rdata_intg_i,
  input  logic                                                         trvk_revbm_err_i,

  // Interrupt inputs
  input  logic                                                         irq_software_i,
  input  logic                                                         irq_timer_i,
  input  logic                                                         irq_external_i,
  input  logic [14:0]                                                  irq_fast_i,
  // non-maskeable interrupt
  input  logic                                                         irq_nm_i,

  // Scrambling Interface
  input  logic                                                         scramble_key_valid_i,
  input  logic [SCRAMBLE_KEY_W-1:0]                                    scramble_key_i,
  input  logic [SCRAMBLE_NONCE_W-1:0]                                  scramble_nonce_i,
  output logic                                                         scramble_req_o,

  // Debug Interface
  input  logic                                                         debug_req_i,
  output crash_dump_t                                                  crash_dump_o,
  output logic                                                         double_fault_seen_o,

  // RISC-V Formal Interface
  // Does not comply with the coding standards of _i/_o suffixes, but follows
  // the convention of RISC-V Formal Interface Specification.
`ifdef RVFI
  output logic                                                        rvfi_valid,
  output logic [63:0]                                                 rvfi_order,
  output logic [31:0]                                                 rvfi_insn,
  output logic                                                        rvfi_trap,
  output logic                                                        rvfi_halt,
  output logic                                                        rvfi_intr,
  output logic [ 1:0]                                                 rvfi_mode,
  output logic [ 1:0]                                                 rvfi_ixl,
  output logic [ 4:0]                                                 rvfi_rs1_addr,
  output logic [ 4:0]                                                 rvfi_rs2_addr,
  output logic [ 4:0]                                                 rvfi_rs3_addr,
  output logic [31:0]                                                 rvfi_rs1_rdata,
  output logic [31:0]                                                 rvfi_rs2_rdata,
  output logic [31:0]                                                 rvfi_rs3_rdata,
  output cap_t                                                        rvfi_rs1_rcap,
  output cap_t                                                        rvfi_rs2_rcap,
  output cap_t                                                        rvfi_rd_wcap,
  output logic [ 4:0]                                                 rvfi_rd_addr,
  output logic [31:0]                                                 rvfi_rd_wdata,
  output logic [31:0]                                                 rvfi_pc_rdata,
  output logic [31:0]                                                 rvfi_pc_wdata,
  output logic [31:0]                                                 rvfi_mem_addr,
  output logic [ 3:0]                                                 rvfi_mem_rmask,
  output logic [ 3:0]                                                 rvfi_mem_wmask,
  output logic [31:0]                                                 rvfi_mem_rdata,
  output logic [31:0]                                                 rvfi_mem_wdata,
  output logic                                                        rvfi_mem_is_cap,
  output cap_t                                                        rvfi_mem_rcap,
  output cap_t                                                        rvfi_mem_wcap,
  output logic [31:0]                                                 rvfi_ext_pre_mip,
  output logic [31:0]                                                 rvfi_ext_post_mip,
  output logic                                                        rvfi_ext_nmi,
  output logic                                                        rvfi_ext_nmi_int,
  output logic                                                        rvfi_ext_debug_req,
  output logic                                                        rvfi_ext_debug_mode,
  output logic                                                        rvfi_ext_rf_wr_suppress,
  output logic [63:0]                                                 rvfi_ext_mcycle,
  output logic [31:0]                                                 rvfi_ext_mhpmcounters [10],
  output logic [31:0]                                                 rvfi_ext_mhpmcountersh [10],
  output logic                                                        rvfi_ext_ic_scr_key_valid,
  output logic                                                        rvfi_ext_irq_valid,
  output logic                                                        rvfi_ext_expanded_insn_valid,
  output logic [15:0]                                                 rvfi_ext_expanded_insn,
  output logic                                                        rvfi_ext_expanded_insn_last,
`endif

  // CPU Control Signals
  input  ibex_mubi_t                                                  fetch_enable_i,
  input  ibex_mubi_t                                                  mcounteren_writable_i,
  output logic                                                        alert_minor_o,
  output logic                                                        alert_major_internal_o,
  output logic                                                        alert_major_bus_o,
  output logic                                                        core_sleep_o,

  // DFT bypass controls
  input logic                                                         scan_rst_ni,

  // Lockstep signals
  output ibex_mubi_t                                                  lockstep_cmp_en_o,

  // Shadow core data interface outputs
  output logic                                                        data_req_shadow_o,
  output logic                                                        data_we_shadow_o,
  output logic [3:0]                                                  data_be_shadow_o,
  output logic [31:0]                                                 data_addr_shadow_o,
  output logic [31:0]                                                 data_wdata_shadow_o,
  output logic [6:0]                                                  data_wdata_intg_shadow_o,

  // Shadow core instruction interface outputs
  output logic                                                        instr_req_shadow_o,
  output logic [31:0]                                                 instr_addr_shadow_o
);
```

## Dependency declarations

### rtl/ibex_core.sv

```verilog
module ibex_core import ibex_pkg::*; import ibex_cheriot_pkg::*; #(
  parameter base_isa_e              BaseIsa                     = BaseIsaRV32I,
  parameter bit                     PMPEnable                   = 1'b0,
  parameter int unsigned            PMPGranularity              = 0,
  parameter int unsigned            PMPNumRegions               = 4,
  parameter ibex_pkg::pmp_cfg_t     PMPRstCfg[PMP_MAX_REGIONS]  = ibex_pkg::PmpCfgRst,
  parameter logic [PMP_ADDR_MSB:0]  PMPRstAddr[PMP_MAX_REGIONS] = ibex_pkg::PmpAddrRst,
  parameter ibex_pkg::pmp_mseccfg_t PMPRstMsecCfg               = ibex_pkg::PmpMseccfgRst,
  parameter int unsigned            MHPMCounterNum              = 0,
  parameter int unsigned            MHPMCounterWidth            = 40,
  parameter bit                     RV32E                       = 1'b0,
  parameter rv32m_e                 RV32M                       = RV32MFast,
  parameter rv32b_e                 RV32B                       = RV32BNone,
  parameter rv32zc_e                RV32ZC                      = RV32ZcaZcbZcmp,
  parameter bit                     BranchTargetALU             = 1'b0,
  parameter bit                     WritebackStage              = 1'b0,
  parameter bit                     ICache                      = 1'b0,
  parameter bit                     ICacheECC                   = 1'b0,
  parameter bit                     ICacheTweakInfection        = 1'b0,
  parameter int unsigned            BusSizeECC                  = BUS_SIZE,
  parameter int unsigned            TagSizeECC                  = IC_TAG_SIZE,
  parameter int unsigned            LineSizeECC                 = IC_LINE_SIZE,
  parameter bit                     BranchPredictor             = 1'b0,
  parameter bit                     DbgTriggerEn                = 1'b0,
  parameter int unsigned            DbgHwBreakNum               = 1,
  parameter bit                     ResetAll                    = 1'b0,
  parameter lfsr_seed_t             RndCnstLfsrSeed             = RndCnstLfsrSeedDefault,
  parameter lfsr_perm_t             RndCnstLfsrPerm             = RndCnstLfsrPermDefault,
  parameter bit                     SecureIbex                  = 1'b0,
  parameter bit                     DummyInstructions           = 1'b0,
  parameter bit                     RegFileECC                  = 1'b0,
  parameter int unsigned            RegFileDataWidth            = 32,
  parameter int unsigned            RegFileCapEccWidth          = REGCAP_W,
  parameter bit                     MemECC                      = 1'b0,
  parameter int unsigned            MemDataWidth                = MemECC ? 32 + 7 : 32,
  parameter int unsigned            DmBaseAddr                  = 32'h1A110000,
  parameter int unsigned            DmAddrMask                  = 32'h00000FFF,
  parameter int unsigned            DmHaltAddr                  = 32'h1A110800,
  parameter int unsigned            DmExceptionAddr             = 32'h1A110808,
  // mvendorid: encoding of manufacturer/provider
  parameter logic [31:0]            CsrMvendorId                = 32'b0,
  // marchid: encoding of base microarchitecture
  parameter logic [31:0]            CsrMimpId                   = 32'b0
) (
  // Clock and Reset
  input  logic                         clk_i,
  input  logic                         rst_ni,

  input  logic [31:0]                  hart_id_i,
  input  logic [31:0]                  boot_addr_i,
  input  ibex_mubi_t                   cheriot_enable_i,

  // Instruction memory interface
  output logic                         instr_req_o,
  input  logic                         instr_gnt_i,
  input  logic                         instr_rvalid_i,
  output logic [31:0]                  instr_addr_o,
  input  logic [MemDataWidth-1:0]      instr_rdata_i,
  input  logic                         instr_err_i,

  // Data memory interface
  output logic                         data_req_o,
  input  logic                         data_gnt_i,
  input  logic                         data_rvalid_i,
  output logic                         data_we_o,
  output logic [3:0]                   data_be_o,
  output logic [31:0]                  data_addr_o,
  output logic [MemDataWidth-1:0]      data_wdata_o,
  output logic                         data_tag_o,
  input  logic [MemDataWidth-1:0]      data_rdata_i,
  input  logic                         data_tag_i,
  input  logic                         data_err_i,

  // Register file interface
  output logic                         dummy_instr_id_o,
  output logic                         dummy_instr_wb_o,
  output logic [4:0]                   rf_raddr_a_o,
  output logic [4:0]                   rf_raddr_b_o,
  output logic [4:0]                   rf_waddr_wb_o,
  output logic                         rf_we_wb_o,
  output logic [RegFileDataWidth-1:0]   rf_wdata_wb_ecc_o,
  input  logic [RegFileDataWidth-1:0]   rf_rdata_a_ecc_i,
  input  logic [RegFileDataWidth-1:0]   rf_rdata_b_ecc_i,
  output logic [RegFileCapEccWidth-1:0] rf_wcap_ecc_wb_o,
  input  logic [RegFileCapEccWidth-1:0] rf_rcap_a_ecc_i,
  input  logic [RegFileCapEccWidth-1:0] rf_rcap_b_ecc_i,

  // RAMs interface
  output logic [IC_NUM_WAYS-1:0]       ic_tag_req_o,
  output logic                         ic_tag_write_o,
  output logic [IC_INDEX_W-1:0]        ic_tag_addr_o,
  output logic [TagSizeECC-1:0]        ic_tag_wdata_o,
  input  logic [TagSizeECC-1:0]        ic_tag_rdata_i [IC_NUM_WAYS],
  output logic [IC_NUM_WAYS-1:0]       ic_data_req_o,
  output logic                         ic_data_write_o,
  output logic [IC_INDEX_W-1:0]        ic_data_addr_o,
  output logic [LineSizeECC-1:0]       ic_data_wdata_o,
  input  logic [LineSizeECC-1:0]       ic_data_rdata_i [IC_NUM_WAYS],
  input  logic                         ic_scr_key_valid_i,
  output logic                         ic_scr_key_req_o,

  // Interrupt inputs
  input  logic                         irq_software_i,
  input  logic                         irq_timer_i,
  input  logic                         irq_external_i,
  input  logic [14:0]                  irq_fast_i,
  input  logic                         irq_nm_i,       // non-maskable interrupt
  output logic                         irq_pending_o,

  // Debug Interface
  input  logic                         debug_req_i,
  output crash_dump_t                  crash_dump_o,
  // SEC_CM: EXCEPTION.CTRL_FLOW.LOCAL_ESC
  // SEC_CM: EXCEPTION.CTRL_FLOW.GLOBAL_ESC
  output logic                         double_fault_seen_o,

  // RISC-V Formal Interface
  // Does not comply with the coding standards of _i/_o suffixes, but follows
  // the convention of RISC-V Formal Interface Specification.
`ifdef RVFI
  output logic                         rvfi_valid,
  output logic [63:0]                  rvfi_order,
  output logic [31:0]                  rvfi_insn,
  output logic                         rvfi_trap,
  output logic                         rvfi_halt,
  output logic                         rvfi_intr,
  output logic [ 1:0]                  rvfi_mode,
  output logic [ 1:0]                  rvfi_ixl,
  output logic [ 4:0]                  rvfi_rs1_addr,
  output logic [ 4:0]                  rvfi_rs2_addr,
  output logic [ 4:0]                  rvfi_rs3_addr,
  output logic [31:0]                  rvfi_rs1_rdata,
  output cap_t                         rvfi_rs1_rcap,
  output logic [31:0]                  rvfi_rs2_rdata,
  output cap_t                         rvfi_rs2_rcap,
  output logic [31:0]                  rvfi_rs3_rdata,
  output logic [ 4:0]                  rvfi_rd_addr,
  output logic [31:0]                  rvfi_rd_wdata,
  output cap_t                         rvfi_rd_wcap,
  output logic [31:0]                  rvfi_pc_rdata,
  output logic [31:0]                  rvfi_pc_wdata,
  output logic                         rvfi_mem_is_cap,
  output logic [31:0]                  rvfi_mem_addr,
  output logic [ 3:0]                  rvfi_mem_rmask,
  output logic [ 3:0]                  rvfi_mem_wmask,
  output logic [31:0]                  rvfi_mem_rdata,
  output cap_t                         rvfi_mem_rcap,
  output logic [31:0]                  rvfi_mem_wdata,
  output cap_t                         rvfi_mem_wcap,
  output logic [31:0]                  rvfi_ext_pre_mip,
  output logic [31:0]                  rvfi_ext_post_mip,
  output logic                         rvfi_ext_nmi,
  output logic                         rvfi_ext_nmi_int,
  output logic                         rvfi_ext_debug_req,
  output logic                         rvfi_ext_debug_mode,
  output logic                         rvfi_ext_rf_wr_suppress,
  output logic [63:0]                  rvfi_ext_mcycle,
  output logic [31:0]                  rvfi_ext_mhpmcounters [10],
  output logic [31:0]                  rvfi_ext_mhpmcountersh [10],
  output logic                         rvfi_ext_ic_scr_key_valid,
  output logic                         rvfi_ext_irq_valid,
  output logic                         rvfi_ext_expanded_insn_valid,
  output logic [15:0]                  rvfi_ext_expanded_insn,
  output logic                         rvfi_ext_expanded_insn_last,
  `endif

  // CPU Control Signals
  // SEC_CM: FETCH.CTRL.LC_GATED
  input  ibex_mubi_t                   fetch_enable_i,
  input  ibex_mubi_t                   mcounteren_writable_i,
  output logic                         alert_minor_o,
  output logic                         alert_major_internal_o,
  output logic                         alert_major_bus_o,
  output ibex_mubi_t                   core_busy_o
);
```

### rtl/ibex_register_file_ff.sv

```verilog
module ibex_register_file_ff import ibex_pkg::*; #(
  parameter base_isa_e            BaseIsa           = BaseIsaRV32I,
  parameter bit                   RV32E             = 0,
  parameter int unsigned          DataWidth         = 32,
  parameter bit                   DummyInstructions = 0,
  parameter logic [DataWidth-1:0] WordZeroVal       = '0,
  // Capability port width
  parameter int unsigned          CapWidth          = ibex_cheriot_pkg::REGCAP_W,
  parameter logic [CapWidth-1:0]  CapWordZeroVal    = '0
) (
  // Clock and Reset
  input  logic                 clk_i,
  input  logic                 rst_ni,

  input  logic                 test_en_i,
  input  logic                 dummy_instr_id_i,
  input  logic                 dummy_instr_wb_i,

  input  ibex_mubi_t           cheriot_enable_i,

  // Read port R1
  input  logic [4:0]           raddr_a_i,
  output logic [DataWidth-1:0] rdata_a_o,
  output logic [CapWidth-1:0]  rcap_a_o,

  // Read port R2
  input  logic [4:0]           raddr_b_i,
  output logic [DataWidth-1:0] rdata_b_o,
  output logic [CapWidth-1:0]  rcap_b_o,

  // Write port W1
  input  logic [4:0]           waddr_a_i,
  input  logic [DataWidth-1:0] wdata_a_i,
  input  logic [CapWidth-1:0]  wcap_a_i,
  input  logic                 we_a_i
);
```

### vendor/lowrisc_ip/ip/prim_generic/rtl/prim_buf.sv

```verilog
module prim_buf #(
  parameter int Width = 1
) (
  input        [Width-1:0] in_i,
  output logic [Width-1:0] out_o
);
```

### vendor/lowrisc_ip/ip/prim_generic/rtl/prim_clock_gating.sv

```verilog
module prim_clock_gating #(
  parameter bit NoFpgaGate = 1'b0, // this parameter has no function in generic
  parameter bit FpgaBufGlobal = 1'b1 // this parameter has no function in generic
) (
  input        clk_i,
  input        en_i,
  input        test_en_i,
  output logic clk_o
);
```

## Related source code

### dv/verilator/simple_system_cosim/ibex_simple_system_cosim_checker.sv

```verilog
        outstanding_misaligned_first <=
          u_top.u_ibex_top.u_ibex_core.load_store_unit_i.handle_misaligned_d |
          ((u_top.u_ibex_top.u_ibex_core.load_store_unit_i.lsu_type_i == 2'b01) &
           (u_top.u_ibex_top.u_ibex_core.load_store_unit_i.data_offset == 2'b01));

        outstanding_misaligned_second <=
          u_top.u_ibex_top.u_ibex_core.load_store_unit_i.addr_incr_req_o;

        outstanding_misaligned_first_saw_error <=
          u_top.u_ibex_top.u_ibex_core.load_store_unit_i.addr_incr_req_o &
          u_top.u_ibex_top.u_ibex_core.load_store_unit_i.lsu_err_d;

        outstanding_m_mode_access <=
          u_top.u_ibex_top.u_ibex_core.priv_mode_lsu == ibex_pkg::PRIV_LVL_M;
```

### examples/simple_system/rtl/ibex_simple_system.sv

```verilog
  export "DPI-C" function mhpmcounter_num;

  function automatic int unsigned mhpmcounter_num();
    return u_top.u_ibex_top.u_ibex_core.cs_registers_i.MHPMCounterNum;
  endfunction

  export "DPI-C" function mhpmcounter_get;

  function automatic longint unsigned mhpmcounter_get(int index);
    return u_top.u_ibex_top.u_ibex_core.cs_registers_i.mhpmcounter[index];
  endfunction
```

## Documentation

### doc/03_reference/pipeline_details.rst

```text
Pipeline Details
================
Ibex has a 2-stage pipeline, the 2 stages are:

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
```
