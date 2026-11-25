# Implement `FPU`

Implement one complete `FPU` source-level hardware definition for the BOOM `LargeBoomConfig` configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Return only the complete `class FPU` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/config-mixins.scala`

```scala
              fpu = Some(freechips.rocketchip.tile.FPUParams(sfmaLatency=4, dfmaLatency=4, divSqrt=true))
    // ...
    case XLen => 64
```

## Package and imports

### `src/main/scala/exu/execution-units/fpu.scala`

```scala
package boom.exu

import chisel3._
import chisel3.util._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.tile.FPConstants._
import freechips.rocketchip.tile.{FPUCtrlSigs, HasFPUParameters}
import freechips.rocketchip.tile
// ...
import boom.common._
import boom.util.{ImmGenRm, ImmGenTyp}
```

## Class declaration

```scala
class FPU(implicit p: Parameters) extends BoomModule with tile.HasFPUParameters
{
  val io = IO(new Bundle {
    val req = Flipped(new ValidIO(new FpuReq))
    val resp = new ValidIO(new ExeUnitResp(65))
  })
  // ...
```

## Parent instantiation

### `src/main/scala/exu/execution-units/functional-unit.scala`

```scala
/**
 * Functional unit to wrap lower level FPU
 *
 * Currently, bypassing is unsupported!
 * All FP instructions are padded out to the max latency unit for easy
 * write-port scheduling.
 */
class FPUUnit(implicit p: Parameters)
  extends PipelinedFunctionalUnit(
    numStages = p(tile.TileKey).core.fpu.get.dfmaLatency,
    numBypassStages = 0,
    earliestBypassStage = 0,
    dataWidth = 65,
    needsFcsr = true)
{
  val fpu = Module(new FPU())
  fpu.io.req.valid         := io.req.valid
  fpu.io.req.bits.uop      := io.req.bits.uop
  fpu.io.req.bits.rs1_data := io.req.bits.rs1_data
  fpu.io.req.bits.rs2_data := io.req.bits.rs2_data
  fpu.io.req.bits.rs3_data := io.req.bits.rs3_data
  fpu.io.req.bits.fcsr_rm  := io.fcsr_rm

  io.resp.bits.data              := fpu.io.resp.bits.data
  io.resp.bits.fflags.valid      := fpu.io.resp.bits.fflags.valid
  io.resp.bits.fflags.bits.uop   := io.resp.bits.uop
  io.resp.bits.fflags.bits.flags := fpu.io.resp.bits.fflags.bits.flags // kill me now
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

  val default: List[BitPat] = List(X,X,X,X,X, X,X,X,X,X,X,X, X,X,X,X)

  val f_table: Array[(BitPat, List[BitPat])] =
    // Note: not all of these signals are used or necessary, but we're
    // constrained by the need to fit the rocket.FPU units' ctrl signals.
    //                                     swap12         fma
    //                                     | swap32       | div
    //                                     | | typeTagIn  | | sqrt
    //                          ldst       | | | typeTagOut | | wflags
    //                          | wen      | | | | from_int | | |
    //                          | | ren1   | | | | | to_int | | |
    //                          | | | ren2 | | | | | | fastpipe |
    //                          | | | | ren3 | | | | | |  | | | |
    //                          | | | | |  | | | | | | |  | | | |
    Array(
    BitPat(uopFCLASS_S) -> List(X,X,Y,N,N, N,X,S,S,N,Y,N, N,N,N,N),
    BitPat(uopFMV_S_X)  -> List(X,X,N,N,N, X,X,S,D,Y,N,N, N,N,N,N),
    BitPat(uopFMV_X_S)  -> List(X,X,Y,N,N, N,X,D,S,N,Y,N, N,N,N,N),
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
// ...
class FpuReq()(implicit p: Parameters) extends BoomBundle
{
  val uop      = new MicroOp()
  val rs1_data = Bits(65.W)
  val rs2_data = Bits(65.W)
  val rs3_data = Bits(65.W)
  val fcsr_rm  = Bits(tile.FPConstants.RM_SZ.W)
}
```

### `src/main/scala/common/micro-op.scala`

```scala
abstract trait HasBoomUOP extends BoomBundle
{
  val uop = new MicroOp()
}

/**
 * MicroOp passing through the pipeline
 */
class MicroOp(implicit p: Parameters) extends BoomBundle
  with freechips.rocketchip.rocket.constants.MemoryOpConstants
  with freechips.rocketchip.rocket.constants.ScalarOpConstants
{
  val uopc             = UInt(UOPC_SZ.W)       // micro-op code
  // ...
  val imm_packed       = UInt(LONGEST_IMM_SZ.W) // densely pack the imm in decode...
  // ...
```

### `src/main/scala/exu/execution-units/execution-unit.scala`

```scala
/**
 * Response from Execution Unit. Bundles a MicroOp with data
 *
 * @param dataWidth width of the data coming from the execution unit
 */
class ExeUnitResp(val dataWidth: Int)(implicit p: Parameters) extends BoomBundle
  with HasBoomUOP
{
  val data = Bits(dataWidth.W)
  val predicated = Bool() // Was this predicated off?
  val fflags = new ValidIO(new FFlagsResp) // write fflags to ROB // TODO: Do this better
}

/**
 * Floating Point flag response
 */
class FFlagsResp(implicit p: Parameters) extends BoomBundle
{
  val uop = new MicroOp()
  val flags = Bits(tile.FPConstants.FLAGS_SZ.W)
}
```

### `src/main/scala/tile/FPU.scala`

```scala
package freechips.rocketchip.tile
// ...
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
  def qNaN = UInt((BigInt(7) << (exp + sig - 3)) + (BigInt(1) << (sig - 2)), recodedWidth)
  def isNaN(x: UInt) = x(sig + exp - 1, sig + exp - 3).andR
  // ...
  // convert between formats, ignoring rounding, range, NaN
  def unsafeConvert(x: UInt, to: FType) = if (this == to) x else {
    val sign = x(sig + exp)
    val fractIn = x(sig - 2, 0)
    val expIn = x(sig + exp - 1, sig - 1)
    val fractOut = fractIn << to.sig >> sig
    val expOut = {
      val expCode = expIn(exp, exp - 2)
      val commonCase = (expIn + (1 << to.exp)) - (1 << exp)
      Mux(expCode === 0 || expCode >= 6, Cat(expCode, commonCase(to.exp - 3, 0)), commonCase(to.exp, 0))
    }
    Cat(sign, expOut, fractOut)
  }
// ...
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
  def prevType(t: FType) = floatTypes(typeTag(t) - 1)
  // ...
  def typeTag(t: FType) = floatTypes.indexOf(t)
  def typeTagWbOffset = UInt(FType.all.indexOf(minType) + 1)
  def typeTagGroup(t: FType) = UInt(if (floatTypes.contains(t)) typeTag(t) else typeTag(maxType))
  // typeTag
  def H = typeTagGroup(FType.H)
  def S = typeTagGroup(FType.S)
  def D = typeTagGroup(FType.D)
  def I = UInt(typeTag(maxType))

  private def isBox(x: UInt, t: FType): Bool = x(t.sig + t.exp, t.sig + t.exp - 4).andR

  private def box(x: UInt, xt: FType, y: UInt, yt: FType): UInt = {
    require(xt.ieeeWidth == 2 * yt.ieeeWidth)
    val swizzledNaN = Cat(
      x(xt.sig + xt.exp, xt.sig + xt.exp - 3),
      x(xt.sig - 2, yt.recodedWidth - 1).andR,
      x(xt.sig + xt.exp - 5, xt.sig),
      y(yt.recodedWidth - 2),
      x(xt.sig - 2, yt.recodedWidth - 1),
      y(yt.recodedWidth - 1),
      y(yt.recodedWidth - 3, 0))
    Mux(xt.isNaN(x), swizzledNaN, x)
  }

  // implement NaN unboxing for FU inputs
  def unbox(x: UInt, tag: UInt, exactType: Option[FType]): UInt = {
    val outType = exactType.getOrElse(maxType)
    def helper(x: UInt, t: FType): Seq[(Bool, UInt)] = {
      val prev =
        if (t == minType) {
          Seq()
        } else {
          val prevT = prevType(t)
          val unswizzled = Cat(
            x(prevT.sig + prevT.exp - 1),
            x(t.sig - 1),
            x(prevT.sig + prevT.exp - 2, 0))
          val prev = helper(unswizzled, prevT)
          val isbox = isBox(x, t)
          prev.map(p => (isbox && p._1, p._2))
        }
      prev :+ (true.B, t.unsafeConvert(x, outType))
    }

    val (oks, floats) = helper(x, maxType).unzip
    if (exactType.isEmpty || floatTypes.size == 1) {
      Mux(oks(tag), floats(tag), maxType.qNaN)
    } else {
      val t = exactType.get
      floats(typeTag(t)) | Mux(oks(typeTag(t)), 0.U, t.qNaN)
    }
  }
  // ...
  // generate a NaN box from an FU result
  def box(x: UInt, t: FType): UInt = {
    if (t == maxType) {
      x
    } else {
      val nt = floatTypes(typeTag(t) + 1)
      val bigger = box(UInt((BigInt(1) << nt.recodedWidth)-1), nt, x, t)
      bigger | UInt((BigInt(1) << maxType.recodedWidth) - (BigInt(1) << nt.recodedWidth))
    }
  }

  // generate a NaN box from an FU result
  def box(x: UInt, tag: UInt): UInt = {
    val opts = floatTypes.map(t => box(x, t))
    opts(tag)
  }
// ...
abstract class FPUModule(implicit val p: Parameters) extends Module with HasCoreParameters with HasFPUParameters

class FPToInt(implicit p: Parameters) extends FPUModule()(p) with ShouldBeRetimed {
  class Output extends Bundle {
    val in = new FPInput
    val lt = Bool()
    val store = Bits(width = fLen)
    val toint = Bits(width = xLen)
    val exc = Bits(width = FPConstants.FLAGS_SZ)
  }
  val io = new Bundle {
    val in = Valid(new FPInput).flip
    val out = Valid(new Output)
  }

  val in = RegEnable(io.in.bits, io.in.valid)
  val valid = Reg(next=io.in.valid)

  val dcmp = Module(new hardfloat.CompareRecFN(maxExpWidth, maxSigWidth))
  dcmp.io.a := in.in1
  dcmp.io.b := in.in2
  dcmp.io.signaling := !in.rm(1)

  val tag = in.typeTagOut
  val store = (floatTypes.map(t => if (t == FType.H) Fill(maxType.ieeeWidth / minXLen,   ieee(in.in1)(15, 0).sextTo(minXLen))
                                   else              Fill(maxType.ieeeWidth / t.ieeeWidth, ieee(in.in1)(t.ieeeWidth - 1, 0))): Seq[UInt])(tag)
  val toint = Wire(init = store)
  val intType = Wire(init = in.fmt(0))
  io.out.bits.store := store
  io.out.bits.toint := ((0 until nIntTypes).map(i => toint((minXLen << i) - 1, 0).sextTo(xLen)): Seq[UInt])(intType)
  // ...
  io.out.valid := valid
  io.out.bits.lt := dcmp.io.lt || (dcmp.io.a.asSInt < 0.S && dcmp.io.b.asSInt >= 0.S)
  io.out.bits.in := in
}
// ...
class FPToFP(val latency: Int)(implicit p: Parameters) extends FPUModule()(p) with ShouldBeRetimed {
  val io = new Bundle {
    val in = Valid(new FPInput).flip
    val out = Valid(new FPResult)
    val lt = Bool(INPUT) // from FPToInt
  }

  val in = Pipe(io.in)
  // ...
  io.out <> Pipe(in.valid, mux, latency-1)
}
// ...
class FPUFMAPipe(val latency: Int, val t: FType)
                (implicit p: Parameters) extends FPUModule()(p) with ShouldBeRetimed {
  require(latency>0)

  val io = new Bundle {
    val in = Valid(new FPInput).flip
    val out = Valid(new FPResult)
  }

  val valid = Reg(next=io.in.valid)
  val in = Reg(new FPInput)
  when (io.in.valid) {
    val one = UInt(1) << (t.sig + t.exp - 1)
    val zero = (io.in.bits.in1 ^ io.in.bits.in2) & (UInt(1) << (t.sig + t.exp))
    val cmd_fma = io.in.bits.ren3
    val cmd_addsub = io.in.bits.swap23
    in := io.in.bits
    when (cmd_addsub) { in.in2 := one }
    when (!(cmd_fma || cmd_addsub)) { in.in3 := zero }
  }

  val fma = Module(new MulAddRecFNPipe((latency-1) min 2, t.exp, t.sig))
  fma.io.validin := valid
  fma.io.op := in.fmaCmd
  fma.io.roundingMode := in.rm
  fma.io.detectTininess := hardfloat.consts.tininess_afterRounding
  fma.io.a := in.in1
  fma.io.b := in.in2
  fma.io.c := in.in3

  val res = Wire(new FPResult)
  res.data := sanitizeNaN(fma.io.out, t)
  res.exc := fma.io.exceptionFlags

  io.out := Pipe(fma.io.validout, res, (latency-3) max 0)
}
```

### `src/main/scala/util/util.scala`

```scala
object ImmGenRm { def apply(ip: UInt): UInt = { return ip(2,0) } }
// ...
object ImmGenTyp { def apply(ip: UInt): UInt = { return ip(9,8) } }
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
The 2-bit floating-point format field _fmt_ is encoded as shown in
<<fmt>>. It is set to _S_ (00) for all instructions in the F extension.

[[fmt]]
.Format field encoding
[%autowidth,float="center",align="center",cols="^,^,<",options="header",]
|===
|_fmt_ field |Mnemonic |Meaning
|00 |S |32-bit single-precision
|01 |D |64-bit double-precision
|10 |H |16-bit half-precision
|11 |Q |128-bit quad-precision
|===
```
