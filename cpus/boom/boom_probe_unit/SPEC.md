# Implement `BoomProbeUnit`

Implement one complete `BoomProbeUnit` source-level hardware definition for the selected BOOM configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class BoomProbeUnit` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/common/config-mixins.scala

```scala
// DOC include start: LargeBoomConfig
/**
 * 3-wide BOOM. Try to match the Cortex-A15.
 */
class WithNLargeBooms(n: Int = 1, overrideIdOffset: Option[Int] = None) extends Config(
// ...
            dcache = Some(
              DCacheParams(rowBits = site(SystemBusKey).beatBits, nSets=64, nWays=8, nMSHRs=4, nTLBWays=16)
            ),
```

## Package and imports

```scala
package boom.lsu

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.tile._
import freechips.rocketchip.util._
import freechips.rocketchip.rocket._

import boom.common._
import boom.exu.BrUpdateInfo
import boom.util.{IsKilledByBranch, GetNewBrMask, BranchKillableQueue, IsOlder, UpdateBrMask, AgePriorityEncoder, WrapInc, Transpose}
```

## Class declaration

```scala
class BoomProbeUnit(implicit edge: TLEdgeOut, p: Parameters) extends L1HellaCacheModule()(p) {
  val io = new Bundle {
    val req = Flipped(Decoupled(new TLBundleB(edge.bundle)))
    val rep = Decoupled(new TLBundleC(edge.bundle))
    val meta_read = Decoupled(new L1MetaReadReq)
    val meta_write = Decoupled(new L1MetaWriteReq)
    val wb_req = Decoupled(new WritebackReq(edge.bundle))
    val way_en = Input(UInt(nWays.W))
    val wb_rdy = Input(Bool()) // Is writeback unit currently busy? If so need to retry meta read when its done
    val mshr_rdy = Input(Bool()) // Is MSHR ready for this request to proceed?
    val mshr_wb_rdy = Output(Bool()) // Should we block MSHR writebacks while we finish our own?
    val block_state = Input(new ClientMetadata())
    val lsu_release = Decoupled(new TLBundleC(edge.bundle))

    val state = Output(Valid(UInt(coreMaxAddrBits.W)))
  }
```

## Parent instantiation

```scala
  // Tag read for prober
  metaReadArb.io.in(1).valid       := prober.io.meta_read.valid
  metaReadArb.io.in(1).bits.req(0) := prober.io.meta_read.bits
  prober.io.meta_read.ready := metaReadArb.io.in(1).ready
  // Prober does not need to read data array
// ...
  // tag check
  def wayMap[T <: Data](f: Int => T) = VecInit((0 until nWays).map(f))
  val s1_tag_eq_way = widthMap(i => wayMap((w: Int) => meta(i).io.resp(w).tag === (s1_addr(i) >> untagBits)).asUInt)
  val s1_tag_match_way = widthMap(i =>
                         Mux(s1_type === t_replay, s1_replay_way_en,
                         Mux(s1_type === t_wb,     s1_wb_way_en,
                         Mux(s1_type === t_mshr_meta_read, s1_mshr_meta_read_way_en,
                           wayMap((w: Int) => s1_tag_eq_way(i)(w) && meta(i).io.resp(w).coh.isValid()).asUInt))))
// ...
  val s2_tag_match_way = RegNext(s1_tag_match_way)
  val s2_tag_match     = s2_tag_match_way.map(_.orR)
  val s2_hit_state     = widthMap(i => Mux1H(s2_tag_match_way(i), wayMap((w: Int) => RegNext(meta(i).io.resp(w).coh))))
// ...
  // probes and releases
  prober.io.req.valid   := tl_out.b.valid && !lrsc_valid
  tl_out.b.ready        := prober.io.req.ready && !lrsc_valid
  prober.io.req.bits    := tl_out.b.bits
  prober.io.way_en      := s2_tag_match_way(0)
  prober.io.block_state := s2_hit_state(0)
  metaWriteArb.io.in(1) <> prober.io.meta_write
  prober.io.mshr_rdy    := mshrs.io.probe_rdy
  prober.io.wb_rdy      := (prober.io.meta_write.bits.idx =/= wb.io.idx.bits) || !wb.io.idx.valid
  mshrs.io.prober_state := prober.io.state
// ...
  // writebacks
  val wbArb = Module(new Arbiter(new WritebackReq(edge.bundle), 2))
  // 0 goes to prober, 1 goes to MSHR evictions
  wbArb.io.in(0)       <> prober.io.wb_req
// ...
  val lsu_release_arb = Module(new Arbiter(new TLBundleC(edge.bundle), 2))
  io.lsu.release <> lsu_release_arb.io.out
  lsu_release_arb.io.in(0) <> wb.io.lsu_release
  lsu_release_arb.io.in(1) <> prober.io.lsu_release

  TLArbiter.lowest(edge, tl_out.c, wb.io.release, prober.io.rep)
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/tilelink/Metadata.scala

```scala
object ClientStates {
  val width = 2

  def Nothing = UInt(0, width)
  def Branch  = UInt(1, width)
  def Trunk   = UInt(2, width)
  def Dirty   = UInt(3, width)

  def hasReadPermission(state: UInt): Bool = state > Nothing
  def hasWritePermission(state: UInt): Bool = state > Branch
}
// ...

/** Stores the client-side coherence information,
  * such as permissions on the data and whether the data is dirty.
  * Its API can be used to make TileLink messages in response to
  * memory operations, cache control oeprations, or Probe messages.
  */
class ClientMetadata extends Bundle {
  /** Actual state information stored in this bundle */
  val state = UInt(width = ClientStates.width)

// ...
  /** Determine what state to go to based on Probe param */
  private def shrinkHelper(param: UInt): (Bool, UInt, UInt) = {
    import ClientStates._
    import TLPermissions._
    MuxTLookup(Cat(param, state), (Bool(false), UInt(0), UInt(0)), Seq(
    //(wanted, am now)  -> (hasDirtyData resp, next)
      Cat(toT, Dirty)   -> (Bool(true),  TtoT, Trunk),
      Cat(toT, Trunk)   -> (Bool(false), TtoT, Trunk),
      Cat(toT, Branch)  -> (Bool(false), BtoB, Branch),
      Cat(toT, Nothing) -> (Bool(false), NtoN, Nothing),
      Cat(toB, Dirty)   -> (Bool(true),  TtoB, Branch),
      Cat(toB, Trunk)   -> (Bool(false), TtoB, Branch),  // Policy: Don't notify on clean downgrade
      Cat(toB, Branch)  -> (Bool(false), BtoB, Branch),
      Cat(toB, Nothing) -> (Bool(false), NtoN, Nothing),
      Cat(toN, Dirty)   -> (Bool(true),  TtoN, Nothing),
      Cat(toN, Trunk)   -> (Bool(false), TtoN, Nothing), // Policy: Don't notify on clean downgrade
      Cat(toN, Branch)  -> (Bool(false), BtoN, Nothing), // Policy: Don't notify on clean downgrade
      Cat(toN, Nothing) -> (Bool(false), NtoN, Nothing)))
  }
// ...
  def onProbe(param: UInt): (Bool, UInt, ClientMetadata) = { 
    val r = shrinkHelper(param)
    (r._1, r._2, ClientMetadata(r._3))
  }
}

/** Factories for ClientMetadata, including on reset */
object ClientMetadata {
  def apply(perm: UInt) = {
    val meta = Wire(new ClientMetadata)
    meta.state := perm
    meta
  }
  def onReset = ClientMetadata(ClientStates.Nothing)
```

### src/main/scala/tilelink/Bundles.scala

```scala
/**
  * The three primary TileLink permissions are:
  *   (T)runk: the agent is (or is on inwards path to) the global point of serialization.
  *   (B)ranch: the agent is on an outwards path to
  *   (N)one:
  * These permissions are permuted by transfer operations in various ways.
  * Operations can cap permissions, request for them to be grown or shrunk,
  * or for a report on their current status.
  */
object TLPermissions
{
  val aWidth = 2
  val bdWidth = 2
  val cWidth = 3

  // Cap types (Grant = new permissions, Probe = permisions <= target)
  def toT = UInt(0, bdWidth)
  def toB = UInt(1, bdWidth)
  def toN = UInt(2, bdWidth)
  def isCap(x: UInt) = x <= toN

  // Grow types (Acquire = permissions >= target)
  def NtoB = UInt(0, aWidth)
  def NtoT = UInt(1, aWidth)
  def BtoT = UInt(2, aWidth)
  def isGrow(x: UInt) = x <= BtoT

  // Shrink types (ProbeAck, Release)
  def TtoB = UInt(0, cWidth)
  def TtoN = UInt(1, cWidth)
  def BtoN = UInt(2, cWidth)
  def isShrink(x: UInt) = x <= BtoN

  // Report types (ProbeAck, Release)
  def TtoT = UInt(3, cWidth)
  def BtoB = UInt(4, cWidth)
  def NtoN = UInt(5, cWidth)
  def isReport(x: UInt) = x <= NtoN

  def PermMsgGrow:Seq[String] = Seq("Grow NtoB", "Grow NtoT", "Grow BtoT")
  def PermMsgCap:Seq[String] = Seq("Cap toT", "Cap toB", "Cap toN")
  def PermMsgReport:Seq[String] = Seq("Shrink TtoB", "Shrink TtoN", "Shrink BtoN", "Report TotT", "Report BtoB", "Report NtoN")
  def PermMsgReserved:Seq[String] = Seq("Reserved")
}
// ...
final class TLBundleB(params: TLBundleParameters)
  extends TLBundleBase(params) with TLAddrChannel
{
  val channelName = "'B' channel"
  // fixed fields during multibeat:
  val opcode  = UInt(width = 3)
  val param   = UInt(width = TLPermissions.bdWidth) // cap perms
  val size    = UInt(width = params.sizeBits)
  val source  = UInt(width = params.sourceBits) // to
  val address = UInt(width = params.addressBits) // from
  // variable fields during multibeat:
  val mask    = UInt(width = params.dataBits/8)
  val data    = UInt(width = params.dataBits)
  val corrupt = Bool() // only applies to *Data messages
}
// ...
final class TLBundleC(params: TLBundleParameters)
  extends TLBundleBase(params) with TLAddrChannel
{
  val channelName = "'C' channel"
  // fixed fields during multibeat:
  val opcode  = UInt(width = 3)
  val param   = UInt(width = TLPermissions.cWidth) // shrink or report perms
  val size    = UInt(width = params.sizeBits)
  val source  = UInt(width = params.sourceBits) // from
  val address = UInt(width = params.addressBits) // to
  val user    = BundleMap(params.requestFields)
  val echo    = BundleMap(params.echoFields)
  // variable fields during multibeat:
  val data    = UInt(width = params.dataBits)
  val corrupt = Bool() // only applies to *Data messages
}
```

### src/main/scala/tilelink/Edges.scala

```scala
  def ProbeAck(b: TLBundleB, reportPermissions: UInt): TLBundleC =
    ProbeAck(b.source, b.address, b.size, reportPermissions)

  def ProbeAck(fromSource: UInt, toAddress: UInt, lgSize: UInt, reportPermissions: UInt): TLBundleC = {
    val c = Wire(new TLBundleC(bundle))
    c.opcode  := TLMessages.ProbeAck
    c.param   := reportPermissions
    c.size    := lgSize
    c.source  := fromSource
    c.address := toAddress
    c.data    := UInt(0)
    c.corrupt := Bool(false)
    c
  }
```

### src/main/scala/rocket/HellaCache.scala

```scala
trait HasL1HellaCacheParameters extends HasL1CacheParameters with HasCoreParameters {
  val cacheParams = tileParams.dcache.get
  val cfg = cacheParams
// ...
  def idxMSB = untagBits-1
  def idxLSB = blockOffBits
// ...
class L1Metadata(implicit p: Parameters) extends L1HellaCacheBundle()(p) {
  val coh = new ClientMetadata
  val tag = UInt(width = tagBits)
}
// ...
class L1MetaReadReq(implicit p: Parameters) extends L1HellaCacheBundle()(p) {
  val idx    = UInt(width = idxBits)
  val way_en = UInt(width = nWays)
  val tag    = UInt(width = tagBits)
}

class L1MetaWriteReq(implicit p: Parameters) extends L1MetaReadReq()(p) {
  val data = new L1Metadata
}
```

### src/main/scala/rocket/NBDcache.scala

```scala
class WritebackReq(params: TLBundleParameters)(implicit p: Parameters) extends L1HellaCacheBundle()(p) {
  val tag = Bits(width = tagBits)
  val idx = Bits(width = idxBits)
  val source = UInt(width = params.sourceBits)
  val param = UInt(width = TLPermissions.cWidth) 
  val way_en = Bits(width = nWays)
  val voluntary = Bool()

}
```

### src/main/scala/tile/L1Cache.scala

```scala
trait HasL1CacheParameters extends HasTileParameters {
  val cacheParams: L1CacheParams

  def nSets = cacheParams.nSets
  def blockOffBits = lgCacheBlockBytes
  def idxBits = log2Up(cacheParams.nSets)
  def untagBits = blockOffBits + idxBits
  def pgUntagBits = if (usingVM) untagBits min pgIdxBits else untagBits
  def tagBits = tlBundleParams.addressBits - pgUntagBits
  def nWays = cacheParams.nWays
  def wayBits = log2Up(nWays)
```

### src/main/scala/tile/Core.scala

```scala
  def coreMaxAddrBits = paddrBits max vaddrBitsExtended
```

### src/main/scala/chisel3/util/Decoupled.scala

```scala
    /** Indicates if IO is both ready and valid
      */
    def fire: Bool = target.ready && target.valid
// ...
/** A concrete subclass of ReadyValidIO signaling that the user expects a
  * "decoupled" interface: 'valid' indicates that the producer has
  * put valid data in 'bits', and 'ready' indicates that the consumer is ready
  * to accept the data this cycle. No requirements are placed on the signaling
  * of ready or valid.
  * @param gen the type of data to be wrapped in DecoupledIO
  */
class DecoupledIO[+T <: Data](gen: T) extends ReadyValidIO[T](gen)
```

## Related source code

### src/main/scala/lsu/dcache.scala

```scala
class BoomWritebackUnit(implicit edge: TLEdgeOut, p: Parameters) extends L1HellaCacheModule()(p) {
  val io = new Bundle {
    val req = Flipped(Decoupled(new WritebackReq(edge.bundle)))
    val meta_read = Decoupled(new L1MetaReadReq)
// ...
  val req = Reg(new WritebackReq(edge.bundle))
  val s_invalid :: s_fill_buffer :: s_lsu_release :: s_active :: s_grant :: Nil = Enum(5)
  val state = RegInit(s_invalid)
// ...
  when (state === s_invalid) {
    io.req.ready := true.B
    when (io.req.fire) {
      state := s_fill_buffer
      data_req_cnt := 0.U
      req := io.req.bits
      acked := false.B
    }
```

### src/main/scala/lsu/lsu.scala

```scala
  // We are making a local line visible to other harts
  val do_release_search = widthMap(w => fired_release(w))
```

### src/main/scala/lsu/mshrs.scala

```scala
    val prober_state = Input(Valid(UInt(coreMaxAddrBits.W)))
// ...
    io.meta_read.valid := !io.prober_state.valid || !grantack.valid || (io.prober_state.bits(untagBits-1,blockOffBits) =/= req_idx)
```

## Documentation

### docs/sections/memory-system.rst

```text
All memory requests to the Hellacache may be killed the cycle after
issuing the request (while the request is accessing the data arrays).

The current data cache design accesses the SRAMs in a single-cycle.

The cache has a three-stage pipeline and can accept a new request every cycle.
The stages do the following:

* S0: Send request address

* S1: Access SRAM

* S2: Perform way-select and format response data
```

## Additional requirement

In the cycle the metadata response arrives, use `way_en` and `block_state` only if `mshr_rdy` and `wb_rdy` are both high and otherwise read the metadata again, then for an absent or clean line transfer `lsu_release` before asserting `rep.valid` and assert `meta_write.valid` only after `rep` transfers, and for a dirty matched line transfer `wb_req` and wait for `wb_req.ready` to be high again before asserting `meta_write.valid`.
