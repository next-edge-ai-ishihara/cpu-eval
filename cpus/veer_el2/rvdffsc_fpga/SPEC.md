# Implement `rvdffsc_fpga`

Implement the complete `rvdffsc_fpga` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module rvdffsc_fpga` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

```text
     -fpga_optimize =   { 0, 1 }
          if 1, minimize clock-gating to facilitate FPGA builds
...
my $fpga_optimize = 1;

```

## Module declaration

```verilog
module rvdffsc_fpga #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic             clear,
     input logic             clk,
     input logic             clken,
     input logic             rawclk,
     input logic             rst_l,

     output logic [WIDTH-1:0] dout
     );

```

## Parent instantiation

```verilog
`ifdef RV_FPGA_OPTIMIZE
   assign dma_bus_clk = 1'b0;
`else
   rvclkhdr  dma_bus_cgc (.en(dma_bus_clk_en), .l1clk(dma_bus_clk), .*);
`endif
// ...
   rvdffsc_fpga  #(.WIDTH(1))              wrbuf_vldff       (.din(1'b1), .dout(wrbuf_vld),      .en(wrbuf_en),      .clear(wrbuf_rst),      .clk(dma_bus_clk), .clken(dma_bus_clk_en), .rawclk(clk), .*);
   rvdffsc_fpga  #(.WIDTH(1))              wrbuf_data_vldff  (.din(1'b1), .dout(wrbuf_data_vld), .en(wrbuf_data_en), .clear(wrbuf_data_rst), .clk(dma_bus_clk), .clken(dma_bus_clk_en), .rawclk(clk), .*);
// ...
   rvdffsc_fpga  #(.WIDTH(1))              rdbuf_vldff  (.din(1'b1), .dout(rdbuf_vld), .en(rdbuf_en), .clear(rdbuf_rst), .clk(dma_bus_clk), .clken(dma_bus_clk_en), .rawclk(clk), .*);

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

All core complex flops are reset asynchronously.
