# Implement `FDivSqrtUnit`

Implement one complete `FDivSqrtUnit` source-level hardware definition for the selected BOOM configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class FDivSqrtUnit` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/config-mixins.scala`

```scala
              fpu = Some(freechips.rocketchip.tile.FPUParams(sfmaLatency=4, dfmaLatency=4, divSqrt=true))
```

## Package and imports

### `src/main/scala/exu/execution-units/fdiv.scala`

```scala
package boom.exu

import chisel3._
import chisel3.util._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.tile.FPConstants._
import freechips.rocketchip.tile
import boom.common._
import boom.util._
import freechips.rocketchip.tile.HasFPUParameters
import freechips.rocketchip.util.uintToBitPat
```

## Class declaration

### `src/main/scala/exu/execution-units/fdiv.scala`

```scala
class FDivSqrtUnit(implicit p: Parameters)
  extends FunctionalUnit(
    isPipelined = false,
    numStages = 1,
    numBypassStages = 0,
    dataWidth = 65,
    needsFcsr = true)
  with tile.HasFPUParameters
{
```

## Parent instantiation

### `src/main/scala/exu/execution-units/execution-unit.scala`

```scala
  var fdivsqrt: FDivSqrtUnit = null
  val fdiv_resp_fflags = Wire(new ValidIO(new FFlagsResp()))
  fdiv_resp_fflags := DontCare
  fdiv_resp_fflags.valid := false.B
  if (hasFdiv) {
    fdivsqrt = Module(new FDivSqrtUnit())
    fdivsqrt.io.req.valid         := io.req.valid && io.req.bits.uop.fu_code_is(FU_FDV)
    fdivsqrt.io.req.bits.uop      := io.req.bits.uop
    fdivsqrt.io.req.bits.rs1_data := io.req.bits.rs1_data
    fdivsqrt.io.req.bits.rs2_data := io.req.bits.rs2_data
    fdivsqrt.io.req.bits.rs3_data := DontCare
    fdivsqrt.io.req.bits.pred_data := false.B
    fdivsqrt.io.req.bits.kill     := io.req.bits.kill
    fdivsqrt.io.fcsr_rm           := io.fcsr_rm
    fdivsqrt.io.brupdate          := io.brupdate

    // share write port with the pipelined units
    fdivsqrt.io.resp.ready := !(fu_units.map(_.io.resp.valid).reduce(_|_)) // TODO PERF will get blocked by fpiu.

    fdiv_busy := !fdivsqrt.io.req.ready || (io.req.valid && io.req.bits.uop.fu_code_is(FU_FDV))

    fdiv_resp_fflags := fdivsqrt.io.resp.bits.fflags

    fu_units += fdivsqrt
  }
```

### `src/main/scala/exu/fp-pipeline.scala`

```scala
  exe_units.map(_.io.fcsr_rm := io.fcsr_rm)
  exe_units.map(_.io.status := io.status)

  //-------------------------------------------------------------
  // **** Flush Pipeline ****
  //-------------------------------------------------------------
  // flush on exceptions, miniexeptions, and after some special instructions

  for (w <- 0 until exe_units.length) {
    exe_units(w).io.req.bits.kill := io.flush_pipeline
  }
```

### `src/main/scala/exu/core.scala`

```scala
  exe_units.withFilter(_.hasFcsr).map(_.io.fcsr_rm := csr.io.fcsr_rm)
  io.fcsr_rm := csr.io.fcsr_rm

  if (usingFPU) {
    fp_pipeline.io.fcsr_rm := csr.io.fcsr_rm
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

### `src/main/scala/exu/execution-units/functional-unit.scala`

```scala
/**
 * Bundle for signals sent to the functional unit
 *
 * @param dataWidth width of the data sent to the functional unit
 */
class FuncUnitReq(val dataWidth: Int)(implicit p: Parameters) extends BoomBundle
  with HasBoomUOP
{
  val numOperands = 3

  val rs1_data = UInt(dataWidth.W)
  val rs2_data = UInt(dataWidth.W)
  val rs3_data = UInt(dataWidth.W) // only used for FMA units
  val pred_data = Bool()

  val kill = Bool() // kill everything
}

