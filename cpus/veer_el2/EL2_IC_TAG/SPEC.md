# Implement `EL2_IC_TAG`

Implement the complete `EL2_IC_TAG` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module EL2_IC_TAG` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### `configs/veer.config`

```text
$icache_enable=1;
$icache_waypack=1;
$icache_addr_xor=0;
$icache_num_ways=2;
$icache_banks_way=2;
$icache_2banks=1;
$icache_bank_width=8;
$icache_ln_sz=64;
$icache_ecc=1;
$icache_size=16;

```

## Module declaration

```verilog
module EL2_IC_TAG
import el2_pkg::*;
 #(
`include "el2_param.vh"
 )
     (
      input logic                                                   clk,
      input logic                                                   active_clk,
      input logic                                                   rst_l,
      input logic                                                   clk_override,
      input logic                                                   dec_tlu_core_ecc_disable,

      input logic [31:3]                                            ic_rw_addr,

      input logic [pt.ICACHE_NUM_WAYS-1:0]                         ic_wr_en,             // way
      input logic [pt.ICACHE_NUM_WAYS-1:0]                         ic_tag_valid,
      input logic                                                  ic_rd_en,

      input logic [pt.ICACHE_INDEX_HI:3]                           ic_debug_addr,        // Read/Write addresss to the Icache.
      input logic                                                  ic_debug_rd_en,       // Icache debug rd
      input logic                                                  ic_debug_wr_en,       // Icache debug wr
      input logic                                                  ic_debug_tag_array,   // Debug tag array
      input logic [pt.ICACHE_NUM_WAYS-1:0]                         ic_debug_way,         // Debug way. Rd or Wr.

      el2_mem_if.veer_icache_tag                                  icache_export,

      output logic [25:0]                                          ictag_debug_rd_data,
      input  logic [70:0]                                          ic_debug_wr_data,     // Debug wr cache.

      output logic [pt.ICACHE_NUM_WAYS-1:0]                        ic_rd_hit,
      output logic                                                 ic_tag_perr,
      // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
      /*pragma coverage off*/
      input  logic                                                 scan_mode
      /*pragma coverage on*/
   ) ;

```

## Parent instantiation

```verilog

   EL2_IC_TAG #(.pt(pt)) ic_tag_inst
          (
           .*,
           .icache_export(local_icache_export.veer_icache_tag),
           .ic_wr_en     (ic_wr_en[pt.ICACHE_NUM_WAYS-1:0]),
           .ic_debug_addr(ic_debug_addr[pt.ICACHE_INDEX_HI:3]),
           .ic_rw_addr   (ic_rw_addr[31:3])
           ) ;

```

## Dependency declarations

### `design/lib/el2_mem_if.sv`

```verilog
  // ICACHE TAG
  logic [pt.ICACHE_NUM_WAYS-1:0]                     ic_tag_clken_final;
  logic [pt.ICACHE_NUM_WAYS-1:0]                     ic_tag_wren_q;
  logic [(26*pt.ICACHE_NUM_WAYS)-1 :0]               ic_tag_wren_biten_vec;
  logic [(26*pt.ICACHE_NUM_WAYS)-1 :0]               ic_tag_data_raw_packed_pre;
  logic [25:0]                                       ic_tag_wr_data;
  logic [pt.ICACHE_INDEX_HI: pt.ICACHE_TAG_INDEX_LO] ic_rw_addr_q;
  logic [pt.ICACHE_NUM_WAYS-1:0] [25:0]              ic_tag_data_raw_pre;

  // ...

  modport veer_icache_tag(
      // tag
      output ic_tag_clken_final, ic_tag_wren_q, ic_tag_wren_biten_vec, ic_tag_wr_data, ic_rw_addr_q,
      input ic_tag_data_raw_packed_pre,ic_tag_data_raw_pre
  );

```

### `design/lib/beh_lib.sv`

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

// ...
`ifndef RV_PHYSICAL
   if (WIDTH >= 8 || OVERRIDE==1) begin: genblock
`endif

// ...
`ifndef RV_PHYSICAL
   end
   else
     $error("%m: rvdffie must be WIDTH >= 8");
`endif

// ...

module rveven_paritygen #(WIDTH = 16)  (
                                         input  logic [WIDTH-1:0]  data_in,         // Data
                                         output logic              parity_out       // generated even parity
                                         );

// ...

module rveven_paritycheck #(WIDTH = 16)  (
                                           input  logic [WIDTH-1:0]  data_in,         // Data
                                           input  logic              parity_in,
                                           output logic              parity_err       // Parity error
                                           );

// ...

module rvecc_encode  (
                      input [31:0] din,
                      output [6:0] ecc_out
                      );

// ...

module rvecc_decode  (
                      input         en,
                      input [31:0]  din,
                      input [6:0]   ecc_in,
                      input         sed_ded,    // only do detection and no correction. Used for the I$
                      output [31:0] dout,
                      output [6:0]  ecc_out,
                      output        single_ecc_error,
                      output        double_ecc_error

                      );

