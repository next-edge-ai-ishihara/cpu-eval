# Implement `RecFNToRecFN`

Implement the complete `RecFNToRecFN` module. Preserve its class declaration and public interface shown below. Return only the complete `class RecFNToRecFN` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package hardfloat

import Chisel._
import consts._
```

## Class declaration

```scala
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

## Parent instantiation

### `src/main/scala/tile/FPU.scala`

```scala
  when (in.bits.wflags && !in.bits.ren2) { // fcvt
    if (floatTypes.size > 1) {
      // widening conversions simply canonicalize NaN operands
      val widened = Mux(maxType.isNaN(in.bits.in1), maxType.qNaN, in.bits.in1)
      fsgnjMux.data := widened
      fsgnjMux.exc := maxType.isSNaN(in.bits.in1) << 4

      // narrowing conversions require rounding (for RVQ, this could be
      // optimized to use a single variable-position rounding unit, rather
      // than two fixed-position ones)
      for (outType <- floatTypes.init) when (outTag === typeTag(outType) && (typeTag(outType) == 0 || outTag < inTag)) {
        val narrower = Module(new hardfloat.RecFNToRecFN(maxType.exp, maxType.sig, outType.exp, outType.sig))
        narrower.io.in := in.bits.in1
        narrower.io.roundingMode := in.bits.rm
        narrower.io.detectTininess := hardfloat.consts.tininess_afterRounding
        val narrowed = sanitizeNaN(narrower.io.out, outType)
        mux.data := Cat(fsgnjMux.data >> narrowed.getWidth, narrowed)
        mux.exc := narrower.io.exceptionFlags
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

### `src/main/scala/common.scala`

```scala
class RawFloat(val expWidth: Int, val sigWidth: Int) extends Bundle
{
    val isNaN  = Bool()              // overrides all other fields
    val isInf  = Bool()              // overrides 'isZero', 'sExp', and 'sig'
    val isZero = Bool()              // overrides 'sExp' and 'sig'
    val sign   = Bool()
    val sExp = SInt(width = expWidth + 2)
    val sig  = UInt(width = sigWidth + 1)   // 2 m.s. bits cannot both be 0

}

//*** CHANGE THIS INTO A '.isSigNaN' METHOD OF THE 'RawFloat' CLASS:
object isSigNaNRawFloat
{
    def apply(in: RawFloat): Bool = in.isNaN && !in.sig(in.sigWidth - 2)
}

```

### `src/main/scala/rawFloatFromRecFN.scala`

```scala
/*----------------------------------------------------------------------------
| In the result, no more than one of 'isNaN', 'isInf', and 'isZero' will be
| set.
*----------------------------------------------------------------------------*/
object rawFloatFromRecFN
{
    def apply(expWidth: Int, sigWidth: Int, in: Bits): RawFloat =
    {
        val exp = in(expWidth + sigWidth - 1, sigWidth - 1)
        val isZero    = (exp(expWidth, expWidth - 2) === UInt(0))
        val isSpecial = (exp(expWidth, expWidth - 1) === UInt(3))

        val out = Wire(new RawFloat(expWidth, sigWidth))
        out.isNaN  := isSpecial &&   exp(expWidth - 2)
        out.isInf  := isSpecial && ! exp(expWidth - 2)
        out.isZero := isZero
        out.sign   := in(expWidth + sigWidth)
        out.sExp   := exp.zext
        out.sig    := Cat(UInt(0, 1), ! isZero, in(sigWidth - 2, 0))
        out
    }
}
```

### `src/main/scala/RoundAnyRawFNToRecFN.scala`

```scala
class
    RoundAnyRawFNToRecFN(
        inExpWidth: Int,
        inSigWidth: Int,
        outExpWidth: Int,
        outSigWidth: Int,
        options: Int
    )
    extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val invalidExc  = Bool(INPUT)   // overrides 'infiniteExc' and 'in'
        val infiniteExc = Bool(INPUT)   // overrides 'in' except for 'in.sign'
        val in = new RawFloat(inExpWidth, inSigWidth).asInput
                                        // (allowed exponent range has limits)
        val roundingMode   = UInt(INPUT, 3)
        val detectTininess = UInt(INPUT, 1)
        val out = Bits(OUTPUT, outExpWidth + outSigWidth + 1)
        val exceptionFlags = Bits(OUTPUT, 5)
    })
```

## Documentation

### `src/d-st-ext.adoc`

```text
The double-precision to single-precision and single-precision to
double-precision conversion instructions, FCVT.S.D and FCVT.D.S, are
encoded in the OP-FP major opcode space and both the source and
destination are floating-point registers. The _rs2_ field encodes the
datatype of the source, and the _fmt_ field encodes the datatype of the
destination. FCVT.S.D rounds according to the RM field; FCVT.D.S will
never round.
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
=== NaN Generation and Propagation

Except when otherwise stated, if the result of a floating-point
operation is NaN, it is the canonical NaN. The canonical NaN has a
positive sign and all significand bits clear except the MSB, a.k.a. the
quiet bit. For single-precision floating-point, this corresponds to the pattern `0x7fc00000`.
...
=== Subnormal Arithmetic

Operations on subnormal numbers are handled in accordance with the IEEE 754-2008 standard.
(((operations, subnormal)))

In the parlance of the IEEE standard, tininess is detected after
rounding.
```
