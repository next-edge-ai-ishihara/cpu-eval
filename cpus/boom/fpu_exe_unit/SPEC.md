# Implement `FPUExeUnit`

Implement one complete `FPUExeUnit` source-level hardware definition for the BOOM `LargeBoomConfig` configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Return only the complete `class FPUExeUnit` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/config-mixins.scala`

```scala
              fpu = Some(freechips.rocketchip.tile.FPUParams(sfmaLatency=4, dfmaLatency=4, divSqrt=true))
```

## Package and imports

### `src/main/scala/exu/execution-units/execution-unit.scala`

```scala
package boom.exu

import scala.collection.mutable.{ArrayBuffer}

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.{Parameters}
import freechips.rocketchip.rocket.{BP}
import freechips.rocketchip.tile.{XLen, RoCCCoreIO}
import freechips.rocketchip.tile

import FUConstants._
import boom.common._
import boom.ifu.{GetPCFromFtqIO}
import boom.util.{ImmGen, IsKilledByBranch, BranchKillableQueue, BoomCoreStringPrefix}
```

## Class declaration

```scala
class FPUExeUnit(
  hasFpu  : Boolean = true,
  hasFdiv : Boolean = false,
  hasFpiu : Boolean = false
  )
  (implicit p: Parameters)
  extends ExecutionUnit(
    readsFrf  = true,
    writesFrf = true,
    writesLlIrf = hasFpiu,
    writesIrf = false,
    numBypassStages = 0,
    dataWidth = p(tile.TileKey).core.fpu.get.fLen + 1,
    bypassable = false,
    hasFpu  = hasFpu,
    hasFdiv = hasFdiv,
    hasFpiu = hasFpiu) with tile.HasFPUParameters
{
  // ...
```

## Parent instantiation

### `src/main/scala/exu/execution-units/execution-units.scala`

```scala
  if (!fpu) {
  // ...
  } else {
    val fp_width = issueParams.find(_.iqType == IQT_FP.litValue).get.issueWidth
    for (w <- 0 until fp_width) {
      val fpu_exe_unit = Module(new FPUExeUnit(hasFpu = true,
                                             hasFdiv = usingFDivSqrt && (w==0),
                                             hasFpiu = (w==0)))
      exe_units += fpu_exe_unit
    }
  }
```

### `src/main/scala/exu/fp-pipeline.scala`

```scala
  for (i <- 0 until issue_unit.issueWidth) {
    iss_valids(i) := issue_unit.io.iss_valids(i)
    iss_uops(i) := issue_unit.io.iss_uops(i)

    var fu_types = exe_units(i).io.fu_types
    if (exe_units(i).supportedFuncUnits.fdiv) {
      val fdiv_issued = iss_valids(i) && iss_uops(i).fu_code_is(FU_FDV)
      fu_types = fu_types & RegNext(~Mux(fdiv_issued, FU_FDV, 0.U))
    }
    issue_unit.io.fu_types(i) := fu_types

    require (exe_units(i).readsFrf)
  }
  // ...
  exe_units.map(_.io.brupdate := io.brupdate)

  for ((ex,w) <- exe_units.withFilter(_.readsFrf).map(x=>x).zipWithIndex) {
    ex.io.req <> fregister_read.io.exe_reqs(w)
    require (!ex.bypassable)
  }
  require (exe_units.numTotalBypassPorts == 0)
  // ...
  for (eu <- exe_units) {
    if (eu.writesFrf) {
      fregfile.io.write_ports(w_cnt).valid     := eu.io.fresp.valid && eu.io.fresp.bits.uop.rf_wen
      fregfile.io.write_ports(w_cnt).bits.addr := eu.io.fresp.bits.uop.pdst
      fregfile.io.write_ports(w_cnt).bits.data := eu.io.fresp.bits.data
      eu.io.fresp.ready                        := true.B
      when (eu.io.fresp.valid) {
        assert(eu.io.fresp.ready, "No backpressuring the FPU")
        assert(eu.io.fresp.bits.uop.rf_wen, "rf_wen must be high here")
        assert(eu.io.fresp.bits.uop.dst_rtype === RT_FLT, "wb type must be FLT for fpu")
      }
      w_cnt += 1
    }
  }
  require (w_cnt == fregfile.io.write_ports.length)

  val fpiu_unit = exe_units.fpiu_unit
  val fpiu_is_sdq = fpiu_unit.io.ll_iresp.bits.uop.uopc === uopSTA
  io.to_int.valid := fpiu_unit.io.ll_iresp.fire && !fpiu_is_sdq
  io.to_sdq.valid := fpiu_unit.io.ll_iresp.fire &&  fpiu_is_sdq
  io.to_int.bits  := fpiu_unit.io.ll_iresp.bits
  io.to_sdq.bits  := fpiu_unit.io.ll_iresp.bits
  fpiu_unit.io.ll_iresp.ready := io.to_sdq.ready && io.to_int.ready
  // ...
  exe_units.map(_.io.fcsr_rm := io.fcsr_rm)
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/exu/execution-units/execution-unit.scala`

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
// ...
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

  if (writesIrf)   {
    io.iresp.bits.fflags.valid := false.B
    io.iresp.bits.predicated := false.B
    assert(io.iresp.ready)
  }
  if (writesLlIrf) {
    io.ll_iresp.bits.fflags.valid := false.B
    io.ll_iresp.bits.predicated := false.B
  }
  if (writesFrf)   {
    io.fresp.bits.fflags.valid := false.B
    io.fresp.bits.predicated := false.B
    assert(io.fresp.ready)
  }
  // ...
  def hasFFlags     : Boolean = hasFpu || hasFdiv

  require ((hasFpu || hasFdiv) ^ (hasAlu || hasMul || hasMem || hasIfpu),
    "[execute] we no longer support mixing FP and Integer functional units in the same exe unit.")
  def hasFcsr = hasIfpu || hasFpu || hasFdiv

  require (bypassable || !alwaysBypassable,
    "[execute] an execution unit must be bypassable if it is always bypassable")

  def supportedFuncUnits = {
    new SupportedFuncUnits(
      alu = hasAlu,
      jmp = hasJmpUnit,
      mem = hasMem,
      muld = hasMul || hasDiv,
      fpu = hasFpu,
      csr = hasCSR,
      fdiv = hasFdiv,
      ifpu = hasIfpu)
  }
  // ...
```

### `src/main/scala/exu/execution-units/functional-unit.scala`

```scala
/**t
 * Functional unit constants
 */
object FUConstants
{
  // bit mask, since a given execution pipeline may support multiple functional units
  val FUC_SZ = 10
  val FU_X   = BitPat.dontCare(FUC_SZ)
  // ...
  val FU_FPU =  64.U(FUC_SZ.W)
  val FU_FDV = 128.U(FUC_SZ.W)
  // ...
  val FU_F2I = 512.U(FUC_SZ.W)

  // FP stores generate data through FP F2I, and generate address through MemAddrCalc
  val FU_F2IMEM = 516.U(FUC_SZ.W)
}
import FUConstants._
// ...
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
// ...
}
// ...
abstract class FunctionalUnit(
  val isPipelined: Boolean,
  val numStages: Int,
  val numBypassStages: Int,
  val dataWidth: Int,
  val isJmpUnit: Boolean = false,
  val isAluUnit: Boolean = false,
  val isMemAddrCalcUnit: Boolean = false,
  val needsFcsr: Boolean = false)
  (implicit p: Parameters) extends BoomModule
{
  val io = IO(new Bundle {
    val req    = Flipped(new DecoupledIO(new FuncUnitReq(dataWidth)))
    val resp   = (new DecoupledIO(new FuncUnitResp(dataWidth)))

    val brupdate = Input(new BrUpdateInfo())

    val bypass = Output(Vec(numBypassStages, Valid(new ExeUnitResp(dataWidth))))

    // only used by the fpu unit
    val fcsr_rm = if (needsFcsr) Input(UInt(tile.FPConstants.RM_SZ.W)) else null

  // ...
  })
}
// ...
/**
 * Functional unit to wrap lower level FPU
 *
 * Currently, bypassing is unsupported!
 * All FP instructions are padded out to the max latency unit for easy
 * write-port scheduling.
 */
class FPUUnit(implicit p: Parameters)
  extends PipelinedFunctionalUnit(
    numStages = p(tile.TileKey).core.fpu.get.dfmaLatency,
    numBypassStages = 0,
    earliestBypassStage = 0,
    dataWidth = 65,
    needsFcsr = true)
{
  // ...
```

### `src/main/scala/exu/execution-units/fdiv.scala`

```scala
class FDivSqrtUnit(implicit p: Parameters)
  extends FunctionalUnit(
    isPipelined = false,
    numStages = 1,
    numBypassStages = 0,
    dataWidth = 65,
    needsFcsr = true)
  with tile.HasFPUParameters
  // ...
```

### `src/main/scala/util/util.scala`

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
  // ...
```

### `src/main/scala/common/micro-op.scala`

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
  // ...
  val fu_code          = UInt(FUConstants.FUC_SZ.W) // which functional unit do we use?
  // ...
  val br_mask          = UInt(maxBrCount.W)  // which branches are we being speculated under?
  // ...
  def fu_code_is(_fu: UInt) = (fu_code & _fu) =/= 0.U
  // ...
```

### `src/main/scala/common/consts.scala`

```scala
  val UOPC_SZ = 7
  val uopX    = BitPat.dontCare(UOPC_SZ)
  val uopNOP  =  0.U(UOPC_SZ.W)
  val uopLD   =  1.U(UOPC_SZ.W)
  val uopSTA  =  2.U(UOPC_SZ.W)  // store address generation
  val uopSTD  =  3.U(UOPC_SZ.W)  // store data generation
```

### `src/main/scala/tile/FPU.scala`

```scala
package freechips.rocketchip.tile
// ...
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
// ...
case class FType(exp: Int, sig: Int) {
  def ieeeWidth = exp + sig
  def recodedWidth = ieeeWidth + 1
  // ...
  def isNaN(x: UInt) = x(sig + exp - 1, sig + exp - 3).andR
  // ...
  def recode(x: UInt) = hardfloat.recFNFromFN(exp, sig, x)
  def ieee(x: UInt) = hardfloat.fNFromRecFN(exp, sig, x)
}

object FType {
  val H = new FType(5, 11)
  val S = new FType(8, 24)
  val D = new FType(11, 53)

  val all = List(H, S, D)
}

trait HasFPUParameters {
  require(fLen == 0 || FType.all.exists(_.ieeeWidth == fLen))
  val minFLen: Int
  val fLen: Int
  def xLen: Int
  // ...
  val floatTypes = FType.all.filter(t => minFLen <= t.ieeeWidth && t.ieeeWidth <= fLen)
  def minType = floatTypes.head
  def maxType = floatTypes.last
  def prevType(t: FType) = floatTypes(typeTag(t) - 1)
  // ...
  def typeTag(t: FType) = floatTypes.indexOf(t)
  // ...
  // implement NaN unboxing and un-recoding for FS*/fmv.x.*
  def ieee(x: UInt, t: FType = maxType): UInt = {
    if (typeTag(t) == 0) {
      t.ieee(x)
    } else {
      val unrecoded = t.ieee(x)
      val prevT = prevType(t)
      val prevRecoded = Cat(
        x(prevT.recodedWidth-2),
        x(t.sig-1),
        x(prevT.recodedWidth-3, 0))
      val prevUnrecoded = ieee(prevRecoded, prevT)
      Cat(unrecoded >> prevT.ieeeWidth, Mux(t.isNaN(x), prevUnrecoded, unrecoded(prevT.ieeeWidth-1, 0)))
    }
  }
  // ...
```

## Documentation

### `docs/sections/execution-stages.rst`

```text
    An example :term:`Execution Unit`. This particular example shows an integer ALU (that can bypass
    results to dependent instructions) and an unpipelined divider that becomes busy during operation. Both
    :term:`Functional Unit`s share a single write-port. The :term:`Execution Unit` accepts both kill signals and branch resolution
    signals and passes them to the internal :term:`Functional Unit` s as required.


...
To make the scheduling of the write-port trivial, all of the pipelined
FP units are padded to have the same latency. [3]_

Floating Point Divide and Square-root Unit
------------------------------------------

BOOM fully supports floating point divide and square-root operations
using a single **FDiv/Sqrt** (or fdiv for short). BOOM accomplishes this by
instantiating a double-precision unit from the hardfloat repository. The
unit comes with the following features/constraints:

-  expects 65-bit recoded double-precision inputs

-  provides a 65-bit recoded double-precision output

-  can execute a divide operation and a square-root operation
   simultaneously

-  operations are unpipelined and take an unknown, variable latency

-  provides an *unstable* FIFO interface

Single-precision operations have their operands upscaled to
double-precision (and then the output downscaled). [4]_
```

### `docs/sections/load-store-unit.rst`

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
```
