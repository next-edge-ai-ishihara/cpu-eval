# Implement `instr_decoder`

Implement the complete `instr_decoder` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module instr_decoder` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

```systemverilog
module instr_decoder #(
    parameter type               copro_issue_resp_t          = logic,
    parameter type               opcode_t                    = logic,
    parameter int                NbInstr                     = 1,
    parameter copro_issue_resp_t CoproInstr        [NbInstr] = {0},
    parameter int unsigned       NrRgprPorts                 = 2,
    parameter type               hartid_t                    = logic,
    parameter type               id_t                        = logic,
    parameter type               x_issue_req_t               = logic,
    parameter type               x_issue_resp_t              = logic,
    parameter type               x_register_t                = logic,
    parameter type               registers_t                 = logic
) (
    input  logic                clk_i,
    input  logic                rst_ni,
    input  logic                issue_valid_i,
    input  x_issue_req_t        issue_req_i,
    output logic                issue_ready_o,
    output x_issue_resp_t       issue_resp_o,
    input  logic                register_valid_i,
    input  x_register_t         register_i,
    output registers_t          registers_o,
    output opcode_t             opcode_o,
    output hartid_t             hartid_o,
    output id_t                 id_o,
    output logic          [4:0] rd_o
);
```

## Parent instantiation

### core/cvxif_example/cvxif_example_coprocessor.sv

```systemverilog
module cvxif_example_coprocessor
  import cvxif_instr_pkg::*;
#(
    // CVXIF Types
    parameter  int unsigned NrRgprPorts         = 2,
    parameter  int unsigned XLEN                = 32,
    parameter  type         readregflags_t      = logic,
    parameter  type         writeregflags_t     = logic,
    parameter  type         id_t                = logic,
    parameter  type         hartid_t            = logic,
    parameter  type         x_compressed_req_t  = logic,
    parameter  type         x_compressed_resp_t = logic,
    parameter  type         x_issue_req_t       = logic,
    parameter  type         x_issue_resp_t      = logic,
    parameter  type         x_register_t        = logic,
    parameter  type         x_commit_t          = logic,
    parameter  type         x_result_t          = logic,
    parameter  type         cvxif_req_t         = logic,
    parameter  type         cvxif_resp_t        = logic,
    localparam type         registers_t         = logic [NrRgprPorts-1:0][XLEN-1:0]
) (
    input  logic        clk_i,        // Clock
    input  logic        rst_ni,       // Asynchronous reset active low
    input  cvxif_req_t  cvxif_req_i,
    output cvxif_resp_t cvxif_resp_o
);

  // Compressed interface signals
  x_compressed_req_t  compressed_req;
  x_compressed_resp_t compressed_resp;
  logic compressed_valid, compressed_ready;
  // Issue interface signals
  x_issue_req_t  issue_req;
  x_issue_resp_t issue_resp;
  logic issue_valid, issue_ready;

  // Register interface signals
  x_register_t register;
  logic register_valid;

  // Decoder and alu signals
  registers_t registers;
  opcode_t opcode;
  hartid_t issue_hartid, hartid;
  id_t issue_id, id;
  logic [4:0] issue_rd, rd;
  logic [XLEN-1:0] result;
  logic            we;

  // Issue and Register interface
  // Mandatory when X_ISSUE_REGISTER_SPLIT = 0
  assign cvxif_resp_o.compressed_ready = compressed_ready;
  assign cvxif_resp_o.compressed_resp  = compressed_resp;
  assign cvxif_resp_o.issue_ready      = issue_ready;
  assign cvxif_resp_o.issue_resp       = issue_resp;
  assign cvxif_resp_o.register_ready   = cvxif_resp_o.issue_ready;

  assign compressed_req                = cvxif_req_i.compressed_req;
  assign compressed_valid              = cvxif_req_i.compressed_valid;
  assign issue_req                     = cvxif_req_i.issue_req;
  assign issue_valid                   = cvxif_req_i.issue_valid;
  assign register                      = cvxif_req_i.register;
  assign register_valid                = cvxif_req_i.register_valid;
