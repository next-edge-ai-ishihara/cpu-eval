# Implement `ibex_id_stage`

Implement the complete `ibex_id_stage` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_id_stage` definition in a single SystemVerilog code block, with no text outside the block.

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
  // -----------------------------------------------------------------------------------------------
  // CHERIoT Decoding and ALU constants
  // -----------------------------------------------------------------------------------------------

  // CHERIoT Operator
  typedef struct packed {
    logic CSET_BOUNDS_RNDN; // CSetBoundsRoundDown
    logic CRAM;             // CRepresentableAlignmentMask
    logic CRRL;             // CRepresentableLength
    logic CAUICGP;          // AUICGP
    logic CAUIPCC;          // AUIPCC
    logic CJAL;             // JAL
    logic CJALR;            // JALR
    logic CCSR_RW;          // CSpecialRW
    logic CSTORE_CAP;       // CSC
    logic CSET_HIGH;        // CSetHigh
    logic CLOAD_CAP;        // CLC
    logic CCLEAR_TAG;       // CClearTag
    logic CSUB_CAP;         // CSub
    logic CMOVE_CAP;        // CMove
    logic CIS_EQUAL;        // CIsEqual
    logic CIS_SUBSET;       // CTestSubset
    logic CSET_BOUNDS_IMM;  // CSetBoundsImm
    logic CSET_BOUNDS_EX;   // CSetBoundsExact
    logic CSET_BOUNDS;      // CSetBounds
    logic CINC_ADDR_IMM;    // CIncAddrImm
    logic CINC_ADDR;        // CIncAddr
    logic CSET_ADDR;        // CSetAddr
    logic CAND_PERM;        // CAndPerm
    logic CUNSEAL;          // CUnseal
    logic CSEAL;            // CSeal
    logic CGET_FIELD;       // CGetPerm/Type/Base/Len/Tag/Addr/High/Top
  } cheriot_op_t;

  typedef enum logic [2:0] {
    CFIELD_PERM = 3'h0,
    CFIELD_TYPE = 3'h1,
    CFIELD_BASE = 3'h2,
    CFIELD_LEN  = 3'h3,
    CFIELD_TAG  = 3'h4,
    CFIELD_ADDR = 3'h5,
    CFIELD_HIGH = 3'h6,
    CFIELD_TOP  = 3'h7
  } cheriot_cap_field_e;

  typedef enum logic [2:0] {
    CHERIOT_ADDER_A_ZERO  = 3'h0,
    CHERIOT_ADDER_A_IMM12 = 3'h1,
    CHERIOT_ADDER_A_IMM21 = 3'h2,
    CHERIOT_ADDER_A_IMM20 = 3'h3,
    CHERIOT_ADDER_A_RS2   = 3'h4
  } cheriot_adder_a_sel_e;

  typedef enum logic [1:0] {
    CHERIOT_ADDER_B_ZERO = 2'h0,
    CHERIOT_ADDER_B_RS1  = 2'h1,
    CHERIOT_ADDER_B_PC   = 2'h2
  } cheriot_adder_b_sel_e;

  typedef enum logic [2:0] {
    SETADDR_NONE      = 3'h0,  // default: null cap, zero addr
    SETADDR_PCC_PCNXT = 3'h1,  // CJAL/CJALR: pcc cap, pc_id_nxt addr
    SETADDR_PCC_ARITH = 3'h2,  // CAUIPCC: pcc cap, addr_result
    SETADDR_RFA_ARITH = 3'h3,  // CSET_ADDR/CINC_ADDR/CINC_ADDR_IMM/CAUICGP: rf_a cap, addr_result
    SETADDR_SCR       = 3'h4   // CCSR_RW: rf_a cap, csr_wdata (only when scr_legalization=1)
  } cheriot_setaddr_sel_e;

  typedef enum logic [2:0] {
    SETBOUNDS_NONE   = 3'h0,  // default
    SETBOUNDS_RS2    = 3'h1,  // CSET_BOUNDS: newlen=rs2, not exact, cap from rs1
    SETBOUNDS_RNDN   = 3'h2,  // CSET_BOUNDS_RNDN: newlen=rs2, not exact, cap from rs1 (rounded)
    SETBOUNDS_RS2_EX = 3'h3,  // CSET_BOUNDS_EX: newlen=rs2, exact, cap from rs1
    SETBOUNDS_IMM    = 3'h4,  // CSET_BOUNDS_IMM: newlen=imm12, not exact, cap from rs1
    SETBOUNDS_CRRL   = 3'h5,  // CRRL: newlen=rs1, null cap, result=rlen
    SETBOUNDS_CRAM   = 3'h6   // CRAM: newlen=rs1, null cap, result=maska
  } cheriot_setbounds_sel_e;

  typedef enum logic [4:0] {
    CHERIOT_CSR_NULL,
    CHERIOT_CSR_RW
  } cheriot_csr_op_e;
```

