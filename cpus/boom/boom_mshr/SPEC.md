# Implement `BoomMSHR`

Implement one complete `BoomMSHR` source-level hardware definition for the selected BOOM configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class BoomMSHR` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/common/config-mixins.scala

```scala
// DOC include start: LargeBoomConfig
/**
 * 3-wide BOOM. Try to match the Cortex-A15.
 */
class WithNLargeBooms(n: Int = 1, overrideIdOffset: Option[Int] = None) extends Config(
// ...
            core = BoomCoreParams(
              fetchWidth = 8,
              decodeWidth = 3,
              numRobEntries = 96,
// ...
            dcache = Some(
              DCacheParams(rowBits = site(SystemBusKey).beatBits, nSets=64, nWays=8, nMSHRs=4, nTLBWays=16)
            ),
// ...
    case SystemBusKey => up(SystemBusKey, site).copy(beatBytes = 16)
    case XLen => 64
  })
)
// DOC include end: LargeBoomConfig
```

### src/main/scala/common/parameters.scala

```scala
case class BoomCoreParams(
// ...
  enablePrefetching: Boolean = false,
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
import boom.util.{IsKilledByBranch, GetNewBrMask, BranchKillableQueue, IsOlder, UpdateBrMask, AgePriorityEncoder, WrapInc}
```

## Class declaration

```scala
class BoomMSHR(implicit edge: TLEdgeOut, p: Parameters) extends BoomModule()(p)
  with HasL1HellaCacheParameters
{
  val io = IO(new Bundle {
    val id = Input(UInt())

    val req_pri_val = Input(Bool())
    val req_pri_rdy = Output(Bool())
    val req_sec_val = Input(Bool())
    val req_sec_rdy = Output(Bool())

    val clear_prefetch = Input(Bool())
    val brupdate       = Input(new BrUpdateInfo)
    val exception    = Input(Bool())
    val rob_pnr_idx  = Input(UInt(robAddrSz.W))
    val rob_head_idx = Input(UInt(robAddrSz.W))

    val req          = Input(new BoomDCacheReqInternal)
    val req_is_probe = Input(Bool())

    val idx = Output(Valid(UInt()))
    val way = Output(Valid(UInt()))
    val tag = Output(Valid(UInt()))


    val mem_acquire = Decoupled(new TLBundleA(edge.bundle))

    val mem_grant   = Flipped(Decoupled(new TLBundleD(edge.bundle)))
    val mem_finish  = Decoupled(new TLBundleE(edge.bundle))

    val prober_state = Input(Valid(UInt(coreMaxAddrBits.W)))

    val refill      = Decoupled(new L1DataWriteReq)

    val meta_write  = Decoupled(new L1MetaWriteReq)
    val meta_read   = Decoupled(new L1MetaReadReq)
    val meta_resp   = Input(Valid(new L1Metadata))
    val wb_req      = Decoupled(new WritebackReq(edge.bundle))

    // To inform the prefetcher when we are commiting the fetch of this line
    val commit_val  = Output(Bool())
    val commit_addr = Output(UInt(coreMaxAddrBits.W))
    val commit_coh  = Output(new ClientMetadata)

    // Reading from the line buffer
    val lb_read       = Decoupled(new LineBufferReadReq)
    val lb_resp       = Input(UInt(encRowBits.W))
    val lb_write      = Decoupled(new LineBufferWriteReq)

    // Replays go through the cache pipeline again
    val replay      = Decoupled(new BoomDCacheReqInternal)
    // Resp go straight out to the core
    val resp        = Decoupled(new BoomDCacheResp)

    // Writeback unit tells us when it is done processing our wb
    val wb_resp     = Input(Bool())

    val probe_rdy   = Output(Bool())
  })
```

## Parent instantiation

```scala
  // --------------------
  // The LineBuffer Data
  // Holds refilling lines, prefetched lines
  val lb = Mem(nLBEntries * cacheDataBeats, UInt(encRowBits.W))
  val lb_read_arb  = Module(new Arbiter(new LineBufferReadReq, cfg.nMSHRs))
  val lb_write_arb = Module(new Arbiter(new LineBufferWriteReq, cfg.nMSHRs))

  lb_read_arb.io.out.ready  := false.B
  lb_write_arb.io.out.ready := true.B

  val lb_read_data = WireInit(0.U(encRowBits.W))
  when (lb_write_arb.io.out.fire) {
    lb.write(lb_write_arb.io.out.bits.lb_addr, lb_write_arb.io.out.bits.data)
  } .otherwise {
    lb_read_arb.io.out.ready := true.B
    when (lb_read_arb.io.out.fire) {
      lb_read_data := lb.read(lb_read_arb.io.out.bits.lb_addr)
    }
  }
// ...
  val meta_write_arb = Module(new Arbiter(new L1MetaWriteReq           , cfg.nMSHRs))
  val meta_read_arb  = Module(new Arbiter(new L1MetaReadReq            , cfg.nMSHRs))
  val wb_req_arb     = Module(new Arbiter(new WritebackReq(edge.bundle), cfg.nMSHRs))
  val replay_arb     = Module(new Arbiter(new BoomDCacheReqInternal    , cfg.nMSHRs))
  val resp_arb       = Module(new Arbiter(new BoomDCacheResp           , cfg.nMSHRs + nIOMSHRs))
  val refill_arb     = Module(new Arbiter(new L1DataWriteReq           , cfg.nMSHRs))
// ...
  var sec_rdy   = false.B

  io.fence_rdy := true.B
  io.probe_rdy := true.B
  io.mem_grant.ready := false.B

  val mshr_alloc_idx = Wire(UInt())
  val pri_rdy = WireInit(false.B)
  val pri_val = req.valid && sdq_rdy && cacheable && !idx_match(req_idx)
  val mshrs = (0 until cfg.nMSHRs) map { i =>
    val mshr = Module(new BoomMSHR)
    mshr.io.id := i.U(log2Ceil(cfg.nMSHRs).W)

    for (w <- 0 until memWidth) {
      idx_matches(w)(i) := mshr.io.idx.valid && mshr.io.idx.bits === io.req(w).bits.addr(untagBits-1,blockOffBits)
      tag_matches(w)(i) := mshr.io.tag.valid && mshr.io.tag.bits === io.req(w).bits.addr >> untagBits
      way_matches(w)(i) := mshr.io.way.valid && mshr.io.way.bits === io.req(w).bits.way_en
    }
    wb_tag_list(i) := mshr.io.wb_req.bits.tag



    mshr.io.req_pri_val  := (i.U === mshr_alloc_idx) && pri_val
    when (i.U === mshr_alloc_idx) {
      pri_rdy := mshr.io.req_pri_rdy
    }

    mshr.io.req_sec_val  := req.valid && sdq_rdy && tag_match(req_idx) && idx_matches(req_idx)(i) && cacheable
    mshr.io.req          := req.bits
    mshr.io.req_is_probe := req_is_probe
    mshr.io.req.sdq_id   := sdq_alloc_id
// ...
    mshr.io.brupdate       := io.brupdate
    mshr.io.exception    := io.exception
    mshr.io.rob_pnr_idx  := io.rob_pnr_idx
    mshr.io.rob_head_idx := io.rob_head_idx

    mshr.io.prober_state := io.prober_state

    mshr.io.wb_resp      := io.wb_resp

    meta_write_arb.io.in(i) <> mshr.io.meta_write
    meta_read_arb.io.in(i)  <> mshr.io.meta_read
    mshr.io.meta_resp       := io.meta_resp
    wb_req_arb.io.in(i)     <> mshr.io.wb_req
    replay_arb.io.in(i)     <> mshr.io.replay
    refill_arb.io.in(i)     <> mshr.io.refill

    lb_read_arb.io.in(i)       <> mshr.io.lb_read
    mshr.io.lb_resp            := lb_read_data
    lb_write_arb.io.in(i)      <> mshr.io.lb_write
// ...
    mshr.io.mem_grant.valid := false.B
    mshr.io.mem_grant.bits  := DontCare
    when (io.mem_grant.bits.source === i.U) {
      mshr.io.mem_grant <> io.mem_grant
    }

    sec_rdy   = sec_rdy || (mshr.io.req_sec_rdy && mshr.io.req_sec_val)
    resp_arb.io.in(i) <> mshr.io.resp

    when (!mshr.io.req_pri_rdy) {
      io.fence_rdy := false.B
    }
    for (w <- 0 until memWidth) {
      when (!mshr.io.probe_rdy && idx_matches(w)(i) && io.req_is_probe(w)) {
        io.probe_rdy := false.B
      }
    }

    mshr
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/lsu/mshrs.scala

```scala
class BoomDCacheReqInternal(implicit p: Parameters) extends BoomDCacheReq()(p)
  with HasL1HellaCacheParameters
{
  // miss info
  val tag_match = Bool()
  val old_meta  = new L1Metadata
  val way_en    = UInt(nWays.W)

  // Used in the MSHRs
  val sdq_id    = UInt(log2Ceil(cfg.nSDQ).W)
}
// ...
class LineBufferReadReq(implicit p: Parameters) extends BoomBundle()(p)
  with HasL1HellaCacheParameters
{
  val id      = UInt(log2Ceil(nLBEntries).W)
  val offset  = UInt(log2Ceil(cacheDataBeats).W)
  def lb_addr = Cat(id, offset)
}

class LineBufferWriteReq(implicit p: Parameters) extends LineBufferReadReq()(p)
{
  val data   = UInt(encRowBits.W)
}
```

### src/main/scala/lsu/lsu.scala

```scala
class BoomDCacheReq(implicit p: Parameters) extends BoomBundle()(p)
  with HasBoomUOP
{
  val addr  = UInt(coreMaxAddrBits.W)
  val data  = Bits(coreDataBits.W)
  val is_hella = Bool() // Is this the hellacache req? If so this is not tracked in LDQ or STQ
}

class BoomDCacheResp(implicit p: Parameters) extends BoomBundle()(p)
  with HasBoomUOP
{
  val data = Bits(coreDataBits.W)
  val is_hella = Bool()
}
```

### src/main/scala/common/micro-op.scala

```scala
/**
 * Extension to BoomBundle to add a MicroOp
 */
abstract trait HasBoomUOP extends BoomBundle
{
  val uop = new MicroOp()
}

/**
 * MicroOp passing through the pipeline
 */
class MicroOp(implicit p: Parameters) extends BoomBundle
  with freechips.rocketchip.rocket.constants.MemoryOpConstants
  with freechips.rocketchip.rocket.constants.ScalarOpConstants
{
// ...
  val mem_cmd          = UInt(M_SZ.W)          // sync primitives/cache flushes
  val mem_size         = UInt(2.W)
  val mem_signed       = Bool()
  val is_fence         = Bool()
  val is_fencei        = Bool()
  val is_amo           = Bool()
  val uses_ldq         = Bool()
  val uses_stq         = Bool()
```

### src/main/scala/common/parameters.scala

```scala
  // coreWidth is width of decode, width of integer rename, width of ROB, and commit width
  val coreWidth = decodeWidth
// ...
  val numRobEntries = boomParams.numRobEntries       // number of ROB entries (e.g., 32 entries for R10k)
// ...
  val enableFastLoadUse = boomParams.enableFastLoadUse
  val enablePrefetching = boomParams.enablePrefetching
  val nLBEntries = dcacheParams.nMSHRs
// ...
  val numRobRows      = numRobEntries/coreWidth
  val robAddrSz       = log2Ceil(numRobRows) + log2Ceil(coreWidth)
```

### src/main/scala/tile/Core.scala

```scala
  val coreDataBits = xLen max fLen max vMemDataBits
  val coreDataBytes = coreDataBits/8
  def coreMaxAddrBits = paddrBits max vaddrBitsExtended
```

### src/main/scala/rocket/HellaCache.scala

```scala
    nMSHRs: Int = 1,
    nSDQ: Int = 17,
    nRPQ: Int = 16,
    nMMIOs: Int = 1,
    blockBytes: Int = 64,
// ...
trait HasL1HellaCacheParameters extends HasL1CacheParameters with HasCoreParameters {
  val cacheParams = tileParams.dcache.get
  val cfg = cacheParams

  def wordBits = coreDataBits
  def wordBytes = coreDataBytes
// ...
  def rowWords = rowBits/wordBits
// ...
  def encDataBits = cacheParams.dataCode.width(coreDataBits) // NBDCache only
  def encRowBits = encDataBits*rowWords
// ...
class L1Metadata(implicit p: Parameters) extends L1HellaCacheBundle()(p) {
  val coh = new ClientMetadata
  val tag = UInt(width = tagBits)
}

object L1Metadata {
  def apply(tag: Bits, coh: ClientMetadata)(implicit p: Parameters) = {
    val meta = Wire(new L1Metadata)
    meta.tag := tag
    meta.coh := coh
    meta
  }
}

class L1MetaReadReq(implicit p: Parameters) extends L1HellaCacheBundle()(p) {
  val idx    = UInt(width = idxBits)
  val way_en = UInt(width = nWays)
  val tag    = UInt(width = tagBits)
}

class L1MetaWriteReq(implicit p: Parameters) extends L1MetaReadReq()(p) {
  val data = new L1Metadata
}
```

### src/main/scala/tile/L1Cache.scala

```scala
  def blockOffBits = lgCacheBlockBytes
  def idxBits = log2Up(cacheParams.nSets)
  def untagBits = blockOffBits + idxBits
  def pgUntagBits = if (usingVM) untagBits min pgIdxBits else untagBits
  def tagBits = tlBundleParams.addressBits - pgUntagBits
  def nWays = cacheParams.nWays
// ...
  def rowBits = cacheParams.rowBits
  def rowBytes = rowBits/8
  def rowOffBits = log2Up(rowBytes)
// ...
  def cacheDataBits = tlBundleParams.dataBits
// ...
  def cacheDataBeats = (cacheBlockBytes * 8) / cacheDataBits
```

### src/main/scala/rocket/NBDcache.scala

```scala
class L1DataReadReq(implicit p: Parameters) extends L1HellaCacheBundle()(p) {
  val way_en = Bits(width = nWays)
  val addr   = Bits(width = untagBits)
}

class L1DataWriteReq(implicit p: Parameters) extends L1DataReadReq()(p) {
  val wmask  = Bits(width = rowWords)
  val data   = Bits(width = encRowBits)
}
// ...
class WritebackReq(params: TLBundleParameters)(implicit p: Parameters) extends L1HellaCacheBundle()(p) {
  val tag = Bits(width = tagBits)
  val idx = Bits(width = idxBits)
  val source = UInt(width = params.sourceBits)
  val param = UInt(width = TLPermissions.cWidth) 
  val way_en = Bits(width = nWays)
  val voluntary = Bool()

}
```

### src/main/scala/tilelink/Metadata.scala

```scala
/** Stores the client-side coherence information,
  * such as permissions on the data and whether the data is dirty.
  * Its API can be used to make TileLink messages in response to
  * memory operations, cache control oeprations, or Probe messages.
  */
class ClientMetadata extends Bundle {
  /** Actual state information stored in this bundle */
  val state = UInt(width = ClientStates.width)

  /** Metadata equality */
  def ===(rhs: UInt): Bool = state === rhs
  def ===(rhs: ClientMetadata): Bool = state === rhs.state
  def =/=(rhs: ClientMetadata): Bool = !this.===(rhs)

  /** Is the block's data present in this cache */
  def isValid(dummy: Int = 0): Bool = state > ClientStates.Nothing
// ...
  /** Does this cache have permissions on this block sufficient to perform op,
    * and what to do next (Acquire message param or updated metadata). */
  def onAccess(cmd: UInt): (Bool, UInt, ClientMetadata) = {
    val r = growStarter(cmd)
    (r._1, r._2, ClientMetadata(r._2))
  }

  /** Does a secondary miss on the block require another Acquire message */
  def onSecondaryAccess(first_cmd: UInt, second_cmd: UInt): (Bool, Bool, UInt, ClientMetadata, UInt) = {
    import MemoryOpCategories._
    val r1 = growStarter(first_cmd)
    val r2 = growStarter(second_cmd)
    val needs_second_acq = isWriteIntent(second_cmd) && !isWriteIntent(first_cmd)
    val hit_again = r1._1 && r2._1
    val dirties = categorize(second_cmd) === wr
    val biggest_grow_param = Mux(dirties, r2._2, r1._2)
    val dirtiest_state = ClientMetadata(biggest_grow_param)
    val dirtiest_cmd = Mux(dirties, second_cmd, first_cmd)
    (needs_second_acq, hit_again, biggest_grow_param, dirtiest_state, dirtiest_cmd)
  }

  /** Metadata change on a returned Grant */
  def onGrant(cmd: UInt, param: UInt): ClientMetadata = ClientMetadata(growFinisher(cmd, param))
// ...
  /** Translate cache control cmds into Probe param */
  private def cmdToPermCap(cmd: UInt): UInt = {
    import MemoryOpCategories._
    import TLPermissions._
    MuxLookup(cmd, toN, Seq(
      M_FLUSH   -> toN,
      M_PRODUCE -> toB,
      M_CLEAN   -> toT))
  }

  def onCacheControl(cmd: UInt): (Bool, UInt, ClientMetadata) = {
    val r = shrinkHelper(cmdToPermCap(cmd))
    (r._1, r._2, ClientMetadata(r._3))
  }
// ...
/** Factories for ClientMetadata, including on reset */
object ClientMetadata {
  def apply(perm: UInt) = {
    val meta = Wire(new ClientMetadata)
    meta.state := perm
    meta
  }
  def onReset = ClientMetadata(ClientStates.Nothing)
  def maximum = ClientMetadata(ClientStates.Dirty)
```

### src/main/scala/tilelink/Edges.scala

```scala
  def isRequest(x: TLChannel): Bool = {
    x match {
      case a: TLBundleA => Bool(true)
      case b: TLBundleB => Bool(true)
      case c: TLBundleC => c.opcode(2) && c.opcode(1)
        //    opcode === TLMessages.Release ||
        //    opcode === TLMessages.ReleaseData
      case d: TLBundleD => d.opcode(2) && !d.opcode(1)
        //    opcode === TLMessages.Grant     ||
        //    opcode === TLMessages.GrantData
      case e: TLBundleE => Bool(false)
    }
  }
// ...
  def hasData(x: TLChannel): Bool = {
    val opdata = x match {
      case a: TLBundleA => !a.opcode(2)
        //    opcode === TLMessages.PutFullData    ||
        //    opcode === TLMessages.PutPartialData ||
        //    opcode === TLMessages.ArithmeticData ||
        //    opcode === TLMessages.LogicalData
      case b: TLBundleB => !b.opcode(2)
        //    opcode === TLMessages.PutFullData    ||
        //    opcode === TLMessages.PutPartialData ||
        //    opcode === TLMessages.ArithmeticData ||
        //    opcode === TLMessages.LogicalData
      case c: TLBundleC => c.opcode(0)
        //    opcode === TLMessages.AccessAckData ||
        //    opcode === TLMessages.ProbeAckData  ||
        //    opcode === TLMessages.ReleaseData
      case d: TLBundleD => d.opcode(0)
        //    opcode === TLMessages.AccessAckData ||
        //    opcode === TLMessages.GrantData
      case e: TLBundleE => Bool(false)
    }
    staticHasData(x).map(Bool(_)).getOrElse(opdata)
  }
// ...
  def firstlastHelper(bits: TLChannel, fire: Bool): (Bool, Bool, Bool, UInt) = {
    val beats1   = numBeats1(bits)
    val counter  = RegInit(UInt(0, width = log2Up(maxTransfer / manager.beatBytes)))
    val counter1 = counter - UInt(1)
    val first = counter === UInt(0)
    val last  = counter === UInt(1) || beats1 === UInt(0)
    val done  = last && fire
    val count = (beats1 & ~counter1)
    when (fire) {
      counter := Mux(first, beats1, counter1)
    }
    (first, last, done, count)
  }

  def first(bits: TLChannel, fire: Bool): Bool = firstlastHelper(bits, fire)._1
  def first(x: DecoupledIO[TLChannel]): Bool = first(x.bits, x.fire())
  def first(x: ValidIO[TLChannel]): Bool = first(x.bits, x.valid)

  def last(bits: TLChannel, fire: Bool): Bool = firstlastHelper(bits, fire)._2
  def last(x: DecoupledIO[TLChannel]): Bool = last(x.bits, x.fire())
  def last(x: ValidIO[TLChannel]): Bool = last(x.bits, x.valid)

  def done(bits: TLChannel, fire: Bool): Bool = firstlastHelper(bits, fire)._3
  def done(x: DecoupledIO[TLChannel]): Bool = done(x.bits, x.fire())
  def done(x: ValidIO[TLChannel]): Bool = done(x.bits, x.valid)

  def firstlast(bits: TLChannel, fire: Bool): (Bool, Bool, Bool) = {
    val r = firstlastHelper(bits, fire)
    (r._1, r._2, r._3)
  }
  def firstlast(x: DecoupledIO[TLChannel]): (Bool, Bool, Bool) = firstlast(x.bits, x.fire())
  def firstlast(x: ValidIO[TLChannel]): (Bool, Bool, Bool) = firstlast(x.bits, x.valid)

  def count(bits: TLChannel, fire: Bool): (Bool, Bool, Bool, UInt) = {
    val r = firstlastHelper(bits, fire)
    (r._1, r._2, r._3, r._4)
  }
  def count(x: DecoupledIO[TLChannel]): (Bool, Bool, Bool, UInt) = count(x.bits, x.fire())
  def count(x: ValidIO[TLChannel]): (Bool, Bool, Bool, UInt) = count(x.bits, x.valid)

  def addr_inc(bits: TLChannel, fire: Bool): (Bool, Bool, Bool, UInt) = {
    val r = firstlastHelper(bits, fire)
    (r._1, r._2, r._3, r._4 << log2Ceil(manager.beatBytes))
  }
  def addr_inc(x: DecoupledIO[TLChannel]): (Bool, Bool, Bool, UInt) = addr_inc(x.bits, x.fire())
  def addr_inc(x: ValidIO[TLChannel]): (Bool, Bool, Bool, UInt) = addr_inc(x.bits, x.valid)
// ...
  def AcquireBlock(fromSource: UInt, toAddress: UInt, lgSize: UInt, growPermissions: UInt) = {
    require (manager.anySupportAcquireB, s"TileLink: No managers visible from this edge support Acquires, but one of these clients would try to request one: ${client.clients}")
    val legal = manager.supportsAcquireBFast(toAddress, lgSize)
    val a = Wire(new TLBundleA(bundle))
    a.opcode  := TLMessages.AcquireBlock
    a.param   := growPermissions
    a.size    := lgSize
    a.source  := fromSource
    a.address := toAddress
    a.mask    := mask(toAddress, lgSize)
    a.data    := UInt(0)
    a.corrupt := Bool(false)
    (legal, a)
  }
// ...
  def GrantAck(d: TLBundleD): TLBundleE = GrantAck(d.sink)
  def GrantAck(toSink: UInt): TLBundleE = {
    val e = Wire(new TLBundleE(bundle))
    e.sink := toSink
    e
  }
```

### src/main/scala/tilelink/Bundles.scala

```scala
final class TLBundleD(params: TLBundleParameters)
  extends TLBundleBase(params) with TLDataChannel
{
  val channelName = "'D' channel"
  // fixed fields during multibeat:
  val opcode  = UInt(width = 3)
  val param   = UInt(width = TLPermissions.bdWidth) // cap perms
  val size    = UInt(width = params.sizeBits)
  val source  = UInt(width = params.sourceBits) // to
  val sink    = UInt(width = params.sinkBits)   // from
  val denied  = Bool() // implies corrupt iff *Data
  val user    = BundleMap(params.responseFields)
  val echo    = BundleMap(params.echoFields)
  // variable fields during multibeat:
  val data    = UInt(width = params.dataBits)
  val corrupt = Bool() // only applies to *Data messages
}

final class TLBundleE(params: TLBundleParameters)
  extends TLBundleBase(params) with TLChannel
{
  val channelName = "'E' channel"
  val sink = UInt(width = params.sinkBits) // to
}
```

### src/main/scala/rocket/Consts.scala

```scala
trait MemoryOpConstants {
  val NUM_XA_OPS = 9
  val M_SZ      = 5
  def M_X       = BitPat("b?????");
  def M_XRD     = UInt("b00000"); // int load
  def M_XWR     = UInt("b00001"); // int store
  def M_PFR     = UInt("b00010"); // prefetch with intent to read
  def M_PFW     = UInt("b00011"); // prefetch with intent to write
  def M_XA_SWAP = UInt("b00100");
  def M_FLUSH_ALL = UInt("b00101")  // flush all lines
  def M_XLR     = UInt("b00110");
  def M_XSC     = UInt("b00111");
  def M_XA_ADD  = UInt("b01000");
  def M_XA_XOR  = UInt("b01001");
  def M_XA_OR   = UInt("b01010");
  def M_XA_AND  = UInt("b01011");
  def M_XA_MIN  = UInt("b01100");
  def M_XA_MAX  = UInt("b01101");
  def M_XA_MINU = UInt("b01110");
  def M_XA_MAXU = UInt("b01111");
  def M_FLUSH   = UInt("b10000") // write back dirty data and cede R/W permissions
  def M_PWR     = UInt("b10001") // partial (masked) store
  def M_PRODUCE = UInt("b10010") // write back dirty data and cede W permissions
  def M_CLEAN   = UInt("b10011") // write back dirty data and retain R/W permissions
  def M_SFENCE  = UInt("b10100") // SFENCE.VMA
  def M_HFENCEV = UInt("b10101") // HFENCE.VVMA
  def M_HFENCEG = UInt("b10110") // HFENCE.GVMA
  def M_WOK     = UInt("b10111") // check write permissions but don't perform a write
  def M_HLVX    = UInt("b10000") // HLVX instruction

  def isAMOLogical(cmd: UInt) = cmd.isOneOf(M_XA_SWAP, M_XA_XOR, M_XA_OR, M_XA_AND)
  def isAMOArithmetic(cmd: UInt) = cmd.isOneOf(M_XA_ADD, M_XA_MIN, M_XA_MAX, M_XA_MINU, M_XA_MAXU)
  def isAMO(cmd: UInt) = isAMOLogical(cmd) || isAMOArithmetic(cmd)
  def isPrefetch(cmd: UInt) = cmd === M_PFR || cmd === M_PFW
  def isRead(cmd: UInt) = cmd.isOneOf(M_XRD, M_HLVX, M_XLR, M_XSC) || isAMO(cmd)
  def isWrite(cmd: UInt) = cmd === M_XWR || cmd === M_PWR || cmd === M_XSC || isAMO(cmd)
  def isWriteIntent(cmd: UInt) = isWrite(cmd) || cmd === M_PFW || cmd === M_XLR
```

### src/main/scala/rocket/AMOALU.scala

```scala
class StoreGen(typ: UInt, addr: UInt, dat: UInt, maxSize: Int) {
  val size = typ(log2Up(log2Up(maxSize)+1)-1,0)
  def misaligned =
    (addr & ((UInt(1) << size) - UInt(1))(log2Up(maxSize)-1,0)).orR

  def mask = {
    var res = UInt(1)
    for (i <- 0 until log2Up(maxSize)) {
      val upper = Mux(addr(i), res, UInt(0)) | Mux(size >= UInt(i+1), UInt((BigInt(1) << (1 << i))-1), UInt(0))
      val lower = Mux(addr(i), UInt(0), res)
      res = Cat(upper, lower)
    }
    res
  }

  protected def genData(i: Int): UInt =
    if (i >= log2Up(maxSize)) dat
    else Mux(size === UInt(i), Fill(1 << (log2Up(maxSize)-i), dat((8 << i)-1,0)), genData(i+1))

  def data = genData(0)
  def wordData = genData(2)
}

class LoadGen(typ: UInt, signed: Bool, addr: UInt, dat: UInt, zero: Bool, maxSize: Int) {
  private val size = new StoreGen(typ, addr, dat, maxSize).size

  private def genData(logMinSize: Int): UInt = {
    var res = dat
    for (i <- log2Up(maxSize)-1 to logMinSize by -1) {
      val pos = 8 << i
      val shifted = Mux(addr(i), res(2*pos-1,pos), res(pos-1,0))
      val doZero = Bool(i == 0) && zero
      val zeroed = Mux(doZero, UInt(0), shifted)
      res = Cat(Mux(size === UInt(i) || doZero, Fill(8*maxSize-pos, signed && zeroed(pos-1)), res(8*maxSize-1,pos)), zeroed)
    }
    res
  }

  def wordData = genData(2)
  def data = genData(0)
}
```

### src/main/scala/util/util.scala

```scala
/**
 * Create a queue that can be killed with a branch kill signal.
 * Assumption: enq.valid only high if not killed by branch (so don't check IsKilled on io.enq).
 */
class BranchKillableQueue[T <: boom.common.HasBoomUOP](gen: T, entries: Int, flush_fn: boom.common.MicroOp => Bool = u => true.B, flow: Boolean = true)
  (implicit p: freechips.rocketchip.config.Parameters)
  extends boom.common.BoomModule()(p)
  with boom.common.HasBoomCoreParameters
{
  val io = IO(new Bundle {
    val enq     = Flipped(Decoupled(gen))
    val deq     = Decoupled(gen)

    val brupdate  = Input(new BrUpdateInfo())
    val flush   = Input(Bool())

    val empty   = Output(Bool())
    val count   = Output(UInt(log2Ceil(entries).W))
  })
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
  // ------------
  // MSHR Replays
  val replay_req = Wire(Vec(memWidth, new BoomDCacheReq))
  replay_req               := DontCare
  replay_req(0).uop        := mshrs.io.replay.bits.uop
  replay_req(0).addr       := mshrs.io.replay.bits.addr
  replay_req(0).data       := mshrs.io.replay.bits.data
  replay_req(0).is_hella   := mshrs.io.replay.bits.is_hella
  mshrs.io.replay.ready    := metaReadArb.io.in(0).ready && dataReadArb.io.in(0).ready
  // Tag read for MSHR replays
  // We don't actually need to read the metadata, for replays we already know our way
  metaReadArb.io.in(0).valid              := mshrs.io.replay.valid
  metaReadArb.io.in(0).bits.req(0).idx    := mshrs.io.replay.bits.addr >> blockOffBits
  metaReadArb.io.in(0).bits.req(0).way_en := DontCare
  metaReadArb.io.in(0).bits.req(0).tag    := DontCare
  // Data read for MSHR replays
  dataReadArb.io.in(0).valid              := mshrs.io.replay.valid
  dataReadArb.io.in(0).bits.req(0).addr   := mshrs.io.replay.bits.addr
  dataReadArb.io.in(0).bits.req(0).way_en := mshrs.io.replay.bits.way_en
  dataReadArb.io.in(0).bits.valid         := widthMap(w => (w == 0).B)

  // -----------
  // MSHR Meta read
  val mshr_read_req = Wire(Vec(memWidth, new BoomDCacheReq))
  mshr_read_req             := DontCare
  mshr_read_req(0).uop      := NullMicroOp
  mshr_read_req(0).addr     := Cat(mshrs.io.meta_read.bits.tag, mshrs.io.meta_read.bits.idx) << blockOffBits
  mshr_read_req(0).data     := DontCare
  mshr_read_req(0).is_hella := false.B
  metaReadArb.io.in(3).valid       := mshrs.io.meta_read.valid
  metaReadArb.io.in(3).bits.req(0) := mshrs.io.meta_read.bits
  mshrs.io.meta_read.ready         := metaReadArb.io.in(3).ready
// ...
  // replacement policy
  val replacer = cacheParams.replacement
  val s1_replaced_way_en = UIntToOH(replacer.way)
  val s2_replaced_way_en = UIntToOH(RegNext(replacer.way))
  val s2_repl_meta = widthMap(i => Mux1H(s2_replaced_way_en, wayMap((w: Int) => RegNext(meta(i).io.resp(w))).toSeq))

  // nack because of incoming probe
  val s2_nack_hit    = RegNext(VecInit(s1_nack))
  // Nack when we hit something currently being evicted
  val s2_nack_victim = widthMap(w => s2_valid(w) &&  s2_hit(w) && mshrs.io.secondary_miss(w))
  // MSHRs not ready for request
  val s2_nack_miss   = widthMap(w => s2_valid(w) && !s2_hit(w) && !mshrs.io.req(w).ready)
  // Bank conflict on data arrays
  val s2_nack_data   = widthMap(w => data.io.nacks(w))
  // Can't allocate MSHR for same set currently being written back
  val s2_nack_wb     = widthMap(w => s2_valid(w) && !s2_hit(w) && s2_wb_idx_matches(w))

  s2_nack           := widthMap(w => (s2_nack_miss(w) || s2_nack_hit(w) || s2_nack_victim(w) || s2_nack_data(w) || s2_nack_wb(w)) && s2_type =/= t_replay)
  val s2_send_resp = widthMap(w => (RegNext(s1_send_resp_or_nack(w)) && !s2_nack(w) &&
                      (s2_hit(w) || (mshrs.io.req(w).fire && isWrite(s2_req(w).uop.mem_cmd) && !isRead(s2_req(w).uop.mem_cmd)))))
  val s2_send_nack = widthMap(w => (RegNext(s1_send_resp_or_nack(w)) && s2_nack(w)))
  for (w <- 0 until memWidth)
    assert(!(s2_send_resp(w) && s2_send_nack(w)))

  // hits always send a response
  // If MSHR is not available, LSU has to replay this request later
  // If MSHR is available and this is only a store(not a amo), we don't need to wait for resp later
  s2_store_failed := s2_valid(0) && s2_nack(0) && s2_send_nack(0) && s2_req(0).uop.uses_stq

  // Miss handling
  for (w <- 0 until memWidth) {
    mshrs.io.req(w).valid := s2_valid(w)          &&
                            !s2_hit(w)            &&
                            !s2_nack_hit(w)       &&
                            !s2_nack_victim(w)    &&
                            !s2_nack_data(w)      &&
                            !s2_nack_wb(w)        &&
                             s2_type.isOneOf(t_lsu, t_prefetch)             &&
                            !IsKilledByBranch(io.lsu.brupdate, s2_req(w).uop) &&
                            !(io.lsu.exception && s2_req(w).uop.uses_ldq)   &&
                             (isPrefetch(s2_req(w).uop.mem_cmd) ||
                              isRead(s2_req(w).uop.mem_cmd)     ||
                              isWrite(s2_req(w).uop.mem_cmd))
    assert(!(mshrs.io.req(w).valid && s2_type === t_replay), "Replays should not need to go back into MSHRs")
    mshrs.io.req(w).bits             := DontCare
    mshrs.io.req(w).bits.uop         := s2_req(w).uop
    mshrs.io.req(w).bits.uop.br_mask := GetNewBrMask(io.lsu.brupdate, s2_req(w).uop)
    mshrs.io.req(w).bits.addr        := s2_req(w).addr
    mshrs.io.req(w).bits.tag_match   := s2_tag_match(w)
    mshrs.io.req(w).bits.old_meta    := Mux(s2_tag_match(w), L1Metadata(s2_repl_meta(w).tag, s2_hit_state(w)), s2_repl_meta(w))
    mshrs.io.req(w).bits.way_en      := Mux(s2_tag_match(w), s2_tag_match_way(w), s2_replaced_way_en)

    mshrs.io.req(w).bits.data        := s2_req(w).data
    mshrs.io.req(w).bits.is_hella    := s2_req(w).is_hella
    mshrs.io.req_is_probe(w)         := s2_type === t_probe && s2_valid(w)
  }

  mshrs.io.meta_resp.valid      := !s2_nack_hit(0) || prober.io.mshr_wb_rdy
  mshrs.io.meta_resp.bits       := Mux1H(s2_tag_match_way(0), RegNext(meta(0).io.resp))
  when (mshrs.io.req.map(_.fire).reduce(_||_)) { replacer.miss }
  tl_out.a <> mshrs.io.mem_acquire

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

  // refills
  when (tl_out.d.bits.source === cfg.nMSHRs.U) {
    // This should be ReleaseAck
    tl_out.d.ready := true.B
    mshrs.io.mem_grant.valid := false.B
    mshrs.io.mem_grant.bits  := DontCare
  } .otherwise {
    // This should be GrantData
    mshrs.io.mem_grant <> tl_out.d
  }

  dataWriteArb.io.in(1) <> mshrs.io.refill
  metaWriteArb.io.in(0) <> mshrs.io.meta_write

  tl_out.e <> mshrs.io.mem_finish

  // writebacks
  val wbArb = Module(new Arbiter(new WritebackReq(edge.bundle), 2))
  // 0 goes to prober, 1 goes to MSHR evictions
  wbArb.io.in(0)       <> prober.io.wb_req
  wbArb.io.in(1)       <> mshrs.io.wb_req
  wb.io.req            <> wbArb.io.out
  wb.io.data_resp       := s2_data_muxed(0)
  mshrs.io.wb_resp      := wb.io.resp
```
