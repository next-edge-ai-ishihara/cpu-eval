# Implement `rvlsadder`

Implement the complete `rvlsadder` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module rvlsadder` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvlsadder
  (
    input logic [31:0] rs1,
    input logic [11:0] offset,

    output logic [31:0] dout
    );
```

## Parent instantiation

```verilog
   rvlsadder   lsadder  (.rs1(rs1_d[31:0]),
                       .offset(offset_d[11:0]),
                       .dout(full_addr_d[31:0])
                       );
```

## Documentation

### src/rv32.adoc

```text
Load and store instructions transfer a value between the registers and
memory. Loads are encoded in the I-type format and stores are S-type.
The effective address is obtained by adding register _rs1_ to the
sign-extended 12-bit offset. Loads copy a value from memory to register
_rd_. Stores copy the value in register _rs2_ to memory.
```
