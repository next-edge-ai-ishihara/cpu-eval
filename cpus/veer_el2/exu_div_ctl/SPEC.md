# Implement `el2_exu_div_ctl`

Implement the complete `el2_exu_div_ctl` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module el2_exu_div_ctl` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

```text
my $div_bit=4;       # number of bits to process each cycle for div
my $div_new=1;       # old or new div algorithm

```

## Package and imports

```verilog
typedef struct packed {
                       logic valid;
                       logic unsign;
                       logic rem;
                       } el2_div_pkt_t;

```

## Module declaration

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

## Parent instantiation

```verilog
   el2_exu_div_ctl #(.pt(pt)) i_div   (.*,
                          .cancel            ( dec_div_cancel              ),   // I
                          .dp                ( div_p                       ),   // I
                          .dividend          ( muldiv_rs1_d[31:0]          ),   // I
                          .divisor           ( i0_rs2_d[31:0]              ),   // I
                          .finish_dly        ( exu_div_wren                ),   // O
                          .out               ( exu_div_result[31:0]        ));  // O

```

## Dependency declarations

```verilog
module el2_exu_div_existing_1bit_cheapshortq
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

// ...

module el2_exu_div_new_1bit_fullshortq
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

// ...

module el2_exu_div_new_2bit_fullshortq
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

// ...

module el2_exu_div_new_3bit_fullshortq
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

// ...

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
