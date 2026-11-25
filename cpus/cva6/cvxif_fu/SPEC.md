# Implement `cvxif_fu`

Implement the complete `cvxif_fu` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module cvxif_fu` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv32a60x_config_pkg.sv`

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
      XLEN: unsigned'(CVA6ConfigXlen),
// ...
      RVH: bit'(0),
// ...
      NrScoreboardEntries: unsigned'(4),
// ...
      TvalEn: bit'(0),

```

### `core/include/build_config_pkg.sv`

```systemverilog
    cfg.GPLEN = IS_XLEN32 ? 34 : 41;
// ...
    cfg.NR_SB_ENTRIES = CVA6Cfg.NrScoreboardEntries;
    cfg.TRANS_ID_BITS = $clog2(CVA6Cfg.NrScoreboardEntries);
// ...
    cfg.TvalEn = CVA6Cfg.TvalEn;

```

## Package and imports

### `core/include/riscv_pkg.sv`

```systemverilog
package riscv;
// ...
  localparam XLEN = cva6_config_pkg::CVA6ConfigXlen;
// ...
  localparam logic [XLEN-1:0] ILLEGAL_INSTR = 2;

```

## Module declaration

```systemverilog
module cvxif_fu
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type exception_t = logic,
    parameter type x_result_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input  logic                                   clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input  logic                                   rst_ni,
    // Virtualization mode state - CSR_REGFILE
    input  logic                                   v_i,
    // CVXIF instruction is valid - ISSUE_STAGE
    input  logic                                   x_valid_i,
    // Transaction ID - ISSUE_STAGE
    input  logic       [CVA6Cfg.TRANS_ID_BITS-1:0] x_trans_id_i,
    // Instruction is illegal, determined during CVXIF issue transaction - ISSUE_STAGE
    input  logic                                   x_illegal_i,
    // Offloaded instruction - ISSUE_STAGE
    input  logic       [                     31:0] x_off_instr_i,
    // CVXIF is ready - ISSUE_STAGE
    output logic                                   x_ready_o,
    // CVXIF result transaction ID - ISSUE_STAGE
    output logic       [CVA6Cfg.TRANS_ID_BITS-1:0] x_trans_id_o,
    // CVXIF exception - ISSUE_STAGE
    output exception_t                             x_exception_o,
    // CVXIF FU result - ISSUE_STAGE
    output logic       [         CVA6Cfg.XLEN-1:0] x_result_o,
    // CVXIF result valid - ISSUE_STAGE
    output logic                                   x_valid_o,
    // CVXIF write enable - ISSUE_STAGE
    output logic                                   x_we_o,
    // CVXIF destination register - ISSUE_STAGE
    output logic       [                      4:0] x_rd_o,
    // CVXIF result interface
    input  logic                                   result_valid_i,
    input  x_result_t                              result_i,
    output logic                                   result_ready_o
);

```

## Parent instantiation

### `core/ex_stage.sv`

```systemverilog
  if (CVA6Cfg.CvxifEn) begin : gen_cvxif
    fu_data_t cvxif_data;
    always_comb begin
      cvxif_data = x_valid_i[0] ? fu_data_i[0] : '0;
      if (CVA6Cfg.SuperscalarEn) begin
        if (x_valid_i[1]) begin
          cvxif_data = fu_data_i[1];
        end
      end
    end

    cvxif_fu #(
        .CVA6Cfg(CVA6Cfg),
        .exception_t(exception_t),
        .x_result_t(x_result_t)
    ) cvxif_fu_i (
        .clk_i,
        .rst_ni,
        .v_i,
        .x_valid_i(|x_valid_i),
        .x_trans_id_i(cvxif_data.trans_id),
        .x_illegal_i(x_transaction_rejected_i),
        .x_off_instr_i,
        .x_ready_o,
        .x_trans_id_o,
        .x_exception_o,
        .x_result_o,
        .x_valid_o,
        .x_we_o,
        .x_rd_o,
        .result_valid_i(x_result_valid_i),
        .result_i(x_result_i),
        .result_ready_o(x_result_ready_o)
    );

```

## Dependency declarations

### `core/cva6.sv`

```systemverilog
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

```

### `core/include/cvxif_types.svh`

```systemverilog
`define X_RESULT_T(Cfg, hartid_t, id_t, writeregflags_t) struct packed { \
    hartid_t hartid;  /*Identification of the hart offloading the instruction*/ \
    id_t id;  /*Identification of the offloaded instruction*/ \
    logic [Cfg.X_RFW_WIDTH-1:0] data;  /*Register file write data value(s)*/ \
    logic [4:0] rd;  /*Register file destination address(es)*/ \
    writeregflags_t we;  /*Register file write enable(s)*/ \
}

```

## Related source code

### `core/issue_read_operands.sv`

```systemverilog
  // TODO check only for 1st instruction ??
  // Allow a cvxif transaction if we WaW condition are ok.
  assign cvxif_req_allowed = (issue_instr_i[0].fu == CVXIF);
  assign cvxif_instruction_valid = !issue_instr_i[0].ex.valid && issue_instr_valid_i[0] && cvxif_req_allowed;
  assign x_transaction_accepted_o = x_issue_valid_o && x_issue_ready_i && x_issue_resp_i.accept;
  assign x_transaction_rejected = x_issue_valid_o && x_issue_ready_i && ~x_issue_resp_i.accept;
  assign x_issue_writeback_o = x_issue_resp_i.writeback;
  assign x_id_o = x_issue_req_o.id;
// ...
    // CVXIF is always ready to try a new transaction on 1st issue port
    // If a transaction is already pending then we stall until the transaction is done.(issue_ack_o[0] = 0)
    // Since we can not have two CVXIF instruction on 1st issue port, CVXIF is always ready for the pending instruction.
// ...
    x_transaction_rejected_n = 1'b0;
    if (issue_instr_i[0].fu == CVXIF) begin
      x_transaction_rejected_n = x_transaction_rejected;
    end
  end

```

