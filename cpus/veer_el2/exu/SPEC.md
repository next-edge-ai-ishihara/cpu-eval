# Implement `el2_exu`

Implement the complete `el2_exu` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module el2_exu` definition in a single SystemVerilog code block, with no text outside the block.

## Package and imports

```verilog
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

```

## Module declaration

```verilog
module el2_exu
import el2_pkg::*;
#(
`include "el2_param.vh"
)
  (
   input logic          clk,                                           // Top level clock
   input logic          rst_l,                                         // Reset
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic          scan_mode,                                     // Scan control
   /*pragma coverage on*/

   input logic  [1:0]   dec_data_en,                                   // Clock enable {x,r}, one cycle pulse
   input logic  [1:0]   dec_ctl_en,                                    // Clock enable {x,r}, two cycle pulse
   input logic  [31:0]  dbg_cmd_wrdata,                                // Debug data   to primary I0 RS1
   input el2_alu_pkt_t i0_ap,                                         // DEC alu {valid,predecodes}

   input logic          dec_debug_wdata_rs1_d,                         // Debug select to primary I0 RS1

   input el2_predict_pkt_t dec_i0_predict_p_d,                        // DEC branch predict packet
   input logic [pt.BHT_GHR_SIZE-1:0] i0_predict_fghr_d,                // DEC predict fghr
   input logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] i0_predict_index_d,     // DEC predict index
   input logic [pt.BTB_BTAG_SIZE-1:0] i0_predict_btag_d,               // DEC predict branch tag

   input logic  [31:0]  lsu_result_m,                                  // Load result M-stage
   input logic  [31:0]  lsu_nonblock_load_data,                        // nonblock load data
   input logic          dec_i0_rs1_en_d,                               // Qualify GPR RS1 data
   input logic          dec_i0_rs2_en_d,                               // Qualify GPR RS2 data
   input logic  [31:0]  gpr_i0_rs1_d,                                  // DEC data gpr
   input logic  [31:0]  gpr_i0_rs2_d,                                  // DEC data gpr
   input logic  [31:0]  dec_i0_immed_d,                                // DEC data immediate
   input logic  [31:0]  dec_i0_result_r,                               // DEC result in R-stage
   input logic  [12:1]  dec_i0_br_immed_d,                             // Branch immediate
   input logic          dec_i0_alu_decode_d,                           // Valid to X-stage ALU
   input logic          dec_i0_branch_d,                               // Branch in D-stage
   input logic          dec_i0_select_pc_d,                            // PC select to RS1
   input logic  [31:1]  dec_i0_pc_d,                                   // Instruction PC
   input logic  [3:0]   dec_i0_rs1_bypass_en_d,                        // DEC bypass select  1 - X-stage, 0 - dec bypass data
   input logic  [3:0]   dec_i0_rs2_bypass_en_d,                        // DEC bypass select  1 - X-stage, 0 - dec bypass data
   input logic          dec_csr_ren_d,                                 // CSR read select
   input logic  [31:0]  dec_csr_rddata_d,                              // CSR read data

   input logic          dec_qual_lsu_d,                                // LSU instruction at D.  Use to quiet LSU operands
   input el2_mul_pkt_t mul_p,                                         // DEC {valid, operand signs, low, operand bypass}
   input el2_div_pkt_t div_p,                                         // DEC {valid, unsigned, rem}
   input logic          dec_div_cancel,                                // Cancel the divide operation

   input logic  [31:1]  pred_correct_npc_x,                            // DEC NPC for correctly predicted branch

   input logic          dec_tlu_flush_lower_r,                         // Flush divide and secondary ALUs
   input logic  [31:1]  dec_tlu_flush_path_r,                          // Redirect target


   input logic         dec_extint_stall,                               // External stall mux select
   input logic [31:2]  dec_tlu_meihap,                                 // External stall mux data


   output logic [31:0]  exu_lsu_rs1_d,                                 // LSU operand
   output logic [31:0]  exu_lsu_rs2_d,                                 // LSU operand

   output logic         exu_flush_final,                               // Pipe is being flushed this cycle
   output logic [31:1]  exu_flush_path_final,                          // Target for the oldest flush source

   output logic [31:0]  exu_i0_result_x,                               // Primary ALU result to DEC
   output logic [31:1]  exu_i0_pc_x,                                   // Primary PC  result to DEC
   output logic [31:0]  exu_csr_rs1_x,                                 // RS1 source for a CSR instruction

   output logic [31:1]  exu_npc_r,                                     // Divide NPC
   output logic [1:0]   exu_i0_br_hist_r,                              // to DEC  I0 branch history
   output logic         exu_i0_br_error_r,                             // to DEC  I0 branch error
   output logic         exu_i0_br_start_error_r,                       // to DEC  I0 branch start error
   output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] exu_i0_br_index_r,     // to DEC  I0 branch index
   output logic         exu_i0_br_valid_r,                             // to DEC  I0 branch valid
   output logic         exu_i0_br_mp_r,                                // to DEC  I0 branch mispredict
   output logic         exu_i0_br_middle_r,                            // to DEC  I0 branch middle
   output logic [pt.BHT_GHR_SIZE-1:0]  exu_i0_br_fghr_r,               // to DEC  I0 branch fghr
   output logic         exu_i0_br_way_r,                               // to DEC  I0 branch way

   output el2_predict_pkt_t exu_mp_pkt,                               // Mispredict branch packet
   output logic [pt.BHT_GHR_SIZE-1:0]  exu_mp_eghr,                    // Mispredict global history
   output logic [pt.BHT_GHR_SIZE-1:0]  exu_mp_fghr,                    // Mispredict fghr
   output logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO]  exu_mp_index,         // Mispredict index
   output logic [pt.BTB_BTAG_SIZE-1:0]  exu_mp_btag,                   // Mispredict btag


   output logic         exu_pmu_i0_br_misp,                            // to PMU - I0 E4 branch mispredict
   output logic         exu_pmu_i0_br_ataken,                          // to PMU - I0 E4 taken
   output logic         exu_pmu_i0_pc4,                                // to PMU - I0 E4 PC


   output logic [31:0]  exu_div_result,                                // Divide result
   output logic         exu_div_wren                                   // Divide write enable to GPR
  );

```

