# Implement `el2_ifu_mem_ctl`

Implement the complete `el2_ifu_mem_ctl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_ifu_mem_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
$iccm_enable=1;
$iccm_region="0xe";
$top_align_iccm = 1;
$iccm_offset="0xe000000"; #0x380*256*1024
$iccm_size=64;
$iccm_num_banks=4;
$iccm_addr_xor=0;
$iccm_ecc_width=7;
$icache_enable=1;
$icache_waypack=1;
$icache_addr_xor=0;
$icache_num_ways=2;
$icache_banks_way=2;
$icache_2banks=1;
$icache_bank_width=8;
$icache_ln_sz=64;
$icache_ecc=1;
$icache_size=16;

```

## Package and imports

### configs/veer.config

```perl
# These parms are used in the Verilog and will be part of global parm structure
# need to have this be width in binary
# for now autosize to the data
our %verilog_parms = (
        "user_mode" => '1',

        "lsu2dma"                 => '1',
        "timer_legal_en"          => '1',
        "bitmanip_zbb"            => '1',
        "bitmanip_zbs"            => '1',
        "bitmanip_zba"            => '1',
        "bitmanip_zbc"            => '1',
        "bitmanip_zbe"            => '1',
        "bitmanip_zbf"            => '1',
        "bitmanip_zbp"            => '1',
        "bitmanip_zbr"            => '1',
        "fast_interrupt_redirect" => '1',

        "pmp_entries"         => '7',
        "smepmp"              => '1',
        "lockstep_enable"     => '1',
        "lockstep_regfile_enable" => '1',
        "lockstep_delay"      => '3',
        "mubi_width"          => "6",
        "mubi_true"           => "32",
        "mubi_false"          => "32",
        "inst_access_enable0" => '1',
        "inst_access_addr0"   => '32',
        "inst_access_mask0"   => '32',
        "inst_access_enable1" => '1',
        "inst_access_addr1"   => '32',
        "inst_access_mask1"   => '32',
        "inst_access_enable2" => '1',
        "inst_access_addr2"   => '32',
        "inst_access_mask2"   => '32',
        "inst_access_enable3" => '1',
        "inst_access_addr3"   => '32',
        "inst_access_mask3"   => '32',
        "inst_access_enable4" => '1',
        "inst_access_addr4"   => '32',
        "inst_access_mask4"   => '32',
        "inst_access_enable5" => '1',
        "inst_access_addr5"   => '32',
        "inst_access_mask5"   => '32',
        "inst_access_enable6" => '1',
        "inst_access_addr6"   => '32',
        "inst_access_mask6"   => '32',
        "inst_access_enable7" => '1',
        "inst_access_addr7"   => '32',
        "inst_access_mask7"   => '32',
        "data_access_enable0" => '1',
        "data_access_addr0"   => '32',
        "data_access_mask0"   => '32',
        "data_access_enable1" => '1',
        "data_access_addr1"   => '32',
        "data_access_mask1"   => '32',
        "data_access_enable2" => '1',
        "data_access_addr2"   => '32',
        "data_access_mask2"   => '32',
        "data_access_enable3" => '1',
        "data_access_addr3"   => '32',
        "data_access_mask3"   => '32',
        "data_access_enable4" => '1',
        "data_access_addr4"   => '32',
        "data_access_mask4"   => '32',
        "data_access_enable5" => '1',
        "data_access_addr5"   => '32',
        "data_access_mask5"   => '32',
        "data_access_enable6" => '1',
        "data_access_addr6"   => '32',
        "data_access_mask6"   => '32',
        "data_access_enable7" => '1',
        "data_access_addr7"   => '32',
        "data_access_mask7"   => '32',
        "iccm_bits"              => '5',
        "iccm_bank_hi"           => '5',
        "iccm_bank_index_lo"     => '5',
        "icache_bank_bits"       => '3',
        "icache_status_bits"     => '3',
        "icache_num_beats"       => '4',
        "icache_beat_bits"       => '4',
        "icache_scnd_last"       => '4',
        "icache_beat_addr_hi"    => '4',
        "icache_bypass_enable"   => '1',
        "icache_num_bypass"      => '4',
        "icache_num_bypass_width"    => '4',
        "icache_tag_bypass_enable"   => '1',
        "icache_tag_num_bypass"      => '4',
        "icache_tag_num_bypass_width"    => '4',
        "iccm_icache"        => '1',
        "iccm_only"          => '1',
        "icache_only"        => '1',
        "no_iccm_no_icache"  => '1',
         "build_axi4" => '1',
         "build_ahb_lite" => '1',
         "build_axi_native" => '1',
         "lsu_num_nbload_width" => '3',
         "lsu_num_nbload"    => '5',
         "ret_stack_size"   => '4',
         "btb_fullya"       => '1',
         "btb_toffset_size" => '5',
         "btb_enable"       => '1',
         "btb_size"         => '10',
         "btb_index1_hi"    => '5',
         "btb_index1_lo"    => '5',
         "btb_index2_hi"    => '5',
         "btb_index2_lo"    => '5',
         "btb_index3_hi"    => '5',
         "btb_index3_lo"    => '5',
         "btb_addr_hi"      => '5',
         "btb_array_depth"  => '9',
         "btb_addr_lo"      => '2',
         "btb_btag_size"    => '5',
         "btb_btag_fold"    => '1',
         "btb_fold2_index_hash" => '1',
         "bht_size"         => '12',
         "bht_addr_hi"      => '4',
         "bht_addr_lo"      => '2',
         "bht_array_depth"  => '11',
         "bht_ghr_size"     => '4',
         "bht_ghr_hash_1"   => '1',
        "div_bit"                 => '3',
        "div_new"                 => '1',
        "lsu_stbuf_depth"   => '4',
        "dma_buf_depth"     => '3',
        "load_to_use_plus1"        => '1',
        "dccm_enable"       => '1',
        "dccm_region"       => '4',
        "dccm_size"         => '10',
        "dccm_num_banks"    => '5',
        "dccm_sadr"         => '32',
        "dccm_bits"         => '5',
        "dccm_bank_bits"    => '3',
        "dccm_data_width"   => '6',
        "dccm_fdata_width"  => '6',
        "dccm_byte_width"   => '3',
        "dccm_width_bits"   => '2',
        "dccm_index_bits"   => '4',
        "dccm_ecc_width"    => '3',
        "lsu_sb_bits"       => '5',
        "iccm_enable"       => '1',
        "iccm_region"       => '4',
        "iccm_size"         => '10',
        "iccm_num_banks"    => '5',
        "iccm_bank_bits"    => '3',
        "iccm_index_bits"   => '4',
        "iccm_sadr"         => '32',
        "iccm_ecc_width"    => '3',
        "icache_enable"     => '1',
        "icache_waypack"    => '1',
        "icache_num_ways"   => '3',
        "icache_banks_way"  => '3',
        "icache_bank_width" => '4',
        "icache_ln_sz"      => '7',
        "icache_size"       => '9',
        "icache_bank_hi"    => '3',
        "icache_bank_lo"    => '2',
        "icache_tag_depth"  => '13',
        "icache_data_depth"      => '14',
        "icache_tag_lo"          => '5',
        "icache_index_hi"        => '5',
        "icache_data_index_lo"   => '3',
        "icache_data_width"      => '7',
        "icache_fdata_width"     => '7',
        "icache_tag_index_lo"    => '3',
        "icache_ecc"             => '1',
        "icache_2banks"          => '1',
        "pic_2cycle"         => '1',
        "pic_region"         => '4',
        "pic_size"           => '9',
        "pic_base_addr"      => '32',
        "pic_total_int_plus1"  => '9',
        "pic_total_int"      => '8',
        "pic_int_words"      => '4',
        "pic_bits"           => '5',
        "lsu_bus_tag"      => '4',
        "lsu_bus_id"       => '1',
        "lsu_bus_prty"     => '2',
        "dma_bus_tag"      => '4',
        "dma_bus_id"       => '5',
        "dma_bus_prty"     => '2',
        "sb_bus_tag"       => '4',
        "sb_bus_id"        => '1',
        "sb_bus_prty"      => '2',
        "ifu_bus_tag"      => '4',
        "ifu_bus_id"       => '1',
        "ifu_bus_prty"     => '2',
        "bus_prty_default" => '2',
);

...
sub dump_parms {#{{{
    my ($hash) = @_;

    my ($bvalue, $blen, $upper);
    printf(FILE1 "typedef struct packed {\n");
    foreach my $key (sort keys %$hash) {
        $bvalue=$hash->{$key};
        $blen=length($bvalue);
        $upper=$key;
        $upper=~ tr/a-z/A-Z/;
        if ($blen==1) {
            printf(FILE1 "\tlogic %-10s $upper;\n");
        }
        else {
            printf(FILE1 "\tlogic %-10s $upper;\n",sprintf("[%d:0]",$blen-1));
        }
    }
   printf(FILE1 "} el2_param_t;\n\n");

```

