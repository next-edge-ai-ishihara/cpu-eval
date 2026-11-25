# Implement `el2_lsu_stbuf`

Implement the complete `el2_lsu_stbuf` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_lsu_stbuf` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_lsu_stbuf
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
(
   input logic                           clk,                         // core clock
   input logic                           rst_l,                       // reset

   input logic                           lsu_stbuf_c1_clk,            // stbuf clock
   input logic                           lsu_free_c2_clk,             // free clk

   // Store Buffer input
   input logic                           store_stbuf_reqvld_r,        // core instruction goes to stbuf
   input logic                           lsu_commit_r,                // lsu commits
   input logic                           dec_lsu_valid_raw_d,         // Speculative decode valid
   input logic [pt.DCCM_DATA_WIDTH-1:0]  store_data_hi_r,             // merged data from the dccm for stores. This is used for fwding
   input logic [pt.DCCM_DATA_WIDTH-1:0]  store_data_lo_r,             // merged data from the dccm for stores. This is used for fwding
   input logic [pt.DCCM_DATA_WIDTH-1:0]  store_datafn_hi_r,           // merged data from the dccm for stores
   input logic [pt.DCCM_DATA_WIDTH-1:0]  store_datafn_lo_r,           // merged data from the dccm for stores

   // Store Buffer output
   output logic                          stbuf_reqvld_any,            // stbuf is draining
   output logic                          stbuf_reqvld_flushed_any,    // Top entry is flushed
   output logic [pt.LSU_SB_BITS-1:0]     stbuf_addr_any,              // address
   output logic [pt.DCCM_DATA_WIDTH-1:0] stbuf_data_any,              // stbuf data

   input  logic                          lsu_stbuf_commit_any,        // pop the stbuf as it commits
   output logic                          lsu_stbuf_full_any,          // stbuf is full
   output logic                          lsu_stbuf_empty_any,         // stbuf is empty
   output logic                          ldst_stbuf_reqvld_r,         // needed for clocking

   input logic [pt.LSU_SB_BITS-1:0]      lsu_addr_d,                  // lsu address D-stage
   input logic [31:0]                    lsu_addr_m,                  // lsu address M-stage
   input logic [31:0]                    lsu_addr_r,                  // lsu address R-stage

   input logic [pt.LSU_SB_BITS-1:0]      end_addr_d,                  // lsu end address D-stage - needed to check unaligned
   input logic [31:0]                    end_addr_m,                  // lsu end address M-stage - needed to check unaligned
   input logic [31:0]                    end_addr_r,                  // lsu end address R-stage - needed to check unaligned

   input logic                           ldst_dual_d, ldst_dual_m, ldst_dual_r,
   input logic                           addr_in_dccm_m,              // address is in dccm
   input logic                           addr_in_dccm_r,              // address is in dccm

   // Forwarding signals
   input logic                           lsu_cmpen_m,                 // needed for forwarding stbuf - load
   input el2_lsu_pkt_t                  lsu_pkt_m,                   // LSU packet M-stage
   input el2_lsu_pkt_t                  lsu_pkt_r,                   // LSU packet R-stage

   output logic [pt.DCCM_DATA_WIDTH-1:0] stbuf_fwddata_hi_m,          // stbuf data
   output logic [pt.DCCM_DATA_WIDTH-1:0] stbuf_fwddata_lo_m,          // stbuf data
   output logic [pt.DCCM_BYTE_WIDTH-1:0] stbuf_fwdbyteen_hi_m,        // stbuf data
   output logic [pt.DCCM_BYTE_WIDTH-1:0] stbuf_fwdbyteen_lo_m,        // stbuf data

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic       scan_mode                                       // Scan mode
   /*pragma coverage on*/

);
```

## Parent instantiation

```verilog
   el2_lsu_stbuf #(.pt(pt)) stbuf (
      .lsu_addr_d(lsu_addr_d[pt.LSU_SB_BITS-1:0]),
      .end_addr_d(end_addr_d[pt.LSU_SB_BITS-1:0]),

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