## Parent instantiation

### design/el2_veer.sv

```verilog
   el2_exu #(.pt(pt)) exu (
                            .clk(active_l2clk),
                            .rst_l(core_rst_l),
                            .*
                            );

```

## Dependency declarations

### design/exu/el2_exu_alu_ctl.sv

```verilog
module el2_exu_alu_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
)
  (
   input  logic                  clk,                // Top level clock
   input  logic                  rst_l,              // Reset
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic                  scan_mode,          // Scan control
   /*pragma coverage on*/

   input  logic                  flush_upper_x,      // Branch flush from previous cycle
   input  logic                  flush_lower_r,      // Master flush of entire pipeline
   input  logic                  enable,             // Clock enable
   input  logic                  valid_in,           // Valid
   input  el2_alu_pkt_t         ap,                 // predecodes
   input  logic                  csr_ren_in,         // CSR select
   input  logic        [31:0]    csr_rddata_in,      // CSR data
   input  logic signed [31:0]    a_in,               // A operand
   input  logic        [31:0]    b_in,               // B operand
   input  logic        [31:1]    pc_in,              // for pc=pc+2,4 calculations
   input  el2_predict_pkt_t     pp_in,              // Predicted branch structure
   input  logic        [12:1]    brimm_in,           // Branch offset


   output logic        [31:0]    result_ff,          // final result
   output logic                  flush_upper_out,    // Branch flush
   output logic                  flush_final_out,    // Branch flush or flush entire pipeline
   output logic        [31:1]    flush_path_out,     // Branch flush PC
   output logic        [31:1]    pc_ff,              // flopped PC
   output logic                  pred_correct_out,   // NPC control
   output el2_predict_pkt_t     predict_p_out       // Predicted branch structure
  );

```

### design/exu/el2_exu_div_ctl.sv

```verilog
module el2_exu_div_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
)
  (
   input logic           clk,                       // Top level clock
   input logic           rst_l,                     // Reset
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic           scan_mode,                 // Scan mode
   /*pragma coverage on*/

   input el2_div_pkt_t  dp,                        // valid, sign, rem
   input logic  [31:0]   dividend,                  // Numerator
   input logic  [31:0]   divisor,                   // Denominator

   input logic           cancel,                    // Cancel divide


   output logic          finish_dly,                // Finish to match data
   output logic [31:0]   out                        // Result
  );

```

### design/exu/el2_exu_mul_ctl.sv

```verilog
module el2_exu_mul_ctl
import el2_pkg::*;
#(
`include "el2_param.vh"
 )
  (
   input logic          clk,              // Top level clock
   input logic          rst_l,            // Reset
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input logic          scan_mode,        // Scan mode
   /*pragma coverage on*/

   input el2_mul_pkt_t mul_p,            // {Valid, RS1 signed operand, RS2 signed operand, Select low 32-bits of result}

   input logic [31:0]   rs1_in,           // A operand
   input logic [31:0]   rs2_in,           // B operand


   output logic [31:0]  result_x          // Result
  );

```

### design/lib/beh_lib.sv

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

module rvdffppe #( parameter integer WIDTH = 39 )
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

   localparam integer RIGHT = 31;
   localparam integer LEFT  = WIDTH - RIGHT;

// ...
`ifndef RV_PHYSICAL
   if (WIDTH>=32 && LEFT>=8 && RIGHT>=8) begin: genblock
