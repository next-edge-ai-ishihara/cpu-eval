# Implement `el2_veer_wrapper`

Implement the complete `el2_veer_wrapper` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_veer_wrapper` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
my $ahb = 0;
my $axi = 1;
...
my $lockstep_enable=0;
my $lockstep_regfile_enable=0;
```

## Module declaration

```verilog
module el2_veer_wrapper
import el2_pkg::*;
 #(
`include "el2_param.vh"
)
(
   input logic                             clk,
   input logic                             rst_l,
   input logic                             dbg_rst_l,
   // rst_vec is supposed to be tied to constant in the top level
   /*pragma coverage off*/
   input logic [31:1]                      rst_vec,
   /*pragma coverage on*/
   input logic                             nmi_int,
   // jtag_id and nmi_vec are supposed to be tied to constants in the top level
   /*pragma coverage off*/
   input logic [31:1]                      nmi_vec,
   input logic [31:1]                      jtag_id,
   /*pragma coverage on*/


   output logic [31:0]                     trace_rv_i_insn_ip,
   output logic [31:0]                     trace_rv_i_address_ip,
   output logic                            trace_rv_i_valid_ip,
   output logic                            trace_rv_i_exception_ip,
   output logic [4:0]                      trace_rv_i_ecause_ip,
   output logic                            trace_rv_i_interrupt_ip,
   output logic [31:0]                     trace_rv_i_tval_ip,

   // Bus signals
`ifdef RV_BUILD_AXI4
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
   input  logic                            dma_axi_awvalid,
   output logic                            dma_axi_awready,
   /* exclude signals that are tied to constant value in tb_top.sv */
   /*pragma coverage off*/
   input  logic [pt.DMA_BUS_TAG-1:0]       dma_axi_awid,
   /*pragma coverage on*/
   input  logic [31:0]                     dma_axi_awaddr,
   input  logic [2:0]                      dma_axi_awsize,
   input  logic [2:0]                      dma_axi_awprot,
   input  logic [7:0]                      dma_axi_awlen,
   input  logic [1:0]                      dma_axi_awburst,


   input  logic                            dma_axi_wvalid,
   output logic                            dma_axi_wready,
   input  logic [63:0]                     dma_axi_wdata,
   input  logic [7:0]                      dma_axi_wstrb,
   input  logic                            dma_axi_wlast,

   output logic                            dma_axi_bvalid,
   input  logic                            dma_axi_bready,
   output logic [1:0]                      dma_axi_bresp,
   output logic [pt.DMA_BUS_TAG-1:0]       dma_axi_bid,

   // AXI Read Channels
   input  logic                            dma_axi_arvalid,
   output logic                            dma_axi_arready,
   /* exclude signals that are tied to constant value in tb_top.sv */
   /*pragma coverage off*/
   input  logic [pt.DMA_BUS_TAG-1:0]       dma_axi_arid,
   /*pragma coverage on*/
   input  logic [31:0]                     dma_axi_araddr,
   input  logic [2:0]                      dma_axi_arsize,
   input  logic [2:0]                      dma_axi_arprot,
   input  logic [7:0]                      dma_axi_arlen,
   input  logic [1:0]                      dma_axi_arburst,

   output logic                            dma_axi_rvalid,
   input  logic                            dma_axi_rready,
   output logic [pt.DMA_BUS_TAG-1:0]       dma_axi_rid,
   output logic [63:0]                     dma_axi_rdata,
   output logic [1:0]                      dma_axi_rresp,
   output logic                            dma_axi_rlast,
`endif

`ifdef RV_BUILD_AHB_LITE
 //// AHB LITE BUS
   output logic [31:0]                     haddr,
   /* exclude signals that are tied to constant value in axi4_to_ahb.sv */
   /*pragma coverage off*/
   output logic [2:0]                      hburst,
   output logic                            hmastlock,
   /*pragma coverage on*/
   output logic [3:0]                      hprot,
   output logic [2:0]                      hsize,
   output logic [1:0]                      htrans,
   output logic                            hwrite,

   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   input logic [63:0]                      hrdata,
   input logic                             hready,
   input logic                             hresp,
   /*pragma coverage on*/

   // LSU AHB Master
   output logic [31:0]                     lsu_haddr,
   /* exclude signals that are tied to constant value in axi4_to_ahb.sv */
   /*pragma coverage off*/
   output logic [2:0]                      lsu_hburst,
   output logic                            lsu_hmastlock,
   /*pragma coverage on*/
   output logic [3:0]                      lsu_hprot,
   output logic [2:0]                      lsu_hsize,
   output logic [1:0]                      lsu_htrans,
   output logic                            lsu_hwrite,
   output logic [63:0]                     lsu_hwdata,

   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   input logic [63:0]                      lsu_hrdata,
   input logic                             lsu_hready,
   input logic                             lsu_hresp,
   /*pragma coverage on*/
   // Debug System Bus AHB
   output logic [31:0]                     sb_haddr,
   /* exclude signals that are tied to constant value in axi4_to_ahb.sv */
   /*pragma coverage off*/
   output logic [2:0]                      sb_hburst,
   output logic                            sb_hmastlock,
   /*pragma coverage on*/
   output logic [3:0]                      sb_hprot,
   output logic [2:0]                      sb_hsize,
   output logic [1:0]                      sb_htrans,
   output logic                            sb_hwrite,
   output logic [63:0]                     sb_hwdata,

   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   input  logic [63:0]                     sb_hrdata,
   input  logic                            sb_hready,
   input  logic                            sb_hresp,
   /*pragma coverage on*/

   // DMA Slave
   /* exclude signals that are tied to constant value in tb_top.sv */
   /*pragma coverage off*/
   input logic                             dma_hsel,
   input logic [31:0]                      dma_haddr,
   input logic [2:0]                       dma_hburst,
   input logic                             dma_hmastlock,
   input logic [3:0]                       dma_hprot,
   input logic [2:0]                       dma_hsize,
   input logic [1:0]                       dma_htrans,
   input logic                             dma_hwrite,
   input logic [63:0]                      dma_hwdata,
   /*pragma coverage on*/
   input logic                             dma_hreadyin,

   output logic [63:0]                     dma_hrdata,
   output logic                            dma_hreadyout,
   output logic                            dma_hresp,
`endif
   // clk ratio signals
   input logic                             lsu_bus_clk_en, // Clock ratio b/w cpu core clk & AHB master interface
   input logic                             ifu_bus_clk_en, // Clock ratio b/w cpu core clk & AHB master interface
   input logic                             dbg_bus_clk_en, // Clock ratio b/w cpu core clk & AHB master interface
   input logic                             dma_bus_clk_en, // Clock ratio b/w cpu core clk & AHB slave interface

   // ICCM/DCCM ECC status
   output logic                            iccm_ecc_single_error,
   output logic                            iccm_ecc_double_error,
   output logic                            dccm_ecc_single_error,
   output logic                            dccm_ecc_double_error,
   output logic                            dccm_write_readback_error,

   // ICache export interface
   el2_mem_if.veer_icache_src              el2_icache_export,

   input logic                             timer_int,
   input logic                             soft_int,
   input logic [pt.PIC_TOTAL_INT:1]        extintsrc_req,

   output logic                            dec_tlu_perfcnt0, // toggles when slot0 perf counter 0 has an event inc
   output logic                            dec_tlu_perfcnt1,
   output logic                            dec_tlu_perfcnt2,
   output logic                            dec_tlu_perfcnt3,

   // ports added by the soc team
   input logic                             jtag_tck,    // JTAG clk
   input logic                             jtag_tms,    // JTAG TMS
   input logic                             jtag_tdi,    // JTAG tdi
   input logic                             jtag_trst_n, // JTAG Reset
   output logic                            jtag_tdo,    // JTAG TDO
   output logic                            jtag_tdoEn,  // JTAG Test Data Output enable

   /*pragma coverage off*/
   input logic [31:4] core_id,
   /*pragma coverage on*/

   // Memory Export Interface
   el2_mem_if.veer_sram_src                el2_mem_export,

`ifdef RV_LOCKSTEP_ENABLE
   // Shadow Core trace
   output logic [31:0] shadow_core_trace_rv_i_insn_ip,
   output logic [31:0] shadow_core_trace_rv_i_address_ip,
   output logic shadow_core_trace_rv_i_valid_ip,
   output logic shadow_core_trace_rv_i_exception_ip,
   output logic [4:0] shadow_core_trace_rv_i_ecause_ip,
   output logic shadow_core_trace_rv_i_interrupt_ip,
   output logic [31:0] shadow_core_trace_rv_i_tval_ip,

   // Shadow Core control
   input el2_mubi_pkg::el2_mubi_t disable_corruption_detection_i,
   input el2_mubi_pkg::el2_mubi_t lockstep_err_injection_en_i,
   output el2_mubi_pkg::el2_mubi_t corruption_detected_o,
`endif

   // external MPC halt/run interface
   input logic                             mpc_debug_halt_req, // Async halt request
   input logic                             mpc_debug_run_req,  // Async run request
   input logic                             mpc_reset_run_req,  // Run/halt after reset
   output logic                            mpc_debug_halt_ack, // Halt ack
   output logic                            mpc_debug_run_ack,  // Run ack
   output logic                            debug_brkpt_status, // debug breakpoint

   input logic                             i_cpu_halt_req,      // Async halt req to CPU
   output logic                            o_cpu_halt_ack,      // core response to halt
   output logic                            o_cpu_halt_status,   // 1'b1 indicates core is halted
   output logic                            o_debug_mode_status, // Core to the PMU that core is in debug mode. When core is in debug mode, the PMU should refrain from sendng a halt or run request
   input logic                             i_cpu_run_req, // Async restart req to CPU
   output logic                            o_cpu_run_ack, // Core response to run req

   // Excluding scan_mode and mbist_mode from coverage as their usage is determined by the integrator of the VeeR core.
   /* pragma coverage off */
   input logic                             scan_mode,     // To enable scan mode
   input logic                             mbist_mode,    // to enable mbist

   // DMI port for uncore
   input logic                             dmi_core_enable,
   input logic                             dmi_uncore_enable,
   output logic                            dmi_uncore_en,
   output logic                            dmi_uncore_wr_en,
   output logic                     [ 6:0] dmi_uncore_addr,
   output logic                     [31:0] dmi_uncore_wdata,
   input logic                      [31:0] dmi_uncore_rdata,
   output logic                            dmi_active
   /* pragma coverage on */
);
```

## Dependency declarations

### design/el2_mem.sv

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

### design/el2_veer.sv

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

### design/dmi/dmi_wrapper.v

```verilog
module dmi_wrapper(

  // JTAG signals
  input              trst_n,              // JTAG reset
  input              tck,                 // JTAG clock
  input              tms,                 // Test mode select
  input              tdi,                 // Test Data Input
  output             tdo,                 // Test Data Output
  output             tdoEnable,           // Test Data Output enable

  // Processor Signals
  input              core_rst_n,          // Core reset
  input              core_clk,            // Core clock
  //jtag_id is supposed to be connected to a constant in the top level
  /* pragma coverage off*/
  input [31:1]       jtag_id,             // JTAG ID
  /* pragma coverage on*/
  input [31:0]       rd_data,             // 32 bit Read data from  Processor
  output [31:0]      reg_wr_data,         // 32 bit Write data to Processor
  output [6:0]       reg_wr_addr,         // 7 bit reg address to Processor
  output             reg_en,              // 1 bit  Read enable to Processor
  output             reg_wr_en,           // 1 bit  Write enable to Processor
  output             dmi_hard_reset
);
```

### design/dmi/dmi_mux.v

```verilog
module dmi_mux (

    // Core access enable
    input wire core_enable,
    // Uncore access enable
    input wire uncore_enable,

    // DMI upstream
    input  wire        dmi_en,
    input  wire        dmi_wr_en,
    input  wire [ 6:0] dmi_addr,
    input  wire [31:0] dmi_wdata,
    output wire [31:0] dmi_rdata,

    // DMI downstream for core
    output wire        dmi_core_en,
    output wire        dmi_core_wr_en,
    output wire [ 6:0] dmi_core_addr,
    output wire [31:0] dmi_core_wdata,
    input  wire [31:0] dmi_core_rdata,

    // DMI downstream for uncore
    output wire        dmi_uncore_en,
    output wire        dmi_uncore_wr_en,
    output wire [ 6:0] dmi_uncore_addr,
    output wire [31:0] dmi_uncore_wdata,
    input  wire [31:0] dmi_uncore_rdata
);
```

## Additional requirement

Drive `dmi_active` high in each cycle in which a DMI register access is requested and low otherwise.
