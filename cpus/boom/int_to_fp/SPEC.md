# Implement `IntToFP`

Implement the complete `IntToFP` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class IntToFP` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/config-mixins.scala`

```scala
              fpu = Some(freechips.rocketchip.tile.FPUParams(sfmaLatency=4, dfmaLatency=4, divSqrt=true))
```

### `src/main/scala/subsystem/Configs.scala`

```scala
  case XLen => 64 // Applies to all cores
```

## Package and imports

```scala
package freechips.rocketchip.tile

import Chisel.{defaultCompileOptions => _, _}
import freechips.rocketchip.util.CompileOptions.NotStrictInferReset
import Chisel.ImplicitConversions._
import chisel3.{DontCare, WireInit, withClock, withReset}
import chisel3.internal.sourceinfo.SourceInfo
import chisel3.experimental.{chiselName, NoChiselNamePrefix}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.rocket._
import freechips.rocketchip.rocket.Instructions._
import freechips.rocketchip.util._
import freechips.rocketchip.util.property
```

## Class declaration

### `src/main/scala/tile/FPU.scala`

```scala
abstract class FPUModule(implicit val p: Parameters) extends Module with HasCoreParameters with HasFPUParameters
// ...
class IntToFP(val latency: Int)(implicit p: Parameters) extends FPUModule()(p) with ShouldBeRetimed {
  val io = new Bundle {
    val in = Valid(new IntToFPInput).flip
    val out = Valid(new FPResult)
  }
```

### `src/main/scala/util/Annotations.scala`

```scala
/** Mix this into a Module class or instance to mark it for register retiming */
trait ShouldBeRetimed { self: RawModule =>
  chisel3.experimental.annotate(new ChiselAnnotation { def toFirrtl: RetimeModuleAnnotation = RetimeModuleAnnotation(self.toNamed) })
}
```

## Parent instantiation

```scala
/**
 * Int to FP conversion functional unit
 *
 * @param latency the amount of stages to delay by
 */
class IntToFPUnit(latency: Int)(implicit p: Parameters)
  extends PipelinedFunctionalUnit(
    numStages = latency,
    numBypassStages = 0,
    earliestBypassStage = 0,
    dataWidth = 65,
    needsFcsr = true)
  with tile.HasFPUParameters
{
  val fp_decoder = Module(new UOPCodeFPUDecoder) // TODO use a simpler decoder
  val io_req = io.req.bits
  fp_decoder.io.uopc := io_req.uop.uopc
  val fp_ctrl = fp_decoder.io.sigs
  val fp_rm = Mux(ImmGenRm(io_req.uop.imm_packed) === 7.U, io.fcsr_rm, ImmGenRm(io_req.uop.imm_packed))
  val req = Wire(new tile.FPInput)
  val tag = fp_ctrl.typeTagIn

  req <> fp_ctrl

  req.rm := fp_rm
  req.in1 := unbox(io_req.rs1_data, tag, None)
  req.in2 := unbox(io_req.rs2_data, tag, None)
  req.in3 := DontCare
  req.typ := ImmGenTyp(io_req.uop.imm_packed)
  req.fmt := DontCare // FIXME: this may not be the right thing to do here
  req.fmaCmd := DontCare

  assert (!(io.req.valid && fp_ctrl.fromint && req.in1(xLen).asBool),
    "[func] IntToFP integer input has 65th high-order bit set!")

  assert (!(io.req.valid && !fp_ctrl.fromint),
    "[func] Only support fromInt micro-ops.")

  val ifpu = Module(new tile.IntToFP(intToFpLatency))
  ifpu.io.in.valid := io.req.valid
  ifpu.io.in.bits := req
  ifpu.io.in.bits.in1 := io_req.rs1_data
  val out_double = Pipe(io.req.valid, fp_ctrl.typeTagOut === D, intToFpLatency).bits

//io.resp.bits.data              := box(ifpu.io.out.bits.data, !io.resp.bits.uop.fp_single)
  io.resp.bits.data              := box(ifpu.io.out.bits.data, out_double)
  io.resp.bits.fflags.valid      := ifpu.io.out.valid
  io.resp.bits.fflags.bits.uop   := io.resp.bits.uop
  io.resp.bits.fflags.bits.flags := ifpu.io.out.bits.exc
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

### `src/main/scala/INToRecFN.scala`

```scala
package hardfloat
// ...
class INToRecFN(intWidth: Int, expWidth: Int, sigWidth: Int) extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val signedIn = Bool(INPUT)
        val in = Bits(INPUT, intWidth)
        val roundingMode   = UInt(INPUT, 3)
        val detectTininess = UInt(INPUT, 1)
        val out = Bits(OUTPUT, expWidth + sigWidth + 1)
        val exceptionFlags = Bits(OUTPUT, 5)
    })
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
```

## Related source code

### `src/main/scala/tile/FPU.scala`

```scala
case class FPUParams(
  minFLen: Int = 32,
  fLen: Int = 64,
  divSqrt: Boolean = true,
  sfmaLatency: Int = 3,
  dfmaLatency: Int = 4
)
// ...
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

