# Implement `BoomCore`

Implement one complete `BoomCore` Chisel definition. Preserve the definition name, constructor parameters, inheritance, and public interface, including the `coreMonitorBundle` member.

Return only the complete `class BoomCore` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/common/config-mixins.scala

```scala
// DOC include start: LargeBoomConfig
/**
 * 3-wide BOOM. Try to match the Cortex-A15.
 */
class WithNLargeBooms(n: Int = 1, overrideIdOffset: Option[Int] = None) extends Config(
  new WithTAGELBPD ++ // Default to TAGE-L BPD
  new Config((site, here, up) => {
    case TilesLocated(InSubsystem) => {
      val prev = up(TilesLocated(InSubsystem), site)
      val idOffset = overrideIdOffset.getOrElse(prev.size)
      (0 until n).map { i =>
        BoomTileAttachParams(
          tileParams = BoomTileParams(
            core = BoomCoreParams(
              fetchWidth = 8,
              decodeWidth = 3,
              numRobEntries = 96,
              issueParams = Seq(
                IssueParams(issueWidth=1, numEntries=16, iqType=IQT_MEM.litValue, dispatchWidth=3),
                IssueParams(issueWidth=3, numEntries=32, iqType=IQT_INT.litValue, dispatchWidth=3),
                IssueParams(issueWidth=1, numEntries=24, iqType=IQT_FP.litValue , dispatchWidth=3)),
              numIntPhysRegisters = 100,
              numFpPhysRegisters = 96,
              numLdqEntries = 24,
              numStqEntries = 24,
              maxBrCount = 16,
              numFetchBufferEntries = 24,
              ftq = FtqParameters(nEntries=32),
              fpu = Some(freechips.rocketchip.tile.FPUParams(sfmaLatency=4, dfmaLatency=4, divSqrt=true))
            ),
            dcache = Some(
              DCacheParams(rowBits = site(SystemBusKey).beatBits, nSets=64, nWays=8, nMSHRs=4, nTLBWays=16)
            ),
            icache = Some(
              ICacheParams(rowBits = site(SystemBusKey).beatBits, nSets=64, nWays=8, fetchBytes=4*4)
            ),
            hartId = i + idOffset
          ),
          crossingParams = RocketCrossingParams()
        )
      } ++ prev
    }
    case SystemBusKey => up(SystemBusKey, site).copy(beatBytes = 16)
    case XLen => 64
  })
)
// DOC include end: LargeBoomConfig
```

## Package and imports

```scala
//******************************************************************************
// Copyright (c) 2015 - 2019, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE and LICENSE.SiFive for license details.
//------------------------------------------------------------------------------
// ...
package boom.exu

import java.nio.file.{Paths}

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.rocket.Instructions._
import freechips.rocketchip.rocket.{Causes, PRV}
import freechips.rocketchip.util.{Str, UIntIsOneOf, CoreMonitorBundle}
import freechips.rocketchip.devices.tilelink.{PLICConsts, CLINTConsts}

import testchipip.{ExtendedTracedInstruction}

import boom.common._
import boom.ifu.{GlobalHistory, HasBoomFrontendParameters}
import boom.exu.FUConstants._
import boom.util._
```

## Class declaration

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

## Parent instantiation

### src/main/scala/common/tile.scala

```scala
class BoomTileModuleImp(outer: BoomTile) extends BaseTileModuleImp(outer){

  Annotated.params(this, outer.boomParams)

  val core = Module(new BoomCore(outer.boomParams.trace)(outer.p))
  val lsu  = Module(new LSU()(outer.p, outer.dcache.module.edge))

  val ptwPorts         = ListBuffer(lsu.io.ptw, outer.frontend.module.io.ptw, core.io.ptw_tlb)

  val hellaCachePorts  = ListBuffer[HellaCacheIO]()

  outer.reportWFI(None) // TODO: actually report this?

  outer.decodeCoreInterrupts(core.io.interrupts) // Decode the interrupt vector

  // Pass through various external constants and reports
  outer.extTraceSourceNode.bundle <> core.io.trace
  outer.traceSourceNode.bundle <> DontCare
  outer.bpwatchSourceNode.bundle <> DontCare // core.io.bpwatch
  core.io.hartid := outer.hartIdSinkNode.bundle

  // Connect the core pipeline to other intra-tile modules
  outer.frontend.module.io.cpu <> core.io.ifu
  core.io.lsu <> lsu.io.core

  //fpuOpt foreach { fpu => core.io.fpu <> fpu.io } RocketFpu - not needed in boom
  core.io.rocc := DontCare
// ...
  // PTW
  val ptw  = Module(new PTW(ptwPorts.length)(outer.dcache.node.edges.out(0), outer.p))
  core.io.ptw <> ptw.io.dpath
  ptw.io.requestor <> ptwPorts
  hellaCachePorts += ptw.io.mem

   // LSU IO
  val hellaCacheArb = Module(new HellaCacheArbiter(hellaCachePorts.length)(outer.p))
  hellaCacheArb.io.requestor <> hellaCachePorts
  lsu.io.hellacache <> hellaCacheArb.io.mem
  outer.dcache.module.io.lsu <> lsu.io.dmem
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

### src/main/scala/common/parameters.scala

```scala
/**
 * Default BOOM core parameters
 */
case class BoomCoreParams(
// DOC include start: BOOM Parameters
  fetchWidth: Int = 1,
  decodeWidth: Int = 1,
  numRobEntries: Int = 64,
  issueParams: Seq[IssueParams] = Seq(
    IssueParams(issueWidth=1, numEntries=16, iqType=IQT_MEM.litValue, dispatchWidth=1),
    IssueParams(issueWidth=2, numEntries=16, iqType=IQT_INT.litValue, dispatchWidth=1),
    IssueParams(issueWidth=1, numEntries=16, iqType=IQT_FP.litValue , dispatchWidth=1)),
  numLdqEntries: Int = 16,
  numStqEntries: Int = 16,
  numIntPhysRegisters: Int = 96,
  numFpPhysRegisters: Int = 64,
  maxBrCount: Int = 4,
  numFetchBufferEntries: Int = 16,
  enableAgePriorityIssue: Boolean = true,
  enablePrefetching: Boolean = false,
  enableFastLoadUse: Boolean = true,
  enableCommitMapTable: Boolean = false,
  enableFastPNR: Boolean = false,
  enableSFBOpt: Boolean = false,
  enableGHistStallRepair: Boolean = true,
  enableBTBFastRepair: Boolean = true,
  useAtomicsOnlyForIO: Boolean = false,
  ftq: FtqParameters = FtqParameters(),
  intToFpLatency: Int = 2,
  imulLatency: Int = 3,
  nPerfCounters: Int = 0,
  numRXQEntries: Int = 4,
  numRCQEntries: Int = 8,
  numDCacheBanks: Int = 1,
  nPMPs: Int = 8,
  enableICacheDelay: Boolean = false,

  /* branch prediction */
  enableBranchPrediction: Boolean = true,
  branchPredictor: Function2[BranchPredictionBankResponse, Parameters, Tuple2[Seq[BranchPredictorBank], BranchPredictionBankResponse]] = ((resp_in: BranchPredictionBankResponse, p: Parameters) => (Nil, resp_in)),
  globalHistoryLength: Int = 64,
  localHistoryLength: Int = 32,
  localHistoryNSets: Int = 128,
  bpdMaxMetaLength: Int = 120,
  numRasEntries: Int = 32,
  enableRasTopRepair: Boolean = true,

  /* more stuff */
  useCompressed: Boolean = true,
  useFetchMonitor: Boolean = true,
  bootFreqHz: BigInt = 0,
  fpu: Option[FPUParams] = Some(FPUParams(sfmaLatency=4, dfmaLatency=4)),
  usingFPU: Boolean = true,
  haveBasicCounters: Boolean = true,
  misaWritable: Boolean = false,
  mtvecInit: Option[BigInt] = Some(BigInt(0)),
  mtvecWritable: Boolean = true,
  haveCFlush: Boolean = false,
  mulDiv: Option[freechips.rocketchip.rocket.MulDivParams] = Some(MulDivParams(divEarlyOut=true)),
  nBreakpoints: Int = 0, // TODO Fix with better frontend breakpoint unit
  nL2TLBEntries: Int = 512,
  val nPTECacheEntries: Int = 8, // TODO: check
  nL2TLBWays: Int = 1,
  nLocalInterrupts: Int = 0,
  useNMI: Boolean = false,
  useAtomics: Boolean = true,
  useDebug: Boolean = true,
  useUser: Boolean = true,
  useSupervisor: Boolean = false,
  useHypervisor: Boolean = false,
  useVM: Boolean = true,
  useSCIE: Boolean = false,
  useRVE: Boolean = false,
  useBPWatch: Boolean = false,
  clockGate: Boolean = false,
  mcontextWidth: Int = 0,
  scontextWidth: Int = 0,

  /* debug stuff */
  enableCommitLogPrintf: Boolean = false,
  enableBranchPrintf: Boolean = false,
  enableMemtracePrintf: Boolean = false

// DOC include end: BOOM Parameters
) extends freechips.rocketchip.tile.CoreParams
{
  val haveFSDirty = true
  val pmpGranularity: Int = 4
  val instBits: Int = 16
  val lrscCycles: Int = 80 // worst case is 14 mispredicted branches + slop
  val retireWidth = decodeWidth
  val jumpInFrontend: Boolean = false // unused in boom

  override def customCSRs(implicit p: Parameters) = new BoomCustomCSRs
}
// ...
/**
 * Mixin trait to add BOOM parameters to expand other traits/objects/etc
 */
trait HasBoomCoreParameters extends freechips.rocketchip.tile.HasCoreParameters
{
  val boomParams: BoomCoreParams = tileParams.core.asInstanceOf[BoomCoreParams]

  //************************************
  // Superscalar Widths

  // fetchWidth provided by CoreParams class.
  // decodeWidth provided by CoreParams class.

  // coreWidth is width of decode, width of integer rename, width of ROB, and commit width
  val coreWidth = decodeWidth

  require (isPow2(fetchWidth))
  require (coreWidth <= fetchWidth)

  //************************************
  // Data Structure Sizes
  val numRobEntries = boomParams.numRobEntries       // number of ROB entries (e.g., 32 entries for R10k)
  val numRxqEntries = boomParams.numRXQEntries       // number of RoCC execute queue entries. Keep small since this holds operands and instruction bits
  val numRcqEntries = boomParams.numRCQEntries       // number of RoCC commit queue entries. This can be large since it just keeps a pdst
  val numLdqEntries = boomParams.numLdqEntries       // number of LAQ entries
  val numStqEntries = boomParams.numStqEntries       // number of SAQ/SDQ entries
  val maxBrCount    = boomParams.maxBrCount          // number of branches we can speculate simultaneously
  val ftqSz         = boomParams.ftq.nEntries        // number of FTQ entries
  val numFetchBufferEntries = boomParams.numFetchBufferEntries // number of instructions that stored between fetch&decode

  val numIntPhysRegs= boomParams.numIntPhysRegisters // size of the integer physical register file
  val numFpPhysRegs = boomParams.numFpPhysRegisters  // size of the floating point physical register file

  //************************************
  // Functional Units
  val usingFDivSqrt = boomParams.fpu.isDefined && boomParams.fpu.get.divSqrt

  val mulDivParams = boomParams.mulDiv.getOrElse(MulDivParams())
  // TODO: Allow RV32IF
  require(!(xLen == 32 && usingFPU), "RV32 does not support fp")

  //************************************
  // Pipelining

  val imulLatency = boomParams.imulLatency
  val dfmaLatency = if (boomParams.fpu.isDefined) boomParams.fpu.get.dfmaLatency else 3
  val sfmaLatency = if (boomParams.fpu.isDefined) boomParams.fpu.get.sfmaLatency else 3
  // All FPU ops padded out to same delay for writeport scheduling.
  require (sfmaLatency == dfmaLatency)

  val intToFpLatency = boomParams.intToFpLatency

  //************************************
  // Issue Units

  val issueParams: Seq[IssueParams] = boomParams.issueParams
  val enableAgePriorityIssue = boomParams.enableAgePriorityIssue

  // currently, only support one of each.
  require (issueParams.count(_.iqType == IQT_FP.litValue) == 1 || !usingFPU)
  require (issueParams.count(_.iqType == IQT_MEM.litValue) == 1)
  require (issueParams.count(_.iqType == IQT_INT.litValue) == 1)

  val intIssueParam = issueParams.find(_.iqType == IQT_INT.litValue).get
  val memIssueParam = issueParams.find(_.iqType == IQT_MEM.litValue).get

  val intWidth = intIssueParam.issueWidth
  val memWidth = memIssueParam.issueWidth

  issueParams.map(x => require(x.dispatchWidth <= coreWidth && x.dispatchWidth > 0))

