# Implement `el2_dec_decode_ctl`

Implement the complete `el2_dec_decode_ctl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_dec_decode_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### `configs/veer.config`

```text
$btb_enable=1;
$btb_fullya=0;
...
$load_to_use_plus1=0;
...
# Default bitmanip options
my $bitmanip_zba = 1;
my $bitmanip_zbb = 1;
my $bitmanip_zbc = 1;
my $bitmanip_zbe = 0;
my $bitmanip_zbf = 0;
my $bitmanip_zbp = 0;
my $bitmanip_zbr = 0;
my $bitmanip_zbs = 1;
```

## Module declaration

```verilog


module el2_dec_decode_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic dec_tlu_trace_disable,
   input logic dec_debug_valid_d,

   input logic dec_tlu_flush_extint,         // Flush external interrupt

   input logic dec_tlu_force_halt,           // invalidate nonblock load cam on a force halt event

   output logic dec_extint_stall,            // Stall from external interrupt

   input  logic [15:0] ifu_i0_cinst,         // 16b compressed instruction
   output logic [31:0] dec_i0_inst_wb,       // 32b instruction at wb+1 for trace encoder
   output logic [31:1] dec_i0_pc_wb,         // 31b pc at wb+1 for trace encoder


   input logic                                lsu_nonblock_load_valid_m,       // valid nonblock load at m
   input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_tag_m,         // -> corresponding tag
   input logic                                lsu_nonblock_load_inv_r,         // invalidate request for nonblock load r
   input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_inv_tag_r,     // -> corresponding tag
   input logic                                lsu_nonblock_load_data_valid,    // valid nonblock load data back
   input logic                                lsu_nonblock_load_data_error,    // nonblock load bus error
   input logic [pt.LSU_NUM_NBLOAD_WIDTH-1:0]  lsu_nonblock_load_data_tag,      // -> corresponding tag


   input logic [3:0] dec_i0_trigger_match_d,          // i0 decode trigger matches

   input logic dec_tlu_wr_pause_r,                    // pause instruction at r
   input logic dec_tlu_pipelining_disable,            // pipeline disable - presync, i0 decode only

   input logic [3:0]  lsu_trigger_match_m,            // lsu trigger matches

   input logic lsu_pmu_misaligned_m,                  // perf mon: load/store misalignment
   input logic dec_tlu_debug_stall,                   // debug stall decode
   input logic dec_tlu_flush_leak_one_r,              // leak1 instruction

   input logic dec_debug_fence_d,                     // debug fence instruction

   input logic [1:0] dbg_cmd_wrdata,                  // disambiguate fence, fence_i

   input logic dec_i0_icaf_d,                         // icache access fault
   input logic dec_i0_icaf_second_d,                  // i0 instruction access fault on second 2B of 4B inst
   input logic [1:0] dec_i0_icaf_type_d,              // i0 instruction access fault type

   input logic dec_i0_dbecc_d,                        // icache/iccm double-bit error

   input el2_br_pkt_t dec_i0_brp,                    // branch packet
   input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] dec_i0_bp_index,   // i0 branch index
   input logic [pt.BHT_GHR_SIZE-1:0] dec_i0_bp_fghr,  // BP FGHR
   input logic [pt.BTB_BTAG_SIZE-1:0] dec_i0_bp_btag, // BP tag
   input logic [$clog2(pt.BTB_SIZE)-1:0] dec_i0_bp_fa_index,          // Fully associative btb index

   input logic lsu_idle_any,                          // lsu idle: if fence instr & ~lsu_idle then stall decode

   input logic lsu_load_stall_any,                    // stall any load at decode
   input logic lsu_store_stall_any,                   // stall any store at decode
   input logic dma_dccm_stall_any,                    // stall any load/store at decode

   input logic exu_div_wren,                          // nonblocking divide write enable to GPR.

   input logic dec_tlu_i0_kill_writeb_wb,             // I0 is flushed, don't writeback any results to arch state
   input logic dec_tlu_flush_lower_wb,                // trap lower flush
   input logic dec_tlu_i0_kill_writeb_r,              // I0 is flushed, don't writeback any results to arch state
   input logic dec_tlu_flush_lower_r,                 // trap lower flush
   input logic dec_tlu_flush_pause_r,                 // don't clear pause state on initial lower flush
   input logic dec_tlu_presync_d,                     // CSR read needs to be presync'd
   input logic dec_tlu_postsync_d,                    // CSR ops that need to be postsync'd

   input logic dec_i0_pc4_d,                          // inst is 4B inst else 2B

   input logic [31:0] dec_csr_rddata_d,               // csr read data at wb
   input logic dec_csr_legal_d,                       // csr indicates legal operation

   input logic [31:0] exu_csr_rs1_x,                  // rs1 for csr instr

   input logic [31:0] lsu_result_m,                   // load result
   input logic [31:0] lsu_result_corr_r,              // load result - corrected data for writing gpr's, not for bypassing

   input logic exu_flush_final,                       // lower flush or i0 flush at X or D

   input logic [31:1] exu_i0_pc_x,                    // pcs at e1

   input logic [31:0] dec_i0_instr_d,                 // inst at decode

   input logic  dec_ib0_valid_d,                      // inst valid at decode

   input logic [31:0] exu_i0_result_x,                // from primary alu's

   input logic  clk,                                  // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic  active_clk,                           // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
   input logic  free_l2clk,                           // Clock always.                  Through one clock header.  For flops with    second header built in.

   input logic  clk_override,                         // Override non-functional clock gating
   input logic  rst_l,                                // Flop reset



   output logic        dec_i0_rs1_en_d,               // rs1 enable at decode
   output logic        dec_i0_rs2_en_d,               // rs2 enable at decode

   output logic [4:0]  dec_i0_rs1_d,                  // rs1 logical source
   output logic [4:0]  dec_i0_rs2_d,                  // rs2 logical source

   output logic [31:0] dec_i0_immed_d,                // 32b immediate data decode


   output logic [12:1] dec_i0_br_immed_d,             // 12b branch immediate

   output el2_alu_pkt_t i0_ap,                       // alu packets

   output logic        dec_i0_decode_d,               // i0 decode

   output logic        dec_i0_alu_decode_d,           // decode to D-stage alu
   output logic        dec_i0_branch_d,               // Branch in D-stage

   output logic [4:0]  dec_i0_waddr_r,                // i0 logical source to write to gpr's
   output logic        dec_i0_wen_r,                  // i0 write enable
   output logic [31:0] dec_i0_wdata_r,                // i0 write data

   output logic        dec_i0_select_pc_d,            // i0 select pc for rs1 - branches

   output logic [3:0]    dec_i0_rs1_bypass_en_d,      // i0 rs1 bypass enable
   output logic [3:0]    dec_i0_rs2_bypass_en_d,      // i0 rs2 bypass enable
   output logic [31:0]   dec_i0_result_r,             // Result R-stage

   output el2_lsu_pkt_t    lsu_p,                    // load/store packet
   output logic             dec_qual_lsu_d,           // LSU instruction at D.  Use to quiet LSU operands

   output el2_mul_pkt_t    mul_p,                    // multiply packet

   output el2_div_pkt_t    div_p,                    // divide packet
   output logic [4:0]       div_waddr_wb,             // DIV write address to GPR
   output logic             dec_div_cancel,           // cancel the divide operation

   output logic        dec_lsu_valid_raw_d,
   output logic [11:0] dec_lsu_offset_d,

   output logic        dec_csr_ren_d,                 // valid csr decode
   output logic        dec_csr_wen_unq_d,             // valid csr with write - for csr legal
   output logic        dec_csr_any_unq_d,             // valid csr - for csr legal
   output logic [11:0] dec_csr_rdaddr_d,              // read address for csr
   output logic        dec_csr_wen_r,                 // csr write enable at r
   output logic [11:0] dec_csr_rdaddr_r,              // read address for csr
   output logic [11:0] dec_csr_wraddr_r,              // write address for csr
   output logic [31:0] dec_csr_wrdata_r,              // csr write data at r
   output logic        dec_csr_stall_int_ff,          // csr is mie/mstatus

   output              dec_tlu_i0_valid_r,            // i0 valid inst at c

   output el2_trap_pkt_t   dec_tlu_packet_r,              // trap packet

   output logic [31:1] dec_tlu_i0_pc_r,               // i0 trap pc

   output logic [31:0] dec_illegal_inst,              // illegal inst
   output logic [31:1] pred_correct_npc_x,            // npc e2 if the prediction is correct

   output el2_predict_pkt_t dec_i0_predict_p_d,      // i0 predict packet decode
   output logic [pt.BHT_GHR_SIZE-1:0] i0_predict_fghr_d, // i0 predict fghr
   output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] i0_predict_index_d, // i0 predict index
   output logic [pt.BTB_BTAG_SIZE-1:0] i0_predict_btag_d, // i0_predict branch tag

   output logic [$clog2(pt.BTB_SIZE)-1:0] dec_fa_error_index, // Fully associative btb error index

   output logic [1:0] dec_data_en,                    // clock-gating logic
   output logic [1:0] dec_ctl_en,

   output logic       dec_pmu_instr_decoded,          // number of instructions decode this cycle encoded
   output logic       dec_pmu_decode_stall,           // decode is stalled
   output logic       dec_pmu_presync_stall,          // decode has presync stall
   output logic       dec_pmu_postsync_stall,         // decode has postsync stall

   output logic       dec_nonblock_load_wen,          // write enable for nonblock load
   output logic [4:0] dec_nonblock_load_waddr,        // logical write addr for nonblock load
   output logic       dec_pause_state,                // core in pause state
   output logic       dec_pause_state_cg,             // pause state for clock-gating

   output logic       dec_div_active,                 // non-block divide is active

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic       scan_mode
   /*pragma coverage on*/
   );
