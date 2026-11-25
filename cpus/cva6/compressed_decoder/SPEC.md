# Implement `compressed_decoder`

Implement the complete `compressed_decoder` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module compressed_decoder` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
  localparam config_pkg::cva6_user_cfg_t cva6_cfg = '{
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(32),
      FpgaEn: bit'(0),
// ...
      RVF: bit'(0),
      RVD: bit'(0),
      XF16: bit'(0),
      XF16ALT: bit'(0),
      XF8: bit'(0),
      RVA: bit'(0),
      RVB: bit'(1),
      ZKN: bit'(0),
      RVV: bit'(0),
      RVC: bit'(1),
      RVH: bit'(0),
      RVZCMT: bit'(0),
      RVZCB: bit'(1),
      RVZCMP: bit'(0),
```

## Package and imports

### core/include/riscv_pkg.sv

```systemverilog
package riscv;
// ...
  // --------------------
  // Opcodes
  // --------------------
  // RV32/64G listings:
  // Quadrant 0
  localparam OpcodeLoad = 7'b00_000_11;
  localparam OpcodeLoadFp = 7'b00_001_11;
  localparam OpcodeCustom0 = 7'b00_010_11;
  localparam OpcodeMiscMem = 7'b00_011_11;
  localparam OpcodeOpImm = 7'b00_100_11;
  localparam OpcodeAuipc = 7'b00_101_11;
  localparam OpcodeOpImm32 = 7'b00_110_11;
  // Quadrant 1
  localparam OpcodeStore = 7'b01_000_11;
  localparam OpcodeStoreFp = 7'b01_001_11;
  localparam OpcodeCustom1 = 7'b01_010_11;
  localparam OpcodeAmo = 7'b01_011_11;
  localparam OpcodeOp = 7'b01_100_11;
  localparam OpcodeLui = 7'b01_101_11;
  localparam OpcodeOp32 = 7'b01_110_11;
  // Quadrant 2
  localparam OpcodeMadd = 7'b10_000_11;
  localparam OpcodeMsub = 7'b10_001_11;
  localparam OpcodeNmsub = 7'b10_010_11;
  localparam OpcodeNmadd = 7'b10_011_11;
  localparam OpcodeOpFp = 7'b10_100_11;
  localparam OpcodeVec = 7'b10_101_11;
  localparam OpcodeCustom2 = 7'b10_110_11;
  // Quadrant 3
  localparam OpcodeBranch = 7'b11_000_11;
  localparam OpcodeJalr = 7'b11_001_11;
  localparam OpcodeRsrvd2 = 7'b11_010_11;
  localparam OpcodeJal = 7'b11_011_11;
  localparam OpcodeSystem = 7'b11_100_11;
  localparam OpcodeRsrvd3 = 7'b11_101_11;
  localparam OpcodeCustom3 = 7'b11_110_11;
// ...
  // RV64C/RV32C listings:
  // Quadrant 0
  localparam OpcodeC0 = 2'b00;
  localparam OpcodeC0Addi4spn = 3'b000;
  localparam OpcodeC0Fld = 3'b001;
  localparam OpcodeC0Lw = 3'b010;
  localparam OpcodeC0Ld = 3'b011;
  localparam OpcodeC0Zcb = 3'b100;
  localparam OpcodeC0Fsd = 3'b101;
  localparam OpcodeC0Sw = 3'b110;
  localparam OpcodeC0Sd = 3'b111;
  // Quadrant 1
  localparam OpcodeC1 = 2'b01;
  localparam OpcodeC1Addi = 3'b000;
  localparam OpcodeC1Addiw = 3'b001;  //for RV64I only
  localparam OpcodeC1Jal = 3'b001;  //for RV32I only
  localparam OpcodeC1Li = 3'b010;
  localparam OpcodeC1LuiAddi16sp = 3'b011;
  localparam OpcodeC1MiscAlu = 3'b100;
  localparam OpcodeC1J = 3'b101;
  localparam OpcodeC1Beqz = 3'b110;
  localparam OpcodeC1Bnez = 3'b111;
  // Quadrant 2
  localparam OpcodeC2 = 2'b10;
  localparam OpcodeC2Slli = 3'b000;
  localparam OpcodeC2Fldsp = 3'b001;
  localparam OpcodeC2Lwsp = 3'b010;
  localparam OpcodeC2Ldsp = 3'b011;
  localparam OpcodeC2JalrMvAdd = 3'b100;
  localparam OpcodeC2Fsdsp = 3'b101;
  localparam OpcodeC2Swsp = 3'b110;
  localparam OpcodeC2Sdsp = 3'b111;
```

## Module declaration

```systemverilog
module compressed_decoder #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    // Input instruction coming from fetch stage - FRONTEND
    input  logic [31:0] instr_i,
    // Output instruction in uncompressed format - decoder
    output logic [31:0] instr_o,
    // Input instruction is illegal - decoder
    output logic        illegal_instr_o,
    // Output instruction is macro - decoder
    output logic        is_macro_instr_o,
    // Output instruction is compressed - decoder
    output logic        is_compressed_o,
    // Output instruction is macro - decoder
    output logic        is_zcmt_instr_o
);
```

## Parent instantiation

