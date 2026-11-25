# Implement `el2_veer`

Implement the complete `el2_veer` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_veer` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
my $ahb = 0;
my $axi = 1;
...
my $smepmp=0;
...
my $lockstep_regfile_enable=0;
...
$user_mode=0;
```

## Module declaration

```verilog
module el2_veer
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic                  clk,
   input logic                  rst_l,
   input logic                  dbg_rst_l,
   // rst_vec is supposed to be connected to a constant in the top level
   /*pragma coverage off*/
   input logic [31:1]           rst_vec,
   /*pragma coverage on*/
   input logic                  nmi_int,
   // nmi_vec is supposed to be connected to a constant in the top level
   /*pragma coverage off*/
   input logic [31:1]           nmi_vec,
   /*pragma coverage on*/
   output logic                 core_rst_l,   // This is "rst_l | dbg_rst_l"

   output logic                 active_l2clk,
   output logic                 free_l2clk,

   output logic [31:0] trace_rv_i_insn_ip,
   output logic [31:0] trace_rv_i_address_ip,
   output logic   trace_rv_i_valid_ip,
   output logic   trace_rv_i_exception_ip,
   output logic [4:0]  trace_rv_i_ecause_ip,
   output logic   trace_rv_i_interrupt_ip,
   output logic [31:0] trace_rv_i_tval_ip,


   output logic                 dccm_clk_override,
   output logic                 icm_clk_override,
   output logic                 dec_tlu_core_ecc_disable,
   output logic                 dec_tlu_dccm_wr_readback_disable,

   // external halt/run interface
   input logic  i_cpu_halt_req,    // Asynchronous Halt request to CPU
   input logic  i_cpu_run_req,     // Asynchronous Restart request to CPU
   output logic o_cpu_halt_ack,    // Core Acknowledge to Halt request
   output logic o_cpu_halt_status, // 1'b1 indicates processor is halted
   output logic o_cpu_run_ack,     // Core Acknowledge to run request
   output logic o_debug_mode_status, // Core to the PMU that core is in debug mode. When core is in debug mode, the PMU should refrain from sendng a halt or run request

   /*pragma coverage off*/
   input logic [31:4] core_id, // CORE ID
   /*pragma coverage on*/

   // external MPC halt/run interface
   input logic mpc_debug_halt_req, // Async halt request
   input logic mpc_debug_run_req, // Async run request
   input logic mpc_reset_run_req, // Run/halt after reset
   output logic mpc_debug_halt_ack, // Halt ack
   output logic mpc_debug_run_ack, // Run ack
   output logic debug_brkpt_status, // debug breakpoint

   output logic dec_tlu_perfcnt0, // toggles when slot0 perf counter 0 has an event inc
   output logic dec_tlu_perfcnt1,
   output logic dec_tlu_perfcnt2,
   output logic dec_tlu_perfcnt3,

   // DCCM ports
   output logic                          dccm_wren,
   output logic                          dccm_rden,
   output logic [pt.DCCM_BITS-1:0]          dccm_wr_addr_lo,
   output logic [pt.DCCM_BITS-1:0]          dccm_wr_addr_hi,
   output logic [pt.DCCM_BITS-1:0]          dccm_rd_addr_lo,
   output logic [pt.DCCM_BITS-1:0]          dccm_rd_addr_hi,
   output logic [pt.DCCM_FDATA_WIDTH-1:0]   dccm_wr_data_lo,
   output logic [pt.DCCM_FDATA_WIDTH-1:0]   dccm_wr_data_hi,

   input logic [pt.DCCM_FDATA_WIDTH-1:0]    dccm_rd_data_lo,
   input logic [pt.DCCM_FDATA_WIDTH-1:0]    dccm_rd_data_hi,

   // ICCM ports
   output logic [pt.ICCM_BITS-1:1]           iccm_rw_addr,
   output logic                  iccm_wren,
   output logic                  iccm_rden,
   output logic [2:0]            iccm_wr_size,
   output logic [77:0]           iccm_wr_data,
   output logic                  iccm_buf_correct_ecc,
   output logic                  iccm_correction_state,

   input  logic [77:0]           iccm_rd_data_ecc,

   // ICache , ITAG  ports
   output logic [31:1]           ic_rw_addr,
   output logic [pt.ICACHE_NUM_WAYS-1:0]            ic_tag_valid,
   output logic [pt.ICACHE_NUM_WAYS-1:0]            ic_wr_en,
   output logic                  ic_rd_en,

   output logic [pt.ICACHE_BANKS_WAY-1:0][70:0]               ic_wr_data,         // Data to fill to the Icache. With ECC
   input  logic [141:0]              ic_rd_data ,              // Raw way-muxed 142-bit ECC-protected word pair. F2 stage.
   input  logic [1:0]                ic_rd_addr_lo,            // F2-aligned ic_rw_addr_ff[2:1] for core-side rotate
   input  logic [pt.ICACHE_BANKS_WAY-1:0] ic_rd_bank_check_en, // Per-bank ECC check enable for core-side decode
   input  logic [70:0]               ic_debug_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
   input  logic [25:0]               ictag_debug_rd_data,// Debug icache tag.
   output logic [70:0]               ic_debug_wr_data,   // Debug wr cache.


   output logic [pt.ICACHE_INDEX_HI:3]               ic_debug_addr,      // Read/Write address to the Icache.
   output logic                      ic_debug_rd_en,     // Icache debug rd
   output logic                      ic_debug_wr_en,     // Icache debug wr
   output logic                      ic_debug_tag_array, // Debug tag array
   output logic [pt.ICACHE_NUM_WAYS-1:0]                ic_debug_way,       // Debug way. Rd or Wr.



   input  logic [pt.ICACHE_NUM_WAYS-1:0]            ic_rd_hit,
   input  logic                  ic_tag_perr,        // Icache Tag parity error

   //-------------------------- LSU AXI signals--------------------------
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

   //-------------------------- IFU AXI signals--------------------------
   // AXI Write Channels
   /* exclude signals that are tied to constant value in el2_ifu_mem_ctl.sv
      IFU does not use AXI write channel */
   /*pragma coverage off*/
   output logic                            ifu_axi_awvalid,
   input  logic                            ifu_axi_awready,
   output logic [pt.IFU_BUS_TAG-1:0]       ifu_axi_awid,
   output logic [31:0]                     ifu_axi_awaddr,
   output logic [3:0]                      ifu_axi_awregion,
   output logic [7:0]                      ifu_axi_awlen,
   output logic [2:0]                      ifu_axi_awsize,
   output logic [1:0]                      ifu_axi_awburst,
   output logic                            ifu_axi_awlock,
   output logic [3:0]                      ifu_axi_awcache,
   output logic [2:0]                      ifu_axi_awprot,
   output logic [3:0]                      ifu_axi_awqos,

   output logic                            ifu_axi_wvalid,
   input  logic                            ifu_axi_wready,
   output logic [63:0]                     ifu_axi_wdata,
   output logic [7:0]                      ifu_axi_wstrb,
   output logic                            ifu_axi_wlast,

   input  logic                            ifu_axi_bvalid,
   output logic                            ifu_axi_bready,
   input  logic [1:0]                      ifu_axi_bresp,
   input  logic [pt.IFU_BUS_TAG-1:0]       ifu_axi_bid,
   /*pragma coverage on*/

   // AXI Read Channels
   output logic                            ifu_axi_arvalid,
   input  logic                            ifu_axi_arready,
   output logic [pt.IFU_BUS_TAG-1:0]       ifu_axi_arid,
   output logic [31:0]                     ifu_axi_araddr,
   output logic [3:0]                      ifu_axi_arregion,
   /* exclude signals that are tied to constant value in el2_ifu_mem_ctl.sv */
   /*pragma coverage off*/
   output logic [7:0]                      ifu_axi_arlen,
   output logic [2:0]                      ifu_axi_arsize,
   output logic [1:0]                      ifu_axi_arburst,
   output logic                            ifu_axi_arlock,
   output logic [3:0]                      ifu_axi_arcache,
   output logic [2:0]                      ifu_axi_arprot,
   output logic [3:0]                      ifu_axi_arqos,
   /*pragma coverage on*/

   input  logic                            ifu_axi_rvalid,
   /* exclude signals that are tied to constant value in el2_ifu_mem_ctl.sv */
   /*pragma coverage off*/
   output logic                            ifu_axi_rready,
   /*pragma coverage on*/
   input  logic [pt.IFU_BUS_TAG-1:0]       ifu_axi_rid,
   input  logic [63:0]                     ifu_axi_rdata,
   input  logic [1:0]                      ifu_axi_rresp,
   input  logic                            ifu_axi_rlast,

   //-------------------------- SB AXI signals--------------------------
   // AXI Write Channels
   output logic                            sb_axi_awvalid,
   input  logic                            sb_axi_awready,
   /* exclude signals that are tied to constant value in dbg/el2_dbg.sv */
   /*pragma coverage off*/
   output logic [pt.SB_BUS_TAG-1:0]        sb_axi_awid,
   /*pragma coverage on*/
   output logic [31:0]                     sb_axi_awaddr,
   output logic [3:0]                      sb_axi_awregion,
   /* exclude signals that are tied to constant value in dbg/el2_dbg.sv */
   /*pragma coverage off*/
   output logic [7:0]                      sb_axi_awlen,
   /*pragma coverage on*/
   output logic [2:0]                      sb_axi_awsize,
   /* exclude signals that are tied to constant value in dbg/el2_dbg.sv */
   /*pragma coverage off*/
   output logic [1:0]                      sb_axi_awburst,
   output logic                            sb_axi_awlock,
   output logic [3:0]                      sb_axi_awcache,
   output logic [2:0]                      sb_axi_awprot,
   output logic [3:0]                      sb_axi_awqos,
   /*pragma coverage on*/

   output logic                            sb_axi_wvalid,
   input  logic                            sb_axi_wready,
   output logic [63:0]                     sb_axi_wdata,
   output logic [7:0]                      sb_axi_wstrb,
   output logic                            sb_axi_wlast,

   input  logic                            sb_axi_bvalid,
   output logic                            sb_axi_bready,
   input  logic [1:0]                      sb_axi_bresp,
   input  logic [pt.SB_BUS_TAG-1:0]        sb_axi_bid,

   // AXI Read Channels
   output logic                            sb_axi_arvalid,
   input  logic                            sb_axi_arready,
   /* exclude signals that are tied to constant value in dbg/el2_dbg.sv */
   /*pragma coverage off*/
   output logic [pt.SB_BUS_TAG-1:0]        sb_axi_arid,
   /*pragma coverage on*/
   output logic [31:0]                     sb_axi_araddr,
   output logic [3:0]                      sb_axi_arregion,
   /* exclude signals that are tied to constant value in dbg/el2_dbg.sv */
   /*pragma coverage off*/
   output logic [7:0]                      sb_axi_arlen,
   /*pragma coverage on*/
   output logic [2:0]                      sb_axi_arsize,
   /* exclude signals that are tied to constant value in dbg/el2_dbg.sv */
   /*pragma coverage off*/
   output logic [1:0]                      sb_axi_arburst,
   output logic                            sb_axi_arlock,
   output logic [3:0]                      sb_axi_arcache,
   output logic [2:0]                      sb_axi_arprot,
   output logic [3:0]                      sb_axi_arqos,
   /*pragma coverage on*/

   input  logic                            sb_axi_rvalid,
   /* exclude signals that are tied to constant value in dbg/el2_dbg.sv */
   /*pragma coverage off*/
   output logic                            sb_axi_rready,
   /*pragma coverage on*/
   input  logic [pt.SB_BUS_TAG-1:0]        sb_axi_rid,
   input  logic [63:0]                     sb_axi_rdata,
   input  logic [1:0]                      sb_axi_rresp,
   input  logic                            sb_axi_rlast,

   //-------------------------- DMA AXI signals--------------------------
   // AXI Write Channels
   input  logic                         dma_axi_awvalid,
   output logic                         dma_axi_awready,
   input  logic [pt.DMA_BUS_TAG-1:0]    dma_axi_awid,
   input  logic [31:0]                  dma_axi_awaddr,
   input  logic [2:0]                   dma_axi_awsize,
   input  logic [2:0]                   dma_axi_awprot,
   input  logic [7:0]                   dma_axi_awlen,
   input  logic [1:0]                   dma_axi_awburst,


   input  logic                         dma_axi_wvalid,
   output logic                         dma_axi_wready,
   input  logic [63:0]                  dma_axi_wdata,
   input  logic [7:0]                   dma_axi_wstrb,
   input  logic                         dma_axi_wlast,

   output logic                         dma_axi_bvalid,
   input  logic                         dma_axi_bready,
   output logic [1:0]                   dma_axi_bresp,
   output logic [pt.DMA_BUS_TAG-1:0]    dma_axi_bid,

   // AXI Read Channels
   input  logic                         dma_axi_arvalid,
   output logic                         dma_axi_arready,
   input  logic [pt.DMA_BUS_TAG-1:0]    dma_axi_arid,
   input  logic [31:0]                  dma_axi_araddr,
   input  logic [2:0]                   dma_axi_arsize,
   input  logic [2:0]                   dma_axi_arprot,
   input  logic [7:0]                   dma_axi_arlen,
   input  logic [1:0]                   dma_axi_arburst,

   output logic                         dma_axi_rvalid,
   input  logic                         dma_axi_rready,
   output logic [pt.DMA_BUS_TAG-1:0]    dma_axi_rid,
   output logic [63:0]                  dma_axi_rdata,
   output logic [1:0]                   dma_axi_rresp,
   output logic                         dma_axi_rlast,


 //// AHB LITE BUS
   output logic [31:0]           haddr,
   /* exclude signals that are tied to constant value in axi4_to_ahb.sv */
   /*pragma coverage off*/
   output logic [2:0]            hburst,
   output logic                  hmastlock,
   /*pragma coverage on*/
   output logic [3:0]            hprot,
   output logic [2:0]            hsize,
   output logic [1:0]            htrans,
   output logic                  hwrite,

   input  logic [63:0]           hrdata,
   input  logic                  hready,
   input  logic                  hresp,

   // LSU AHB Master
   output logic [31:0]          lsu_haddr,
   /* exclude signals that are tied to constant value in axi4_to_ahb.sv */
   /*pragma coverage off*/
   output logic [2:0]           lsu_hburst,
   output logic                 lsu_hmastlock,
   /*pragma coverage on*/
   output logic [3:0]           lsu_hprot,
   output logic [2:0]           lsu_hsize,
   output logic [1:0]           lsu_htrans,
   output logic                 lsu_hwrite,
   output logic [63:0]          lsu_hwdata,

   input  logic [63:0]          lsu_hrdata,
   input  logic                 lsu_hready,
   input  logic                 lsu_hresp,

   //System Bus Debug Master
   output logic [31:0]          sb_haddr,
   /* exclude signals that are tied to constant value in axi4_to_ahb.sv */
   /*pragma coverage off*/
   output logic [2:0]           sb_hburst,
   output logic                 sb_hmastlock,
   /*pragma coverage on*/
   output logic [3:0]           sb_hprot,
   output logic [2:0]           sb_hsize,
   output logic [1:0]           sb_htrans,
   output logic                 sb_hwrite,
   output logic [63:0]          sb_hwdata,

   input  logic [63:0]          sb_hrdata,
   input  logic                 sb_hready,
   input  logic                 sb_hresp,

   // DMA Slave
   input logic                   dma_hsel,
   input logic [31:0]            dma_haddr,
   input logic [2:0]             dma_hburst,
   input logic                   dma_hmastlock,
   input logic [3:0]             dma_hprot,
   input logic [2:0]             dma_hsize,
   input logic [1:0]             dma_htrans,
   input logic                   dma_hwrite,
   input logic [63:0]            dma_hwdata,
   input logic                   dma_hreadyin,

   output  logic [63:0]          dma_hrdata,
   output  logic                 dma_hreadyout,
   output  logic                 dma_hresp,

   input   logic                 lsu_bus_clk_en,
   input   logic                 ifu_bus_clk_en,
   input   logic                 dbg_bus_clk_en,
   input   logic                 dma_bus_clk_en,

   input logic                  dmi_reg_en,                // read or write
   input logic [6:0]            dmi_reg_addr,              // address of DM register
   input logic                  dmi_reg_wr_en,             // write instruction
   input logic [31:0]           dmi_reg_wdata,             // write data
   output logic [31:0]          dmi_reg_rdata,

   // ICCM/DCCM ECC status
   output logic                 iccm_ecc_single_error,
   output logic                 iccm_ecc_double_error,
   output logic                 dccm_ecc_single_error,
   output logic                 dccm_ecc_double_error,
   output logic                 dccm_write_readback_error,

`ifdef RV_LOCKSTEP_REGFILE_ENABLE
   // Register file
   el2_regfile_if.veer_rf_src regfile,
