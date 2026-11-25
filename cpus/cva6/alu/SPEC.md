# Implement `alu`

Implement the complete `alu` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module alu` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
      RVB: bit'(1),
      ZKN: bit'(0),
// ...
      RVZiCond: bit'(0),
```

## Package and imports

### core/include/ariane_pkg.sv

```systemverilog
  typedef enum logic [7:0] {  // basic ALU op
    ADD,
    SUB,
// ...
    // logic operations
    XORL,
    ORL,
    ANDL,
    // shifts
    SRA,
    SRL,
    SLL,
// ...
    // comparisons
    LTS,
    LTU,
    GES,
    GEU,
    EQ,
    NE,
    // jumps
    JALR,
// ...
    // set lower than operations
    SLTS,
    SLTU,
// ...
    // Or-Combine and REV8
    ORCB,
    REV8,
    // Bitwise Rotation
    ROL,
// ...
    ROR,
    RORI,
// ...
    // Sign and Zero Extend
    SEXTB,
    SEXTH,
    ZEXTH,
    // Count population
    CPOP,
// ...
    // Count Leading/Training Zeros
    CLZ,
// ...
    CTZ,
// ...
    // Single bit instructions Op's
    BCLR,
    BCLRI,
    BEXT,
    BEXTI,
    BINV,
    BINVI,
    BSET,
    BSETI,
    // Integer minimum/maximum
    MAX,
    MAXU,
    MIN,
    MINU,
// ...
    // Shift with Add (Bitmanip)
    SH1ADD,
    SH2ADD,
    SH3ADD,
    // Bitmanip Logical with negate op (Bitmanip)
    ANDN,
    ORN,
    XNOR,
// ...
  } fu_op;
```

## Module declaration

```systemverilog
module alu
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter bit HasBranch = 1'b1,
    parameter type fu_data_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // FU data needed to execute instruction - ISSUE_STAGE
    input fu_data_t fu_data_i,
    // FU data needed to execute CPOP/CPOPW - ISSUE_STAGE
    input fu_data_t fu_data_cpop_i,
    // ALU result - ISSUE_STAGE
    output logic [CVA6Cfg.XLEN-1:0] result_o,
    // ALU branch compare result - branch_unit
    output logic alu_branch_res_o
);
```

## Parent instantiation

### core/alu_wrapper.sv

```systemverilog
  alu #(
      .CVA6Cfg  (CVA6Cfg),
      .HasBranch(1'b1),
      .fu_data_t(fu_data_t)
  ) alu_i (
      .clk_i           (clk_i),
      .rst_ni          (rst_ni),
      .fu_data_i       (fu_data_i[0]),
      .fu_data_cpop_i  (fu_data_i[0]),
      .result_o        (result_o[0]),
      .alu_branch_res_o(alu_branch_res_o)
  );
```

## Dependency declarations

### core/cva6.sv

```systemverilog
    localparam type fu_data_t = struct packed {
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.XLEN-1:0]          operand_a;
      logic [CVA6Cfg.XLEN-1:0]          operand_b;
      logic [CVA6Cfg.XLEN-1:0]          imm;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
    },
```

## Related source code

### core/decoder.sv

```systemverilog
        // Jump and link register
        riscv::OpcodeJalr: begin
          instruction_o.fu        = CTRL_FLOW;
          instruction_o.op        = ariane_pkg::JALR;
          instruction_o.rs1       = instr.itype.rs1;
          imm_select              = IIMM;
          instruction_o.rd        = instr.itype.rd;
          is_control_flow_instr_o = 1'b1;
          // invalid jump and link register -> reserved for vector encoding
          if (instr.itype.funct3 != 3'b0) illegal_instr = 1'b1;
        end
```

### core/issue_read_operands.sv

```systemverilog
        case (issue_instr_i[i].fu)
// ...
          CTRL_FLOW: begin
            branch_valid_n[i] = 1'b1;
          end
// ...
```

### core/ex_stage.sv

