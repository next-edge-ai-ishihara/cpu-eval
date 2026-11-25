# Implement `Arbiter`

Implement one complete `Arbiter` source-level hardware definition for BOOM. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class Arbiter` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package chisel3.util

import chisel3._
import chisel3.internal.naming.chiselName // can't use chisel3_ version because of compile order
```

## Class declaration

```scala
@chiselName
class Arbiter[T <: Data](val gen: T, val n: Int) extends Module {
  val io = IO(new ArbiterIO(gen, n))
```

## Parent instantiation

### src/main/scala/exu/fp-pipeline.scala

```scala
  val ll_wbarb = Module(new Arbiter(new ExeUnitResp(fLen+1), 2))


  // Hookup load writeback -- and recode FP values.
  ll_wbarb.io.in(0) <> io.ll_wports(0)
  ll_wbarb.io.in(0).bits.data := recode(io.ll_wports(0).bits.data,
                                        io.ll_wports(0).bits.uop.mem_size =/= 2.U)

  val ifpu_resp = io.from_int
  ll_wbarb.io.in(1) <> ifpu_resp


  // Cut up critical path by delaying the write by a cycle.
  // Wakeup signal is sent on cycle S0, write is now delayed until end of S1,
  // but Issue happens on S1 and RegRead doesn't happen until S2 so we're safe.
  fregfile.io.write_ports(0) := RegNext(WritePort(ll_wbarb.io.out, fpregSz, fLen+1, RT_FLT))

  assert (ll_wbarb.io.in(0).ready) // never backpressure the memory unit.
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/chisel3/util/Arbiter.scala

```scala
/** IO bundle definition for an Arbiter, which takes some number of ready-valid inputs and outputs
  * (selects) at most one.
  * @groupdesc Signals The actual hardware fields of the Bundle
  *
  * @param gen data type
  * @param n number of inputs
  */
class ArbiterIO[T <: Data](private val gen: T, val n: Int) extends Bundle {
  // See github.com/freechipsproject/chisel3/issues/765 for why gen is a private val and proposed replacement APIs.

  /** Input data, one per potential sender
    *
    * @group Signals
    */
  val in = Flipped(Vec(n, Decoupled(gen)))

  /** Output data after arbitration
    *
    * @group Signals
    */
  val out = Decoupled(gen)

  /** One-Hot vector indicating which output was chosen
    *
    * @group Signals
    */
  val chosen = Output(UInt(log2Ceil(n).W))
}

/** Arbiter Control determining which producer has access
  */
private object ArbiterCtrl {
  def apply(request: Seq[Bool]): Seq[Bool] = request.length match {
    case 0 => Seq()
    case 1 => Seq(true.B)
    case _ => true.B +: request.tail.init.scanLeft(request.head)(_ || _).map(!_)
  }
}
```

### src/main/scala/chisel3/util/Decoupled.scala

```scala
/** A concrete subclass of ReadyValidIO signaling that the user expects a
  * "decoupled" interface: 'valid' indicates that the producer has
  * put valid data in 'bits', and 'ready' indicates that the consumer is ready
  * to accept the data this cycle. No requirements are placed on the signaling
  * of ready or valid.
  * @param gen the type of data to be wrapped in DecoupledIO
  */
class DecoupledIO[+T <: Data](gen: T) extends ReadyValidIO[T](gen)
```
