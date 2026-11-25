# Implement `MemAddrCalcUnit`

Implement the complete `MemAddrCalcUnit` module. Preserve its declaration and I/O interface. Return only the complete `class MemAddrCalcUnit` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/parameters.scala`

```scala
case class BoomCoreParams(
// ...
  nBreakpoints: Int = 0, // TODO Fix with better frontend breakpoint unit
// ...
  useVM: Boolean = true,
// ...
```

### `src/main/scala/common/config-mixins.scala`

```scala
class WithNLargeBooms(n: Int = 1, overrideIdOffset: Option[Int] = None) extends Config(
// ...
    case XLen => 64
// ...
```

### `generators/chipyard/src/main/scala/config/BoomConfigs.scala`

```scala
class LargeBoomConfig extends Config(
  new boom.common.WithNLargeBooms(1) ++                          // large boom config
  new chipyard.config.AbstractConfig)
```

## Package and imports

### `src/main/scala/exu/execution-units/functional-unit.scala`

```scala
package boom.exu

import chisel3._
import chisel3.util._
import chisel3.experimental.chiselName

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.rocket.ALU._
import freechips.rocketchip.util._
import freechips.rocketchip.tile
import freechips.rocketchip.rocket.{PipelinedMultiplier,BP,BreakpointUnit,Causes,CSR}

import boom.common._
import boom.ifu._
import boom.util._
```

## Class declaration

```scala
class MemAddrCalcUnit(implicit p: Parameters)
  extends PipelinedFunctionalUnit(
    numStages = 0,
    numBypassStages = 0,
    earliestBypassStage = 0,
    dataWidth = 65, // TODO enable this only if FP is enabled?
    isMemAddrCalcUnit = true)
  with freechips.rocketchip.rocket.constants.MemoryOpConstants
  with freechips.rocketchip.rocket.constants.ScalarOpConstants
{
```

## Parent instantiation

### `src/main/scala/exu/execution-units/execution-unit.scala`

```scala
  // Mem Unit --------------------------
  if (hasMem) {
    require(!hasAlu)
    val maddrcalc = Module(new MemAddrCalcUnit)
    maddrcalc.io.req        <> io.req
    maddrcalc.io.req.valid  := io.req.valid && io.req.bits.uop.fu_code_is(FU_MEM)
    maddrcalc.io.brupdate     <> io.brupdate
    maddrcalc.io.status     := io.status
    maddrcalc.io.bp         := io.bp
    maddrcalc.io.mcontext   := io.mcontext
    maddrcalc.io.scontext   := io.scontext
    maddrcalc.io.resp.ready := DontCare
    require(numBypassStages == 0)

    io.lsu_io.req := maddrcalc.io.resp
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/exu/execution-units/functional-unit.scala`

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

    // only used by branch unit
    val brinfo     = if (isAluUnit) Output(new BrResolutionInfo()) else null
    val get_ftq_pc = if (isJmpUnit) Flipped(new GetPCFromFtqIO()) else null
    val status     = if (isMemAddrCalcUnit) Input(new freechips.rocketchip.rocket.MStatus()) else null

    // only used by memaddr calc unit
    val bp = if (isMemAddrCalcUnit) Input(Vec(nBreakpoints, new BP)) else null
    val mcontext = if (isMemAddrCalcUnit) Input(UInt(coreParams.mcontextWidth.W)) else null
    val scontext = if (isMemAddrCalcUnit) Input(UInt(coreParams.scontextWidth.W)) else null

  })
}
// ...
abstract class PipelinedFunctionalUnit(
  numStages: Int,
  numBypassStages: Int,
  earliestBypassStage: Int,
  dataWidth: Int,
  isJmpUnit: Boolean = false,
  isAluUnit: Boolean = false,
  isMemAddrCalcUnit: Boolean = false,
  needsFcsr: Boolean = false
  )(implicit p: Parameters) extends FunctionalUnit(
    isPipelined = true,
    numStages = numStages,
    numBypassStages = numBypassStages,
    dataWidth = dataWidth,
    isJmpUnit = isJmpUnit,
    isAluUnit = isAluUnit,
    isMemAddrCalcUnit = isMemAddrCalcUnit,
    needsFcsr = needsFcsr)
{
  // Pipelined functional unit is always ready.
  io.req.ready := true.B
// ...
  } else {
    require (numStages == 0)
    // pass req straight through to response

    // valid doesn't check kill signals, let consumer deal with it.
    // The LSU already handles it and this hurts critical path.
    io.resp.valid    := io.req.valid && !IsKilledByBranch(io.brupdate, io.req.bits.uop)
    io.resp.bits.predicated := false.B
    io.resp.bits.uop := io.req.bits.uop
    io.resp.bits.uop.br_mask := GetNewBrMask(io.brupdate, io.req.bits.uop)
  }
}
```

### `src/main/scala/common/micro-op.scala`

```scala
/**
 * Extension to BoomBundle to add a MicroOp
 */
abstract trait HasBoomUOP extends BoomBundle
{
  val uop = new MicroOp()
}
// ...
class MicroOp(implicit p: Parameters) extends BoomBundle
  with freechips.rocketchip.rocket.constants.MemoryOpConstants
  with freechips.rocketchip.rocket.constants.ScalarOpConstants
{
  val uopc             = UInt(UOPC_SZ.W)       // micro-op code
// ...
  val imm_packed       = UInt(LONGEST_IMM_SZ.W) // densely pack the imm in decode...
                                              // then translate and sign-extend in execute
// ...
  val mem_cmd          = UInt(M_SZ.W)          // sync primitives/cache flushes
  val mem_size         = UInt(2.W)
// ...
  val lrs1             = UInt(lregSz.W)
  val lrs2             = UInt(lregSz.W)
```

### `src/main/scala/common/consts.scala`

```scala
  val UOPC_SZ = 7
// ...
  val uopLD   =  1.U(UOPC_SZ.W)
  val uopSTA  =  2.U(UOPC_SZ.W)  // store address generation
// ...
  val uopAMO_AG    =  67.U(UOPC_SZ.W) // AMO-address gen (use normal STD for datagen)
// ...
  val LONGEST_IMM_SZ = 20
```

### `src/main/scala/exu/decode.scala`

```scala
  uop.mem_cmd    := cs.mem_cmd
  uop.mem_size   := Mux(cs.mem_cmd.isOneOf(M_SFENCE, M_FLUSH_ALL), Cat(uop.lrs2 =/= 0.U, uop.lrs1 =/= 0.U), inst(13,12))
// ...
  // repackage the immediate, and then pass the fewest number of bits around
  val di24_20 = Mux(cs.imm_sel === IS_B || cs.imm_sel === IS_S, inst(11,7), inst(24,20))
  uop.imm_packed := Cat(inst(31,25), di24_20, inst(19,12))
```

### `src/main/scala/rocket/Consts.scala`

```scala
  val M_SZ      = 5
// ...
  def M_FLUSH_ALL = UInt("b00101")  // flush all lines
// ...
  def M_SFENCE  = UInt("b10100") // SFENCE.VMA
```

### `src/main/scala/rocket/Instructions.scala`

```scala
  def LB                 = BitPat("b?????????????????000?????0000011")
  def LH                 = BitPat("b?????????????????001?????0000011")
  def LW                 = BitPat("b?????????????????010?????0000011")
  def LD                 = BitPat("b?????????????????011?????0000011")
  def LBU                = BitPat("b?????????????????100?????0000011")
  def LHU                = BitPat("b?????????????????101?????0000011")
  def LWU                = BitPat("b?????????????????110?????0000011")
  def SB                 = BitPat("b?????????????????000?????0100011")
  def SH                 = BitPat("b?????????????????001?????0100011")
  def SW                 = BitPat("b?????????????????010?????0100011")
  def SD                 = BitPat("b?????????????????011?????0100011")
// ...
object Causes {
// ...
  val misaligned_load = 0x4
// ...
  val misaligned_store = 0x6
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

## Related source code

### `src/main/scala/exu/core.scala`

```scala
      // Efficient means to compress 64-bit VA into vaddrBits+1 bits.
      // (VA is bad if VA(vaddrBits) != VA(vaddrBits-1)).
```

### `src/main/scala/lsu/lsu.scala`

```scala
  val exe_tlb_vaddr = widthMap(w =>
                    Mux(will_fire_load_incoming (w) ||
                        will_fire_stad_incoming (w) ||
                        will_fire_sta_incoming  (w)  , exe_req(w).bits.addr,
                    Mux(will_fire_sfence        (w)  , exe_req(w).bits.sfence.bits.addr,
                    Mux(will_fire_load_retry    (w)  , ldq_retry_e.bits.addr.bits,
                    Mux(will_fire_sta_retry     (w)  , stq_retry_e.bits.addr.bits,
                    Mux(will_fire_hella_incoming(w)  , hella_req.addr,
                                                       0.U))))))
// ...
  val ma_ld = widthMap(w => will_fire_load_incoming(w) && exe_req(w).bits.mxcpt.valid) // We get ma_ld in memaddrcalc
  val ma_st = widthMap(w => (will_fire_sta_incoming(w) || will_fire_stad_incoming(w)) && exe_req(w).bits.mxcpt.valid) // We get ma_ld in memaddrcalc
// ...
    when (will_fire_std_incoming(w) || will_fire_stad_incoming(w) || fp_stdata_fire)
    {
      val sidx = Mux(will_fire_std_incoming(w) || will_fire_stad_incoming(w),
        stq_incoming_idx(w),
        io.core.fp_stdata.bits.uop.stq_idx)
      stq(sidx).bits.data.valid := true.B
      stq(sidx).bits.data.bits  := Mux(will_fire_std_incoming(w) || will_fire_stad_incoming(w),
        exe_req(w).bits.data,
        io.core.fp_stdata.bits.data)
      assert(!(stq(sidx).bits.data.valid),
        "[lsu] Incoming store is overwriting a valid data entry")
    }
```

## Documentation

### `src/rv32.adoc`

```text
Load and store instructions transfer a value between the registers and
memory. Loads are encoded in the I-type format and stores are S-type.
The effective address is obtained by adding register _rs1_ to the
sign-extended 12-bit offset. Loads copy a value from memory to register
_rd_. Stores copy the value in register _rs2_ to memory.
...
Regardless of EEI, loads and stores whose effective addresses are
naturally aligned shall not raise an address-misaligned exception. Loads
and stores whose effective address is not naturally aligned to the
referenced datatype (i.e., the effective address is not divisible by the
size of the access in bytes) have behavior dependent on the EEI.
```

### `src/a-st-ext.adoc`

```text
The atomic memory operation (AMO) instructions perform read-modify-write
operations for multiprocessor synchronization and are encoded with an
R-type instruction format. These AMO instructions atomically load a data
value from the address in _rs1_, place the value into register _rd_,
apply a binary operator to the loaded value and the original value in
_rs2_, then store the result back to the original address in _rs1_. AMOs
can either operate on _doublewords_ (RV64 only) or _words_ in memory. For
RV64, 32-bit AMOs always sign-extend the value placed in _rd_, and
ignore the upper 32 bits of the original value of _rs2_.

For AMOs, the Zaamo extension requires that the address held in _rs1_ be
naturally aligned to the size of the operand (i.e., eight-byte aligned
for _doublewords_ and four-byte aligned for _words_). If the address
is not naturally aligned, an address-misaligned exception or an
access-fault exception will be generated. The access-fault exception can
be generated for a memory access that would otherwise be able to
complete except for the misalignment, if the misaligned access should
not be emulated.
```

### `src/supervisor.adoc`

```text
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
Sv39 implementations support a 39-bit virtual address space, divided
into pages. An Sv39 address is partitioned as shown in
<<sv39va>>. Instruction fetch addresses and load and
store effective addresses, which are 64 bits, must have bits 63–39 all
equal to bit 38, or else a page-fault exception will occur. The 27-bit
VPN is translated into a 44-bit PPN via a three-level page table, while
the 12-bit page offset is untranslated.
```
