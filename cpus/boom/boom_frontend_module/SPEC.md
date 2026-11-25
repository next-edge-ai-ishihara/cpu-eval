# Implement `BoomFrontendModule`

Implement the `BoomFrontendModule` definition for the selected configuration. Preserve the declaration and public interface below.

Return only the complete `class BoomFrontendModule` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/common/parameters.scala

```scala
  numFetchBufferEntries: Int = 16,
// ...
  enableSFBOpt: Boolean = false,
  enableGHistStallRepair: Boolean = true,
  enableBTBFastRepair: Boolean = true,
// ...
  ftq: FtqParameters = FtqParameters(),
// ...
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
// ...
  nBreakpoints: Int = 0, // TODO Fix with better frontend breakpoint unit
```

### src/main/scala/common/config-mixins.scala

```scala
// DOC include start: LargeBoomConfig
/**
 * 3-wide BOOM. Try to match the Cortex-A15.
 */
class WithNLargeBooms(n: Int = 1, overrideIdOffset: Option[Int] = None) extends Config(
  new WithTAGELBPD ++ // Default to TAGE-L BPD
  new Config((site, here, up) => {
// ...
            core = BoomCoreParams(
              fetchWidth = 8,
              decodeWidth = 3,
// ...
              maxBrCount = 16,
              numFetchBufferEntries = 24,
              ftq = FtqParameters(nEntries=32),
// ...
            icache = Some(
              ICacheParams(rowBits = site(SystemBusKey).beatBits, nSets=64, nWays=8, fetchBytes=4*4)
            ),
// ...
    case SystemBusKey => up(SystemBusKey, site).copy(beatBytes = 16)
    case XLen => 64
// ...
class WithTAGELBPD extends Config((site, here, up) => {
  case TilesLocated(InSubsystem) => up(TilesLocated(InSubsystem), site) map {
    case tp: BoomTileAttachParams => tp.copy(tileParams = tp.tileParams.copy(core = tp.tileParams.core.copy(
      bpdMaxMetaLength = 120,
      globalHistoryLength = 64,
      localHistoryLength = 1,
      localHistoryNSets = 0,
      branchPredictor = ((resp_in: BranchPredictionBankResponse, p: Parameters) => {
        val loop = Module(new LoopBranchPredictorBank()(p))
        val tage = Module(new TageBranchPredictorBank()(p))
        val btb = Module(new BTBBranchPredictorBank()(p))
        val bim = Module(new BIMBranchPredictorBank()(p))
        val ubtb = Module(new FAMicroBTBBranchPredictorBank()(p))
        val preds = Seq(loop, tage, btb, ubtb, bim)
        preds.map(_.io := DontCare)

        ubtb.io.resp_in(0)  := resp_in
        bim.io.resp_in(0)   := ubtb.io.resp
        btb.io.resp_in(0)   := bim.io.resp
        tage.io.resp_in(0)  := btb.io.resp
        loop.io.resp_in(0)  := tage.io.resp

        (preds, loop.io.resp)
      })
    )))
    case other => other
  }
})
```

## Package and imports

```scala
//******************************************************************************
// Copyright (c) 2017 - 2019, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE and LICENSE.SiFive for license details.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// Frontend
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

package boom.ifu

import chisel3._
import chisel3.util._
import chisel3.internal.sourceinfo.{SourceInfo}

import freechips.rocketchip.config._
import freechips.rocketchip.subsystem._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.rocket._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.tile._
import freechips.rocketchip.util._
import freechips.rocketchip.util.property._

import boom.common._
import boom.exu.{CommitExceptionSignals, BranchDecode, BrUpdateInfo, BranchDecodeSignals}
import boom.util._
```

## Class declaration

```scala
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

/**
 * Top level Frontend class
 *
 * @param icacheParams parameters for the icache
 * @param hartid id for the hardware thread of the core
 */
class BoomFrontend(val icacheParams: ICacheParams, staticIdForMetadataUseOnly: Int)(implicit p: Parameters) extends LazyModule
{
  lazy val module = new BoomFrontendModule(this)
  val icache = LazyModule(new boom.ifu.ICache(icacheParams, staticIdForMetadataUseOnly))
  val masterNode = icache.masterNode
  val resetVectorSinkNode = BundleBridgeSink[UInt](Some(() =>
    UInt(masterNode.edges.out.head.bundle.addressBits.W)))
}

/**
 * Bundle wrapping the IO for the Frontend as a whole
 *
 * @param outer top level Frontend class
 */
class BoomFrontendBundle(val outer: BoomFrontend) extends CoreBundle()(outer.p)
{
  val cpu = Flipped(new BoomFrontendIO())
  val ptw = new TLBPTWIO()
  val errors = new ICacheErrors
}

/**
 * Main Frontend module that connects the icache, TLB, fetch controller,
 * and branch prediction pipeline together.
 *
 * @param outer top level Frontend class
 */
class BoomFrontendModule(outer: BoomFrontend) extends LazyModuleImp(outer)
  with HasBoomCoreParameters
  with HasBoomFrontendParameters
{
  val io = IO(new BoomFrontendBundle(outer))
```

## Parent instantiation

### src/main/scala/common/tile.scala

```scala
  // Frontend/ICache
  val frontend = LazyModule(new BoomFrontend(tileParams.icache.get, staticIdForMetadataUseOnly))
  frontend.resetVectorSinkNode := resetVectorNexusNode
  tlMasterXbar.node := frontend.masterNode
// ...
  val core = Module(new BoomCore(outer.boomParams.trace)(outer.p))
  val lsu  = Module(new LSU()(outer.p, outer.dcache.module.edge))

  val ptwPorts         = ListBuffer(lsu.io.ptw, outer.frontend.module.io.ptw, core.io.ptw_tlb)
// ...
  // Connect the core pipeline to other intra-tile modules
  outer.frontend.module.io.cpu <> core.io.ifu
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
// ...
  val maxBrCount    = boomParams.maxBrCount          // number of branches we can speculate simultaneously
  val ftqSz         = boomParams.ftq.nEntries        // number of FTQ entries
  val numFetchBufferEntries = boomParams.numFetchBufferEntries // number of instructions that stored between fetch&decode
// ...
  val icacheParams: ICacheParams = tileParams.icache.get
  val icBlockBytes = icacheParams.blockBytes

  require(icacheParams.nSets <= 64, "Handling aliases in the ICache is buggy.")
// ...
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
// ...
  val enableSFBOpt = boomParams.enableSFBOpt
  val enableGHistStallRepair = boomParams.enableGHistStallRepair
  val enableBTBFastRepair = boomParams.enableBTBFastRepair
```

### src/main/scala/ifu/frontend.scala

