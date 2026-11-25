# Implement `scoreboard`

Implement the complete `scoreboard` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module scoreboard` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
      SuperscalarEn: bit'(0),
// ...
      NrCommitPorts: unsigned'(1),
// ...
      RVF: bit'(0),
      RVD: bit'(0),
      XF16: bit'(0),
      XF16ALT: bit'(0),
      XF8: bit'(0),
// ...
      CvxifEn: bit'(1),
// ...
      NrScoreboardEntries: unsigned'(4),
// ...
      DebugEn: bit'(0),
```

### core/include/build_config_pkg.sv

```systemverilog
  function automatic config_pkg::cva6_cfg_t build_config(config_pkg::cva6_user_cfg_t CVA6Cfg);
    bit IS_XLEN32 = (CVA6Cfg.XLEN == 32) ? 1'b1 : 1'b0;
    bit IS_XLEN64 = (CVA6Cfg.XLEN == 32) ? 1'b0 : 1'b1;
    bit FpPresent = CVA6Cfg.RVF | CVA6Cfg.RVD | CVA6Cfg.XF16 | CVA6Cfg.XF16ALT | CVA6Cfg.XF8;
// ...
    bit EnableAccelerator = CVA6Cfg.RVV;  // Currently only used by V extension (Ara)
    int unsigned NrWbPorts = (CVA6Cfg.CvxifEn || EnableAccelerator) ? 5 : 4;
// ...
    cfg.SuperscalarEn = CVA6Cfg.SuperscalarEn;
    cfg.NrCommitPorts = CVA6Cfg.SuperscalarEn ? unsigned'(2) : CVA6Cfg.NrCommitPorts;
    cfg.NrIssuePorts = unsigned'(CVA6Cfg.SuperscalarEn ? 2 : 1);
    cfg.SpeculativeSb = CVA6Cfg.SuperscalarEn;
// ...
    cfg.NR_SB_ENTRIES = CVA6Cfg.NrScoreboardEntries;
    cfg.TRANS_ID_BITS = $clog2(CVA6Cfg.NrScoreboardEntries);

    cfg.FpPresent = bit'(FpPresent);
```

## Module declaration

