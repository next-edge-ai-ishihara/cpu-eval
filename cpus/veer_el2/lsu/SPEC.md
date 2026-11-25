# Implement `el2_lsu`

Implement the complete `el2_lsu` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_lsu` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog

module el2_lsu
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
(

   input logic                             clk_override,             // Override non-functional clock gating
   input logic                             dec_tlu_flush_lower_r,    // I0/I1 writeback flush. This is used to flush the old packets only
   input logic                             dec_tlu_i0_kill_writeb_r, // I0 is flushed, don't writeback any results to arch state
   input logic                             dec_tlu_force_halt,       // This will be high till TLU goes to debug halt

   // chicken signals
   input logic                             dec_tlu_external_ldfwd_disable,    // disable load to load forwarding for externals
   input logic                             dec_tlu_wb_coalescing_disable,     // disable the write buffer coalesce
   input logic                             dec_tlu_sideeffect_posted_disable, // disable the posted sideeffect load store to the bus
   input logic                             dec_tlu_core_ecc_disable,          // disable the generation of the ecc
   input logic                             dec_tlu_dccm_wr_readback_disable,  // disable the DCCM write-readback check

   input logic [31:0]                      exu_lsu_rs1_d,        // address rs operand
   input logic [31:0]                      exu_lsu_rs2_d,        // store data
   input logic [11:0]                      dec_lsu_offset_d,     // address offset operand

   input                                   el2_lsu_pkt_t lsu_p,  // lsu control packet
   input logic                             dec_lsu_valid_raw_d,   // Raw valid for address computation
   input logic [31:0]                      dec_tlu_mrac_ff,       // CSR for memory region control

   output logic [31:0]                     lsu_result_m,          // lsu load data
   output logic [31:0]                     lsu_result_corr_r,     // This is the ECC corrected data going to RF
   output logic                            lsu_load_stall_any,    // This is for blocking loads in the decode
   output logic                            lsu_store_stall_any,   // This is for blocking stores in the decode
   output logic                            lsu_fastint_stall_any, // Stall the fastint in decode-1 stage
   output logic                            lsu_idle_any,          // lsu buffers are empty and no instruction in the pipeline. Doesn't include DMA
   output logic                            lsu_active,            // Used to turn off top level clk

   output logic [31:1]                     lsu_fir_addr,        // fast interrupt address
   output logic [1:0]                      lsu_fir_error,       // Error during fast interrupt lookup

   output logic                            lsu_single_ecc_error_incr,     // Increment the ecc counter
   output el2_lsu_error_pkt_t             lsu_error_pkt_r,               // lsu exception packet
   output logic                            lsu_imprecise_error_load_any,  // bus load imprecise error
   output logic                            lsu_imprecise_error_store_any, // bus store imprecise error
   output logic [31:0]                     lsu_imprecise_error_addr_any,  // bus store imprecise error address

   // Non-blocking loads
   output logic                               lsu_nonblock_load_valid_m,      // there is an external load -> put in the cam
   output logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_tag_m,        // the tag of the external non block load
   output logic                               lsu_nonblock_load_inv_r,        // invalidate signal for the cam entry for non block loads
   output logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_inv_tag_r,    // tag of the entry which needs to be invalidated
   output logic                               lsu_nonblock_load_data_valid,   // the non block is valid - sending information back to the cam
   output logic                               lsu_nonblock_load_data_error,   // non block load has an error
   output logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_data_tag,     // the tag of the non block load sending the data/error
   output logic [31:0]                        lsu_nonblock_load_data,         // Data of the non block load

   output logic                            lsu_pmu_load_external_m,        // PMU : Bus loads
   output logic                            lsu_pmu_store_external_m,       // PMU : Bus loads
   output logic                            lsu_pmu_misaligned_m,           // PMU : misaligned
   output logic                            lsu_pmu_bus_trxn,               // PMU : bus transaction
   output logic                            lsu_pmu_bus_misaligned,         // PMU : misaligned access going to the bus
   output logic                            lsu_pmu_bus_error,              // PMU : bus sending error back
   output logic                            lsu_pmu_bus_busy,               // PMU : bus is not ready

   // Trigger signals
   input                                   el2_trigger_pkt_t [3:0] trigger_pkt_any, // Trigger info from the decode
   output logic [3:0]                      lsu_trigger_match_m,                      // lsu trigger hit (one bit per trigger)

   // DCCM ports
   output logic                            dccm_wren,       // DCCM write enable
   output logic                            dccm_rden,       // DCCM read enable
   output logic [pt.DCCM_BITS-1:0]         dccm_wr_addr_lo, // DCCM write address low bank
   output logic [pt.DCCM_BITS-1:0]         dccm_wr_addr_hi, // DCCM write address hi bank
   output logic [pt.DCCM_BITS-1:0]         dccm_rd_addr_lo, // DCCM read address low bank
   output logic [pt.DCCM_BITS-1:0]         dccm_rd_addr_hi, // DCCM read address hi bank (hi and low same if aligned read)
   output logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_wr_data_lo, // DCCM write data for lo bank
   output logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_wr_data_hi, // DCCM write data for hi bank

   input logic [pt.DCCM_FDATA_WIDTH-1:0]   dccm_rd_data_lo, // DCCM read data low bank
   input logic [pt.DCCM_FDATA_WIDTH-1:0]   dccm_rd_data_hi, // DCCM read data hi bank

   // PIC ports
   output logic                            picm_wren,    // PIC memory write enable
   output logic                            picm_rden,    // PIC memory read enable
   output logic                            picm_mken,    // Need to read the mask for stores to determine which bits to write/forward
   output logic [31:0]                     picm_rdaddr,  // address for pic read access
   output logic [31:0]                     picm_wraddr,  // address for pic write access
   output logic [31:0]                     picm_wr_data, // PIC memory write data
   input logic [31:0]                      picm_rd_data, // PIC memory read/mask data

   // AXI Write Channels
   output logic                            lsu_axi_awvalid,
   input  logic                            lsu_axi_awready,
   output logic [pt.LSU_BUS_TAG-1:0]       lsu_axi_awid,
   output logic [31:0]                     lsu_axi_awaddr,
   output logic [3:0]                      lsu_axi_awregion,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic [7:0]                      lsu_axi_awlen,
   /*pragma coverage on*/
   output logic [2:0]                      lsu_axi_awsize,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic [1:0]                      lsu_axi_awburst,
   output logic                            lsu_axi_awlock,
   /*pragma coverage on*/
   output logic [3:0]                      lsu_axi_awcache,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
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
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
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
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic [7:0]                      lsu_axi_arlen,
   /*pragma coverage on*/
   output logic [2:0]                      lsu_axi_arsize,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic [1:0]                      lsu_axi_arburst,
   output logic                            lsu_axi_arlock,
   /*pragma coverage on*/
   output logic [3:0]                      lsu_axi_arcache,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic [2:0]                      lsu_axi_arprot,
   output logic [3:0]                      lsu_axi_arqos,
   /*pragma coverage on*/

   input  logic                            lsu_axi_rvalid,
   /* exclude signals that are tied to constant value in el2_lsu_bus_buffer.sv */
   /*pragma coverage off*/
   output logic                            lsu_axi_rready,
   /*pragma coverage on*/
   input  logic [pt.LSU_BUS_TAG-1:0]       lsu_axi_rid,
   input  logic [63:0]                     lsu_axi_rdata,
   input  logic [1:0]                      lsu_axi_rresp,
   input  logic                            lsu_axi_rlast,

   input logic                             lsu_bus_clk_en,    // external drives a clock_en to control bus ratio

   // DMA slave
   input logic                             dma_dccm_req,       // DMA read/write to dccm
   input logic [2:0]                       dma_mem_tag,        // DMA request tag
   input logic [31:0]                      dma_mem_addr,       // DMA address
   input logic [2:0]                       dma_mem_sz,         // DMA access size
   input logic                             dma_mem_write,      // DMA access is a write
   input logic [63:0]                      dma_mem_wdata,      // DMA write data

   output logic                            dccm_dma_rvalid,     // lsu data valid for DMA dccm read
   output logic                            dccm_dma_ecc_error,  // DMA load had ecc error
   output logic [2:0]                      dccm_dma_rtag,       // DMA request tag
   output logic [63:0]                     dccm_dma_rdata,      // lsu data for DMA dccm read
   output logic                            dccm_ready,          // lsu ready for DMA access

   // DCCM ECC status
   output logic                            lsu_dccm_rd_ecc_single_err,
   output logic                            lsu_dccm_rd_ecc_double_err,

   // DCCM write-readback status
   output logic                            dccm_wr_readback_error,

   // DCCM write-readback sticky first-fault capture, exposed to el2_dbg over DMI
   output logic                            dccm_wr_rdbk_fault_valid,
   output logic [pt.DCCM_BITS-1:0]         dccm_wr_rdbk_fault_addr,
   output logic [pt.DCCM_FDATA_WIDTH-1:0]  dccm_wr_rdbk_fault_data,
   input logic                             dccm_wr_rdbk_fault_clear,

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic                             scan_mode,           // scan mode
   /*pragma coverage on*/
   input logic                             clk,                 // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic                             active_clk,          // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
    input logic                             rst_l,               // reset, active low

    output logic [31:0] lsu_pmp_addr_start,
    output logic [31:0] lsu_pmp_addr_end,
    input  logic        lsu_pmp_error_start,
    input  logic        lsu_pmp_error_end,
    output logic        lsu_pmp_we,
    output logic        lsu_pmp_re

   );

```

