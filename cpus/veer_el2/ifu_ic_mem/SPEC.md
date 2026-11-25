# Implement `el2_ifu_ic_mem`

Implement the complete `el2_ifu_ic_mem` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_ifu_ic_mem` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_ifu_ic_mem
import el2_pkg::*;
 #(
`include "el2_param.vh"
 )
  (
      input logic                                   clk,                // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
      input logic                                   active_clk,         // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
      input logic                                   rst_l,              // reset, active low
      input logic                                   clk_override,       // Override non-functional clock gating
      input logic                                   dec_tlu_core_ecc_disable,  // Disable ECC checking

      input logic [31:1]                            ic_rw_addr,
      input logic [pt.ICACHE_NUM_WAYS-1:0]          ic_wr_en  ,         // Which way to write
      input logic                                   ic_rd_en  ,         // Read enable
      input logic [pt.ICACHE_INDEX_HI:3]            ic_debug_addr,      // Read/Write address to the Icache.
      input logic                                   ic_debug_rd_en,     // Icache debug rd
      input logic                                   ic_debug_wr_en,     // Icache debug wr
      input logic                                   ic_debug_tag_array, // Debug tag array
      input logic [pt.ICACHE_NUM_WAYS-1:0]          ic_debug_way,       // Debug way. Rd or Wr.

      input  logic [pt.ICACHE_BANKS_WAY-1:0][70:0]  ic_wr_data,         // Data to fill to the Icache. With ECC
      output logic [141:0]                          ic_rd_data ,        // Raw way-muxed 142-bit ECC-protected word pair. F2 stage.
      output logic [1:0]                            ic_rd_addr_lo,      // F2-aligned ic_rw_addr_ff[2:1] for core-side rotate
      output logic [pt.ICACHE_BANKS_WAY-1:0]        ic_rd_bank_check_en,// Per-bank ECC check enable for core-side decode
      output logic [70:0]                           ic_debug_rd_data ,  // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
      output logic [25:0]                           ictag_debug_rd_data,// Debug icache tag.
      input logic  [70:0]                           ic_debug_wr_data,   // Debug wr cache.

      input logic [pt.ICACHE_NUM_WAYS-1:0]          ic_tag_valid,       // Valid from the I$ tag valid outside (in flops).

      el2_mem_if.veer_icache_src icache_export,

      output logic [pt.ICACHE_NUM_WAYS-1:0]         ic_rd_hit,          // ic_rd_hit[3:0]
      output logic                                  ic_tag_perr,        // Tag Parity error
      // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
      /*pragma coverage off*/
      input  logic                                  scan_mode           // Flop scan mode control
      /*pragma coverage on*/
      ) ;

```

## Parent instantiation

```verilog
   el2_ifu_ic_mem #(.pt(pt)) icm  (
      .clk_override(icm_clk_override),
      .icache_export(mem_export_local.veer_icache_src),
      .*
   );

```

## Dependency declarations

### `EL2_IC_DATA`

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

### `EL2_IC_TAG`

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

### design/lib/el2_mem_if.sv

```verilog
interface el2_mem_if
import el2_pkg::*;
#(
    `include "el2_param.vh"
) ();

// ...
  //////////////////////////////////////////
  // ICACHE DATA
  logic [pt.ICACHE_BANKS_WAY-1:0][pt.ICACHE_NUM_WAYS-1:0]                       ic_b_sb_wren;
  logic [pt.ICACHE_BANKS_WAY-1:0][(71*pt.ICACHE_NUM_WAYS)-1:0]                  ic_b_sb_bit_en_vec;
  logic [pt.ICACHE_BANKS_WAY-1:0][(71*pt.ICACHE_NUM_WAYS)-1:0]                  wb_packeddout_pre;
  logic [pt.ICACHE_BANKS_WAY-1:0][70:0]                                         ic_sb_wr_data;
  logic [pt.ICACHE_BANKS_WAY-1:0][pt.ICACHE_INDEX_HI : pt.ICACHE_DATA_INDEX_LO] ic_rw_addr_bank_q;
  logic [pt.ICACHE_BANKS_WAY-1:0]                                               ic_bank_way_clken_final;
  logic [pt.ICACHE_NUM_WAYS-1:0][pt.ICACHE_BANKS_WAY-1:0]                       ic_bank_way_clken_final_up;
  logic [pt.ICACHE_NUM_WAYS-1:0][pt.ICACHE_BANKS_WAY-1:0][71-1:0]               wb_dout_pre_up;

  //////////////////////////////////////////
  // ICACHE TAG
  logic [pt.ICACHE_NUM_WAYS-1:0]                     ic_tag_clken_final;
  logic [pt.ICACHE_NUM_WAYS-1:0]                     ic_tag_wren_q;
  logic [(26*pt.ICACHE_NUM_WAYS)-1 :0]               ic_tag_wren_biten_vec;
  logic [(26*pt.ICACHE_NUM_WAYS)-1 :0]               ic_tag_data_raw_packed_pre;
  logic [25:0]                                       ic_tag_wr_data;
  logic [pt.ICACHE_INDEX_HI: pt.ICACHE_TAG_INDEX_LO] ic_rw_addr_q;
  logic [pt.ICACHE_NUM_WAYS-1:0] [25:0]              ic_tag_data_raw_pre;


// ...
  modport veer_icache_data(
      // data
      output ic_b_sb_wren, ic_b_sb_bit_en_vec, ic_sb_wr_data, ic_rw_addr_bank_q, ic_bank_way_clken_final, ic_bank_way_clken_final_up,
      input wb_packeddout_pre, wb_dout_pre_up
  );

  modport veer_icache_tag(
      // tag
      output ic_tag_clken_final, ic_tag_wren_q, ic_tag_wren_biten_vec, ic_tag_wr_data, ic_rw_addr_q,
      input ic_tag_data_raw_packed_pre,ic_tag_data_raw_pre
  );

  modport veer_icache_src(
      // cache uses the same clk as sram, we do not define clk port in this modport,
      // assuming the clk will be connected in sram_src
      // data
      output ic_b_sb_wren, ic_b_sb_bit_en_vec, ic_sb_wr_data, ic_rw_addr_bank_q, ic_bank_way_clken_final, ic_bank_way_clken_final_up,
      input wb_packeddout_pre, wb_dout_pre_up,
      // tag
      output ic_tag_clken_final, ic_tag_wren_q, ic_tag_wren_biten_vec, ic_tag_wr_data, ic_rw_addr_q,
      input ic_tag_data_raw_packed_pre,ic_tag_data_raw_pre
  );

endinterface

```