```scala
class FrontendResp(implicit p: Parameters) extends BoomBundle()(p) {
  val pc = UInt(vaddrBitsExtended.W)  // ID stage PC
  val data = UInt((fetchWidth * coreInstBits).W)
  val mask = UInt(fetchWidth.W)
  val xcpt = new FrontendExceptions
  val ghist = new GlobalHistory

  // fsrc provides the prediction FROM a branch in this packet
  // tsrc provides the prediction TO this packet
  val fsrc = UInt(BSRC_SZ.W)
  val tsrc = UInt(BSRC_SZ.W)
}

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

  def histories(bank: Int) = {
    if (nBanks == 1) {
      old_history
    } else {
      require(nBanks == 2)
      if (bank == 0) {
        old_history
      } else {
        Mux(new_saw_branch_taken                            , old_history << 1 | 1.U,
        Mux(new_saw_branch_not_taken                        , old_history << 1,
                                                              old_history))
      }
    }
  }

  def ===(other: GlobalHistory): Bool = {
    ((old_history === other.old_history) &&
     (new_saw_branch_not_taken === other.new_saw_branch_not_taken) &&
     (new_saw_branch_taken === other.new_saw_branch_taken)
    )
  }
  def =/=(other: GlobalHistory): Bool = !(this === other)

  def update(branches: UInt, cfi_taken: Bool, cfi_is_br: Bool, cfi_idx: UInt,
    cfi_valid: Bool, addr: UInt,
    cfi_is_call: Bool, cfi_is_ret: Bool): GlobalHistory = {
    val cfi_idx_fixed = cfi_idx(log2Ceil(fetchWidth)-1,0)
    val cfi_idx_oh = UIntToOH(cfi_idx_fixed)
    val new_history = Wire(new GlobalHistory)

    val not_taken_branches = branches & Mux(cfi_valid,
                                            MaskLower(cfi_idx_oh) & ~Mux(cfi_is_br && cfi_taken, cfi_idx_oh, 0.U(fetchWidth.W)),
                                            ~(0.U(fetchWidth.W)))

    if (nBanks == 1) {
      // In the single bank case every bank sees the history including the previous bank
      new_history := DontCare
      new_history.current_saw_branch_not_taken := false.B
      val saw_not_taken_branch = not_taken_branches =/= 0.U || current_saw_branch_not_taken
      new_history.old_history := Mux(cfi_is_br && cfi_taken && cfi_valid   , histories(0) << 1 | 1.U,
                                 Mux(saw_not_taken_branch                  , histories(0) << 1,
                                                                             histories(0)))
    } else {
      // In the two bank case every bank ignore the history added by the previous bank
      val base = histories(1)
      val cfi_in_bank_0 = cfi_valid && cfi_taken && cfi_idx_fixed < bankWidth.U
      val ignore_second_bank = cfi_in_bank_0 || mayNotBeDualBanked(addr)

      val first_bank_saw_not_taken = not_taken_branches(bankWidth-1,0) =/= 0.U || current_saw_branch_not_taken
      new_history.current_saw_branch_not_taken := false.B
      when (ignore_second_bank) {
        new_history.old_history := histories(1)
        new_history.new_saw_branch_not_taken := first_bank_saw_not_taken
        new_history.new_saw_branch_taken     := cfi_is_br && cfi_in_bank_0
      } .otherwise {
        new_history.old_history := Mux(cfi_is_br && cfi_in_bank_0                             , histories(1) << 1 | 1.U,
                                   Mux(first_bank_saw_not_taken                               , histories(1) << 1,
                                                                                                histories(1)))

        new_history.new_saw_branch_not_taken := not_taken_branches(fetchWidth-1,bankWidth) =/= 0.U
        new_history.new_saw_branch_taken     := cfi_valid && cfi_taken && cfi_is_br && !cfi_in_bank_0

      }
    }
    new_history.ras_idx := Mux(cfi_valid && cfi_is_call, WrapInc(ras_idx, nRasEntries),
                           Mux(cfi_valid && cfi_is_ret , WrapDec(ras_idx, nRasEntries), ras_idx))
    new_history
  }

}

/**
 * Parameters to manage a L1 Banked ICache
 */
trait HasBoomFrontendParameters extends HasL1ICacheParameters
{
  // How many banks does the ICache use?
  val nBanks = if (cacheParams.fetchBytes <= 8) 1 else 2
  // How many bytes wide is a bank?
  val bankBytes = fetchBytes/nBanks

  val bankWidth = fetchWidth/nBanks

  require(nBanks == 1 || nBanks == 2)



  // How many "chunks"/interleavings make up a cache line?
  val numChunks = cacheParams.blockBytes / bankBytes

  // Which bank is the address pointing to?
  def bank(addr: UInt) = if (nBanks == 2) addr(log2Ceil(bankBytes)) else 0.U
  def isLastBankInBlock(addr: UInt) = {
    (nBanks == 2).B && addr(blockOffBits-1, log2Ceil(bankBytes)) === (numChunks-1).U
  }
  def mayNotBeDualBanked(addr: UInt) = {
    require(nBanks == 2)
    isLastBankInBlock(addr)
  }

  def blockAlign(addr: UInt) = ~(~addr | (cacheParams.blockBytes-1).U)
  def bankAlign(addr: UInt) = ~(~addr | (bankBytes-1).U)

  def fetchIdx(addr: UInt) = addr >> log2Ceil(fetchBytes)

  def nextBank(addr: UInt) = bankAlign(addr) + bankBytes.U
  def nextFetch(addr: UInt) = {
    if (nBanks == 1) {
      bankAlign(addr) + bankBytes.U
    } else {
      require(nBanks == 2)
      bankAlign(addr) + Mux(mayNotBeDualBanked(addr), bankBytes.U, fetchBytes.U)
    }
  }

  def fetchMask(addr: UInt) = {
    val idx = addr.extract(log2Ceil(fetchWidth)+log2Ceil(coreInstBytes)-1, log2Ceil(coreInstBytes))
    if (nBanks == 1) {
      ((1 << fetchWidth)-1).U << idx
    } else {
      val shamt = idx.extract(log2Ceil(fetchWidth)-2, 0)
      val end_mask = Mux(mayNotBeDualBanked(addr), Fill(fetchWidth/2, 1.U), Fill(fetchWidth, 1.U))
      ((1 << fetchWidth)-1).U << shamt & end_mask
    }
  }

  def bankMask(addr: UInt) = {
    val idx = addr.extract(log2Ceil(fetchWidth)+log2Ceil(coreInstBytes)-1, log2Ceil(coreInstBytes))
    if (nBanks == 1) {
      1.U(1.W)
    } else {
      Mux(mayNotBeDualBanked(addr), 1.U(2.W), 3.U(2.W))
    }
  }
}



/**
 * Bundle passed into the FetchBuffer and used to combine multiple
 * relevant signals together.
 */
class FetchBundle(implicit p: Parameters) extends BoomBundle
  with HasBoomFrontendParameters
{
  val pc            = UInt(vaddrBitsExtended.W)
  val next_pc       = UInt(vaddrBitsExtended.W)
  val edge_inst     = Vec(nBanks, Bool()) // True if 1st instruction in this bundle is pc - 2
  val insts         = Vec(fetchWidth, Bits(32.W))
  val exp_insts     = Vec(fetchWidth, Bits(32.W))

  // Information for sfb folding
  // NOTE: This IS NOT equivalent to uop.pc_lob, that gets calculated in the FB
  val sfbs                 = Vec(fetchWidth, Bool())
  val sfb_masks            = Vec(fetchWidth, UInt((2*fetchWidth).W))
  val sfb_dests            = Vec(fetchWidth, UInt((1+log2Ceil(fetchBytes)).W))
  val shadowable_mask      = Vec(fetchWidth, Bool())
  val shadowed_mask        = Vec(fetchWidth, Bool())

  val cfi_idx       = Valid(UInt(log2Ceil(fetchWidth).W))
  val cfi_type      = UInt(CFI_SZ.W)
  val cfi_is_call   = Bool()
  val cfi_is_ret    = Bool()
  val cfi_npc_plus4 = Bool()

  val ras_top       = UInt(vaddrBitsExtended.W)

  val ftq_idx       = UInt(log2Ceil(ftqSz).W)
  val mask          = UInt(fetchWidth.W) // mark which words are valid instructions

  val br_mask       = UInt(fetchWidth.W)

  val ghist         = new GlobalHistory
  val lhist         = Vec(nBanks, UInt(localHistoryLength.W))

  val xcpt_pf_if    = Bool() // I-TLB miss (instruction fetch fault).
  val xcpt_ae_if    = Bool() // Access exception.

  val bp_debug_if_oh= Vec(fetchWidth, Bool())
  val bp_xcpt_if_oh = Vec(fetchWidth, Bool())

  val end_half      = Valid(UInt(16.W))


  val bpd_meta      = Vec(nBanks, UInt())

  // Source of the prediction from this bundle
  val fsrc    = UInt(BSRC_SZ.W)
  // Source of the prediction to this bundle
  val tsrc    = UInt(BSRC_SZ.W)
}
```

