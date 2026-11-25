# Implement `MaxPeriodFibonacciLFSR`

Implement the complete `MaxPeriodFibonacciLFSR` module. Preserve its constructor parameters. Return only the complete `class MaxPeriodFibonacciLFSR` definition in a single Scala code block, with no text outside the block.

## Package and imports

### `src/main/scala/chisel3/util/random/FibonacciLFSR.scala`

```scala
// SPDX-License-Identifier: Apache-2.0

package chisel3.util.random

import chisel3._
```

## Class declaration

```scala
class MaxPeriodFibonacciLFSR(width: Int, seed: Option[BigInt] = Some(1), reduction: LFSRReduce = XOR)
```

## Parent instantiation

### `src/main/scala/chisel3/util/random/FibonacciLFSR.scala`

```scala
object FibonacciLFSR {
// ...
  /** Return a pseudorandom [[UInt]] generated using a maximal period [[FibonacciLFSR]]
    * $paramWidth
    * $paramIncrement
    * $paramSeed
    * $paramReduction
    */
  def maxPeriod(
    width:     Int,
    increment: Bool = true.B,
    seed:      Option[BigInt] = Some(1),
    reduction: LFSRReduce = XOR
  ): UInt = PRNG(new MaxPeriodFibonacciLFSR(width, seed, reduction), increment)

}
```

### `src/main/scala/chisel3/util/random/PRNG.scala`

```scala
/** Helper utilities related to the construction of Pseudo Random Number Generators (PRNGs) */
object PRNG {

  /** Wrap a [[PRNG]] to only return a pseudo-random [[UInt]]
    * @param gen a pseudo random number generator
    * @param increment when asserted the [[PRNG]] will increment
    * @return the output (internal state) of the [[PRNG]]
    */
  def apply(gen: => PRNG, increment: Bool = true.B): UInt = {
    val prng = Module(gen)
    prng.io.seed.valid := false.B
    prng.io.seed.bits := DontCare
    prng.io.increment := increment
    prng.io.out.asUInt
  }

}
```

### `src/main/scala/ifu/icache.scala`

```scala
  val repl_way = if (isDM) 0.U else LFSR(16, refill_fire)(log2Ceil(nWays)-1,0)
```

### `src/main/scala/ifu/bpd/tage.scala`

```scala
case class BoomTageParams(
  //                                           nSets, histLen, tagSz
  tableInfo: Seq[Tuple3[Int, Int, Int]] = Seq((  128,       2,     7),
                                              (  128,       4,     7),
                                              (  256,       8,     8),
                                              (  256,      16,     8),
                                              (  128,      32,     9),
                                              (  128,      64,     9)),
  uBitPeriod: Int = 2048
)


class TageBranchPredictorBank(params: BoomTageParams = BoomTageParams())(implicit p: Parameters) extends BranchPredictorBank()(p)
{
  val tageUBitPeriod = params.uBitPeriod
  val tageNTables    = params.tableInfo.size
// ...
    val alloc_lfsr = random.LFSR(tageNTables max 2)
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/chisel3/util/random/PRNG.scala`

