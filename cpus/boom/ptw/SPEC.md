# Implement `PTW`

Implement the complete `PTW` module. Preserve the annotated class declaration and public interface shown below. Return only the complete `class PTW` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/parameters.scala`

```scala
  nL2TLBEntries: Int = 512,
  val nPTECacheEntries: Int = 8, // TODO: check
  nL2TLBWays: Int = 1,
// ...
  useHypervisor: Boolean = false,
  useVM: Boolean = true,
// ...
  nPMPs: Int = 8,
// ...
  val pmpGranularity: Int = 4
```

### `src/main/scala/common/config-mixins.scala`

```scala
            dcache = Some(
              DCacheParams(rowBits = site(SystemBusKey).beatBits, nSets=64, nWays=8, nMSHRs=4, nTLBWays=16)
            ),
// ...
    case XLen => 64
```

### `src/main/scala/rocket/HellaCache.scala`

```scala
    separateUncachedResp: Boolean = false,
// ...
    clockGate: Boolean = false,
```

### `src/main/scala/subsystem/Configs.scala`

```scala
  case PgLevels => if (site(XLen) == 64) 3 /* Sv39 */ else 2 /* Sv32 */
```

## Package and imports

```scala
package freechips.rocketchip.rocket

import Chisel._
import Chisel.ImplicitConversions._
import chisel3.withClock
import chisel3.internal.sourceinfo.SourceInfo
import chisel3.experimental.chiselName
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.subsystem.CacheBlockBytes
import freechips.rocketchip.tile._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.util._
import freechips.rocketchip.util.property
import freechips.rocketchip.diplomaticobjectmodel.model.OMSRAM
import scala.collection.mutable.ListBuffer
```

## Class declaration

```scala
@chiselName
class PTW(n: Int)(implicit edge: TLEdgeOut, p: Parameters) extends CoreModule()(p) {
  val io = new Bundle {
    val requestor = Vec(n, new TLBPTWIO).flip
    val mem = new HellaCacheIO
    val dpath = new DatapathPTWIO
  }

  val omSRAMs = collection.mutable.ListBuffer[OMSRAM]()
```

## Parent instantiation

### `src/main/scala/common/tile.scala`

```scala
  val core = Module(new BoomCore(outer.boomParams.trace)(outer.p))
  val lsu  = Module(new LSU()(outer.p, outer.dcache.module.edge))