## Module declaration

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

  import ibex_pkg::*;
```

## Parent instantiation

### rtl/ibex_core.sv

```verilog
  ibex_id_stage #(
    .RV32E          (RV32E),
    .RV32M          (RV32M),
    .RV32B          (RV32B),
    .BranchTargetALU(BranchTargetALU),
    .DataIndTiming  (DataIndTiming),
    .WritebackStage (WritebackStage),
    .BranchPredictor(BranchPredictor),
    .MemECC         (MemECC),
    .BaseIsa        (BaseIsa)
  ) id_stage_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    .cheriot_enable_i     (cheriot_enable_i),

    // Processor Enable
    .ctrl_busy_o   (ctrl_busy),
    .illegal_insn_o(illegal_insn_id),

    // from/to IF-ID pipeline register
    .instr_valid_i        (instr_valid_id),
    .instr_rdata_i        (instr_rdata_id),
    .instr_rdata_alu_i    (instr_rdata_alu_id),
    .instr_rdata_c_i      (instr_rdata_c_id),
    .instr_is_compressed_i(instr_is_compressed_id),
    .instr_gets_expanded_i(instr_gets_expanded_id),
    .instr_bp_taken_i     (instr_bp_taken_id),

    // Jumps and branches
    .branch_decision_i(branch_decision),

    // IF and ID control signals
    .instr_first_cycle_id_o(instr_first_cycle_id),
    .instr_valid_clear_o   (instr_valid_clear),
    .id_in_ready_o         (id_in_ready),
    .instr_exec_i          (instr_exec),
    .instr_req_o           (instr_req_int),
    .pc_set_o              (pc_set),
    .pc_mux_o              (pc_mux_id),
    .nt_branch_mispredict_o(nt_branch_mispredict),
    .nt_branch_addr_o      (nt_branch_addr),
    .exc_pc_mux_o          (exc_pc_mux_id),
    .exc_cause_o           (exc_cause),
    .icache_inval_o        (icache_inval),

    .instr_fetch_err_i               (instr_fetch_err),
    .instr_fetch_err_plus2_i         (instr_fetch_err_plus2),
    .instr_fetch_cheriot_acc_vio_i   (instr_fetch_cheriot_acc_vio),
    .instr_fetch_cheriot_bound_vio_i (instr_fetch_cheriot_bound_vio),

    .illegal_c_insn_i       (illegal_c_insn_id),

    .pc_id_i(pc_id),

    // Stalls
    .ex_valid_i      (ex_valid),
    .lsu_resp_valid_i(lsu_resp_valid),

    .alu_operator_ex_o (alu_operator_ex),
    .alu_operand_a_ex_o(alu_operand_a_ex),
    .alu_operand_b_ex_o(alu_operand_b_ex),

    .imd_val_q_ex_o (imd_val_q_ex),
    .imd_val_d_ex_i (imd_val_d_ex),
    .imd_val_we_ex_i(imd_val_we_ex),

    .bt_a_operand_o(bt_a_operand),
    .bt_b_operand_o(bt_b_operand),

    .mult_en_ex_o            (mult_en_ex),
    .div_en_ex_o             (div_en_ex),
    .mult_sel_ex_o           (mult_sel_ex),
    .div_sel_ex_o            (div_sel_ex),
    .multdiv_operator_ex_o   (multdiv_operator_ex),
    .multdiv_signed_mode_ex_o(multdiv_signed_mode_ex),
    .multdiv_operand_a_ex_o  (multdiv_operand_a_ex),
    .multdiv_operand_b_ex_o  (multdiv_operand_b_ex),
    .multdiv_ready_id_o      (multdiv_ready_id),

    // CSR ID/EX
    .csr_access_o         (csr_access),
    .csr_op_o             (csr_op),
    .csr_addr_o           (csr_addr),
    .csr_op_en_o          (csr_op_en),
    .csr_save_if_o        (csr_save_if),  // control signal to save PC
    .csr_save_id_o        (csr_save_id),  // control signal to save PC
    .csr_save_wb_o        (csr_save_wb),  // control signal to save PC
    .csr_restore_mret_id_o(csr_restore_mret_id),  // restore mstatus upon MRET
    .csr_restore_dret_id_o(csr_restore_dret_id),  // restore mstatus upon MRET
    .csr_save_cause_o     (csr_save_cause),
    .csr_mepcc_clrtag_o   (csr_mepcc_clrtag),
    .csr_mtval_o          (csr_mtval),
    .priv_mode_i          (priv_mode_id),
    .csr_mstatus_tw_i     (csr_mstatus_tw),
    .illegal_csr_insn_i   (illegal_csr_insn_id),
    .data_ind_timing_i    (data_ind_timing),
    .csr_pcc_perm_sr_i    (pcc_cap_r.perms.SR),

    // LSU
    .lsu_req_o     (rv32_lsu_req),  // to load store unit
    .lsu_we_o      (rv32_lsu_we),  // to load store unit
    .lsu_type_o    (rv32_lsu_type),  // to load store unit
    .lsu_sign_ext_o(rv32_lsu_sign_ext),  // to load store unit
    .lsu_wdata_o   (rv32_lsu_wdata),  // to load store unit
    .lsu_req_done_i(lsu_req_done),  // from load store unit

    .lsu_addr_incr_req_i(rv32_lsu_addr_incr_req),
    .lsu_addr_last_i    (rv32_lsu_addr_last),

    .lsu_load_err_i           (lsu_load_err),
    .lsu_load_resp_intg_err_i (lsu_load_resp_intg_err),
    .lsu_store_err_i          (lsu_store_err),
    .lsu_store_resp_intg_err_i(lsu_store_resp_intg_err),
    .lsu_err_is_cheriot_i     (lsu_err_is_cheriot),

    .expecting_load_resp_o (expecting_load_resp_id),
    .expecting_store_resp_o(expecting_store_resp_id),

    // Interrupt Signals
    .csr_mstatus_mie_i(csr_mstatus_mie),
    .irq_pending_i    (irq_pending_o),
    .irqs_i           (irqs),
    .irq_nm_i         (irq_nm_i),
    .nmi_mode_o       (nmi_mode),

    // Debug Signal
    .debug_mode_o         (debug_mode),
    .debug_mode_entering_o(debug_mode_entering),
    .debug_cause_o        (debug_cause),
    .debug_csr_save_o     (debug_csr_save),
    .debug_req_i          (debug_req_i),
    .debug_single_step_i  (debug_single_step),
    .debug_ebreakm_i      (debug_ebreakm),
    .debug_ebreaku_i      (debug_ebreaku),
    .trigger_match_i      (trigger_match),

    // write data to commit in the register file
    .result_ex_i(result_ex),
    .csr_rdata_i(csr_rdata),

    .rf_raddr_a_o      (rf_raddr_a),
    .rf_rdata_a_i      (rf_rdata_a),
    .rf_raddr_b_o      (rf_raddr_b),
    .rf_rdata_b_i      (rf_rdata_b),
    .rf_ren_a_o        (rf_ren_a),
    .rf_ren_b_o        (rf_ren_b),
    .rf_waddr_id_o     (rf_waddr_id),
    .rf_wdata_id_o     (rf_wdata_id),
    .rf_we_id_o        (rf_we_id),
    .rf_rd_a_wb_match_o(rf_rd_a_wb_match),
    .rf_rd_b_wb_match_o(rf_rd_b_wb_match),

    .rf_waddr_wb_i    (rf_waddr_wb),
    .rf_wdata_fwd_wb_i(rf_wdata_fwd_wb),
    .rf_write_wb_i    (rf_write_wb),

    .en_wb_o               (en_wb),
    .instr_type_wb_o       (instr_type_wb),
    .instr_perf_count_id_o (instr_perf_count_id),
    .ready_wb_i            (ready_wb),
    .outstanding_load_wb_i (outstanding_load_wb),
    .outstanding_store_wb_i(outstanding_store_wb),

    // Performance Counters
    .perf_jump_o      (perf_jump),
    .perf_branch_o    (perf_branch),
    .perf_tbranch_o   (perf_tbranch),
    .perf_dside_wait_o(perf_dside_wait),
    .perf_mul_wait_o  (perf_mul_wait),
    .perf_div_wait_o  (perf_div_wait),
    .instr_id_done_o  (instr_id_done),

    .cheriot_exec_id_o       (cheriot_exec_id),
    .instr_is_cheriot_id_o   (instr_is_cheriot_id),
    .instr_is_rv32lsu_id_o   (instr_is_rv32lsu_id),
    .cheriot_imm12_o         (cheriot_imm12),
    .cheriot_imm20_o         (cheriot_imm20),
    .cheriot_imm21_o         (cheriot_imm21),
    .cheriot_operator_o      (cheriot_operator),
    .cheriot_cs2_dec_o       (cheriot_cs2_dec),
    .cheriot_cap_field_sel_o (cheriot_cap_field_sel),
    .cheriot_adder_a_sel_o   (cheriot_adder_a_sel),
    .cheriot_adder_b_sel_o   (cheriot_adder_b_sel),
    .cheriot_setaddr_sel_o   (cheriot_setaddr_sel),
    .cheriot_setbounds_sel_o (cheriot_setbounds_sel),
    .cheriot_load_o          (cheriot_load_id),
    .cheriot_store_o         (cheriot_store_id),
    .cheriot_ex_valid_i      (cheriot_ex_valid),
    .cheriot_ex_err_i        (cheriot_ex_err),
    .cheriot_ex_err_info_i   (cheriot_ex_err_info),
    .cheriot_wb_err_i        (cheriot_wb_err),
    .cheriot_wb_err_info_i   (cheriot_wb_err_info),
    .cheriot_branch_req_i    (cheriot_branch_req_spec),
    .cheriot_branch_target_i (branch_target_ex_cheriot)
  );
