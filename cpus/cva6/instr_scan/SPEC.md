# Implement `instr_scan`

Implement the complete `instr_scan` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module instr_scan` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
  localparam config_pkg::cva6_user_cfg_t cva6_cfg = '{
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(32),
// ...
      RVC: bit'(1),
```

## Module declaration

```systemverilog
module instr_scan #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    // Instruction to be predecoded - instr_realign
    input logic [31:0] instr_i,
    // Return instruction - FRONTEND
    output logic rvi_return_o,
    // JAL instruction - FRONTEND
    output logic rvi_call_o,
    // Branch instruction - FRONTEND
    output logic rvi_branch_o,
    // JALR instruction - FRONTEND
    output logic rvi_jalr_o,
    // Unconditional jump instruction - FRONTEND
    output logic rvi_jump_o,
    // Instruction immediate - FRONTEND
    output logic [CVA6Cfg.VLEN-1:0] rvi_imm_o,
    // Branch compressed instruction - FRONTEND
    output logic rvc_branch_o,
    // Unconditional jump compressed instruction - FRONTEND
    output logic rvc_jump_o,
    // JR compressed instruction - FRONTEND
    output logic rvc_jr_o,
    // Return compressed instruction - FRONTEND
    output logic rvc_return_o,
    // JALR compressed instruction - FRONTEND
    output logic rvc_jalr_o,
    // JAL compressed instruction - FRONTEND
    output logic rvc_call_o,
    // Instruction compressed immediate - FRONTEND
    output logic [CVA6Cfg.VLEN-1:0] rvc_imm_o
);
```

## Parent instantiation

### core/frontend/frontend.sv

```systemverilog
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0] is_branch;
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0] is_call;
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0] is_jump;
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0] is_return;
  logic [CVA6Cfg.INSTR_PER_FETCH-1:0] is_jalr;

  for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
    // branch history table -> BHT
    assign is_branch[i] = instruction_valid[i] & (rvi_branch[i] | rvc_branch[i]);
    // function calls -> RAS
    assign is_call[i] = instruction_valid[i] & (rvi_call[i] | rvc_call[i]);
    // function return -> RAS
    assign is_return[i] = instruction_valid[i] & (rvi_return[i] | rvc_return[i]);
    // unconditional jumps with known target -> immediately resolved
    assign is_jump[i] = instruction_valid[i] & (rvi_jump[i] | rvc_jump[i]);
    // unconditional jumps with unknown target -> BTB
    assign is_jalr[i] = instruction_valid[i] & ~is_return[i] & (rvi_jalr[i] | rvc_jalr[i] | rvc_jr[i]);
  end
// ...
      // calculate the jump target address
      if (taken_rvc_cf[i] || taken_rvi_cf[i]) begin
        predict_address = addr[i] + (taken_rvc_cf[i] ? rvc_imm[i] : rvi_imm[i]);
      end
// ...
  // we need to inspect up to CVA6Cfg.INSTR_PER_FETCH instructions for branches
  // and jumps
  for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin : gen_instr_scan
    instr_scan #(
        .CVA6Cfg(CVA6Cfg)
    ) i_instr_scan (
        .instr_i     (instr[i]),
        .rvi_return_o(rvi_return[i]),
        .rvi_call_o  (rvi_call[i]),
        .rvi_branch_o(rvi_branch[i]),
        .rvi_jalr_o  (rvi_jalr[i]),
        .rvi_jump_o  (rvi_jump[i]),
        .rvi_imm_o   (rvi_imm[i]),
        .rvc_branch_o(rvc_branch[i]),
        .rvc_jump_o  (rvc_jump[i]),
        .rvc_jr_o    (rvc_jr[i]),
        .rvc_return_o(rvc_return[i]),
        .rvc_jalr_o  (rvc_jalr[i]),
        .rvc_call_o  (rvc_call[i]),
        .rvc_imm_o   (rvc_imm[i])
    );
  end
```

## Dependency declarations

### core/include/riscv_pkg.sv