```

## Parent instantiation

```verilog


  el2_dec_decode_ctl #(.pt(pt)) decode (.*);
```

## Dependency declarations

### `design/dec/el2_dec_decode_ctl.sv`

```verilog

module el2_dec_dec_ctl
  import el2_pkg::*;
(
    input logic [31:0] inst,
    output el2_dec_pkt_t out
);
```

### `design/lib/beh_lib.sv`

```verilog


module rvdff #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic                   rst_l,

     output logic [WIDTH-1:0] dout
     );
// ...
module rvdffs #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
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
// ...
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
// ...




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
// ...

module rvbradder
  (
    input [31:1] pc,
    input [12:1] offset,

    output [31:1] dout
    );
```

### `design/include/el2_def.sv`

```verilog
typedef enum logic [3:0] {
                          NULL_OP  = 4'b0000,
                          MUL      = 4'b0001,
                          LOAD     = 4'b0010,
                          STORE    = 4'b0011,
                          ALU      = 4'b0100,
                          CSRREAD  = 4'b0101,
                          CSRWRITE = 4'b0110,
                          CSRRW    = 4'b0111,
                          EBREAK   = 4'b1000,
                          ECALL    = 4'b1001,
                          FENCE    = 4'b1010,
                          FENCEI   = 4'b1011,
                          MRET     = 4'b1100,
                          CONDBR   = 4'b1101,
                          JAL      = 4'b1110,
                          BITMANIPU = 4'b1111
                          } el2_inst_pkt_t;
