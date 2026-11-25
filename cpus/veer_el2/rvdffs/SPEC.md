# Implement `rvdffs`

Implement the complete `rvdffs` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module rvdffs` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvdffs #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic                   rst_l,
     output logic [WIDTH-1:0] dout
     );

```

## Parent instantiation

```verilog
   rvdffs #(1) wbnbloaddelayff (.*, .clk(active_clk), .en(i0_r_ctl_en ), .din(lsu_nonblock_load_valid_m),        .dout(nonblock_load_valid_m_delay) );

```

## Dependency declarations

```verilog
module rvdff #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic                   rst_l,

     output logic [WIDTH-1:0] dout
     );

```

## Documentation

### docs/source/clocks.md

All core complex flops are reset asynchronously.
