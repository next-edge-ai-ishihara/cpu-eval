# Implement `rvdffpcie`

Implement the complete `rvdffpcie` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvdffpcie` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvdffpcie #( parameter WIDTH=31 )
   (
     input  logic [WIDTH-1:0] din,
     input  logic             clk,
     input  logic             rst_l,
     input  logic             en,
     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
     /*pragma coverage off*/
     input  logic             scan_mode,
     /*pragma coverage on*/
     output logic [WIDTH-1:0] dout
     );
```

## Parent instantiation

```verilog
   rvdffpcie #(31) i0_pc_r_ff           (.*, .en(i0_r_data_en), .din(exu_i0_pc_x[31:1]), .dout(dec_i0_pc_r[31:1]));
```

## Dependency declarations

### design/lib/beh_lib.sv

```verilog
module rvdff #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic                   rst_l,

     output logic [WIDTH-1:0] dout
     );

// ...

// rvdff with 2:1 input mux to flop din iff sel==1
module rvdffs #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic                   rst_l,
     output logic [WIDTH-1:0] dout
     );
```

## Documentation

### docs/source/clocks.md

```markdown
### Core Complex Reset (rst_l)

As shown in {numref}`fig-clock-reset-timing`, the core complex reset signal (`rst_l`) is active-low, may be asynchronously asserted, but must be synchronously deasserted to avoid any glitches.
The `rst_l` input signal is not synchronized to the core clock (`clk`) inside the core complex logic.
All core complex flops are reset asynchronously.
```
