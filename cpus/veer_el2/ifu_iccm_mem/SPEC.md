# Implement `el2_ifu_iccm_mem`

Implement the complete `el2_ifu_iccm_mem` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_ifu_iccm_mem` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
$iccm_size=64;
$iccm_num_banks=4;
$iccm_addr_xor=0;
$iccm_ecc_width=7;

...
$config{iccm}{iccm_bits}       = 10 + log2($config{iccm}{iccm_size});
$config{iccm}{iccm_bank_bits}  = log2($config{iccm}{iccm_num_banks});  //-1;
$config{iccm}{iccm_index_bits} = $config{iccm}{iccm_bits} - $config{iccm}{iccm_bank_bits} - 2;   # always 4 bytes
$config{iccm}{iccm_rows}       = 2**$config{iccm}{iccm_index_bits};
$config{iccm}{iccm_data_cell}  = "ram_$config{iccm}{iccm_rows}x39";

$config{iccm}{iccm_bank_hi}        = 2+$config{iccm}{iccm_bank_bits}-1;
$config{iccm}{iccm_bank_index_lo}  = 1+$config{iccm}{iccm_bank_hi};

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

module el2_ifu_iccm_mem
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input logic                                        clk,                                 // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic                                        active_clk,                          // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
   input logic                                        rst_l,                               // reset, active low
   input logic                                        clk_override,                        // Override non-functional clock gating

   input logic                                        iccm_wren,                           // ICCM write enable
   input logic                                        iccm_rden,                           // ICCM read enable
   input logic [pt.ICCM_BITS-1:1]                     iccm_rw_addr,                        // ICCM read/write address
   input logic                                        iccm_buf_correct_ecc,                // ICCM is doing a single bit error correct cycle
   input logic                                        iccm_correction_state,               // ICCM under a correction - This is needed to guard replacements when hit
   input logic [2:0]                                  iccm_wr_size,                        // ICCM write size
   input logic [77:0]                                 iccm_wr_data,                        // ICCM write data

   el2_mem_if.veer_iccm                               iccm_mem_export,                     // RAM repositioned in testbench and connected by this interface

   output logic [77:0]                                iccm_rd_data_ecc,                    // ICCM read ecc
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic                                       scan_mode                            // Scan mode control
   /*pragma coverage on*/

);

```

## Parent instantiation

```verilog
   el2_ifu_iccm_mem  #(.pt(pt)) iccm (.*,
                  .clk_override(icm_clk_override),
                  .iccm_rw_addr(iccm_rw_addr[pt.ICCM_BITS-1:1]),
                  .iccm_mem_export(mem_export_local.veer_iccm)
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

// ...
  modport veer_iccm(
      input clk,
      // ICCM
      output iccm_clken, iccm_wren_bank, iccm_addr_bank, iccm_bank_wr_data, iccm_bank_wr_ecc,
      input iccm_bank_dout, iccm_bank_ecc
  );

// ...
endinterface

```

## Related source code

### design/lib/mem_lib.sv

```verilog
always @(posedge CLK) begin                 \
`ifdef GTLSIM                               \
   if (ME && WE) ram_core[ADR] <= D;        \
`else                                       \
   if (ME && WE) begin ram_core[ADR] <= D; Q <= 'x; end  \
`endif                                      \
   if (ME && ~WE) Q <= ram_core[ADR];       \
end                                         \

