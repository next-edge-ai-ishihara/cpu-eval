# Implement `el2_lsu_bus_intf`

Implement the complete `el2_lsu_bus_intf` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_lsu_bus_intf` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_lsu_bus_intf
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input logic                          clk,                                // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic                          clk_override,                       // Override non-functional clock gating
   input logic                          rst_l,                              // reset, active low
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic                          scan_mode,                          // scan mode
   /*pragma coverage on*/
   input logic                          dec_tlu_external_ldfwd_disable,     // disable load to load forwarding for externals
   input logic                          dec_tlu_wb_coalescing_disable,      // disable write buffer coalescing
   input logic                          dec_tlu_sideeffect_posted_disable,  // disable the posted sideeffect load store to the bus

   // various clocks needed for the bus reads and writes
   input logic                          lsu_bus_obuf_c1_clken,              // obuf clock enable
   input logic                          lsu_busm_clken,                     // bus clock enable

   input logic                          lsu_c1_r_clk,                       // r pipe single pulse clock
   input logic                          lsu_c2_r_clk,                       // r pipe double pulse clock
   input logic                          lsu_bus_ibuf_c1_clk,                // ibuf single pulse clock
   input logic                          lsu_bus_obuf_c1_clk,                // obuf single pulse clock
   input logic                          lsu_bus_buf_c1_clk,                 // buf  single pulse clock
   input logic                          lsu_free_c2_clk,                    // free clock double pulse clock
   input logic                          active_clk,                         // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
   input logic                          lsu_busm_clk,                       // bus clock

   input logic                          dec_lsu_valid_raw_d,               // Raw valid for address computation
   input logic                          lsu_busreq_m,                      // bus request is in m

   input                                el2_lsu_pkt_t lsu_pkt_m,          // lsu packet flowing down the pipe
   input                                el2_lsu_pkt_t lsu_pkt_r,          // lsu packet flowing down the pipe

   input logic [31:0]                   lsu_addr_m,                        // lsu address flowing down the pipe
   input logic [31:0]                   lsu_addr_r,                        // lsu address flowing down the pipe

   input logic [31:0]                   end_addr_m,                        // lsu address flowing down the pipe
   input logic [31:0]                   end_addr_r,                        // lsu address flowing down the pipe

   input logic [31:0]                   store_data_r,                      // store data flowing down the pipe
   input logic                          dec_tlu_force_halt,

   input logic                          lsu_commit_r,                      // lsu instruction in r commits
   input logic                          is_sideeffects_m,                  // lsu attribute is side_effects
   input logic                          flush_m_up,                        // flush
   input logic                          flush_r,                           // flush
   input logic                          ldst_dual_d, ldst_dual_m, ldst_dual_r,

   output logic                         lsu_busreq_r,                      // bus request is in r
   output logic                         lsu_bus_buffer_pend_any,           // bus buffer has a pending bus entry
   output logic                         lsu_bus_buffer_full_any,           // write buffer is full
   output logic                         lsu_bus_buffer_empty_any,          // write buffer is empty
   output logic [31:0]                  bus_read_data_m,                   // the bus return data


   output logic                         lsu_imprecise_error_load_any,      // imprecise load bus error
   output logic                         lsu_imprecise_error_store_any,     // imprecise store bus error
   output logic [31:0]                  lsu_imprecise_error_addr_any,      // address of the imprecise error

   // Non-blocking loads
   output logic                               lsu_nonblock_load_valid_m,   // there is an external load -> put in the cam
   output logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_tag_m,     // the tag of the external non block load
   output logic                               lsu_nonblock_load_inv_r,     // invalidate signal for the cam entry for non block loads
   output logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_inv_tag_r, // tag of the entry which needs to be invalidated
   output logic                               lsu_nonblock_load_data_valid,// the non block is valid - sending information back to the cam
   output logic                               lsu_nonblock_load_data_error,// non block load has an error
   output logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_data_tag,  // the tag of the non block load sending the data/error
   output logic [31:0]                        lsu_nonblock_load_data,      // Data of the non block load

   // PMU events
   output logic                         lsu_pmu_bus_trxn,
   output logic                         lsu_pmu_bus_misaligned,
   output logic                         lsu_pmu_bus_error,
   output logic                         lsu_pmu_bus_busy,

   // AXI Write Channels
   output logic                        lsu_axi_awvalid,
   input  logic                        lsu_axi_awready,
   output logic [pt.LSU_BUS_TAG-1:0]   lsu_axi_awid,
   output logic [31:0]                 lsu_axi_awaddr,
   output logic [3:0]                  lsu_axi_awregion,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic [7:0]                  lsu_axi_awlen,
   /*pragma coverage on*/
   output logic [2:0]                  lsu_axi_awsize,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic [1:0]                  lsu_axi_awburst,
   output logic                        lsu_axi_awlock,
   /*pragma coverage on*/
   output logic [3:0]                  lsu_axi_awcache,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic [2:0]                  lsu_axi_awprot,
   output logic [3:0]                  lsu_axi_awqos,
   /*pragma coverage on*/

   output logic                        lsu_axi_wvalid,
   input  logic                        lsu_axi_wready,
   output logic [63:0]                 lsu_axi_wdata,
   output logic [7:0]                  lsu_axi_wstrb,
   output logic                        lsu_axi_wlast,

   input  logic                        lsu_axi_bvalid,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic                        lsu_axi_bready,
   /*pragma coverage on*/
   input  logic [1:0]                  lsu_axi_bresp,
   input  logic [pt.LSU_BUS_TAG-1:0]   lsu_axi_bid,

   // AXI Read Channels
   output logic                        lsu_axi_arvalid,
   input  logic                        lsu_axi_arready,
   output logic [pt.LSU_BUS_TAG-1:0]   lsu_axi_arid,
   output logic [31:0]                 lsu_axi_araddr,
   output logic [3:0]                  lsu_axi_arregion,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic [7:0]                  lsu_axi_arlen,
   /*pragma coverage on*/
   output logic [2:0]                  lsu_axi_arsize,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic [1:0]                  lsu_axi_arburst,
   output logic                        lsu_axi_arlock,
   /*pragma coverage on*/
   output logic [3:0]                  lsu_axi_arcache,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic [2:0]                  lsu_axi_arprot,
   output logic [3:0]                  lsu_axi_arqos,
   /*pragma coverage on*/

   input  logic                        lsu_axi_rvalid,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic                        lsu_axi_rready,
   /*pragma coverage on*/
   input  logic [pt.LSU_BUS_TAG-1:0]   lsu_axi_rid,
   input  logic [63:0]                 lsu_axi_rdata,
   input  logic [1:0]                  lsu_axi_rresp,

   input logic                         lsu_bus_clk_en

);
```

