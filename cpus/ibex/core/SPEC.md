# Implement `ibex_core`

Implement the complete `ibex_core` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_core` definition in a single SystemVerilog code block, with no text outside the block.

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

  typedef enum logic [6:0] {
    // Arithmetics
    ALU_ADD,
    ALU_SUB,

    // Logics
    ALU_XOR,
    ALU_OR,
    ALU_AND,
    // RV32B
    ALU_XNOR,
    ALU_ORN,
    ALU_ANDN,

    // Shifts
    ALU_SRA,
    ALU_SRL,
    ALU_SLL,
    // RV32B
    ALU_SRO,
    ALU_SLO,
    ALU_ROR,
    ALU_ROL,
    ALU_GREV,
    ALU_GORC,
    ALU_SHFL,
    ALU_UNSHFL,
    ALU_XPERM_N,
    ALU_XPERM_B,
    ALU_XPERM_H,

    // Address Calculations
    // RV32B
    ALU_SH1ADD,
    ALU_SH2ADD,
    ALU_SH3ADD,

    // Comparisons
    ALU_LT,
    ALU_LTU,
    ALU_GE,
    ALU_GEU,
    ALU_EQ,
    ALU_NE,
    // RV32B
    ALU_MIN,
    ALU_MINU,
    ALU_MAX,
    ALU_MAXU,

    // Pack
    // RV32B
    ALU_PACK,
    ALU_PACKU,
    ALU_PACKH,

    // Sign-Extend
    // RV32B
    ALU_SEXTB,
    ALU_SEXTH,

    // Bitcounting
    // RV32B
    ALU_CLZ,
    ALU_CTZ,
    ALU_CPOP,

    // Set lower than
    ALU_SLT,
    ALU_SLTU,

    // Ternary Bitmanip Operations
    // RV32B
    ALU_CMOV,
    ALU_CMIX,
    ALU_FSL,
    ALU_FSR,

    // Single-Bit Operations
    // RV32B
    ALU_BSET,
    ALU_BCLR,
    ALU_BINV,
    ALU_BEXT,

    // Bit Compress / Decompress
    // RV32B
    ALU_BCOMPRESS,
    ALU_BDECOMPRESS,

    // Bit Field Place
    // RV32B
    ALU_BFP,

    // Carry-less Multiply
    // RV32B
    ALU_CLMUL,
    ALU_CLMULR,
    ALU_CLMULH,

    // Cyclic Redundancy Check
    ALU_CRC32_B,
    ALU_CRC32C_B,
    ALU_CRC32_H,
    ALU_CRC32C_H,
    ALU_CRC32_W,
    ALU_CRC32C_W
  } alu_op_e;

  typedef enum logic [1:0] {
    // Multiplier/divider
    MD_OP_MULL,
    MD_OP_MULH,
    MD_OP_DIV,
    MD_OP_REM
  } md_op_e;


  //////////////////////////////////
  // Control and status registers //
  //////////////////////////////////

  // CSR operations
  typedef enum logic [1:0] {
    CSR_OP_READ,
    CSR_OP_WRITE,
    CSR_OP_SET,
    CSR_OP_CLEAR
  } csr_op_e;

  // Privileged mode
  typedef enum logic[1:0] {
    PRIV_LVL_M = 2'b11,
    PRIV_LVL_H = 2'b10,
    PRIV_LVL_S = 2'b01,
    PRIV_LVL_U = 2'b00
  } priv_lvl_e;

  // Constants for the dcsr.xdebugver fields
  typedef enum logic[3:0] {
    XDEBUGVER_NO     = 4'd0, // no external debug support
    XDEBUGVER_STD    = 4'd4, // external debug according to RISC-V debug spec
    XDEBUGVER_NONSTD = 4'd15 // debug not conforming to RISC-V debug spec
  } x_debug_ver_e;

  //////////////
  // WB stage //
  //////////////

  // Type of instruction present in writeback stage
  typedef enum logic[1:0] {
    WB_INSTR_LOAD,  // Instruction is awaiting load data
    WB_INSTR_STORE, // Instruction is awaiting store response
    WB_INSTR_OTHER  // Instruction doesn't fit into above categories
  } wb_instr_type_e;

  //////////////
  // ID stage //
  //////////////

  // Operand a selection
  typedef enum logic[1:0] {
    OP_A_REG_A,
    OP_A_FWD,
    OP_A_CURRPC,
    OP_A_IMM
  } op_a_sel_e;

  // Immediate a selection
  typedef enum logic {
    IMM_A_Z,
    IMM_A_ZERO
  } imm_a_sel_e;

  // Operand b selection
  typedef enum logic {
    OP_B_REG_B,
    OP_B_IMM
  } op_b_sel_e;

  // Immediate b selection
  typedef enum logic [2:0] {
    IMM_B_I,
    IMM_B_S,
    IMM_B_B,
    IMM_B_U,
    IMM_B_J,
    IMM_B_INCR_PC,
    IMM_B_INCR_ADDR
  } imm_b_sel_e;

  // Regfile write data selection
  typedef enum logic {
    RF_WD_EX,
    RF_WD_CSR
  } rf_wd_sel_e;

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

  // CSRs
  typedef enum logic[11:0] {
    // Machine information
    CSR_MVENDORID  = 12'hF11,
    CSR_MARCHID    = 12'hF12,
    CSR_MIMPID     = 12'hF13,
    CSR_MHARTID    = 12'hF14,
    CSR_MCONFIGPTR = 12'hF15,

    // Machine trap setup
    CSR_MSTATUS   = 12'h300,
    CSR_MISA      = 12'h301,
    CSR_MIE       = 12'h304,
    CSR_MTVEC     = 12'h305,
    CSR_MCOUNTEREN= 12'h306,
    CSR_MSTATUSH  = 12'h310,

    CSR_MENVCFG   = 12'h30A,
    CSR_MENVCFGH  = 12'h31A,

    // Machine trap handling
    CSR_MSCRATCH  = 12'h340,
    CSR_MEPC      = 12'h341,
    CSR_MCAUSE    = 12'h342,
    CSR_MTVAL     = 12'h343,
    CSR_MIP       = 12'h344,

    // Physical memory protection
    CSR_PMPCFG0   = 12'h3A0,
    CSR_PMPCFG1   = 12'h3A1,
    CSR_PMPCFG2   = 12'h3A2,
    CSR_PMPCFG3   = 12'h3A3,
    CSR_PMPADDR0  = 12'h3B0,
    CSR_PMPADDR1  = 12'h3B1,
    CSR_PMPADDR2  = 12'h3B2,
    CSR_PMPADDR3  = 12'h3B3,
    CSR_PMPADDR4  = 12'h3B4,
    CSR_PMPADDR5  = 12'h3B5,
    CSR_PMPADDR6  = 12'h3B6,
    CSR_PMPADDR7  = 12'h3B7,
    CSR_PMPADDR8  = 12'h3B8,
    CSR_PMPADDR9  = 12'h3B9,
    CSR_PMPADDR10 = 12'h3BA,
    CSR_PMPADDR11 = 12'h3BB,
    CSR_PMPADDR12 = 12'h3BC,
    CSR_PMPADDR13 = 12'h3BD,
    CSR_PMPADDR14 = 12'h3BE,
    CSR_PMPADDR15 = 12'h3BF,

    CSR_SCONTEXT  = 12'h5A8,

    // ePMP control
    CSR_MSECCFG   = 12'h747,
    CSR_MSECCFGH  = 12'h757,

    // Debug trigger
    CSR_TSELECT   = 12'h7A0,
    CSR_TDATA1    = 12'h7A1,
    CSR_TDATA2    = 12'h7A2,
    CSR_TDATA3    = 12'h7A3,
    CSR_MCONTEXT  = 12'h7A8,
    CSR_MSCONTEXT = 12'h7AA,

    // Debug/trace
    CSR_DCSR      = 12'h7b0,
    CSR_DPC       = 12'h7b1,

    // Debug
    CSR_DSCRATCH0 = 12'h7b2, // optional
    CSR_DSCRATCH1 = 12'h7b3, // optional

    // Machine Counter/Timers
    CSR_MCOUNTINHIBIT  = 12'h320,
    CSR_MHPMEVENT3     = 12'h323,
    CSR_MHPMEVENT4     = 12'h324,
    CSR_MHPMEVENT5     = 12'h325,
    CSR_MHPMEVENT6     = 12'h326,
    CSR_MHPMEVENT7     = 12'h327,
    CSR_MHPMEVENT8     = 12'h328,
    CSR_MHPMEVENT9     = 12'h329,
    CSR_MHPMEVENT10    = 12'h32A,
    CSR_MHPMEVENT11    = 12'h32B,
    CSR_MHPMEVENT12    = 12'h32C,
    CSR_MHPMEVENT13    = 12'h32D,
    CSR_MHPMEVENT14    = 12'h32E,
    CSR_MHPMEVENT15    = 12'h32F,
    CSR_MHPMEVENT16    = 12'h330,
    CSR_MHPMEVENT17    = 12'h331,
    CSR_MHPMEVENT18    = 12'h332,
    CSR_MHPMEVENT19    = 12'h333,
    CSR_MHPMEVENT20    = 12'h334,
    CSR_MHPMEVENT21    = 12'h335,
    CSR_MHPMEVENT22    = 12'h336,
    CSR_MHPMEVENT23    = 12'h337,
    CSR_MHPMEVENT24    = 12'h338,
    CSR_MHPMEVENT25    = 12'h339,
    CSR_MHPMEVENT26    = 12'h33A,
    CSR_MHPMEVENT27    = 12'h33B,
    CSR_MHPMEVENT28    = 12'h33C,
    CSR_MHPMEVENT29    = 12'h33D,
    CSR_MHPMEVENT30    = 12'h33E,
    CSR_MHPMEVENT31    = 12'h33F,
    CSR_MCYCLE         = 12'hB00,
    CSR_MINSTRET       = 12'hB02,
    CSR_MHPMCOUNTER3   = 12'hB03,
    CSR_MHPMCOUNTER4   = 12'hB04,
    CSR_MHPMCOUNTER5   = 12'hB05,
    CSR_MHPMCOUNTER6   = 12'hB06,
    CSR_MHPMCOUNTER7   = 12'hB07,
    CSR_MHPMCOUNTER8   = 12'hB08,
    CSR_MHPMCOUNTER9   = 12'hB09,
    CSR_MHPMCOUNTER10  = 12'hB0A,
    CSR_MHPMCOUNTER11  = 12'hB0B,
    CSR_MHPMCOUNTER12  = 12'hB0C,
    CSR_MHPMCOUNTER13  = 12'hB0D,
    CSR_MHPMCOUNTER14  = 12'hB0E,
    CSR_MHPMCOUNTER15  = 12'hB0F,
    CSR_MHPMCOUNTER16  = 12'hB10,
    CSR_MHPMCOUNTER17  = 12'hB11,
    CSR_MHPMCOUNTER18  = 12'hB12,
    CSR_MHPMCOUNTER19  = 12'hB13,
    CSR_MHPMCOUNTER20  = 12'hB14,
    CSR_MHPMCOUNTER21  = 12'hB15,
    CSR_MHPMCOUNTER22  = 12'hB16,
    CSR_MHPMCOUNTER23  = 12'hB17,
    CSR_MHPMCOUNTER24  = 12'hB18,
    CSR_MHPMCOUNTER25  = 12'hB19,
    CSR_MHPMCOUNTER26  = 12'hB1A,
    CSR_MHPMCOUNTER27  = 12'hB1B,
    CSR_MHPMCOUNTER28  = 12'hB1C,
    CSR_MHPMCOUNTER29  = 12'hB1D,
    CSR_MHPMCOUNTER30  = 12'hB1E,
    CSR_MHPMCOUNTER31  = 12'hB1F,
    CSR_MCYCLEH        = 12'hB80,
    CSR_MINSTRETH      = 12'hB82,
    CSR_MHPMCOUNTER3H  = 12'hB83,
    CSR_MHPMCOUNTER4H  = 12'hB84,
    CSR_MHPMCOUNTER5H  = 12'hB85,
    CSR_MHPMCOUNTER6H  = 12'hB86,
    CSR_MHPMCOUNTER7H  = 12'hB87,
    CSR_MHPMCOUNTER8H  = 12'hB88,
    CSR_MHPMCOUNTER9H  = 12'hB89,
    CSR_MHPMCOUNTER10H = 12'hB8A,
    CSR_MHPMCOUNTER11H = 12'hB8B,
    CSR_MHPMCOUNTER12H = 12'hB8C,
    CSR_MHPMCOUNTER13H = 12'hB8D,
    CSR_MHPMCOUNTER14H = 12'hB8E,
    CSR_MHPMCOUNTER15H = 12'hB8F,
    CSR_MHPMCOUNTER16H = 12'hB90,
    CSR_MHPMCOUNTER17H = 12'hB91,
    CSR_MHPMCOUNTER18H = 12'hB92,
    CSR_MHPMCOUNTER19H = 12'hB93,
    CSR_MHPMCOUNTER20H = 12'hB94,
    CSR_MHPMCOUNTER21H = 12'hB95,
    CSR_MHPMCOUNTER22H = 12'hB96,
    CSR_MHPMCOUNTER23H = 12'hB97,
    CSR_MHPMCOUNTER24H = 12'hB98,
    CSR_MHPMCOUNTER25H = 12'hB99,
    CSR_MHPMCOUNTER26H = 12'hB9A,
    CSR_MHPMCOUNTER27H = 12'hB9B,
    CSR_MHPMCOUNTER28H = 12'hB9C,
    CSR_MHPMCOUNTER29H = 12'hB9D,
    CSR_MHPMCOUNTER30H = 12'hB9E,
    CSR_MHPMCOUNTER31H = 12'hB9F,
    CSR_MSHWM          = 12'hBC1,
    CSR_MSHWMB         = 12'hBC2,
    CSR_CDBG_CTRL      = 12'hBC4,
    // Unprivileged Counter/Timers (readable from U-mode subject to mcounteren)
    CSR_CYCLE          = 12'hC00,
    CSR_INSTRET        = 12'hC02,
    CSR_HPMCOUNTER3    = 12'hC03,
    CSR_HPMCOUNTER4    = 12'hC04,
    CSR_HPMCOUNTER5    = 12'hC05,
    CSR_HPMCOUNTER6    = 12'hC06,
    CSR_HPMCOUNTER7    = 12'hC07,
    CSR_HPMCOUNTER8    = 12'hC08,
    CSR_HPMCOUNTER9    = 12'hC09,
    CSR_HPMCOUNTER10   = 12'hC0A,
    CSR_HPMCOUNTER11   = 12'hC0B,
    CSR_HPMCOUNTER12   = 12'hC0C,
    CSR_HPMCOUNTER13   = 12'hC0D,
    CSR_HPMCOUNTER14   = 12'hC0E,
    CSR_HPMCOUNTER15   = 12'hC0F,
    CSR_HPMCOUNTER16   = 12'hC10,
    CSR_HPMCOUNTER17   = 12'hC11,
    CSR_HPMCOUNTER18   = 12'hC12,
    CSR_HPMCOUNTER19   = 12'hC13,
    CSR_HPMCOUNTER20   = 12'hC14,
    CSR_HPMCOUNTER21   = 12'hC15,
    CSR_HPMCOUNTER22   = 12'hC16,
    CSR_HPMCOUNTER23   = 12'hC17,
    CSR_HPMCOUNTER24   = 12'hC18,
    CSR_HPMCOUNTER25   = 12'hC19,
    CSR_HPMCOUNTER26   = 12'hC1A,
    CSR_HPMCOUNTER27   = 12'hC1B,
    CSR_HPMCOUNTER28   = 12'hC1C,
    CSR_HPMCOUNTER29   = 12'hC1D,
    CSR_HPMCOUNTER30   = 12'hC1E,
    CSR_HPMCOUNTER31   = 12'hC1F,
    CSR_CYCLEH         = 12'hC80,
    CSR_INSTRETH       = 12'hC82,
    CSR_HPMCOUNTER3H   = 12'hC83,
    CSR_HPMCOUNTER4H   = 12'hC84,
    CSR_HPMCOUNTER5H   = 12'hC85,
    CSR_HPMCOUNTER6H   = 12'hC86,
    CSR_HPMCOUNTER7H   = 12'hC87,
    CSR_HPMCOUNTER8H   = 12'hC88,
    CSR_HPMCOUNTER9H   = 12'hC89,
    CSR_HPMCOUNTER10H  = 12'hC8A,
    CSR_HPMCOUNTER11H  = 12'hC8B,
    CSR_HPMCOUNTER12H  = 12'hC8C,
    CSR_HPMCOUNTER13H  = 12'hC8D,
    CSR_HPMCOUNTER14H  = 12'hC8E,
    CSR_HPMCOUNTER15H  = 12'hC8F,
    CSR_HPMCOUNTER16H  = 12'hC90,
    CSR_HPMCOUNTER17H  = 12'hC91,
    CSR_HPMCOUNTER18H  = 12'hC92,
    CSR_HPMCOUNTER19H  = 12'hC93,
    CSR_HPMCOUNTER20H  = 12'hC94,
    CSR_HPMCOUNTER21H  = 12'hC95,
    CSR_HPMCOUNTER22H  = 12'hC96,
    CSR_HPMCOUNTER23H  = 12'hC97,
    CSR_HPMCOUNTER24H  = 12'hC98,
    CSR_HPMCOUNTER25H  = 12'hC99,
    CSR_HPMCOUNTER26H  = 12'hC9A,
    CSR_HPMCOUNTER27H  = 12'hC9B,
    CSR_HPMCOUNTER28H  = 12'hC9C,
    CSR_HPMCOUNTER29H  = 12'hC9D,
    CSR_HPMCOUNTER30H  = 12'hC9E,
    CSR_HPMCOUNTER31H  = 12'hC9F,
    CSR_CPUCTRLSTS     = 12'h7C0,
    CSR_SECURESEED     = 12'h7C1
  } csr_num_e;

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

## Parent instantiation

### rtl/ibex_top.sv

```verilog
  ibex_core #(
    .PMPEnable            (PMPEnable),
    .PMPGranularity       (PMPGranularity),
    .PMPNumRegions        (PMPNumRegions),
    .PMPRstCfg            (PMPRstCfg),
    .PMPRstAddr           (PMPRstAddr),
    .PMPRstMsecCfg        (PMPRstMsecCfg),
    .MHPMCounterNum       (MHPMCounterNum),
    .MHPMCounterWidth     (MHPMCounterWidth),
    .RV32E                (RV32E),
    .RV32M                (RV32M),
    .RV32B                (RV32B),
    .RV32ZC               (RV32ZC),
    .BranchTargetALU      (BranchTargetALU),
    .ICache               (ICache),
    .ICacheECC            (ICacheECC),
    .ICacheTweakInfection (ICacheTweakInfection),
    .BusSizeECC           (BusSizeECC),
    .TagSizeECC           (TagSizeECC),
    .LineSizeECC          (LineSizeECC),
    .BranchPredictor      (BranchPredictor),
    .DbgTriggerEn         (DbgTriggerEn),
    .DbgHwBreakNum        (DbgHwBreakNum),
    .WritebackStage       (WritebackStage),
    .ResetAll             (ResetAll),
    .RndCnstLfsrSeed      (RndCnstLfsrSeed),
    .RndCnstLfsrPerm      (RndCnstLfsrPerm),
    .SecureIbex           (SecureIbex),
    .DummyInstructions    (DummyInstructions),
    .RegFileECC           (RegFileECC),
    .RegFileDataWidth     (RegFileDataWidth),
    .RegFileCapEccWidth   (REGCAP_W),
    .MemECC               (MemECC),
    .MemDataWidth         (MemDataWidth),
    .DmBaseAddr           (DmBaseAddr),
    .DmAddrMask           (DmAddrMask),
    .DmHaltAddr           (DmHaltAddr),
    .DmExceptionAddr      (DmExceptionAddr),
    .CsrMvendorId         (CsrMvendorId),
    .CsrMimpId            (CsrMimpId),
    .BaseIsa              (BaseIsa)
  ) u_ibex_core (
    .clk_i(clk),
    .rst_ni,

    .hart_id_i,
    .boot_addr_i,
    .cheriot_enable_i,

    .instr_req_o,
    .instr_gnt_i,
    .instr_rvalid_i,
    .instr_addr_o,
    .instr_rdata_i(instr_rdata_core),
    .instr_err_i,

    .data_req_o   (trvk_req),
    .data_gnt_i   (trvk_gnt),
    .data_rvalid_i(trvk_rvalid),
    .data_we_o    (trvk_we),
    .data_be_o    (trvk_be),
    .data_addr_o  (trvk_addr),
    .data_wdata_o (data_wdata_core),
    .data_tag_o   (trvk_wtag),
    .data_rdata_i (data_rdata_core),
    .data_tag_i   (trvk_rtag),
    .data_err_i   (trvk_err),

    .dummy_instr_id_o (dummy_instr_id),
    .dummy_instr_wb_o (dummy_instr_wb),
    .rf_raddr_a_o     (rf_raddr_a),
    .rf_raddr_b_o     (rf_raddr_b),
    .rf_waddr_wb_o    (rf_waddr_wb),
    .rf_we_wb_o       (rf_we_wb),
    .rf_wdata_wb_ecc_o(rf_wdata_wb),
    .rf_rdata_a_ecc_i (rf_rdata_a),
    .rf_rdata_b_ecc_i (rf_rdata_b),
    .rf_wcap_ecc_wb_o (rf_wcap),
    .rf_rcap_a_ecc_i  (rf_rcap_a),
    .rf_rcap_b_ecc_i  (rf_rcap_b),

    .ic_tag_req_o      (ic_tag_req),
    .ic_tag_write_o    (ic_tag_write),
    .ic_tag_addr_o     (ic_tag_addr),
    .ic_tag_wdata_o    (ic_tag_wdata),
    .ic_tag_rdata_i    (ic_tag_rdata),
    .ic_data_req_o     (ic_data_req),
    .ic_data_write_o   (ic_data_write),
    .ic_data_addr_o    (ic_data_addr),
    .ic_data_wdata_o   (ic_data_wdata),
    .ic_data_rdata_i   (ic_data_rdata),
    .ic_scr_key_valid_i(scramble_key_valid_q),
    .ic_scr_key_req_o  (ic_scr_key_req),

    .irq_software_i,
    .irq_timer_i,
    .irq_external_i,
    .irq_fast_i,
    .irq_nm_i,
    .irq_pending_o(irq_pending),

    .debug_req_i,
    .crash_dump_o,
    .double_fault_seen_o,

`ifdef RVFI
    .rvfi_valid,
    .rvfi_order,
    .rvfi_insn,
    .rvfi_trap,
    .rvfi_halt,
    .rvfi_intr,
    .rvfi_mode,
    .rvfi_ixl,
    .rvfi_rs1_addr,
    .rvfi_rs2_addr,
    .rvfi_rs3_addr,
    .rvfi_rs1_rdata,
    .rvfi_rs1_rcap,
    .rvfi_rs2_rdata,
    .rvfi_rs2_rcap,
    .rvfi_rs3_rdata,
    .rvfi_rd_addr,
    .rvfi_rd_wdata,
    .rvfi_rd_wcap,
    .rvfi_pc_rdata,
    .rvfi_pc_wdata,
    .rvfi_mem_addr,
    .rvfi_mem_rmask,
    .rvfi_mem_wmask,
    .rvfi_mem_rdata,
    .rvfi_mem_wdata,
    .rvfi_mem_rcap,
    .rvfi_mem_wcap,
    .rvfi_mem_is_cap,
    .rvfi_ext_pre_mip,
    .rvfi_ext_post_mip,
    .rvfi_ext_nmi,
    .rvfi_ext_nmi_int,
    .rvfi_ext_debug_req,
    .rvfi_ext_debug_mode,
    .rvfi_ext_rf_wr_suppress,
    .rvfi_ext_mcycle,
    .rvfi_ext_mhpmcounters,
    .rvfi_ext_mhpmcountersh,
    .rvfi_ext_ic_scr_key_valid,
    .rvfi_ext_irq_valid,
    .rvfi_ext_expanded_insn_valid,
    .rvfi_ext_expanded_insn,
    .rvfi_ext_expanded_insn_last,
`endif

    .fetch_enable_i        (fetch_enable_buf),
    .mcounteren_writable_i (mcounteren_writable_buf),
    .alert_minor_o         (core_alert_minor),
    .alert_major_internal_o(core_alert_major_internal),
    .alert_major_bus_o     (core_alert_major_bus),
    .core_busy_o           (core_busy_d)
  );
