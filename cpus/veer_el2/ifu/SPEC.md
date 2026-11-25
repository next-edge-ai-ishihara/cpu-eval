# Implement `el2_ifu`

Implement the complete `el2_ifu` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module el2_ifu` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

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

## Parent instantiation

```verilog
   el2_ifu #(.pt(pt)) ifu (
                            .clk(active_l2clk),
                            .rst_l(core_rst_l),
                            .dec_tlu_flush_err_wb       (dec_tlu_flush_err_r      ),
                            .dec_tlu_flush_noredir_wb   (dec_tlu_flush_noredir_r  ),
                            .dec_tlu_fence_i_wb         (dec_tlu_fence_i_r        ),
                            .dec_tlu_flush_leak_one_wb  (dec_tlu_flush_leak_one_r ),
                            .dec_tlu_flush_lower_wb     (dec_tlu_flush_lower_r    ),

                            // AXI signals
                            .ifu_axi_arready(ifu_axi_arready_int),
                            .ifu_axi_rvalid(ifu_axi_rvalid_int),
                            .ifu_axi_rid(ifu_axi_rid_int[pt.IFU_BUS_TAG-1:0]),
                            .ifu_axi_rdata(ifu_axi_rdata_int[63:0]),
                            .ifu_axi_rresp(ifu_axi_rresp_int[1:0]),

                            .*
                            );

// ...

  assign pmp_chan_addr[0] = {ifu_pmp_addr, 1'b0};
  assign pmp_chan_type[0] = EXEC;
  assign ifu_pmp_error    = pmp_chan_err[0];

```

## Dependency declarations

### design/ifu/el2_ifu_aln_ctl.sv

```verilog
module el2_ifu_aln_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic                                    scan_mode,                // Flop scan mode control
   /*pragma coverage on*/
   input logic                                    rst_l,                    // reset, active low
   input logic                                    clk,                      // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic                                    active_clk,               // Clock only while core active.  Through two clock headers. For flops without second clock header built in.

   input logic                                    ifu_async_error_start,    // ecc/parity related errors with current fetch - not sent down the pipe

   input logic [1:0]                              iccm_rd_ecc_double_err,   // This fetch has a double ICCM ecc  error.

   input logic [1:0]                              ic_access_fault_f,        // Instruction access fault for the current fetch.
   input logic [1:0]                              ic_access_fault_type_f,   // Instruction access fault types

   input logic                                    exu_flush_final,          // Flush from the pipeline.

   input logic                                    dec_i0_decode_d,          // Valid instruction at D-stage and not blocked

   input logic [31:0]                             ifu_fetch_data_f,         // fetch data in memory format - not right justified

   input logic [1:0]                              ifu_fetch_val,            // valids on a 2B boundary, right justified
   input logic [31:1]                             ifu_fetch_pc,             // starting pc of fetch



   output logic                                   ifu_i0_valid,             // Instruction 0 is valid
   output logic                                   ifu_i0_icaf,              // Instruction 0 has access fault
   output logic [1:0]                             ifu_i0_icaf_type,         // Instruction 0 access fault type
   output logic                                   ifu_i0_icaf_second,       // Instruction 0 has access fault on second 2B of 4B inst

   output logic                                   ifu_i0_dbecc,             // Instruction 0 has double bit ecc error
   output logic [31:0]                            ifu_i0_instr,             // Instruction 0
   output logic [31:1]                            ifu_i0_pc,                // Instruction 0 PC
   output logic                                   ifu_i0_pc4,

   output logic                                   ifu_fb_consume1,          // Consumed one buffer. To fetch control fetch for buffer mass balance
   output logic                                   ifu_fb_consume2,          // Consumed two buffers.To fetch control fetch for buffer mass balance


   input logic [pt.BHT_GHR_SIZE-1:0]              ifu_bp_fghr_f,            // fetch GHR
   input logic [31:1]                             ifu_bp_btb_target_f,      // predicted RET target
   input logic [11:0]                             ifu_bp_poffset_f,         // predicted target offset
   input logic [1:0] [$clog2(pt.BTB_SIZE)-1:0]    ifu_bp_fa_index_f,        // predicted branch index (fully associative option)

   input logic [1:0]                              ifu_bp_hist0_f,           // history counters for all 4 potential branches, bit 1, right justified
   input logic [1:0]                              ifu_bp_hist1_f,           // history counters for all 4 potential branches, bit 1, right justified
   input logic [1:0]                              ifu_bp_pc4_f,             // pc4 indication, right justified
   input logic [1:0]                              ifu_bp_way_f,             // way indication, right justified
   input logic [1:0]                              ifu_bp_valid_f,           // branch valid, right justified
   input logic [1:0]                              ifu_bp_ret_f,             // predicted ret indication, right justified


   output el2_br_pkt_t                           i0_brp,                   // Branch packet for I0.
   output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]   ifu_i0_bp_index,          // BP index
   output logic [pt.BHT_GHR_SIZE-1:0]             ifu_i0_bp_fghr,           // BP FGHR
   output logic [pt.BTB_BTAG_SIZE-1:0]            ifu_i0_bp_btag,           // BP tag

   output logic [$clog2(pt.BTB_SIZE)-1:0]         ifu_i0_fa_index,          // Fully associative btb index

   output logic                                   ifu_pmu_instr_aligned,    // number of inst aligned this cycle

   output logic [15:0]                            ifu_i0_cinst              // 16b compress inst for i0
   );