  //************************************
  // Load/Store Unit
  val dcacheParams: DCacheParams = tileParams.dcache.get
  val icacheParams: ICacheParams = tileParams.icache.get
  val icBlockBytes = icacheParams.blockBytes

  require(icacheParams.nSets <= 64, "Handling aliases in the ICache is buggy.")

  val enableFastLoadUse = boomParams.enableFastLoadUse
  val enablePrefetching = boomParams.enablePrefetching
  val nLBEntries = dcacheParams.nMSHRs

  //************************************
  // Branch Prediction
  val globalHistoryLength = boomParams.globalHistoryLength
  val localHistoryLength = boomParams.localHistoryLength
  val localHistoryNSets = boomParams.localHistoryNSets
  val bpdMaxMetaLength = boomParams.bpdMaxMetaLength

  def getBPDComponents(resp_in: BranchPredictionBankResponse, p: Parameters) = {
    boomParams.branchPredictor(resp_in, p)
  }

  val nRasEntries = boomParams.numRasEntries max 2
  val useRAS = boomParams.numRasEntries > 0
  val enableRasTopRepair = boomParams.enableRasTopRepair

  val useBPD = boomParams.enableBranchPrediction

  val useLHist = localHistoryNSets > 1 && localHistoryLength > 1

  //************************************
  // Extra Knobs and Features
  val enableCommitMapTable = boomParams.enableCommitMapTable
  require(!enableCommitMapTable) // TODO Fix the commit map table.
  val enableFastPNR = boomParams.enableFastPNR
  val enableSFBOpt = boomParams.enableSFBOpt
  val enableGHistStallRepair = boomParams.enableGHistStallRepair
  val enableBTBFastRepair = boomParams.enableBTBFastRepair

  //************************************
  // Implicitly calculated constants
  val numRobRows      = numRobEntries/coreWidth
  val robAddrSz       = log2Ceil(numRobRows) + log2Ceil(coreWidth)
  // the f-registers are mapped into the space above the x-registers
  val logicalRegCount = if (usingFPU) 64 else 32
  val lregSz          = log2Ceil(logicalRegCount)
  val ipregSz         = log2Ceil(numIntPhysRegs)
  val fpregSz         = log2Ceil(numFpPhysRegs)
  val maxPregSz       = ipregSz max fpregSz
  val ldqAddrSz       = log2Ceil(numLdqEntries)
  val stqAddrSz       = log2Ceil(numStqEntries)
  val lsuAddrSz       = ldqAddrSz max stqAddrSz
  val brTagSz         = log2Ceil(maxBrCount)

  require (numIntPhysRegs >= (32 + coreWidth))
  require (numFpPhysRegs >= (32 + coreWidth))
  require (maxBrCount >=2)
  require (numRobEntries % coreWidth == 0)
  require ((numLdqEntries-1) > coreWidth)
  require ((numStqEntries-1) > coreWidth)

  //***********************************
  // Debug printout parameters
  val COMMIT_LOG_PRINTF   = boomParams.enableCommitLogPrintf // dump commit state, for comparision against ISA sim
  val BRANCH_PRINTF       = boomParams.enableBranchPrintf // dump branch predictor results
  val MEMTRACE_PRINTF     = boomParams.enableMemtracePrintf // dump trace of memory accesses to L1D for debugging

  //************************************
  // Other Non/Should-not-be sythesizable modules
  val useFetchMonitor = boomParams.useFetchMonitor

  //************************************
  // Non-BOOM parameters

  val corePAddrBits = paddrBits
  val corePgIdxBits = pgIdxBits
}
```

### src/main/scala/tile/Interrupts.scala

```scala
class NMI(val w: Int) extends Bundle {
  val rnmi = Bool()
  val rnmi_interrupt_vector = UInt(w.W)
  val rnmi_exception_vector = UInt(w.W)
}

class TileInterrupts(implicit p: Parameters) extends CoreBundle()(p) {
  val debug = Bool()
  val mtip = Bool()
  val msip = Bool()
  val meip = Bool()
  val seip = usingSupervisor.option(Bool())
  val lip = Vec(coreParams.nLocalInterrupts, Bool())
  val nmi = usingNMI.option(new NMI(resetVectorLen))
}
```

### src/main/scala/chisel3/util/Decoupled.scala

```scala
/** An I/O Bundle containing 'valid' and 'ready' signals that handshake
  * the transfer of data stored in the 'bits' subfield.
  * The base protocol implied by the directionality is that
  * the producer uses the interface as-is (outputs bits)
  * while the consumer uses the flipped interface (inputs bits).
  * The actual semantics of ready/valid are enforced via the use of concrete subclasses.
  * @param gen the type of data to be wrapped in Ready/Valid
  * @groupdesc Signals The actual hardware fields of the Bundle
  */
abstract class ReadyValidIO[+T <: Data](gen: T) extends Bundle {
  // Compatibility hack for rocket-chip
  private val genType = (DataMirror.internal.isSynthesizable(gen), chisel3.internal.Builder.currentModule) match {
    case (true, Some(module: Module)) if !module.compileOptions.declaredTypeMustBeUnbound => chiselTypeOf(gen)
    case _ => gen
  }

  /** Indicates that the consumer is ready to accept the data this cycle
    * @group Signals
    */
  val ready = Input(Bool())

  /** Indicates that the producer has put valid data in 'bits'
    * @group Signals
    */
  val valid = Output(Bool())

  /** The data to be transferred when ready and valid are asserted at the same cycle
    * @group Signals
    */
  val bits = Output(genType)
}
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

### src/main/scala/common/micro-op.scala

```scala
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
  val uopc             = UInt(UOPC_SZ.W)       // micro-op code
  val inst             = UInt(32.W)
  val debug_inst       = UInt(32.W)
  val is_rvc           = Bool()
  val debug_pc         = UInt(coreMaxAddrBits.W)
  val iq_type          = UInt(IQT_SZ.W)        // which issue unit do we use?
  val fu_code          = UInt(FUConstants.FUC_SZ.W) // which functional unit do we use?
  val ctrl             = new CtrlSignals

  // What is the next state of this uop in the issue window? useful
  // for the compacting queue.
  val iw_state         = UInt(2.W)
  // Has operand 1 or 2 been waken speculatively by a load?
  // Only integer operands are speculaively woken up,
  // so we can ignore p3.
  val iw_p1_poisoned   = Bool()
  val iw_p2_poisoned   = Bool()

  val is_br            = Bool()                      // is this micro-op a (branch) vs a regular PC+4 inst?
  val is_jalr          = Bool()                      // is this a jump? (jal or jalr)
  val is_jal           = Bool()                      // is this a JAL (doesn't include JR)? used for branch unit
  val is_sfb           = Bool()                      // is this a sfb or in the shadow of a sfb

  val br_mask          = UInt(maxBrCount.W)  // which branches are we being speculated under?
  val br_tag           = UInt(brTagSz.W)

  // Index into FTQ to figure out our fetch PC.
  val ftq_idx          = UInt(log2Ceil(ftqSz).W)
  // This inst straddles two fetch packets
  val edge_inst        = Bool()
  // Low-order bits of our own PC. Combine with ftq[ftq_idx] to get PC.
  // Aligned to a cache-line size, as that is the greater fetch granularity.
  // TODO: Shouldn't this be aligned to fetch-width size?
  val pc_lob           = UInt(log2Ceil(icBlockBytes).W)

  // Was this a branch that was predicted taken?
  val taken            = Bool()

  val imm_packed       = UInt(LONGEST_IMM_SZ.W) // densely pack the imm in decode...
                                              // then translate and sign-extend in execute
  val csr_addr         = UInt(CSR_ADDR_SZ.W)    // only used for critical path reasons in Exe
  val rob_idx          = UInt(robAddrSz.W)
  val ldq_idx          = UInt(ldqAddrSz.W)
  val stq_idx          = UInt(stqAddrSz.W)
  val rxq_idx          = UInt(log2Ceil(numRxqEntries).W)
  val pdst             = UInt(maxPregSz.W)
  val prs1             = UInt(maxPregSz.W)
  val prs2             = UInt(maxPregSz.W)
  val prs3             = UInt(maxPregSz.W)
  val ppred            = UInt(log2Ceil(ftqSz).W)

  val prs1_busy        = Bool()
  val prs2_busy        = Bool()
  val prs3_busy        = Bool()
  val ppred_busy       = Bool()
  val stale_pdst       = UInt(maxPregSz.W)
  val exception        = Bool()
  val exc_cause        = UInt(xLen.W)          // TODO compress this down, xlen is insanity
  val bypassable       = Bool()                      // can we bypass ALU results? (doesn't include loads, csr, etc...)
  val mem_cmd          = UInt(M_SZ.W)          // sync primitives/cache flushes
  val mem_size         = UInt(2.W)
  val mem_signed       = Bool()
  val is_fence         = Bool()
  val is_fencei        = Bool()
  val is_amo           = Bool()
  val uses_ldq         = Bool()
  val uses_stq         = Bool()
  val is_sys_pc2epc    = Bool()                      // Is a ECall or Breakpoint -- both set EPC to PC.
  val is_unique        = Bool()                      // only allow this instruction in the pipeline, wait for STQ to
                                                     // drain, clear fetcha fter it (tell ROB to un-ready until empty)
  val flush_on_commit  = Bool()                      // some instructions need to flush the pipeline behind them

  // Preditation
  def is_sfb_br        = is_br && is_sfb && enableSFBOpt.B // Does this write a predicate
  def is_sfb_shadow    = !is_br && is_sfb && enableSFBOpt.B // Is this predicated
  val ldst_is_rs1      = Bool() // If this is set and we are predicated off, copy rs1 to dst,
                                // else copy rs2 to dst

  // logical specifiers (only used in Decode->Rename), except rollback (ldst)
  val ldst             = UInt(lregSz.W)
  val lrs1             = UInt(lregSz.W)
  val lrs2             = UInt(lregSz.W)
  val lrs3             = UInt(lregSz.W)

  val ldst_val         = Bool()              // is there a destination? invalid for stores, rd==x0, etc.
  val dst_rtype        = UInt(2.W)
  val lrs1_rtype       = UInt(2.W)
  val lrs2_rtype       = UInt(2.W)
  val frs3_en          = Bool()

  // floating point information
  val fp_val           = Bool()             // is a floating-point instruction (F- or D-extension)?
                                            // If it's non-ld/st it will write back exception bits to the fcsr.
  val fp_single        = Bool()             // single-precision floating point instruction (F-extension)

  // frontend exception information
  val xcpt_pf_if       = Bool()             // I-TLB page fault.
  val xcpt_ae_if       = Bool()             // I$ access exception.
  val xcpt_ma_if       = Bool()             // Misaligned fetch (jal/brjumping to misaligned addr).
  val bp_debug_if      = Bool()             // Breakpoint
  val bp_xcpt_if       = Bool()             // Breakpoint


  // What prediction structure provides the prediction FROM this op
  val debug_fsrc       = UInt(BSRC_SZ.W)
  // What prediction structure provides the prediction TO this op
  val debug_tsrc       = UInt(BSRC_SZ.W)

  // Do we allocate a branch tag for this?
  // SFB branches don't get a mask, they get a predicate bit
  def allocate_brtag   = (is_br && !is_sfb) || is_jalr

  // Does this register write-back
  def rf_wen           = dst_rtype =/= RT_X

  // Is it possible for this uop to misspeculate, preventing the commit of subsequent uops?
  def unsafe           = uses_ldq || (uses_stq && !is_fence) || is_br || is_jalr

  def fu_code_is(_fu: UInt) = (fu_code & _fu) =/= 0.U
}

/**
 * Control signals within a MicroOp
 *
 * TODO REFACTOR this, as this should no longer be true, as bypass occurs in stage before branch resolution
 */
class CtrlSignals extends Bundle()
{
  val br_type     = UInt(BR_N.getWidth.W)
  val op1_sel     = UInt(OP1_X.getWidth.W)
  val op2_sel     = UInt(OP2_X.getWidth.W)
  val imm_sel     = UInt(IS_X.getWidth.W)
  val op_fcn      = UInt(freechips.rocketchip.rocket.ALU.SZ_ALU_FN.W)
  val fcn_dw      = Bool()
  val csr_cmd     = UInt(freechips.rocketchip.rocket.CSR.SZ.W)
  val is_load     = Bool()   // will invoke TLB address lookup
  val is_sta      = Bool()   // will invoke TLB address lookup
  val is_std      = Bool()
}
```

### src/main/scala/exu/execution-units/functional-unit.scala