```

## Dependency declarations

### rtl/ibex_cs_registers.sv

```verilog
module ibex_cs_registers import ibex_pkg::*, ibex_cheriot_pkg::*; #(
  parameter base_isa_e              BaseIsa                     = BaseIsaRV32I,
  parameter bit                     DbgTriggerEn                = 0,
  parameter int unsigned            DbgHwBreakNum               = 1,
  parameter bit                     DataIndTiming               = 1'b0,
  parameter bit                     DummyInstructions           = 1'b0,
  parameter bit                     ShadowCSR                   = 1'b0,
  parameter bit                     ICache                      = 1'b0,
  parameter int unsigned            MHPMCounterNum              = 10,
  parameter int unsigned            MHPMCounterWidth            = 40,
  parameter bit                     PMPEnable                   = 0,
  parameter int unsigned            PMPGranularity              = 0,
  parameter int unsigned            PMPNumRegions               = 4,
  parameter ibex_pkg::pmp_cfg_t     PMPRstCfg[PMP_MAX_REGIONS]  = ibex_pkg::PmpCfgRst,
  parameter logic [PMP_ADDR_MSB:0]  PMPRstAddr[PMP_MAX_REGIONS] = ibex_pkg::PmpAddrRst,
  parameter ibex_pkg::pmp_mseccfg_t PMPRstMsecCfg               = ibex_pkg::PmpMseccfgRst,
  parameter bit                     RV32E                       = 0,
  parameter ibex_pkg::rv32m_e RV32M                             = ibex_pkg::RV32MFast,
  parameter ibex_pkg::rv32b_e RV32B                             = ibex_pkg::RV32BNone,
  // mvendorid: encoding of manufacturer/provider
  parameter logic [31:0]            CsrMvendorId                = 32'b0,
  // mimpid: encoding of processor implementation version
  parameter logic [31:0]            CsrMimpId                   = 32'b0
) (
  // Clock and Reset
  input  logic                 clk_i,
  input  logic                 rst_ni,

  input  ibex_mubi_t           cheriot_enable_i,
  // Hart ID
  input  logic [31:0]          hart_id_i,

  // Privilege mode
  output ibex_pkg::priv_lvl_e  priv_mode_id_o,
  output ibex_pkg::priv_lvl_e  priv_mode_lsu_o,
  output logic                 csr_mstatus_tw_o,

  // mtvec
  output logic [31:0]          csr_mtvec_o,
  input  logic                 csr_mtvec_init_i,
  input  logic [31:0]          boot_addr_i,

  // Interface to registers (SRAM like)
  input  logic                 csr_access_i,
  input  ibex_pkg::csr_num_e   csr_addr_i,
  input  logic [31:0]          csr_wdata_i,
  input  ibex_pkg::csr_op_e    csr_op_i,
  input  logic                 csr_op_en_i,
  output logic [31:0]          csr_rdata_o,

  input  logic                 cheriot_csr_access_i,
  input  logic [4:0]           cheriot_csr_addr_i,
  input  logic [31:0]          cheriot_csr_wdata_i,
  input  cap_t                 cheriot_csr_wcap_i,
  input  cheriot_csr_op_e      cheriot_csr_op_i,
  input  logic                 cheriot_csr_op_en_i,
  input  logic                 cheriot_csr_set_mie_i,
  input  logic                 cheriot_csr_clr_mie_i,

  output logic [31:0]          cheriot_csr_rdata_o,
  output cap_t                 cheriot_csr_rcap_o,

  // stack highwatermark and fast-clearing function
  output logic [31:0]          csr_mshwm_o,
  output logic [31:0]          csr_mshwmb_o,
  input  logic                 csr_mshwm_set_i,
  input  logic [31:0]          csr_mshwm_new_i,

  // interrupts
  input  logic                 irq_software_i,
  input  logic                 irq_timer_i,
  input  logic                 irq_external_i,
  input  logic [14:0]          irq_fast_i,
  input  logic                 nmi_mode_i,
  output logic                 irq_pending_o,          // interrupt request pending
  output ibex_pkg::irqs_t      irqs_o,                 // interrupt requests qualified with mie
  output logic                 csr_mstatus_mie_o,
  output logic [31:0]          csr_mepc_o,
  output logic [31:0]          csr_mtval_o,

  // PMP
  output ibex_pkg::pmp_cfg_t     csr_pmp_cfg_o  [PMPNumRegions],
  output logic [PMP_ADDR_MSB:0]  csr_pmp_addr_o [PMPNumRegions],
  output ibex_pkg::pmp_mseccfg_t csr_pmp_mseccfg_o,

  // debug
  input  logic                 debug_mode_i,
  input  logic                 debug_mode_entering_i,
  input  ibex_pkg::dbg_cause_e debug_cause_i,
  input  logic                 debug_csr_save_i,
  output logic [31:0]          csr_depc_o,
  output logic                 debug_single_step_o,
  output logic                 debug_ebreakm_o,
  output logic                 debug_ebreaku_o,
  output logic                 trigger_match_o,

  input  logic [31:0]          pc_if_i,
  input  logic [31:0]          pc_id_i,
  input  logic [31:0]          pc_wb_i,

  // CPU control and status bits
  output logic                 data_ind_timing_o,
  output logic                 dummy_instr_en_o,
  output logic [2:0]           dummy_instr_mask_o,
  output logic                 dummy_instr_seed_en_o,
  output logic [31:0]          dummy_instr_seed_o,
  output logic                 icache_enable_o,
  output logic                 csr_shadow_err_o,
  input  logic                 ic_scr_key_valid_i,
  input  ibex_mubi_t           mcounteren_writable_i,

  // Exception save/restore
  input  logic                 csr_save_if_i,
  input  logic                 csr_save_id_i,
  input  logic                 csr_save_wb_i,
  input  logic                 csr_restore_mret_i,
  input  logic                 csr_restore_dret_i,
  input  logic                 csr_save_cause_i,
  input  logic                 csr_mepcc_clrtag_i,
  input  ibex_pkg::exc_cause_t csr_mcause_i,
  input  logic [31:0]          csr_mtval_i,
  output logic                 illegal_csr_insn_o,     // access to non-existent CSR,
                                                        // with wrong privilege level, or
                                                        // missing write permissions
  output logic                 double_fault_seen_o,
  // Performance Counters
  input  logic                 instr_ret_i,                 // instr retired in ID/EX stage
  input  logic                 instr_ret_compressed_i,      // compressed instr retired
  input  logic                 instr_ret_spec_i,            // speculative instr_ret_i
  input  logic                 instr_ret_compressed_spec_i, // speculative instr_ret_compressed_i
  input  logic                 iside_wait_i,                // core waiting for the iside
  input  logic                 jump_i,                      // jump instr seen (j, jr, jal, jalr)
  input  logic                 branch_i,                    // branch instr seen (bf, bnf)
  input  logic                 branch_taken_i,              // branch was taken
  input  logic                 mem_load_i,                  // load from memory in this cycle
  input  logic                 mem_store_i,                 // store to memory in this cycle
  input  logic                 dside_wait_i,                // core waiting for the dside
  input  logic                 mul_wait_i,                  // core waiting for multiply
  input  logic                 div_wait_i,                   // core waiting for divide

  input  logic                 cheriot_branch_req_i,
  input  logic [31:0]          cheriot_branch_target_i,
  input  decoded_cap_t         pcc_cap_i,
  output decoded_cap_t         pcc_cap_o,

  output logic                 csr_dbg_tclr_fault_o,
  output logic                 cheriot_fatal_err_o
);
```

### rtl/ibex_ex_block.sv

```verilog
module ibex_ex_block #(
  parameter ibex_pkg::rv32m_e RV32M           = ibex_pkg::RV32MFast,
  parameter ibex_pkg::rv32b_e RV32B           = ibex_pkg::RV32BNone,
  parameter bit               BranchTargetALU = 0
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,

  // ALU
  input  ibex_pkg::alu_op_e     alu_operator_i,
  input  logic [31:0]           alu_operand_a_i,
  input  logic [31:0]           alu_operand_b_i,
  input  logic                  alu_instr_first_cycle_i,

  // Branch Target ALU
  // All of these signals are unused when BranchTargetALU == 0
  input  logic [31:0]           bt_a_operand_i,
  input  logic [31:0]           bt_b_operand_i,

  // Multiplier/Divider
  input  ibex_pkg::md_op_e      multdiv_operator_i,
  input  logic                  mult_en_i,             // dynamic enable signal, for FSM control
  input  logic                  div_en_i,              // dynamic enable signal, for FSM control
  input  logic                  mult_sel_i,            // static decoder output, for data muxes
  input  logic                  div_sel_i,             // static decoder output, for data muxes
  input  logic  [1:0]           multdiv_signed_mode_i,
  input  logic [31:0]           multdiv_operand_a_i,
  input  logic [31:0]           multdiv_operand_b_i,
  input  logic                  multdiv_ready_id_i,
  input  logic                  data_ind_timing_i,

  // intermediate val reg
  output logic [1:0]            imd_val_we_o,
  output logic [33:0]           imd_val_d_o[2],
  input  logic [33:0]           imd_val_q_i[2],

  // Outputs
  output logic [31:0]           alu_adder_result_ex_o, // to LSU
  output logic [31:0]           result_ex_o,
  output logic [31:0]           branch_target_o,       // to IF
  output logic                  branch_decision_o,     // to ID

  output logic                  ex_valid_o             // EX has valid output
);
```

### rtl/ibex_id_stage.sv

```verilog
module ibex_id_stage import ibex_cheriot_pkg::*; #(
  parameter bit               RV32E           = 0,
  parameter ibex_pkg::rv32m_e RV32M           = ibex_pkg::RV32MFast,
  parameter ibex_pkg::rv32b_e RV32B           = ibex_pkg::RV32BNone,
  parameter bit               DataIndTiming   = 1'b0,
  parameter bit               BranchTargetALU = 0,
  parameter bit               WritebackStage  = 0,
  parameter bit               BranchPredictor = 0,
  parameter bit               MemECC          = 1'b0,
  parameter ibex_pkg::base_isa_e BaseIsa      = ibex_pkg::BaseIsaRV32IorCHERIoT
) (
  input  logic                      clk_i,
  input  logic                      rst_ni,

  input  ibex_pkg::ibex_mubi_t      cheriot_enable_i,
  output logic                      ctrl_busy_o,
  output logic                      illegal_insn_o,

  // Interface to IF stage
  input  logic                      instr_valid_i,
  input  logic [31:0]               instr_rdata_i,         // from IF-ID pipeline registers
  input  logic [31:0]               instr_rdata_alu_i,     // from IF-ID pipeline registers
  input  logic [15:0]               instr_rdata_c_i,       // from IF-ID pipeline registers
  input  logic                      instr_is_compressed_i,
  input  ibex_pkg::instr_exp_e      instr_gets_expanded_i,
  input  logic                      instr_bp_taken_i,
  output logic                      instr_req_o,
  output logic                      instr_first_cycle_id_o,
  output logic                      instr_valid_clear_o,   // kill instr in IF-ID reg
  output logic                      id_in_ready_o,         // ID stage is ready for next instr
  input  logic                      instr_exec_i,
  output logic                      icache_inval_o,

  // Jumps and branches
  input  logic                      branch_decision_i,

  // IF and ID stage signals
  output logic                      pc_set_o,
  output ibex_pkg::pc_sel_e         pc_mux_o,
  output logic                      nt_branch_mispredict_o,
  output logic [31:0]               nt_branch_addr_o,
  output ibex_pkg::exc_pc_sel_e     exc_pc_mux_o,
  output ibex_pkg::exc_cause_t      exc_cause_o,

  input  logic                      illegal_c_insn_i,
  input  logic                      instr_fetch_err_i,
  input  logic                      instr_fetch_err_plus2_i,
  input  logic                      instr_fetch_cheriot_acc_vio_i,
  input  logic                      instr_fetch_cheriot_bound_vio_i,

  input  logic [31:0]               pc_id_i,

  // Stalls
  input  logic                      ex_valid_i,       // EX stage has valid output
  input  logic                      lsu_resp_valid_i, // LSU has valid output, or is done
  // ALU
  output ibex_pkg::alu_op_e         alu_operator_ex_o,
  output logic [31:0]               alu_operand_a_ex_o,
  output logic [31:0]               alu_operand_b_ex_o,

  // Multicycle Operation Stage Register
  input  logic [1:0]                imd_val_we_ex_i,
  input  logic [33:0]               imd_val_d_ex_i[2],
  output logic [33:0]               imd_val_q_ex_o[2],

  // Branch target ALU
  output logic [31:0]               bt_a_operand_o,
  output logic [31:0]               bt_b_operand_o,

  // MUL, DIV
  output logic                      mult_en_ex_o,
  output logic                      div_en_ex_o,
  output logic                      mult_sel_ex_o,
  output logic                      div_sel_ex_o,
  output ibex_pkg::md_op_e          multdiv_operator_ex_o,
  output logic  [1:0]               multdiv_signed_mode_ex_o,
  output logic [31:0]               multdiv_operand_a_ex_o,
  output logic [31:0]               multdiv_operand_b_ex_o,
  output logic                      multdiv_ready_id_o,

  // CSR
  output logic                      csr_access_o,
  output ibex_pkg::csr_op_e         csr_op_o,
  output ibex_pkg::csr_num_e        csr_addr_o,
  output logic                      csr_op_en_o,
  output logic                      csr_save_if_o,
  output logic                      csr_save_id_o,
  output logic                      csr_save_wb_o,
  output logic                      csr_restore_mret_id_o,
  output logic                      csr_restore_dret_id_o,
  output logic                      csr_save_cause_o,
  output logic                      csr_mepcc_clrtag_o,
  output logic [31:0]               csr_mtval_o,
  input  ibex_pkg::priv_lvl_e       priv_mode_i,
  input  logic                      csr_mstatus_tw_i,
  input  logic                      illegal_csr_insn_i,
  input  logic                      data_ind_timing_i,
  input  logic                      csr_pcc_perm_sr_i,

  // Interface to load store unit
  output logic                      lsu_req_o,
  output logic                      lsu_we_o,
  output logic [1:0]                lsu_type_o,
  output logic                      lsu_sign_ext_o,
  output logic [31:0]               lsu_wdata_o,

  input  logic                      lsu_req_done_i, // Data req to LSU is complete and
                                                    // instruction can move to writeback
                                                    // (only relevant where writeback stage is
                                                    // present)

  input  logic                      lsu_addr_incr_req_i,
  input  logic [31:0]               lsu_addr_last_i,

  // Interrupt signals
  input  logic                      csr_mstatus_mie_i,
  input  logic                      irq_pending_i,
  input  ibex_pkg::irqs_t           irqs_i,
  input  logic                      irq_nm_i,
  output logic                      nmi_mode_o,

  input  logic                      lsu_load_err_i,
  input  logic                      lsu_load_resp_intg_err_i,
  input  logic                      lsu_store_err_i,
  input  logic                      lsu_store_resp_intg_err_i,
  input  logic                      lsu_err_is_cheriot_i,

  output logic                      expecting_load_resp_o,
  output logic                      expecting_store_resp_o,

  // Debug Signal
  output logic                      debug_mode_o,
  output logic                      debug_mode_entering_o,
  output ibex_pkg::dbg_cause_e      debug_cause_o,
  output logic                      debug_csr_save_o,
  input  logic                      debug_req_i,
  input  logic                      debug_single_step_i,
  input  logic                      debug_ebreakm_i,
  input  logic                      debug_ebreaku_i,
  input  logic                      trigger_match_i,

  // Write back signal
  input  logic [31:0]               result_ex_i,
  input  logic [31:0]               csr_rdata_i,

  // Register file read
  output logic [4:0]                rf_raddr_a_o,
  input  logic [31:0]               rf_rdata_a_i,
  output logic [4:0]                rf_raddr_b_o,
  input  logic [31:0]               rf_rdata_b_i,
  output logic                      rf_ren_a_o,
  output logic                      rf_ren_b_o,

  // Register file write (via writeback)
  output logic [4:0]                rf_waddr_id_o,
  output logic [31:0]               rf_wdata_id_o,
  output logic                      rf_we_id_o,
  output logic                      rf_rd_a_wb_match_o,
  output logic                      rf_rd_b_wb_match_o,

  // Register write information from writeback (for resolving data hazards)
  input  logic [4:0]                rf_waddr_wb_i,
  input  logic [31:0]               rf_wdata_fwd_wb_i,
  input  logic                      rf_write_wb_i,

  output  logic                     en_wb_o,
  output  ibex_pkg::wb_instr_type_e instr_type_wb_o,
  output  logic                     instr_perf_count_id_o,
  input logic                       ready_wb_i,
  input logic                       outstanding_load_wb_i,
  input logic                       outstanding_store_wb_i,

  // Performance Counters
  output logic                      perf_jump_o,    // executing a jump instr
  output logic                      perf_branch_o,  // executing a branch instr
  output logic                      perf_tbranch_o, // executing a taken branch instr
  output logic                      perf_dside_wait_o, // instruction in ID/EX is awaiting memory
                                                        // access to finish before proceeding
  output logic                      perf_mul_wait_o,
  output logic                      perf_div_wait_o,
  output logic                      instr_id_done_o,

  // cheriot signals
  output logic                      cheriot_exec_id_o,
  output logic                      instr_is_cheriot_id_o,
  output logic                      instr_is_rv32lsu_id_o,
  output logic [11:0]               cheriot_imm12_o,
  output logic [19:0]               cheriot_imm20_o,
  output logic [20:0]               cheriot_imm21_o,
  output cheriot_op_t               cheriot_operator_o,
  output logic  [4:0]               cheriot_cs2_dec_o,
  output cheriot_cap_field_e        cheriot_cap_field_sel_o,
  output cheriot_adder_a_sel_e      cheriot_adder_a_sel_o,
  output cheriot_adder_b_sel_e      cheriot_adder_b_sel_o,
  output cheriot_setaddr_sel_e      cheriot_setaddr_sel_o,
  output cheriot_setbounds_sel_e    cheriot_setbounds_sel_o,
  output logic                      cheriot_load_o,
  output logic                      cheriot_store_o,

  input  logic                      cheriot_ex_valid_i,
  input  logic                      cheriot_ex_err_i,
  input  logic [11:0]               cheriot_ex_err_info_i,
  input  logic                      cheriot_wb_err_i,
  input  logic [15:0]               cheriot_wb_err_info_i,
  input  logic                      cheriot_branch_req_i,   // from cheriot EX
  input  logic [31:0]               cheriot_branch_target_i
);
```

### rtl/ibex_if_stage.sv

```verilog
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