```systemverilog
package riscv;
// ...
  localparam OpcodeBranch = 7'b11_000_11;
  localparam OpcodeJalr = 7'b11_001_11;
// ...
  localparam OpcodeJal = 7'b11_011_11;
// ...
  localparam OpcodeC1 = 2'b01;
// ...
  localparam OpcodeC1Jal = 3'b001;  //for RV32I only
// ...
  localparam OpcodeC1J = 3'b101;
  localparam OpcodeC1Beqz = 3'b110;
  localparam OpcodeC1Bnez = 3'b111;
// ...
  localparam OpcodeC2 = 2'b10;
// ...
  localparam OpcodeC2JalrMvAdd = 3'b100;
```

## Documentation

### docs/design/design-manual/source/cva6_frontend.adoc

```text
Each instr_scan submodule pre-decodes the fetched instructions coming from the instr_realign module, also calculate the immediate, instructions could be compressed or not.
The instr_scan submodule is a flow controller which provides the instruction type: branch, jump, return, jalr, imm, call or others.
These outputs are used by the branch prediction feature.
```

### src/rv32.adoc

```text
==== Unconditional Jumps
The jump and link (JAL) instruction uses the J-type format, where the
J-immediate encodes a signed offset in multiples of 2 bytes. The offset
is sign-extended and added to the address of the jump instruction to
form the jump target address. Jumps can therefore target a
&#177;1 MiB range. JAL stores the address of the instruction
following the jump ('pc'+4) into register _rd_. The standard software
calling convention uses 'x1' as the return address register and 'x5' as
an alternate link register.
...
Plain unconditional jumps (assembler pseudoinstruction J) are encoded as
a JAL with _rd_=`x0`.
...
The indirect jump instruction JALR (jump and link register) uses the
I-type encoding. The target address is obtained by adding the
sign-extended 12-bit I-immediate to the register _rs1_, then setting the
least-significant bit of the result to zero. The address of the
instruction following the jump (`pc`+4) is written to register _rd_.
Register `x0` can be used as the destination if the result is not
required.

Plain unconditional indirect jumps (assembler pseudoinstruction JR) are
encoded as a JALR with _rd_=`x0`.
Procedure returns in the standard calling convention (assembler
pseudoinstruction RET) are encoded as a JALR with _rd_=`x0`, _rs1_=`x1`, and
_imm_=0.
...
Return-address prediction stacks are a common feature of
high-performance instruction-fetch units, but require accurate detection
of instructions used for procedure calls and returns to be effective.
For RISC-V, hints as to the instructions' usage are encoded implicitly
via the register numbers used. A JAL instruction should push the return
address onto a return-address stack (RAS) only when _rd_ is 'x1' or
`x5`. JALR instructions should push/pop a RAS as shown in <<rashints>>.

[[rashints]]
.Return-address stack prediction hints encoded in the register operands of a JALR instruction.
[%autowidth,float="center",align="center",cols="^,^,^,<",options="header"]
|===
|_rd_ is _x1/x5_ |_rs1_ is _x1/x5_ |_rd_=_rs1_ |RAS action

|No |No |-- |None

|No |Yes |-- |Pop

|Yes |No |-- |Push

|Yes |Yes |No |Pop, then push

|Yes |Yes |Yes |Push
|===
...
==== Conditional Branches

All branch instructions use the B-type instruction format. The 12-bit
B-immediate encodes signed offsets in multiples of 2 bytes. The offset
is sign-extended and added to the address of the branch instruction to
give the target address. The conditional branch range is
&#177;4 KiB.
```

### src/images/wavedrom/ct-unconditional.edn

```text
{reg: [
  {bits: 7,  name: 'opcode', attr: ['7', 'JAL']},
  {bits: 5,  name: 'rd', attr: ['5', 'dest']},
  {bits: 8,  name: 'imm[19:12]', attr: ['8']},
  {bits: 1,  name: '[11]', attr: ['1']},
  {bits: 10, name: 'imm[10:1]', attr: ['10', 'offset[20:1]']},
  {bits: 1,  name: '[20]', attr: ['1']},
], config:{fontsize: 12}}
```

### src/images/wavedrom/ct-conditional.edn

