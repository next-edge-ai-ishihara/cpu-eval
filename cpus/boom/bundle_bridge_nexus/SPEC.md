# Implement `BundleBridgeNexus`

Implement one complete `BundleBridgeNexus` source-level hardware definition. Preserve the definition name, constructor parameters, inheritance, and public node.

Return only the complete `class BundleBridgeNexus` definition in a single Scala code block, with no text outside the block. The companion object remains fixed.

## Package and imports

```scala
package freechips.rocketchip.diplomacy

import chisel3._
import chisel3.internal.sourceinfo.SourceInfo
import chisel3.experimental.{DataMirror,IO}
import chisel3.experimental.DataMirror.internal.chiselTypeClone
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.util.DataToAugmentedData
```

## Class declaration

```scala
class BundleBridgeNexus[T <: Data](
  inputFn: Seq[T] => T,
  outputFn: (T, Int) => Seq[T],
  default: Option[() => T] = None,
  inputRequiresOutput: Boolean = false,
  override val shouldBeInlined: Boolean = true
) (implicit p: Parameters) extends LazyModule
{
  val node = BundleBridgeNexusNode[T](default, inputRequiresOutput)
```

## Parent instantiation

### src/main/scala/subsystem/HasTiles.scala

```scala
  /** tileHartIdNexusNode is a BundleBridgeNexus that collects dynamic hart prefixes.
    *
    *   Each "prefix" input is actually the same full width as the outer hart id; the expected usage
    *   is that each prefix source would set only some non-overlapping portion of the bits to non-zero values.
    *   This node orReduces them, and further combines the reduction with the static ids assigned to each tile,
    *   producing a unique, dynamic hart id for each tile.
    *
    *   If p(InsertTimingClosureRegistersOnHartIds) is set, the input and output values are registered.
    *
    *   The output values are [[dontTouch]]'d to prevent constant propagation from pulling the values into
    *   the tiles if they are constant, which would ruin deduplication of tiles that are otherwise homogeneous.
    */
  val tileHartIdNexusNode = LazyModule(new BundleBridgeNexus[UInt](
    inputFn = BundleBridgeNexus.orReduction[UInt](registered = p(InsertTimingClosureRegistersOnHartIds)) _,
    outputFn = (prefix: UInt, n: Int) =>  Seq.tabulate(n) { i =>
      val y = dontTouch(prefix | hartIdList(i).U(p(MaxHartIdBits).W)) // dontTouch to keep constant prop from breaking tile dedup
      if (p(InsertTimingClosureRegistersOnHartIds)) BundleBridgeNexus.safeRegNext(y) else y
    },
    default = Some(() => 0.U(p(MaxHartIdBits).W)),
    inputRequiresOutput = true, // guard against this being driven but then ignored in tileHartIdIONodes below
    shouldBeInlined = false // can't inline something whose output we are are dontTouching
  )).node
```

### src/main/scala/tile/BaseTile.scala

```scala
  val mmioAddressPrefixNexusNode = BundleBridgeNexus[UInt](
    inputFn = BundleBridgeNexus.orReduction[UInt](registered = false) _,
    outputFn = BundleBridgeNexus.fillN[UInt](registered = false) _,
    default = Some(() => 0.U(1.W))
  )
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/diplomacy/BundleBridge.scala

```scala
case class BundleBridgeParams[T <: Data](genOpt: Option[() => T])

case object BundleBridgeParams {
  def apply[T <: Data](gen: () => T): BundleBridgeParams[T] = BundleBridgeParams(Some(gen))
}

case class BundleBridgeEdgeParams[T <: Data](source: BundleBridgeParams[T], sink: BundleBridgeParams[T])