### rtl/ibex_load_store_unit.sv

```verilog
module ibex_load_store_unit import ibex_pkg::*; import ibex_cheriot_pkg::*; #(
  parameter base_isa_e   BaseIsa      = BaseIsaRV32I,
  parameter bit          MemECC       = 1'b0,
  parameter int unsigned MemDataWidth = MemECC ? 32 + 7 : 32
) (
  input  logic         clk_i,
  input  logic         rst_ni,
  input  ibex_mubi_t   cheriot_enable_i,

  // data interface
  output logic         data_req_o,
  input  logic         data_gnt_i,
  input  logic         data_rvalid_i,
  input  logic         data_bus_err_i,
  input  logic         data_pmp_err_i,

  output logic [31:0]             data_addr_o,
  output logic                    data_we_o,
  output logic [3:0]              data_be_o,
  output logic [MemDataWidth-1:0] data_wdata_o,
  output logic                    data_tag_o,
  input  logic [MemDataWidth-1:0] data_rdata_i,
  input  logic                    data_tag_i,

  // signals to/from ID/EX stage
  input  logic         lsu_we_i,             // write enable                     -> from ID/EX
  input  logic         lsu_is_cap_i,         // capability load/store            -> from ID/EX
  input  logic         lsu_cheriot_err_i,    // CHERIoT access error               -> from ID/EX
  input  logic [1:0]   lsu_type_i,           // data type: word, half word, byte -> from ID/EX
  input  logic [31:0]  lsu_wdata_i,          // data to write to memory          -> from ID/EX
  input  cap_t         lsu_wcap_i,           // capability to write to memory    -> from ID/EX
  input  cap_clrperm_t lsu_lc_clrperm_i,     // cap load clear permissions       -> from ID/EX
  input  logic         lsu_sign_ext_i,       // sign extension                   -> from ID/EX

  output cap_t         lsu_rcap_o,           // capability read from memory      -> to ID/EX
  output logic [31:0]  lsu_rdata_o,          // requested data                   -> to ID/EX
  output logic         lsu_rdata_valid_o,
  input  logic         lsu_req_i,            // data request                     -> from ID/EX

  input  logic [31:0]  adder_result_ex_i,    // address computed in ALU          -> from ID/EX

  output logic         addr_incr_req_o,      // request address increment for
                                             // misaligned accesses              -> to ID/EX
  output logic [31:0]  addr_last_o,          // address of last transaction      -> to controller
                                             // -> mtval
                                             // -> AGU for misaligned accesses

  output logic         lsu_req_done_o,       // Signals that data request is complete
                                             // (only need to await final data
                                             // response)                        -> to ID/EX

  output logic         lsu_resp_valid_o,     // LSU has response from transaction -> to ID/EX & WB

  // exception signals
  output logic         load_err_o,
  output logic         load_resp_intg_err_o,
  output logic         store_err_o,
  output logic         store_resp_intg_err_o,
  output logic         lsu_err_is_cheriot_o,

  output logic         busy_o,

  output logic         perf_load_o,
  output logic         perf_store_o
);
```

