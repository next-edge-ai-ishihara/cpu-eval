# Implement `NBDTLB`

Implement the complete `NBDTLB` module. Preserve its class declaration and public interface. Return only the complete `class NBDTLB` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/config-mixins.scala`

```scala
class WithNLargeBooms(n: Int = 1, overrideIdOffset: Option[Int] = None) extends Config(
// ...
                IssueParams(issueWidth=1, numEntries=16, iqType=IQT_MEM.litValue, dispatchWidth=3),
// ...
            dcache = Some(
              DCacheParams(rowBits = site(SystemBusKey).beatBits, nSets=64, nWays=8, nMSHRs=4, nTLBWays=16)
            ),
// ...
    case XLen => 64
// ...
```

### `src/main/scala/common/parameters.scala`

```scala
case class BoomCoreParams(
// ...
  useAtomicsOnlyForIO: Boolean = false,
// ...
  nPMPs: Int = 8,
// ...
  haveCFlush: Boolean = false,
// ...
  useAtomics: Boolean = true,
// ...
  useUser: Boolean = true,
  useSupervisor: Boolean = false,
  useHypervisor: Boolean = false,
  useVM: Boolean = true,
// ...
  val pmpGranularity: Int = 4
// ...
```

### `src/main/scala/rocket/HellaCache.scala`

```scala
case class DCacheParams(
// ...
    nTLBSets: Int = 1,
// ...
    scratch: Option[BigInt] = None) extends L1CacheParams {
// ...
```

### `src/main/scala/subsystem/Configs.scala`

```scala
class BaseSubsystemConfig extends Config ((site, here, up) => {
// ...
  case PgLevels => if (site(XLen) == 64) 3 /* Sv39 */ else 2 /* Sv32 */
// ...
```

## Package and imports

### `src/main/scala/lsu/tlb.scala`

```scala
package boom.lsu

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.rocket._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.subsystem.{CacheBlockBytes}
import freechips.rocketchip.diplomacy.{RegionType}
import freechips.rocketchip.util._

import boom.common._
import boom.exu.{BrResolutionInfo, Exception, FuncUnitResp, CommitSignals}
import boom.util.{BoolToChar, AgePriorityEncoder, IsKilledByBranch, GetNewBrMask, WrapInc, IsOlder, UpdateBrMask}
```

## Class declaration

```scala
class NBDTLB(instruction: Boolean, lgMaxSize: Int, cfg: TLBConfig)(implicit edge: TLEdgeOut, p: Parameters) extends BoomModule()(p) {
  require(!instruction)
  val io = IO(new Bundle {
    val req = Flipped(Vec(memWidth, Decoupled(new TLBReq(lgMaxSize))))
    val miss_rdy = Output(Bool())
    val resp = Output(Vec(memWidth, new TLBResp))
    val sfence = Input(Valid(new SFenceReq))
    val ptw = new TLBPTWIO
    val kill = Input(Bool())
  })
```

## Parent instantiation

### `src/main/scala/lsu/lsu.scala`

```scala
  val dtlb = Module(new NBDTLB(
    instruction = false, lgMaxSize = log2Ceil(coreDataBytes), rocket.TLBConfig(dcacheParams.nTLBSets, dcacheParams.nTLBWays)))

  io.ptw <> dtlb.io.ptw
  io.core.perf.tlbMiss := io.ptw.req.fire
// ...
  // Can we retry a load that missed in the TLB
  val can_fire_load_retry    = widthMap(w =>
                               ( ldq_retry_e.valid                            &&
                                 ldq_retry_e.bits.addr.valid                  &&
                                 ldq_retry_e.bits.addr_is_virtual             &&
                                !p1_block_load_mask(ldq_retry_idx)            &&
                                !p2_block_load_mask(ldq_retry_idx)            &&
                                RegNext(dtlb.io.miss_rdy)                     &&
                                !store_needs_order                            &&
                                (w == memWidth-1).B                           && // TODO: Is this best scheduling?
                                !ldq_retry_e.bits.order_fail))

  // Can we retry a store addrgen that missed in the TLB
  // - Weird edge case when sta_retry and std_incoming for same entry in same cycle. Delay this
  val can_fire_sta_retry     = widthMap(w =>
                               ( stq_retry_e.valid                            &&
                                 stq_retry_e.bits.addr.valid                  &&
                                 stq_retry_e.bits.addr_is_virtual             &&
                                 (w == memWidth-1).B                          &&
                                 RegNext(dtlb.io.miss_rdy)                    &&
                                 !(widthMap(i => (i != w).B               &&
                                                 can_fire_std_incoming(i) &&
                                                 stq_incoming_idx(i) === stq_retry_idx).reduce(_||_))
                               ))
// ...
  val exe_passthr= widthMap(w =>
                   Mux(will_fire_hella_incoming(w)  , hella_req.phys,
                                                      false.B))
  val exe_kill   = widthMap(w =>
                   Mux(will_fire_hella_incoming(w)  , io.hellacache.s1_kill,
                                                      false.B))
  for (w <- 0 until memWidth) {
    dtlb.io.req(w).valid            := exe_tlb_valid(w)
    dtlb.io.req(w).bits.vaddr       := exe_tlb_vaddr(w)
    dtlb.io.req(w).bits.size        := exe_size(w)
    dtlb.io.req(w).bits.cmd         := exe_cmd(w)
    dtlb.io.req(w).bits.passthrough := exe_passthr(w)
    dtlb.io.req(w).bits.v           := io.ptw.status.v
    dtlb.io.req(w).bits.prv         := io.ptw.status.prv
  }
  dtlb.io.kill                      := exe_kill.reduce(_||_)
  dtlb.io.sfence                    := exe_sfence

  // exceptions
  val ma_ld = widthMap(w => will_fire_load_incoming(w) && exe_req(w).bits.mxcpt.valid) // We get ma_ld in memaddrcalc
  val ma_st = widthMap(w => (will_fire_sta_incoming(w) || will_fire_stad_incoming(w)) && exe_req(w).bits.mxcpt.valid) // We get ma_ld in memaddrcalc
  val pf_ld = widthMap(w => dtlb.io.req(w).valid && dtlb.io.resp(w).pf.ld && exe_tlb_uop(w).uses_ldq)
  val pf_st = widthMap(w => dtlb.io.req(w).valid && dtlb.io.resp(w).pf.st && exe_tlb_uop(w).uses_stq)
  val ae_ld = widthMap(w => dtlb.io.req(w).valid && dtlb.io.resp(w).ae.ld && exe_tlb_uop(w).uses_ldq)
  val ae_st = widthMap(w => dtlb.io.req(w).valid && dtlb.io.resp(w).ae.st && exe_tlb_uop(w).uses_stq)

  // TODO check for xcpt_if and verify that never happens on non-speculative instructions.
  val mem_xcpt_valids = RegNext(widthMap(w =>
                     (pf_ld(w) || pf_st(w) || ae_ld(w) || ae_st(w) || ma_ld(w) || ma_st(w)) &&
                     !io.core.exception &&
                     !IsKilledByBranch(io.core.brupdate, exe_tlb_uop(w))))
  val mem_xcpt_uops   = RegNext(widthMap(w => UpdateBrMask(io.core.brupdate, exe_tlb_uop(w))))
  val mem_xcpt_causes = RegNext(widthMap(w =>
    Mux(ma_ld(w), rocket.Causes.misaligned_load.U,
    Mux(ma_st(w), rocket.Causes.misaligned_store.U,
    Mux(pf_ld(w), rocket.Causes.load_page_fault.U,
    Mux(pf_st(w), rocket.Causes.store_page_fault.U,
    Mux(ae_ld(w), rocket.Causes.load_access.U,
                  rocket.Causes.store_access.U)))))))
// ...
  val exe_tlb_miss  = widthMap(w => dtlb.io.req(w).valid && (dtlb.io.resp(w).miss || !dtlb.io.req(w).ready))
  val exe_tlb_paddr = widthMap(w => Cat(dtlb.io.resp(w).paddr(paddrBits-1,corePgIdxBits),
                                        exe_tlb_vaddr(w)(corePgIdxBits-1,0)))
  val exe_tlb_uncacheable = widthMap(w => !(dtlb.io.resp(w).cacheable))

  for (w <- 0 until memWidth) {
    assert (exe_tlb_paddr(w) === dtlb.io.resp(w).paddr || exe_req(w).bits.sfence.valid, "[lsu] paddrs should match.")
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
// ...
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

### `src/main/scala/rocket/CSR.scala`

```scala
class MStatus extends Bundle {
  // not truly part of mstatus, but convenient
  val debug = Bool()
  val cease = Bool()
  val wfi = Bool()
  val isa = UInt(width = 32)

  val dprv = UInt(width = PRV.SZ) // effective prv for data accesses
  val dv = Bool() // effective v for data accesses
  val prv = UInt(width = PRV.SZ)
  val v = Bool()
// ...
  val mxr = Bool()
  val sum = Bool()
  val mprv = Bool()
// ...
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

### `src/main/scala/rocket/PMP.scala`

```scala
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

object TLBPageLookup
{
// ...
  // Unmapped memory is considered to be inhomogeneous
  def apply(managers: Seq[TLManagerParameters], xLen: Int, cacheBlockBytes: Int, pageSize: BigInt): UInt => TLBPermissions = {
```

### `src/main/scala/diplomacy/Parameters.scala`

```scala
  case object PUT_EFFECTS extends T // puts produce side effects and so must not be combined/delayed
  case object GET_EFFECTS extends T // gets produce side effects and so must not be issued speculatively
```

### `src/main/scala/tilelink/package.scala`

```scala
  type TLManagerParameters = TLSlaveParameters
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
  val supports:           TLMasterToSlaveTransferSizes,
  val emits:              TLSlaveToMasterTransferSizes,
  // By default, slaves are forbidden from issuing 'denied' responses (it prevents Fragmentation)
  val alwaysGrantsT:      Boolean, // typically only true for CacheCork'd read-write devices; dual: neverReleaseData
  // If fifoId=Some, all accesses sent to the same fifoId are executed and ACK'd in FIFO order
  // Note: you can only rely on this FIFO behaviour if your TLMasterParameters include requestFifo
  val mayDenyGet:         Boolean, // applies to: AccessAckData, GrantData
  val mayDenyPut:         Boolean) // applies to: AccessAck,     Grant,    HintAck
                                   // ReleaseAck may NEVER be denied
// ...
  def supportsAcquireT:   TransferSizes = supports.acquireT
  def supportsAcquireB:   TransferSizes = supports.acquireB
  def supportsArithmetic: TransferSizes = supports.arithmetic
  def supportsLogical:    TransferSizes = supports.logical
  def supportsGet:        TransferSizes = supports.get
  def supportsPutFull:    TransferSizes = supports.putFull
  def supportsPutPartial: TransferSizes = supports.putPartial
  def supportsHint:       TransferSizes = supports.hint
// ...
  // The safe version will check the entire address
  def findSafe(address: UInt) = Vec(slaves.map(_.address.map(_.contains(address)).reduce(_ || _)))
// ...
  // Select a property
  def fastProperty[K, D <: Data](address: UInt, p: TLSlaveParameters => K, d: K => D): D =
    Mux1H(fastPropertyGroup(p).map { case (v, a) => (a.map(_.contains(address)).reduce(_||_), d(v)) })
```

### `src/main/scala/rocket/Consts.scala`

```scala
  val M_SZ      = 5
// ...
  def M_XRD     = UInt("b00000"); // int load
  def M_XWR     = UInt("b00001"); // int store
// ...
  def M_XA_SWAP = UInt("b00100");
// ...
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
// ...
  def M_PWR     = UInt("b10001") // partial (masked) store
// ...
  def M_HLVX    = UInt("b10000") // HLVX instruction

  def isAMOLogical(cmd: UInt) = cmd.isOneOf(M_XA_SWAP, M_XA_XOR, M_XA_OR, M_XA_AND)
  def isAMOArithmetic(cmd: UInt) = cmd.isOneOf(M_XA_ADD, M_XA_MIN, M_XA_MAX, M_XA_MINU, M_XA_MAXU)
  def isAMO(cmd: UInt) = isAMOLogical(cmd) || isAMOArithmetic(cmd)
// ...
  def isRead(cmd: UInt) = cmd.isOneOf(M_XRD, M_HLVX, M_XLR, M_XSC) || isAMO(cmd)
  def isWrite(cmd: UInt) = cmd === M_XWR || cmd === M_PWR || cmd === M_XSC || isAMO(cmd)
```

### `src/main/scala/tile/BaseTile.scala`

```scala
  def usingVM: Boolean = tileParams.core.useVM
  def usingUser: Boolean = tileParams.core.useUser || usingSupervisor
  def usingSupervisor: Boolean = tileParams.core.hasSupervisorMode
  def usingHypervisor: Boolean = usingVM && tileParams.core.useHypervisor
// ...
  def usingDataScratchpad: Boolean = tileParams.dcache.flatMap(_.scratch).isDefined

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
  def vmIdBits: Int = p(VMIdBits)
  lazy val maxPAddrBits: Int = {
    require(xLen == 32 || xLen == 64, s"Only XLENs of 32 or 64 are supported, but got $xLen")
    xLen match { case 32 => 34; case 64 => 56 }
  }
// ...
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
```

### `src/main/scala/tile/Core.scala`

```scala
  def hasSupervisorMode: Boolean = useSupervisor || useVM
// ...
  val usingAtomics = coreParams.useAtomics
  val usingAtomicsOnlyForIO = coreParams.useAtomicsOnlyForIO
  val usingAtomicsInCache = usingAtomics && !usingAtomicsOnlyForIO
```

### `src/main/scala/common/parameters.scala`

```scala
  require (issueParams.count(_.iqType == IQT_MEM.litValue) == 1)
  require (issueParams.count(_.iqType == IQT_INT.litValue) == 1)

  val intIssueParam = issueParams.find(_.iqType == IQT_INT.litValue).get
  val memIssueParam = issueParams.find(_.iqType == IQT_MEM.litValue).get

  val intWidth = intIssueParam.issueWidth
  val memWidth = memIssueParam.issueWidth
```

## Related source code

### `src/main/scala/rocket/TLB.scala`

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

### `src/main/scala/rocket/CSR.scala`

```scala
  io.status.dprv := Mux(reg_mstatus.mprv && !reg_debug, reg_mstatus.mpp, reg_mstatus.prv)
  io.status.dv := reg_mstatus.v || Mux(reg_mstatus.mprv && !reg_debug, reg_mstatus.mpv, false.B)
```

## Documentation

### `src/supervisor.adoc`

```text
The `satp` CSR is an SXLEN-bit read/write register, formatted as
shown in <<rv32satp>> for SXLEN=32 and
<<rv64satp>> for SXLEN=64, which controls
supervisor-mode address translation and protection. This register holds
the physical page number (PPN) of the root page table, i.e., its
supervisor physical address divided by 4 KiB; an address space identifier
(ASID), which facilitates address-translation fences on a
per-address-space basis; and the MODE field, which selects the current
address-translation scheme. Further details on the access to this
register are described in <<virt-control>>.
...
<<satp-mode>> shows the encodings of the MODE field when
SXLEN=32 and SXLEN=64. When MODE=Bare, supervisor virtual addresses are
equal to supervisor physical addresses, and there is no additional
memory protection beyond the physical memory protection scheme described
in <<pmp>>. To select MODE=Bare, software must write
zero to the remaining fields of `satp` (bits 30–0 when SXLEN=32, or bits
59–0 when SXLEN=64). Attempting to select MODE=Bare with a nonzero
pattern in the remaining fields has an UNSPECIFIED effect on the value that the
remaining fields assume and an UNSPECIFIED effect on address translation and
protection behavior.
...
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
It is always legal to over-fence, e.g., by fencing only based on a
subset of the bits in _rs1_ and/or _rs2_, and/or by simply treating all
SFENCE.VMA instructions as having _rs1_=`x0` and/or _rs2_=`x0`. For
example, simpler implementations can ignore the virtual address in _rs1_
and the ASID value in _rs2_ and always perform a global fence. The
choice not to raise an exception when an invalid virtual address is held
in _rs1_ facilitates this type of simplification.
...
A virtual address _va_ is translated into a physical address _pa_ as follows:

. Let _a_ be ``satp``.__ppn__×PAGESIZE, and let __i__=LEVELS-1. (For Sv32, PAGESIZE=2^12^ and LEVELS=2.) The `satp` register must be
_active_, i.e., the effective privilege mode must be S-mode or U-mode.
...
. Determine if the requested memory access is allowed by the _pte_._u_ bit, given the current privilege mode and the value of the SUM and MXR fields of the *mstatus* register. If not, stop and raise a page-fault exception corresponding to the original access type.
...
. Determine if the requested memory access is allowed by the _pte_._r_, _pte_._w_, and _pte_._x_ bits. If not, stop and raise a page-fault exception corresponding to the original access type.
...
. The translation is successful. The translated physical address is
given as follows:
* _pa.pgoff_ = _va.pgoff_.
* If _i_>0, then this is a superpage translation and __pa.ppn__[__i__-1:0] = __va.vpn__[__i__-1:0].
* _pa.ppn_[LEVELS-1:__i__] = _pte_._ppn_[LEVELS-1:__i__].
...
Speculative executions of the address-translation algorithm behave as
non-speculative executions of the algorithm do, except that they must
not set the dirty bit for a PTE, they must not trigger an exception, and
they must not create address-translation cache entries if those entries
would have been invalidated by any SFENCE.VMA instruction executed by
the hart since the speculative execution of the algorithm began.
...
==== Addressing and Memory Protection

Sv39 implementations support a 39-bit virtual address space, divided
into pages. An Sv39 address is partitioned as shown in
<<sv39va>>. Instruction fetch addresses and load and
store effective addresses, which are 64 bits, must have bits 63–39 all
equal to bit 38, or else a page-fault exception will occur. The 27-bit
VPN is translated into a 44-bit PPN via a three-level page table, while
the 12-bit page offset is untranslated.
```

### `src/machine.adoc`

```text
The MPRV (Modify PRiVilege) bit modifies the _effective privilege mode_,
i.e., the privilege level at which loads and stores execute. When
MPRV=0, loads and stores behave as normal, using the translation and
protection mechanisms of the current privilege mode. When MPRV=1, load
and store memory addresses are translated and protected, and endianness
is applied, as though the current privilege mode were set to MPP.
Instruction address-translation and protection are unaffected by the
setting of MPRV. MPRV is read-only 0 if U-mode is not supported.
...
The MXR (Make eXecutable Readable) bit modifies the privilege with which
loads access virtual memory. When MXR=0, only loads from pages marked
readable (R=1 in <<sv32pte>>) will succeed. When
MXR=1, loads from pages marked either readable or executable (R=1 or
X=1) will succeed. MXR has no effect when page-based virtual memory is
not in effect. MXR is read-only 0 if S-mode is not supported.
...
The SUM (permit Supervisor User Memory access) bit modifies the
privilege with which S-mode loads and stores access virtual memory. When
SUM=0, S-mode memory accesses to pages that are accessible by U-mode
(U=1 in <<sv32pte>>) will fault. When SUM=1, these
accesses are permitted. SUM has no effect when page-based virtual memory
is not in effect. Note that, while SUM is ordinarily ignored when not
executing in S-mode, it _is_ in effect when MPRV=1 and MPP=S. SUM is
read-only 0 if S-mode is not supported or if `satp`.MODE is read-only 0.

The MXR and SUM mechanisms only affect the interpretation of permissions
encoded in page-table entries. In particular, they have no impact on
whether access-fault exceptions are raised due to PMAs or PMP.
...
To support secure processing and contain faults, it is desirable to
limit the physical addresses accessible by software running on a hart.
An optional physical memory protection (PMP) unit provides per-hart
machine-mode control registers to allow physical memory access
privileges (read, write, execute) to be specified for each physical
memory region. The PMP values are checked in parallel with the PMA
checks described in <<pma>>.

The granularity of PMP access control settings are platform-specific,
but the standard PMP encoding supports regions as small as four bytes.
Certain regions’ privileges can be hardwired—for example, some regions
might only ever be visible in machine mode but in no lower-privilege
layers.
...
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

PMP violations are always trapped precisely at the processor.
```