### src/main/scala/rocket/ICache.scala

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
  def tagCode: Code = Code.fromString(tagECC)
  def dataCode: Code = Code.fromString(dataECC)
  def replacement = new RandomReplacement(nWays)
}

trait HasL1ICacheParameters extends HasL1CacheParameters with HasCoreParameters {
  val cacheParams = tileParams.icache.get
}

class ICacheReq(implicit p: Parameters) extends CoreBundle()(p) with HasL1ICacheParameters {
  val addr = UInt(width = vaddrBits)
}
```

### src/main/scala/ifu/icache.scala

```scala
/**
 * IO Signals leaving the ICache
 *
 * @param outer top level ICache class
 */
class ICacheResp(val outer: ICache) extends Bundle
{
  val data = UInt((outer.icacheParams.fetchBytes*8).W)
  val replay = Bool()
  val ae = Bool()
}

/**
 * IO Signals for interacting with the ICache
 *
 * @param outer top level ICache class
 */
class ICacheBundle(val outer: ICache) extends BoomBundle()(outer.p)
  with HasBoomFrontendParameters
{
  val req = Flipped(Decoupled(new ICacheReq))
  val s1_paddr = Input(UInt(paddrBits.W)) // delayed one cycle w.r.t. req

  val s1_kill = Input(Bool()) // delayed one cycle w.r.t. req
  val s2_kill = Input(Bool()) // delayed two cycles; prevents I$ miss emission
  val s2_prefetch = Input(Bool()) // should I$ prefetch next line on a miss?

  val resp = Valid(new ICacheResp(outer))
  val invalidate = Input(Bool())

  val perf = Output(new Bundle {
    val acquire = Bool()
  })
}
```

### src/main/scala/rocket/TLB.scala

```scala
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

