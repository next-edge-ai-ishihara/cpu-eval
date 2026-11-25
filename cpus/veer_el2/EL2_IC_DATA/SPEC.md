# Implement `EL2_IC_DATA`

Implement the complete `EL2_IC_DATA` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module EL2_IC_DATA` definition in a single SystemVerilog code block, with no text outside the block.

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
module EL2_IC_DATA
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
     (
      input logic clk,
      input logic active_clk,
      input logic rst_l,
      input logic clk_override,

      input logic [31:1]                  ic_rw_addr,
      input logic [pt.ICACHE_NUM_WAYS-1:0]ic_wr_en,
      input logic                          ic_rd_en,           // Read enable

      input  logic [pt.ICACHE_BANKS_WAY-1:0][70:0]    ic_wr_data,         // Data to fill to the Icache. With ECC
      output logic [141:0]                            ic_rd_data ,        // Raw way-muxed 142-bit ECC-protected word pair. F2 stage.
      output logic [1:0]                              ic_rd_addr_lo,      // F2-aligned ic_rw_addr_ff[2:1] for core-side rotate
      output logic [pt.ICACHE_BANKS_WAY-1:0]          ic_rd_bank_check_en,// Per-bank ECC check enable for core-side decode
      input  logic [70:0]                             ic_debug_wr_data,   // Debug wr cache.
      output logic [70:0]                             ic_debug_rd_data ,  // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
      input logic [pt.ICACHE_INDEX_HI:3]     ic_debug_addr,     // Read/Write address to the Icache.
      input logic                            ic_debug_rd_en,      // Icache debug rd
      input logic                            ic_debug_wr_en,      // Icache debug wr
      input logic                            ic_debug_tag_array,  // Debug tag array
      input logic [pt.ICACHE_NUM_WAYS-1:0]   ic_debug_way,        // Debug way. Rd or Wr.

      input logic [pt.ICACHE_NUM_WAYS-1:0]ic_rd_hit,
      el2_mem_if.veer_icache_data         icache_export,
      // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
      /*pragma coverage off*/
      input  logic                         scan_mode
      /*pragma coverage on*/

      ) ;

```

## Parent instantiation

```verilog

   EL2_IC_DATA #(.pt(pt)) ic_data_inst
          (
           .*,
           .icache_export(local_icache_export.veer_icache_data),
           .ic_wr_en     (ic_wr_en[pt.ICACHE_NUM_WAYS-1:0]),
           .ic_debug_addr(ic_debug_addr[pt.ICACHE_INDEX_HI:3]),
           .ic_rw_addr   (ic_rw_addr[31:1])
           ) ;

```

## Dependency declarations

### `design/lib/el2_mem_if.sv`

```verilog
  // ICACHE DATA
  logic [pt.ICACHE_BANKS_WAY-1:0][pt.ICACHE_NUM_WAYS-1:0]                       ic_b_sb_wren;
  logic [pt.ICACHE_BANKS_WAY-1:0][(71*pt.ICACHE_NUM_WAYS)-1:0]                  ic_b_sb_bit_en_vec;
  logic [pt.ICACHE_BANKS_WAY-1:0][(71*pt.ICACHE_NUM_WAYS)-1:0]                  wb_packeddout_pre;
  logic [pt.ICACHE_BANKS_WAY-1:0][70:0]                                         ic_sb_wr_data;
  logic [pt.ICACHE_BANKS_WAY-1:0][pt.ICACHE_INDEX_HI : pt.ICACHE_DATA_INDEX_LO] ic_rw_addr_bank_q;
  logic [pt.ICACHE_BANKS_WAY-1:0]                                               ic_bank_way_clken_final;
  logic [pt.ICACHE_NUM_WAYS-1:0][pt.ICACHE_BANKS_WAY-1:0]                       ic_bank_way_clken_final_up;
  logic [pt.ICACHE_NUM_WAYS-1:0][pt.ICACHE_BANKS_WAY-1:0][71-1:0]               wb_dout_pre_up;

  // ...

  modport veer_icache_data(
      // data
      output ic_b_sb_wren, ic_b_sb_bit_en_vec, ic_sb_wr_data, ic_rw_addr_bank_q, ic_bank_way_clken_final, ic_bank_way_clken_final_up,
      input wb_packeddout_pre, wb_dout_pre_up
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

```

## Related source code

### `design/ifu/el2_ifu_mem_ctl.sv`

