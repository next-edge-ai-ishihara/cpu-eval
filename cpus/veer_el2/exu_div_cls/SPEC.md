# Implement `el2_exu_div_cls`

Implement the complete `el2_exu_div_cls` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module el2_exu_div_cls` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_exu_div_cls
  (
   input  logic [32:0] operand,

   output logic [4:0]  cls                  // Count leading sign bits - "n" format ignoring [32]
   );

```

## Parent instantiation

```verilog
   assign shortq_dividend[32:0]   = {dividend_sign_ff,a_ff[31:0]};


   logic [5:0]  dw_a_enc;
   logic [5:0]  dw_b_enc;
   logic [6:0]  dw_shortq_raw;



   el2_exu_div_cls i_a_cls  (
       .operand  ( shortq_dividend[32:0]  ),
       .cls      ( dw_a_enc[4:0]          ));

   el2_exu_div_cls i_b_cls  (
       .operand  ( b_ff[32:0]             ),
       .cls      ( dw_b_enc[4:0]          ));

   assign dw_a_enc[5]             =  1'b0;
   assign dw_b_enc[5]             =  1'b0;


   assign dw_shortq_raw[6:0]      =  {1'b0,dw_b_enc[5:0]} - {1'b0,dw_a_enc[5:0]} + 7'd1;
   assign shortq[5:0]             =  dw_shortq_raw[6]  ?  6'd0  :  dw_shortq_raw[5:0];

```

## Additional requirement

`operand[32]` is the sign bit for the leading sign bit count of `operand[31:0]`, and `cls` is 31 when every bit of `operand` is 1.