class TLB(instruction: Boolean, lgMaxSize: Int, cfg: TLBConfig)(implicit edge: TLEdgeOut, p: Parameters) extends CoreModule()(p) {
  val io = new Bundle {
    val req = Decoupled(new TLBReq(lgMaxSize)).flip
    val resp = new TLBResp().asOutput
    val sfence = Valid(new SFenceReq).asInput
    val ptw = new TLBPTWIO
    val kill = Bool(INPUT) // suppress a TLB refill, one cycle after a miss
  }
```

### src/main/scala/rocket/Frontend.scala

```scala
class FrontendExceptions extends Bundle {
  val pf = new Bundle {
    val inst = Bool()
  }
  val gf = new Bundle {
    val inst = Bool()
  }
  val ae = new Bundle {
    val inst = Bool()
  }
}
// ...
class FrontendPerfEvents extends Bundle {
  val acquire = Bool()
  val tlbMiss = Bool()
}
```

### src/main/scala/rocket/CSR.scala

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

  val sd = Bool()
  val zero2 = UInt(width = 23)
  val mpv = Bool()
  val gva = Bool()
  val mbe = Bool()
  val sbe = Bool()
  val sxl = UInt(width = 2)
  val uxl = UInt(width = 2)
  val sd_rv32 = Bool()
  val zero1 = UInt(width = 8)
  val tsr = Bool()
  val tw = Bool()
  val tvm = Bool()
  val mxr = Bool()
  val sum = Bool()
  val mprv = Bool()
  val xs = UInt(width = 2)
  val fs = UInt(width = 2)
  val mpp = UInt(width = 2)
  val vs = UInt(width = 2)
  val spp = UInt(width = 1)
  val mpie = Bool()
  val ube = Bool()
  val spie = Bool()
  val upie = Bool()
  val mie = Bool()
  val hie = Bool()
  val sie = Bool()
  val uie = Bool()
}
```

### src/main/scala/ifu/bpd/predictor.scala

```scala
// A branch prediction for a single instruction
class BranchPrediction(implicit p: Parameters) extends BoomBundle()(p)
{
  // If this is a branch, do we take it?
  val taken           = Bool()

  // Is this a branch?
  val is_br           = Bool()
  // Is this a JAL?
  val is_jal          = Bool()
  // What is the target of his branch/jump? Do we know the target?
  val predicted_pc    = Valid(UInt(vaddrBitsExtended.W))


}

// A branch prediction for a entire fetch-width worth of instructions
// This is typically merged from individual predictions from the banked
// predictor
class BranchPredictionBundle(implicit p: Parameters) extends BoomBundle()(p)
  with HasBoomFrontendParameters
{
  val pc = UInt(vaddrBitsExtended.W)
  val preds = Vec(fetchWidth, new BranchPrediction)
  val meta = Output(Vec(nBanks, UInt(bpdMaxMetaLength.W)))
  val lhist = Output(Vec(nBanks, UInt(localHistoryLength.W)))
}


// A branch update for a fetch-width worth of instructions
class BranchPredictionUpdate(implicit p: Parameters) extends BoomBundle()(p)
  with HasBoomFrontendParameters
{
  // Indicates that this update is due to a speculated misprediction
  // Local predictors typically update themselves with speculative info
  // Global predictors only care about non-speculative updates
  val is_mispredict_update = Bool()
  val is_repair_update = Bool()
  val btb_mispredicts = UInt(fetchWidth.W)
  def is_btb_mispredict_update = btb_mispredicts =/= 0.U
  def is_commit_update = !(is_mispredict_update || is_repair_update || is_btb_mispredict_update)

  val pc            = UInt(vaddrBitsExtended.W)
  // Mask of instructions which are branches.
  // If these are not cfi_idx, then they were predicted not taken
  val br_mask       = UInt(fetchWidth.W)
  // Which CFI was taken/mispredicted (if any)
  val cfi_idx       = Valid(UInt(log2Ceil(fetchWidth).W))
  // Was the cfi taken?
  val cfi_taken     = Bool()
  // Was the cfi mispredicted from the original prediction?
  val cfi_mispredicted = Bool()
  // Was the cfi a br?
  val cfi_is_br     = Bool()
  // Was the cfi a jal/jalr?
  val cfi_is_jal  = Bool()
  // Was the cfi a jalr
  val cfi_is_jalr = Bool()
  //val cfi_is_ret  = Bool()

  val ghist = new GlobalHistory
  val lhist = Vec(nBanks, UInt(localHistoryLength.W))


  // What did this CFI jump to?
  val target        = UInt(vaddrBitsExtended.W)

  val meta          = Vec(nBanks, UInt(bpdMaxMetaLength.W))
}
// ...
class BranchPredictionRequest(implicit p: Parameters) extends BoomBundle()(p)
{
  val pc    = UInt(vaddrBitsExtended.W)
  val ghist = new GlobalHistory
}


class BranchPredictionBankResponse(implicit p: Parameters) extends BoomBundle()(p)
  with HasBoomFrontendParameters
{
  val f1 = Vec(bankWidth, new BranchPrediction)
  val f2 = Vec(bankWidth, new BranchPrediction)
  val f3 = Vec(bankWidth, new BranchPrediction)
}
// ...
class BranchPredictor(implicit p: Parameters) extends BoomModule()(p)
 with HasBoomFrontendParameters
{
  val io = IO(new Bundle {

    // Requests and responses
    val f0_req = Input(Valid(new BranchPredictionRequest))

    val resp = Output(new Bundle {
      val f1 = new BranchPredictionBundle
      val f2 = new BranchPredictionBundle
      val f3 = new BranchPredictionBundle
    })

    val f3_fire = Input(Bool())

    // Update
    val update = Input(Valid(new BranchPredictionUpdate))
  })
```

### src/main/scala/ifu/bpd/ras.scala

```scala
class BoomRAS(implicit p: Parameters) extends BoomModule()(p)
{
  val io = IO(new Bundle {
    val read_idx   = Input(UInt(log2Ceil(nRasEntries).W))
    val read_addr  = Output(UInt(vaddrBitsExtended.W))

    val write_valid = Input(Bool())
    val write_idx   = Input(UInt(log2Ceil(nRasEntries).W))
    val write_addr  = Input(UInt(vaddrBitsExtended.W))
  })
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

/**
 * Buffer to hold fetched packets and convert them into a vector of MicroOps
 * to give the Decode stage
 *
 * @param num_entries effectively the number of full-sized fetch packets we can hold.
 */
class FetchBuffer(implicit p: Parameters) extends BoomModule
  with HasBoomCoreParameters
  with HasBoomFrontendParameters
{
  val numEntries = numFetchBufferEntries
  val io = IO(new BoomBundle {
    val enq = Flipped(Decoupled(new FetchBundle()))
    val deq = new DecoupledIO(new FetchBufferResp())

    // Was the pipeline redirected? Clear/reset the fetchbuffer.
    val clear = Input(Bool())
  })

  require (numEntries > fetchWidth)
  require (numEntries % coreWidth == 0)
```

### src/main/scala/ifu/fetch-target-queue.scala

```scala
/**
 * FTQ Parameters used in configurations
 *
 * @param nEntries # of entries in the FTQ
 */
case class FtqParameters(
  nEntries: Int = 16
)

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

/**
 * Queue to store the fetch PC and other relevant branch predictor signals that are inflight in the
 * processor.
 *
 * @param num_entries # of entries in the FTQ
 */
class FetchTargetQueue(implicit p: Parameters) extends BoomModule
  with HasBoomCoreParameters
  with HasBoomFrontendParameters
{
  val num_entries = ftqSz
  private val idx_sz = log2Ceil(num_entries)

  val io = IO(new BoomBundle {
    // Enqueue one entry for every fetch cycle.
    val enq = Flipped(Decoupled(new FetchBundle()))
    // Pass to FetchBuffer (newly fetched instructions).
    val enq_idx = Output(UInt(idx_sz.W))
    // ROB tells us the youngest committed ftq_idx to remove from FTQ.
    val deq = Flipped(Valid(UInt(idx_sz.W)))

    // Give PC info to BranchUnit.
    val get_ftq_pc = Vec(2, new GetPCFromFtqIO())


    // Used to regenerate PC for trace port stuff in FireSim
    // Don't tape this out, this blows up the FTQ
    val debug_ftq_idx  = Input(Vec(coreWidth, UInt(log2Ceil(ftqSz).W)))
    val debug_fetch_pc = Output(Vec(coreWidth, UInt(vaddrBitsExtended.W)))

    val redirect = Input(Valid(UInt(idx_sz.W)))

    val brupdate = Input(new BrUpdateInfo)

    val bpdupdate = Output(Valid(new BranchPredictionUpdate))

    val ras_update = Output(Bool())
    val ras_update_idx = Output(UInt(log2Ceil(nRasEntries).W))
    val ras_update_pc  = Output(UInt(vaddrBitsExtended.W))

  })
```

### src/main/scala/exu/decode.scala

```scala
/**
 * Smaller Decode unit for the Frontend to decode different
 * branches.
 * Accepts EXPANDED RVC instructions
  */

class BranchDecodeSignals(implicit p: Parameters) extends BoomBundle
{
  val is_ret   = Bool()
  val is_call  = Bool()
  val target   = UInt(vaddrBitsExtended.W)
  val cfi_type = UInt(CFI_SZ.W)


  // Is this branch a short forwards jump?
  val sfb_offset = Valid(UInt(log2Ceil(icBlockBytes).W))
  // Is this instruction allowed to be inside a sfb?
  val shadowable = Bool()
}

class BranchDecode(implicit p: Parameters) extends BoomModule
{
  val io = IO(new Bundle {
    val inst    = Input(UInt(32.W))
    val pc      = Input(UInt(vaddrBitsExtended.W))

    val out = Output(new BranchDecodeSignals)
  })
```

### src/main/scala/rocket/Breakpoint.scala

```scala
class BPWatch (val n: Int) extends Bundle() {
  val valid = Vec(n, Bool())
  val rvalid = Vec(n, Bool())
  val wvalid = Vec(n, Bool())
  val ivalid = Vec(n, Bool())
  val action = UInt(3.W)
}

class BreakpointUnit(n: Int)(implicit val p: Parameters) extends Module with HasCoreParameters {
  val io = IO(new Bundle {
    val status = Input(new MStatus())
    val bp = Input(Vec(n, new BP))
    val pc = Input(UInt(vaddrBits.W))
    val ea = Input(UInt(vaddrBits.W))
    val mcontext = Input(UInt(coreParams.mcontextWidth.W))
    val scontext = Input(UInt(coreParams.scontextWidth.W))
    val xcpt_if  = Output(Bool())
    val xcpt_ld  = Output(Bool())
    val xcpt_st  = Output(Bool())
    val debug_if = Output(Bool())
    val debug_ld = Output(Bool())
    val debug_st = Output(Bool())
    val bpwatch  = Output(Vec(n, new BPWatch(1)))
  })
```

### src/main/scala/common/consts.scala

```scala
  val BSRC_SZ = 2
  val BSRC_1 = 0.U(BSRC_SZ.W) // 1-cycle branch pred
  val BSRC_2 = 1.U(BSRC_SZ.W) // 2-cycle branch pred
  val BSRC_3 = 2.U(BSRC_SZ.W) // 3-cycle branch pred
  val BSRC_C = 3.U(BSRC_SZ.W) // core branch resolution

  //************************************
  // Control Signals

  // CFI types
  val CFI_SZ   = 3
  val CFI_X    = 0.U(CFI_SZ.W) // Not a CFI instruction
  val CFI_BR   = 1.U(CFI_SZ.W) // Branch
  val CFI_JAL  = 2.U(CFI_SZ.W) // JAL
  val CFI_JALR = 3.U(CFI_SZ.W) // JALR
// ...
  val jal_opc = (0x6f).U
  val jalr_opc = (0x67).U

  def GetUop(inst: UInt): UInt = inst(6,0)
  def GetRd (inst: UInt): UInt = inst(RD_MSB,RD_LSB)
  def GetRs1(inst: UInt): UInt = inst(RS1_MSB,RS1_LSB)

  def ExpandRVC(inst: UInt)(implicit p: Parameters): UInt = {
    val rvc_exp = Module(new RVCExpander)
    rvc_exp.io.in := inst
    Mux(rvc_exp.io.rvc, rvc_exp.io.out.bits, inst)
  }
```

### src/main/scala/util/util.scala

```scala
/**
 * Set all bits at or below the highest order '1'.
 */
object MaskLower
{
  def apply(in: UInt) = {
    val n = in.getWidth
    (0 until n).map(i => in >> i.U).reduce(_|_)
  }
}

/**
 * Set all bits at or above the lowest order '1'.
 */
object MaskUpper
{
  def apply(in: UInt) = {
    val n = in.getWidth
    (0 until n).map(i => (in << i.U)(n-1,0)).reduce(_|_)
  }
}
```

## Related source code

### src/main/scala/exu/core.scala

```scala
  io.ifu.brupdate := brupdate
// ...
  io.ifu.redirect_val         := false.B
  io.ifu.redirect_flush       := false.B

  // Breakpoint info
  io.ifu.status  := csr.io.status
  io.ifu.bp      := csr.io.bp
  io.ifu.mcontext := csr.io.mcontext
  io.ifu.scontext := csr.io.scontext

  io.ifu.flush_icache := (0 until coreWidth).map { i =>
    (rob.io.commit.arch_valids(i) && rob.io.commit.uops(i).is_fencei) ||
    (RegNext(dec_valids(i) && dec_uops(i).is_jalr && csr.io.status.debug))
  }.reduce(_||_)
// ...
  when (RegNext(rob.io.flush.valid)) {
    io.ifu.redirect_val   := true.B
    io.ifu.redirect_flush := true.B
    val flush_typ = RegNext(rob.io.flush.bits.flush_typ)
    // Clear the global history when we flush the ROB (exceptions, AMOs, unique instructions, etc.)
    val new_ghist = WireInit((0.U).asTypeOf(new GlobalHistory))
    new_ghist.current_saw_branch_not_taken := true.B
    new_ghist.ras_idx := io.ifu.get_pc(0).entry.ras_idx
    io.ifu.redirect_ghist := new_ghist
    when (FlushTypes.useCsrEvec(flush_typ)) {
      io.ifu.redirect_pc  := Mux(flush_typ === FlushTypes.eret,
                                 RegNext(RegNext(csr.io.evec)),
                                 csr.io.evec)
    } .otherwise {
      val flush_pc = (AlignPCToBoundary(io.ifu.get_pc(0).pc, icBlockBytes)
                      + RegNext(rob.io.flush.bits.pc_lob)
                      - Mux(RegNext(rob.io.flush.bits.edge_inst), 2.U, 0.U))
      val flush_pc_next = flush_pc + Mux(RegNext(rob.io.flush.bits.is_rvc), 2.U, 4.U)
      io.ifu.redirect_pc := Mux(FlushTypes.useSamePC(flush_typ),
                                flush_pc, flush_pc_next)

    }
    io.ifu.redirect_ftq_idx := RegNext(rob.io.flush.bits.ftq_idx)
  } .elsewhen (brupdate.b2.mispredict && !RegNext(rob.io.flush.valid)) {
    val block_pc = AlignPCToBoundary(io.ifu.get_pc(1).pc, icBlockBytes)
    val uop_maybe_pc = block_pc | brupdate.b2.uop.pc_lob
    val npc = uop_maybe_pc + Mux(brupdate.b2.uop.is_rvc || brupdate.b2.uop.edge_inst, 2.U, 4.U)
    val jal_br_target = Wire(UInt(vaddrBitsExtended.W))
    jal_br_target := (uop_maybe_pc.asSInt + brupdate.b2.target_offset +
      (Fill(vaddrBitsExtended-1, brupdate.b2.uop.edge_inst) << 1).asSInt).asUInt
    val bj_addr = Mux(brupdate.b2.cfi_type === CFI_JALR, brupdate.b2.jalr_target, jal_br_target)
    val mispredict_target = Mux(brupdate.b2.pc_sel === PC_PLUS4, npc, bj_addr)
    io.ifu.redirect_val     := true.B
    io.ifu.redirect_pc      := mispredict_target
    io.ifu.redirect_flush   := true.B
    io.ifu.redirect_ftq_idx := brupdate.b2.uop.ftq_idx
    val use_same_ghist = (brupdate.b2.cfi_type === CFI_BR &&
                          !brupdate.b2.taken &&
                          bankAlign(block_pc) === bankAlign(npc))
    val ftq_entry = io.ifu.get_pc(1).entry
    val cfi_idx = (brupdate.b2.uop.pc_lob ^
      Mux(ftq_entry.start_bank === 1.U, 1.U << log2Ceil(bankBytes), 0.U))(log2Ceil(fetchWidth), 1)
    val ftq_ghist = io.ifu.get_pc(1).ghist
    val next_ghist = ftq_ghist.update(
      ftq_entry.br_mask.asUInt,
      brupdate.b2.taken,
      brupdate.b2.cfi_type === CFI_BR,
      cfi_idx,
      true.B,
      io.ifu.get_pc(1).pc,
      ftq_entry.cfi_is_call && ftq_entry.cfi_idx.bits === cfi_idx,
      ftq_entry.cfi_is_ret  && ftq_entry.cfi_idx.bits === cfi_idx)


    io.ifu.redirect_ghist   := Mux(
      use_same_ghist,
      ftq_ghist,
      next_ghist)
    io.ifu.redirect_ghist.current_saw_branch_not_taken := use_same_ghist
  } .elsewhen (rob.io.flush_frontend || brupdate.b1.mispredict_mask =/= 0.U) {
    io.ifu.redirect_flush   := true.B
  }

  // Tell the FTQ it can deallocate entries by passing youngest ftq_idx.
  val youngest_com_idx = (coreWidth-1).U - PriorityEncoder(rob.io.commit.valids.reverse)
  io.ifu.commit.valid := rob.io.commit.valids.reduce(_|_) || rob.io.com_xcpt.valid
  io.ifu.commit.bits  := Mux(rob.io.com_xcpt.valid,
                             rob.io.com_xcpt.bits.ftq_idx,
                             rob.io.commit.uops(youngest_com_idx).ftq_idx)

  assert(!(rob.io.commit.valids.reduce(_|_) && rob.io.com_xcpt.valid),
    "ROB can't commit and except in same cycle!")

  for (i <- 0 until memWidth) {
    when (RegNext(io.lsu.exe(i).req.bits.sfence.valid)) {
      io.ifu.sfence := RegNext(io.lsu.exe(i).req.bits.sfence)
    }
  }
// ...
  io.ifu.fetchpacket.ready := dec_ready
  val dec_fbundle = io.ifu.fetchpacket.bits
// ...
  io.ifu.get_pc(0).ftq_idx := ftq_arb.io.out.bits
  ftq_arb.io.out.ready  := true.B

  // Branch Unit Requests (for JALs) (Should delay issue of JALs if this not ready)
  jmp_pc_req.valid := RegNext(iss_valids(jmp_unit_idx) && iss_uops(jmp_unit_idx).fu_code === FU_JMP)
  jmp_pc_req.bits  := RegNext(iss_uops(jmp_unit_idx).ftq_idx)

  jmp_unit.io.get_ftq_pc := DontCare
  jmp_unit.io.get_ftq_pc.pc               := io.ifu.get_pc(0).pc
  jmp_unit.io.get_ftq_pc.entry            := io.ifu.get_pc(0).entry
  jmp_unit.io.get_ftq_pc.next_val         := io.ifu.get_pc(0).next_val
  jmp_unit.io.get_ftq_pc.next_pc          := io.ifu.get_pc(0).next_pc


  // Frontend Exception Requests
  val xcpt_idx = PriorityEncoder(dec_xcpts)
  xcpt_pc_req.valid    := dec_xcpts.reduce(_||_)
  xcpt_pc_req.bits     := dec_uops(xcpt_idx).ftq_idx
  //rob.io.xcpt_fetch_pc := RegEnable(io.ifu.get_pc.fetch_pc, dis_ready)
  rob.io.xcpt_fetch_pc := io.ifu.get_pc(0).pc

  flush_pc_req.valid   := rob.io.flush.valid
  flush_pc_req.bits    := rob.io.flush.bits.ftq_idx

  // Mispredict requests (to get the correct target)
  io.ifu.get_pc(1).ftq_idx := oldest_mispredict_ftq_idx
// ...
    for (w <- 0 until coreWidth) {
      // Delay the trace so we have a cycle to pull PCs out of the FTQ
      io.trace(w).valid      := RegNext(rob.io.commit.arch_valids(w))

      // Recalculate the PC
      io.ifu.debug_ftq_idx(w) := rob.io.commit.uops(w).ftq_idx
      val iaddr = (AlignPCToBoundary(io.ifu.debug_fetch_pc(w), icBlockBytes)
                   + RegNext(rob.io.commit.uops(w).pc_lob)
                   - Mux(RegNext(rob.io.commit.uops(w).edge_inst), 2.U, 0.U))(vaddrBits-1,0)
      io.trace(w).iaddr      := Sext(iaddr, xLen)
```

## Documentation

### docs/sections/instruction-fetch-stage.rst

```text
BOOM instantiates its own :term:`Front-end` , similar to how the Rocket core(s)
instantiates its own :term:`Front-end` . This :term:`Front-end` fetches instructions and
makes predictions throughout the Fetch stage to redirect the instruction
stream in multiple fetch cycles (**F0**, **F1**...). If a misprediction is detected in BOOM’s
:term:`Back-end` (execution pipeline), or one of BOOM’s own predictors wants to redirect the pipeline in
a different direction, a request is sent to the :term:`Front-end` and it begins
fetching along a new instruction path. See :ref:`Branch Prediction` for
more information on how branch prediction fits into the Fetch Stage’s pipeline.

Since superscalar fetch is supported, the :term:`Front-end` retrieves a :term:`Fetch Packet`
of instructions from instruction memory and puts them into the
:term:`Fetch Buffer` to give to the rest of the pipeline. The :term:`Fetch Packet` also
contains other meta-data, such as a valid mask (which instructions in the
packet are valid?) and some branch prediction information that is used
later in the pipeline. Additionally, the PC and branch prediction information
is stored inside of the :term:`Fetch Target Queue` which holds this information
for the rest of the pipeline.

The Rocket Core I-Cache
-----------------------

BOOM instantiates the i-cache taken from the Rocket processor source code.
The i-cache is a virtually indexed, physically tagged set-associative cache.

To save power, the i-cache reads out a fixed number of bytes (aligned)
and stores the instruction bits into a register. Further instruction
fetches can be managed by this register. The i-cache is only fired up
again once the fetch register has been exhausted (or a branch prediction
directs the PC elsewhere).

The i-cache does not (currently) support fetching across cache-lines,
nor does it support fetching unaligned relative to the superscalar fetch
address. [1]_

The i-cache does not (currently) support hit-under-miss. If an i-cache
miss occurs, the i-cache will not accept any further requests until the
miss has been handled. This is less than ideal for scenarios in which
the pipeline discovers a branch mispredict and would like to redirect
the i-cache to start fetching along the correct path.

Fetching Compressed Instructions
--------------------------------

This section describes how the `RISC-V Compressed ISA extension <https://riscv.org/specifications/>`__
was implemented in BOOM. The Compressed ISA Extension, or RVC enables smaller, 16
bit encodings of common instructions to decrease the static and dynamic
code size. "RVC" comes with a number of features that are of particular
interest to micro-architects:

-  32b instructions have no alignment requirement, and may start on a
   half-word boundary.

-  All 16b instructions map directly into a longer 32b instruction.

During the :term:`Front-end` stages, BOOM retrieves a :term:`Fetch Packet` from the
i-cache, quickly decodes the instructions for branch
prediction, and pushes the :term:`Fetch Packet` into the :term:`Fetch Buffer`. However,
doing this brings up a particular set of issues to manage:

-  Increased decoding complexity (e.g., operands can now move around).

-  Finding *where* the instruction begins.

-  Removing ``+4`` assumptions throughout the code base,
   particularly with branch handling.

-  Unaligned instructions, in particular, running off cache lines and
   virtual pages.

The last point requires some additional "statefulness" in the :term:`Fetch Unit` ,
as fetching all of the pieces of an instruction may take multiple cycles.

The following describes the implementation of RVC in BOOM by describing
the lifetime of a instruction.

-  The :term:`Front-end` returns :term:`Fetch Packet` s of :term:`fetchWidth<Fetch Width>` \*16 bits wide. This
   was supported inherently in the BOOM :term:`Front-end` .

-  Maintain statefulness in **F3**, in the cycle where :term:`Fetch Packet` s
   are dequeued from the i-cache response queue and enqueued onto the
   :term:`Fetch Buffer` .

-  **F3** tracks the trailing 16b, PC, and instruction boundaries of the
   last :term:`Fetch Packet` . These bits are combined with the current
   :term:`Fetch Packet` and expanded to :term:`fetchWidth<Fetch Width>` \*32 bits for enqueuing onto the
   :term:`Fetch Buffer` . Predecode determines the start address of every
   instruction in this :term:`Fetch Packet` and masks the :term:`Fetch Packet` for the
   :term:`Fetch Buffer` .

-  The :term:`Fetch Buffer` now compacts away invalid, or misaligned instructions
   when storing to its memory.

The following section describes miscellaneous implementation details.

-  A challenging problem is dealing with instructions that cross a
   :term:`Fetch Boundary`. We track these instructions as belonging to the
   :term:`Fetch Packet` that contains their higher-order 16 bits. We have to
   be careful when determining the PC of these instructions, by tracking
   all instructions which were initially misaligned across a :term:`Fetch Boundary` .

-  The pipeline must also track whether an instruction was originally
   16b or 32b, for calculating ``PC+4`` or ``PC+2``.

The Fetch Buffer
----------------

:term:`Fetch Packet` s coming from the i-cache are placed into a :term:`Fetch Buffer` . The :term:`Fetch Buffer` helps to decouple the instruction
fetch :term:`Front-end` from the execution pipeline in the :term:`Back-end` .

The :term:`Fetch Buffer` is parameterizable. The number of entries can be
changed and whether the buffer is implemented as a “flow-through"
queue [2]_ or not can be toggled.

The Fetch Target Queue
----------------------

The :term:`Fetch Target Queue` is a queue that holds the PC
received from the i-cache and the branch prediction info associated
with that address. It holds this information for the pipeline to
reference during the executions of its :term:`Micro-Ops (UOPs)<Micro-Op (UOP)>` . It is dequeued by
the ROB once an instruction is committed and is updated during pipeline
redirection/mispeculation.
```

### docs/sections/branch-prediction/backing-predictor.rst

```text
The :term:`BPD<Backing Predictor (BPD)>` is accessed throughout the **Fetch** stages and in parallel with the instruction cache access and BTB (see
:numref:`front-end-bpu-bpd`). This allows the :term:`BPD<Backing Predictor (BPD)>` to be stored in sequential
memory (i.e., SRAM instead of flip-flops). With some clever
architecting, the :term:`BPD<Backing Predictor (BPD)>` can be stored in single-ported SRAM to achieve the
density desired.

.. _front-end-bpu-bpd:
.. figure:: /figures/front-end.svg
    :alt: BOOM :term:`Front-end`

