# Implement `BoomTileModuleImp`

Implement one complete `BoomTileModuleImp` Chisel definition. Preserve the definition name, constructor parameter, and inheritance shown below.

Return only the complete `class BoomTileModuleImp` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package boom.common

import chisel3._
import chisel3.util.{RRArbiter, Queue}

import scala.collection.mutable.{ListBuffer}

import freechips.rocketchip.config._
import freechips.rocketchip.subsystem._
import freechips.rocketchip.devices.tilelink._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.diplomaticobjectmodel.logicaltree.{LogicalTreeNode }
import freechips.rocketchip.rocket._
import freechips.rocketchip.subsystem.{RocketCrossingParams}
import freechips.rocketchip.tilelink._
import freechips.rocketchip.interrupts._
import freechips.rocketchip.util._
import freechips.rocketchip.tile._

import testchipip.{ExtendedTracedInstruction, WithExtendedTraceport}

import boom.exu._
import boom.ifu._
import boom.lsu._
import boom.util.{BoomCoreStringPrefix}
import freechips.rocketchip.prci.ClockSinkParameters
```

## Class declaration

```scala
/**
 * BOOM tile implementation
 *
 * @param outer top level BOOM tile
 */
class BoomTileModuleImp(outer: BoomTile) extends BaseTileModuleImp(outer){
```

## Parent instantiation

### src/main/scala/common/tile.scala

```scala
/**
 * BOOM tile
 *
 */
class BoomTile private(
  val boomParams: BoomTileParams,
  crossing: ClockCrossingType,
  lookup: LookupByHartIdImpl,
  q: Parameters)
  extends BaseTile(boomParams, crossing, lookup, q)
  with SinksExternalInterrupts
  with SourcesExternalNotifications
  with WithExtendedTraceport
{
  // ...
  override lazy val module = new BoomTileModuleImp(this)

  // DCache
  lazy val dcache: BoomNonBlockingDCache = LazyModule(new BoomNonBlockingDCache(staticIdForMetadataUseOnly))
  val dCacheTap = TLIdentityNode()
  tlMasterXbar.node := dCacheTap := dcache.node


  // Frontend/ICache
  val frontend = LazyModule(new BoomFrontend(tileParams.icache.get, staticIdForMetadataUseOnly))
  frontend.resetVectorSinkNode := resetVectorNexusNode
  tlMasterXbar.node := frontend.masterNode

  // ROCC
  val roccs = p(BuildRoCC).map(_(p))
  roccs.map(_.atlNode).foreach { atl => tlMasterXbar.node :=* atl }
  roccs.map(_.tlNode).foreach { tl => tlOtherMastersNode :=* tl }
}
```

### generators/chipyard/src/main/scala/Subsystem.scala

```scala
class ChipyardSubsystem(implicit p: Parameters) extends BaseSubsystem
  with HasTiles
  with CanHaveHTIF
{
  def coreMonitorBundles = tiles.map {
    case r: RocketTile => r.module.core.rocketImpl.coreMonitorBundle
    case b: BoomTile => b.module.core.coreMonitorBundle
  }.toList
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/common/tile.scala

```scala
case class BoomTileParams(
  core: BoomCoreParams = BoomCoreParams(),
  icache: Option[ICacheParams] = Some(ICacheParams()),
  dcache: Option[DCacheParams] = Some(DCacheParams()),
  btb: Option[BTBParams] = Some(BTBParams()),
  trace: Boolean = false,
  name: Option[String] = Some("boom_tile"),
  hartId: Int = 0
) extends InstantiableTileParams[BoomTile]
```

### src/main/scala/exu/core.scala

```scala
/**
 * Top level core object that connects the Frontend to the rest of the pipeline.
 */
class BoomCore(usingTrace: Boolean)(implicit p: Parameters) extends BoomModule
  with HasBoomFrontendParameters // TODO: Don't add this trait
{
  val io = new freechips.rocketchip.tile.CoreBundle
  {
    val hartid = Input(UInt(hartIdLen.W))
    val interrupts = Input(new freechips.rocketchip.tile.CoreInterrupts())
    val ifu = new boom.ifu.BoomFrontendIO
    val ptw = Flipped(new freechips.rocketchip.rocket.DatapathPTWIO())
    val rocc = Flipped(new freechips.rocketchip.tile.RoCCCoreIO())
    val lsu = Flipped(new boom.lsu.LSUCoreIO)
    val ptw_tlb = new freechips.rocketchip.rocket.TLBPTWIO()
    val trace = Output(Vec(coreParams.retireWidth, new ExtendedTracedInstruction))
    val fcsr_rm = UInt(freechips.rocketchip.tile.FPConstants.RM_SZ.W)
  }
```

### src/main/scala/ifu/frontend.scala

```scala
class BoomFrontend(val icacheParams: ICacheParams, staticIdForMetadataUseOnly: Int)(implicit p: Parameters) extends LazyModule
{
  lazy val module = new BoomFrontendModule(this)
// ...
class BoomFrontendBundle(val outer: BoomFrontend) extends CoreBundle()(outer.p)
{
  val cpu = Flipped(new BoomFrontendIO())
  val ptw = new TLBPTWIO()
// ...
class BoomFrontendModule(outer: BoomFrontend) extends LazyModuleImp(outer)
  with HasBoomCoreParameters
  with HasBoomFrontendParameters
{
  val io = IO(new BoomFrontendBundle(outer))
```

### src/main/scala/lsu/lsu.scala

```scala
class LSUIO(implicit p: Parameters, edge: TLEdgeOut) extends BoomBundle()(p)
{
  val ptw   = new rocket.TLBPTWIO
  val core  = new LSUCoreIO
  val dmem  = new LSUDMemIO

  val hellacache = Flipped(new freechips.rocketchip.rocket.HellaCacheIO)
}
// ...
class LSU(implicit p: Parameters, edge: TLEdgeOut) extends BoomModule()(p)
  with rocket.HasL1HellaCacheParameters
{
  val io = IO(new LSUIO)
```

### src/main/scala/lsu/dcache.scala

```scala
class BoomDCacheBundle(implicit p: Parameters, edge: TLEdgeOut) extends BoomBundle()(p) {
  val errors = new DCacheErrors
  val lsu   = Flipped(new LSUDMemIO)
}

class BoomNonBlockingDCacheModule(outer: BoomNonBlockingDCache) extends LazyModuleImp(outer)
  with HasL1HellaCacheParameters
  with HasBoomCoreParameters
{
  implicit val edge = outer.node.edges.out(0)
  val (tl_out, _) = outer.node.out(0)
  val io = IO(new BoomDCacheBundle)
```

### src/main/scala/tile/BaseTile.scala

```scala
trait TileParams {
  val core: CoreParams
  val icache: Option[ICacheParams]
  val dcache: Option[DCacheParams]
  val btb: Option[BTBParams]
  val hartId: Int
  val beuAddr: Option[BigInt]
  val blockerCtrlAddr: Option[BigInt]
  val name: Option[String]
  val clockSinkParams: ClockSinkParameters
}
// ...
trait HasNonDiplomaticTileParameters {
  implicit val p: Parameters
  def tileParams: TileParams = p(TileKey)
// ...
trait HasTileParameters extends HasNonDiplomaticTileParameters {
// ...
abstract class BaseTile private (val crossing: ClockCrossingType, q: Parameters)
    extends LazyModule()(q)
    with CrossesToOnlyOneClockDomain
    with HasNonDiplomaticTileParameters
    with HasLogicalTreeNode
{
  // ...
  /** Node for broadcasting a hart id to diplomatic consumers within the tile. */
  val hartIdNexusNode: BundleBridgeNode[UInt] = BundleBroadcast[UInt](registered = p(InsertTimingClosureRegistersOnHartIds))

  /** Node for consuming the hart id input in tile-layer Chisel logic. */
  val hartIdSinkNode = BundleBridgeSink[UInt]()
  // ...
  protected def traceRetireWidth = tileParams.core.retireWidth
  /** Node for the core to drive legacy "raw" instruction trace. */
  val traceSourceNode = BundleBridgeSource(() => Vec(traceRetireWidth, new TracedInstruction()))
  private val traceNexus = BundleBroadcast[Vec[TracedInstruction]]() // backwards compatiblity; not blocked during stretched reset
  /** Node for external consumers to source a legacy instruction trace from the core. */
  val traceNode: BundleBridgeOutwardNode[Vec[TracedInstruction]] = traceNexus := traceSourceNode
  // ...
  /** Node for watchpoints to control trace driven by core. */
  val bpwatchSourceNode = BundleBridgeSource(() => Vec(tileParams.core.nBreakpoints, new BPWatch(traceRetireWidth)))
  /** Node to broadcast watchpoints to control trace. */
  val bpwatchNexusNode = BundleBroadcast[Vec[BPWatch]]()
  /** Node for external consumers to source watchpoints to control trace. */
  val bpwatchNode: BundleBridgeOutwardNode[Vec[BPWatch]] =
    BundleBridgeNameNode("bpwatch") :*= bpwatchNexusNode := bpwatchSourceNode
// ...
abstract class BaseTileModuleImp[+L <: BaseTile](val outer: L) extends LazyModuleImp(outer) with HasTileParameters
```

### src/main/scala/tile/Interrupts.scala

```scala
trait SinksExternalInterrupts { this: BaseTile =>
  // ...
  // go from flat diplomatic Interrupts to bundled TileInterrupts
  def decodeCoreInterrupts(core: TileInterrupts): Unit = {
    val async_ips = Seq(core.debug)
    val periph_ips = Seq(
      core.msip,
      core.mtip,
      core.meip)

    val seip = if (core.seip.isDefined) Seq(core.seip.get) else Nil

    val core_ips = core.lip

    val (interrupts, _) = intSinkNode.in(0)
    (async_ips ++ periph_ips ++ seip ++ core_ips).zip(interrupts).foreach { case(c, i) => c := i }
  }
// ...
trait SourcesExternalNotifications { this: BaseTile =>
  // ...
  // Report when the tile is waiting for an interrupt
  val wfiNode = IntSourceNode(IntSourcePortSimple())

  def reportWFI(could_wfi: Option[Bool]): Unit = {
    val (wfi, _) = wfiNode.out(0)
    wfi(0) := could_wfi.map(RegNext(_, init=false.B)).getOrElse(false.B)
  }
```

### src/main/scala/tile/Core.scala

```scala
class CoreInterrupts(implicit p: Parameters) extends TileInterrupts()(p) {
  val buserror = tileParams.beuAddr.map(a => Bool())
}
```

### src/main/scala/rocket/PTW.scala

```scala
class TLBPTWIO(implicit p: Parameters) extends CoreBundle()(p)
    with HasCoreParameters {
// ...
class DatapathPTWIO(implicit p: Parameters) extends CoreBundle()(p)
    with HasCoreParameters {
// ...
@chiselName
class PTW(n: Int)(implicit edge: TLEdgeOut, p: Parameters) extends CoreModule()(p) {
  val io = new Bundle {
    val requestor = Vec(n, new TLBPTWIO).flip
    val mem = new HellaCacheIO
    val dpath = new DatapathPTWIO
  }
```

### src/main/scala/rocket/HellaCacheArbiter.scala

```scala
class HellaCacheArbiter(n: Int)(implicit p: Parameters) extends Module
{
  val io = new Bundle {
    val requestor = Vec(n, new HellaCacheIO).flip
    val mem = new HellaCacheIO
  }

  if (n == 1) {
    io.mem <> io.requestor.head
```

### src/main/scala/tile/LazyRoCC.scala

```scala
case object BuildRoCC extends Field[Seq[Parameters => LazyRoCC]](Nil)
```

### src/main/scala/TraceIO.scala

```scala
class ExtendedTracedInstruction(val extended: Boolean = true)(implicit p: Parameters) extends TracedInstruction {
  val wdata = if (extended) Some(UInt(xLen.W)) else None
}
// ...
//*****************************************************************
// Allow BaseTiles to have an ExtendedTracedInstruction port/bundle
//*****************************************************************

trait WithExtendedTraceport { this: BaseTile =>
  // Extended Traceport
  val extTraceSourceNode = BundleBridgeSource(() => Vec(tileParams.core.retireWidth, new ExtendedTracedInstruction()))
  val extTraceNode = BundleBroadcast[Vec[ExtendedTracedInstruction]](Some("trace"))
  extTraceNode := extTraceSourceNode
}
```

## Documentation

```text
Create Implementation Class
---------------------------

The implementation class contains the parameterized, actual hardware that depends on the values resolved by the Diplomacy
framework according to the info provided in the Tile class. This class will normally contains Chisel RTL code. If your
core is in Verilog, you will need to instantiate the black box class that wraps your Verilog implementation and connect it with the buses
and other components. No Diplomacy/TileLink code should be in this class; you should only connect the IO signals in TileLink
interfaces or other diplomatically defined components, which are located in the tile class.

...

Connect Interrupt
-----------------

Chipyard allows a tile to either receive interrupts from other devices or initiate interrupts to notify other cores/devices.
In the tile that inherited ``SinksExternalInterrupts``, one can create a ``TileInterrupts`` object (a Chisel bundle) and
call ``decodeCoreInterrupts()`` with the object as the argument. Note that you should call this function in the implementation
class since it returns a Chisel bundle used by RTL code. You can then read the interrupt bits from the ``TileInterrupts`` bundle
we create above. The definition of ``TileInterrupts``
(in the file `Interrupts.scala <https://github.com/chipsalliance/rocket-chip/blob/master/src/main/scala/tile/Interrupts.scala>`_) is

.. code-block:: scala

    class TileInterrupts(implicit p: Parameters) extends CoreBundle()(p) {
      val debug = Bool() // debug interrupt
      val mtip = Bool() // Machine level timer interrupt
      val msip = Bool() // Machine level software interrupt
      val meip = Bool() // Machine level external interrupt
      val seip = usingSupervisor.option(Bool()) // Valid only if supervisor mode is supported
      val lip = Vec(coreParams.nLocalInterrupts, Bool())  // Local interrupts
    }

...

Also, the tile can also notify other cores or devices for some events by calling following functions in ``SourcesExternalNotifications``
from the implementation class:
(These functions can be found in in the trait ``SourcesExternalNotifications`` in the file
`Interrupts.scala <https://github.com/chipsalliance/rocket-chip/blob/master/src/main/scala/tile/Interrupts.scala>`_)

.. code-block:: scala

    def reportHalt(could_halt: Option[Bool]) // Triggered when there is an unrecoverable hardware error (halt the machine)
    def reportHalt(errors: Seq[CanHaveErrors]) // Varient for standard error bundle (Rocket specific: used only by cache when there's an ECC error)
    def reportCease(could_cease: Option[Bool], quiescenceCycles: Int = 8) // Triggered when the core stop retiring instructions (like clock gating)
    def reportWFI(could_wfi: Option[Bool]) // Triggered when a WFI instruction is executed
```
