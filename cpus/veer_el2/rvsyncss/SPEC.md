# Implement `rvsyncss`

Implement the complete `rvsyncss` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module rvsyncss` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvsyncss #(parameter WIDTH = 251)
   (
     input  logic                 clk,
     input  logic                 rst_l,
     input  logic [WIDTH-1:0]     din,
     output logic [WIDTH-1:0]     dout
     );

```

## Parent instantiation

### design/dbg/el2_dbg.sv

```verilog
   rvsyncss #(1) rstl_syncff (.din(rst_l), .dout(rst_l_sync), .clk(free_clk), .rst_l(dbg_rst_l));

```

### design/dec/el2_dec_tlu_ctl.sv

```verilog
   rvsyncss #(7) syncro_ff(.*,
                           .clk(free_clk),
                           .din ({nmi_int,      timer_int,      soft_int,      i_cpu_halt_req,      i_cpu_run_req,      mpc_debug_halt_req,          mpc_debug_run_req}),
                           .dout({nmi_int_sync, timer_int_sync, soft_int_sync, i_cpu_halt_req_sync, i_cpu_run_req_sync, mpc_debug_halt_req_sync_raw, mpc_debug_run_req_sync}));

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

Note that each asynchronous input passes through a two-stage synchronizer.
The signal must be asserted for at least two full `clk` cycles to guarantee it is detected by the core complex logic.
Shorter pulses might be dropped by the synchronizer circuit.

...

All core complex flops are reset asynchronously.