```scala
/**
 * Bundle for signals sent to the functional unit
 *
 * @param dataWidth width of the data sent to the functional unit
 */
class FuncUnitReq(val dataWidth: Int)(implicit p: Parameters) extends BoomBundle
  with HasBoomUOP
{
  val numOperands = 3

  val rs1_data = UInt(dataWidth.W)
  val rs2_data = UInt(dataWidth.W)
  val rs3_data = UInt(dataWidth.W) // only used for FMA units
  val pred_data = Bool()

  val kill = Bool() // kill everything
}

/**
 * Bundle for the signals sent out of the function unit
 *
 * @param dataWidth data sent from the functional unit
 */
class FuncUnitResp(val dataWidth: Int)(implicit p: Parameters) extends BoomBundle
  with HasBoomUOP
{
  val predicated = Bool() // Was this response from a predicated-off instruction
  val data = UInt(dataWidth.W)
  val fflags = new ValidIO(new FFlagsResp)
  val addr = UInt((vaddrBits+1).W) // only for maddr -> LSU
  val mxcpt = new ValidIO(UInt((freechips.rocketchip.rocket.Causes.all.max+2).W)) //only for maddr->LSU
  val sfence = Valid(new freechips.rocketchip.rocket.SFenceReq) // only for mcalc
}

/**
 * Branch resolution information given from the branch unit
 */
class BrResolutionInfo(implicit p: Parameters) extends BoomBundle
{
  val uop        = new MicroOp
  val valid      = Bool()
  val mispredict = Bool()
  val taken      = Bool()                     // which direction did the branch go?
  val cfi_type   = UInt(CFI_SZ.W)

  // Info for recalculating the pc for this branch
  val pc_sel     = UInt(2.W)

  val jalr_target = UInt(vaddrBitsExtended.W)
  val target_offset = SInt()
}

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
}
```

### src/main/scala/ifu/fetch-buffer.scala

```scala
/**
 * Bundle that is made up of converted MicroOps from the Fetch Bundle
 * input to the Fetch Buffer. This is handed to the Decode stage.
 */
class FetchBufferResp(implicit p: Parameters) extends BoomBundle
{
  val uops = Vec(coreWidth, Valid(new MicroOp()))
}
```

### src/main/scala/ifu/fetch-target-queue.scala

```scala
/**
 * Bundle to add to the FTQ RAM and to be used as the pass in IO
 */
class FTQBundle(implicit p: Parameters) extends BoomBundle
  with HasBoomFrontendParameters
{
  // // TODO compress out high-order bits
  // val fetch_pc  = UInt(vaddrBitsExtended.W)
  // IDX of instruction that was predicted taken, if any
  val cfi_idx   = Valid(UInt(log2Ceil(fetchWidth).W))
  // Was the CFI in this bundle found to be taken? or not
  val cfi_taken = Bool()
  // Was this CFI mispredicted by the branch prediction pipeline?
  val cfi_mispredicted = Bool()
  // What type of CFI was taken out of this bundle
  val cfi_type = UInt(CFI_SZ.W)
  // mask of branches which were visible in this fetch bundle
  val br_mask   = UInt(fetchWidth.W)
  // This CFI is likely a CALL
  val cfi_is_call   = Bool()
  // This CFI is likely a RET
  val cfi_is_ret    = Bool()
  // Is the NPC after the CFI +4 or +2
  val cfi_npc_plus4 = Bool()
  // What was the top of the RAS that this bundle saw?
  val ras_top = UInt(vaddrBitsExtended.W)
  val ras_idx = UInt(log2Ceil(nRasEntries).W)

  // Which bank did this start from?
  val start_bank = UInt(1.W)

  // // Metadata for the branch predictor
  // val bpd_meta = Vec(nBanks, UInt(bpdMaxMetaLength.W))
}

/**
 * IO to provide a port for a FunctionalUnit to get the PC of an instruction.
 * And for JALRs, the PC of the next instruction.
 */
class GetPCFromFtqIO(implicit p: Parameters) extends BoomBundle
{
  val ftq_idx   = Input(UInt(log2Ceil(ftqSz).W))

  val entry     = Output(new FTQBundle)
  val ghist     = Output(new GlobalHistory)

  val pc        = Output(UInt(vaddrBitsExtended.W))
  val com_pc    = Output(UInt(vaddrBitsExtended.W))

  // the next_pc may not be valid (stalled or still being fetched)
  val next_val  = Output(Bool())
  val next_pc   = Output(UInt(vaddrBitsExtended.W))
}
```

### src/main/scala/ifu/frontend.scala

```scala
class GlobalHistory(implicit p: Parameters) extends BoomBundle()(p)
  with HasBoomFrontendParameters
{
  // For the dual banked case, each bank ignores the contribution of the
  // last bank to the history. Thus we have to track the most recent update to the
  // history in that case
  val old_history = UInt(globalHistoryLength.W)

  val current_saw_branch_not_taken = Bool()

  val new_saw_branch_not_taken = Bool()
  val new_saw_branch_taken     = Bool()

  val ras_idx = UInt(log2Ceil(nRasEntries).W)

// ...
/**
 * IO for the BOOM Frontend to/from the CPU
 */
class BoomFrontendIO(implicit p: Parameters) extends BoomBundle
{
  // Give the backend a packet of instructions.
  val fetchpacket       = Flipped(new DecoupledIO(new FetchBufferResp))

  // 1 for xcpt/jalr/auipc/flush
  val get_pc            = Flipped(Vec(2, new GetPCFromFtqIO()))
  val debug_ftq_idx     = Output(Vec(coreWidth, UInt(log2Ceil(ftqSz).W)))
  val debug_fetch_pc    = Input(Vec(coreWidth, UInt(vaddrBitsExtended.W)))

  // Breakpoint info
  val status            = Output(new MStatus)
  val bp                = Output(Vec(nBreakpoints, new BP))
  val mcontext          = Output(UInt(coreParams.mcontextWidth.W))
  val scontext          = Output(UInt(coreParams.scontextWidth.W))

  val sfence = Valid(new SFenceReq)

  val brupdate          = Output(new BrUpdateInfo)

  // Redirects change the PC
  val redirect_flush   = Output(Bool()) // Flush and hang the frontend?
  val redirect_val     = Output(Bool()) // Redirect the frontend?
  val redirect_pc      = Output(UInt()) // Where do we redirect to?
  val redirect_ftq_idx = Output(UInt()) // Which ftq entry should we reset to?
  val redirect_ghist   = Output(new GlobalHistory) // What are we setting as the global history?

  val commit = Valid(UInt(ftqSz.W))

  val flush_icache = Output(Bool())

  val perf = Input(new FrontendPerfEvents)
}
```

### src/main/scala/exu/decode.scala

```scala
/**
 * IO bundle for the Decode unit
 */
class DecodeUnitIo(implicit p: Parameters) extends BoomBundle
{
  val enq = new Bundle { val uop = Input(new MicroOp()) }
  val deq = new Bundle { val uop = Output(new MicroOp()) }

  // from CSRFile
  val status = Input(new freechips.rocketchip.rocket.MStatus())
  val csr_decode = Flipped(new freechips.rocketchip.rocket.CSRDecodeIO)
  val interrupt = Input(Bool())
  val interrupt_cause = Input(UInt(xLen.W))
}

/**
 * Decode unit that takes in a single instruction and generates a MicroOp.
 */
class DecodeUnit(implicit p: Parameters) extends BoomModule
  with freechips.rocketchip.rocket.constants.MemoryOpConstants
{
  val io = IO(new DecodeUnitIo)
// ...
/**
 * Track the current "branch mask", and give out the branch mask to each micro-op in Decode
 * (each micro-op in the machine has a branch mask which says which branches it
 * is being speculated under).
 *
 * @param pl_width pipeline width for the processor
 */
class BranchMaskGenerationLogic(val pl_width: Int)(implicit p: Parameters) extends BoomModule
{
  val io = IO(new Bundle {
    // guess if the uop is a branch (we'll catch this later)
    val is_branch = Input(Vec(pl_width, Bool()))
    // lock in that it's actually a branch and will fire, so we update
    // the branch_masks.
    val will_fire = Input(Vec(pl_width, Bool()))

    // give out tag immediately (needed in rename)
    // mask can come later in the cycle
    val br_tag    = Output(Vec(pl_width, UInt(brTagSz.W)))
    val br_mask   = Output(Vec(pl_width, UInt(maxBrCount.W)))

     // tell decoders the branch mask has filled up, but on the granularity
     // of an individual micro-op (so some micro-ops can go through)
    val is_full   = Output(Vec(pl_width, Bool()))

    val brupdate         = Input(new BrUpdateInfo())
    val flush_pipeline = Input(Bool())

    val debug_branch_mask = Output(UInt(maxBrCount.W))
  })
```

### src/main/scala/exu/rename/rename-stage.scala

```scala
abstract class AbstractRenameStage(
  plWidth: Int,
  numPhysRegs: Int,
  numWbPorts: Int)
  (implicit p: Parameters) extends BoomModule
{
  val io = IO(new Bundle {
    val ren_stalls = Output(Vec(plWidth, Bool()))

    val kill = Input(Bool())

    val dec_fire  = Input(Vec(plWidth, Bool())) // will commit state updates
    val dec_uops  = Input(Vec(plWidth, new MicroOp()))

    // physical specifiers available AND busy/ready status available.
    val ren2_mask = Vec(plWidth, Output(Bool())) // mask of valid instructions
    val ren2_uops = Vec(plWidth, Output(new MicroOp()))

    // branch resolution (execute)
    val brupdate = Input(new BrUpdateInfo())

    val dis_fire  = Input(Vec(coreWidth, Bool()))
    val dis_ready = Input(Bool())

    // wakeup ports
    val wakeups = Flipped(Vec(numWbPorts, Valid(new ExeUnitResp(xLen))))

    // commit stage
    val com_valids = Input(Vec(plWidth, Bool()))
    val com_uops = Input(Vec(plWidth, new MicroOp()))
    val rbk_valids = Input(Vec(plWidth, Bool()))
    val rollback = Input(Bool())

    val debug_rob_empty = Input(Bool())
    val debug = Output(new DebugRenameStageIO(numPhysRegs))
  })
// ...
/**
 * Rename stage that connets the map table, free list, and busy table.
 * Can be used in both the FP pipeline and the normal execute pipeline.
 *
 * @param plWidth pipeline width
 * @param numWbPorts number of int writeback ports
 * @param numWbPorts number of FP writeback ports
 */
class RenameStage(
  plWidth: Int,
  numPhysRegs: Int,
  numWbPorts: Int,
  float: Boolean)
(implicit p: Parameters) extends AbstractRenameStage(plWidth, numPhysRegs, numWbPorts)(p)
// ...
class PredRenameStage(
  plWidth: Int,
  numPhysRegs: Int,
  numWbPorts: Int)
  (implicit p: Parameters) extends AbstractRenameStage(plWidth, numPhysRegs, numWbPorts)(p)
```

### src/main/scala/exu/issue-units/issue-unit.scala

```scala
/**
 * Class used for configurations
 *
 * @param issueWidth amount of things that can be issued
 * @param numEntries size of issue queue
 * @param iqType type of issue queue
 */
case class IssueParams(
  dispatchWidth: Int = 1,
  issueWidth: Int = 1,
  numEntries: Int = 8,
  iqType: BigInt
)
// ...
/**
 * What physical register is broadcasting its wakeup?
 * Is the physical register poisoned (aka, was it woken up by a speculative issue)?
 *
 * @param pregSz size of physical destination register
 */
class IqWakeup(val pregSz: Int) extends Bundle
{
  val pdst = UInt(width=pregSz.W)
  val poisoned = Bool()
}

/**
 * IO bundle to interact with the issue unit
 *
 * @param issueWidth amount of operations that can be issued at once
 * @param numWakeupPorts number of wakeup ports for issue unit
 */
class IssueUnitIO(
  val issueWidth: Int,
  val numWakeupPorts: Int,
  val dispatchWidth: Int)
  (implicit p: Parameters) extends BoomBundle
{
  val dis_uops         = Vec(dispatchWidth, Flipped(Decoupled(new MicroOp)))

  val iss_valids       = Output(Vec(issueWidth, Bool()))
  val iss_uops         = Output(Vec(issueWidth, new MicroOp()))
  val wakeup_ports     = Flipped(Vec(numWakeupPorts, Valid(new IqWakeup(maxPregSz))))
  val pred_wakeup_port = Flipped(Valid(UInt(log2Ceil(ftqSz).W)))

  val spec_ld_wakeup   = Flipped(Vec(memWidth, Valid(UInt(width=maxPregSz.W))))

  // tell the issue unit what each execution pipeline has in terms of functional units
  val fu_types         = Input(Vec(issueWidth, Bits(width=FUC_SZ.W)))

  val brupdate         = Input(new BrUpdateInfo())
  val flush_pipeline   = Input(Bool())
  val ld_miss          = Input(Bool())

  val event_empty      = Output(Bool()) // used by HPM events; is the issue unit empty?

  val tsc_reg          = Input(UInt(width=xLen.W))
}

/**
 * Abstract top level issue unit
 *
 * @param numIssueSlots depth of issue queue
 * @param issueWidth amoutn of operations that can be issued at once
 * @param numWakeupPorts number of wakeup ports for issue unit
 * @param iqType type of issue queue (mem, int, fp)
 */
abstract class IssueUnit(
  val numIssueSlots: Int,
  val issueWidth: Int,
  val numWakeupPorts: Int,
  val iqType: BigInt,
  val dispatchWidth: Int)
  (implicit p: Parameters)
  extends BoomModule
  with IssueUnitConstants
{
  val io = IO(new IssueUnitIO(issueWidth, numWakeupPorts, dispatchWidth))
```