// ...
  instr_decoder #(
      .copro_issue_resp_t (cvxif_instr_pkg::copro_issue_resp_t),
      .opcode_t (cvxif_instr_pkg::opcode_t),
      .NbInstr   (cvxif_instr_pkg::NbInstr),
      .CoproInstr(cvxif_instr_pkg::CoproInstr),
      .NrRgprPorts(NrRgprPorts),
      .hartid_t (hartid_t),
      .id_t (id_t),
      .x_issue_req_t (x_issue_req_t),
      .x_issue_resp_t (x_issue_resp_t),
      .x_register_t (x_register_t),
      .registers_t (registers_t)
  ) instr_decoder_i (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .issue_valid_i   (issue_valid),
      .issue_req_i     (issue_req),
      .issue_ready_o   (issue_ready),
      .issue_resp_o    (issue_resp),
      .register_valid_i(register_valid),
      .register_i      (register),
      .registers_o     (registers),
      .opcode_o        (opcode),
      .hartid_o        (issue_hartid),
      .id_o            (issue_id),
      .rd_o            (issue_rd)
  );
```

## Dependency declarations

### core/cvxif_example/include/cvxif_instr_pkg.sv

```systemverilog
  typedef enum logic [3:0] {
    ILLEGAL = 4'b0000,
    NOP = 4'b0001,
    ADD = 4'b0010,
    DOUBLE_RS1 = 4'b0011,
    DOUBLE_RS2 = 4'b0100,
    ADD_MULTI = 4'b0101,
    MADD_RS3_R4 = 4'b0110,
    MSUB_RS3_R4 = 4'b0111,
    NMADD_RS3_R4 = 4'b1000,
    NMSUB_RS3_R4 = 4'b1001,
    ADD_RS3_R = 4'b1111
  } opcode_t;


  typedef struct packed {
    logic accept;
    logic writeback;  // TODO depends on dualwrite
    logic [2:0] register_read;  // TODO Nr read ports
  } issue_resp_t;

  typedef struct packed {
    logic        accept;
    logic [31:0] instr;
  } compressed_resp_t;

  typedef struct packed {
    logic [31:0] instr;
    logic [31:0] mask;
    issue_resp_t resp;
    opcode_t     opcode;
  } copro_issue_resp_t;
// ...
  // 4 Possible RISCV instructions for Coprocessor
  parameter int unsigned NbInstr = 10;
  parameter copro_issue_resp_t CoproInstr[NbInstr] = '{
      '{
          // Custom Nop
          instr:
          32'b00000_00_00000_00000_0_00_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b0, register_read : {1'b0, 1'b0, 1'b0}},
          opcode : NOP
      },
      '{
          // Custom Add : cus_add rd, rs1, rs2
          instr:
          32'b00000_00_00000_00000_0_01_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode : ADD
      },
      '{
          // Custom Add rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_01_00000_00000_0_01_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b0, 1'b1}},
          opcode : DOUBLE_RS1
      },
      '{
          // Custom Add rs2 : cus_add rd, rs2, rs2
          instr:
          32'b00000_10_00000_00000_0_01_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b0}},
          opcode : DOUBLE_RS2
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_11_00000_00000_0_01_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode : ADD_MULTI
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00001_00_00000_00000_0_01_00000_1111011,  // custom3 opcode
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b1, 1'b1, 1'b1}},
          opcode : ADD_RS3_R
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_00_00000_00000_0_00_00000_1000011,  // MADD opcode
          mask: 32'b00000_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b1, 1'b1, 1'b1}},
          opcode : MADD_RS3_R4
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_00_00000_00000_0_00_00000_1000111,  // MSUB opcode
          mask: 32'b00000_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b1, 1'b1, 1'b1}},
          opcode : MSUB_RS3_R4
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_00_00000_00000_0_00_00000_1001011,  // NMSUB opcode
          mask: 32'b00000_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b1, 1'b1, 1'b1}},
          opcode : NMSUB_RS3_R4
      },
      '{
          // Custom Add Multi rs1 : cus_add rd, rs1, rs1
          instr:
          32'b00000_00_00000_00000_0_00_00000_1001111,  // NMADD opcode
          mask: 32'b00000_11_00000_00000_1_11_00000_1111111,
          resp : '{accept : 1'b1, writeback : 1'b1, register_read : {1'b1, 1'b1, 1'b1}},
          opcode : NMADD_RS3_R4
      }
  };
```

### core/include/cvxif_types.svh

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
```

## Documentation

### docs/source/x_ext.rst

