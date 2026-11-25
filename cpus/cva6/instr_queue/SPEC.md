# Implement `instr_queue`

Implement the complete `instr_queue` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module instr_queue` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
      VLEN: unsigned'(32),
      FpgaEn: bit'(0),
      FpgaAlteraEn: bit'(0),
      TechnoCut: bit'(1),
      SuperscalarEn: bit'(0),
// ...
      RVC: bit'(1),
      RVH: bit'(0),
      RVZCMT: bit'(0),
      RVZCB: bit'(1),
      RVZCMP: bit'(0),
// ...
      TvalEn: bit'(0),
```

### core/include/build_config_pkg.sv

```systemverilog
    cfg.FETCH_WIDTH = unsigned'(CVA6Cfg.SuperscalarEn ? 64 : 32);
    cfg.FETCH_ALIGN_BITS = $clog2(cfg.FETCH_WIDTH / 8);
    cfg.INSTR_PER_FETCH = cfg.FETCH_WIDTH / (CVA6Cfg.RVC ? 16 : 32);
    cfg.LOG2_INSTR_PER_FETCH = cfg.INSTR_PER_FETCH > 1 ? $clog2(cfg.INSTR_PER_FETCH) : 1;
```

## Module declaration

```systemverilog
module instr_queue
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type fetch_entry_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Fetch flush request - CONTROLLER
    input logic flush_i,
    // Instruction - instr_realign
    input logic [CVA6Cfg.INSTR_PER_FETCH-1:0][31:0] instr_i,
    // Instruction address - instr_realign
    input logic [CVA6Cfg.INSTR_PER_FETCH-1:0][CVA6Cfg.VLEN-1:0] addr_i,
    // Instruction is valid - instr_realign
    input logic [CVA6Cfg.INSTR_PER_FETCH-1:0] valid_i,
    // Handshake’s ready with CACHE - CACHE
    output logic ready_o,
    // Indicates instructions consumed, or popped by ID_STAGE - FRONTEND
    output logic [CVA6Cfg.INSTR_PER_FETCH-1:0] consumed_o,
    // Exception (which is page-table fault) - CACHE
    input ariane_pkg::frontend_exception_t exception_i,
    // Exception address - CACHE
    input logic [CVA6Cfg.VLEN-1:0] exception_addr_i,
    input logic [CVA6Cfg.GPLEN-1:0] exception_gpaddr_i,
    input logic [31:0] exception_tinst_i,
    input logic exception_gva_i,
    // Branch predict - FRONTEND
    input logic [CVA6Cfg.VLEN-1:0] predict_address_i,
    // Instruction predict address - FRONTEND
    input ariane_pkg::cf_t [CVA6Cfg.INSTR_PER_FETCH-1:0] cf_type_i,
    // Replay instruction because one of the FIFO was full - FRONTEND
    output logic replay_o,
    // Address at which to replay the fetch - FRONTEND
    output logic [CVA6Cfg.VLEN-1:0] replay_addr_o,
    // Handshake’s data with ID_STAGE - ID_STAGE
    output fetch_entry_t [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_o,
    // Handshake’s valid with ID_STAGE - ID_STAGE
    output logic [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_valid_o,
    // Handshake’s ready with ID_STAGE - ID_STAGE
    input logic [CVA6Cfg.NrIssuePorts-1:0] fetch_entry_ready_i
);
```

## Parent instantiation

### core/frontend/frontend.sv

