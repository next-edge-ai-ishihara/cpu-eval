# Implement `el2_lsu_lsc_ctl`

Implement the complete `el2_lsu_lsc_ctl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_lsu_lsc_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### configs/veer.config

```perl
$load_to_use_plus1=0;
```

## Module declaration

```verilog
module el2_lsu_lsc_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input logic                rst_l,                     // reset, active low
   input logic                clk_override,              // Override non-functional clock gating
   input logic                clk,                       // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.

   // clocks per pipe
   input logic                lsu_c1_m_clk,
   input logic                lsu_c1_r_clk,
   input logic                lsu_c2_m_clk,
   input logic                lsu_c2_r_clk,
   input logic                lsu_store_c1_m_clk,

   input logic [31:0]         lsu_ld_data_r,             // Load data R-stage
   input logic [31:0]         lsu_ld_data_corr_r,        // ECC corrected data R-stage
   input logic                lsu_single_ecc_error_r,    // ECC single bit error R-stage
   input logic                lsu_double_ecc_error_r,    // ECC double bit error R-stage

   input logic [31:0]         lsu_ld_data_m,             // Load data M-stage
   input logic                lsu_single_ecc_error_m,    // ECC single bit error M-stage
   input logic                lsu_double_ecc_error_m,    // ECC double bit error M-stage

   input logic                flush_m_up,                // Flush M and D stage
   input logic                flush_r,                   // Flush R-stage
   input logic                ldst_dual_d,               // load/store is unaligned at 32 bit boundary D-stage
   input logic                ldst_dual_m,               // load/store is unaligned at 32 bit boundary M-stage
   input logic                ldst_dual_r,               // load/store is unaligned at 32 bit boundary R-stage

   input logic [31:0]         exu_lsu_rs1_d,             // address
   input logic [31:0]         exu_lsu_rs2_d,             // store data

   input el2_lsu_pkt_t       lsu_p,                     // lsu control packet
   input logic                dec_lsu_valid_raw_d,       // Raw valid for address computation
   input logic [11:0]         dec_lsu_offset_d,          // 12b offset for load/store addresses

   input  logic [31:0]        picm_mask_data_m,          // PIC data M-stage
   input  logic [31:0]        bus_read_data_m,           // the bus return data
   output logic [31:0]        lsu_result_m,              // lsu load data
   output logic [31:0]        lsu_result_corr_r,         // This is the ECC corrected data going to RF
   // lsu address down the pipe
   output logic [31:0]        lsu_addr_d,
   output logic [31:0]        lsu_addr_m,
   output logic [31:0]        lsu_addr_r,
   // lsu address down the pipe - needed to check unaligned
   output logic [31:0]        end_addr_d,
   output logic [31:0]        end_addr_m,
   output logic [31:0]        end_addr_r,
   // store data down the pipe
   output logic [31:0]        store_data_m,

   input  logic [31:0]         dec_tlu_mrac_ff,          // CSR for memory region control
   output logic                lsu_exc_m,                // Access or misaligned fault
   output logic                is_sideeffects_m,         // is sideffects space
   output logic                lsu_commit_r,             // lsu instruction in r commits
   output logic                lsu_single_ecc_error_incr,// LSU inc SB error counter
   output el2_lsu_error_pkt_t lsu_error_pkt_r,          // lsu exception packet

   output logic [31:1]         lsu_fir_addr,             // fast interrupt address
   output logic [1:0]          lsu_fir_error,            // Error during fast interrupt lookup

   // address in dccm/pic/external per pipe stage
   output logic               addr_in_dccm_d,
   output logic               addr_in_dccm_m,
   output logic               addr_in_dccm_r,

   output logic               addr_in_pic_d,
   output logic               addr_in_pic_m,
   output logic               addr_in_pic_r,

   output logic               addr_external_m,

   // DMA slave
   input logic                dma_dccm_req,
   input logic [31:0]         dma_mem_addr,
   input logic [2:0]          dma_mem_sz,
   input logic                dma_mem_write,
   input logic [63:0]         dma_mem_wdata,

   // Store buffer related signals
   output el2_lsu_pkt_t      lsu_pkt_d,
   output el2_lsu_pkt_t      lsu_pkt_m,
   output el2_lsu_pkt_t      lsu_pkt_r,

    input logic lsu_pmp_error_start,
    input logic lsu_pmp_error_end,

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic               scan_mode                  // Scan mode
   /*pragma coverage on*/

   );
```

## Parent instantiation

```verilog
   el2_lsu_lsc_ctl #(.pt(pt)) lsu_lsc_ctl (.*);