## Module declaration

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

## Parent instantiation

```verilog
   el2_ifu_mem_ctl #(.pt(pt)) mem_ctl
     (.*,
      .ic_data_f(ic_data_f[31:0])
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

### `rvdffs`

```verilog
module rvdffs #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic                   rst_l,
     output logic [WIDTH-1:0] dout
     );

```

### `rvdff_fpga`

```verilog
module rvdff_fpga #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic           clken,
     input logic           rawclk,
     input logic           rst_l,

     output logic [WIDTH-1:0] dout
     );

```

### `rvdffs_fpga`

```verilog
module rvdffs_fpga #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic           clken,
     input logic           rawclk,
     input logic           rst_l,

     output logic [WIDTH-1:0] dout
     );

```

### `rvdffe`

```verilog
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

### `rvdffpcie`

```verilog
module rvdffpcie #( parameter WIDTH=31 )
   (
     input  logic [WIDTH-1:0] din,
     input  logic             clk,
     input  logic             rst_l,
     input  logic             en,
     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
     /*pragma coverage off*/
     input  logic             scan_mode,
     /*pragma coverage on*/
     output logic [WIDTH-1:0] dout
     );

// ...
`ifndef RV_PHYSICAL
   if (WIDTH == 31) begin: genblock
`endif

// ...
`ifndef RV_PHYSICAL
   end
   else
      $error("%m: rvdffpcie width must be 31");
