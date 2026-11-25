# Implement `ibex_wb_stage`

Implement the complete `ibex_wb_stage` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_wb_stage` definition in a single SystemVerilog code block, with no text outside the block.

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
  // Type of instruction present in writeback stage
  typedef enum logic[1:0] {
    WB_INSTR_LOAD,  // Instruction is awaiting load data
    WB_INSTR_STORE, // Instruction is awaiting store response
    WB_INSTR_OTHER  // Instruction doesn't fit into above categories
  } wb_instr_type_e;
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

## Parent instantiation

### rtl/ibex_core.sv

```verilog
  ibex_wb_stage #(
    .ResetAll         (ResetAll),
    .WritebackStage   (WritebackStage),
    .DummyInstructions(DummyInstructions)
  ) wb_stage_i (
    .clk_i                   (clk_i),
    .rst_ni                  (rst_ni),
    .en_wb_i                 (en_wb),
    .instr_type_wb_i         (instr_type_wb),
    .pc_id_i                 (pc_id),
    .instr_is_compressed_id_i(instr_is_compressed_id),
    .instr_perf_count_id_i   (instr_perf_count_id),
    .instr_is_cheriot_i      (instr_is_cheriot_id),
    .cheriot_load_i          (cheriot_load_id),
    .cheriot_store_i         (cheriot_store_id),

    .ready_wb_o                         (ready_wb),
    .rf_write_wb_o                      (rf_write_wb),
    .outstanding_load_wb_o              (outstanding_load_wb),
    .outstanding_store_wb_o             (outstanding_store_wb),
    .pc_wb_o                            (pc_wb),
    .perf_instr_ret_wb_o                (perf_instr_ret_wb),
    .perf_instr_ret_compressed_wb_o     (perf_instr_ret_compressed_wb),
    .perf_instr_ret_wb_spec_o           (perf_instr_ret_wb_spec),
    .perf_instr_ret_compressed_wb_spec_o(perf_instr_ret_compressed_wb_spec),

    .rf_waddr_id_i(rf_waddr_id),
    .rf_wdata_id_i(rf_wdata_id),
    .rf_we_id_i   (rf_we_id),

    .dummy_instr_id_i(dummy_instr_id),

    .cheriot_rf_we_i    (cheriot_rf_we),
    .cheriot_rf_wdata_i (cheriot_result_data),
    .cheriot_rf_wcap_i  (cheriot_result_cap),

    .rf_wdata_lsu_i(rf_wdata_lsu),
    .rf_wcap_lsu_i (rf_wcap_lsu),
    .rf_we_lsu_i   (rf_we_lsu),

    .rf_wdata_fwd_wb_o(rf_wdata_fwd_wb),
    .rf_wcap_fwd_wb_o (rf_wcap_fwd_wb),

    .rf_waddr_wb_o(rf_waddr_wb),
    .rf_wdata_wb_o(rf_wdata_wb),
    .rf_wcap_wb_o (rf_wcap_wb),
    .rf_we_wb_o   (rf_we_wb),

    .dummy_instr_wb_o(dummy_instr_wb),

    .lsu_resp_valid_i(lsu_resp_valid),
    .lsu_resp_err_i  (lsu_resp_err),

    .instr_done_wb_o(instr_done_wb)
  );
```

## Related source code

### rtl/ibex_id_stage.sv

```systemverilog
  // Note for the two-stage configuration ready_wb_i is always set
  assign multdiv_ready_id_o = ready_wb_i;
// ...
  if (WritebackStage) begin : gen_stall_mem
// ...
  end else begin : gen_no_stall_mem
// ...
    assign instr_type_wb_o = WB_INSTR_OTHER;
    assign stall_wb        = 1'b0;
// ...
    assign instr_id_done_o = instr_done;
  end
// ...
  // Signal which instructions to count as retired in minstret, all traps along with ebrk and
  // ecall instructions are not counted. Writes to minstret/minstreth themselves are also excluded
  // to avoid incrementing right after a write.
  logic minstret_write;
  assign minstret_write = csr_access_o &
      (csr_op_o inside {CSR_OP_WRITE, CSR_OP_SET, CSR_OP_CLEAR}) &
      (csr_addr_o inside {CSR_MINSTRET, CSR_MINSTRETH});

  assign instr_perf_count_id_o = ~ebrk_insn & ~ecall_insn_dec & ~illegal_insn_dec &
      ~illegal_csr_insn_i & ~instr_fetch_err_i & ~minstret_write &
      !(instr_gets_expanded_i inside {INSTR_EXPANDED, INSTR_EXPANDED_COMMIT});

  // An instruction is ready to move to the writeback stage (or retire if there is no writeback
  // stage)
  assign en_wb_o = instr_done;
```

### rtl/ibex_core.sv

```systemverilog
  assign lsu_resp_err = lsu_load_err | lsu_store_err;
// ...
  if (SecureIbex) begin : g_check_mem_response
    // For secure configurations only process load/store responses if we're expecting them to guard
    // against false responses being injected on to the bus
    assign lsu_load_err  = lsu_load_err_raw  & (outstanding_load_wb  | expecting_load_resp_id);
    assign lsu_store_err = lsu_store_err_raw & (outstanding_store_wb | expecting_store_resp_id);
    assign rf_we_lsu     = lsu_rdata_valid   & (outstanding_load_wb  | expecting_load_resp_id);
  end else begin : g_no_check_mem_response
    // For non-secure configurations trust the bus protocol is being followed and we'll only ever
    // see a response if we have an outstanding request.
    assign lsu_load_err  = lsu_load_err_raw;
    assign lsu_store_err = lsu_store_err_raw;
    assign rf_we_lsu     = lsu_rdata_valid;
// ...
  assign rf_waddr_wb_o    = rf_waddr_wb;
  assign rf_we_wb_o       = rf_we_wb;
```

### rtl/ibex_cs_registers.sv

```systemverilog
  // Where the writeback stage is present instruction in ID observing value of minstret must take
  // into account any instruction in the writeback stage. If one is present the incremented value of
  // minstret is used. A speculative version of the signal is used to aid timing. When the writeback
  // stage sees an exception (so the speculative signal is incorrect) the ID stage will be flushed
  // so the incorrect value doesn't matter. A similar behaviour is required for the compressed
  // instruction retired counter below. When the writeback stage isn't present the speculative
  // signals are always 0.
  assign mhpmcounter[2] = instr_ret_spec_i & ~mcountinhibit[2] ? minstret_next : minstret_raw;
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
```

## Additional requirement

`perf_instr_ret_wb_o` is 0 in a cycle in which `lsu_resp_valid_i` and `lsu_resp_err_i` are both 1.
