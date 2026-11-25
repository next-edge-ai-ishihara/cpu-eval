# Implement `el2_lsu_dccm_ctl`

Implement the complete `el2_lsu_dccm_ctl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_lsu_dccm_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
$load_to_use_plus1=0;
```

## Module declaration

```verilog
module el2_lsu_dccm_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic                             lsu_c2_m_clk,            // clocks
   input logic                             lsu_c2_r_clk,            // clocks
   input logic                             lsu_c1_r_clk,            // clocks
   input logic                             lsu_store_c1_r_clk,      // clocks
   input logic                             lsu_free_c2_clk,         // clocks
   input logic                             clk_override,            // Override non-functional clock gating
   input logic                             clk,                     // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.

   input logic                             rst_l,                   // reset, active low

   input                                   el2_lsu_pkt_t lsu_pkt_r,// lsu packets
   input                                   el2_lsu_pkt_t lsu_pkt_m,// lsu packets
   input                                   el2_lsu_pkt_t lsu_pkt_d,// lsu packets
   input logic                             addr_in_dccm_d,          // address maps to dccm
   input logic                             addr_in_pic_d,           // address maps to pic
   input logic                             addr_in_pic_m,           // address maps to pic
   input logic                             addr_in_dccm_m, addr_in_dccm_r,   // address in dccm per pipe stage
   input logic                             addr_in_pic_r,                    // address in pic  per pipe stage
   input logic                             lsu_raw_fwd_lo_r, lsu_raw_fwd_hi_r,
   input logic                             lsu_commit_r,            // lsu instruction in r commits
   input logic                             ldst_dual_m, ldst_dual_r,// load/store is unaligned at 32 bit boundary per pipe stage

   // lsu address down the pipe
   input logic [31:0]                      lsu_addr_d,
   input logic [pt.DCCM_BITS-1:0]          lsu_addr_m,
   input logic [31:0]                      lsu_addr_r,

   // lsu address down the pipe - needed to check unaligned
   input logic [pt.DCCM_BITS-1:0]          end_addr_d,
   input logic [pt.DCCM_BITS-1:0]          end_addr_m,
   input logic [pt.DCCM_BITS-1:0]          end_addr_r,


   input logic                             stbuf_reqvld_any,        // write enable
   input logic [pt.LSU_SB_BITS-1:0]        stbuf_addr_any,          // stbuf address (aligned)

   input logic [pt.DCCM_DATA_WIDTH-1:0]    stbuf_data_any,          // the read out from stbuf
   input logic [pt.DCCM_ECC_WIDTH-1:0]     stbuf_ecc_any,           // the encoded data with ECC bits
   input logic [pt.DCCM_DATA_WIDTH-1:0]    stbuf_fwddata_hi_m,      // stbuf forwarding to load
   input logic [pt.DCCM_DATA_WIDTH-1:0]    stbuf_fwddata_lo_m,      // stbuf forwarding to load
   input logic [pt.DCCM_BYTE_WIDTH-1:0]    stbuf_fwdbyteen_hi_m,    // stbuf forwarding to load
   input logic [pt.DCCM_BYTE_WIDTH-1:0]    stbuf_fwdbyteen_lo_m,    // stbuf forwarding to load

   output logic [pt.DCCM_DATA_WIDTH-1:0]   dccm_rdata_hi_r,         // data from the dccm
   output logic [pt.DCCM_DATA_WIDTH-1:0]   dccm_rdata_lo_r,         // data from the dccm
   output logic [pt.DCCM_ECC_WIDTH-1:0]    dccm_data_ecc_hi_r,      // data from the dccm + ecc
   output logic [pt.DCCM_ECC_WIDTH-1:0]    dccm_data_ecc_lo_r,
   output logic [pt.DCCM_DATA_WIDTH-1:0]   lsu_ld_data_r,           // right justified, ie load byte will have data at 7:0
   output logic [pt.DCCM_DATA_WIDTH-1:0]   lsu_ld_data_corr_r,      // right justified & ECC corrected, ie load byte will have data at 7:0

   input logic                             lsu_double_ecc_error_r,  // lsu has a DED
   input logic                             single_ecc_error_hi_r,   // sec detected on hi dccm bank
   input logic                             single_ecc_error_lo_r,   // sec detected on lower dccm bank
   input logic [pt.DCCM_DATA_WIDTH-1:0]    sec_data_hi_r,           // corrected dccm data
   input logic [pt.DCCM_DATA_WIDTH-1:0]    sec_data_lo_r,           // corrected dccm data
   input logic [pt.DCCM_DATA_WIDTH-1:0]    sec_data_hi_r_ff,        // corrected dccm data
   input logic [pt.DCCM_DATA_WIDTH-1:0]    sec_data_lo_r_ff,        // corrected dccm data
   input logic [pt.DCCM_ECC_WIDTH-1:0]     sec_data_ecc_hi_r_ff,    // the encoded data with ECC bits
   input logic [pt.DCCM_ECC_WIDTH-1:0]     sec_data_ecc_lo_r_ff,    // the encoded data with ECC bits

   output logic [pt.DCCM_DATA_WIDTH-1:0]   dccm_rdata_hi_m,         // data from the dccm
   output logic [pt.DCCM_DATA_WIDTH-1:0]   dccm_rdata_lo_m,         // data from the dccm
   output logic [pt.DCCM_ECC_WIDTH-1:0]    dccm_data_ecc_hi_m,      // data from the dccm + ecc
   output logic [pt.DCCM_ECC_WIDTH-1:0]    dccm_data_ecc_lo_m,
   output logic [pt.DCCM_DATA_WIDTH-1:0]   lsu_ld_data_m,           // right justified, ie load byte will have data at 7:0

   input logic                             lsu_double_ecc_error_m,  // lsu has a DED
   input logic [pt.DCCM_DATA_WIDTH-1:0]    sec_data_hi_m,           // corrected dccm data
   input logic [pt.DCCM_DATA_WIDTH-1:0]    sec_data_lo_m,           // corrected dccm data

   input logic [31:0]                      store_data_m,            // Store data M-stage
   input logic                             dma_dccm_wen,            // Perform DMA writes only for word/dword
   input logic                             dma_pic_wen,             // Perform PIC writes
   input logic [2:0]                       dma_mem_tag_m,           // DMA Buffer entry number M-stage
   input logic [31:0]                      dma_mem_addr,            // DMA request address
   input logic [63:0]                      dma_mem_wdata,           // DMA write data
   input logic [31:0]                      dma_dccm_wdata_lo,       // Shift the dma data to lower bits to make it consistent to lsu stores
   input logic [31:0]                      dma_dccm_wdata_hi,       // Shift the dma data to lower bits to make it consistent to lsu stores
   input logic [pt.DCCM_ECC_WIDTH-1:0]     dma_dccm_wdata_ecc_hi,   // ECC bits for the DMA wdata
   input logic [pt.DCCM_ECC_WIDTH-1:0]     dma_dccm_wdata_ecc_lo,   // ECC bits for the DMA wdata

   output logic [pt.DCCM_DATA_WIDTH-1:0]   store_data_hi_r,
   output logic [pt.DCCM_DATA_WIDTH-1:0]   store_data_lo_r,
   output logic [pt.DCCM_DATA_WIDTH-1:0]   store_datafn_hi_r,       // data from the dccm
   output logic [pt.DCCM_DATA_WIDTH-1:0]   store_datafn_lo_r,       // data from the dccm
   output logic [31:0]                     store_data_r,            // raw store data to be sent to bus
   output logic                            ld_single_ecc_error_r,
   output logic                            ld_single_ecc_error_r_ff,

   output logic [31:0]                     picm_mask_data_m,        // pic data to stbuf
   output logic                            lsu_stbuf_commit_any,    // stbuf wins the dccm port or is to pic
   output logic                            lsu_dccm_rden_m,         // dccm read
   output logic                            lsu_dccm_rden_r,         // dccm read

   output logic                            dccm_dma_rvalid,         // dccm servicing the dma load
   output logic                            dccm_dma_ecc_error,      // DMA load had ecc error
   output logic [2:0]                      dccm_dma_rtag,           // DMA return tag
   output logic [63:0]                     dccm_dma_rdata,          // dccm data to dma request

   // DCCM ports
   output logic                            dccm_wren,               // dccm interface -- write
   output logic                            dccm_rden,               // dccm interface -- write
   output logic [pt.DCCM_BITS-1:0]         dccm_wr_addr_lo,         // dccm interface -- wr addr for lo bank
   output logic [pt.DCCM_BITS-1:0]         dccm_wr_addr_hi,         // dccm interface -- wr addr for hi bank
   output logic [pt.DCCM_BITS-1:0]         dccm_rd_addr_lo,         // dccm interface -- read address for lo bank
   output logic [pt.DCCM_BITS-1:0]         dccm_rd_addr_hi,         // dccm interface -- read address for hi bank
   output logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_wr_data_lo,         // dccm write data for lo bank
   output logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_wr_data_hi,         // dccm write data for hi bank

   input logic [pt.DCCM_FDATA_WIDTH-1:0]   dccm_rd_data_lo,         // dccm read data back from the dccm
   input logic [pt.DCCM_FDATA_WIDTH-1:0]   dccm_rd_data_hi,         // dccm read data back from the dccm

   output logic                            dccm_wr_rdbk_pend_ff,             // write-readback window open -- stall decode/dma
   output logic                            dccm_wr_readback_error,           // write-readback mismatch fault pin
   input logic                             dec_tlu_dccm_wr_readback_disable, // runtime disable (MFDC), default enabled

   // Sticky first-fault DCCM wr readback capture for DMI (debug) visibility.
   output logic                            dccm_wr_rdbk_fault_valid,         // a fault is latched, pending DMI clear
   output logic [pt.DCCM_BITS-1:0]         dccm_wr_rdbk_fault_addr,          // address of the latched fault
   output logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_wr_rdbk_fault_data,          // actual (corrupted) data+ecc read back
   input logic                             dccm_wr_rdbk_fault_clear,         // DMI write-to-clear: re-arm capture

   // PIC ports
   output logic                            picm_wren,               // write to pic
   output logic                            picm_rden,               // read to pick
   output logic                            picm_mken,               // write to pic need a mask
   output logic [31:0]                     picm_rdaddr,             // address for pic read access
   output logic [31:0]                     picm_wraddr,             // address for pic write access
   output logic [31:0]                     picm_wr_data,            // write data
   input logic [31:0]                      picm_rd_data,            // read data

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic                             scan_mode                // scan mode
   /*pragma coverage on*/
);
```

