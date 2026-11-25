# Implement `RoundAnyRawFNToRecFN`

Implement the complete `RoundAnyRawFNToRecFN` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Keep the declarations under Dependency declarations in the fixed source and do not resubmit them.

Return only the complete `class RoundAnyRawFNToRecFN` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package hardfloat

import Chisel._
import consts._
```

## Class declaration

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

## Parent instantiation

### `src/main/scala/RoundAnyRawFNToRecFN.scala`

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

    val roundAnyRawFNToRecFN =
        Module(
            new RoundAnyRawFNToRecFN(
                    expWidth, sigWidth + 2, expWidth, sigWidth, options))
    roundAnyRawFNToRecFN.io.invalidExc     := io.invalidExc
    roundAnyRawFNToRecFN.io.infiniteExc    := io.infiniteExc
    roundAnyRawFNToRecFN.io.in             := io.in
    roundAnyRawFNToRecFN.io.roundingMode   := io.roundingMode
    roundAnyRawFNToRecFN.io.detectTininess := io.detectTininess
    io.out            := roundAnyRawFNToRecFN.io.out
    io.exceptionFlags := roundAnyRawFNToRecFN.io.exceptionFlags
}
```

### `src/main/scala/INToRecFN.scala`

```scala
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

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val intAsRawFloat = rawFloatFromIN(io.signedIn, io.in);

    val roundAnyRawFNToRecFN =
        Module(
            new RoundAnyRawFNToRecFN(
                    intAsRawFloat.expWidth,
                    intWidth,
                    expWidth,
                    sigWidth,
                    flRoundOpt_sigMSBitAlwaysZero | flRoundOpt_neverUnderflows
                ))
    roundAnyRawFNToRecFN.io.invalidExc     := Bool(false)
    roundAnyRawFNToRecFN.io.infiniteExc    := Bool(false)
    roundAnyRawFNToRecFN.io.in             := intAsRawFloat
    roundAnyRawFNToRecFN.io.roundingMode   := io.roundingMode
    roundAnyRawFNToRecFN.io.detectTininess := io.detectTininess
    io.out            := roundAnyRawFNToRecFN.io.out
    io.exceptionFlags := roundAnyRawFNToRecFN.io.exceptionFlags
```

### `src/main/scala/RecFNToRecFN.scala`

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

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val rawIn = rawFloatFromRecFN(inExpWidth, inSigWidth, io.in);

    if ((inExpWidth == outExpWidth) && (inSigWidth <= outSigWidth)) {

        //--------------------------------------------------------------------
        //--------------------------------------------------------------------
        io.out            := io.in<<(outSigWidth - inSigWidth)
        io.exceptionFlags := Cat(isSigNaNRawFloat(rawIn), Bits(0, 4))

    } else {

        //--------------------------------------------------------------------
        //--------------------------------------------------------------------
        val roundAnyRawFNToRecFN =
            Module(
                new RoundAnyRawFNToRecFN(
                        inExpWidth,
                        inSigWidth,
                        outExpWidth,
                        outSigWidth,
                        flRoundOpt_sigMSBitAlwaysZero
                    ))
        roundAnyRawFNToRecFN.io.invalidExc     := isSigNaNRawFloat(rawIn)
        roundAnyRawFNToRecFN.io.infiniteExc    := Bool(false)
        roundAnyRawFNToRecFN.io.in             := rawIn
        roundAnyRawFNToRecFN.io.roundingMode   := io.roundingMode
        roundAnyRawFNToRecFN.io.detectTininess := io.detectTininess
        io.out            := roundAnyRawFNToRecFN.io.out
        io.exceptionFlags := roundAnyRawFNToRecFN.io.exceptionFlags
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
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    def flRoundOpt_sigMSBitAlwaysZero  = 1
    def flRoundOpt_subnormsAlwaysExact = 2
    def flRoundOpt_neverUnderflows     = 4
    def flRoundOpt_neverOverflows      = 8
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    def divSqrtOpt_twoBitsPerCycle     = 16
}

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

### `src/main/scala/primitives.scala`

