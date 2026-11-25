# Implement `FPToInt`

Implement one complete `FPToInt` source-level hardware definition for the BOOM `LargeBoomConfig` configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Return only the complete `class FPToInt` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/config-mixins.scala`

```scala
              fpu = Some(freechips.rocketchip.tile.FPUParams(sfmaLatency=4, dfmaLatency=4, divSqrt=true))
    // ...
    case XLen => 64
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
  // ...
```

## Parent instantiation

### `src/main/scala/exu/execution-units/fpu.scala`

```scala
  // all FP units are padded out to the same latency for easy scheduling of the write port
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
    when (fp_ctrl.swap23) { req.in3 := req.in2 }
    req.typ := ImmGenTyp(io_req.uop.imm_packed)
    req.fmt := Mux(tag === S, 0.U, 1.U) // TODO support Zfh and avoid special-case below
    when (io_req.uop.uopc === uopFMV_X_S) {
      req.fmt := 0.U
    }
  // ...
  val fpiu = Module(new tile.FPToInt)
  fpiu.io.in.valid := io.req.valid && (fp_ctrl.toint || (fp_ctrl.fastpipe && fp_ctrl.wflags))
  fpiu.io.in.bits := fuInput(None)
  val fpiu_out = Pipe(RegNext(fpiu.io.in.valid && !fp_ctrl.fastpipe),
                              fpiu.io.out.bits, fpu_latency-1)
  val fpiu_result  = Wire(new tile.FPResult)
  fpiu_result.data := fpiu_out.bits.toint
  fpiu_result.exc  := fpiu_out.bits.exc

  val fpmu = Module(new tile.FPToFP(fpu_latency)) // latency 2 for rocket
  fpmu.io.in.valid := io.req.valid && fp_ctrl.fastpipe
  fpmu.io.in.bits := fpiu.io.in.bits
  fpmu.io.lt := fpiu.io.out.bits.lt
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
          FMV_X_S  -> List(N,N,Y,N,N,N,X,I,S,N,Y,N,N,N,N,N),
          FCLASS_S -> List(N,N,Y,N,N,N,X,S,S,N,Y,N,N,N,N,N),
          FCVT_W_S -> List(N,N,Y,N,N,N,X,S,X,N,Y,N,N,N,N,Y),
          FCVT_WU_S-> List(N,N,Y,N,N,N,X,S,X,N,Y,N,N,N,N,Y),
          FCVT_L_S -> List(N,N,Y,N,N,N,X,S,X,N,Y,N,N,N,N,Y),
          FCVT_LU_S-> List(N,N,Y,N,N,N,X,S,X,N,Y,N,N,N,N,Y),
          FEQ_S    -> List(N,N,Y,Y,N,N,N,S,S,N,Y,N,N,N,N,Y),
          FLT_S    -> List(N,N,Y,Y,N,N,N,S,S,N,Y,N,N,N,N,Y),
          FLE_S    -> List(N,N,Y,Y,N,N,N,S,S,N,Y,N,N,N,N,Y),
          // ...
          FMIN_S   -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,Y),
          FMAX_S   -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,Y),
          // ...
          FMV_X_D  -> List(N,N,Y,N,N,N,X,I,D,N,Y,N,N,N,N,N),
          FCLASS_D -> List(N,N,Y,N,N,N,X,D,D,N,Y,N,N,N,N,N),
          FCVT_W_D -> List(N,N,Y,N,N,N,X,D,X,N,Y,N,N,N,N,Y),
          FCVT_WU_D-> List(N,N,Y,N,N,N,X,D,X,N,Y,N,N,N,N,Y),
          FCVT_L_D -> List(N,N,Y,N,N,N,X,D,X,N,Y,N,N,N,N,Y),
          FCVT_LU_D-> List(N,N,Y,N,N,N,X,D,X,N,Y,N,N,N,N,Y),
          FCVT_S_D -> List(N,Y,Y,N,N,N,X,D,S,N,N,Y,N,N,N,Y),
          FCVT_D_S -> List(N,Y,Y,N,N,N,X,S,D,N,N,Y,N,N,N,Y),
          FEQ_D    -> List(N,N,Y,Y,N,N,N,D,D,N,Y,N,N,N,N,Y),
          FLT_D    -> List(N,N,Y,Y,N,N,N,D,D,N,Y,N,N,N,N,Y),
          FLE_D    -> List(N,N,Y,Y,N,N,N,D,D,N,Y,N,N,N,N,Y),
          // ...
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
  def classify(x: UInt) = {
    val sign = x(sig + exp)
    val code = x(exp + sig - 1, exp + sig - 3)
    val codeHi = code(2, 1)
    val isSpecial = codeHi === UInt(3)

    val isHighSubnormalIn = x(exp + sig - 3, sig - 1) < UInt(2)
    val isSubnormal = code === UInt(1) || codeHi === UInt(1) && isHighSubnormalIn
    val isNormal = codeHi === UInt(1) && !isHighSubnormalIn || codeHi === UInt(2)
    val isZero = code === UInt(0)
    val isInf = isSpecial && !code(0)
    val isNaN = code.andR
    val isSNaN = isNaN && !x(sig-2)
    val isQNaN = isNaN && x(sig-2)

    Cat(isQNaN, isSNaN, isInf && !sign, isNormal && !sign,
        isSubnormal && !sign, isZero && !sign, isZero && sign,
        isSubnormal && sign, isNormal && sign, isInf && sign)
  }

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
  def ieee(x: UInt) = hardfloat.fNFromRecFN(exp, sig, x)
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
  // implement NaN unboxing and un-recoding for FS*/fmv.x.*
  def ieee(x: UInt, t: FType = maxType): UInt = {
    if (typeTag(t) == 0) {
      t.ieee(x)
    } else {
      val unrecoded = t.ieee(x)
      val prevT = prevType(t)
      val prevRecoded = Cat(
        x(prevT.recodedWidth-2),
        x(t.sig-1),
        x(prevT.recodedWidth-3, 0))
      val prevUnrecoded = ieee(prevRecoded, prevT)
      Cat(unrecoded >> prevT.ieeeWidth, Mux(t.isNaN(x), prevUnrecoded, unrecoded(prevT.ieeeWidth-1, 0)))
    }
  }
