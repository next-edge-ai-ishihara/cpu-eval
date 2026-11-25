# Implement `el2_exu_mul_ctl`

Implement the complete `el2_exu_mul_ctl` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module el2_exu_mul_ctl` definition in a single SystemVerilog code block, with no text outside the block.

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

## Parent instantiation

```verilog
   rvdffie #(pt.BHT_GHR_SIZE+2,1)       i_misc_ff            (.*, .clk(clk),                                .din ({ghr_d_ns[pt.BHT_GHR_SIZE-1:0], mul_p.valid, dec_i0_branch_d}),
                                                                                                            .dout({ghr_d[pt.BHT_GHR_SIZE-1:0]   , mul_valid_x, i0_branch_x}) );

// ...

   el2_exu_mul_ctl #(.pt(pt)) i_mul   (.*,
                          .mul_p             ( mul_p              & {$bits(el2_mul_pkt_t){mul_p.valid}} ),   // I
                          .rs1_in            ( muldiv_rs1_d[31:0] & {32{mul_p.valid}}                    ),   // I
                          .rs2_in            ( i0_rs2_d[31:0]     & {32{mul_p.valid}}                    ),   // I
                          .result_x          ( mul_result_x[31:0]                                        ));  // O

// ...

   assign exu_i0_result_x[31:0]    =  (mul_valid_x)  ?  mul_result_x[31:0]  :  alu_result_x[31:0];

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

```

## Documentation

### src/m-st-ext.adoc

```text
=== Multiplication Operations

include::images/wavedrom/m-st-ext-for-int-mult.edn[]
[[m-st-ext-for-int-mult]]
//.Multiplication operation instructions
(((MUL, MULH)))
(((MUL, MULHU)))
(((MUL, MULHSU)))

MUL performs an XLEN-bit×XLEN-bit multiplication of
_rs1_ by _rs2_ and places the lower XLEN bits in the destination
register. MULH, MULHU, and MULHSU perform the same multiplication but
return the upper XLEN bits of the full 2×XLEN-bit
product, for signed×signed,
unsigned×unsigned, and _rs1_×unsigned _rs2_ multiplication, respectively.
If both the high and low bits of the same product are required, then the recommended code sequence is: MULH[[S]U] _rdh, rs1, rs2_; MUL _rdl, rs1, rs2_ (source register specifiers must be in same order and _rdh_ cannot be the same as _rs1_ or _rs2_). Microarchitectures can then fuse these into a single multiply operation instead of performing two separate multiplies.

[NOTE]
====
MULHSU is used in multi-word signed multiplication to multiply the
most-significant word of the multiplicand (which contains the sign bit)
with the less-significant words of the multiplier (which are unsigned).
====

MULW is an RV64 instruction that multiplies the lower 32 bits of the
source registers, placing the sign extension of the lower 32 bits of the
result into the destination register.

```

### src/b-st-ext.adoc

```text
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

```
