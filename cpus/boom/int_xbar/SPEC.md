# Implement `IntXbar`

Implement the complete `IntXbar` module. Keep its constructor, inheritance and public node `intnode`. Return only the complete `class IntXbar` definition in a single Scala code block, with no text outside the block.

## Package and imports

### `src/main/scala/interrupts/Xbar.scala`

```scala
// See LICENSE.SiFive for license details.

package freechips.rocketchip.interrupts

import Chisel._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._
```

## Class declaration

```scala
class IntXbar()(implicit p: Parameters) extends LazyModule
{
```

## Parent instantiation

### `src/main/scala/interrupts/Xbar.scala`

```scala
object IntXbar {
  def apply(implicit p: Parameters): IntNode = {
    val xbar = LazyModule(new IntXbar)
    xbar.intnode
  }
}
```

### `src/main/scala/subsystem/InterruptBus.scala`

```scala
class InterruptBusWrapper(implicit p: Parameters) extends ClockSinkDomain {
  override def shouldBeInlined = true
  val int_bus = LazyModule(new IntXbar)   // Interrupt crossbar
  private val int_in_xing  = this.crossIn(int_bus.intnode)
  private val int_out_xing = this.crossOut(int_bus.intnode)
  def from(name: Option[String])(xing: ClockCrossingType) = int_in_xing(xing) :=* IntNameNode(name)
  def to(name: Option[String])(xing: ClockCrossingType) = IntNameNode(name) :*= int_out_xing(xing)
  def fromAsync: IntInwardNode = from(None)(AsynchronousCrossing(8,3))
  def fromRational: IntInwardNode = from(None)(RationalCrossing())
  def fromSync: IntInwardNode = int_bus.intnode
  def toPLIC: IntOutwardNode = int_bus.intnode
}
```

### `src/main/scala/tile/Interrupts.scala`

```scala
// Use diplomatic interrupts to external interrupts from the subsystem into the tile
trait SinksExternalInterrupts { this: BaseTile =>

  val intInwardNode = intXbar.intnode :=* IntIdentityNode()(ValName("int_local"))
  protected val intSinkNode = IntSinkNode(IntSinkPortSimple())
  intSinkNode := intXbar.intnode
// ...
```

### `src/main/scala/tile/BaseTile.scala`

```scala
  protected val intXbar = LazyModule(new IntXbar)
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/interrupts/Parameters.scala`

```scala
// A potentially empty half-open range; [start, end)
case class IntRange(start: Int, end: Int)
{
  require (start >= 0)
  require (start <= end)
  def size = end - start
  def overlaps(x: IntRange) = start < x.end && x.start < end
  def offset(x: Int) = IntRange(x+start, x+end)
}

object IntRange
{
  implicit def apply(end: Int): IntRange = apply(0, end)
}

case class IntSourceParameters(
  range:     IntRange,
  resources: Seq[Resource] = Seq(),
  nodePath:  Seq[BaseNode] = Seq())
{
  val name = nodePath.lastOption.map(_.lazyModule.name).getOrElse("disconnected")
}

case class IntSinkParameters(
  nodePath:  Seq[BaseNode] = Seq())
{
  val name = nodePath.lastOption.map(_.lazyModule.name).getOrElse("disconnected")
}

case class IntSourcePortParameters(sources: Seq[IntSourceParameters])
{
  val num = sources.map(_.range.size).sum
  // The interrupts mapping must not overlap
  sources.map(_.range).combinations(2).foreach { case Seq(a, b) => require (!a.overlaps(b)) }
  // The interrupts must perfectly cover the range
  require (sources.isEmpty || sources.map(_.range.end).max == num)
}
// ...
case class IntSinkPortParameters(sinks: Seq[IntSinkParameters])
object IntSinkPortSimple
{
  def apply(ports: Int = 1, sinks: Int = 1) =
    Seq.fill(ports)(IntSinkPortParameters(Seq.fill(sinks)(IntSinkParameters())))
}

case class IntEdge(source: IntSourcePortParameters, sink: IntSinkPortParameters, params: Parameters, sourceInfo: SourceInfo)
```

### `src/main/scala/interrupts/Nodes.scala`

```scala
object IntImp extends SimpleNodeImp[IntSourcePortParameters, IntSinkPortParameters, IntEdge, Vec[Bool]]
{
  def edge(pd: IntSourcePortParameters, pu: IntSinkPortParameters, p: Parameters, sourceInfo: SourceInfo) = IntEdge(pd, pu, p, sourceInfo)
  def bundle(e: IntEdge) = Vec(e.source.num, Bool())
  def render(e: IntEdge) = RenderedEdge(colour = "#0000ff" /* blue */, label = e.source.sources.map(_.range.size).sum.toString, flipped = true)

  override def mixO(pd: IntSourcePortParameters, node: OutwardNode[IntSourcePortParameters, IntSinkPortParameters, Vec[Bool]]): IntSourcePortParameters =
   pd.copy(sources = pd.sources.map  { s => s.copy (nodePath = node +: s.nodePath) })
  override def mixI(pu: IntSinkPortParameters, node: InwardNode[IntSourcePortParameters, IntSinkPortParameters, Vec[Bool]]): IntSinkPortParameters =
   pu.copy(sinks   = pu.sinks.map    { s => s.copy (nodePath = node +: s.nodePath) })
}
// ...
case class IntNexusNode(
  sourceFn:       Seq[IntSourcePortParameters] => IntSourcePortParameters,
  sinkFn:         Seq[IntSinkPortParameters]   => IntSinkPortParameters,
  inputRequiresOutput: Boolean = true,
  outputRequiresInput: Boolean = true)(
  implicit valName: ValName)
  extends NexusNode(IntImp)(sourceFn, sinkFn, inputRequiresOutput, outputRequiresInput) with IntFormatNode
```

### `src/main/scala/interrupts/package.scala`

```scala
package object interrupts
{
  type IntInwardNode = InwardNodeHandle[IntSourcePortParameters, IntSinkPortParameters, IntEdge, Vec[Bool]]
  type IntOutwardNode = OutwardNodeHandle[IntSourcePortParameters, IntSinkPortParameters, IntEdge, Vec[Bool]]
  type IntNode = SimpleNodeHandle[IntSourcePortParameters, IntSinkPortParameters, IntEdge, Vec[Bool]]

// ...
```

### `src/main/scala/diplomacy/LazyModule.scala`

```scala
  /** [[chisel3]] hardware implementation of this [[LazyModule]].
    *
    * Subclasses should define this function as `lazy val`s for lazy evaluation.
    * Generally, the evaluation of this marks the beginning of phase 2.
    */
  def module: LazyModuleImpLike
```

### `src/main/scala/diplomacy/Nodes.scala`

```scala
  def out: Seq[(BO, EO)] = {
    require(instantiated, s"$name.out should not be called until after instantiation of its parent LazyModule.module has begun")
    bundleOut zip edgesOut
  }

  /** Gather Bundle and edge parameters of inward ports.
    *
    * Accessors to the result of negotiation to be used within
    * [[LazyModuleImp]] Code. Should only be used within [[LazyModuleImp]] code
    * or after its instantiation has completed.
    */
  def in: Seq[(BI, EI)] = {
    require(instantiated, s"$name.in should not be called until after instantiation of its parent LazyModule.module has begun")
    bundleIn zip edgesIn
  }
```

## Additional requirement

Each connected output must carry the interrupt bits of all inputs concatenated in input-port order, and each source in the output's `IntSourcePortParameters` must keep its `resources` and `nodePath` and have its `range` offset by the sum of `num` over the preceding inputs.