// ...
abstract class FPUModule(implicit val p: Parameters) extends Module with HasCoreParameters with HasFPUParameters
// ...
```

### `src/main/scala/rocket/Instructions.scala`

```scala
  def FLE_S              = BitPat("b1010000??????????000?????1010011")
  def FLT_S              = BitPat("b1010000??????????001?????1010011")
  def FEQ_S              = BitPat("b1010000??????????010?????1010011")
  def FLE_D              = BitPat("b1010001??????????000?????1010011")
  def FLT_D              = BitPat("b1010001??????????001?????1010011")
  def FEQ_D              = BitPat("b1010001??????????010?????1010011")
  // ...
  def FCVT_W_S           = BitPat("b110000000000?????????????1010011")
  def FCVT_WU_S          = BitPat("b110000000001?????????????1010011")
  def FCVT_L_S           = BitPat("b110000000010?????????????1010011")
  def FCVT_LU_S          = BitPat("b110000000011?????????????1010011")
  def FMV_X_W            = BitPat("b111000000000?????000?????1010011")
  def FCLASS_S           = BitPat("b111000000000?????001?????1010011")
  def FCVT_W_D           = BitPat("b110000100000?????????????1010011")
  def FCVT_WU_D          = BitPat("b110000100001?????????????1010011")
  def FCVT_L_D           = BitPat("b110000100010?????????????1010011")
  def FCVT_LU_D          = BitPat("b110000100011?????????????1010011")
  def FMV_X_D            = BitPat("b111000100000?????000?????1010011")
  def FCLASS_D           = BitPat("b111000100000?????001?????1010011")
  // ...
  def FMV_X_S            = BitPat("b111000000000?????000?????1010011")
