# Implement `cvxif_compressed_if_driver`

Implement the complete `cvxif_compressed_if_driver` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module cvxif_compressed_if_driver` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
module cvxif_compressed_if_driver #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type x_compressed_req_t = logic,
    parameter type x_compressed_resp_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic                    clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic                    rst_ni,
    input logic                    flush_i,
    // CVA6 Hart id
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,

    input logic        is_compressed_i,
    input logic        is_illegal_i,
    input logic [31:0] instruction_i,

    output logic                      is_compressed_o,
    output logic                      is_illegal_o,
    output logic               [31:0] instruction_o,
    input  logic                      stall_i,
    output logic                      stall_o,
    // CVXIF Compressed interface
    input  logic                      compressed_ready_i,
    input  x_compressed_resp_t        compressed_resp_i,
    output logic                      compressed_valid_o,
    output x_compressed_req_t         compressed_req_o
);

```

## Parent instantiation

### `core/id_stage.sv`

```systemverilog
    if (CVA6Cfg.RVZCMT) begin
      assign instruction_cvxif_i = is_zcmt_instr[0] ? instruction_zcmt : instruction_zcmp;
      assign is_illegal_cvxif_i = is_zcmt_instr[0] ? is_illegal_zcmt : is_illegal_zcmp;
      assign is_compressed_cvxif_i = is_zcmt_instr[0] ? is_compressed_zcmt : is_compressed_zcmp;
      assign stall_macro_deco = is_zcmt_instr[0] ? stall_macro_deco_zcmt : stall_macro_deco_zcmp;
    end else begin  // Do not instantiate the mux which is not optimized cross-boundaries
      assign instruction_cvxif_i = instruction_zcmp;
      assign is_illegal_cvxif_i = is_illegal_zcmp;
      assign is_compressed_cvxif_i = is_compressed_zcmp;
      assign stall_macro_deco = stall_macro_deco_zcmp;
    end

    if (CVA6Cfg.CvxifEn) begin
      cvxif_compressed_if_driver #(
          .CVA6Cfg(CVA6Cfg),
          .x_compressed_req_t(x_compressed_req_t),
          .x_compressed_resp_t(x_compressed_resp_t)
      ) i_cvxif_compressed_if_driver_i (
          .clk_i             (clk_i),
          .rst_ni            (rst_ni),
          .flush_i           (flush_i),
          .hart_id_i         (hart_id_i),
          .is_compressed_i   (is_compressed_cvxif_i),
          .is_illegal_i      (is_illegal_cvxif_i),
          .instruction_i     (instruction_cvxif_i),
          .is_compressed_o   (is_compressed_cvxif_o),
          .is_illegal_o      (is_illegal_cvxif_o),
          .instruction_o     (instruction_cvxif_o),
          .stall_i           (stall_macro_deco),
          .stall_o           (stall_instr_fetch[0]),
          .compressed_ready_i(compressed_ready_i),
          .compressed_resp_i (compressed_resp_i),
          .compressed_valid_o(compressed_valid_o),
          .compressed_req_o  (compressed_req_o)
      );
    end else begin
      assign stall_instr_fetch[0] = stall_macro_deco;
    end
// ...
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
// ...
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
// ...
        .instruction_o             (decoded_instruction[i]),
        .orig_instr_o              (orig_instr[i]),
        .is_control_flow_instr_o   (is_control_flow_instr[i]),
        .sdtrig_decoder_action_i   (sdtrig_decoder_action_i[i])
    );
  end
// ...
      // instruction is not valid if we stall due to ZCMT or CVXIF
      decoded_instruction_valid[0] = (CVA6Cfg.RVZCMT && is_zcmt_instr[0] && stall_macro_deco_zcmt) ||
                                     (CVA6Cfg.CvxifEn && is_illegal_cvxif_i && ~stall_macro_deco && stall_instr_fetch[0])
                                     ? 1'b0 : 1'b1;
// ...
      if (!issue_n[0].valid && fetch_entry_valid_i[0]) begin
        fetch_entry_ready_o[0] = ~stall_instr_fetch[0];
        issue_n[0] = '{
            decoded_instruction_valid[0],
            decoded_instruction[0],
            orig_instr[0],
            is_control_flow_instr[0]
        };
      end
// ...
      // invalidate the pipeline register on a flush
      if (flush_i) issue_n[0].valid = 1'b0;

```