`endif

```

### `rvdfflie`

```verilog
module rvdfflie #( parameter WIDTH=16, LEFT=8 )
   (
     input  logic [WIDTH-1:0] din,
     input  logic             clk,
     input  logic             rst_l,
     input  logic             en,
     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
     /*pragma coverage off*/
     input  logic             scan_mode,
     /*pragma coverage on*/
     output logic [WIDTH-1:0] dout
     );

   localparam EXTRA = WIDTH-LEFT;

// ...
`ifndef RV_PHYSICAL
   if (WIDTH >= 16 && LEFT >= 8 && EXTRA >= 8) begin: genblock
`endif

// ...
`ifndef RV_PHYSICAL
   end
   else
      $error("%m: rvdfflie musb be WIDTH >= 16 && LEFT >= 8 && EXTRA >= 8");
`endif

```

### `rvdffie`

```verilog
module rvdffie #( parameter WIDTH=1, OVERRIDE=0 )
   (
     input  logic [WIDTH-1:0] din,

     input  logic           clk,
     input  logic           rst_l,
     // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
     /*pragma coverage off*/
     input  logic             scan_mode,
     /*pragma coverage on*/
     output logic [WIDTH-1:0] dout
     );

// ...
`ifndef RV_PHYSICAL
   if (WIDTH >= 8 || OVERRIDE==1) begin: genblock
`endif

// ...
`ifndef RV_PHYSICAL
   end
   else
     $error("%m: rvdffie must be WIDTH >= 8");
`endif

```

### `rvecc_encode`

```verilog
module rvecc_encode  (
                      input [31:0] din,
                      output [6:0] ecc_out
                      );

```

### `rvecc_decode`

```verilog
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

### `rvecc_encode_64`

```verilog
module rvecc_encode_64  (
                      input [63:0] din,
                      output [6:0] ecc_out
                      );

```

### `rvecc_decode_64`

```verilog
module rvecc_decode_64  (
                      input         en,
                      input [63:0]  din,
                      input [6:0]   ecc_in,
                      output        ecc_error
                      );

```

### `rvclkhdr`

```verilog
module rvclkhdr
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

### design/include/el2_def.sv

```verilog
typedef struct packed {
                        logic [70:0]  icache_wrdata; // {dicad1[1:0], dicad0h[31:0], dicad0[31:0]}
                        logic [16:0]  icache_dicawics; // Arraysel:24, Waysel:21:20, Index:16:3
                        logic         icache_rd_valid;
                        logic         icache_wr_valid;
            } el2_cache_debug_pkt_t;

```

## Related source code

### design/ifu/el2_ifu.sv

```verilog
   logic [1:0]   ifu_fetch_val;  // valids on a 2B boundary, left justified [7] implies valid fetch

// ...
   logic [1:0]   ic_fetch_val_f;

// ...
   assign ifu_fetch_val[1:0] = ic_fetch_val_f[1:0];

```

### design/ifu/el2_ifu_ic_mem.sv