## Parent instantiation

```verilog
   el2_lsu_dccm_ctl #(.pt(pt)) dccm_ctl (
      .lsu_addr_d(lsu_addr_d[31:0]),
      .end_addr_d(end_addr_d[pt.DCCM_BITS-1:0]),
      .lsu_addr_m(lsu_addr_m[pt.DCCM_BITS-1:0]),
      .lsu_addr_r(lsu_addr_r[31:0]),

      .end_addr_m(end_addr_m[pt.DCCM_BITS-1:0]),
      .end_addr_r(end_addr_r[pt.DCCM_BITS-1:0]),
      .*
   );
```

## Dependency declarations

### design/include/el2_def.sv

```verilog
typedef struct packed {
                       logic fast_int;
/* verilator lint_off SYMRSVDWORD */
                       logic stack;
/* verilator lint_on SYMRSVDWORD */
                       logic by;
                       logic half;
                       logic word;
                       logic dword;  // for dma
                       logic load;
                       logic store;
                       logic unsign;
                       logic dma;    // dma pkt
                       logic store_data_bypass_d;
                       logic load_ldst_bypass_d;
                       logic store_data_bypass_m;
                       logic valid;
                       } el2_lsu_pkt_t;
```

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
module rvdffsc #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic             clear,
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

## Related source code

