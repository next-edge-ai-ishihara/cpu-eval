# Implement `FPUFMAPipe`

Implement the complete `FPUFMAPipe` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Return only the complete `class FPUFMAPipe` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/config-mixins.scala`

```scala
              fpu = Some(freechips.rocketchip.tile.FPUParams(sfmaLatency=4, dfmaLatency=4, divSqrt=true))
```

## Package and imports

### `src/main/scala/tile/FPU.scala`

```scala
package freechips.rocketchip.tile

import Chisel.{defaultCompileOptions => _, _}
// ...
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.rocket._
// ...
import freechips.rocketchip.util._
```

## Class declaration

```scala
class FPUFMAPipe(val latency: Int, val t: FType)
                (implicit p: Parameters) extends FPUModule()(p) with ShouldBeRetimed {
  require(latency>0)

  val io = new Bundle {
    val in = Valid(new FPInput).flip
    val out = Valid(new FPResult)
  }
  // ...
```

## Parent instantiation

### `src/main/scala/exu/execution-units/fpu.scala`

```scala
  // all FP units are padded out to the same latency for easy scheduling of the write port
  val fpu_latency = dfmaLatency
  // ...
  val dfma = Module(new tile.FPUFMAPipe(latency = fpu_latency, t = tile.FType.D))
  dfma.io.in.valid := io.req.valid && fp_ctrl.fma && (fp_ctrl.typeTagOut === D)
  dfma.io.in.bits := fuInput(Some(dfma.t))

  val sfma = Module(new tile.FPUFMAPipe(latency = fpu_latency, t = tile.FType.S))
  sfma.io.in.valid := io.req.valid && fp_ctrl.fma && (fp_ctrl.typeTagOut === S)
  sfma.io.in.bits := fuInput(Some(sfma.t))
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/tile/FPU.scala`

```scala
case class FPUParams(
  minFLen: Int = 32,
  fLen: Int = 64,
  divSqrt: Boolean = true,
  sfmaLatency: Int = 3,
  dfmaLatency: Int = 4
)

object FPConstants
{
  val RM_SZ = 3
  val FLAGS_SZ = 5
}

trait HasFPUCtrlSigs {
  val ldst = Bool()
  val wen = Bool()
  val ren1 = Bool()
  val ren2 = Bool()
  val ren3 = Bool()
  val swap12 = Bool()
  val swap23 = Bool()
  val typeTagIn = UInt(2.W)
  val typeTagOut = UInt(2.W)
  val fromint = Bool()
  val toint = Bool()
  val fastpipe = Bool()
  val fma = Bool()
  val div = Bool()
  val sqrt = Bool()
  val wflags = Bool()
}

class FPUCtrlSigs extends Bundle with HasFPUCtrlSigs
// ...
class FPResult(implicit p: Parameters) extends CoreBundle()(p) {
  val data = Bits(width = fLen+1)
  val exc = Bits(width = FPConstants.FLAGS_SZ)
}
// ...
class FPInput(implicit p: Parameters) extends CoreBundle()(p) with HasFPUCtrlSigs {
  val rm = Bits(width = FPConstants.RM_SZ)
  val fmaCmd = Bits(width = 2)
  val typ = Bits(width = 2)
  val fmt = Bits(width = 2)
  val in1 = Bits(width = fLen+1)
  val in2 = Bits(width = fLen+1)
  val in3 = Bits(width = fLen+1)

}

case class FType(exp: Int, sig: Int) {
  def ieeeWidth = exp + sig
  def recodedWidth = ieeeWidth + 1
  // ...
  def isNaN(x: UInt) = x(sig + exp - 1, sig + exp - 3).andR
  // ...
}

object FType {
  val H = new FType(5, 11)
  val S = new FType(8, 24)
  val D = new FType(11, 53)

  val all = List(H, S, D)
}

trait HasFPUParameters {
  require(fLen == 0 || FType.all.exists(_.ieeeWidth == fLen))
  val minFLen: Int
  val fLen: Int
  def xLen: Int
  // ...
  val floatTypes = FType.all.filter(t => minFLen <= t.ieeeWidth && t.ieeeWidth <= fLen)
  def minType = floatTypes.head
  def maxType = floatTypes.last
  // ...
  def typeTag(t: FType) = floatTypes.indexOf(t)
  // ...
  // zap bits that hardfloat thinks are don't-cares, but we do care about
  def sanitizeNaN(x: UInt, t: FType): UInt = {
    if (typeTag(t) == 0) {
      x
    } else {
      val maskedNaN = x & ~UInt((BigInt(1) << (t.sig-1)) | (BigInt(1) << (t.sig+t.exp-4)), t.recodedWidth)
      Mux(t.isNaN(x), maskedNaN, x)
    }
  }
// ...
abstract class FPUModule(implicit val p: Parameters) extends Module with HasCoreParameters with HasFPUParameters
// ...
class MulAddRecFNPipe(latency: Int, expWidth: Int, sigWidth: Int) extends Module
{
    require(latency<=2)

    val io = new Bundle {
        val validin = Bool(INPUT)
        val op = Bits(INPUT, 2)
        val a = Bits(INPUT, expWidth + sigWidth + 1)
        val b = Bits(INPUT, expWidth + sigWidth + 1)
        val c = Bits(INPUT, expWidth + sigWidth + 1)
        val roundingMode   = UInt(INPUT, 3)
        val detectTininess = UInt(INPUT, 1)
        val out = Bits(OUTPUT, expWidth + sigWidth + 1)
        val exceptionFlags = Bits(OUTPUT, 5)
        val validout = Bool(OUTPUT)
    }
    // ...
```

### `src/main/scala/util/Annotations.scala`

```scala
package freechips.rocketchip.util
// ...
/** Mix this into a Module class or instance to mark it for register retiming */
trait ShouldBeRetimed { self: RawModule =>
  chisel3.experimental.annotate(new ChiselAnnotation { def toFirrtl: RetimeModuleAnnotation = RetimeModuleAnnotation(self.toNamed) })
}
```

### `src/main/scala/common.scala`

```scala
package hardfloat
// ...
object consts {
    /*------------------------------------------------------------------------
    | For rounding to integer values, rounding mode 'odd' rounds to minimum
    | magnitude instead, same as 'minMag'.
    *------------------------------------------------------------------------*/
    def round_near_even   = UInt("b000", 3)
    def round_minMag      = UInt("b001", 3)
    def round_min         = UInt("b010", 3)
    def round_max         = UInt("b011", 3)
    def round_near_maxMag = UInt("b100", 3)
    def round_odd         = UInt("b110", 3)
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    def tininess_beforeRounding = UInt(0, 1)
    def tininess_afterRounding  = UInt(1, 1)
    // ...
```

## Related source code

### `src/main/scala/exu/execution-units/fpu.scala`

```scala
class UOPCodeFPUDecoder(implicit p: Parameters) extends BoomModule with HasFPUParameters
{
  val io = IO(new Bundle {
    val uopc = Input(Bits(UOPC_SZ.W))
    val sigs = Output(new FPUCtrlSigs())
  })

  // TODO change N,Y,X to BitPat("b1"), BitPat("b0"), and BitPat("b?")
  val N = false.B
  val Y = true.B
  val X = false.B
    // ...
    BitPat(uopFADD_S)   -> List(X,X,Y,Y,N, N,Y,S,S,N,N,N, Y,N,N,Y),
    BitPat(uopFSUB_S)   -> List(X,X,Y,Y,N, N,Y,S,S,N,N,N, Y,N,N,Y),
    BitPat(uopFMUL_S)   -> List(X,X,Y,Y,N, N,N,S,S,N,N,N, Y,N,N,Y),
    BitPat(uopFMADD_S)  -> List(X,X,Y,Y,Y, N,N,S,S,N,N,N, Y,N,N,Y),
    BitPat(uopFMSUB_S)  -> List(X,X,Y,Y,Y, N,N,S,S,N,N,N, Y,N,N,Y),
    BitPat(uopFNMADD_S) -> List(X,X,Y,Y,Y, N,N,S,S,N,N,N, Y,N,N,Y),
    BitPat(uopFNMSUB_S) -> List(X,X,Y,Y,Y, N,N,S,S,N,N,N, Y,N,N,Y)
    // ...
    BitPat(uopFADD_D)   -> List(X,X,Y,Y,N, N,Y,D,D,N,N,N, Y,N,N,Y),
    BitPat(uopFSUB_D)   -> List(X,X,Y,Y,N, N,Y,D,D,N,N,N, Y,N,N,Y),
    BitPat(uopFMUL_D)   -> List(X,X,Y,Y,N, N,N,D,D,N,N,N, Y,N,N,Y),

    BitPat(uopFMADD_D)  -> List(X,X,Y,Y,Y, N,N,D,D,N,N,N, Y,N,N,Y),
    BitPat(uopFMSUB_D)  -> List(X,X,Y,Y,Y, N,N,D,D,N,N,N, Y,N,N,Y),
    BitPat(uopFNMADD_D) -> List(X,X,Y,Y,Y, N,N,D,D,N,N,N, Y,N,N,Y),
    BitPat(uopFNMSUB_D) -> List(X,X,Y,Y,Y, N,N,D,D,N,N,N, Y,N,N,Y)
  // ...
  val s = io.sigs
  val sigs = Seq(s.ldst, s.wen, s.ren1, s.ren2, s.ren3, s.swap12,
                 s.swap23, s.typeTagIn, s.typeTagOut, s.fromint, s.toint, s.fastpipe, s.fma,
                 s.div, s.sqrt, s.wflags)
  sigs zip decoder map {case(s,d) => s := d}
}

/**
 * FP fused multiple add decoder for the FPU
 */
class FMADecoder extends Module
{
  val io = IO(new Bundle {
    val uopc = Input(UInt(UOPC_SZ.W))
    val cmd = Output(UInt(2.W))
  })

  val default: List[BitPat] = List(BitPat("b??"))
  val table: Array[(BitPat, List[BitPat])] =
    Array(
      BitPat(uopFADD_S)   -> List(BitPat("b00")),
      BitPat(uopFSUB_S)   -> List(BitPat("b01")),
      BitPat(uopFMUL_S)   -> List(BitPat("b00")),
      BitPat(uopFMADD_S)  -> List(BitPat("b00")),
      BitPat(uopFMSUB_S)  -> List(BitPat("b01")),
      BitPat(uopFNMADD_S) -> List(BitPat("b11")),
      BitPat(uopFNMSUB_S) -> List(BitPat("b10")),
      BitPat(uopFADD_D)   -> List(BitPat("b00")),
      BitPat(uopFSUB_D)   -> List(BitPat("b01")),
      BitPat(uopFMUL_D)   -> List(BitPat("b00")),
      BitPat(uopFMADD_D)  -> List(BitPat("b00")),
      BitPat(uopFMSUB_D)  -> List(BitPat("b01")),
      BitPat(uopFNMADD_D) -> List(BitPat("b11")),
      BitPat(uopFNMSUB_D) -> List(BitPat("b10"))
      )

  val decoder = rocket.DecodeLogic(io.uopc, default, table)

  val (cmd: UInt) :: Nil = decoder
  io.cmd := cmd
}
```

## Documentation

### `docs/sections/execution-stages.rst`

```text
To make the scheduling of the write-port trivial, all of the pipelined
FP units are padded to have the same latency. [3]_
```

### `src/f-st-ext.adoc`

```text
[[rm]]
.Rounding mode encoding.
[%autowidth,float="center",align="center",cols="^,^,<",options="header"]
|===
|Rounding Mode |Mnemonic |Meaning
|000 |RNE |Round to Nearest, ties to Even
|001 |RTZ |Round towards Zero
|010 |RDN |Round Down (towards latexmath:[$-\infty$])
|011 |RUP |Round Up (towards latexmath:[$+\infty$])
|100 |RMM |Round to Nearest, ties to Max Magnitude
|101 | |_Reserved for future use._
|110 | |_Reserved for future use._
|111 |DYN |In instruction's _rm_ field, selects dynamic rounding mode; In Rounding Mode register, _reserved_.
|===
...
Floating-point arithmetic instructions with one or two source operands
use the R-type format with the OP-FP major opcode. FADD.S and FMUL.S
perform single-precision floating-point addition and multiplication
respectively, between _rs1_ and _rs2_. FSUB.S performs the
single-precision floating-point subtraction of _rs2_ from _rs1_. FDIV.S performs the single-precision floating-point division of _rs1_ by _rs2_. FSQRT.S computes the square root of _rs1_. In each case, the result is written to _rd_.
...
Floating-point fused multiply-add instructions require a new standard
instruction format. R4-type instructions specify three source registers (_rs1_, _rs2_, and _rs3_) and a destination register (_rd_). This format is only used by the floating-point fused multiply-add instructions.

FMADD.S multiplies the values in _rs1_ and _rs2_, adds the value in
_rs3_, and writes the final result to _rd_. FMADD.S computes
_(rs1latexmath:[$\times$]rs2)latexmath:[$\+$]rs3_.

FMSUB.S multiplies the values in _rs1_ and _rs2_, subtracts the value in _rs3_, and writes the final result to _rd_. FMSUB.S computes
_(rs1latexmath:[$\times$]rs2)latexmath:[$\-$]rs3_.

FNMSUB.S multiplies the values in _rs1_ and _rs2_, negates the product, adds the value in _rs3_, and writes the final result to _rd_. FNMSUB.S computes _-(rs1latexmath:[$\times$]rs2)latexmath:[$\+$]rs3_.

FNMADD.S multiplies the values in _rs1_ and _rs2_, negates the product, subtracts the value in _rs3_, and writes the final result to _rd_. FNMADD.S computes _-(rs1latexmath:[$\times$]rs2)latexmath:[$\-$]rs3_.
...
The fused multiply-add instructions must set the invalid operation
exception flag when the multiplicands are latexmath:[$\infty$] and zero, even when the addend is a quiet NaN.
```

### `src/d-st-ext.adoc`

```text
=== Double-Precision Floating-Point Computational Instructions

The double-precision floating-point computational instructions are
defined analogously to their single-precision counterparts, but operate
on double-precision operands and produce double-precision results.
```
