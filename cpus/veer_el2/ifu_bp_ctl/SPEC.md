# Implement `el2_ifu_bp_ctl`

Implement the complete `el2_ifu_bp_ctl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_ifu_bp_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
$ret_stack_size=8;
$btb_enable=1;
$btb_fullya=0;
$btb_toffset_size=12;
$btb_size=512;
$bht_size=512;

...
$config{btb}{btb_btag_fold} = 0;
$config{btb}{btb_fold2_index_hash} = 0;

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

## Parent instantiation

```verilog
      el2_ifu_bp_ctl #(.pt(pt)) bp (.*);

```

## Dependency declarations

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

### `rvbradder`

```verilog

module rvbradder
  (
    input [31:1] pc,
    input [12:1] offset,

    output [31:1] dout
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

### `el2_btb_tag_hash`

```verilog
module el2_btb_tag_hash
import el2_pkg::*;
#(
`include "el2_param.vh"
 ) (
                       input logic [pt.BTB_ADDR_HI+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE:pt.BTB_ADDR_HI+1] pc,
                       output logic [pt.BTB_BTAG_SIZE-1:0] hash
                       );

```

### `el2_btb_tag_hash_fold`

```verilog

module el2_btb_tag_hash_fold
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
                       input logic [pt.BTB_ADDR_HI+pt.BTB_BTAG_SIZE+pt.BTB_BTAG_SIZE:pt.BTB_ADDR_HI+1] pc,
                       output logic [pt.BTB_BTAG_SIZE-1:0] hash
                       );

```

### `el2_btb_addr_hash`

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

### `el2_btb_ghr_hash`

```verilog

module el2_btb_ghr_hash
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
                       input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] hashin,
                       input logic [pt.BHT_GHR_SIZE-1:0] ghr,
                       output logic [pt.BHT_ADDR_HI:pt.BHT_ADDR_LO] hash
                       );

```

### design/include/el2_def.sv

```verilog
typedef struct packed {
                       logic valid;
                       logic [1:0] hist;
                       logic br_error;
                       logic br_start_error;
                       logic way;
                       logic middle;
                       } el2_br_tlu_pkt_t;

// ...
typedef struct packed {
                       logic misp;
                       logic ataken;
                       logic boffset;
                       logic pc4;
                       logic [1:0] hist;
                       logic [11:0] toffset;
                       logic valid;
                       logic br_error;
                       logic br_start_error;
                       logic pcall;
                       logic pja;
                       logic way;
                       logic pret;
                       // for power use the pret bit to clock the prett field
                       logic [31:1] prett;
                       } el2_predict_pkt_t;

```

## Related source code

### design/exu/el2_exu_alu_ctl.sv

```verilog
   // .i 3
   // .o 2
   // .ilb hist[1] hist[0] taken
   // .ob newhist[1] newhist[0]
   // .type fd
   //
   // 00 0 01
   // 01 0 01
   // 10 0 00
   // 11 0 10
   // 00 1 10
   // 01 1 00
   // 10 1 11
   // 11 1 11

   assign newhist[1]          = ( pp_in.hist[1] &  pp_in.hist[0]) | (~pp_in.hist[0] & actual_taken);
   assign newhist[0]          = (~pp_in.hist[1] & ~actual_taken)  | ( pp_in.hist[1] & actual_taken);

   always_comb begin
      predict_p_out           =  pp_in;

      predict_p_out.misp      = ~flush_upper_x & ~flush_lower_r & (cond_mispredict | target_mispredict);
      predict_p_out.ataken    =  actual_taken;
      predict_p_out.hist[1]   =  newhist[1];
      predict_p_out.hist[0]   =  newhist[0];

   end

```

### design/exu/el2_exu.sv

```verilog
   assign i0_valid_d               =  i0_predict_p_d.valid  & dec_i0_alu_decode_d & ~dec_tlu_flush_lower_r;
   assign i0_taken_d               = (i0_predict_p_d.ataken & dec_i0_alu_decode_d);

