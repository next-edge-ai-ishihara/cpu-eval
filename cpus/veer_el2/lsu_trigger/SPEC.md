# Implement `el2_lsu_trigger`

Implement the complete `el2_lsu_trigger` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_lsu_trigger` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_lsu_trigger
import el2_pkg::*;
#(
`include "el2_param.vh"
 )(
   input el2_trigger_pkt_t [3:0] trigger_pkt_any,            // trigger packet from dec
   input el2_lsu_pkt_t           lsu_pkt_m,                  // lsu packet
   input logic [31:0]             lsu_addr_m,                 // address
   input logic [31:0]             store_data_m,               // store data

   output logic [3:0]             lsu_trigger_match_m         // match result
);
```

## Parent instantiation

```verilog
   el2_lsu_trigger #(.pt(pt)) trigger (
      .store_data_m(store_data_m[31:0]),
      .*
   );
```

## Dependency declarations

### design/include/el2_def.sv

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
```

### design/lib/beh_lib.sv

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
#### Match Control Register (mcontrol)

:::{note}
VeeR EL2 does not support triggering on the data of a load or on the opcode of an executed instruction.
:::
...
* - select
  - 19
  - Match selection:

    0: Perform match on address

    1: Perform match on store data value
  - R/W
  - 0
...
* - sizelo
  - 17:16
  - Match size:
    - 0: Trigger attempts to match against access of any size.
      - Match against address (if select bit is ‘0’)
      - Match against store data (if select bit is ‘1’)

      **Note**: Data is zero extended for byte or halfword stores.

      **Note**: If *match* bit is ‘1’, the mask in the `tdata2` register is applied independent of the *select* bit value (i.e., in address or data matches).

      **Note**: Other match size values not implemented.
  - R
  - 0
...
* - match
  - 10:7
  - Match control:
    - 0: Matches when value equals `tdata2` register’s ([](debugging.md#trigger-data-2-register-tdata2)) value [^fn-debugging-4]
    - 1: Matches when top *M* bits of value match top *M* bits of `tdata2` register’s ([](debugging.md#trigger-data-2-register-tdata2)) value (*M* is 31 minus the index of least-significant bit containing 0 in `tdata2` register)

    **Note**: Other values not implemented or reserved for future use.
  - R/W
  - 0
```