```systemverilog
  // Cache interface
  // Gate ICache requests and NPC updates during fence.i
  assign icache_dreq_o.req = instr_queue_ready & ~halt_frontend_i;
  assign if_ready = icache_dreq_i.ready & instr_queue_ready & ~halt_frontend_i;
  // We need to flush the cache pipeline if:
  // 1. We mispredicted
  // 2. Want to flush the whole processor front-end
  // 3. Need to replay an instruction because the fetch-fifo was full
  assign icache_dreq_o.kill_s1 = is_mispredict | flush_i | replay;
  // if we have a valid branch-prediction we need to only kill the last cache request
  // also if we killed the first stage we also need to kill the second stage (inclusive flush)
  assign icache_dreq_o.kill_s2 = icache_dreq_o.kill_s1 | bp_valid;
// ...

  instr_queue #(
      .CVA6Cfg(CVA6Cfg),
      .fetch_entry_t(fetch_entry_t)
  ) i_instr_queue (
      .clk_i              (clk_i),
      .rst_ni             (rst_ni),
      .flush_i            (flush_i),
      .instr_i            (instr),                 // from re-aligner
      .addr_i             (addr),                  // from re-aligner
      .exception_i        (icache_ex_valid_q),     // from I$
      .exception_addr_i   (icache_vaddr_q),
      .exception_gpaddr_i (icache_gpaddr_q),
      .exception_tinst_i  (icache_tinst_q),
      .exception_gva_i    (icache_gva_q),
      .predict_address_i  (predict_address),
      .cf_type_i          (cf_type),
      .valid_i            (instruction_valid),     // from re-aligner
      .consumed_o         (instr_queue_consumed),
      .ready_o            (instr_queue_ready),
      .replay_o           (replay),
      .replay_addr_o      (replay_addr),
      .fetch_entry_o      (fetch_entry_o),         // to back-end
      .fetch_entry_valid_o(fetch_entry_valid_o),   // to back-end
      .fetch_entry_ready_i(fetch_entry_ready_i)    // to back-end
  );
```

## Dependency declarations

### core/include/ariane_pkg.sv

```systemverilog
  // leave as is (fails with >8 entries and wider fetch width)
  localparam int unsigned FETCH_FIFO_DEPTH = 4;
  localparam int unsigned FETCH_ADDR_FIFO_DEPTH = 2;

  typedef enum logic [2:0] {
    NoCF,    // No control flow prediction
    Branch,  // Branch
    Jump,    // Jump to address from immediate
    JumpR,   // Jump to address from registers
    Return   // Return Address Prediction
  } cf_t;
// ...
  typedef enum logic [1:0] {
    FE_NONE,
    FE_INSTR_ACCESS_FAULT,
    FE_INSTR_PAGE_FAULT,
    FE_INSTR_GUEST_PAGE_FAULT
  } frontend_exception_t;
```

### core/cva6.sv

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
```

### core/cva6_fifo_v3.sv

```systemverilog
module cva6_fifo_v3 #(
    parameter bit FALL_THROUGH = 1'b0,  // fifo is in fall-through mode
    parameter bit FPGA_ALTERA = 1'b0,  // FPGA Altera optimizations enabled
    parameter int unsigned DATA_WIDTH = 32,  // default data width if the fifo is of type logic
    parameter int unsigned DEPTH = 8,  // depth can be arbitrary from 0 to 2**32
    parameter type dtype = logic [DATA_WIDTH-1:0],
    parameter bit FPGA_EN = 1'b0,
    // DO NOT OVERWRITE THIS PARAMETER
    parameter int unsigned ADDR_DEPTH = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
    input  logic                  clk_i,       // Clock
    input  logic                  rst_ni,      // Asynchronous reset active low
    input  logic                  flush_i,     // flush the queue
    input  logic                  testmode_i,  // test_mode to bypass clock gating
    // status flags
    output logic                  full_o,      // queue is full
    output logic                  empty_o,     // queue is empty
    output logic [ADDR_DEPTH-1:0] usage_o,     // fill pointer
    // as long as the queue is not full we can push new data
    input  dtype                  data_i,      // data to push into the queue
    input  logic                  push_i,      // data is valid and can be pushed to the queue
    // as long as the queue is not empty we can pop new elements
    output dtype                  data_o,      // output data
    input  logic                  pop_i        // pop head from queue
);
```

### vendor/pulp-platform/common_cells/src/lzc.sv

```systemverilog
module lzc #(
  /// The width of the input vector.
  parameter int unsigned WIDTH = 2,
  /// Mode selection: 0 -> trailing zero, 1 -> leading zero
  parameter bit          MODE  = 1'b0,
  /// Dependent parameter. Do **not** change!
  ///
  /// Width of the output signal with the zero count.
  parameter int unsigned CNT_WIDTH = cf_math_pkg::idx_width(WIDTH)
) (
  /// Input vector to be counted.
  input  logic [WIDTH-1:0]     in_i,
  /// Count of the leading / trailing zeros.
  output logic [CNT_WIDTH-1:0] cnt_o,
  /// Counter is empty: Asserted if all bits in in_i are zero.
  output logic                 empty_o
);
```

### vendor/pulp-platform/common_cells/src/popcount.sv

```systemverilog
module popcount #(
    parameter int unsigned INPUT_WIDTH = 256,
    localparam int unsigned PopcountWidth = $clog2(INPUT_WIDTH)+1
) (
    input logic [INPUT_WIDTH-1:0]     data_i,
    output logic [PopcountWidth-1:0] popcount_o
);
```

### core/include/riscv_pkg.sv

```systemverilog
package riscv;
// ...
  localparam logic [XLEN-1:0] INSTR_ACCESS_FAULT    = 1;  // Illegal access as governed by PMPs and PMAs
