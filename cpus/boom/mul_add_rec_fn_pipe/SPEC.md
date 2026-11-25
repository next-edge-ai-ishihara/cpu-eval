# Implement `MulAddRecFNPipe`

Implement the complete `MulAddRecFNPipe` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class MulAddRecFNPipe` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package freechips.rocketchip.tile

import Chisel.{defaultCompileOptions => _, _}
// ...
import freechips.rocketchip.util._
```

## Class declaration

```scala
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
```

## Parent instantiation

```scala
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
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/MulAddRecFN.scala`

```scala
package hardfloat
// ...
class MulAddRecFN_interIo(expWidth: Int, sigWidth: Int) extends Bundle
{
//*** ENCODE SOME OF THESE CASES IN FEWER BITS?:
    val isSigNaNAny     = Bool()
    val isNaNAOrB       = Bool()
    val isInfA          = Bool()
    val isZeroA         = Bool()
    val isInfB          = Bool()
    val isZeroB         = Bool()
    val signProd        = Bool()
    val isNaNC          = Bool()
    val isInfC          = Bool()
    val isZeroC         = Bool()
    val sExpSum         = SInt(width = expWidth + 2)
    val doSubMags       = Bool()
    val CIsDominant     = Bool()
    val CDom_CAlignDist = UInt(width = log2Up(sigWidth + 1))
    val highAlignedSigC = UInt(width = sigWidth + 2)
    val bit0AlignedSigC = UInt(width = 1)

}
// ...
class MulAddRecFNToRaw_preMul(expWidth: Int, sigWidth: Int) extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val op = Bits(INPUT, 2)
        val a = Bits(INPUT, expWidth + sigWidth + 1)
        val b = Bits(INPUT, expWidth + sigWidth + 1)
        val c = Bits(INPUT, expWidth + sigWidth + 1)
        val mulAddA = UInt(OUTPUT, sigWidth)
        val mulAddB = UInt(OUTPUT, sigWidth)
        val mulAddC = UInt(OUTPUT, sigWidth * 2)
        val toPostMul = new MulAddRecFN_interIo(expWidth, sigWidth).asOutput
    })

// ...
class MulAddRecFNToRaw_postMul(expWidth: Int, sigWidth: Int) extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val fromPreMul = new MulAddRecFN_interIo(expWidth, sigWidth).asInput
        val mulAddResult = UInt(INPUT, sigWidth * 2 + 1)
        val roundingMode = UInt(INPUT, 3)
        val invalidExc  = Bool(OUTPUT)
        val rawOut = new RawFloat(expWidth, sigWidth + 2).asOutput
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
// ...
class RawFloat(val expWidth: Int, val sigWidth: Int) extends Bundle
{
    val isNaN  = Bool()              // overrides all other fields
    val isInf  = Bool()              // overrides 'isZero', 'sExp', and 'sig'
    val isZero = Bool()              // overrides 'sExp' and 'sig'
    val sign   = Bool()
    val sExp = SInt(width = expWidth + 2)
    val sig  = UInt(width = sigWidth + 1)   // 2 m.s. bits cannot both be 0

}
```

### `src/main/scala/RoundAnyRawFNToRecFN.scala`

```scala
package hardfloat
// ...
class
    RoundRawFNToRecFN(expWidth: Int, sigWidth: Int, options: Int)
    extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val invalidExc  = Bool(INPUT)   // overrides 'infiniteExc' and 'in'
        val infiniteExc = Bool(INPUT)   // overrides 'in' except for 'in.sign'
        val in = new RawFloat(expWidth, sigWidth + 2).asInput
        val roundingMode   = UInt(INPUT, 3)
        val detectTininess = UInt(INPUT, 1)
        val out = Bits(OUTPUT, expWidth + sigWidth + 1)
        val exceptionFlags = Bits(OUTPUT, 5)
    })
```

## Documentation

### `doc/divSqrtRecFN_small.txt`

```text
'exceptionFlags' is a bit vector of the exception flags, with this format:

    { invalid, infinity, overflow, underflow, inexact }
```

### `src/f-st-ext.adoc`

```text
FMADD.S multiplies the values in _rs1_ and _rs2_, adds the value in
_rs3_, and writes the final result to _rd_. FMADD.S computes
_(rs1latexmath:[$\times$]rs2)latexmath:[$\+$]rs3_.

FMSUB.S multiplies the values in _rs1_ and _rs2_, subtracts the value in _rs3_, and writes the final result to _rd_. FMSUB.S computes
_(rs1latexmath:[$\times$]rs2)latexmath:[$\-$]rs3_.

FNMSUB.S multiplies the values in _rs1_ and _rs2_, negates the product, adds the value in _rs3_, and writes the final result to _rd_. FNMSUB.S computes _-(rs1latexmath:[$\times$]rs2)latexmath:[$\+$]rs3_.

FNMADD.S multiplies the values in _rs1_ and _rs2_, negates the product, subtracts the value in _rs3_, and writes the final result to _rd_. FNMADD.S computes _-(rs1latexmath:[$\times$]rs2)latexmath:[$\-$]rs3_.
```
