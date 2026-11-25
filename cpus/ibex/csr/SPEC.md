# Implement `ibex_csr`

Implement the complete `ibex_csr` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module ibex_csr` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
module ibex_csr #(
  parameter int unsigned    Width      = 32,
  parameter bit             ShadowCopy = 1'b0,
  parameter bit [Width-1:0] ResetValue = '0
 ) (
  input  logic             clk_i,
  input  logic             rst_ni,

  input  logic [Width-1:0] wr_data_i,
  input  logic             wr_en_i,
  output logic [Width-1:0] rd_data_o,

  output logic             rd_error_o
);
```

## Parent instantiation

### rtl/ibex_cs_registers.sv

```systemverilog
  // MSCRATCH
  ibex_csr #(
    .Width     (32),
    .ShadowCopy(1'b0),
    .ResetValue('0)
  ) u_mscratch_csr (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .wr_data_i (csr_wdata_int),
    .wr_en_i   (mscratch_en),
    .rd_data_o (mscratch_q),
    .rd_error_o()
  );

  // ...

  // MTVEC
  ibex_csr #(
    .Width     (32),
    .ShadowCopy(ShadowCSR),
    .ResetValue({32'd1})   // retain this to make lec vs ibex pass
  ) u_mtvec_csr (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .wr_data_i (mtvec_d_combi),
    .wr_en_i   (mtvec_en_combi),
    .rd_data_o (mtvec_q),
    .rd_error_o(mtvec_err)
  );
```

## Related source code

### rtl/ibex_core.sv

```systemverilog
  localparam bit          ShadowCSR     = 1'b0;

  // ...

  ibex_cs_registers #(
    // ...
    .ShadowCSR        (ShadowCSR),
```

## Documentation

### doc/02_user/integration.rst

```text
Interfaces
----------

+------------------------------+-------------------------+-----+----------------------------------------+
| Signal(s)                    | Width                   | Dir | Description                            |
+==============================+=========================+=====+========================================+
| ``clk_i``                    | 1                       | in  | Clock signal                           |
+------------------------------+-------------------------+-----+----------------------------------------+
| ``rst_ni``                   | 1                       | in  | Active-low asynchronous reset          |
+------------------------------+-------------------------+-----+----------------------------------------+
```