`endif

// ...
`ifndef RV_PHYSICAL
   end
   else
      $error("%m: must be WIDTH>=32 && LEFT>=8 && RIGHT>=8");
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

```

## Related source code

### design/dec/el2_dec_decode_ctl.sv

```verilog
// order the producers as follows:  , i0_x, i0_r, i0_wb

   assign {i0_rs1_class_d, i0_rs1_depth_d[1:0]} = (i0_rs1_depend_i0_x ) ? { i0_x_c,  2'd1  } :
                                                  (i0_rs1_depend_i0_r ) ? { i0_r_c,  2'd2  } : '0;

   assign {i0_rs2_class_d, i0_rs2_depth_d[1:0]} = (i0_rs2_depend_i0_x ) ? { i0_x_c,  2'd1  } :
                                                  (i0_rs2_depend_i0_r ) ? { i0_r_c,  2'd2  } : '0;

   // ...

   // add nonblock load rs1/rs2 bypass cases

   assign i0_rs1_nonblock_load_bypass_en_d  = dec_i0_rs1_en_d & dec_nonblock_load_wen & (dec_nonblock_load_waddr[4:0] == i0r.rs1[4:0]);

   assign i0_rs2_nonblock_load_bypass_en_d  = dec_i0_rs2_en_d & dec_nonblock_load_wen & (dec_nonblock_load_waddr[4:0] == i0r.rs2[4:0]);



   // bit 2 is priority match, bit 0 lowest priority, i0_x, i0_r

   assign i0_rs1bypass[2]                =  i0_rs1_depth_d[0] & (i0_rs1_class_d.alu | i0_rs1_class_d.mul                      );
   assign i0_rs1bypass[1]                =  i0_rs1_depth_d[0] & (                                          i0_rs1_class_d.load);
   assign i0_rs1bypass[0]                =  i0_rs1_depth_d[1] & (i0_rs1_class_d.alu | i0_rs1_class_d.mul | i0_rs1_class_d.load);

   assign i0_rs2bypass[2]                =  i0_rs2_depth_d[0] & (i0_rs2_class_d.alu | i0_rs2_class_d.mul                      );
   assign i0_rs2bypass[1]                =  i0_rs2_depth_d[0] & (                                          i0_rs2_class_d.load);
   assign i0_rs2bypass[0]                =  i0_rs2_depth_d[1] & (i0_rs2_class_d.alu | i0_rs2_class_d.mul | i0_rs2_class_d.load);


   assign dec_i0_rs1_bypass_en_d[3]      =  i0_rs1_nonblock_load_bypass_en_d & ~i0_rs1bypass[0] & ~i0_rs1bypass[1] & ~i0_rs1bypass[2];
   assign dec_i0_rs1_bypass_en_d[2]      =  i0_rs1bypass[2];
   assign dec_i0_rs1_bypass_en_d[1]      =  i0_rs1bypass[1];
   assign dec_i0_rs1_bypass_en_d[0]      =  i0_rs1bypass[0];

   assign dec_i0_rs2_bypass_en_d[3]      =  i0_rs2_nonblock_load_bypass_en_d & ~i0_rs2bypass[0] & ~i0_rs2bypass[1] & ~i0_rs2bypass[2];
   assign dec_i0_rs2_bypass_en_d[2]      =  i0_rs2bypass[2];
   assign dec_i0_rs2_bypass_en_d[1]      =  i0_rs2bypass[1];
   assign dec_i0_rs2_bypass_en_d[0]      =  i0_rs2bypass[0];

```

## Documentation

### docs/source/overview.md

```markdown
### Core

{numref}`fig-core-pipeline` depicts the scalar 4-stage core with one execution pipeline, one load/store pipeline, one multiplier pipeline, and one out-of-pipeline divider. There are two stall points in the pipeline: 'Fetch' and 'Decode'. The diagram also shows how VeeR EH1's logic stages have been shifted up and merged into 4 stages named Fetch (F), Decode (D), Execute/Memory (X/M), and Retire (R). Also shown is additional logic such as a new branch adder in the D stage. The branch mispredict penalty is either 1 or 2 cycles in VeeR EL2.

The merged F stage performs the program counter calculation and the I-cache/ICCM memory access in parallel. The load pipeline has been moved up so that the DC1 memory address generation (AGU) logic is now combined with align and decode logic to enable a DCCM memory access to start at the beginning of the M stage. The design supports a load-to-use of 1 cycle for smaller memories and a load-to-use of 2 cycles for larger memories. For 1-cycle load-to-use, the memory is accessed and the load data aligned and formatted for the register file and forwarding paths, all in the single-cycle M stage. For 2-cycle load-to-use, almost the entire M stage is allocated to the memory access, and the DC3/DC4 logic combined into the R stage is used to perform the load align and formatting for the register file and forwarding paths. EX3 and EX4/WB are combined into the R stage and primarily used for commit and writeback to update the architectural registers.

```