### rtl/ibex_wb_stage.sv

```verilog
module ibex_wb_stage import ibex_cheriot_pkg::*; #(
  parameter bit ResetAll          = 1'b0,
  parameter bit WritebackStage    = 1'b0,
  parameter bit DummyInstructions = 1'b0
) (
  input  logic                     clk_i,
  input  logic                     rst_ni,

  input  logic                     en_wb_i,
  input  ibex_pkg::wb_instr_type_e instr_type_wb_i,
  input  logic [31:0]              pc_id_i,
  input  logic                     instr_is_compressed_id_i,
  input  logic                     instr_perf_count_id_i,
  input  logic                     instr_is_cheriot_i,
  input  logic                     cheriot_load_i,
  input  logic                     cheriot_store_i,

  output logic                     ready_wb_o,
  output logic                     rf_write_wb_o,
  output logic                     outstanding_load_wb_o,
  output logic                     outstanding_store_wb_o,
  output logic [31:0]              pc_wb_o,
  output logic                     perf_instr_ret_wb_o,
  output logic                     perf_instr_ret_compressed_wb_o,
  output logic                     perf_instr_ret_wb_spec_o,
  output logic                     perf_instr_ret_compressed_wb_spec_o,

  input  logic [4:0]               rf_waddr_id_i,
  input  logic [31:0]              rf_wdata_id_i,
  input  logic                     rf_we_id_i,

  input  logic                     cheriot_rf_we_i,
  input  logic [31:0]              cheriot_rf_wdata_i,
  input  cap_t                     cheriot_rf_wcap_i,

  input  logic                     dummy_instr_id_i,

  input  logic [31:0]              rf_wdata_lsu_i,
  input  cap_t                     rf_wcap_lsu_i,
  input  logic                     rf_we_lsu_i,

  output logic [31:0]              rf_wdata_fwd_wb_o,
  output cap_t                     rf_wcap_fwd_wb_o,

  output logic [4:0]               rf_waddr_wb_o,
  output logic [31:0]              rf_wdata_wb_o,
  output cap_t                     rf_wcap_wb_o,
  output logic                     rf_we_wb_o,

  output logic                     dummy_instr_wb_o,

  input logic                      lsu_resp_valid_i,
  input logic                      lsu_resp_err_i,

  output logic                     instr_done_wb_o
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

## Related source code

### dv/verilator/simple_system_cosim/ibex_simple_system_cosim_checker.sv

```verilog
  always @(posedge clk_i) begin
    if (u_top.rvfi_valid) begin
      riscv_cosim_set_nmi(cosim_handle, u_top.rvfi_ext_nmi);
      riscv_cosim_set_nmi_int(cosim_handle, u_top.rvfi_ext_nmi_int);
      riscv_cosim_set_mip(cosim_handle, u_top.rvfi_ext_pre_mip, u_top.rvfi_ext_post_mip);
      riscv_cosim_set_debug_req(cosim_handle, u_top.rvfi_ext_debug_req);
      riscv_cosim_set_mcycle(cosim_handle, u_top.rvfi_ext_mcycle);
      for (int i=0; i < 10; i++) begin
        riscv_cosim_set_csr(cosim_handle, int'(CSR_MHPMCOUNTER3) + i,
          u_top.rvfi_ext_mhpmcounters[i]);
        riscv_cosim_set_csr(cosim_handle, int'(CSR_MHPMCOUNTER3H) + i,
          u_top.rvfi_ext_mhpmcountersh[i]);
      end
      riscv_cosim_set_ic_scr_key_valid(cosim_handle, u_top.rvfi_ext_ic_scr_key_valid);

      if (riscv_cosim_step(cosim_handle, u_top.rvfi_rd_addr, u_top.rvfi_rd_wdata,
                           u_top.rvfi_pc_rdata, u_top.rvfi_trap,
                           u_top.rvfi_ext_rf_wr_suppress) == 0)
      begin
        $display("FAILURE: Co-simulation mismatch at time %t", $time());
        for (int i = 0;i < riscv_cosim_get_num_errors(cosim_handle); ++i) begin
          $display(riscv_cosim_get_error(cosim_handle, i));
        end
        riscv_cosim_clear_errors(cosim_handle);

        $fatal(1, "Co-simulation mismatch seen");
      end
    end
  end

  logic outstanding_store;
  logic [31:0] outstanding_addr;
  logic [3:0] outstanding_be;
  logic [31:0] outstanding_store_data;
  logic outstanding_misaligned_first;
  logic outstanding_misaligned_second;
  logic outstanding_misaligned_first_saw_error;
  logic outstanding_m_mode_access;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      outstanding_store <= 1'b0;
    end else begin
      if (host_dmem_req && host_dmem_gnt) begin
        outstanding_store      <= host_dmem_we;
        outstanding_addr       <= host_dmem_addr;
        outstanding_be         <= host_dmem_be;
        outstanding_store_data <= host_dmem_wdata;
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
      end

      if (host_dmem_rvalid) begin
        riscv_cosim_notify_dside_access(cosim_handle, outstanding_store, outstanding_addr,
          outstanding_store ? outstanding_store_data : host_dmem_rdata, outstanding_be,
          host_dmem_err, outstanding_misaligned_first, outstanding_misaligned_second,
          outstanding_misaligned_first_saw_error, outstanding_m_mode_access);
      end
    end
  end
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