// ...
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
// ...
typedef struct packed {
                       // unlikely to change
                       logic icaf;
                       logic icaf_second;
                       logic [1:0] icaf_type;
                       logic fence_i;
                       logic [3:0] i0trigger;
                       logic pmu_i0_br_unpred;     // pmu
                       logic pmu_divide;
                       // likely to change
                       logic legal;
                       logic pmu_lsu_misaligned;
                       el2_inst_pkt_t pmu_i0_itype;        // pmu - instruction type
                       } el2_trap_pkt_t;
// ...
typedef struct packed {
                       logic clz;
                       logic ctz;
                       logic cpop;
                       logic sext_b;
                       logic sext_h;
                       logic min;
                       logic max;
                       logic pack;
                       logic packu;
                       logic packh;
                       logic rol;
                       logic ror;
                       logic grev;
                       logic gorc;
                       logic zbb;
                       logic bset;
                       logic bclr;
                       logic binv;
                       logic bext;
                       logic sh1add;
                       logic sh2add;
                       logic sh3add;
                       logic zba;
                       logic land;
                       logic lor;
                       logic lxor;
                       logic sll;
                       logic srl;
                       logic sra;
                       logic beq;
                       logic bne;
                       logic blt;
                       logic bge;
                       logic add;
                       logic sub;
                       logic slt;
                       logic unsign;
                       logic jal;
                       logic predict_t;
                       logic predict_nt;
                       logic csr_write;
                       logic csr_imm;
                       } el2_alu_pkt_t;
