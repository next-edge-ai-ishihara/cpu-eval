# Implement `mult`

Implement the complete `mult` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module mult` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
      RVB: bit'(1),
```

### core/include/build_config_pkg.sv

```systemverilog
    bit IS_XLEN32 = (CVA6Cfg.XLEN == 32) ? 1'b1 : 1'b0;
    bit IS_XLEN64 = (CVA6Cfg.XLEN == 32) ? 1'b0 : 1'b1;
```

## Package and imports

### core/include/ariane_pkg.sv

```systemverilog
    // Multiplications
    MUL,
    MULH,
    MULHU,
    MULHSU,
    MULW,
    // Divisions
    DIV,
    DIVU,
    DIVW,
    DIVUW,
    REM,
    REMU,
    REMW,
    REMUW,
// ...
    // Carry less multiplication Op's
    CLMUL,
    CLMULH,
    CLMULR,
```

## Module declaration

```systemverilog
module mult
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type fu_data_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input  logic                                 clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input  logic                                 rst_ni,
    // Flush - CONTROLLER
    input  logic                                 flush_i,
    // FU data needed to execute instruction - ISSUE_STAGE
    input  fu_data_t                             fu_data_i,
    // Mult instruction is valid - ISSUE_STAGE
    input  logic                                 mult_valid_i,
    // Mult result - ISSUE_STAGE
    output logic     [         CVA6Cfg.XLEN-1:0] result_o,
    // Mult result is valid - ISSUE_STAGE
    output logic                                 mult_valid_o,
    // Mutl is ready - ISSUE_STAGE
    output logic                                 mult_ready_o,
    // Mult transaction ID - ISSUE_STAGE
    output logic     [CVA6Cfg.TRANS_ID_BITS-1:0] mult_trans_id_o
);
```

## Parent instantiation

### core/cva6.sv

```systemverilog
    localparam type fu_data_t = struct packed {
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.XLEN-1:0]          operand_a;
      logic [CVA6Cfg.XLEN-1:0]          operand_b;
      logic [CVA6Cfg.XLEN-1:0]          imm;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
    },
```

### core/ex_stage.sv

```systemverilog
  assign flu_valid_o = |one_cycle_select | mult_valid;

  // result MUX
  always_comb begin
    // Branch result as default case
    flu_result_o   = {{CVA6Cfg.XLEN - CVA6Cfg.VLEN{1'b0}}, branch_result};
    flu_trans_id_o = one_cycle_data.trans_id;
    // ALU result
    if (|alu_valid_i) begin
      flu_result_o = alu_result[0];
      // CSR result
    end else if (|csr_valid_i) begin
      flu_result_o = csr_result;
    end else if (mult_valid) begin
      flu_result_o   = mult_result;
      flu_trans_id_o = mult_trans_id;
    end else if (|aes_valid_i) begin
      flu_result_o = aes_result;
    end
  end

  // ready flags for FLU
  always_comb begin
    flu_ready_o = csr_ready & mult_ready;
  end

  // 4. Multiplication (Sequential)
  fu_data_t mult_data;
  // input silencing of multiplier
  always_comb begin
    mult_data = mult_valid_i[0] ? fu_data_i[0] : '0;
    if (CVA6Cfg.SuperscalarEn) begin
      if (mult_valid_i[1]) begin
        mult_data = fu_data_i[1];
      end
    end
  end

  mult #(
      .CVA6Cfg  (CVA6Cfg),
      .fu_data_t(fu_data_t)
  ) i_mult (
      .clk_i,
      .rst_ni,
      .flush_i,
      .mult_valid_i   (|mult_valid_i),
      .fu_data_i      (mult_data),
      .result_o       (mult_result),
      .mult_valid_o   (mult_valid),
      .mult_ready_o   (mult_ready),
      .mult_trans_id_o(mult_trans_id)
  );
```

## Dependency declarations

### core/multiplier.sv

```systemverilog
// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
//
// Description: Multiplication Unit with one pipeline register
//              This unit relies on retiming features of the synthesizer
//


module multiplier
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    // Subsystem Clock - SUBSYSTEM
    input  logic                             clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input  logic                             rst_ni,
    // Multiplier transaction ID - Mult
    input  logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_i,
    // Multiplier instruction is valid - Mult
    input  logic                             mult_valid_i,
    // Multiplier operation - Mult
    input  fu_op                             operation_i,
    // A operand - Mult
    input  logic [         CVA6Cfg.XLEN-1:0] operand_a_i,
    // B operand - Mult
    input  logic [         CVA6Cfg.XLEN-1:0] operand_b_i,
    // Multiplier result - Mult
    output logic [         CVA6Cfg.XLEN-1:0] result_o,
    // Mutliplier result is valid - Mult
    output logic                             mult_valid_o,
    // Multiplier transaction ID - Mult
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] mult_trans_id_o
);
```

### core/serdiv.sv

```systemverilog
// Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
//         Andreas Traber    <traber@iis.ee.ethz.ch>, ETH Zurich
//
// Date: 18.10.2018
// Description: simple 64bit serial divider


module serdiv
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter WIDTH = 64,
    parameter STABLE_HANDSHAKE = 0             // Guarantee a stable in_rdy_o during the input handshake. Keep it at 0 in CVA6
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Serdiv translation ID - Mult
    input logic [CVA6Cfg.TRANS_ID_BITS-1:0] id_i,
    // A operand - Mult
    input logic [WIDTH-1:0] op_a_i,
    // B operand - Mult
    input logic [WIDTH-1:0] op_b_i,
    // Serdiv operation - Mult
    input logic [1:0] opcode_i,  // 0: udiv, 2: urem, 1: div, 3: rem
    // Serdiv instruction is valid - Mult
    input logic in_vld_i,
    // Serdiv FU is ready - Mult
    output logic in_rdy_o,
    // Flush - CONTROLLER
    input logic flush_i,
    // Serdiv result is valid - Mult
    output logic out_vld_o,
    // Serdiv is ready - Mult
    input logic out_rdy_i,
    // Serdiv transaction ID - Mult
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] id_o,
    // Serdiv result - Mult
    output logic [WIDTH-1:0] res_o
);
```

## Documentation

### docs/design/design-manual/source/cva6_execute.adoc

```text
[[mult]]
mult
++++

The multiplier module supports the division and multiplication operations.

image:mult_modules.png[mult submodules]

include::port_mult.adoc[]

[[multiplier]]
====== multiplier

Multiplication is performed in two cycles and is fully pipelined.

include::port_multiplier.adoc[]
```
