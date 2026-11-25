# Implement `ibex_decoder`

Implement the complete `ibex_decoder` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_decoder` definition in a single SystemVerilog code block, with no text outside the block.

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
    OPCODE_LOAD     = 7'h03,
    OPCODE_MISC_MEM = 7'h0f,
    OPCODE_OP_IMM   = 7'h13,
    OPCODE_AUIPC    = 7'h17,
    OPCODE_STORE    = 7'h23,
    OPCODE_OP       = 7'h33,
    OPCODE_LUI      = 7'h37,
    OPCODE_BRANCH   = 7'h63,
    OPCODE_JALR     = 7'h67,
    OPCODE_JAL      = 7'h6f,
    OPCODE_SYSTEM   = 7'h73,
    OPCODE_CHERI    = 7'h5b,
    OPCODE_AUICGP   = 7'h7b
  } opcode_e;
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

  import ibex_pkg::*;
```

## Parent instantiation

### rtl/ibex_id_stage.sv

```verilog
  ibex_decoder #(
    .RV32E          (RV32E),
    .RV32M          (RV32M),
    .RV32B          (RV32B),
    .BranchTargetALU(BranchTargetALU),
    .BaseIsa        (BaseIsa)
  ) decoder_i (
    .clk_i (clk_i),
    .rst_ni(rst_ni),

    .cheriot_enable_i (cheriot_enable_i),
    // controller
    .illegal_insn_o(illegal_insn_dec),
    .ebrk_insn_o   (ebrk_insn),
    .mret_insn_o   (mret_insn_dec),
    .dret_insn_o   (dret_insn_dec),
    .ecall_insn_o  (ecall_insn_dec),
    .wfi_insn_o    (wfi_insn_dec),
    .jump_set_o    (jump_set_dec),
    .branch_taken_i(branch_taken),
    .icache_inval_o(icache_inval_o),

    // from IF-ID pipeline register
    .instr_first_cycle_i(instr_first_cycle),
    .instr_rdata_i      (instr_rdata_i),
    .instr_rdata_alu_i  (instr_rdata_alu_i),
    .illegal_c_insn_i   (illegal_c_insn_i),

    // immediates
    .imm_a_mux_sel_o(imm_a_mux_sel),
    .imm_b_mux_sel_o(imm_b_mux_sel_dec),
    .bt_a_mux_sel_o (bt_a_mux_sel),
    .bt_b_mux_sel_o (bt_b_mux_sel),

    .imm_i_type_o   (imm_i_type),
    .imm_s_type_o   (imm_s_type),
    .imm_b_type_o   (imm_b_type),
    .imm_u_type_o   (imm_u_type),
    .imm_j_type_o   (imm_j_type),
    .zimm_rs1_type_o(zimm_rs1_type),

    // register file
    .rf_wdata_sel_o(rf_wdata_sel),
    .rf_we_o       (rf_we_dec),
    .rf_we_or_load_o(rf_we_or_load),

    .rf_raddr_a_o(rf_raddr_a_o),
    .rf_raddr_b_o(rf_raddr_b_o),
    .rf_waddr_o  (rf_waddr_id_o),
    .rf_ren_a_o  (rf_ren_a_dec),
    .rf_ren_b_o  (rf_ren_b_dec),

    // ALU
    .alu_operator_o    (alu_operator),
    .alu_op_a_mux_sel_o(alu_op_a_mux_sel_dec),
    .alu_op_b_mux_sel_o(alu_op_b_mux_sel_dec),
    .alu_multicycle_o  (alu_multicycle_dec),

    // MULT & DIV
    .mult_en_o            (mult_en_dec),
    .div_en_o             (div_en_dec),
    .mult_sel_o           (mult_sel_ex_o),
    .div_sel_o            (div_sel_ex_o),
    .multdiv_operator_o   (multdiv_operator),
    .multdiv_signed_mode_o(multdiv_signed_mode),

    // CSRs
    .csr_access_o(csr_access_o),
    .csr_op_o    (csr_op_o),
    .csr_addr_o  (csr_addr_o),
    .csr_cheriot_always_ok_o(csr_cheriot_always_ok),

    // LSU
    .data_req_o             (lsu_req_dec),
    .cheriot_data_req_o     (cheriot_lsu_req_dec),
    .data_we_o              (lsu_we),
    .data_type_o            (lsu_type),
    .data_sign_extension_o  (lsu_sign_ext),

    // jump/branches
    .jump_in_dec_o  (jump_in_dec),
    .branch_in_dec_o(branch_in_dec),

    // cheriot signals
    .instr_is_cheriot_o       (instr_is_cheriot_id_o),
    .instr_is_legal_cheriot_o (instr_is_legal_cheriot),
    .cheriot_imm12_o          (cheriot_imm12_o),
    .cheriot_imm20_o          (cheriot_imm20_o),
    .cheriot_imm21_o          (cheriot_imm21_o),
    .cheriot_operator_o       (cheriot_operator_o),
    .cheriot_cs2_dec_o        (cheriot_cs2_dec_o),
    .cheriot_cap_field_sel_o  (cheriot_cap_field_sel_o),
    .cheriot_adder_a_sel_o    (cheriot_adder_a_sel_o),
    .cheriot_adder_b_sel_o    (cheriot_adder_b_sel_o),
    .cheriot_setaddr_sel_o    (cheriot_setaddr_sel_o),
    .cheriot_setbounds_sel_o  (cheriot_setbounds_sel_o)
  );
```

