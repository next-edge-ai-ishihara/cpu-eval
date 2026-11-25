# Implement `el2_configurable_gw`

Implement the complete `el2_configurable_gw` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_configurable_gw` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

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
```

## Parent instantiation

```verilog
        el2_configurable_gw gw_inst(
             .*,
            .gw_clk(grp_clk),
            .rawclk(clk),
            .clken (grp_clken),
            .extintsrc_req(extintsrc_req[i+p*4]) ,
            .meigwctrl_polarity(gw_config_reg[i+p*4][0]) ,
            .meigwctrl_type(gw_config_reg[i+p*4][1]) ,
            .meigwclr(gw_clear_reg_we[i+p*4]) ,
            .extintsrc_req_config(extintsrc_req_gw[i+p*4])
        );
```

## Dependency declarations

```verilog
module rvdff_fpga #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic           clken,
     input logic           rawclk,
     input logic           rst_l,

     output logic [WIDTH-1:0] dout
     );
// ...
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

## Documentation

```text
The gateway is responsible for synchronizing the interrupt request to the core's clock domain, and for converting the request signal to a common interrupt request format (i.e., active-high and level-triggered) for the PIC.
...
For edge-triggered interrupts, the gateway must latch the interrupt request in an interrupt pending (IP) flop to convert the edge- to a level-triggered interrupt signal.
Firmware must clear the IP flop while handling the interrupt.
...
The gateway does not implement any edge-detection logic (e.g., an edge-triggered flop) to convert the interrupt request to a level-triggered interrupt signal (see {numref}`fig-configurable-gateway-diagram`).
Therefore, the interrupt request input signal must be set to the inactive level (i.e., to '0' for an active-high interrupt and to '1' for an active-low interrupt) to avoid an interrupt request being continuously reported as pending, even after the gateway's IP latch has been cleared.
...
  - External interrupt type for interrupt source ID S:
    - 0: Level-triggered interrupt
    - 1: Edge-triggered interrupt
...
  - External interrupt polarity for interrupt source ID S:
    - 0: Active-high interrupt
    - 1: Active-low interrupt
```