```systemverilog
  fu_data_t [CVA6Cfg.NrALUs-1:0] alu_data;

  logic [CVA6Cfg.NrIssuePorts-1:0] one_cycle_select;
  assign one_cycle_select = alu_valid_i | branch_valid_i | csr_valid_i | aes_valid_i;

  fu_data_t one_cycle_data;
// ...
  always_comb begin
    // data silence operation
    one_cycle_data = one_cycle_select[0] ? fu_data_i[0] : '0;
// ...
  end

  // 1. ALU(s) (combinatorial)
  assign alu_data[0] = one_cycle_data;
// ...
  alu_wrapper #(
      .CVA6Cfg  (CVA6Cfg),
      .fu_data_t(fu_data_t)
  ) alu_wrapper_i (
      .clk_i,
      .rst_ni,
      .alu_bypass_i    (alu_bypass_i),
      .fu_data_i       (alu_data),
      .result_o        (alu_result),
      .alu_branch_res_o(alu_branch_res)
  );
// ...
  branch_unit #(
      .CVA6Cfg(CVA6Cfg),
      .bp_resolve_t(bp_resolve_t),
      .branchpredict_sbe_t(branchpredict_sbe_t),
      .exception_t(exception_t),
      .fu_data_t(fu_data_t)
  ) branch_unit_i (
      .clk_i,
      .rst_ni,
      .v_i,
      .debug_mode_i,
      .fu_data_i         (one_cycle_data),
      .pc_i,
      .is_zcmt_i,
      .is_compressed_instr_i,
      .branch_valid_i    (|branch_valid_i),
      .branch_comp_res_i (alu_branch_res),
// ...
```

### core/branch_unit.sv

```systemverilog
    // There are only three sources of mispredicts:
    // 1. Branches
    // 2. Jumps to register addresses
    // 3. Zcmt instructions
    if (branch_valid_i) begin
      // write target address which goes to PC Gen or select target address if zcmt
      resolved_branch_o.target_address = (branch_comp_res_i) ? target_address : next_pc;
      resolved_branch_o.is_taken = branch_comp_res_i;
// ...
```

## Documentation

### docs/design/design-manual/source/cva6_execute.adoc

```text
alu
+++

The arithmetic logic unit (ALU) is a small piece of hardware which performs 32 and 64-bit arithmetic and bitwise operations: subtraction, addition, shifts, comparisons...
It always completes its operation in a single cycle.
```

### src/rv32.adoc

```text
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
```

```text
Shifts by a constant are encoded as a specialization of the I-type
format. The operand to be shifted is in _rs1_, and the shift amount is
encoded in the lower 5 bits of the I-immediate field. The right shift
type is encoded in bit 30. SLLI is a logical left shift (zeros are
shifted into the lower bits); SRLI is a logical right shift (zeros are
shifted into the upper bits); and SRAI is an arithmetic right shift (the
original sign bit is copied into the vacated upper bits).
```

```text
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
```

```text
Branch instructions compare two registers. BEQ and BNE take the branch
if registers _rs1_ and _rs2_ are equal or unequal respectively. BLT and
BLTU take the branch if _rs1_ is less than _rs2_, using signed and
unsigned comparison respectively. BGE and BGEU take the branch if _rs1_
is greater than or equal to _rs2_, using signed and unsigned comparison
respectively. Note, BGT, BGTU, BLE, and BLEU can be synthesized by
reversing the operands to BLT, BLTU, BGE, and BGEU, respectively.
```

### src/b-st-ext.adoc

```text
==== andn
...
Operation::
[source,sail]
--
X(rd) = X(rs1) & ~X(rs2);
--
```

```text
==== bclr
...
Operation::
[source,sail]
--
let index = X(rs2) & (XLEN - 1);
X(rd) = X(rs1) & ~(1 << index)
--
```

```text
==== bclri
...
Operation::
[source,sail]
--
let index = shamt & (XLEN - 1);
X(rd) = X(rs1) & ~(1 << index)
--
```

```text
==== bext
...
Operation::
[source,sail]
--
let index = X(rs2) & (XLEN - 1);
X(rd) = (X(rs1) >> index) & 1;
--
```

```text
==== bexti
...
Operation::
[source,sail]
--
let index = shamt & (XLEN - 1);
X(rd) = (X(rs1) >> index) & 1;
--
```

```text
==== binv
...
Operation::
[source,sail]
--
let index = X(rs2) & (XLEN - 1);
X(rd) = X(rs1) ^ (1 << index)
--
```

```text
==== binvi
...
Operation::
[source,sail]
--
let index = shamt & (XLEN - 1);
X(rd) = X(rs1) ^ (1 << index)
--
```

```text
==== bset
...
Operation::
[source,sail]
--
let index = X(rs2) & (XLEN - 1);
X(rd) = X(rs1) | (1 << index)
--
```

```text
==== bseti
...
Operation::
[source,sail]
--
let index = shamt & (XLEN - 1);
X(rd) = X(rs1) | (1 << index)
--
```

