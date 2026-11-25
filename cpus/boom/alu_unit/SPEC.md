# Implement `ALUUnit`

Implement one complete `ALUUnit` source-level hardware definition for BOOM. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class ALUUnit` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
//******************************************************************************
// Copyright (c) 2013 - 2018, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE and LICENSE.SiFive for license details.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// Functional Units
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//
// If regfile bypassing is disabled, then the functional unit must do its own
// bypassing in here on the WB stage (i.e., bypassing the io.resp.data)
//
// TODO: explore possibility of conditional IO fields? if a branch unit... how to add extra to IO in subclass?

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
class ALUUnit(isJmpUnit: Boolean = false, numStages: Int = 1, dataWidth: Int)(implicit p: Parameters)
  extends PipelinedFunctionalUnit(
    numStages = numStages,
    numBypassStages = numStages,
    isAluUnit = true,
    earliestBypassStage = 0,
    dataWidth = dataWidth,
    isJmpUnit = isJmpUnit)
  with boom.ifu.HasBoomFrontendParameters
{
```

## Parent instantiation

### src/main/scala/exu/execution-units/execution-unit.scala

```scala
  // ALU Unit -------------------------------
  var alu: ALUUnit = null
  if (hasAlu) {
    alu = Module(new ALUUnit(isJmpUnit = hasJmpUnit,
                             numStages = numBypassStages,
                             dataWidth = xLen))
    alu.io.req.valid := (
      io.req.valid &&
      (io.req.bits.uop.fu_code === FU_ALU ||
       io.req.bits.uop.fu_code === FU_JMP ||
      (io.req.bits.uop.fu_code === FU_CSR && io.req.bits.uop.uopc =/= uopROCC)))
    //ROCC Rocc Commands are taken by the RoCC unit

    alu.io.req.bits.uop      := io.req.bits.uop
    alu.io.req.bits.kill     := io.req.bits.kill
    alu.io.req.bits.rs1_data := io.req.bits.rs1_data
    alu.io.req.bits.rs2_data := io.req.bits.rs2_data
    alu.io.req.bits.rs3_data := DontCare
    alu.io.req.bits.pred_data := io.req.bits.pred_data
    alu.io.resp.ready := DontCare
    alu.io.brupdate := io.brupdate

    iresp_fu_units += alu

    // Bypassing only applies to ALU
    io.bypass := alu.io.bypass

    // branch unit is embedded inside the ALU
    io.brinfo := alu.io.brinfo
    if (hasJmpUnit) {
      alu.io.get_ftq_pc <> io.get_ftq_pc
    }
// ...
  // Outputs (Write Port #0)  ---------------
  if (writesIrf) {
    io.iresp.valid     := iresp_fu_units.map(_.io.resp.valid).reduce(_|_)
    io.iresp.bits.uop  := PriorityMux(iresp_fu_units.map(f =>
      (f.io.resp.valid, f.io.resp.bits.uop)))
    io.iresp.bits.data := PriorityMux(iresp_fu_units.map(f =>
      (f.io.resp.valid, f.io.resp.bits.data)))
    io.iresp.bits.predicated := PriorityMux(iresp_fu_units.map(f =>
      (f.io.resp.valid, f.io.resp.bits.predicated)))

    // pulled out for critical path reasons
    // TODO: Does this make sense as part of the iresp bundle?
    if (hasAlu) {
      io.iresp.bits.uop.csr_addr := ImmGen(alu.io.resp.bits.uop.imm_packed, IS_I).asUInt
      io.iresp.bits.uop.ctrl.csr_cmd := alu.io.resp.bits.uop.ctrl.csr_cmd
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

### src/main/scala/exu/execution-units/functional-unit.scala

```scala
/**t
 * Functional unit constants
 */
