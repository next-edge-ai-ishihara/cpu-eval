# Implement `ALU`

Implement one complete `ALU` source-level hardware definition for the behavior used by BOOM. Preserve the definition name, constructor parameters, inheritance, and public interface shown below, and drive every declared output to a defined value.

Return only the complete `class ALU` definition in a single Scala code block, with no text outside the block. The companion object remains fixed.

## Package and imports

```scala
// See LICENSE.SiFive for license details.
// See LICENSE.Berkeley for license details.

package freechips.rocketchip.rocket

import Chisel._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.tile.CoreModule
```

## Class declaration

```scala
class ALU(implicit p: Parameters) extends CoreModule()(p) {
  val io = new Bundle {
    val dw = Bits(INPUT, SZ_DW)
    val fn = Bits(INPUT, SZ_ALU_FN)
    val in2 = UInt(INPUT, xLen)
    val in1 = UInt(INPUT, xLen)
    val out = UInt(OUTPUT, xLen)
    val adder_out = UInt(OUTPUT, xLen)
    val cmp_out = Bool(OUTPUT)
  }
```

## Parent instantiation

### src/main/scala/exu/execution-units/functional-unit.scala

```scala
  // operand 1 select
  var op1_data: UInt = null
  if (isJmpUnit) {
    // Get the uop PC for jumps
    val block_pc = AlignPCToBoundary(io.get_ftq_pc.pc, icBlockBytes)
    val uop_pc = (block_pc | uop.pc_lob) - Mux(uop.edge_inst, 2.U, 0.U)

    op1_data = Mux(uop.ctrl.op1_sel.asUInt === OP1_RS1 , io.req.bits.rs1_data,
               Mux(uop.ctrl.op1_sel.asUInt === OP1_PC  , Sext(uop_pc, xLen),
                                                         0.U))
  } else {
    op1_data = Mux(uop.ctrl.op1_sel.asUInt === OP1_RS1 , io.req.bits.rs1_data,
                                                         0.U)
  }

  // operand 2 select
  val op2_data = Mux(uop.ctrl.op2_sel === OP2_IMM,  Sext(imm_xprlen.asUInt, xLen),
                 Mux(uop.ctrl.op2_sel === OP2_IMMC, io.req.bits.uop.prs1(4,0),
                 Mux(uop.ctrl.op2_sel === OP2_RS2 , io.req.bits.rs2_data,
                 Mux(uop.ctrl.op2_sel === OP2_NEXT, Mux(uop.is_rvc, 2.U, 4.U),
                                                    0.U))))

  val alu = Module(new freechips.rocketchip.rocket.ALU())

  alu.io.in1 := op1_data.asUInt
  alu.io.in2 := op2_data.asUInt
  alu.io.fn  := uop.ctrl.op_fcn
  alu.io.dw  := uop.ctrl.fcn_dw
  // ...
  val r_val  = RegInit(VecInit(Seq.fill(numStages) { false.B }))
  val r_data = Reg(Vec(numStages, UInt(xLen.W)))
  val r_pred = Reg(Vec(numStages, Bool()))
  val alu_out = Mux(io.req.bits.uop.is_sfb_shadow && io.req.bits.pred_data,
    Mux(io.req.bits.uop.ldst_is_rs1, io.req.bits.rs1_data, io.req.bits.rs2_data),
    Mux(io.req.bits.uop.uopc === uopMOV, io.req.bits.rs2_data, alu.io.out))
  r_val (0) := io.req.valid
  r_data(0) := Mux(io.req.bits.uop.is_sfb_br, pc_sel === PC_BRJMP, alu_out)
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/rocket/ALU.scala

```scala
object ALU
{
  val SZ_ALU_FN = 4
  def FN_X    = BitPat("b????")
  def FN_ADD  = UInt(0)
  def FN_SL   = UInt(1)
  def FN_SEQ  = UInt(2)
  def FN_SNE  = UInt(3)
  def FN_XOR  = UInt(4)
  def FN_SR   = UInt(5)
  def FN_OR   = UInt(6)
  def FN_AND  = UInt(7)
  def FN_SUB  = UInt(10)
  def FN_SRA  = UInt(11)
  def FN_SLT  = UInt(12)
  def FN_SGE  = UInt(13)
  def FN_SLTU = UInt(14)
  def FN_SGEU = UInt(15)

  def FN_DIV  = FN_XOR
  def FN_DIVU = FN_SR
  def FN_REM  = FN_OR
  def FN_REMU = FN_AND

  def FN_MUL    = FN_ADD
  def FN_MULH   = FN_SL
  def FN_MULHSU = FN_SEQ
  def FN_MULHU  = FN_SNE