```text
{reg: [
  {bits: 7,  name: 'opcode',    attr: ['7', 'BRANCH', 'BRANCH', 'BRANCH'] },
  {bits: 5,  name: 'imm[4:1|11]',  attr: ['5', 'offset[4:1|11]', 'offset[4:1|11]', 'offset[4:1|11]'] },
  {bits: 3,  name: 'funct3',     attr: ['3', 'BEQ/BNE', 'BLT[U]', 'BGE[U]'] },
  {bits: 5,  name: 'rs1', attr: ['5', 'src1', 'src1', 'src1'] },
  {bits: 5,  name: 'rs2', attr: ['5', 'src2','src2', 'src2'] },
  {bits: 7,  name: 'imm[12|10:5]', attr: ['7', 'offset[12|10:5]', 'offset[12|10:5]', 'offset[12|10:5]'] },
], config:{fontsize: 10}}
```

### src/c-st-ext.adoc

```text
=== Control Transfer Instructions

RVC provides unconditional jump instructions and conditional branch
instructions. As with base RVI instructions, the offsets of all RVC
control transfer instructions are in multiples of 2 bytes.
...
C.J performs an unconditional control transfer. The offset is
sign-extended and added to the `pc` to form the jump target address. C.J
can therefore target a &#177;2 KiB range. C.J expands to
`jal x0, offset`.

C.JAL is an RV32C-only instruction that performs the same operation as
C.J, but additionally writes the address of the instruction following
the jump (`pc+2`) to the link register, `x1`. C.JAL expands to
`jal x1, offset`.
...
C.JR (jump register) performs an unconditional control transfer to the
address in register _rs1_. C.JR expands to `jalr x0, 0(rs1)`. C.JR is
valid only when _rs1_≠`x0`; the code
point with _rs1_=`x0` is reserved.

C.JALR (jump and link register) performs the same operation as C.JR, but
additionally writes the address of the instruction following the jump
(`pc`+2) to the link register, `x1`. C.JALR expands to
`jalr x1, 0(rs1)`. C.JALR is valid only when
_rs1_≠`x0`; the code point with
_rs1_=`x0` corresponds to the C.EBREAK
instruction.
...
These instructions use the CB format.

C.BEQZ performs conditional control transfers. The offset is
sign-extended and added to the `pc` to form the branch target address.
It can therefore target a &#177;256 B range. C.BEQZ takes the
branch if the value in register _rs1′_ is zero. It
expands to `beq rs1′, x0, offset`.

C.BNEZ is defined analogously, but it takes the branch if
_rs1′_ contains a nonzero value. It expands to
`bne rs1′, x0, offset`.
```

### src/images/wavedrom/c-cj-format-ls.edn

```text
{reg: [
  {bits: 2, name: 'op',     attr: ['2','C1','C1']},
  {bits: 11, name: 'imm',   attr: ['11','offset[11|4|9:8|10|6|7|3:1|5]','offset[11|4|9:8|10|6|7|3:1|5]']},
  {bits: 3, name: 'funct3', attr: ['3','C.J','C.JAL']},
], config: {bits: 16}}
```

### src/images/wavedrom/c-cr-format-ls.edn

```text
{reg: [
  {bits: 2, name: 'op', attr: ['2','C2', 'C2']},
  {bits: 5, name: 'rs2',     attr: ['5','0', '0']},
  {bits: 5, name: 'rs1',     attr: ['5','src≠0', 'src≠0']},
  {bits: 4, name: 'funct4',  attr: ['4','C.JR', 'C.JALR']},
], config: {bits: 16}}
```

### src/images/wavedrom/c-cb-format-ls.edn

```text
{reg: [
  {bits: 2, name: 'op', attr: ['2','C1', 'C1']},
  {bits: 5, name: 'imm', attr: ['5','offset[7:6|2:1|5]', 'offset[7:6|2:1|5]']},
  {bits: 3, name: 'rs1′',     attr: ['3','src', 'src']},
  {bits: 3, name: 'imm',    attr: ['3','offset[8|4:3]', 'offset[8|4:3]'],},
  {bits: 3, name: 'funct3',    attr: ['3','C.BEQZ', 'C.BNEZ'],},
], config: {bits: 16}}
```