### doc/03_reference/rvfi.rst

```text
.. _rvfi:

RISC-V Formal Interface
=======================

Ibex supports the `RISC-V Formal Interface (RVFI) <https://github.com/SymbioticEDA/riscv-formal/blob/master/docs/rvfi.md>`_.
This interface basically decodes the current instruction and provides additional insight into the core state thereby enabling formal verification.
Examples of such information include opcode, source and destination registers, program counter, as well as address and data for memory operations.


Formal Verification
-------------------

The signals provided by RVFI can be used to formally verify compliance of Ibex with the `RISC-V specification <https://riscv.org/specifications/>`_.

Currently, the implementation is restricted to support the "I" and "C" extensions, and Ibex is not yet formally verified.
It predecessor "Zero-riscy" had been tested, but this required changes to the core as well as to the tool used in the process (`yosys <https://github.com/YosysHQ/yosys>`_).
The formal verification of the Ibex core is work in progress.
```

### doc/03_reference/cosim.rst

```text
.. _cosim:

Co-simulation System
====================

Overview
--------

A co-simulation system is provided that can run in either the Ibex UVM DV environment or with Simple System.
This system runs a RISC-V ISS (currently only Spike is supported) in lockstep with an Ibex core.
All instructions executed by Ibex and memory transactions generated are checked against the behaviour of the ISS.
This system supports memory errors, interrupt and debug requests which are observed in the RTL simulation and forwarded to the ISS so the ISS and RTL remain in sync.
The system uses a generic interface to allow support of multiple ISSes.
Only VCS is supported as a simulator, though no VCS specific functionality is required so adding support for another simulator should be straight-forward.

