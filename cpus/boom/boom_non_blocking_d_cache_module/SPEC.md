# Implement `BoomNonBlockingDCacheModule`

Implement one complete `BoomNonBlockingDCacheModule` source-level hardware definition for the selected BOOM configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class BoomNonBlockingDCacheModule` definition in a single Scala code block, with no text outside the block.

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
              issueParams = Seq(
                IssueParams(issueWidth=1, numEntries=16, iqType=IQT_MEM.litValue, dispatchWidth=3),
                IssueParams(issueWidth=3, numEntries=32, iqType=IQT_INT.litValue, dispatchWidth=3),
                IssueParams(issueWidth=1, numEntries=24, iqType=IQT_FP.litValue , dispatchWidth=3)),
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
// ...
  numDCacheBanks: Int = 1,
// ...
  val lrscCycles: Int = 80 // worst case is 14 mispredicted branches + slop
```

### src/main/scala/rocket/HellaCache.scala

```scala
case class DCacheParams(
    nSets: Int = 64,
    nWays: Int = 4,
    rowBits: Int = 64,
    subWordBits: Option[Int] = None,
    replacementPolicy: String = "random",
// ...
    tagECC: Option[String] = None,
    dataECC: Option[String] = None,
    dataECCBytes: Int = 1,
    nMSHRs: Int = 1,
// ...
    nMMIOs: Int = 1,
    blockBytes: Int = 64,
// ...
    scratch: Option[BigInt] = None) extends L1CacheParams {
// ...
  def replacement = new RandomReplacement(nWays)
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

## Parent instantiation

```scala
/**
 * Top level class wrapping a non-blocking dcache.
 *
 * @param hartid hardware thread for the cache
 */
class BoomNonBlockingDCache(staticIdForMetadataUseOnly: Int)(implicit p: Parameters) extends LazyModule
{
  private val tileParams = p(TileKey)
  protected val cfg = tileParams.dcache.get

  protected def cacheClientParameters = cfg.scratch.map(x => Seq()).getOrElse(Seq(TLMasterParameters.v1(
    name          = s"Core ${staticIdForMetadataUseOnly} DCache",
    sourceId      = IdRange(0, 1 max (cfg.nMSHRs + 1)),
    supportsProbe = TransferSizes(cfg.blockBytes, cfg.blockBytes))))

  protected def mmioClientParameters = Seq(TLMasterParameters.v1(
    name          = s"Core ${staticIdForMetadataUseOnly} DCache MMIO",
    sourceId      = IdRange(cfg.nMSHRs + 1, cfg.nMSHRs + 1 + cfg.nMMIOs),
    requestFifo   = true))

  val node = TLClientNode(Seq(TLMasterPortParameters.v1(
    cacheClientParameters ++ mmioClientParameters,
    minLatency = 1)))


  lazy val module = new BoomNonBlockingDCacheModule(this)

  def flushOnFenceI = cfg.scratch.isEmpty && !node.edges.out(0).manager.managers.forall(m => !m.supportsAcquireT || !m.executable || m.regionType >= RegionType.TRACKED || m.regionType <= RegionType.IDEMPOTENT)

  require(!tileParams.core.haveCFlush || cfg.scratch.isEmpty, "CFLUSH_D_L1 instruction requires a D$")
}
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/rocket/DCache.scala