### `core/branch_unit.sv`

```systemverilog
    branch_exception_o.tval2 = {CVA6Cfg.GPLEN{1'b0}};
    branch_exception_o.tinst = '0;
    branch_exception_o.gva   = CVA6Cfg.RVH ? v_i : 1'b0;

```

### `core/cva6.sv`

```systemverilog
  if (CVA6Cfg.CvxifEn) begin
    always_comb begin : gen_cvxif_input_assignment
      x_compressed_ready = cvxif_resp_i.compressed_ready;
      x_compressed_resp  = cvxif_resp_i.compressed_resp;
      x_issue_ready      = cvxif_resp_i.issue_ready;
      x_issue_resp       = cvxif_resp_i.issue_resp;
      x_register_ready   = cvxif_resp_i.register_ready;
      x_result_valid     = cvxif_resp_i.result_valid;
      x_result           = cvxif_resp_i.result;
    end

    always_comb begin : gen_cvxif_output_assignment
      cvxif_req.compressed_valid = x_compressed_valid;
      cvxif_req.compressed_req   = x_compressed_req;
      cvxif_req.issue_valid      = x_issue_valid;
      cvxif_req.issue_req        = x_issue_req;
      cvxif_req.register_valid   = x_register_valid;
      cvxif_req.register         = x_register;
      cvxif_req.commit_valid     = x_commit_valid;
      cvxif_req.commit           = x_commit;
      cvxif_req.result_ready     = x_result_ready;
    end
    assign trans_id_ex_id[X_WB] = x_trans_id_ex_id;
    assign wbdata_ex_id[X_WB]   = x_result_ex_id;
    assign ex_ex_ex_id[X_WB]    = x_exception_ex_id;
    assign wt_valid_ex_id[X_WB] = x_valid_ex_id;

```

### `core/scoreboard.sv`

```systemverilog
        mem_n[trans_id_i[i]].sbe.result = wbdata_i[i];
        // save the target address of a branch (needed for debug in commit stage)
        if (CVA6Cfg.DebugEn) begin
          mem_n[trans_id_i[i]].sbe.bp.predict_address = resolved_branch_i.target_address;
        end
        if (mem_n[trans_id_i[i]].sbe.fu == ariane_pkg::CVXIF) begin
          if (x_we_i) mem_n[trans_id_i[i]].sbe.rd = x_rd_i;
          else mem_n[trans_id_i[i]].sbe.rd = 5'b0;
        end
        // write the exception back if it is valid
        if (ex_i[i].valid || ex_i[i].timing) mem_n[trans_id_i[i]].sbe.ex = ex_i[i];

```

## Documentation

### `docs/source/x_ext.rst`

```text
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | Signal                    | Type            | Direction       | Description                                                                                                                  |
  |                           |                 | (|processor|)   |                                                                                                                              |
  +===========================+=================+=================+==============================================================================================================================+
  | ``result_valid``          | logic           | input           | Result request valid. Indicates that the |coprocessor| has a valid result (write data or exception) for an offloaded         |
  |                           |                 |                 | instruction.                                                                                                                 |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``result_ready``          | logic           | output          | Result request ready. The result signaled via ``result`` is accepted by the |processor| when                                 |
  |                           |                 |                 | ``result_valid`` and  ``result_ready`` are both 1.                                                                           |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``result``                | x_result_t      | input           | Result packet.                                                                                                               |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+

The |coprocessor| shall provide results to the |processor| via the result interface. A |coprocessor| is allowed to provide results to the |processor| in an out of order fashion. A |coprocessor| is only
allowed to provide a result for an instruction once the |processor| has indicated (via the commit interface) that this instruction is allowed to be committed. Each accepted offloaded (committed and not killed) instruction shall
have exactly one result transaction (even if no data needs to be written back to the |processor|'s register file). No result transaction shall be performed for instructions which have not been accepted for offload or
for instructions that have been killed.

:numref:`Result packet type` describes the ``x_result_t`` type.

.. table:: Result packet type
  :name: Result packet type
  :class: no-scrollbar-table
  :widths: 20 20 60

  +---------------+---------------------------------+-----------------------------------------------------------------------------------------------------------------+
  | Signal        | Type                            | Description                                                                                                     |
  +===============+=================================+=================================================================================================================+
  | ``hartid``    | :ref:`hartid_t <hartid>`        | Identification of the hart offloading the instruction.                                                          |
  +---------------+---------------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``id``        | :ref:`id_t <id>`                | Identification of the offloaded instruction.                                                                    |
  +---------------+---------------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``data``      | logic [X_RFW_WIDTH-1:0]         | Register file write data value(s).                                                                              |
  +---------------+---------------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``rd``        | logic [4:0]                     | Register file destination address(es).                                                                          |
  +---------------+---------------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``we``        | :ref:`writeregflags_t           | Register file write enable(s).                                                                                  |
  |               | <writeregflags>`                |                                                                                                                 |
  +---------------+---------------------------------+-----------------------------------------------------------------------------------------------------------------+
...
A result transaction starts in the cycle that ``result_valid`` = 1 and ends in the cycle that both ``result_valid`` = 1 and ``result_ready`` = 1. The signals in ``result`` are
valid when ``result_valid`` is 1. The signals in ``result`` shall remain stable during a result transaction.

```

### `docs/design/design-manual/source/CVX_Interface_Coprocessor.adoc`

```text
* Result interface::
  ** Request;;
    *** [verse]
    --
    Ready signal of result interface is always set as CVA6 is always ready
    to take a result from coprocessor for an accepted offloaded instruction.
    --
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
