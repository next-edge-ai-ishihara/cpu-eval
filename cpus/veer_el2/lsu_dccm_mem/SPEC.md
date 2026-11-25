# Implement `el2_lsu_dccm_mem`

Implement the complete `el2_lsu_dccm_mem` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_lsu_dccm_mem` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

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

## Parent instantiation

```verilog
      el2_lsu_dccm_mem #(.pt(pt)) dccm (
         .clk_override(dccm_clk_override),
         .dccm_mem_export(mem_export_local.veer_dccm),
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
// ...
  //////////////////////////////////////////
  // DCCM
  logic [pt.DCCM_NUM_BANKS-1:0]                                       dccm_clken;
  logic [pt.DCCM_NUM_BANKS-1:0]                                       dccm_wren_bank;
  logic [pt.DCCM_NUM_BANKS-1:0][pt.DCCM_BITS-1:(pt.DCCM_BANK_BITS+2)] dccm_addr_bank;
  logic [pt.DCCM_NUM_BANKS-1:0][              pt.DCCM_DATA_WIDTH-1:0] dccm_wr_data_bank;
  logic [pt.DCCM_NUM_BANKS-1:0][               pt.DCCM_ECC_WIDTH-1:0] dccm_wr_ecc_bank;
  logic [pt.DCCM_NUM_BANKS-1:0][              pt.DCCM_DATA_WIDTH-1:0] dccm_bank_dout;
  logic [pt.DCCM_NUM_BANKS-1:0][               pt.DCCM_ECC_WIDTH-1:0] dccm_bank_ecc;
// ...
  modport veer_dccm(
      input clk,
      // DCCM
      output dccm_clken, dccm_wren_bank, dccm_addr_bank, dccm_wr_data_bank, dccm_wr_ecc_bank,
      input dccm_bank_dout, dccm_bank_ecc
  );
// ...
endinterface
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
```