## Related source code

### rtl/ibex_id_stage.sv

```systemverilog
  // Main ALU immediate MUX for Operand A
  assign imm_a = (imm_a_mux_sel == IMM_A_Z) ? zimm_rs1_type : '0;

  // Main ALU MUX for Operand A
  always_comb begin : alu_operand_a_mux
    unique case (alu_op_a_mux_sel)
      OP_A_REG_A:  alu_operand_a = rf_rdata_a_fwd;
      OP_A_FWD:    alu_operand_a = lsu_addr_last_i;
      OP_A_CURRPC: alu_operand_a = pc_id_i;
      OP_A_IMM:    alu_operand_a = imm_a;
      default:     alu_operand_a = pc_id_i;
    endcase
  end
// ...
  assign alu_operand_a_ex_o          = alu_operand_a;
// ...
  // Branch condition is calculated in the first cycle and flopped for use in the second cycle
  // (only used in fixed time execution mode to determine branch destination).
  if (DataIndTiming) begin : g_sec_branch_taken
    // SEC_CM: CORE.DATA_REG_SW.SCA
    logic branch_taken_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        branch_taken_q <= 1'b0;
      end else begin
        branch_taken_q <= branch_decision_i;
      end
    end

    assign branch_taken = ~data_ind_timing_i | branch_taken_q;

  end else begin : g_nosec_branch_taken

    // Signal unused without fixed time execution mode - only taken branches will trigger
    // branch_set_raw
    assign branch_taken = 1'b1;

  end
// ...
  typedef enum logic { FIRST_CYCLE, MULTI_CYCLE } id_fsm_e;
  id_fsm_e id_fsm_q, id_fsm_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin : id_pipeline_reg
    if (!rst_ni) begin
      id_fsm_q <= FIRST_CYCLE;
    end else if (instr_executing) begin
      id_fsm_q <= id_fsm_d;
    end
  end

  // ID/EX stage can be in two states, FIRST_CYCLE and MULTI_CYCLE. An instruction enters
  // MULTI_CYCLE if it requires multiple cycles to complete regardless of stalls and other
  // considerations. An instruction may be held in FIRST_CYCLE if it's unable to begin executing
  // (this is controlled by instr_executing).
// ...
  always_comb begin
    id_fsm_d                = id_fsm_q;
    rf_we_raw               = rf_we_dec;
// ...
            branch_in_dec: begin
              // cond branch operation
              // All branches take two cycles in fixed time execution mode, regardless of branch
              // condition.
              // SEC_CM: CORE.DATA_REG_SW.SCA
              id_fsm_d         = (data_ind_timing_i || (!BranchTargetALU && branch_decision_i)) ?
                                     MULTI_CYCLE : FIRST_CYCLE;
              stall_branch     = (~BranchTargetALU & branch_decision_i) | data_ind_timing_i;
              branch_set_raw_d = (branch_decision_i | data_ind_timing_i);

              if (BranchPredictor) begin
                branch_not_set = ~branch_decision_i;
              end

              perf_branch_o = 1'b1;
            end
            jump_in_dec: begin
              // uncond branch operation
              // BTALU means jumps only need one cycle
              id_fsm_d      = BranchTargetALU ? FIRST_CYCLE : MULTI_CYCLE;
              stall_jump    = ~BranchTargetALU;
              jump_set_raw  = jump_set_dec;
            end
// ...
  // Signal instruction in ID is in its first cycle. It can remain in its
  // first cycle if it is stalled.
  assign instr_first_cycle      = instr_valid_i & (id_fsm_q == FIRST_CYCLE);
```

