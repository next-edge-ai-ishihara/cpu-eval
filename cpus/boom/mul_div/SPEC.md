# Implement `MulDiv`

Implement the complete `MulDiv` module. Preserve the definition name, constructor parameters, and public interface shown below.

Return only the complete `class MulDiv` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package freechips.rocketchip.rocket

import chisel3._
import chisel3.util.{Cat, log2Up, log2Ceil, log2Floor, Log2, Decoupled, Enum, Fill, Valid, Pipe}
import Chisel.ImplicitConversions._
import freechips.rocketchip.util._
import ALU._
```

## Class declaration

```scala
class MultiplierReq(dataBits: Int, tagBits: Int) extends Bundle {
  val fn = Bits(SZ_ALU_FN.W)
  val dw = Bits(SZ_DW.W)
  val in1 = Bits(dataBits.W)
  val in2 = Bits(dataBits.W)
  val tag = UInt(tagBits.W)
}

class MultiplierResp(dataBits: Int, tagBits: Int) extends Bundle {
  val data = Bits(dataBits.W)
  val tag = UInt(tagBits.W)
}

class MultiplierIO(val dataBits: Int, val tagBits: Int) extends Bundle {
  val req = Flipped(Decoupled(new MultiplierReq(dataBits, tagBits)))
  val kill = Input(Bool())
  val resp = Decoupled(new MultiplierResp(dataBits, tagBits))
}

case class MulDivParams(
  mulUnroll: Int = 1,
  divUnroll: Int = 1,
  mulEarlyOut: Boolean = false,
  divEarlyOut: Boolean = false,
  divEarlyOutGranularity: Int = 1
)

class MulDiv(cfg: MulDivParams, width: Int, nXpr: Int = 32) extends Module {
// ...
  val io = IO(new MultiplierIO(width, log2Up(nXpr)))
```

## Parent instantiation

```scala
/**
 * Iterative/unpipelined functional unit, can only hold a single MicroOp at a time
 * assumes at least one register between request and response
 *
 * TODO allow up to N micro-ops simultaneously.
 *
 * @param dataWidth width of the data to be passed into the functional unit
 */
abstract class IterativeFunctionalUnit(dataWidth: Int)(implicit p: Parameters)
  extends FunctionalUnit(
    isPipelined = false,
    numStages = 1,
    numBypassStages = 0,
    dataWidth = dataWidth)
{
  val r_uop = Reg(new MicroOp())

  val do_kill = Wire(Bool())
  do_kill := io.req.bits.kill // irrelevant default

  when (io.req.fire) {
    // update incoming uop
    do_kill := IsKilledByBranch(io.brupdate, io.req.bits.uop) || io.req.bits.kill
    r_uop := io.req.bits.uop
    r_uop.br_mask := GetNewBrMask(io.brupdate, io.req.bits.uop)
  } .otherwise {
    do_kill := IsKilledByBranch(io.brupdate, r_uop) || io.req.bits.kill
    r_uop.br_mask := GetNewBrMask(io.brupdate, r_uop)
  }

  // assumes at least one pipeline register between request and response
  io.resp.bits.uop := r_uop
}

/**
 * Divide functional unit.
 *
 * @param dataWidth data to be passed into the functional unit
 */
class DivUnit(dataWidth: Int)(implicit p: Parameters)
  extends IterativeFunctionalUnit(dataWidth)
{

  // We don't use the iterative multiply functionality here.
  // Instead we use the PipelinedMultiplier
  val div = Module(new freechips.rocketchip.rocket.MulDiv(mulDivParams, width = dataWidth))

  // request
  div.io.req.valid    := io.req.valid && !this.do_kill
  div.io.req.bits.dw  := io.req.bits.uop.ctrl.fcn_dw
  div.io.req.bits.fn  := io.req.bits.uop.ctrl.op_fcn
  div.io.req.bits.in1 := io.req.bits.rs1_data
  div.io.req.bits.in2 := io.req.bits.rs2_data
  div.io.req.bits.tag := DontCare
  io.req.ready        := div.io.req.ready

  // handle pipeline kills and branch misspeculations
  div.io.kill         := this.do_kill

  // response
  io.resp.valid       := div.io.resp.valid && !this.do_kill
  div.io.resp.ready   := io.resp.ready
  io.resp.bits.data   := div.io.resp.bits.data
}
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

## Related source code

### `src/main/scala/rocket/ALU.scala`

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
```

### `src/main/scala/rocket/Consts.scala`

```scala
  def X = BitPat("b?")
  def N = BitPat("b0")
  def Y = BitPat("b1")

  val SZ_DW = 1
  def DW_X  = X
  def DW_32 = Bool(false)
  def DW_64 = Bool(true)
  def DW_XPR = DW_64
```

### `src/main/scala/exu/register-read/func-unit-decode.scala`

```scala
         BitPat(uopDIV)   -> List(BR_N , N, Y, N, FN_DIV , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopDIVU)  -> List(BR_N , N, Y, N, FN_DIVU, DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopREM)   -> List(BR_N , N, Y, N, FN_REM , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopREMU)  -> List(BR_N , N, Y, N, FN_REMU, DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopDIVW)  -> List(BR_N , N, Y, N, FN_DIV , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopDIVUW) -> List(BR_N , N, Y, N, FN_DIVU, DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopREMW)  -> List(BR_N , N, Y, N, FN_REM , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopREMUW) -> List(BR_N , N, Y, N, FN_REMU, DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N))
```

## Documentation

### `src/m-st-ext.adoc`

```text
DIV and DIVU perform an XLEN bits by XLEN bits signed and unsigned
integer division of _rs1_ by _rs2_, rounding towards zero. REM and REMU
provide the remainder of the corresponding division operation. For REM,
the sign of a nonzero result equals the sign of the dividend.
...
For both signed and unsigned division, except in the case of overflow, it holds
that
latexmath:[$\textrm{dividend} = \textrm{divisor} \times \textrm{quotient} + \textrm{remainder}$].
...
DIVW and DIVUW are RV64 instructions that divide the lower 32 bits of
_rs1_ by the lower 32 bits of _rs2_, treating them as signed and
unsigned integers respectively, placing the 32-bit quotient in _rd_,
sign-extended to 64 bits. REMW and REMUW are RV64 instructions that
provide the corresponding signed and unsigned remainder operations
respectively. Both REMW and REMUW always sign-extend the 32-bit result
to 64 bits, including on a divide by zero.
...
The semantics for division by zero and division overflow are summarized
in <<divby0>>. The quotient of division by zero has all bits
set, and the remainder of division by zero equals the dividend. Signed
division overflow occurs only when the most-negative integer is divided
by latexmath:[$-1$]. The quotient of a signed division with overflow is
equal to the dividend, and the remainder is zero. Unsigned division
overflow cannot occur.

[[divby0]]
.Semantics for division by zero and division overflow. L is the width of the operation in bits: XLEN for DIV[U] and REM[U], or 32 for DIV[U]W and REM[U]W.
[cols="<2,^,^,^,^,^,^",options="header",]
|===
|Condition |Dividend |Divisor |DIVU[W] |REMU[W] |DIV[W] |REM[W]

|Division by zero +
Overflow (signed only) |latexmath:[$x$] +
latexmath:[$-2^{L-1}$] |0 +
latexmath:[$-1$] |latexmath:[$2^{L}-1$] +
 - |latexmath:[$x$] + 
 - |latexmath:[$-1$] +
 latexmath:[$-2^{L-1}$] +
  |latexmath:[$x$] +
  0
|===
```