### core/id_stage.sv

```systemverilog
  if (CVA6Cfg.RVC) begin
    // ---------------------------------------------------------
    // 1. Check if they are compressed and expand in case they are
    // ---------------------------------------------------------
    for (genvar i = 0; i < CVA6Cfg.NrIssuePorts; i++) begin
      compressed_decoder #(
          .CVA6Cfg(CVA6Cfg)
      ) compressed_decoder_i (
          .instr_i         (fetch_entry_i[i].instruction),
          .instr_o         (instruction_rvc[i]),
          .illegal_instr_o (is_illegal_rvc[i]),
          .is_compressed_o (is_compressed_rvc[i]),
          .is_macro_instr_o(is_macro_instr[i]),
          .is_zcmt_instr_o (is_zcmt_instr[i])
      );
    end
  // ...
```

## Related source code

### core/decoder.sv

```systemverilog
        riscv::OpcodeOp: begin
// ...
                // Zero Extend Op RV32 encoding
                {
                  7'b000_0100, 3'b100
                } : begin
                  if (!CVA6Cfg.IS_XLEN64 && instr.instr[24:20] == 5'b00000)
                    instruction_o.op = ariane_pkg::ZEXTH;  // Zero Extend Op RV32 encoding
// ...
        riscv::OpcodeOpImm: begin
// ...
          if (CVA6Cfg.RVB) begin
            unique case (instr.itype.funct3)
              3'b001: begin
                if (instr.instr[31:25] == 7'b0110000) begin
                  if (instr.instr[24:20] == 5'b00100) instruction_o.op = ariane_pkg::SEXTB;
                  else if (instr.instr[24:20] == 5'b00101) instruction_o.op = ariane_pkg::SEXTH;
// ...
```

### verif/env/corev-dv/custom/riscv_zcb_instr.sv

