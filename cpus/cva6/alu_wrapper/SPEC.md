# Implement `alu_wrapper`

Implement the complete `alu_wrapper` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module alu_wrapper` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
      SuperscalarEn: bit'(0),
```

### core/include/build_config_pkg.sv

```systemverilog
    cfg.NrALUs = CVA6Cfg.SuperscalarEn ? unsigned'(2) : unsigned'(1);
    cfg.ALUBypass = CVA6Cfg.SuperscalarEn ? bit'(CVA6Cfg.ALUBypass) : bit'(0);
```

## Package and imports

### core/include/ariane_pkg.sv

```systemverilog
  typedef struct packed {
    logic rs1_from_rd;
    logic rs2_from_rd;
  } alu_bypass_t;
```

## Module declaration

```systemverilog
module alu_wrapper
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type fu_data_t = logic
) (
    input  logic                                               clk_i,
    input  logic                                               rst_ni,
    input  alu_bypass_t                                        alu_bypass_i,
    input  fu_data_t    [CVA6Cfg.NrALUs-1:0]                   fu_data_i,
    output logic        [CVA6Cfg.NrALUs-1:0][CVA6Cfg.XLEN-1:0] result_o,
    output logic                                               alu_branch_res_o
);
```

## Parent instantiation

```systemverilog
  alu_wrapper #(
      .CVA6Cfg  (CVA6Cfg),
      .fu_data_t(fu_data_t)
  ) alu_wrapper_i (
      .clk_i,
      .rst_ni,
      .alu_bypass_i    (alu_bypass_i),
      .fu_data_i       (alu_data),
      .result_o        (alu_result),
      .alu_branch_res_o(alu_branch_res)
  );
```

## Dependency declarations

```systemverilog
module alu
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter bit HasBranch = 1'b1,
    parameter type fu_data_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // FU data needed to execute instruction - ISSUE_STAGE
    input fu_data_t fu_data_i,
    // FU data needed to execute CPOP/CPOPW - ISSUE_STAGE
    input fu_data_t fu_data_cpop_i,
    // ALU result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] result_o,
    // ALU branch compare result - branch_unit
    output logic alu_branch_res_o
);
```
