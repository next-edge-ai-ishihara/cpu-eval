# Implement `lzc`

Implement the complete `lzc` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module lzc` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

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

## Additional requirement

When `in_i` is all zeros, `cnt_o` is `WIDTH - 1`.