```text
Issue interface
~~~~~~~~~~~~~~~
:numref:`Issue interface signals` describes the issue interface signals.

.. table:: Issue interface signals
  :name: Issue interface signals
  :class: no-scrollbar-table
  :widths: 20 20 10 50

  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | Signal                    | Type            | Direction       | Description                                                                                                                  |
  |                           |                 | (|processor|)   |                                                                                                                              |
  +===========================+=================+=================+==============================================================================================================================+
  | ``issue_valid``           | logic           | output          | Issue request valid. Indicates that |processor| wants to offload an instruction.                                             |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``issue_ready``           | logic           | input           | Issue request ready. The transaction signaled via ``issue_req`` and ``issue_resp`` is accepted when                          |
  |                           |                 |                 | ``issue_valid`` and  ``issue_ready`` are both 1.                                                                             |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``issue_req``             | x_issue_req_t   | output          | Issue request packet.                                                                                                        |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``issue_resp``            | x_issue_resp_t  | input           | Issue response packet.                                                                                                       |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+

:numref:`Issue request type` describes the ``x_issue_req_t`` type.

.. table:: Issue request type
  :name: Issue request type
  :class: no-scrollbar-table
  :widths: 20 20 60

  +------------------------+----------------------------------------+-----------------------------------------------------------------------------------------------------------------+
  | Signal                 | Type                                   | Description                                                                                                     |
  +========================+========================================+=================================================================================================================+
  | ``instr``              | logic [31:0]                           | Offloaded instruction.                                                                                          |
  +------------------------+----------------------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``hartid``             | :ref:`hartid_t <hartid>`               | Identification of the hart offloading the instruction.                                                          |
  +------------------------+----------------------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``id``                 | :ref:`id_t <id>`                       | Identification of the offloaded instruction.                                                                    |
  |                        |                                        |                                                                                                                 |
  |                        |                                        |                                                                                                                 |
  +------------------------+----------------------------------------+-----------------------------------------------------------------------------------------------------------------+

An issue request transaction is defined as the combination of all ``issue_req`` signals during which ``issue_valid`` is 1, and the ``id`` and ``hartid`` remain unchanged.
A |processor| is allowed to retract its issue request transaction before it is accepted with ``issue_ready`` = 1 and it can do so in the following ways:

* Set ``issue_valid`` = 0.
* Keep ``issue_valid`` = 1, but change the ``id`` or ``hartid`` signal (and if desired change the other signals in ``issue_req``).

The ``instr``, ``hartid``, and ``id`` signals are valid when ``issue_valid`` is 1.
...
:numref:`Issue response type` describes the ``x_issue_resp_t`` type.

.. table:: Issue response type
  :name: Issue response type
  :class: no-scrollbar-table
  :widths: 20 20 60

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
  | ``register_read``      | :ref:`readregflags_t   | Will the |coprocessor| perform require specific registers to be read?                                            |
  |                        | <readregflags>`        | A |coprocessor| may only request an odd register of a pair, if it also requests the even register of a pair.     |
  +------------------------+------------------------+------------------------------------------------------------------------------------------------------------------+
...
The |processor| shall attempt to offload instructions via the issue interface for the following two main scenarios:

* The instruction is originally non-compressed and it is not recognized as a valid instruction by the |processor|'s non-compressed instruction decoder.
* The instruction is originally compressed and the |coprocessor| accepted the compressed instruction and provided a 32-bit uncompressed instruction.
  In this case the 32-bit uncompressed instruction will be attempted for offload even if it matches in the |processor|'s non-compressed instruction decoder.

Apart from the above two main scenarios a |processor| may also attempt to offload
(compressed/uncompressed) instructions that it does recognize as legal instructions itself. In case that both the |processor| and the |coprocessor| accept the same instruction as being valid,
the instruction will cause an illegal instruction fault upon execution.

In all cases, the |processor| must decode the instruction.
The |processor| shall cause an illegal instruction fault when attempting to execute (commit) an instruction that:

* is considered to be valid by the |processor| and accepted by the |coprocessor| (``accept`` = 1).
* is considered neither to be valid by the |processor| nor accepted by the |coprocessor| (``accept`` = 0).

A |coprocessor| can delay accept accepting an instruction via ``issue_ready`` in the presence of structural hazards that would prevent execution.
A |coprocessor| can (only) accept an offloaded instruction when it can handle the instruction (based on decoding ``instr``).

A transaction is considered offloaded/accepted on the positive edge of ``clk`` when ``issue_valid``, ``issue_ready`` are asserted and ``accept`` is 1.
A transaction is considered not offloaded/rejected on the positive edge of ``clk`` when ``issue_valid`` and ``issue_ready`` are asserted while ``accept`` is 0.

The signals in ``issue_resp`` are valid when ``issue_valid`` and ``issue_ready`` are both 1. There are no stability requirements.
...
Register interface
~~~~~~~~~~~~~~~~~~
:numref:`Register interface signals` describes the register interface signals.

.. table:: Register interface signals
  :name: Register interface signals
  :class: no-scrollbar-table
  :widths: 20 20 10 50

  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | Signal                    | Type            | Direction       | Description                                                                                                                  |
  |                           |                 | (|processor|)   |                                                                                                                              |
  +===========================+=================+=================+==============================================================================================================================+
  | ``register_valid``        | logic           | output          | Register request valid. Indicates that |processor| provides register contents related to an instruction.                     |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``register_ready``        | logic           | input           | Register request ready. The transaction signaled via ``register_req`` is accepted when                                       |
  |                           |                 |                 | ``register_valid`` and  ``register_ready`` are both 1.                                                                       |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``register``              | x_register_t    | output          | Register packet.                                                                                                             |
  +---------------------------+-----------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+

:numref:`Register type` describes the ``x_register_t`` type.

.. table:: Register type
  :name: Register type
  :class: no-scrollbar-table
  :widths: 20 20 60

  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+
  | Signal                 | Type                     | Description                                                                                                     |
  +========================+==========================+=================================================================================================================+
  | ``hartid``             | :ref:`hartid_t <hartid>` | Identification of the hart offloading the instruction.                                                          |
  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``id``                 | :ref:`id_t <id>`         | Identification of the offloaded instruction.                                                                    |
  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``rs[X_NUM_RS-1:0]``   | logic [X_RFR_WIDTH-1:0]  | Register file source operands for the offloaded instruction.                                                    |
  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``rs_valid``           | :ref:`readregflags_t     | Validity of the register file source operand(s). If register pairs are supported, the validity is signaled for  |
  |                        | <readregflags>`          | each register within the pair individually.                                                                     |
  +------------------------+--------------------------+-----------------------------------------------------------------------------------------------------------------+

...
There are two main scenarios, in how the register interface will be used. They are selected by ``X_ISSUE_REGISTER_SPLIT``:

1. ``X_ISSUE_REGISTER_SPLIT`` = 0: A register transaction can be started in the same clock cycle as the issue transaction (``issue_valid = register_valid``, ``issue_ready = register_ready``, ``issue_req.hartid = register.hartid`` and ``issue_req.id = register.id``).
   In this case, the |processor| will speculatively provide all possible source registers via ``register.rs`` when they become available (signalled via the respective ``rs_valid`` signals).
   The |coprocessor| will delay accepting the instruction until all necessary registers are provided, and only then assert ``issue_ready`` and ``register_ready``.
   The ``rs_valid`` bits are not required to be stable during the transaction.
   Each bit can transition from 0 to 1, but is not allowed to transition back to 0 during a transaction.
   A |coprocessor| is not expected to wait for all ``rs_valid`` bits to be 1, but only for those registers it intends to read.
   The ``rs`` signals are only required to be stable during the part of a transaction in which these signals are considered to be valid.
```

