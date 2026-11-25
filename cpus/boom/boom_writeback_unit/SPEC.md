# Implement `BoomWritebackUnit`

Implement one complete `BoomWritebackUnit` Chisel definition. Preserve the definition name, implicit parameters, inheritance, and public interface shown below.

Return only the complete `class BoomWritebackUnit` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/common/config-mixins.scala

```scala
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
// ...
import freechips.rocketchip.config.Parameters
// ...
import freechips.rocketchip.tilelink._
import freechips.rocketchip.tile._
// ...
import freechips.rocketchip.rocket._
```

## Class declaration

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
```

## Parent instantiation

```scala
  val wb = Module(new BoomWritebackUnit)
  val prober = Module(new BoomProbeUnit)
  val mshrs = Module(new BoomMSHRFile)
  // ...
  // -----------
  // Write-backs
  val wb_fire = wb.io.meta_read.fire && wb.io.data_req.fire
  val wb_req = Wire(Vec(memWidth, new BoomDCacheReq))
  wb_req             := DontCare
  wb_req(0).uop      := NullMicroOp
  wb_req(0).addr     := Cat(wb.io.meta_read.bits.tag, wb.io.data_req.bits.addr)
  wb_req(0).data     := DontCare
  wb_req(0).is_hella := false.B
  // Couple the two decoupled interfaces of the WBUnit's meta_read and data_read
  // Tag read for write-back
  metaReadArb.io.in(2).valid        := wb.io.meta_read.valid
  metaReadArb.io.in(2).bits.req(0)  := wb.io.meta_read.bits
  wb.io.meta_read.ready := metaReadArb.io.in(2).ready && dataReadArb.io.in(1).ready
  // Data read for write-back
  dataReadArb.io.in(1).valid        := wb.io.data_req.valid
  dataReadArb.io.in(1).bits.req(0)  := wb.io.data_req.bits
  dataReadArb.io.in(1).bits.valid   := widthMap(w => (w == 0).B)
  wb.io.data_req.ready  := metaReadArb.io.in(2).ready && dataReadArb.io.in(1).ready
  assert(!(wb.io.meta_read.fire ^ wb.io.data_req.fire))
  // ...
  prober.io.wb_rdy      := (prober.io.meta_write.bits.idx =/= wb.io.idx.bits) || !wb.io.idx.valid
  // ...
  // refills
  when (tl_out.d.bits.source === cfg.nMSHRs.U) {
    // This should be ReleaseAck
    tl_out.d.ready := true.B
    mshrs.io.mem_grant.valid := false.B
    mshrs.io.mem_grant.bits  := DontCare
  } .otherwise {
    // This should be GrantData
    mshrs.io.mem_grant <> tl_out.d
  // ...
  // writebacks
  val wbArb = Module(new Arbiter(new WritebackReq(edge.bundle), 2))
  // 0 goes to prober, 1 goes to MSHR evictions
  wbArb.io.in(0)       <> prober.io.wb_req
  wbArb.io.in(1)       <> mshrs.io.wb_req
  wb.io.req            <> wbArb.io.out
  wb.io.data_resp       := s2_data_muxed(0)
  mshrs.io.wb_resp      := wb.io.resp
  wb.io.mem_grant       := tl_out.d.fire && tl_out.d.bits.source === cfg.nMSHRs.U

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

### src/main/scala/rocket/NBDcache.scala

```scala
class L1DataReadReq(implicit p: Parameters) extends L1HellaCacheBundle()(p) {
  val way_en = Bits(width = nWays)
  val addr   = Bits(width = untagBits)
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

### src/main/scala/rocket/HellaCache.scala

```scala
trait HasL1HellaCacheParameters extends HasL1CacheParameters with HasCoreParameters {
  val cacheParams = tileParams.dcache.get
  val cfg = cacheParams
// ...
abstract class L1HellaCacheModule(implicit val p: Parameters) extends Module
  with HasL1HellaCacheParameters

abstract class L1HellaCacheBundle(implicit val p: Parameters) extends ParameterizedBundle()(p)
  with HasL1HellaCacheParameters
// ...
class L1MetaReadReq(implicit p: Parameters) extends L1HellaCacheBundle()(p) {
  val idx    = UInt(width = idxBits)
  val way_en = UInt(width = nWays)
  val tag    = UInt(width = tagBits)
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
  // ...
  def rowBits = cacheParams.rowBits
  def rowBytes = rowBits/8
  def rowOffBits = log2Up(rowBytes)
  // ...
  def cacheDataBits = tlBundleParams.dataBits
  def cacheDataBytes = cacheDataBits / 8
  def cacheDataBeats = (cacheBlockBytes * 8) / cacheDataBits
  def refillCycles = cacheDataBeats
```

### src/main/scala/tile/BaseTile.scala

```scala
  def cacheBlockBytes = p(CacheBlockBytes)
  def lgCacheBlockBytes = log2Up(cacheBlockBytes)
```

### src/main/scala/tilelink/Edges.scala

```scala
  def Release(fromSource: UInt, toAddress: UInt, lgSize: UInt, shrinkPermissions: UInt, data: UInt, corrupt: Bool): (Bool, TLBundleC) = {
    require (manager.anySupportAcquireB, s"TileLink: No managers visible from this edge support Acquires, but one of these clients would try to request one: ${client.clients}")
    val legal = manager.supportsAcquireBFast(toAddress, lgSize)
    val c = Wire(new TLBundleC(bundle))
    c.opcode  := TLMessages.ReleaseData
    c.param   := shrinkPermissions
    c.size    := lgSize
    c.source  := fromSource
    c.address := toAddress
    c.data    := data
    c.corrupt := corrupt
    (legal, c)
  }

  def Release(fromSource: UInt, toAddress: UInt, lgSize: UInt, shrinkPermissions: UInt, data: UInt): (Bool, TLBundleC) =
    Release(fromSource, toAddress, lgSize, shrinkPermissions, data, Bool(false))
  // ...
  def ProbeAck(b: TLBundleB, reportPermissions: UInt, data: UInt): TLBundleC =
    ProbeAck(b.source, b.address, b.size, reportPermissions, data)

  def ProbeAck(fromSource: UInt, toAddress: UInt, lgSize: UInt, reportPermissions: UInt, data: UInt, corrupt: Bool): TLBundleC = {
    val c = Wire(new TLBundleC(bundle))
    c.opcode  := TLMessages.ProbeAckData
    c.param   := reportPermissions
    c.size    := lgSize
    c.source  := fromSource
    c.address := toAddress
    c.data    := data
    c.corrupt := corrupt
    c
  }

  def ProbeAck(fromSource: UInt, toAddress: UInt, lgSize: UInt, reportPermissions: UInt, data: UInt): TLBundleC =
    ProbeAck(fromSource, toAddress, lgSize, reportPermissions, data, Bool(false))
```

### src/main/scala/tilelink/Bundles.scala

```scala
  def ProbeAck       = UInt(4) //               .
  def ProbeAckData   = UInt(5) //               .
  def Release        = UInt(6) //               .              => ReleaseAck
  def ReleaseData    = UInt(7) //               .              => ReleaseAck
  // ...
  def ReleaseAck     = UInt(6) //                    .
// ...
  val cWidth = 3
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

## Related source code

### src/main/scala/lsu/dcache.scala

```scala
  assert(!io.rep.valid || !edge.hasData(io.rep.bits),
    "ProbeUnit should not send ProbeAcks with data, WritebackUnit should handle it")
  // ...
  io.wb_req.valid := state === s_writeback_req
  io.wb_req.bits.source := req.source
  io.wb_req.bits.idx := req_idx
  io.wb_req.bits.tag := req_tag
  io.wb_req.bits.param := report_param
  io.wb_req.bits.way_en := way_en
  io.wb_req.bits.voluntary := false.B
  // ...
  io.lsu_release.valid := state === s_lsu_release
  io.lsu_release.bits  := edge.ProbeAck(req, report_param)
  // ...
  } .elsewhen (state === s_writeback_req) {
    when (io.wb_req.fire) {
      state := s_writeback_resp
    }
  } .elsewhen (state === s_writeback_resp) {
    // wait for the writeback request to finish before updating the metadata
    when (io.wb_req.ready) {
      state := s_meta_write
  // ...
      io.resp(j)(w) := RegNext(array.read(raddr, io.read(j).bits.way_en(w) && io.read(j).valid).asUInt)
  // ...
  val s1_wb_way_en             = RegNext(wb.io.data_req.bits.way_en)
  // ...
  val s2_data = Wire(Vec(memWidth, Vec(nWays, UInt(encRowBits.W))))
  for (i <- 0 until memWidth) {
    for (w <- 0 until nWays) {
      s2_data(i)(w) := data.io.resp(i)(w)
    }
  }

  val s2_data_muxed = widthMap(w => Mux1H(s2_tag_match_way(w), s2_data(w)))
```

### src/main/scala/rocket/NBDcache.scala

```scala
  // We reissue the meta read as it sets up the mux ctrl for s2_data_muxed
```

### src/main/scala/lsu/mshrs.scala

```scala
    // Writeback unit tells us when it is done processing our wb
    val wb_resp     = Input(Bool())
  // ...
  } .elsewhen (state === s_wb_req) {
    io.wb_req.valid          := true.B

    io.wb_req.bits.tag       := req.old_meta.tag
    io.wb_req.bits.idx       := req_idx
    io.wb_req.bits.param     := shrink_param
    io.wb_req.bits.way_en    := req.way_en
    io.wb_req.bits.source    := io.id
    io.wb_req.bits.voluntary := true.B
    when (io.wb_req.fire) {
      state := s_wb_resp
    }
  } .elsewhen (state === s_wb_resp) {
    when (io.wb_resp) {
      state := s_commit_line
    }
```

### src/main/scala/lsu/lsu.scala

```scala
  // We are making a local line visible to other harts
  val do_release_search = widthMap(w => fired_release(w))
  // ...
  val lcam_addr  = widthMap(w => Mux(fired_stad_incoming(w) || fired_sta_incoming(w) || fired_sta_retry(w),
                                     RegNext(exe_tlb_paddr(w)),
                                     Mux(fired_release(w), RegNext(io.dmem.release.bits.address),
                                         mem_paddr(w))))
```

## Documentation

```text
[dcache] TileLink may ReleaseAck before we are done doing the Release. Support that
```

```text
[dcache] Fix BoomWritebackUnit not sending all wb beats
```

```text
[dcache] Reread tags before voluntary writeback
```

```text
[dcache] Give the WritebackUnit its own SourceId
```

### docs/sections/load-store-unit.rst

```text
Ordering Loads to the Same Address
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The RISC-V WMO memory model requires that loads to the same address be ordered.
[2]_ This requires loads to search against other loads for potential address conflicts.
If a younger load executes before an older load with a matching address, the
younger load must be replayed and the instructions after it in the pipeline flushed.
However, this scenario is only required if a cache coherence probe event
snooped the core’s memory, exposing the reordering to the other threads.
If no probe events occurred, the load re-ordering may safely occur.
```

## Additional requirement

For both probe and voluntary requests, `resp` pulses no earlier than the cycle in which the last row of the line is on `data_resp`, then one `lsu_release` beat with the request's line address transfers before the first `release` beat, and every `release` message uses source `nMSHRs`.
