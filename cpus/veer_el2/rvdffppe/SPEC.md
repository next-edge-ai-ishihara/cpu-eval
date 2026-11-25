# Implement `rvdffppe`

Implement the complete `rvdffppe` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module rvdffppe` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvdffppe #( parameter integer WIDTH = 39 )
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
   rvdffppe #($bits(el2_predict_pkt_t)) i_predictpacket_x_ff (.*, .clk(clk),        .en ( x_data_en     ),  .din ( i0_predict_p_d                ),  .dout( i0_predict_p_x             ) );
// ...
   rvdffppe #($bits(el2_predict_pkt_t)+1) i_r_ff0         (.*, .clk(clk),        .en ( r_ctl_en      ),  .din ({i0_pred_correct_upper_x, i0_predict_p_x}),
                                                                                                          .dout({i0_pred_correct_upper_r, i0_pp_r       }) );

```

## Dependency declarations

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

```

## Additional requirement

While `rst_l` is low, `dout` is zero without waiting for a clock edge, and otherwise each rising edge of `clk` loads all `WIDTH` bits of `din` into `dout` when `en` is high and leaves `dout` unchanged when `en` is low.
