# Implement `Rob`

Implement the complete `Rob` module. Preserve its class declaration and public interfaces shown below. Return only the complete `class Rob` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `generators/chipyard/src/main/scala/config/BoomConfigs.scala`

```scala
class LargeBoomConfig extends Config(
  new boom.common.WithNLargeBooms(1) ++                          // large boom config
  new chipyard.config.AbstractConfig)
```

### `src/main/scala/common/config-mixins.scala`

```scala
              decodeWidth = 3,
              numRobEntries = 96,
```

### `src/main/scala/common/parameters.scala`

```scala
  enableCommitMapTable: Boolean = false,
  enableFastPNR: Boolean = false,
// ...
  // coreWidth is width of decode, width of integer rename, width of ROB, and commit width
  val coreWidth = decodeWidth
// ...
  val numRobEntries = boomParams.numRobEntries       // number of ROB entries (e.g., 32 entries for R10k)
// ...
  val enableCommitMapTable = boomParams.enableCommitMapTable
  require(!enableCommitMapTable) // TODO Fix the commit map table.
  val enableFastPNR = boomParams.enableFastPNR
// ...
  val numRobRows      = numRobEntries/coreWidth
  val robAddrSz       = log2Ceil(numRobRows) + log2Ceil(coreWidth)
```

## Package and imports

```scala
//******************************************************************************
// Copyright (c) 2013 - 2018, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE and LICENSE.SiFive for license details.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// Re-order Buffer
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//
// Bank the ROB, such that each "dispatch" group gets its own row of the ROB,
// and each instruction in the dispatch group goes to a different bank.
// We can compress out the PC by only saving the high-order bits!
//
// ASSUMPTIONS:
//    - dispatch groups are aligned to the PC.
//
// NOTES:
//    - Currently we do not compress out bubbles in the ROB.
//    - Exceptions are only taken when at the head of the commit bundle --
//      this helps deal with loads, stores, and refetch instructions.

package boom.exu

import scala.math.ceil

import chisel3._
import chisel3.util._
import chisel3.experimental.chiselName

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.util.Str

import boom.common._
import boom.util._
```

## Class declaration

```scala
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
```

## Parent instantiation

### `src/main/scala/exu/core.scala`

```scala
  val rob              = Module(new Rob(
                           numIrfWritePorts + numFpWakeupPorts, // +memWidth for ll writebacks
                           numFpWakeupPorts))
// ...
  //-------------------------------------------------------------
  // Rob Allocation Logic

  rob.io.enq_valids := dis_fire
  rob.io.enq_uops   := dis_uops
  rob.io.enq_partial_stall := dis_stalls.last // TODO come up with better ROB compacting scheme.
  rob.io.debug_tsc := debug_tsc_reg
  rob.io.csr_stall := csr.io.csr_stall
// ...
  // Writeback
  // ---------
  // First connect the ll_wport
  val ll_uop = ll_wbarb.io.out.bits.uop
  rob.io.wb_resps(0).valid  := ll_wbarb.io.out.valid && !(ll_uop.uses_stq && !ll_uop.is_amo)
  rob.io.wb_resps(0).bits   <> ll_wbarb.io.out.bits
  rob.io.debug_wb_valids(0) := ll_wbarb.io.out.valid && ll_uop.dst_rtype =/= RT_X
  rob.io.debug_wb_wdata(0)  := ll_wbarb.io.out.bits.data
  var cnt = 1
  for (i <- 1 until memWidth) {
    val mem_uop = mem_resps(i).bits.uop
    rob.io.wb_resps(cnt).valid := mem_resps(i).valid && !(mem_uop.uses_stq && !mem_uop.is_amo)
    rob.io.wb_resps(cnt).bits  := mem_resps(i).bits
    rob.io.debug_wb_valids(cnt) := mem_resps(i).valid && mem_uop.dst_rtype =/= RT_X
    rob.io.debug_wb_wdata(cnt)  := mem_resps(i).bits.data
    cnt += 1
  }
  var f_cnt = 0 // rob fflags port index
  for (eu <- exe_units) {
    if (eu.writesIrf)
    {
      val resp   = eu.io.iresp
      val wb_uop = resp.bits.uop
      val data   = resp.bits.data

      rob.io.wb_resps(cnt).valid := resp.valid && !(wb_uop.uses_stq && !wb_uop.is_amo)
      rob.io.wb_resps(cnt).bits  <> resp.bits
      rob.io.debug_wb_valids(cnt) := resp.valid && wb_uop.rf_wen && wb_uop.dst_rtype === RT_FIX
      if (eu.hasFFlags) {
        rob.io.fflags(f_cnt) <> resp.bits.fflags
        f_cnt += 1
      }
      if (eu.hasCSR) {
        rob.io.debug_wb_wdata(cnt) := Mux(wb_uop.ctrl.csr_cmd =/= freechips.rocketchip.rocket.CSR.N,
          csr.io.rw.rdata,
          data)
      } else {
        rob.io.debug_wb_wdata(cnt) := data
      }
      cnt += 1
    }
  }

  require(cnt == numIrfWritePorts)
  if (usingFPU) {
    for ((wdata, wakeup) <- fp_pipeline.io.debug_wb_wdata zip fp_pipeline.io.wakeups) {
      rob.io.wb_resps(cnt) <> wakeup
      rob.io.fflags(f_cnt) <> wakeup.bits.fflags
      rob.io.debug_wb_valids(cnt) := wakeup.valid
      rob.io.debug_wb_wdata(cnt) := wdata
      cnt += 1
      f_cnt += 1

      assert (!(wakeup.valid && wakeup.bits.uop.dst_rtype =/= RT_FLT),
        "[core] FP wakeup does not write back to a FP register.")

      assert (!(wakeup.valid && !wakeup.bits.uop.fp_val),
        "[core] FP wakeup does not involve an FP instruction.")
    }
  }
// ...
  require (cnt == rob.numWakeupPorts)
  require (f_cnt == rob.numFpuPorts)

  // branch resolution
  rob.io.brupdate <> brupdate
// ...
  // LSU <> ROB
  rob.io.lsu_clr_bsy    := io.lsu.clr_bsy
  rob.io.lsu_clr_unsafe := io.lsu.clr_unsafe
  rob.io.lxcpt          <> io.lsu.lxcpt
// ...
  assert (!(rob.io.com_xcpt.valid && !rob.io.flush.valid),
    "[core] exception occurred, but pipeline flush signal not set!")
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/exu/rob.scala`