  val ptwPorts         = ListBuffer(lsu.io.ptw, outer.frontend.module.io.ptw, core.io.ptw_tlb)
// ...
  // PTW
  val ptw  = Module(new PTW(ptwPorts.length)(outer.dcache.node.edges.out(0), outer.p))
  core.io.ptw <> ptw.io.dpath
  ptw.io.requestor <> ptwPorts
  hellaCachePorts += ptw.io.mem
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
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

class PTWPerfEvents extends Bundle {
  val l2miss = Bool()
  val l2hit = Bool()
  val pte_miss = Bool()
  val pte_hit = Bool()
}

class DatapathPTWIO(implicit p: Parameters) extends CoreBundle()(p)
    with HasCoreParameters {
  val ptbr = new PTBR().asInput
  val hgatp = new PTBR().asInput
  val vsatp = new PTBR().asInput
  val sfence = Valid(new SFenceReq).flip
  val status = new MStatus().asInput
  val hstatus = new HStatus().asInput
  val gstatus = new MStatus().asInput
  val pmp = Vec(nPMPs, new PMP).asInput
  val perf = new PTWPerfEvents().asOutput
  val customCSRs = coreParams.customCSRs.asInput
  val clock_enabled = Bool(OUTPUT)
}

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

class L2TLBEntry(nSets: Int)(implicit p: Parameters) extends CoreBundle()(p)
    with HasCoreParameters {
  val idxBits = log2Ceil(nSets)
  val tagBits = maxSVAddrBits - pgIdxBits - idxBits + (if (usingHypervisor) 1 else 0)
  val tag = UInt(width = tagBits)
  val ppn = UInt(width = ppnBits)
  val d = Bool()
  val a = Bool()
  val u = Bool()
  val x = Bool()
  val w = Bool()
  val r = Bool()

}

```

### `src/main/scala/tile/BaseTile.scala`

```scala
  def usingVM: Boolean = tileParams.core.useVM
// ...
  def usingHypervisor: Boolean = usingVM && tileParams.core.useHypervisor
// ...
  def xLen: Int = p(XLen)
// ...
  def pgIdxBits: Int = 12
  def pgLevelBits: Int = 10 - log2Ceil(xLen / 32)
  def pgLevels: Int = p(PgLevels)
  def maxSVAddrBits: Int = pgIdxBits + pgLevels * pgLevelBits
  def maxHypervisorExtraAddrBits: Int = 2
  def hypervisorExtraAddrBits: Int = {
    if (usingHypervisor) maxHypervisorExtraAddrBits
    else 0
  }
  def maxHVAddrBits: Int = maxSVAddrBits + hypervisorExtraAddrBits
  def minPgLevels: Int = {
    val res = xLen match { case 32 => 2; case 64 => 3 }
    require(pgLevels >= res)
    res
  }
  def asIdBits: Int = p(ASIdBits)
// ...
  lazy val maxPAddrBits: Int = {
    require(xLen == 32 || xLen == 64, s"Only XLENs of 32 or 64 are supported, but got $xLen")
    xLen match { case 32 => 34; case 64 => 56 }
  }
// ...
/** These parameters values are computed based on diplomacy negotiations
  * and so are NOT safe to use while diplomacy itself is running.
  * Only mix this trait into LazyModuleImps, Modules, Bundles, Data, etc.
  */
trait HasTileParameters extends HasNonDiplomaticTileParameters {
  protected def tlBundleParams = p(TileVisibilityNodeKey).edges.out.head.bundle
  lazy val paddrBits: Int = {
    val bits = tlBundleParams.addressBits
    require(bits <= maxPAddrBits, s"Requested $bits paddr bits, but since xLen is $xLen only $maxPAddrBits will fit")
    bits
  }
  def vaddrBits: Int =
    if (usingVM) {
      val v = maxHVAddrBits
      require(v == xLen || xLen > v && v > paddrBits)
      v
    } else {
      // since virtual addresses sign-extend but physical addresses
      // zero-extend, make room for a zero sign bit for physical addresses
      (paddrBits + 1) min xLen
    }
  def vpnBits: Int = vaddrBits - pgIdxBits
  def ppnBits: Int = paddrBits - pgIdxBits
  def vpnBitsExtended: Int = vpnBits + (vaddrBits < xLen).toInt
  def vaddrBitsExtended: Int = vpnBitsExtended + pgIdxBits
}
```

### `src/main/scala/rocket/TLB.scala`

```scala
class SFenceReq(implicit p: Parameters) extends CoreBundle()(p) {
  val rs1 = Bool()
  val rs2 = Bool()
  val addr = UInt(width = vaddrBits)
  val asid = UInt(width = asIdBits max 1) // TODO zero-width
  val hv = Bool()
  val hg = Bool()
}
```

### `src/main/scala/rocket/CSR.scala`

```scala
class PTBR(implicit p: Parameters) extends CoreBundle()(p) {
  def additionalPgLevels = mode.extract(log2Ceil(pgLevels-minPgLevels+1)-1, 0)
  def pgLevelsToMode(i: Int) = (xLen, i) match {
    case (32, 2) => 1
    case (64, x) if x >= 3 && x <= 6 => x + 5
  }
  val (modeBits, maxASIdBits) = xLen match {
    case 32 => (1, 9)
    case 64 => (4, 16)
  }
  require(modeBits + maxASIdBits + maxPAddrBits - pgIdxBits == xLen)