```

### design/ifu/el2_ifu_bp_ctl.sv

```verilog
module el2_ifu_bp_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (

   input logic clk,
   input logic rst_l,

   input logic ic_hit_f,      // Icache hit, enables F address capture

   input logic [31:1] ifc_fetch_addr_f, // look up btb address
   input logic ifc_fetch_req_f,  // F1 valid

   input el2_br_tlu_pkt_t dec_tlu_br0_r_pkt, // BP commit update packet, includes errors
   input logic [pt.BHT_GHR_SIZE-1:0] exu_i0_br_fghr_r, // fghr to bp
   input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] exu_i0_br_index_r, // bp index

   input logic [$clog2(pt.BTB_SIZE)-1:0] dec_fa_error_index, // Fully associative btb error index

   input logic dec_tlu_flush_lower_wb, // used to move EX4 RS to EX1 and F
   input logic dec_tlu_flush_leak_one_wb, // don't hit for leak one fetches

   input logic dec_tlu_bpred_disable, // disable all branch prediction

   input el2_predict_pkt_t  exu_mp_pkt, // mispredict packet

   input logic [pt.BHT_GHR_SIZE-1:0] exu_mp_eghr, // execute ghr (for patching fghr)
   input logic [pt.BHT_GHR_SIZE-1:0]  exu_mp_fghr,                    // Mispredict fghr
   input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]  exu_mp_index,         // Mispredict index
   input logic [pt.BTB_BTAG_SIZE-1:0]  exu_mp_btag,                   // Mispredict btag

   input logic exu_flush_final, // all flushes

   output logic ifu_bp_hit_taken_f, // btb hit, select target
   output logic [31:1] ifu_bp_btb_target_f, //  predicted target PC
   output logic ifu_bp_inst_mask_f, // tell ic which valids to kill because of a taken branch, right justified

   output logic [pt.BHT_GHR_SIZE-1:0] ifu_bp_fghr_f, // fetch ghr

   output logic [1:0] ifu_bp_way_f, // way
   output logic [1:0] ifu_bp_ret_f, // predicted ret
   output logic [1:0] ifu_bp_hist1_f, // history counters for all 4 potential branches, bit 1, right justified
   output logic [1:0] ifu_bp_hist0_f, // history counters for all 4 potential branches, bit 0, right justified
   output logic [1:0] ifu_bp_pc4_f, // pc4 indication, right justified
   output logic [1:0] ifu_bp_valid_f, // branch valid, right justified
   output logic [11:0] ifu_bp_poffset_f, // predicted target

   output logic [1:0] [$clog2(pt.BTB_SIZE)-1:0]    ifu_bp_fa_index_f, // predicted branch index (fully associative option)

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic       scan_mode
   /*pragma coverage on*/
   );