```systemverilog
  constraint rvc_rx_c {
    //  Registers specified by the three-bit rs1’, rs2’, and rd’
      if (has_rs1) {
        rs1 inside {[S0:A5]};
      }
      if (has_rs2) {
        rs2 inside {[S0:A5]};
      }
      if (has_rd) {
        rd inside {[S0:A5]};
      }
    }

  constraint Zcb_imm_c {
    //  Constraint for immediate field
      if (instr_name inside {C_LHU, C_LH, C_SH}) {
        imm[0] == 1'b0;
      }
    }

  virtual function void set_imm_len();
    if (instr_name inside {C_LBU, C_LH, C_LHU, C_SB, C_SH}) begin
      imm_len = 2;
    end
// ...
  virtual function string convert2bin(string prefix = "");
    string binary;
    case (instr_name) inside
      //`uvm_info(`gfn, $sformatf("rs1 = %0s, imm = %b,
      C_LBU:
        binary = $sformatf("0x%4h", {get_func6(), rs1, imm[0], imm[1], rd, get_c_opcode()});
      C_LHU:
        binary = $sformatf("0x%4h", {get_func6(), rs1, 1'b0, imm[1], rd, get_c_opcode()});
      C_LH:
        binary = $sformatf("0x%4h", {get_func6(), rs1 , 1'b1, imm[1],rd , get_c_opcode()});
      C_SB:
        binary = $sformatf("0x%4h", {get_func6(), rs1, imm[0], imm[1] ,rs2 , get_c_opcode()});
      C_SH:
        binary = $sformatf("0x%4h", {get_func6(), rs1, 1'b0, imm[1], rs2, get_c_opcode()});
      C_ZEXT_B:
        binary = $sformatf("0x%4h", {get_func6(), rd, 5'b11000, get_c_opcode()});
      C_SEXT_B:
        binary = $sformatf("0x%4h", {get_func6(), rd, 5'b11001, get_c_opcode()});
      C_ZEXT_H:
        binary = $sformatf("0x%4h", {get_func6(), rd, 5'b11010, get_c_opcode()});
      C_SEXT_H:
        binary = $sformatf("0x%4h", {get_func6(), rd, 5'b11011, get_c_opcode()});
// ...
      C_NOT:
        binary = $sformatf("0x%4h", {get_func6(), rd, 5'b11101, get_c_opcode()});
      C_MUL:
        binary = $sformatf("0x%4h", {get_func6(), rd, 2'b10, rs2, get_c_opcode()});
// ...
  virtual function bit [1:0] get_c_opcode();
    case (instr_name) inside
      C_LBU,C_LH,C_LHU,C_SB,C_SH                      : get_c_opcode = 2'b00;
      C_MUL,C_ZEXT_B,C_SEXT_B,
      C_SEXT_H,C_ZEXT_H,C_ZEXT_W                      : get_c_opcode = 2'b01;
// ...
   virtual function bit [5:0] get_func6();
      case (instr_name) inside
         C_LBU                  : get_func6 = 6'b100000;
         C_LH                   : get_func6 = 6'b100001;
         C_LHU                  : get_func6 = 6'b100001;
         C_SB                   : get_func6 = 6'b100010;
         C_SH                   : get_func6 = 6'b100011;
         C_MUL                  : get_func6 = 6'b100111;
         C_ZEXT_B               : get_func6 = 6'b100111;
         C_SEXT_B               : get_func6 = 6'b100111;
         C_ZEXT_H               : get_func6 = 6'b100111;
         C_SEXT_H               : get_func6 = 6'b100111;
// ...
         C_NOT                  : get_func6 = 6'b100111;
      endcase
   endfunction
```

### corev_apu/bootrom/encoding.h

```c
/* Automatically generated by parse-opcodes.  */
#ifndef RISCV_ENCODING_H
#define RISCV_ENCODING_H
#define MATCH_BEQ 0x63
#define MASK_BEQ  0x707f
#define MATCH_BNE 0x1063
#define MASK_BNE  0x707f
#define MATCH_BLT 0x4063
#define MASK_BLT  0x707f
#define MATCH_BGE 0x5063
#define MASK_BGE  0x707f
#define MATCH_BLTU 0x6063
#define MASK_BLTU  0x707f
#define MATCH_BGEU 0x7063
#define MASK_BGEU  0x707f
#define MATCH_JALR 0x67
#define MASK_JALR  0x707f
#define MATCH_JAL 0x6f
#define MASK_JAL  0x7f
#define MATCH_LUI 0x37
#define MASK_LUI  0x7f
#define MATCH_AUIPC 0x17
#define MASK_AUIPC  0x7f
#define MATCH_ADDI 0x13
#define MASK_ADDI  0x707f
#define MATCH_SLLI 0x1013
#define MASK_SLLI  0xfc00707f
// ...
#define MATCH_XORI 0x4013
#define MASK_XORI  0x707f
#define MATCH_SRLI 0x5013
#define MASK_SRLI  0xfc00707f
#define MATCH_SRAI 0x40005013
#define MASK_SRAI  0xfc00707f
#define MATCH_ORI 0x6013
#define MASK_ORI  0x707f
#define MATCH_ANDI 0x7013
#define MASK_ANDI  0x707f
#define MATCH_ADD 0x33
#define MASK_ADD  0xfe00707f
#define MATCH_SUB 0x40000033
#define MASK_SUB  0xfe00707f
#define MATCH_SLL 0x1033
#define MASK_SLL  0xfe00707f
#define MATCH_SLT 0x2033
#define MASK_SLT  0xfe00707f
#define MATCH_SLTU 0x3033
#define MASK_SLTU  0xfe00707f
#define MATCH_XOR 0x4033
#define MASK_XOR  0xfe00707f
#define MATCH_SRL 0x5033
#define MASK_SRL  0xfe00707f
#define MATCH_SRA 0x40005033
#define MASK_SRA  0xfe00707f
#define MATCH_OR 0x6033
#define MASK_OR  0xfe00707f
#define MATCH_AND 0x7033
// ...
#define MATCH_LB 0x3
#define MASK_LB  0x707f
#define MATCH_LH 0x1003
#define MASK_LH  0x707f
#define MATCH_LW 0x2003
#define MASK_LW  0x707f
#define MATCH_LD 0x3003
#define MASK_LD  0x707f
#define MATCH_LBU 0x4003
#define MASK_LBU  0x707f
#define MATCH_LHU 0x5003
#define MASK_LHU  0x707f
#define MATCH_LWU 0x6003
#define MASK_LWU  0x707f
#define MATCH_SB 0x23
#define MASK_SB  0x707f
#define MATCH_SH 0x1023
#define MASK_SH  0x707f
#define MATCH_SW 0x2023
#define MASK_SW  0x707f
#define MATCH_SD 0x3023
#define MASK_SD  0x707f
#define MATCH_FENCE 0xf
#define MASK_FENCE  0x707f
#define MATCH_FENCE_I 0x100f
#define MASK_FENCE_I  0x707f
#define MATCH_MUL 0x2000033
#define MASK_MUL  0xfe00707f
// ...
#define MATCH_EBREAK 0x100073
#define MASK_EBREAK  0xffffffff
```

## Documentation

### docs/design/design-manual/source/cva6_id_stage.adoc

```text
[[compressed_decoder]]
Compressed_decoder
++++++++++++++++++

The compressed_decoder module decompresses all the compressed
instructions taking a 16-bit compressed instruction and expanding it to
its 32-bit equivalent. All compressed instructions have a 32-bit
equivalent.

Non-compressed instructions on the input are transmitted as-is.
```

### src/c-st-ext.adoc

```text
These instructions use the CI format.

C.LWSP loads a 32-bit value from memory into register _rd_. It computes
an effective address by adding the _zero_-extended offset, scaled by 4,
to the stack pointer, `x2`. It expands to `lw rd, offset(x2)`. C.LWSP is
valid only when _rd_≠`x0`; the code points with _rd_=`x0` are reserved.

...

These instructions use the CSS format.

C.SWSP stores a 32-bit value in register _rs2_ to memory. It computes an
effective address by adding the _zero_-extended offset, scaled by 4, to
the stack pointer, `x2`. It expands to `sw rs2, offset(x2)`.

...

These instructions use the CL format.

C.LW loads a 32-bit value from memory into register
`_rd′_`. It computes an effective address by adding the
_zero_-extended offset, scaled by 4, to the base address in register
`_rs1′_`. It expands to `lw rd′, offset(rs1′)`.

...

These instructions use the CS format.

C.SW stores a 32-bit value in register `_rs2′_` to memory.
It computes an effective address by adding the _zero_-extended offset,
scaled by 4, to the base address in register `_rs1′_`. It
expands to `sw rs2′, offset(rs1′)`.

...

RVC provides unconditional jump instructions and conditional branch
instructions. As with base RVI instructions, the offsets of all RVC
control transfer instructions are in multiples of 2 bytes.

[[c-cj-format-ls]]
include::images/wavedrom/c-cj-format-ls.edn[]
//.Compressed, CJ format load and store--these instructions use the CJ format.
(((compressed, cj-format load and store)))

These instructions use the CJ format.

C.J performs an unconditional control transfer. The offset is
sign-extended and added to the `pc` to form the jump target address. C.J
can therefore target a &#177;2 KiB range. C.J expands to
`jal x0, offset`.

C.JAL is an RV32C-only instruction that performs the same operation as
C.J, but additionally writes the address of the instruction following
the jump (`pc+2`) to the link register, `x1`. C.JAL expands to
`jal x1, offset`.

...

These instructions use the CR format.

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

...

The two constant-generation instructions both use the CI instruction
format and can target any integer register.

[[c-integer-const-gen]]
include::images/wavedrom/c-integer-const-gen.edn[]
//.Integer constant generation format.
(((compressed, integer constant generation)))


C.LI loads the sign-extended 6-bit immediate, _imm_, into register _rd_.
C.LI expands into `addi rd, x0, imm`. C.LI is valid only when
_rd_≠`x0`; the code points with _rd_=`x0` encode HINTs.

C.LUI loads the non-zero 6-bit immediate field into bits 17–12 of the
destination register, clears the bottom 12 bits, and sign-extends bit 17
into all higher bits of the destination. C.LUI expands into
`lui rd, imm`. C.LUI is valid only when
_rd_≠{`x0`,`x2`},
and when the immediate is not equal to zero. The code points with
_imm_=0 are reserved; the remaining code points with _rd_=`x0` are
HINTs; and the remaining code points with _rd_=`x2` correspond to the
C.ADDI16SP instruction.

...

These integer register-immediate operations are encoded in the CI format
and perform operations on an integer register and a 6-bit immediate.

[[c-integer-register-immediate]]
include::images/wavedrom/c-int-reg-immed.edn[]
//.Integer register-immediate format.
(((compressed, integer register-immediate)))

C.ADDI adds the non-zero sign-extended 6-bit immediate to the value in
register _rd_ then writes the result to _rd_. C.ADDI expands into
`addi rd, rd, imm`. C.ADDI is valid only when
_rd_≠`x0` and _imm_≠0. The code
points with _rd_=`x0` encode the C.NOP instruction; the remaining code
points with _imm_=0 encode HINTs.

...

C.ADDI16SP (add immediate to stack pointer)
shares the opcode with C.LUI, but has a destination field of
`x2`. C.ADDI16SP adds the non-zero sign-extended 6-bit immediate to the
value in the stack pointer (`sp=x2`), where the immediate is scaled to
represent multiples of 16 in the range [-512, 496]. C.ADDI16SP is used to
adjust the stack pointer in procedure prologues and epilogues. It
expands into `addi x2, x2, nzimm[9:4]`. C.ADDI16SP is valid only when
_nzimm_≠0; the code point with _nzimm_=0 is reserved.

...

C.ADDI4SPN (add immediate to stack pointer, non-destructive)
is a CIW-format instruction that adds a _zero_-extended
non-zero immediate, scaled by 4, to the stack pointer, `x2`, and writes
the result to `rd′`. This instruction is used to generate
pointers to stack-allocated variables, and expands to
`addi rd′, x2, nzuimm[9:2]`. C.ADDI4SPN is valid only when
_nzuimm_≠0; the code points with _nzuimm_=0 are
reserved.

...

C.SLLI is a CI-format instruction that performs a logical left shift of
the value in register _rd_ then writes the result to _rd_. The shift
amount is encoded in the _shamt_ field. For RV128C, a shift amount of
zero is used to encode a shift of 64. C.SLLI expands into
`slli rd, rd, shamt[5:0]`, except for RV128C with `shamt=0`, which expands to
`slli rd, rd, 64`.

For RV32C, _shamt[5]_ must be zero; the code points with _shamt[5]_=1
are designated for custom extensions. For RV32C and RV64C, the shift
amount must be non-zero; the code points with _shamt_=0 are HINTs. For
all base ISAs, the code points with _rd_=`x0` are HINTs, except those
with _shamt[5]_=1 in RV32C.

...

C.SRLI is a CB-format instruction that performs a logical right shift of
the value in register _rd′_ then writes the result to
_rd′_. The shift amount is encoded in the _shamt_ field.
For RV128C, a shift amount of zero is used to encode a shift of 64.
Furthermore, the shift amount is sign-extended for RV128C, and so the
legal shift amounts are 1-31, 64, and 96-127. C.SRLI expands into
`srli rd′, rd′, shamt`, except for
RV128C with `shamt=0`, which expands to
`srli rd′, rd′, 64`.

For RV32C, _shamt[5]_ must be zero; the code points with _shamt[5]_=1
are designated for custom extensions. For RV32C and RV64C, the shift
amount must be non-zero; the code points with _shamt_=0 are HINTs.

C.SRAI is defined analogously to C.SRLI, but instead performs an
arithmetic right shift. C.SRAI expands to
`srai rd′, rd′, shamt`.

...

C.ANDI is a CB-format instruction that computes the bitwise AND of the
value in register _rd′_ and the sign-extended 6-bit
immediate, then writes the result to _rd′_. C.ANDI
expands to `andi rd′, rd′, imm`.

...

These instructions use the CR format.

C.MV copies the value in register _rs2_ into register _rd_. C.MV expands
into `add rd, x0, rs2`. C.MV is valid only when
_rs2_≠`x0`; the code points with _rs2_=`x0` correspond to the C.JR instruction. The code points with _rs2_≠`x0` and _rd_=`x0` are HINTs.

...

C.ADD adds the values in registers _rd_ and _rs2_ and writes the result
to register _rd_. C.ADD expands into `add rd, rd, rs2`. C.ADD is only
valid when _rs2_≠`x0`; the code points with _rs2_=`x0` correspond to the C.JALR
and C.EBREAK instructions. The code points with _rs2_≠`x0` and _rd_=`x0` are HINTs.

...

These instructions use the CA format.

`C.AND` computes the bitwise `AND` of the values in registers
_rd′_ and _rs2′_, then writes the result
to register _rd′_. `C.AND` expands into
*`_and rd′, rd′, rs2′_`*.

`C.OR` computes the bitwise `OR` of the values in registers
_rd′_ and _rs2′_, then writes the result
to register _rd′_. `C.OR` expands into
*`_or rd&#8242;, rd&#8242;, rs2&#8242;_`*.

`C.XOR` computes the bitwise `XOR` of the values in registers
_rd′_ and _rs2′_, then writes the result
to register _rd′_. `C.XOR` expands into
*`_xor rd′, rd′, rs2′_`*.

`C.SUB` subtracts the value in register _rs2′_ from the
value in register _rd′_, then writes the result to
register _rd′_. `C.SUB` expands into
*`_sub rd′, rd′, rs2′_`*.

...

==== Defined Illegal Instruction

[[c-def-illegal-inst]]
include::images/wavedrom/c-def-illegal-inst.edn[]
((((compressed. C.DIINST))))

A 16-bit instruction with all bits zero is permanently reserved as an
illegal instruction.

...

==== NOP Instruction

[[c-nop-instr]]
include::images/wavedrom/c-nop-instr.edn[]
((((compressed. C.NOPINSTR))))

`C.NOP` is a CI-format instruction that does not change any user-visible
state, except for advancing the `pc` and incrementing any applicable
performance counters. `C.NOP` expands to `nop`. `C.NOP` is valid only when
_imm_=0; the code points with _imm_≠0 encode HINTs.

...

==== Breakpoint Instruction

[[c-breakpoint-instr]]
include::images/wavedrom/c-breakpoint-instr.edn[]
((((compressed. C.BREAKPOINTINSTR))))

Debuggers can use the `C.EBREAK` instruction, which expands to `ebreak`,
to cause control to be transferred back to the debugging environment.
`C.EBREAK` shares the opcode with the `C.ADD` instruction, but with _rd_ and
_rs2_ both zero, thus can also use the `CR` format.
```

### src/images/wavedrom/c-sp-load-store.edn

```text
//## 16.3 Load and Store Instructions
//### Stack-Pointer-Based Loads and Stores

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',     attr: ['2','C2','C2','C2','C2','C2']},
  {bits: 5, name: 'imm',    attr: ['5','offset[4:2|7:6]', 'offset[4:3|8:6]', 'offset[4|9:6]', 'offset[4:2|7:6]', 'offset[4:3|8:6]']},
  {bits: 5, name: 'rd',     attr: ['5','dest≠0', 'dest≠0', 'dest≠0', 'dest', 'dest']},
  {bits: 1, name: 'imm',    attr: ['1','offset[5]','offset[5]','offset[5]','offset[5]','offset[5]']},
  {bits: 3, name: 'funct3', attr: ['3','C.LWSP', 'C.LDSP', 'C.LQSP', 'C.FLWSP', 'C.FLDSP']},
], config: {bits: 16}}
....
```

### src/images/wavedrom/c-sp-load-store-css.edn

```text
//c-sp load and store, css format--is this correct?

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',     attr: ['2','C2','C2','C2','C2','C2']},
  {bits: 5, name: 'rs2',    attr: ['5','src', 'src', 'src', 'src', 'src']},
  {bits: 6, name: 'imm',    attr: ['6','offset[5:2|7:6]', 'offset[5:3|8:6]', 'offset[5:4|9:6]', 'offset[5:2|7:6]','offset[5:3|8:6]']},
  {bits: 3, name: 'funct3', attr: ['3','C.SWSP', 'C.SDSP', 'C.SQSP', 'C.FSWSP', 'C.FSDSP']},
], config: {bits: 16}}
....
```

### src/images/wavedrom/reg-based-ldnstr.edn

```text
//Register-Based loads and Stores