### rtl/ibex_core.sv

```systemverilog
  localparam bit          DataIndTiming = SecureIbex;
// ...
  assign csr_wdata  = alu_operand_a_ex;
```

### rtl/ibex_multdiv_fast.sv

```systemverilog
  input  logic  [1:0]      signed_mode_i,
  input  logic [31:0]      op_a_i,
  input  logic [31:0]      op_b_i,
// ...
  assign div_sign_a      = op_a_i[31] & signed_mode_i[0];
  assign div_sign_b      = op_b_i[31] & signed_mode_i[1];
```

### rtl/ibex_load_store_unit.sv

```systemverilog
      unique case (lsu_type_i) // Data type 00 Word, 01 Half word, 11,10 byte
```

## Documentation

### doc/03_reference/instruction_decode_execute.rst

```text
Decoder
-------
Source File: :file:`rtl/ibex_decoder.sv`

The decoder takes uncompressed instruction data and issues appropriate control signals to the other blocks to execute the instruction.
```

### src/rv32.adoc

```text
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

[NOTE]
====
The assembly syntax for `lui` and `auipc` does not represent the lower
12 bits of the U-immediate, which are always zero.

The AUIPC instruction supports two-instruction sequences to access
arbitrary offsets from the PC for both control-flow transfers and data
accesses. The combination of an AUIPC and the 12-bit immediate in a JALR
can transfer control to any 32-bit PC-relative address, while an AUIPC
plus the 12-bit immediate offset in regular load or store instructions
can access any 32-bit PC-relative data address.

The current PC can be obtained by setting the U-immediate to 0. Although
a JAL +4 instruction could also be used to obtain the local PC (of the
instruction following the JAL), it might cause pipeline breaks in
simpler microarchitectures or pollute BTB structures in more complex
microarchitectures.
====

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

[NOTE]
====
NOPs can be used to align code segments to microarchitecturally
significant address boundaries, or to leave space for inline code
modifications. Although there are many possible ways to encode a NOP, we
define a canonical NOP encoding to allow microarchitectural
optimizations as well as for more readable disassembly output. The other
NOP encodings are made available for <<rv32i-hints>>.

ADDI was chosen for the NOP encoding as this is most likely to take
fewest resources to execute across a range of systems (if not optimized
away in decode). In particular, the instruction only reads one register.
Also, an ADDI functional unit is more likely to be available in a
superscalar design as adds are the most common operation. In particular,
address-generation functional units can execute ADDI using the same
hardware needed for base+offset address calculations, while
register-register ADD or logical/shift operations require additional
hardware.
====

=== Control Transfer Instructions
RV32I provides two types of control transfer instructions: unconditional
jumps and conditional branches. Control transfer instructions in RV32I
do _not_ have architecturally visible delay slots.

If an instruction access-fault or instruction page-fault exception
occurs on the target of a jump or taken branch, the exception is
reported on the target instruction, not on the jump or branch
instruction.

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

[NOTE]
====
The unconditional jump instructions all use PC-relative addressing to
help support position-independent code. The JALR instruction was defined
to enable a two-instruction sequence to jump anywhere in a 32-bit
absolute address range. A LUI instruction can first load _rs1_ with the
upper 20 bits of a target address, then JALR can add in the lower bits.
Similarly, AUIPC then JALR can jump anywhere in a 32-bit `pc`-relative
address range.

Note that the JALR instruction does not treat the 12-bit immediate as
multiples of 2 bytes, unlike the conditional branch instructions. This
avoids one more immediate format in hardware. In practice, most uses of
JALR will have either a zero immediate or be paired with a LUI or AUIPC,
so the slight reduction in range is not significant.

Clearing the least-significant bit when calculating the JALR target
address both simplifies the hardware slightly and allows the low bit of
function pointers to be used to store auxiliary information. Although
there is potentially a slight loss of error checking in this case, in
practice jumps to an incorrect instruction address will usually quickly
raise an exception.

When used with a base _rs1_=`x0`, JALR can be used to
implement a single instruction subroutine call to the lowest or highest
address region from anywhere in the address space, which could be used
to implement fast calls to a small runtime library. Alternatively, an
ABI could dedicate a general-purpose register to point to a library
elsewhere in the address space.
====

The JAL and JALR instructions will generate an
instruction-address-misaligned exception if the target address is not
aligned to a four-byte boundary.

[NOTE]
====
Instruction-address-misaligned exceptions are not possible on machines
that support extensions with 16-bit aligned instructions, such as the
compressed instruction-set extension, C.
====

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


[NOTE]
====
Some other ISAs added explicit hint bits to their indirect-jump
instructions to guide return-address stack manipulation. We use implicit
hinting tied to register numbers and the calling convention to reduce
the encoding space used for these hints.

When two different link registers (`x1` and `x5`) are given as _rs1_ and
_rd_, then the RAS is both popped and pushed to support coroutines. If
_rs1_ and _rd_ are the same link register (either `x1` or `x5`), the RAS
is only pushed to enable macro-op fusion of the sequences:
`lui ra, imm20; jalr ra, imm12(ra)_ and _auipc ra, imm20; jalr ra, imm12(ra)`
====

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

[NOTE]
====
Signed array bounds may be checked with a single BLTU instruction, since
any negative index will compare greater than any nonnegative bound.
====

Software should be optimized such that the sequential code path is the
most common path, with less-frequently taken code paths placed out of
line. Software should also assume that backward branches will be
predicted taken and forward branches as not taken, at least the first
time they are encountered. Dynamic predictors should quickly learn any
predictable branch behavior.

Unlike some other architectures, the RISC-V jump (JAL with _rd_=`x0`)
instruction should always be used for unconditional branches instead of
a conditional branch instruction with an always-true condition. RISC-V
jumps are also PC-relative and support a much wider offset range than
branches, and will not pollute conditional-branch prediction tables.

[NOTE]
====
The conditional branches were designed to include arithmetic comparison
operations between two registers (as also done in PA-RISC, Xtensa, and
MIPS R6), rather than use condition codes (x86, ARM, SPARC, PowerPC), or
to only compare one register against zero (Alpha, MIPS), or two
registers only for equality (MIPS). This design was motivated by the
observation that a combined compare-and-branch instruction fits into a
regular pipeline, avoids additional condition code state or use of a
temporary register, and reduces static code size and dynamic instruction
fetch traffic. Another point is that comparisons against zero require
non-trivial circuit delay (especially after the move to static logic in
advanced processes) and so are almost as expensive as arithmetic
magnitude compares. Another advantage of a fused compare-and-branch
instruction is that branches are observed earlier in the front-end
instruction stream, and so can be predicted earlier. There is perhaps an
advantage to a design with condition codes in the case where multiple
branches can be taken based on the same condition codes, but we believe
this case to be relatively rare.

We considered but did not include static branch hints in the instruction
encoding. These can reduce the pressure on dynamic predictors, but
require more instruction encoding space and software profiling for best
results, and can result in poor performance if production runs do not
match profiling runs.

We considered but did not include conditional moves or predicated
instructions, which can effectively replace unpredictable short forward
branches. Conditional moves are the simpler of the two, but are
difficult to use with conditional code that might cause exceptions
(memory accesses and floating-point operations). Predication adds
additional flag state to a system, additional instructions to set and
clear flags, and additional encoding overhead on every instruction. Both
conditional move and predicated instructions add complexity to
out-of-order microarchitectures, adding an implicit third source operand
due to the need to copy the original value of the destination
architectural register into the renamed destination physical register if
the predicate is false. Also, static compile-time decisions to use
predication instead of branches can result in lower performance on
inputs not included in the compiler training set, especially given that
unpredictable branches are rare, and becoming rarer as branch prediction
techniques improve.

We note that various microarchitectural techniques exist to dynamically
convert unpredictable short forward branches into internally predicated
code to avoid the cost of flushing pipelines on a branch mispredict cite:[heil-tr1996], cite:[Klauser-1998], cite:[Kim-micro2005] and
have been implemented in commercial processors  cite:[ibmpower7]. The simplest techniques
just reduce the penalty of recovering from a mispredicted short forward
branch by only flushing instructions in the branch shadow instead of the
entire fetch pipeline, or by fetching instructions from both sides using
wide instruction fetch or idle instruction fetch slots. More complex
techniques for out-of-order cores add internal predicates on
instructions in the branch shadow, with the internal predicate value
written by the branch instruction, allowing the branch and following
instructions to be executed speculatively and out-of-order with respect
to other code.
====

The conditional branch instructions will generate an
instruction-address-misaligned exception if the target address is not
aligned to a four-byte boundary and the branch condition evaluates to
true. If the branch condition evaluates to false, the
instruction-address-misaligned exception will not be raised.

[NOTE]
====
Instruction-address-misaligned exceptions are not possible on machines
that support extensions with 16-bit aligned instructions, such as the
compressed instruction-set extension, C.
====

[[ldst]]
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

Regardless of EEI, loads and stores whose effective addresses are
naturally aligned shall not raise an address-misaligned exception. Loads
and stores whose effective address is not naturally aligned to the
referenced datatype (i.e., the effective address is not divisible by the
size of the access in bytes) have behavior dependent on the EEI.

An EEI may guarantee that misaligned loads and stores are fully
supported, and so the software running inside the execution environment
will never experience a contained or fatal address-misaligned trap. In
this case, the misaligned loads and stores can be handled in hardware,
or via an invisible trap into the execution environment implementation,
or possibly a combination of hardware and invisible trap depending on
address.

An EEI may not guarantee misaligned loads and stores are handled
invisibly. In this case, loads and stores that are not naturally aligned
may either complete execution successfully or raise an exception. The
exception raised can be either an address-misaligned exception or an
access-fault exception. For a memory access that would otherwise be able
to complete except for the misalignment, an access-fault exception can
be raised instead of an address-misaligned exception if the misaligned
access should not be emulated, e.g., if accesses to the memory region
have side effects. When an EEI does not guarantee misaligned loads and
stores are handled invisibly, the EEI must define if exceptions caused
by address misalignment result in a contained trap (allowing software
running inside the execution environment to handle the trap) or a fatal
trap (terminating execution).

[NOTE]
====
Misaligned accesses are occasionally required when porting legacy code,
and help performance on applications when using any form of packed-SIMD
extension or handling externally packed data structures. Our rationale
for allowing EEIs to choose to support misaligned accesses via the
regular load and store instructions is to simplify the addition of
misaligned hardware support. One option would have been to disallow
misaligned accesses in the base ISAs and then provide some separate ISA
support for misaligned accesses, either special instructions to help
software handle misaligned accesses or a new hardware addressing mode
for misaligned accesses. Special instructions are difficult to use,
complicate the ISA, and often add new processor state (e.g., SPARC VIS
align address offset register) or complicate access to existing
processor state (e.g., MIPS LWL/LWR partial register writes). In
addition, for loop-oriented packed-SIMD code, the extra overhead when
operands are misaligned motivates software to provide multiple forms of
loop depending on operand alignment, which complicates code generation
and adds to loop startup overhead. New misaligned hardware addressing
modes take considerable space in the instruction encoding or require
very simplified addressing modes (e.g., register indirect only).
====

Even when misaligned loads and stores complete successfully, these
accesses might run extremely slowly depending on the implementation
(e.g., when implemented via an invisible trap). Furthermore, whereas
naturally aligned loads and stores are guaranteed to execute atomically,
misaligned loads and stores might not, and hence require additional
synchronization to ensure atomicity.

[NOTE]
====
We do not mandate atomicity for misaligned accesses so execution
environment implementations can use an invisible machine trap and a
software handler to handle some or all misaligned accesses. If hardware
misaligned support is provided, software can exploit this by simply
using regular load and store instructions. Hardware can then
automatically optimize accesses depending on whether runtime addresses
are aligned.
====
```