`endif

   input logic [pt.PIC_TOTAL_INT:1]           extintsrc_req,
   input logic                   timer_int,
   input logic                   soft_int,
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic                   scan_mode
   /*pragma coverage on*/
);
```

## Parent instantiation

### design/el2_veer_wrapper.sv

```verilog
   el2_veer #(.pt(pt)) veer (
                                .clk(clk),
`ifdef RV_LOCKSTEP_REGFILE_ENABLE
                                .regfile(regfile.veer_rf_src),
`endif
                                .*
                                );
```

## Dependency declarations

### design/dbg/el2_dbg.sv

```verilog
module el2_dbg
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   // outputs to the core for command and data interface
   output logic [31:0]                 dbg_cmd_addr,
   output logic [31:0]                 dbg_cmd_wrdata,
   output logic                        dbg_cmd_valid,
   output logic                        dbg_cmd_write,             // 1: write command, 0: read_command
   output logic [1:0]                  dbg_cmd_type,              // 0:gpr 1:csr 2: memory
   output logic [1:0]                  dbg_cmd_size,              // size of the abstract mem access debug command
   output logic                        dbg_core_rst_l,            // core reset from dm

   // inputs back from the core/dec
   input logic [31:0]                  core_dbg_rddata,
   input logic                         core_dbg_cmd_done,         // This will be treated like a valid signal
   input logic                         core_dbg_cmd_fail,         // Exception during command run

   // Signals to dma to get a bubble
   output logic                        dbg_dma_bubble,            // Debug needs a bubble to send a valid
   input  logic                        dma_dbg_ready,             // DMA is ready to accept debug request

   // interface with the rest of the core to halt/resume handshaking
   output logic                        dbg_halt_req,              // This is a pulse
   output logic                        dbg_resume_req,            // Debug sends a resume requests. Pulse
   input  logic                        dec_tlu_debug_mode,        // Core is in debug mode
   input  logic                        dec_tlu_dbg_halted,        // The core has finished the queiscing sequence. Core is halted now
   input  logic                        dec_tlu_mpc_halted_only,   // Only halted due to MPC
   input  logic                        dec_tlu_resume_ack,        // core sends back an ack for the resume (pulse)

   // inputs from the JTAG
   input logic                         dmi_reg_en,                // read or write
   input logic [6:0]                   dmi_reg_addr,              // address of DM register
   input logic                         dmi_reg_wr_en,             // write instruction
   input logic [31:0]                  dmi_reg_wdata,             // write data

   // output
   output logic [31:0]                 dmi_reg_rdata,             // read data

   // AXI Write Channels
   output logic                        sb_axi_awvalid,
   input  logic                        sb_axi_awready,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [pt.SB_BUS_TAG-1:0]    sb_axi_awid,
   /*pragma coverage on*/
   output logic [31:0]                 sb_axi_awaddr,
   output logic [3:0]                  sb_axi_awregion,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [7:0]                  sb_axi_awlen,
   /*pragma coverage on*/
   output logic [2:0]                  sb_axi_awsize,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [1:0]                  sb_axi_awburst,
   output logic                        sb_axi_awlock,
   output logic [3:0]                  sb_axi_awcache,
   output logic [2:0]                  sb_axi_awprot,
   output logic [3:0]                  sb_axi_awqos,
   /*pragma coverage on*/

   output logic                        sb_axi_wvalid,
   input  logic                        sb_axi_wready,
   output logic [63:0]                 sb_axi_wdata,
   output logic [7:0]                  sb_axi_wstrb,
   output logic                        sb_axi_wlast,

   input  logic                        sb_axi_bvalid,
   output logic                        sb_axi_bready,
   input  logic [1:0]                  sb_axi_bresp,

   // AXI Read Channels
   output logic                        sb_axi_arvalid,
   input  logic                        sb_axi_arready,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [pt.SB_BUS_TAG-1:0]    sb_axi_arid,
   /*pragma coverage on*/
   output logic [31:0]                 sb_axi_araddr,
   output logic [3:0]                  sb_axi_arregion,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [7:0]                  sb_axi_arlen,
   /*pragma coverage on*/
   output logic [2:0]                  sb_axi_arsize,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic [1:0]                  sb_axi_arburst,
   output logic                        sb_axi_arlock,
   output logic [3:0]                  sb_axi_arcache,
   output logic [2:0]                  sb_axi_arprot,
   output logic [3:0]                  sb_axi_arqos,
   /*pragma coverage on*/

   input  logic                        sb_axi_rvalid,
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic                        sb_axi_rready,
   /*pragma coverage on*/
   input  logic [63:0]                 sb_axi_rdata,
   input  logic [1:0]                  sb_axi_rresp,

   input logic                         dbg_bus_clk_en,

   // DCCM write-readback sticky fault capture (see el2_lsu_dccm_ctl), exposed
   // read-only over DMI at 0x70/0x71/0x72. dccm_wr_rdbk_fault_clear re-arms
   // capture for the next fault.
   input logic                           dccm_wr_rdbk_fault_valid,
   input logic [pt.DCCM_BITS-1:0]        dccm_wr_rdbk_fault_addr,
   input logic [pt.DCCM_FDATA_WIDTH-1:0] dccm_wr_rdbk_fault_data,
   output logic                          dccm_wr_rdbk_fault_clear,

   // general inputs
   input logic                         clk,
   input logic                         free_clk,
   input logic                         rst_l,        // This includes both top rst and debug rst
   input logic                         dbg_rst_l,
   input logic                         clk_override,
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic                         scan_mode
   /*pragma coverage on*/
);
```