[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2', 'C0', 'C0', 'C0', 'C0', 'C0']},
  {bits: 3, name: 'rdʹ',  attr: ['3', 'dest', 'dest','dest','dest','dest']},
  {bits: 2, name: 'imm', attr:['2', 'offset[2|6]', 'offset[7:6]', 'offset[7:6]', 'offset[2|6]', 'offset[7:6]']},
  {bits: 3, name: 'rs1ʹ', attr: ['3', 'base', 'base', 'base', 'base', 'base']},
  {bits: 3, name: 'imm',  attr: ['3', 'offset[5:3]', 'offset[5:3]', 'offset[5|4|8]', 'offset[5:3]', 'offset[5:3]']},
  {bits: 3, name: 'funct3',  attr: ['3', 'C.LW', 'C.LD', 'C.LQ', 'C.FLW', 'C.FLD']},
], config: {bits: 16}}
....
```

### src/images/wavedrom/c-cs-format-ls.edn

```text
//## 16.X Load and Store Instructions
//### c-cs-format-ls

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',     attr: ['2', 'C0','C0','C0','C0','C0']},
  {bits: 3, name: 'rs2ʹ',   attr: ['3', 'src','src','src','src','src']},
  {bits: 2, name: 'imm',    attr: ['2', 'offset[2|6]','offset[7:6]','offset[7:6]','offset[2|6]','offset[7:6]']},
  {bits: 3, name: 'rs1ʹ',   attr: ['3', 'base','base','base','base','base']},
  {bits: 3, name: 'imm',    attr: ['3', 'offset[5:3]','offset[5:3]','offset[5|4|8]','offset[5:3]','offset[5:3]']},
  {bits: 3, name: 'funct3', attr: ['3', 'C.SW','C.SD','C.SQ','C.FSW','C.FSD']},
], config: {bits: 16}}
....
```

### src/images/wavedrom/c-cj-format-ls.edn

```text
//c-cj-format-ls

