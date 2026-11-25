# Implement `el2_lsu_addrcheck`

Implement the complete `el2_lsu_addrcheck` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_lsu_addrcheck` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
$dccm_enable=1;
$dccm_region="0xf";
$dccm_offset="0x40000"; #1*256*1024
$dccm_size=64;

...
$pic_region="0xf";
$pic_offset="0xc0000"; # 3*256*1024
$pic_size=32;

...
$config{pic}{pic_base_addr} = (hex($config{pic}{pic_region})<<28) +
    (hex($config{pic}{pic_offset}));

...
$config{dccm}{dccm_sadr} = (hex($config{dccm}{dccm_region})<<28) +
    (hex($config{dccm}{dccm_offset}));

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
module el2_lsu_addrcheck
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input logic          lsu_c2_m_clk,              // clock
   input logic          rst_l,                     // reset

   input logic [31:0]   start_addr_d,              // start address for lsu
   input logic [31:0]   end_addr_d,                // end address for lsu
   input el2_lsu_pkt_t lsu_pkt_d,                 // packet in d
   input logic [31:0]   dec_tlu_mrac_ff,           // CSR read
   input logic [3:0]    rs1_region_d,              // address rs operand [31:28]

   input logic [31:0]   rs1_d,                     // address rs operand

   output logic         is_sideeffects_m,          // is sideffects space
   output logic         addr_in_dccm_d,            // address in dccm
   output logic         addr_in_pic_d,             // address in pic
   output logic         addr_external_d,           // address in external

   output logic         access_fault_d,            // access fault
   output logic         misaligned_fault_d,        // misaligned
   output logic [3:0]   exc_mscause_d,             // mscause for access/misaligned faults

   output logic         fir_dccm_access_error_d,   // Fast interrupt dccm access error
   output logic         fir_nondccm_access_error_d,// Fast interrupt dccm access error

    input logic lsu_pmp_error_start,
    input logic lsu_pmp_error_end,

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic         scan_mode                  // Scan mode
   /*pragma coverage on*/
);

```

## Parent instantiation