```

## Related source code

### `design/ifu/el2_ifu_mem_ctl.sv`

```verilog
   output logic [pt.ICACHE_NUM_WAYS-1:0]                ic_tag_valid,       // Valid bits when accessing the Icache. One valid bit per way. F2 stage

   input  logic [pt.ICACHE_NUM_WAYS-1:0]                ic_rd_hit,          // Compare hits from Icache tags. Per way.  F2 stage
// ...
   assign ic_act_hit_f         = (|ic_rd_hit[pt.ICACHE_NUM_WAYS-1:0]) & fetch_req_icache_f & ~reset_all_tags & (~miss_pending | (miss_state==HIT_U_MISS)) & ~sel_mb_addr_ff;
// ...
 assign   ic_rd_en    =  (ifc_fetch_req_bf & ~ifc_fetch_uncacheable_bf & ~ifc_iccm_access_bf  &
                            ~(((miss_state == STREAM) & ~miss_state_en)                                       |
                              ((miss_state == CRIT_BYP_OK) & ~miss_state_en)                                  |
                              ((miss_state == STALL_SCND_MISS) & ~miss_state_en)                              |
                              ((miss_state == MISS_WAIT) & ~miss_state_en)                                    |
                              ((miss_state == CRIT_WRD_RDY) & ~miss_state_en)  |
                              ((miss_state == CRIT_BYP_OK) &  miss_state_en &  (miss_nxtstate == MISS_WAIT))  ))  |
                             ( ifc_fetch_req_bf & exu_flush_final  & ~ifc_fetch_uncacheable_bf & ~ifc_iccm_access_bf )     ;
// ...
   assign ic_tag_valid[pt.ICACHE_NUM_WAYS-1:0] = ic_tag_valid_unq[pt.ICACHE_NUM_WAYS-1:0]   & {pt.ICACHE_NUM_WAYS{(~fetch_uncacheable_ff & ifc_fetch_req_f_raw) }} ;
```

### `testbench/icache_macros.svh`

```verilog
`define EL2_IC_TAG_PACKED_SRAM(depth,width)                                                       \
   ram_be_``depth``x``width  ic_way_tag (                                                         \
      .CLK (el2_mem_export.clk),                                                                  \
      .ME  (|el2_mem_export.ic_tag_clken_final),                                                  \
      .WE  (|el2_mem_export.ic_tag_wren_q[pt.ICACHE_NUM_WAYS-1:0]),                               \
      .WEM (el2_mem_export.ic_tag_wren_biten_vec[``width-1:0]),                                   \
                                                                                                  \
      .D   ({pt.ICACHE_NUM_WAYS{el2_mem_export.ic_tag_wr_data[``width/pt.ICACHE_NUM_WAYS-1:0]}}), \
      .ADR (el2_mem_export.ic_rw_addr_q[pt.ICACHE_INDEX_HI:pt.ICACHE_TAG_INDEX_LO]),              \
      .Q   (el2_mem_export.ic_tag_data_raw_packed_pre[``width-1:0]),                              \
      .ROP ( ),                                                                                   \
                                                                                                  \
      .TEST1    (1'b0),                                                                           \
      .RME      (1'b0),                                                                           \
      .RM       (4'b0000),                                                                        \
                                                                                                  \
      .LS       (1'b0),                                                                           \
      .DS       (1'b0),                                                                           \
      .SD       (1'b0),                                                                           \
                                                                                                  \
      .TEST_RNM (1'b0),                                                                           \
      .BC1      (1'b0),                                                                           \
      .BC2      (1'b0)                                                                            \
   );

```

### `design/lib/mem_lib.sv`

```verilog
`define EL2_RAM_BE(depth, width)           \
module ram_be_``depth``x``width(            \
   input logic [$clog2(depth)-1:0] ADR,     \
   input logic [(width-1):0] D, WEM,        \
   output logic [(width-1):0] Q,            \
    `EL2_LOCAL_RAM_TEST_IO                 \
);                                          \
reg [(width-1):0] ram_core [(depth-1):0];   \
`ifdef GTLSIM                               \
integer i;                                  \
initial begin                               \
   for (i=0; i<depth; i=i+1)                \
     ram_core[i] = '0;                      \
end                                         \
`endif                                      \
always @(posedge CLK) begin                 \
`ifdef GTLSIM                               \
   if (ME && WE)       ram_core[ADR] <= D & WEM | ~WEM & ram_core[ADR];      \
`else                                       \
   if (ME && WE) begin ram_core[ADR] <= D & WEM | ~WEM & ram_core[ADR]; Q <= 'x; end  \
`endif                                      \
   if (ME && ~WE) Q <= ram_core[ADR];          \
end                                         \
assign ROP = ME;                            \
                                            \
endmodule

```
