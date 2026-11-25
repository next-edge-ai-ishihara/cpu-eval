# Implement `el2_dec_trigger`

Implement the complete `el2_dec_trigger` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module el2_dec_trigger` definition in a single SystemVerilog code block, with no text outside the block.

## Package and imports

```verilog
typedef struct packed {
                        logic        select;
                        logic        match;
                        logic        store;
                        logic        load;
                        logic        execute;
                        logic        m;
                        logic [31:0] tdata2;
            } el2_trigger_pkt_t;

```

## Module declaration

```verilog
module el2_dec_trigger
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(

   input el2_trigger_pkt_t [3:0] trigger_pkt_any,           // Packet from tlu. 'select':0-pc,1-Opcode  'Execute' needs to be set for dec triggers to fire. 'match'-1 do mask, 0: full match
   input logic [31:1]  dec_i0_pc_d,                          // i0 pc

   output logic [3:0] dec_i0_trigger_match_d                 // Trigger match
);

```

## Parent instantiation

```verilog
  el2_dec_trigger #(.pt(pt)) dec_trigger (.*);

```

## Dependency declarations

```verilog
module rvmaskandmatch #( parameter WIDTH=32 )
   (
     input  logic [WIDTH-1:0] mask,     // this will have the mask in the lower bit positions
     input  logic [WIDTH-1:0] data,     // this is what needs to be matched on the upper bits with the mask's upper bits
     input  logic             masken,   // when 1 : do mask. 0 : full match
     output logic             match
     );

```

## Documentation

### docs/source/debugging.md

```text
* - match
  - 10:7
  - Match control:
    - 0: Matches when value equals `tdata2` register’s ([](debugging.md#trigger-data-2-register-tdata2)) value [^fn-debugging-4]
    - 1: Matches when top *M* bits of value match top *M* bits of `tdata2` register’s ([](debugging.md#trigger-data-2-register-tdata2)) value (*M* is 31 minus the index of least-significant bit containing 0 in `tdata2` register)

    **Note**: Other values not implemented or reserved for future use.
  - R/W
  - 0
* - m
  - 6
  - When set, enable this trigger in M-mode

...

[^fn-debugging-4]: Bit 0 of tdata2 register is ignored for instruction address matches.

```