  val mode = UInt(width = modeBits)
  val asid = UInt(width = maxASIdBits)
  val ppn = UInt(width = maxPAddrBits - pgIdxBits)
}

object PRV
{
  val SZ = 2
  val U = 0
  val S = 1
  val H = 2
  val M = 3
}
```

### `src/main/scala/rocket/HellaCache.scala`

```scala
trait HasCoreMemOp extends HasL1HellaCacheParameters {
  val addr = UInt(width = coreMaxAddrBits)
  val idx  = (usingVM && untagBits > pgIdxBits).option(UInt(coreMaxAddrBits.W))
  val tag  = Bits(width = coreParams.dcacheReqTagBits + log2Ceil(dcacheArbPorts))
  val cmd  = Bits(width = M_SZ)
  val size = Bits(width = log2Ceil(coreDataBytes.log2 + 1))
  val signed = Bool()
  val dprv = UInt(width = PRV.SZ)
  val dv = Bool()
}

trait HasCoreData extends HasCoreParameters {
  val data = Bits(width = coreDataBits)
  val mask = UInt(width = coreDataBytes)
}

class HellaCacheReqInternal(implicit p: Parameters) extends CoreBundle()(p) with HasCoreMemOp {
  val phys = Bool()
  val no_alloc = Bool()
  val no_xcpt = Bool()
}

class HellaCacheReq(implicit p: Parameters) extends HellaCacheReqInternal()(p) with HasCoreData

class HellaCacheResp(implicit p: Parameters) extends CoreBundle()(p)
    with HasCoreMemOp
    with HasCoreData {
  val replay = Bool()
  val has_data = Bool()
  val data_word_bypass = Bits(width = coreDataBits)
  val data_raw = Bits(width = coreDataBits)
  val store_data = Bits(width = coreDataBits)
}

class AlignmentExceptions extends Bundle {
  val ld = Bool()
  val st = Bool()
}

class HellaCacheExceptions extends Bundle {
  val ma = new AlignmentExceptions
  val pf = new AlignmentExceptions
  val gf = new AlignmentExceptions
  val ae = new AlignmentExceptions
}

class HellaCacheWriteData(implicit p: Parameters) extends CoreBundle()(p) with HasCoreData

class HellaCachePerfEvents extends Bundle {
  val acquire = Bool()
  val release = Bool()
  val grant = Bool()
  val tlbMiss = Bool()
  val blocked = Bool()
  val canAcceptStoreThenLoad = Bool()
  val canAcceptStoreThenRMW = Bool()
  val canAcceptLoadThenLoad = Bool()
  val storeBufferEmptyAfterLoad = Bool()
  val storeBufferEmptyAfterStore = Bool()
}

// interface between D$ and processor/DTLB
class HellaCacheIO(implicit p: Parameters) extends CoreBundle()(p) {
  val req = Decoupled(new HellaCacheReq)
  val s1_kill = Bool(OUTPUT) // kill previous cycle's req
  val s1_data = new HellaCacheWriteData().asOutput // data for previous cycle's req
  val s2_nack = Bool(INPUT) // req from two cycles ago is rejected
  val s2_nack_cause_raw = Bool(INPUT) // reason for nack is store-load RAW hazard (performance hint)
  val s2_kill = Bool(OUTPUT) // kill req from two cycles ago
  val s2_uncached = Bool(INPUT) // advisory signal that the access is MMIO
  val s2_paddr = UInt(INPUT, paddrBits) // translated address

  val resp = Valid(new HellaCacheResp).flip
  val replay_next = Bool(INPUT)
  val s2_xcpt = (new HellaCacheExceptions).asInput
  val s2_gpa = UInt(vaddrBitsExtended.W).asInput
  val s2_gpa_is_pte = Bool(INPUT)
  val uncached_resp = tileParams.dcache.get.separateUncachedResp.option(Decoupled(new HellaCacheResp).flip)
  val ordered = Bool(INPUT)
  val perf = new HellaCachePerfEvents().asInput

