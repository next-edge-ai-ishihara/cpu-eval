# Implement `shift_reg`

Implement the complete `shift_reg` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module shift_reg` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
      NrLoadPipeRegs: int'(0),
      NrStorePipeRegs: int'(0),
```

## Module declaration

```systemverilog
module shift_reg #(
    parameter type dtype         = logic,
    parameter int unsigned Depth = 1
)(
    input  logic clk_i,    // Clock
    input  logic rst_ni,   // Asynchronous reset active low
    input  dtype d_i,
    output dtype d_o
);
```

## Parent instantiation

### core/load_store_unit.sv

```systemverilog
  shift_reg #(
      .dtype(logic [$bits(ld_valid) + $bits(ld_trans_id) + $bits(ld_result) + $bits(ld_ex) - 1:0]),
      .Depth(CVA6Cfg.NrLoadPipeRegs)
  ) i_pipe_reg_load (
      .clk_i,
      .rst_ni,
      .d_i({ld_valid, ld_trans_id, ld_result, ld_ex}),
      .d_o({load_valid_o, load_trans_id_o, load_result_o, load_exception_o})
  );
```

## Documentation

### vendor/pulp-platform/common_cells/README.md

```text
| `shift_reg`                | Shift register for arbitrary types                                                                        | active       |               |
```