//[wavedrom, ,svg]
//....
//{reg: [
//	{bits: 2,  name: 'op', attr: ['2','CI','CI']},
//	{bits: 10, name: 'imm'},
//	{bits: 4,  name: 'funct3' attr:['3','CJ','CJAL']},
//] config: {bits: 16}}
//....


[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',     attr: ['2','C1','C1']},
  {bits: 11, name: 'imm',   attr: ['11','offset[11|4|9:8|10|6|7|3:1|5]','offset[11|4|9:8|10|6|7|3:1|5]']},
  {bits: 3, name: 'funct3', attr: ['3','C.J','C.JAL']},
], config: {bits: 16}}
....
```

### src/images/wavedrom/c-cr-format-ls.edn

```text
//These instructions use the CR format.

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C2', 'C2']},
  {bits: 5, name: 'rs2',     attr: ['5','0', '0']},
  {bits: 5, name: 'rs1',     attr: ['5','src≠0', 'src≠0']},
  {bits: 4, name: 'funct4',  attr: ['4','C.JR', 'C.JALR']},
], config: {bits: 16}}
....
```

### src/images/wavedrom/c-cb-format-ls.edn

```text
//c-cb-format-ls

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C1', 'C1']},
  {bits: 5, name: 'imm', attr: ['5','offset[7:6|2:1|5]', 'offset[7:6|2:1|5]']},
  {bits: 3, name: 'rs1′',     attr: ['3','src', 'src']},
  {bits: 3, name: 'imm',    attr: ['3','offset[8|4:3]', 'offset[8|4:3]'],},
  {bits: 3, name: 'funct3',    attr: ['3','C.BEQZ', 'C.BNEZ'],},
], config: {bits: 16}}
....
```

### src/images/wavedrom/c-integer-const-gen.edn

```text
//c-integer-const-gen

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C1', 'C1']},
  {bits: 5, name: 'imm[4:0]',    attr: ['5','imm[4:0]','nzimm[16:12]']},
  {bits: 5, name: 'rd',     attr: ['5','dest != 0', 'dest != {0, 2}']},
  {bits: 1, name: 'imm[5]',    attr: ['1','imm[5]', 'nzimm[17]'],},
  {bits: 3, name: 'funct3',    attr: ['3','C.LI', 'C.LUI'],},
], config: {bits: 16}}
....
```

### src/images/wavedrom/c-int-reg-immed.edn

```text
//c-int-reg-immed.adoc

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',        attr: ['2','C1', 'C1', 'C1']},
  {bits: 5, name: 'imm[4:]',  attr: ['5','nzimm[4:0]', 'imm[4:0]', 'nzimm[4|6|8:7|5]']},
  {bits: 5, name: 'rd/rs1',    attr: ['5','dest != 0', 'dest != 0', '2']},
  {bits: 1, name: 'imm[5]',    attr: ['1','nzimm[5]', 'imm[5]', 'nzimm[9]']},
  {bits: 3, name: 'funct3',    attr: ['3','C.ADDI', 'C.ADDIW', 'C.ADDI16SP']},
], config: {bits: 16}}
....
```

### src/images/wavedrom/c-ciw.edn

```text
//c-ciw.adoc

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C0'],},
  {bits: 3, name: 'rd′',     attr: ['3','dest'],},
  {bits: 8, name: 'imm',    attr: ['8','nzuimm[5:4|9:6|2|3]']},
  {bits: 3, name: 'funct3',    attr: ['3','C.ADDI4SPN']},
], config: {bits: 16}}
....
```

### src/images/wavedrom/c-ci.edn

```text
//

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2', 'C2']},
  {bits: 5, name: 'shamt[4:0]',    attr: ['5', 'shamt[4:0]']},
  {bits: 5, name: 'rd/rs1',     attr: ['5', 'dest != 0']},
  {bits: 1, name: 'shamt[5]',    attr: ['1', 'shamt[5]']},
  {bits: 3, name: 'funct3',    attr: ['3', 'C.SLLI']},
]}
....
```

### src/images/wavedrom/c-srli-srai.edn

```text
//c-srli-srai.adoc

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C1', 'C1'],},
  {bits: 5, name: 'shamt[4:0]',    attr: ['5','shamt[4:0]', 'shamt[4:0]'],},
  {bits: 3, name: 'rd′/rs1′',     attr: ['3','dest', 'dest'],},
  {bits: 2, name: 'funct2',    attr: ['2','C.SRLI', 'C.SRAI'],},
  {bits: 1, name: 'shamt[5]',    attr: ['1','shamt[5]', 'shamt[5]'],},
  {bits: 3, name: 'funct3',    attr: ['3','C.SRLI', 'C.SRAI'],},
]}
```

### src/images/wavedrom/c-andi.edn

```text
//c-andi.adoc

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',    attr: ['2','C1'],},
  {bits: 5, name: 'imm[4:0]',    attr: ['5','imm[4:0]']},
  {bits: 3, name: 'rd′/rs1′',    attr: ['3','dest'],},
  {bits: 2, name: 'funct2',     attr: ['2','C.ANDI'],},
  {bits: 1, name: 'imm[5]',    attr: ['1','imm[5]'],},
  {bits: 3, name: 'funct3', attr: ['3','C.ANDI'],},
]}
```

### src/images/wavedrom/c-int-reg-to-reg-cr-format.edn

```text
//