To run the co-simulation system, a particular version of Spike is required (see the Setup and Usage section, below).

The RISC-V Formal Interface (RVFI) is used to provide information about retired instructions and instructions that produce synchronous traps for checking.
The RVFI has been extended to provide interrupt and debug information and the value of various CSRs that are harder to model (e.g. ``mcycle``).
These extended signals have the prefix ``rvfi_ext``

...

Co-simulation details
----------------------

The co-simulation system uses DPI calls to link the DV and ISS sides together.
A C++ interface is defined in ``dv/cosim/cosim.h`` with a DPI wrapper provided by ``dv/cosim/cosim_dpi.cc`` and ``dv/cosim/cosim_dpi.h``.
A ``chandle``, which points to some class instance that implements the interface, must be provided by the DV environment.
All the co-simulation DPI calls take this ``chandle`` as a first argument.

The details below discuss the C++ interface.
The DPI version of the interface is almost identical, with all functions prefaced with ``riscv_cosim`` and taking a ``chandle`` of the co-simulation instance to use.

The core function of the co-simulation interface is the ``step`` function:

.. code-block:: c++

  virtual bool step(uint32_t write_reg, uint32_t write_reg_data, uint32_t pc, bool sync_trap);

``step`` takes arguments giving the PC of the most recently retired or synchronously trapping instruction in the DUT along with details of any register write that occurred.