```systemverilog
// Description: Scoreboard - keeps track of all decoded, issued and committed instructions

module scoreboard #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bp_resolve_t = logic,
    parameter type exception_t = logic,
    parameter type scoreboard_entry_t = logic,
    parameter type forwarding_t = logic,
    parameter type writeback_t = logic,
    parameter type rs3_len_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input  logic                                          clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input  logic                                          rst_ni,
    // Is scoreboard full - PERF_COUNTERS
    output logic                                          sb_full_o,
    // Prevent from issuing - CONTROLLER
    input  logic                                          flush_unissued_instr_i,
    // Flush whole scoreboard - CONTROLLER
    input  logic                                          flush_i,
    // Writeback Handling of CVXIF
    // TO_BE_COMPLETED - ISSUE_READ_OPERANDS
    input  logic                                          x_transaction_accepted_i,
    // TO_BE_COMPLETED - ISSUE_READ_OPERANDS
    input  logic                                          x_issue_writeback_i,
    // TO_BE_COMPLETED - ISSUE_READ_OPERANDS
    input  logic              [CVA6Cfg.TRANS_ID_BITS-1:0] x_id_i,
    // advertise instruction to commit stage, if commit_ack_i is asserted advance the commit pointer
    // Instructions to commit - COMMIT_STAGE
    output scoreboard_entry_t [CVA6Cfg.NrCommitPorts-1:0] commit_instr_o,
    // Instruction is cancelled - COMMIT_STAGE
    output logic              [CVA6Cfg.NrCommitPorts-1:0] commit_drop_o,
    // Commit acknowledge - COMMIT_STAGE
    input  logic              [CVA6Cfg.NrCommitPorts-1:0] commit_ack_i,

    // instruction to put on top of scoreboard e.g.: top pointer
    // we can always put this instruction to the top unless we signal with asserted full_o
    // Handshake's data with decode stage - ID_STAGE
    input  scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0]       decoded_instr_i,
    // instruction value - ID_STAGE
    input  logic              [CVA6Cfg.NrIssuePorts-1:0][31:0] orig_instr_i,
    // Handshake's valid with decode stage - ID_STAGE
    input  logic              [CVA6Cfg.NrIssuePorts-1:0]       decoded_instr_valid_i,
    // Handshake's acknowledge with decode stage - ID_STAGE
    output logic              [CVA6Cfg.NrIssuePorts-1:0]       decoded_instr_ack_o,

    // instruction to issue logic, if issue_instr_valid and issue_ready is asserted, advance the issue pointer
    // Entry about the instruction to issue - ISSUE_READ_OPERANDS
    output scoreboard_entry_t [CVA6Cfg.NrIssuePorts-1:0]       issue_instr_o,
    // Instruction to issue - ISSUE_READ_OPERANDS
    output logic              [CVA6Cfg.NrIssuePorts-1:0][31:0] orig_instr_o,
    // Is there an instruction to issue - ISSUE_READ_OPERANDS
    output logic              [CVA6Cfg.NrIssuePorts-1:0]       issue_instr_valid_o,
    // Issue stage acknowledge - ISSUE_READ_OPERANDS
    input  logic              [CVA6Cfg.NrIssuePorts-1:0]       issue_ack_i,
    // Forwarding - ISSUE_READ_OPERANDS
    output forwarding_t                                        fwd_o,

    // Result from branch unit - EX_STAGE
    input bp_resolve_t resolved_branch_i,
    // Transaction ID at which to write the result back - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_i,
    // Results to write back - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0][CVA6Cfg.XLEN-1:0] wbdata_i,
    // Exception from a functional unit (e.g.: ld/st exception) - EX_STAGE
    input exception_t [CVA6Cfg.NrWbPorts-1:0] ex_i,
    // Indicates valid results - EX_STAGE
    input logic [CVA6Cfg.NrWbPorts-1:0] wt_valid_i,
    // Cvxif we for writeback - EX_STAGE
    input logic x_we_i,
    // CVXIF destination register - ISSUE_STAGE
    input logic [4:0] x_rd_i,

    // Issue pointer - RVFI
    output logic [ CVA6Cfg.NrIssuePorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] rvfi_issue_pointer_o,
    // Commit pointer - RVFI
    output logic [CVA6Cfg.NrCommitPorts-1:0][CVA6Cfg.TRANS_ID_BITS-1:0] rvfi_commit_pointer_o
);
```

## Parent instantiation

### core/cva6.sv

```systemverilog
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
// ...
  logic x_transaction_accepted_iro_sb, x_issue_writeback_iro_sb;
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] x_id_iro_sb;

  // ---------------------------------------------------------
  // 2. Manage instructions in a scoreboard
  // ---------------------------------------------------------
  scoreboard #(
      .CVA6Cfg   (CVA6Cfg),
      .rs3_len_t (rs3_len_t),
      .bp_resolve_t(bp_resolve_t),
      .writeback_t(writeback_t),
      .forwarding_t(forwarding_t),
      .exception_t(exception_t),
      .scoreboard_entry_t(scoreboard_entry_t)
  ) i_scoreboard (
      .clk_i,
      .rst_ni,
      .sb_full_o               (sb_full_o),
      .flush_unissued_instr_i,
      .flush_i,
      .x_transaction_accepted_i(x_transaction_accepted_iro_sb),
      .x_issue_writeback_i     (x_issue_writeback_iro_sb),
      .x_id_i                  (x_id_iro_sb),
      .commit_instr_o,
      .commit_drop_o,
      .commit_ack_i,
      .decoded_instr_i         (decoded_instr_i),
      .orig_instr_i,
      .decoded_instr_valid_i   (decoded_instr_valid_i),
      .decoded_instr_ack_o     (decoded_instr_ack_o),
      .issue_instr_o           (issue_instr_sb_iro),
      .orig_instr_o            (orig_instr_sb_iro),
      .issue_instr_valid_o     (issue_instr_valid_sb_iro),
      .issue_ack_i             (issue_ack_iro_sb),
      .fwd_o                   (fwd),
      .resolved_branch_i       (resolved_branch_i),
      .trans_id_i              (trans_id_i),
      .wbdata_i                (wbdata_i),
      .ex_i                    (ex_ex_i),
      .wt_valid_i,
      .x_we_i,
      .x_rd_i,
      .rvfi_issue_pointer_o,
      .rvfi_commit_pointer_o
  );
```

