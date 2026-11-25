# Implement `rvtwoscomp`

Implement the complete `rvtwoscomp` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvtwoscomp` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
// 2s complement circuit
module rvtwoscomp #( parameter WIDTH=32 )
   (
     input logic [WIDTH-1:0] din,

     output logic [WIDTH-1:0] dout
     );
```

## Parent instantiation

```verilog
   rvtwoscomp #(32) i_twos_comp  (.din(twos_comp_in[31:0]), .dout(twos_comp_out[31:0]));
```
