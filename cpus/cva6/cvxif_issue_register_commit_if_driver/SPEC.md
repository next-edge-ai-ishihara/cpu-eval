# Implement `cvxif_issue_register_commit_if_driver`

Implement the complete `cvxif_issue_register_commit_if_driver` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module cvxif_issue_register_commit_if_driver` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
module cvxif_issue_register_commit_if_driver #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type x_issue_req_t = logic,
    parameter type x_issue_resp_t = logic,
    parameter type x_register_t = logic,
    parameter type x_commit_t = logic
) (
    // CVA6 inputs
    input logic clk_i,
    input logic rst_ni,
    input logic flush_i,
    input logic [CVA6Cfg.XLEN-1:0] hart_id_i,
    // CVXIF Issue interface
    input logic issue_ready_i,
    input x_issue_resp_t issue_resp_i,
    output logic issue_valid_o,
    output x_issue_req_t issue_req_o,
    // CVXIF Register interface
    input logic register_ready_i,
    output logic register_valid_o,
    output x_register_t register_o,
    // CVXIF Commit interface
    output logic commit_valid_o,
    output x_commit_t commit_o,
    // IRO in/out
    input logic valid_i,
    input logic [31:0] x_off_instr_i,
    input logic [CVA6Cfg.TRANS_ID_BITS-1:0] x_trans_id_i,
    input [(CVA6Cfg.NrRgprPorts/CVA6Cfg.NrIssuePorts)-1:0][CVA6Cfg.XLEN-1:0] register_i,
    input logic [(CVA6Cfg.NrRgprPorts/CVA6Cfg.NrIssuePorts)-1:0] rs_valid_i
);

```

## Parent instantiation

### `core/issue_read_operands.sv`

```systemverilog
  // CVXIF Signals
  logic cvxif_req_allowed;
  logic x_transaction_rejected, x_transaction_rejected_n;
  logic [OPERANDS_PER_INSTR-1:0] rs_valid;
  logic [OPERANDS_PER_INSTR-1:0][CVA6Cfg.XLEN-1:0] rs;

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
      .x_trans_id_i    (issue_instr_i[0].trans_id),
      .register_i      (rs),
      .rs_valid_i      (rs_valid)
  );
  if (OPERANDS_PER_INSTR == 3) begin
    assign rs_valid = {~stall_rs3[0], ~stall_rs2[0], ~stall_rs1[0]};
    assign rs = {fu_data_n[0].imm, fu_data_n[0].operand_b, fu_data_n[0].operand_a};
  end else begin
    assign rs_valid = {~stall_rs2[0], ~stall_rs1[0]};
    assign rs = {fu_data_n[0].operand_b, fu_data_n[0].operand_a};
  end

  // TODO check only for 1st instruction ??
  // Allow a cvxif transaction if we WaW condition are ok.
  assign cvxif_req_allowed = (issue_instr_i[0].fu == CVXIF);
  assign cvxif_instruction_valid = !issue_instr_i[0].ex.valid && issue_instr_valid_i[0] && cvxif_req_allowed;
  assign x_transaction_accepted_o = x_issue_valid_o && x_issue_ready_i && x_issue_resp_i.accept;
  assign x_transaction_rejected = x_issue_valid_o && x_issue_ready_i && ~x_issue_resp_i.accept;
  assign x_issue_writeback_o = x_issue_resp_i.writeback;
  assign x_id_o = x_issue_req_o.id;

```

## Dependency declarations

### `core/include/cvxif_types.svh`

```systemverilog
`define X_ISSUE_REQ_T(Cfg, hartid_t, id_t) struct packed { \
    logic [31:0] instr; /*Offloaded instruction*/ \
    hartid_t hartid; /*Identification of the hart offloading the instruction*/ \
    id_t id; /*Identification of the offloaded instruction*/ \
}
`define X_ISSUE_RESP_T(Cfg, writeregflags_t, readregflags_t) struct packed { \
    logic accept; /*Is the offloaded instruction (id) accepted by the coprocessor?*/ \
    writeregflags_t writeback; /*Will the coprocessor perform a writeback in the core to rd?*/ \
    readregflags_t register_read; /*Will the coprocessor perform require specific registers to be read?*/ \
}

`define X_REGISTER_T(Cfg, hartid_t, id_t, readregflags_t) struct packed { \
    hartid_t hartid;  /*Identification of the hart offloading the instruction*/ \
    id_t id;  /*Identification of the offloaded instruction*/ \
    logic [Cfg.X_NUM_RS-1:0][Cfg.X_RFR_WIDTH-1:0] rs;  /*Register file source operands for the offloaded instruction.*/ \
    readregflags_t rs_valid; /*Validity of the register file source operand(s).*/ \
}

`define X_COMMIT_T(Cfg, hartid_t, id_t) struct packed { \
    hartid_t hartid;  /*Identification of the hart offloading the instruction*/ \
    id_t id;  /*Identification of the offloaded instruction*/ \
    logic commit_kill;  /*Shall an offloaded instruction be killed?*/ \
}

```

## Related source code

### `core/cvxif_example/cvxif_example_coprocessor.sv`

```systemverilog
  assign cvxif_resp_o.issue_ready      = issue_ready;
  assign cvxif_resp_o.issue_resp       = issue_resp;
  assign cvxif_resp_o.register_ready   = cvxif_resp_o.issue_ready;
// ...
  assign issue_req                     = cvxif_req_i.issue_req;
  assign issue_valid                   = cvxif_req_i.issue_valid;
  assign register                      = cvxif_req_i.register;
  assign register_valid                = cvxif_req_i.register_valid;

```

