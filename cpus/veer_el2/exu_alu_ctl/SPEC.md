# Implement `el2_exu_alu_ctl`

Implement the complete `el2_exu_alu_ctl` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module el2_exu_alu_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

```text
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

```

## Module declaration

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

## Parent instantiation

### design/exu/el2_exu.sv

```verilog
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

## Dependency declarations

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

module rvbradder
  (
    input [31:1] pc,
    input [12:1] offset,

    output [31:1] dout
    );

```

## Related source code

### design/dec/el2_dec_decode_ctl.sv

```verilog
   assign i0_predict_br =  i0_dp.condbr | i0_pcall | i0_pja | i0_pret;

   assign i0_predict_nt = ~(dec_i0_brp.hist[1] & i0_brp_valid) & i0_predict_br;
   assign i0_predict_t  =  (dec_i0_brp.hist[1] & i0_brp_valid) & i0_predict_br;

   // ...

   assign i0_ap.csr_write =  i0_csr_write_only_d;
   assign i0_ap.csr_imm   =  i0_dp.csr_imm;
   assign i0_ap.jal       =  i0_jal;

   assign i0_ap_pc2 = ~dec_i0_pc4_d;
   assign i0_ap_pc4 =  dec_i0_pc4_d;

   assign i0_ap.predict_nt = i0_predict_nt;
   assign i0_ap.predict_t  = i0_predict_t;

   // ...

   assign i0_pcall_case  = i0_pcall_12b_offset & i0_dp_raw.imm20 &  (i0r.rd[4:0] == 5'd1 | i0r.rd[4:0] == 5'd5);
   assign i0_pja_case    = i0_pcall_12b_offset & i0_dp_raw.imm20 & ~(i0r.rd[4:0] == 5'd1 | i0r.rd[4:0] == 5'd5);

   assign i0_pcall_raw   = i0_dp_raw.jal &   i0_pcall_case;   // this includes ja
   assign i0_pcall       = i0_dp.jal     &   i0_pcall_case;

   assign i0_pja_raw     = i0_dp_raw.jal &   i0_pja_case;
   assign i0_pja         = i0_dp.jal     &   i0_pja_case;


   assign i0_br_offset[11:0] = (i0_pcall_raw | i0_pja_raw) ? i0_pcall_imm[12:1] : {i0[31],i0[7],i0[30:25],i0[11:8]};

   assign i0_pret_case = (i0_dp_raw.jal & i0_dp_raw.imm12 & (i0r.rd[4:0] == 5'b0) & (i0r.rs1[4:0] == 5'd1 | i0r.rs1[4:0] == 5'd5));  // jalr with rd==0, rs1==1 or rs1==5 is a ret

   assign i0_pret_raw = i0_dp_raw.jal &   i0_pret_case;
   assign i0_pret     = i0_dp.jal     &   i0_pret_case;

   assign i0_jal      = i0_dp.jal     &  ~i0_pcall_case & ~i0_pja_case & ~i0_pret_case;

   // ...

   assign i0_csr_write_only_d = i0_csr_write & ~i0_dp.csr_read;

   // ...

   // for csr write only data is produced by the alu
   assign dec_csr_wrdata_r[31:0]  = (r_d.csrwonly & r_d.i0valid) ? i0_result_corr_r[31:0] : write_csr_data[31:0];

   // ...

   // all conditional branches are currently predict_nt
   // change this to generate the sequential address for all other cases for NPC requirements at commit
   assign dec_i0_br_immed_d[12:1] = (i0_ap.predict_nt & ~i0_dp.jal) ? i0_br_offset[11:0] : {10'b0,i0_ap_pc4,i0_ap_pc2};

```

### design/dec/decode

