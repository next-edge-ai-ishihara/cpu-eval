# Implement `rvmaskandmatch`

Implement the complete `rvmaskandmatch` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvmaskandmatch` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
// mask and match function matches bits after finding the first 0 position
// find first starting from LSB. Skip that location and match the rest of the bits
module rvmaskandmatch #( parameter WIDTH=32 )
   (
     input  logic [WIDTH-1:0] mask,     // this will have the mask in the lower bit positions
     input  logic [WIDTH-1:0] data,     // this is what needs to be matched on the upper bits with the mask's upper bits
     input  logic             masken,   // when 1 : do mask. 0 : full match
     output logic             match
     );

```

## Parent instantiation

### design/dec/el2_dec_trigger.sv

```verilog
      rvmaskandmatch trigger_i0_match (.mask(trigger_pkt_any[i].tdata2[31:0]), .data(dec_i0_match_data[i][31:0]), .masken(trigger_pkt_any[i].match), .match(dec_i0_trigger_data_match[i]));
```

### design/lsu/el2_lsu_trigger.sv

```verilog
      rvmaskandmatch trigger_match (.mask(trigger_pkt_any[i].tdata2[31:0]), .data(lsu_match_data[i][31:0]), .masken(trigger_pkt_any[i].match), .match(lsu_trigger_data_match[i]));
```

## Documentation

### docs/source/debugging.md

```markdown
* - match
  - 10:7
  - Match control:
    - 0: Matches when value equals `tdata2` register’s ([](debugging.md#trigger-data-2-register-tdata2)) value [^fn-debugging-4]
    - 1: Matches when top *M* bits of value match top *M* bits of `tdata2` register’s ([](debugging.md#trigger-data-2-register-tdata2)) value (*M* is 31 minus the index of least-significant bit containing 0 in `tdata2` register)
```

## Additional requirement

When `masken` is 1 and every bit of `mask` is 1, `match` is 1 only when `data` equals `mask`.