class IntToFPInput(implicit p: Parameters) extends CoreBundle()(p) with HasFPUCtrlSigs {
  val rm = Bits(width = FPConstants.RM_SZ)
  val typ = Bits(width = 2)
  val in1 = Bits(width = xLen)
}
// ...
case class FType(exp: Int, sig: Int) {
  def ieeeWidth = exp + sig
  def recodedWidth = ieeeWidth + 1

  def ieeeQNaN = UInt((BigInt(1) << (ieeeWidth - 1)) - (BigInt(1) << (sig - 2)), ieeeWidth)
  def qNaN = UInt((BigInt(7) << (exp + sig - 3)) + (BigInt(1) << (sig - 2)), recodedWidth)
  def isNaN(x: UInt) = x(sig + exp - 1, sig + exp - 3).andR
  def isSNaN(x: UInt) = isNaN(x) && !x(sig - 2)
// ...
  def recode(x: UInt) = hardfloat.recFNFromFN(exp, sig, x)
  def ieee(x: UInt) = hardfloat.fNFromRecFN(exp, sig, x)
}
// ...
object FType {
  val H = new FType(5, 11)
  val S = new FType(8, 24)
  val D = new FType(11, 53)

  val all = List(H, S, D)
}
// ...
trait HasFPUParameters {
  require(fLen == 0 || FType.all.exists(_.ieeeWidth == fLen))
  val minFLen: Int
  val fLen: Int
  def xLen: Int
  val minXLen = 32
  val nIntTypes = log2Ceil(xLen/minXLen) + 1
  val floatTypes = FType.all.filter(t => minFLen <= t.ieeeWidth && t.ieeeWidth <= fLen)
  def minType = floatTypes.head
  def maxType = floatTypes.last
  def prevType(t: FType) = floatTypes(typeTag(t) - 1)
  def maxExpWidth = maxType.exp
  def maxSigWidth = maxType.sig
  def typeTag(t: FType) = floatTypes.indexOf(t)
  def typeTagWbOffset = UInt(FType.all.indexOf(minType) + 1)
  def typeTagGroup(t: FType) = UInt(if (floatTypes.contains(t)) typeTag(t) else typeTag(maxType))
  // typeTag
  def H = typeTagGroup(FType.H)
  def S = typeTagGroup(FType.S)
  def D = typeTagGroup(FType.D)
  def I = UInt(typeTag(maxType))
// ...
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

  // zap bits that hardfloat thinks are don't-cares, but we do care about
  def sanitizeNaN(x: UInt, t: FType): UInt = {
    if (typeTag(t) == 0) {
      x
    } else {
      val maskedNaN = x & ~UInt((BigInt(1) << (t.sig-1)) | (BigInt(1) << (t.sig+t.exp-4)), t.recodedWidth)
      Mux(t.isNaN(x), maskedNaN, x)
    }
  }