  def isMulFN(fn: UInt, cmp: UInt) = fn(1,0) === cmp(1,0)
  def isSub(cmd: UInt) = cmd(3)
  def isCmp(cmd: UInt) = cmd >= FN_SLT
  def cmpUnsigned(cmd: UInt) = cmd(1)
  def cmpInverted(cmd: UInt) = cmd(0)
  def cmpEq(cmd: UInt) = !cmd(3)
}

import ALU._
```

### src/main/scala/rocket/Consts.scala

```scala
trait ScalarOpConstants {
  // ...
  def X = BitPat("b?")
  def N = BitPat("b0")
  def Y = BitPat("b1")

  val SZ_DW = 1
  def DW_X  = X
  def DW_32 = Bool(false)
  def DW_64 = Bool(true)
  def DW_XPR = DW_64
}
```

### src/main/scala/rocket/package.scala

```scala
package freechips.rocketchip

package object rocket extends rocket.constants.ScalarOpConstants with rocket.constants.MemoryOpConstants
```

## Related source code

### src/main/scala/exu/register-read/func-unit-decode.scala

```scala
         BitPat(uopADDI)  -> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopANDI)  -> List(BR_N , Y, N, N, FN_AND , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopORI)   -> List(BR_N , Y, N, N, FN_OR  , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopXORI)  -> List(BR_N , Y, N, N, FN_XOR , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSLTI)  -> List(BR_N , Y, N, N, FN_SLT , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSLTIU) -> List(BR_N , Y, N, N, FN_SLTU, DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSLLI)  -> List(BR_N , Y, N, N, FN_SL  , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSRAI)  -> List(BR_N , Y, N, N, FN_SRA , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSRLI)  -> List(BR_N , Y, N, N, FN_SR  , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),

         BitPat(uopADDIW) -> List(BR_N , Y, N, N, FN_ADD , DW_32 , OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSLLIW) -> List(BR_N , Y, N, N, FN_SL  , DW_32 , OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSRAIW) -> List(BR_N , Y, N, N, FN_SRA , DW_32 , OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSRLIW) -> List(BR_N , Y, N, N, FN_SR  , DW_32 , OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),

         BitPat(uopADD)   -> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSLL)   -> List(BR_N , Y, N, N, FN_SL  , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSUB)   -> List(BR_N , Y, N, N, FN_SUB , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSLT)   -> List(BR_N , Y, N, N, FN_SLT , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSLTU)  -> List(BR_N , Y, N, N, FN_SLTU, DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopAND)   -> List(BR_N , Y, N, N, FN_AND , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopOR)    -> List(BR_N , Y, N, N, FN_OR  , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopXOR)   -> List(BR_N , Y, N, N, FN_XOR , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSRA)   -> List(BR_N , Y, N, N, FN_SRA , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSRL)   -> List(BR_N , Y, N, N, FN_SR  , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),

         BitPat(uopADDW)  -> List(BR_N , Y, N, N, FN_ADD , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSUBW)  -> List(BR_N , Y, N, N, FN_SUB , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSLLW)  -> List(BR_N , Y, N, N, FN_SL  , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSRAW)  -> List(BR_N , Y, N, N, FN_SRA , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSRLW)  -> List(BR_N , Y, N, N, FN_SR  , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
```

### src/main/scala/rocket/IDecode.scala

```scala
    BNE->       List(Y,N,N,Y,N,N,Y,Y,N,A2_RS2, A1_RS1, IMM_SB,DW_X,  FN_SNE,   N,M_X,        N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    BEQ->       List(Y,N,N,Y,N,N,Y,Y,N,A2_RS2, A1_RS1, IMM_SB,DW_X,  FN_SEQ,   N,M_X,        N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    BLT->       List(Y,N,N,Y,N,N,Y,Y,N,A2_RS2, A1_RS1, IMM_SB,DW_X,  FN_SLT,   N,M_X,        N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    BLTU->      List(Y,N,N,Y,N,N,Y,Y,N,A2_RS2, A1_RS1, IMM_SB,DW_X,  FN_SLTU,  N,M_X,        N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    BGE->       List(Y,N,N,Y,N,N,Y,Y,N,A2_RS2, A1_RS1, IMM_SB,DW_X,  FN_SGE,   N,M_X,        N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    BGEU->      List(Y,N,N,Y,N,N,Y,Y,N,A2_RS2, A1_RS1, IMM_SB,DW_X,  FN_SGEU,  N,M_X,        N,N,N,N,N,N,N,CSR.N,N,N,N,N),
```

### src/main/scala/rocket/RocketCore.scala

```scala
    mem_reg_wdata := Mux(ex_scie_unpipelined, ex_scie_unpipelined_wdata, alu.io.out)
    mem_br_taken := alu.io.cmp_out
  // ...
  io.dmem.req.bits.addr := encodeVirtualAddress(ex_rs(0), alu.io.adder_out)
```

## Documentation

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

include::images/wavedrom/int-comp-slli-srli-srai.edn[]
[[int-comp-slli-srli-srai]]
//.Integer register-immediate, SLLI, SRLI, SRAI

Shifts by a constant are encoded as a specialization of the I-type
format. The operand to be shifted is in _rs1_, and the shift amount is
encoded in the lower 5 bits of the I-immediate field. The right shift
type is encoded in bit 30. SLLI is a logical left shift (zeros are
shifted into the lower bits); SRLI is a logical right shift (zeros are
shifted into the upper bits); and SRAI is an arithmetic right shift (the
original sign bit is copied into the vacated upper bits).
...
==== Integer Register-Register Operations

RV32I defines several arithmetic R-type operations. All operations read
the _rs1_ and _rs2_ registers as source operands and write the result
into register _rd_. The _funct7_ and _funct3_ fields select the type of
operation.

include::images/wavedrom/int-reg-reg.edn[]
[[int-reg-reg]]
//.Integer register-register

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
...
==== Conditional Branches

All branch instructions use the B-type instruction format. The 12-bit
B-immediate encodes signed offsets in multiples of 2 bytes. The offset
is sign-extended and added to the address of the branch instruction to
give the target address. The conditional branch range is
&#177;4 KiB.

include::images/wavedrom/ct-conditional.edn[]
[[ct-conditional]]
//.Conditional branches

Branch instructions compare two registers. BEQ and BNE take the branch
if registers _rs1_ and _rs2_ are equal or unequal respectively. BLT and
BLTU take the branch if _rs1_ is less than _rs2_, using signed and
unsigned comparison respectively. BGE and BGEU take the branch if _rs1_
is greater than or equal to _rs2_, using signed and unsigned comparison
respectively. Note, BGT, BGTU, BLE, and BLEU can be synthesized by
reversing the operands to BLT, BLTU, BGE, and BGEU, respectively.
```

### src/rv64.adoc

```text
=== Integer Computational Instructions

Most integer computational instructions operate on XLEN-bit values.
Additional instruction variants are provided to manipulate 32-bit values
in RV64I, indicated by a 'W' suffix to the opcode. These "*W"
instructions ignore the upper 32 bits of their inputs and always produce
32-bit signed values, sign-extending them to 64 bits, i.e. bits XLEN-1
through 31 are equal.
...
ADDIW is an RV64I instruction that adds the sign-extended 12-bit
immediate to register _rs1_ and produces the proper sign extension of a
32-bit result in _rd_. Overflows are ignored and the result is the low
32 bits of the result sign-extended to 64 bits. Note, ADDIW _rd, rs1, 0_
writes the sign extension of the lower 32 bits of register _rs1_ into
register _rd_ (assembler pseudoinstruction SEXT.W).
...
Shifts by a constant are encoded as a specialization of the I-type
format using the same instruction opcode as RV32I. The operand to be
shifted is in _rs1_, and the shift amount is encoded in the lower 6 bits
of the I-immediate field for RV64I. The right shift type is encoded in
bit 30. SLLI is a logical left shift (zeros are shifted into the lower
bits); SRLI is a logical right shift (zeros are shifted into the upper
bits); and SRAI is an arithmetic right shift (the original sign bit is
copied into the vacated upper bits).
(((RV64I, SLLI)))
(((RV64I, SRKIW)))
(((RV64I, SRLIW)))
(((RV64I, RV64I-only)))

include::images/wavedrom/rv64i-slliw.edn[]
[[rv64i-slliw]]

SLLIW, SRLIW, and SRAIW are RV64I-only instructions that are analogously
defined but operate on 32-bit values and sign-extend their 32-bit
results to 64 bits. SLLIW, SRLIW, and SRAIW encodings with
_imm[5] &#8800; 0_ are reserved.
...
ADDW and SUBW are RV64I-only instructions that are defined analogously
to ADD and SUB but operate on 32-bit values and produce signed 32-bit
results. Overflows are ignored, and the low 32-bits of the result is
sign-extended to 64-bits and written to the destination register.
(((RV64I-only, ADDW)))
(((RV64I-only, SUBW)))

SLL, SRL, and SRA perform logical left, logical right, and arithmetic
right shifts on the value in register _rs1_ by the shift amount held in
register _rs2_. In RV64I, only the low 6 bits of _rs2_ are considered
for the shift amount.

SLLW, SRLW, and SRAW are RV64I-only instructions that are analogously
defined but operate on 32-bit values and sign-extend their 32-bit
results to 64 bits. The shift amount is given by _rs2[4:0]_.
```
