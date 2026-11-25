# Implement `rvdff_fpga`

Implement the complete `rvdff_fpga` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvdff_fpga` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### tools/riscv-dv/Makefile

```make
VEER_TARGET     = default
VEER_CONF       = -set build_axi4 \
                  -set reset_vec=0x80000000 \
                  -set fpga_optimize=0 \
                  $(VEER_EXTRA_CONF)
```

### configs/veer.config

```text
     -fpga_optimize =   { 0, 1 }
          if 1, minimize clock-gating to facilitate FPGA builds
```

## Module declaration

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
```

## Parent instantiation

```verilog
   rvdff_fpga #(1) fifo_full_bus_ff     (.din(fifo_full_spec),   .dout(fifo_full_spec_bus), .clk(dma_bus_clk), .clken(dma_bus_clk_en), .rawclk(clk), .*);
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
```