[wavedrom, ,svg]

....
{reg: [
  {bits: 2, name: 'op',     attr: ['2', 'C2', 'C2'],},
  {bits: 5, name: 'rs2',    attr: ['5', 'src≠0', 'src≠0'],},
  {bits: 5, name: 'rd/rs1', attr: ['5', 'dest≠0', 'dest≠0'],},
  {bits: 4, name: 'funct4', attr: ['4', 'C.MV', 'C.ADD'],},
], config: {bits: 16}} 
```

### src/images/wavedrom/c-int-reg-to-reg-ca-format.edn

```text
//

[wavedrom, ,svg]

....
{reg: [
  {bits: 2, name: 'op',     attr: ['2', 'C1', 'C1', 'C1', 'C1', 'C1', 'C1'],},
  {bits: 3, name: 'rs2′',    attr: ['3', 'src', 'src', 'src', 'src', 'src', 'src'],},
  {bits: 2, name: 'funct2', attr: ['2', 'C.AND', 'C.OR', 'C.XOR', 'C.SUB', 'C.ADDW', 'C.SUBW'],},
  {bits: 3, name: 'rd′/rs1′', attr: ['3', 'dest', 'dest', 'dest', 'dest', 'dest', 'dest'],},
  {bits: 6, name: 'funct6', attr: ['6', 'C.AND', 'C.OR', 'C.XOR', 'C.SUB', 'C.ADDW', 'C.SUBW'],},
]} 
```

### docs/01_cva6_user/RISCV_Instructions_RV32ZCb.rst

```text
- **C.ZEXT.B**: Compressed Zero Extend Byte

    **Format**: c.zext.b rd'

    **Description**: This instruction takes a single source/destination operand. It zero-extends the least-significant byte of the operand by inserting zeros into all of the bits more significant than 7.

    **Pseudocode**: x[8 + rd'] = zext(x[8 + rd'][7:0])