    The BOOM :term:`Front-end`. Here you can see the BTB and Branch Predictor on the lower portion of the diagram.
    The instructions returning from the instruction cache are quickly decoded; any branches that are predicted as taken
    from the BTB or :term:`Backing Predictor (BPD)` will redirect the :term:`Front-end` from the **F4** stage. Prediction snapshots and metadata
    are stored in the :term:`Branch Rename Snapshots` (for fixing the predictor after mispredictions) and the :term:`Fetch Target Queue (FTQ)`
    (for updating the predictors in the **Commit** stage).

Making Predictions
------------------

When making a prediction, the :term:`BPD<Backing Predictor (BPD)>` must provide the
following:

-   is a prediction being made?

-   a bit-vector of taken/not-taken predictions

As per the first bullet-point, the :term:`BPD<Backing Predictor (BPD)>` may decide to not make a
prediction. This may be because the predictor uses tags to inform
whether its prediction is valid or there may be a structural hazard that
prevented a prediction from being made.

The :term:`BPD<Backing Predictor (BPD)>` provides a bit-vector of taken/not-taken predictions, the size
of the bit-vector matching the :term:`Fetch Width` of the pipeline (one
bit for each instruction in the :term:`Fetch Packet` ). A later **Fetch** stage will
will decode the instructions in the :term:`Fetch Packet` , compute the branch targets, and decide in conjunction with
the :term:`BPD<Backing Predictor (BPD)>` 's prediction bit-vector if a :term:`Front-end` redirect should be made.

Jump and Jump-Register Instructions
-----------------------------------

The :term:`BPD<Backing Predictor (BPD)>` makes predictions only on the direction (taken versus not-taken)
of conditional branches. Non-conditional "jumps" (JAL) and "jump-register"
(JALR) instructions are handled separately from the :term:`BPD<Backing Predictor (BPD)>` . [8]_

The :term:`NLP<Next-Line Predictor (NLP)>` learns any "taken" instruction's PC and target PC -
thus, the :term:`NLP<Next-Line Predictor (NLP)>` is able to predict jumps and jump-register instructions.

If the :term:`NLP<Next-Line Predictor (NLP)>` does not make a prediction on a JAL instruction, the pipeline
will redirect the :term:`Front-end` in **F4** (see :numref:`Front-end`). [9]_

Jump-register instructions that were not predicted by the :term:`NLP<Next-Line Predictor (NLP)>` will be
sent down the pipeline with no prediction made. As JALR instructions require
reading the register file to deduce the jump target, there's nothing
that can be done if the :term:`NLP<Next-Line Predictor (NLP)>` does not make a prediction.

Updating the Backing Predictor
------------------------------

Generally speaking, the :term:`BPD<Backing Predictor (BPD)>` is updated during the **Commit** stage.
This prevents the :term:`BPD<Backing Predictor (BPD)>` from being polluted by wrong-path
information. [10]_ However, as the :term:`BPD<Backing Predictor (BPD)>` makes use of global history, this
history must be reset whenever the :term:`Front-end` is redirected. Thus, the
:term:`BPD<Backing Predictor (BPD)>` must also be (partially) updated during **Execute** when a
misprediction occurs to reset any speculative updates that had occurred
during the **Fetch** stages.

When making a prediction, the :term:`BPD<Backing Predictor (BPD)>` passes to the pipeline a "response
info packet". This "info packet" is stored in the :term:`Fetch Target Queue (FTQ)`
until commit time. [11]_ Once all of the instructions
corresponding to the "info packet" is committed, the "info packet" is
set to the :term:`BPD<Backing Predictor (BPD)>` (along with the eventual outcome of the branches) and the
:term:`BPD<Backing Predictor (BPD)>` is updated. :ref:`The Fetch Target Queue (FTQ) for Predictions` covers the :term:`FTQ<Fetch Target Queue (FTQ)>` , which handles the
snapshot information needed for update the predictor during
**Commit**. :ref:`Rename Snapshot State` covers the :term:`Branch Rename Snapshots` ,
which handles the snapshot information needed to update the
predictor during a misspeculation in the **Execute** stage.

Managing the Global History Register (GHR)
------------------------------------------

The :term:`Global History Register (GHR)` is an important piece of a branch
predictor. It contains the outcomes of the previous ``N`` branches (where
N is the size of the :term:`GHR<Global History Register (GHR)>` ). [12]_

When fetching branch ``i``, it is important that the direction of the
previous ``i-N`` branches is available so an accurate prediction can be
made. Waiting until the **Commit** stage to update the :term:`GHR<Global History Register (GHR)>`
would be too late (dozens of branches would be inflight and not
reflected!). Therefore, the :term:`GHR<Global History Register (GHR)>` must be updated
*speculatively*, once the branch is fetched and predicted.

If a misprediction occurs, the :term:`GHR<Global History Register (GHR)>` must be reset and
updated to reflect the actual history. This means that each branch (more
accurately, each :term:`Fetch Packet` ) must snapshot the :term:`GHR<Global History Register (GHR)>` in case of a misprediction. [13]_

There is one final wrinkle - exceptional pipeline behavior. While each
branch contains a snapshot of the :term:`GHR<Global History Register (GHR)>` , any
instruction can potential throw an exception that will cause a :term:`Front-end`
redirect. Such an event will cause the :term:`GHR<Global History Register (GHR)>` to become
corrupted. For exceptions, this may seem acceptable - exceptions should
be rare and the trap handlers will cause a pollution of the :term:`GHR<Global History Register (GHR)>`
anyways (from the point of view of the user code).
However, some exceptional events include "pipeline replays" - events
where an instruction causes a pipeline flush and the instruction is
refetched and re-executed. [14]_ For this reason, a *commit copy* of
the :term:`GHR<Global History Register (GHR)>` is also maintained by the :term:`BPD<Backing Predictor (BPD)>` and reset on
any sort of pipeline flush event.
```

### docs/sections/branch-prediction/nl-predictor.rst

```text
BOOM core's :term:`Front-end` fetches
instructions and predicts every cycle where to fetch the next
instructions. If a misprediction is detected in BOOM's :term:`Back-end`, or
BOOM’s own :term:`Backing Predictor (BPD)` wants to redirect the pipeline in a
different direction, a request is sent to the :term:`Front-end` and it begins
fetching along a new instruction path.

The :term:`Next-Line Predictor (NLP)` takes in the current PC being used to
fetch instructions (the :term:`Fetch PC`) and predicts combinationally
where the next instructions should be fetched for the next cycle. If
predicted correctly, there are no pipeline bubbles.

The :term:`NLP<Next-Line Predictor (NLP)>` is an amalgamation of a fully-associative **Branch
Target Buffer (BTB)**, :term:`Bi-Modal Table (BIM)` and a **Return Address Stack (RAS)** which work together
to make a fast, but reasonably accurate prediction.

NLP Predictions
---------------

The :term:`Fetch PC` first performs a tag match to find a uniquely
matching BTB entry. If a hit occurs, the BTB entry will make a
prediction in concert with the RAS as to whether there is a
branch, jump, or return found in the :term:`Fetch Packet` and which
instruction in the :term:`Fetch Packet` is to blame. The :term:`BIM<Bi-Modal Table (BIM)>` is used to
determine if that prediction made was a branch taken or not taken.
The BTB entry also contains a predicted PC target, which is used
as the :term:`Fetch PC` on the next cycle.

.. _nlp-predictor-unit:
.. figure:: /figures/btb.png
    :scale: 35 %
    :align: center
    :alt: The :term:`Next-Line Predictor`