## Parent instantiation

```verilog

   el2_lsu #(.pt(pt)) lsu (
                            .clk(active_l2clk),
                            .rst_l(core_rst_l),
                            .clk_override(dec_tlu_lsu_clk_override),
                            .dec_tlu_i0_kill_writeb_r(dec_tlu_i0_kill_writeb_r),

                            // AXI signals
                            .lsu_axi_awready(lsu_axi_awready_int),
                            .lsu_axi_wready(lsu_axi_wready_int),
                            .lsu_axi_bvalid(lsu_axi_bvalid_int),
                            .lsu_axi_bid(lsu_axi_bid_int[pt.LSU_BUS_TAG-1:0]),
                            .lsu_axi_bresp(lsu_axi_bresp_int[1:0]),

                            .lsu_axi_arready(lsu_axi_arready_int),
                            .lsu_axi_rvalid(lsu_axi_rvalid_int),
                            .lsu_axi_rid(lsu_axi_rid_int[pt.LSU_BUS_TAG-1:0]),
                            .lsu_axi_rdata(lsu_axi_rdata_int[63:0]),
                            .lsu_axi_rresp(lsu_axi_rresp_int[1:0]),
                            .lsu_axi_rlast(lsu_axi_rlast_int),

                            .*

                            );

```

## Dependency declarations