```scala
class DCacheErrors(implicit p: Parameters) extends L1HellaCacheBundle()(p)
    with CanHaveErrors {
  val correctable = (cacheParams.tagCode.canCorrect || cacheParams.dataCode.canCorrect).option(Valid(UInt(width = paddrBits)))
  val uncorrectable = (cacheParams.tagCode.canDetect || cacheParams.dataCode.canDetect).option(Valid(UInt(width = paddrBits)))
  val bus = Valid(UInt(width = paddrBits))
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

class LSUDMemIO(implicit p: Parameters, edge: TLEdgeOut) extends BoomBundle()(p)
{
  // In LSU's dmem stage, send the request
  val req         = new DecoupledIO(Vec(memWidth, Valid(new BoomDCacheReq)))
  // In LSU's LCAM search stage, kill if order fail (or forwarding possible)
  val s1_kill     = Output(Vec(memWidth, Bool()))
  // Get a request any cycle
  val resp        = Flipped(Vec(memWidth, new ValidIO(new BoomDCacheResp)))
  // In our response stage, if we get a nack, we need to reexecute
  val nack        = Flipped(Vec(memWidth, new ValidIO(new BoomDCacheReq)))

  val brupdate       = Output(new BrUpdateInfo)
  val exception    = Output(Bool())
  val rob_pnr_idx  = Output(UInt(robAddrSz.W))
  val rob_head_idx = Output(UInt(robAddrSz.W))

  val release = Flipped(new DecoupledIO(new TLBundleC(edge.bundle)))

  // Clears prefetching MSHRs
  val force_order  = Output(Bool())
  val ordered     = Input(Bool())

  val perf = Input(new Bundle {
    val acquire = Bool()
    val release = Bool()
  })

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
  val br_mask          = UInt(maxBrCount.W)  // which branches are we being speculated under?
  val br_tag           = UInt(brTagSz.W)
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

### src/main/scala/exu/execution-units/functional-unit.scala

```scala
class BrUpdateInfo(implicit p: Parameters) extends BoomBundle
{
  // On the first cycle we get masks to kill registers
  val b1 = new BrUpdateMasks
  // On the second cycle we get indices to reset pointers
  val b2 = new BrResolutionInfo
}

class BrUpdateMasks(implicit p: Parameters) extends BoomBundle
{
  val resolve_mask = UInt(maxBrCount.W)
  val mispredict_mask = UInt(maxBrCount.W)
```

### src/main/scala/lsu/dcache.scala

```scala
class BoomWritebackUnit(implicit edge: TLEdgeOut, p: Parameters) extends L1HellaCacheModule()(p) {
  val io = new Bundle {
    val req = Flipped(Decoupled(new WritebackReq(edge.bundle)))
    val meta_read = Decoupled(new L1MetaReadReq)
    val resp = Output(Bool())
    val idx = Output(Valid(UInt()))
    val data_req = Decoupled(new L1DataReadReq)
    val data_resp = Input(UInt(encRowBits.W))
    val mem_grant = Input(Bool())
    val release = Decoupled(new TLBundleC(edge.bundle))
    val lsu_release = Decoupled(new TLBundleC(edge.bundle))
  }
// ...
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
// ...
class BoomL1MetaReadReq(implicit p: Parameters) extends BoomBundle()(p) {
  val req = Vec(memWidth, new L1MetaReadReq)
}

class BoomL1DataReadReq(implicit p: Parameters) extends BoomBundle()(p) {
  val req = Vec(memWidth, new L1DataReadReq)
  val valid = Vec(memWidth, Bool())
}

abstract class AbstractBoomDataArray(implicit p: Parameters) extends BoomModule with HasL1HellaCacheParameters {
  val io = IO(new BoomBundle {
    val read  = Input(Vec(memWidth, Valid(new L1DataReadReq)))
    val write = Input(Valid(new L1DataWriteReq))
    val resp  = Output(Vec(memWidth, Vec(nWays, Bits(encRowBits.W))))
    val nacks = Output(Vec(memWidth, Bool()))
  })