### src/zicsr.adoc

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
```

### src/m-st-ext.adoc

```text
== "M" Extension for Integer Multiplication and Division, Version 2.0

This chapter describes the standard integer multiplication and division
instruction extension, which is named "M" and contains instructions
that multiply or divide values held in two integer registers.

[NOTE]
====
We separate integer multiply and divide out from the base to simplify
low-end implementations, or for applications where integer multiply and
divide operations are either infrequent or better handled in attached
accelerators.
====

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

[[divby0]]
.Semantics for division by zero and division overflow. L is the width of the operation in bits: XLEN for DIV[U] and REM[U], or 32 for DIV[U]W and REM[U]W.
[cols="<2,^,^,^,^,^,^",options="header",]
|===
|Condition |Dividend |Divisor |DIVU[W] |REMU[W] |DIV[W] |REM[W]

|Division by zero +
Overflow (signed only) |latexmath:[$x$] +
latexmath:[$-2^{L-1}$] |0 +
latexmath:[$-1$] |latexmath:[$2^{L}-1$] +
 - |latexmath:[$x$] + 
 - |latexmath:[$-1$] +
 latexmath:[$-2^{L-1}$] +
  |latexmath:[$x$] +
  0
|===

//|Overflow (signed only) |latexmath:[$-2^{L-1}$] |latexmath:[$-1$] |– |– |latexmath:[$-2^{L-1}$] |0
//|===