```

## Dependency declarations

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
// ...
typedef struct packed {
                      logic inst_type;   //0: Load, 1: Store
                      //logic dma_valid;
                      logic exc_type;    //0: MisAligned, 1: Access Fault
                      logic [3:0] mscause;
                      logic [31:0] addr;
                      logic single_ecc_error;
                      logic exc_valid;
                      } el2_lsu_error_pkt_t;
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
// ...
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
// ...
module rvlsadder
  (
    input logic [31:0] rs1,
    input logic [11:0] offset,

    output logic [31:0] dout
    );
```

### design/lsu/el2_lsu_addrcheck.sv

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

## Related source code

### design/lsu/el2_lsu.sv

```verilog
   // Dual signals
   assign ldst_dual_d  = (lsu_addr_d[2] != end_addr_d[2]);
   assign ldst_dual_m  = (lsu_addr_m[2] != end_addr_m[2]);
   assign ldst_dual_r  = (lsu_addr_r[2] != end_addr_r[2]);
```

### design/lsu/el2_lsu_dccm_ctl.sv

```verilog
   output logic [pt.DCCM_DATA_WIDTH-1:0]   lsu_ld_data_r,           // right justified, ie load byte will have data at 7:0
   output logic [pt.DCCM_DATA_WIDTH-1:0]   lsu_ld_data_corr_r,      // right justified & ECC corrected, ie load byte will have data at 7:0
// ...
   output logic [pt.DCCM_DATA_WIDTH-1:0]   lsu_ld_data_m,           // right justified, ie load byte will have data at 7:0
// ...
   if (pt.LOAD_TO_USE_PLUS1 == 1) begin: L2U_Plus1_1
// ...
   end else begin: L2U_Plus1_0
// ...
      assign lsu_ld_data_r        = '0;
// ...
      rvdffe #(32) lsu_ld_data_corr_rff(.*, .din(lsu_ld_data_corr_m[31:0]), .dout(lsu_ld_data_corr_r[31:0]), .en((lsu_pkt_m.valid & lsu_pkt_m.load & (addr_in_pic_m | addr_in_dccm_m)) | clk_override));
   end
```

### design/dec/el2_dec_decode_ctl.sv

```verilog
   input logic [31:0] lsu_result_corr_r,              // load result - corrected data for writing gpr's, not for bypassing
// ...
   assign i0_result_corr_r[31:0]     = (r_d.i0v & r_d.i0load) ? lsu_result_corr_r[31:0] : i0_result_r_raw[31:0];
```

## Documentation

### src/rv32.adoc

```text
[[ldst]]
=== Load and Store Instructions
RV32I is a load-store architecture, where only load and store
instructions access memory and arithmetic instructions only operate on
CPU registers. RV32I provides a 32-bit address space that is
byte-addressed. The EEI will define what portions of the address space
are legal to access with which instructions (e.g., some addresses might
be read only, or support word access only). Loads with a destination of
`x0` must still raise any exceptions and cause any other side effects
even though the load value is discarded.

The EEI will define whether the memory system is little-endian or
big-endian. In RISC-V, endianness is byte-address invariant.

[NOTE]
====
In a system for which endianness is byte-address invariant, the
following property holds: if a byte is stored to memory at some address
in some endianness, then a byte-sized load from that address in any
endianness returns the stored value.

In a little-endian configuration, multibyte stores write the
least-significant register byte at the lowest memory byte address,
followed by the other register bytes in ascending order of their
significance. Loads similarly transfer the contents of the lesser memory
byte addresses to the less-significant register bytes.

In a big-endian configuration, multibyte stores write the
most-significant register byte at the lowest memory byte address,
followed by the other register bytes in descending order of their
significance. Loads similarly transfer the contents of the greater
memory byte addresses to the less-significant register bytes.
====

include::images/wavedrom/load-store.edn[]
[[load-store,load and store]]
//.Load and store instructions

Load and store instructions transfer a value between the registers and
memory. Loads are encoded in the I-type format and stores are S-type.
The effective address is obtained by adding register _rs1_ to the
sign-extended 12-bit offset. Loads copy a value from memory to register
_rd_. Stores copy the value in register _rs2_ to memory.

The LW instruction loads a 32-bit value from memory into _rd_. LH loads
a 16-bit value from memory, then sign-extends to 32-bits before storing
in _rd_. LHU loads a 16-bit value from memory but then zero extends to
32-bits before storing in _rd_. LB and LBU are defined analogously for
8-bit values. The SW, SH, and SB instructions store 32-bit, 16-bit, and
8-bit values from the low bits of register _rs2_ to memory.
```