### src/main/scala/exu/issue-units/issue-unit-age-ordered.scala

```scala
/**
 * Specific type of issue unit
 *
 * @param params issue queue params
 * @param numWakeupPorts number of wakeup ports for the issue queue
 */
class IssueUnitCollapsing(
  params: IssueParams,
  numWakeupPorts: Int)
  (implicit p: Parameters)
  extends IssueUnit(params.numEntries, params.issueWidth, numWakeupPorts, params.iqType, params.dispatchWidth)
```

### src/main/scala/exu/dispatch.scala

```scala
class DispatchIO(implicit p: Parameters) extends BoomBundle
{
  // incoming microops from rename2
  val ren_uops = Vec(coreWidth, Flipped(DecoupledIO(new MicroOp)))

  // outgoing microops to issue queues
  // N issues each accept up to dispatchWidth uops
  // dispatchWidth may vary between issue queues
  val dis_uops = MixedVec(issueParams.map(ip=>Vec(ip.dispatchWidth, DecoupledIO(new MicroOp))))
}

abstract class Dispatcher(implicit p: Parameters) extends BoomModule
{
  val io = IO(new DispatchIO)
}
// ...
/**
 * This Dispatcher assumes worst case, all dispatched uops go to 1 issue queue
 * This is equivalent to BOOMv2 behavior
 */
class BasicDispatcher(implicit p: Parameters) extends Dispatcher
{
  issueParams.map(ip=>require(ip.dispatchWidth == coreWidth))
```

### src/main/scala/exu/register-read/regfile.scala

```scala
/**
 * IO bundle for a register read port
 *
 * @param addrWidth size of register address in bits
 * @param dataWidth size of register in bits
 */
class RegisterFileReadPortIO(val addrWidth: Int, val dataWidth: Int)(implicit p: Parameters) extends BoomBundle
{
  val addr = Input(UInt(addrWidth.W))
  val data = Output(UInt(dataWidth.W))
}

/**
 * IO bundle for the register write port
 *
 * @param addrWidth size of register address in bits
 * @param dataWidth size of register in bits
 */
class RegisterFileWritePort(val addrWidth: Int, val dataWidth: Int)(implicit p: Parameters) extends BoomBundle
{
  val addr = UInt(addrWidth.W)
  val data = UInt(dataWidth.W)
}
// ...
/**
 * Register file abstract class
 *
 * @param numRegisters number of registers
 * @param numReadPorts number of read ports
 * @param numWritePorts number of write ports
 * @param registerWidth size of registers in bits
 * @param bypassableArray list of write ports from func units to the read port of the regfile
 */
abstract class RegisterFile(
  numRegisters: Int,
  numReadPorts: Int,
  numWritePorts: Int,
  registerWidth: Int,
  bypassableArray: Seq[Boolean]) // which write ports can be bypassed to the read ports?
  (implicit p: Parameters) extends BoomModule
{
  val io = IO(new BoomBundle {
    val read_ports = Vec(numReadPorts, new RegisterFileReadPortIO(maxPregSz, registerWidth))
    val write_ports = Flipped(Vec(numWritePorts, Valid(new RegisterFileWritePort(maxPregSz, registerWidth))))
  })
// ...
/**
 * A synthesizable model of a Register File. You will likely want to blackbox this for more than modest port counts.
 *
 * @param numRegisters number of registers
 * @param numReadPorts number of read ports
 * @param numWritePorts number of write ports
 * @param registerWidth size of registers in bits
 * @param bypassableArray list of write ports from func units to the read port of the regfile
 */
class RegisterFileSynthesizable(
   numRegisters: Int,
   numReadPorts: Int,
   numWritePorts: Int,
   registerWidth: Int,
   bypassableArray: Seq[Boolean])
   (implicit p: Parameters)
   extends RegisterFile(numRegisters, numReadPorts, numWritePorts, registerWidth, bypassableArray)
```

### src/main/scala/exu/register-read/register-read.scala

```scala
/**
 * Handle the register read and bypass network for the OoO backend
 * interfaces with the issue window on the enqueue side, and the execution
 * pipelines on the dequeue side.
 *
 * @param issueWidth total issue width from all issue queues
 * @param supportedUnitsArray seq of SupportedFuncUnits classes indicating what the functional units do
 * @param numTotalReadPorts number of read ports
 * @param numReadPortsArray execution units read port sequence
 * @param numTotalBypassPorts number of bypass ports out of the execution units
 * @param registerWidth size of register in bits
 */
class RegisterRead(
  issueWidth: Int,
  supportedUnitsArray: Seq[SupportedFuncUnits],
  numTotalReadPorts: Int,
  numReadPortsArray: Seq[Int],
                        // each exe_unit must tell us how many max
                        // operands it can accept (the sum should equal
                        // numTotalReadPorts)
  numTotalBypassPorts: Int,
  numTotalPredBypassPorts: Int,
  registerWidth: Int
)(implicit p: Parameters) extends BoomModule
{
  val io = IO(new Bundle {
    // issued micro-ops
    val iss_valids = Input(Vec(issueWidth, Bool()))
    val iss_uops   = Input(Vec(issueWidth, new MicroOp()))

    // interface with register file's read ports
    val rf_read_ports = Flipped(Vec(numTotalReadPorts, new RegisterFileReadPortIO(maxPregSz, registerWidth)))
    val prf_read_ports = Flipped(Vec(issueWidth, new RegisterFileReadPortIO(log2Ceil(ftqSz), 1)))

    val bypass = Input(Vec(numTotalBypassPorts, Valid(new ExeUnitResp(registerWidth))))
    val pred_bypass = Input(Vec(numTotalPredBypassPorts, Valid(new ExeUnitResp(1))))

    // send micro-ops to the execution pipelines
    val exe_reqs = Vec(issueWidth, (new DecoupledIO(new FuncUnitReq(registerWidth))))

    val kill   = Input(Bool())
    val brupdate = Input(new BrUpdateInfo())
  })
```

### src/main/scala/exu/fp-pipeline.scala

```scala
/**
 * Top level datapath that wraps the floating point issue window, regfile, and arithmetic units.
 */
class FpPipeline(implicit p: Parameters) extends BoomModule with tile.HasFPUParameters
{
  val fpIssueParams = issueParams.find(_.iqType == IQT_FP.litValue).get
  val dispatchWidth = fpIssueParams.dispatchWidth
  val numLlPorts = memWidth
  val numWakeupPorts = fpIssueParams.issueWidth + numLlPorts
  val fpPregSz = log2Ceil(numFpPhysRegs)

  val io = IO(new Bundle {
    val brupdate         = Input(new BrUpdateInfo())
    val flush_pipeline   = Input(Bool())
    val fcsr_rm          = Input(UInt(width=freechips.rocketchip.tile.FPConstants.RM_SZ.W))
    val status           = Input(new freechips.rocketchip.rocket.MStatus())

    val dis_uops         = Vec(dispatchWidth, Flipped(Decoupled(new MicroOp)))

    // +1 for recoding.
    val ll_wports        = Flipped(Vec(memWidth, Decoupled(new ExeUnitResp(fLen+1))))// from memory unit
    val from_int         = Flipped(Decoupled(new ExeUnitResp(fLen+1)))// from integer RF
    val to_sdq           = Decoupled(new ExeUnitResp(fLen))           // to Load/Store Unit
    val to_int           = Decoupled(new ExeUnitResp(xLen))           // to integer RF

    val wakeups          = Vec(numWakeupPorts, Valid(new ExeUnitResp(fLen+1)))
    val wb_valids        = Input(Vec(numWakeupPorts, Bool()))
    val wb_pdsts         = Input(Vec(numWakeupPorts, UInt(width=fpPregSz.W)))

    val debug_tsc_reg    = Input(UInt(width=xLen.W))
    val debug_wb_wdata   = Output(Vec(numWakeupPorts, UInt((fLen+1).W)))
  })
```

### src/main/scala/exu/rob.scala

```scala
/**
 * IO bundle to interact with the ROB
 *
 * @param numWakeupPorts number of wakeup ports to the rob
 * @param numFpuPorts number of fpu ports that will write back fflags
 */
class RobIo(
  val numWakeupPorts: Int,
  val numFpuPorts: Int
  )(implicit p: Parameters)  extends BoomBundle
{
  // Decode Stage
  // (Allocate, write instruction to ROB).
  val enq_valids       = Input(Vec(coreWidth, Bool()))
  val enq_uops         = Input(Vec(coreWidth, new MicroOp()))
  val enq_partial_stall= Input(Bool()) // we're dispatching only a partial packet,
                                       // and stalling on the rest of it (don't
                                       // advance the tail ptr)

  val xcpt_fetch_pc = Input(UInt(vaddrBitsExtended.W))

  val rob_tail_idx = Output(UInt(robAddrSz.W))
  val rob_pnr_idx  = Output(UInt(robAddrSz.W))
  val rob_head_idx = Output(UInt(robAddrSz.W))

  // Handle Branch Misspeculations
  val brupdate = Input(new BrUpdateInfo())

  // Write-back Stage
  // (Update of ROB)
  // Instruction is no longer busy and can be committed
  val wb_resps = Flipped(Vec(numWakeupPorts, Valid(new ExeUnitResp(xLen max fLen+1))))

  // Unbusying ports for stores.
  // +1 for fpstdata
  val lsu_clr_bsy      = Input(Vec(memWidth + 1, Valid(UInt(robAddrSz.W))))

  // Port for unmarking loads/stores as speculation hazards..
  val lsu_clr_unsafe   = Input(Vec(memWidth, Valid(UInt(robAddrSz.W))))


  // Track side-effects for debug purposes.
  // Also need to know when loads write back, whereas we don't need loads to unbusy.
  val debug_wb_valids = Input(Vec(numWakeupPorts, Bool()))
  val debug_wb_wdata  = Input(Vec(numWakeupPorts, Bits(xLen.W)))

  val fflags = Flipped(Vec(numFpuPorts, new ValidIO(new FFlagsResp())))
  val lxcpt = Flipped(new ValidIO(new Exception())) // LSU

  // Commit stage (free resources; also used for rollback).
  val commit = Output(new CommitSignals())

  // tell the LSU that the head of the ROB is a load
  // (some loads can only execute once they are at the head of the ROB).
  val com_load_is_at_rob_head = Output(Bool())

  // Communicate exceptions to the CSRFile
  val com_xcpt = Valid(new CommitExceptionSignals())

  // Let the CSRFile stall us (e.g., wfi).
  val csr_stall = Input(Bool())

  // Flush signals (including exceptions, pipeline replays, and memory ordering failures)
  // to send to the frontend for redirection.
  val flush = Valid(new CommitExceptionSignals)

  // Stall Decode as appropriate
  val empty = Output(Bool())
  val ready = Output(Bool()) // ROB is busy unrolling rename state...

  // Stall the frontend if we know we will redirect the PC
  val flush_frontend = Output(Bool())


  val debug_tsc = Input(UInt(xLen.W))
}

/**
 * Bundle to send commit signals across processor
 */
class CommitSignals(implicit p: Parameters) extends BoomBundle
{
  val valids      = Vec(retireWidth, Bool()) // These instructions may not correspond to an architecturally executed insn
  val arch_valids = Vec(retireWidth, Bool())
  val uops        = Vec(retireWidth, new MicroOp())
  val fflags      = Valid(UInt(5.W))

  // These come a cycle later
  val debug_insts = Vec(retireWidth, UInt(32.W))

  // Perform rollback of rename state (in conjuction with commit.uops).
  val rbk_valids = Vec(retireWidth, Bool())
  val rollback   = Bool()

  val debug_wdata = Vec(retireWidth, UInt(xLen.W))
}

/**
 * Bundle to communicate exceptions to CSRFile
 *
 * TODO combine FlushSignals and ExceptionSignals (currently timed to different cycles).
 */
class CommitExceptionSignals(implicit p: Parameters) extends BoomBundle
{
  val ftq_idx    = UInt(log2Ceil(ftqSz).W)
  val edge_inst  = Bool()
  val is_rvc     = Bool()
  val pc_lob     = UInt(log2Ceil(icBlockBytes).W)
  val cause      = UInt(xLen.W)
  val badvaddr   = UInt(xLen.W)
// The ROB needs to tell the FTQ if there's a pipeline flush (and what type)
// so the FTQ can drive the frontend with the correct redirected PC.
  val flush_typ  = FlushTypes()
}

/**
 * Tell the frontend the type of flush so it can set up the next PC properly.
 */
object FlushTypes
{
  def SZ = 3
  def apply() = UInt(SZ.W)
  def none = 0.U
  def xcpt = 1.U // An exception occurred.
  def eret = (2+1).U // Execute an environment return instruction.
  def refetch = 2.U // Flush and refetch the head instruction.
  def next = 4.U // Flush and fetch the next instruction.

  def useCsrEvec(typ: UInt): Bool = typ(0) // typ === xcpt.U || typ === eret.U
  def useSamePC(typ: UInt): Bool = typ === refetch
  def usePCplus4(typ: UInt): Bool = typ === next

  def getType(valid: Bool, i_xcpt: Bool, i_eret: Bool, i_refetch: Bool): UInt = {
    val ret =
      Mux(!valid, none,
      Mux(i_eret, eret,
      Mux(i_xcpt, xcpt,
      Mux(i_refetch, refetch,
        next))))
    ret
  }
}

/**
 * Bundle of signals indicating that an exception occurred
 */
class Exception(implicit p: Parameters) extends BoomBundle
{
  val uop = new MicroOp()
  val cause = Bits(log2Ceil(freechips.rocketchip.rocket.Causes.all.max+2).W)
  val badvaddr = UInt(coreMaxAddrBits.W)
}

/**
 * Bundle for debug ROB signals
 * These should not be synthesized!
 */
class DebugRobSignals(implicit p: Parameters) extends BoomBundle
{
  val state = UInt()
  val rob_head = UInt(robAddrSz.W)
  val rob_pnr = UInt(robAddrSz.W)
  val xcpt_val = Bool()
  val xcpt_uop = new MicroOp()
  val xcpt_badvaddr = UInt(xLen.W)
}

/**
 * Reorder Buffer to keep track of dependencies and inflight instructions
 *
 * @param numWakeupPorts number of wakeup ports to the ROB
 * @param numFpuPorts number of FPU units that will write back fflags
 */
@chiselName
class Rob(
  val numWakeupPorts: Int,
  val numFpuPorts: Int
  )(implicit p: Parameters) extends BoomModule
{
  val io = IO(new RobIo(numWakeupPorts, numFpuPorts))
```

