# Implement `Alu`

Implement the complete `Alu` class. Preserve the class name and interface shown below.

Return only the complete `class Alu` definition in a single Scala code block, with no text outside the block.

## Class declaration

### src/main/scala/rift2Core/backend/Alu.scala

```scala
class Alu(implicit p: Parameters) extends RiftModule {

  class AluIO extends Bundle{
    val alu_iss_exe = Flipped(new DecoupledIO(new Alu_iss_info))
    val alu_exe_iwb = new DecoupledIO(new WriteBack_info(dw=64))

    val flush = Input(Bool())    
  }
  
  val io = IO(new AluIO)
```

## Parent instantiation

### src/main/scala/rift2Core/backend/Execute.scala

```scala
    val alu_iss_exe = Vec(aluNum, Flipped(Decoupled(new Alu_iss_info)))
    val alu_exe_iwb = Vec(aluNum, Decoupled(new WriteBack_info(dw=64)))
// ...
  val alu = for( _ <- 0 until aluNum ) yield Module(new Alu)
// ...
  for( i <- 0 until aluNum ) {
    alu(i).io.alu_iss_exe <> io.alu_iss_exe(i)
    alu(i).io.alu_exe_iwb <> io.alu_exe_iwb(i)
    alu(i).io.flush <> io.flush    
  }
```

## Dependency declarations

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class Alu_function(implicit p: Parameters) extends RiftBundle {

  val add = Bool()
  val slt = Bool()
  val xor = Bool()
  val or  = Bool()
  val and = Bool()
  val sll = Bool()
  val srl = Bool()
  val sra = Bool()
}

class Alu_param(implicit p: Parameters) extends RD_PHY {
  val is_32w = Bool()
  val is_usi = Bool()

  val dat = new Operation_source(dw=64)
}

class Alu_iss_info(implicit p: Parameters) extends RiftBundle {
  val fun = new Alu_function
  val param = new Alu_param
}
// ...
class RD_PHY(implicit p: Parameters) extends RiftBundle {
  val rd0 = UInt((log2Ceil(maxRegNum)).W)
}

class Operation_source(dw: Int)(implicit p: Parameters) extends RiftBundle {
  val op0 = UInt(dw.W)
  val op1 = UInt(dw.W)
  val op2 = UInt(dw.W)
  val op3 = UInt(dw.W)
}
// ...
class WriteBack_info(dw:Int)(implicit p: Parameters) extends RD_PHY {
  val res = UInt(dw.W)
}
```

## Related source code

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
  def is_32w = addiw | addw | subw | slliw | sllw | srliw | srlw | sraiw | sraw;
  def is_usi = sltiu | sltu
  def is_imm =  lui | auipc | addi | addiw | slti | sltiu | xori | ori | andi | slli | slliw | srli | srliw | srai | sraiw

  def is_fun_add = addi | addiw | add | addw | lui | auipc | sub | subw | wfi
  def is_fun_slt = slti | sltiu | slt | sltu
  def is_fun_xor = xori | xor
  def is_fun_or  = ori | or
  def is_fun_and = andi | and
  def is_fun_sll = slli | slliw | sll | sllw
  def is_fun_srl = srli | srliw | srl | srlw
  def is_fun_sra = srai | sraiw | sra | sraw

  def is_alu = lui | auipc | addi | addiw | slti | sltiu | xori | ori | andi | slli | slliw | srli | srliw | srai | sraiw | add | addw | sub | subw | sll | sllw | slt | sltu | xor | srl | srlw | sra | sraw | or |and |wfi
```

### src/main/scala/rift2Core/backend/Issue.scala