```verilog
 if ( pt.ICACHE_ECC ) begin : ECC1_MUX

   assign ic_bank_wr_data[1] = ic_wr_data[1][70:0];
   assign ic_bank_wr_data[0] = ic_wr_data[0][70:0];

    always_comb begin : rd_mux
      wb_dout_way_pre[pt.ICACHE_NUM_WAYS-1:0] = '0;

      for ( int i=0; i<pt.ICACHE_NUM_WAYS; i++) begin : num_ways
        for ( int j=0; j<pt.ICACHE_BANKS_WAY; j++) begin : banks
         wb_dout_way_pre[i][70:0]      |=  ({71{(ic_rw_addr_ff[pt.ICACHE_BANK_HI : pt.ICACHE_BANK_LO] == (pt.ICACHE_BANK_BITS)'(j))}}   &  wb_dout[i][j]);
         wb_dout_way_pre[i][141 : 71]  |=  ({71{(ic_rw_addr_ff[pt.ICACHE_BANK_HI : pt.ICACHE_BANK_LO] == (pt.ICACHE_BANK_BITS)'(j-1))}} &  wb_dout[i][j]);
        end
      end
    end

   always_comb begin : rd_out
      ic_debug_rd_data[70:0]     = '0;
      wb_dout_ecc[141:0]         = '0;
      for ( int i=0; i<pt.ICACHE_NUM_WAYS; i++) begin : num_ways_mux2
         ic_debug_rd_data[70:0] |= ({71{ic_rd_hit_q[i]}}) & wb_dout_way_pre[i][70:0];
         wb_dout_ecc[141:0]     |= {142{ic_rd_hit_q[i]}}  & wb_dout_way_pre[i];
      end
   end

   // Expose the raw way-muxed 142-bit ECC-protected word pair to the core.
   // Byte-rotate + ECC decode are performed core-side (in el2_ifu_mem_ctl).
   assign ic_rd_data                = wb_dout_ecc;
   assign ic_rd_addr_lo[1:0]        = ic_rw_addr_ff[2:1];
   assign ic_rd_bank_check_en       = bank_check_en;

```

### testbench/ahb_sif.sv

```verilog
module axi_slv #(
    TAGW = 1
) (
    input                 aclk,
    input                 rst_l,
    input                 arvalid,
    output reg            arready,
    input      [    31:0] araddr,
    input      [TAGW-1:0] arid,
    input      [     7:0] arlen,
    input      [     1:0] arburst,
    input      [     2:0] arsize,

    output reg            rvalid,
    input                 rready,
    output reg [    63:0] rdata,
    output reg [     1:0] rresp,
    output reg [TAGW-1:0] rid,
    output reg            rlast,

// ...
  always @(posedge aclk) begin
    if (arvalid && arready) begin
      read_address = {araddr[31:3], 3'b000};
       rdata <= {
        mem[read_address+7],
        mem[read_address+6],
        mem[read_address+5],
        mem[read_address+4],
        mem[read_address+3],
        mem[read_address+2],
        mem[read_address+1],
        mem[read_address]
      };
       arready <= 0;
       rvalid <= 1;
       rid <= arid;
       rlast <= 1;
       rresp <= 0;
    end else if (rready) begin
       rvalid <= 0;
       arready <= 1;
       rlast <= 0;
    end

```

### testbench/tb_top.sv

```verilog
axi_slv #(.TAGW(`RV_IFU_BUS_TAG)) imem(
    .aclk(core_clk),
    .rst_l(rst_l_combined),
    .arvalid(ifu_axi_arvalid),
    .arready(ifu_axi_arready),
    .araddr(ifu_axi_araddr),
    .arid(ifu_axi_arid),
    .arlen(ifu_axi_arlen),
    .arburst(ifu_axi_arburst),
    .arsize(ifu_axi_arsize),

    .rvalid(ifu_axi_rvalid),
    .rready(ifu_axi_rready),
    .rdata(ifu_axi_rdata),
    .rresp(ifu_axi_rresp),
    .rid(ifu_axi_rid),
    .rlast(ifu_axi_rlast),

```

## Documentation

### docs/source/memory-map.md

```markdown
### Fencing

#### Instructions

The `fence.i` instruction operates on the instruction memory and/or I-cache.
This instruction causes a flush, a flash invalidation of the I-cache, and a refetch of the next program counter (RFNPC).
The refetch is guaranteed to miss the I-cache.
Note that since the `fence.i` instruction is used to synchronize the instruction and data streams, it also includes the functionality of the `fence` instruction (see [](memory-map.md#data)).

```

### docs/source/performance.md

```markdown
:::{list-table} List of Countable Events
:name: tab-list-of-countable-events

* - **Event No**
  - **Event Name**
  - **Description**

...
* - 2
  - I-cache hits
  - Number of I-cache hits (OOP, speculative, valid fetch &amp; hit)
* - 3
  - I-cache misses
  - Number of I-cache misses (OOP, valid fetch &amp; miss)

...
:::

```
