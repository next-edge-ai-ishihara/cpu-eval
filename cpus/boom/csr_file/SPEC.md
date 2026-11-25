# Implement `CSRFile`

Implement one complete `CSRFile` Chisel definition. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class CSRFile` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### generators/chipyard/src/main/scala/config/BoomConfigs.scala

```scala
class LargeBoomConfig extends Config(
  new boom.common.WithNLargeBooms(1) ++                          // large boom config
  new chipyard.config.AbstractConfig)
```

### src/main/scala/subsystem/Configs.scala

```scala
class BaseSubsystemConfig extends Config ((site, here, up) => {
  // Tile parameters
  case PgLevels => if (site(XLen) == 64) 3 /* Sv39 */ else 2 /* Sv32 */
  case XLen => 64 // Applies to all cores
```

### src/main/scala/common/parameters.scala

```scala
  nPerfCounters: Int = 0,
  // ...
  nPMPs: Int = 8,
  // ...
  useCompressed: Boolean = true,
  // ...
  haveBasicCounters: Boolean = true,
  misaWritable: Boolean = false,
  mtvecInit: Option[BigInt] = Some(BigInt(0)),
  mtvecWritable: Boolean = true,
  haveCFlush: Boolean = false,
  mulDiv: Option[freechips.rocketchip.rocket.MulDivParams] = Some(MulDivParams(divEarlyOut=true)),
  nBreakpoints: Int = 0, // TODO Fix with better frontend breakpoint unit
  // ...
  nLocalInterrupts: Int = 0,
  useNMI: Boolean = false,
  useAtomics: Boolean = true,
  useDebug: Boolean = true,
  useUser: Boolean = true,
  useSupervisor: Boolean = false,
  useHypervisor: Boolean = false,
  useVM: Boolean = true,
  // ...
  clockGate: Boolean = false,
  mcontextWidth: Int = 0,
  scontextWidth: Int = 0,
  // ...
  val haveFSDirty = true
  val pmpGranularity: Int = 4
  // ...
  val retireWidth = decodeWidth
  // ...
  override def customCSRs(implicit p: Parameters) = new BoomCustomCSRs
// ...
/**
  * Defines custom BOOM CSRs
  */
class BoomCustomCSRs(implicit p: Parameters) extends freechips.rocketchip.tile.CustomCSRs
  with HasBoomCoreParameters {
  override def chickenCSR = {
    val params = tileParams.core.asInstanceOf[BoomCoreParams]
    val mask = BigInt(
      tileParams.dcache.get.clockGate.toInt << 0 |
      params.clockGate.toInt << 1 |
      params.clockGate.toInt << 2 |
      1 << 3 // Disable OOO when this bit is high
    )
    val init = BigInt(
      tileParams.dcache.get.clockGate.toInt << 0 |
      params.clockGate.toInt << 1 |
      params.clockGate.toInt << 2 |
      0 << 3 // Enable OOO at init
    )
    Some(CustomCSR(chickenCSRId, mask, Some(init)))
  }
  def disableOOO = getOrElse(chickenCSR, _.value(3), true.B)
}
```

### src/main/scala/common/config-mixins.scala

```scala
              decodeWidth = 3,
              // ...
              fpu = Some(freechips.rocketchip.tile.FPUParams(sfmaLatency=4, dfmaLatency=4, divSqrt=true))
```

### src/main/scala/rocket/TLB.scala

```scala
case object PgLevels extends Field[Int](2)
case object ASIdBits extends Field[Int](0)
case object VMIdBits extends Field[Int](0)
```

### src/main/scala/devices/debug/Debug.scala

```scala
case class DebugModuleParams (
  baseAddress : BigInt = BigInt(0),
  nDMIAddrSize  : Int = 7,
  nProgramBufferWords: Int = 16,
  nAbstractDataWords : Int = 4,
  nScratch : Int = 1,
  hasBusMaster : Boolean = false,
  clockGate : Boolean = true,
  maxSupportedSBAccess : Int = 32,
  supportQuickAccess : Boolean = false,
  supportHartArray   : Boolean = true,
  nHaltGroups        : Int = 1,
  nExtTriggers       : Int = 0,
  hasHartResets      : Boolean = false,
  hasImplicitEbreak  : Boolean = false,
  hasAuthentication  : Boolean = false,
  crossingHasSafeReset : Boolean = true
) {
  // ...
  def address = AddressSet(baseAddress, 0xFFF)
  def atzero = (baseAddress == 0)
  def nAbstractInstructions = if (atzero) 2 else 5
  def debugEntry: BigInt = baseAddress + 0x800
  def debugException: BigInt = baseAddress + 0x808
  def nDscratch: Int = if (atzero) 1 else 2
}
// ...
case object DebugModuleKey extends Field[Option[DebugModuleParams]](Some(DebugModuleParams()))
```

### src/main/scala/tile/LazyRoCC.scala

```scala
case object BuildRoCC extends Field[Seq[Parameters => LazyRoCC]](Nil)
```

### src/main/scala/common/tile.scala

```scala
  val beuAddr: Option[BigInt] = None
```

## Package and imports

```scala
package freechips.rocketchip.rocket

import Chisel._
import Chisel.ImplicitConversions._
import chisel3.{DontCare, WireInit, withClock}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.devices.debug.DebugModuleKey
import freechips.rocketchip.tile._
import freechips.rocketchip.util._
import freechips.rocketchip.util.property
import scala.collection.mutable.LinkedHashMap
import Instructions._
```

## Class declaration

```scala
class CSRFile(
  perfEventSets: EventSets = new EventSets(Seq()),
  customCSRs: Seq[CustomCSR] = Nil)(implicit p: Parameters)
    extends CoreModule()(p)
    with HasCoreParameters {
  val io = new CSRFileIO {
    val customCSRs = Vec(CSRFile.this.customCSRs.size, new CustomCSRIO).asOutput
  }
```

## Parent instantiation

### src/main/scala/exu/core.scala

```scala
  val csr = Module(new freechips.rocketchip.rocket.CSRFile(perfEvents, boomParams.customCSRs.decls))
  csr.io.inst foreach { c => c := DontCare }
  csr.io.rocc_interrupt := io.rocc.interrupt

  val custom_csrs = Wire(new BoomCustomCSRs)
  (custom_csrs.csrs zip csr.io.customCSRs).map { case (lhs, rhs) => lhs := rhs }

  //val icache_blocked = !(io.ifu.fetchpacket.valid || RegNext(io.ifu.fetchpacket.valid))
  val icache_blocked = false.B
  csr.io.counters foreach { c => c.inc := RegNext(perfEvents.evaluate(c.eventSel)) }
  // ...
  //-------------------------------------------------------------
  // Privileged Co-processor 0 Register File
  // Note: Normally this would be bad in that I'm writing state before
  // committing, so to get this to work I stall the entire pipeline for
  // CSR instructions so I never speculate these instructions.

  val csr_exe_unit = exe_units.csr_unit

  // for critical path reasons, we aren't zero'ing this out if resp is not valid
  val csr_rw_cmd = csr_exe_unit.io.iresp.bits.uop.ctrl.csr_cmd
  val wb_wdata = csr_exe_unit.io.iresp.bits.data

  csr.io.rw.addr        := csr_exe_unit.io.iresp.bits.uop.csr_addr
  csr.io.rw.cmd         := freechips.rocketchip.rocket.CSR.maskCmd(csr_exe_unit.io.iresp.valid, csr_rw_cmd)
  csr.io.rw.wdata       := wb_wdata

  // Extra I/O
  // Delay retire/exception 1 cycle
  csr.io.retire    := RegNext(PopCount(rob.io.commit.arch_valids.asUInt))
  csr.io.exception := RegNext(rob.io.com_xcpt.valid)
  // csr.io.pc used for setting EPC during exception or CSR.io.trace.

  csr.io.pc        := (boom.util.AlignPCToBoundary(io.ifu.get_pc(0).com_pc, icBlockBytes)
                     + RegNext(rob.io.com_xcpt.bits.pc_lob)
                     - Mux(RegNext(rob.io.com_xcpt.bits.edge_inst), 2.U, 0.U))
  // Cause not valid for for CALL or BREAKPOINTs (CSRFile will override it).
  csr.io.cause     := RegNext(rob.io.com_xcpt.bits.cause)
  csr.io.ungated_clock := clock
  // ...
  val tval_valid = csr.io.exception &&
    csr.io.cause.isOneOf(
      //Causes.illegal_instruction.U, we currently only write 0x0 for illegal instructions
      Causes.breakpoint.U,
      Causes.misaligned_load.U,
      Causes.misaligned_store.U,
      Causes.load_access.U,
      Causes.store_access.U,
      Causes.fetch_access.U,
      Causes.load_page_fault.U,
      Causes.store_page_fault.U,
      Causes.fetch_page_fault.U)

  csr.io.tval := Mux(tval_valid,
    RegNext(encodeVirtualAddress(rob.io.com_xcpt.bits.badvaddr, rob.io.com_xcpt.bits.badvaddr)), 0.U)
  // ...
  csr.io.fcsr_flags.valid := rob.io.commit.fflags.valid
  csr.io.fcsr_flags.bits  := rob.io.commit.fflags.bits
  csr.io.set_fs_dirty.get := rob.io.commit.fflags.valid

  exe_units.withFilter(_.hasFcsr).map(_.io.fcsr_rm := csr.io.fcsr_rm)
  io.fcsr_rm := csr.io.fcsr_rm

  if (usingFPU) {
    fp_pipeline.io.fcsr_rm := csr.io.fcsr_rm
  }

  csr.io.hartid := io.hartid
  csr.io.interrupts := io.interrupts

  // we do not support the H-extension
  csr.io.htval := DontCare
  csr.io.gva := DontCare
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/tile/Core.scala

```scala
  val useVM: Boolean
  val useHypervisor: Boolean
  val useUser: Boolean
  val useSupervisor: Boolean
  val useDebug: Boolean
  val useAtomics: Boolean
  // ...
  val useCompressed: Boolean
  val useBitManip: Boolean = false
  val useVector: Boolean = false
  // ...
  val useRVE: Boolean
  val mulDiv: Option[MulDivParams]
  val fpu: Option[FPUParams]
  // ...
  val decodeWidth: Int
  val retireWidth: Int
  val instBits: Int
  val nLocalInterrupts: Int
  val useNMI: Boolean
  val nPMPs: Int
  val pmpGranularity: Int
  val nBreakpoints: Int
  // ...
  val mcontextWidth: Int
  val scontextWidth: Int
  val nPerfCounters: Int
  val haveBasicCounters: Boolean
  val haveFSDirty: Boolean
  val misaWritable: Boolean
  val haveCFlush: Boolean
  // ...
  val mtvecInit: Option[BigInt]
  val mtvecWritable: Boolean
  def customCSRs(implicit p: Parameters): CustomCSRs = new CustomCSRs

  def hasSupervisorMode: Boolean = useSupervisor || useVM
// ...
trait HasCoreParameters extends HasTileParameters {
  val coreParams: CoreParams = tileParams.core

  val minFLen = coreParams.fpu.map(_ => coreParams.minFLen).getOrElse(0)
  val fLen = coreParams.fpu.map(_.fLen).getOrElse(0)

  val usingMulDiv = coreParams.mulDiv.nonEmpty
  val usingFPU = coreParams.fpu.nonEmpty
  val usingAtomics = coreParams.useAtomics
  // ...
  val usingCompressed = coreParams.useCompressed
  val usingBitManip = coreParams.useBitManip
  val usingVector = coreParams.useVector
  // ...
  val usingNMI = coreParams.useNMI

  val retireWidth = coreParams.retireWidth
  // ...
  val decodeWidth = coreParams.decodeWidth
  // ...
  def coreMaxAddrBits = paddrBits max vaddrBitsExtended

  val nBreakpoints = coreParams.nBreakpoints
  val nPMPs = coreParams.nPMPs
  val pmpGranularity = coreParams.pmpGranularity
  val nPerfCounters = coreParams.nPerfCounters
  val mtvecInit = coreParams.mtvecInit
  val mtvecWritable = coreParams.mtvecWritable
  // ...
  // Print out log of committed instructions and their writeback values.
  // Requires post-processing due to out-of-order writebacks.
  val enableCommitLog = false
// ...
abstract class CoreModule(implicit val p: Parameters) extends Module
  with HasCoreParameters

abstract class CoreBundle(implicit val p: Parameters) extends ParameterizedBundle()(p)
  with HasCoreParameters

class CoreInterrupts(implicit p: Parameters) extends TileInterrupts()(p) {
  val buserror = tileParams.beuAddr.map(a => Bool())
}
```

### src/main/scala/tile/CustomCSRs.scala

```scala
case class CustomCSR(id: Int, mask: BigInt, init: Option[BigInt])

object CustomCSR {
  def constant(id: Int, value: BigInt): CustomCSR = CustomCSR(id, BigInt(0), Some(value))
}

class CustomCSRIO(implicit p: Parameters) extends CoreBundle {
  val wen = Bool()
  val wdata = UInt(xLen.W)
  val value = UInt(xLen.W)
}
// ...
class CustomCSRs(implicit p: Parameters) extends CoreBundle {
  // Not all cores have these CSRs, but those that do should follow the same
  // numbering conventions.  So we list them here but default them to None.
  protected def bpmCSRId = 0x7c0
  protected def bpmCSR: Option[CustomCSR] = None

  protected def chickenCSRId = 0x7c1
  protected def chickenCSR: Option[CustomCSR] = None

  // If you override this, you'll want to concatenate super.decls
  def decls: Seq[CustomCSR] = bpmCSR.toSeq ++ chickenCSR

  val csrs = Vec(decls.size, new CustomCSRIO)
  // ...
  protected def getByIdOrElse[T](id: Int, f: CustomCSRIO => T, alt: T): T = {
    val idx = decls.indexWhere(_.id == id)
    if (idx < 0) alt else f(csrs(idx))
  }

  protected def getOrElse[T](csr: Option[CustomCSR], f: CustomCSRIO => T, alt: T): T =
    csr.map(c => getByIdOrElse(c.id, f, alt)).getOrElse(alt)
}
```

### src/main/scala/tile/BaseTile.scala

```scala
trait HasNonDiplomaticTileParameters {
  implicit val p: Parameters
  def tileParams: TileParams = p(TileKey)

  def usingVM: Boolean = tileParams.core.useVM
  def usingUser: Boolean = tileParams.core.useUser || usingSupervisor
  def usingSupervisor: Boolean = tileParams.core.hasSupervisorMode
  def usingHypervisor: Boolean = usingVM && tileParams.core.useHypervisor
  def usingDebug: Boolean = tileParams.core.useDebug
  def usingRoCC: Boolean = !p(BuildRoCC).isEmpty
  // ...
  def xLen: Int = p(XLen)
  // ...
  def pgIdxBits: Int = 12
  def pgLevelBits: Int = 10 - log2Ceil(xLen / 32)
  def pgLevels: Int = p(PgLevels)
  def maxSVAddrBits: Int = pgIdxBits + pgLevels * pgLevelBits
  // ...
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
// ...
class HStatus extends Bundle {
  val zero6 = UInt(width = 30)
  val vsxl = UInt(width = 2)
  val zero5 = UInt(width = 9)
  val vtsr = Bool()
  val vtw = Bool()
  val vtvm = Bool()
  val zero3 = UInt(width = 2)
  val vgein = UInt(width = 6)
  val zero2 = UInt(width = 2)
  val hu = Bool()
  val spvp = Bool()
  val spv = Bool()
  val gva = Bool()
  val vsbe = Bool()
  val zero1 = UInt(width = 5)
}
// ...
class DCSR extends Bundle {
  val xdebugver = UInt(width = 2)
  val zero4 = UInt(width=2)
  val zero3 = UInt(width = 12)
  val ebreakm = Bool()
  val ebreakh = Bool()
  val ebreaks = Bool()
  val ebreaku = Bool()
  val zero2 = Bool()
  val stopcycle = Bool()
  val stoptime = Bool()
  val cause = UInt(width = 3)
  val v = Bool()
  val zero1 = UInt(width = 2)
  val step = Bool()
  val prv = UInt(width = PRV.SZ)
}
// ...
class MIP(implicit p: Parameters) extends CoreBundle()(p)
    with HasCoreParameters {
  val lip = Vec(coreParams.nLocalInterrupts, Bool())
  val zero1 = Bool()
  val debug = Bool() // keep in sync with CSR.debugIntCause
  val rocc = Bool()
  val sgeip = Bool()
  val meip = Bool()
  val vseip = Bool()
  val seip = Bool()
  val ueip = Bool()
  val mtip = Bool()
  val vstip = Bool()
  val stip = Bool()
  val utip = Bool()
  val msip = Bool()
  val vssip = Bool()
  val ssip = Bool()
  val usip = Bool()
}

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

object CSR
{
  // commands
  val SZ = 3
  def X = BitPat.dontCare(SZ)
  def N = UInt(0,SZ)
  def R = UInt(2,SZ)
  def I = UInt(4,SZ)
  def W = UInt(5,SZ)
  def S = UInt(6,SZ)
  def C = UInt(7,SZ)

  // mask a CSR cmd with a valid bit
  def maskCmd(valid: Bool, cmd: UInt): UInt = {
    // all commands less than CSR.I are treated by CSRFile as NOPs
    cmd & ~Mux(valid, 0.U, CSR.I)
  }

  val ADDRSZ = 12

  def modeLSB: Int = 8
  def mode(addr: Int): Int = (addr >> modeLSB) % (1 << PRV.SZ)
  def mode(addr: UInt): UInt = addr(modeLSB + PRV.SZ - 1, modeLSB)

  def busErrorIntCause = 128
  def debugIntCause = 14 // keep in sync with MIP.debug
  def debugTriggerCause = {
    val res = debugIntCause
    require(!(Causes.all contains res))
    res
  }
  def rnmiIntCause = 13  // NMI: Higher numbers = higher priority, must not reuse debugIntCause
  def rnmiBEUCause = 12

  val firstCtr = CSRs.cycle
  val firstCtrH = CSRs.cycleh
  val firstHPC = CSRs.hpmcounter3
  val firstHPCH = CSRs.hpmcounter3h
  val firstHPE = CSRs.mhpmevent3
  val firstMHPC = CSRs.mhpmcounter3
  val firstMHPCH = CSRs.mhpmcounter3h
  val firstHPM = 3
  val nCtr = 32
  val nHPM = nCtr - firstHPM
  val hpmWidth = 40

  val maxPMPs = 16
}
// ...
class PerfCounterIO(implicit p: Parameters) extends CoreBundle
    with HasCoreParameters {
  val eventSel = UInt(OUTPUT, xLen)
  val inc = UInt(INPUT, log2Ceil(1+retireWidth))
}

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

class TraceAux extends Bundle {
  val enable = Bool()
  val stall = Bool()
}

class CSRDecodeIO(implicit p: Parameters) extends CoreBundle {
  val inst = Input(UInt(iLen.W))

  def csr_addr = (inst >> 20)(CSR.ADDRSZ-1, 0)

  val fp_illegal = Bool(OUTPUT)
  val vector_illegal = Bool(OUTPUT)
  val fp_csr = Bool(OUTPUT)
  val rocc_illegal = Bool(OUTPUT)
  val read_illegal = Bool(OUTPUT)
  val write_illegal = Bool(OUTPUT)
  val write_flush = Bool(OUTPUT)
  val system_illegal = Bool(OUTPUT)
  val virtual_access_illegal = Bool(OUTPUT)
  val virtual_system_illegal = Bool(OUTPUT)
}

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

### src/main/scala/rocket/PMP.scala

```scala
class PMPConfig extends Bundle {
  val l = Bool()
  val res = UInt(2.W)
  val a = UInt(2.W)
  val x = Bool()
  val w = Bool()
  val r = Bool()
}

object PMP {
  def lgAlign = 2

  def apply(reg: PMPReg): PMP = {
    val pmp = Wire(new PMP()(reg.p))
    pmp.cfg := reg.cfg
    pmp.addr := reg.addr
    pmp.mask := pmp.computeMask
    pmp
  }
}

class PMPReg(implicit p: Parameters) extends CoreBundle()(p) {
  val cfg = new PMPConfig
  val addr = UInt((paddrBits - PMP.lgAlign).W)

  def reset(): Unit = {
    cfg.a := 0
    cfg.l := 0
  }

  def readAddr = if (pmpGranularity.log2 == PMP.lgAlign) addr else {
    val mask = ((BigInt(1) << (pmpGranularity.log2 - PMP.lgAlign)) - 1).U
    Mux(napot, addr | (mask >> 1), ~(~addr | mask))
  }
  def napot = cfg.a(1)
  def torNotNAPOT = cfg.a(0)
  def tor = !napot && torNotNAPOT
  def cfgLocked = cfg.l
  def addrLocked(next: PMPReg) = cfgLocked || next.cfgLocked && next.tor
}
```

### src/main/scala/tile/FPU.scala

```scala
case class FPUParams(
  minFLen: Int = 32,
  fLen: Int = 64,
  divSqrt: Boolean = true,
  sfmaLatency: Int = 3,
  dfmaLatency: Int = 4
)

object FPConstants
{
  val RM_SZ = 3
  val FLAGS_SZ = 5
}
```

### src/main/scala/rocket/Instructions.scala

```scala
  def ECALL              = BitPat("b00000000000000000000000001110011")
  def EBREAK             = BitPat("b00000000000100000000000001110011")
  // ...
  def SRET               = BitPat("b00010000001000000000000001110011")
  def MRET               = BitPat("b00110000001000000000000001110011")
  // ...
  def DRET               = BitPat("b01111011001000000000000001110011")
  def SFENCE_VMA         = BitPat("b0001001??????????000000001110011")
  def WFI                = BitPat("b00010000010100000000000001110011")
  def CEASE              = BitPat("b00110000010100000000000001110011")
  // ...
  def CSRRW              = BitPat("b?????????????????001?????1110011")
  def CSRRS              = BitPat("b?????????????????010?????1110011")
  def CSRRC              = BitPat("b?????????????????011?????1110011")
  def CSRRWI             = BitPat("b?????????????????101?????1110011")
  def CSRRSI             = BitPat("b?????????????????110?????1110011")
  def CSRRCI             = BitPat("b?????????????????111?????1110011")
// ...
object Causes {
  val misaligned_fetch = 0x0
  val fetch_access = 0x1
  val illegal_instruction = 0x2
  val breakpoint = 0x3
  val misaligned_load = 0x4
  val load_access = 0x5
  val misaligned_store = 0x6
  val store_access = 0x7
  val user_ecall = 0x8
  val supervisor_ecall = 0x9
  val virtual_supervisor_ecall = 0xa
  val machine_ecall = 0xb
  val fetch_page_fault = 0xc
  val load_page_fault = 0xd
  val store_page_fault = 0xf
  val fetch_guest_page_fault = 0x14
  val load_guest_page_fault = 0x15
  val virtual_instruction = 0x16
  val store_guest_page_fault = 0x17
  val all = {
    val res = collection.mutable.ArrayBuffer[Int]()
    res += misaligned_fetch
    res += fetch_access
    res += illegal_instruction
    res += breakpoint
    res += misaligned_load
    res += load_access
    res += misaligned_store
    res += store_access
    res += user_ecall
    res += supervisor_ecall
    res += virtual_supervisor_ecall
    res += machine_ecall
    res += fetch_page_fault
    res += load_page_fault
    res += store_page_fault
    res += fetch_guest_page_fault
    res += load_guest_page_fault
    res += virtual_instruction
    res += store_guest_page_fault
    res.toArray
  }
}
object CSRs {
  val fflags = 0x1
  val frm = 0x2
  val fcsr = 0x3
  val ustatus = 0x0
  val uie = 0x4
  val utvec = 0x5
  val vstart = 0x8
  val vxsat = 0x9
  val vxrm = 0xa
  val vcsr = 0xf
  val uscratch = 0x40
  val uepc = 0x41
  val ucause = 0x42
  val utval = 0x43
  val uip = 0x44
  val cycle = 0xc00
  val time = 0xc01
  val instret = 0xc02
  // ...
  val sstatus = 0x100
  val sie = 0x104
  val stvec = 0x105
  val scounteren = 0x106
  val sscratch = 0x140
  val sepc = 0x141
  val scause = 0x142
  val stval = 0x143
  val sip = 0x144
  val satp = 0x180
  // ...
  val mstatus = 0x300
  val misa = 0x301
  val medeleg = 0x302
  val mideleg = 0x303
  val mie = 0x304
  val mtvec = 0x305
  val mcounteren = 0x306
  val mscratch = 0x340
  val mepc = 0x341
  val mcause = 0x342
  val mtval = 0x343
  val mip = 0x344
  val mnscratch = 0x350
  val mnepc = 0x351
  val mncause = 0x352
  val mnstatus = 0x353
  val mtinst = 0x34a
  val mtval2 = 0x34b
  val pmpcfg0 = 0x3a0
  val pmpcfg1 = 0x3a1
  val pmpcfg2 = 0x3a2
  val pmpcfg3 = 0x3a3
  val pmpaddr0 = 0x3b0
  val pmpaddr1 = 0x3b1
  val pmpaddr2 = 0x3b2
  val pmpaddr3 = 0x3b3
  val pmpaddr4 = 0x3b4
  val pmpaddr5 = 0x3b5
  val pmpaddr6 = 0x3b6
  val pmpaddr7 = 0x3b7
  // ...
  val tselect = 0x7a0
  val tdata1 = 0x7a1
  val tdata2 = 0x7a2
  val tdata3 = 0x7a3
  val scontext = 0x5a8
  val hcontext = 0x6a8
  val mcontext = 0x7a8
  val dcsr = 0x7b0
  val dpc = 0x7b1
  val dscratch = 0x7b2
  val dscratch1 = 0x7b3
  val mcycle = 0xb00
  val minstret = 0xb02
  // ...
  val mcountinhibit = 0x320
  // ...
  val mvendorid = 0xf11
  val marchid = 0xf12
  val mimpid = 0xf13
  val mhartid = 0xf14
```

## Related source code

### src/main/scala/exu/core.scala

```scala
  // Breakpoint info
  io.ifu.status  := csr.io.status
  io.ifu.bp      := csr.io.bp
  io.ifu.mcontext := csr.io.mcontext
  io.ifu.scontext := csr.io.scontext
  // ...
  //       ERETs are reported to the CSR two cycles before we send the flush
  //       Exceptions are reported to the CSR on the cycle we send the flush
  // This discrepency should be resolved elsewhere.
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
  // ...
  for (w <- 0 until coreWidth) {
    dec_valids(w)                      := io.ifu.fetchpacket.valid && dec_fbundle.uops(w).valid &&
                                          !dec_finished_mask(w)
    decode_units(w).io.enq.uop         := dec_fbundle.uops(w).bits
    decode_units(w).io.status          := csr.io.status
    decode_units(w).io.csr_decode      <> csr.io.decode(w)
    decode_units(w).io.interrupt       := csr.io.interrupt
    decode_units(w).io.interrupt_cause := csr.io.interrupt_cause
  // ...
  val dis_prior_slot_valid = dis_valids.scanLeft(false.B) ((s,v) => s || v)
  val dis_prior_slot_unique = (dis_uops zip dis_valids).scanLeft(false.B) {case (s,(u,v)) => s || v && u.is_unique}
  val wait_for_empty_pipeline = (0 until coreWidth).map(w => (dis_uops(w).is_unique || custom_csrs.disableOOO) &&
                                  (!rob.io.empty || !io.lsu.fencei_rdy || dis_prior_slot_valid(w)))
  // ...
  rob.io.enq_valids := dis_fire
  rob.io.enq_uops   := dis_uops
  rob.io.enq_partial_stall := dis_stalls.last // TODO come up with better ROB compacting scheme.
  rob.io.debug_tsc := debug_tsc_reg
  rob.io.csr_stall := csr.io.csr_stall
      // ...
      def wbIsValid(rtype: UInt) =
        wbresp.valid && wbresp.bits.uop.rf_wen && wbresp.bits.uop.dst_rtype === rtype
      val wbReadsCSR = wbresp.bits.uop.ctrl.csr_cmd =/= freechips.rocketchip.rocket.CSR.N

      iregfile.io.write_ports(w_cnt).valid     := wbIsValid(RT_FIX)
      iregfile.io.write_ports(w_cnt).bits.addr := wbpdst
      wbresp.ready := true.B
      if (exe_units(i).hasCSR) {
        iregfile.io.write_ports(w_cnt).bits.data := Mux(wbReadsCSR, csr.io.rw.rdata, wbdata)
      } else {
        iregfile.io.write_ports(w_cnt).bits.data := wbdata
  // ...
  exe_units.map(u => u.io.status := csr.io.status)
  if (usingFPU)
    fp_pipeline.io.status := csr.io.status

  // Connect breakpoint info to memaddrcalcunit
  for (i <- 0 until memWidth) {
    mem_units(i).io.status   := csr.io.status
    mem_units(i).io.bp       := csr.io.bp
    mem_units(i).io.mcontext := csr.io.mcontext
    mem_units(i).io.scontext := csr.io.scontext
  }

  // LSU <> ROB
  rob.io.lsu_clr_bsy    := io.lsu.clr_bsy
  rob.io.lsu_clr_unsafe := io.lsu.clr_unsafe
  rob.io.lxcpt          <> io.lsu.lxcpt

  assert (!(csr.io.singleStep), "[core] single-step is unsupported.")
  // ...
  // Page Table Walker

  io.ptw.ptbr       := csr.io.ptbr
  io.ptw.status     := csr.io.status
  io.ptw.pmp        := csr.io.pmp
  io.ptw.sfence     := io.ifu.sfence
```

### src/main/scala/exu/decode.scala

```scala
  // from CSRFile
  val status = Input(new freechips.rocketchip.rocket.MStatus())
  val csr_decode = Flipped(new freechips.rocketchip.rocket.CSRDecodeIO)
  val interrupt = Input(Bool())
  val interrupt_cause = Input(UInt(xLen.W))
}
  // ...
  // Exception Handling
  io.csr_decode.inst := inst
  val csr_en = cs.csr_cmd.isOneOf(CSR.S, CSR.C, CSR.W)
  val csr_ren = cs.csr_cmd.isOneOf(CSR.S, CSR.C) && uop.lrs1 === 0.U
  val system_insn = cs.csr_cmd === CSR.I
  val sfence = cs.uopc === uopSFENCE

  val cs_legal = cs.legal
//   dontTouch(cs_legal)

  val id_illegal_insn = !cs_legal ||
    cs.fp_val && io.csr_decode.fp_illegal || // TODO check for illegal rm mode: (io.fpu.illegal_rm)
    cs.rocc && io.csr_decode.rocc_illegal ||
    cs.is_amo && !io.status.isa('a'-'a')  ||
    (cs.fp_val && !cs.fp_single) && !io.status.isa('d'-'a') ||
    csr_en && (io.csr_decode.read_illegal || !csr_ren && io.csr_decode.write_illegal) ||
    ((sfence || system_insn) && io.csr_decode.system_illegal)
  // ...
  uop.is_sys_pc2epc   := cs.is_sys_pc2epc
  uop.is_unique  := cs.inst_unique
  uop.flush_on_commit := cs.flush_on_commit || (csr_en && !csr_ren && io.csr_decode.write_flush)
```

### src/main/scala/common/micro-op.scala

```scala
  val is_sys_pc2epc    = Bool()                      // Is a ECall or Breakpoint -- both set EPC to PC.
  val is_unique        = Bool()                      // only allow this instruction in the pipeline, wait for STQ to
                                                     // drain, clear fetcha fter it (tell ROB to un-ready until empty)
  val flush_on_commit  = Bool()                      // some instructions need to flush the pipeline behind them
```

### src/main/scala/exu/rob.scala

```scala
  val flush_commit_mask = Range(0,coreWidth).map{i => io.commit.valids(i) && io.commit.uops(i).flush_on_commit}
  val flush_commit = flush_commit_mask.reduce(_|_)
  val flush_val = exception_thrown || flush_commit

  assert(!(PopCount(flush_commit_mask) > 1.U),
    "[rob] Can't commit multiple flush_on_commit instructions on one cycle")

  val flush_uop = Mux(exception_thrown, com_xcpt_uop, Mux1H(flush_commit_mask, io.commit.uops))

  // delay a cycle for critical path considerations
  io.flush.valid          := flush_val
  io.flush.bits.ftq_idx   := flush_uop.ftq_idx
  io.flush.bits.pc_lob    := flush_uop.pc_lob
  io.flush.bits.edge_inst := flush_uop.edge_inst
  io.flush.bits.is_rvc    := flush_uop.is_rvc
  io.flush.bits.flush_typ := FlushTypes.getType(flush_val,
```

## Documentation

```text
Clock the cycle counter while opportunistically clock gated

...but not during WFI.
```

```text
Use maximal mtvec alignment, regardless of interrupt count

It's slightly less hardware to allow the alignment to be a function of
the number of interrupts, but it confounds software.  (The ISA permits
either choice.)
```

```text
If any PMPs are supported, all CSRs exist
```

```text
Reserve the PMP R=0 W=1 combination

This was a post-v1.10 amendment to the spec:

https://github.com/riscv/riscv-isa-manual/commit/059f64c941856f249d8a0647e23e150dbdb1f62c
```

```text
Add CEASE instruction

After retiring this instruction, no further instructions will retire
until reset (including debugging).
```

### docs/sections/execution-stages.rst

```text
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

### src/zicsr.adoc

```text
=== CSR Instructions

All CSR instructions atomically read-modify-write a single CSR, whose
CSR specifier is encoded in the 12-bit _csr_ field of the instruction
held in bits 31-20. The immediate forms use a 5-bit zero-extended
immediate encoded in the _rs1_ field.

include::images/wavedrom/csr-instr.edn[]

The CSRRW (Atomic Read/Write CSR) instruction atomically swaps values in
the CSRs and integer registers. CSRRW reads the old value of the CSR,
zero-extends the value to XLEN bits, then writes it to integer register
_rd_. The initial value in _rs1_ is written to the CSR. If _rd_=`x0`,
then the instruction shall not read the CSR and shall not cause any of
the side effects that might occur on a CSR read.

The CSRRS (Atomic Read and Set Bits in CSR) instruction reads the value
of the CSR, zero-extends the value to XLEN bits, and writes it to
integer register _rd_. The initial value in integer register _rs1_ is
treated as a bit mask that specifies bit positions to be set in the CSR.
Any bit that is high in _rs1_ will cause the corresponding bit to be set
in the CSR, if that CSR bit is writable.

The CSRRC (Atomic Read and Clear Bits in CSR) instruction reads the
value of the CSR, zero-extends the value to XLEN bits, and writes it to
integer register _rd_. The initial value in integer register _rs1_ is
treated as a bit mask that specifies bit positions to be cleared in the
CSR. Any bit that is high in _rs1_ will cause the corresponding bit to
be cleared in the CSR, if that CSR bit is writable.

For both CSRRS and CSRRC, if _rs1_=`x0`, then the instruction will not
write to the CSR at all, and so shall not cause any of the side effects
that might otherwise occur on a CSR write, nor raise illegal-instruction
exceptions on accesses to read-only CSRs. Both CSRRS and CSRRC always
read the addressed CSR and cause any read side effects regardless of
_rs1_ and _rd_ fields.
Note that if _rs1_ specifies a register other than `x0`, and that register
holds a zero value, the instruction will not action any attendant per-field
side effects, but will action any side effects caused by writing to the entire
CSR.

A CSRRW with _rs1_=`x0` will attempt to write zero to the destination CSR.

The CSRRWI, CSRRSI, and CSRRCI variants are similar to CSRRW, CSRRS, and
CSRRC respectively, except they update the CSR using an XLEN-bit value
obtained by zero-extending a 5-bit unsigned immediate (uimm[4:0]) field
encoded in the _rs1_ field instead of a value from an integer register.
For CSRRSI and CSRRCI, if the uimm[4:0] field is zero, then these
instructions will not write to the CSR, and shall not cause any of the
side effects that might otherwise occur on a CSR write, nor raise
illegal-instruction exceptions on accesses to read-only CSRs. For
CSRRWI, if _rd_=`x0`, then the instruction shall not read the CSR and
shall not cause any of the side effects that might occur on a CSR read.
Both CSRRSI and CSRRCI will always read the CSR and cause any read side
effects regardless of _rd_ and _rs1_ fields.

[[csrsideeffects]]
.Conditions determining whether a CSR instruction reads or writes the specified CSR.
[%autowidth,float="center",align="center",cols="<,^,^,^,^",options="header",]
|===
5+^|*Register operand* 
|Instruction |_rd_ is `x0` |_rs1_ is `x0` |Reads CSR |Writes CSR

|CSRRW |Yes |- |No |Yes

|CSRRW |No |- |Yes |Yes

|CSRRS/CSRRC |- |Yes |Yes |No

|CSRRS/CSRRC |- |No |Yes |Yes

5+^|*Immediate operand* 

|Instruction |_rd_ is `x0` |__uimm__latexmath:[$=$]0 |Reads CSR |Writes
CSR

|CSRRWI |Yes |- |No |Yes

|CSRRWI |No |- |Yes |Yes

|CSRRSI/CSRRCI |- |Yes |Yes |No

|CSRRSI/CSRRCI |- |No |Yes |Yes
|===

<<csrsideeffects>> summarizes the behavior of the CSR
instructions with respect to whether they read and/or write the CSR.
```

### src/priv-csrs.adoc

```text
Standard CSRs do not have side effects on reads but may have side
effects on writes.

=== CSR Address Mapping Conventions

The standard RISC-V ISA sets aside a 12-bit encoding space (csr[11:0])
for up to 4,096 CSRs. By convention, the upper 4 bits of the CSR address
(csr[11:8]) are used to encode the read and write accessibility of the
CSRs according to privilege level as shown in <<csrrwpriv>>. The top two bits (csr[11:10]) indicate whether the register is read/write (`00`,`01`, or `10`) or read-only (`11`). The next two bits (csr[9:8]) encode the lowest privilege level that can access the CSR.

...

Instructions that access a non-existent CSR are reserved.
Attempts to access a CSR without appropriate privilege level
raise illegal-instruction exceptions or, as described in
<<sec:hcauses>>, virtual-instruction exceptions.
Attempts to write a read-only register raise illegal-instruction exceptions.
A read/write register might also contain some bits that are
read-only, in which case writes to the read-only bits are ignored.

<<csrrwpriv>> also indicates the convention to
allocate CSR addresses between standard and custom uses. The CSR
addresses designated for custom uses will not be redefined by future
standard extensions.

Machine-mode standard read-write CSRs `0x7A0`-`0x7BF` are reserved for
use by the debug system. Of these CSRs, `0x7A0`-`0x7AF` are accessible
to machine mode, whereas `0x7B0`-`0x7BF` are only visible to debug mode.
Implementations should raise illegal-instruction exceptions on
machine-mode access to the latter set of registers.
```

### src/f-st-ext.adoc

```text
=== Floating-Point Control and Status Register

The floating-point control and status register, `fcsr`, is a RISC-V
control and status register (CSR). It is a 32-bit read/write register
that selects the dynamic rounding mode for floating-point arithmetic
operations and holds the accrued exception flags, as shown in <<fcsr>>.

[[fcsr, Floating-Point Control and Status Register]]
.Floating-point control and status register
include::images/wavedrom/float-csr.edn[]

The `fcsr` register can be read and written with the FRCSR and FSCSR
instructions, which are assembler pseudoinstructions built on the
underlying CSR access instructions. FRCSR reads `fcsr` by copying it
into integer register _rd_. FSCSR swaps the value in `fcsr` by copying
the original value into integer register _rd_, and then writing a new
value obtained from integer register _rs1_ into `fcsr`.

The fields within the `fcsr` can also be accessed individually through
different CSR addresses, and separate assembler pseudoinstructions are defined
for these accesses. The FRRM instruction reads the Rounding Mode field `frm`
(`fcsr` bits 7--5) and copies it into the least-significant three bits of
integer register _rd_, with zero in all other bits. FSRM swaps the value in
`frm` by copying the original value into integer register _rd_, and then
writing a new value obtained from the three least-significant bits of integer
register _rs1_ into `frm`. FRFLAGS and FSFLAGS are defined analogously for the
Accrued Exception Flags field `fflags` (`fcsr` bits 4--0).

Bits 31--8 of the `fcsr` are reserved for other standard extensions. If
these extensions are not present, implementations shall ignore writes to
these bits and supply a zero value when read. Standard software should
preserve the contents of these bits.

Floating-point operations use either a static rounding mode encoded in
the instruction, or a dynamic rounding mode held in `frm`. Rounding
modes are encoded as shown in <<rm>>. A value of 111 in the
instruction's _rm_ field selects the dynamic rounding mode held in
`frm`. The behavior of floating-point instructions that depend on
rounding mode when executed with a reserved rounding mode is _reserved_, including both static reserved rounding modes (101-110) and dynamic reserved rounding modes (101-111). Some instructions, including widening conversions, have the _rm_ field but are nevertheless mathematically unaffected by the rounding mode; software should set their _rm_ field to 
RNE (000) but implementations must treat the _rm_ field as usual (in
particular, with regard to decoding legal vs. reserved encodings).

[[rm]]
.Rounding mode encoding.
[%autowidth,float="center",align="center",cols="^,^,<",options="header"]
|===
|Rounding Mode |Mnemonic |Meaning
|000 |RNE |Round to Nearest, ties to Even
|001 |RTZ |Round towards Zero
|010 |RDN |Round Down (towards latexmath:[$-\infty$])
|011 |RUP |Round Up (towards latexmath:[$+\infty$])
|100 |RMM |Round to Nearest, ties to Max Magnitude
|101 | |_Reserved for future use._
|110 | |_Reserved for future use._
|111 |DYN |In instruction's _rm_ field, selects dynamic rounding mode; In Rounding Mode register, _reserved_.
|===

...

The accrued exception flags indicate the exception conditions that have
arisen on any floating-point arithmetic instruction since the field was
last reset by software, as shown in <<bitdef>>. The base
RISC-V ISA does not support generating a trap on the setting of a
floating-point exception flag.
(((floating-point, exception flag)))

[[bitdef]]
.Accrued exception flag encoding.
[%autowidth,float="center",align="center",cols="^,<",options="header",]
|===
|Flag Mnemonic |Flag Meaning
|NV |Invalid Operation
|DZ |Divide by Zero
|OF |Overflow
|UF |Underflow
|NX |Inexact
|===
```

### src/counters.adoc

```text
=== "Zicntr" Extension for Base Counters and Timers

The Zicntr standard extension comprises the first three of these
counters (CYCLE, TIME, and INSTRET), which have dedicated functions
(cycle count, real-time clock, and instructions retired, respectively).
The Zicntr extension depends on the Zicsr extension.

...

For base ISAs with XLEN&#8805;64, CSR instructions can access
the full 64-bit CSRs directly. In particular, the RDCYCLE, RDTIME, and
RDINSTRET pseudoinstructions read the full 64 bits of the `cycle`,
`time`, and `instret` counters.

...

The RDCYCLE pseudoinstruction reads the low XLEN bits of the `cycle`
CSR which holds a count of the number of clock cycles executed by the
processor core on which the hart is running from an arbitrary start time
in the past. RDCYCLEH is only present when XLEN=32 and reads bits 63-32
of the same cycle counter. The underlying 64-bit counter should never
overflow in practice. The rate at which the cycle counter advances will
depend on the implementation and operating environment. The execution
environment should provide a means to determine the current rate
(cycles/second) at which the cycle counter is incrementing.

...

The RDINSTRET pseudoinstruction reads the low XLEN bits of the
`instret` CSR, which counts the number of instructions retired by this
hart from some arbitrary start point in the past. RDINSTRETH is only
present when XLEN=32 and reads bits 63-32 of the same instruction
counter. The underlying 64-bit counter should never overflow in
practice.
[NOTE]
====
Instructions that cause synchronous exceptions, including ECALL and
EBREAK, are not considered to retire and hence do not increment the
`instret` CSR.
====
```

### src/machine.adoc

```text
==== Machine ISA (`misa`) Register 

The `misa` CSR is a *WARL* read-write register reporting the ISA supported by the hart. This register must be readable in any implementation, but a value of zero can be returned to indicate the `misa` register has not been implemented, requiring that CPU capabilities be determined through a separate non-standard mechanism.

.Machine ISA register (misa)
include::images/bytefield/misareg.edn[]

The MXL (Machine XLEN) field encodes the native base integer ISA width as
shown in <<misabase>>. The MXL field is read-only.  If `misa` is nonzero, the
MXL field indicates the effective XLEN in M-mode, a constant termed _MXLEN_.
XLEN is never greater than MXLEN, but XLEN might be smaller than MXLEN in
less-privileged modes.

[[misabase]]
.Encoding of MXL field in `misa`
[%autowidth,float="center",align="center",cols=">,>",options="header",]
|===
|MXL |XLEN
|1 +
2 +
3
|32 +
64 +
128
|===

...

The Extensions field encodes the presence of the standard extensions,
with a single bit per letter of the alphabet (bit 0 encodes presence of
extension "A" , bit 1 encodes presence of extension "B", through to
bit 25 which encodes "Z"). The "I" bit will be set for RV32I, RV64I,
and RV128I base ISAs, and the "E" bit will be set for RV32E and RV64E. The
Extensions field is a *WARL* field that can contain writable bits where the
implementation allows the supported ISA to be modified. At reset, the
Extensions field shall contain the maximal set of supported extensions,
and "I" shall be selected over "E" if both are available.

When a standard extension is disabled by clearing its bit in `misa`, the
instructions and CSRs defined or modified by the extension revert to
their defined or reserved behaviors as if the extension is not
implemented.

...

.Encoding of Extensions field in `misa`.  All bits that are reserved for future use must return zero when read.
[%autowidth,float="center",align="center",cols=">,>,<",options="header",]
|===
|Bit |Character |Description
|0 +
1 +
2 +
3 +
4 +
5 +
6 +
7 +
8 +
9 +
10 +
11 +
12 +
13 +
14 +
15 +
16 +
17 +
18 +
19 +
20 +
21 +
22 +
23 +
24 +
25 +
|A +
B +
C +
D +
E +
F +
G +
H +
I +
J +
K +
L +
M +
N +
O + 
P +
Q +
R +
S +
T +
U +
V +
W +
X +
Y +
Z
|Atomic extension +
B extension +
Compressed extension +
Double-precision floating-point extension +
RV32E/64E base ISA +
Single-precision floating-point extension +
_Reserved_ +
Hypervisor extension +
RV32I/64I/128I base ISA +
_Reserved_ +
_Reserved_ +
_Reserved_ +
Integer Multiply/Divide extension +
_Tentatively reserved for User-Level Interrupts extension_ +
_Reserved_ +
_Tentatively reserved for Packed-SIMD extension_ +
Quad-precision floating-point extension +
_Reserved_ +
Supervisor mode implemented +
_Reserved_ +
User mode implemented +
Vector extension +
_Reserved_ +
Non-standard extensions present +
_Reserved_ +
_Reserved_
|===

...

The "U" and "S" bits will be set if there is support for user and
supervisor modes respectively.

The "X" bit will be set if there are any non-standard extensions.

...

==== Machine Vendor ID (`mvendorid`) Register 

The `mvendorid` CSR is a 32-bit read-only register providing the JEDEC
manufacturer ID of the provider of the core. This register must be
readable in any implementation, but a value of 0 can be returned to
indicate the field is not implemented or that this is a non-commercial
implementation.

...

==== Machine Architecture ID (`marchid`) Register 

The `marchid` CSR is an MXLEN-bit read-only register encoding the base
microarchitecture of the hart. This register must be readable in any
implementation, but a value of 0 can be returned to indicate the field
is not implemented. The combination of `mvendorid` and `marchid` should
uniquely identify the type of hart microarchitecture that is
implemented.

...

==== Machine Implementation ID (`mimpid`) Register 

The `mimpid` CSR provides a unique encoding of the version of the
processor implementation. This register must be readable in any
implementation, but a value of 0 can be returned to indicate that the
field is not implemented. The Implementation value should reflect the
design of the RISC-V processor itself and not any surrounding system.

...

==== Hart ID (`mhartid`) Register 

The `mhartid` CSR is an MXLEN-bit read-only register containing the
integer ID of the hardware thread running the code. This register must
be readable in any implementation. Hart IDs might not necessarily be
numbered contiguously in a multiprocessor system, but at least one hart
must have a hart ID of zero. Hart IDs must be unique within the
execution environment.

...

==== Machine Status (`mstatus` and `mstatush`) Registers 

The `mstatus` register is an MXLEN-bit read/write register formatted as
shown in <<mstatusreg-rv32>> for RV32 and
<<mstatusreg>> for RV64. The `mstatus` register
keeps track of and controls the hart’s current operating state. A
restricted view of `mstatus` appears as the `sstatus` register in the
S-level ISA.

[[mstatusreg-rv32]]
.Machine-mode status (`mstatus`) register for RV32
include::images/wavedrom/mstatusreg-rv321.edn[]

[[mstatusreg]]
.Machine-mode status (`mstatus`) register for RV64
include::images/wavedrom/mstatusreg.edn[]

For RV32 only, `mstatush` is a 32-bit read/write register formatted as
shown in <<mstatushreg>>. Bits 30:4 of `mstatush` generally contain the same fields found in bits 62:36 of `mstatus` for RV64. Fields SD, SXL, and UXL do not exist in `mstatush`.

[[mstatushreg]]
.Additional machine-mode status (`mstatush`) register  for RV32.
include::images/wavedrom/mstatushreg.edn[]

[[privstack]]
===== Privilege and Global Interrupt-Enable Stack in `mstatus` register

Global interrupt-enable bits, MIE and SIE, are provided for M-mode and
S-mode respectively. These bits are primarily used to guarantee
atomicity with respect to interrupt handlers in the current privilege
mode.

...

When a hart is executing in privilege mode _x_, interrupts are globally
enabled when __x__IE=1 and globally disabled when __x__IE=0. Interrupts for
lower-privilege modes, __w__<__x__, are always globally
disabled regardless of the setting of any global __w__IE bit for the
lower-privilege mode. Interrupts for higher-privilege modes,
__y__>__x__, are always globally enabled regardless of the
setting of the global __y__IE bit for the higher-privilege mode.
Higher-privilege-level code can use separate per-interrupt enable bits
to disable selected higher-privilege-mode interrupts before ceding
control to a lower-privilege mode.

...

To support nested traps, each privilege mode _x_ that can respond to
interrupts has a two-level stack of interrupt-enable bits and privilege
modes. __x__PIE holds the value of the interrupt-enable bit active prior
to the trap, and __x__PP holds the previous privilege mode. The __x__PP
fields can only hold privilege modes up to _x_, so MPP is two bits wide
and SPP is one bit wide. When a trap is taken from privilege mode _y_
into privilege mode _x_, __x__PIE is set to the value of __x__IE; __x__IE is
set to 0; and __x__PP is set to _y_.

[NOTE]
====
For lower privilege modes, any trap (synchronous or asynchronous) is
usually taken at a higher privilege mode with interrupts disabled upon
entry. The higher-level trap handler will either service the trap and
return using the stacked information, or, if not returning immediately
to the interrupted context, will save the privilege stack before
re-enabling interrupts, so only one entry per stack is required.
====

An MRET or SRET instruction is used to return from a trap in M-mode or
S-mode respectively. When executing an __x__RET instruction, supposing
__x__PP holds the value _y_, __x__IE is set to __x__PIE; the privilege mode is
changed to _y_; __x__PIE is set to 1; and __x__PP is set to the
least-privileged supported mode (U if U-mode is implemented, else M). If
__y__&#8800;M, __x__RET also sets MPRV=0.

...

__x__PP fields are *WARL* fields that can hold only privilege mode _x_ and any implemented privilege mode lower than _x_. If privilege mode _x_ is not implemented, then __x__PP must be read-only 0.

...

===== Base ISA Control in `mstatus` Register

For RV64 harts, the SXL and UXL fields are *WARL* fields that control the
value of XLEN for S-mode and U-mode, respectively. The encoding of these
fields is the same as the MXL field of `misa`, shown in
<<misabase>>. The effective XLEN in S-mode and
U-mode are termed _SXLEN_ and _UXLEN_, respectively.

When MXLEN=32, the SXL and UXL fields do not exist, and SXLEN=32 and
UXLEN=32.

When MXLEN=64, if S-mode is not supported, then SXL is read-only
zero. Otherwise, it is a *WARL* field that encodes the current value of SXLEN.
In particular, an implementation may make SXL be a read-only field whose
value always ensures that SXLEN=MXLEN.

When MXLEN=64, if U-mode is not supported, then UXL is read-only
zero. Otherwise, it is a *WARL* field that encodes the current value of UXLEN.
In particular, an implementation may make UXL be a read-only field whose
value always ensures that UXLEN=MXLEN or UXLEN=SXLEN.

If S-mode is implemented, the set of legal values that the UXL field may
assume excludes those that would cause UXLEN to be greater than SXLEN.

...

===== Memory Privilege in `mstatus` Register

The MPRV (Modify PRiVilege) bit modifies the _effective privilege mode_,
i.e., the privilege level at which loads and stores execute. When
MPRV=0, loads and stores behave as normal, using the translation and
protection mechanisms of the current privilege mode. When MPRV=1, load
and store memory addresses are translated and protected, and endianness
is applied, as though the current privilege mode were set to MPP.
Instruction address-translation and protection are unaffected by the
setting of MPRV. MPRV is read-only 0 if U-mode is not supported.

An MRET or SRET instruction that changes the privilege mode to a mode
less privileged than M also sets MPRV=0.

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

[[virt-control]]
===== Virtualization Support in `mstatus` Register

The TVM (Trap Virtual Memory) bit is a *WARL* field that supports intercepting
supervisor virtual-memory management operations. When TVM=1, attempts to
read or write the `satp` CSR or execute an SFENCE.VMA or SINVAL.VMA
instruction while executing in S-mode will raise an illegal-instruction
exception. When TVM=0, these operations are permitted in S-mode. TVM is
read-only 0 when S-mode is not supported.

...

The TW (Timeout Wait) bit is a *WARL* field that supports intercepting the WFI
instruction (see <<wfi>>). When TW=0, the WFI
instruction may execute in lower privilege modes when not prevented for
some other reason. When TW=1, then if WFI is executed in any
less-privileged mode, and it does not complete within an
implementation-specific, bounded time limit, the WFI instruction causes
an illegal-instruction exception. An implementation may have WFI always
raise an illegal-instruction exception in less-privileged modes when
TW=1, even if there are pending globally-disabled interrupts when the
instruction is executed. TW is read-only 0 when there are no modes less
privileged than M.

...

When S-mode is implemented, then executing WFI in U-mode causes an
illegal-instruction exception, unless it completes within an
implementation-specific, bounded time limit. A future revision of this
specification might add a feature that allows S-mode to selectively
permit WFI in U-mode. Such a feature would only be active when TW=0.

The TSR (Trap SRET) bit is a *WARL* field that supports intercepting the
supervisor exception return instruction, SRET. When TSR=1, attempts to
execute SRET while executing in S-mode will raise an illegal-instruction
exception. When TSR=0, this operation is permitted in S-mode. TSR is
read-only 0 when S-mode is not supported.

...

The FS[1:0] and VS[1:0] *WARL* fields and the XS[1:0] read-only field are used
to reduce the cost of context save and restore by setting and tracking
the current state of the floating-point unit and any other user-mode
extensions respectively. The FS field encodes the status of the
floating-point unit state, including the floating-point registers
`f0`–`f31` and the CSRs `fcsr`, `frm`, and `fflags`. The VS field
encodes the status of the vector extension state, including the vector
registers `v0`–`v31` and the CSRs `vcsr`, `vxrm`, `vxsat`, `vstart`,
`vl`, `vtype`, and `vlenb`. The XS field encodes the status of
additional user-mode extensions and associated state. These fields can
be checked by a context switch routine to quickly determine whether a
state save or restore is required. If a save or restore is required,
additional instructions and CSRs are typically required to effect and
optimize the process.

...

The FS, VS, and XS fields use the same status encoding as shown in
<<fsxsencoding>>, with the four possible status
values being Off, Initial, Clean, and Dirty.

[[fsxsencoding]]
.Encoding of FS[1:0], VS[1:0], and XS[1:0] status fields
[%autowidth,float="center",align="center",cols=">,<,<",options="header",]
|===
|Status |FS and VS Meaning |XS Meaning
|0 +
1 +
2 +
3
|Off +
Initial +
Clean +
Dirty
|All off +
None dirty or clean, some on +
None dirty, some clean +
Some dirty
|===

If the F extension is implemented, the FS field shall not be read-only
zero.

If neither the F extension nor S-mode is implemented, then FS is
read-only zero. If S-mode is implemented but the F extension is not, FS
may optionally be read-only zero.

...

If the `v` registers are implemented, the VS field shall not be
read-only zero.

If neither the `v` registers nor S-mode is implemented, then VS is
read-only zero. If S-mode is implemented but the `v` registers are not,
VS may optionally be read-only zero.

In harts without additional user extensions requiring new state, the
XS field is read-only zero. Every additional extension with state
provides a CSR field that encodes the equivalent of the XS states. The
XS field represents a summary of all extensions' status as shown in
<<fsxsencoding>>.

...

The SD bit is a read-only bit that summarizes whether either the FS, VS,
or XS fields signal the presence of some dirty state that will require
saving extended user context to memory. If FS, XS, and VS are all
read-only zero, then SD is also always zero.

When an extension's status is set to Off, any instruction that attempts
to read or write the corresponding state will cause an
illegal-instruction exception. When the status is Initial, the corresponding
state should have an initial constant value. When the status is Clean,
the corresponding state is potentially different from the initial value,
but matches the last value stored on a context swap. When the status is
Dirty, the corresponding state has potentially been modified since the
last context save.

...

==== Machine Trap-Vector Base-Address (`mtvec`) Register 

The `mtvec` register is an MXLEN-bit *WARL* read/write register that holds
trap vector configuration, consisting of a vector base address (BASE)
and a vector mode (MODE).


.Encoding of mtvec MODE field.
include::images/bytefield/mtvec.edn[]

The `mtvec` register must always be implemented, but can contain a
read-only value. If `mtvec` is writable, the set of values the register
may hold can vary by implementation. The value in the BASE field must
always be aligned on a 4-byte boundary, and the MODE setting may impose
additional alignment constraints on the value in the BASE field.

...

[[mtvec-mode]]
.Encoding of mtvec MODE field.
[%autowidth,float="center",align="center",cols=">,^,<",options="header"]
|===
|Value |Name |Description
|0 +
1 +
&#8805;2
|Direct +
Vectored +
---
|All traps set `pc` to BASE. +
Asynchronous interrupts set `pc` to BASE+4&#215;cause. +
_Reserved_
|===

The encoding of the MODE field is shown in
<<mtvec-mode>>. When MODE=Direct, all traps into
machine mode cause the `pc` to be set to the address in the BASE field.
When MODE=Vectored, all synchronous exceptions into machine mode cause
the `pc` to be set to the address in the BASE field, whereas interrupts
cause the `pc` to be set to the address in the BASE field plus four
times the interrupt cause number. For example, a machine-mode timer
interrupt (see <<mcauses>>) causes the `pc`
to be set to BASE+`0x1c`.


An implementation may have different alignment constraints for different
modes. In particular, MODE=Vectored may have stricter alignment
constraints than MODE=Direct.

...

==== Machine Trap Delegation (`medeleg` and `mideleg`) Registers 

By default, all traps at any privilege level are handled in machine
mode, though a machine-mode handler can redirect traps back to the
appropriate level with the MRET instruction
(<<otherpriv>>). To increase performance,
implementations can provide individual read/write bits within `medeleg`
and `mideleg` to indicate that certain exceptions and interrupts should
be processed directly by a lower privilege level. The machine exception
delegation register (`medeleg`) is a 64-bit read/write register.
The machine interrupt delegation (`mideleg`) register is an MXLEN-bit
read/write register.

In harts with S-mode, the `medeleg` and `mideleg` registers must
exist, and setting a bit in `medeleg` or `mideleg` will delegate the
corresponding trap, when occurring in S-mode or U-mode, to the S-mode
trap handler. In harts without S-mode, the `medeleg` and `mideleg`
registers should not exist.

...

When a trap is delegated to S-mode, the `scause` register is written
with the trap cause; the `sepc` register is written with the virtual
address of the instruction that took the trap; the `stval` register is
written with an exception-specific datum; the SPP field of `mstatus` is
written with the active privilege mode at the time of the trap; the SPIE
field of `mstatus` is written with the value of the SIE field at the
time of the trap; and the SIE field of `mstatus` is cleared. The
`mcause`, `mepc`, and `mtval` registers and the MPP and MPIE fields of
`mstatus` are not written.

An implementation can choose to subset the delegatable traps, with the
supported delegatable bits found by writing one to every bit location,
then reading back the value in `medeleg` or `mideleg` to see which bit
positions hold a one.

An implementation shall not have any bits of `medeleg` be read-only one,
i.e., any synchronous trap that can be delegated must support not being
delegated. Similarly, an implementation shall not fix as read-only one
any bits of `mideleg` corresponding to machine-level interrupts (but may
do so for lower-level interrupts).

...

Traps never transition from a more-privileged mode to a less-privileged
mode. For example, if M-mode has delegated illegal-instruction
exceptions to S-mode, and M-mode software later executes an illegal
instruction, the trap is taken in M-mode, rather than being delegated to
S-mode. By contrast, traps may be taken horizontally. Using the same
example, if M-mode has delegated illegal-instruction exceptions to
S-mode, and S-mode software later executes an illegal instruction, the
trap is taken in S-mode.

Delegated interrupts result in the interrupt being masked at the
delegator privilege level. For example, if the supervisor timer
interrupt (STI) is delegated to S-mode by setting `mideleg`[5], STIs
will not be taken when executing in M-mode. By contrast, if `mideleg`[5]
is clear, STIs can be taken in any mode and regardless of current mode
will transfer control to M-mode.

.Machine Exception Delegation (`medeleg`) register.
include::images/bytefield/medeleg.edn[]

`medeleg` has a bit position allocated for every synchronous exception
shown in <<mcauses>>, with the index of the
bit position equal to the value returned in the `mcause` register (i.e.,
setting bit 8 allows user-mode environment calls to be delegated to a
lower-privilege trap handler).

When XLEN=32, `medelegh` is a 32-bit read/write register
that aliases bits 63:32 of `medeleg`.
The `medelegh` register does not exist when XLEN=64.

.Machine Interrupt Delegation (`mideleg`) Register.
include::images/bytefield/mideleg.edn[]

`mideleg` holds trap delegation bits for individual interrupts, with the
layout of bits matching those in the `mip` register (i.e., STIP
interrupt delegation control is located in bit 5).

For exceptions that cannot occur in less privileged modes, the
corresponding `medeleg` bits should be read-only zero. In particular,
`medeleg`[11] is read-only zero.

...

==== Machine Interrupt (`mip` and `mie`) Registers 

The `mip` register is an MXLEN-bit read/write register containing
information on pending interrupts, while `mie` is the corresponding
MXLEN-bit read/write register containing interrupt enable bits.
Interrupt cause number _i_ (as reported in CSR `mcause`,
<<mcause>>) corresponds with bit _i_ in both `mip` and
`mie`. Bits 15:0 are allocated to standard interrupt causes only, while
bits 16 and above are designated for platform use.

NOTE: Interrupts designated for platform use may be designated for custom use
at the platform's discretion.

.Machine Interrupt-Pending (`mip`) register.
include::images/bytefield/mideleg.edn[]

.Machine Interrupt-Enable (`mie`) register
include::images/bytefield/mideleg.edn[]

An interrupt _i_ will trap to M-mode (causing the privilege mode to
change to M-mode) if all of the following are true: (a) either the
current privilege mode is M and the MIE bit in the `mstatus` register is
set, or the current privilege mode has less privilege than M-mode;
(b) bit _i_ is set in both `mip` and `mie`; and (c) if register
`mideleg` exists, bit _i_ is not set in `mideleg`.

These conditions for an interrupt trap to occur must be evaluated in a
bounded amount of time from when an interrupt becomes, or ceases to be,
pending in `mip`, and must also be evaluated immediately following the
execution of an __x__RET instruction or an explicit write to a CSR on
which these interrupt trap conditions expressly depend (including `mip`,
`mie`, `mstatus`, and `mideleg`).

Interrupts to M-mode take priority over any interrupts to lower
privilege modes.

Each individual bit in register `mip` may be writable or may be
read-only. When bit _i_ in `mip` is writable, a pending interrupt _i_
can be cleared by writing 0 to this bit. If interrupt _i_ can become
pending but bit _i_ in `mip` is read-only, the implementation must
provide some other mechanism for clearing the pending interrupt.

A bit in `mie` must be writable if the corresponding interrupt can ever
become pending. Bits of `mie` that are not writable must be read-only
zero.

...

Bits `mip`.MEIP and `mie`.MEIE are the interrupt-pending and
interrupt-enable bits for machine-level external interrupts. MEIP is
read-only in `mip`, and is set and cleared by a platform-specific
interrupt controller.

Bits `mip`.MTIP and `mie`.MTIE are the interrupt-pending and
interrupt-enable bits for machine timer interrupts. MTIP is read-only in
the `mip` register, and is cleared by writing to the memory-mapped machine-mode timer
compare register.

Bits `mip`.MSIP and `mie`.MSIE are the interrupt-pending and
interrupt-enable bits for machine-level software interrupts. MSIP is
read-only in `mip`, and is written by accesses to memory-mapped control
registers, which are used by remote harts to provide machine-level
interprocessor interrupts. A hart can write its own MSIP bit using the
same memory-mapped control register. If a system has only one hart, or
if a platform standard supports the delivery of machine-level
interprocessor interrupts through external interrupts (MEI) instead,
then `mip`.MSIP and `mie`.MSIE may both be read-only zeros.

If supervisor mode is not implemented, bits SEIP, STIP, and SSIP of
`mip` and SEIE, STIE, and SSIE of `mie` are read-only zeros.

If supervisor mode is implemented, bits `mip`.SEIP and `mie`.SEIE are
the interrupt-pending and interrupt-enable bits for supervisor-level
external interrupts. SEIP is writable in `mip`, and may be written by
M-mode software to indicate to S-mode that an external interrupt is
pending. Additionally, the platform-level interrupt controller may
generate supervisor-level external interrupts. Supervisor-level external
interrupts are made pending based on the logical-OR of the
software-writable SEIP bit and the signal from the external interrupt
controller. When `mip` is read with a CSR instruction, the value of the
SEIP bit returned in the `rd` destination register is the logical-OR of
the software-writable bit and the interrupt signal from the interrupt
controller, but the signal from the interrupt controller is not used to
calculate the value written to SEIP. Only the software-writable SEIP bit
participates in the read-modify-write sequence of a CSRRS or CSRRC
instruction.

...

If supervisor mode is implemented, bits `mip`.STIP and `mie`.STIE are
the interrupt-pending and interrupt-enable bits for supervisor-level
timer interrupts. STIP is writable in `mip`, and may be written by
M-mode software to deliver timer interrupts to S-mode.

If supervisor mode is implemented, bits `mip`.SSIP and `mie`.SSIE are
the interrupt-pending and interrupt-enable bits for supervisor-level
software interrupts. SSIP is writable in `mip` and may also be set to 1
by a platform-specific interrupt controller.

...

Multiple simultaneous interrupts destined for M-mode are handled in the
following decreasing priority order: MEI, MSI, MTI, SEI, SSI, STI, LCOFI.

...

Restricted views of the `mip` and `mie` registers appear as the `sip`
and `sie` registers for supervisor level. If an interrupt is delegated
to S-mode by setting a bit in the `mideleg` register, it becomes visible
in the `sip` register and is maskable using the `sie` register.
Otherwise, the corresponding bits in `sip` and `sie` are read-only zero.

...

==== Machine Counter-Enable (`mcounteren`) Register 

The counter-enable `mcounteren` register is a 32-bit register that
controls the availability of the hardware performance-monitoring
counters to the next-lower privileged mode.

.Counter-enable (`mcounteren`) register.
include::images/bytefield/counteren.edn[]

The settings in this register only control accessibility. The act of
reading or writing this register does not affect the underlying
counters, which continue to increment even when not accessible.

When the CY, TM, IR, or HPM__n__ bit in the `mcounteren` register is
clear, attempts to read the `cycle`, `time`, `instret`, or
`hpmcountern` register while executing in S-mode or U-mode will cause an
illegal-instruction exception. When one of these bits is set, access to
the corresponding register is permitted in the next implemented
privilege mode (S-mode if implemented, otherwise U-mode).

...

The `cycle`, `instret`, and `hpmcountern` CSRs are read-only shadows of
`mcycle`, `minstret`, and `mhpmcounter n`, respectively. The `time` CSR
is a read-only shadow of the memory-mapped `mtime` register.
Analogously, when XLEN=32, the `cycleh`, `instreth` and `hpmcounternh` CSRs
are read-only shadows of `mcycleh`, `minstreth` and `mhpmcounternh`,
respectively. When XLEN=32, the `timeh` CSR is a read-only shadow of the
upper 32 bits of the memory-mapped `mtime` register, while `time`
shadows only the lower 32 bits of `mtime`.

...

In harts with U-mode, the `mcounteren` must be implemented, but all
fields are *WARL* and may be read-only zero, indicating reads to the
corresponding counter will cause an illegal-instruction exception when
executing in a less-privileged mode. In harts without U-mode, the
`mcounteren` register should not exist.

...

==== Machine Counter-Inhibit (`mcountinhibit`) Register 

.Counter-inhibit `mcountinhibit` register
include::images/bytefield/counterinh.edn[]

The counter-inhibit register `mcountinhibit` is a 32-bit *WARL* register that
controls which of the hardware performance-monitoring counters
increment. The settings in this register only control whether the
counters increment; their accessibility is not affected by the setting
of this register.

When the CY, IR, or HPM__n__ bit in the `mcountinhibit` register is clear,
the `mcycle`, `minstret`, or `mhpmcountern` register increments as usual.
When the CY, IR, or HPM_n_ bit is set, the corresponding counter does
not increment.

The `mcycle` CSR may be shared between harts on the same core, in which
case the `mcountinhibit.CY` field is also shared between those harts,
and so writes to `mcountinhibit.CY` will be visible to those harts.

If the `mcountinhibit` register is not implemented, the implementation
behaves as though the register were set to zero.

...

==== Machine Scratch (`mscratch`) Register 

The `mscratch` register is an MXLEN-bit read/write register dedicated
for use by machine mode. Typically, it is used to hold a pointer to a
machine-mode hart-local context space and swapped with a user register
upon entry to an M-mode trap handler.

...

==== Machine Exception Program Counter (`mepc`) Register

`mepc` is an MXLEN-bit read/write register formatted as shown in
<<mepcreg>>. The low bit of `mepc` (`mepc[0]`) is
always zero. On implementations that support only IALIGN=32, the two low
bits (`mepc[1:0]`) are always zero.

If an implementation allows IALIGN to be either 16 or 32 (by changing
CSR `misa`, for example), then, whenever IALIGN=32, bit `mepc[1]` is
masked on reads so that it appears to be 0. This masking occurs also for
the implicit read by the MRET instruction. Though masked, `mepc[1]`
remains writable when IALIGN=32.

`mepc` is a *WARL* register that must be able to hold all valid virtual
addresses. It need not be capable of holding all possible invalid
addresses. Prior to writing `mepc`, implementations may convert an
invalid address into some other invalid address that `mepc` is capable
of holding.

...

When a trap is taken into M-mode, `mepc` is written with the virtual
address of the instruction that was interrupted or that encountered the
exception. Otherwise, `mepc` is never written by the implementation,
though it may be explicitly written by software.

[[mepcreg]]
.Machine exception program counter register.
include::images/bytefield/mepcreg.edn[]

...

==== Machine Cause (`mcause`) Register 

The `mcause` register is an MXLEN-bit read-write register formatted as
shown in <<mcausereg>>. When a trap is taken into
M-mode, `mcause` is written with a code indicating the event that
caused the trap. Otherwise, `mcause` is never written by the
implementation, though it may be explicitly written by software.

The Interrupt bit in the `mcause` register is set if the trap was caused
by an interrupt. The Exception Code field contains a code identifying
the last exception or interrupt. <<mcauses>> lists
the possible machine-level exception codes. The Exception Code is a
*WLRL* field, so is only guaranteed to hold supported exception codes.

[[mcausereg]]
.Machine Cause (`mcause`) register.
include::images/bytefield/mcausereg.edn[]

...

==== Machine Trap Value (`mtval`) Register 

The `mtval` register is an MXLEN-bit read-write register formatted as
shown in <<mtvalreg>>. When a trap is taken into
M-mode, `mtval` is either set to zero or written with exception-specific
information to assist software in handling the trap. Otherwise, `mtval`
is never written by the implementation, though it may be explicitly
written by software. The hardware platform will specify which exceptions
must set `mtval` informatively, which may unconditionally set it to
zero, and which may exhibit either behavior, depending on the underlying event
that caused the exception.
If the hardware platform specifies that no exceptions set `mtval`
to a nonzero value, then `mtval` is read-only zero.

If `mtval` is written with a nonzero value when a breakpoint,
address-misaligned, access-fault, or page-fault exception occurs on an
instruction fetch, load, or store, then `mtval` will contain the
faulting virtual address.

When page-based virtual memory is enabled, `mtval` is written with the
faulting virtual address, even for physical-memory access-fault
exceptions. This design reduces datapath cost for most implementations,
particularly those with hardware page-table walkers.

[[mtvalreg]]
.Machine Trap Value (`mtval`) register.
include::images/bytefield/mtvalreg.edn[]

...

If `mtval` is written with a nonzero value when a misaligned load or
store causes an access-fault or page-fault exception, then `mtval` will
contain the virtual address of the portion of the access that caused the
fault.

If `mtval` is written with a nonzero value when an instruction
access-fault or page-fault exception occurs on a hart with
variable-length instructions, then `mtval` will contain the virtual
address of the portion of the instruction that caused the fault, while
`mepc` will point to the beginning of the instruction.

...

=== Machine-Mode Privileged Instructions

==== Environment Call and Breakpoint

include::images/wavedrom/mm-env-call.edn[]

The ECALL instruction is used to make a request to the supporting
execution environment. When executed in U-mode, S-mode, or M-mode, it
generates an environment-call-from-U-mode exception,
environment-call-from-S-mode exception, or environment-call-from-M-mode
exception, respectively, and performs no other operation.

...

The EBREAK instruction is used by debuggers to cause control to be
transferred back to a debugging environment.
Unless overridden by an external debug environment, EBREAK raises
a breakpoint exception and performs no other operation.

...

ECALL and EBREAK cause the receiving privilege mode’s `epc` register to
be set to the address of the ECALL or EBREAK instruction itself, _not_
the address of the following instruction. As ECALL and EBREAK cause
synchronous exceptions, they are not considered to retire, and should
not increment the `minstret` CSR.

...

==== Trap-Return Instructions

Instructions to return from trap are encoded under the PRIV minor
opcode.

include::images/wavedrom/trap-return.edn[]

To return after handling a trap, there are separate trap return
instructions per privilege level, MRET and SRET. MRET is always
provided. SRET must be provided if supervisor mode is supported, and
should raise an illegal-instruction exception otherwise. SRET should
also raise an illegal-instruction exception when TSR=1 in `mstatus`, as
described in <<virt-control>>. An __x__RET instruction
can be executed in privilege mode _x_ or higher, where executing a
lower-privilege __x__RET instruction will pop the relevant lower-privilege
interrupt enable and privilege mode stack. In addition to manipulating
the privilege stack as described in <<privstack>>,
__x__RET sets the `pc` to the value stored in the `__x__epc` register.

...

==== Wait for Interrupt

The Wait for Interrupt instruction (WFI) informs the
implementation that the current hart can be stalled until an interrupt
might need servicing. Execution of the WFI instruction can also be used
to inform the hardware platform that suitable interrupts should
preferentially be routed to this hart. WFI is available in all
privileged modes, and optionally available to U-mode. This instruction
may raise an illegal-instruction exception when TW=1 in `mstatus`, as
described in <<virt-control>>.

include::images/wavedrom/wfi.edn[]

If an enabled interrupt is present or later becomes present while the
hart is stalled, the interrupt trap will be taken on the following
instruction, i.e., execution resumes in the trap handler and `mepc` =
`pc` + 4.

...

Implementations are permitted to resume execution for any reason, even if an
enabled interrupt has not become pending.  Hence, a legal implementation is to
simply implement the WFI instruction as a NOP.

...

The WFI instruction can also be executed when interrupts are disabled.
The operation of WFI must be unaffected by the global interrupt bits in
`mstatus` (MIE and SIE) and the delegation register `mideleg` (i.e.,
the hart must resume if a locally enabled interrupt becomes pending,
even if it has been delegated to a less-privileged mode), but should
honor the individual interrupt enables (e.g, MTIE) (i.e.,
implementations should avoid resuming the hart if the interrupt is
pending but not individually enabled). WFI is also required to resume
execution for locally enabled interrupts pending at any privilege level,
regardless of the global interrupt enable at each privilege level.

If the event that causes the hart to resume execution does not cause an
interrupt to be taken, execution will resume at `pc` + 4, and software
must determine what action to take, including looping back to repeat the
WFI if there was no actionable event.

...

=== Reset

Upon reset, a hart’s privilege mode is set to M. The `mstatus` fields
MIE and MPRV are reset to 0. If little-endian memory accesses are
supported, the `mstatus`/`mstatush` field MBE is reset to 0. The `misa`
register is reset to enable the maximal set of supported extensions,
as described in <<misa>>.  For
implementations with the "A" standard extension, there is no valid
load reservation. The `pc` is set to an implementation-defined reset
vector. The `mcause` register is set to a value indicating the cause of
the reset. Writable PMP registers’ A and L fields are set to 0, unless
the platform mandates a different reset value for some PMP registers’ A
and L fields. If the hypervisor extension is implemented, the
`hgatp`.MODE and `vsatp`.MODE fields are reset to 0. If the Smrnmi
extension is implemented, the `mnstatus`.NMIE field is reset to 0. No
 *WARL* field contains an illegal value. If the Zicfilp extension is
implemented, the `mseccfg`.MLPE field is reset to 0. All other hart
state is UNSPECIFIED.

The `mcause` values after reset have implementation-specific
interpretation, but the value 0 should be returned on implementations
that do not distinguish different reset conditions. Implementations that
distinguish different reset conditions should only use 0 to indicate the
most complete reset.

...

==== Physical Memory Protection CSRs

PMP entries are described by an 8-bit configuration register and one
MXLEN-bit address register. Some PMP settings additionally use the
address register associated with the preceding PMP entry. Up to 64 PMP
entries are supported. Implementations may implement zero, 16, or 64 PMP
entries; the lowest-numbered PMP entries must be implemented first. All
PMP CSR fields are *WARL* and may be read-only zero. PMP CSRs are only
accessible to M-mode.

The PMP configuration registers are densely packed into CSRs to minimize
context-switch time. For RV32, sixteen CSRs, `pmpcfg0`–`pmpcfg15`, hold
the configurations `pmp0cfg`–`pmp63cfg` for the 64 PMP entries, as shown
in <<pmpcfg-rv32>>. For RV64, eight
even-numbered CSRs, `pmpcfg0`, `pmpcfg2`, …, `pmpcfg14`, hold the
configurations for the 64 PMP entries, as shown in
<<pmpcfg-rv64>>. For RV64, the odd-numbered
configuration registers, `pmpcfg1`, `pmpcfg3`, …, `pmpcfg15`, are
illegal.

...

[[pmpcfg-rv64]]
.RV64 PMP configuration CSR layout.
include::images/bytefield/pmp-rv64.edn[]


The PMP address registers are CSRs named `pmpaddr0`-`pmpaddr63`. Each
PMP address register encodes bits 33-2 of a 34-bit physical address for
RV32, as shown in <<pmpaddr-rv32>>. For RV64,
each PMP address register encodes bits 55-2 of a 56-bit physical
address, as shown in <<pmpaddr-rv64>>. Not all
physical address bits may be implemented, and so the `pmpaddr` registers
are *WARL*.

...

[[pmpaddr-rv64]]
.PMP address register format, RV64.
include::images/bytefield/pmpaddr-rv64.edn[]

<<pmpcfg>> shows the layout of a PMP configuration
register. The R, W, and X bits, when set, indicate that the PMP entry
permits read, write, and instruction execution, respectively. When one
of these bits is clear, the corresponding access type is denied. The R,
W, and X fields form a collective *WARL* field for which the combinations with R=0 and W=1 are reserved. The remaining two fields, A and L, are described in the following sections.

[[pmpcfg]]
.PMP configuration register format.
include::images/bytefield/pmpcfg.edn[]

...

===== Address Matching

The A field in a PMP entry's configuration register encodes the
address-matching mode of the associated PMP address register. The
encoding of this field is shown in <<pmpcfg-a>>.
When A=0, this PMP entry is disabled and matches no addresses. Two other
address-matching modes are supported: naturally aligned power-of-2
regions (NAPOT), including the special case of naturally aligned
four-byte regions (NA4); and the top boundary of an arbitrary range
(TOR). These modes support four-byte granularity.

[[pmpcfg-a]]
.Encoding of A field in PMP configuration registers.
[%autowidth,float="center",align="center",cols=">,^,<",options="header"]
|===
|A |Name |Description
|0 +
1 +
2 +
3
|OFF +
TOR +
NA4 +
NAPOT
|Null region (disabled) +
Top of range +
Naturally aligned four-byte region +
Naturally aligned power-of-two region, &#8805;8
bytes
|===

...

===== Locking and Privilege Mode

The L bit indicates that the PMP entry is locked, i.e., writes to the
configuration register and associated address registers are ignored.
Locked PMP entries remain locked until the hart is reset. If PMP entry
_i_ is locked, writes to ``pmp``__i__``cfg`` and ``pmpaddr``__i__ are ignored. Additionally, if PMP
entry _i_ is locked and ``pmp``__i__``cfg.A`` is set
to TOR, writes to ``pmpaddr``__i__-1 are ignored.
```

### src/supervisor.adoc

```text
The SPP bit indicates the privilege level at which a hart was executing
before entering supervisor mode. When a trap is taken, SPP is set to 0
if the trap originated from user mode, or 1 otherwise. When an SRET
instruction (see <<otherpriv>>) is executed to
return from the trap handler, the privilege level is set to user mode if
the SPP bit is 0, or supervisor mode if the SPP bit is 1; SPP is then
set to 0.

The SIE bit enables or disables all interrupts in supervisor mode. When
SIE is clear, interrupts are not taken while in supervisor mode. When
the hart is running in user-mode, the value in SIE is ignored, and
supervisor-level interrupts are enabled. The supervisor can disable
individual interrupt sources using the `sie` CSR.

The SPIE bit indicates whether supervisor interrupts were enabled prior
to trapping into supervisor mode. When a trap is taken into supervisor
mode, SPIE is set to SIE, and SIE is set to 0. When an SRET instruction
is executed, SIE is set to SPIE, then SPIE is set to 1.

The `sstatus` register is a subset of the `mstatus` register.

[NOTE]
====
In a straightforward implementation, reading or writing any field in
`sstatus` is equivalent to reading or writing the homonymous field in
`mstatus`.
====

...

===== Base ISA Control in `sstatus` Register

The UXL field controls the value of XLEN for U-mode, termed _UXLEN_,
which may differ from the value of XLEN for S-mode, termed _SXLEN_. The
encoding of UXL is the same as that of the MXL field of `misa`, shown in
<<misabase>>.

When SXLEN=32, the UXL field does not exist, and UXLEN=32. When
SXLEN=64, it is a *WARL* field that encodes the current value of UXLEN. In
particular, an implementation may make UXL be a read-only field whose
value always ensures that UXLEN=SXLEN.

...

===== Memory Privilege in `sstatus` Register

The MXR (Make eXecutable Readable) bit modifies the privilege with which
loads access virtual memory. When MXR=0, only loads from pages marked
readable (R=1 in <<sv32pte>>) will succeed. When
MXR=1, loads from pages marked either readable or executable (R=1 or
X=1) will succeed. MXR has no effect when page-based virtual memory is
not in effect.

The SUM (permit Supervisor User Memory access) bit modifies the
privilege with which S-mode loads and stores access virtual memory. When
SUM=0, S-mode memory accesses to pages that are accessible by U-mode
(U=1 in <<sv32pte>>) will fault. When SUM=1, these
accesses are permitted. SUM has no effect when page-based virtual memory
is not in effect, nor when executing in U-mode. Note that S-mode can
never execute instructions from user pages, regardless of the state of
SUM.

SUM is read-only 0 if `satp`.MODE is read-only 0.

...

===== Endianness Control in `sstatus` Register

The UBE bit is a *WARL* field that controls the endianness of explicit memory
accesses made from U-mode, which may differ from the endianness of
memory accesses in S-mode. An implementation may make UBE be a read-only
field that always specifies the same endianness as for S-mode.

UBE controls whether explicit load and store memory accesses made from
U-mode are little-endian (UBE=0) or big-endian (UBE=1).

UBE has no effect on instruction fetches, which are _implicit_ memory
accesses that are always little-endian.

For _implicit_ accesses to supervisor-level memory management data
structures, such as page tables, S-mode endianness always applies and
UBE is ignored.

...

==== Supervisor Trap Vector Base Address (`stvec`)  Register

The `stvec` register is an SXLEN-bit read/write register that holds trap
vector configuration, consisting of a vector base address (BASE) and a
vector mode (MODE).

.Supervisor trap vector base address (`stvec`) register.
include::images/bytefield/stvec.edn[]

The BASE field in `stvec` is a  field that can hold any valid virtual or
physical address, subject to the following alignment constraints: the
address must be 4-byte aligned, and MODE settings other than Direct
might impose additional alignment constraints on the value in the BASE
field.

[[stvec-mode]]
.Encoding of `stvec` MODE field.
[%autowidth,float="center",align="center",cols=">,^,<",options="header",]
|===
|Value |Name |Description
|0 +
1 +
&#8805;2
|Direct +
Vectored
|All exceptions set `pc` to BASE. +
Asynchronous interrupts set `pc` to BASE+4&#215;cause. +
_Reserved_
|===

The encoding of the MODE field is shown in
<<stvec-mode>>. When MODE=Direct, all traps into
supervisor mode cause the `pc` to be set to the address in the BASE
field. When MODE=Vectored, all synchronous exceptions into supervisor
mode cause the `pc` to be set to the address in the BASE field, whereas
interrupts cause the `pc` to be set to the address in the BASE field
plus four times the interrupt cause number. For example, a
supervisor-mode timer interrupt (see <<scauses>>)
causes the `pc` to be set to BASE+`0x14`. Setting MODE=Vectored may
impose a stricter alignment constraint on BASE.

...

==== Supervisor Interrupt (`sip` and `sie`) Registers

The `sip` register is an SXLEN-bit read/write register containing
information on pending interrupts, while `sie` is the corresponding
SXLEN-bit read/write register containing interrupt enable bits.
Interrupt cause number _i_ (as reported in CSR `scause`,
<<scause>>) corresponds with bit _i_ in both `sip` and
`sie`. Bits 15:0 are allocated to standard interrupt causes only, while
bits 16 and above are designated for platform use.

.Supervisor interrupt-pending register (`sip`).
include::images/bytefield/sip.edn[]

.Supervisor interrupt-enable register (`sie`).
include::images/bytefield/sie.edn[]

An interrupt _i_ will trap to S-mode if both of the following are true:
(a) either the current privilege mode is S and the SIE bit in the
`sstatus` register is set, or the current privilege mode has less
privilege than S-mode; and (b) bit _i_ is set in both `sip` and `sie`.

These conditions for an interrupt trap to occur must be evaluated in a
bounded amount of time from when an interrupt becomes, or ceases to be,
pending in `sip`, and must also be evaluated immediately following the
execution of an SRET instruction or an explicit write to a CSR on which
these interrupt trap conditions expressly depend (including `sip`, `sie`
and `sstatus`).

Interrupts to S-mode take priority over any interrupts to lower
privilege modes.

Each individual bit in register `sip` may be writable or may be
read-only. When bit _i_ in `sip` is writable, a pending interrupt _i_
can be cleared by writing 0 to this bit. If interrupt _i_ can become
pending but bit _i_ in `sip` is read-only, the implementation must
provide some other mechanism for clearing the pending interrupt (which
may involve a call to the execution environment).

A bit in `sie` must be writable if the corresponding interrupt can ever
become pending. Bits of `sie` that are not writable are read-only zero.

...

Bits `sip`.SEIP and `sie`.SEIE are the interrupt-pending and
interrupt-enable bits for supervisor-level external interrupts. If
implemented, SEIP is read-only in `sip`, and is set and cleared by the
execution environment, typically through a platform-specific interrupt
controller.

Bits `sip`.STIP and `sie`.STIE are the interrupt-pending and
interrupt-enable bits for supervisor-level timer interrupts. If
implemented, STIP is read-only in `sip`, and is set and cleared by the
execution environment.

Bits `sip`.SSIP and `sie`.SSIE are the interrupt-pending and
interrupt-enable bits for supervisor-level software interrupts. If
implemented, SSIP is writable in `sip` and may also be set to 1 by a
platform-specific interrupt controller.

...

Each standard interrupt type (SEI, STI, SSI, or LCOFI) may not be implemented,
in which case the corresponding interrupt-pending and interrupt-enable
bits are read-only zeros. All bits in `sip` and `sie` are *WARL* fields. The
implemented interrupts may be found by writing one to every bit location
in `sie`, then reading back to see which bit positions hold a one.

...

The `sip` and `sie` registers are subsets of the `mip` and `mie`
registers. Reading any implemented field, or writing any writable field,
of `sip`/`sie` effects a read or write of the homonymous field of
`mip`/`mie`.

...

Multiple simultaneous interrupts destined for supervisor mode are
handled in the following decreasing priority order: SEI, SSI, STI, LCOFI.

...

==== Counter-Enable (`scounteren`) Register

.Counter-enable (`scounteren`) register
include::images/bytefield/scounteren.edn[]

The counter-enable (`scounteren`) CSR is a 32-bit register that
controls the availability of the hardware performance monitoring
counters to U-mode.

When the CY, TM, IR, or HPM__n__ bit in the `scounteren` register is
clear, attempts to read the `cycle`, `time`, `instret`, or `hpmcountern`
register while executing in U-mode will cause an illegal-instruction
exception. When one of these bits is set, access to the corresponding
register is permitted.

`scounteren` must be implemented. However, any of the bits may be
read-only zero, indicating reads to the corresponding counter will cause
an exception when executing in U-mode. Hence, they are effectively
*WARL* fields.

...

==== Supervisor Scratch (`sscratch`) Register

The `sscratch` CSR is an SXLEN-bit read/write register, dedicated
for use by the supervisor. Typically, `sscratch` is used to hold a
pointer to the hart-local supervisor context while the hart is executing
user code.
At the beginning of a trap handler, software normally uses a CSRRW
instruction to swap `sscratch` with an integer register to obtain an
initial working register.

...

==== Supervisor Exception Program Counter (`sepc`) Register

`sepc` is an SXLEN-bit read/write CSR formatted as shown in
<<epcreg>>. The low bit of `sepc` (`sepc[0]`) is always zero. On implementations that support only IALIGN=32, the two low bits (`sepc[1:0]`) are always zero.

If an implementation allows IALIGN to be either 16 or 32 (by changing
CSR `misa`, for example), then, whenever IALIGN=32, bit `sepc[1]` is
masked on reads so that it appears to be 0. This masking occurs also for
the implicit read by the SRET instruction. Though masked, `sepc[1]`
remains writable when IALIGN=32.

`sepc` is a *WARL* register that must be able to hold all valid virtual
addresses. It need not be capable of holding all possible invalid
addresses. Prior to writing `sepc`, implementations may convert an
invalid address into some other invalid address that `sepc` is capable
of holding.

When a trap is taken into S-mode, `sepc` is written with the virtual
address of the instruction that was interrupted or that encountered the
exception. Otherwise, `sepc` is never written by the implementation,
though it may be explicitly written by software.

[[epcreg]]
.Supervisor exception program counter register.
include::images/bytefield/epcreg.edn[]

...

[[scause]]
==== Supervisor Cause (`scause`) Register

The `scause` CSR is an SXLEN-bit read-write register formatted as
shown in <<scausereg>>. When a trap is taken into
S-mode, `scause` is written with a code indicating the event that
caused the trap. Otherwise, `scause` is never written by the
implementation, though it may be explicitly written by software.

The Interrupt bit in the `scause` register is set if the trap was caused
by an interrupt. The Exception Code field contains a code identifying
the last exception or interrupt. <<scauses>> lists
the possible exception codes for the current supervisor ISAs. The
Exception Code is a *WLRL* field. It is required to hold the values 0–31
(i.e., bits 4–0 must be implemented), but otherwise it is only
guaranteed to hold supported exception codes.

[[scausereg]]
.Supervisor Cause (`scause`) register.
include::images/bytefield/scausereg.edn[]

...

==== Supervisor Trap Value (`stval`) Register

The `stval` CSR is an SXLEN-bit read-write register formatted as
shown in <<stvalreg>>. When a trap is taken into
S-mode, `stval` is written with exception-specific information to assist
software in handling the trap. Otherwise, `stval` is never written by
the implementation, though it may be explicitly written by software. The
hardware platform will specify which exceptions must set `stval`
informatively, which may unconditionally set it to zero, and which may
exhibit either behavior, depending on the underlying event that caused the
exception.

If `stval` is written with a nonzero value when a breakpoint,
address-misaligned, access-fault, or page-fault exception occurs on an
instruction fetch, load, or store, then `stval` will contain the
faulting virtual address.

[[stvalreg]]
.Supervisor Trap Value register.
include::images/bytefield/stvalreg.edn[]

...

If `stval` is written with a nonzero value when a misaligned load or
store causes an access-fault or page-fault exception, then `stval` will
contain the virtual address of the portion of the access that caused the
fault.

If `stval` is written with a nonzero value when an instruction
access-fault or page-fault exception occurs on a system with
variable-length instructions, then `stval` will contain the virtual
address of the portion of the instruction that caused the fault, while
`sepc` will point to the beginning of the instruction.

...

==== Supervisor Address Translation and Protection (`satp`) Register

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

[[rv64satp]]
.Supervisor address translation and protection (`satp`) register when SXLEN=64, for MODE values Bare, Sv39, Sv48, and Sv57.
include::images/bytefield/rv64satp.edn[]

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

When SXLEN=32, the `satp` encodings corresponding to MODE=Bare and
ASID[8:7]=3 are designated for custom use, whereas the encodings
corresponding to MODE=Bare and ASID[8:7]≠3 are reserved
for future standard use. When SXLEN=64, all `satp` encodings
corresponding to MODE=Bare are reserved for future standard use.

[NOTE]
====
Version 1.11 of this standard stated that the remaining fields in `satp`
had no effect when MODE=Bare. Making these fields reserved facilitates
future definition of additional translation and protection modes,
particularly in RV32, for which all patterns of the existing MODE field
have already been allocated.
====

When SXLEN=32, the only other valid setting for MODE is Sv32, a paged
virtual-memory scheme described in <<sv32>>.

When SXLEN=64, three paged virtual-memory schemes are defined: Sv39,
Sv48, and Sv57, described in <<sv39>>, <<sv48>>,
and <<sv57>>, respectively. One additional scheme, Sv64, will be
defined in a later version of this specification. The remaining MODE
settings are reserved for future use and may define different
interpretations of the other fields in `satp`.

Implementations are not required to support all MODE settings, and if
`satp` is written with an unsupported MODE, the entire write has no
effect; no fields in `satp` are modified.

The number of ASID bits is UNSPECIFIED and may be zero. The number of implemented
ASID bits, termed _ASIDLEN_, may be determined by writing one to every
bit position in the ASID field, then reading back the value in `satp` to
see which bit positions in the ASID field hold a one. The
least-significant bits of ASID are implemented first: that is, if
ASIDLEN latexmath:[$>$] 0, ASID[ASIDLEN-1:0] is writable. The maximal
value of ASIDLEN, termed ASIDMAX, is 9 for Sv32 or 16 for Sv39, Sv48,
and Sv57.

...

[[satp-mode]]
.Encoding of `satp` MODE field.
[%autowidth,float="center",align="center",cols="^,^,<",options="header"]
|===
3+|SXLEN=32
|Value |Name |Description
|0 +
1
|Bare +
Sv32
|No translation or protection. +
Page-based 32-bit virtual addressing (see <<sv32>>).
3+|*SXLEN=64*
|Value |Name |Description
|0 +
1-7 +
8 +
9 +
10 +
11 +
12-13 +
14-15
|Bare +
- +
Sv39 +
Sv48 +
Sv57 +
Sv64 +
- +
-
|No translation or protection. +
_Reserved for standard use_ +
Page-based 39-bit virtual addressing (see <<sv39>>). +
Page-based 48-bit virtual addressing (see <<sv48>>). +
Page-based 57-bit virtual addressing (see <<sv57>>). +
_Reserved for page-based 64-bit virtual addressing._ +
_Reserved for standard use_ +
_Designated for custom use_
|===

...

=== Supervisor Instructions

In addition to the SRET instruction defined in <<otherpriv>>, one new supervisor-level instruction is provided.

[[sfence.vma]]
==== Supervisor Memory-Management Fence Instruction
include::images/wavedrom/sfencevma.edn[]


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
```

### core_debug.tex

```text
Modifications to the RISC-V core to support debug are kept to a minimum.  There
is a special execution mode (Debug Mode) and a few extra CSRs. The DM takes care
of the rest.

\section{Debug Mode} \label{debugmode}

Debug Mode is a special processor mode used only when the core is halted for
external debugging. How Debug Mode is implemented is not specified here.

\begin{steps}{When executing code from the Program Buffer, the processor stays
    in Debug Mode and the following apply:}
\item All operations are executed at machine mode privilege level, except that
    \Fmprv in \Rmstatus is ignored.
\item All interrupts are masked.
\item Exceptions don't update any registers.  That includes {\tt cause}, {\tt
    epc}, {\tt tval}, {\tt dpc}, and \Rmstatus. They do end execution of the
    Program Buffer.
\item No action is taken if a trigger matches.
\item Trace is disabled.
\item Counters may be stopped, depending on \Fstopcount in \Rdcsr.
\item Timers may be stopped, depending on \Fstoptime in \Rdcsr.
\item The {\tt wfi} instruction acts as a {\tt nop}.
\item Almost all instructions that change the privilege level have undefined
    behavior.  This includes {\tt ecall}, {\tt mret}, {\tt hret}, {\tt sret},
    and {\tt uret}.  (To change the privilege level, the debugger can write
    \Fprv in \Rdcsr). The only exception is {\tt ebreak}. When that is executed
    in Debug Mode, it halts the processor again but without updating \Rdpc or \Rdcsr.
\end{steps}

...

\section{Reset}

If the halt signal (driven by the hart's halt request bit in the Debug Module)
is asserted when a hart comes out of reset, the hart must
enter Debug Mode before executing any instructions, but after performing any
initialization that would usually happen before the first instruction is
executed.

\subsection{{\tt dret} Instruction} \label{dret}

To return from Debug Mode, a new instruction is defined: {\tt dret}. It has an
encoding of 0x7b200073. On harts which support this instruction,
executing {\tt dret} in Debug Mode changes \Rpc to the value
stored in \Rdpc. The current privilege level is changed to that specified by
\Fprv in \Rdcsr. The hart is no longer in debug mode.

...

\section{Core Debug Registers} \label{debreg}

The supported Core Debug Registers must be implemented for each hart that can
be debugged.
```

### core_registers.xml

```text
        <field name="xdebugver" bits="31:30" access="R" reset="Preset">
          0: There is no external debug support.

          1: External debug support exists as it is described in this document.

	  Other values are reserved for future standards.
        </field>
        <field name="0" bits="29:16" access="R" reset="0" />
```

### xml/core_registers.xml

```text
        <field name="ebreakm" bits="15" access="R/W" reset="0">
            When 1, {\tt ebreak} instructions in Machine Mode enter Debug Mode.
        </field>
        <field name="0" bits="14" access="R" reset="0" />
        <field name="ebreaks" bits="13" access="R/W" reset="0">
            When 1, {\tt ebreak} instructions in Supervisor Mode enter Debug Mode.
        </field>
        <field name="ebreaku" bits="12" access="R/W" reset="0">
            When 1, {\tt ebreak} instructions in User/Application Mode enter
            Debug Mode.
        </field>
        <field name="stepie" bits="11" access="R/W" reset="0">
            0: Interrupts are disabled during single stepping.

            1: Interrupts are enabled during single stepping.

            Implementations may hard wire this bit to 0.
            The debugger must read back the value it
            writes to check whether the feature is supported. If not
            supported, interrupt behavior can be emulated by the debugger.
        </field>
        <field name="stopcount" bits="10" access="R/W" reset="Preset">

            0: Increment counters as usual.

            1: Don't increment any counters while in Debug Mode or on {\tt
            ebreak} instructions that cause entry into Debug Mode.  These
            counters include the {\tt cycle} and {\tt instret} CSRs. This is
            preferred for most debugging scenarios.

            An implementation may choose not to support writing to this bit.
            The debugger must read back the value it writes to check whether
            the feature is supported.

        </field>
        <field name="stoptime" bits="9" access="R/W" reset="Preset">
            0: Increment timers as usual.

            1: Don't increment any hart-local timers while in Debug Mode.

            An implementation may choose not to support writing to this bit.
            The debugger must read back the value it writes to check whether
            the feature is supported.

        </field>
        <field name="cause" bits="8:6" access="R" reset="0">
            Explains why Debug Mode was entered.

            When there are multiple reasons to enter Debug Mode in a single
            cycle, the cause with the highest priority is the one written.

            1: An {\tt ebreak} instruction was executed. (priority 3)

            2: The Trigger Module caused a breakpoint exception. (priority 4)

            3: The debugger requested entry to Debug Mode. (priority 2)

            4: The hart single stepped because \Fstep was set. (priority 1)

            Other values are reserved for future use.
        </field>
        <field name="0" bits="5:3" access="R" reset="0" />
        <field name="step" bits="2" access="R/W" reset="0">
            When set and not in Debug Mode, the hart will only execute a single
            instruction and then enter Debug Mode.
            If the instruction does not complete due to an exception,
            the hart will immediately enter Debug Mode before executing
            the trap handler, with appropriate exception registers set.
        </field>
        <field name="prv" bits="1:0" access="R/W" reset="0">
            Contains the privilege level the hart was operating in when Debug
            Mode was entered. The encoding is described in Table
            \ref{tab:privlevel}.  A debugger can change this value to change
            the hart's privilege level when exiting Debug Mode.

            Not all privilege levels are supported on all harts. If the
            encoding written is not supported or the debugger is not allowed to
            change to it, the hart may change to any supported privilege level.
        </field>
    </register>

...

    <register name="Debug PC" short="dpc" address="0x7b1">
        Upon entry to debug mode, \Rdpc is updated with the virtual address of
        the next instruction to be executed. The behavior is described in more
        detail in Table~\ref{tab:dpc}.

        \begin{table}[H]
        \centering
        \caption{Virtual address in DPC upon Debug Mode Entry}
        \label{tab:dpc}
        \begin{tabular}{|l|L|}
        \hline
        Cause &amp; Virtual Address in DPC \\
        \hline
        {\tt ebreak} &amp; Address of the {\tt ebreak} instruction \\
        \hline
        single step &amp; Address of the instruction that would be executed
        next if no debugging was going on. Ie. $\Rpc+4$ for 32-bit instructions
        that don't change program flow, the destination PC on taken
        jumps/branches, etc. \\
        \hline

...

        halt request &amp; Address of the next instruction to be
        executed at the time that debug mode was entered \\
        \hline
        \end{tabular}
        \end{table}

        When resuming, the hart's PC is updated to the virtual address stored in
        \Rdpc. A debugger may write \Rdpc to change where the hart resumes.
        <field name="dpc" bits="XLEN-1:0" access="R/W" reset="0" />
    </register>

    <register name="Debug Scratch Register 0" short="dscratch0" address="0x7b2">
        Optional scratch register that can be used by implementations that need
        it. A debugger must not write to this register unless \Rhartinfo
        explicitly mentions it (the Debug Module may use this register internally).
    </register>
```

### trigger.tex

```text
        \item When no hardware triggers are implemented at all, all related
            registers return 0. The algorithm above terminates when checking
            \Ftype.
```