### src/main/scala/lsu/lsu.scala

```scala
class LSUExeIO(implicit p: Parameters) extends BoomBundle()(p)
{
  // The "resp" of the maddrcalc is really a "req" to the LSU
  val req       = Flipped(new ValidIO(new FuncUnitResp(xLen)))
  // Send load data to regfiles
  val iresp    = new DecoupledIO(new boom.exu.ExeUnitResp(xLen))
  val fresp    = new DecoupledIO(new boom.exu.ExeUnitResp(xLen+1)) // TODO: Should this be fLen?
}

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

class LSUCoreIO(implicit p: Parameters) extends BoomBundle()(p)
{
  val exe = Vec(memWidth, new LSUExeIO)

  val dis_uops    = Flipped(Vec(coreWidth, Valid(new MicroOp)))
  val dis_ldq_idx = Output(Vec(coreWidth, UInt(ldqAddrSz.W)))
  val dis_stq_idx = Output(Vec(coreWidth, UInt(stqAddrSz.W)))

  val ldq_full    = Output(Vec(coreWidth, Bool()))
  val stq_full    = Output(Vec(coreWidth, Bool()))

  val fp_stdata   = Flipped(Decoupled(new ExeUnitResp(fLen)))

  val commit      = Input(new CommitSignals)
  val commit_load_at_rob_head = Input(Bool())

  // Stores clear busy bit when stdata is received
  // memWidth for int, 1 for fp (to avoid back-pressure fpstdat)
  val clr_bsy         = Output(Vec(memWidth + 1, Valid(UInt(robAddrSz.W))))

  // Speculatively safe load (barring memory ordering failure)
  val clr_unsafe      = Output(Vec(memWidth, Valid(UInt(robAddrSz.W))))

  // Tell the DCache to clear prefetches/speculating misses
  val fence_dmem   = Input(Bool())

  // Speculatively tell the IQs that we'll get load data back next cycle
  val spec_ld_wakeup = Output(Vec(memWidth, Valid(UInt(maxPregSz.W))))
  // Tell the IQs that the load we speculated last cycle was misspeculated
  val ld_miss      = Output(Bool())

  val brupdate       = Input(new BrUpdateInfo)
  val rob_pnr_idx  = Input(UInt(robAddrSz.W))
  val rob_head_idx = Input(UInt(robAddrSz.W))
  val exception    = Input(Bool())

  val fencei_rdy  = Output(Bool())

  val lxcpt       = Output(Valid(new Exception))

  val tsc_reg     = Input(UInt())

  val perf        = Output(new Bundle {
    val acquire = Bool()
    val release = Bool()
    val tlbMiss = Bool()
  })
}
```

### src/main/scala/exu/execution-units/execution-unit.scala

```scala
/**
 * Response from Execution Unit. Bundles a MicroOp with data
 *
 * @param dataWidth width of the data coming from the execution unit
 */
class ExeUnitResp(val dataWidth: Int)(implicit p: Parameters) extends BoomBundle
  with HasBoomUOP
{
  val data = Bits(dataWidth.W)
  val predicated = Bool() // Was this predicated off?
  val fflags = new ValidIO(new FFlagsResp) // write fflags to ROB // TODO: Do this better
}

/**
 * Floating Point flag response
 */
class FFlagsResp(implicit p: Parameters) extends BoomBundle
{
  val uop = new MicroOp()
  val flags = Bits(tile.FPConstants.FLAGS_SZ.W)
}


/**
 * Abstract Top level Execution Unit that wraps lower level functional units to make a
 * multi function execution unit.
 *
 * @param readsIrf does this exe unit need a integer regfile port
 * @param writesIrf does this exe unit need a integer regfile port
 * @param readsFrf does this exe unit need a integer regfile port
 * @param writesFrf does this exe unit need a integer regfile port
 * @param writesLlIrf does this exe unit need a integer regfile port
 * @param writesLlFrf does this exe unit need a integer regfile port
 * @param numBypassStages number of bypass ports for the exe unit
 * @param dataWidth width of the data coming out of the exe unit
 * @param bypassable is the exe unit able to be bypassed
 * @param hasMem does the exe unit have a MemAddrCalcUnit
 * @param hasCSR does the exe unit write to the CSRFile
 * @param hasBrUnit does the exe unit have a branch unit
 * @param hasAlu does the exe unit have a alu
 * @param hasFpu does the exe unit have a fpu
 * @param hasMul does the exe unit have a multiplier
 * @param hasDiv does the exe unit have a divider
 * @param hasFdiv does the exe unit have a FP divider
 * @param hasIfpu does the exe unit have a int to FP unit
 * @param hasFpiu does the exe unit have a FP to int unit
 */
abstract class ExecutionUnit(
  val readsIrf         : Boolean       = false,
  val writesIrf        : Boolean       = false,
  val readsFrf         : Boolean       = false,
  val writesFrf        : Boolean       = false,
  val writesLlIrf      : Boolean       = false,
  val writesLlFrf      : Boolean       = false,
  val numBypassStages  : Int,
  val dataWidth        : Int,
  val bypassable       : Boolean       = false, // TODO make override def for code clarity
  val alwaysBypassable : Boolean       = false,
  val hasMem           : Boolean       = false,
  val hasCSR           : Boolean       = false,
  val hasJmpUnit       : Boolean       = false,
  val hasAlu           : Boolean       = false,
  val hasFpu           : Boolean       = false,
  val hasMul           : Boolean       = false,
  val hasDiv           : Boolean       = false,
  val hasFdiv          : Boolean       = false,
  val hasIfpu          : Boolean       = false,
  val hasFpiu          : Boolean       = false,
  val hasRocc          : Boolean       = false
  )(implicit p: Parameters) extends BoomModule
{

  val io = IO(new Bundle {
    val fu_types = Output(Bits(FUC_SZ.W))

    val req      = Flipped(new DecoupledIO(new FuncUnitReq(dataWidth)))

    val iresp    = if (writesIrf)   new DecoupledIO(new ExeUnitResp(dataWidth)) else null
    val fresp    = if (writesFrf)   new DecoupledIO(new ExeUnitResp(dataWidth)) else null
    val ll_iresp = if (writesLlIrf) new DecoupledIO(new ExeUnitResp(dataWidth)) else null
    val ll_fresp = if (writesLlFrf) new DecoupledIO(new ExeUnitResp(dataWidth)) else null


    val bypass   = Output(Vec(numBypassStages, Valid(new ExeUnitResp(dataWidth))))
    val brupdate = Input(new BrUpdateInfo())


    // only used by the rocc unit
    val rocc = if (hasRocc) new RoCCShimCoreIO else null

    // only used by the branch unit
    val brinfo     = if (hasAlu) Output(new BrResolutionInfo()) else null
    val get_ftq_pc = if (hasJmpUnit) Flipped(new GetPCFromFtqIO()) else null
    val status     = Input(new freechips.rocketchip.rocket.MStatus())

    // only used by the fpu unit
    val fcsr_rm = if (hasFcsr) Input(Bits(tile.FPConstants.RM_SZ.W)) else null

    // only used by the mem unit
    val lsu_io = if (hasMem) Flipped(new boom.lsu.LSUExeIO) else null
    val bp = if (hasMem) Input(Vec(nBreakpoints, new BP)) else null
    val mcontext = if (hasMem) Input(UInt(coreParams.mcontextWidth.W)) else null
    val scontext = if (hasMem) Input(UInt(coreParams.scontextWidth.W)) else null

    // TODO move this out of ExecutionUnit
    val com_exception = if (hasMem || hasRocc) Input(Bool()) else null
  })
```

### src/main/scala/exu/execution-units/execution-units.scala

```scala
/**
 * Top level class to wrap all execution units together into a "collection"
 *
 * @param fpu using a FPU?
 */
class ExecutionUnits(val fpu: Boolean)(implicit val p: Parameters) extends HasBoomCoreParameters
{
  val totalIssueWidth = issueParams.map(_.issueWidth).sum

  //*******************************
  // Instantiate the ExecutionUnits

  private val exe_units = ArrayBuffer[ExecutionUnit]()

  //*******************************
  // Act like a collection

  def length = exe_units.length

  def apply(n: Int) = exe_units(n)

  def map[T](f: ExecutionUnit => T) = {
    exe_units.map(f)
  }

  def withFilter(f: ExecutionUnit => Boolean) = {
    exe_units.withFilter(f)
  }

  def foreach[U](f: ExecutionUnit => U) = {
    exe_units.foreach(f)
  }

  def zipWithIndex = {
    exe_units.zipWithIndex
  }

  def indexWhere(f: ExecutionUnit => Boolean) = {
    exe_units.indexWhere(f)
  }

  def count(f: ExecutionUnit => Boolean) = {
    exe_units.count(f)
  }

  lazy val memory_units = {
    exe_units.filter(_.hasMem)
  }

  lazy val alu_units = {
    exe_units.filter(_.hasAlu)
  }

  lazy val csr_unit = {
    require (exe_units.count(_.hasCSR) == 1)
    exe_units.find(_.hasCSR).get
  }

  lazy val ifpu_unit = {
    require (usingFPU)
    require (exe_units.count(_.hasIfpu) == 1)
    exe_units.find(_.hasIfpu).get
  }

  lazy val fpiu_unit = {
    require (usingFPU)
    require (exe_units.count(_.hasFpiu) == 1)
    exe_units.find(_.hasFpiu).get
  }


  lazy val jmp_unit_idx = {
    exe_units.indexWhere(_.hasJmpUnit)
  }

  lazy val rocc_unit = {
    require (usingRoCC)
    require (exe_units.count(_.hasRocc) == 1)
    exe_units.find(_.hasRocc).get
  }
// ...
  if (!fpu) {
    val int_width = issueParams.find(_.iqType == IQT_INT.litValue).get.issueWidth

    for (w <- 0 until memWidth) {
      val memExeUnit = Module(new ALUExeUnit(
        hasAlu = false,
        hasMem = true))

      memExeUnit.io.ll_iresp.ready := DontCare

      exe_units += memExeUnit
    }

    for (w <- 0 until int_width) {
      def is_nth(n: Int): Boolean = w == ((n) % int_width)
      val alu_exe_unit = Module(new ALUExeUnit(
        hasJmpUnit     = is_nth(0),
        hasCSR         = is_nth(1),
        hasRocc        = is_nth(1) && usingRoCC,
        hasMul         = is_nth(2),
        hasDiv         = is_nth(3),
        hasIfpu        = is_nth(4) && usingFPU))
      exe_units += alu_exe_unit
    }
  } else {
    val fp_width = issueParams.find(_.iqType == IQT_FP.litValue).get.issueWidth
    for (w <- 0 until fp_width) {
      val fpu_exe_unit = Module(new FPUExeUnit(hasFpu = true,
                                             hasFdiv = usingFDivSqrt && (w==0),
                                             hasFpiu = (w==0)))
      exe_units += fpu_exe_unit
    }
  }
// ...
  val numIrfReaders       = exe_units.count(_.readsIrf)
  val numIrfReadPorts     = exe_units.count(_.readsIrf) * 2
  val numIrfWritePorts    = exe_units.count(_.writesIrf)
  val numLlIrfWritePorts  = exe_units.count(_.writesLlIrf)
  val numTotalBypassPorts = exe_units.withFilter(_.bypassable).map(_.numBypassStages).foldLeft(0)(_+_)

  val numFrfReaders       = exe_units.count(_.readsFrf)
  val numFrfReadPorts     = exe_units.count(_.readsFrf) * 3
  val numFrfWritePorts    = exe_units.count(_.writesFrf)
  val numLlFrfWritePorts  = exe_units.count(_.writesLlFrf)

  // The mem-unit will also bypass writes to readers in the RRD stage.
  // NOTE: This does NOT include the ll_wport
  val bypassable_write_port_mask = exe_units.withFilter(x => x.writesIrf).map(u => u.bypassable)
}
```

