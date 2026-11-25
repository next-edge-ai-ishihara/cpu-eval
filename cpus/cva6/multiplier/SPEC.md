# Implement `multiplier`

Implement the complete `multiplier` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module multiplier` definition in a single SystemVerilog code
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
// ...
    // Carry less multiplication Op's
    CLMUL,
    CLMULH,
    CLMULR,
```

## Module declaration

```systemverilog
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

## Parent instantiation

### core/mult.sv

```systemverilog
  // ---------------------
  // Multiplication
  // ---------------------
  multiplier #(
      .CVA6Cfg(CVA6Cfg)
  ) i_multiplier (
      .clk_i,
      .rst_ni,
      .trans_id_i     (fu_data_i.trans_id),
      .operation_i    (fu_data_i.operation),
      .operand_a_i    (fu_data_i.operand_a),
      .operand_b_i    (fu_data_i.operand_b),
      .result_o       (mul_result),
      .mult_valid_i   (mul_valid_op),
      .mult_valid_o   (mul_valid),
      .mult_trans_id_o(mul_trans_id)
  );
```

## Documentation

### docs/design/design-manual/source/cva6_execute.adoc

```text
[[multiplier]]
====== multiplier

Multiplication is performed in two cycles and is fully pipelined.

include::port_multiplier.adoc[]
```

### src/m-st-ext.adoc

```text
(((MUL, MULH)))
(((MUL, MULHU)))
(((MUL, MULHSU)))

MUL performs an XLEN-bit×XLEN-bit multiplication of
_rs1_ by _rs2_ and places the lower XLEN bits in the destination
register. MULH, MULHU, and MULHSU perform the same multiplication but
return the upper XLEN bits of the full 2×XLEN-bit
product, for signed×signed,
unsigned×unsigned, and _rs1_×unsigned _rs2_ multiplication, respectively.
```

### src/b-st-ext.adoc

```text
Description::
clmul produces the lower half of the 2·XLEN carry-less product.

Operation::
[source,sail]
--
let rs1_val = X(rs1);
let rs2_val = X(rs2);
let output : xlenbits = 0;

foreach (i from 0 to (xlen - 1) by 1) {
   output = if   ((rs2_val >> i) & 1)
            then output ^ (rs1_val << i);
            else output;
}

X[rd] = output
--
...
Description::
clmulh produces the upper half of the 2·XLEN carry-less product.

Operation::
[source,sail]
--
let rs1_val = X(rs1);
let rs2_val = X(rs2);
let output : xlenbits = 0;

foreach (i from 1 to xlen by 1) {
   output = if   ((rs2_val >> i) & 1)
            then output ^ (rs1_val >> (xlen - i));
            else output;
}

X[rd] = output
--
...
Description::
*clmulr* produces bits 2·XLEN−2:XLEN-1 of the 2·XLEN carry-less
product.

Operation::
[source,sail]
--
let rs1_val = X(rs1);
let rs2_val = X(rs2);
let output : xlenbits = 0;

foreach (i from 0 to (xlen - 1) by 1) {
   output = if   ((rs2_val >> i) & 1)
            then output ^ (rs1_val >> (xlen - i - 1));
            else output;
}

X[rd] = output
--
```

## Additional requirement

Present `result_o`, `mult_trans_id_o` and `mult_valid_o` for a request in the clock cycle that follows the rising edge at which `mult_valid_i` is sampled.