```

### design/ifu/el2_ifu_ifc_ctl.sv

```verilog
module el2_ifu_ifc_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic clk,                         // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic free_l2clk,                  // Clock always.                  Through one clock header.  For flops with    second header built in.

   input logic rst_l, // reset enable, from core pin
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic scan_mode, // scan
   /*pragma coverage on*/

   input logic ic_hit_f,      // Icache hit
   input logic ifu_ic_mb_empty, // Miss buffer empty

   input logic ifu_fb_consume1,  // Aligner consumed 1 fetch buffer
   input logic ifu_fb_consume2,  // Aligner consumed 2 fetch buffers

   input logic dec_tlu_flush_noredir_wb, // Don't fetch on flush
   input logic exu_flush_final, // FLush
   input logic [31:1] exu_flush_path_final, // Flush path

   input logic ifu_bp_hit_taken_f, // btb hit, select the target path
   input logic [31:1] ifu_bp_btb_target_f, //  predicted target PC

   input logic ic_dma_active, // IC DMA active, stop fetching
   input logic ic_write_stall, // IC is writing, stop fetching
   input logic dma_iccm_stall_any, // force a stall in the fetch pipe for DMA ICCM access

   input logic [31:0]  dec_tlu_mrac_ff ,   // side_effect and cacheable for each region

   output logic [31:1] ifc_fetch_addr_f, // fetch addr F
   output logic [31:1] ifc_fetch_addr_bf, // fetch addr BF

   output logic  ifc_fetch_req_f,  // fetch request valid F

   output logic  ifu_pmu_fetch_stall, // pmu event measuring fetch stall

   output logic                       ifc_fetch_uncacheable_bf,      // The fetch request is uncacheable space. BF stage
   output logic                      ifc_fetch_req_bf,              // Fetch request. Comes with the address.  BF stage
   output logic                       ifc_fetch_req_bf_raw,          // Fetch request without some qualifications. Used for clock-gating. BF stage
   output logic                       ifc_iccm_access_bf,            // This request is to the ICCM. Do not generate misses to the bus.
   output logic                       ifc_region_acc_fault_bf,       // Access fault. in ICCM region but offset is outside defined ICCM.

   output logic  ifc_dma_access_ok // fetch is not accessing the ICCM, DMA can proceed


   );

```

### design/ifu/el2_ifu_mem_ctl.sv

```verilog
module el2_ifu_mem_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic clk,                                                 // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic active_clk,                                          // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
   input logic free_l2clk,                                          // Clock always.                  Through one clock header.  For flops with    second header built in.
   input logic rst_l,                                               // reset, active low

   input logic                       exu_flush_final,               // Flush from the pipeline., includes flush lower
   input logic                       dec_tlu_flush_lower_wb,        // Flush lower from the pipeline.
   input logic                       dec_tlu_flush_err_wb,          // Flush from the pipeline due to perr.
   input logic                       dec_tlu_i0_commit_cmt,         // committed i0 instruction
   input logic                       dec_tlu_force_halt,            // force halt.

   input logic [31:1]                ifc_fetch_addr_bf,             // Fetch Address byte aligned always.      F1 stage.
   input logic                       ifc_fetch_uncacheable_bf,      // The fetch request is uncacheable space. F1 stage
   input logic                       ifc_fetch_req_bf,              // Fetch request. Comes with the address.  F1 stage
   input logic                       ifc_fetch_req_bf_raw,          // Fetch request without some qualifications. Used for clock-gating. F1 stage
   input logic                       ifc_iccm_access_bf,            // This request is to the ICCM. Do not generate misses to the bus.
   input logic                       ifc_region_acc_fault_bf,       // Access fault. in ICCM region but offset is outside defined ICCM.
   input logic                       ifc_dma_access_ok,             // It is OK to give dma access to the ICCM. (ICCM is not busy this cycle).
   input logic                       dec_tlu_fence_i_wb,            // Fence.i instruction is committing. Clear all Icache valids.
   input logic                       ifu_bp_hit_taken_f,            // Branch is predicted taken. Kill the fetch next cycle.

   input logic                       ifu_bp_inst_mask_f,            // tell ic which valids to kill because of a taken branch, right justified

   output logic                      ifu_miss_state_idle,           // No icache misses are outstanding.
   output logic                      ifu_ic_mb_empty,               // Continue with normal fetching. This does not mean that miss is finished.
   output logic                      ic_dma_active  ,               // In the middle of servicing dma request to ICCM. Do not make any new requests.
   output logic                      ic_write_stall,                // Stall fetch the cycle we are writing the cache.

