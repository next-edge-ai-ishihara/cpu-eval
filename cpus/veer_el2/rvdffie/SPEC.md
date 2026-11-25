# Implement `rvdffie`

Implement the complete `rvdffie` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvdffie` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvdffie #( parameter WIDTH=1, OVERRIDE=0 )
   (
     input  logic [WIDTH-1:0] din,

     input  logic           clk,
     input  logic           rst_l,
     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
     /*pragma coverage off*/
     input  logic             scan_mode,
     /*pragma coverage on*/
     output logic [WIDTH-1:0] dout
     );
```

## Parent instantiation

### design/dec/el2_dec_decode_ctl.sv

```verilog
   rvdffie  #(8) misc1ff (.*,
                          .clk(free_l2clk),
                          .din( {leak1_i1_stall_in,leak1_i0_stall_in,dec_tlu_flush_extint,pause_state_in ,dec_tlu_wr_pause_r, tlu_wr_pause_r1,illegal_lockout_in,ps_stall_in}),
                          .dout({leak1_i1_stall,   leak1_i0_stall,   dec_extint_stall,    pause_state,       tlu_wr_pause_r1,tlu_wr_pause_r2,illegal_lockout,   ps_stall   })
                          );
```

### design/exu/el2_exu.sv

```verilog
   rvdffie #(pt.BHT_GHR_SIZE+2,1)       i_misc_ff            (.*, .clk(clk),                                .din ({ghr_d_ns[pt.BHT_GHR_SIZE-1:0], mul_p.valid, dec_i0_branch_d}),
                                                                                                            .dout({ghr_d[pt.BHT_GHR_SIZE-1:0]   , mul_valid_x, i0_branch_x}) );
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

module rvclkhdr
  (
   input  logic en,
   input  logic clk,
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic scan_mode,
   /*pragma coverage on*/
   output logic l1clk
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