```scala
  def Pkg_alu_iss(idx: Int): Alu_iss_info = {

    val res = Wire(new Alu_iss_info)
    val src1 = postBufOperator(idx)(1)
    val src2 = postBufOperator(idx)(2)
    res.fun.add := bufInfo(idx).aluIsa.is_fun_add
    res.fun.slt := bufInfo(idx).aluIsa.is_fun_slt
    res.fun.xor := bufInfo(idx).aluIsa.is_fun_xor
    res.fun.or  := bufInfo(idx).aluIsa.is_fun_or
    res.fun.and := bufInfo(idx).aluIsa.is_fun_and
    res.fun.sll := bufInfo(idx).aluIsa.is_fun_sll
    res.fun.srl := bufInfo(idx).aluIsa.is_fun_srl
    res.fun.sra := bufInfo(idx).aluIsa.is_fun_sra

    res.param.is_32w  := bufInfo(idx).aluIsa.is_32w
    res.param.is_usi  := bufInfo(idx).aluIsa.is_usi


    res.param.dat.op1 :=
      Mux1H(Seq(
        bufInfo(idx).aluIsa.lui    -> 0.U,  bufInfo(idx).aluIsa.auipc  -> extVaddr(bufInfo(idx).param.pc, vlen),
        bufInfo(idx).aluIsa.addi   -> src1, bufInfo(idx).aluIsa.addiw  -> src1,
        bufInfo(idx).aluIsa.slti   -> src1, bufInfo(idx).aluIsa.sltiu  -> src1,
        bufInfo(idx).aluIsa.xori   -> src1, bufInfo(idx).aluIsa.ori    -> src1,
        bufInfo(idx).aluIsa.andi   -> src1, bufInfo(idx).aluIsa.slli   -> src1,
        bufInfo(idx).aluIsa.slliw  -> src1, bufInfo(idx).aluIsa.srli   -> src1,
        bufInfo(idx).aluIsa.srliw  -> src1, bufInfo(idx).aluIsa.srai   -> src1,
        bufInfo(idx).aluIsa.sraiw  -> src1, bufInfo(idx).aluIsa.add    -> src1,
        bufInfo(idx).aluIsa.addw   -> src1, bufInfo(idx).aluIsa.sub    -> src1,
        bufInfo(idx).aluIsa.subw   -> src1, bufInfo(idx).aluIsa.sll    -> src1,
        bufInfo(idx).aluIsa.sllw   -> src1, bufInfo(idx).aluIsa.slt    -> src1,
        bufInfo(idx).aluIsa.sltu   -> src1, bufInfo(idx).aluIsa.xor    -> src1,
        bufInfo(idx).aluIsa.srl    -> src1, bufInfo(idx).aluIsa.srlw   -> src1,
        bufInfo(idx).aluIsa.sra    -> src1, bufInfo(idx).aluIsa.sraw   -> src1,
        bufInfo(idx).aluIsa.or     -> src1, bufInfo(idx).aluIsa.and    -> src1,

        bufInfo(idx).aluIsa.wfi    -> 0.U,

    ))

    res.param.dat.op2 :=
      Mux1H(Seq(
        bufInfo(idx).aluIsa.lui    -> bufInfo(idx).param.imm,      bufInfo(idx).aluIsa.auipc  -> bufInfo(idx).param.imm,
        bufInfo(idx).aluIsa.addi   -> bufInfo(idx).param.imm,      bufInfo(idx).aluIsa.addiw  -> bufInfo(idx).param.imm,
        bufInfo(idx).aluIsa.slti   -> bufInfo(idx).param.imm,      bufInfo(idx).aluIsa.sltiu  -> bufInfo(idx).param.imm,
        bufInfo(idx).aluIsa.xori   -> bufInfo(idx).param.imm,      bufInfo(idx).aluIsa.ori    -> bufInfo(idx).param.imm,
        bufInfo(idx).aluIsa.andi   -> bufInfo(idx).param.imm,      bufInfo(idx).aluIsa.slli   -> bufInfo(idx).param.imm(5,0),
        bufInfo(idx).aluIsa.slliw  -> bufInfo(idx).param.imm(5,0), bufInfo(idx).aluIsa.srli   -> bufInfo(idx).param.imm(5,0),
        bufInfo(idx).aluIsa.srliw  -> bufInfo(idx).param.imm(5,0), bufInfo(idx).aluIsa.srai   -> bufInfo(idx).param.imm(5,0),
        bufInfo(idx).aluIsa.sraiw  -> bufInfo(idx).param.imm(5,0), bufInfo(idx).aluIsa.add    -> src2,
        bufInfo(idx).aluIsa.addw   -> src2,                        bufInfo(idx).aluIsa.sub    -> (~src2 + 1.U),
        bufInfo(idx).aluIsa.subw   -> (~src2 + 1.U),               bufInfo(idx).aluIsa.sll    -> src2,
        bufInfo(idx).aluIsa.sllw   -> src2,                        bufInfo(idx).aluIsa.slt    -> src2,
        bufInfo(idx).aluIsa.sltu   -> src2,                        bufInfo(idx).aluIsa.xor    -> src2,
        bufInfo(idx).aluIsa.srl    -> src2,                        bufInfo(idx).aluIsa.srlw   -> src2,
        bufInfo(idx).aluIsa.sra    -> src2,                        bufInfo(idx).aluIsa.sraw   -> src2,
        bufInfo(idx).aluIsa.or     -> src2,                        bufInfo(idx).aluIsa.and    -> src2,

        bufInfo(idx).aluIsa.wfi    -> 0.U
    ))
    res.param.dat.op0 := 0.U
    res.param.dat.op3 := 0.U

    res.param.rd0 := bufInfo(idx).phy.rd0
    return res
  }
```

## Documentation

### src/unpriv/rv32.adoc