```text
==== clz
...
Operation::
[source,sail]
--
val HighestSetBit : forall ('N : Int), 'N >= 0. bits('N) -> int

function HighestSetBit x = {
  foreach (i from (xlen - 1) to 0 by 1 in dec)
    if [x[i]] == 0b1 then return(i) else ();
  return -1;
}

let rs = X(rs);
X[rd] = (xlen - 1) - HighestSetBit(rs);
--
```

```text
==== cpop
...
Operation::
[source,sail]
--
let bitcount = 0;
let rs = X(rs);

foreach (i from 0 to (xlen - 1) in inc)
    if rs[i] == 0b1 then bitcount = bitcount + 1 else ();

X[rd] = bitcount
--
```

```text
==== ctz
...
Operation::
[source,sail]
--
val LowestSetBit : forall ('N : Int), 'N >= 0. bits('N) -> int

function LowestSetBit x = {
  foreach (i from 0 to (xlen - 1) by 1 in dec)
    if [x[i]] == 0b1 then return(i) else ();
  return xlen;
}

let rs = X(rs);
X[rd] = LowestSetBit(rs);
--
```

```text
==== max
...
Operation::
[source,sail]
--
let rs1_val = X(rs1);
let rs2_val = X(rs2);

let result = if   rs1_val <_s rs2_val
             then rs2_val
             else rs1_val;

X(rd) = result;
--
```

```text
==== maxu
...
Operation::
[source,sail]
--
let rs1_val = X(rs1);
let rs2_val = X(rs2);

let result = if   rs1_val <_u rs2_val
             then rs2_val
             else rs1_val;

X(rd) = result;
--
```

```text
==== min
...
Operation::
[source,sail]
--
let rs1_val = X(rs1);
let rs2_val = X(rs2);

let result = if   rs1_val <_s rs2_val
             then rs1_val
             else rs2_val;

X(rd) = result;
--
```

```text
==== minu
...
Operation::
[source,sail]
--
let rs1_val = X(rs1);
let rs2_val = X(rs2);

let result = if   rs1_val <_u rs2_val
             then rs1_val
             else rs2_val;

X(rd) = result;
--
```

```text
==== orc.b
...
Operation::
[source,sail]
--
let input = X(rs);
let output : xlenbits = 0;

foreach (i from 0 to (xlen - 8) by 8) {
   output[(i + 7)..i] = if   input[(i + 7)..i] == 0
                        then 0b00000000
                        else 0b11111111;
}

X[rd] = output;
--
```

```text
==== orn
...
Operation::
[source,sail]
--
X(rd) = X(rs1) | ~X(rs2);
--
```

```text
==== rev8
...
Operation::
[source,sail]
--
let input = X(rs);
let output : xlenbits = 0;
let j = xlen - 1;

foreach (i from 0 to (xlen - 8) by 8) {
   output[i..(i + 7)] = input[(j - 7)..j];
   j = j - 8;
}

X[rd] = output
--
```

```text
==== rol
...
Operation::
[source,sail]
--
let shamt = if   xlen == 32
            then X(rs2)[4..0]
            else X(rs2)[5..0];
let result = (X(rs1) << shamt) | (X(rs1) >> (xlen - shamt));

X(rd) = result;
--
```

```text
==== ror
...
Operation::
[source,sail]
--
let shamt = if   xlen == 32
            then X(rs2)[4..0]
            else X(rs2)[5..0];
let result = (X(rs1) >> shamt) | (X(rs1) << (xlen - shamt));

X(rd) = result;
--
```

```text
==== rori
...
Operation::
[source,sail]
--
let shamt = if   xlen == 32
            then shamt[4..0]
            else shamt[5..0];
let result = (X(rs1) >> shamt) | (X(rs1) << (xlen - shamt));

X(rd) = result;
--
```

```text
==== sext.b
...
Operation::
[source,sail]
--
X(rd) = EXTS(X(rs)[7..0]);
--
```

```text
==== sext.h
...
Operation::
[source,sail]
--
X(rd) = EXTS(X(rs)[15..0]);
--
```

```text
==== sh1add
...
Operation::
[source,sail]
--
X(rd) = X(rs2) + (X(rs1) << 1);
--
```

```text
==== sh2add
...
Operation::
[source,sail]
--
X(rd) = X(rs2) + (X(rs1) << 2);
--
```

```text
==== sh3add
...
Operation::
[source,sail]
--
X(rd) = X(rs2) + (X(rs1) << 3);
--
```

```text
==== xnor
...
Operation::
[source,sail]
--
X(rd) = ~(X(rs1) ^ X(rs2));
--
```

```text
==== zext.h
...
Operation::
[source,sail]
--
X(rd) = EXTZ(X(rs)[15..0]);
--
```
