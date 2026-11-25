# Implement `FPToFP`

Implement one complete `FPToFP` source-level hardware definition for the BOOM `LargeBoomConfig` configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Return only the complete `class FPToFP` definition in a single Scala code block, with no text outside the block.

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
class FPToFP(val latency: Int)(implicit p: Parameters) extends FPUModule()(p) with ShouldBeRetimed {
  val io = new Bundle {
    val in = Valid(new FPInput).flip
    val out = Valid(new FPResult)
    val lt = Bool(INPUT) // from FPToInt
  }
  // ...
```

## Parent instantiation

### `src/main/scala/exu/execution-units/fpu.scala`

```scala
  val fpu_latency = dfmaLatency
  val io_req = io.req.bits

  val fp_decoder = Module(new UOPCodeFPUDecoder)
  fp_decoder.io.uopc := io_req.uop.uopc
  val fp_ctrl = fp_decoder.io.sigs
  val fp_rm = Mux(ImmGenRm(io_req.uop.imm_packed) === 7.U, io_req.fcsr_rm, ImmGenRm(io_req.uop.imm_packed))

  def fuInput(minT: Option[tile.FType]): tile.FPInput = {
    val req = Wire(new tile.FPInput)
    val tag = fp_ctrl.typeTagIn
    req <> fp_ctrl
    req.rm := fp_rm
    req.in1 := unbox(io_req.rs1_data, tag, minT)
    req.in2 := unbox(io_req.rs2_data, tag, minT)
    req.in3 := unbox(io_req.rs3_data, tag, minT)
  // ...
  fpiu.io.in.bits := fuInput(None)
  // ...
  val fpmu = Module(new tile.FPToFP(fpu_latency)) // latency 2 for rocket
  fpmu.io.in.valid := io.req.valid && fp_ctrl.fastpipe
  fpmu.io.in.bits := fpiu.io.in.bits
  fpmu.io.lt := fpiu.io.out.bits.lt
  val fpmu_double = Pipe(io.req.valid && fp_ctrl.fastpipe, fp_ctrl.typeTagOut === D, fpu_latency).bits

  // Response (all FP units have been padded out to the same latency)
  io.resp.valid := fpiu_out.valid ||
                   fpmu.io.out.valid ||
                   sfma.io.out.valid ||
                   dfma.io.out.valid
  val fpu_out_data =
    Mux(dfma.io.out.valid, box(dfma.io.out.bits.data, true.B),
    Mux(sfma.io.out.valid, box(sfma.io.out.bits.data, false.B),
    Mux(fpiu_out.valid,    fpiu_result.data,
                           box(fpmu.io.out.bits.data, fpmu_double))))
  // ...
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

class FPUDecoder(implicit p: Parameters) extends FPUModule()(p) {
  val io = new Bundle {
    val inst = Bits(INPUT, 32)
    val sigs = new FPUCtrlSigs().asOutput
  }

  val default =       List(X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X)
          // ...
          FSGNJ_S  -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,N),
          FSGNJN_S -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,N),
          FSGNJX_S -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,N),
          FMIN_S   -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,Y),
          FMAX_S   -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,Y),
          // ...
          FCVT_S_D -> List(N,Y,Y,N,N,N,X,D,S,N,N,Y,N,N,N,Y),
          FCVT_D_S -> List(N,Y,Y,N,N,N,X,S,D,N,N,Y,N,N,N,Y),
          // ...
          FSGNJ_D  -> List(N,Y,Y,Y,N,N,N,D,D,N,N,Y,N,N,N,N),
          FSGNJN_D -> List(N,Y,Y,Y,N,N,N,D,D,N,N,Y,N,N,N,N),
          FSGNJX_D -> List(N,Y,Y,Y,N,N,N,D,D,N,N,Y,N,N,N,N),
          FMIN_D   -> List(N,Y,Y,Y,N,N,N,D,D,N,N,Y,N,N,N,Y),
          FMAX_D   -> List(N,Y,Y,Y,N,N,N,D,D,N,N,Y,N,N,N,Y),
  // ...
  val decoder = DecodeLogic(io.inst, default, insns)
  val s = io.sigs
  val sigs = Seq(s.ldst, s.wen, s.ren1, s.ren2, s.ren3, s.swap12,
                 s.swap23, s.typeTagIn, s.typeTagOut, s.fromint, s.toint,
                 s.fastpipe, s.fma, s.div, s.sqrt, s.wflags)
  sigs zip decoder map {case(s,d) => s := d}
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
  def isSNaN(x: UInt) = isNaN(x) && !x(sig - 2)
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
  // ...
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
  // ...
  io.out.bits.lt := dcmp.io.lt || (dcmp.io.a.asSInt < 0.S && dcmp.io.b.asSInt >= 0.S)
  // ...
