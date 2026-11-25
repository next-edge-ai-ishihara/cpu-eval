# Implement `el2_mem`

Implement the complete `el2_mem` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_mem` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_mem
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
(
   input logic         clk,
   input logic         rst_l,
   input logic         dccm_clk_override,
   input logic         icm_clk_override,
   input logic         dec_tlu_core_ecc_disable,

   //DCCM ports
   input logic         dccm_wren,
   input logic         dccm_rden,
   input logic [pt.DCCM_BITS-1:0]  dccm_wr_addr_lo,
   input logic [pt.DCCM_BITS-1:0]  dccm_wr_addr_hi,
   input logic [pt.DCCM_BITS-1:0]  dccm_rd_addr_lo,
   input logic [pt.DCCM_BITS-1:0]  dccm_rd_addr_hi,
   input logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_wr_data_lo,
   input logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_wr_data_hi,


   output logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_lo,
   output logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_rd_data_hi,

   //ICCM ports
   input logic [pt.ICCM_BITS-1:1]  iccm_rw_addr,
   input logic                                        iccm_buf_correct_ecc,                    // ICCM is doing a single bit error correct cycle
   input logic                                        iccm_correction_state,               // ICCM is doing a single bit error correct cycle
   input logic         iccm_wren,
   input logic         iccm_rden,
   input logic [2:0]   iccm_wr_size,
   input logic [77:0]  iccm_wr_data,

   output logic [77:0] iccm_rd_data_ecc,

   // Icache and Itag Ports

   input  logic [31:1]  ic_rw_addr,
   input  logic [pt.ICACHE_NUM_WAYS-1:0]   ic_tag_valid,
   input  logic [pt.ICACHE_NUM_WAYS-1:0]   ic_wr_en,
   input  logic         ic_rd_en,

   input  logic [pt.ICACHE_BANKS_WAY-1:0][70:0]               ic_wr_data,         // Data to fill to the Icache. With ECC
   input  logic [70:0]               ic_debug_wr_data,   // Debug wr cache.
   output logic [70:0]               ic_debug_rd_data ,  // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
   input  logic [pt.ICACHE_INDEX_HI:3]               ic_debug_addr,      // Read/Write address to the Icache.
   input  logic                      ic_debug_rd_en,     // Icache debug rd
   input  logic                      ic_debug_wr_en,     // Icache debug wr
   input  logic                      ic_debug_tag_array, // Debug tag array
   input  logic [pt.ICACHE_NUM_WAYS-1:0]                ic_debug_way,       // Debug way. Rd or Wr.

   output logic [141:0]                   ic_rd_data ,         // Raw way-muxed 142-bit ECC-protected word pair. F2 stage.
   output logic [1:0]                     ic_rd_addr_lo,       // F2-aligned ic_rw_addr_ff[2:1] for core-side rotate
   output logic [pt.ICACHE_BANKS_WAY-1:0] ic_rd_bank_check_en, // Per-bank ECC check enable for core-side decode

   output logic [25:0]               ictag_debug_rd_data,// Debug icache tag.


   output logic [pt.ICACHE_NUM_WAYS-1:0]   ic_rd_hit,
   output logic         ic_tag_perr,        // Icache Tag parity error

   el2_mem_if.veer_sram_src   mem_export,
   el2_mem_if.veer_icache_src icache_export,

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic         scan_mode
   /*pragma coverage on*/

);
```

## Parent instantiation

### design/el2_veer_wrapper.sv

```verilog
   el2_mem  #(.pt(pt)) mem (
                             .clk(active_l2clk),
                             .rst_l(core_rst_l),
                             .mem_export(el2_mem_export),
                             .icache_export(el2_icache_export),
                             .*
                             );
```

## Dependency declarations

### design/lib/el2_mem_if.sv