### docs/design/design-manual/source/CVX_Interface_Coprocessor.adoc

```text
* Issue interface::
  ** Request;;
    *** [verse]
    --
    Operands are connected to `issue_req.rs` signals
    --
    *** [verse]
    --
    Scoreboard transaction id is connected to `issue_req.id` signal.
    Therefore scoreboard ids and offloaded instruction ids are linked
    together (equal in this implementation). It allows the CVA6 to do out
    of order execution with the coprocessor in the same way as other
    functional units.
    --
    *** [verse]
    --
    Undecoded instruction is connected to `issue_req.instruction`
    --
    *** [verse]
    --
    Valid signal for CVXIF functional unit is connected to
    `issue_req.valid`
    --
    *** [verse]
    --
    All `issue_req.rs_valid` signals are set to 1. The validity of source
    registers is assured by the validity of valid signal sent from issue stage.
    --
  ** Response;;
    *** [verse]
    --
    If `issue_resp.accept` is set during a transaction (i.e. issue valid
    and ready are set), the offloaded instruction is accepted by the coprocessor
    and a result transaction will happen.
    --
    *** [verse]
    --
    If `issue_resp.accept` is not set during a transaction, the offloaded
    instruction is illegal and an illegal instruction exception will be
    raised as soon as no result transaction are written on the writeback bus.
    --
```
