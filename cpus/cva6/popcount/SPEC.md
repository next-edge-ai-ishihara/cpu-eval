# Implement `popcount`

Implement the complete `popcount` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module popcount` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
module popcount #(
    parameter int unsigned INPUT_WIDTH = 256,
    localparam int unsigned PopcountWidth = $clog2(INPUT_WIDTH)+1
) (
    input logic [INPUT_WIDTH-1:0]     data_i,
    output logic [PopcountWidth-1:0] popcount_o
);
```

## Documentation

### vendor/pulp-platform/common_cells/README.md

```text
| `popcount`                 | Combinatorial popcount (hamming weight)                                                                   | active       |               |
```