/// PMU signals
   output logic                      ifu_pmu_ic_miss,               // IC miss event
   output logic                      ifu_pmu_ic_hit,                // IC hit event
   output logic                      ifu_pmu_bus_error,             // Bus error event
   output logic                      ifu_pmu_bus_busy,              // Bus busy event
   output logic                      ifu_pmu_bus_trxn,              // Bus transaction

  //-------------------------- IFU AXI signals--------------------------
   // AXI Write Channels
   /* exclude signals that are tied to constant value in this file */
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
   /* exclude signals that are tied to constant value in this file */
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
   /* exclude signals that are tied to constant value in this file */
   /*pragma coverage off*/
   output logic                            ifu_axi_rready,
   /*pragma coverage on*/
   input  logic [pt.IFU_BUS_TAG-1:0]       ifu_axi_rid,
   input  logic [63:0]                     ifu_axi_rdata,
   input  logic [1:0]                      ifu_axi_rresp,

    input  logic                     ifu_bus_clk_en,


   input  logic                      dma_iccm_req,      //  dma iccm command (read or write)
   input  logic [31:0]               dma_mem_addr,      //  dma address
   input  logic [2:0]                dma_mem_sz,        //  size
   input  logic                      dma_mem_write,     //  write
   input  logic [63:0]               dma_mem_wdata,     //  write data
   input  logic [2:0]                dma_mem_tag,       //  DMA Buffer entry number

   output logic                      iccm_dma_ecc_error,//   Data read from iccm has an ecc error
   output logic                      iccm_dma_rvalid,   //   Data read from iccm is valid
   output logic [63:0]               iccm_dma_rdata,    //   dma data read from iccm
   output logic [2:0]                iccm_dma_rtag,     //   Tag of the DMA req
   output logic                      iccm_ready,        //   iccm ready to accept new command.