  def pipeMap[T <: Data](f: Int => T) = VecInit((0 until memWidth).map(f))

}

class BoomDuplicatedDataArray(implicit p: Parameters) extends AbstractBoomDataArray
{
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
class BoomMSHRFile(implicit edge: TLEdgeOut, p: Parameters) extends BoomModule()(p)
  with HasL1HellaCacheParameters
{
  val io = IO(new Bundle {
    val req  = Flipped(Vec(memWidth, Decoupled(new BoomDCacheReqInternal))) // Req from s2 of DCache pipe
    val req_is_probe = Input(Vec(memWidth, Bool()))
    val resp = Decoupled(new BoomDCacheResp)
    val secondary_miss = Output(Vec(memWidth, Bool()))
    val block_hit = Output(Vec(memWidth, Bool()))

    val brupdate       = Input(new BrUpdateInfo)
    val exception    = Input(Bool())
    val rob_pnr_idx  = Input(UInt(robAddrSz.W))
    val rob_head_idx = Input(UInt(robAddrSz.W))

    val mem_acquire  = Decoupled(new TLBundleA(edge.bundle))
    val mem_grant    = Flipped(Decoupled(new TLBundleD(edge.bundle)))
    val mem_finish   = Decoupled(new TLBundleE(edge.bundle))

    val refill     = Decoupled(new L1DataWriteReq)
    val meta_write = Decoupled(new L1MetaWriteReq)
    val meta_read  = Decoupled(new L1MetaReadReq)
    val meta_resp  = Input(Valid(new L1Metadata))
    val replay     = Decoupled(new BoomDCacheReqInternal)
    val prefetch   = Decoupled(new BoomDCacheReq)
    val wb_req     = Decoupled(new WritebackReq(edge.bundle))

    val prober_state = Input(Valid(UInt(coreMaxAddrBits.W)))

    val clear_all = Input(Bool()) // Clears all uncommitted MSHRs to prepare for fence

    val wb_resp   = Input(Bool())

    val fence_rdy = Output(Bool())
    val probe_rdy = Output(Bool())
  })
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
```

### src/main/scala/rocket/HellaCache.scala

```scala
trait HasL1HellaCacheParameters extends HasL1CacheParameters with HasCoreParameters {
  val cacheParams = tileParams.dcache.get
  val cfg = cacheParams

  def wordBits = coreDataBits
  def wordBytes = coreDataBytes
// ...
  def wordOffBits = log2Up(wordBytes)
// ...
  def idxMSB = untagBits-1
  def idxLSB = blockOffBits
  def offsetmsb = idxLSB-1
  def offsetlsb = wordOffBits
  def rowWords = rowBits/wordBits
// ...
  def encDataBits = cacheParams.dataCode.width(coreDataBits) // NBDCache only
  def encRowBits = encDataBits*rowWords
  def lrscCycles = coreParams.lrscCycles // ISA requires 16-insn LRSC sequences to succeed
  def lrscBackoff = 3 // disallow LRSC reacquisition briefly
  def blockProbeAfterGrantCycles = 8 // give the processor some time to issue a request after a grant
  def nIOMSHRs = cacheParams.nMMIOs
// ...
/** Metadata array used for all HellaCaches */

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

class L1MetadataArray[T <: L1Metadata](onReset: () => T)(implicit p: Parameters) extends L1HellaCacheModule()(p) {
  val rstVal = onReset()
  val io = new Bundle {
    val read = Decoupled(new L1MetaReadReq).flip
    val write = Decoupled(new L1MetaWriteReq).flip
    val resp = Vec(nWays, rstVal.cloneType).asOutput
```

### src/main/scala/tilelink/Metadata.scala

```scala
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

  /** Determine whether this cmd misses, and the new state (on hit) or param to be sent (on miss) */
  private def growStarter(cmd: UInt): (Bool, UInt) = {
    import MemoryOpCategories._
    import TLPermissions._
    import ClientStates._
    val c = categorize(cmd)
    MuxTLookup(Cat(c, state), (Bool(false), UInt(0)), Seq(
    //(effect, am now) -> (was a hit,   next)
      Cat(rd, Dirty)   -> (Bool(true),  Dirty),
      Cat(rd, Trunk)   -> (Bool(true),  Trunk),
      Cat(rd, Branch)  -> (Bool(true),  Branch),
      Cat(wi, Dirty)   -> (Bool(true),  Dirty),
      Cat(wi, Trunk)   -> (Bool(true),  Trunk),
      Cat(wr, Dirty)   -> (Bool(true),  Dirty),
      Cat(wr, Trunk)   -> (Bool(true),  Dirty),
    //(effect, am now) -> (was a miss,  param)
      Cat(rd, Nothing) -> (Bool(false), NtoB),
      Cat(wi, Branch)  -> (Bool(false), BtoT),
      Cat(wi, Nothing) -> (Bool(false), NtoT),
      Cat(wr, Branch)  -> (Bool(false), BtoT),
      Cat(wr, Nothing) -> (Bool(false), NtoT)))
  }
// ...
  /** Does this cache have permissions on this block sufficient to perform op,
    * and what to do next (Acquire message param or updated metadata). */
  def onAccess(cmd: UInt): (Bool, UInt, ClientMetadata) = {
    val r = growStarter(cmd)
    (r._1, r._2, ClientMetadata(r._2))
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
// ...
  def M_HLVX    = UInt("b10000") // HLVX instruction

  def isAMOLogical(cmd: UInt) = cmd.isOneOf(M_XA_SWAP, M_XA_XOR, M_XA_OR, M_XA_AND)
  def isAMOArithmetic(cmd: UInt) = cmd.isOneOf(M_XA_ADD, M_XA_MIN, M_XA_MAX, M_XA_MINU, M_XA_MAXU)
  def isAMO(cmd: UInt) = isAMOLogical(cmd) || isAMOArithmetic(cmd)
  def isPrefetch(cmd: UInt) = cmd === M_PFR || cmd === M_PFW
  def isRead(cmd: UInt) = cmd.isOneOf(M_XRD, M_HLVX, M_XLR, M_XSC) || isAMO(cmd)
  def isWrite(cmd: UInt) = cmd === M_XWR || cmd === M_PWR || cmd === M_XSC || isAMO(cmd)
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
// ...
class AMOALU(operandBits: Int)(implicit p: Parameters) extends Module {
  val minXLen = 32
  val widths = (0 to log2Ceil(operandBits / minXLen)).map(minXLen << _)

  val io = new Bundle {
    val mask = UInt(INPUT, operandBits/8)
    val cmd = Bits(INPUT, M_SZ)
    val lhs = Bits(INPUT, operandBits)
    val rhs = Bits(INPUT, operandBits)
    val out = Bits(OUTPUT, operandBits)
    val out_unmasked = Bits(OUTPUT, operandBits)
  }
```

### src/main/scala/common/parameters.scala

```scala
trait HasBoomCoreParameters extends freechips.rocketchip.tile.HasCoreParameters
{
// ...
  val issueParams: Seq[IssueParams] = boomParams.issueParams
// ...
  val memIssueParam = issueParams.find(_.iqType == IQT_MEM.litValue).get

  val intWidth = intIssueParam.issueWidth
  val memWidth = memIssueParam.issueWidth
// ...
  val dcacheParams: DCacheParams = tileParams.dcache.get
// ...
  val enableFastLoadUse = boomParams.enableFastLoadUse
  val enablePrefetching = boomParams.enablePrefetching
```

### src/main/scala/tile/L1Cache.scala

```scala
  def nSets = cacheParams.nSets
  def blockOffBits = lgCacheBlockBytes
  def idxBits = log2Up(cacheParams.nSets)
  def untagBits = blockOffBits + idxBits
  def pgUntagBits = if (usingVM) untagBits min pgIdxBits else untagBits
  def tagBits = tlBundleParams.addressBits - pgUntagBits
  def nWays = cacheParams.nWays
  def wayBits = log2Up(nWays)
  def isDM = nWays == 1
  def rowBits = cacheParams.rowBits
  def rowBytes = rowBits/8
  def rowOffBits = log2Up(rowBytes)
// ...
  def cacheDataBits = tlBundleParams.dataBits
  def cacheDataBytes = cacheDataBits / 8
  def cacheDataBeats = (cacheBlockBytes * 8) / cacheDataBits
  def refillCycles = cacheDataBeats
```

### src/main/scala/tile/Core.scala

```scala
  val coreDataBits = xLen max fLen max vMemDataBits
  val coreDataBytes = coreDataBits/8
  def coreMaxAddrBits = paddrBits max vaddrBitsExtended
```

### src/main/scala/util/Replacement.scala

```scala
abstract class ReplacementPolicy {
  def nBits: Int
  def perSet: Boolean
  def way: UInt
  def miss: Unit
  def hit: Unit
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
// ...
/** Hardware module that is used to sequence n producers into 1 consumer.
  * Priority is given to lower producer.
  *
  * @param gen data type
  * @param n number of inputs
  *
  * @example {{{
  * val arb = Module(new Arbiter(UInt(), 2))
  * arb.io.in(0) <> producer0.io.out
  * arb.io.in(1) <> producer1.io.out
  * consumer.io.in <> arb.io.out
  * }}}
  */
@chiselName
class Arbiter[T <: Data](val gen: T, val n: Int) extends Module {
  val io = IO(new ArbiterIO(gen, n))
```

### src/main/scala/util/util.scala

```scala
/**
 * Object to check if MicroOp was killed due to a branch mispredict.
 * Uses "Fast" branch masks
 */
object IsKilledByBranch
{
  def apply(brupdate: BrUpdateInfo, uop: MicroOp): Bool = {
    return maskMatch(brupdate.b1.mispredict_mask, uop.br_mask)
  }

  def apply(brupdate: BrUpdateInfo, uop_mask: UInt): Bool = {
    return maskMatch(brupdate.b1.mispredict_mask, uop_mask)
  }
}
// ...
/**
 * Object to return a BR mask given a MicroOp mask and old BR mask.
 */
object GetNewBrMask
{
   def apply(brupdate: BrUpdateInfo, uop: MicroOp): UInt = {
     return uop.br_mask & ~brupdate.b1.resolve_mask
   }

   def apply(brupdate: BrUpdateInfo, br_mask: UInt): UInt = {
     return br_mask & ~brupdate.b1.resolve_mask
   }
}
// ...
object UpdateBrMask
{
  def apply(brupdate: BrUpdateInfo, uop: MicroOp): MicroOp = {
    val out = WireInit(uop)
    out.br_mask := GetNewBrMask(brupdate, uop)
    out
  }
  def apply[T <: boom.common.HasBoomUOP](brupdate: BrUpdateInfo, bundle: T): T = {
    val out = WireInit(bundle)
    out.uop.br_mask := GetNewBrMask(brupdate, bundle.uop.br_mask)
    out
  }
  def apply[T <: boom.common.HasBoomUOP](brupdate: BrUpdateInfo, bundle: Valid[T]): Valid[T] = {
    val out = WireInit(bundle)
    out.bits.uop.br_mask := GetNewBrMask(brupdate, bundle.bits.uop.br_mask)
    out.valid := bundle.valid && !IsKilledByBranch(brupdate, bundle.bits.uop.br_mask)
    out
  }
```

### src/main/scala/tilelink/Edges.scala

```scala
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
// ...
  def done(bits: TLChannel, fire: Bool): Bool = firstlastHelper(bits, fire)._3
  def done(x: DecoupledIO[TLChannel]): Bool = done(x.bits, x.fire())
  def done(x: ValidIO[TLChannel]): Bool = done(x.bits, x.valid)
```

### src/main/scala/tilelink/Arbiter.scala

```scala
object TLArbiter
{
  // (valids, select) => readys
  type Policy = (Integer, UInt, Bool) => UInt

  val lowestIndexFirst: Policy = (width, valids, select) => ~(leftOR(valids) << 1)(width-1, 0)
// ...
  def lowest[T <: TLChannel](edge: TLEdge, sink: DecoupledIO[T], sources: DecoupledIO[T]*): Unit = {
    apply(lowestIndexFirst)(sink, sources.toList.map(s => (edge.numBeats1(s.bits), s)):_*)
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
```

## Related source code

### src/main/scala/lsu/dcache.scala

```scala
class BoomWritebackUnit(implicit edge: TLEdgeOut, p: Parameters) extends L1HellaCacheModule()(p) {
// ...
  val id = cfg.nMSHRs
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

### src/a-st-ext.adoc

```text
Complex atomic memory operations on a single memory word or doubleword
are performed with the load-reserved (LR) and store-conditional (SC)
instructions. LR.W loads a word from the address in _rs1_, places the
sign-extended value in _rd_, and registers a _reservation set_—a set of
bytes that subsumes the bytes in the addressed word. SC.W conditionally
writes a word in _rs2_ to the address in _rs1_: the SC.W succeeds only
if the reservation is still valid and the reservation set contains the
bytes being written. If the SC.W succeeds, the instruction writes the
word in _rs2_ to memory, and it writes zero to _rd_. If the SC.W fails,
the instruction does not write to memory, and it writes a nonzero value
to _rd_.  For the purposes of memory protection, a failed SC.W may be
treated like a store.  Regardless of success or failure, executing an
SC.W instruction invalidates any reservation held by this hart. LR.D and
SC.D act analogously on doublewords and are only available on RV64. For
RV64, LR.W and SC.W sign-extend the value placed in _rd_.
```
