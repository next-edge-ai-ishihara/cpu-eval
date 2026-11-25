# Implement `el2_lsu_bus_buffer`

Implement the complete `el2_lsu_bus_buffer` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_lsu_bus_buffer` definition in a single SystemVerilog code block, with no text outside the block.

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

## Parent instantiation

```verilog
   el2_lsu_bus_buffer #(.pt(pt)) bus_buffer (
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

### `rvdffsc`

```verilog
module rvdffsc #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic             clear,
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

## Documentation

### docs/source/memory-map.md

```markdown
:::{note}
 'Cacheable = Yes' and 'Side Effect = Yes' is an illegal combination.
:::

## Memory Access Ordering

Loads and stores to system bus-attached memory (i.e. accesses with no side effects, idempotent) and devices (i.e. accesses with potential side effects, non-idempotent) pass through a unified read/write buffer.
The buffer is implemented as a FIFO.

### Load-To-Load and Store-To-Store Ordering

All loads are sent to the system bus interface in program order. Also, all stores are sent to the system bus interface in program order.

### Load/Store Ordering

#### Accesses with Potential Side Effects (i.e., Non-Idempotent)

When a load with potential side effects (i.e., non-idempotent) enters the buffer, the entire unified buffer is emptied, i.e., both stores with no side effects (i.e., idempotent) and with potential side effects (i.e., non-idempotent) are drained out.
Loads with potential side effects (i.e., non-idempotent) are sent out to the system bus with their exact size.

Stores with potential side effects (i.e., non-idempotent) are neither coalesced nor forwarded to a load.

#### Accesses with No Side Effects (i.e., Idempotent)

Loads with no side effects (i.e., idempotent) are always issued as double-words and check the contents of the unified buffer:

1. **Full address match** (all load bytes present in the unified buffer): Data is forwarded from the unified buffer.
   The load does not go out to the system bus.
2. **Partial address match** (some of the load bytes are in the unified buffer): The entire unified buffer is emptied, then the load request goes to the system bus.
3. **No match** (none of the bytes are in the unified buffer): The load is presented to the system bus interface without waiting for the stores to drain.

#### Ordering of Store - Load with No Side Effects (i.e., Idempotent)

A `fence` instruction is required to order an older store before a younger load with no side effects (i.e., idempotent).

:::{note}
 All memory-mapped register writes must be followed by a `fence` instruction to enforce ordering and synchronization.
:::

### Fencing

#### Instructions

The `fence.i` instruction operates on the instruction memory and/or I-cache.
This instruction causes a flush, a flash invalidation of the I-cache, and a refetch of the next program counter (RFNPC).
The refetch is guaranteed to miss the I-cache.
Note that since the `fence.i` instruction is used to synchronize the instruction and data streams, it also includes the functionality of the `fence` instruction (see [](memory-map.md#data)).

#### Data

The `fence` instruction is implemented conservatively in VeeR EL2 to keep the implementation simple.
It always performs the most conservative fencing, independent of the instruction's arguments.
The `fence` instruction is presynced to make sure that there are no instructions in the LSU pipe.
It stalls until the LSU indicates that the store buffer and unified buffer have been fully drained (i.e., are empty).
The `fence` instruction is only committed after all LSU buffers are idle and all outstanding bus transactions are completed.

### Imprecise Data Bus Errors

All store errors as well as non-blocking load errors on the system bus are imprecise.
The address of the first occurring imprecise data system bus error is logged and a non-maskable interrupt (NMI) is flagged for the first reported error only.
For stores, if there are other stores in the unified buffer behind the store which had the error, these stores are sent out on the system bus and any error responses are ignored.
Similarly, for non-blocking loads, any error responses on subsequent loads sent out on the system bus are ignored.

```