// ...
  localparam logic [XLEN-1:0] INSTR_PAGE_FAULT = 12;  // Instruction page fault
// ...
  localparam logic [XLEN-1:0] INSTR_GUEST_PAGE_FAULT = 20;  // Instruction guest-page fault
```

## Documentation

### docs/design/design-manual/source/cva6_frontend.adoc

```text
Fetch stage controls the CACHE module by a handshaking protocol.
Fetched data is a {ifetch-len}-bit block with a word-aligned address.
A granted fetch is processed by the instr_realign submodule to produce instructions.
Then instructions are pushed into an internal instruction FIFO called instruction queue (instr_queue submodule).
This submodule stores the instructions with its associated address and sends them to the DECODE module.

Before sending the instructions to the DECODE stage, the frontend calculates a prediction address in case of a JUMP or Branch. This predicted address is sent to the DECODE stage along with the instruction and its fetch address.
The prediction address is not valid if there is no prediction.
Instructions following a predicted taken control flow instruction are dropped.
...
Memory can feedback potential exceptions which can be bus errors, invalid accesses or instruction page faults.
The FRONTEND transmits the exception from CACHES to DECODE.
...
[[instr_queue-submodule]]
Instr_queue submodule
+++++++++++++++++++++

The instr_queue receives multiple instructions from instr_realign submodule to create a valid stream to be executed.
Frontend pushes instructions and all related information into the FIFO for storage, including details needed in case of a misprediction or exception: the instructions themselves, instruction control flow type, exception, exception address, and predicted address.
DECODE pops them when decode stage is ready and indicates to the FRONTEND the instruction has been consumed.


The instruction queue contains two FIFOs: one for instructions and one for addresses, which stores addresses in case of a prediction.
The instruction FIFO can hold up to 4×{instr-per-fetch} instructions, while the address FIFO can hold up to 2 addresses.
If the instruction FIFO is full, a replay request is sent to inform the fetch mechanism to replay the fetch.
If the address FIFO is full and there is a prediction, a replay request is sent to inform the fetch mechanism to replay the fetch, even if the instruction FIFO is not full.

The instruction queue can be flushed by the flush signal coming from the CONTROLLER.
```

## Additional requirement

`consumed_o[i]` is 1 exactly when instruction `i` of the current `instr_i` fetch is admitted into the queue in that cycle, and when `replay_o` is 1, `replay_addr_o` is the address of the first valid instruction of the current fetch that is not admitted.