class BundleBridgeImp[T <: Data]() extends SimpleNodeImp[BundleBridgeParams[T], BundleBridgeParams[T], BundleBridgeEdgeParams[T], T]
{
  def edge(pd: BundleBridgeParams[T], pu: BundleBridgeParams[T], p: Parameters, sourceInfo: SourceInfo) = BundleBridgeEdgeParams(pd, pu)
  def bundle(e: BundleBridgeEdgeParams[T]): T = {
    val sourceOpt = e.source.genOpt.map(_())
    val sinkOpt = e.sink.genOpt.map(_())
    (sourceOpt, sinkOpt) match {
      case (None,    None)    =>
        throw new Exception("BundleBridge needs source or sink to provide bundle generator function")
      case (Some(a), None)    => a
      case (None,    Some(b)) => b
      case (Some(a), Some(b)) => {
        require(DataMirror.checkTypeEquivalence(a, b),
          s"BundleBridge requires doubly-specified source and sink generators to have equivalent Chisel Data types, but got \n$a\n vs\n$b")
        a
      }
    }
  }
  def render(e: BundleBridgeEdgeParams[T]) = RenderedEdge(colour = "#cccc00" /* yellow */)
}
// ...
case class BundleBridgeNexusNode[T <: Data](default: Option[() => T] = None,
                                            inputRequiresOutput: Boolean = false) // when false, connecting a source does not mandate connecting a sink
                                           (implicit valName: ValName)
  extends NexusNode(new BundleBridgeImp[T])(
    dFn = seq => seq.headOption.getOrElse(BundleBridgeParams(default)),
    uFn = seq => seq.headOption.getOrElse(BundleBridgeParams(None)),
    inputRequiresOutput = inputRequiresOutput,
    outputRequiresInput = !default.isDefined)
// ...
object BundleBridgeNexus {
  def safeRegNext[T <: Data](x: T): T = {
    val reg = Reg(chiselTypeOf(x))
    reg := x
    reg
  }

  def requireOne[T <: Data](registered: Boolean)(seq: Seq[T]): T = {
    require(seq.size == 1, "BundleBroadcast default requires one input")
    if (registered) safeRegNext(seq.head) else seq.head
  }

  def orReduction[T <: Data](registered: Boolean)(seq: Seq[T]): T = {
    val x = seq.reduce((a,b) => (a.asUInt | b.asUInt).asTypeOf(seq.head))
    if (registered) safeRegNext(x) else x
  }

  def fillN[T <: Data](registered: Boolean)(x: T, n: Int): Seq[T] = Seq.fill(n) {
    if (registered) safeRegNext(x) else x
  }

  def apply[T <: Data](
    inputFn: Seq[T] => T = orReduction[T](false) _,
    outputFn: (T, Int) => Seq[T] = fillN[T](false) _,
    default: Option[() => T] = None,
    inputRequiresOutput: Boolean = false,
    shouldBeInlined: Boolean = true
  )(implicit p: Parameters): BundleBridgeNexusNode[T] = {
    val nexus = LazyModule(new BundleBridgeNexus[T](inputFn, outputFn, default, inputRequiresOutput, shouldBeInlined))
    nexus.node
  }
}
```

## Documentation

```text
diplomacy: refactor BundleBroadcast into BundleBridgeNexus
bundlebridge: default not included in inputs
bundlebridge: actually support inputRequiresOutput=false
bundlebridge: add output equivalence check to nexus
```

### docs/src/diplomacy/adder_tutorial.md

```text
Our adder node will take inputs from two `AdderDriverNode`s (the two addends)
and pass one output (the sum) into the monitor. Because the number of inputs and
outputs differ, we will make this node extend a `NexusNode`.

`dFn` maps **downward** parameters along **inward edges** into **downward**
parameters along **outward edges**. Similarly, `uFn` maps **upward**
parameters along **outward edges** into **upward** parameters along **inward
edges**.
...
### Creating the `LazyModule`s

"Lazy" evaluation refers to deferring the evaluation of an expression until
it is needed.

Parameter negotiation in Diplomacy is done lazily, after the Diplomacy graph
is created. Because of this, the concrete hardware that we want to parameterize
must also be generated lazily. Diplomacy provides the `LazyModule` construct for
writing lazily-evaluated hardware modules.

Let's use `LazyModule` to define our `Adder`. Notice that the creation of the
components used to define Diplomacy graph (in this case, the node), is non-lazy.
The desired hardware for the module must be written inside `LazyModuleImp`.

For this example, we expect our drivers to drive addends of equal bit widths
into the adder, meaning we expect all of our downward flowing parameters to be
equivalent. We also expect a single monitor, so all of our upward flowing
parameters should also be equivalent. Thus, we can require these properties in
our `AdderNode` and simply pass on downward the first `DownwardParam` we see.
Following the same logic, we can pass upward the first `UpwardParam` we see.
...
    node.out.head._1 := node.in.unzip._1.reduce(_ + _)
```

## Additional requirement

During elaboration, the class must throw `IllegalArgumentException` when the connected inputs do not all have equivalent Chisel types or when `outputFn` does not return, for each outgoing edge, exactly one value whose Chisel type is equivalent to that edge's type.
