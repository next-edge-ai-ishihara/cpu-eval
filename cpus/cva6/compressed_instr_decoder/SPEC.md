# Implement `compressed_instr_decoder`

Implement the complete `compressed_instr_decoder` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module compressed_instr_decoder` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

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

## Parent instantiation

```systemverilog
  compressed_instr_decoder #(
      .copro_compressed_resp_t(cvxif_instr_pkg::copro_compressed_resp_t),
      .NbInstr(cvxif_instr_pkg::NbCompInstr),
      .CoproInstr(cvxif_instr_pkg::CoproCompInstr),
      .x_compressed_req_t(x_compressed_req_t),
      .x_compressed_resp_t(x_compressed_resp_t)
  ) compressed_instr_decoder_i (
      .clk_i             (clk_i),
      .rst_ni            (rst_ni),
      .compressed_valid_i(compressed_valid),
      .compressed_req_i  (compressed_req),
      .compressed_ready_o(compressed_ready),
      .compressed_resp_o (compressed_resp)
  );
```

## Dependency declarations

### core/include/cvxif_types.svh

```systemverilog
`define X_COMPRESSED_REQ_T(Cfg, hartid_t) struct packed { \
    logic [15:0] instr; /*Offloaded compressed instruction*/ \
    hartid_t     hartid;  /*Identification of the hart offloading the instruction*/ \
}
`define X_COMPRESSED_RESP_T(Cfg) struct packed { \
    logic [31:0] instr; /*Uncompressed instruction*/ \
    logic accept; /*Is the offloaded compressed instruction (id) accepted by the coprocessor?*/ \
}
```

### core/cvxif_example/include/cvxif_instr_pkg.sv

```systemverilog
  typedef struct packed {
    logic        accept;
    logic [31:0] instr;
  } compressed_resp_t;

// ...

  typedef struct packed {
    logic [15:0]      instr;
    logic [15:0]      mask;
    compressed_resp_t resp;
  } copro_compressed_resp_t;

// ...

  parameter int unsigned NbCompInstr = 2;
  parameter copro_compressed_resp_t CoproCompInstr[NbCompInstr] = '{
      // C_NOP
      '{
          instr : 16'b111_0_00000_00000_00,
          mask : 16'b111_1_00000_00000_11,
          resp : '{accept : 1'b1, instr : 32'b00000_00_00000_00000_0_00_00000_1111011}
      },
      '{
          instr : 16'b111_1_00000_00000_00,
          mask : 16'b111_1_00000_00000_11,
          resp : '{accept : 1'b1, instr : 32'b00000_00_00000_00000_0_01_01010_1111011}
      }
  };
```

## Related source code

### core/cvxif_example/instr_decoder.sv

```systemverilog
  for (genvar i = 0; i < NbInstr; i++) begin : gen_predecoder_selector
    assign sel[i] = ((CoproInstr[i].mask & issue_req_i.instr) == CoproInstr[i].instr);
  end
```

## Documentation

### docs/source/x_ext.rst

```text
|processor| will attempt to offload every (compressed or non-compressed) instruction that it does not recognize as a legal instruction itself.
In case of a compressed instruction the |coprocessor| must first provide the |processor| with a matching uncompressed (i.e. 32-bit) instruction using the compressed interface.
This non-compressed instruction is then attempted for offload via the issue interface.

...

  | ``compressed_valid``      | logic               | output          | Compressed request valid. Request to uncompress a compressed instruction.                                                    |
  +---------------------------+---------------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``compressed_ready``      | logic               | input           | Compressed request ready. The transactions signaled via ``compressed_req`` and ``compressed_resp`` are accepted when         |
  |                           |                     |                 | ``compressed_valid`` and  ``compressed_ready`` are both 1.                                                                   |
  +---------------------------+---------------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``compressed_req``        | x_compressed_req_t  | output          | Compressed request packet.                                                                                                   |
  +---------------------------+---------------------+-----------------+------------------------------------------------------------------------------------------------------------------------------+
  | ``compressed_resp``       | x_compressed_resp_t | input           | Compressed response packet.                                                                                                  |

...

The ``instr[15:0]`` signal is used to signal compressed instructions that are considered illegal by |processor| itself. A |coprocessor| can provide an uncompressed instruction
in response to receiving this.

...

  +------------------------+----------------------+-----------------------------------------------------------------------------------------------------------------+
  | Signal                 | Type                 | Description                                                                                                     |
  +========================+======================+=================================================================================================================+
  | ``instr``              | logic [31:0]         | Uncompressed instruction.                                                                                       |
  +------------------------+----------------------+-----------------------------------------------------------------------------------------------------------------+
  | ``accept``             | logic                | Is the offloaded compressed instruction (``id``) accepted by the |coprocessor|?                                 |
  +------------------------+----------------------+-----------------------------------------------------------------------------------------------------------------+

The signals in ``compressed_resp`` are valid when ``compressed_valid`` and ``compressed_ready`` are both 1. There are no stability requirements.

...

If an offloaded instruction uses any of the register file sources ``rs1``, ``rs2``, then these are always encoded in instruction bits ``[19:15]`` and
``[24:20]``, respectively.
```

### verif/env/uvme/cvxif_vseq/custom_instructions_cvxif_1_0_0.rst

```text
- **CUS_CNOP** : Custom Compressed NOP

    **Format**: cus_cnop -> |111|0|rs1|rs2|00|

    **Description**: Extends to CUS_NOP : do nothing, it's just a hint instruction.

    **Pseudocode**: cus_cnop

- **CUS_CADD** : Custom Compressed ADD

    **Format**: cus_cnop -> |111|1|rs1|rs2|00|

    **Description**: Extends to CUS_ADD rs1, rs2 -> x10 : Add rs1 + rs2 into x10 (a0).

    **Pseudocode**: cus_cadd
```