### design/dec/el2_dec.sv

```verilog
module el2_dec
  import el2_pkg::*;
#(
    `include "el2_param.vh"
) (
    input logic clk,                          // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
    input logic active_clk,                   // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
    input logic free_clk,                     // Clock always.                  Through two clock headers. For flops without second clock header built in.
    input logic free_l2clk,                   // Clock always.                  Through one clock header.  For flops with    second header built in.

    input logic lsu_fastint_stall_any,        // needed by lsu for 2nd pass of dma with ecc correction, stall next cycle

    output logic dec_extint_stall,  // Stall on external interrupt

    output logic dec_i0_decode_d,    // Valid instruction at D-stage and not blocked
    output logic dec_pause_state_cg, // to top for active state clock gating

    output logic dec_tlu_core_empty,

    input logic        rst_l,   // reset, active low
    // rst_vec is supposed to be connected to a constant in the top level
    /*pragma coverage off*/
    input logic [31:1] rst_vec, // reset vector, from core pins
    /*pragma coverage on*/

    input logic        nmi_int,  // NMI pin
    // nmi_vec is supposed to be connected to a constant in the top level
    /*pragma coverage off*/
    input logic [31:1] nmi_vec,  // NMI vector, from pins
    /*pragma coverage on*/

    input logic i_cpu_halt_req,  // Asynchronous Halt request to CPU
    input logic i_cpu_run_req,   // Asynchronous Restart request to CPU

    output logic o_cpu_halt_status,  // Halt status of core (pmu/fw)
    output logic o_cpu_halt_ack,  // Halt request ack
    output logic o_cpu_run_ack,  // Run request ack
    output logic o_debug_mode_status,         // Core to the PMU that core is in debug mode. When core is in debug mode, the PMU should refrain from sendng a halt or run request

    /*pragma coverage off*/
    input logic [31:4] core_id,  // CORE ID
    /*pragma coverage on*/

    // external MPC halt/run interface
    input  logic mpc_debug_halt_req,  // Async halt request
    input  logic mpc_debug_run_req,   // Async run request
    input  logic mpc_reset_run_req,   // Run/halt after reset
    output logic mpc_debug_halt_ack,  // Halt ack
    output logic mpc_debug_run_ack,   // Run ack
    output logic debug_brkpt_status,  // debug breakpoint

    input logic exu_pmu_i0_br_misp,    // slot 0 branch misp
    input logic exu_pmu_i0_br_ataken,  // slot 0 branch actual taken
    input logic exu_pmu_i0_pc4,        // slot 0 4 byte branch


    input logic lsu_nonblock_load_valid_m,  // valid nonblock load at m
    input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_tag_m,  // -> corresponding tag
    input logic lsu_nonblock_load_inv_r,  // invalidate request for nonblock load r
    input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_inv_tag_r,  // -> corresponding tag
    input logic lsu_nonblock_load_data_valid,  // valid nonblock load data back
    input logic lsu_nonblock_load_data_error,  // nonblock load bus error
    input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0] lsu_nonblock_load_data_tag,  // -> corresponding tag
    input logic [31:0] lsu_nonblock_load_data,  // nonblock load data

    input logic lsu_pmu_bus_trxn,          // D side bus transaction
    input logic lsu_pmu_bus_misaligned,    // D side bus misaligned
    input logic lsu_pmu_bus_error,         // D side bus error
    input logic lsu_pmu_bus_busy,          // D side bus busy
    input logic lsu_pmu_misaligned_m,      // D side load or store misaligned
    input logic lsu_pmu_load_external_m,   // D side bus load
    input logic lsu_pmu_store_external_m,  // D side bus store
    input logic dma_pmu_dccm_read,         // DMA DCCM read
    input logic dma_pmu_dccm_write,        // DMA DCCM write
    input logic dma_pmu_any_read,          // DMA read
    input logic dma_pmu_any_write,         // DMA write

    input logic [31:1] lsu_fir_addr,  // Fast int address
    input logic [ 1:0] lsu_fir_error, // Fast int lookup error

    input logic ifu_pmu_instr_aligned,  // aligned instructions
    input logic ifu_pmu_fetch_stall,    // fetch unit stalled
    input logic ifu_pmu_ic_miss,        // icache miss
    input logic ifu_pmu_ic_hit,         // icache hit
    input logic ifu_pmu_bus_error,      // Instruction side bus error
    input logic ifu_pmu_bus_busy,       // Instruction side bus busy
    input logic ifu_pmu_bus_trxn,       // Instruction side bus transaction

    input logic ifu_ic_error_start,         // IC single bit error
    input logic ifu_iccm_rd_ecc_single_err, // ICCM single bit error

    input logic [ 3:0] lsu_trigger_match_m,
    input logic        dbg_cmd_valid,        // debugger abstract command valid
    input logic        dbg_cmd_write,        // command is a write
    input logic [ 1:0] dbg_cmd_type,         // command type
    input logic [31:0] dbg_cmd_addr,         // command address
    input logic [ 1:0] dbg_cmd_wrdata,       // command write data, for fence/fence_i


    input logic       ifu_i0_icaf,      // icache access fault
    input logic [1:0] ifu_i0_icaf_type, // icache access fault type

    input logic ifu_i0_icaf_second,  // i0 has access fault on second 2B of 4B inst
    input logic ifu_i0_dbecc,        // icache/iccm double-bit error

    input logic lsu_idle_any,  // lsu idle for halting

    input el2_br_pkt_t                                 i0_brp,           // branch packet
    input logic        [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] ifu_i0_bp_index,  // BP index
    input logic        [          pt.BHT_GHR_SIZE-1:0] ifu_i0_bp_fghr,   // BP FGHR
    input logic        [         pt.BTB_BTAG_SIZE-1:0] ifu_i0_bp_btag,   // BP tag
    input logic        [      $clog2(pt.BTB_SIZE)-1:0] ifu_i0_fa_index,  // Fully associative btb index

    input el2_lsu_error_pkt_t lsu_error_pkt_r,           // LSU exception/error packet
    input logic               lsu_single_ecc_error_incr, // LSU inc SB error counter

    input logic        lsu_imprecise_error_load_any,   // LSU imprecise load bus error
    input logic        lsu_imprecise_error_store_any,  // LSU imprecise store bus error
    input logic [31:0] lsu_imprecise_error_addr_any,   // LSU imprecise bus error address

    input logic [31:0] exu_div_result,  // final div result
    input logic        exu_div_wren,    // Divide write enable to GPR

    input logic [31:0] exu_csr_rs1_x,  // rs1 for csr instruction

    input logic [31:0] lsu_result_m,      // load result
    input logic [31:0] lsu_result_corr_r, // load result - corrected load data

    input logic lsu_load_stall_any,   // This is for blocking loads
    input logic lsu_store_stall_any,  // This is for blocking stores
    input logic dma_dccm_stall_any,   // stall any load/store at decode, pmu event
    input logic dma_iccm_stall_any,   // iccm stalled, pmu event

    input logic iccm_dma_sb_error,  // ICCM DMA single bit error

    input logic exu_flush_final,  // slot0 flush

    input logic [31:1] exu_npc_r,  // next PC

    input logic [31:0] exu_i0_result_x,  // alu result x


    input logic        ifu_i0_valid,  // fetch valids to instruction buffer
    input logic [31:0] ifu_i0_instr,  // fetch inst's to instruction buffer
    input logic [31:1] ifu_i0_pc,     // pc's for instruction buffer
    input logic        ifu_i0_pc4,    // indication of 4B or 2B for corresponding inst
    input logic [31:1] exu_i0_pc_x,   // pc's for e1 from the alu's

    input logic mexintpend,  // External interrupt pending
    input logic timer_int,   // Timer interrupt pending (from pin)
    input logic soft_int,    // Software interrupt pending (from pin)

    input logic [7:0] pic_claimid,  // PIC claimid
    input logic [3:0] pic_pl,       // PIC priv level
    input logic       mhwakeup,     // High priority wakeup

    output logic [3:0] dec_tlu_meicurpl,  // to PIC, Current priv level
    output logic [3:0] dec_tlu_meipt,     // to PIC

    input logic [70:0] ifu_ic_debug_rd_data,  // diagnostic icache read data
    input logic ifu_ic_debug_rd_data_valid,  // diagnostic icache read data valid
    output el2_cache_debug_pkt_t dec_tlu_ic_diag_pkt, // packet of DICAWICS, DICAD0/1, DICAGO info for icache diagnostics


    // Debug start
    input logic dbg_halt_req,        // DM requests a halt
    input logic dbg_resume_req,      // DM requests a resume
    input logic ifu_miss_state_idle, // I-side miss buffer empty

    output logic        dec_tlu_dbg_halted,        // Core is halted and ready for debug command
    output logic        dec_tlu_debug_mode,        // Core is in debug mode
    output logic        dec_tlu_resume_ack,        // Resume acknowledge
    output logic        dec_tlu_flush_noredir_r,   // Tell fetch to idle on this flush
    output logic        dec_tlu_mpc_halted_only,   // Core is halted only due to MPC
    output logic        dec_tlu_flush_leak_one_r,  // single step
    output logic        dec_tlu_flush_err_r,       // iside perr/ecc rfpc
    output logic [31:2] dec_tlu_meihap,            // Fast ext int base

    output logic dec_debug_wdata_rs1_d,  // insert debug write data into rs1 at decode

    output logic [31:0] dec_dbg_rddata,  // debug command read data

    output logic dec_dbg_cmd_done,  // abstract command is done
    output logic dec_dbg_cmd_fail,  // abstract command failed (illegal reg address)

    output el2_trigger_pkt_t [3:0] trigger_pkt_any,  // info needed by debug trigger blocks

    output logic       dec_tlu_force_halt,       // halt has been forced
    // Debug end
    // branch info from pipe0 for errors or counter updates
    input  logic [1:0] exu_i0_br_hist_r,         // history
    input  logic       exu_i0_br_error_r,        // error
    input  logic       exu_i0_br_start_error_r,  // start error
    input  logic       exu_i0_br_valid_r,        // valid
    input  logic       exu_i0_br_mp_r,           // mispredict
    input  logic       exu_i0_br_middle_r,       // middle of bank

    // branch info from pipe1 for errors or counter updates

    input logic exu_i0_br_way_r,  // way hit or repl

    output logic        dec_i0_rs1_en_d,  // Qualify GPR RS1 data
    output logic        dec_i0_rs2_en_d,  // Qualify GPR RS2 data
    output logic [31:0] gpr_i0_rs1_d,     // gpr rs1 data
    output logic [31:0] gpr_i0_rs2_d,     // gpr rs2 data

    output logic [31:0] dec_i0_immed_d,    // immediate data
    output logic [12:1] dec_i0_br_immed_d, // br immediate data

    output el2_alu_pkt_t i0_ap,  // alu packet

    output logic dec_i0_alu_decode_d,  // schedule on D-stage alu
    output logic dec_i0_branch_d,      // Branch in D-stage

    output logic dec_i0_select_pc_d,  // select pc onto rs1 for jal's

    output logic [31:1] dec_i0_pc_d,             // pc's at decode
    output logic [ 3:0] dec_i0_rs1_bypass_en_d,  // rs1 bypass enable
    output logic [ 3:0] dec_i0_rs2_bypass_en_d,  // rs2 bypass enable

    output logic [31:0] dec_i0_result_r,  // Result R-stage

    output el2_lsu_pkt_t lsu_p,           // lsu packet
    output logic         dec_qual_lsu_d,  // LSU instruction at D.  Use to quiet LSU operands
    output el2_mul_pkt_t mul_p,           // mul packet
    output el2_div_pkt_t div_p,           // div packet
    output logic         dec_div_cancel,  // cancel divide operation

    output logic [11:0] dec_lsu_offset_d,  // 12b offset for load/store addresses

    output logic        dec_csr_ren_d,    // CSR read enable
    output logic [31:0] dec_csr_rddata_d, // CSR read data

    output logic dec_tlu_flush_lower_r,  // tlu flush due to late mp, exception, rfpc, or int
    output logic dec_tlu_flush_lower_wb,
    output logic [31:1] dec_tlu_flush_path_r,  // tlu flush target
    output logic        dec_tlu_i0_kill_writeb_r,    // I0 is flushed, don't writeback any results to arch state
    output logic dec_tlu_fence_i_r,  // flush is a fence_i rfnpc, flush icache

    output logic [31:1] pred_correct_npc_x,  // npc if prediction is correct at e2 stage

    output el2_br_tlu_pkt_t dec_tlu_br0_r_pkt,  // slot 0 branch predictor update packet

    output logic dec_tlu_perfcnt0,  // toggles when slot0 perf counter 0 has an event inc
    output logic dec_tlu_perfcnt1,  // toggles when slot0 perf counter 1 has an event inc
    output logic dec_tlu_perfcnt2,  // toggles when slot0 perf counter 2 has an event inc
    output logic dec_tlu_perfcnt3,  // toggles when slot0 perf counter 3 has an event inc

    output el2_predict_pkt_t dec_i0_predict_p_d,  // prediction packet to alus
    output logic [pt.BHT_GHR_SIZE-1:0] i0_predict_fghr_d,  // DEC predict fghr
    output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] i0_predict_index_d,  // DEC predict index
    output logic [pt.BTB_BTAG_SIZE-1:0] i0_predict_btag_d,  // DEC predict branch tag

    output logic [$clog2(pt.BTB_SIZE)-1:0] dec_fa_error_index,  // Fully associative btb error index

    output logic dec_lsu_valid_raw_d,

    output logic [31:0] dec_tlu_mrac_ff,  // CSR for memory region control

    output logic [1:0] dec_data_en,  // clock-gate control logic
    output logic [1:0] dec_ctl_en,

    input logic [15:0] ifu_i0_cinst,  // 16b compressed instruction

    output el2_trace_pkt_t trace_rv_trace_pkt,  // trace packet

    // PMP signals
    output el2_pmp_cfg_pkt_t        pmp_pmpcfg [pt.PMP_ENTRIES],
    output logic             [31:0] pmp_pmpaddr[pt.PMP_ENTRIES],

