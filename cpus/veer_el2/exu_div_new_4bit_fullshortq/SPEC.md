# Implement `el2_exu_div_new_4bit_fullshortq`

Implement the complete `el2_exu_div_new_4bit_fullshortq` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module el2_exu_div_new_4bit_fullshortq` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_exu_div_new_4bit_fullshortq
  (
   input  logic            clk,                       // Top level clock
   input  logic            rst_l,                     // Reset
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic            scan_mode,                 // Scan mode
   /*pragma coverage on*/

   input  logic            cancel,                    // Flush pipeline
   input  logic            valid_in,
   input  logic            signed_in,
   input  logic            rem_in,
   input  logic [31:0]     dividend_in,
   input  logic [31:0]     divisor_in,

   output logic            valid_out,
   output logic [31:0]     data_out
  );

```

## Parent instantiation

```verilog
        el2_exu_div_new_4bit_fullshortq         i_new_4bit_div_fullshortq       (
            .clk              ( clk                      ),   // I
            .rst_l            ( rst_l                    ),   // I
            .scan_mode        ( scan_mode                ),   // I
            .cancel           ( cancel                   ),   // I
            .valid_in         ( dp.valid                 ),   // I
            .signed_in        (~dp.unsign                ),   // I
            .rem_in           ( dp.rem                   ),   // I
            .dividend_in      ( dividend[31:0]           ),   // I
            .divisor_in       ( divisor[31:0]            ),   // I
            .valid_out        ( finish_dly               ),   // O
            .data_out         ( out_raw[31:0]            ));  // O

```

## Dependency declarations

### design/exu/el2_exu_div_ctl.sv

```verilog
module el2_exu_div_cls
  (
   input  logic [32:0] operand,

   output logic [4:0]  cls                  // Count leading sign bits - "n" format ignoring [32]
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

module rvtwoscomp #( parameter WIDTH=32 )
   (
     input logic [WIDTH-1:0] din,

     output logic [WIDTH-1:0] dout
     );

```

## Documentation

### src/m-st-ext.adoc

```text
=== Division Operations

include::images/wavedrom/division-op.edn[]
[[division-op]]
//.Division operation instructions
(((MUL, DIV)))
(((MUL, DIVU)))

DIV and DIVU perform an XLEN bits by XLEN bits signed and unsigned
integer division of _rs1_ by _rs2_, rounding towards zero. REM and REMU
provide the remainder of the corresponding division operation. For REM,
the sign of a nonzero result equals the sign of the dividend.

[NOTE]
====
For both signed and unsigned division, except in the case of overflow, it holds
that
latexmath:[$\textrm{dividend} = \textrm{divisor} \times \textrm{quotient} + \textrm{remainder}$].
====

If both the quotient and remainder are required from the same division,
the recommended code sequence is: DIV[U] _rdq, rs1, rs2_; REM[U] _rdr,
rs1, rs2_ (_rdq_ cannot be the same as _rs1_ or _rs2_).
Microarchitectures can then fuse these into a single divide operation
instead of performing two separate divides.

...

The semantics for division by zero and division overflow are summarized
in <<divby0>>. The quotient of division by zero has all bits
set, and the remainder of division by zero equals the dividend. Signed
division overflow occurs only when the most-negative integer is divided
by latexmath:[$-1$]. The quotient of a signed division with overflow is
equal to the dividend, and the remainder is zero. Unsigned division
overflow cannot occur.

[[divby0]]
.Semantics for division by zero and division overflow. L is the width of the operation in bits: XLEN for DIV[U] and REM[U], or 32 for DIV[U]W and REM[U]W.
[cols="<2,^,^,^,^,^,^",options="header",]
|===
|Condition |Dividend |Divisor |DIVU[W] |REMU[W] |DIV[W] |REM[W]

|Division by zero +
Overflow (signed only) |latexmath:[$x$] +
latexmath:[$-2^{L-1}$] |0 +
latexmath:[$-1$] |latexmath:[$2^{L}-1$] +
 - |latexmath:[$x$] + 
 - |latexmath:[$-1$] +
 latexmath:[$-2^{L-1}$] +
  |latexmath:[$x$] +
  0
|===

```