if(pt.BTB_ENABLE==1) begin
   // maintain GHR at D
   assign ghr_d_ns[pt.BHT_GHR_SIZE-1:0]
                                   = ({pt.BHT_GHR_SIZE{~dec_tlu_flush_lower_r &  i0_valid_d}} & {ghr_d[pt.BHT_GHR_SIZE-2:0], i0_taken_d}) |
                                     ({pt.BHT_GHR_SIZE{~dec_tlu_flush_lower_r & ~i0_valid_d}} &  ghr_d[pt.BHT_GHR_SIZE-1:0]             ) |
                                     ({pt.BHT_GHR_SIZE{ dec_tlu_flush_lower_r              }} &  ghr_x[pt.BHT_GHR_SIZE-1:0]             );

   // maintain GHR at X
   assign ghr_x_ns[pt.BHT_GHR_SIZE-1:0]
                                   = ({pt.BHT_GHR_SIZE{ i0_valid_x}} & {ghr_x[pt.BHT_GHR_SIZE-2:0], i0_taken_x}) |
                                     ({pt.BHT_GHR_SIZE{~i0_valid_x}} &  ghr_x[pt.BHT_GHR_SIZE-1:0]             ) ;


   assign exu_i0_br_valid_r                                 =  i0_pp_r.valid;
   assign exu_i0_br_mp_r                                    =  i0_pp_r.misp;
   assign exu_i0_br_way_r                                   =  i0_pp_r.way;
   assign exu_i0_br_hist_r[1:0]                             =  {2{i0_pp_r.valid}} & i0_pp_r.hist[1:0];
   assign exu_i0_br_error_r                                 =  i0_pp_r.br_error;
   assign exu_i0_br_middle_r                                =  i0_pp_r.pc4 ^ i0_pp_r.boffset;
   assign exu_i0_br_start_error_r                           =  i0_pp_r.br_start_error;

   assign {exu_i0_br_fghr_r[pt.BHT_GHR_SIZE-1:0],
           exu_i0_br_index_r[pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]}=  predpipe_r[PREDPIPESIZE-1:pt.BTB_BTAG_SIZE];


   assign final_predict_mp                                  = (i0_flush_upper_x)  ?  i0_predict_p_x  :  '0;

   assign final_predpipe_mp[PREDPIPESIZE-1:0]               = (i0_flush_upper_x)  ?  predpipe_x      :  '0;

   assign after_flush_eghr[pt.BHT_GHR_SIZE-1:0]             = (i0_flush_upper_x & ~dec_tlu_flush_lower_r)  ?  ghr_d[pt.BHT_GHR_SIZE-1:0]  :  ghr_x[pt.BHT_GHR_SIZE-1:0];


   assign exu_mp_pkt.valid                                  =  final_predict_mp.valid;
   assign exu_mp_pkt.way                                    =  final_predict_mp.way;
   assign exu_mp_pkt.misp                                   =  final_predict_mp.misp;
   assign exu_mp_pkt.pcall                                  =  final_predict_mp.pcall;
   assign exu_mp_pkt.pja                                    =  final_predict_mp.pja;
   assign exu_mp_pkt.pret                                   =  final_predict_mp.pret;
   assign exu_mp_pkt.ataken                                 =  final_predict_mp.ataken;
   assign exu_mp_pkt.boffset                                =  final_predict_mp.boffset;
   assign exu_mp_pkt.pc4                                    =  final_predict_mp.pc4;
   assign exu_mp_pkt.hist[1:0]                              =  final_predict_mp.hist[1:0];
   assign exu_mp_pkt.toffset[11:0]                          =  final_predict_mp.toffset[11:0];
   assign exu_mp_pkt.br_error                               =  '0;
   assign exu_mp_pkt.br_start_error                         =  '0;

   assign exu_mp_fghr[pt.BHT_GHR_SIZE-1:0]                  =  after_flush_eghr[pt.BHT_GHR_SIZE-1:0];

   assign {exu_mp_index[pt.BTB_ADDR_HI:pt.BTB_ADDR_LO],
           exu_mp_btag[pt.BTB_BTAG_SIZE-1:0]}               =  final_predpipe_mp[PREDPIPESIZE-pt.BHT_GHR_SIZE-1:0];

   assign exu_mp_eghr[pt.BHT_GHR_SIZE-1:0]                  =  final_predpipe_mp[PREDPIPESIZE-1:pt.BTB_ADDR_HI-pt.BTB_ADDR_LO+pt.BTB_BTAG_SIZE+1]; // mp ghr for bht write
