# Implement `rvdffe`

Implement the complete `rvdffe` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvdffe` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
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
```

## Parent instantiation

### design/dbg/el2_dbg.sv

```verilog
   rvdffe #(32)    dbg_sbdata0_reg    (.*, .din(sbdata0_din[31:0]), .dout(sbdata0_reg[31:0]), .en(sbdata0_reg_wren), .rst_l(dbg_dm_rst_l));
```

### design/dec/el2_dec_decode_ctl.sv

```verilog
   rvdffe #(.WIDTH(5),.OVERRIDE(1))  i0rdff  (.*, .en(i0_div_decode_d),        .din(i0r.rd[4:0]),             .dout(div_waddr_wb[4:0]));
```

### design/lib/beh_lib.sv

```verilog
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

   logic                      l1clk;
   logic                      final_en;

`ifndef RV_PHYSICAL
   if (WIDTH >= 8 || OVERRIDE==1) begin: genblock
`endif

      assign final_en = (|(din ^ dout)) & en;

`ifdef RV_FPGA_OPTIMIZE
      rvdffs #(WIDTH) dff ( .*, .en(final_en) );
`else
      rvdffe #(WIDTH) dff (.*,  .en(final_en));
`endif

`ifndef RV_PHYSICAL
   end
   else
      $error("%m: rvdffie width must be >= 8");
`endif

endmodule
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

module rvdffs #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
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