object FUConstants
{
  // bit mask, since a given execution pipeline may support multiple functional units
  val FUC_SZ = 10
  val FU_X   = BitPat.dontCare(FUC_SZ)
  val FU_ALU =   1.U(FUC_SZ.W)
  val FU_JMP =   2.U(FUC_SZ.W)
  val FU_MEM =   4.U(FUC_SZ.W)
  val FU_MUL =   8.U(FUC_SZ.W)
  val FU_DIV =  16.U(FUC_SZ.W)
  val FU_CSR =  32.U(FUC_SZ.W)
  val FU_FPU =  64.U(FUC_SZ.W)
  val FU_FDV = 128.U(FUC_SZ.W)
  val FU_I2F = 256.U(FUC_SZ.W)
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


/**
 * Abstract top level functional unit class that wraps a lower level hand made functional unit
 *
 * @param isPipelined is the functional unit pipelined?
 * @param numStages how many pipeline stages does the functional unit have
 * @param numBypassStages how many bypass stages does the function unit have
 * @param dataWidth width of the data being operated on in the functional unit
 * @param hasBranchUnit does this functional unit have a branch unit?
 */
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

/**
 * Abstract top level pipelined functional unit
 *
 * Note: this helps track which uops get killed while in intermediate stages,
 * but it is the job of the consumer to check for kills on the same cycle as consumption!!!
 *
 * @param numStages how many pipeline stages does the functional unit have
 * @param numBypassStages how many bypass stages does the function unit have
 * @param earliestBypassStage first stage that you can start bypassing from
 * @param dataWidth width of the data being operated on in the functional unit
 * @param hasBranchUnit does this functional unit have a branch unit?
 */
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