## Related source code

### core/issue_read_operands.sv

```systemverilog
  assign x_transaction_accepted_o = x_issue_valid_o && x_issue_ready_i && x_issue_resp_i.accept;
  assign x_transaction_rejected = x_issue_valid_o && x_issue_ready_i && ~x_issue_resp_i.accept;
  assign x_issue_writeback_o = x_issue_resp_i.writeback;
  assign x_id_o = x_issue_req_o.id;
```

### core/decoder.sv

```systemverilog
  // this instruction has already executed if the exception is valid
  assign instruction_o.valid = instruction_o.ex.valid;
```

## Documentation

### docs/03_cva6_design/issue_stage.md

```text
# Issue Stage

The issue stage's purpose is to receive the decoded instructions and
issue them to the various functional units. Furthermore the issue stage
keeps track of all issued instructions, the functional unit status and
receives the write-back data from the execute stage. Furthermore it
contains the CPU's register file. By using a data-structure called
scoreboard (see ) it knows exactly which instructions are issued, which
functional unit they are in and which register they will write-back to.
As previously mentioned you can roughly divide the execution in four
parts **1. issue**, **2. read operands**, **3. execute** and **4.
write-back**. The issue stage handles step one, two and four.
...

The issue stage communicates with the various functional units
independently. This in particular means that it has to monitor their
ready and valid signals, receive and store their write-back data
unconditionally. It will always have enough space as it allocates a slot
in the scoreboard for every issued instruction. This solves the
potential structural hazards of smaller microprocessors. This modular
design will also allow to explore more advanced issuing technique like
out-of-order issue ().

The issuing of instructions happen in-order, that means order of program
flow is naturally maintained. What can happen out-of-order is the
write-back of each functional unit. Think for example, that the issue
stage issues a load which takes $n$ clock cycles to produce a
valid result. In the next cycle the issue stage issues an ALU
instruction like an addition. The addition will just take one clock
cycle to return and therefore return before the load's result
is ready. Because of this we need to assign IDs to the various issue
stages. The ID resembles the (unique) position in which the scoreboard
will store the result of this instruction. The ID (called transaction
ID) has enough bits to uniquely represent each slot in the scoreboard
and needs to be passed along with the other data to the corresponding
functional unit.

This scheme allows the functional units to operate in complete
independence of the issue logic. They can return different transactions
in different order. The scoreboard will know where to put them as long
as the corresponding ID is signaled alongside the result. This scheme
even allows the functional unit to buffer results and process them
entirely out-of-order if it makes sense to them. This is a further
example of how to efficiently decouple the different modules of a
processor.
...
#### Scoreboard

The scoreboard is implemented as a FIFO with one read and one write port
with valid and acknowledge signals. In addition to that it provides the
aforementioned signals which tell the rest of the CPU which registers
are going to be clobbered by a previously scheduled instruction.
Instruction decode directly writes to the scoreboard if it is not
already full. The commit stage looks for already finished instructions
and updates the architectural state. Which either means going for an
exception, updating the register or CSR file.
```

### docs/design/design-manual/source/CVX_Interface_Coprocessor.adoc

```text
  ** Response;;
    *** [verse]
    --
    If `issue_resp.accept` is set during a transaction (i.e. issue valid
    and ready are set), the offloaded instruction is accepted by the coprocessor
    and a result transaction will happen.
    --
...
* Result interface::
  ** Request;;
...
  ** Response;;
    *** [verse]
    --
    Result response is directly connected to writeback bus of the CV-X-IF
    functional unit.
    --
    *** [verse]
    --
    Valid signal of result interface is connected to valid signal of
    writeback bus.
    --
    *** [verse]
    --
    Id signal of result interface is connected to scoreboard id of
    writeback bus.
    --
    *** [verse]
    --
    Write enable signal of result interface is connected to a dedicated CV-X-IF WE
    signal in CVA6 which signals scoreboard if a writeback should happen
    or not to the CVA6 register file.
    --
```

### docs/source/x_ext.rst

```text
The |coprocessor| informs the core to which register(s) in the register file it will write-back.
The |processor| uses this information to track data dependencies between instructions.
...
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
```