### src/main/scala/tile/Core.scala

```scala
abstract class CoreModule(implicit val p: Parameters) extends Module
  with HasCoreParameters

abstract class CoreBundle(implicit val p: Parameters) extends ParameterizedBundle()(p)
  with HasCoreParameters

class CoreInterrupts(implicit p: Parameters) extends TileInterrupts()(p) {
  val buserror = tileParams.beuAddr.map(a => Bool())
}
```

### src/main/scala/rocket/PTW.scala

```scala
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
```

### src/main/scala/tile/LazyRoCC.scala

```scala
class RoCCResponse(implicit p: Parameters) extends CoreBundle()(p) {
  val rd = Bits(5.W)
  val data = Bits(xLen.W)
}

class RoCCCoreIO(implicit p: Parameters) extends CoreBundle()(p) {
  val cmd = Flipped(Decoupled(new RoCCCommand))
  val resp = Decoupled(new RoCCResponse)
  val mem = new HellaCacheIO
  val busy = Output(Bool())
  val interrupt = Output(Bool())
  val exception = Input(Bool())
}
```

### src/main/scala/rocket/CSR.scala

```scala
package freechips.rocketchip.rocket
// ...
class TracedInstruction(implicit p: Parameters) extends CoreBundle {
  val valid = Bool()
  val iaddr = UInt(width = coreMaxAddrBits)
  val insn = UInt(width = iLen)
  val priv = UInt(width = 3)
  val exception = Bool()
  val interrupt = Bool()
  val cause = UInt(width = xLen)
  val tval = UInt(width = coreMaxAddrBits max iLen)
}
// ...
class CSRFileIO(implicit p: Parameters) extends CoreBundle
    with HasCoreParameters {
  val ungated_clock = Clock().asInput
  val interrupts = new CoreInterrupts().asInput
  val hartid = UInt(INPUT, hartIdLen)
  val rw = new Bundle {
    val addr = UInt(INPUT, CSR.ADDRSZ)
    val cmd = Bits(INPUT, CSR.SZ)
    val rdata = Bits(OUTPUT, xLen)
    val wdata = Bits(INPUT, xLen)
  }

  val decode = Vec(decodeWidth, new CSRDecodeIO)

  val csr_stall = Bool(OUTPUT)
  val eret = Bool(OUTPUT)
  val singleStep = Bool(OUTPUT)

  val status = new MStatus().asOutput
  val hstatus = new HStatus().asOutput
  val gstatus = new MStatus().asOutput
  val ptbr = new PTBR().asOutput
  val hgatp = new PTBR().asOutput
  val vsatp = new PTBR().asOutput
  val evec = UInt(OUTPUT, vaddrBitsExtended)
  val exception = Bool(INPUT)
  val retire = UInt(INPUT, log2Up(1+retireWidth))
  val cause = UInt(INPUT, xLen)
  val pc = UInt(INPUT, vaddrBitsExtended)
  val tval = UInt(INPUT, vaddrBitsExtended)
  val htval = UInt(INPUT, (maxSVAddrBits + 1) min xLen)
  val gva = Bool(INPUT)
  val time = UInt(OUTPUT, xLen)
  val fcsr_rm = Bits(OUTPUT, FPConstants.RM_SZ)
  val fcsr_flags = Valid(Bits(width = FPConstants.FLAGS_SZ)).flip
  val set_fs_dirty = coreParams.haveFSDirty.option(Bool(INPUT))
  val rocc_interrupt = Bool(INPUT)
  val interrupt = Bool(OUTPUT)
  val interrupt_cause = UInt(OUTPUT, xLen)
  val bp = Vec(nBreakpoints, new BP).asOutput
  val pmp = Vec(nPMPs, new PMP).asOutput
  val counters = Vec(nPerfCounters, new PerfCounterIO)
  val csrw_counter = UInt(OUTPUT, CSR.nCtr)
  val inhibit_cycle = Output(Bool())
  val inst = Vec(retireWidth, UInt(width = iLen)).asInput
  val trace = Vec(retireWidth, new TracedInstruction).asOutput
  val mcontext = Output(UInt(coreParams.mcontextWidth.W))
  val scontext = Output(UInt(coreParams.scontextWidth.W))

  val vector = usingVector.option(new Bundle {
    val vconfig = new VConfig().asOutput
    val vstart = UInt(maxVLMax.log2.W).asOutput
    val vxrm = UInt(2.W).asOutput
    val set_vs_dirty = Input(Bool())
    val set_vconfig = Valid(new VConfig).flip
    val set_vstart = Valid(vstart).flip
    val set_vxsat = Bool().asInput
  })
}
// ...
class CSRFile(
  perfEventSets: EventSets = new EventSets(Seq()),
  customCSRs: Seq[CustomCSR] = Nil)(implicit p: Parameters)
    extends CoreModule()(p)
    with HasCoreParameters {
  val io = new CSRFileIO {
    val customCSRs = Vec(CSRFile.this.customCSRs.size, new CustomCSRIO).asOutput
  }
```

### src/main/scala/rocket/Frontend.scala

```scala
class FrontendPerfEvents extends Bundle {
  val acquire = Bool()
  val tlbMiss = Bool()
}
```

### src/main/scala/TraceIO.scala

```scala
//***************************************************************************
// Extended Trace Instruction Utilities:
// Used to map TracedInstructions to their Extended version and
// used to connect the TracerV or Dromajo bridges (in FireSim and normal sim)
//***************************************************************************

case class TracedInstructionWidths(iaddr: Int, insn: Int, wdata: Option[Int], cause: Int, tval: Int)

object TracedInstructionWidths {
  def apply(tI: ExtendedTracedInstruction): TracedInstructionWidths = {
    val wdataWidth = tI.wdata.map { w => w.getWidth }
    TracedInstructionWidths(tI.iaddr.getWidth, tI.insn.getWidth, wdataWidth, tI.cause.getWidth, tI.tval.getWidth)
  }

  def apply(tI: TracedInstruction): TracedInstructionWidths =
    TracedInstructionWidths(tI.iaddr.getWidth, tI.insn.getWidth, None, tI.cause.getWidth, tI.tval.getWidth)
}

class ExtendedTracedInstruction(val extended: Boolean = true)(implicit p: Parameters) extends TracedInstruction {
  val wdata = if (extended) Some(UInt(xLen.W)) else None
}
```

### src/main/scala/util/CoreMonitor.scala

```scala
// this bundle is used to expose some internal core signals
// to verification monitors which sample instruction commits
class CoreMonitorBundle(val xLen: Int, val fLen: Int) extends Bundle with Clocked {
  val excpt = Bool()
  val priv_mode = UInt(width = 3.W)
  val hartid = UInt(width = xLen.W)
  val timer = UInt(width = 32.W)
  val valid = Bool()
  val pc = UInt(width = xLen.W)
  val wrdst = UInt(width = 5.W)
  val wrdata = UInt(width = (xLen max fLen).W)
  val wrenx = Bool()
  val wrenf = Bool()
  @deprecated("replace wren with wrenx or wrenf to specify integer or floating point","Rocket Chip 2020.05")
  def wren: Bool = wrenx || wrenf
  val rd0src = UInt(width = 5.W)
  val rd0val = UInt(width = xLen.W)
  val rd1src = UInt(width = 5.W)
  val rd1val = UInt(width = xLen.W)
  val inst = UInt(width = 32.W)
}
```

## Related source code

### src/main/scala/ifu/fetch-target-queue.scala

```scala
  val ghist    = Seq.fill(2) { SyncReadMem(num_entries, new GlobalHistory) }
// ...

  for (i <- 0 until 2) {
    val idx = io.get_ftq_pc(i).ftq_idx
    val next_idx = WrapInc(idx, num_entries)
    val next_is_enq = (next_idx === enq_ptr) && io.enq.fire
    val next_pc = Mux(next_is_enq, io.enq.bits.pc, pcs(next_idx))
    val get_entry = ram(idx)
    val next_entry = ram(next_idx)
    io.get_ftq_pc(i).entry     := RegNext(get_entry)
    if (i == 1)
      io.get_ftq_pc(i).ghist   := ghist(1).read(idx, true.B)
    else
      io.get_ftq_pc(i).ghist   := DontCare
    io.get_ftq_pc(i).pc        := RegNext(pcs(idx))
    io.get_ftq_pc(i).next_pc   := RegNext(next_pc)
    io.get_ftq_pc(i).next_val  := RegNext(next_idx =/= enq_ptr || next_is_enq)
    io.get_ftq_pc(i).com_pc    := RegNext(pcs(Mux(io.deq.valid, io.deq.bits, deq_ptr)))
  }

  for (w <- 0 until coreWidth) {
    io.debug_fetch_pc(w) := RegNext(pcs(io.debug_ftq_idx(w)))
  }
```

## Documentation

### docs/sections/intro-overview/boom-pipeline.rst

```text
Conceptually, BOOM is broken up into 10 stages: **Fetch**, **Decode**,
**Register Rename**, **Dispatch**, **Issue**, **Register Read**, **Execute**, **Memory**,
**Writeback** and **Commit**. However, many of those stages are
combined in the current implementation, yielding **seven** stages:
**Fetch**, **Decode/Rename**, **Rename/Dispatch**, **Issue/RegisterRead**, **Execute**,
**Memory** and **Writeback** (**Commit** occurs asynchronously, so it is not counted as part of the “pipeline").
:numref:`boom-pipeline` shows a simplified BOOM pipeline that has all of the pipeline stages listed.

Stages
------

Fetch
^^^^^

Instructions are *fetched* from instruction memory and
pushed into a FIFO queue, known as the :term:`Fetch Buffer` . Branch
prediction also occurs in this stage, redirecting the fetched
instructions as necessary. [1]_

Decode
^^^^^^

**Decode** pulls instructions out of the :term:`Fetch Buffer` and
generates the appropriate :term:`Micro-Op(s) (UOPs)<Micro-Op (UOP)>` to place into the
pipeline. [2]_

Rename
^^^^^^

The ISA, or "logical", register specifiers (e.g. x0-x31) are
then *renamed* into "physical" register specifiers.

Dispatch
^^^^^^^^

The :term:`UOP<Micro-Op (UOP)>` is then *dispatched*, or written, into
a set of :term:`Issue Queue` s.

Issue
^^^^^

:term:`UOPs<Micro-Op (UOP)>` sitting in a :term:`Issue Queue` wait until all of
their operands are ready and are then *issued*. [3]_ This is
the beginning of the out–of–order piece of the pipeline.

Register Read
^^^^^^^^^^^^^

Issued :term:`UOPs<Micro-Op (UOP)>` s first *read* their register operands from the unified
**Physical Register File** (or from the **Bypass Network**)...

Execute
^^^^^^^

... and then enter the **Execute** stage where the functional
units reside. Issued memory operations perform their address
calculations in the **Execute** stage, and then store the
calculated addresses in the **Load/Store Unit** which resides in the
**Memory** stage.

Memory
^^^^^^

The **Load/Store Unit** consists of three queues: a **Load Address Queue
(LAQ)**, a **Store Address Queue (SAQ)**, and a **Store Data Queue (SDQ)**.
Loads are fired to memory when their address is present in the
**LAQ**. Stores are fired to memory at **Commit** time (and
naturally, stores cannot be *committed* until both their
address and data have been placed in the **SAQ** and **SDQ**).

Writeback
^^^^^^^^^

ALU operations and load operations are *written* back to the
**Physical Register File**.

Commit
^^^^^^

The **Reorder Buffer (ROB)**, tracks the status of each instruction
in the pipeline. When the head of the **ROB** is not-busy, the **ROB**
*commits* the instruction. For stores, the **ROB** signals to the
store at the head of the **Store Queue (SAQ/SDQ)** that it can now write its
data to memory.

Branch Support
--------------

BOOM supports full branch speculation and branch prediction. Each
instruction, no matter where it is in the pipeline, is accompanied by a
**Branch Tag** that marks which branches the instruction is "speculated
under". A mispredicted branch requires killing all instructions that
depended on that branch. When a branch instructions passes through
**Rename**, copies of the **Register Rename Table** and the **Free
List** are made. On a mispredict, the saved processor state is
restored.

Detailed BOOM Pipeline
----------------------

Although :numref:`boom-pipeline` shows a simplified BOOM pipeline, BOOM supports RV64GC and the privileged ISA
which includes single-precision and double-precision floating point, atomics support, and page-based virtual memory.
A more detailed diagram is shown below in :numref:`boom-pipeline-detailed`.
```