```

## Dependency declarations

### rtl/ibex_controller.sv

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

### rtl/ibex_decoder.sv

```verilog
module ibex_decoder import ibex_cheriot_pkg::*; #(
  parameter bit RV32E               = 0,
  parameter ibex_pkg::rv32m_e RV32M = ibex_pkg::RV32MFast,
  parameter ibex_pkg::rv32b_e RV32B = ibex_pkg::RV32BNone,
  parameter bit BranchTargetALU     = 0,
  parameter ibex_pkg::base_isa_e BaseIsa        = ibex_pkg::BaseIsaRV32IorCHERIoT
) (
  input  logic                 clk_i,
  input  logic                 rst_ni,

  input  ibex_pkg::ibex_mubi_t cheriot_enable_i,

  // to/from controller
  output logic                 illegal_insn_o,        // illegal instr encountered
  output logic                 ebrk_insn_o,           // trap instr encountered
  output logic                 mret_insn_o,           // return from exception instr
                                                      // encountered
  output logic                 dret_insn_o,           // return from debug instr encountered
  output logic                 ecall_insn_o,          // syscall instr encountered
  output logic                 wfi_insn_o,            // wait for interrupt instr encountered
  output logic                 jump_set_o,            // jump taken set signal
  input  logic                 branch_taken_i,        // registered branch decision
  output logic                 icache_inval_o,

  // from IF-ID pipeline register
  input  logic                 instr_first_cycle_i,   // instruction read is in its first cycle
  input  logic [31:0]          instr_rdata_i,         // instruction read from memory/cache
  input  logic [31:0]          instr_rdata_alu_i,     // instruction read from memory/cache
                                                      // replicated to ease fan-out)

  input  logic                 illegal_c_insn_i,      // compressed instruction decode failed

  // immediates
  output ibex_pkg::imm_a_sel_e  imm_a_mux_sel_o,       // immediate selection for operand a
  output ibex_pkg::imm_b_sel_e  imm_b_mux_sel_o,       // immediate selection for operand b
  output ibex_pkg::op_a_sel_e   bt_a_mux_sel_o,        // branch target selection operand a
  output ibex_pkg::imm_b_sel_e  bt_b_mux_sel_o,        // branch target selection operand b
  output logic [31:0]           imm_i_type_o,
  output logic [31:0]           imm_s_type_o,
  output logic [31:0]           imm_b_type_o,
  output logic [31:0]           imm_u_type_o,
  output logic [31:0]           imm_j_type_o,
  output logic [31:0]           zimm_rs1_type_o,

  // register file
  output ibex_pkg::rf_wd_sel_e rf_wdata_sel_o,   // RF write data selection
  output logic                 rf_we_o,          // write enable for regfile
  output logic                 rf_we_or_load_o,
  output logic [4:0]           rf_raddr_a_o,
  output logic [4:0]           rf_raddr_b_o,
  output logic [4:0]           rf_waddr_o,
  output logic                 rf_ren_a_o,          // Instruction reads from RF addr A
  output logic                 rf_ren_b_o,          // Instruction reads from RF addr B

  // ALU
  output ibex_pkg::alu_op_e    alu_operator_o,        // ALU operation selection
  output ibex_pkg::op_a_sel_e  alu_op_a_mux_sel_o,    // operand a selection: reg value, PC,
                                                      // immediate or zero
  output ibex_pkg::op_b_sel_e  alu_op_b_mux_sel_o,    // operand b selection: reg value or
                                                      // immediate
  output logic                 alu_multicycle_o,      // ternary bitmanip instruction

  // MULT & DIV
  output logic                 mult_en_o,             // perform integer multiplication
  output logic                 div_en_o,              // perform integer division or remainder
  output logic                 mult_sel_o,            // as above but static, for data muxes
  output logic                 div_sel_o,             // as above but static, for data muxes

  output ibex_pkg::md_op_e     multdiv_operator_o,
  output logic [1:0]           multdiv_signed_mode_o,

  // CSRs
  output logic                 csr_access_o,          // access to CSR
  output ibex_pkg::csr_op_e    csr_op_o,              // operation to perform on CSR
  output ibex_pkg::csr_num_e   csr_addr_o,            // CSR address
  output logic                 csr_cheriot_always_ok_o, // CHERIoT safe-listed (no ASR needed) CSRs

  // LSU
  output logic                 data_req_o,            // start transaction to data memory
  output logic                 cheriot_data_req_o,      // cheriot lsu transaction
  output logic                 data_we_o,             // write enable
  output logic [1:0]           data_type_o,           // size of transaction: byte, half
                                                      // word or word
  output logic                 data_sign_extension_o, // sign extension for data read from
                                                      // memory

  // jump/branches
  output logic                 jump_in_dec_o,         // jump is being calculated in ALU
  output logic                 branch_in_dec_o,

  // output to cheriot EX
  output logic                   instr_is_cheriot_o,
  output logic                   instr_is_legal_cheriot_o,
  output logic [11:0]            cheriot_imm12_o,
  output logic [19:0]            cheriot_imm20_o,
  output logic [20:0]            cheriot_imm21_o,
  output cheriot_op_t            cheriot_operator_o,
  output logic [4:0]             cheriot_cs2_dec_o,
  output cheriot_cap_field_e     cheriot_cap_field_sel_o,
  output cheriot_adder_a_sel_e   cheriot_adder_a_sel_o,
  output cheriot_adder_b_sel_e   cheriot_adder_b_sel_o,
  output cheriot_setaddr_sel_e   cheriot_setaddr_sel_o,
  output cheriot_setbounds_sel_e cheriot_setbounds_sel_o
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

  assign new_nmi_int = id_stage_i.controller_i.irq_nm_int & ~nmi_mode & ~debug_mode;
```

## Documentation

### doc/03_reference/instruction_decode_execute.rst

```text
Instruction Decode and Execute
==============================

.. figure:: images/de_ex_stage.svg
   :name: de_ex_stage
   :align: center

   Instruction Decode and Execute

The Instruction Decode and Execute stage takes instruction data from the instruction fetch stage (which has been converted to the uncompressed representation in the compressed instruction case).
The instructions are decoded and executed all within one cycle including the register read and write.
The stage is made up of multiple sub-blocks which are described below.
```