```scala
package hardfloat

import Chisel._

//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
object lowMask
{
    def apply(in: UInt, topBound: BigInt, bottomBound: BigInt): UInt =
    {
        require(topBound != bottomBound)
        val numInVals = BigInt(1)<<in.getWidth
        if (topBound < bottomBound) {
            lowMask(~in, numInVals - 1 - topBound, numInVals - 1 - bottomBound)
        } else if (numInVals > 64 /* Empirical */) {
            // For simulation performance, we should avoid generating
            // exteremely wide shifters, so we divide and conquer.
            // Empirically, this does not impact synthesis QoR.
            val mid = numInVals / 2
            val msb = in(in.getWidth - 1)
            val lsbs = in(in.getWidth - 2, 0)
            if (mid < topBound) {
                if (mid <= bottomBound) {
                    Mux(msb,
                        lowMask(lsbs, topBound - mid, bottomBound - mid),
                        UInt(0)
                    )
                } else {
                    Mux(msb,
                        Cat(lowMask(lsbs, topBound - mid, 0),
                            UInt((BigInt(1)<<(mid - bottomBound).toInt) - 1)
                        ),
                        lowMask(lsbs, mid, bottomBound)
                    )
                }
            } else {
                ~Mux(msb, UInt(0), ~lowMask(lsbs, topBound, bottomBound))
            }
        } else {
            val shift = SInt(BigInt(-1)<<numInVals.toInt)>>in
            Reverse(
                shift(
                    (numInVals - 1 - bottomBound).toInt,
                    (numInVals - topBound).toInt
                )
            )
        }
    }
}
```

## Related source code

### `src/main/scala/tile/FPU.scala`

```scala
case class FType(exp: Int, sig: Int) {
  def ieeeWidth = exp + sig
  def recodedWidth = ieeeWidth + 1

  def ieeeQNaN = UInt((BigInt(1) << (ieeeWidth - 1)) - (BigInt(1) << (sig - 2)), ieeeWidth)
  def qNaN = UInt((BigInt(7) << (exp + sig - 3)) + (BigInt(1) << (sig - 2)), recodedWidth)
  def isNaN(x: UInt) = x(sig + exp - 1, sig + exp - 3).andR
  def isSNaN(x: UInt) = isNaN(x) && !x(sig - 2)
```

## Documentation

### `HardFloat-Verilog.html`