`ifdef RV_USER_MODE

    // Privilege mode
    output logic priv_mode,
    output logic priv_mode_eff,
    output logic priv_mode_ns,

    // mseccfg CSR content for PMP
    output el2_mseccfg_pkt_t mseccfg,

`endif

    // feature disable from mfdc
    output logic dec_tlu_external_ldfwd_disable,  // disable external load forwarding
    output logic dec_tlu_sideeffect_posted_disable,  // disable posted stores to side-effect address
    output logic dec_tlu_core_ecc_disable,  // disable core ECC
    output logic dec_tlu_dccm_wr_readback_disable,  // disable DCCM write-readback check
    output logic dec_tlu_bpred_disable,  // disable branch prediction
    output logic dec_tlu_wb_coalescing_disable,  // disable writebuffer coalescing
    output logic [2:0] dec_tlu_dma_qos_prty,  // DMA QoS priority coming from MFDC [18:16]

    // clock gating overrides from mcgc
    output logic dec_tlu_misc_clk_override,   // override misc clock domain gating
    output logic dec_tlu_ifu_clk_override,    // override fetch clock domain gating
    output logic dec_tlu_lsu_clk_override,    // override load/store clock domain gating
    output logic dec_tlu_bus_clk_override,    // override bus clock domain gating
    output logic dec_tlu_pic_clk_override,    // override PIC clock domain gating
    output logic dec_tlu_picio_clk_override,  // override PICIO clock domain gating
    output logic dec_tlu_dccm_clk_override,   // override DCCM clock domain gating
    output logic dec_tlu_icm_clk_override,    // override ICCM clock domain gating