```text
.decode

rv32i[clz]       =  { alu zbb     rs1     rd                       clz   }
rv32i[ctz]       =  { alu zbb     rs1     rd                       ctz   }
rv32i[cpop]      =  { alu zbb     rs1     rd                       cpop  }
rv32i[sext_b]    =  { alu zbb     rs1     rd                       sext_b}
rv32i[sext_h]    =  { alu zbb     rs1     rd                       sext_h}
rv32i[min]       =  { alu zbb     rs1 rs2 rd                sub    min   }
rv32i[max]       =  { alu zbb     rs1 rs2 rd                sub    max   }
rv32i[minu]      =  { alu zbb     rs1 rs2 rd  unsign        sub    min   }
rv32i[maxu]      =  { alu zbb     rs1 rs2 rd  unsign        sub    max   }
rv32i[andn]      =  { alu zbb zbp rs1 rs2 rd                       land  }
rv32i[orn]       =  { alu zbb zbp rs1 rs2 rd                       lor   }
rv32i[xnor]      =  { alu zbb zbp rs1 rs2 rd                       lxor  }
rv32i[packu]     =  { alu     zbp rs1 rs2 rd                       packu }
rv32i[packh]     =  { alu     zbp rs1 rs2 rd                       packh zbe zbf}
rv32i[rol]       =  { alu zbb zbp rs1 rs2 rd                       rol   }
rv32i[ror]       =  { alu zbb zbp rs1 rs2 rd                       ror   }
rv32i[rori]      =  { alu zbb zbp rs1     rd         shimm5        ror   }
rv32i[bset]      =  { alu zbs     rs1 rs2 rd                       bset  }
rv32i[bclr]      =  { alu zbs     rs1 rs2 rd                       bclr  }
rv32i[binv]      =  { alu zbs     rs1 rs2 rd                       binv  }
rv32i[bext]      =  { alu zbs     rs1 rs2 rd                       bext  }
rv32i[bseti]     =  { alu zbs     rs1     rd         shimm5        bset  }
rv32i[bclri]     =  { alu zbs     rs1     rd         shimm5        bclr  }
rv32i[binvi]     =  { alu zbs     rs1     rd         shimm5        binv  }
rv32i[bexti]     =  { alu zbs     rs1     rd         shimm5        bext  }
rv32i[sh1add]    =  { alu zba     rs1 rs2 rd                       sh1add}
rv32i[sh2add]    =  { alu zba     rs1 rs2 rd                       sh2add}
rv32i[sh3add]    =  { alu zba     rs1 rs2 rd                       sh3add}

#v32i[pack]      =  { alu     zbp rs1 rs2 rd                       pack  zbe zbf}
rv32i[zext_h]    =  { alu zbb zbp rs1 rs2 rd                       pack  zbe zbf}   # pack with rs2=x0
rv32i[pack{1-31}]=  { alu     zbp rs1 rs2 rd                       pack  zbe zbf}

...

rv32i[rev8]          =  { alu zbb zbp rs1     rd         shimm5        grev  } # grevi24

rv32i[gorc]          =  { mul     zbp rs1 rs2 rd                       gorc  }

rv32i[gorci{0-6}]    =  { mul     zbp rs1     rd         shimm5        gorc  }
rv32i[gorci{8-31}]   =  { mul     zbp rs1     rd         shimm5        gorc  }

rv32i[orc_b]         =  { alu zbb zbp rs1     rd         shimm5        gorc  }  # gorci7

...

rv32i[add]       =  { alu rs1 rs2   rd add pm_alu }
rv32i[addi]      =  { alu rs1 imm12 rd add pm_alu }

rv32i[sub]       =  { alu rs1 rs2   rd sub pm_alu }

rv32i[and]       =  { alu rs1 rs2   rd land pm_alu }
rv32i[andi]      =  { alu rs1 imm12 rd land pm_alu }

rv32i[or]        =  { alu rs1 rs2   rd lor pm_alu }
rv32i[ori]       =  { alu rs1 imm12 rd lor pm_alu }

rv32i[xor]       =  { alu rs1 rs2   rd lxor pm_alu }
rv32i[xori]      =  { alu rs1 imm12 rd lxor pm_alu }

rv32i[sll]       =  { alu rs1 rs2    rd sll pm_alu }
rv32i[slli]      =  { alu rs1 shimm5 rd sll pm_alu }

rv32i[sra]       =  { alu rs1 rs2    rd sra pm_alu }
rv32i[srai]      =  { alu rs1 shimm5 rd sra pm_alu }

rv32i[srl]       =  { alu rs1 rs2    rd srl pm_alu }
rv32i[srli]      =  { alu rs1 shimm5 rd srl pm_alu }

rv32i[lui]       =  { alu imm20    rd lor pm_alu }
rv32i[auipc]     =  { alu imm20 pc rd add pm_alu }


rv32i[slt]    =     { alu rs1 rs2    rd sub slt        pm_alu }
rv32i[sltu]    =    { alu rs1 rs2    rd sub slt unsign pm_alu }
rv32i[slti]    =    { alu rs1 imm12  rd sub slt        pm_alu }
rv32i[sltiu]    =   { alu rs1 imm12  rd sub slt unsign pm_alu }

rv32i[beq]    =     { alu rs1 rs2 sub condbr beq }
rv32i[bne]    =     { alu rs1 rs2 sub condbr bne }
rv32i[bge]    =     { alu rs1 rs2 sub condbr bge }
rv32i[blt]    =     { alu rs1 rs2 sub condbr blt }
rv32i[bgeu]    =    { alu rs1 rs2 sub condbr bge unsign }
rv32i[bltu]    =    { alu rs1 rs2 sub condbr blt unsign }

rv32i[jal]    =     { alu imm20 rd pc    jal }
rv32i[jalr]    =    { alu rs1   rd imm12 jal }



rv32i[lb] =      { lsu load rs1 rd by    }
rv32i[lh] =      { lsu load rs1 rd half  }
rv32i[lw] =      { lsu load rs1 rd word  }
rv32i[lbu] =     { lsu load rs1 rd by   unsign  }
rv32i[lhu] =     { lsu load rs1 rd half unsign  }

rv32i[sb] =      { lsu store rs1 rs2 by   }
rv32i[sh] =      { lsu store rs1 rs2 half }
rv32i[sw] =      { lsu store rs1 rs2 word }


rv32i[fence] =   { alu lor fence presync}

# fence.i has fence effect in addtion to flush I$ and redirect
rv32i[fence.i] = { alu lor fence fence_i presync postsync}

# nops for now

rv32i[ebreak] = {  alu rs1 imm12 rd lor ebreak postsync}
rv32i[ecall] =  {  alu rs1 imm12 rd lor ecall  postsync}
rv32i[mret] =   {  alu rs1 imm12 rd lor mret   postsync}

rv32i[wfi] =    {  alu rs1 imm12 rd lor pm_alu }

# csr means read

# csr_read - put csr on rs2 and rs1 0's
rv32i[csrrc_ro] =        { alu rd csr_read }

# put csr on rs2 and make rs1 0's into alu.  Save rs1 for csr_clr later
rv32i[csrrc_rw{0-4}] =   { alu rd csr_read rs1 csr_clr            presync postsync }

rv32i[csrrci_ro] =       { alu rd csr_read }

rv32i[csrrci_rw{0-4}] =  { alu rd csr_read rs1 csr_clr   csr_imm  presync postsync }

rv32i[csrrs_ro] =        { alu rd csr_read }

rv32i[csrrs_rw{0-4}] =   { alu rd csr_read rs1 csr_set            presync postsync }

rv32i[csrrsi_ro] =       { alu rd csr_read }

rv32i[csrrsi_rw{0-4}] =  { alu rd csr_read rs1 csr_set   csr_imm presync postsync }

rv32i[csrrw{0-4}] =     { alu rd csr_read rs1 csr_write         presync postsync }


rv32i[csrrwi{0-4}] =         { alu rd csr_read rs1 csr_write csr_imm presync postsync }

# optimize csr write only - pipelined
rv32i[csrw] =                { alu rd rs1 csr_write           }

rv32i[csrwi]       =         { alu rd     csr_write csr_imm   }

```