//   I$ & ITAG Ports
   output logic [31:1]               ic_rw_addr,         // Read/Write address to the Icache.
   output logic [pt.ICACHE_NUM_WAYS-1:0]                ic_wr_en,           // Icache write enable, when filling the Icache.
   output logic                      ic_rd_en,           // Icache read  enable.

   output logic [pt.ICACHE_BANKS_WAY-1:0] [70:0]               ic_wr_data,           // Data to fill to the Icache. With ECC
   input  logic [141:0]              ic_rd_data ,              // Raw way-muxed 142-bit ECC-protected word pair. F2 stage.
   input  logic [1:0]                ic_rd_addr_lo,            // F2-aligned ic_rw_addr_ff[2:1] for core-side rotate
   input  logic [pt.ICACHE_BANKS_WAY-1:0] ic_rd_bank_check_en, // Per-bank ECC check enable for core-side decode
   input  logic [70:0]               ic_debug_rd_data ,          // Data read from Icache. 2x64bits + parity bits. F2 stage. With ECC
   input  logic [25:0]               ictag_debug_rd_data,  // Debug icache tag.
   output logic [70:0]               ic_debug_wr_data,     // Debug wr cache.
   output logic [70:0]               ifu_ic_debug_rd_data, // debug data read


   output logic [pt.ICACHE_INDEX_HI:3]               ic_debug_addr,      // Read/Write address to the Icache.
   output logic                      ic_debug_rd_en,     // Icache debug rd
   output logic                      ic_debug_wr_en,     // Icache debug wr
   output logic                      ic_debug_tag_array, // Debug tag array
   output logic [pt.ICACHE_NUM_WAYS-1:0]                ic_debug_way,       // Debug way. Rd or Wr.


   output logic [pt.ICACHE_NUM_WAYS-1:0]                ic_tag_valid,       // Valid bits when accessing the Icache. One valid bit per way. F2 stage

   input  logic [pt.ICACHE_NUM_WAYS-1:0]                ic_rd_hit,          // Compare hits from Icache tags. Per way.  F2 stage
   input  logic                      ic_tag_perr,        // Icache Tag parity error

   // ICCM ports
   output logic [pt.ICCM_BITS-1:1]  iccm_rw_addr,       // ICCM read/write address.
   output logic                      iccm_wren,          // ICCM write enable (through the DMA)
   output logic                      iccm_rden,          // ICCM read enable.
   output logic [77:0]               iccm_wr_data,       // ICCM write data.
   output logic [2:0]                iccm_wr_size,       // ICCM write location within DW.

   input  logic [77:0]               iccm_rd_data_ecc,   // Data + ECC read from ICCM.
   input  logic [1:0]                ifu_fetch_val,
   // IFU control signals
   output logic                      ic_hit_f,               // Hit in Icache(if Icache access) or ICCM access( ICCM always has ic_hit_f)
   output logic [1:0]                ic_access_fault_f,      // Access fault (bus error or ICCM access in region but out of offset range).
   output logic [1:0]                ic_access_fault_type_f, // Access fault types
   output logic                      iccm_rd_ecc_single_err, // This fetch has a single ICCM ECC error.
   output logic [1:0]                iccm_rd_ecc_double_err, // This fetch has a double ICCM ECC error.
   output logic                      iccm_dma_rd_ecc_single_err, // This fetch has a single ICCM DMA ECC error.
   output logic                      iccm_dma_rd_ecc_double_err, // This fetch has a double ICCM DMA ECC error.
   output logic                      ic_error_start,         // This has any I$ errors ( data/tag/ecc/parity )

   output logic                      ifu_async_error_start,  // Or of the sb iccm, and all the icache errors sent to aligner to stop
   output logic                      iccm_dma_sb_error,      // Single Bit ECC error from a DMA access
   output logic [1:0]                ic_fetch_val_f,         // valid bytes for fetch. To the Aligner.
   output logic [31:0]               ic_data_f,              // Data read from Icache or ICCM. To the Aligner.

/////  Debug
   input  el2_cache_debug_pkt_t     dec_tlu_ic_diag_pkt ,       // Icache/tag debug read/write packet
   input  logic                      dec_tlu_core_ecc_disable,   // disable the ecc checking and flagging
   output logic                      ifu_ic_debug_rd_data_valid, // debug data valid.
   output logic                      iccm_buf_correct_ecc,
   output logic                      iccm_correction_state,

   input  logic                      ifu_pmp_error,


   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic         scan_mode
   /*pragma coverage on*/
   );

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

### design/lib/el2_lib.sv

```verilog
module el2_btb_addr_hash
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
                        input logic [pt.BTB_INDEX3_HI:pt.BTB_INDEX1_LO] pc,
                        output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] hash
                        );

```

## Related source code

### design/ifu/el2_ifu_mem_ctl.sv

```verilog
// memory protection  - equation to look identical to the LSU equation
   if (pt.PMP_ENTRIES != 0) begin : g_ifc_access_check_pmp
      assign ifc_region_acc_okay = ~ifu_pmp_error;
      assign ifc_region_acc_fault_memory_bf = ~ifc_region_acc_okay & ifc_fetch_req_bf;
   end

```