```

### `src/main/scala/exu/decode.scala`

```scala
  val di24_20 = Mux(cs.imm_sel === IS_B || cs.imm_sel === IS_S, inst(11,7), inst(24,20))
  uop.imm_packed := Cat(inst(31,25), di24_20, inst(19,12))
```

### `src/main/scala/util/util.scala`

```scala
object ImmGenRm { def apply(ip: UInt): UInt = { return ip(2,0) } }
// ...
object ImmGenTyp { def apply(ip: UInt): UInt = { return ip(9,8) } }
```

### `src/main/scala/CompareRecFN.scala`

```scala
package hardfloat
// ...
class CompareRecFN(expWidth: Int, sigWidth: Int) extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val a = Bits(INPUT, expWidth + sigWidth + 1)
        val b = Bits(INPUT, expWidth + sigWidth + 1)
        val signaling = Bool(INPUT)
        val lt = Bool(OUTPUT)
        val eq = Bool(OUTPUT)
        val gt = Bool(OUTPUT)
        val exceptionFlags = Bits(OUTPUT, 5)
    })
    // ...
```

### `src/main/scala/RecFNToIN.scala`

```scala
package hardfloat
// ...
class RecFNToIN(expWidth: Int, sigWidth: Int, intWidth: Int) extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val in = Bits(INPUT, expWidth + sigWidth + 1)
        val roundingMode = UInt(INPUT, 3)
        val signedOut = Bool(INPUT)
        val out = Bits(OUTPUT, intWidth)
        val intExceptionFlags = Bits(OUTPUT, 3)
    })
    // ...
    io.intExceptionFlags := Cat(invalidExc, overflow, inexact)
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
[[bitdef]]
.Accrued exception flag encoding.
[%autowidth,float="center",align="center",cols="^,<",options="header",]
|===
|Flag Mnemonic |Flag Meaning
|NV |Invalid Operation
|DZ |Divide by Zero
|OF |Overflow
|UF |Underflow
|NX |Inexact
|===
...
Floating-point loads and stores use the same base+offset addressing mode as the integer base ISAs, with a base address in register _rs1_ and a 12-bit signed byte offset. The FLW instruction loads a single-precision floating-point value from memory into floating-point register _rd_. FSW stores a single-precision value from floating-point register _rs2_ to memory.
...
FLW and FSW do not modify the bits being transferred; in particular, the payloads of non-canonical NaNs are preserved.
...
All floating-point operations that perform rounding can select the
rounding mode using the _rm_ field with the encoding shown in
<<rm>>.

Floating-point minimum-number and maximum-number instructions FMIN.S and FMAX.S write, respectively, the smaller or larger of _rs1_ and _rs2_ to _rd_. For the purposes of these instructions only, the value
latexmath:[$-0.0$] is considered to be less than the value
latexmath:[$+0.0$]. If both inputs are NaNs, the result is the canonical NaN. If only one operand is a NaN, the result is the non-NaN operand.
Signaling NaN inputs set the invalid operation exception flag, even when the result is not NaN.
...
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
...
[[int_conv]]
.Domains of float-to-integer conversions and behavior for invalid inputs
[%autowidth,float="center",align="center",cols="<,>,>,>,>",options="header",]
|===
| |FCVT.W.S |FCVT.WU.S |FCVT.L.S |FCVT.LU.S
|Minimum valid input (after rounding) |latexmath:[$-2^{31}$] |0
|latexmath:[$-2^{63}$] |0

|Maximum valid input (after rounding) |latexmath:[$2^{31}-1$]
|latexmath:[$2^{32}-1$] |latexmath:[$2^{63}-1$] |latexmath:[$2^{64}-1$]