...

- **C.SEXT.B**: Compressed Sign Extend Byte

    **Format**: c.sext.b rd'

    **Description**: This instruction takes a single source/destination operand. It sign-extends the least-significant byte in the operand by copying the most-significant bit in the byte (i.e., bit 7) to all of the more-significant bits. It also requires Bit-Manipulation (Zbb) extension support.

    **Pseudocode**: x[8 + rd'] = sext(x[8 + rd'][7:0])

...

- **C.ZEXT.H**: Compressed Zero Extend Halfword

    **Format**: c.zext.h rd'

    **Description**: This instruction takes a single source/destination operand. It zero-extends the least-significant halfword of the operand by inserting zeros into all of the bits more significant than 15. It also requires Bit-Manipulation (Zbb) extension support.

    **Pseudocode**: x[8 + rd'] = zext(x[8 + rd'][15:0])

...

- **C.SEXT.H**: Compressed Sign Extend Halfword

    **Format**: c.sext.h rd'

    **Description**: This instruction takes a single source/destination operand. It sign-extends the least-significant halfword in the operand by copying the most-significant bit in the halfword (i.e., bit 15) to all of the more-significant bits.  It also requires Bit-Manipulation (Zbb) extension support.

    **Pseudocode**: x[8 + rd'] = sext(x[8 + rd'][15:0])