`ifdef RV_LOCKSTEP_REGFILE_ENABLE
    el2_regfile_if.veer_rf_src regfile,
`endif

    output logic dec_tlu_i0_commit_cmt,  // committed i0 instruction
    // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
    /*pragma coverage off*/
    input  logic scan_mode               // Flop scan mode control
    /*pragma coverage on*/

);
```

### design/el2_dma_ctrl.sv

```verilog
module el2_dma_ctrl 
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input logic         clk,
   input logic         free_clk,
   input logic         rst_l,
   input logic         dma_bus_clk_en, // slave bus clock enable
   input logic         clk_override,
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic         scan_mode,
   /*pragma coverage on*/

   // Debug signals
   input logic [31:0]  dbg_cmd_addr,
   input logic [31:0]  dbg_cmd_wrdata,
   input logic         dbg_cmd_valid,
   input logic         dbg_cmd_write, // 1: write command, 0: read_command
   input logic [1:0]   dbg_cmd_type, // 0:gpr 1:csr 2: memory
   input logic [1:0]   dbg_cmd_size, // size of the abstract mem access debug command

   input  logic        dbg_dma_bubble,   // Debug needs a bubble to send a valid
   output logic        dma_dbg_ready,    // DMA is ready to accept debug request

   output logic        dma_dbg_cmd_done,
   output logic        dma_dbg_cmd_fail,
   output logic [31:0] dma_dbg_rddata,

   // Core side signals
   output logic        dma_dccm_req,  // DMA dccm request (only one of dccm/iccm will be set)
   output logic        dma_iccm_req,  // DMA iccm request
   output logic [2:0]  dma_mem_tag,   // DMA Buffer entry number
   output logic [31:0] dma_mem_addr,  // DMA request address
   output logic [2:0]  dma_mem_sz,    // DMA request size
   output logic        dma_mem_write, // DMA write to dccm/iccm
   output logic [63:0] dma_mem_wdata, // DMA write data

   input logic         dccm_dma_rvalid,    // dccm data valid for DMA read
   input logic         dccm_dma_ecc_error, // ECC error on DMA read
   input logic [2:0]   dccm_dma_rtag,      // Tag of the DMA req
   input logic [63:0]  dccm_dma_rdata,     // dccm data for DMA read
   input logic         iccm_dma_rvalid,    // iccm data valid for DMA read
   input logic         iccm_dma_ecc_error, // ECC error on DMA read
   input logic [2:0]   iccm_dma_rtag,      // Tag of the DMA req
   input logic [63:0]  iccm_dma_rdata,     // iccm data for DMA read

   output logic        dma_active,         // DMA is busy
   output logic        dma_dccm_stall_any, // stall dccm pipe (bubble) so that DMA can proceed
   output logic        dma_iccm_stall_any, // stall iccm pipe (bubble) so that DMA can proceed
   input logic         dccm_ready, // dccm ready to accept DMA request
   input logic         iccm_ready, // iccm ready to accept DMA request
   input logic [2:0]   dec_tlu_dma_qos_prty,    // DMA QoS priority coming from MFDC [18:15]

   // PMU signals
   output logic        dma_pmu_dccm_read,
   output logic        dma_pmu_dccm_write,
   output logic        dma_pmu_any_read,
   output logic        dma_pmu_any_write,

   // AXI Write Channels
   input  logic                        dma_axi_awvalid,
   output logic                        dma_axi_awready,
   input  logic [pt.DMA_BUS_TAG-1:0]   dma_axi_awid,
   input  logic [31:0]                 dma_axi_awaddr,
   input  logic [2:0]                  dma_axi_awsize,


   input  logic                        dma_axi_wvalid,
   output logic                        dma_axi_wready,
   input  logic [63:0]                 dma_axi_wdata,
   input  logic [7:0]                  dma_axi_wstrb,

   output logic                        dma_axi_bvalid,
   input  logic                        dma_axi_bready,
   output logic [1:0]                  dma_axi_bresp,
   output logic [pt.DMA_BUS_TAG-1:0]   dma_axi_bid,

   // AXI Read Channels
   input  logic                        dma_axi_arvalid,
   output logic                        dma_axi_arready,
   input  logic [pt.DMA_BUS_TAG-1:0]   dma_axi_arid,
   input  logic [31:0]                 dma_axi_araddr,
   input  logic [2:0]                  dma_axi_arsize,

   output logic                        dma_axi_rvalid,
   input  logic                        dma_axi_rready,
   output logic [pt.DMA_BUS_TAG-1:0]   dma_axi_rid,
   output logic [63:0]                 dma_axi_rdata,
   output logic [1:0]                  dma_axi_rresp,
   output logic                        dma_axi_rlast
);
```

### design/el2_pic_ctrl.sv

```verilog
module el2_pic_ctrl 
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
                  (

                     input  logic                   clk,                  // Core clock
                     input  logic                   free_clk,             // free clock
                     input  logic                   rst_l,                // Reset for all flops
                     input  logic                   clk_override,         // Clock over-ride for gating
                     input  logic                   io_clk_override,      // PIC IO  Clock over-ride for gating
                     input  logic [pt.PIC_TOTAL_INT_PLUS1-1:0]   extintsrc_req,  // Interrupt requests
                     input  logic [31:0]            picm_rdaddr,          // Address of the register
                     input  logic [31:0]            picm_wraddr,          // Address of the register
                     input  logic [31:0]            picm_wr_data,         // Data to be written to the register
                     input  logic                   picm_wren,            // Write enable to the register
                     input  logic                   picm_rden,            // Read enable for the register
                     input  logic                   picm_mken,            // Read the Mask for the register
                     input  logic [3:0]             meicurpl,             // Current Priority Level
                     input  logic [3:0]             meipt,                // Current Priority Threshold

                     output logic                   mexintpend,           // External interrupt request to the core
                     output logic [7:0]             claimid,              // Claim Id of the requested interrupt
                     output logic [3:0]             pl,                   // Priority level of the requested interrupt
                     output logic [31:0]            picm_rd_data,         // Read data of the register
                     output logic                   mhwakeup,             // Wake-up interrupt request
                     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
                     /*pragma coverage off*/
                     input  logic                   scan_mode             // scan mode
                     /*pragma coverage on*/

);
```

### design/el2_pmp.sv

```verilog
module el2_pmp
  import el2_pkg::*;