```html
<H3>5.2. Recoded Formats</H3>

<P>
For each standard format, HardFloat defines a corresponding
<I>recoded format</I> that encodes the same set of values in a slightly
different representation.
The recoded formats have sign, exponent, and significand fields just like the
standard formats, but with one extra bit for the exponent.
Hence, standard <NOBR>32-bit</NOBR> single-precision, for example, gets recoded
in <NOBR>33 bits</NOBR>:  one bit for the sign, 9 for the encoded exponent (one
more than usual), and 23 for the trailing significand.
The recoded formats simplify the implementation of floating-point arithmetic in
a few ways, the most important being to normalize subnormals so they can be
treated nearly the same as regular floating-point numbers.
</P>

<P>
The following table summarizes the recoding:
<BLOCKQUOTE>
<TABLE>
<TR>
<TD></TD>
<TD ROWSPAN=99 WIDTH=20></TD>
<TD COLSPAN=5>standard format</TD>
<TD ROWSPAN=99 WIDTH=25></TD>
<TD COLSPAN=4>HardFloat&rsquo;s recoded format</TD>
</TR>
<TR>
<TD></TD>
<TD>sign</TD>
<TD ROWSPAN=99> &nbsp; </TD>
<TD>exponent</TD>
<TD ROWSPAN=99> &nbsp; </TD>
<TD ALIGN=CENTER>significand</TD>
<TD>sign</TD>
<TD ROWSPAN=99> &nbsp; </TD>
<TD ALIGN=CENTER>exponent</TD>
<TD ALIGN=CENTER>significand</TD>
</TR>
<TR><TD></TD></TR>
<TR>
<TD>zeros</TD>
<TD ALIGN=CENTER><I>s</I></TD>
<TD ALIGN=CENTER>0</TD>
<TD ALIGN=CENTER>0</TD>
<TD ALIGN=CENTER><I>s</I></TD>
<TD ALIGN=CENTER><CODE>000</CODE><I>xx</I>...<I>xx</I></TD>
<TD ALIGN=CENTER>0</TD>
</TR>
<TR>
<TD>subnormal numbers</TD>
<TD ALIGN=CENTER><I>s</I></TD>
<TD ALIGN=CENTER>0</TD>
<TD ALIGN=CENTER><I>F</I></TD>
<TD ALIGN=CENTER><I>s</I></TD>
<TD ALIGN=CENTER>2<SUP><I>k</I></SUP> + 2 &minus; <I>n</I></TD>
<TD ALIGN=CENTER> &nbsp;&nbsp; normalized <I>F</I><CODE>&lt;&lt;</CODE><I>n</I></TD>
</TR>
<TR>
<TD>normal numbers</TD>
<TD ALIGN=CENTER><I>s</I></TD>
<TD ALIGN=CENTER><I>E</I></TD>
<TD ALIGN=CENTER><I>F</I></TD>
<TD ALIGN=CENTER><I>s</I></TD>
<TD ALIGN=CENTER><I>E</I> + 2<SUP><I>k</I></SUP> + 1</TD>
<TD ALIGN=CENTER><I>F</I></TD>
</TR>
<TR>
<TD>infinities</TD>
<TD ALIGN=CENTER><I>s</I></TD>
<TD ALIGN=CENTER><CODE>1111</CODE>...<CODE>11</CODE></TD>
<TD ALIGN=CENTER>0</TD>
<TD ALIGN=CENTER><I>s</I></TD>
<TD ALIGN=CENTER><CODE>110</CODE><I>xx</I>...<I>xx</I></TD>
<TD ALIGN=CENTER><I>xxxxxxx</I>...<I>xxxx</I></TD>
</TR>
<TR>
<TD>NaNs</TD>
<TD ALIGN=CENTER><I>s</I></TD>
<TD ALIGN=CENTER><CODE>1111</CODE>...<CODE>11</CODE></TD>
<TD ALIGN=CENTER><I>F</I></TD>
<TD ALIGN=CENTER><I>s</I></TD>
<TD ALIGN=CENTER><CODE>111</CODE><I>xx</I>...<I>xx</I></TD>
<TD ALIGN=CENTER><I>F</I></TD>
</TR>
</TABLE>
</BLOCKQUOTE>
<P>
The parameter <I>k</I> is <NOBR><CODE>expWidth</CODE> &minus; 1</NOBR>, where
<CODE>expWidth</CODE> is the <EM>standard width</EM> of the exponent field, not
the recoded width.
An <I>x</I> represents a &ldquo;don&rsquo;t care&rdquo; bit.
For the special values of zeros, infinities, and NaNs, only the three
most-significant bits are relevant in the recoded exponent field.
If those three bits are <CODE>000</CODE>, <CODE>110</CODE>, or
<CODE>111</CODE>, the floating-point value is a zero, infinity, or NaN,
respectively;
otherwise, the value is a normalized finite number.
In the latter case, if the recoded exponent field is
<NOBR>2<SUP><I>k</I></SUP> + 2</NOBR> or more, the value is a regular normal
number, and if it&rsquo;s less, the value is a normalized subnormal number.
(The notation &ldquo;normalized <I>F</I><CODE>&lt;&lt;</CODE><I>n</I>&rdquo;
means <I>F</I> normalized by shifting left by <NOBR><I>n</I> bits</NOBR> and
discarding the <NOBR>leading <CODE>1</CODE></NOBR>).
</P>

<P>
For most floating-point values (zeros, normal numbers, and NaNs) the only thing
different about the recoded formats is the encoding of the exponent;
the sign and significand fields are the same as the corresponding standard
format.
Infinities are special only in that the significand field is ignored in the
recoded formats and might not be zero.
Only for subnormals is there a significant transformation of both exponent and
significand fields, due to normalization.
</P>

<P>
A large number of possible bit patterns in the recoded formats don&rsquo;t
conform to entries in the table above, such as when the recoded
exponent&rsquo;s most-significant three bits are <CODE>000</CODE>, indicating a
zero, yet the significand field is not zero.
Such patterns are not valid.
If an invalid recoded input is given to a HardFloat module, all module outputs
are unspecified.
Invalid recoded results are never generated by HardFloat&rsquo;s modules, so
long as all module inputs are valid.
For normalized numbers (not zeros, infinities, or NaNs), a valid recoded
exponent field is always in the range
<NOBR>2<SUP><I>k</I></SUP> + 3 &minus; <CODE>sigWidth</CODE></NOBR> (for the
tiniest subnormal) to <NOBR>3&times;2<SUP><I>k</I></SUP> &minus; 1</NOBR> (for
the largest normal number).
</P>

<P>
In module names, a recoded format is abbreviated as
&lsquo;<CODE>recFN</CODE>&rsquo;.
Like the standard formats, a particular recoded format is specified by
parameters <CODE>expWidth</CODE> and <CODE>sigWidth</CODE>.
The parameters to give, however, are those of the <EM>corresponding standard
format</EM>, without adjustment for the wider recoded exponent field.
For example, the recoded format for common <NOBR>32-bit</NOBR> single-precision
is specified by <NOBR><CODE>expWidth</CODE> = 8</NOBR> and
<NOBR><CODE>sigWidth</CODE> = 24</NOBR>, the same as the standard format.
(Refer back to the previous subsection on the standard formats.)
Accordingly, the width of a recoded floating-point exponent field is really
<NOBR><CODE>expWidth</CODE> + 1</NOBR>, and the size in bits of the entire
recoded floating-point format is <CODE>expWidth</CODE> +
<NOBR><CODE>sigWidth</CODE> + 1</NOBR>.
</P>

<H3>5.3. Raw Deconstructions</H3>

<P>
Within the implementation of individual arithmetic operations (addition,
multiplication, etc.), HardFloat often represents floating-point values in a
deconstructed form, with six separate components:
<BLOCKQUOTE>
<DL>

<DT><CODE>isNaN</CODE></DT>
<DD>
A single bit indicating whether the floating-point value is a NaN.
If <CODE>isNaN</CODE> is <I>true</I> (<NOBR>= 1</NOBR>), the other components
are irrelevant except possibly for <CODE>sign</CODE> and <CODE>sig</CODE>.
Components <CODE>sign</CODE> and <CODE>sig</CODE> are relevant for a NaN only
if HardFloat is configured to propagate NaN payloads.
</DD>

<DT><CODE>isInf</CODE></DT>
<DD>
A single bit indicating whether the floating-point value is an infinity.
If <CODE>isNaN</CODE> is <I>false</I> and <CODE>isInf</CODE> is <I>true</I>,
the other components are irrelevant except for <CODE>sign</CODE>.
</DD>

<DT><CODE>isZero</CODE></DT>
<DD>
A single bit indicating whether the floating-point value is a zero.
If <CODE>isNaN</CODE> and <CODE>isInf</CODE> are both <I>false</I> and
<CODE>isZero</CODE> is <I>true</I>, the other components are irrelevant except
for <CODE>sign</CODE>.
</DD>

<DT><CODE>sign</CODE></DT>
<DD>
The floating-point sign bit.
Ignored only if <CODE>isNaN</CODE> is <I>true</I> and NaN payloads are not
propagated.
</DD>

<DT><CODE>sExp</CODE></DT>
<DD>
For a finite nonzero floating-point value, the biased floating-point exponent
as a signed integer.
For NaNs, infinities, and zeros, <CODE>sExp</CODE> is ignored.
As there are no special encodings of <CODE>sExp</CODE> to indicate special
values, <CODE>sExp</CODE> is always just a simple signed integer, with the same
bias as in the recoded formats.
For a specified <CODE>expWidth</CODE>, the actual width of <CODE>sExp</CODE> is
<NOBR><CODE>expWidth</CODE> + 2</NOBR>, giving it a range of
&minus;2<SUP><I>w</I>+1</SUP> to <NOBR>2<SUP><I>w</I>+1</SUP> &minus; 1</NOBR>,
where <NOBR><I>w</I> = <CODE>expWidth</CODE></NOBR> as usual.
</DD>

<DT><CODE>sig</CODE></DT>
<DD>
For a NaN, the NaN payload (sometimes ignored).
For a finite nonzero floating-point value, the complete significand, including
the usually implicit <NOBR><CODE>1</CODE> bit</NOBR>.
For a specified <CODE>sigWidth</CODE>, the width of <CODE>sig</CODE> is
<NOBR><CODE>sigWidth</CODE> + 1</NOBR>, with 2 extra bits at the
most-significant end when compared to the usual trailing significand of the
standard and recoded formats.
In some cases, these two bits are always binary <CODE>01</CODE>.
In other cases, the most-significant <CODE>1</CODE> bit of the significand can
be either of the two leading bits of <CODE>sig</CODE>, allowing for a
<NOBR>1-bit</NOBR> slack in the normalization of the significand.
A value of <CODE>sig</CODE> with the two most-significant bits both zeros
(<CODE>00</CODE>) is invalid (unless one of <CODE>isNaN</CODE>,
<CODE>isInf</CODE>, or <CODE>isZero</CODE> is <I>true</I>).
</DD>

</DL>
</BLOCKQUOTE>

<P>
Unlike the recoded formats, the deconstructed forms allow many valid encodings
that do not correspond directly to IEEE floating-point values.
These extra-precise and/or out-of-bounds values may be mapped to the set of
valid IEEE values by <EM>rounding</EM>, possibly resulting in underflow or
overflow.
</P>

...

<H3>6.2. Rounding Mode</H3>

<P>
The <CODE>roundingMode</CODE> input to a module chooses the rounding mode for a
floating-point operation (obviously).
All five rounding modes defined by the 2008 IEEE Floating-Point Standard are
implemented for all operations that require rounding.
HardFloat adds support also for a sixth mode, <I>round to odd</I>.
The value of <CODE>roundingMode</CODE> may be that of any of these macros
defined in <CODE>HardFloat_consts.vi</CODE>:
<BLOCKQUOTE>
<TABLE CELLSPACING=0 CELLPADDING=0>
<TR>
<TD><CODE>round_near_even</CODE></TD>
<TD>round to nearest, with ties to even</TD>
</TR>
<TR>
<TD><CODE>round_near_maxMag&nbsp;&nbsp;</CODE></TD>
<TD>round to nearest, with ties to maximum magnitude (away from zero)</TD>
</TR>
<TR>
<TD><CODE>round_minMag</CODE></TD>
<TD>round to minimum magnitude (toward zero)</TD>
</TR>
<TR>
<TD><CODE>round_min</CODE></TD>
<TD>round to minimum (down)</TD>
</TR>
<TR>
<TD><CODE>round_max</CODE></TD>
<TD>round to maximum (up)</TD>
</TR>
<TR>
<TD><CODE>round_odd</CODE></TD>
<TD>round to odd (jamming)</TD>
</TR>
</TABLE>
</BLOCKQUOTE>

<P>
Rounding mode <CODE>round_odd</CODE> operates as follows:
For a conversion to an integer, if the input is not already an integer value,
the rounded result is the closest <EM>odd</EM> integer.
For operations that return a floating-point value, the floating-point result is
first rounded to minimum magnitude, the same as <CODE>round_minMag</CODE>, and
then, if the result is inexact, the least-significant bit of the result is set
<NOBR>to <CODE>1</CODE></NOBR>.
Rounding to odd is also known as <EM>jamming</EM>.
</P>


<H2>7. Exception Results</H2>

<P>
HardFloat supports all five exception flags required by the IEEE Floating-Point
Standard.
Most modules for floating-point operations have an <CODE>exceptionFlags</CODE>
output with <NOBR>5 bits</NOBR> in this order:
<BLOCKQUOTE>
<CODE>{</CODE><I>invalid</I><CODE>, </CODE><I>infinite</I><CODE>,
    </CODE><I>overflow</I><CODE>, </CODE><I>underflow</I><CODE>,
    </CODE><I>inexact</I><CODE>}</CODE>
</BLOCKQUOTE>
<P>
The <I>infinite</I> exception is what the standard calls
&ldquo;divide by zero&rdquo;, meaning an infinite result generated from finite
operands.
</P>

...

<H3>10.3. <CODE>roundAnyRawFNToRecFN</CODE></H3>

<P>
Module <CODE>roundAnyRawFNToRecFN</CODE> takes an intermediate floating-point
value in deconstructed form and rounds it to a valid IEEE-conformant value in a
recoded format, applying the requested rounding mode and taking account of any
exceptional conditions such as underflow or overflow.

...

<P>
Parameters <CODE>inExpWidth</CODE> and <CODE>inSigWidth</CODE> characterize the
floating-point input to be rounded, while <CODE>outExpWidth</CODE> and
<CODE>outSigWidth</CODE> control the result format.
The <CODE>options</CODE> parameter is explained later below.

...

The <CODE>in_*</CODE> inputs obviously supply the incoming floating-point value
in deconstructed form.
Output <CODE>out</CODE> is the rounded IEEE floating-point value, in recoded
format, while <CODE>exceptionFlags</CODE> delivers the five floating-point
exception flags as documented in <NOBR>section 7</NOBR>,
<I>Exception Results</I>.
</P>

<P>
That leaves only inputs <CODE>invalidExc</CODE> and <CODE>infiniteExc</CODE>,
both Booleans.
If <CODE>invalidExc</CODE> is <I>true</I>, it forces an <I>invalid</I>
exception to be asserted, independent of the other inputs, so the
floating-point result delivered by <CODE>out</CODE> will be a NaN, and an
<I>invalid</I> exception will be indicated in <CODE>exceptionFlags</CODE>.
Similarly, <CODE>infiniteExc</CODE> asserts an <I>infinite</I> exception
(&ldquo;divide by zero&rdquo;) independent of most other inputs.
If <CODE>invalidExc</CODE> is <I>false</I> and <CODE>infiniteExc</CODE> is
<I>true</I>, the floating-point output will be an infinity with sign
<CODE>in_sign</CODE>, and an <I>infinite</I> exception will be indicated in
<CODE>exceptionFlags</CODE>.
</P>

<P>
When the floating-point input to <CODE>roundAnyRawFNToRecFN</CODE> is the
intermediate result of an operation, its precision typically needs to be at
least two bits greater than the output precision to avoid corrupting the result
value, i.e.,
<CODE>inSigWidth</CODE> &ge; <NOBR><CODE>outSigWidth</CODE> + 2</NOBR>.
In this case, the least-significant bit of the input is typically called the
<I>sticky</I> bit of the computation.
On the other hand, if the floating-point input is always an <EM>exact</EM>
value (such as from <CODE>iNToRawFN</CODE> or <CODE>recFNToRawFN</CODE>), then
no relationship between input and output formats is necessary.
</P>

<P>
Source file <CODE>HardFloat_consts.vi</CODE> defines several
&lsquo;<CODE>flRoundOpt_</CODE>&rsquo; macros to be used for the
<CODE>options</CODE> parameter, with the following meanings:
<BLOCKQUOTE>
<DL>

<DT><CODE>flRoundOpt_sigMSBitAlwaysZero</CODE></DT>
<DD>
For finite nonzero values, the two most-significant bits of <CODE>in_sig</CODE>
are always binary <CODE>01</CODE>.
</DD>

<DT><CODE>flRoundOpt_subnormsAlwaysExact</CODE></DT>
<DD>
Whenever the floating-point result is a subnormal, the result is always exact,
requiring no real rounding.
The <I>inexact</I> exception is therefore never indicated for subnormal
results.
(This case commonly arises with floating-point addition and subtraction.)
</DD>

<DT><CODE>flRoundOpt_neverUnderflows</CODE></DT>
<DD>
Underflow never occurs, because, for finite nonzero values, the floating-point
exponent is never below the normal range.
</DD>

<DT><CODE>flRoundOpt_neverOverflows</CODE></DT>
<DD>
Overflow never occurs, because, for finite nonzero values, the floating-point
exponent is never above the normal range.
</DD>

</DL>
</BLOCKQUOTE>
<P>
The <CODE>options</CODE> parameter can be set to the bitwise OR of any
combination of these macro values, or to 0, if none is applicable.
By setting <CODE>options</CODE> to the maximal set of conditions that apply,
the efficiency of the module may be improved.
</P>
```

### `berkeley-softfloat-3/doc/SoftFloat.html`

```html
<H3>6.2. Underflow Detection</H3>

<P>
In the terminology of the IEEE Standard, SoftFloat can detect tininess for
underflow either before or after rounding.
The choice is made by the global variable
<BLOCKQUOTE>
<CODE>uint_fast8_t softfloat_detectTininess;</CODE>
</BLOCKQUOTE>
which can be set to either
<BLOCKQUOTE>
<CODE>softfloat_tininess_beforeRounding</CODE><BR>
<CODE>softfloat_tininess_afterRounding</CODE>
</BLOCKQUOTE>
Detecting tininess after rounding is usually better because it results in fewer
spurious underflow signals.
The other option is provided for compatibility with some systems.
Like most systems (and as required by the newer 2008 IEEE Standard), SoftFloat
always detects loss of accuracy for underflow as an inexact result.
</P>
```

### `src/f-st-ext.adoc`

```text
=== NaN Generation and Propagation

Except when otherwise stated, if the result of a floating-point
operation is NaN, it is the canonical NaN. The canonical NaN has a
positive sign and all significand bits clear except the MSB, a.k.a. the
quiet bit. For single-precision floating-point, this corresponds to the pattern `0x7fc00000`.
```
