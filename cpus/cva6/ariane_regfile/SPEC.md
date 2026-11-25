# Implement `ariane_regfile`

Implement the complete `ariane_regfile` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ariane_regfile` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
module ariane_regfile #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg       = config_pkg::cva6_cfg_empty,
    parameter int unsigned           DATA_WIDTH    = 32,
    parameter int unsigned           NR_READ_PORTS = 2,
    parameter bit                    ZERO_REG_ZERO = 0
) (
    // clock and reset
    input  logic                                             clk_i,
    input  logic                                             rst_ni,
    // disable clock gates for testing
    input  logic                                             test_en_i,
    // read port
    input  logic [        NR_READ_PORTS-1:0][           4:0] raddr_i,
    output logic [        NR_READ_PORTS-1:0][DATA_WIDTH-1:0] rdata_o,
    // write port
    input  logic [CVA6Cfg.NrCommitPorts-1:0][           4:0] waddr_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0][DATA_WIDTH-1:0] wdata_i,
    input  logic [CVA6Cfg.NrCommitPorts-1:0]                 we_i
);
```

## Parent instantiation

```systemverilog
    ariane_regfile #(
        .CVA6Cfg      (CVA6Cfg),
        .DATA_WIDTH   (CVA6Cfg.XLEN),
        .NR_READ_PORTS(CVA6Cfg.NrRgprPorts),
        .ZERO_REG_ZERO(1)
    ) i_ariane_regfile (
        .clk_i,
        .rst_ni,
        .test_en_i(1'b0),
        .raddr_i  (raddr_pack),
        .rdata_o  (rdata),
        .waddr_i  (waddr_pack),
        .wdata_i  (wdata_pack),
        .we_i     (we_pack)
    );
```

## Related source code

### core/ariane_regfile_fpga.sv

```systemverilog
// Description:    This register file is optimized for implementation on
//                 FPGAs. The register file features one distributed RAM block per implemented
//                 sync-write port, each with a parametrized number of async-read ports.
```

## Documentation

### docs/design/design-manual/source/cva6_issue_stage.adoc

```text
The input operands provided to EX_STAGE come from the register file by default.
However, when one of the source registers has a RAW dependence, the corresponding input operand is replaced by the forwarded value (see <<raw_hazard,Data hazards/RAW hazards>> above).
The register file is an instance of `ariane_regfile` where ach register stores {XLEN} bits and the register at index 0 is wired to zero.
```

### src/rv32.adoc

```text
=== Programmers' Model for Base Integer ISA

<<gprs>> shows the unprivileged state for the base
integer ISA. For RV32I, the 32 `x` registers are each 32 bits wide,
i.e., `XLEN=32`. Register `x0` is hardwired with all bits equal to 0.
General purpose registers `x1-x31` hold values that various
instructions interpret as a collection of Boolean values, or as two's
complement signed binary integers or unsigned binary integers.
```
