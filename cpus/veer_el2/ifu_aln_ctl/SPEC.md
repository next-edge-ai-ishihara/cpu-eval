# Implement `el2_ifu_aln_ctl`

Implement the complete `el2_ifu_aln_ctl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_ifu_aln_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
$btb_enable=1;
$btb_fullya=0;

...
$config{btb}{btb_btag_fold} = 0;

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

## Parent instantiation

```verilog

   el2_ifu_aln_ctl #(.pt(pt)) aln (
                                    .*
                                    );

```

## Dependency declarations

### `el2_ifu_compress_ctl`

```verilog

module el2_ifu_compress_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input  logic [15:0] din,        // 16-bit   compressed instruction
   output logic [31:0] dout        // 32-bit uncompressed instruction
   );

```

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

### design/include/el2_def.sv

```verilog
typedef struct packed {
                       logic valid;
                       logic [11:0] toffset;
                       logic [1:0] hist;
                       logic br_error;
                       logic br_start_error;
                       logic  bank;
                       logic [31:1] prett;  // predicted ret target
                       logic way;
                       logic ret;
                       } el2_br_pkt_t;

```

## Related source code

### design/ifu/el2_ifu_bp_ctl.sv

```verilog
   // Branch prediction info is sent with the 2byte lane associated with the end of the branch.
   // Cases
   //       BANK1         BANK0
   // -------------------------------
   // |      :       |      :       |
   // -------------------------------
   //         <------------>                   : PC4 branch, offset, should be in B1 (indicated on [2])
   //                <------------>            : PC4 branch, no offset, indicate PC4, VALID, HIST on [1]
   //                       <------------>     : PC4 branch, offset, indicate PC4, VALID, HIST on [0]
   //                <------>                  : PC2 branch, offset, indicate VALID, HIST on [1]
   //                       <------>           : PC2 branch, no offset, indicate VALID, HIST on [0]

```

### design/ifu/el2_ifu_ifc_ctl.sv

```verilog
   assign ifc_fetch_req_bf_raw = ~idle;
   assign ifc_fetch_req_bf =  ifc_fetch_req_bf_raw &

                 ~(fb_full_f_ns & ~(ifu_fb_consume2 | ifu_fb_consume1)) &
                 ~dma_stall &
                 ~ic_write_stall &
                 ~dec_tlu_flush_noredir_wb;

// ...
   assign flush_fb = exu_flush_final;

   // model fb write logic to mass balance the fetch buffers
   assign fb_right = ( ifu_fb_consume1 & ~ifu_fb_consume2 & (~ifc_fetch_req_f | miss_f)) | // Consumed and no new fetch
              (ifu_fb_consume2 &  ifc_fetch_req_f); // Consumed 2 and new fetch


   assign fb_right2 = (ifu_fb_consume2 & (~ifc_fetch_req_f | miss_f)); // Consumed 2 and no new fetch

   assign fb_left = ifc_fetch_req_f & ~(ifu_fb_consume1 | ifu_fb_consume2) & ~miss_f;

// CBH
   assign fb_write_ns[3:0] = ( ({4{(flush_fb)}} & 4'b0001) |
                   ({4{~flush_fb & fb_right }} & {1'b0, fb_write_f[3:1]}) |
                   ({4{~flush_fb & fb_right2}} & {2'b0, fb_write_f[3:2]}) |
                   ({4{~flush_fb & fb_left  }} & {fb_write_f[2:0], 1'b0}) |
                   ({4{~flush_fb & ~fb_right & ~fb_right2 & ~fb_left}}  & fb_write_f[3:0]));


   assign fb_full_f_ns = fb_write_ns[3];

   assign idle     = state      == IDLE  ;
   assign wfm      = state      == WFM   ;

   rvdffie #(10) fbwrite_ff (.*, .clk(free_l2clk),
                          .din( {dma_iccm_stall_any, miss_f, ifc_fetch_req_bf, next_state[1:0], fb_full_f_ns, fb_write_ns[3:0]}),
                          .dout({dma_iccm_stall_any_f, miss_a, ifc_fetch_req_f, state[1:0], fb_full_f, fb_write_f[3:0]}));

```

## Documentation

### docs/source/tests.md

```markdown
## *I-MISALIGN_JMP-01*

* **Test location**: [https://github.com/riscv/riscv-compliance/blob/master/riscv-test-suite/rv32i/src/I-MISALIGN_JMP-01.S](https://github.com/riscv/riscv-compliance/blob/master/riscv-test-suite/rv32i/src/I-MISALIGN_JMP-01.S)
* **Reason for Failure**:
  * The VeeR EL2 core supports the standard "C" 16-bit compressed instruction extension.
    Compressed instruction execution cannot be turned off.
    Therefore, branch and jump instructions to 16-bit aligned memory addresses do not trigger misalignment exceptions.
  * Note that this is a known issue with the test suite ([https://github.com/riscv/riscv-compliance/issues/16](https://github.com/riscv/riscv-compliance/issues/16)) and is expected to eventually be fixed.

```

### src/intro.adoc

```asciidoc
=== Base Instruction-Length Encoding

The base RISC-V ISA has fixed-length 32-bit instructions that must be
naturally aligned on 32-bit boundaries. However, the standard RISC-V
encoding scheme is designed to support ISA extensions with
variable-length instructions, where each instruction can be any number
of 16-bit instruction _parcels_ in length and parcels are naturally
aligned on 16-bit boundaries. The standard compressed ISA extension
described in <<compressed>> reduces code size by
providing compressed 16-bit instructions and relaxes the alignment
constraints to allow all instructions (16 bit and 32 bit) to be aligned
on any 16-bit boundary to improve code density.

We use the term IALIGN (measured in bits) to refer to the
instruction-address alignment constraint the implementation enforces.
IALIGN is 32 bits in the base ISA, but some ISA extensions, including
the compressed ISA extension, relax IALIGN to 16 bits. IALIGN may not
take on any value other than 16 or 32.
(((ILEN)))

We use the term ILEN (measured in bits) to refer to the maximum
instruction length supported by an implementation, and which is always a
multiple of IALIGN. For implementations supporting only a base
instruction set, ILEN is 32 bits. Implementations supporting longer
instructions have larger values of ILEN.

<<instlengthcode>> illustrates the standard
RISC-V instruction-length encoding convention. All the 32-bit
instructions in the base ISA have their lowest two bits set to `11`. The
optional compressed 16-bit instruction-set extensions have their lowest
two bits equal to `00`, `01`, or `10`.

```