end // if (pt.BTB_ENABLE==1)

```

### design/dec/el2_dec_tlu_ctl.sv

```verilog
if(pt.BTB_ENABLE==1) begin
   // go ahead and repair the branch error on other flushes, doesn't have to be the rfpc flush
   assign dec_tlu_br0_error_r = exu_i0_br_error_r & dec_tlu_i0_valid_r & ~tlu_flush_lower_r_d1;
   assign dec_tlu_br0_start_error_r = exu_i0_br_start_error_r & dec_tlu_i0_valid_r & ~tlu_flush_lower_r_d1;
   assign dec_tlu_br0_v_r = exu_i0_br_valid_r & dec_tlu_i0_valid_r & ~tlu_flush_lower_r_d1 & (~exu_i0_br_mp_r | ~exu_pmu_i0_br_ataken);


   assign dec_tlu_br0_r_pkt.hist[1:0] = exu_i0_br_hist_r[1:0];
   assign dec_tlu_br0_r_pkt.br_error = dec_tlu_br0_error_r;
   assign dec_tlu_br0_r_pkt.br_start_error = dec_tlu_br0_start_error_r;
   assign dec_tlu_br0_r_pkt.valid = dec_tlu_br0_v_r;
   assign dec_tlu_br0_r_pkt.way = exu_i0_br_way_r;
   assign dec_tlu_br0_r_pkt.middle = exu_i0_br_middle_r;
end // if (pt.BTB_ENABLE==1)
else begin
   assign dec_tlu_br0_error_r = '0;
   assign dec_tlu_br0_start_error_r = '0;
   assign dec_tlu_br0_v_r = '0;
   assign dec_tlu_br0_r_pkt  = '0;
end // else: !if(pt.BTB_ENABLE==1)

```

### design/ifu/el2_ifu_ifc_ctl.sv

```verilog
if(pt.BTB_ENABLE==1) begin : genblock1
   logic sel_btb_addr_bf;

   assign sel_last_addr_bf = ~exu_flush_final & (~ifc_fetch_req_f | ~ic_hit_f);
   assign sel_btb_addr_bf  = ~exu_flush_final & ifc_fetch_req_f & ifu_bp_hit_taken_f & ic_hit_f;
   assign sel_next_addr_bf = ~exu_flush_final & ifc_fetch_req_f & ~ifu_bp_hit_taken_f & ic_hit_f;


   assign fetch_addr_bf[31:1] = ( ({31{exu_flush_final}} &  exu_flush_path_final[31:1]) | // FLUSH path
                  ({31{sel_last_addr_bf}} & ifc_fetch_addr_f[31:1]) | // MISS path
                  ({31{sel_btb_addr_bf}} & {ifu_bp_btb_target_f[31:1]})| // BTB target
                  ({31{sel_next_addr_bf}} & {fetch_addr_next[31:1]})); // SEQ path


end // if (pt.BTB_ENABLE=1)

```

## Additional requirement

Except when restoring the history after `exu_flush_final`, update `ifu_bp_fghr_f` only after a cycle in which both `ifc_fetch_req_f` and `ic_hit_f` are set.