## Parent instantiation

```verilog
   el2_lsu_bus_intf #(.pt(pt)) bus_intf (
      .lsu_addr_m(lsu_addr_m[31:0] & {32{addr_external_m & lsu_pkt_m.valid}}),
      .lsu_addr_r(lsu_addr_r[31:0] & {32{lsu_busreq_r}}),

      .end_addr_m(end_addr_m[31:0] & {32{addr_external_m & lsu_pkt_m.valid}}),
      .end_addr_r(end_addr_r[31:0] & {32{lsu_busreq_r}}),

      .store_data_r(store_data_r[31:0] & {32{lsu_busreq_r}}),
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
```

### design/lsu/el2_lsu_bus_buffer.sv

```verilog
module el2_lsu_bus_buffer
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input logic                          clk,                                // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic                          clk_override,                       // Override non-functional clock gating
   input logic                          rst_l,                              // reset, active low
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic                          scan_mode,                          // scan mode
   /*pragma coverage on*/
   input logic                          dec_tlu_external_ldfwd_disable,     // disable load to load forwarding for externals
   input logic                          dec_tlu_wb_coalescing_disable,      // disable write buffer coalescing
   input logic                          dec_tlu_sideeffect_posted_disable,  // Don't block the sideeffect load store to the bus
   input logic                          dec_tlu_force_halt,

   // various clocks needed for the bus reads and writes
   input logic                          lsu_bus_obuf_c1_clken,
   input logic                          lsu_busm_clken,
   input logic                          lsu_c2_r_clk,
   input logic                          lsu_bus_ibuf_c1_clk,
   input logic                          lsu_bus_obuf_c1_clk,
   input logic                          lsu_bus_buf_c1_clk,
   input logic                          lsu_free_c2_clk,
   input logic                          lsu_busm_clk,


   input logic                          dec_lsu_valid_raw_d,            // Raw valid for address computation
   input el2_lsu_pkt_t                 lsu_pkt_m,                      // lsu packet flowing down the pipe
   input el2_lsu_pkt_t                 lsu_pkt_r,                      // lsu packet flowing down the pipe

   input logic [31:0]                   lsu_addr_m,                     // lsu address flowing down the pipe
   input logic [31:0]                   end_addr_m,                     // lsu address flowing down the pipe
   input logic [31:0]                   lsu_addr_r,                     // lsu address flowing down the pipe
   input logic [31:0]                   end_addr_r,                     // lsu address flowing down the pipe
   input logic [31:0]                   store_data_r,                   // store data flowing down the pipe

   input logic                          no_word_merge_r,                // r store doesn't need to wait in ibuf since it will not coalesce
   input logic                          no_dword_merge_r,               // r store doesn't need to wait in ibuf since it will not coalesce
   input logic                          lsu_busreq_m,                   // bus request is in m
   output logic                         lsu_busreq_r,                   // bus request is in r
   input logic                          ld_full_hit_m,                  // load can get all its byte from a write buffer entry
   input logic                          flush_m_up,                     // flush
   input logic                          flush_r,                        // flush
   input logic                          lsu_commit_r,                   // lsu instruction in r commits
   input logic                          is_sideeffects_r,               // lsu attribute is side_effects
   input logic                          ldst_dual_d,                    // load/store is unaligned at 32 bit boundary
   input logic                          ldst_dual_m,                    // load/store is unaligned at 32 bit boundary
   input logic                          ldst_dual_r,                    // load/store is unaligned at 32 bit boundary

   input logic [7:0]                    ldst_byteen_ext_m,              // HI and LO signals

   output logic                         lsu_bus_buffer_pend_any,          // bus buffer has a pending bus entry
   output logic                         lsu_bus_buffer_full_any,          // bus buffer is full
   output logic                         lsu_bus_buffer_empty_any,         // bus buffer is empty

   output logic [3:0]                   ld_byte_hit_buf_lo, ld_byte_hit_buf_hi,    // Byte enables for forwarding data
   output logic [31:0]                  ld_fwddata_buf_lo, ld_fwddata_buf_hi,      // load forwarding data

   output logic                         lsu_imprecise_error_load_any,     // imprecise load bus error
   output logic                         lsu_imprecise_error_store_any,    // imprecise store bus error
   output logic [31:0]                  lsu_imprecise_error_addr_any,     // address of the imprecise error

   // Non-blocking loads
   output logic                               lsu_nonblock_load_valid_m,     // there is an external load -> put in the cam
   output logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_tag_m,       // the tag of the external non block load
   output logic                               lsu_nonblock_load_inv_r,       // invalidate signal for the cam entry for non block loads
   output logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_inv_tag_r,   // tag of the entry which needs to be invalidated
   output logic                               lsu_nonblock_load_data_valid,  // the non block is valid - sending information back to the cam
   output logic                               lsu_nonblock_load_data_error,  // non block load has an error
   output logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_data_tag,    // the tag of the non block load sending the data/error
   output logic [31:0]                        lsu_nonblock_load_data,        // Data of the non block load

   // PMU events
   output logic                         lsu_pmu_bus_trxn,
   output logic                         lsu_pmu_bus_misaligned,
   output logic                         lsu_pmu_bus_error,
   output logic                         lsu_pmu_bus_busy,

   // AXI Write Channels
   output logic                            lsu_axi_awvalid,
   input  logic                            lsu_axi_awready,
   output logic [pt.LSU_BUS_TAG-1:0]       lsu_axi_awid,
   output logic [31:0]                     lsu_axi_awaddr,
   output logic [3:0]                      lsu_axi_awregion,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [7:0]                      lsu_axi_awlen,
   /*pragma coverage on*/
   output logic [2:0]                      lsu_axi_awsize,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [1:0]                      lsu_axi_awburst,
   output logic                            lsu_axi_awlock,
   /*pragma coverage on*/
   output logic [3:0]                      lsu_axi_awcache,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [2:0]                      lsu_axi_awprot,
   output logic [3:0]                      lsu_axi_awqos,
   /*pragma coverage on*/

   output logic                            lsu_axi_wvalid,
   input  logic                            lsu_axi_wready,
   output logic [63:0]                     lsu_axi_wdata,
   output logic [7:0]                      lsu_axi_wstrb,
   output logic                            lsu_axi_wlast,

   input  logic                            lsu_axi_bvalid,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic                            lsu_axi_bready,
   /*pragma coverage on*/
   input  logic [1:0]                      lsu_axi_bresp,
   input  logic [pt.LSU_BUS_TAG-1:0]       lsu_axi_bid,

   // AXI Read Channels
   output logic                            lsu_axi_arvalid,
   input  logic                            lsu_axi_arready,
   output logic [pt.LSU_BUS_TAG-1:0]       lsu_axi_arid,
   output logic [31:0]                     lsu_axi_araddr,
   output logic [3:0]                      lsu_axi_arregion,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [7:0]                      lsu_axi_arlen,
   /*pragma coverage on*/
   output logic [2:0]                      lsu_axi_arsize,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [1:0]                      lsu_axi_arburst,
   output logic                            lsu_axi_arlock,
   /*pragma coverage on*/
   output logic [3:0]                      lsu_axi_arcache,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [2:0]                      lsu_axi_arprot,
   output logic [3:0]                      lsu_axi_arqos,
   /*pragma coverage on*/

   input  logic                            lsu_axi_rvalid,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic                            lsu_axi_rready,
   /*pragma coverage on*/
   input  logic [pt.LSU_BUS_TAG-1:0]       lsu_axi_rid,
   input  logic [63:0]                     lsu_axi_rdata,
   input  logic [1:0]                      lsu_axi_rresp,

   input logic                             lsu_bus_clk_en,
   input logic                             lsu_bus_clk_en_q

);
```