```verilog
   el2_lsu_addrcheck addrcheck (
              .start_addr_d(full_addr_d[31:0]),
              .end_addr_d(full_end_addr_d[31:0]),
              .rs1_region_d(rs1_d[31:28]),
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

### `rvrangecheck`

```verilog
module rvrangecheck  #(CCM_SADR = 32'h0,
                       CCM_SIZE  = 128) (
   input  logic [31:0]   addr,                             // Address to be checked for range
   output logic          in_range,                            // S_ADDR <= start_addr < E_ADDR
   output logic          in_region
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

## Documentation

### docs/source/memory-map.md

```markdown
## Memory Protection

To eliminate issuing speculative accesses to the IFU and LSU bus interfaces, VeeR EL2 provides a rudimentary memory protection mechanism for instruction and data accesses outside of the ICCM and DCCM memory regions.
Separate core build arguments for instructions and data are provided by the Memory Protection Unit (MPU) to enable and configure up to 8 address windows each.

...
Similarly, a load/store access to a non-DCCM or non-PIC memory-mapped control register region must fall within the address range of at least one data access window for the access to be forwarded to the LSU bus interface.
If at least one data access window is enabled, non-speculative load/store requests which are not within the address range of any enabled data access window cause a precise load/store address misaligned or access fault exception.
If none of the 8 data access windows is enabled, the memory protection mechanism for data accesses is turned off.
For the DCCM and PIC memory-mapped control register region(s), accesses within the DCCM's or the PIC memory-mapped control register's address range are allowed.
However, any access not within the DCCM's or PIC memory-mapped control register's address range results in a precise load/store address misaligned or access fault exception.

The configuration parameters for each of the 8 instruction and 8 data access windows are:

* Enable/disable instruction/data access window 0..7,
* a base address of the window (which must be 64B-aligned), and
* a mask specifying the size of the window (which must be an integer-multiple of 64 bytes minus 1).

...
### Rules for Core-Local Memory Accesses

The rules for instruction fetch and load/store accesses to core-local memories are:

...
1. A load/store access to a region
    1. containing one or more DCCM/PIC memory-mapped control register sub-region(s) causes an exception if
        1. the access is not completely within the DCCM/PIC memory-mapped control register subregion, or
        1. the boundary of
            1. a DCCM to a non-DCCM sub-region and vice versa, or
            1. a PIC memory-mapped control register sub-region

            is crossed,

          even if the region contains an ICCM sub-region.
    1. not containing a DCCM/PIC memory-mapped control register sub-region goes out to the system bus, even if the region contains an ICCM sub-region.

### Core-Local / D-Bus Access Prediction

In VeeR EL2, a prediction is made early in the pipeline if the access is to a core-local address (i.e., DCCM or PIC memory-mapped register) or to the D-bus (i.e., a memory or register address of the SoC).
The prediction is based on the base address (i.e., value of register *rs1*) of the load/store instruction.
Later in the pipeline, the actual address is calculated also taking the offset into account (i.e., value of register *rs1 + offset*).
A mismatch of the predicted and the actual destination (i.e., a core-local or a D-bus access) results in a load/store access fault exception.

...
### Misaligned Accesses

General notes:
* The core performs a misalignment check during the address calculation.
* Accesses across region boundaries always cause a misaligned exception.
* Splitting a load/store from/to an address with no side effects (i.e., idempotent) is not of concern for VeeR EL2.

:::{list-table} Handling of Misaligned Accesses
:name: tab-handling-misaligned-addresses
:header-rows: 1

* - **Access**
  - **Core/Bus**
  - **Side Effect**
  - **Region Cross**
  - **Action**
  - **Comments**

...
* - Load
  - Core
  - No
  - No
  - Load split into multiple DCCM read accesses
  - Split performed by core
* - Load
  - Bus
  - No
  - No
  - Load split into multiple bus transactions
  - Split performed by core
* - Load
  - Bus
  - Yes [^fn-misaligned-accesses-2]
  - No
  - Load address misaligned exception
  - Precise exception
* - Store
  - Core
  - No
  - No
  - Store split into multiple DCCM write accesses
  - Split performed by core
* - Store
  - Bus
  - No
  - No
  - Store split into multiple bus transactions
  - Split performed by core
* - Store
  - Bus
  - Yes [^fn-misaligned-accesses-2]
  - No
  - Store/AMO address misaligned exception
  - Precise exception

...
* - Load
  - N/A
  - N/A
  - Yes
  - Load address misaligned exception
  - Precise exception
* - Store
  - N/A
  - N/A
  - Yes
  - Store/AMO address misaligned exception
  - Precise exception

...
:::

...
[^fn-misaligned-accesses-2]: The RISC-V Privileged specification recommends that misaligned accesses to regions with potential side-effects should trigger an access fault exception, instead of a misaligned exception (see Section 3.5.6 in [[2]](intro.md#ref-2)). Note that VeeR EL2 triggers a misaligned exception in this case. To avoid potential side-effects, the exception handler should not emulate a misaligned access using multiple smaller aligned accesses.

...
### Machine Secondary Cause Register (mscause)

The `mscause` register, in conjunction with the standard RISC-V `mcause` register (see [](adaptations.md#machine-cause-register-mcause)), allows the determination of the exact cause of a trap for cases where multiple, different conditions share a single trap code.
The standard RISC-V mcause register provides the trap code and the `mscause` register provides supporting information about the trap to disambiguate different sources.
A value of '0' indicates that there is no additional information available.

...
* - **mcause**
  - **mcause Description**
  - **mscause (Rel. Priority)** [^fn-mscause-register-1]
  - **mscause Description**
  - **Section(s)**

...
* - 0x4
  - Load address misaligned
  - 0x2 (0)
  - D-side load across region boundary
  - [](memory-map.md#misaligned-accesses)
* - 0x4
  - Load address misaligned
  - 0x1 (1)
  - D-side size-misaligned load to non-idempotent address
  - [](memory-map.md#misaligned-accesses)
* - 0x5
  - Load access fault
  - 0x2 (0)
  - D-side core-local [^fn-mscause-register-4], [^fn-mscause-register-5] load unmapped address error
  - [](memory-map.md#unmapped-addresses) and [](error-protection.md#error-detection-and-handling)

...
* - 0x5
  - Load access fault
  - 0x3 (1)
  - D-side load access out of MPU range
  - [](memory-map.md#memory-protection)
* - 0x5
  - Load access fault
  - 0x5 (2)
  - D-side load region prediction error
  - [Core-Local / D-Bus Access Prediction](memory-map.md#core-local-d-bus-access-prediction)
* - 0x5
  - Load access fault
  - 0x6 (3)
  - D-side PIC [^fn-mscause-register-6] load access error
  - [](memory-map.md#unmapped-addresses)
* - 0x6
  - Store/AMO address misaligned
  - 0x2 (0)
  - D-side store across region boundary
  - [](memory-map.md#misaligned-accesses)
* - 0x6
  - Store/AMO address misaligned
  - 0x1 (1)
  - D-side size-misaligned store to non-idempotent address
  - [](memory-map.md#misaligned-accesses)
* - 0x7
  - Store/AMO access fault
  - 0x2 (0)
  - D-side core-local [^fn-mscause-register-4], [^fn-mscause-register-5] store unmapped address error
  - [](memory-map.md#unmapped-addresses) and [](error-protection.md#error-detection-and-handling)

...
* - 0x7
  - Store/AMO access fault
  - 0x3 (1)
  - D-side store access out of MPU range
  - [](memory-map.md#memory-protection)
* - 0x7
  - Store/AMO access fault
  - 0x5 (2)
  - D-side store region prediction error
  - [Core-Local / D-Bus Access Prediction](memory-map.md#core-local-d-bus-access-prediction)
* - 0x7
  - Store/AMO access fault
  - 0x6 (3)
  - D-side PIC [^fn-mscause-register-6] store access error
  - [](memory-map.md#unmapped-addresses)

...
[^fn-mscause-register-1]: Relative priority of load/store exceptions (0: highest priority).

...
[^fn-mscause-register-4]: Load/store access not within DCCM or PIC memory-mapped register address ranges.
[^fn-mscause-register-5]: If a load or store access crosses the upper boundary of either the DCCM or PIC memory-mapped register address range, the error address reported in the mtval register is the base address of the access, not the address of the first byte outside the DCCM or PIC range. Note that firmware cannot recover from this access fault independent of which address is reported.
[^fn-mscause-register-6]: PIC load/store not word-sized or address not word-aligned.

```