### `rvdff`

```verilog
module rvdff #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic                   rst_l,

     output logic [WIDTH-1:0] dout
     );

```

### `el2_lsu_bus_intf`

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

### `el2_lsu_clkdomain`

```verilog


module el2_lsu_clkdomain
import el2_pkg::*;
#(
`include "el2_param.vh"
)(
   input logic      clk,                               // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic      active_clk,                        // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
   input logic      rst_l,                             // reset, active low
   input logic      dec_tlu_force_halt,                // This will be high till TLU goes to debug halt

   // Inputs
   input logic      clk_override,                      // chciken bit to turn off clock gating
   input logic      dma_dccm_req,                      // dma is active
   input logic      ldst_stbuf_reqvld_r,               // allocating in to the store queue

   input logic      stbuf_reqvld_any,                  // stbuf is draining
   input logic      stbuf_reqvld_flushed_any,          // instruction going to stbuf is flushed
   input logic      lsu_busreq_r,                      // busreq in r
   input logic      lsu_bus_buffer_pend_any,           // bus buffer has a pending bus entry
   input logic      lsu_bus_buffer_empty_any,          // external bus buffer is empty
   input logic      lsu_stbuf_empty_any,               // stbuf is empty

   input logic      lsu_bus_clk_en,                    // bus clock enable

   input el2_lsu_pkt_t  lsu_p,                        // lsu packet in decode
   input el2_lsu_pkt_t  lsu_pkt_d,                    // lsu packet in d
   input el2_lsu_pkt_t  lsu_pkt_m,                    // lsu packet in m
   input el2_lsu_pkt_t  lsu_pkt_r,                    // lsu packet in r

   // Outputs
   output logic     lsu_bus_obuf_c1_clken,             // obuf clock enable
   output logic     lsu_busm_clken,                    // bus clock enable

   output logic     lsu_c1_m_clk,                      // m pipe single pulse clock
   output logic     lsu_c1_r_clk,                      // r pipe single pulse clock

   output logic     lsu_c2_m_clk,                      // m pipe double pulse clock
   output logic     lsu_c2_r_clk,                      // r pipe double pulse clock

   output logic     lsu_store_c1_m_clk,                // store in m
   output logic     lsu_store_c1_r_clk,                // store in r

   output logic     lsu_stbuf_c1_clk,
   output logic     lsu_bus_obuf_c1_clk,               // ibuf clock
   output logic     lsu_bus_ibuf_c1_clk,               // ibuf clock
   output logic     lsu_bus_buf_c1_clk,                // ibuf clock
   output logic     lsu_busm_clk,                      // bus clock

   output logic     lsu_free_c2_clk,                   // free double pulse clock

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic     scan_mode                          // Scan mode
   /*pragma coverage on*/
);