Where ``step`` is provided with a retired (successfully executed) instruction it steps the ISS by one instruction and checks it executed the same instruction, with the same register write result, as the DUT.

When ``step`` is provided with an instruction that produces a synchronous trap, it checks the ISS also traps on the same instruction but does not step to the next executed instruction.
That instruction will be the first instruction of the trap handler and will be checked/stepped by the next call to ``step`` when it retires from the DUT.

Any data memory accesses that the ISS produces during the ``step`` are checked against observed DUT memory accesses.

``step`` returns false if any checks have failed.
If any errors occur during the step they can be accessed via ``get_errors`` which returns a vector of error messages.
For the DPI interface errors are accessed using ``riscv_cosim_get_num_errors`` and ``riscv_cosim_get_error``.
When errors have been checked they can be cleared with ``clear_errors``.

Trap Handling
^^^^^^^^^^^^^

Traps are separated into two categories, synchronous and asynchronous.
Synchronous traps are caused by a particular instruction's execution (e.g. an illegal instruction).
Asynchronous traps are caused by external interrupts.
Note that in Ibex error responses to both loads and store produce a synchronous trap so the co-simulation system has the same behaviour.

A synchronous trap is associated with a particular instruction and prevents that instruction from completing its execution.
That instruction doesn't retire, but is still made visible on the RVFI.
The ``rvfi_trap`` signal is asserted for an instruction that causes a synchronous trap.
As described above ``step`` should be called for any instruction that causes a synchronous trap to check the trap is also seen by the ISS.

