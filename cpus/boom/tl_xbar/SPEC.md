# Implement `TLXbar`

Implement the complete `TLXbar` module. Preserve its class declaration shown below. Keep its public `node` member as its TileLink nexus node. Return only the complete `class TLXbar` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
// See LICENSE.SiFive for license details.

package freechips.rocketchip.tilelink

import chisel3._
import chisel3.util._
import freechips.rocketchip.config.{Field, Parameters}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.util._
```

## Class declaration

```scala
class TLXbar(policy: TLArbiter.Policy = TLArbiter.roundRobin)(implicit p: Parameters) extends LazyModule
{
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/tilelink/Nodes.scala`

```scala
case class TLNexusNode(
  clientFn:        Seq[TLMasterPortParameters] => TLMasterPortParameters,
  managerFn:       Seq[TLSlavePortParameters]  => TLSlavePortParameters)(
  implicit valName: ValName)
  extends NexusNode(TLImp)(clientFn, managerFn) with TLFormatNode
```

### `src/main/scala/diplomacy/Nodes.scala`

```scala
/** [[MixedNexusNode]] is used when the number of nodes connecting from either side is unknown (e.g. a Crossbar which also is a protocol adapter).
  *
  * The [[NodeImp]] is different between [[inner]] and [[outer]],
  *
  * @param dFn                 Function for mapping the parameters flowing downward into new outward flowing down parameters.
  * @param uFn                 Function for mapping the parameters flowing upward into new inward flowing up parameters.
  * @param inputRequiresOutput True if it is required that if there are input connections, there are output connections (this node can't just be a sink).
  * @param outputRequiresInput True if it is required that if there are output connections, there are input connections (this node can't just be a source).
  */
// ...
/** [[NexusNode]] is a [[MixedNexusNode]], in which the inward and outward side of the node have the same [[NodeImp]] implementation. */
class NexusNode[D, U, EO, EI, B <: Data](imp: NodeImp[D, U, EO, EI, B])(
  dFn: Seq[D] => D,
  uFn: Seq[U] => U,
  inputRequiresOutput: Boolean = true,
  outputRequiresInput: Boolean = true)(
  implicit valName: ValName)
    extends MixedNexusNode[D, U, EI, B, D, U, EO, B](imp, imp)(dFn, uFn, inputRequiresOutput, outputRequiresInput)
```

### `src/main/scala/tilelink/Parameters.scala`

```scala
class TLSlaveParameters private(
  val nodePath:           Seq[BaseNode],
  val resources:          Seq[Resource],
  setName:                Option[String],
  val address:            Seq[AddressSet],
  val regionType:         RegionType.T,
  val executable:         Boolean,
  val fifoId:             Option[Int],
// ...
  def v1copy(
    address:            Seq[AddressSet] = address,
    resources:          Seq[Resource]   = resources,
    regionType:         RegionType.T    = regionType,
    executable:         Boolean         = executable,
    nodePath:           Seq[BaseNode]   = nodePath,
    supportsAcquireT:   TransferSizes   = supports.acquireT,
    supportsAcquireB:   TransferSizes   = supports.acquireB,
    supportsArithmetic: TransferSizes   = supports.arithmetic,
    supportsLogical:    TransferSizes   = supports.logical,
    supportsGet:        TransferSizes   = supports.get,
    supportsPutFull:    TransferSizes   = supports.putFull,
    supportsPutPartial: TransferSizes   = supports.putPartial,
    supportsHint:       TransferSizes   = supports.hint,
    mayDenyGet:         Boolean         = mayDenyGet,
    mayDenyPut:         Boolean         = mayDenyPut,
    alwaysGrantsT:      Boolean         = alwaysGrantsT,
    fifoId:             Option[Int]     = fifoId) =
// ...
class TLSlavePortParameters private(
  val slaves:         Seq[TLSlaveParameters],
  val channelBytes:   TLChannelBeatBytes,
  val endSinkId:      Int,
  val minLatency:     Int,
  val responseFields: Seq[BundleFieldBase],
  val requestKeys:    Seq[BundleKeyBase]) extends SimpleProduct
{
// ...
  require (!slaves.isEmpty, "Slave ports must have slaves")
  require (endSinkId >= 0, "Sink ids cannot be negative")
  require (minLatency >= 0, "Minimum required latency cannot be negative")

  // Using this API implies you cannot handle mixed-width busses
  def beatBytes = {
    channelBytes.members.foreach { width =>
      require (width.isDefined && width == channelBytes.a)
    }
    channelBytes.a.get
  }

  // TODO this should be deprecated
  def managers = slaves
// ...
  def v1copy(
    managers:   Seq[TLSlaveParameters] = slaves,
    beatBytes:  Int = -1,
    endSinkId:  Int = endSinkId,
    minLatency: Int = minLatency,
    responseFields: Seq[BundleFieldBase] = responseFields,
    requestKeys:    Seq[BundleKeyBase]   = requestKeys) =
  {
    new TLSlavePortParameters(
      slaves       = managers,
      channelBytes = if (beatBytes != -1) TLChannelBeatBytes(beatBytes) else channelBytes,
      endSinkId    = endSinkId,
      minLatency   = minLatency,
      responseFields = responseFields,
      requestKeys    = requestKeys)
  }
// ...
class TLMasterParameters private(
  val nodePath:          Seq[BaseNode],
  val resources:         Seq[Resource],
  val name:              String,
  val visibility:        Seq[AddressSet],
  val unusedRegionTypes: Set[RegionType.T],
  val executesOnly:      Boolean,
  val requestFifo:       Boolean, // only a request, not a requirement. applies to A, not C.
  val supports:          TLSlaveToMasterTransferSizes,
  val emits:             TLMasterToSlaveTransferSizes,
  val neverReleasesData: Boolean,
  val sourceId:          IdRange) extends SimpleProduct
// ...
  def v1copy(
    name:                String          = name,
    sourceId:            IdRange         = sourceId,
    nodePath:            Seq[BaseNode]   = nodePath,
    requestFifo:         Boolean         = requestFifo,
    visibility:          Seq[AddressSet] = visibility,
    supportsProbe:       TransferSizes   = supports.probe,
    supportsArithmetic:  TransferSizes   = supports.arithmetic,
    supportsLogical:     TransferSizes   = supports.logical,
    supportsGet:         TransferSizes   = supports.get,
    supportsPutFull:     TransferSizes   = supports.putFull,
    supportsPutPartial:  TransferSizes   = supports.putPartial,
    supportsHint:        TransferSizes   = supports.hint) =
// ...
class TLMasterPortParameters private(
  val masters:       Seq[TLMasterParameters],
  val channelBytes:  TLChannelBeatBytes,
  val minLatency:    Int,
  val echoFields:    Seq[BundleFieldBase],
  val requestFields: Seq[BundleFieldBase],
  val responseKeys:  Seq[BundleKeyBase]) extends SimpleProduct
{
// ...
  require (!masters.isEmpty)
  require (minLatency >= 0)

  def clients = masters

  // Require disjoint ranges for Ids
  IdRange.overlaps(masters.map(_.sourceId)).foreach { case (x, y) =>
    require (!x.overlaps(y), s"TLClientParameters.sourceId ${x} overlaps ${y}")
  }

  // Bounds on required sizes
  def endSourceId = masters.map(_.sourceId.end).max
  def maxTransfer = masters.map(_.maxTransfer).max
// ...
  def v1copy(
    clients: Seq[TLMasterParameters] = masters,
    minLatency: Int = minLatency,
    echoFields:    Seq[BundleFieldBase] = echoFields,
    requestFields: Seq[BundleFieldBase] = requestFields,
    responseKeys:  Seq[BundleKeyBase]   = responseKeys) =
  {
    new TLMasterPortParameters(
      masters       = clients,
      channelBytes  = channelBytes,
      minLatency    = minLatency,
      echoFields    = echoFields,
      requestFields = requestFields,
      responseKeys  = responseKeys)
  }
```

### `src/main/scala/diplomacy/Parameters.scala`

```scala
case class IdRange(start: Int, end: Int) extends Ordered[IdRange]
{
// ...
  def shift(x: Int) = IdRange(start+x, end+x)
  def size = end - start
  def isEmpty = end == start
```

### `src/main/scala/util/BundleMap.scala`

```scala
object BundleField {
  /* Consider an arbiter that receives two request streams A and B and combines them to C.
   * The output stream C should have the union of all keys from A and B.
   * When a key from A and B have the same name:
   *  - it is an error if they are not equal.
   *  - the union contains only one copy.
   */
  def union(fields: Seq[BundleFieldBase]): Seq[BundleFieldBase] =
    fields.groupBy(_.key.name).map(_._2.reduce(_ unify _)).toList
```

### `src/main/scala/tilelink/Xbar.scala`

```scala
object TLXbar
{
  def circuit(policy: TLArbiter.Policy, seqIn: Seq[(TLBundle, TLEdge)], seqOut: Seq[(TLBundle, TLEdge)]): Unit = {
    val seqOut_ACancel = seqOut.map(sOut => (Wire(new TLBundle_ACancel(sOut._1.params)), sOut._2))
    val seqIn_ACancel = seqIn.map(sIn => (TLBundle_ACancel(sIn._1), sIn._2))
    TLXbar_ACancel.circuit(policy, seqIn_ACancel, seqOut_ACancel)
    (seqOut.map(_._1) zip seqOut_ACancel.map(_._1)) foreach { case (sOut, sOut_ACancel) =>
      sOut <> sOut_ACancel.asDecoupled()
    }
  }

  def apply(policy: TLArbiter.Policy = TLArbiter.roundRobin)(implicit p: Parameters): TLNode =
  {
    val xbar = LazyModule(new TLXbar(policy))
    xbar.node
  }

  def mapInputIds (ports: Seq[TLMasterPortParameters]) = assignRanges(ports.map(_.endSourceId))
  def mapOutputIds(ports: Seq[TLSlavePortParameters ]) = assignRanges(ports.map(_.endSinkId))

  def assignRanges(sizes: Seq[Int]) = {
    val pow2Sizes = sizes.map { z => if (z == 0) 0 else 1 << log2Ceil(z) }
    val tuples = pow2Sizes.zipWithIndex.sortBy(_._1) // record old index, then sort by increasing size
    val starts = tuples.scanRight(0)(_._1 + _).tail // suffix-sum of the sizes = the start positions
    val ranges = (tuples zip starts) map { case ((sz, i), st) =>
      (if (sz == 0) IdRange(0,0) else IdRange(st, st+sz), i)
    }
    ranges.sortBy(_._2).map(_._1) // Restore original order
  }

  def relabeler() = {
    var idFactory = 0
    () => {
      val fifoMap = scala.collection.mutable.HashMap.empty[Int, Int]
      (x: Int) => {
        if (fifoMap.contains(x)) fifoMap(x) else {
          val out = idFactory
          idFactory = idFactory + 1
          fifoMap += (x -> out)
          out
        }
      }
    }
  }
// ...
}
```

## Documentation

### `docs/TileLink-Diplomacy-Reference/Widgets.rst`

```text
TLXbar and AXI4Xbar
-------------------

These are crossbar generators for TileLink and AXI4 which will route requests
from TL client / AXI4 master nodes to TL manager / AXI4 slave nodes based on
the addresses defined in the managers / slaves. Normally, these are constructed
without arguments. However, you can change the arbitration policy, which
determines which client ports get precedent in the arbiters. The default policy
is ``TLArbiter.roundRobin``, but you can change it to ``TLArbiter.lowestIndexFirst``
if you want a fixed arbitration precedence.
...
**Example Usage:**

.. code-block:: scala

    // Instantiate the crossbar lazy module
    val tlBus = LazyModule(new TLXbar)

    // Connect a single input edge
    tlBus.node := tlClient0.node
    // Connect multiple input edges
    tlBus.node :=* tlClient1.node

    // Connect a single output edge
    tlManager0.node := tlBus.node
    // Connect multiple output edges
    tlManager1.node :*= tlBus.node
```

### `docs/TileLink-Diplomacy-Reference/NodeTypes.rst`

```text
Diplomacy represents the different components of an SoC as nodes of a
directed acyclic graph. TileLink nodes can come in several different types.

Client Node
-----------

TileLink clients are modules that initiate TileLink transactions by sending
requests on the A channel and receive responses on the D channel. If the
client implements TL-C, it will receive probes on the B channel, send releases
on the C channel, and send grant acknowledgements on the E channel.
...
The ``sourceId`` argument specifies the range of source identifiers that this
client will use. Since we have set the range to [0, 4) here, this client will
be able to send up to four requests in flight at a time. Each request will
have a distinct value in its source field. The default value for this field
is ``IdRange(0, 1)``, which means it would only be able to send a single
request inflight.

The ``requestFifo`` argument is a boolean option which defaults to false.
If it is set to true, the client will request that downstream managers that
support it send responses in FIFO order (that is, in the same order the
corresponding requests were sent).

The ``visibility`` argument specifies the address ranges that the client will
access. By default it is set to include all addresses. In this example, we set
it to contain a single address range ``AddressSet(0x10000, 0xffff)``, which
means that the client will only be able to access addresses from 0x10000 to
0x1ffff.  normally do not specify this, but it can help downstream crossbar
generators optimize the hardware by not arbitrating the client to managers with
address ranges that don't overlap with its visibility.
...
Manager Node
------------

TileLink managers take requests from clients on the A channel and send
responses back on the D channel. You can create a manager node using the
TLHelper like so:
...
The only required argument for ``TLManagerParameters`` is the ``address``,
which is the set of address ranges that this manager will serve.
This information is used to route requests from the clients. In this example,
the manager will only take requests for addresses from 0x20000 to 0x20fff.
The second argument in ``AddressSet`` is a mask, not a size.
You should generally set it to be one less than a power of two. Otherwise,
the addressing behavior may not be what you expect.
...
The final argument shown here is the ``fifoId`` setting, which determines
which FIFO domain (if any) the manager is in. If this argument is set to ``None``
(the default), the manager will not guarantee any ordering of the responses.
If the ``fifoId`` is set, it will share a FIFO domain with all other managers
that specify the same ``fifoId``. This means that client requests sent to
that FIFO domain will see responses in the same order.
...
The ``clientFn`` is a function that takes the ``TLClientPortParameters`` of
the input as an argument and returns the corresponding parameters for the
output. The ``managerFn`` takes the ``TLManagerPortParameters`` of the output
as an argument and returns the corresponding parameters for the input.

Nexus Node
----------

The nexus node is similar to the adapter node in that it has a different
output interface than input interface. But it can also have a different
number of inputs than it does outputs. This node type is mainly used by
the ``TLXbar`` widget, which provides a TileLink crossbar generator. You will
also likely not need to define this node type manually, but its invocation is
as follows.

.. code-block:: scala

    val node = TLNexusNode(
      clientFn = { seq =>
        // ..
      },
      managerFn = { seq =>
        // ..
      })

This has similar arguments as the adapter node's constructor, but instead of
taking single parameters objects as arguments and returning single objects
as results, the functions take and return sequences of parameters. And as you
might expect, the size of the returned sequence need not be the same size as
the input sequence.
```
