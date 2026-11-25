# Implement `CompareRecFN`

Implement one complete `CompareRecFN` source-level hardware definition for BOOM. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class CompareRecFN` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package hardfloat

import Chisel._
```

## Class declaration

```scala
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
```

## Parent instantiation

### src/main/scala/tile/FPU.scala

```scala
  val dcmp = Module(new hardfloat.CompareRecFN(maxExpWidth, maxSigWidth))
  dcmp.io.a := in.in1
  dcmp.io.b := in.in2
  dcmp.io.signaling := !in.rm(1)
// ...
  when (in.wflags) { // feq/flt/fle, fcvt
    toint := (~in.rm & Cat(dcmp.io.lt, dcmp.io.eq)).orR | (store >> minXLen << minXLen)
    io.out.bits.exc := dcmp.io.exceptionFlags
    intType := 0
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/common.scala

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

### src/main/scala/rawFloatFromRecFN.scala

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

## Documentation

### src/f-st-ext.adoc

```text
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
```

### src/d-st-ext.adoc

```text
=== Double-Precision Floating-Point Compare Instructions

The double-precision floating-point compare instructions are defined
analogously to their single-precision counterparts, but operate on
double-precision operands.
```

### src/images/wavedrom/float-csr.edn

```text
[wavedrom, ,svg]
....
{reg: [
  {bits: 1,  name: 'NX', attr: ['1']},
  {bits: 1,  name: 'UF', attr: ['1']},
  {bits: 1,  name: 'OF', attr: ['1']},
  {bits: 1,  name: 'DZ', attr: ['1']},
  {bits: 1,  name: 'NV', attr: ['1']},
  {bits: 3,  name: 'Rounding Mode', attr:['3']},
  {bits: 24, name: 'Reserved', attr:['24']},
], config: {fontsize: 10}}
....
```

### doc/divSqrtRecFN_small.txt

```text
'exceptionFlags' is a bit vector of the exception flags, with this format:

    { invalid, infinity, overflow, underflow, inexact }

(The "infinity" exception is also known as "divide-by-zero".)
```

### berkeley-softfloat-3/doc/SoftFloat.html

```text
<P>
For each format, the following floating-point comparison functions are
provided:
<BLOCKQUOTE>
<CODE>&lt;<I>float</I>&gt;_eq</CODE><BR>
<CODE>&lt;<I>float</I>&gt;_le</CODE><BR>
<CODE>&lt;<I>float</I>&gt;_lt</CODE>
</BLOCKQUOTE>
Each comparison takes two operands of the same type and returns a Boolean.
The abbreviation <CODE>eq</CODE> stands for &ldquo;equal&rdquo; (=);
<CODE>le</CODE> stands for &ldquo;less than or equal&rdquo; (&le;);
and <CODE>lt</CODE> stands for &ldquo;less than&rdquo; (&lt;).
...
The usual greater-than (&gt;), greater-than-or-equal (&ge;), and not-equal
(&ne;) comparisons are easily obtained from the functions provided.
The not-equal function is just the logical complement of the equal function.
The greater-than-or-equal function is identical to the less-than-or-equal
function with the arguments in reverse order, and likewise the greater-than
function is identical to the less-than function with the arguments reversed.
</P>
```