```verilog
interface el2_mem_if
import el2_pkg::*;
#(
    `include "el2_param.vh"
) ();
  //////////////////////////////////////////
  // Clock
  logic                                                               clk;


  //////////////////////////////////////////
  // ICCM
  logic [pt.ICCM_NUM_BANKS-1:0]                                       iccm_clken;
  logic [pt.ICCM_NUM_BANKS-1:0]                                       iccm_wren_bank;
  logic [pt.ICCM_NUM_BANKS-1:0][pt.ICCM_BITS-1:pt.ICCM_BANK_INDEX_LO] iccm_addr_bank;

  logic [pt.ICCM_NUM_BANKS-1:0][                                31:0] iccm_bank_wr_data;
  logic [pt.ICCM_NUM_BANKS-1:0][               pt.ICCM_ECC_WIDTH-1:0] iccm_bank_wr_ecc;
  logic [pt.ICCM_NUM_BANKS-1:0][                                31:0] iccm_bank_dout;
  logic [pt.ICCM_NUM_BANKS-1:0][               pt.ICCM_ECC_WIDTH-1:0] iccm_bank_ecc;


  //////////////////////////////////////////
  // DCCM
  logic [pt.DCCM_NUM_BANKS-1:0]                                       dccm_clken;
  logic [pt.DCCM_NUM_BANKS-1:0]                                       dccm_wren_bank;
  logic [pt.DCCM_NUM_BANKS-1:0][pt.DCCM_BITS-1:(pt.DCCM_BANK_BITS+2)] dccm_addr_bank;
  logic [pt.DCCM_NUM_BANKS-1:0][              pt.DCCM_DATA_WIDTH-1:0] dccm_wr_data_bank;
  logic [pt.DCCM_NUM_BANKS-1:0][               pt.DCCM_ECC_WIDTH-1:0] dccm_wr_ecc_bank;
  logic [pt.DCCM_NUM_BANKS-1:0][              pt.DCCM_DATA_WIDTH-1:0] dccm_bank_dout;
  logic [pt.DCCM_NUM_BANKS-1:0][               pt.DCCM_ECC_WIDTH-1:0] dccm_bank_ecc;

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

  //////////////////////////////////////////
  // MODPORTS
  // Complete modport
  modport veer_sram_icache_src(
      output clk,
      // ICCM
      output iccm_clken, iccm_wren_bank, iccm_addr_bank, iccm_bank_wr_data, iccm_bank_wr_ecc,
      input iccm_bank_dout, iccm_bank_ecc,
      // DCCM
      output dccm_clken, dccm_wren_bank, dccm_addr_bank, dccm_wr_data_bank, dccm_wr_ecc_bank,
      input dccm_bank_dout, dccm_bank_ecc,
      // ICACHE data
      output ic_b_sb_wren, ic_b_sb_bit_en_vec, ic_sb_wr_data, ic_rw_addr_bank_q, ic_bank_way_clken_final, ic_bank_way_clken_final_up,
      input wb_packeddout_pre, wb_dout_pre_up,
      // ICACHE tag
      output ic_tag_clken_final, ic_tag_wren_q, ic_tag_wren_biten_vec, ic_tag_wr_data, ic_rw_addr_q,
      input ic_tag_data_raw_packed_pre, ic_tag_data_raw_pre
  );

  modport veer_iccm(
      input clk,
      // ICCM
      output iccm_clken, iccm_wren_bank, iccm_addr_bank, iccm_bank_wr_data, iccm_bank_wr_ecc,
      input iccm_bank_dout, iccm_bank_ecc
  );

  modport veer_dccm(
      input clk,
      // DCCM
      output dccm_clken, dccm_wren_bank, dccm_addr_bank, dccm_wr_data_bank, dccm_wr_ecc_bank,
      input dccm_bank_dout, dccm_bank_ecc
  );

  modport veer_sram_src(
      output clk,
      // ICCM
      output iccm_clken, iccm_wren_bank, iccm_addr_bank, iccm_bank_wr_data, iccm_bank_wr_ecc,
      input iccm_bank_dout, iccm_bank_ecc,
      // DCCM
      output dccm_clken, dccm_wren_bank, dccm_addr_bank, dccm_wr_data_bank, dccm_wr_ecc_bank,
      input dccm_bank_dout, dccm_bank_ecc
  );

  modport veer_sram_sink(
      input clk,
      // ICCM
      input iccm_clken, iccm_wren_bank, iccm_addr_bank, iccm_bank_wr_data, iccm_bank_wr_ecc,
      output iccm_bank_dout, iccm_bank_ecc,
      // DCCM
      input dccm_clken, dccm_wren_bank, dccm_addr_bank, dccm_wr_data_bank, dccm_wr_ecc_bank,
      output dccm_bank_dout, dccm_bank_ecc
  );

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

### design/ifu/el2_ifu_ic_mem.sv

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

### design/ifu/el2_ifu_iccm_mem.sv

```verilog
module el2_ifu_iccm_mem
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input logic                                        clk,                                 // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic                                        active_clk,                          // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
   input logic                                        rst_l,                               // reset, active low
   input logic                                        clk_override,                        // Override non-functional clock gating

   input logic                                        iccm_wren,                           // ICCM write enable
   input logic                                        iccm_rden,                           // ICCM read enable
   input logic [pt.ICCM_BITS-1:1]                     iccm_rw_addr,                        // ICCM read/write address
   input logic                                        iccm_buf_correct_ecc,                // ICCM is doing a single bit error correct cycle
   input logic                                        iccm_correction_state,               // ICCM under a correction - This is needed to guard replacements when hit
   input logic [2:0]                                  iccm_wr_size,                        // ICCM write size
   input logic [77:0]                                 iccm_wr_data,                        // ICCM write data

   el2_mem_if.veer_iccm                               iccm_mem_export,                     // RAM repositioned in testbench and connected by this interface

   output logic [77:0]                                iccm_rd_data_ecc,                    // ICCM read ecc
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic                                       scan_mode                            // Scan mode control
   /*pragma coverage on*/

);
```

### design/lib/beh_lib.sv

```verilog
module rvoclkhdr
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

### design/lsu/el2_lsu_dccm_mem.sv

```verilog
module el2_lsu_dccm_mem
  import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input logic         clk,                                             // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic         active_clk,                                      // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
   input logic         rst_l,                                           // reset, active low
   input logic         clk_override,                                    // Override non-functional clock gating

   input logic         dccm_wren,                                       // write enable
   input logic         dccm_rden,                                       // read enable
   input logic [pt.DCCM_BITS-1:0]  dccm_wr_addr_lo,                     // write address
   input logic [pt.DCCM_BITS-1:0]  dccm_wr_addr_hi,                     // write address
   input logic [pt.DCCM_BITS-1:0]  dccm_rd_addr_lo,                     // read address
   input logic [pt.DCCM_BITS-1:0]  dccm_rd_addr_hi,                     // read address for the upper bank in case of a misaligned access
   input logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_wr_data_lo,              // write data
   input logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_wr_data_hi,              // write data
   el2_mem_if.veer_dccm                   dccm_mem_export,              // RAM repositioned in testbench and connected by this interface

   output logic [pt.DCCM_FDATA_WIDTH-1:0] dccm_rd_data_lo,              // read data from the lo bank
   output logic [pt.DCCM_FDATA_WIDTH-1:0] dccm_rd_data_hi,              // read data from the hi bank

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic         scan_mode
   /*pragma coverage on*/
);
```