#(
    parameter PMP_CHANNELS = 3,
    // Granularity of NAPOT access,
    // 0 = No restriction, 1 = 8 byte, 2 = 16 byte, 3 = 32 byte, etc.
    parameter PMP_GRANULARITY = 0,  // TODO: Move to veer.config
    `include "el2_param.vh"
) (
    input logic clk,       // Top level clock
    input logic rst_l,     // Reset
    /* pragma coverage off */
    input logic scan_mode, // Scan mode
    /* pragma coverage on */

`ifdef RV_SMEPMP
    input el2_mseccfg_pkt_t mseccfg, // mseccfg CSR content, RLB, MMWP and MML bits
`endif

`ifdef RV_USER_MODE
    input logic priv_mode_ns,   // operating privilege mode (next clock cycle)
    input logic priv_mode_eff,  // operating effective privilege mode
`endif

    input el2_pmp_cfg_pkt_t        pmp_pmpcfg [pt.PMP_ENTRIES],
    input logic             [31:0] pmp_pmpaddr[pt.PMP_ENTRIES],

    input  logic              [31:0] pmp_chan_addr[PMP_CHANNELS],
    input  el2_pmp_type_pkt_t        pmp_chan_type[PMP_CHANNELS],
    output logic                     pmp_chan_err [PMP_CHANNELS]
);
```

### design/exu/el2_exu.sv