## Documentation

### docs/source/overview.md

```text
## Functional Blocks

The VeeR EL2 core complex's functional blocks are described in the following sections in more detail.

### Core

{numref}`fig-core-pipeline` depicts the scalar 4-stage core with one execution pipeline, one load/store pipeline, one multiplier pipeline, and one out-of-pipeline divider. There are two stall points in the pipeline: 'Fetch' and 'Decode'. The diagram also shows how VeeR EH1's logic stages have been shifted up and merged into 4 stages named Fetch (F), Decode (D), Execute/Memory (X/M), and Retire (R). Also shown is additional logic such as a new branch adder in the D stage. The branch mispredict penalty is either 1 or 2 cycles in VeeR EL2.

The merged F stage performs the program counter calculation and the I-cache/ICCM memory access in parallel. The load pipeline has been moved up so that the DC1 memory address generation (AGU) logic is now combined with align and decode logic to enable a DCCM memory access to start at the beginning of the M stage. The design supports a load-to-use of 1 cycle for smaller memories and a load-to-use of 2 cycles for larger memories. For 1-cycle load-to-use, the memory is accessed and the load data aligned and formatted for the register file and forwarding paths, all in the single-cycle M stage. For 2-cycle load-to-use, almost the entire M stage is allocated to the memory access, and the DC3/DC4 logic combined into the R stage is used to perform the load align and formatting for the register file and forwarding paths. EX3 and EX4/WB are combined into the R stage and primarily used for commit and writeback to update the architectural registers.

:::{figure-md} fig-core-pipeline
![VeeR EL2 Core Pipeline](img/core_pipeline.png)

VeeR EL2 Core Pipeline
:::

## Standard Extensions

The VeeR EL2 core implements the following RISC-V standard extensions:

:::{list-table} VeeR EL2's RISC-V Standard Extensions
:name: tab-riscv-std-ext
:header-rows: 1

* - Extension
  - Description
  - References
* - M
  - Integer multiplication and division
  - Chapter 7 in [[1]](intro.md#ref-1)
* - C
  - Compressed instructions
  - Chapter 16 in [[1]](intro.md#ref-1)
* - Zicsr
  - Control and status register (CSR) instructions
  - Chapter 9 in [[1]](intro.md#ref-1)
* - Zifencei
  - Instruction-fetch fence
  - Chapter 3 in [[1]](intro.md#ref-1)
* - Zba [^fn-standard-extensions-1] (address calculation) (frozen)
  - Bit manipulation instructions
  - Chapter 2 in [[4]](intro.md#ref-4)
* - Zbb [^fn-standard-extensions-2] (base) (frozen)
  - Bit manipulation instructions
  - Chapter 2 in [[4]](intro.md#ref-4)
* - Zbc [^fn-standard-extensions-3] (carry-less multiply) (frozen)
  - Bit manipulation instructions
  - Chapter 2 in [[4]](intro.md#ref-4)
* - Zbs [^fn-standard-extensions-4] (single-bit) (frozen)
  - Bit manipulation instructions
  - Chapter 2 in [[4]](intro.md#ref-4)
* - Zbe [^fn-standard-extensions-5] (bit compress/ decompress) (stable)
  - Bit manipulation instructions
  - Chapter 2 in [[4]](intro.md#ref-4)
* - Zbf [^fn-standard-extensions-6] (bit-field place) (stable)
  - Bit manipulation instructions
  - Chapter 2 in [[4]](intro.md#ref-4)
* - Zbp [^fn-standard-extensions-7] (bit permutation) (stable)
  - Bit manipulation instructions
  - Chapter 2 in [[4]](intro.md#ref-4)
* - Zbr [^fn-standard-extensions-8] (CRC) (stable)
  - Bit manipulation instructions
  - Chapter 2 in [[4]](intro.md#ref-4)
:::

* `frozen` specified means that the extensions are not expected to change.
* `stable` mean that the marked extension may still change.

[^fn-standard-extensions-1]: List of Zba instructions (as of 1/20/21, "frozen"): sh1add, sh2add, sh3add
[^fn-standard-extensions-2]: List of Zbb instructions (as of 1/20/21, "frozen"): clz, ctz, cpop, min, minu, max, maxu, sext.b, sext.h, zext.h, andn, orn, xnor, rol, ror, rori, rev8, orc.b
[^fn-standard-extensions-3]: List of Zbc instructions (as of 1/20/21, "frozen"): clmul, clmulh, clmulr
[^fn-standard-extensions-4]: List of Zbs instructions (as of 1/20/21, "frozen"): bset, bseti, bclr, bclri, binv, binvi, bext, bexti
[^fn-standard-extensions-5]: List of Zbe instructions (as of 1/20/21, "stable"): bcompress, bdecompress, pack, packh
[^fn-standard-extensions-6]: List of Zbf instructions (as of 1/20/21, "stable"): bfp, pack, packh
[^fn-standard-extensions-7]: List of Zbp instructions (as of 1/20/21, "stable"): andn, orn, xnor, pack, packu, packh, rol, ror, rori, grev, grevi, gorc, gorci, shfl, shfli, unshfl, unshfli, xperm.n, xperm.b, xperm.h
[^fn-standard-extensions-8]: List of Zbr instructions (as of 1/20/21, "stable"): crc32.b, crc32c.b, crc32.h, crc32c.h, crc32.w, crc32c.w

```

