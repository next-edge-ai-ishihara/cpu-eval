# Implement `TLB`

Implement the complete `TLB` module. Preserve its class declaration and public interface shown below. Return only the complete `class TLB` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/rocket/ICache.scala`

```scala
case class ICacheParams(
    nSets: Int = 64,
    nWays: Int = 4,
    rowBits: Int = 128,
    nTLBSets: Int = 1,
    nTLBWays: Int = 32,
    nTLBBasePageSectors: Int = 4,
    nTLBSuperpages: Int = 4,
    cacheIdBits: Int = 0,
    tagECC: Option[String] = None,
    dataECC: Option[String] = None,
    itimAddr: Option[BigInt] = None,
    prefetch: Boolean = false,
    blockBytes: Int = 64,
    latency: Int = 2,
    fetchBytes: Int = 4) extends L1CacheParams {
```

### `src/main/scala/common/config-mixins.scala`

```scala
// DOC include start: LargeBoomConfig
/**
 * 3-wide BOOM. Try to match the Cortex-A15.
 */
class WithNLargeBooms(n: Int = 1, overrideIdOffset: Option[Int] = None) extends Config(
  new WithTAGELBPD ++ // Default to TAGE-L BPD
// ...
            icache = Some(
              ICacheParams(rowBits = site(SystemBusKey).beatBits, nSets=64, nWays=8, fetchBytes=4*4)
            ),
```

## Package and imports

```scala
// See LICENSE.SiFive for license details.
// See LICENSE.Berkeley for license details.

package freechips.rocketchip.rocket

import Chisel._
import Chisel.ImplicitConversions._

import freechips.rocketchip.config.{Field, Parameters}
import freechips.rocketchip.subsystem.CacheBlockBytes
import freechips.rocketchip.diplomacy.RegionType
import freechips.rocketchip.tile.{CoreModule, CoreBundle}
import freechips.rocketchip.tilelink._
import freechips.rocketchip.util._
import freechips.rocketchip.util.property
import freechips.rocketchip.devices.debug.DebugModuleKey
import chisel3.internal.sourceinfo.SourceInfo
```

## Class declaration

```scala
class TLB(instruction: Boolean, lgMaxSize: Int, cfg: TLBConfig)(implicit edge: TLEdgeOut, p: Parameters) extends CoreModule()(p) {
  val io = new Bundle {
    val req = Decoupled(new TLBReq(lgMaxSize)).flip
    val resp = new TLBResp().asOutput
    val sfence = Valid(new SFenceReq).asInput
    val ptw = new TLBPTWIO
    val kill = Bool(INPUT) // suppress a TLB refill, one cycle after a miss
  }
```

## Parent instantiation

### `src/main/scala/ifu/frontend.scala`

```scala
  val icache = outer.icache.module
  icache.io.invalidate := io.cpu.flush_icache
  val tlb = Module(new TLB(true, log2Ceil(fetchBytes), TLBConfig(nTLBSets, nTLBWays)))
  io.ptw <> tlb.io.ptw
  io.cpu.perf.tlbMiss := io.ptw.req.fire
// ...
  tlb.io.req.valid      := (s1_valid && !s1_is_replay && !f1_clear) || s1_is_sfence
  tlb.io.req.bits.cmd   := DontCare
  tlb.io.req.bits.vaddr := s1_vpc
  tlb.io.req.bits.passthrough := false.B
  tlb.io.req.bits.size  := log2Ceil(coreInstBytes * fetchWidth).U
  tlb.io.req.bits.v     := io.ptw.status.v
  tlb.io.req.bits.prv   := io.ptw.status.prv
  tlb.io.sfence         := RegNext(io.cpu.sfence)
  tlb.io.kill           := false.B

  val s1_tlb_miss = !s1_is_replay && tlb.io.resp.miss
  val s1_tlb_resp = Mux(s1_is_replay, RegNext(s0_replay_resp), tlb.io.resp)
  val s1_ppc  = Mux(s1_is_replay, RegNext(s0_replay_ppc), tlb.io.resp.paddr)
  val s1_bpd_resp = bpd.io.resp.f1

  icache.io.s1_paddr := s1_ppc
  icache.io.s1_kill  := tlb.io.resp.miss || f1_clear

```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/rocket/TLB.scala`

```scala

case object PgLevels extends Field[Int](2)
case object ASIdBits extends Field[Int](0)
case object VMIdBits extends Field[Int](0)


class SFenceReq(implicit p: Parameters) extends CoreBundle()(p) {
  val rs1 = Bool()
  val rs2 = Bool()
  val addr = UInt(width = vaddrBits)
  val asid = UInt(width = asIdBits max 1) // TODO zero-width
  val hv = Bool()
  val hg = Bool()
}

class TLBReq(lgMaxSize: Int)(implicit p: Parameters) extends CoreBundle()(p) {
  val vaddr = UInt(width = vaddrBitsExtended)
  val passthrough = Bool()
  val size = UInt(width = log2Ceil(lgMaxSize + 1))
  val cmd  = Bits(width = M_SZ)
  val prv = UInt(PRV.SZ.W)
  val v = Bool()

}

class TLBExceptions(implicit p: Parameters) extends CoreBundle()(p) {
  val ld = Bool()
  val st = Bool()
  val inst = Bool()
  val v = Bool()
}

class TLBResp(implicit p: Parameters) extends CoreBundle()(p) {
  // lookup responses
  val miss = Bool()
  val paddr = UInt(width = paddrBits)
  val gpa = UInt(vaddrBitsExtended.W)
  val gpa_is_pte = Bool()
  val pf = new TLBExceptions
  val gf = new TLBExceptions
  val ae = new TLBExceptions
  val ma = new TLBExceptions
  val cacheable = Bool()
  val must_alloc = Bool()
  val prefetchable = Bool()
}

class TLBEntryData(implicit p: Parameters) extends CoreBundle()(p) {
  val ppn = UInt(width = ppnBits)
  val v = Bool()
  val u = Bool()
  val g = Bool()
  val ae_ptw = Bool()
  val ae_final = Bool()
  val gf = Bool()
  val sw = Bool()
  val sx = Bool()
  val sr = Bool()
  val hw = Bool()
  val hx = Bool()
  val hr = Bool()
  val pw = Bool()
  val px = Bool()
  val pr = Bool()
  val ppp = Bool() // PutPartial
  val pal = Bool() // AMO logical
  val paa = Bool() // AMO arithmetic
  val eff = Bool() // get/put effects
  val c = Bool()
  val fragmented_superpage = Bool()
}

class TLBEntry(val nSectors: Int, val superpage: Boolean, val superpageOnly: Boolean)(implicit p: Parameters) extends CoreBundle()(p) {
  require(nSectors == 1 || !superpage)
  require(!superpageOnly || superpage)

  val level = UInt(width = log2Ceil(pgLevels))
  val tag = UInt(width = vpnBits)
  val data = Vec(nSectors, UInt(width = new TLBEntryData().getWidth))
  val valid = Vec(nSectors, Bool())
  def entry_data = data.map(_.asTypeOf(new TLBEntryData))

  private def sectorIdx(vpn: UInt) = vpn.extract(nSectors.log2-1, 0)
  def getData(vpn: UInt) = OptimizationBarrier(data(sectorIdx(vpn)).asTypeOf(new TLBEntryData))
  def sectorHit(vpn: UInt) = valid.orR && sectorTagMatch(vpn)
  def sectorTagMatch(vpn: UInt) = ((tag ^ vpn) >> nSectors.log2) === 0
  def hit(vpn: UInt, virtual: Bool): Bool = {
    if (superpage && usingVM) {
      var tagMatch = valid.head && entry_data.head.v === virtual
      for (j <- 0 until pgLevels) {
        val base = (pgLevels - 1 - j) * pgLevelBits
        val n = pgLevelBits + (if (j == 0) hypervisorExtraAddrBits else 0)
        val ignore = level < j || superpageOnly && j == pgLevels - 1
        tagMatch = tagMatch && (ignore || (tag ^ vpn)(base + n - 1, base) === 0)
      }
      tagMatch
    } else {
      val idx = sectorIdx(vpn)
      val virtualMatch = entry_data.map(_.v === virtual)
      valid(idx) && virtualMatch(idx) && sectorTagMatch(vpn)
    }
  }
  def ppn(vpn: UInt, data: TLBEntryData) = {
    val supervisorVPNBits = pgLevels * pgLevelBits
    if (superpage && usingVM) {
      var res = data.ppn >> pgLevelBits*(pgLevels - 1)
      for (j <- 1 until pgLevels) {
        val ignore = level < j || superpageOnly && j == pgLevels - 1
        res = Cat(res, (Mux(ignore, vpn, 0.U) | data.ppn)(supervisorVPNBits - j*pgLevelBits - 1, supervisorVPNBits - (j + 1)*pgLevelBits))
      }
      res
    } else {
      data.ppn
    }
  }

  def insert(tag: UInt, level: UInt, entry: TLBEntryData): Unit = {
    this.tag := tag
    this.level := level.extract(log2Ceil(pgLevels - superpageOnly.toInt)-1, 0)

    val idx = sectorIdx(tag)
    valid(idx) := true
    data(idx) := entry.asUInt
  }

  def invalidate(): Unit = { valid.foreach(_ := false) }
  def invalidate(virtual: Bool, guestPhys: Bool): Unit = {
    for ((v, e) <- valid zip entry_data)
      when (e.v === virtual || e.v && guestPhys) { v := false }
  }
  def invalidateVPN(vpn: UInt, virtual: Bool): Unit = {
    if (superpage) {
      when (hit(vpn, virtual)) { invalidate() }
    } else {
      when (sectorTagMatch(vpn)) {
        for (((v, e), i) <- (valid zip entry_data).zipWithIndex)
          when (e.v === virtual && i === sectorIdx(vpn)) { v := false }
      }

      // For fragmented superpage mappings, we assume the worst (largest)
      // case, and zap entries whose most-significant VPNs match
      when (((tag ^ vpn) >> (pgLevelBits * (pgLevels - 1))) === 0) {
        for ((v, e) <- valid zip entry_data)
          when (e.v === virtual && e.fragmented_superpage) { v := false }
      }
    }
  }
  def invalidateNonGlobal(virtual: Bool): Unit = {
    for ((v, e) <- valid zip entry_data)
      when (e.v === virtual && !e.g) { v := false }
  }
}

case class TLBConfig(
    nSets: Int,
    nWays: Int,
    nSectors: Int = 4,
    nSuperpageEntries: Int = 4)
```

### `src/main/scala/rocket/PTW.scala`

```scala
class PTWReq(implicit p: Parameters) extends CoreBundle()(p) {
  val addr = UInt(width = vpnBits)
  val need_gpa = Bool()
  val vstage1 = Bool()
  val stage2 = Bool()
}

class PTWResp(implicit p: Parameters) extends CoreBundle()(p) {
  val ae_ptw = Bool()
  val ae_final = Bool()
  val gf = Bool()
  val hr = Bool()
  val hw = Bool()
  val hx = Bool()
  val pte = new PTE
  val level = UInt(width = log2Ceil(pgLevels))
  val fragmented_superpage = Bool()
  val homogeneous = Bool()
  val gpa = Valid(UInt(vaddrBits.W))
}

class TLBPTWIO(implicit p: Parameters) extends CoreBundle()(p)
    with HasCoreParameters {
  val req = Decoupled(Valid(new PTWReq))
  val resp = Valid(new PTWResp).flip
  val ptbr = new PTBR().asInput
  val hgatp = new PTBR().asInput
  val vsatp = new PTBR().asInput
  val status = new MStatus().asInput
  val hstatus = new HStatus().asInput
  val gstatus = new MStatus().asInput
  val pmp = Vec(nPMPs, new PMP).asInput
  val customCSRs = coreParams.customCSRs.asInput
}
// ...
class PTE(implicit p: Parameters) extends CoreBundle()(p) {
  val ppn = UInt(width = 54)
  val reserved_for_software = Bits(width = 2)
  val d = Bool()
  val a = Bool()
  val g = Bool()
  val u = Bool()
  val x = Bool()
  val w = Bool()
  val r = Bool()
  val v = Bool()

  def table(dummy: Int = 0) = v && !r && !w && !x && !d && !a && !u
  def leaf(dummy: Int = 0) = v && (r || (x && !w)) && a
  def ur(dummy: Int = 0) = sr() && u
  def uw(dummy: Int = 0) = sw() && u
  def ux(dummy: Int = 0) = sx() && u
  def sr(dummy: Int = 0) = leaf() && r
  def sw(dummy: Int = 0) = leaf() && w && d
  def sx(dummy: Int = 0) = leaf() && x
  def isFullPerm(dummy: Int = 0) = uw() && ux()
}
```

### `src/main/scala/rocket/TLBPermissions.scala`

```scala
// See LICENSE.SiFive for license details.

package freechips.rocketchip.rocket

import Chisel._

import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tilelink._

case class TLBPermissions(
  homogeneous: Bool, // if false, the below are undefined
  r: Bool, // readable
  w: Bool, // writeable
  x: Bool, // executable
  c: Bool, // cacheable
  a: Bool, // arithmetic ops
  l: Bool) // logical ops

object TLBPageLookup
{
  private case class TLBFixedPermissions(
    e: Boolean, // get-/put-effects
    r: Boolean, // readable
    w: Boolean, // writeable
    x: Boolean, // executable
    c: Boolean, // cacheable
    a: Boolean, // arithmetic ops
    l: Boolean) { // logical ops
    val useful = r || w || x || c || a || l
  }

  private def groupRegions(managers: Seq[TLManagerParameters]): Map[TLBFixedPermissions, Seq[AddressSet]] = {
    val permissions = managers.map { m =>
      (m.address, TLBFixedPermissions(
        e = Seq(RegionType.PUT_EFFECTS, RegionType.GET_EFFECTS) contains m.regionType,
        r = m.supportsGet     || m.supportsAcquireB, // if cached, never uses Get
        w = m.supportsPutFull || m.supportsAcquireT, // if cached, never uses Put
        x = m.executable,
        c = m.supportsAcquireB,
        a = m.supportsArithmetic,
        l = m.supportsLogical))
    }

    permissions
      .filter(_._2.useful) // get rid of no-permission devices
      .groupBy(_._2) // group by permission type
      .mapValues(seq =>
        AddressSet.unify(seq.flatMap(_._1))) // coalesce same-permission regions
  }

  // Unmapped memory is considered to be inhomogeneous
  def apply(managers: Seq[TLManagerParameters], xLen: Int, cacheBlockBytes: Int, pageSize: BigInt): UInt => TLBPermissions = {
    require (isPow2(xLen) && xLen >= 8)
    require (isPow2(cacheBlockBytes) && cacheBlockBytes >= xLen/8)
    require (isPow2(pageSize) && pageSize >= cacheBlockBytes)

    val xferSizes = TransferSizes(cacheBlockBytes, cacheBlockBytes)
    val allSizes = TransferSizes(1, cacheBlockBytes)
    val amoSizes = TransferSizes(4, xLen/8)

    val permissions = managers.foreach { m =>
      require (!m.supportsGet        || m.supportsGet       .contains(allSizes),  s"Memory region '${m.name}' at ${m.address} only supports ${m.supportsGet} Get, but must support ${allSizes}")
      require (!m.supportsPutFull    || m.supportsPutFull   .contains(allSizes),  s"Memory region '${m.name}' at ${m.address} only supports ${m.supportsPutFull} PutFull, but must support ${allSizes}")
      require (!m.supportsPutPartial || m.supportsPutPartial.contains(allSizes),  s"Memory region '${m.name}' at ${m.address} only supports ${m.supportsPutPartial} PutPartial, but must support ${allSizes}")
      require (!m.supportsAcquireB   || m.supportsAcquireB  .contains(xferSizes), s"Memory region '${m.name}' at ${m.address} only supports ${m.supportsAcquireB} AcquireB, but must support ${xferSizes}")
      require (!m.supportsAcquireT   || m.supportsAcquireT  .contains(xferSizes), s"Memory region '${m.name}' at ${m.address} only supports ${m.supportsAcquireT} AcquireT, but must support ${xferSizes}")
      require (!m.supportsLogical    || m.supportsLogical   .contains(amoSizes),  s"Memory region '${m.name}' at ${m.address} only supports ${m.supportsLogical} Logical, but must support ${amoSizes}")
      require (!m.supportsArithmetic || m.supportsArithmetic.contains(amoSizes),  s"Memory region '${m.name}' at ${m.address} only supports ${m.supportsArithmetic} Arithmetic, but must support ${amoSizes}")
      require (!(m.supportsAcquireB && m.supportsPutFull && !m.supportsAcquireT), s"Memory region '${m.name}' supports AcquireB (cached read) and PutFull (un-cached write) but not AcquireT (cached write)")
    }

    val grouped = groupRegions(managers)
      .mapValues(_.filter(_.alignment >= pageSize)) // discard any region that's not big enough

    def lowCostProperty(prop: TLBFixedPermissions => Boolean): UInt => Bool = {
      val (yesm, nom) = grouped.partition { case (k, eq) => prop(k) }
      val (yes, no) = (yesm.values.flatten.toList, nom.values.flatten.toList)
      // Find the minimal bits needed to distinguish between yes and no
      val decisionMask = AddressDecoder(Seq(yes, no))
      def simplify(x: Seq[AddressSet]) = AddressSet.unify(x.map(_.widen(~decisionMask)).distinct)
      val (yesf, nof) = (simplify(yes), simplify(no))
      if (yesf.size < no.size) {
        (x: UInt) => yesf.map(_.contains(x)).foldLeft(false.B)(_ || _)
      } else {
        (x: UInt) => !nof.map(_.contains(x)).foldLeft(false.B)(_ || _)
      }
    }

    // Derive simplified property circuits (don't care when !homo)
    val rfn = lowCostProperty(_.r)
    val wfn = lowCostProperty(_.w)
    val xfn = lowCostProperty(_.x)
    val cfn = lowCostProperty(_.c)
    val afn = lowCostProperty(_.a)
    val lfn = lowCostProperty(_.l)

    val homo = AddressSet.unify(grouped.values.flatten.toList)
    (x: UInt) => TLBPermissions(
      homogeneous = homo.map(_.contains(x)).foldLeft(false.B)(_ || _),
      r = rfn(x),
      w = wfn(x),
      x = xfn(x),
      c = cfn(x),
      a = afn(x),
      l = lfn(x))
  }

  // Are all pageSize intervals of mapped regions homogeneous?
  def homogeneous(managers: Seq[TLManagerParameters], pageSize: BigInt): Boolean = {
    groupRegions(managers).values.forall(_.forall(_.alignment >= pageSize))
  }
}
```

### `src/main/scala/rocket/PMP.scala`

```scala
class PMPHomogeneityChecker(pmps: Seq[PMP])(implicit p: Parameters) {
  def apply(addr: UInt, pgLevel: UInt): Bool = {
    pmps.foldLeft((true.B, 0.U.asTypeOf(new PMP))) { case ((h, prev), pmp) =>
      (h && pmp.homogeneous(addr, pgLevel, prev), pmp)
    }._1
  }
}

class PMPChecker(lgMaxSize: Int)(implicit val p: Parameters) extends Module
    with HasCoreParameters {
  val io = IO(new Bundle {
    val prv = Input(UInt(PRV.SZ.W))
    val pmp = Input(Vec(nPMPs, new PMP))
    val addr = Input(UInt(paddrBits.W))
    val size = Input(UInt(log2Ceil(lgMaxSize + 1).W))
    val r = Output(Bool())
    val w = Output(Bool())
    val x = Output(Bool())
  })

  val default = if (io.pmp.isEmpty) true.B else io.prv > PRV.S
  val pmp0 = WireInit(0.U.asTypeOf(new PMP))
  pmp0.cfg.r := default
  pmp0.cfg.w := default
  pmp0.cfg.x := default

  val res = (io.pmp zip (pmp0 +: io.pmp)).reverse.foldLeft(pmp0) { case (prev, (pmp, prevPMP)) =>
    val hit = pmp.hit(io.addr, io.size, lgMaxSize, prevPMP)
    val ignore = default && !pmp.cfg.l
    val aligned = pmp.aligned(io.addr, io.size, lgMaxSize, prevPMP)

    for ((name, idx) <- Seq("no", "TOR", if (pmpGranularity <= 4) "NA4" else "", "NAPOT").zipWithIndex; if name.nonEmpty)
      property.cover(pmp.cfg.a === idx, s"The cfg access is set to ${name} access ", "Cover PMP access mode setting")

    property.cover(pmp.cfg.l === 0x1, s"The cfg lock is set to high ", "Cover PMP lock mode setting")
   
    // Not including Write and no Read permission as the combination is reserved
    for ((name, idx) <- Seq("no", "RO", "", "RW", "X", "RX", "", "RWX").zipWithIndex; if name.nonEmpty)
      property.cover((Cat(pmp.cfg.x, pmp.cfg.w, pmp.cfg.r) === idx), s"The permission is set to ${name} access ", "Cover PMP access permission setting")

    for ((name, idx) <- Seq("", "TOR", if (pmpGranularity <= 4) "NA4" else "", "NAPOT").zipWithIndex; if name.nonEmpty) {
      property.cover(!ignore && hit && aligned && pmp.cfg.a === idx, s"The access matches ${name} mode ", "Cover PMP access")
      property.cover(pmp.cfg.l && hit && aligned && pmp.cfg.a === idx, s"The access matches ${name} mode with lock bit high", "Cover PMP access with lock bit")
    }

    val cur = WireInit(pmp)
    cur.cfg.r := aligned && (pmp.cfg.r || ignore)
    cur.cfg.w := aligned && (pmp.cfg.w || ignore)
    cur.cfg.x := aligned && (pmp.cfg.x || ignore)
    Mux(hit, cur, prev)
```

## Related source code

### `src/main/scala/rocket/DCache.scala`

```scala
  val tlb = Module(new TLB(false, log2Ceil(coreDataBytes), TLBConfig(nTLBSets, nTLBWays, cacheParams.nTLBBasePageSectors, cacheParams.nTLBSuperpages)))
  val pma_checker = Module(new TLB(false, log2Ceil(coreDataBytes), TLBConfig(nTLBSets, nTLBWays, cacheParams.nTLBBasePageSectors, cacheParams.nTLBSuperpages)) with InlineInstance)
// ...
  // address translation
  val s1_cmd_uses_tlb = s1_readwrite || s1_flush_line || s1_req.cmd === M_WOK
  io.ptw <> tlb.io.ptw
  tlb.io.kill := io.cpu.s2_kill || s2_tlb_req_valid && tlb_port.s2_kill
  tlb.io.req.valid := s1_tlb_req_valid || s1_valid && !io.cpu.s1_kill && s1_cmd_uses_tlb
  tlb.io.req.bits := s1_tlb_req
  when (!tlb.io.req.ready && !tlb.io.ptw.resp.valid && !io.cpu.req.bits.phys) { io.cpu.req.ready := false }
  when (!s1_tlb_req_valid && s1_valid && s1_cmd_uses_tlb && tlb.io.resp.miss) { s1_nack := true }

  tlb.io.sfence.valid := s1_valid && !io.cpu.s1_kill && s1_sfence
  tlb.io.sfence.bits.rs1 := s1_req.size(0)
  tlb.io.sfence.bits.rs2 := s1_req.size(1)
  tlb.io.sfence.bits.asid := io.cpu.s1_data.data
  tlb.io.sfence.bits.addr := s1_req.addr
  tlb.io.sfence.bits.hv := s1_req.cmd === M_HFENCEV
  tlb.io.sfence.bits.hg := s1_req.cmd === M_HFENCEG

  tlb_port.req.ready := clock_en_reg
  tlb_port.s1_resp := tlb.io.resp
  when (s1_tlb_req_valid && s1_valid && !(s1_req.phys && s1_req.no_xcpt)) { s1_nack := true }

  pma_checker.io.req.bits.passthrough := true
  pma_checker.io.req.bits := s1_req
```

## Documentation

### `src/priv/supervisor.adoc`

```text
[[norm:sstatus_mxr]]
The MXR (Make eXecutable Readable) bit modifies the privilege with which
loads access virtual memory. When MXR=0, only loads from pages marked
readable (R=1 in <<sv32pte>>) will succeed. When
MXR=1, loads from pages marked either readable or executable (R=1 or
X=1) will succeed. MXR has no effect when page-based virtual memory is
not in effect.

[[norm:sstatus_sum]]
The SUM (permit Supervisor User Memory access) bit modifies the
privilege with which S-mode loads and stores access virtual memory. When
SUM=0, S-mode memory accesses to pages that are accessible by U-mode
(U=1 in <<sv32pte>>) will fault. When SUM=1, these
accesses are permitted. SUM has no effect when page-based virtual memory
is not in effect, nor when executing in U-mode. Note that S-mode can
never execute instructions from user pages, regardless of the state of
SUM.
...
The supervisor memory-management fence instruction SFENCE.VMA is used to
synchronize updates to in-memory memory-management data structures with
current execution. Instruction execution causes implicit reads and
writes to these data structures; however, these implicit references are
ordinarily not ordered with respect to explicit loads and stores.
[#norm:sfence_vma_ordering]#Executing an SFENCE.VMA instruction guarantees that any previous stores
already visible to the current RISC-V hart are ordered before certain
implicit references by subsequent instructions in that hart to the
memory-management data structures. The specific set of operations
ordered by SFENCE.VMA is determined by _rs1_ and _rs2_, as described
below.# [#norm:sfence_vma_invalidation]#SFENCE.VMA is also used to invalidate entries in the
address-translation cache associated with a hart (see <<sv32algorithm>>).# Further details on the behavior of this instruction are described in <<virt-control>> and <<pmp-vmem>>.
...
For the common case that the translation data structures have only been
modified for a single address mapping (i.e., one page or superpage),
_rs1_ can specify a virtual address within that mapping to effect a
translation fence for that mapping only. Furthermore, for the common
case that the translation data structures have only been modified for a
single address-space identifier, _rs2_ can specify the address space.
The behavior of SFENCE.VMA depends on _rs1_ and _rs2_ as follows:


* [#norm:sfence_vma_all_asid_va]#If __rs1__=`x0` and __rs2__=`x0`, the fence orders all reads and writes
made to any level of the page tables, for all address spaces. The fence
also invalidates all address-translation cache entries, for all address
spaces.#

* [#norm:sfence_vma_asid_only]#If __rs1__=`x0` and __rs2__{ne}``x0``, the fence orders all
reads and writes made to any level of the page tables, but only for the
address space identified by integer register _rs2_. Accesses to _global_
mappings (see <<translation>>) are not ordered. The
fence also invalidates all address-translation cache entries matching
the address space identified by integer register _rs2_, except for
entries containing global mappings.#

* [#norm:sfence_vma_va_all_asid]#If __rs1__{ne}``x0`` and __rs2__=`x0`, the fence orders only
reads and writes made to leaf page table entries corresponding to the
virtual address in __rs1__, for all address spaces. The fence also
invalidates all address-translation cache entries that contain leaf page
table entries corresponding to the virtual address in _rs1_, for all
address spaces.#

* [#norm:sfence_vma_va_asid]#If __rs1__{ne}``x0`` and __rs2__{ne}``x0``, the
fence orders only reads and writes made to leaf page table entries
corresponding to the virtual address in _rs1_, for the address space
identified by integer register _rs2_. Accesses to global mappings are
not ordered. The fence also invalidates all address-translation cache
entries that contain leaf page table entries corresponding to the
virtual address in _rs1_ and that match the address space identified by
integer register _rs2_, except for entries containing global mappings.#
...
[#norm:sfence_vma_sum_mxr_effect]#Changes to the `sstatus` fields SUM and MXR take effect immediately,
without the need to execute an SFENCE.VMA instruction.#
[#norm:sfence_vma_mode_effect]#Changing
`satp`.MODE from Bare to other modes and vice versa also takes effect
immediately, without the need to execute an SFENCE.VMA instruction.#
[#norm:sfence_vma_asid_effect]#Likewise, changes to `satp`.ASID take effect immediately.#
...
The PTE format for Sv32 is shown in <<sv32pte>>.
The V bit indicates whether the PTE is valid; if it is 0, all other bits
in the PTE are don’t-cares and may be used freely by software. The
permission bits, R, W, and X, indicate whether the page is readable,
writable, and executable, respectively. When all three are zero, the PTE
is a pointer to the next level of the page table; otherwise, it is a
leaf PTE. Writable pages must also be marked readable; the contrary
combinations are reserved for future use. <<pteperm>>
...
[#norm:fetch_page_fault_no_x]#Attempting to fetch an instruction from a page that does not have
execute permissions raises a fetch page-fault exception.#
[#norm:load_page_fault_no_r]#Attempting to execute a load, load-reserved, or cache-block management
instruction whose effective address lies
within a page without read permissions raises a load page-fault exception.#
[#norm:store_page_fault_no_w]#Attempting to execute a store, store-conditional, AMO, or cache-block zero instruction
instruction whose effective address lies within a page without write
permissions raises a store page-fault exception.#

[NOTE]
====
AMOs never raise load page-fault exceptions. Since any unreadable page
is also unwritable, attempting to perform an AMO on an unreadable page
always raises a store page-fault exception.
====

The U bit indicates whether the page is accessible to user mode. U-mode
software may only access the page when U=1. If the SUM bit in the
`sstatus` register is set, supervisor mode software may also access
pages with U=1. However, supervisor code normally operates with the SUM
bit clear, in which case, supervisor code will fault on accesses to
user-mode pages. Irrespective of SUM, the supervisor may not execute
code on pages with U=1.
...
The G bit designates a _global_ mapping. Global mappings are those that
exist in all address spaces. For non-leaf PTEs, the global setting
implies that all mappings in the subsequent levels of the page table are
global. Note that failing to mark a global mapping as global merely
reduces performance, whereas marking a non-global mapping as global is a
software bug that, after switching to an address space with a different
non-global mapping for that address range, can unpredictably result in
either mapping being used.

[NOTE]
====
Global mappings need not be stored redundantly in address-translation
caches for multiple ASIDs. Additionally, they need not be flushed from
local address-translation caches when an SFENCE.VMA instruction is
executed with __rs2__{ne}``x0``.
====

The RSW field is reserved for use by supervisor software; the
implementation shall ignore this field.

Each leaf PTE contains an accessed (A) and dirty (D) bit. The A bit
indicates the virtual page has been read, written, or fetched from since
the last time the A bit was cleared. The D bit indicates the virtual
page has been written since the last time the D bit was cleared.
...
. The translation is successful. The translated physical address is
given as follows:
* _pa.pgoff_ = _va.pgoff_.
* If _i_>0, then this is a superpage translation and __pa.ppn__[__i__-1:0] = __va.vpn__[__i__-1:0].
* _pa.ppn_[LEVELS-1:__i__] = _pte_._ppn_[LEVELS-1:__i__].
...
[[sv39]]
=== Sv39: Page-Based 39-bit Virtual-Memory System

This section describes a [#norm:Sv39_sxlen]#simple paged virtual-memory system for
SXLEN=64#, which [#norm:Sv39_va_sz]#supports 39-bit virtual address spaces#. The design of
Sv39 follows the overall scheme of Sv32, and this section details only
the differences between the schemes.
...
[[addressing-and-memory-protection]]
==== Addressing and Memory Protection

Sv39 implementations support a 39-bit virtual address space, divided
into 4 KiB pages. An Sv39 address is partitioned as shown in
<<sv39va>>. Instruction fetch addresses and load and
store effective addresses, which are 64 bits,
[#norm:Sv39_va_signext]#must have bits 63–39 all equal to bit 38, or else
a page-fault exception will occur#.
The [#norm:Sv39_vpn_sz]#27-bit VPN# is translated into a
[#norm:satp_ppn_sv39_sz]#44-bit PPN# via a
[#norm:Sv39_levels]#three-level page table#, while the
[#norm:Sv39_page_offset_sz]#12-bit page offset is untranslated#.
...
Sv39 page tables contain [#norm:Sv39_pte_count]#2^9^ page table entries
(PTEs)#, [#norm:Sv39_pte_sz]#eight bytes each#.
A page table is [#norm:Sv39_pt_sz]#exactly the size of a page# and
[#norm:Sv39_pt_align]#must always be aligned to a page boundary#.
The physical page number of the root page table is stored in the `satp`
register's PPN field.

The PTE format for Sv39 is shown in <<sv39pte>>.
Bits 9-0 have the same meaning as for Sv32.
Bit 63 is reserved for use by the extlink:svnapot[] extension.
[#norm:Sv39_pte_svnapot_rsv]#If Svnapot is not implemented, bit 63 remains
reserved and must be zeroed by software for forward compatibility, or
else a page-fault exception is raised#.
Bits 62-61 are reserved for use by the extlink:svpbmt[] extension.
[#norm:Sv39_pte_svpbmt_rsv]#If Svpbmt is not implemented, bits 62-61 remain
reserved and must be zeroed by software for forward compatibility, or
else a page-fault exception is raised#.
Bits 60-54 are reserved for future standard use and, until their use is
defined by some standard extension,
[#norm:Sv39_pte_future_rsv]#must be zeroed by software for forward
compatibility. If any of these bits are set, a page-fault exception is
raised#.
...
[#norm:Sv39_leaf_any_level]#Any level of PTE may be a leaf PTE#, so in
addition to 4 KiB pages, Sv39 supports
[#norm:Sv39_page_sizes]#2 MiB megapages and 1 GiB gigapages#, each of
which [#norm:Sv39_superpage_align]#must be virtually and physically
aligned to a boundary equal to its size#.
[#norm:Sv39_superpage_align_fault]#A page-fault exception is raised if
the physical address is insufficiently aligned#.

The algorithm for virtual-to-physical address translation is the same as
in <<sv32algorithm>>, except
[#norm:Sv39_LEVELS]#LEVELS equals 3# and
[#norm:Sv39_PTESIZE]#PTESIZE equals 8#.
```