### docs/sections/intro-overview/riscv-isa.rst

```text
The RISC-V ISA
==============

The `RISC-V ISA <riscv.org>`__ is a widely adopted open-source ISA suited for a variety of applications.
It includes a base ISA as well as multiple optional extensions that implement different features.
BOOM implements the RV64GC variant of the RISC-V ISA (otherwise known as IMAFDC) [1]_. This includes the
MAFDC extensions and the privileged specification (multiply/divide, AMOs,
load-reserve/store-conditional, single-precision and double-precision IEEE
754-2008 floating point).

RISC-V provides the following features which make it easy to target with
high-performance designs:

* **Relaxed memory model**

    * This greatly simplifies the **Load/Store Unit (LSU)**, which does not need to
      have loads snoop other loads nor does coherence traffic need to snoop
      the LSU, as required by sequential consistency.

* **Accrued Floating Point (FP) exception flags**

    * The FP status register does not need to be renamed, nor can FP
      instructions throw exceptions themselves.

* **No integer side-effects**

    * All integer ALU operations exhibit no side-effects, other than the writing
      of the destination register. This prevents the need to rename
      additional condition state.

* **No cmov or predication**

    * Although predication can lower the branch predictor complexity of
      small designs, it greatly complicates out-of-order pipelines, including the
      addition of a third read port for integer operations.

* **No implicit register specifiers**

    * Even JAL requires specifying an explicit register. This simplifies rename
      logic, which prevents either the need to know the instruction first
      before accessing the rename tables, or it prevents adding more ports
      to remove the instruction decode off the critical path.

* **Registers rs1, rs2, rs3, rd are always in the same place**

    * This allows decode and rename to proceed in parallel.

More information about the RISC-V ISA can be found at http://riscv.org.

.. [1] Currently, BOOM does not implement the proposed "V" vector extension.
```

### docs/sections/decode-stage.rst

```text
The Decode Stage
================

The **Decode** stage takes instructions from the :term:`Fetch Buffer`, decodes them,
and allocates the necessary resources as required by each instruction.
The **Decode** stage will stall as needed if not all resources are available.

RVC Changes
-----------

RVC decode is performed by expanding RVC instructions using Rocket's
``RVCExpander``. This does not change normal functionality of the **Decode** stage.
```

### docs/sections/rename-stage.rst

```text
BOOM is an "explicit renaming" or "physical register file" out-of-order
core design. A **Physical Register File**, containing many more registers
than the ISA dictates, holds both the committed architectural register
state and speculative register state. The **Rename Map Table** s contain the
information needed to recover the committed state. As instructions are
renamed, their register specifiers are explicitly updated to point to
physical registers located in the Physical Register File. [1]_
...
The Rename Map Table
--------------------

.. _rename-stage:
.. figure:: /figures/rename-pipeline.png
    :alt: The Rename Stage

    The **Rename Stage**. Logical register specifiers read the **Rename Map Table** to get their physical specifier.
    For superscalar rename, any changes to the Map Tables must be bypassed to dependent instructions. The
    physical source specifiers can then read the Busy Table. The Stale specifier is used to track which physical
    register will be freed when the instruction later commits. P0 in the Physical Register File is always 0.

The **Rename Map Table (abbreviated as Map Table)** holds the speculative mappings from ISA registers
to physical registers.

Each branch gets its own copy of the Rename Map Table[3]_ On a branch
mispredict, the Rename Map Table can be reset instantly from the mispredicting
branch’s copy of the Rename Map Table

As the RV64G ISA uses fixed locations of the register specifiers (and no
implicit register specifiers), the Map Table can be read before the
instruction is decoded! And hence the **Decode** and **Rename** stages can be combined.

Resets on Exceptions and Flushes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

An additional, optional "Committed Map Table" holds the rename map for
the committed architectural state. If enabled, this allows single-cycle
reset of the pipeline during flushes and exceptions (the current map
table is reset to the Committed Map Table). Otherwise, pipeline flushes
require multiple cycles to "unwind" the ROB to write back in the rename
state at the commit point, one ROB row per cycle.

The Busy Table
--------------

The **Busy Table** tracks the readiness status of each physical register. If
all physical operands are ready, the instruction will be ready to be
issued.

The Free List
-------------

The **Free List** tracks the physical registers that are currently un-used
and is used to allocate new physical registers to instructions passing
through the *Rename* stage.

The Free List is implemented as a bit-vector. A priority decoder can
then be used to find the first free register. BOOM uses a cascading
priority decoder to allocate multiple registers per cycle. [4]_

On every branch (or JALR), the Rename Map Tables are snapshotted to
allow single-cycle recovery on a branch misprediction. Likewise, the
Free List also sets aside a new "Allocation List", initialized to zero.
As new physical registers are allocated, the Allocation List for each
branch is updated to track all of the physical registers that have been
allocated after the branch. If a misspeculation occurs, its Allocation
List is added back to the Free List by *OR'ing* the branch’s Allocation
List with the Free List. [5]_

Stale Destination Specifiers
----------------------------

For instructions that will write a register, the Map Table is read to
get the *stale physical destination specifier* ("stale pdst"). Once the
instruction commits, the *stale pdst* is returned to the Free List, as
no future instructions will read it.
```

### docs/sections/issue-units.rst

```text
The Issue Unit
==============

The **Issue Queue** s hold dispatched :term:`Micro-Ops (UOPs) <Micro-Op (UOP)>` that have not yet executed.
When all of the operands for the :term:`UOP<Micro-Op (UOP)` are ready, the issue slot sets
its "request" bit high. The issue select logic then chooses to issue a
slot which is asserting its "request" signal. Once a :term:`UOP<Micro-Op (UOP)` is issued,
it is removed from the Issue Queue to make room for more dispatched
instructions.

BOOM uses a split Issue Queues - instructions of specific types are placed
into a unique Issue Queue (integer, floating point, memory).
...
Issue Select Logic
------------------

.. _single-issue-slot:
.. figure:: /figures/issue_slot.png
    :alt: Single Issue Slot

    A single issue slot from the Issue Queue.

Each issue select logic port is a static-priority encoder that picks
that first available :term:`UOP<Micro-Op (UOP)` in the Issue Queue. Each port will only
schedule a :term:`UOP<Micro-Op (UOP)` that its port can handle (e.g., floating point
:term:`UOPs<Micro-Op (UOP)` will only be scheduled onto the port governing the Floating
Point Unit). This creates a cascading priority encoder for ports that
can schedule the same :term:`UOPs<Micro-Op (UOP)` as each other.

If a **Functional Unit** is unavailable, it de-asserts its available signal
and instructions will not be issued to it (e.g., an un-pipelined
divider).
...
Age-ordered Issue Queue
------------------------

The second available policy is an Age-ordered Issue Queue. Dispatched
instructions are placed into the bottom of the Issue Queue (at lowest
priority). Every cycle, every instruction is shifted upwards (the Issue
queue is a “collapsing queue"). Thus, the oldest instructions will have
the highest issue priority. While this increases performance by
scheduling older branches and older loads as soon as possible, it comes
with a potential energy penalty as potentially every Issue Queue slot
is being read and written to on every cycle.

Wake-up
-------

There are two types of wake-up in BOOM - *fast* wakeup and *slow*
wakeup (also called a long latency wakeup). Because ALU :term:`UOPs<Micro-Op (UOP)` can send their write-back data through the
bypass network, issued ALU :term:`UOPs<Micro-Op (UOP)` will broadcast their wakeup to the
Issue Queue as they are issued.

However, floating-point operations, loads, and variable latency
operations are not sent through the bypass network, and instead the
wakeup signal comes from the register file ports during the *write-back*
stage.
```

### docs/sections/reg-file-bypass-network.rst

```text
BOOM is a unified, **Physical Register File (PRF)** design. The register
files hold both the committed and speculative state. Additionally,
there are two register files: one for integer and one for floating point
register values. The **Rename Map Tables** track which physical register corresponds
to which ISA register.

BOOM uses the Berkeley hardfloat floating point units which use an
internal 65-bit operand format
(https://github.com/ucb-bar/berkeley-hardfloat). Therefore, all physical
floating point registers are 65-bits.

Register Read
-------------

The register file statically provisions all of the register read ports
required to satisfy all issued instructions. For example, if *issue port
#0* corresponds to an integer ALU and *issue port #1* corresponds to memory
unit, then the first two register read ports will statically serve the
ALU and the next two register read ports will service the memory unit for four
total read ports.
...
Bypass Network
--------------

ALU operations can be issued back-to-back by having the write-back
values forwarded through the **Bypass Network**. Bypassing occurs at the end
of the **Register Read** stage.
```

### docs/sections/execution-stages.rst

```text
An :term:`Execution Unit` is a module that a single issue port will schedule
:term:`UOPs<Micro-Op (UOP)` onto and contains some mix of :term:`Functional Unit` s. Phrased in
another way, each issue port from the **Issue Queue** talks to one and only
one :term:`Execution Unit`. An :term:`Execution Unit` may contain just a single simple
integer ALU, or it could contain a full complement of floating point
units, a integer ALU, and an integer multiply unit.

The purpose of the :term:`Execution Unit` is to provide a flexible abstraction
which gives a lot of control over what kind of :term:`Execution Unit` s the
architect can add to their pipeline

Scheduling Readiness
~~~~~~~~~~~~~~~~~~~~

An :term:`Execution Unit` provides a bit-vector of the :term:`Functional Unit` s it has
available to the issue scheduler. The issue scheduler will only schedule
:term:`UOPs<Micro-Op (UOP)` that the :term:`Execution Unit` supports. For :term:`Functional Unit` s that
may not always be ready (e.g., an un-pipelined divider), the appropriate
bit in the bit-vector will be disabled (See :numref:`dual-issue-pipeline`).
...
Pipelined Functional Units
~~~~~~~~~~~~~~~~~~~~~~~~~~

A pipelined :term:`Functional Unit` can accept a new :term:`UOP<Micro-Op (UOP)` every cycle. Each
:term:`UOP<Micro-Op (UOP)` will take a known, fixed latency.

Speculation support is provided by auto-generating a pipeline that
passes down the :term:`UOP<Micro-Op (UOP)` meta-data and *branch mask* in parallel with
the :term:`UOP<Micro-Op (UOP)` within the expert-written :term:`Functional Unit` . If a :term:`UOP<Micro-Op (UOP)` is
misspeculated, it’s response is de-asserted as it exits the functional
unit.

An example pipelined :term:`Functional Unit` is shown in :numref:`abstract-fu`.

Un-pipelined Functional Units
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Un-pipelined :term:`Functional Unit` s (e.g., a divider) take an variable (and
unknown) number of cycles to complete a single operation. Once occupied,
they de-assert their ready signal and no additional :term:`UOPs<Micro-Op (UOP)` may be
scheduled to them.

Speculation support is provided by tracking the **branch mask** of the
:term:`UOP<Micro-Op (UOP)` in the :term:`Functional Unit`.

The only requirement of the expert-written un-pipelined :term:`Functional Unit`
is to provide a *kill* signal to quickly remove misspeculated
:term:`UOPs<Micro-Op (UOP)`. [1]_
...
Branch Unit & Branch Speculation
--------------------------------

The :term:`Branch Unit` handles the resolution of all branch and jump
instructions.

All :term:`UOPs<Micro-Op (UOP)` that are "inflight" in the pipeline (have an allocated ROB
entry) are given a branch mask, where each bit in the branch mask
corresponds to an un-executed, inflight branch that the :term:`UOP<Micro-Op (UOP)` is
speculated under. Each branch in *Decode* is allocated a branch tag,
and all following :term:`UOPs<Micro-Op (UOP)` will have the corresponding bit in the
branch mask set (until the branch is resolved by the :term:`Branch Unit`).

If the branches (or jumps) have been correctly speculated by the
:term:`Front-end`, then the :term:`Branch Unit` s only action is to broadcast the
corresponding branch tag to *all* inflight :term:`UOPs<Micro-Op (UOP)` that the branch has
been resolved correctly. Each :term:`UOP<Micro-Op (UOP)` can then clear the corresponding
bit in its branch mask, and that branch tag can then be allocated to a
new branch in the *Decode* stage.

If a branch (or jump) is misspeculated, the :term:`Branch Unit` must redirect
the PC to the correct target, kill the :term:`Front-end` and :term:`Fetch Buffer`, and
broadcast the misspeculated branch tag so that all dependent, inflight
:term:`UOPs<Micro-Op (UOP)` may be killed. The PC redirect signal goes out immediately, to
decrease the misprediction penalty. However, the *kill* signal is
delayed a cycle for critical path reasons.

...
Load/Store Unit
---------------

The **Load/Store Unit (LSU)** handles the execution of load, store, atomic,
and fence operations.

BOOM (currently) only supports having one LSU (and thus can only send
one load or store per cycle to memory). [2]_
...
Control/Status Register Instructions
------------------------------------

A set of **Control/Status Register (CSR)** instructions allow the atomic
read and write of the Control/Status Registers. These architectural
registers are separate from the integer and floating registers, and
include the cycle count, retired instruction count, status, exception
PC, and exception vector registers (and many more!). Each CSR has its
own required privilege levels to read and write to it and some have
their own side-effects upon reading (or writing).

BOOM (currently) does not rename *any* of the CSRs, and in addition to
the potential side-effects caused by reading or writing a CSR, **BOOM
will only execute a CSR instruction non-speculatively.** [6]_ This is
accomplished by marking the CSR instruction as a "unique" (or
"serializing") instruction - the ROB must be empty before it may proceed
to the Issue Queue (and no instruction may follow it until it has
finished execution and been committed by the ROB). It is then issued by
the Issue Queue, reads the appropriate operands from the Physical
Register File, and is then sent to the CSRFile. [7]_ The CSR instruction
executes in the CSRFile and then writes back data as required to the
Physical Register File. The CSRFile may also emit a PC redirect and/or
an exception as part of executing a CSR instruction (e.g., a syscall).
```