```

### `el2_lsu_dccm_ctl`

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

### `el2_lsu_ecc`

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

### `el2_lsu_lsc_ctl`

```verilog
module el2_lsu_lsc_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input logic                rst_l,                     // reset, active low
   input logic                clk_override,              // Override non-functional clock gating
   input logic                clk,                       // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.

   // clocks per pipe
   input logic                lsu_c1_m_clk,
   input logic                lsu_c1_r_clk,
   input logic                lsu_c2_m_clk,
   input logic                lsu_c2_r_clk,
   input logic                lsu_store_c1_m_clk,

   input logic [31:0]         lsu_ld_data_r,             // Load data R-stage
   input logic [31:0]         lsu_ld_data_corr_r,        // ECC corrected data R-stage
   input logic                lsu_single_ecc_error_r,    // ECC single bit error R-stage
   input logic                lsu_double_ecc_error_r,    // ECC double bit error R-stage

   input logic [31:0]         lsu_ld_data_m,             // Load data M-stage
   input logic                lsu_single_ecc_error_m,    // ECC single bit error M-stage
   input logic                lsu_double_ecc_error_m,    // ECC double bit error M-stage

   input logic                flush_m_up,                // Flush M and D stage
   input logic                flush_r,                   // Flush R-stage
   input logic                ldst_dual_d,               // load/store is unaligned at 32 bit boundary D-stage
   input logic                ldst_dual_m,               // load/store is unaligned at 32 bit boundary M-stage
   input logic                ldst_dual_r,               // load/store is unaligned at 32 bit boundary R-stage

   input logic [31:0]         exu_lsu_rs1_d,             // address
   input logic [31:0]         exu_lsu_rs2_d,             // store data

   input el2_lsu_pkt_t       lsu_p,                     // lsu control packet
   input logic                dec_lsu_valid_raw_d,       // Raw valid for address computation
   input logic [11:0]         dec_lsu_offset_d,          // 12b offset for load/store addresses

   input  logic [31:0]        picm_mask_data_m,          // PIC data M-stage
   input  logic [31:0]        bus_read_data_m,           // the bus return data
   output logic [31:0]        lsu_result_m,              // lsu load data
   output logic [31:0]        lsu_result_corr_r,         // This is the ECC corrected data going to RF
   // lsu address down the pipe
   output logic [31:0]        lsu_addr_d,
   output logic [31:0]        lsu_addr_m,
   output logic [31:0]        lsu_addr_r,
   // lsu address down the pipe - needed to check unaligned
   output logic [31:0]        end_addr_d,
   output logic [31:0]        end_addr_m,
   output logic [31:0]        end_addr_r,
   // store data down the pipe
   output logic [31:0]        store_data_m,

   input  logic [31:0]         dec_tlu_mrac_ff,          // CSR for memory region control
   output logic                lsu_exc_m,                // Access or misaligned fault
   output logic                is_sideeffects_m,         // is sideffects space
   output logic                lsu_commit_r,             // lsu instruction in r commits
   output logic                lsu_single_ecc_error_incr,// LSU inc SB error counter
   output el2_lsu_error_pkt_t lsu_error_pkt_r,          // lsu exception packet

   output logic [31:1]         lsu_fir_addr,             // fast interrupt address
   output logic [1:0]          lsu_fir_error,            // Error during fast interrupt lookup

   // address in dccm/pic/external per pipe stage
   output logic               addr_in_dccm_d,
   output logic               addr_in_dccm_m,
   output logic               addr_in_dccm_r,

   output logic               addr_in_pic_d,
   output logic               addr_in_pic_m,
   output logic               addr_in_pic_r,

   output logic               addr_external_m,

   // DMA slave
   input logic                dma_dccm_req,
   input logic [31:0]         dma_mem_addr,
   input logic [2:0]          dma_mem_sz,
   input logic                dma_mem_write,
   input logic [63:0]         dma_mem_wdata,

   // Store buffer related signals
   output el2_lsu_pkt_t      lsu_pkt_d,
   output el2_lsu_pkt_t      lsu_pkt_m,
   output el2_lsu_pkt_t      lsu_pkt_r,

    input logic lsu_pmp_error_start,
    input logic lsu_pmp_error_end,

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic               scan_mode                  // Scan mode
   /*pragma coverage on*/

   );

```

### `el2_lsu_stbuf`

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

### `el2_lsu_trigger`

```verilog
module el2_lsu_trigger
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input el2_trigger_pkt_t [3:0] trigger_pkt_any,            // trigger packet from dec
   input el2_lsu_pkt_t           lsu_pkt_m,                  // lsu packet
   input logic [31:0]             lsu_addr_m,                 // address
   input logic [31:0]             store_data_m,               // store data

   output logic [3:0]             lsu_trigger_match_m         // match result
);

```

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
