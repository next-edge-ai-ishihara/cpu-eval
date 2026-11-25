# Implement `el2_ifu_ifc_ctl`

Implement the complete `el2_ifu_ifc_ctl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_ifu_ifc_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
$btb_enable=1;

...
$iccm_enable=1;
$iccm_region="0xe";
$top_align_iccm = 1;
$iccm_offset="0xe000000"; #0x380*256*1024
$iccm_size=64;

...
$icache_ln_sz=64;

...
$config{icache}{icache_tag_index_lo}   = log2($config{icache}{icache_ln_sz});

...
$config{icache}{icache_beat_addr_hi}  = ($config{icache}{icache_ln_sz}==64) ? 5 : 4;

...
$config{iccm}{iccm_sadr} = (hex($config{iccm}{iccm_region})<<28) +
                           (hex($config{iccm}{iccm_offset}));

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

## Parent instantiation

```verilog
   el2_ifu_ifc_ctl #(.pt(pt)) ifc (.*
                    );

```

## Dependency declarations

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

### `rvrangecheck`

```verilog
module rvrangecheck  #(CCM_SADR = 32'h0,
                       CCM_SIZE  = 128) (
   input  logic [31:0]   addr,                             // Address to be checked for range
   output logic          in_range,                            // S_ADDR <= start_addr < E_ADDR
   output logic          in_region
);

```

## Related source code

### design/ifu/el2_ifu_mem_ctl.sv

```verilog
   output logic                      ifu_miss_state_idle,           // No icache misses are outstanding.
   output logic                      ifu_ic_mb_empty,               // Continue with normal fetching. This does not mean that miss is finished.
   output logic                      ic_dma_active  ,               // In the middle of servicing dma request to ICCM. Do not make any new requests.
   output logic                      ic_write_stall,                // Stall fetch the cycle we are writing the cache.

// ...
assign ic_fetch_val_f[1] = fetch_req_f_qual & ifu_bp_inst_mask_f & ~(vaddr_f[pt.ICACHE_BEAT_ADDR_HI:1] == {pt.ICACHE_BEAT_ADDR_HI{1'b1}}) & (err_stop_state != ERR_FETCH2);
assign ic_fetch_val_f[0] = fetch_req_f_qual ;

```

### design/ifu/el2_ifu_aln_ctl.sv

```verilog
   rvdffe #(32)           q2ff        (.*, .clk(clk), .en(qwen[2]),        .din(ifu_fetch_data_f[31:0]),     .dout(q2[31:0]));
   rvdffe #(32)           q1ff        (.*, .clk(clk), .en(qwen[1]),        .din(ifu_fetch_data_f[31:0]),     .dout(q1[31:0]));
   rvdffe #(32)           q0ff        (.*, .clk(clk), .en(qwen[0]),        .din(ifu_fetch_data_f[31:0]),     .dout(q0[31:0]));

// ...
   assign qwen[2:0]          = { (wrptr[1:0] == 2'b10) & ifvalid,
                                 (wrptr[1:0] == 2'b01) & ifvalid,
                                 (wrptr[1:0] == 2'b00) & ifvalid };

// ...
   assign ifu_fb_consume1    =  consume_fb0 & ~consume_fb1 & ~exu_flush_final;
   assign ifu_fb_consume2    =  consume_fb0 &  consume_fb1 & ~exu_flush_final;

```

## Documentation

### docs/source/memory-map.md

```markdown
### Rules for Core-Local Memory Accesses

The rules for instruction fetch and load/store accesses to core-local memories are:

1. An instruction fetch access to a region
    1. containing one or more ICCM sub-region(s)causes an exception if
        1. the access is not completely within the ICCM sub-region, or
        1. the boundary of an ICCM to a non-ICCM sub-region and vice versa is crossed,

        even if the region contains a DCCM/PIC memory-mapped control register sub-region.
    1. not containing an ICCM sub-region goes out to the system bus, even if the region contains a DCCM/PIC memory-mapped control register sub-region.

...
### Region Access Control Register (mrac)

A single region access control register is sufficient to provide independent control for 16 address regions.

:::{note}
To guarantee that updates to the `mrac` register are in effect, if a region being updated is in the load/store space, a `fence` instruction is required.
Likewise, if a region being updated is in the instruction space, a `fence.i` instruction (which flushes the I-cache) is required.
:::

:::{note}
The *sideeffect* access control bits are ignored by the core for load/store accesses to addresses mapped to core-local memories (i.e., DCCM and ICCM) and PIC memory-mapped control registers as well as for all instruction fetch accesses.
The *cacheable* access control bits are ignored for instruction fetch accesses from addresses mapped to the ICCM, but not for any other addresses.
:::

:::{note}
The combination '11' (i.e., side effect and cacheable) is illegal. Writing '11' is mapped by hardware to the legal value '10' (i.e., side effect and non-cacheable).
:::

This register is mapped to the non-standard read/write CSR address space.

:::{list-table} Region Access Control Register (mrac, at CSR 0x7C0)
:name: tab-region-access-control-register
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - Y = 0..15 (= Region)
  -
  -
  -
  -
* - sideeffectY
  - Y*2+1
  - Side effect indication for region Y:
    - 0: No side effects (idempotent)
    - 1: Side effects possible (non-idempotent)
  - R/W
  - 0
* - cacheableY
  - Y*2
  - Caching control for region Y:
    - 0: Caching not allowed
    - 1: Caching allowed
  - R/W
  - 0
:::

```