```scala
/** Pseudo Random Number Generators (PRNG) interface
  * @param n the width of the LFSR
  * @groupdesc Signals The actual hardware fields of the Bundle
  */
class PRNGIO(val n: Int) extends Bundle {

  /** A [[chisel3.util.Valid Valid]] interface that can be used to set the seed (internal PRNG state)
    * @group Signals
    */
  val seed: Valid[Vec[Bool]] = Input(Valid(Vec(n, Bool())))

  /** When asserted, the PRNG will increment by one
    * @group Signals
    */
  val increment: Bool = Input(Bool())

  /** The current state of the PRNG
    * @group Signals
    */
  val out: Vec[Bool] = Output(Vec(n, Bool()))
}

/** An abstract class representing a Pseudo Random Number Generator (PRNG)
  * @param width the width of the PRNG
  * @param seed the initial state of the PRNG
  * @param step the number of state updates per cycle
  * @param updateSeed if true, when loading the seed the state will be updated as if the seed were the current state, if
  * false, the state will be set to the seed
  */
abstract class PRNG(val width: Int, val seed: Option[BigInt], step: Int = 1, updateSeed: Boolean = false)
    extends Module {
  require(width > 0, s"Width must be greater than zero! (Found '$width')")
  require(step > 0, s"Step size must be greater than one! (Found '$step')")

  val io: PRNGIO = IO(new PRNGIO(width))

  /** Allow implementations to override the reset value, e.g., if some bits should be don't-cares. */
  protected def resetValue: Vec[Bool] = seed match {
    case Some(s) => VecInit(s.U(width.W).asBools)
    case None    => WireDefault(Vec(width, Bool()), DontCare)
  }

  /** Internal state of the PRNG. If the user sets a seed, this is initialized to the seed. If the user does not set a
    * seed this is left uninitialized. In the latter case, a PRNG subclass *must do something to handle lockup*, e.g.,
    * the PRNG state should be manually reset to a safe value. [[LFSR]] handles this by, based on the chosen reduction
    * operator, either sets or resets the least significant bit of the state.
    */
  private[random] val state: Vec[Bool] = RegInit(resetValue)

  /** State update function
    * @param s input state
    * @return the next state
    */
  def delta(s: Seq[Bool]): Seq[Bool]

  /** The method that will be used to update the state of this PRNG
    * @param s input state
    * @return the next state after `step` applications of [[PRNG.delta]]
    */
  final def nextState(s: Seq[Bool]): Seq[Bool] = (0 until step).foldLeft(s) { case (s, _) => delta(s) }

  when(io.increment) {
    state := nextState(state)
  }

  when(io.seed.fire) {
    state := (if (updateSeed) { nextState(io.seed.bits) }
              else { io.seed.bits })
  }

  io.out := state

}
```

### `src/main/scala/chisel3/util/random/FibonacciLFSR.scala`

```scala
/** Fibonacci Linear Feedback Shift Register (LFSR) generator.
  *
  * A Fibonacci LFSR can be generated by defining a width and a set of tap points (corresponding to a polynomial). An
  * optional initial seed and a reduction operation ([[XOR]], the default, or [[XNOR]]) can be used to augment the
  * generated hardware. The resulting hardware has support for a run-time programmable seed (via [[PRNGIO.seed]]) and
  * conditional increment (via [[PRNGIO.increment]]).
  * ...
  */
class FibonacciLFSR(
  width:         Int,
  taps:          Set[Int],
  seed:          Option[BigInt] = Some(1),
  val reduction: LFSRReduce = XOR,
  step:          Int = 1,
  updateSeed:    Boolean = false)
    extends PRNG(width, seed, step, updateSeed)
    with LFSR {

  def delta(s: Seq[Bool]): Seq[Bool] = taps.map { case i => s(i - 1) }.reduce(reduction) +: s.dropRight(1)

}
```

### `src/main/scala/chisel3/util/random/LFSR.scala`