  if (numStages > 0) {
    val r_valids = RegInit(VecInit(Seq.fill(numStages) { false.B }))
    val r_uops   = Reg(Vec(numStages, new MicroOp()))

    // handle incoming request
    r_valids(0) := io.req.valid && !IsKilledByBranch(io.brupdate, io.req.bits.uop) && !io.req.bits.kill
    r_uops(0)   := io.req.bits.uop
    r_uops(0).br_mask := GetNewBrMask(io.brupdate, io.req.bits.uop)

    // handle middle of the pipeline
    for (i <- 1 until numStages) {
      r_valids(i) := r_valids(i-1) && !IsKilledByBranch(io.brupdate, r_uops(i-1)) && !io.req.bits.kill
      r_uops(i)   := r_uops(i-1)
      r_uops(i).br_mask := GetNewBrMask(io.brupdate, r_uops(i-1))

      if (numBypassStages > 0) {
        io.bypass(i-1).bits.uop := r_uops(i-1)
      }
    }

    // handle outgoing (branch could still kill it)
    // consumer must also check for pipeline flushes (kills)
    io.resp.valid    := r_valids(numStages-1) && !IsKilledByBranch(io.brupdate, r_uops(numStages-1))
    io.resp.bits.predicated := false.B
    io.resp.bits.uop := r_uops(numStages-1)
    io.resp.bits.uop.br_mask := GetNewBrMask(io.brupdate, r_uops(numStages-1))

    // bypassing (TODO allow bypass vector to have a different size from numStages)
    if (numBypassStages > 0 && earliestBypassStage == 0) {
      io.bypass(0).bits.uop := io.req.bits.uop

      for (i <- 1 until numBypassStages) {
        io.bypass(i).bits.uop := r_uops(i-1)
      }
    }
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

### src/main/scala/common/micro-op.scala

```scala
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

### src/main/scala/common/consts.scala

```scala
trait ScalarOpConstants
// ...
  //************************************
  // Control Signals

  // CFI types
  val CFI_SZ   = 3
  val CFI_X    = 0.U(CFI_SZ.W) // Not a CFI instruction
  val CFI_BR   = 1.U(CFI_SZ.W) // Branch
  val CFI_JAL  = 2.U(CFI_SZ.W) // JAL
  val CFI_JALR = 3.U(CFI_SZ.W) // JALR

  // PC Select Signal
  val PC_PLUS4 = 0.U(2.W)  // PC + 4
  val PC_BRJMP = 1.U(2.W)  // brjmp_target
  val PC_JALR  = 2.U(2.W)  // jump_reg_target

  // Branch Type
  val BR_N   = 0.U(4.W)  // Next
  val BR_NE  = 1.U(4.W)  // Branch on NotEqual
  val BR_EQ  = 2.U(4.W)  // Branch on Equal
  val BR_GE  = 3.U(4.W)  // Branch on Greater/Equal
  val BR_GEU = 4.U(4.W)  // Branch on Greater/Equal Unsigned
  val BR_LT  = 5.U(4.W)  // Branch on Less Than
  val BR_LTU = 6.U(4.W)  // Branch on Less Than Unsigned
  val BR_J   = 7.U(4.W)  // Jump
  val BR_JR  = 8.U(4.W)  // Jump Register

  // RS1 Operand Select Signal
  val OP1_RS1 = 0.U(2.W) // Register Source #1
  val OP1_ZERO= 1.U(2.W)
  val OP1_PC  = 2.U(2.W)
  val OP1_X   = BitPat("b??")

  // RS2 Operand Select Signal
  val OP2_RS2 = 0.U(3.W) // Register Source #2
  val OP2_IMM = 1.U(3.W) // immediate
  val OP2_ZERO= 2.U(3.W) // constant 0
  val OP2_NEXT= 3.U(3.W) // constant 2/4 (for PC+2/4)
  val OP2_IMMC= 4.U(3.W) // for CSR imm found in RS1
  val OP2_X   = BitPat("b???")

  // Register File Write Enable Signal
  val REN_0   = false.B
  val REN_1   = true.B

  // Is 32b Word or 64b Doubldword?
  val SZ_DW = 1
  val DW_X   = true.B // Bool(xLen==64)
  val DW_32  = false.B
  val DW_64  = true.B
  val DW_XPR = true.B // Bool(xLen==64)
```

### src/main/scala/common/package.scala

```scala
package boom

package object common extends
  boom.common.constants.ScalarOpConstants with
  boom.common.constants.ExcCauseConstants with
  boom.common.constants.RISCVConstants with
  boom.common.constants.IQType
{
}
```

### src/main/scala/ifu/fetch-target-queue.scala

```scala
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

### src/main/scala/util/util.scala

```scala
/**
 * Object to translate from BOOM's special "packed immediate" to a 32b signed immediate
 * Asking for U-type gives it shifted up 12 bits.
 */
object ImmGen
{
  import boom.common.{LONGEST_IMM_SZ, IS_B, IS_I, IS_J, IS_S, IS_U}
  def apply(ip: UInt, isel: UInt): SInt = {
    val sign = ip(LONGEST_IMM_SZ-1).asSInt
    val i30_20 = Mux(isel === IS_U, ip(18,8).asSInt, sign)
    val i19_12 = Mux(isel === IS_U || isel === IS_J, ip(7,0).asSInt, sign)
    val i11    = Mux(isel === IS_U, 0.S,
                 Mux(isel === IS_J || isel === IS_B, ip(8).asSInt, sign))
    val i10_5  = Mux(isel === IS_U, 0.S, ip(18,14).asSInt)
    val i4_1   = Mux(isel === IS_U, 0.S, ip(13,9).asSInt)
    val i0     = Mux(isel === IS_S || isel === IS_I, ip(8).asSInt, 0.S)

    return Cat(sign, i30_20, i19_12, i11, i10_5, i4_1, i0).asSInt
  }
}
```

### src/main/scala/rocket/ALU.scala

```scala
package freechips.rocketchip.rocket
// ...
object ALU
{
  val SZ_ALU_FN = 4
  def FN_X    = BitPat("b????")
  def FN_ADD  = UInt(0)
  def FN_SL   = UInt(1)
  def FN_SEQ  = UInt(2)
  def FN_SNE  = UInt(3)
  def FN_XOR  = UInt(4)
  def FN_SR   = UInt(5)
  def FN_OR   = UInt(6)
  def FN_AND  = UInt(7)
  def FN_SUB  = UInt(10)
  def FN_SRA  = UInt(11)
  def FN_SLT  = UInt(12)
  def FN_SGE  = UInt(13)
  def FN_SLTU = UInt(14)
  def FN_SGEU = UInt(15)

  def FN_DIV  = FN_XOR
  def FN_DIVU = FN_SR
  def FN_REM  = FN_OR
  def FN_REMU = FN_AND

  def FN_MUL    = FN_ADD
  def FN_MULH   = FN_SL
  def FN_MULHSU = FN_SEQ
  def FN_MULHU  = FN_SNE

  def isMulFN(fn: UInt, cmp: UInt) = fn(1,0) === cmp(1,0)
  def isSub(cmd: UInt) = cmd(3)
  def isCmp(cmd: UInt) = cmd >= FN_SLT
  def cmpUnsigned(cmd: UInt) = cmd(1)
  def cmpInverted(cmd: UInt) = cmd(0)
  def cmpEq(cmd: UInt) = !cmd(3)
}

import ALU._

class ALU(implicit p: Parameters) extends CoreModule()(p) {
  val io = new Bundle {
    val dw = Bits(INPUT, SZ_DW)
    val fn = Bits(INPUT, SZ_ALU_FN)
    val in2 = UInt(INPUT, xLen)
    val in1 = UInt(INPUT, xLen)
    val out = UInt(OUTPUT, xLen)
    val adder_out = UInt(OUTPUT, xLen)
    val cmp_out = Bool(OUTPUT)
  }
```

## Related source code

### src/main/scala/ifu/fetch-buffer.scala

```scala
      if (w == 0) {
        when (io.enq.bits.edge_inst(b)) {
          in_uops(i).debug_pc  := bankAlign(io.enq.bits.pc) + (b * bankBytes).U - 2.U
          in_uops(i).pc_lob    := bankAlign(io.enq.bits.pc) + (b * bankBytes).U
          in_uops(i).edge_inst := true.B
        }
      }
```

### src/main/scala/exu/core.scala

```scala
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
```

## Documentation

### docs/sections/execution-stages.rst

```text
Functional Unit
----------------

.. _abstract-fu:
.. figure:: /figures/abstract-functional-unit.png
    :alt: Abstract :term:`Functional Unit`

    The abstract Pipelined :term:`Functional Unit` class. An expert-written, low-level :term:`Functional Unit`
    is instantiated within the :term:`Functional Unit`. The request and response ports are abstracted and bypass and
    branch speculation support is provided. :term:`UOPs<Micro-Op (UOP)` are individually killed by gating off their response as they
    exit the low-level :term:`Functional Unit` .

:term:`Functional Unit` s are the muscle of the CPU, computing the necessary
operations as required by the instructions. :term:`Functional Unit` s typically
require a knowledgable domain expert to implement them correctly and
efficiently.

For this reason, BOOM uses an abstract :term:`Functional Unit` class to "wrap"
expert-written, low-level :term:`Functional Unit` s from the Rocket repository
(see :ref:`Rocket Chip SoC Generator`). However, the expert-written :term:`Functional Unit` s
created for the Rocket in-order processor make assumptions about
in-order issue and commit points (namely, that once an instruction has
been dispatched to them it will never need to be killed). These
assumptions break down for BOOM.

However, instead of re-writing or forking the :term:`Functional Unit` s, BOOM
provides an abstract :term:`Functional Unit` class (see :numref:`abstract-fu`)
that “wraps" the lower-level functional
units with the parameterized auto-generated support code needed to make
them work within BOOM. The request and response ports are abstracted,
allowing :term:`Functional Unit` s to provide a unified, interchangeable
interface.

Pipelined Functional Units
~~~~~~~~~~~~~~~~~~~~~~~~~~

A pipelined :term:`Functional Unit` can accept a new :term:`UOP<Micro-Op (UOP)` every cycle. Each
:term:`UOP<Micro-Op (UOP)` will take a known, fixed latency.

Speculation support is provided by auto-generating a pipeline that
passes down the :term:`UOP<Micro-Op (UOP)` meta-data and *branch mask* in parallel with
the :term:`UOP<Micro-Op (UOP)` within the expert-written :term:`Functional Unit` . If a :term:`UOP<Micro-Op (UOP)` is
misspeculated, it’s response is de-asserted as it exits the functional
unit.
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

The :term:`Front-end` must pass down the pipeline the appropriate branch
speculation meta-data, so that the correct direction can be reconciled
with the prediction. Jump Register instructions are evaluated by
comparing the correct target with the PC of the next instruction in the
ROB (if not available, then a misprediction is assumed). Jumps are
evaluated and handled in the :term:`Front-end` (as their direction and target
are both known once the instruction can be decoded).

BOOM (currently) only supports having one :term:`Branch Unit` .
```

### src/rv32.adoc

```text
==== Integer Register-Immediate Instructions

include::images/wavedrom/integer-computational.edn[]
//.Integer Computational Instructions

ADDI adds the sign-extended 12-bit immediate to register _rs1_.
Arithmetic overflow is ignored and the result is simply the low XLEN
bits of the result. ADDI _rd, rs1, 0_ is used to implement the MV _rd,
rs1_ assembler pseudoinstruction.

SLTI (set less than immediate) places the value 1 in register _rd_ if
register _rs1_ is less than the sign-extended immediate when both are
treated as signed numbers, else 0 is written to _rd_. SLTIU is similar
but compares the values as unsigned numbers (i.e., the immediate is
first sign-extended to XLEN bits then treated as an unsigned number).
Note, SLTIU _rd, rs1, 1_ sets _rd_ to 1 if _rs1_ equals zero, otherwise
sets _rd_ to 0 (assembler pseudoinstruction SEQZ _rd, rs_).

ANDI, ORI, XORI are logical operations that perform bitwise AND, OR, and
XOR on register _rs1_ and the sign-extended 12-bit immediate and place
the result in _rd_. Note, XORI _rd, rs1, -1_ performs a bitwise logical
inversion of register _rs1_ (assembler pseudoinstruction NOT _rd, rs_).

include::images/wavedrom/int-comp-slli-srli-srai.edn[]
[[int-comp-slli-srli-srai]]
//.Integer register-immediate, SLLI, SRLI, SRAI

Shifts by a constant are encoded as a specialization of the I-type
format. The operand to be shifted is in _rs1_, and the shift amount is
encoded in the lower 5 bits of the I-immediate field. The right shift
type is encoded in bit 30. SLLI is a logical left shift (zeros are
shifted into the lower bits); SRLI is a logical right shift (zeros are
shifted into the upper bits); and SRAI is an arithmetic right shift (the
original sign bit is copied into the vacated upper bits).

include::images/wavedrom/int-comp-lui-aiupc.edn[]
[[int-comp-lui-aiupc]]
//.Integer register-immediate, U-immediate

LUI (load upper immediate) is used to build 32-bit constants and uses
the U-type format. LUI places the 32-bit U-immediate value into the
destination register _rd_, filling in the lowest 12 bits with zeros.

AUIPC (add upper immediate to `pc`) is used to build `pc`-relative
addresses and uses the U-type format. AUIPC forms a 32-bit offset from
the U-immediate, filling in the lowest 12 bits with zeros, adds this
offset to the address of the AUIPC instruction, then places the result
in register _rd_.

[NOTE]
====
The assembly syntax for `lui` and `auipc` does not represent the lower
12 bits of the U-immediate, which are always zero.

The AUIPC instruction supports two-instruction sequences to access
arbitrary offsets from the PC for both control-flow transfers and data
accesses. The combination of an AUIPC and the 12-bit immediate in a JALR
can transfer control to any 32-bit PC-relative address, while an AUIPC
plus the 12-bit immediate offset in regular load or store instructions
can access any 32-bit PC-relative data address.

The current PC can be obtained by setting the U-immediate to 0. Although
a JAL +4 instruction could also be used to obtain the local PC (of the
instruction following the JAL), it might cause pipeline breaks in
simpler microarchitectures or pollute BTB structures in more complex
microarchitectures.
====

==== Integer Register-Register Operations

RV32I defines several arithmetic R-type operations. All operations read
the _rs1_ and _rs2_ registers as source operands and write the result
into register _rd_. The _funct7_ and _funct3_ fields select the type of
operation.

include::images/wavedrom/int-reg-reg.edn[]
[[int-reg-reg]]
//.Integer register-register

ADD performs the addition of _rs1_ and _rs2_. SUB performs the
subtraction of _rs2_ from _rs1_. Overflows are ignored and the low XLEN
bits of results are written to the destination _rd_. SLT and SLTU
perform signed and unsigned compares respectively, writing 1 to _rd_ if
_rs1_ < _rs2_, 0 otherwise. Note, SLTU _rd_, _x0_, _rs2_ sets _rd_ to 1 if
_rs2_ is not equal to zero, otherwise sets _rd_ to zero (assembler
pseudoinstruction SNEZ _rd, rs_). AND, OR, and XOR perform bitwise
logical operations.

SLL, SRL, and SRA perform logical left, logical right, and arithmetic
right shifts on the value in register _rs1_ by the shift amount held in
the lower 5 bits of register _rs2_.
...
==== Unconditional Jumps
The jump and link (JAL) instruction uses the J-type format, where the
J-immediate encodes a signed offset in multiples of 2 bytes. The offset
is sign-extended and added to the address of the jump instruction to
form the jump target address. Jumps can therefore target a
&#177;1 MiB range. JAL stores the address of the instruction
following the jump ('pc'+4) into register _rd_. The standard software
calling convention uses 'x1' as the return address register and 'x5' as
an alternate link register.
...
The indirect jump instruction JALR (jump and link register) uses the
I-type encoding. The target address is obtained by adding the
sign-extended 12-bit I-immediate to the register _rs1_, then setting the
least-significant bit of the result to zero. The address of the
instruction following the jump (`pc`+4) is written to register _rd_.
Register `x0` can be used as the destination if the result is not
required.
...
==== Conditional Branches

All branch instructions use the B-type instruction format. The 12-bit
B-immediate encodes signed offsets in multiples of 2 bytes. The offset
is sign-extended and added to the address of the branch instruction to
give the target address. The conditional branch range is
&#177;4 KiB.

include::images/wavedrom/ct-conditional.edn[]
[[ct-conditional]]
//.Conditional branches

Branch instructions compare two registers. BEQ and BNE take the branch
if registers _rs1_ and _rs2_ are equal or unequal respectively. BLT and
BLTU take the branch if _rs1_ is less than _rs2_, using signed and
unsigned comparison respectively. BGE and BGEU take the branch if _rs1_
is greater than or equal to _rs2_, using signed and unsigned comparison
respectively. Note, BGT, BGTU, BLE, and BLEU can be synthesized by
reversing the operands to BLT, BLTU, BGE, and BGEU, respectively.
```

### src/c-st-ext.adoc

```text
C.JR (jump register) performs an unconditional control transfer to the
address in register _rs1_. C.JR expands to `jalr x0, 0(rs1)`. C.JR is
valid only when _rs1_≠`x0`; the code
point with _rs1_=`x0` is reserved.

C.JALR (jump and link register) performs the same operation as C.JR, but
additionally writes the address of the instruction following the jump
(`pc`+2) to the link register, `x1`. C.JALR expands to
`jalr x1, 0(rs1)`. C.JALR is valid only when
_rs1_≠`x0`; the code point with
_rs1_=`x0` corresponds to the C.EBREAK
instruction.
```

### src/rv64.adoc

```text
=== Integer Computational Instructions

Most integer computational instructions operate on XLEN-bit values.
Additional instruction variants are provided to manipulate 32-bit values
in RV64I, indicated by a 'W' suffix to the opcode. These "*W"
instructions ignore the upper 32 bits of their inputs and always produce
32-bit signed values, sign-extending them to 64 bits, i.e. bits XLEN-1
through 31 are equal.

[NOTE]
====
The compiler and calling convention maintain an invariant that all
32-bit values are held in a sign-extended format in 64-bit registers.
Even 32-bit unsigned integers extend bit 31 into bits 63 through 32.
Consequently, conversion between unsigned and signed 32-bit integers is
a no-op, as is conversion from a signed 32-bit integer to a signed
64-bit integer. Existing 64-bit wide SLTU and unsigned branch compares
still operate correctly on unsigned 32-bit integers under this
invariant. Similarly, existing 64-bit wide logical operations on 32-bit
sign-extended integers preserve the sign-extension property. A few new
instructions (ADD[I]W/SUBW/SxxW) are required for addition and shifts to
ensure reasonable performance for 32-bit values.
====
(((RV64I, shifts)))
(((RV64I, compares)))

==== Integer Register-Immediate Instructions

include::images/wavedrom/rv64i-base-int.edn[]
[[rv64i-base-int]]
//.RV64I register-immediate instructions

ADDIW is an RV64I instruction that adds the sign-extended 12-bit
immediate to register _rs1_ and produces the proper sign extension of a
32-bit result in _rd_. Overflows are ignored and the result is the low
32 bits of the result sign-extended to 64 bits. Note, ADDIW _rd, rs1, 0_
writes the sign extension of the lower 32 bits of register _rs1_ into
register _rd_ (assembler pseudoinstruction SEXT.W).

include::images/wavedrom/rv64i-slli.edn[]
[[rv64i-slli]]
//.RV64I register-immediate (descr ADDIW) instructions

Shifts by a constant are encoded as a specialization of the I-type
format using the same instruction opcode as RV32I. The operand to be
shifted is in _rs1_, and the shift amount is encoded in the lower 6 bits
of the I-immediate field for RV64I. The right shift type is encoded in
bit 30. SLLI is a logical left shift (zeros are shifted into the lower
bits); SRLI is a logical right shift (zeros are shifted into the upper
bits); and SRAI is an arithmetic right shift (the original sign bit is
copied into the vacated upper bits).
(((RV64I, SLLI)))
(((RV64I, SRKIW)))
(((RV64I, SRLIW)))
(((RV64I, RV64I-only)))

include::images/wavedrom/rv64i-slliw.edn[]
[[rv64i-slliw]]

SLLIW, SRLIW, and SRAIW are RV64I-only instructions that are analogously
defined but operate on 32-bit values and sign-extend their 32-bit
results to 64 bits. SLLIW, SRLIW, and SRAIW encodings with
_imm[5] &#8800; 0_ are reserved.

[NOTE]
====
Previously, SLLIW, SRLIW, and SRAIW with _imm[5] &#8800; 0_
were defined to cause illegal-instruction exceptions, whereas now they
are marked as reserved. This is a backwards-compatible change.
====

include::images/wavedrom/rv64-lui-auipc.edn[]
[[rv64_lui-auipc]]
//.RV64I register-immediate (descr) instructions

LUI (load upper immediate) uses the same opcode as RV32I. LUI places the
32-bit U-immediate into register _rd_, filling in the lowest 12 bits
with zeros. The 32-bit result is sign-extended to 64 bits.
(((RV64I, LUI)))

AUIPC (add upper immediate to `pc`) uses the same opcode as RV32I. AUIPC
is used to build `pc`-relative addresses and uses the U-type format.
AUIPC forms a 32-bit offset from the U-immediate, filling in the lowest
12 bits with zeros, sign-extends the result to 64 bits, adds it to the
address of the AUIPC instruction, then places the result in register
_rd_.

[NOTE]
====
Note that the set of address offsets that can be formed by pairing LUI
with LD, AUIPC with JALR, etc. in RV64I is
[latexmath:[${-}2^{31}{-}2^{11}$], latexmath:[$2^{31}{-}2^{11}{-}1$]].
====

==== Integer Register-Register Operations

//this diagramdoesn't match the tex specification
include::images/wavedrom/rv64i-int-reg-reg.edn[]
[[int_reg-reg]]
//.RV64I integer register-register instructions

ADDW and SUBW are RV64I-only instructions that are defined analogously
to ADD and SUB but operate on 32-bit values and produce signed 32-bit
results. Overflows are ignored, and the low 32-bits of the result is
sign-extended to 64-bits and written to the destination register.
(((RV64I-only, ADDW)))
(((RV64I-only, SUBW)))

SLL, SRL, and SRA perform logical left, logical right, and arithmetic
right shifts on the value in register _rs1_ by the shift amount held in
register _rs2_. In RV64I, only the low 6 bits of _rs2_ are considered
for the shift amount.

SLLW, SRLW, and SRAW are RV64I-only instructions that are analogously
defined but operate on 32-bit values and sign-extend their 32-bit
results to 64 bits. The shift amount is given by _rs2[4:0]_.
```