## Documentation

### `docs/source/x_ext.rst`

```text
An issue request transaction is defined as the combination of all ``issue_req`` signals during which ``issue_valid`` is 1, and the ``id`` and ``hartid`` remain unchanged.
A |processor| is allowed to retract its issue request transaction before it is accepted with ``issue_ready`` = 1 and it can do so in the following ways:

* Set ``issue_valid`` = 0.
* Keep ``issue_valid`` = 1, but change the ``id`` or ``hartid`` signal (and if desired change the other signals in ``issue_req``).

The ``instr``, ``hartid``, and ``id`` signals are valid when ``issue_valid`` is 1.
...
A transaction is considered offloaded/accepted on the positive edge of ``clk`` when ``issue_valid``, ``issue_ready`` are asserted and ``accept`` is 1.
A transaction is considered not offloaded/rejected on the positive edge of ``clk`` when ``issue_valid`` and ``issue_ready`` are asserted while ``accept`` is 0.

The signals in ``issue_resp`` are valid when ``issue_valid`` and ``issue_ready`` are both 1. There are no stability requirements.
...
There are two main scenarios, in how the register interface will be used. They are selected by ``X_ISSUE_REGISTER_SPLIT``:

1. ``X_ISSUE_REGISTER_SPLIT`` = 0: A register transaction can be started in the same clock cycle as the issue transaction (``issue_valid = register_valid``, ``issue_ready = register_ready``, ``issue_req.hartid = register.hartid`` and ``issue_req.id = register.id``).
   In this case, the |processor| will speculatively provide all possible source registers via ``register.rs`` when they become available (signalled via the respective ``rs_valid`` signals).
   The |coprocessor| will delay accepting the instruction until all necessary registers are provided, and only then assert ``issue_ready`` and ``register_ready``.
   The ``rs_valid`` bits are not required to be stable during the transaction.
   Each bit can transition from 0 to 1, but is not allowed to transition back to 0 during a transaction.
   A |coprocessor| is not expected to wait for all ``rs_valid`` bits to be 1, but only for those registers it intends to read.
   The ``rs`` signals are only required to be stable during the part of a transaction in which these signals are considered to be valid.
...
In both scenarios, the following applies:

A register transaction is defined as the combination of all ``register`` signals during which ``register_valid`` is 1, and the ``id`` and ``hartid`` remain unchanged.
A |processor| is allowed to retract its register transaction before it is accepted with ``register_ready`` = 1 and it can do so in the following ways:

* Set ``register_valid`` = 0.
* Keep ``register_valid`` = 1, but change the ``id`` or ``hartid`` signal (and if desired change the other signals in ``register``).

The ``hartid``, ``id``, and ``rs_valid`` signals are valid when ``register_valid`` is 1.
The ``rs`` signal is only considered valid when ``register_valid`` is 1 and the corresponding bit in ``rs_valid`` is 1 as well.
...
  | ``commit_valid``          | logic           | output          | Commit request valid. Indicates that |processor| has valid commit or kill information for an offloaded instruction.          |
  |                           |                 |                 | There is no corresponding ready signal (it is implicit and assumed 1). The |coprocessor| shall be ready                      |
  |                           |                 |                 | to observe the ``commit_valid`` and ``commit_kill`` signals at any time coincident or after an issue transaction             |
  |                           |                 |                 | initiation.                                                                                                                  |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``commit``                | x_commit_t      | output          | Commit packet.                                                                                                               |
...
  | ``hartid``         | :ref:`hartid_t <hartid>` | Identification of the hart offloading the instruction.                                                                       |
  +--------------------+--------------------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``id``             | :ref:`id_t <id>`         | Identification of the offloaded instruction. Valid when ``commit_valid`` is 1.                                               |
  +--------------------+--------------------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``commit_kill``    | logic                    | If ``commit_valid`` is 1 and ``commit_kill`` is 0,  then the |processor| guarantees that the offloaded instruction (``id``)  |
  |                    |                          | and any older (i.e. preceding) instructions are no longer speculative, will not get killed (e.g. due to misspeculation or an |
  |                    |                          | exception in a preceding instruction), and are allowed to be committed.                                                      |
  |                    |                          | If ``commit_valid`` is 1 and ``commit_kill`` is 1, then the offloaded instruction (``id``) and any newer (i.e. succeeding)   |
  |                    |                          | instructions shall be killed in the |coprocessor| and the |coprocessor| must guarantee that the related instructions do/did  |
  |                    |                          | not change architectural state.                                                                                              |
  |                    |                          | The taken action only applies to instructions offloaded with the specified ``hartid``.                                       |
  +--------------------+--------------------------+------------------------------------------------------------------------------------------------------------------------------+

The ``commit_valid`` signal will be 1 exactly one ``clk`` cycle.
...
A |processor| is required to mark every instruction that has completed the issue transaction as either killed or non-speculative.
This includes accepted (``issue_resp.accept`` = 1) and rejected instructions (``issue_resp.accept`` = 0).

```

### `docs/design/design-manual/source/CVX_Interface_Coprocessor.adoc`

```text
  ** [verse]
  --
  Id signal of commit interface is connected to issue interface id signal
  (i.e. scoreboard id).
  --
  ** [verse]
  --
  Killing of offload instruction is never set. (Unsupported feature)
  --
  ** [verse]
  --
  Therefore all accepted offloaded instructions are commited to their
  execution and no killing of instruction is possible in this implementation.
  --

```