### docs/sections/load-store-unit.rst

```text
The **Load/Store Unit (LSU)** is responsible for deciding when to fire memory
operations to the memory system. There are two queues: the **Load
Queue (LDQ)**, and the **Store Queue (STQ)**. Load instructions generate a
“uopLD" :term:`Micro-Op (UOP)`. When issued, "uopLD" calculates the load address and
places its result in the LDQ. Store instructions (may) generate *two*
:term:`UOP<Micro-Op (UOP)>` s, “uopSTA" (Store Address Generation) and “uopSTD" (Store Data
Generation). The STA :term:`UOP<Micro-Op (UOP)>` calculates the store address and updates the
address in the STQ entry. The STD :term:`UOP<Micro-Op (UOP)>` moves the store data into the
STQ entry. Each of these :term:`UOP<Micro-Op (UOP)>` s will issue out of the
*Issue Window* as soon their operands are ready. See :ref:`Store Micro-Ops`
for more details on the store :term:`UOP<Micro-Op (UOP)>` specifics.

Store Instructions
------------------

Entries in the Store Queue are allocated in the *Decode* stage (
stq(i).valid is set). A “valid" bit denotes when an entry in the STQ holds
a valid address and valid data (stq(i).bits.addr.valid and stq(i).bits.data.valid).
Once a store instruction is committed, the corresponding entry in the Store
Queue is marked as committed. The store is then free to be fired to the
memory system at its convenience. Stores are fired to the memory in program
order.

Store Micro-Ops
~~~~~~~~~~~~~~~

Stores are inserted into the issue window as a single instruction (as
opposed to being broken up into separate addr-gen and data-gen
:term:`UOP<Micro-Op (UOP)>` s). This prevents wasteful usage of the expensive issue window
entries and extra contention on the issue ports to the LSU. A store in
which both operands are ready can be issued to the LSU as a single
:term:`UOP<Micro-Op (UOP)>` which provides both the address and the data to the LSU. While
this requires store instructions to have access to two register file
read ports, this is motivated by a desire to not cut performance in half
on store-heavy code. Sequences involving stores to the stack should
operate at IPC=1!

However, it is common for store addresses to be known well in advance of
the store data. Store addresses should be moved to the STQ as soon as
possible to allow later loads to avoid any memory ordering failures.
Thus, the issue window will emit uopSTA or uopSTD :term:`UOP<Micro-Op (UOP)>` s as required,
but retain the remaining half of the store until the second operand is
ready.

Load Instructions
-----------------

Entries in the Load Queue (LDQ) are allocated in the *Decode* stage
(``ldq(i).valid``). In **Decode**, each load entry is also given a *store
mask* (``ldq(i).bits.st\_dep\_mask``), which marks which stores in the Store
Queue the given load depends on. When a store is fired to memory and
leaves the Store Queue, the appropriate bit in the *store mask* is cleared.

Once a load address has been computed and placed in the LDQ, the
corresponding *valid* bit is set (``ldq(i).addr.valid``).

Loads are optimistically fired to memory on arrival to the LSU (getting
loads fired early is a huge benefit of out–of–order pipelines).
Simultaneously, the load instruction compares its address with all of
the store addresses that it depends on. If there is a match, the memory
request is killed. If the corresponding store data is present, then the
store data is *forwarded* to the load and the load marks itself as
having *succeeded*. If the store data is not present, then the load goes
to *sleep*. Loads that have been put to sleep are retried at a later
time. [1]_

The BOOM Memory Model
---------------------

BOOM follows the RVWMO memory consistency model.
...
Ordering Loads to the Same Address
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The RISC-V WMO memory model requires that loads to the same address be ordered.
[2]_ This requires loads to search against other loads for potential address conflicts.
If a younger load executes before an older load with a matching address, the
younger load must be replayed and the instructions after it in the pipeline flushed.
However, this scenario is only required if a cache coherence probe event
snooped the core’s memory, exposing the reordering to the other threads.
If no probe events occurred, the load re-ordering may safely occur.

Memory Ordering Failures
------------------------

The Load/Store Unit has to be careful regarding
store -> load dependences. For the best performance,
loads need to be fired to memory as soon as possible.

.. code-block:: bash

    sw x1 -> 0(x2)
    ld x3 <- 0(x4)

However, if x2 and x4 reference the same memory address, then the load
in our example *depends* on the earlier store. If the load issues to
memory before the store has been issued, the load will read the wrong
value from memory, and a *memory ordering failure* has occurred. On an
ordering failure, the pipeline must be flushed and the Rename Map Tables
reset. This is an incredibly expensive operation.

To discover ordering failures, when a store commits, it checks the
entire LDQ for any address matches. If there is a match, the store
checks to see if the load has *executed*, and if it got its data from
memory or if the data was forwarded from an older store. In either case,
a memory ordering failure has occurred.
```

### docs/sections/reorder-buffer.rst

```text
The Reorder Buffer (ROB) and the Dispatch Stage
===============================================

The **Reorder Buffer (ROB)** tracks the state of all inflight instructions in the pipeline.
The role of the ROB is to provide the illusion to the programmer that
his program executes in-order. After instructions are *decoded* and
*renamed*, they are then *dispatched* to the ROB and the **Issue Queue** and
marked as *busy*. As instructions finish execution, they inform the ROB
and are marked *not busy*. Once the "head" of the ROB is no longer busy,
the instruction is *committed*, and it’s architectural state now
visible. If an exception occurs and the excepting instruction is at the
head of the ROB, the pipeline is flushed and no architectural changes
that occurred after the excepting instruction are made visible. The ROB
then redirects the PC to the appropriate exception handler.
...
The ROB is, conceptually, a circular buffer that tracks all inflight
instructions in-order. The oldest instruction is pointed to by the
*commit head*, and the newest instruction will be added at the *rob
tail*.

To facilitate superscalar *dispatch* and *commit*, the ROB is
implemented as a circular buffer with ``W`` banks (where ``W``
is the *dispatch* and *commit* width of the machine [1]_). This
organization is shown in :numref:`rob`.

At *dispatch*, up to ``W`` instructions are written from the :term:`Fetch Packet`
into an ROB row, where each instruction is written to a
different bank across the row. As the instructions within a :term:`Fetch Packet`
are all consecutive (and aligned) in memory, this allows a
single PC to be associated with the entire :term:`Fetch Packet` (and the
instruction’s position within the :term:`Fetch Packet` provides the low-order
bits to its own PC). While this means that branching code will leave
bubbles in the ROB, it makes adding more instructions to the ROB very
cheap as the expensive costs are amortized across each ROB row.
...
Exception State
~~~~~~~~~~~~~~~

The ROB tracks the oldest excepting instruction. If this instruction
reaches the head of the ROB, then an exception is thrown.

Each ROB entry is marked with a single-bit to signify whether or not the
instruction has encountered exceptional behavior, but the additional
exception state (e.g., the bad virtual address and the exception cause)
is only tracked for the oldest known excepting instruction. This saves
considerable state by not storing this on a per entry basis.
...
The Commit Stage
----------------
When the instruction at the *commit head* is no longer busy (and it is
not excepting), it may be *committed*, i.e., its changes to the
architectural state of the machine are made visible. For superscalar
commit, the entire ROB row is analyzed for *not busy* instructions (and
thus, up to the entire ROB row may be committed in a single cycle). The
ROB will greedily commit as many instructions as it can per row to
release resource as soon as possible. However, the ROB does not
(currently) look across multiple rows to find commit-able instructions.

Only once a store has been committed may it be sent to memory. For
superscalar committing of stores, the **Load/Store Unit (LSU)** is told "how many stores" may
be marked as committed. The LSU will then drain the committed stores to
memory as it sees fit.

When an instruction (that writes to a register) commits, it then frees
the *stale physical destination register*. The *stale pdst* is then free
to be re-allocated to a new instruction.

Exceptions and Flushes
----------------------

Exceptions are handled when the instruction at the *commit head* is
excepting. The pipeline is then flushed and the ROB emptied. The **Rename
Map Tables** must be reset to represent the true, non-speculative
*committed* state. The :term:`Front-end` is then directed to the appropriate PC.
If it is an architectural exception, the excepting instruction’s PC
(referred to as the *exception vector*) is sent to the Control/Status
Register (CSR) file. If it is a micro-architectural exception (e.g., a
load/store ordering misspeculation) the failing instruction is refetched
and execution can begin anew.

Parameterization - Rollback versus Single-cycle Reset
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The behavior of resetting the Rename Map Tables is parameterizable. The first
option is to rollback the ROB one row per cycle to unwind the rename
state (this is the behavior of the MIPS
R10k). For each instruction, the *stale
physical destination* register is written back into the Map Table for
its *logical destination* specifier.

A faster single-cycle reset is available. This is accomplished by using
another rename snapshot that tracks the *committed* state of the rename
tables. This *Committed Map Table* is updated as instructions
commit. [2]_
...
Point of No Return (PNR)
------------------------

The point-of-no-return head runs ahead of the ROB commit head, marking the
next instruction which might be misspeculated or generate an exception.
These include unresolved branches and untranslated memory operations.
Thus, the instructions *ahead* of the commit head and *behind* the PNR
head are guaranteed to be *non-speculative*, even if they have not yet
written back.

Currently the PNR is only used for RoCC instructions. RoCC co-processors
typically expect their instructions in-order, and do not tolerate misspeculation.
Thus we can only issue a instruction to our co-processor when it has past the
PNR head, and thus is no longer speculative.
```

### docs/sections/memory-system.rst

```text
BOOM uses the Rocket Chip non-blocking cache ("Hellacache"). Designed for use
in in-order processors, a "shim" is used to connect BOOM to the
data cache. The source code for the cache can be found in
``nbdcache.scala`` in the `Rocket Chip repository <https://github.com/chipsalliance/rocket-chip>`.

The contract with the cache is that it may execute all memory operations
sent to it (barring structural hazards). As BOOM will send speculative
load instructions to the cache, the shim (``dcacheshim.scala``) must
track all "inflight load requests" and their status. If an inflight load
is discovered to be misspeculated, it is marked as such in the shim.
Upon return from the data cache, the load’s response to the pipeline is
suppressed and it is removed from the inflight load queue.

The Hellacache does not ack store requests; the absence of a nack is
used to signal a success.

All memory requests to the Hellacache may be killed the cycle after
issuing the request (while the request is accessing the data arrays).

The current data cache design accesses the SRAMs in a single-cycle.

The cache has a three-stage pipeline and can accept a new request every cycle.
```
