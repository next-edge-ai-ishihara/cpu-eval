# Implement `Mul54`

Implement the complete `Mul54` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class Mul54` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package hardfloat

import Chisel._
```

## Class declaration

```scala
class Mul54 extends Module
{
    val io = IO(new Bundle {
        val val_s0 = Bool(INPUT)
        val latch_a_s0 = Bool(INPUT)
        val a_s0 = UInt(INPUT, 54)
        val latch_b_s0 = Bool(INPUT)
        val b_s0 = UInt(INPUT, 54)
        val c_s2 = UInt(INPUT, 105)
        val result_s3 = UInt(OUTPUT, 105)
    })
```

## Parent instantiation

```scala
    val mul = Module(new Mul54)

    mul.io.val_s0     := ds.io.usingMulAdd(0)
    mul.io.latch_a_s0 := ds.io.latchMulAddA_0
    mul.io.a_s0       := ds.io.mulAddA_0
    mul.io.latch_b_s0 := ds.io.latchMulAddB_0
    mul.io.b_s0       := ds.io.mulAddB_0
    mul.io.c_s2       := ds.io.mulAddC_2
    ds.io.mulAddResult_3 := mul.io.result_s3
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

## Documentation

### `doc/divSqrtRecodedFloat64_mulAddZ31.txt`

```text
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
```
