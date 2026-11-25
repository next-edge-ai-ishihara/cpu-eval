# Implement `DivSqrtRecF64ToRaw_mulAddZ31`

Implement one complete `DivSqrtRecF64ToRaw_mulAddZ31` source-level hardware definition for the BOOM `LargeBoomConfig` configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Return only the complete `class DivSqrtRecF64ToRaw_mulAddZ31` definition in a single Scala code block, with no text outside the block.

## Package and imports

### `src/main/scala/DivSqrtRecF64_mulAddZ31.scala`

```scala
package hardfloat

import Chisel._
import consts._
```

## Class declaration

```scala
class DivSqrtRecF64ToRaw_mulAddZ31(options: Int) extends Module
{
    val io = IO(new Bundle {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        val inReady_div    = Bool(OUTPUT)
        val inReady_sqrt   = Bool(OUTPUT)
        val inValid        = Bool(INPUT)
        val sqrtOp         = Bool(INPUT)
        val a              = Bits(INPUT, 65)
        val b              = Bits(INPUT, 65)
        val roundingMode   = UInt(INPUT, 3)
//*** OPTIONALLY PROPAGATE:
//        val detectTininess = UInt(INPUT, 1)
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        val usingMulAdd    = Bits(OUTPUT, 4)
        val latchMulAddA_0 = Bool(OUTPUT)
        val mulAddA_0      = UInt(OUTPUT, 54)
        val latchMulAddB_0 = Bool(OUTPUT)
        val mulAddB_0      = UInt(OUTPUT, 54)
        val mulAddC_2      = UInt(OUTPUT, 105)
        val mulAddResult_3 = UInt(INPUT, 105)
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        val rawOutValid_div  = Bool(OUTPUT)
        val rawOutValid_sqrt = Bool(OUTPUT)
        val roundingModeOut  = UInt(OUTPUT, 3)
        val invalidExc       = Bool(OUTPUT)
        val infiniteExc      = Bool(OUTPUT)
        val rawOut = new RawFloat(11, 55).asOutput
    })
    // ...
```

## Parent instantiation

### `src/main/scala/DivSqrtRecF64_mulAddZ31.scala`