### design/lsu/el2_lsu_stbuf.sv

```verilog
   input logic [pt.DCCM_DATA_WIDTH-1:0]  store_data_hi_r,             // merged data from the dccm for stores. This is used for fwding
   input logic [pt.DCCM_DATA_WIDTH-1:0]  store_data_lo_r,             // merged data from the dccm for stores. This is used for fwding
   input logic [pt.DCCM_DATA_WIDTH-1:0]  store_datafn_hi_r,           // merged data from the dccm for stores
   input logic [pt.DCCM_DATA_WIDTH-1:0]  store_datafn_lo_r,           // merged data from the dccm for stores
```

### design/lsu/el2_lsu_ecc.sv

```verilog
   if (pt.LOAD_TO_USE_PLUS1 == 1) begin: L2U_Plus1_1
// ...
   end else begin: L2U_Plus1_0
// ...
      rvdffe #(.WIDTH(pt.DCCM_DATA_WIDTH)) sec_data_hi_rff (.din(sec_data_hi_m[pt.DCCM_DATA_WIDTH-1:0]), .dout(sec_data_hi_r[pt.DCCM_DATA_WIDTH-1:0]), .en(lsu_single_ecc_error_m | clk_override), .*);
      rvdffe #(.WIDTH(pt.DCCM_DATA_WIDTH)) sec_data_lo_rff (.din(sec_data_lo_m[pt.DCCM_DATA_WIDTH-1:0]), .dout(sec_data_lo_r[pt.DCCM_DATA_WIDTH-1:0]), .en(lsu_single_ecc_error_m | clk_override), .*);

   end
```

## Documentation

### docs/source/memory-map.md

```text
## Partial Writes

Rules for partial writes handling are:

* **Core-local addresses:** The core performs a read-modify-write operation and updates ECC to core-local memories (i.e., I- and DCCMs).
```