/**
 * Bundle for the signals sent out of the function unit
 *
 * @param dataWidth data sent from the functional unit
 */
class FuncUnitResp(val dataWidth: Int)(implicit p: Parameters) extends BoomBundle
  with HasBoomUOP
{
  val predicated = Bool() // Was this response from a predicated-off instruction
  val data = UInt(dataWidth.W)
  val fflags = new ValidIO(new FFlagsResp)
  val addr = UInt((vaddrBits+1).W) // only for maddr -> LSU
  val mxcpt = new ValidIO(UInt((freechips.rocketchip.rocket.Causes.all.max+2).W)) //only for maddr->LSU
  val sfence = Valid(new freechips.rocketchip.rocket.SFenceReq) // only for mcalc
}
```

```scala
/**
 * Abstract top level functional unit class that wraps a lower level hand made functional unit
 *
 * @param isPipelined is the functional unit pipelined?
 * @param numStages how many pipeline stages does the functional unit have
 * @param numBypassStages how many bypass stages does the function unit have
 * @param dataWidth width of the data being operated on in the functional unit
 * @param hasBranchUnit does this functional unit have a branch unit?
 */
abstract class FunctionalUnit(
  val isPipelined: Boolean,
  val numStages: Int,
  val numBypassStages: Int,
  val dataWidth: Int,
  val isJmpUnit: Boolean = false,
  val isAluUnit: Boolean = false,
  val isMemAddrCalcUnit: Boolean = false,
  val needsFcsr: Boolean = false)
  (implicit p: Parameters) extends BoomModule
{
  val io = IO(new Bundle {
    val req    = Flipped(new DecoupledIO(new FuncUnitReq(dataWidth)))
    val resp   = (new DecoupledIO(new FuncUnitResp(dataWidth)))

    val brupdate = Input(new BrUpdateInfo())

    val bypass = Output(Vec(numBypassStages, Valid(new ExeUnitResp(dataWidth))))

    // only used by the fpu unit
    val fcsr_rm = if (needsFcsr) Input(UInt(tile.FPConstants.RM_SZ.W)) else null

```

### `src/main/scala/chisel3/util/Decoupled.scala`

```scala
abstract class ReadyValidIO[+T <: Data](gen: T) extends Bundle {
  // ...
  /** Indicates that the consumer is ready to accept the data this cycle
    * @group Signals
    */
  val ready = Input(Bool())

  /** Indicates that the producer has put valid data in 'bits'
    * @group Signals
    */
  val valid = Output(Bool())

  /** The data to be transferred when ready and valid are asserted at the same cycle
    * @group Signals
    */
  val bits = Output(genType)
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
  val inst             = UInt(32.W)
  // ...
  val br_mask          = UInt(maxBrCount.W)  // which branches are we being speculated under?
  // ...
  val imm_packed       = UInt(LONGEST_IMM_SZ.W) // densely pack the imm in decode...
                                              // then translate and sign-extend in execute
```

### `src/main/scala/exu/execution-units/execution-unit.scala`

```scala
/**
 * Floating Point flag response
 */
class FFlagsResp(implicit p: Parameters) extends BoomBundle
{
  val uop = new MicroOp()
  val flags = Bits(tile.FPConstants.FLAGS_SZ.W)
}

```

### `src/main/scala/exu/execution-units/fdiv.scala`

```scala
/**
 * Decoder for FPU divide and square root signals
 */
class UOPCodeFDivDecoder(implicit p: Parameters) extends BoomModule
  with HasFPUParameters
{
  val io = IO(new Bundle {
    val uopc = Input(Bits(UOPC_SZ.W))
    val sigs = Output(new tile.FPUCtrlSigs())
  })

  val N = BitPat("b0")
  val Y = BitPat("b1")
  val X = BitPat("b?")

  val decoder = freechips.rocketchip.rocket.DecodeLogic(io.uopc,
    // Note: not all of these signals are used or necessary, but we're
    // constrained by the need to fit the rocket.FPU units' ctrl signals.
    //                                      swap12         fma
    //                                      | swap32       | div
    //                                      | | typeTagIn  | | sqrt
    //                           ldst       | | | typeTagOut | | wflags
    //                           | wen      | | | | from_int | | |
    //                           | | ren1   | | | | | to_int | | |
    //                           | | | ren2 | | | | | | fast | | |
    //                           | | | | ren3 | | | | | |  | | | |
    //                           | | | | |  | | | | | | |  | | | |
    /* Default */           List(X,X,X,X,X, X,X,X,X,X,X,X, X,X,X,X),
    Array(
      BitPat(uopFDIV_S)  -> List(X,X,Y,Y,X, X,X,S,S,X,X,X, X,Y,N,Y),
      BitPat(uopFDIV_D)  -> List(X,X,Y,Y,X, X,X,D,D,X,X,X, X,Y,N,Y),
      BitPat(uopFSQRT_S) -> List(X,X,Y,N,X, X,X,S,S,X,X,X, X,N,Y,Y),
      BitPat(uopFSQRT_D) -> List(X,X,Y,N,X, X,X,D,D,X,X,X, X,N,Y,Y)
    ): Array[(BitPat, List[BitPat])])

  val s = io.sigs
  val sigs = Seq(s.ldst, s.wen, s.ren1, s.ren2, s.ren3, s.swap12,
                 s.swap23, s.typeTagIn, s.typeTagOut, s.fromint, s.toint, s.fastpipe, s.fma,
                 s.div, s.sqrt, s.wflags)
  sigs zip decoder map {case(s,d) => s := d}
}
```

### `src/main/scala/util/util.scala`

```scala
/**
 * Object to check if MicroOp was killed due to a branch mispredict.
 * Uses "Fast" branch masks
 */
object IsKilledByBranch
{
  def apply(brupdate: BrUpdateInfo, uop: MicroOp): Bool = {
    return maskMatch(brupdate.b1.mispredict_mask, uop.br_mask)
  }

  def apply(brupdate: BrUpdateInfo, uop_mask: UInt): Bool = {
    return maskMatch(brupdate.b1.mispredict_mask, uop_mask)
  }
}
// ...
/**
 * Object to return a BR mask given a MicroOp mask and old BR mask.
 */
object GetNewBrMask
{
   def apply(brupdate: BrUpdateInfo, uop: MicroOp): UInt = {
     return uop.br_mask & ~brupdate.b1.resolve_mask
   }

   def apply(brupdate: BrUpdateInfo, br_mask: UInt): UInt = {
     return br_mask & ~brupdate.b1.resolve_mask
   }
}
// ...
/**
 * Object to get the FP rounding mode out of a packed immediate.
 */
object ImmGenRm { def apply(ip: UInt): UInt = { return ip(2,0) } }
```

### `src/main/scala/exu/decode.scala`

```scala
  // repackage the immediate, and then pass the fewest number of bits around
  val di24_20 = Mux(cs.imm_sel === IS_B || cs.imm_sel === IS_S, inst(11,7), inst(24,20))
  uop.imm_packed := Cat(inst(31,25), di24_20, inst(19,12))
```

### `src/main/scala/DivSqrtRecF64.scala`

```scala
package hardfloat
// ...
class DivSqrtRecF64 extends Module
{
    val io = IO(new Bundle {
        val inReady_div  = Bool(OUTPUT)
        val inReady_sqrt = Bool(OUTPUT)
        val inValid = Bool(INPUT)
        val sqrtOp = Bool(INPUT)
        val a = Bits(INPUT, 65)
        val b = Bits(INPUT, 65)
        val roundingMode   = UInt(INPUT, 3)
        val detectTininess = UInt(INPUT, 1)
        val outValid_div  = Bool(OUTPUT)
        val outValid_sqrt = Bool(OUTPUT)
        val out = Bits(OUTPUT, 65)
        val exceptionFlags = Bits(OUTPUT, 5)
    })

```

### `src/main/scala/RecFNToRecFN.scala`

```scala
package hardfloat
// ...
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

  def ieeeQNaN = UInt((BigInt(1) << (ieeeWidth - 1)) - (BigInt(1) << (sig - 2)), ieeeWidth)
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

  // zap bits that hardfloat thinks are don't-cares, but we do care about
  def sanitizeNaN(x: UInt, t: FType): UInt = {
    if (typeTag(t) == 0) {
      x
    } else {
      val maskedNaN = x & ~UInt((BigInt(1) << (t.sig-1)) | (BigInt(1) << (t.sig+t.exp-4)), t.recodedWidth)
      Mux(t.isNaN(x), maskedNaN, x)
    }
  }
```

## Documentation

### `docs/sections/execution-stages.rst`

```text
Floating Point Divide and Square-root Unit
------------------------------------------

BOOM fully supports floating point divide and square-root operations
using a single **FDiv/Sqrt** (or fdiv for short). BOOM accomplishes this by
instantiating a double-precision unit from the hardfloat repository. The
unit comes with the following features/constraints:

-  expects 65-bit recoded double-precision inputs

-  provides a 65-bit recoded double-precision output

-  can execute a divide operation and a square-root operation
   simultaneously

-  operations are unpipelined and take an unknown, variable latency

-  provides an *unstable* FIFO interface

Single-precision operations have their operands upscaled to
double-precision (and then the output downscaled). [4]_

Although the unit is unpipelined, it does not fit cleanly into the
Pipelined/Unpipelined abstraction used by the other :term:`Functional Unit` s
(see :numref:`fu-hierarchy`). This is because the unit provides
an unstable FIFO interface: although the unit may provide a *ready*
signal on Cycle ``i``, there is no guarantee that it will continue
to be *ready* on Cycle ``i+1``, even if no operations are enqueued.
This proves to be a challenge, as the Issue Queue may attempt to issue
an instruction but cannot be certain the unit will accept it once it
reaches the unit on a later cycle.

The solution is to add extra buffering within the unit to hold
instructions until they can be released directly into the unit. If the
buffering of the unit fills up, back pressure can be safely applied to
the **Issue Queue**. [5]_
```

### `doc/divSqrtRecodedFloat64_mulAddZ31.txt`

```text
Module `divSqrtRecodedFloat64_mulAddZ31' computes a division or square root
for standard 64-bit floating-point in recoded form, using a separate integer
multiplier-adder.  Multiple clock cycles are needed for each division or
square-root operation.

------------------------------------------------------------------------------
Function interface

The module can be working on up to four operations at a time, in a pipelined
fashion, for any mix of division and square-root operations.  A new
division operation can be started in any clock cycle for which the output
`inReady_div' is asserted (= 1).  Likewise, a new square-root operation can
be started whenever output `inReady_sqrt' is asserted.  An operation is
started when the following conditions are met in any clock cycle:

    inValid & (sqrtOp == 0) & inReady_div   ->  division is started
    inValid & (sqrtOp == 1) & inReady_sqrt  ->  square root is started

When a division is started, the values of inputs `a', `b', and
`roundingMode' in the same clock cycle are interpreted as the dividend,
divisor, and rounding mode, respectively.  (The division is thus `a'/`b'.)
For a square root, `b' provides the function argument and `roundingMode'
is again the rounding mode.  Arguments `a' and `b' are supplied in recoded
form, which is documented elsewhere.

In each clock cycle, input `inValid' is expected to be stable very early in
the cycle.  The same is true of inputs `sqrtOp' and `b' whenever `inValid'
is asserted.

When the module is working on an operation, `inReady_div' or `inReady_sqrt'
may be asserted by the module for one clock cycle and then deasserted in the
next cycle, even without a new operation being started (for example, because
`inValid' was 0).  When there are existing operations in the pipeline, the
opportunity to add a new operation to the pipeline will be available in some
cycles and not others.  These opportunities may also depend on the values
of arguments `a', `b', and `roundingMode' for the operations already in the
pipeline.  After an operation is started, the first opportunity to start
another operation of the same kind will be:

    division after division:        at most 6 cycles later;
    square root after square root:  at most 10 cycles later.

Operation results are delivered strictly in the same order that the
operations were started.  When a division result is ready, `outValid_div'
is asserted (= 1), and when a square root result is ready, `outValid_sqrt'
is asserted.  In either case, `out' is the function result in recoded form
(same as the `a' and `b' inputs), and `exceptionFlags' is a bit vector of
the exception flags, with this format:

    { invalid, infinity, overflow, underflow, inexact }

(The "infinity" exception is also known as "divide-by-zero".)

Outputs `out' and `exceptionFlags' are expected to be stable only late in a
clock cycle.

From the beginning of the starting clock cycle to the end of the final
cycle, a single operation has the following latency:

    division:     19 cycles or less;
    square root:  27 cycles or less.

Latencies shorter than the maximum occur only for special cases, such as
when the argument of a square root is negative.  The minimum special-case
latency is 2 cycles, for either division or square root.
```

### `src/f-st-ext.adoc`

```text
[[single-float-compute]]
=== Single-Precision Floating-Point Computational Instructions

Floating-point arithmetic instructions with one or two source operands
use the R-type format with the OP-FP major opcode. FADD.S and FMUL.S
perform single-precision floating-point addition and multiplication
respectively, between _rs1_ and _rs2_. FSUB.S performs the
single-precision floating-point subtraction of _rs2_ from _rs1_. FDIV.S performs the single-precision floating-point division of _rs1_ by _rs2_. FSQRT.S computes the square root of _rs1_. In each case, the result is written to _rd_.

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

All floating-point operations that perform rounding can select the
rounding mode using the _rm_ field with the encoding shown in
<<rm>>.
```

### `src/d-st-ext.adoc`

```text
=== Double-Precision Floating-Point Computational Instructions

The double-precision floating-point computational instructions are
defined analogously to their single-precision counterparts, but operate
on double-precision operands and produce double-precision results.
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
```

```text
The accrued exception flags indicate the exception conditions that have
arisen on any floating-point arithmetic instruction since the field was
last reset by software, as shown in <<bitdef>>. The base
RISC-V ISA does not support generating a trap on the setting of a
floating-point exception flag.
(((floating-point, exception flag)))

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
```

### `src/d-st-ext.adoc`

```text
[[nanboxing]]
=== NaN Boxing of Narrower Values

When multiple floating-point precisions are supported, then valid values
of narrower _n_-bit types, _n_<FLEN, are represented in the lower _n_ bits of an FLEN-bit NaN value, in a process termed NaN-boxing. The upper bits of a valid NaN-boxed value must be all 1s. Valid NaN-boxed _n_-bit values
therefore appear as negative quiet NaNs (qNaNs) when viewed as any wider
_m_-bit value, _n_ < _m_ &#8804; FLEN. Any operation that writes a narrower result to an 'f' register must write all 1s to the uppermost FLEN-_n_ bits to yield a legal NaN-boxedvalue.
```

```text
Apart from transfer operations described in the previous paragraph, all
other floating-point operations on narrower __n__-bit
operations, _n_<FLEN, check if the input operands are
correctly NaN-boxed, i.e., all upper FLEN-_n_ bits are 1. If
so, the _n_ least-significant bits of the input are used as
the input value, otherwise the input value is treated as an
_n_-bit canonical NaN.
```

### `src/f-st-ext.adoc`

```text
=== NaN Generation and Propagation

Except when otherwise stated, if the result of a floating-point
operation is NaN, it is the canonical NaN. The canonical NaN has a
positive sign and all significand bits clear except the MSB, a.k.a. the
quiet bit. For single-precision floating-point, this corresponds to the pattern `0x7fc00000`.
```

## Additional requirement

Keep `io.resp.valid` and `io.resp.bits.fflags.valid` low for an operation from the cycle in which a misprediction in `io.brupdate` cancels it.