```

### `src/main/scala/rocket/Instructions.scala`

```scala
  def FSGNJ_S            = BitPat("b0010000??????????000?????1010011")
  def FSGNJN_S           = BitPat("b0010000??????????001?????1010011")
  def FSGNJX_S           = BitPat("b0010000??????????010?????1010011")
  def FMIN_S             = BitPat("b0010100??????????000?????1010011")
  def FMAX_S             = BitPat("b0010100??????????001?????1010011")
  // ...
  def FSGNJ_D            = BitPat("b0010001??????????000?????1010011")
  def FSGNJN_D           = BitPat("b0010001??????????001?????1010011")
  def FSGNJX_D           = BitPat("b0010001??????????010?????1010011")
  def FMIN_D             = BitPat("b0010101??????????000?????1010011")
  def FMAX_D             = BitPat("b0010101??????????001?????1010011")
```

### `src/main/scala/exu/decode.scala`

```scala
  uop.imm_packed := Cat(inst(31,25), di24_20, inst(19,12))
```

### `src/main/scala/util/util.scala`

```scala
object ImmGenRm { def apply(ip: UInt): UInt = { return ip(2,0) } }
```

### `src/main/scala/RecFNToRecFN.scala`

```scala
package hardfloat

import Chisel._
import consts._

class
    RecFNToRecFN(
        inExpWidth: Int, inSigWidth: Int, outExpWidth: Int, outSigWidth: Int)
    extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val in = Bits(INPUT, inExpWidth + inSigWidth + 1)
        val roundingMode   = UInt(INPUT, 3)
        val detectTininess = UInt(INPUT, 1)
        val out = Bits(OUTPUT, outExpWidth + outSigWidth + 1)
        val exceptionFlags = Bits(OUTPUT, 5)
    })
    // ...
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
All floating-point operations that perform rounding can select the
rounding mode using the _rm_ field with the encoding shown in
<<rm>>.

Floating-point minimum-number and maximum-number instructions FMIN.S and FMAX.S write, respectively, the smaller or larger of _rs1_ and _rs2_ to _rd_. For the purposes of these instructions only, the value
latexmath:[$-0.0$] is considered to be less than the value
latexmath:[$+0.0$]. If both inputs are NaNs, the result is the canonical NaN. If only one operand is a NaN, the result is the non-NaN operand.
Signaling NaN inputs set the invalid operation exception flag, even when the result is not NaN.
...
Floating-point to floating-point sign-injection instructions, FSGNJ.S,
FSGNJN.S, and FSGNJX.S, produce a result that takes all bits except the
sign bit from _rs1_. For FSGNJ, the result's sign bit is _rs2_'s sign
bit; for FSGNJN, the result's sign bit is the opposite of _rs2_'s sign
bit; and for FSGNJX, the sign bit is the XOR of the sign bits of _rs1_
and _rs2_. Sign-injection instructions do not set floating-point
exception flags, nor do they canonicalize NaNs. Note, FSGNJ.S _rx, ry,
ry_ moves _ry_ to _rx_ (assembler pseudoinstruction FMV.S _rx, ry_);
FSGNJN.S _rx, ry, ry_ moves the negation of _ry_ to _rx_ (assembler
pseudoinstruction FNEG.S _rx, ry_); and FSGNJX.S _rx, ry, ry_ moves the absolute value of _ry_ to _rx_ (assembler pseudoinstruction FABS.S _rx,
ry_).
```

### `src/d-st-ext.adoc`

```text
[[nanboxing]]
=== NaN Boxing of Narrower Values

When multiple floating-point precisions are supported, then valid values
of narrower _n_-bit types, _n_<FLEN, are represented in the lower _n_ bits of an FLEN-bit NaN value, in a process termed NaN-boxing. The upper bits of a valid NaN-boxed value must be all 1s. Valid NaN-boxed _n_-bit values
therefore appear as negative quiet NaNs (qNaNs) when viewed as any wider
_m_-bit value, _n_ < _m_ &#8804; FLEN. Any operation that writes a narrower result to an 'f' register must write all 1s to the uppermost FLEN-_n_ bits to yield a legal NaN-boxedvalue.
...
=== Double-Precision Floating-Point Computational Instructions

The double-precision floating-point computational instructions are
defined analogously to their single-precision counterparts, but operate
on double-precision operands and produce double-precision results.
...
The double-precision to single-precision and single-precision to
double-precision conversion instructions, FCVT.S.D and FCVT.D.S, are
encoded in the OP-FP major opcode space and both the source and
destination are floating-point registers. The _rs2_ field encodes the
datatype of the source, and the _fmt_ field encodes the datatype of the
destination. FCVT.S.D rounds according to the RM field; FCVT.D.S will
never round.
...
Floating-point to floating-point sign-injection instructions, FSGNJ.D,
FSGNJN.D, and FSGNJX.D are defined analogously to the single-precision
sign-injection instruction.
```