```text
[#norm:addi_op]#insn:addi[] adds the sign-extended 12-bit immediate to register _rs1_.#
[#norm:addi_overflow]#Arithmetic overflow is ignored and the result is simply the low XLEN bits of the result.#
insn:addi[rd,rs1,0] is used to implement the insn:mv[rd,rs1] assembler pseudoinstruction.

[#norm:slti_sltiu_op]#insn:slti[] (set less than immediate) places the value 1 in register _rd_ if
register _rs1_ is less than the sign-extended immediate when both are
treated as signed numbers, else 0 is written to _rd_. insn:sltiu[] is similar
but compares the values as unsigned numbers (i.e., the immediate is
first sign-extended to XLEN bits then treated as an unsigned number).#
Note, insn:sltiu[rd,rs1,1] sets _rd_ to 1 if _rs1_ equals zero, otherwise
sets _rd_ to 0 (assembler pseudoinstruction insn:seqz[rd,rs]).

[#norm:andi_ori_xori_op]#insn:andi[], insn:ori[], insn:xori[] are logical operations that perform bitwise AND, OR, and
XOR on register _rs1_ and the sign-extended 12-bit immediate and place
the result in _rd_.#
Note, insn:xori[rd,rs1,-1] performs a bitwise logical inversion of register _rs1_ (assembler pseudoinstruction insn:not[rd,rs]).

...

RV32I defines several arithmetic R-type operations. [#norm:R-type_operands]#All operations read
the _rs1_ and _rs2_ registers as source operands and write the result into register _rd_.#
The _funct7_ and _funct3_ fields select the type of operation.

include::images/wavedrom/int-reg-reg.edn[]
[[int-reg-reg]]
//.Integer register-register

[#norm:add_op]#insn:add[] performs the addition of _rs1_ and _rs2_.#
[#norm:sub_op]#insn:sub[] performs the subtraction of _rs2_ from _rs1_.#
[#norm:add_sub_overflow]#Overflows are ignored and the low XLEN bits of results are written to the destination _rd_.#
[#norm:slt_sltu_op]#insn:slt[] and insn:sltu[] perform signed and unsigned compares respectively, writing 1 to _rd_ if
_rs1_ < _rs2_, 0 otherwise.#
Note, insn:sltu[rd,x0,rs2] sets _rd_ to 1 if _rs2_ is not equal to zero,
otherwise sets _rd_ to zero (assembler pseudoinstruction insn:snez[rd,rs]).
[#norm:and_or_xor_op]#insn:and[], insn:or[], and insn:xor[] perform bitwise logical operations.#
```

### src/unpriv/rv64.adoc

```text
Most integer computational instructions operate on XLEN-bit values.
Additional instruction variants are provided to manipulate 32-bit values
in RV64I, indicated by a insn:*w[] suffix to the opcode. [#norm:rv64_w_sex]#These
insn:*w[] instructions ignore the upper 32 bits of their inputs and always produce
32-bit signed values, sign-extending them to 64 bits, i.e. bits XLEN-1
through 31 are equal.#

...

[#norm:addiw_op]#insn:addiw[] is an RV64I instruction that adds the sign-extended 12-bit
immediate to register _rs1_ and produces the proper sign extension of a
32-bit result in _rd_.# [#norm:addiw_overflow]#Overflows are ignored and the result is the low
32 bits of the result sign-extended to 64 bits.# Note, insn:addiw[rd,rs1,0]
writes the sign extension of the lower 32 bits of register _rs1_ into
register _rd_ (assembler pseudoinstruction insn:sext.w[]).

...

(((RV64I, SLLI))) (((RV64I, SRLI))) (((RV64I, SRAI)))
Shifts by a constant are encoded as a specialization of the I-type
format using the same instruction opcode as RV32I. The operand to be
shifted is in _rs1_, and the shift amount is encoded in the lower 6 bits
of the I-immediate field for RV64I. The right-shift type is encoded in
bit 30. insn:slli[] is a logical left shift (zeros are shifted into the lower
bits); insn:srli[] is a logical right shift (zeros are shifted into the upper
bits); and insn:srai[] is an arithmetic right shift (the original sign bit is
copied into the vacated upper bits).

...

(((RV64I, SLLIW))) (((RV64I, SRLIW))) (((RV64I, SRAIW))) (((RV64I, RV64I-only)))
[#norm:slliw_srliw_sraiw_op]#insn:slliw[], insn:srliw[], and insn:sraiw[] are RV64I-only instructions that are analogously
defined but operate on 32-bit values and sign-extend their 32-bit
results to 64 bits.# [#norm:slliw_srliw_sraiw_imm5_rsv]#insn:slliw[], insn:srliw[], and insn:sraiw[] encodings with
_imm[5]_{ne}0 are reserved.#

...

(((RV64I-only, ADDW))) (((RV64I-only, SUBW)))
[#norm:addw_subw_op]#insn:addw[] and insn:subw[] are RV64I-only instructions that are defined analogously
to insn:add[] and insn:sub[] but operate on 32-bit values and produce signed 32-bit results.#
[#norm:addw_subw_overflow]#Overflows are ignored, and the low 32-bits of the result is
sign-extended to 64-bits and written to the destination register.#

insn:sll[], insn:srl[], and insn:sra[] perform logical left, logical right, and arithmetic
right shifts on the value in register _rs1_ by the shift amount held in
register _rs2_. [#norm:sll_srl_sra_sh_amt_rv64i]#In RV64I, only the low 6 bits of _rs2_ are considered
for the shift amount.#

[[norm:sllw_srlw_sraw_op]]
(((RV64I-only, SLLW))) (((RV64I-only, SRLW))) (((RV64I-only, SRAW)))
insn:sllw[], insn:srlw[], and insn:sraw[] are RV64I-only instructions that are analogously
defined but operate on 32-bit values and sign-extend their 32-bit
results to 64 bits. The shift amount is given by _rs2[4:0]_.
```