### src/rv32.adoc

```text
==== Integer Register-Immediate Instructions

include::images/wavedrom/integer-computational.edn[]
//.Integer Computational Instructions

ADDI adds the sign-extended 12-bit immediate to register _rs1_.
Arithmetic overflow is ignored and the result is simply the low XLEN
bits of the result. ADDI _rd, rs1, 0_ is used to implement the MV _rd,
rs1_ assembler pseudoinstruction.

SLTI (set less than immediate) places the value 1 in register _rd_ if
register _rs1_ is less than the sign-extended immediate when both are
treated as signed numbers, else 0 is written to _rd_. SLTIU is similar
but compares the values as unsigned numbers (i.e., the immediate is
first sign-extended to XLEN bits then treated as an unsigned number).
Note, SLTIU _rd, rs1, 1_ sets _rd_ to 1 if _rs1_ equals zero, otherwise
sets _rd_ to 0 (assembler pseudoinstruction SEQZ _rd, rs_).

ANDI, ORI, XORI are logical operations that perform bitwise AND, OR, and
XOR on register _rs1_ and the sign-extended 12-bit immediate and place
the result in _rd_. Note, XORI _rd, rs1, -1_ performs a bitwise logical
inversion of register _rs1_ (assembler pseudoinstruction NOT _rd, rs_).

include::images/wavedrom/int-comp-slli-srli-srai.edn[]
[[int-comp-slli-srli-srai]]
//.Integer register-immediate, SLLI, SRLI, SRAI

Shifts by a constant are encoded as a specialization of the I-type
format. The operand to be shifted is in _rs1_, and the shift amount is
encoded in the lower 5 bits of the I-immediate field. The right shift
type is encoded in bit 30. SLLI is a logical left shift (zeros are
shifted into the lower bits); SRLI is a logical right shift (zeros are
shifted into the upper bits); and SRAI is an arithmetic right shift (the
original sign bit is copied into the vacated upper bits).

include::images/wavedrom/int-comp-lui-aiupc.edn[]
[[int-comp-lui-aiupc]]
//.Integer register-immediate, U-immediate

LUI (load upper immediate) is used to build 32-bit constants and uses
the U-type format. LUI places the 32-bit U-immediate value into the
destination register _rd_, filling in the lowest 12 bits with zeros.

AUIPC (add upper immediate to `pc`) is used to build `pc`-relative
addresses and uses the U-type format. AUIPC forms a 32-bit offset from
the U-immediate, filling in the lowest 12 bits with zeros, adds this
offset to the address of the AUIPC instruction, then places the result
in register _rd_.

[NOTE]
====
The assembly syntax for `lui` and `auipc` does not represent the lower
12 bits of the U-immediate, which are always zero.

The AUIPC instruction supports two-instruction sequences to access
arbitrary offsets from the PC for both control-flow transfers and data
accesses. The combination of an AUIPC and the 12-bit immediate in a JALR
can transfer control to any 32-bit PC-relative address, while an AUIPC
plus the 12-bit immediate offset in regular load or store instructions
can access any 32-bit PC-relative data address.

The current PC can be obtained by setting the U-immediate to 0. Although
a JAL +4 instruction could also be used to obtain the local PC (of the
instruction following the JAL), it might cause pipeline breaks in
simpler microarchitectures or pollute BTB structures in more complex
microarchitectures.
====

==== Integer Register-Register Operations

RV32I defines several arithmetic R-type operations. All operations read
the _rs1_ and _rs2_ registers as source operands and write the result
into register _rd_. The _funct7_ and _funct3_ fields select the type of
operation.

include::images/wavedrom/int-reg-reg.edn[]
[[int-reg-reg]]
//.Integer register-register

ADD performs the addition of _rs1_ and _rs2_. SUB performs the
subtraction of _rs2_ from _rs1_. Overflows are ignored and the low XLEN
bits of results are written to the destination _rd_. SLT and SLTU
perform signed and unsigned compares respectively, writing 1 to _rd_ if
_rs1_ < _rs2_, 0 otherwise. Note, SLTU _rd_, _x0_, _rs2_ sets _rd_ to 1 if
_rs2_ is not equal to zero, otherwise sets _rd_ to zero (assembler
pseudoinstruction SNEZ _rd, rs_). AND, OR, and XOR perform bitwise
logical operations.

SLL, SRL, and SRA perform logical left, logical right, and arithmetic
right shifts on the value in register _rs1_ by the shift amount held in
the lower 5 bits of register _rs2_.

==== NOP Instruction

include::images/wavedrom/nop.edn[]
[[nop]]
//.NOP instructions

The NOP instruction does not change any architecturally visible state,
except for advancing the `pc` and incrementing any applicable
performance counters. NOP is encoded as ADDI _x0, x0, 0_.

[NOTE]
====
NOPs can be used to align code segments to microarchitecturally
significant address boundaries, or to leave space for inline code
modifications. Although there are many possible ways to encode a NOP, we
define a canonical NOP encoding to allow microarchitectural
optimizations as well as for more readable disassembly output. The other
NOP encodings are made available for <<rv32i-hints>>.

ADDI was chosen for the NOP encoding as this is most likely to take
fewest resources to execute across a range of systems (if not optimized
away in decode). In particular, the instruction only reads one register.
Also, an ADDI functional unit is more likely to be available in a
superscalar design as adds are the most common operation. In particular,
address-generation functional units can execute ADDI using the same
hardware needed for base+offset address calculations, while
register-register ADD or logical/shift operations require additional
hardware.
====

=== Control Transfer Instructions
RV32I provides two types of control transfer instructions: unconditional
jumps and conditional branches. Control transfer instructions in RV32I
do _not_ have architecturally visible delay slots.

If an instruction access-fault or instruction page-fault exception
occurs on the target of a jump or taken branch, the exception is
reported on the target instruction, not on the jump or branch
instruction.

==== Unconditional Jumps
The jump and link (JAL) instruction uses the J-type format, where the
J-immediate encodes a signed offset in multiples of 2 bytes. The offset
is sign-extended and added to the address of the jump instruction to
form the jump target address. Jumps can therefore target a
&#177;1 MiB range. JAL stores the address of the instruction
following the jump ('pc'+4) into register _rd_. The standard software
calling convention uses 'x1' as the return address register and 'x5' as
an alternate link register.

[NOTE]
====
The alternate link register supports calling millicode routines (e.g.,
those to save and restore registers in compressed code) while preserving
the regular return address register. The register `x5` was chosen as the
alternate link register as it maps to a temporary in the standard
calling convention, and has an encoding that is only one bit different
than the regular link register.
====

Plain unconditional jumps (assembler pseudoinstruction J) are encoded as
a JAL with _rd_=`x0`.

include::images/wavedrom/ct-unconditional.edn[]
[[ct-unconditional]]
//.The unconditional-jump instruction, JAL

The indirect jump instruction JALR (jump and link register) uses the
I-type encoding. The target address is obtained by adding the
sign-extended 12-bit I-immediate to the register _rs1_, then setting the
least-significant bit of the result to zero. The address of the
instruction following the jump (`pc`+4) is written to register _rd_.
Register `x0` can be used as the destination if the result is not
required.

Plain unconditional indirect jumps (assembler pseudoinstruction JR) are
encoded as a JALR with _rd_=`x0`.
Procedure returns in the standard calling convention (assembler
pseudoinstruction RET) are encoded as a JALR with _rd_=`x0`, _rs1_=`x1`, and
_imm_=0.

include::images/wavedrom/ct-unconditional-2.edn[]
[[ct-unconditional-2]]
//.The indirect unconditional-jump instruction, JALR

[NOTE]
====
The unconditional jump instructions all use PC-relative addressing to
help support position-independent code. The JALR instruction was defined
to enable a two-instruction sequence to jump anywhere in a 32-bit
absolute address range. A LUI instruction can first load _rs1_ with the
upper 20 bits of a target address, then JALR can add in the lower bits.
Similarly, AUIPC then JALR can jump anywhere in a 32-bit `pc`-relative
address range.

Note that the JALR instruction does not treat the 12-bit immediate as
multiples of 2 bytes, unlike the conditional branch instructions. This
avoids one more immediate format in hardware. In practice, most uses of
JALR will have either a zero immediate or be paired with a LUI or AUIPC,
so the slight reduction in range is not significant.

Clearing the least-significant bit when calculating the JALR target
address both simplifies the hardware slightly and allows the low bit of
function pointers to be used to store auxiliary information. Although
there is potentially a slight loss of error checking in this case, in
practice jumps to an incorrect instruction address will usually quickly
raise an exception.

When used with a base _rs1_=`x0`, JALR can be used to
implement a single instruction subroutine call to the lowest or highest
address region from anywhere in the address space, which could be used
to implement fast calls to a small runtime library. Alternatively, an
ABI could dedicate a general-purpose register to point to a library
elsewhere in the address space.
====

The JAL and JALR instructions will generate an
instruction-address-misaligned exception if the target address is not
aligned to a four-byte boundary.

[NOTE]
====
Instruction-address-misaligned exceptions are not possible on machines
that support extensions with 16-bit aligned instructions, such as the
compressed instruction-set extension, C.
====

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


[NOTE]
====
Some other ISAs added explicit hint bits to their indirect-jump
instructions to guide return-address stack manipulation. We use implicit
hinting tied to register numbers and the calling convention to reduce
the encoding space used for these hints.

When two different link registers (`x1` and `x5`) are given as _rs1_ and
_rd_, then the RAS is both popped and pushed to support coroutines. If
_rs1_ and _rd_ are the same link register (either `x1` or `x5`), the RAS
is only pushed to enable macro-op fusion of the sequences:
`lui ra, imm20; jalr ra, imm12(ra)_ and _auipc ra, imm20; jalr ra, imm12(ra)`
====

==== Conditional Branches

All branch instructions use the B-type instruction format. The 12-bit
B-immediate encodes signed offsets in multiples of 2 bytes. The offset
is sign-extended and added to the address of the branch instruction to
give the target address. The conditional branch range is
&#177;4 KiB.

include::images/wavedrom/ct-conditional.edn[]
[[ct-conditional]]
//.Conditional branches

Branch instructions compare two registers. BEQ and BNE take the branch
if registers _rs1_ and _rs2_ are equal or unequal respectively. BLT and
BLTU take the branch if _rs1_ is less than _rs2_, using signed and
unsigned comparison respectively. BGE and BGEU take the branch if _rs1_
is greater than or equal to _rs2_, using signed and unsigned comparison
respectively. Note, BGT, BGTU, BLE, and BLEU can be synthesized by
reversing the operands to BLT, BLTU, BGE, and BGEU, respectively.

[NOTE]
====
Signed array bounds may be checked with a single BLTU instruction, since
any negative index will compare greater than any nonnegative bound.
====

```