[NOTE]
====
We considered raising exceptions on integer divide by zero, with these
exceptions causing a trap in most execution environments. However, this
would be the only arithmetic trap in the standard ISA (floating-point
exceptions set flags and write default values, but do not cause traps)
and would require language implementors to interact with the execution
environment's trap handlers for this case. Further, where language
standards mandate that a divide-by-zero exception must cause an
immediate control flow change, only a single branch instruction needs to
be added to each divide operation, and this branch instruction can be
inserted after the divide and should normally be very predictably not
taken, adding little runtime overhead.

The value of all bits set is returned for both unsigned and signed
divide by zero to simplify the divider circuitry. The value of all 1s is
both the natural value to return for unsigned divide, representing the
largest unsigned number, and also the natural result for simple unsigned
divider implementations. Signed division is often implemented using an
unsigned division circuit and specifying the same overflow result
simplifies the hardware.
====

=== Zmmul Extension, Version 1.0

The Zmmul extension implements the multiplication subset of the M
extension. It adds all of the instructions defined in
<<Multiplication Operations>>, namely: MUL, MULH, MULHU,
MULHSU, and (for RV64 only) MULW. The encodings are identical to those
of the corresponding M-extension instructions. M implies Zmmul.
(((MUL, Zmmul)))

[NOTE]
====
The *Zmmul* extension enables low-cost implementations that require
multiplication operations but not division. For many microcontroller
applications, division operations are too infrequent to justify the cost
of divider hardware. By contrast, multiplication operations are more
frequent, making the cost of multiplier hardware more justifiable.
Simple FPGA soft cores particularly benefit from eliminating division
but retaining multiplication, since many FPGAs provide hardwired
multipliers but require dividers be implemented in soft logic.
====
```
