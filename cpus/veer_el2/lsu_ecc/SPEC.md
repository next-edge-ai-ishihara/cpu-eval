# Implement `el2_lsu_ecc`

Implement the complete `el2_lsu_ecc` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_lsu_ecc` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
$load_to_use_plus1=0;
```

## Module declaration

```verilog
module el2_lsu_ecc
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
(
   input logic                           clk,                // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic                           lsu_c2_r_clk,       // clock
   input logic                           clk_override,       // Override non-functional clock gating
   input logic                           rst_l,              // reset, active low
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic                           scan_mode,          // scan mode
   /*pragma coverage on*/

   input el2_lsu_pkt_t                  lsu_pkt_m,          // packet in m
   input el2_lsu_pkt_t                  lsu_pkt_r,          // packet in r
   input logic [pt.DCCM_DATA_WIDTH-1:0]  stbuf_data_any,

   input logic                           dec_tlu_core_ecc_disable,  // disables the ecc computation and error flagging

   input logic                           lsu_dccm_rden_r,          // dccm rden
   input logic                           addr_in_dccm_r,           // address in dccm
   input logic  [pt.DCCM_BITS-1:0]       lsu_addr_r,               // start address
   input logic  [pt.DCCM_BITS-1:0]       end_addr_r,               // end address
   input logic  [pt.DCCM_DATA_WIDTH-1:0] dccm_rdata_hi_r,          // data from the dccm
   input logic  [pt.DCCM_DATA_WIDTH-1:0] dccm_rdata_lo_r,          // data from the dccm
   input logic  [pt.DCCM_ECC_WIDTH-1:0]  dccm_data_ecc_hi_r,       // data from the dccm + ecc
   input logic  [pt.DCCM_ECC_WIDTH-1:0]  dccm_data_ecc_lo_r,       // data from the dccm + ecc
   output logic [pt.DCCM_DATA_WIDTH-1:0] sec_data_hi_r,            // corrected dccm data R-stage
   output logic [pt.DCCM_DATA_WIDTH-1:0] sec_data_lo_r,            // corrected dccm data R-stage
   output logic [pt.DCCM_DATA_WIDTH-1:0] sec_data_hi_r_ff,         // corrected dccm data R+1 stage
   output logic [pt.DCCM_DATA_WIDTH-1:0] sec_data_lo_r_ff,         // corrected dccm data R+1 stage

   input logic                           ld_single_ecc_error_r,     // ld has a single ecc error
   input logic                           ld_single_ecc_error_r_ff,  // ld has a single ecc error
   input logic                           lsu_dccm_rden_m,           // dccm rden
   input logic                           addr_in_dccm_m,            // address in dccm
   input logic  [pt.DCCM_BITS-1:0]       lsu_addr_m,                // start address
   input logic  [pt.DCCM_BITS-1:0]       end_addr_m,                // end address
   input logic  [pt.DCCM_DATA_WIDTH-1:0] dccm_rdata_hi_m,           // raw data from mem
   input logic  [pt.DCCM_DATA_WIDTH-1:0] dccm_rdata_lo_m,           // raw data from mem
   input logic  [pt.DCCM_ECC_WIDTH-1:0]  dccm_data_ecc_hi_m,        // ecc read out from mem
   input logic  [pt.DCCM_ECC_WIDTH-1:0]  dccm_data_ecc_lo_m,        // ecc read out from mem
   output logic [pt.DCCM_DATA_WIDTH-1:0] sec_data_hi_m,             // corrected dccm data M-stage
   output logic [pt.DCCM_DATA_WIDTH-1:0] sec_data_lo_m,             // corrected dccm data M-stage

   input logic                           dma_dccm_wen,              // Perform DMA writes only for word/dword
   input logic  [31:0]                   dma_dccm_wdata_lo,         // Shifted dma data to lower bits to make it consistent to lsu stores
   input logic  [31:0]                   dma_dccm_wdata_hi,         // Shifted dma data to lower bits to make it consistent to lsu stores
   output logic [pt.DCCM_ECC_WIDTH-1:0]  dma_dccm_wdata_ecc_hi,     // ECC bits for the DMA wdata
   output logic [pt.DCCM_ECC_WIDTH-1:0]  dma_dccm_wdata_ecc_lo,     // ECC bits for the DMA wdata

   output logic [pt.DCCM_ECC_WIDTH-1:0]  stbuf_ecc_any,             // Encoded data with ECC bits
   output logic [pt.DCCM_ECC_WIDTH-1:0]  sec_data_ecc_hi_r_ff,      // Encoded data with ECC bits
   output logic [pt.DCCM_ECC_WIDTH-1:0]  sec_data_ecc_lo_r_ff,      // Encoded data with ECC bits

   output logic                          single_ecc_error_hi_r,                   // sec detected
   output logic                          single_ecc_error_lo_r,                   // sec detected on lower dccm bank
   output logic                          lsu_single_ecc_error_r,                  // or of the 2
   output logic                          lsu_double_ecc_error_r,                   // double error detected

   output logic                          lsu_single_ecc_error_m,                  // or of the 2
   output logic                          lsu_double_ecc_error_m                   // double error detected

 );
```

## Parent instantiation

```verilog
   el2_lsu_ecc #(.pt(pt)) ecc (
      .lsu_addr_r(lsu_addr_r[pt.DCCM_BITS-1:0]),
      .end_addr_r(end_addr_r[pt.DCCM_BITS-1:0]),
      .lsu_addr_m(lsu_addr_m[pt.DCCM_BITS-1:0]),
      .end_addr_m(end_addr_m[pt.DCCM_BITS-1:0]),
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