### src/b-st-ext.adoc

```text
==== Zba: Address generation

The Zba instructions can be used to accelerate the generation of addresses that index into arrays of basic types (halfword, word, doubleword) using both unsigned word-sized and XLEN-sized indices: a shifted index is added to a base address.

The shift and add instructions do a left shift of 1, 2, or 3 because these are commonly found in real-world code and because they can be implemented with a minimal amount of additional hardware beyond that of the simple adder. This avoids lengthening the critical path in implementations.

While the shift and add instructions are limited to a maximum left shift of 3, the slli instruction (from the base ISA) can be used to perform similar shifts for indexing into arrays of wider elements. The slli.uw -- added in this extension -- can be used when the index is to be interpreted as an unsigned word.

The following instructions comprise the Zba extension:

[%header,cols="^1,^1,4,8"]
|===
|RV32
|RV64
|Mnemonic
|Instruction

|
|&#10003;
|add.uw _rd_, _rs1_, _rs2_
|<<#insns-add_uw>>

|&#10003;
|&#10003;
|sh1add _rd_, _rs1_, _rs2_
|<<#insns-sh1add>>

|
|&#10003;
|sh1add.uw _rd_, _rs1_, _rs2_
|<<#insns-sh1add_uw>>

|&#10003;
|&#10003;
|sh2add _rd_, _rs1_, _rs2_
|<<#insns-sh2add>>

|
|&#10003;
|sh2add.uw _rd_, _rs1_, _rs2_
|<<#insns-sh2add_uw>>

|&#10003;
|&#10003;
|sh3add _rd_, _rs1_, _rs2_
|<<#insns-sh3add>>

|
|&#10003;
|sh3add.uw _rd_, _rs1_, _rs2_
|<<#insns-sh3add_uw>>

|
|&#10003;
|slli.uw _rd_, _rs1_, _imm_
|<<#insns-slli_uw>>

|===

[#zbb,reftext="Basic bit-manipulation"]
==== Zbb: Basic bit-manipulation

===== Logical with negate

[%header,cols="^1,^1,4,8"]
|===
|RV32
|RV64
|Mnemonic
|Instruction

|&#10003;
|&#10003;
|andn _rd_, _rs1_, _rs2_
|<<#insns-andn>>

|&#10003;
|&#10003;
|orn _rd_, _rs1_, _rs2_
|<<#insns-orn>>

|&#10003;
|&#10003;
|xnor _rd_, _rs1_, _rs2_
|<<#insns-xnor>>
|===

.Implementation Hint
[NOTE, caption="Imp" ]
===============================================================
The Logical with Negate instructions can be implemented by inverting the _rs2_ inputs to the base-required AND, OR, and XOR logic instructions.
In some implementations, the inverter on rs2 used for subtraction can be reused for this purpose.
===============================================================

===== Count leading/trailing zero bits

[%header,cols="^1,^1,4,8"]
|===
|RV32
|RV64
|Mnemonic
|Instruction

|&#10003;
|&#10003;
|clz _rd_, _rs_
|<<#insns-clz>>

|
|&#10003;
|clzw _rd_, _rs_
|<<#insns-clzw>>

|&#10003;
|&#10003;
|ctz _rd_, _rs_
|<<#insns-ctz>>

|
|&#10003;
|ctzw _rd_, _rs_
|<<#insns-ctzw>>
|===

===== Count population

These instructions count the number of set bits (1-bits). This is also
commonly referred to as population count.

[%header,cols="^1,^1,4,8"]
|===
|RV32
|RV64
|Mnemonic
|Instruction

|&#10003;
|&#10003;
|cpop _rd_, _rs_
|<<#insns-cpop>>

|
|&#10003;
|cpopw _rd_, _rs_
|<<#insns-cpopw>>
|===

===== Integer minimum/maximum

The integer minimum/maximum instructions are arithmetic R-type
instructions that return the smaller/larger of two operands.

[%header,cols="^1,^1,4,8"]
|===
|RV32
|RV64
|Mnemonic
|Instruction

|&#10003;
|&#10003;
|max _rd_, _rs1_, _rs2_
|<<#insns-max>>

|&#10003;
|&#10003;
|maxu _rd_, _rs1_, _rs2_
|<<#insns-maxu>>

|&#10003;
|&#10003;
|min _rd_, _rs1_, _rs2_
|<<#insns-min>>

|&#10003;
|&#10003;
|minu _rd_, _rs1_, _rs2_
|<<#insns-minu>>
|===

===== Sign extension and zero extension

These instructions perform the sign extension or zero extension of the least significant 8 bits or 16 bits of the source register.

These instructions replace the generalized idioms `slli rD,rS,(XLEN-<size>) + srli` (for zero extension) or `slli + srai` (for sign extension) for the sign extension of 8-bit and 16-bit quantities, and for the zero extension of 16-bit quantities.

[%header,cols="^1,^1,4,8"]
|===
|RV32
|RV64
|Mnemonic
|Instruction

|&#10003;
|&#10003;
|sext.b _rd_, _rs_
|<<#insns-sext_b>>

|&#10003;
|&#10003;
|sext.h _rd_, _rs_
|<<#insns-sext_h>>

|&#10003;
|&#10003;
|zext.h _rd_, _rs_
|<<#insns-zext_h>>
|===

===== Bitwise rotation

Bitwise rotation instructions are similar to the shift-logical operations from the base spec. However, where the shift-logical 
instructions shift in zeros, the rotate instructions shift in the bits that were shifted out of the other side of the value.
Such operations are also referred to as ‘circular shifts’.



[%header,cols="^1,^1,4,8"]
|===
|RV32
|RV64
|Mnemonic
|Instruction

|&#10003;
|&#10003;
|rol _rd_, _rs1_, _rs2_
|<<#insns-rol>>

|
|&#10003;
|rolw _rd_, _rs1_, _rs2_
|<<#insns-rolw>>

|&#10003;
|&#10003;
|ror _rd_, _rs1_, _rs2_
|<<#insns-ror>>

|&#10003;
|&#10003;
|rori _rd_, _rs1_, _shamt_
|<<#insns-rori>>

|
|&#10003;
|roriw _rd_, _rs1_, _shamt_
|<<#insns-roriw>>

|
|&#10003;
|rorw _rd_, _rs1_, _rs2_
|<<#insns-rorw>>
|===

.Architecture Explanation
[NOTE, caption="AE" ]
===============================================================
The rotate instructions were included to replace a common
four-instruction sequence to achieve the same effect (neg; sll/srl; srl/sll; or)
===============================================================

===== OR Combine

*orc.b* sets the bits of each byte in the result _rd_ to all zeros if no bit within the respective byte of _rs_ is set, or to all ones if any bit within the respective byte of _rs_ is set.

One use-case is string-processing functions, such as *strlen* and *strcpy*, which can use *orc.b* to test for the terminating zero byte by counting the set bits in leading non-zero bytes in a word.

[%header,cols="^1,^1,4,8"]
|===
|RV32
|RV64
|Mnemonic
|Instruction

|&#10003;
|&#10003;
|orc.b _rd_, _rs_
|<<#insns-orc_b>>
|===

===== Byte-reverse

*rev8* reverses the byte-ordering of _rs_.

[%header,cols="^1,^1,4,8"]
|====
|RV32
|RV64
|Mnemonic
|Instruction

|&#10003;
|&#10003;
|rev8 _rd_, _rs_
|<<#insns-rev8>>

|====

[#zbc,reftext="Carry-less multiplication"]
==== Zbc: Carry-less multiplication

Carry-less multiplication is the multiplication in the polynomial ring over GF(2).

*clmul* produces the lower half of the carry-less product and *clmulh* produces the upper half of the 2&#x2715;XLEN carry-less product.

*clmulr* produces bits 2&#x2715;XLEN−2:XLEN-1 of the 2&#x2715;XLEN carry-less product.

[%header,cols="^1,^1,4,8"]
|===
|RV32
|RV64
|Mnemonic
|Instruction

|&#10003;
|&#10003;
|clmul _rd_, _rs1_, _rs2_
|<<#insns-clmul>>

|&#10003;
|&#10003;
|clmulh _rd_, _rs1_, _rs2_
|<<#insns-clmulh>>

|&#10003;
|&#10003;
|clmulr _rd_, _rs1_, _rs2_
|<<#insns-clmulr>>

|===

[#zbs,reftext="Single-bit instructions"]
==== Zbs: Single-bit instructions

The single-bit instructions provide a mechanism to set, clear, invert, or extract
a single bit in a register. The bit is specified by its index.

[%header,cols="^1,^1,4,8"]
|===
|RV32
|RV64
|Mnemonic
|Instruction

|&#10003;
|&#10003;
|bclr _rd_, _rs1_, _rs2_
|<<#insns-bclr>>

|&#10003;
|&#10003;
|bclri _rd_, _rs1_, _imm_
|<<#insns-bclri>>

|&#10003;
|&#10003;
|bext _rd_, _rs1_, _rs2_
|<<#insns-bext>>

|&#10003;
|&#10003;
|bexti _rd_, _rs1_, _imm_
|<<#insns-bexti>>

|&#10003;
|&#10003;
|binv _rd_, _rs1_, _rs2_
|<<#insns-binv>>

|&#10003;
|&#10003;
|binvi _rd_, _rs1_, _imm_
|<<#insns-binvi>>

|&#10003;
|&#10003;
|bset _rd_, _rs1_, _rs2_
|<<#insns-bset>>

|&#10003;
|&#10003;
|bseti _rd_, _rs1_, _imm_
|<<#insns-bseti>>

|===

```