```scala
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
```

### `src/main/scala/exu/execution-units/functional-unit.scala`

```scala
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
```

### `src/main/scala/common/micro-op.scala`

```scala
  val uopc             = UInt(UOPC_SZ.W)       // micro-op code
  val inst             = UInt(32.W)
  val debug_inst       = UInt(32.W)
  val is_rvc           = Bool()
// ...
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
// ...
  val rob_idx          = UInt(robAddrSz.W)
// ...
  val pdst             = UInt(maxPregSz.W)
// ...
  val stale_pdst       = UInt(maxPregSz.W)
  val exception        = Bool()
  val exc_cause        = UInt(xLen.W)          // TODO compress this down, xlen is insanity
// ...
  val is_fence         = Bool()
  val is_fencei        = Bool()
  val is_amo           = Bool()
  val uses_ldq         = Bool()
  val uses_stq         = Bool()
  val is_sys_pc2epc    = Bool()                      // Is a ECall or Breakpoint -- both set EPC to PC.
  val is_unique        = Bool()                      // only allow this instruction in the pipeline, wait for STQ to
                                                     // drain, clear fetcha fter it (tell ROB to un-ready until empty)
  val flush_on_commit  = Bool()                      // some instructions need to flush the pipeline behind them
// ...
  // logical specifiers (only used in Decode->Rename), except rollback (ldst)
  val ldst             = UInt(lregSz.W)
  val lrs1             = UInt(lregSz.W)
  val lrs2             = UInt(lregSz.W)
  val lrs3             = UInt(lregSz.W)

  val ldst_val         = Bool()              // is there a destination? invalid for stores, rd==x0, etc.
  val dst_rtype        = UInt(2.W)
// ...
  // floating point information
  val fp_val           = Bool()             // is a floating-point instruction (F- or D-extension)?
                                            // If it's non-ld/st it will write back exception bits to the fcsr.
  val fp_single        = Bool()             // single-precision floating point instruction (F-extension)
// ...
  // What prediction structure provides the prediction FROM this op
  val debug_fsrc       = UInt(BSRC_SZ.W)
// ...
  // Does this register write-back
  def rf_wen           = dst_rtype =/= RT_X

  // Is it possible for this uop to misspeculate, preventing the commit of subsequent uops?
  def unsafe           = uses_ldq || (uses_stq && !is_fence) || is_br || is_jalr

```

### `src/main/scala/common/consts.scala`