  // implement NaN boxing and recoding for FL*/fmv.*.x
  def recode(x: UInt, tag: UInt): UInt = {
    def helper(x: UInt, t: FType): UInt = {
      if (typeTag(t) == 0) {
        t.recode(x)
      } else {
        val prevT = prevType(t)
        box(t.recode(x), t, helper(x, prevT), prevT)
      }
    }

    // fill MSBs of subword loads to emulate a wider load of a NaN-boxed value
    val boxes = floatTypes.map(t => UInt((BigInt(1) << maxType.ieeeWidth) - (BigInt(1) << t.ieeeWidth)))
    helper(boxes(tag) | x, maxType)
  }
```

### `src/main/scala/tile/Core.scala`

```scala
  def minFLen: Int = 32
// ...
trait HasCoreParameters extends HasTileParameters {
  val coreParams: CoreParams = tileParams.core

  val minFLen = coreParams.fpu.map(_ => coreParams.minFLen).getOrElse(0)
  val fLen = coreParams.fpu.map(_.fLen).getOrElse(0)
```

### `src/main/scala/exu/execution-units/fpu.scala`

```scala
    //                                     swap12         fma
    //                                     | swap32       | div
    //                                     | | typeTagIn  | | sqrt
    //                          ldst       | | | typeTagOut | | wflags
    //                          | wen      | | | | from_int | | |
    //                          | | ren1   | | | | | to_int | | |
    //                          | | | ren2 | | | | | | fastpipe |
    //                          | | | | ren3 | | | | | |  | | | |
    //                          | | | | |  | | | | | | |  | | | |
// ...
    BitPat(uopFMV_S_X)  -> List(X,X,N,N,N, X,X,S,D,Y,N,N, N,N,N,N),
// ...
    BitPat(uopFCVT_S_X) -> List(X,X,N,N,N, X,X,S,S,Y,N,N, N,N,N,Y),
// ...
    BitPat(uopFMV_D_X)  -> List(X,X,N,N,N, X,X,D,D,Y,N,N, N,N,N,N),
// ...
    BitPat(uopFCVT_D_X) -> List(X,X,N,N,N, X,X,D,D,Y,N,N, N,N,N,Y),
// ...
  val insns = f_table ++ d_table
  val decoder = rocket.DecodeLogic(io.uopc, default, insns)