// ...
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
                       logic clz;
                       logic ctz;
                       logic cpop;
                       logic sext_b;
                       logic sext_h;
                       logic min;
                       logic max;
                       logic pack;
                       logic packu;
                       logic packh;
                       logic rol;
                       logic ror;
                       logic grev;
                       logic gorc;
                       logic zbb;
                       logic bset;
                       logic bclr;
                       logic binv;
                       logic bext;
                       logic zbs;
                       logic bcompress;
                       logic bdecompress;
                       logic zbe;
                       logic clmul;
                       logic clmulh;
                       logic clmulr;
                       logic zbc;
                       logic shfl;
                       logic unshfl;
                       logic xperm_n;
                       logic xperm_b;
                       logic xperm_h;
                       logic zbp;
                       logic crc32_b;
                       logic crc32_h;
                       logic crc32_w;
                       logic crc32c_b;
                       logic crc32c_h;
                       logic crc32c_w;
                       logic zbr;
                       logic bfp;
                       logic zbf;
                       logic sh1add;
                       logic sh2add;
                       logic sh3add;
                       logic zba;
                       logic alu;
                       logic rs1;
                       logic rs2;
                       logic imm12;
                       logic rd;
                       logic shimm5;
                       logic imm20;
                       logic pc;
                       logic load;
                       logic store;
                       logic lsu;
                       logic add;
                       logic sub;
                       logic land;
                       logic lor;
                       logic lxor;
                       logic sll;
                       logic sra;
                       logic srl;
                       logic slt;
                       logic unsign;
                       logic condbr;
                       logic beq;
                       logic bne;
                       logic bge;
                       logic blt;
                       logic jal;
                       logic by;
                       logic half;
                       logic word;
                       logic csr_read;
                       logic csr_clr;
                       logic csr_set;
                       logic csr_write;
                       logic csr_imm;
                       logic presync;
                       logic postsync;
                       logic ebreak;
                       logic ecall;
                       logic mret;
                       logic mul;
                       logic rs1_sign;
                       logic rs2_sign;
                       logic low;
                       logic div;
                       logic rem;
                       logic fence;
                       logic fence_i;
                       logic pm_alu;
                       logic legal;
                       } el2_dec_pkt_t;
// ...
typedef struct packed {
                       logic valid;
                       logic rs1_sign;
                       logic rs2_sign;
                       logic low;
                       logic bcompress;
                       logic bdecompress;
                       logic clmul;
                       logic clmulh;
                       logic clmulr;
                       logic grev;
                       logic gorc;
                       logic shfl;
                       logic unshfl;
                       logic crc32_b;
                       logic crc32_h;
                       logic crc32_w;
                       logic crc32c_b;
                       logic crc32c_h;
                       logic crc32c_w;
                       logic bfp;
                       logic xperm_n;
                       logic xperm_b;
                       logic xperm_h;
                       } el2_mul_pkt_t;
// ...
typedef struct packed {
                       logic valid;
                       logic unsign;
                       logic rem;
                       } el2_div_pkt_t;