|Output for out-of-range negative input |latexmath:[$-2^{31}$] |0
|latexmath:[$-2^{63}$] |0

|Output for latexmath:[$-\infty$] |latexmath:[$-2^{31}$] |0
|latexmath:[$-2^{63}$] |0

|Output for out-of-range positive input |latexmath:[$2^{31}-1$]
|latexmath:[$2^{32}-1$] |latexmath:[$2^{63}-1$] |latexmath:[$2^{64}-1$]

|Output for latexmath:[$+\infty$] or NaN |latexmath:[$2^{31}-1$]
|latexmath:[$2^{32}-1$] |latexmath:[$2^{63}-1$] |latexmath:[$2^{64}-1$]
|===

All floating-point conversion instructions set the Inexact exception
flag if the rounded result differs from the operand value and the
Invalid exception flag is not set.
...
Instructions are provided to move bit patterns between the
floating-point and integer registers. FMV.X.W moves the single-precision value in floating-point register _rs1_ represented in IEEE 754-2008 encoding to the lower 32 bits of integer register _rd_. The bits are not modified in the transfer, and in particular, the payloads of non-canonical NaNs are preserved. For RV64, the higher 32 bits of the destination register are filled with copies of the floating-point number's sign bit.
...
=== Single-Precision Floating-Point Compare Instructions

Floating-point compare instructions (FEQ.S, FLT.S, FLE.S) perform the
specified comparison between floating-point registers
(latexmath:[$\mbox{\em rs1}
= \mbox{\em rs2}$], latexmath:[$\mbox{\em rs1} < \mbox{\em rs2}$],
latexmath:[$\mbox{\em rs1} \leq
\mbox{\em rs2}$]) writing 1 to the integer register _rd_ if the
condition holds, and 0 otherwise.

FLT.S and FLE.S perform what the IEEE 754-2008 standard refers to as
_signaling_ comparisons: that is, they set the invalid operation
exception flag if either input is NaN. FEQ.S performs a _quiet_
comparison: it only sets the invalid operation exception flag if either input is a signaling NaN. For all three instructions, the result is 0 if either operand is NaN.
...
=== Single-Precision Floating-Point Classify Instruction

The FCLASS.S instruction examines the value in floating-point register
_rs1_ and writes to integer register _rd_ a 10-bit mask that indicates
the class of the floating-point number. The format of the mask is
described in <<fclass>>. The corresponding bit in _rd_ will
be set if the property is true and clear otherwise. All other bits in
_rd_ are cleared. Note that exactly one bit in _rd_ will be set.
FCLASS.S does not set the floating-point exception flags.
...
[[fclass]]
.Format of result of FCLASS instruction.
[%autowidth,float="center",align="center",cols="^,<",options="header",]
|===
|_rd_ bit |Meaning
|0 |_rs1_ is latexmath:[$-\infty$].
|1 |_rs1_ is a negative normal number.
|2 |_rs1_ is a negative subnormal number.
|3 |_rs1_ is latexmath:[$-0$].
|4 |_rs1_ is latexmath:[$+0$].
|5 |_rs1_ is a positive subnormal number.
|6 |_rs1_ is a positive normal number.
|7 |_rs1_ is latexmath:[$+\infty$].
|8 |_rs1_ is a signaling NaN.
|9 |_rs1_ is a quiet NaN.
|===
```

### `src/d-st-ext.adoc`

```text
=== Double-Precision Floating-Point Computational Instructions

The double-precision floating-point computational instructions are
defined analogously to their single-precision counterparts, but operate
on double-precision operands and produce double-precision results.
...
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
...
=== Double-Precision Floating-Point Compare Instructions

The double-precision floating-point compare instructions are defined
analogously to their single-precision counterparts, but operate on
double-precision operands.
...
=== Double-Precision Floating-Point Classify Instruction

The double-precision floating-point classify instruction, FCLASS.D, is
defined analogously to its single-precision counterpart, but operates on
double-precision operands.
```