  val s = io.sigs
  val sigs = Seq(s.ldst, s.wen, s.ren1, s.ren2, s.ren3, s.swap12,
                 s.swap23, s.typeTagIn, s.typeTagOut, s.fromint, s.toint, s.fastpipe, s.fma,
                 s.div, s.sqrt, s.wflags)
  sigs zip decoder map {case(s,d) => s := d}
```

### `src/main/scala/util/util.scala`

```scala
/**
 * Object to get the FP rounding mode out of a packed immediate.
 */
object ImmGenRm { def apply(ip: UInt): UInt = { return ip(2,0) } }

/**
 * Object to get the FP function fype from a packed immediate.
 * Note: only works if !(IS_B or IS_S)
 */
object ImmGenTyp { def apply(ip: UInt): UInt = { return ip(9,8) } }
```

### `src/main/scala/exu/decode.scala`

```scala
  // repackage the immediate, and then pass the fewest number of bits around
  val di24_20 = Mux(cs.imm_sel === IS_B || cs.imm_sel === IS_S, inst(11,7), inst(24,20))
  uop.imm_packed := Cat(inst(31,25), di24_20, inst(19,12))
```

### `src/main/scala/rocket/Instructions.scala`

```scala
object Instructions {
// ...
  def FCVT_S_W           = BitPat("b110100000000?????????????1010011")
  def FCVT_S_WU          = BitPat("b110100000001?????????????1010011")
  def FCVT_S_L           = BitPat("b110100000010?????????????1010011")
  def FCVT_S_LU          = BitPat("b110100000011?????????????1010011")
  def FMV_W_X            = BitPat("b111100000000?????000?????1010011")
  def FCVT_D_W           = BitPat("b110100100000?????????????1010011")
  def FCVT_D_WU          = BitPat("b110100100001?????????????1010011")
  def FCVT_D_L           = BitPat("b110100100010?????????????1010011")
  def FCVT_D_LU          = BitPat("b110100100011?????????????1010011")
```

## Documentation

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
=== Single-Precision Floating-Point Conversion and Move Instructions

Floating-point-to-integer and integer-to-floating-point conversion
instructions are encoded in the OP-FP major opcode space. FCVT.W.S or
FCVT.L.S converts a floating-point number in floating-point register
_rs1_ to a signed 32-bit or 64-bit integer, respectively, in integer
register _rd_. FCVT.S.W or FCVT.S.L converts a 32-bit or 64-bit signed
integer, respectively, in integer register _rs1_ into a floating-point
number in floating-point register _rd_. FCVT.WU.S, FCVT.LU.S, FCVT.S.WU,
and FCVT.S.LU variants convert to or from unsigned integer values. For
XLENlatexmath:[$>32$], FCVT.W[U].S sign-extends the 32-bit result to the
destination register width. FCVT.L[U].S and FCVT.S.L[U] are RV64-only
instructions. If the rounded result is not representable in the
destination format, it is clipped to the nearest value and the invalid
flag is set. <<int_conv>> gives the range of valid inputs
for FCVT._int_.S and the behavior for invalid inputs.
(((floating-point, conversion)))

All floating-point to integer and integer to floating-point conversion
instructions round according to the _rm_ field. A floating-point
register can be initialized to floating-point positive zero using
FCVT.S.W _rd_, `x0`, which will never set any exception flags.
...
FMV.W.X moves the single-precision value encoded in IEEE 754-2008
standard encoding from the lower 32 bits of integer register _rs1_ to
the floating-point register _rd_. The bits are not modified in the
transfer, and in particular, the payloads of non-canonical NaNs are
preserved.
```

### `src/d-st-ext.adoc`

```text
=== Double-Precision Floating-Point Conversion and Move Instructions

Floating-point-to-integer and integer-to-floating-point conversion
instructions are encoded in the OP-FP major opcode space. FCVT.W.D or
FCVT.L.D converts a double-precision floating-point number in
floating-point register _rs1_ to a signed 32-bit or 64-bit integer,
respectively, in integer register _rd_. FCVT.D.W or FCVT.D.L converts a
32-bit or 64-bit signed integer, respectively, in integer register _rs1_
into a double-precision floating-point number in floating-point register
_rd_. FCVT.WU.D, FCVT.LU.D, FCVT.D.WU, and FCVT.D.LU variants convert to
or from unsigned integer values. For RV64, FCVT.W[U].D sign-extends the
32-bit result. FCVT.L[U].D and FCVT.D.L[U] are RV64-only instructions.
The range of valid inputs for FCVT._int_.D and the behavior for invalid
inputs are the same as for FCVT._int_.S.
(((floating point, convert and move)))

All floating-point to integer and integer to floating-point conversion
instructions round according to the _rm_ field. Note FCVT.D.W[U] always
produces an exact result and is unaffected by rounding mode.
...
For XLEN&#8805;64 only, instructions are provided to move bit
patterns between the floating-point and integer registers. FMV.X.D moves
the double-precision value in floating-point register _rs1_ to a
representation in IEEE 754-2008 standard encoding in integer register
_rd_. FMV.D.X moves the double-precision value encoded in IEEE 754-2008
standard encoding from the integer register _rs1_ to the floating-point
register _rd_.

FMV.X.D and FMV.D.X do not modify the bits being transferred; in
particular, the payloads of non-canonical NaNs are preserved.
```