```verilog
   assign ic_wr_addr_bits_hi_3[pt.ICACHE_BEAT_ADDR_HI:3]  = ifu_bus_rid_ff[pt.ICACHE_BEAT_BITS-1:0] & {pt.ICACHE_BEAT_BITS{bus_ifu_wr_en_ff}};

// ...
   assign sel_mb_addr  = ((miss_pending & write_ic_16_bytes & ~uncacheable_miss_ff) | reset_tag_valid_for_miss) ;
   assign ifu_ic_rw_int_addr[31:1] = ({31{ sel_mb_addr}}  &  {imb_ff[31:pt.ICACHE_BEAT_ADDR_HI+1] , ic_wr_addr_bits_hi_3[pt.ICACHE_BEAT_ADDR_HI:3] , imb_ff[2:1]})  |
                                     ({31{~sel_mb_addr}}  &  ifc_fetch_addr_bf[31:1] )   ;

// ...
  assign ic_rw_addr[31:1]      = ifu_ic_rw_int_addr[31:1] ;

// ...
   for (genvar i=0; i < pt.ICACHE_BANKS_WAY ; i++) begin : ic_wr_data_loop
      assign ic_wr_data[i][70:0]  =  ic_wr_16bytes_data[((71*i)+70): (71*i)];
   end

// ...
  assign ic_wr_16bytes_data[141:0] =  ifu_bus_rid_ff[0] ? {ic_wr_ecc[6:0], ifu_bus_rdata_ff[63:0] ^ ic_wr_addr_infect,
                                                           ic_miss_buff_ecc[6:0], ic_miss_buff_half[63:0] ^ ic_wr_addr_infect}
                                                        :
                                                          {ic_miss_buff_ecc[6:0],  ic_miss_buff_half[63:0] ^ ic_wr_addr_infect,
                                                           ic_wr_ecc[6:0] , ifu_bus_rdata_ff[63:0] ^ ic_wr_addr_infect};

// ...
  // Core-side alignment (byte-rotate) and ECC / parity check of the raw 142-bit
  // ic_rd_data input (ic_rd_data_aligned / ic_eccerr_int / ic_parerr_int declared above).
  if (pt.ICACHE_ECC) begin : g_ic_rd_ecc_core
     logic [63:0]  ic_rd_rot;
     logic [141:0] ic_rd_data_fixed;
     assign ic_rd_data_fixed = {ic_rd_data[141:135], ic_rd_data[134:71] ^ ic_rd_addr_infect,
                                ic_rd_data[70:64],   ic_rd_data[63:0]   ^ ic_rd_addr_infect};
     assign ic_rd_rot = (ic_rd_addr_lo == 2'b00) ? ic_rd_data_fixed[63:0]                              :
                        (ic_rd_addr_lo == 2'b01) ? {ic_rd_data_fixed[86:71],  ic_rd_data_fixed[63:16]} :
                        (ic_rd_addr_lo == 2'b10) ? {ic_rd_data_fixed[102:71], ic_rd_data_fixed[63:32]} :
                                                 {ic_rd_data_fixed[118:71], ic_rd_data_fixed[63:48]};
     assign ic_rd_data_aligned = ic_sel_premux_data ? ic_premux_data[63:0] : ic_rd_rot;
     for (genvar i=0; i<pt.ICACHE_BANKS_WAY; i++) begin : g_dec
        rvecc_decode_64 ecc_decode_64 (
           .en       (ic_rd_bank_check_en[i]),
           .din      (ic_rd_data_fixed[71*i +: 64]),
           .ecc_in   (ic_rd_data_fixed[71*i+64 +: 7]),
           .ecc_error(ic_eccerr_int[i]));
     end
     assign ic_parerr_int = '0;

// ...
assign ic_wr_en[pt.ICACHE_NUM_WAYS-1:0] = bus_ic_wr_en[pt.ICACHE_NUM_WAYS-1:0] & {pt.ICACHE_NUM_WAYS{write_ic_16_bytes}};

```

### `testbench/icache_macros.svh`

```verilog
`define EL2_PACKED_IC_DATA_SRAM(depth,width,waywidth,k)                                         \
    ram_be_``depth``x``width  ic_bank_sb_way_data (                                             \
      .CLK   (el2_mem_export.clk),                                                              \
      .WE    (|el2_mem_export.ic_b_sb_wren[k]),              // OR of all the ways in the bank  \
      .WEM   (el2_mem_export.ic_b_sb_bit_en_vec[k]),         // 284 bits of bit enables         \
      .D     ({pt.ICACHE_NUM_WAYS{el2_mem_export.ic_sb_wr_data[k][``waywidth-1:0]}}),           \
      .ADR   (el2_mem_export.ic_rw_addr_bank_q[k][pt.ICACHE_INDEX_HI:pt.ICACHE_DATA_INDEX_LO]), \
      .Q     (el2_mem_export.wb_packeddout_pre[k]),                                             \
      .ME    (|el2_mem_export.ic_bank_way_clken_final[k]),                                      \
      .ROP   ( ),                                                                               \
      .TEST1 (1'b0),                                                                            \
      .RME   (1'b0),                                                                            \
      .RM    (4'b0000),                                                                         \
                                                                                                \
      .LS    (1'b0),                                                                            \
      .DS    (1'b0),                                                                            \
      .SD    (1'b0),                                                                            \
                                                                                                \
      .TEST_RNM (1'b0),                                                                         \
      .BC1      (1'b0),                                                                         \
      .BC2      (1'b0)                                                                          \
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