```scala
/** A reduction operation for an LFSR.
  * @see [[XOR]]
  * @see [[XNOR]]
  */
sealed trait LFSRReduce extends ((Bool, Bool) => Bool)

/** XOR (exclusive or) reduction operation */
object XOR extends LFSRReduce {
  def apply(a: Bool, b: Bool): Bool = a ^ b
}

/** Not XOR (exclusive or) reduction operation */
object XNOR extends LFSRReduce {
  def apply(a: Bool, b: Bool): Bool = !(a ^ b)
}

/** Trait that defines a Linear Feedback Shift Register (LFSR).
  *
  * $seedExplanation
  * @see [[FibonacciLFSR]]
  * @see [[GaloisLFSR]]
  * @see [[https://en.wikipedia.org/wiki/Linear-feedback_shift_register]]
  *
  * @define paramWidth @param width the width of the LFSR
  * @define paramTaps @param taps a set of tap points to use when constructing the LFSR
  * @define paramSeed @param seed an initial value for internal LFSR state. If [[scala.None None]], then the LFSR
  * state LSB will be set to a known safe value on reset (to prevent lock up).
  * @define paramReduction @param reduction the reduction operation (either [[chisel3.util.random.XOR XOR]] or
  * [[chisel3.util.random.XNOR XNOR]])
  * @define paramStep @param step the number of state updates per cycle
  * @define paramUpdateSeed @param updateSeed if true, when loading the seed the state will be updated as if the seed
  * were the current state, if false, the state will be set to the seed
  * @define seedExplanation If the user specifies a seed, then a compile-time check is added that they are not
  * initializing the LFSR to a state which will cause it to lock up. If the user does not set a seed, then the least
  * significant bit of the state will be set or reset based on the choice of reduction operator.
  */
trait LFSR extends PRNG {

  /** The binary reduction operation used by this LFSR, either [[chisel3.util.random.XOR XOR]] or
    * [[chisel3.util.random.XNOR XNOR]]. This has the effect of mandating what seed is invalid.
    */
  def reduction: LFSRReduce

  override protected def resetValue: Vec[Bool] = seed match {
    case Some(s) =>
      reduction match {
        case XOR  => require(s != 0, "Seed cannot be zero")
        case XNOR => require(s != BigInt(2).pow(width) - 1, "Seed cannot be all ones (max value)")
      }
      super.resetValue

    case None => {
      val res = WireDefault(Vec(width, Bool()), DontCare)

      reduction match {
        case XOR  => res(0) := true.B
        case XNOR => res(0) := false.B
      }

      res
    }
  }
}
// ...
object LFSR {

  /** Return a pseudorandom [[UInt]] generated using a [[FibonacciLFSR]]. If you require a Galois LFSR, use
    * [[GaloisLFSR$.maxPeriod GaloisLFSR.maxPeriod]].
    * @param width the width of the LFSR
    * @param increment when asserted, the LFSR will increment
    * @param seed an initial seed (this cannot be zero)
    * @return a [[UInt]] that is the output of a maximal period LFSR of the requested width
    */
  def apply(width: Int, increment: Bool = true.B, seed: Option[BigInt] = Some(1)): UInt =
    FibonacciLFSR.maxPeriod(width, increment, seed, XOR)

  /** Utility used to report an unknown tap width */
  private[random] def badWidth(width: Int): Nothing = throw new IllegalArgumentException(
    s"No max period LFSR taps stored for requested width '$width'"
  )

  /** A mapping of widths to a sequence of known LFSR taps that produce a maximal period LFSR. These work for either a
    * [[chisel3.util.random.FibonacciLFSR Fibonacci LFSR]] or a [[chisel3.util.random.GaloisLFSR Galois LFSR]]. Taps are
    * available for bit widths of 2--786, 1024, 2048, and 4096.
    *
    * Users can automatically generate [[LFSR]]s using these taps with [[LFSR.apply]] for a maximum period Fibonacci XOR
    * LFSR or with [[MaxPeriodGaloisLFSR]]/[[GaloisLFSR.maxPeriod]] or
    * [[MaxPeriodFibonacciLFSR]]/[[FibonacciLFSR.maxPeriod]] for more configuration options.
    * @see [[http://courses.cse.tamu.edu/walker/csce680/lfsr_table.pdf]]
    * @see [[https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf]]
    */
  lazy val tapsMaxPeriod: Map[Int, Seq[Set[Int]]] = tapsFirst ++ tapsSecond

  /** First portion of known taps (a combined map hits the 64KB JVM method limit) */
  private def tapsFirst = Map(
// ...
    6 -> Seq(Set(6, 5), Set(6, 5, 3, 2)),
// ...
    16 -> Seq(Set(16, 14, 13, 11)),
// ...
```