```

## Related source code

### `design/exu/el2_exu.sv`

```verilog
   assign i0_rs1_bypass_en_d       = dec_i0_rs1_bypass_en_d[0] | dec_i0_rs1_bypass_en_d[1] | dec_i0_rs1_bypass_en_d[2] | dec_i0_rs1_bypass_en_d[3];
   assign i0_rs2_bypass_en_d       = dec_i0_rs2_bypass_en_d[0] | dec_i0_rs2_bypass_en_d[1] | dec_i0_rs2_bypass_en_d[2] | dec_i0_rs2_bypass_en_d[3];

   assign i0_rs1_bypass_data_d[31:0]=({32{dec_i0_rs1_bypass_en_d[0]}} & dec_i0_result_r[31:0]       ) |
                                     ({32{dec_i0_rs1_bypass_en_d[1]}} & lsu_result_m[31:0]          ) |
                                     ({32{dec_i0_rs1_bypass_en_d[2]}} & exu_i0_result_x[31:0]       ) |
                                     ({32{dec_i0_rs1_bypass_en_d[3]}} & lsu_nonblock_load_data[31:0]);

   assign i0_rs2_bypass_data_d[31:0]=({32{dec_i0_rs2_bypass_en_d[0]}} & dec_i0_result_r[31:0]       ) |
                                     ({32{dec_i0_rs2_bypass_en_d[1]}} & lsu_result_m[31:0]          ) |
                                     ({32{dec_i0_rs2_bypass_en_d[2]}} & exu_i0_result_x[31:0]       ) |
                                     ({32{dec_i0_rs2_bypass_en_d[3]}} & lsu_nonblock_load_data[31:0]);


   assign i0_rs1_d[31:0]           = ({32{ i0_rs1_bypass_en_d                                           }}             & i0_rs1_bypass_data_d[31:0]) |
                                     ({32{~i0_rs1_bypass_en_d &  dec_i0_select_pc_d                     }}             & {dec_i0_pc_d[31:1],1'b0}  ) |    // for jal's
                                     ({32{~i0_rs1_bypass_en_d &  dec_debug_wdata_rs1_d                  }}             & dbg_cmd_wrdata[31:0]      ) |
                                     ({32{~i0_rs1_bypass_en_d & ~dec_debug_wdata_rs1_d & dec_i0_rs1_en_d}}             & gpr_i0_rs1_d[31:0]        );

   assign i0_rs2_d[31:0]           = ({32{~i0_rs2_bypass_en_d & dec_i0_rs2_en_d}}                                      & gpr_i0_rs2_d[31:0]        ) |
                                     ({32{~i0_rs2_bypass_en_d                  }}                                      & dec_i0_immed_d[31:0]      ) |
                                     ({32{ i0_rs2_bypass_en_d                  }}                                      & i0_rs2_bypass_data_d[31:0]);


   assign exu_lsu_rs1_d[31:0]      = ({32{~i0_rs1_bypass_en_d & ~dec_extint_stall & dec_i0_rs1_en_d & dec_qual_lsu_d}} & gpr_i0_rs1_d[31:0]        ) |
                                     ({32{ i0_rs1_bypass_en_d & ~dec_extint_stall                   & dec_qual_lsu_d}} & i0_rs1_bypass_data_d[31:0]) |
                                     ({32{                       dec_extint_stall                   & dec_qual_lsu_d}} & {dec_tlu_meihap[31:2],2'b0});
// ...
   assign x_data_en                =  dec_data_en[1];
   assign x_data_en_q1             =  dec_data_en[1] & dec_csr_ren_d;
   assign x_data_en_q2             =  dec_data_en[1] & dec_i0_branch_d;
   assign r_data_en                =  dec_data_en[0];
   assign r_data_en_q2             =  dec_data_en[0] & i0_branch_x;
   assign x_ctl_en                 =  dec_ctl_en[1];
   assign r_ctl_en                 =  dec_ctl_en[0];




   el2_exu_alu_ctl #(.pt(pt)) i_alu  (.*,
                          .enable            ( x_data_en                   ),   // I
                          .pp_in             ( i0_predict_newp_d           ),   // I
                          .valid_in          ( dec_i0_alu_decode_d         ),   // I
                          .flush_upper_x     ( i0_flush_upper_x            ),   // I
                          .flush_lower_r     ( dec_tlu_flush_lower_r       ),   // I
                          .a_in              ( i0_rs1_d[31:0]              ),   // I
                          .b_in              ( i0_rs2_d[31:0]              ),   // I
                          .pc_in             ( dec_i0_pc_d[31:1]           ),   // I
                          .brimm_in          ( dec_i0_br_immed_d[12:1]     ),   // I
                          .ap                ( i0_ap                       ),   // I
                          .csr_ren_in        ( dec_csr_ren_d               ),   // I
                          .csr_rddata_in     ( dec_csr_rddata_d[31:0]      ),   // I
                          .result_ff         ( alu_result_x[31:0]          ),   // O
                          .flush_upper_out   ( i0_flush_upper_d            ),   // O
                          .flush_final_out   ( exu_flush_final             ),   // O
                          .flush_path_out    ( i0_flush_path_d[31:1]       ),   // O
                          .predict_p_out     ( i0_predict_p_d              ),   // O
                          .pred_correct_out  ( i0_pred_correct_upper_d     ),   // O
                          .pc_ff             ( exu_i0_pc_x[31:1]           ));  // O
```

### `design/exu/el2_exu_alu_ctl.sv`

```verilog
   // *** branch handling ***

   assign any_jal             =  ap.jal      |
                                 pp_in.pcall |
                                 pp_in.pja   |
                                 pp_in.pret;

   assign actual_taken        = (ap.beq & eq) |
                                (ap.bne & ne) |
                                (ap.blt & lt) |
                                (ap.bge & ge) |
                                 any_jal;

   // for a conditional br pcout[] will be the opposite of the branch prediction
   // for jal or pcall, it will be the link address pc+2 or pc+4

   rvbradder ibradder (
                     .pc     ( pc_in[31:1]    ),
                     .offset ( brimm_in[12:1] ),
                     .dout   ( pcout[31:1]    ));
```

### `design/lsu/el2_lsu.sv`

```verilog
   // offset should be zero for fast interrupt
   property offset_0_fastint;
      @(posedge clk) disable iff(~rst_l) (lsu_p.valid & lsu_p.fast_int) |-> (dec_lsu_offset_d[11:0] == 12'b0);
   endproperty
```

### `design/lsu/el2_lsu_lsc_ctl.sv`

```verilog
   always_comb begin
      lsu_pkt_d = dec_lsu_valid_raw_d ? lsu_p : dma_pkt_d;
      lsu_pkt_m_in = lsu_pkt_d;
      lsu_pkt_r_in = lsu_pkt_m;

      lsu_pkt_d.valid = (lsu_p.valid & ~(flush_m_up & ~lsu_p.fast_int)) | dma_dccm_req;
      lsu_pkt_m_in.valid = lsu_pkt_d.valid & ~(flush_m_up & ~lsu_pkt_d.dma);
      lsu_pkt_r_in.valid = lsu_pkt_m.valid & ~(flush_m_up & ~lsu_pkt_m.dma) ;
   end
```

### `design/lsu/el2_lsu_bus_buffer.sv`

```verilog
   assign lsu_nonblock_load_inv_r = lsu_nonblock_load_valid_r & ~lsu_commit_r;
   assign lsu_nonblock_load_inv_tag_r[DEPTH_LOG2-1:0] = WrPtr0_r[DEPTH_LOG2-1:0];      // r tag needs to be accurate even if there is no invalidate
```

### `design/dec/el2_dec_tlu_ctl.sv`

```verilog
   assign dec_tlu_flush_extint = take_ext_int_start;
// ...
   assign ext_int_freeze = take_ext_int_start | take_ext_int_start_d1 | take_ext_int_start_d2 | take_ext_int_start_d3;
   assign take_ext_int = take_ext_int_start_d3 & ~|lsu_fir_error[1:0];
// ...
   rvdffie #(12)  excinfo_wb_ff (.*,
                                 .din({interrupt_valid_r, i0_exception_valid_r, exc_or_int_valid_r,
                                       exc_cause_r[4:0], tlu_i0_commit_cmt & ~illegal_r, i0_trigger_hit_r,
                                       take_nmi, pause_expired_r }),
                                 .dout({interrupt_valid_r_d1, i0_exception_valid_r_d1, exc_or_int_valid_r_d1,
                                        exc_cause_wb[4:0], i0_valid_wb, trigger_hit_r_d1,
                                        take_nmi_r_d1, pause_expired_wb}));
// ...
   assign {dec_tlu_i0_valid_wb1,
           dec_tlu_i0_exc_valid_wb1,
           dec_tlu_exc_cause_wb1_raw[4:0],
           dec_tlu_int_valid_wb1_raw}  =   {8{~dec_tlu_trace_disable}} & {i0_valid_wb,
                                                                          i0_exception_valid_r_d1 | lsu_i0_exc_r_d1 | (trigger_hit_r_d1 & ~trigger_hit_dmode_r_d1),
                                                                          exc_cause_wb[4:0],
                                                                          interrupt_valid_r_d1};
```

## Documentation

### `docs/source/power.md`

```text
### Core Pause Control Register (mcpc)

The `mcpc` register supports functions to temporarily stop the core from executing instructions.
This helps to save core power since busy-waiting loops can be avoided in the firmware.

PAUSE stops the core from executing instructions for a specified number [^fn-power-1] of clock ticks or until an interrupt is received.

[^fn-power-1]: The field width provided by the mcpc register allows to pause execution for about 4 seconds at a 1 GHz core clock.

:::{note}
PAUSE is a long-latency, interruptible instruction and does not change the core's activity state (i.e., the core remains in the Running state).
Therefore, even though this function may reduce core power, it is not part of core power management.
:::

:::{note}
PAUSE has a skid of several cycles.
Therefore, instruction execution might not be stopped for precisely the number of cycles specified in the *pause* field of the mcpc register.
However, this is acceptable for the intended use case of this function.
:::

:::{note}
Depending on the *pause_en* bit of the `mitctl0/1` registers, the internal timers might be incremented while executing PAUSE.
If an internal timer interrupt is signaled, PAUSE is terminated and normal execution resumes.
:::

:::{note}
If the PMU sends a halt request while PAUSE is still executing, the core enters the Halted (pmu/fw-halt) state and the *pause* clock counter stops until the core is back in the Running state.
:::
...
The *pause* field of the `mcpc` register has WAR0 (Write Any value, Read 0) behavior, as also indicated in the 'Access' column.

This register is mapped to the non-standard read/write CSR address space.

:::{list-table} Core Pause Control Register (mcpc, at CSR 0x7C2)
:name: tab-core-pause-ctrl-register

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - pause
  - 31:0
  - Pause execution for number of core clock cycles specified
    
    **Note:** *pause* is decremented by 1 for each core clock cycle. Execution continues either when *pause* is 0 or any interrupt is received.
  - R0/W
  - 0
:::
```

### `docs/source/error-protection.md`

```text
:::{list-table} Error Detection, Recovery, and Logging
:name: tab-error-detection-recovery-logging

* - **Memory Type**
  - **Detection**
  - **Recovery**
  - **Recovery**
  - **Logging**
  - **Logging**
* -
  -
  - **Single-bit Error**
  - **Double-bit Error**
  - **Single-bit Error**
  - **Double-bit Error**
...
* - ICCM
  -
    - Each 32-bit chunk protected with 7 ECC bits
    - ECC checked in pipeline
  -
    - For fetches [^fn-error-protection-4]:
      - Write corrected data/ECC back to ICCM
      - Refetch instruction from ICCM [^fn-error-protection-3]
    - For DMA reads:
      - Correct error in-line
      - Write corrected data/ECC back to ICCM
  - Fatal error [^fn-error-protection-5] (uncorrectable)
  -
    - Increment [^fn-error-protection-4] ICCM single- bit error counter
    - If error counter has reached threshold, signal correctable error local interrupt (see [](error-protection.md#iccm-correctable-error-counter-threshold-register-miccmect))
  -
    - For fetches [^fn-error-protection-5]:
      - Instruction access fault exception
    - For DMA reads:
      - Send error response on DMA slave bus to master
```

### `docs/source/memory-map.md`

```text
### Memory Synchronization Trigger Register (dmst)

The `dmst` register provides triggers to force the synchronization of memory accesses. Specifically, it allows a debugger to initiate operations that are equivalent to the `fence.i` (see [](memory-map.md#instructions)) and `fence` (see [](memory-map.md#data)) instructions.

:::{note}
 This register is accessible in **Debug Mode only**. Attempting to access this register in machine mode raises an illegal instruction exception.
:::

The *fence_i* and *fence* fields of the `dmst` register have W1R0 (Write 1, Read 0) behavior, as also indicated in the
'Access' column.

This register is mapped to the non-standard read/write CSR address space.

:::{list-table} Memory Synchronization Trigger Register (dmst, at CSR 0x7C4)
:name: tab-memory-synchronization-trigger-register
:header-rows: 1

* - **Field**
  - **Bits**
  - **Description**
  - **Access**
  - **Reset**
* - Reserved
  - 31:2
  - Reserved
  - R
  - 0
* - fence
  - 1
  - Trigger operation equivalent to `fence` instruction
  - R0/W1
  - 0
* - fence_i
  - 0
  - Trigger operation equivalent to `fence.i` instruction
  - R0/W1
  - 0
:::
```

### `docs/source/interrupts.md`

```text
The VeeR EL2 PIC implementation provides support for vectored external interrupts.
The content of the `meihap` register is a full 32-bit pointer to the specific vector to the handler of the external interrupt source which needs service.
This pointer consists of a 22-bit base address (*base*) of the external interrupt vector table, the 8-bit claim ID (*claimid*), and a 2-bit '0' field.
The *claimid* field is adjusted with 2 bits of zeros to construct the offset into the vector table containing 32-bit vectors.
...
### Fast Interrupt Redirect

VeeR EL2 provides fast interrupt handing through interrupt redirection by hardware.
The fast interrupt redirect feature is configured with a build argument to the core.

If this feature is instantiated, hardware automatically captures a consistent claim ID / priority level pair once at least one qualifying external interrupt is pending and external interrupts are enabled (i.e., the *meie* bit in the `mie` register and the *mie* bit in the `mstatus` register are set).
Following conceptually the same flow as shown in {numref}`fig-vectored-external-interrupts`, hardware uses the content of the meihap register to lookup the start address of the corresponding Interrupt Service Routine (ISR) by stalling decode and creating a bubble in the LSU pipeline.
This bubble allows the core to access the external interrupt vector table in the DCCM to get the start address of the interrupt source-specific ISR.
Once the start address of the ISR is known, hardware creates an interrupt flush and redirects directly to the corresponding ISR.
If the hardware lookup of the ISR's start address fails for any reason, a non-maskable interrupt (NMI, see [](memory-map.md#non-maskable-interrupt-nmi-signal-and-vector)) is taken.
The reason for the lookup failure is reported in the mcause register (see {numref}`tab-machine-cause-register`) so firmware may determine which error condition has occurred.
```

### `src/rv32.adoc`

```text
Return-address prediction stacks are a common feature of
high-performance instruction-fetch units, but require accurate detection
of instructions used for procedure calls and returns to be effective.
For RISC-V, hints as to the instructions' usage are encoded implicitly
via the register numbers used. A JAL instruction should push the return
address onto a return-address stack (RAS) only when _rd_ is 'x1' or
`x5`. JALR instructions should push/pop a RAS as shown in <<rashints>>.

[[rashints]]
.Return-address stack prediction hints encoded in the register operands of a JALR instruction.
[%autowidth,float="center",align="center",cols="^,^,^,<",options="header"]
|===
|_rd_ is _x1/x5_ |_rs1_ is _x1/x5_ |_rd_=_rs1_ |RAS action

|No |No |-- |None

|No |Yes |-- |Pop

|Yes |No |-- |Push

|Yes |Yes |No |Pop, then push

|Yes |Yes |Yes |Push
|===
```

### `src/zicsr.adoc`

```text

=== CSR Instructions

All CSR instructions atomically read-modify-write a single CSR, whose
CSR specifier is encoded in the 12-bit _csr_ field of the instruction
held in bits 31-20. The immediate forms use a 5-bit zero-extended
immediate encoded in the _rs1_ field.

...

The CSRRW (Atomic Read/Write CSR) instruction atomically swaps values in
the CSRs and integer registers. CSRRW reads the old value of the CSR,
zero-extends the value to XLEN bits, then writes it to integer register
_rd_. The initial value in _rs1_ is written to the CSR. If _rd_=`x0`,
then the instruction shall not read the CSR and shall not cause any of
the side effects that might occur on a CSR read.

The CSRRS (Atomic Read and Set Bits in CSR) instruction reads the value
of the CSR, zero-extends the value to XLEN bits, and writes it to
integer register _rd_. The initial value in integer register _rs1_ is
treated as a bit mask that specifies bit positions to be set in the CSR.
Any bit that is high in _rs1_ will cause the corresponding bit to be set
in the CSR, if that CSR bit is writable.

The CSRRC (Atomic Read and Clear Bits in CSR) instruction reads the
value of the CSR, zero-extends the value to XLEN bits, and writes it to
integer register _rd_. The initial value in integer register _rs1_ is
treated as a bit mask that specifies bit positions to be cleared in the
CSR. Any bit that is high in _rs1_ will cause the corresponding bit to
be cleared in the CSR, if that CSR bit is writable.

For both CSRRS and CSRRC, if _rs1_=`x0`, then the instruction will not
write to the CSR at all, and so shall not cause any of the side effects
that might otherwise occur on a CSR write, nor raise illegal-instruction
exceptions on accesses to read-only CSRs. Both CSRRS and CSRRC always
read the addressed CSR and cause any read side effects regardless of
_rs1_ and _rd_ fields.
Note that if _rs1_ specifies a register other than `x0`, and that register
holds a zero value, the instruction will not action any attendant per-field
side effects, but will action any side effects caused by writing to the entire
CSR.

A CSRRW with _rs1_=`x0` will attempt to write zero to the destination CSR.
```

## Additional requirement

For a 2-byte instruction, `dec_i0_inst_wb` reports `ifu_i0_cinst` zero-extended to 32 bits.
