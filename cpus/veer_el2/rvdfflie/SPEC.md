# Implement `rvdfflie`

Implement the complete `rvdfflie` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvdfflie` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
// format: { LEFT, EXTRA }
// LEFT # of bits will be done with rvdffie, all else EXTRA with rvdffe
module rvdfflie #( parameter WIDTH=16, LEFT=8 )
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

### design/dec/el2_dec_decode_ctl.sv

```verilog
   rvdfflie #( .WIDTH($bits(el2_trap_pkt_t)),.LEFT(9) ) trap_xff (.*, .en(i0_x_ctl_en), .din(d_t),  .dout(x_t));
   // ...
   rvdfflie #( .WIDTH($bits(el2_dest_pkt_t)),.LEFT(15) ) e1ff (.*, .en(i0_x_ctl_en), .din(d_d),  .dout(x_d));
```

### design/ifu/el2_ifu_bp_ctl.sv

```verilog
   rvdfflie #(.WIDTH(30), .LEFT(19)) faddrf_ff (.*, .en(ifc_fetch_req_f & ~ifu_bp_hit_taken_f & ic_hit_f), .din(ifc_fetch_addr_f[31:2]), .dout(ifc_fetch_adder_prior[31:2]));
```

### design/ifu/el2_ifu_mem_ctl.sv

```verilog
   rvdfflie #(.WIDTH(31-pt.ICACHE_BEAT_ADDR_HI),.LEFT(31-pt.ICACHE_BEAT_ADDR_HI-8)) miss_f_ff       (.*, .en(bus_ifu_bus_clk_en | ic_act_miss_f | dec_tlu_force_halt), .din ({miss_addr_in[31:pt.ICACHE_BEAT_ADDR_HI+1]}), .dout({miss_addr[31:pt.ICACHE_BEAT_ADDR_HI+1]}));
```

### design/lib/beh_lib.sv

```verilog
      rvdfflie #(.WIDTH(WIDTH), .LEFT(19)) dff (.*);
```

## Dependency declarations

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

// ...

// ie flop but it has an .en input
module rvdffiee #( parameter WIDTH=1, OVERRIDE=0 )
   (
     input  logic [WIDTH-1:0] din,

     input  logic           clk,
     input  logic           rst_l,
     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
     /*pragma coverage off*/
     input  logic           scan_mode,
     /*pragma coverage on*/
     input  logic           en,
     output logic [WIDTH-1:0] dout
     );

// ...
`ifndef RV_PHYSICAL
   if (WIDTH >= 8 || OVERRIDE==1) begin: genblock
`endif

// ...
`ifndef RV_PHYSICAL
   end
   else
      $error("%m: rvdffie width must be >= 8");
`endif
```

## Additional requirement

When `en` is 0, a rising edge of `clk` leaves every bit of `dout`, including the `LEFT` bits, unchanged.