    The :term:`Next-Line Predictor (NLP)` Unit. The :term:`Fetch PC` scans the BTB’s "PC tags" for a match.
    If a match is found (and the entry is valid), the :term:`Bi-Modal Table (BIM)` and RAS are consulted for the final verdict. If the entry
    is a "ret" (return instruction), then the target comes from the RAS. If the entry is a unconditional "jmp"
    (jump instruction), then the :term:`BIM<Bi-Modal Table (BIM)>` is not consulted. The "bidx", or branch index, marks which instruction
    in a superscalar :term:`Fetch Packet` is the cause of the control flow prediction. This is necessary to mask off the
    other instructions in the :term:`Fetch Packet` that come over the taken branch

The hysteresis bits in the :term:`BIM<Bi-Modal Table (BIM)>` are only used
on a BTB entry *hit* and if the predicting instruction is a branch.

If the BTB entry contains a *return* instruction, the RAS stack is
used to provide the predicted return PC as the next :term:`Fetch PC`. The
actual RAS management (of when to or the stack) is governed externally.
...
NLP Updates
-----------

Each branch passed down the pipeline remembers not only its own PC, but
also its :term:`Fetch PC` (the PC of the head instruction of its :term:`Fetch Packet` ). [2]_

BTB Updates
^^^^^^^^^^^

The BTB is updated *only* when the :term:`Front-end` is redirected to
*take* a branch or jump by either the :term:`Branch Unit` (in the
Execute stage) or the :term:`BPD<Backing Predictor (BPD)>` (later in the **Fetch** stages). [3]_

If there is no BTB entry corresponding to the taken branch or jump, an
new entry is allocated for it.

RAS Updates
^^^^^^^^^^^

The RAS is updated during the Fetch stages once the
instructions in the :term:`Fetch Packet` have been decoded. If the taken
instruction is a call [4]_ , the return address is pushed onto the RAS. If
the taken instruction is a return, then the RAS is popped.

Superscalar Predictions
^^^^^^^^^^^^^^^^^^^^^^^

When the :term:`NLP<Next-Line Predictor (NLP)>` makes a prediction, it is actually using the BTB to tag
match against the predicted branch’s :term:`Fetch PC`, and not the PC of
the branch itself. The :term:`NLP<Next-Line Predictor (NLP)>` must predict across the entire :term:`Fetch Packet`
which of the many possible branches will be the dominating
branch that redirects the PC. For this reason, we use a given branch’s
:term:`Fetch PC` rather than its own PC in the BTB tag match. [5]_
```