```

### design/el2_dma_ctrl.sv

```verilog
   assign dma_alignment_error = fifo_valid[RdPtr] & ~fifo_done[RdPtr] & ~fifo_dbg[RdPtr] & ~dma_address_error &
                                (((dma_mem_sz_int[2:0] == 3'h1) & dma_mem_addr_int[0])                                                             |    // HW size but unaligned
                                 ((dma_mem_sz_int[2:0] == 3'h2) & (|dma_mem_addr_int[1:0]))                                                        |    // W size but unaligned
                                 ((dma_mem_sz_int[2:0] == 3'h3) & (|dma_mem_addr_int[2:0]))                                                        |    // DW size but unaligned
                                 (dma_mem_addr_in_iccm & ~((dma_mem_sz_int[1:0] == 2'b10) | (dma_mem_sz_int[1:0] == 2'b11)))                       |    // ICCM access not word size
                                 (dma_mem_addr_in_dccm & dma_mem_write & ~((dma_mem_sz_int[1:0] == 2'b10) | (dma_mem_sz_int[1:0] == 2'b11)))       |    // DCCM write not word size
                                 (dma_mem_write & (dma_mem_sz_int[2:0] == 3'h2) & (dma_mem_addr_int[2:0] == 3'h0) & (dma_mem_byteen[3:0] != 4'hf)) |    // Write byte enables not aligned for word store
                                 (dma_mem_write & (dma_mem_sz_int[2:0] == 3'h2) & (dma_mem_addr_int[2:0] == 3'h4) & (dma_mem_byteen[7:4] != 4'hf)) |    // Write byte enables not aligned for word store
                                 (dma_mem_write & (dma_mem_sz_int[2:0] == 3'h3) & ~((dma_mem_byteen[7:0] == 8'h0f) | (dma_mem_byteen[7:0] == 8'hf0) | (dma_mem_byteen[7:0] == 8'hff)))); // Write byte enables not aligned for dword store

```

### design/ifu/el2_ifu_mem_ctl.sv

```verilog
   assign iccm_correct_ecc     = (perr_state == ECC_CORR);
   assign dma_sb_err_state     = (perr_state == DMA_SB_ERR);
   assign iccm_buf_correct_ecc = iccm_correct_ecc & ~dma_sb_err_state_ff;

// ...
         assign iccm_wren          =  (ifc_dma_access_q_ok & dma_iccm_req &  dma_mem_write) | iccm_correct_ecc;
         assign iccm_rden          =  (ifc_dma_access_q_ok & dma_iccm_req & ~dma_mem_write) | (ifc_iccm_access_bf & ifc_fetch_req_bf);
         assign iccm_dma_rden      =  (ifc_dma_access_q_ok & dma_iccm_req & ~dma_mem_write)                     ;
         assign iccm_wr_size[2:0]  =  {3{dma_iccm_req}}    & dma_mem_sz[2:0] ;

// ...
         logic [77:0] iccm_wr_data_pre;
         assign iccm_wr_data_pre[77:0] =  (iccm_correct_ecc & ~(ifc_dma_access_q_ok & dma_iccm_req)) ?  {iccm_ecc_corr_data_ff[38:0], iccm_ecc_corr_data_ff[38:0]} :
                                                                                                        {dma_mem_ecc[13:7],dma_mem_wdata[63:32], dma_mem_ecc[6:0],dma_mem_wdata[31:0]};
         assign iccm_wr_data[31:0]   = iccm_wr_data_pre[31:0]  ^ iccm_wr_xor_mask_w0[31:0]; // word0 data ^ addr mask
         assign iccm_wr_data[38:32]  = iccm_wr_data_pre[38:32];                             // word0 ecc (plain)
         assign iccm_wr_data[70:39]  = iccm_wr_data_pre[70:39] ^ iccm_wr_xor_mask_w1[31:0]; // word1 data ^ addr mask
         assign iccm_wr_data[77:71]  = iccm_wr_data_pre[77:71];                             // word1 ecc (plain)

         assign iccm_dma_rdata_1_muxed[31:0] = dma_mem_addr_ff[2] ?  iccm_corrected_data[0][31:0] : iccm_corrected_data[1][31:0] ;
         assign iccm_dma_rdata_in[63:0]      = iccm_dma_ecc_error_in ? {2{dma_mem_addr[31:0]}} : {iccm_dma_rdata_1_muxed[31:0], iccm_corrected_data[0]};
         assign iccm_dma_ecc_error_in   =   |(iccm_double_ecc_error[1:0]);

// ...
         assign iccm_rw_addr[pt.ICCM_BITS-1:1]    = (  ifc_dma_access_q_ok & dma_iccm_req  & ~iccm_correct_ecc) ? dma_mem_addr[pt.ICCM_BITS-1:1] :
                                                 (~(ifc_dma_access_q_ok & dma_iccm_req) &  iccm_correct_ecc) ? {iccm_ecc_corr_index_ff[pt.ICCM_BITS-1:2],1'b0} : ifc_fetch_addr_bf[pt.ICCM_BITS-1:1] ;

// ...

   // ICCM address-XOR: remove the address from the DATA bits before ECC decode, using the
   // registered read address.
   assign iccm_rdmux_data[31:0]   = iccm_rd_data_ecc[31:0]   ^ iccm_rd_xor_mask_w0[31:0]; // word0 data de-XOR
   assign iccm_rdmux_data[38:32]  = iccm_rd_data_ecc[38:32];                              // word0 ecc (plain)
   assign iccm_rdmux_data[70:39]  = iccm_rd_data_ecc[70:39]  ^ iccm_rd_xor_mask_w1[31:0]; // word1 data de-XOR
   assign iccm_rdmux_data[77:71]  = iccm_rd_data_ecc[77:71];                              // word1 ecc (plain)
   // Remove the ECC and align by the fetch halfword.
    assign iccm_rd_data[63:0] =  64'({iccm_rdmux_data[70:39], iccm_rdmux_data[31:0]} >> (16*ifu_fetch_addr_int_f[1]));
   for (genvar i=0; i < 2 ; i++) begin : ICCM_ECC_CHECK
      assign iccm_ecc_word_enable[i] = ((|ic_fetch_val_shift_right[(2*i+1):(2*i)] & ~exu_flush_final & sel_iccm_data) | iccm_dma_rvalid_in) & ~dec_tlu_core_ecc_disable;
   rvecc_decode  ecc_decode (
                           .en(iccm_ecc_word_enable[i]),
                           .sed_ded ( 1'b0 ),    // 1 : means only detection
                           .din(iccm_rdmux_data[(39*i+31):(39*i)]),
                           .ecc_in(iccm_rdmux_data[(39*i+38):(39*i+32)]),
                           .dout(iccm_corrected_data[i][31:0]),
                           .ecc_out(iccm_corrected_ecc[i][6:0]),
                           .single_ecc_error(iccm_single_ecc_error[i]),
                           .double_ecc_error(iccm_double_ecc_error[i]));
end

```

### testbench/tb_top.sv

```verilog
function int get_iccm_bank(input[31:0] addr,  output int bank_idx);

// ...
`elsif RV_ICCM_NUM_BANKS_4
    bank_idx = int'(addr[`RV_ICCM_BITS-1:4]);
    return int'(addr[3:2]);

```

## Documentation

### docs/source/error-protection.md

```markdown
General comments:

* No address information of each individual correctable error is captured.
* Stuck-at faults:
  * Stuck-at bits would cause the correctable error threshold to be reached relatively quickly but are only reported if interrupts are enabled.
  * Use MBIST to determine exact location of the bad bit.
  * Because ICCM single-bit errors on fetches are not in-line corrected, VeeR EL2's ICCM implements two row's worth of redundant memory which is transparently managed in hardware.
    These extra rows help to avoid that a stuck-at bit may hang the core.

```