An asynchronous trap can be seen as occurring between instructions and as such doesn't have an associated instruction, nothing will be seen on RVFI with ``rvfi_trap`` set.
The co-simulation system will immediately take any pending asynchronous trap when ``step`` is called, expecting the instruction checked with ``step`` to be the first instruction of the trap handler.

While a debug request is not strictly an asynchronous trap (it doesn't use the same exception handling mechanism), they work identically to asynchronous traps for the co-simulation system.
When a debug request is pending when ``step`` is called the co-simulation will expect the instruction checked by ``step`` to be the first instruction of the debug handler.

Interrupts and Debug Requests
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The DV environment must observe any incoming interrupts and debug requests generated by the testbench and notify the co-simulation system of them using ``set_mip``, ``set_debug_req`` and ``set_nmi``.
An interrupt or debug request will take immediate effect at the next ``step`` (if architecturally required to do so).
The DV environment is responsible for determining when to call ``set_mip``, ``set_debug_req`` and ``set_nmi`` to ensure a RTL and co-simulation match.

The state of the incoming interrupts and debug request is sampled when an instruction moves from IF to ID/EX.
The sampled state is tracked with the rest of the RVFI pipeline and used to call ``set_mip``, ``set_debug_req`` and ``set_nmi`` when the instruction is output by the RVFI.

A complication occurs when more than one interrupt or debug requests occur between individual instruction fetches.
One interrupt or debug request may take priority over another when they all occur together but when they occur in time is important as well.
If interrupt and debug request notification is associated exclusively with retired instructions the co-simulation system cannot correctly prioritise multiple interrupts and debug requests.
To deal with this the RVFI can also signal an interrupt event not associated with an instruction by setting ``rvfi_ext_irq_valid`` without setting ``rvfi_valid``.
When this is set the interrupt related RVFI signals are valid and provide the interrupt state.
The RVFI is used in this way, as opposed to a separate notification interface, so the interrupt notifications are ordered relative to the retired instructions.

See the comments in :file:`rtl/ibex_core.sv`, around the ``new_debug_req``, ``new_nmi``, ``new_irq`` and ``rvfi_irq_valid`` signals for further details.
```