## Dependency declarations

### `core/cva6.sv`

```systemverilog
    parameter type hartid_t = `HARTID_T(CVA6Cfg),
    parameter type x_compressed_req_t = `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t),
    parameter type x_compressed_resp_t = `X_COMPRESSED_RESP_T(CVA6Cfg),

```

### `core/include/cvxif_types.svh`

```systemverilog
`define HARTID_T(Cfg) logic [Cfg.X_HARTID_WIDTH-1:0]
// ...
`define X_COMPRESSED_REQ_T(Cfg, hartid_t) struct packed { \
    logic [15:0] instr; /*Offloaded compressed instruction*/ \
    hartid_t     hartid;  /*Identification of the hart offloading the instruction*/ \
}
`define X_COMPRESSED_RESP_T(Cfg) struct packed { \
    logic [31:0] instr; /*Uncompressed instruction*/ \
    logic accept; /*Is the offloaded compressed instruction (id) accepted by the coprocessor?*/ \
}

`define X_ISSUE_REQ_T(Cfg, hartid_t, id_t) struct packed { \
    logic [31:0] instr; /*Offloaded instruction*/ \
    hartid_t hartid; /*Identification of the hart offloading the instruction*/ \
    id_t id; /*Identification of the offloaded instruction*/ \
}

```

### `core/include/build_config_pkg.sv`

```systemverilog
    cfg.X_HARTID_WIDTH = cfg.XLEN;

```

## Related source code

### `core/decoder.sv`

```systemverilog
      // if we didn't already get an exception save the instruction here as we may need it
      // in the commit stage if we got a access exception to one of the CSR registers
      if (CVA6Cfg.CvxifEn || CVA6Cfg.RVF || CVA6Cfg.ZKN)
        orig_instr_o = (is_compressed_i) ? {{CVA6Cfg.XLEN-16{1'b0}}, compressed_instr_i} : {{CVA6Cfg.XLEN-32{1'b0}}, instruction_i};

```

### `core/issue_read_operands.sv`

```systemverilog
  cvxif_issue_register_commit_if_driver #(
      .CVA6Cfg       (CVA6Cfg),
      .x_issue_req_t (x_issue_req_t),
      .x_issue_resp_t(x_issue_resp_t),
      .x_register_t  (x_register_t),
      .x_commit_t    (x_commit_t)
  ) i_cvxif_issue_register_commit_if_driver (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .flush_i         (flush_i),
      .hart_id_i       (hart_id_i),
      .issue_ready_i   (x_issue_ready_i),
      .issue_resp_i    (x_issue_resp_i),
      .issue_valid_o   (x_issue_valid_o),
      .issue_req_o     (x_issue_req_o),
      .register_ready_i(x_register_ready_i),
      .register_valid_o(x_register_valid_o),
      .register_o      (x_register_o),
      .commit_valid_o  (x_commit_valid_o),
      .commit_o        (x_commit_o),
      .valid_i         (cvxif_instruction_valid),
      .x_off_instr_i   (orig_instr_i[0]),

```

### `core/cvxif_example/compressed_instr_decoder.sv`

```systemverilog
module compressed_instr_decoder #(
    parameter type                    copro_compressed_resp_t          = logic,
    parameter int                     NbInstr                          = 1,
    parameter copro_compressed_resp_t CoproInstr             [NbInstr] = {0},
    parameter type                    x_compressed_req_t               = logic,
    parameter type                    x_compressed_resp_t              = logic
) (
    input  logic               clk_i,
    input  logic               rst_ni,
    input  logic               compressed_valid_i,
    input  x_compressed_req_t  compressed_req_i,
    output logic               compressed_ready_o,
    output x_compressed_resp_t compressed_resp_o
);

```

## Documentation

### `docs/source/x_ext.rst`

```text
Compressed interface
~~~~~~~~~~~~~~~~~~~~
:numref:`Compressed interface signals` describes the compressed interface signals.

