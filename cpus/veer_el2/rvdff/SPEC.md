# Implement `rvdff`

Implement the complete `rvdff` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvdff` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvdff #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic                   rst_l,

     output logic [WIDTH-1:0] dout
     );
```

## Parent instantiation

### design/lsu/el2_lsu_lsc_ctl.sv

```verilog
   rvdff #(32) samff (.*, .din(lsu_addr_d[31:0]), .dout(lsu_addr_m[31:0]), .clk(lsu_c1_m_clk));
   rvdff #(32) sarff (.*, .din(lsu_addr_m[31:0]), .dout(lsu_addr_r[31:0]), .clk(lsu_c1_r_clk));
```

## Related source code

### design/lib/beh_lib.sv

```verilog
module rvdffs #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic                   rst_l,
     output logic [WIDTH-1:0] dout
     );

// ...
if (SHORT == 1) begin : genblock
   assign dout = din;
end
// ...
```

## Documentation

### docs/source/clocks.md

```markdown
### Core Complex Reset (rst_l)

As shown in {numref}`fig-clock-reset-timing`, the core complex reset signal (`rst_l`) is active-low, may be asynchronously asserted, but must be synchronously deasserted to avoid any glitches.
The `rst_l` input signal is not synchronized to the core clock (`clk`) inside the core complex logic.
All core complex flops are reset asynchronously.
```