...

- **C.NOT**: Compressed Bitwise NOT

    **Format**: c.not rd'

    **Description**: This instruction takes the one’s complement of rd'/rs1' and writes the result to the same register.

    **Pseudocode**: x[8 + rd'] = x[8 + rd'] ^ -1

...

- **C.MUL**: Compressed Multiply

    **Format**: c.mul rd', rs2'

    **Description**: performs a 32-bit × 32-bit multiplication and places the lower 32 bits in the destination register (Both rd' and rs2' treated as signed numbers). It also requires M extension support.

    **Pseudocode**: x[8 + rd'] = (x[8 + rd'] * x[8 + rs2'])[31:0]

...

- **C.LHU**: Compressed Load Halfword Unsigned

    **Format**: c.lhu rd', uimm(rs1')

    **Description**: This instruction loads a halfword from the memory address formed by adding rs1' to the zero extended immediate uimm. The resulting halfword is zero extended and is written to rd'.

    **Pseudocode**: x[8+rd'] = zext(M[x[8+rs1'] + zext(uimm[1])][15:0])

...

- **C.LH**: Compressed Load Halfword

    **Format**: c.lh rd', uimm(rs1')

    **Description**: This instruction loads a halfword from the memory address formed by adding rs1' to the zero extended immediate uimm. The resulting halfword is sign extended and is written to rd'.

    **Pseudocode**: x[8+rd'] = sext(M[x[8+rs1'] + zext(uimm[1])][15:0])

...

- **C.LBU**: Compressed Load Byte Unsigned

    **Format**: c.lbu rd', uimm(rs1')

    **Description**: This instruction loads a byte from the memory address formed by adding rs1' to the zero extended immediate uimm. The resulting byte is zero extended and is written to rd'.

    **Pseudocode**: x[8+rd'] = zext(M[x[8+rs1'] + zext(uimm[1:0])][7:0])

...

- **C.SH**: Compressed Store Halfword

    **Format**: c.sh rs2', uimm(rs1')

    **Description**: This instruction stores the least significant halfword of rs2' to the memory address formed by adding rs1' to the zero extended immediate uimm.

    **Pseudocode**: M[x[8+rs1'] + zext(uimm[1])][15:0] = x[8+rs2']

...

- **C.SB**: Compressed Store Byte

    **Format**: c.sb rs2', uimm(rs1')

    **Description**: This instruction stores the least significant byte of rs2' to the memory address formed by adding rs1' to the zero extended immediate uimm.

    **Pseudocode**: M[x[8+rs1'] + zext(uimm[1:0])][7:0] = x[8+rs2']
```

### src/zc.adoc

```text
=== Zc instruction formats

Several instructions in this specification use the following new instruction formats.

[%header,cols="2,3,2,1,1,1,1,1,1,1,1,1,1"]
|=====================================================================
| Format | instructions       | 15:10  | 9  | 8 | 7   | 6 | 5 | 4   | 3 | 2  | 1 | 0
| CLB    | c.lbu              | funct6 3+| rs1'    2+| uimm    3+| rd'    2+| op
| CSB    | c.sb               | funct6 3+| rs1'    2+| uimm    3+| rs2'   2+| op
| CLH    | c.lhu, c.lh        | funct6 3+| rs1'    | funct1 | uimm 3+| rd'  2+| op
| CSH    | c.sh               | funct6 3+| rs1'    | funct1 | uimm 3+| rs2' 2+| op
| CU     | c.[sz]ext.*, c.not | funct6 3+| rd'/rs1' 5+| funct5            2+| op
| CMMV   | cm.mvsa01 cm.mva01s| funct6 3+| r1s'     2+| funct2 3+| r2s'   2+| op
| CMJT   | cm.jt cm.jalt      | funct6 8+| index                          2+| op
| CMPP   | cm.push*, cm.pop*  | funct6 2+| funct2 4+| urlist   2+| spimm  2+| op
|=====================================================================

[NOTE]
====
c.mul uses the existing CA format.
====

...

==== c.zext.b

...

32-bit equivalent:

[source,sail]
----
andi rd'/rs1', rd'/rs1', 0xff
----

...

==== c.zext.w

Synopsis:

Zero extend word, 16-bit encoding

Mnemonic:

c.zext.w _rd'/rs1'_

Encoding (RV64):

[wavedrom, , svg]
....
{reg:[
    { bits:  2, name: 0x1, attr: ['C1'] },
    { bits:  3, name: 0x4, attr: ['C.ZEXT.W'] },
    { bits:  2, name: 0x3, attr: ['FUNCT2'] },
    { bits:  3, name: 'rd\'/rs1\'', attr: ['SRCDST'] },
    { bits:  3, name: 0x7 },
    { bits:  3, name: 0x4, attr: ['FUNCT3'] },
],config:{bits:16}}
....

...

==== c.not

...

32-bit equivalent:

[source,sail]
----
xori rd'/rs1', rd'/rs1', -1
----
```

## Additional requirement

When `illegal_instr_o` is 1, `instr_o` equals `instr_i`.
