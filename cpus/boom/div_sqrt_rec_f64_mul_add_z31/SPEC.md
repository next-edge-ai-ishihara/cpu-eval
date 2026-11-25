# Implement `DivSqrtRecF64_mulAddZ31`

Implement one complete `DivSqrtRecF64_mulAddZ31` source-level hardware definition for the BOOM `LargeBoomConfig` configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Return only the complete `class DivSqrtRecF64_mulAddZ31` definition in a single Scala code block, with no text outside the block.

## Package and imports

### `src/main/scala/DivSqrtRecF64_mulAddZ31.scala`

```scala
package hardfloat

import Chisel._
import consts._
```

## Class declaration

```scala
class DivSqrtRecF64_mulAddZ31(options: Int) extends Module
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
        val detectTininess = UInt(INPUT, 1)
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
        val outValid_div   = Bool(OUTPUT)
        val outValid_sqrt  = Bool(OUTPUT)
        val out            = Bits(OUTPUT, 65)
        val exceptionFlags = Bits(OUTPUT, 5)
    })
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

### `src/main/scala/DivSqrtRecF64_mulAddZ31.scala`

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
    // ...
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

The other three bits of `usingMulAdd' show the future value of
`usingMulAdd[0]' up to three cycles in advance.  `usingMulAdd[1]' shows
the future value of `usingMulAdd[0]' one cycle in advance; `usingMulAdd[2]'
shows it two cycles in advance; and `usingMulAdd[3]' shows it three cycles
in advance.
```