```verilog
module el2_exu
import el2_pkg::*;
#(
`include "el2_param.vh"
)
  (
   input logic          clk,                                           // Top level clock
   input logic          rst_l,                                         // Reset
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic          scan_mode,                                     // Scan control
   /*pragma coverage on*/

   input logic  [1:0]   dec_data_en,                                   // Clock enable {x,r}, one cycle pulse
   input logic  [1:0]   dec_ctl_en,                                    // Clock enable {x,r}, two cycle pulse
   input logic  [31:0]  dbg_cmd_wrdata,                                // Debug data   to primary I0 RS1
   input el2_alu_pkt_t i0_ap,                                         // DEC alu {valid,predecodes}

   input logic          dec_debug_wdata_rs1_d,                         // Debug select to primary I0 RS1

   input el2_predict_pkt_t dec_i0_predict_p_d,                        // DEC branch predict packet
   input logic [pt.BHT_GHR_SIZE-1:0] i0_predict_fghr_d,                // DEC predict fghr
   input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] i0_predict_index_d,     // DEC predict index
   input logic [pt.BTB_BTAG_SIZE-1:0] i0_predict_btag_d,               // DEC predict branch tag

   input logic  [31:0]  lsu_result_m,                                  // Load result M-stage
   input logic  [31:0]  lsu_nonblock_load_data,                        // nonblock load data
   input logic          dec_i0_rs1_en_d,                               // Qualify GPR RS1 data
   input logic          dec_i0_rs2_en_d,                               // Qualify GPR RS2 data
   input logic  [31:0]  gpr_i0_rs1_d,                                  // DEC data gpr
   input logic  [31:0]  gpr_i0_rs2_d,                                  // DEC data gpr
   input logic  [31:0]  dec_i0_immed_d,                                // DEC data immediate
   input logic  [31:0]  dec_i0_result_r,                               // DEC result in R-stage
   input logic  [12:1]  dec_i0_br_immed_d,                             // Branch immediate
   input logic          dec_i0_alu_decode_d,                           // Valid to X-stage ALU
   input logic          dec_i0_branch_d,                               // Branch in D-stage
   input logic          dec_i0_select_pc_d,                            // PC select to RS1
   input logic  [31:1]  dec_i0_pc_d,                                   // Instruction PC
   input logic  [3:0]   dec_i0_rs1_bypass_en_d,                        // DEC bypass select  1 - X-stage, 0 - dec bypass data
   input logic  [3:0]   dec_i0_rs2_bypass_en_d,                        // DEC bypass select  1 - X-stage, 0 - dec bypass data
   input logic          dec_csr_ren_d,                                 // CSR read select
   input logic  [31:0]  dec_csr_rddata_d,                              // CSR read data

   input logic          dec_qual_lsu_d,                                // LSU instruction at D.  Use to quiet LSU operands
   input el2_mul_pkt_t mul_p,                                         // DEC {valid, operand signs, low, operand bypass}
   input el2_div_pkt_t div_p,                                         // DEC {valid, unsigned, rem}
   input logic          dec_div_cancel,                                // Cancel the divide operation

   input logic  [31:1]  pred_correct_npc_x,                            // DEC NPC for correctly predicted branch

   input logic          dec_tlu_flush_lower_r,                         // Flush divide and secondary ALUs
   input logic  [31:1]  dec_tlu_flush_path_r,                          // Redirect target


   input logic         dec_extint_stall,                               // External stall mux select
   input logic [31:2]  dec_tlu_meihap,                                 // External stall mux data


   output logic [31:0]  exu_lsu_rs1_d,                                 // LSU operand
   output logic [31:0]  exu_lsu_rs2_d,                                 // LSU operand

   output logic         exu_flush_final,                               // Pipe is being flushed this cycle
   output logic [31:1]  exu_flush_path_final,                          // Target for the oldest flush source

   output logic [31:0]  exu_i0_result_x,                               // Primary ALU result to DEC
   output logic [31:1]  exu_i0_pc_x,                                   // Primary PC  result to DEC
   output logic [31:0]  exu_csr_rs1_x,                                 // RS1 source for a CSR instruction

   output logic [31:1]  exu_npc_r,                                     // Divide NPC
   output logic [1:0]   exu_i0_br_hist_r,                              // to DEC  I0 branch history
   output logic         exu_i0_br_error_r,                             // to DEC  I0 branch error
   output logic         exu_i0_br_start_error_r,                       // to DEC  I0 branch start error
   output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] exu_i0_br_index_r,     // to DEC  I0 branch index
   output logic         exu_i0_br_valid_r,                             // to DEC  I0 branch valid
   output logic         exu_i0_br_mp_r,                                // to DEC  I0 branch mispredict
   output logic         exu_i0_br_middle_r,                            // to DEC  I0 branch middle
   output logic [pt.BHT_GHR_SIZE-1:0]  exu_i0_br_fghr_r,               // to DEC  I0 branch fghr
   output logic         exu_i0_br_way_r,                               // to DEC  I0 branch way

   output el2_predict_pkt_t exu_mp_pkt,                               // Mispredict branch packet
   output logic [pt.BHT_GHR_SIZE-1:0]  exu_mp_eghr,                    // Mispredict global history
   output logic [pt.BHT_GHR_SIZE-1:0]  exu_mp_fghr,                    // Mispredict fghr
   output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]  exu_mp_index,         // Mispredict index
   output logic [pt.BTB_BTAG_SIZE-1:0]  exu_mp_btag,                   // Mispredict btag


   output logic         exu_pmu_i0_br_misp,                            // to PMU - I0 E4 branch mispredict
   output logic         exu_pmu_i0_br_ataken,                          // to PMU - I0 E4 taken
   output logic         exu_pmu_i0_pc4,                                // to PMU - I0 E4 PC


   output logic [31:0]  exu_div_result,                                // Divide result
   output logic         exu_div_wren                                   // Divide write enable to GPR
  );
```

### design/ifu/el2_ifu.sv

```verilog
module el2_ifu
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic free_l2clk,                   // Clock always.                  Through one clock header.  For flops with    second header built in.
   input logic active_clk,                   // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
   input logic clk,                          // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic rst_l,                        // reset, active low

   input logic dec_i0_decode_d,              // Valid instruction at D and not blocked

   input logic exu_flush_final, // flush, includes upper and lower
   input logic dec_tlu_i0_commit_cmt , // committed i0
   input logic dec_tlu_flush_err_wb , // flush due to parity error.
   input logic dec_tlu_flush_noredir_wb, // don't fetch, validated with exu_flush_final
   input logic [31:1] exu_flush_path_final, // flush fetch address

   input logic [31:0]  dec_tlu_mrac_ff ,// Side_effect , cacheable for each region
   input logic         dec_tlu_fence_i_wb, // fence.i, invalidate icache, validated with exu_flush_final
   input logic         dec_tlu_flush_leak_one_wb, // ignore bp for leak one fetches

   input logic                       dec_tlu_bpred_disable,     // disable all branch prediction
   input logic                       dec_tlu_core_ecc_disable,  // disable ecc checking and flagging
   input logic                       dec_tlu_force_halt,        // force halt

  //-------------------------- IFU AXI signals--------------------------
   // AXI Write Channels
   /* exclude signals that are tied to constant value in el2_ifu_mem_ctl.sv */
   /*pragma coverage off*/
   output logic                            ifu_axi_awvalid,
   output logic [pt.IFU_BUS_TAG-1:0]       ifu_axi_awid,
   output logic [31:0]                     ifu_axi_awaddr,
   output logic [3:0]                      ifu_axi_awregion,
   output logic [7:0]                      ifu_axi_awlen,
   output logic [2:0]                      ifu_axi_awsize,
   output logic [1:0]                      ifu_axi_awburst,
   output logic                            ifu_axi_awlock,
   output logic [3:0]                      ifu_axi_awcache,
   output logic [2:0]                      ifu_axi_awprot,
   output logic [3:0]                      ifu_axi_awqos,

   output logic                            ifu_axi_wvalid,
   output logic [63:0]                     ifu_axi_wdata,
   output logic [7:0]                      ifu_axi_wstrb,
   output logic                            ifu_axi_wlast,

   output logic                            ifu_axi_bready,
   /*pragma coverage on*/

   // AXI Read Channels
   output logic                            ifu_axi_arvalid,
   input  logic                            ifu_axi_arready,
   output logic [pt.IFU_BUS_TAG-1:0]       ifu_axi_arid,
   output logic [31:0]                     ifu_axi_araddr,
   output logic [3:0]                      ifu_axi_arregion,
   /* exclude signals that are tied to constant value in el2_ifu_mem_ctl.sv */
   /*pragma coverage off*/
   output logic [7:0]                      ifu_axi_arlen,
   output logic [2:0]                      ifu_axi_arsize,
   output logic [1:0]                      ifu_axi_arburst,
   output logic                            ifu_axi_arlock,
   output logic [3:0]                      ifu_axi_arcache,
   output logic [2:0]                      ifu_axi_arprot,
   output logic [3:0]                      ifu_axi_arqos,
   /*pragma coverage on*/

   input  logic                            ifu_axi_rvalid,
   /* exclude signals that are tied to constant value in el2_ifu_mem_ctl.sv */
   /*pragma coverage off*/
   output logic                            ifu_axi_rready,
   /*pragma coverage on*/
   input  logic [pt.IFU_BUS_TAG-1:0]       ifu_axi_rid,
   input  logic [63:0]                     ifu_axi_rdata,
   input  logic [1:0]                      ifu_axi_rresp,

   input  logic                      ifu_bus_clk_en,

   input  logic                      dma_iccm_req,
   input  logic [31:0]               dma_mem_addr,
   input  logic [2:0]                dma_mem_sz,
   input  logic                      dma_mem_write,
   input  logic [63:0]               dma_mem_wdata,
   input  logic [2:0]                dma_mem_tag,       //  DMA Buffer entry number


   input  logic                      dma_iccm_stall_any,
   output logic                      iccm_dma_ecc_error,
   output logic                      iccm_dma_rvalid,
   output logic [63:0]               iccm_dma_rdata,
   output logic [2:0]                iccm_dma_rtag,     //   Tag of the DMA req
   output logic                      iccm_ready,

   output logic       ifu_pmu_instr_aligned,
   output logic       ifu_pmu_fetch_stall,
   output logic       ifu_ic_error_start,     // has all of the I$ ecc/parity for data/tag