  val keep_clock_enabled = Bool(OUTPUT) // should D$ avoid clock-gating itself?
  val clock_enabled = Bool(INPUT) // is D$ currently being clocked?
}
```

### `src/main/scala/rocket/Consts.scala`

```scala
  def M_XRD     = UInt("b00000"); // int load
```

### `src/main/scala/rocket/PMP.scala`

```scala
  // returns whether this PMP completely contains, or contains none of, a page
  def homogeneous(x: UInt, pgLevel: UInt, prev: PMP): Bool =
    Mux(napot, pow2Homogeneous(x, pgLevel), !torNotNAPOT || rangeHomogeneous(x, pgLevel, prev))
// ...
class PMPHomogeneityChecker(pmps: Seq[PMP])(implicit p: Parameters) {
  def apply(addr: UInt, pgLevel: UInt): Bool = {
    pmps.foldLeft((true.B, 0.U.asTypeOf(new PMP))) { case ((h, prev), pmp) =>
      (h && pmp.homogeneous(addr, pgLevel, prev), pmp)
    }._1
  }
}
```

### `src/main/scala/rocket/TLBPermissions.scala`

```scala
case class TLBPermissions(
  homogeneous: Bool, // if false, the below are undefined
  r: Bool, // readable
  w: Bool, // writeable
  x: Bool, // executable
  c: Bool, // cacheable
  a: Bool, // arithmetic ops
  l: Bool) // logical ops
// ...
object TLBPageLookup
{
// ...
  // Unmapped memory is considered to be inhomogeneous
  def apply(managers: Seq[TLManagerParameters], xLen: Int, cacheBlockBytes: Int, pageSize: BigInt): UInt => TLBPermissions = {
// ...
  // Are all pageSize intervals of mapped regions homogeneous?
  def homogeneous(managers: Seq[TLManagerParameters], pageSize: BigInt): Boolean = {
// ...
}
```

### `src/main/scala/util/DescribedSRAM.scala`

```scala
object DescribedSRAM {
  def apply[T <: Data](
    name: String,
    desc: String,
    size: BigInt, // depth
    data: T
  ): (SyncReadMem[T], OMSRAM) = {
```

### `src/main/scala/chisel3/util/Decoupled.scala`

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

### `src/main/scala/chisel3/util/Valid.scala`

```scala
/** A [[Bundle]] that adds a `valid` bit to some data. This indicates that the user expects a "valid" interface between
  * a producer and a consumer. Here, the producer asserts the `valid` bit when data on the `bits` line contains valid
  * data. This differs from [[DecoupledIO]] or [[IrrevocableIO]] as there is no `ready` line that the consumer can use
  * to put back pressure on the producer.
  *
  * In most scenarios, the `Valid` class will ''not'' be used directly. Instead, users will create `Valid` interfaces
  * using the [[Valid$ Valid factory]].
  * @tparam T the type of the data
  * @param gen some data
  * @see [[Valid$ Valid factory]] for concrete examples
  * @groupdesc Signals The actual hardware fields of the Bundle
  */
class Valid[+T <: Data](gen: T) extends Bundle {

  /** A bit that will be asserted when `bits` is valid
    * @group Signals
    */
  val valid = Output(Bool())

  /** The data to be transferred, qualified by `valid`
    * @group Signals
    */
  val bits = Output(gen)

  /** True when `valid` is asserted
    * @return a Chisel [[Bool]] true if `valid` is asserted
    */
  def fire: Bool = valid

  @deprecated(
    "Calling this function with an empty argument list is invalid in Scala 3. Use the form without parentheses instead",
    "Chisel 3.5"
  )
  def fire(dummy: Int = 0): Bool = valid
}
```

## Related source code

### `src/main/scala/rocket/TLB.scala`

```scala
  io.ptw.req.bits.valid := !io.kill
  io.ptw.req.bits.bits.addr := r_refill_tag
  io.ptw.req.bits.bits.vstage1 := r_vstage1_en
  io.ptw.req.bits.bits.stage2 := r_stage2_en
  io.ptw.req.bits.bits.need_gpa := r_need_gpa
// ...
  val vstage1_en = Bool(usingHypervisor) && priv_v && io.ptw.vsatp.mode(io.ptw.vsatp.mode.getWidth-1)
  val stage2_en  = Bool(usingHypervisor) && priv_v && io.ptw.hgatp.mode(io.ptw.hgatp.mode.getWidth-1)
  val vm_enabled = (stage1_en || stage2_en) && priv_uses_vm && !io.req.bits.passthrough
// ...
  // permission bit arrays
  when (do_refill) {
    val pte = io.ptw.resp.bits.pte
    val newEntry = Wire(new TLBEntryData)
    newEntry.ppn := pte.ppn
    newEntry.v := r_vstage1_en || r_stage2_en
    newEntry.c := cacheable
    newEntry.u := pte.u
    newEntry.g := pte.g && pte.v
    newEntry.ae_ptw := io.ptw.resp.bits.ae_ptw
    newEntry.ae_final := io.ptw.resp.bits.ae_final
    newEntry.gf := io.ptw.resp.bits.gf
    newEntry.hr := io.ptw.resp.bits.hr
    newEntry.hw := io.ptw.resp.bits.hw
    newEntry.hx := io.ptw.resp.bits.hx
    newEntry.sr := pte.sr()
    newEntry.sw := pte.sw()
    newEntry.sx := pte.sx()
    newEntry.pr := prot_r
    newEntry.pw := prot_w
    newEntry.px := prot_x
    newEntry.ppp := prot_pp
    newEntry.pal := prot_al
    newEntry.paa := prot_aa
    newEntry.eff := prot_eff
    newEntry.fragmented_superpage := io.ptw.resp.bits.fragmented_superpage
// ...
    when (special_entry.nonEmpty && !io.ptw.resp.bits.homogeneous) {
      special_entry.foreach(_.insert(r_refill_tag, io.ptw.resp.bits.level, newEntry))
    }.elsewhen (io.ptw.resp.bits.level < pgLevels-1) {
      val waddr = Mux(r_superpage_hit.valid && usingHypervisor, r_superpage_hit.bits, r_superpage_repl_addr)
      for ((e, i) <- superpage_entries.zipWithIndex) when (r_superpage_repl_addr === i) {
        e.insert(r_refill_tag, io.ptw.resp.bits.level, newEntry)
```

### `src/main/scala/lsu/tlb.scala`

```scala
  io.ptw.req.valid := state === s_request
  io.ptw.req.bits.valid := !io.kill
  io.ptw.req.bits.bits.addr := r_refill_tag

// ...
    // permission bit arrays
  when (do_refill) {
    val pte = io.ptw.resp.bits.pte
    val newEntry = Wire(new EntryData)
    newEntry.ppn := pte.ppn
    newEntry.c := cacheable(0)
    newEntry.u := pte.u
    newEntry.g := pte.g
    newEntry.ae := io.ptw.resp.bits.ae_final
    newEntry.sr := pte.sr()
    newEntry.sw := pte.sw()
    newEntry.sx := pte.sx()
    newEntry.pr := prot_r(0)
    newEntry.pw := prot_w(0)
    newEntry.px := prot_x(0)
    newEntry.pal := prot_al(0)
    newEntry.paa := prot_aa(0)
    newEntry.eff := prot_eff(0)
    newEntry.fragmented_superpage := io.ptw.resp.bits.fragmented_superpage
// ...
    when (special_entry.nonEmpty.B && !io.ptw.resp.bits.homogeneous) {
      special_entry.foreach(_.insert(r_refill_tag, io.ptw.resp.bits.level, newEntry))
    }.elsewhen (io.ptw.resp.bits.level < (pgLevels-1).U) {
      for ((e, i) <- superpage_entries.zipWithIndex) when (r_superpage_repl_addr === i.U) {
        e.insert(r_refill_tag, io.ptw.resp.bits.level, newEntry)
```

### `src/main/scala/exu/core.scala`

```scala
    new freechips.rocketchip.rocket.EventSet((mask, hits) => (mask & hits).orR, Seq(
      ("I$ miss",     () => io.ifu.perf.acquire),
      ("D$ miss",     () => io.lsu.perf.acquire),
      ("D$ release",  () => io.lsu.perf.release),
      ("ITLB miss",   () => io.ifu.perf.tlbMiss),
      ("DTLB miss",   () => io.lsu.perf.tlbMiss),
      ("L2 TLB miss", () => io.ptw.perf.l2miss)))))
  val csr = Module(new freechips.rocketchip.rocket.CSRFile(perfEvents, boomParams.customCSRs.decls))
```

### `src/main/scala/rocket/PTW.scala`

```scala
/** Mix-ins for constructing tiles that might have a PTW */
trait CanHavePTW extends HasTileParameters with HasHellaCache { this: BaseTile =>
  val module: CanHavePTWModule
  val utlbOMSRAMs = collection.mutable.ListBuffer[OMSRAM]()
  var nPTWPorts = 1
  nDCachePorts += usingPTW.toInt
}

trait CanHavePTWModule extends HasHellaCacheModule {
  val outer: CanHavePTW
  val ptwPorts = ListBuffer(outer.dcache.module.io.ptw)
  val ptw = Module(new PTW(outer.nPTWPorts)(outer.dcache.node.edges.out(0), outer.p))
  if (outer.usingPTW) {
    dcachePorts += ptw.io.mem
    outer.utlbOMSRAMs ++= ptw.omSRAMs
  }
}
```

## Documentation

```text
rocket: separate page faults from physical memory access exceptions
...
PTWPerfEvents pte_miss/hit, l2hit (#2668)
...
PTW do not count pte_hit/miss on L2TLB hits (#2688)
...
PTW do not count pte_miss on leaf walk level (#2692)
```

### `src/supervisor.adoc`

```text
The supervisor memory-management fence instruction SFENCE.VMA is used to
synchronize updates to in-memory memory-management data structures with
current execution. Instruction execution causes implicit reads and
writes to these data structures; however, these implicit references are
ordinarily not ordered with respect to explicit loads and stores.
Executing an SFENCE.VMA instruction guarantees that any previous stores
already visible to the current RISC-V hart are ordered before certain
implicit references by subsequent instructions in that hart to the
memory-management data structures. The specific set of operations
ordered by SFENCE.VMA is determined by _rs1_ and _rs2_, as described
below. SFENCE.VMA is also used to invalidate entries in the
address-translation cache associated with a hart (see <<sv32algorithm>>). Further details on the behavior of this instruction are described in <<virt-control>> and <<pmp-vmem>>.
...
For the common case that the translation data structures have only been
modified for a single address mapping (i.e., one page or superpage),
_rs1_ can specify a virtual address within that mapping to effect a
translation fence for that mapping only. Furthermore, for the common
case that the translation data structures have only been modified for a
single address-space identifier, _rs2_ can specify the address space.
The behavior of SFENCE.VMA depends on _rs1_ and _rs2_ as follows:

* If __rs1__=`x0` and __rs2__=`x0`, the fence orders all reads and writes
made to any level of the page tables, for all address spaces. The fence
also invalidates all address-translation cache entries, for all address
spaces.
* If __rs1__=`x0` and __rs2__&#8800;``x0``, the fence orders all
reads and writes made to any level of the page tables, but only for the
address space identified by integer register _rs2_. Accesses to _global_
mappings (see <<translation>>) are not ordered. The
fence also invalidates all address-translation cache entries matching
the address space identified by integer register _rs2_, except for
entries containing global mappings.
* If __rs1__&#8800;``x0`` and __rs2__=`x0`, the fence orders only
reads and writes made to leaf page table entries corresponding to the
virtual address in __rs1__, for all address spaces. The fence also
invalidates all address-translation cache entries that contain leaf page
table entries corresponding to the virtual address in _rs1_, for all
address spaces.
* If __rs1__&#8800;``x0`` and __rs2__&#8800;``x0``, the
fence orders only reads and writes made to leaf page table entries
corresponding to the virtual address in _rs1_, for the address space
identified by integer register _rs2_. Accesses to global mappings are
not ordered. The fence also invalidates all address-translation cache
entries that contain leaf page table entries corresponding to the
virtual address in _rs1_ and that match the address space identified by
integer register _rs2_, except for entries containing global mappings.
...
The PTE format for Sv32 is shown in <<sv32pte>>.
The V bit indicates whether the PTE is valid; if it is 0, all other bits
in the PTE are don’t-cares and may be used freely by software. The
permission bits, R, W, and X, indicate whether the page is readable,
writable, and executable, respectively. When all three are zero, the PTE
is a pointer to the next level of the page table; otherwise, it is a
leaf PTE. Writable pages must also be marked readable; the contrary
combinations are reserved for future use. <<pteperm>>
summarizes the encoding of the permission bits.
...
For non-leaf PTEs, the D, A, and U bits are reserved for future standard
use. Until their use is defined by a standard extension, they must be
cleared by software for forward compatibility.
...
==== Virtual Address Translation Process

A virtual address _va_ is translated into a physical address _pa_ as follows:

. Let _a_ be ``satp``.__ppn__×PAGESIZE, and let __i__=LEVELS-1. (For Sv32, PAGESIZE=2^12^ and LEVELS=2.) The `satp` register must be
_active_, i.e., the effective privilege mode must be S-mode or U-mode.

. Let _pte_ be the value of the PTE at address __a__+__va__.__vpn__[__i__]×PTESIZE. (For Sv32, PTESIZE=4.)  If accessing _pte_ violates a PMA or PMP check, raise an access-fault exception corresponding to the original access type.

...
. Otherwise, the PTE is valid. If __pte__.__r__=1 or __pte__.__x__=1, go to step 5. Otherwise, this PTE is a pointer to the next level of the page table. Let __i=i__-1. If __i__<0, stop and raise a page-fault exception corresponding to the original access type. Otherwise, let
__a__=__pte__.__ppn__×PAGESIZE and go to step 2.

. A leaf PTE has been reached. If _i>0_ and _pte_._ppn_[__i__-1:0] ≠ 0, this is a misaligned superpage; stop and raise a page-fault exception corresponding to the original access type.
...
. The translation is successful. The translated physical address is
given as follows:
* _pa.pgoff_ = _va.pgoff_.
* If _i_>0, then this is a superpage translation and __pa.ppn__[__i__-1:0] = __va.vpn__[__i__-1:0].
* _pa.ppn_[LEVELS-1:__i__] = _pte_._ppn_[LEVELS-1:__i__].

All implicit accesses to the address-translation data structures in this
algorithm are performed using width PTESIZE.
...
The results of implicit address-translation reads in step 2 may be held
in a read-only, incoherent _address-translation cache_ but not shared
with other harts. The address-translation cache may hold an arbitrary
number of entries, including an arbitrary number of entries for the same
address and ASID. Entries in the address-translation cache may then
satisfy subsequent step 2 reads if the ASID associated with the entry
matches the ASID loaded in step 0 or if the entry is associated with a
_global_ mapping. To ensure that implicit reads observe writes to the
same memory locations, an SFENCE.VMA instruction must be executed after
the writes to flush the relevant cached translations.
...
Sv39 implementations support a 39-bit virtual address space, divided
into pages. An Sv39 address is partitioned as shown in
<<sv39va>>. Instruction fetch addresses and load and
store effective addresses, which are 64 bits, must have bits 63–39 all
equal to bit 38, or else a page-fault exception will occur. The 27-bit
VPN is translated into a 44-bit PPN via a three-level page table, while
the 12-bit page offset is untranslated.
...
Sv39 page tables contain 2^9^ page table entries (PTEs),
eight bytes each. A page table is exactly the size of a page and must
always be aligned to a page boundary. The physical page number of the
root page table is stored in the `satp` register's PPN field.
...
Any level of PTE may be a leaf PTE, so in addition to 4 KiB pages, Sv39
supports 2 MiB _megapages_ and 1 GiB _gigapages_, each of which must be virtually and physically aligned to a boundary equal to its size. A page-fault exception is raised if the physical address is insufficiently aligned.

The algorithm for virtual-to-physical address translation is the same as
in <<sv32algorithm>>, except LEVELS equals 3 and PTESIZE equals 8.
```

### `src/supervisor.tex`

```text
Each leaf PTE contains an accessed (A) and dirty (D) bit.  The A bit indicates
the virtual page has been read, written, or fetched from since the last time
the A bit was cleared.  The D bit indicates the virtual page has been written
since the last time the D bit was cleared.
```

### `src/machine.adoc`

```text
PMP checks are applied to all accesses whose effective privilege mode is
S or U, including instruction fetches and data accesses in S and U mode,
and data accesses in M-mode when the MPRV bit in `mstatus` is set and
the MPP field in `mstatus` contains S or U. PMP checks are also applied
to page-table accesses for virtual-address translation, for which the
effective privilege mode is S. Optionally, PMP checks may additionally
apply to M-mode accesses, in which case the PMP registers themselves are
locked, so that even M-mode software cannot change them until the hart
is reset. In effect, PMP can _grant_ permissions to S and U modes, which
by default have none, and can _revoke_ permissions from M-mode, which by
default has full permissions.
```
