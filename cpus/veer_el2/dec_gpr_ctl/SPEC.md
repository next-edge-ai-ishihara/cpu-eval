# Implement `el2_dec_gpr_ctl`

Implement the complete `el2_dec_gpr_ctl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_dec_gpr_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog

module el2_dec_gpr_ctl
import el2_pkg::*;
#(
   `include "el2_param.vh"
 )  (
    input logic [4:0]  raddr0,       // logical read addresses
    input logic [4:0]  raddr1,

    input logic        wen0,         // write enable
    input logic [4:0]  waddr0,       // write address
    input logic [31:0] wd0,          // write data

    input logic        wen1,         // write enable
    input logic [4:0]  waddr1,       // write address
    input logic [31:0] wd1,          // write data

    input logic        wen2,         // write enable
    input logic [4:0]  waddr2,       // write address
    input logic [31:0] wd2,          // write data

    input logic        clk,
    input logic        rst_l,

    output logic [31:0] rd0,         // read data
    output logic [31:0] rd1,

`ifdef RV_LOCKSTEP_REGFILE_ENABLE
    el2_regfile_if.veer_gpr_rf regfile,
`endif

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
    input  logic        scan_mode
   /*pragma coverage on*/
);

```

## Parent instantiation

```verilog


  el2_dec_gpr_ctl #(
      .pt(pt)
  ) arf (
      .*,
`ifdef RV_LOCKSTEP_REGFILE_ENABLE
      .regfile(regfile_if.veer_gpr_rf),
`endif
      // inputs
      .raddr0(dec_i0_rs1_d[4:0]),
      .raddr1(dec_i0_rs2_d[4:0]),

      .wen0(dec_i0_wen_r),
      .waddr0(dec_i0_waddr_r[4:0]),
      .wd0(dec_i0_wdata_r[31:0]),
      .wen1(dec_nonblock_load_wen),
      .waddr1(dec_nonblock_load_waddr[4:0]),
      .wd1(lsu_nonblock_load_data[31:0]),
      .wen2(exu_div_wren),
      .waddr2(div_waddr_wb),
      .wd2(exu_div_result[31:0]),

      // outputs
      .rd0(gpr_i0_rs1_d[31:0]),
      .rd1(gpr_i0_rs2_d[31:0])
  );

```

## Dependency declarations

```verilog


module rvdffe #( parameter WIDTH=1, SHORT=0, OVERRIDE=0 )
   (
     input  logic [WIDTH-1:0] din,
     input  logic           en,
     input  logic           clk,
     input  logic           rst_l,
     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
     /*pragma coverage off*/
     input  logic             scan_mode,
     /*pragma coverage on*/
     output logic [WIDTH-1:0] dout
     );

// ...
if (SHORT == 1) begin : genblock
   if (1) begin : genblock
      assign dout = din;
   end
end
else begin : genblock

`ifndef RV_PHYSICAL
   if (WIDTH >= 8 || OVERRIDE==1) begin: genblock
`endif

// ...
`ifndef RV_PHYSICAL
   end
   else
      $error("%m: rvdffe must be WIDTH >= 8");
`endif
end // else: !if(SHORT == 1)

```

## Documentation

### `src/rv32.adoc`

```text
=== Programmers' Model for Base Integer ISA

<<gprs>> shows the unprivileged state for the base
integer ISA. For RV32I, the 32 `x` registers are each 32 bits wide,
i.e., `XLEN=32`. Register `x0` is hardwired with all bits equal to 0.
General purpose registers `x1-x31` hold values that various
instructions interpret as a collection of Boolean values, or as two's
complement signed binary integers or unsigned binary integers.
```

### `docs/source/memory-map.md`

```text
The `rst_l` input signal is active-low, asynchronously asserted, and synchronously deasserted (see also [](clocks.md#reset)).
When the core is reset, it fetches the first instruction to be executed from the address provided on the reset vector bus.
Note that the applied reset vector must be pointing to the ICCM, if enabled, or a valid memory address, which is within an enabled instruction access window if the memory protection mechanism (see [](memory-map.md#memory-protection)) is used.

:::{note}
The core's 31 general-purpose registers (`x1 - x31`) are cleared on reset.
:::
```

## Additional requirement

Each read port returns the value currently stored in the addressed register and does not forward write data that has not yet been stored on a rising clock edge.