```scala
class DivSqrtRecF64_mulAddZ31(options: Int) extends Module
    // ...
    val divSqrtRecF64ToRaw = Module(new DivSqrtRecF64ToRaw_mulAddZ31(options))

    io.inReady_div  := divSqrtRecF64ToRaw.io.inReady_div
    io.inReady_sqrt := divSqrtRecF64ToRaw.io.inReady_sqrt
    divSqrtRecF64ToRaw.io.inValid      := io.inValid
    divSqrtRecF64ToRaw.io.sqrtOp       := io.sqrtOp
    divSqrtRecF64ToRaw.io.a            := io.a
    divSqrtRecF64ToRaw.io.b            := io.b
    divSqrtRecF64ToRaw.io.roundingMode := io.roundingMode

    io.usingMulAdd    := divSqrtRecF64ToRaw.io.usingMulAdd
    io.latchMulAddA_0 := divSqrtRecF64ToRaw.io.latchMulAddA_0
    io.mulAddA_0      := divSqrtRecF64ToRaw.io.mulAddA_0
    io.latchMulAddB_0 := divSqrtRecF64ToRaw.io.latchMulAddB_0
    io.mulAddB_0      := divSqrtRecF64ToRaw.io.mulAddB_0
    io.mulAddC_2      := divSqrtRecF64ToRaw.io.mulAddC_2
    divSqrtRecF64ToRaw.io.mulAddResult_3 := io.mulAddResult_3

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    io.outValid_div  := divSqrtRecF64ToRaw.io.rawOutValid_div
    io.outValid_sqrt := divSqrtRecF64ToRaw.io.rawOutValid_sqrt

    val roundRawFNToRecFN =
        Module(new RoundRawFNToRecFN(11, 53, flRoundOpt_sigMSBitAlwaysZero))
    roundRawFNToRecFN.io.invalidExc   := divSqrtRecF64ToRaw.io.invalidExc
    roundRawFNToRecFN.io.infiniteExc  := divSqrtRecF64ToRaw.io.infiniteExc
    roundRawFNToRecFN.io.in           := divSqrtRecF64ToRaw.io.rawOut
    roundRawFNToRecFN.io.roundingMode := divSqrtRecF64ToRaw.io.roundingModeOut
    roundRawFNToRecFN.io.detectTininess := io.detectTininess
    io.out            := roundRawFNToRecFN.io.out
    io.exceptionFlags := roundRawFNToRecFN.io.exceptionFlags

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

## Related source code

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

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val sigMSBitAlwaysZero = ((options & flRoundOpt_sigMSBitAlwaysZero) != 0)
    val effectiveInSigWidth =
        if (sigMSBitAlwaysZero) inSigWidth else inSigWidth + 1
    val neverUnderflows =
        ((options &
              (flRoundOpt_neverUnderflows | flRoundOpt_subnormsAlwaysExact)
         ) != 0) ||
            (inExpWidth < outExpWidth)
    val neverOverflows =
        ((options & flRoundOpt_neverOverflows) != 0) ||
            (inExpWidth < outExpWidth)
    val outNaNExp = BigInt(7)<<(outExpWidth - 2)
    val outInfExp = BigInt(6)<<(outExpWidth - 2)
    val outMaxFiniteExp = outInfExp - 1
    val outMinNormExp = (BigInt(1)<<(outExpWidth - 1)) + 2
    val outMinNonzeroExp = outMinNormExp - outSigWidth + 1

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val roundingMode_near_even   = (io.roundingMode === round_near_even)
    val roundingMode_minMag      = (io.roundingMode === round_minMag)
    val roundingMode_min         = (io.roundingMode === round_min)
    val roundingMode_max         = (io.roundingMode === round_max)
    val roundingMode_near_maxMag = (io.roundingMode === round_near_maxMag)
    val roundingMode_odd         = (io.roundingMode === round_odd)

    val roundMagUp =
        (roundingMode_min && io.in.sign) || (roundingMode_max && ! io.in.sign)

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val sAdjustedExp =
        if (inExpWidth < outExpWidth)
            (io.in.sExp +&
                 SInt((BigInt(1)<<outExpWidth) - (BigInt(1)<<inExpWidth))
            )(outExpWidth, 0).zext
        else if (inExpWidth == outExpWidth)
            io.in.sExp
        else
            io.in.sExp +&
                SInt((BigInt(1)<<outExpWidth) - (BigInt(1)<<inExpWidth))
    val adjustedSig =
        if (inSigWidth <= outSigWidth + 2)
            io.in.sig<<(outSigWidth - inSigWidth + 2)
        else
            Cat(io.in.sig(inSigWidth, inSigWidth - outSigWidth - 1),
                io.in.sig(inSigWidth - outSigWidth - 2, 0).orR
            )
    val doShiftSigDown1 =
        if (sigMSBitAlwaysZero) Bool(false) else adjustedSig(outSigWidth + 2)

    val common_expOut   = Wire(UInt(width = outExpWidth + 1))
    val common_fractOut = Wire(UInt(width = outSigWidth - 1))
    val common_overflow       = Wire(Bool())
    val common_totalUnderflow = Wire(Bool())
    val common_underflow      = Wire(Bool())
    val common_inexact        = Wire(Bool())

    if (
        neverOverflows && neverUnderflows
            && (effectiveInSigWidth <= outSigWidth)
    ) {

        //--------------------------------------------------------------------
        //--------------------------------------------------------------------
        common_expOut := sAdjustedExp(outExpWidth, 0) + doShiftSigDown1
        common_fractOut :=
            Mux(doShiftSigDown1,
                adjustedSig(outSigWidth + 1, 3),
                adjustedSig(outSigWidth, 2)
            )
        common_overflow       := Bool(false)
        common_totalUnderflow := Bool(false)
        common_underflow      := Bool(false)
        common_inexact        := Bool(false)

    } else {

        //--------------------------------------------------------------------
        //--------------------------------------------------------------------
        val roundMask =
            if (neverUnderflows)
                Cat(UInt(0, outSigWidth), doShiftSigDown1, UInt(3, 2))
            else
                Cat(lowMask(
                        sAdjustedExp(outExpWidth, 0),
                        outMinNormExp - outSigWidth - 1,
                        outMinNormExp
                    ) | doShiftSigDown1,
                    UInt(3, 2)
                )
        val shiftedRoundMask = Cat(UInt(0, 1), roundMask>>1)
        val roundPosMask = ~shiftedRoundMask & roundMask
        val roundPosBit = (adjustedSig & roundPosMask).orR
        val anyRoundExtra = (adjustedSig & shiftedRoundMask).orR
        val anyRound = roundPosBit || anyRoundExtra

        val roundIncr =
            ((roundingMode_near_even || roundingMode_near_maxMag) &&
                 roundPosBit) ||
                (roundMagUp && anyRound)
        val roundedSig =
            Mux(roundIncr,
                (((adjustedSig | roundMask)>>2) +& UInt(1)) &
                    ~Mux(roundingMode_near_even && roundPosBit &&
                             ! anyRoundExtra,
                         roundMask>>1,
                         UInt(0, outSigWidth + 2)
                     ),
                (adjustedSig & ~roundMask)>>2 |
                    Mux(roundingMode_odd && anyRound, roundPosMask>>1, UInt(0))
            )
//*** IF SIG WIDTH IS VERY NARROW, NEED TO ACCOUNT FOR ROUND-EVEN ZEROING
//***  M.S. BIT OF SUBNORMAL SIG?
        val sRoundedExp = sAdjustedExp +& (roundedSig>>outSigWidth).zext

        common_expOut := sRoundedExp(outExpWidth, 0)
        common_fractOut :=
            Mux(doShiftSigDown1,
                roundedSig(outSigWidth - 1, 1),
                roundedSig(outSigWidth - 2, 0)
            )
        common_overflow :=
            (if (neverOverflows) Bool(false) else
//*** REWRITE BASED ON BEFORE-ROUNDING EXPONENT?:
                 (sRoundedExp>>(outExpWidth - 1) >= SInt(3)))
        common_totalUnderflow :=
            (if (neverUnderflows) Bool(false) else
//*** WOULD BE GOOD ENOUGH TO USE EXPONENT BEFORE ROUNDING?:
                 (sRoundedExp < SInt(outMinNonzeroExp)))

        val unboundedRange_roundPosBit =
            Mux(doShiftSigDown1, adjustedSig(2), adjustedSig(1))
        val unboundedRange_anyRound =
            (doShiftSigDown1 && adjustedSig(2)) || adjustedSig(1, 0).orR
        val unboundedRange_roundIncr =
            ((roundingMode_near_even || roundingMode_near_maxMag) &&
                 unboundedRange_roundPosBit) ||
                (roundMagUp && unboundedRange_anyRound)
        val roundCarry =
            Mux(doShiftSigDown1,
                roundedSig(outSigWidth + 1),
                roundedSig(outSigWidth)
            )
        common_underflow :=
            (if (neverUnderflows) Bool(false) else
                 common_totalUnderflow ||
//*** IF SIG WIDTH IS VERY NARROW, NEED TO ACCOUNT FOR ROUND-EVEN ZEROING
//***  M.S. BIT OF SUBNORMAL SIG?
                     (anyRound && (sAdjustedExp>>outExpWidth <= SInt(0)) &&
                          Mux(doShiftSigDown1, roundMask(3), roundMask(2)) &&
                          ! ((io.detectTininess === tininess_afterRounding) &&
                                 ! Mux(doShiftSigDown1,
                                       roundMask(4),
                                       roundMask(3)
                                   ) &&
                                 roundCarry && roundPosBit &&
                                 unboundedRange_roundIncr)))

        common_inexact := common_totalUnderflow || anyRound
    }

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val isNaNOut = io.invalidExc || io.in.isNaN
    val notNaN_isSpecialInfOut = io.infiniteExc || io.in.isInf
    val commonCase = ! isNaNOut && ! notNaN_isSpecialInfOut && ! io.in.isZero
    val overflow  = commonCase && common_overflow
    val underflow = commonCase && common_underflow
    val inexact = overflow || (commonCase && common_inexact)

    val overflow_roundMagUp =
        roundingMode_near_even || roundingMode_near_maxMag || roundMagUp
    val pegMinNonzeroMagOut =
        commonCase && common_totalUnderflow && (roundMagUp || roundingMode_odd)
    val pegMaxFiniteMagOut = overflow && ! overflow_roundMagUp
    val notNaN_isInfOut =
        notNaN_isSpecialInfOut || (overflow && overflow_roundMagUp)

    val signOut = Mux(isNaNOut, Bool(false), io.in.sign)
    val expOut =
        (common_expOut &
             ~Mux(io.in.isZero || common_totalUnderflow,
                  UInt(BigInt(7)<<(outExpWidth - 2), outExpWidth + 1),
                  UInt(0)
              ) &
             ~Mux(pegMinNonzeroMagOut,
                  ~UInt(outMinNonzeroExp, outExpWidth + 1),
                  UInt(0)
              ) &
             ~Mux(pegMaxFiniteMagOut,
                  UInt(BigInt(1)<<(outExpWidth - 1), outExpWidth + 1),
                  UInt(0)
              ) &
             ~Mux(notNaN_isInfOut,
                  UInt(BigInt(1)<<(outExpWidth - 2), outExpWidth + 1),
                  UInt(0)
              )) |
            Mux(pegMinNonzeroMagOut,
                UInt(outMinNonzeroExp, outExpWidth + 1),
                UInt(0)
            ) |
            Mux(pegMaxFiniteMagOut,
                UInt(outMaxFiniteExp, outExpWidth + 1),
                UInt(0)
            ) |
            Mux(notNaN_isInfOut, UInt(outInfExp, outExpWidth + 1), UInt(0)) |
            Mux(isNaNOut,        UInt(outNaNExp, outExpWidth + 1), UInt(0))
    val fractOut =
        Mux(isNaNOut || io.in.isZero || common_totalUnderflow,
            Mux(isNaNOut, UInt(BigInt(1)<<(outSigWidth - 2)), UInt(0)),
            common_fractOut
        ) |
        Fill(outSigWidth - 1, pegMaxFiniteMagOut)

    io.out := Cat(signOut, expOut, fractOut)
    io.exceptionFlags :=
        Cat(io.invalidExc, io.infiniteExc, overflow, underflow, inexact)
}

//----------------------------------------------------------------------------
//----------------------------------------------------------------------------

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

## Documentation

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

------------------------------------------------------------------------------
Interface to the outside multiplier-adder

An outside integer multiplier-adder is needed that can multiply two 54-bit
integer factors and add an additional 105-bit term to generate a 105-bit
integer result.  Because the large multiplier-adder is outside of this
division/square-root module, it can be shared for other purposes as needed.
The multiplier-adder must be fully pipelined with three cycles of latency,
detailed as follows:

It is assumed that the multiplication factors are held in registers just
preceding the multiplier-adder unit.  New values for these registers are
supplied by outputs `mulAddA_0' and `mulAddB_0'.  The value of `mulAddA_0'
must be latched into its corresponding register whenever output
`latchMulAddA_0' is asserted (= 1); and likewise for `mulAddB_0' and
`latchMulAddB_0'.

The outside multiplier-adder is not needed during every clock cycle that
a division or square root is being computed.  Bit vector `usingMulAdd'
indicates when the multiplier-adder is required, up to four clock cycles
in advance.  For any clock cycle T during which `usingMulAdd[0]' is 1,
if A and B are the values of the factor registers in cycle T + 1, and,
furthermore, if C is the value of output `mulAddC_2' in cycle T + 2, then
the 105-bit integer A * B + C must be returned in input `mulAddResult_3'
well before the end of cycle T + 3.

When the value of `usingMulAdd[0]' is 1, the A and B factor registers can
be latched only under the control of `latchMulAddA_0' and `latchMulAddB_0'.
(Be aware that `usingMulAdd[0]' may be 1 even when `latchMulAddA_0'
and `latchMulAddB_0' are both 0.)  On the other hand, in any cycle when
`usingMulAdd[0]' is 0, arbitrary new values may be freely latched into
either or both of the factor registers without regard for `latchMulAddA_0'
and `latchMulAddB_0', which will both be 0.  Thus, whenever `usingMulAdd[0]'
is 0, other uses can be made of the outside multiplier-adder, independent of
this module.
```