//   I$ & ITAG Ports
   output logic [31:1]               ic_rw_addr,         // Read/Write address to the Icache.
   output logic [pt.ICACHE_NUM_WAYS-1:0]                ic_wr_en,           // Icache write enable, when filling the Icache.
   output logic                      ic_rd_en,           // Icache read  enable.

   output logic [pt.ICACHE_BANKS_WAY-1:0][70:0]               ic_wr_data,         // Data to fill to the Icache. With ECC
   input  logic [141:0]                   ic_rd_data ,         // Raw way-muxed 142-bit ECC-protected word pair. F2 stage.
   input  logic [1:0]                     ic_rd_addr_lo,       // F2-aligned ic_rw_addr_ff[2:1] for core-side rotate
   input  logic [pt.ICACHE_BANKS_WAY-1:0] ic_rd_bank_check_en, // Per-bank ECC check enable for core-side decode
   input  logic [70:0]              ic_debug_rd_data ,        // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
   input  logic [25:0]                     ictag_debug_rd_data,// Debug icache tag.
   output logic [70:0]               ic_debug_wr_data,   // Debug wr cache.

   output logic [70:0]               ifu_ic_debug_rd_data,

   output logic [pt.ICACHE_INDEX_HI:3]               ic_debug_addr,      // Read/Write address to the Icache.
   output logic                      ic_debug_rd_en,     // Icache debug rd
   output logic                      ic_debug_wr_en,     // Icache debug wr
   output logic                      ic_debug_tag_array, // Debug tag array
   output logic [pt.ICACHE_NUM_WAYS-1:0]                ic_debug_way,       // Debug way. Rd or Wr.


   output logic [pt.ICACHE_NUM_WAYS-1:0]                ic_tag_valid,       // Valid bits when accessing the Icache. One valid bit per way. F2 stage

   input  logic [pt.ICACHE_NUM_WAYS-1:0]                ic_rd_hit,          // Compare hits from Icache tags. Per way.  F2 stage
   input  logic                      ic_tag_perr,        // Icache Tag parity error


   // ICCM ports
   output logic [pt.ICCM_BITS-1:1]               iccm_rw_addr,       // ICCM read/write address.
   output logic                      iccm_wren,          // ICCM write enable (through the DMA)
   output logic                      iccm_rden,          // ICCM read enable.
   output logic [77:0]               iccm_wr_data,       // ICCM write data.
   output logic [2:0]                iccm_wr_size,       // ICCM write location within DW.

   input  logic [77:0]               iccm_rd_data_ecc,   // Data + ECC read from ICCM.

   // ICCM ECC status
   output logic                      ifu_iccm_dma_rd_ecc_single_err, // This fetch has a single ICCM DMA ECC error.
   output logic                      ifu_iccm_rd_ecc_single_err,     // This fetch has a single ICCM ECC error.
   output logic                      ifu_iccm_rd_ecc_double_err,     // This fetch has a double ICCM ECC error.

// Perf counter sigs
   output logic       ifu_pmu_ic_miss, // ic miss
   output logic       ifu_pmu_ic_hit, // ic hit
   output logic       ifu_pmu_bus_error, // iside bus error
   output logic       ifu_pmu_bus_busy,  // iside bus busy
   output logic       ifu_pmu_bus_trxn, // iside bus transactions


   output logic       ifu_i0_icaf,         // Instruction 0 access fault. From Aligner to Decode
   output logic [1:0] ifu_i0_icaf_type, // Instruction 0 access fault type

   output logic  ifu_i0_valid,        // Instruction 0 valid. From Aligner to Decode
   output logic  ifu_i0_icaf_second,  // Instruction 0 has access fault on second 2B of 4B inst
   output logic  ifu_i0_dbecc,        // Instruction 0 has double bit ecc error
   output logic  iccm_dma_sb_error,   // Single Bit ECC error from a DMA access
   output logic[31:0] ifu_i0_instr,   // Instruction 0 . From Aligner to Decode
   output logic[31:1] ifu_i0_pc,      // Instruction 0 pc. From Aligner to Decode
   output logic ifu_i0_pc4,           // Instruction 0 is 4 byte. From Aligner to Decode

   output logic ifu_miss_state_idle,   // There is no outstanding miss. Cache miss state is idle.

   output el2_br_pkt_t i0_brp,           // Instruction 0 branch packet. From Aligner to Decode
   output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] ifu_i0_bp_index, // BP index
   output logic [pt.BHT_GHR_SIZE-1:0] ifu_i0_bp_fghr, // BP FGHR
   output logic [pt.BTB_BTAG_SIZE-1:0] ifu_i0_bp_btag, // BP tag
   output logic [$clog2(pt.BTB_SIZE)-1:0]         ifu_i0_fa_index,          // Fully associative btb index

   input el2_predict_pkt_t  exu_mp_pkt, // mispredict packet
   input logic [pt.BHT_GHR_SIZE-1:0] exu_mp_eghr, // execute ghr
   input logic [pt.BHT_GHR_SIZE-1:0]  exu_mp_fghr,                    // Mispredict fghr
   input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]  exu_mp_index,         // Mispredict index
   input logic [pt.BTB_BTAG_SIZE-1:0]  exu_mp_btag,                   // Mispredict btag

   input el2_br_tlu_pkt_t dec_tlu_br0_r_pkt, // slot0 update/error pkt
   input logic [pt.BHT_GHR_SIZE-1:0] exu_i0_br_fghr_r, // fghr to bp
   input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] exu_i0_br_index_r, // bp index
   input logic [$clog2(pt.BTB_SIZE)-1:0] dec_fa_error_index, // Fully associative btb error index

   input dec_tlu_flush_lower_wb,

   output logic [15:0] ifu_i0_cinst,

    output logic [31:1] ifu_pmp_addr,
    input  logic        ifu_pmp_error,

/// Icache debug
   input  el2_cache_debug_pkt_t        dec_tlu_ic_diag_pkt ,
   output logic                    ifu_ic_debug_rd_data_valid,
   output logic                                iccm_buf_correct_ecc,
   output logic                                iccm_correction_state,

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic scan_mode
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

### design/lsu/el2_lsu.sv

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

### design/include/el2_def.sv

```verilog
typedef struct packed {
                       logic  trace_rv_i_valid_ip;
                       logic [31:0] trace_rv_i_insn_ip;
                       logic [31:0] trace_rv_i_address_ip;
                       logic  trace_rv_i_exception_ip;
                       logic [4:0] trace_rv_i_ecause_ip;
                       logic  trace_rv_i_interrupt_ip;
                       logic [31:0] trace_rv_i_tval_ip;
                       } el2_trace_pkt_t;
// ...
  typedef enum logic [2:0] {
    NONE  = 3'b000,
    READ  = 3'b001,
    WRITE = 3'b010,
    EXEC  = 3'b100
  } el2_pmp_type_pkt_t;
```
