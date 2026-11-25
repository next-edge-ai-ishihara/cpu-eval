# Implement `rvsyncss_fpga`

Implement the complete `rvsyncss_fpga` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvsyncss_fpga` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvsyncss_fpga #(parameter WIDTH = 251)
   (
     input  logic                 gw_clk,
     input  logic                 rawclk,
     input  logic                 clken,
     input  logic                 rst_l,
     input  logic [WIDTH-1:0]     din,
     output logic [WIDTH-1:0]     dout
     );

```

## Parent instantiation

```verilog
module el2_configurable_gw (
                             input logic gw_clk,
                             input logic rawclk,
                             input logic clken,
                             input logic rst_l,
                             input logic extintsrc_req ,
                             input logic meigwctrl_polarity ,
                             input logic meigwctrl_type ,
                             input logic meigwclr ,

                             output logic extintsrc_req_config
                            );

// ...
  rvsyncss_fpga  #(1) sync_inst (
      .dout        (extintsrc_req_sync),
      .din         (extintsrc_req),
      .*) ;

// ...

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

module rvdff_fpga #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic           clken,
     input logic           rawclk,
     input logic           rst_l,

     output logic [WIDTH-1:0] dout
     );

```

## Documentation

### docs/source/clocks.md

Note that each asynchronous input passes through a two-stage synchronizer.
The signal must be asserted for at least two full `clk` cycles to guarantee it is detected by the core complex logic.
Shorter pulses might be dropped by the synchronizer circuit.

...

All core complex flops are reset asynchronously.
