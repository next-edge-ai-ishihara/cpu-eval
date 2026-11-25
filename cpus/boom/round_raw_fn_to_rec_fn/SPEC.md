# Implement `RoundRawFNToRecFN`

Implement the complete `RoundRawFNToRecFN` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Keep the declarations under Dependency declarations in the fixed source and do not resubmit them.

Return only the complete `class RoundRawFNToRecFN` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package hardfloat

import Chisel._
import consts._
```

## Class declaration

```scala
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

### `HardFloat-Verilog.html`

```html
<H3>10.4. <CODE>roundRawFNToRecFN</CODE></H3>

<P>
Module <CODE>roundRawFNToRecFN</CODE> is a variation on
<CODE>roundAnyRawFNToRecFN</CODE>, with the same set of ports but fewer
parameters:

...

<P>
<CODE>roundRawFNToRecFN</CODE> is identical to
<CODE>roundAnyRawFNToRecFN</CODE> with this assignment of parameters:
<BLOCKQUOTE>
<CODE>inExpWidth</CODE> = <CODE>expWidth</CODE><BR>
<CODE>inSigWidth</CODE> = <CODE>sigWidth</CODE> + 2<BR>
<CODE>outExpWidth</CODE> = <CODE>expWidth</CODE><BR>
<CODE>outSigWidth</CODE> = <CODE>sigWidth</CODE>
</BLOCKQUOTE>
<P>
Note that the deconstructed input has implicitly two more bits of precision
than the specified <CODE>sigWidth</CODE> would normally indicate.
</P>
```
