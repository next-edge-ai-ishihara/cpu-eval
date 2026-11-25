# Implement `serdiv`

Implement the complete `serdiv` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module serdiv` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
```

## Module declaration

```systemverilog
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

## Parent instantiation

### core/mult.sv

```systemverilog
  assign div_valid_op = ~flush_i && mult_valid_i && (fu_data_i.operation inside { DIV, DIVU, DIVW, DIVUW, REM, REMU, REMW, REMUW });

  // ---------------------
  // Output Arbitration
  // ---------------------
  // we give precedence to multiplication as the divider supports stalling and the multiplier is
  // just a dumb pipelined multiplier
  assign div_ready_i = (mul_valid) ? 1'b0 : 1'b1;
  assign mult_trans_id_o = (mul_valid) ? mul_trans_id : div_trans_id;
  assign result_o = (mul_valid) ? mul_result : div_result;
  assign mult_valid_o = div_valid | mul_valid;
  // mult_ready_o = division as the multiplication will unconditionally be ready to accept new requests
// ...
  serdiv #(
      .CVA6Cfg(CVA6Cfg),
      .WIDTH  (CVA6Cfg.XLEN)
  ) i_div (
      .clk_i    (clk_i),
      .rst_ni   (rst_ni),
      .id_i     (fu_data_i.trans_id),
      .op_a_i   (operand_a),
      .op_b_i   (operand_b),
      .opcode_i ({rem, div_signed}),   // 00: udiv, 10: urem, 01: div, 11: rem
      .in_vld_i (div_valid_op),
      .in_rdy_o (mult_ready_o),
      .flush_i  (flush_i),
      .out_vld_o(div_valid),
      .out_rdy_i(div_ready_i),
      .id_o     (div_trans_id),
      .res_o    (result)
  );
```

## Documentation

### src/m-st-ext.adoc

```text
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
...
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
```

### docs/design/design-manual/source/cva6_execute.adoc

```text
The division is a simple serial divider which needs 64 cycles in the worst case.
```

### docs/design/design-manual/source/cva6_issue_stage.adoc

```text
* Structural hazards: ISSUE_STAGE checks that a functional unit (FU) and its result bus (RB) are ready to execute the instruction.

** Integer division instructions and some^[FIXME{sp}which?]^ CSR instructions have an unknown latency.
When EX_STAGE reports that such an instruction is running, instructions using ALU, BRANCH, CSR or MULT are blocked.
...
Instructions are sent to EX_STAGE via a register so they are visible in EX_STAGE one cycle after being issued.
```