```scala
  val BSRC_C = 3.U(BSRC_SZ.W) // core branch resolution
// ...
  val RT_X     = 2.U(2.W) // not-a-register (but shouldn't get a busy-bit, etc.)
// ...
  val uopERET      = 106.U(UOPC_SZ.W) // pass uop down the CSR pipeline, also is ERET
// ...
  val BUBBLE  = (0x4033).U(32.W)
// ...
/**
 * Mixin for exception cause constants
 */
trait ExcCauseConstants
{
  // a memory disambigious misspeculation occurred
  val MINI_EXCEPTION_MEM_ORDERING = 16.U

  require (!freechips.rocketchip.rocket.Causes.all.contains(16))
}
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

/**
 * Object to return new MicroOp with a new BR mask given a MicroOp mask
 * and old BR mask.
 */
object GetNewUopAndBrMask
{
  def apply(uop: MicroOp, brupdate: BrUpdateInfo)
    (implicit p: Parameters): MicroOp = {
    val newuop = WireInit(uop)
    newuop.br_mask := uop.br_mask & ~brupdate.b1.resolve_mask
    newuop
  }
}

/**
 * Object to return a BR mask given a MicroOp mask and old BR mask.
 */
object GetNewBrMask
{
   def apply(brupdate: BrUpdateInfo, uop: MicroOp): UInt = {
     return uop.br_mask & ~brupdate.b1.resolve_mask
   }

   def apply(brupdate: BrUpdateInfo, br_mask: UInt): UInt = {
     return br_mask & ~brupdate.b1.resolve_mask
   }
}
// ...
/**
 * Object to increment an input value, wrapping it if
 * necessary.
 */
object WrapInc
{
  // "n" is the number of increments, so we wrap at n-1.
  def apply(value: UInt, n: Int): UInt = {
    if (isPow2(n)) {
      (value + 1.U)(log2Ceil(n)-1,0)
    } else {
      val wrap = (value === (n-1).U)
      Mux(wrap, 0.U, value + 1.U)
    }
  }
}

/**
 * Object to decrement an input value, wrapping it if
 * necessary.
 */
object WrapDec
{
  // "n" is the number of increments, so we wrap at n-1.
  def apply(value: UInt, n: Int): UInt = {
    if (isPow2(n)) {
      (value - 1.U)(log2Ceil(n)-1,0)
    } else {
      val wrap = (value === 0.U)
      Mux(wrap, (n-1).U, value - 1.U)
    }
  }
}
// ...
/**
 * Object to mask off lower bits of a PC to align to a "b"
 * Byte boundary.
 */
object AlignPCToBoundary
{
  def apply(pc: UInt, b: Int): UInt = {
    // Invert for scenario where pc longer than b
    //   (which would clear all bits above size(b)).
    ~(~pc | (b-1).U)
  }
}
// ...
/**
 * Object to return the lowest bit position after the head.
 */
object AgePriorityEncoder
{
  def apply(in: Seq[Bool], head: UInt): UInt = {
    val n = in.size
    val width = log2Ceil(in.size)
    val n_padded = 1 << width
    val temp_vec = (0 until n_padded).map(i => if (i < n) in(i) && i.U >= head else false.B) ++ in
    val idx = PriorityEncoder(temp_vec)
    idx(width-1, 0) //discard msb
  }
}

/**
  * Object to determine whether queue
  * index i0 is older than index i1.
 */
object IsOlder
{
  def apply(i0: UInt, i1: UInt, head: UInt) = ((i0 < i1) ^ (i0 < head) ^ (i1 < head))
}

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
```

## Documentation

### `docs/sections/reorder-buffer.rst`

```text
.. _rob-dispatch-stage:

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

The ROB Organization
--------------------

.. _rob:
.. figure:: /figures/rob.png
    :alt: The Reorder Buffer

    The Reorder Buffer for a two-wide BOOM with three-issue. Dispatched uops (dis uops) are
    written at the bottom of the ROB (rob tail), while committed uops (com uops) are committed from the top,
    at rob head, and update the rename state. Uops that finish executing (wb uops) clear their busy bit. Note:
    the dispatched uops are written into the same ROB row together, and are located consecutively in memory
    allowing a single PC to represent the entire row.

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

ROB State
---------

Each ROB entry contains relatively little state:

-  is entry valid?

-  is entry busy?

-  is entry an exception?

-  branch mask (which branches is this entry still speculated under?

-  rename state (what is the logical destination and the stale physical
   destination?)

-  floating-point status updates

-  other miscellaneous data (e.g., helpful for statistic tracking)

The PC and the branch prediction information is stored on a per-row
basis (see :ref:`PC Storage`). The **Exception State** only tracks the
oldest known excepting instruction (see :ref:`Exception State`).

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

Causes
~~~~~~

The RV64G ISA provides relatively few exception sources:

    Load/Store Unit
        - page faults

    :term:`Branch Unit`
        - misaligned fetches

    **Decode** Stage
        - all other exceptions and interrupts can be handled before the
          instruction is dispatched to the ROB

Note that memory ordering speculation errors also originate from the
Load/Store Unit, and are treated as exceptions in the BOOM pipeline
(actually they only cause a pipeline “retry").

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