.. table:: Compressed interface signals
  :name: Compressed interface signals
  :class: no-scrollbar-table
  :widths: 20 20 10 50

  +---------------------------+---------------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | Signal                    | Type                | Direction       | Description                                                                                                                  |
  |                           |                     | (|processor|)   |                                                                                                                              |
  +===========================+=====================+=================+==============================================================================================================================+
  | ``compressed_valid``      | logic               | output          | Compressed request valid. Request to uncompress a compressed instruction.                                                    |
  +---------------------------+---------------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``compressed_ready``      | logic               | input           | Compressed request ready. The transactions signaled via ``compressed_req`` and ``compressed_resp`` are accepted when         |
  |                           |                     |                 | ``compressed_valid`` and  ``compressed_ready`` are both 1.                                                                   |
  +---------------------------+---------------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``compressed_req``        | x_compressed_req_t  | output          | Compressed request packet.                                                                                                   |
  +---------------------------+---------------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``compressed_resp``       | x_compressed_resp_t | input           | Compressed response packet.                                                                                                  |
  +---------------------------+---------------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+

:numref:`Compressed request type` describes the ``x_compressed_req_t`` type.

.. table:: Compressed request type
  :name: Compressed request type
  :class: no-scrollbar-table
  :widths: 20 20 60

  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+
  | Signal                 | Type                     | Description                                                                                                     |
  +========================+==========================+=================================================================================================================+
  | ``instr``              | logic [15:0]             | Offloaded compressed instruction.                                                                               |
  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``hartid``             | :ref:`hartid_t <hartid>` | Identification of the hart offloading the instruction.                                                          |
  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+

The ``instr[15:0]`` signal is used to signal compressed instructions that are considered illegal by |processor| itself. A |coprocessor| can provide an uncompressed instruction
in response to receiving this.
...
A compressed request transaction is defined as the combination of all ``compressed_req`` signals during which ``compressed_valid`` is 1 and ``compressed_req`` remains unchanged.
A |processor| is allowed to retract its compressed request transaction before it is accepted with ``compressed_ready`` = 1 and it can do so in the following ways:

* Set ``compressed_valid`` = 0.
* Keep ``compressed_valid`` = 1, but change any of the signals in ``compressed_req``.

The signals in ``compressed_req`` are valid when ``compressed_valid`` is 1. These signals remain stable during a compressed request transaction.

:numref:`Compressed response type` describes the ``x_compressed_resp_t`` type.

.. table:: Compressed response type
  :name: Compressed response type
  :class: no-scrollbar-table
  :widths: 20 20 60

  +------------------------+----------------------+-----------------------------------------------------------------------------------------------------------------+
  | Signal                 | Type                 | Description                                                                                                     |
  +========================+======================+=================================================================================================================+
  | ``instr``              | logic [31:0]         | Uncompressed instruction.                                                                                       |
  +------------------------+----------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``accept``             | logic                | Is the offloaded compressed instruction (``id``) accepted by the |coprocessor|?                                 |
  +------------------------+----------------------+-----------------------------------------------------------------------------------------------------------------+

The signals in ``compressed_resp`` are valid when ``compressed_valid`` and ``compressed_ready`` are both 1. There are no stability requirements.

The |processor| will attempt to offload every compressed instruction that it does not recognize as a legal instruction itself. A |processor| might also attempt to offload
compressed instructions that it does recognize as legal instructions itself.

A |coprocessor| may only accept valid 16-bit instructions, i.e. bits ``[1:0]`` must not be binary 11.

The |processor| shall cause an illegal instruction fault when attempting to execute (commit) an instruction that:

* is considered to be valid by the |processor| and accepted by the |coprocessor| (``accept`` = 1).
* is considered neither to be valid by the |processor| nor accepted by the |coprocessor| (``accept`` = 0).

The ``accept`` signal of the *compressed* interface merely indicates that the |coprocessor| accepts the compressed instruction as an instruction that it implements and translates into
its uncompressed counterpart.
Typically an accepted transaction over the compressed interface will be followed by a corresponding transaction over the issue interface, but there is no requirement
on the |processor| to do so (as the instructions offloaded over the compressed interface and issue interface are allowed to be speculative). Only when an ``accept``
is signaled over the *issue* interface, then an instruction is considered *accepted for offload*.

Explicitly, the |coprocessor| shall not execute the instruction after receiving it via the compressed interface.

```
