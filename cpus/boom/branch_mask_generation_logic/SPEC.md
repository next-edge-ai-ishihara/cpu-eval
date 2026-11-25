# Implement `BranchMaskGenerationLogic`

Implement one complete `BranchMaskGenerationLogic` Chisel definition. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class BranchMaskGenerationLogic` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package boom.exu

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.Parameters
// ...
import boom.common._
import boom.util._
```

## Class declaration

```scala
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

## Parent instantiation

### src/main/scala/exu/core.scala

```scala
  val dec_brmask_logic = Module(new BranchMaskGenerationLogic(coreWidth))
  // ...
  // "Merged" branch update info from all ALUs
  // brmask contains masks for rapidly clearing mispredicted instructions
  // brindices contains indices to reset pointers for allocated structures
  //           brindices is delayed a cycle
  val brupdate  = Wire(new BrUpdateInfo)
  val b1    = Wire(new BrUpdateMasks)
  val b2    = Reg(new BrResolutionInfo)

  brupdate.b1 := b1
  brupdate.b2 := b2

  for ((b, a) <- brinfos zip exe_units.alu_units) {
    b := a.io.brinfo
    b.valid := a.io.brinfo.valid && !rob.io.flush.valid
  }
  b1.resolve_mask := brinfos.map(x => x.valid << x.uop.br_tag).reduce(_|_)
  b1.mispredict_mask := brinfos.map(x => (x.valid && x.mispredict) << x.uop.br_tag).reduce(_|_)
  // ...
  b2.mispredict  := mispredict_val
  b2.cfi_type    := oldest_mispredict.cfi_type
  b2.taken       := oldest_mispredict.taken
  b2.pc_sel      := oldest_mispredict.pc_sel
  b2.uop         := UpdateBrMask(brupdate, oldest_mispredict.uop)
  b2.jalr_target := RegNext(jmp_unit.io.brinfo.jalr_target)
  b2.target_offset := oldest_mispredict.target_offset
  // ...
  // stall fetch/dcode because we ran out of branch tags
  val branch_mask_full = Wire(Vec(coreWidth, Bool()))

  val dec_hazards = (0 until coreWidth).map(w =>
                      dec_valids(w) &&
                      (  !dis_ready
                      || rob.io.commit.rollback
                      || dec_xcpt_stall
                      || branch_mask_full(w)
                      || brupdate.b1.mispredict_mask =/= 0.U
                      || brupdate.b2.mispredict
                      || io.ifu.redirect_flush))

  val dec_stalls = dec_hazards.scanLeft(false.B) ((s,h) => s || h).takeRight(coreWidth)
  dec_fire := (0 until coreWidth).map(w => dec_valids(w) && !dec_stalls(w))
  // ...
  //-------------------------------------------------------------
  // Branch Mask Logic

  dec_brmask_logic.io.brupdate := brupdate
  dec_brmask_logic.io.flush_pipeline := RegNext(rob.io.flush.valid)

  for (w <- 0 until coreWidth) {
    dec_brmask_logic.io.is_branch(w) := !dec_finished_mask(w) && dec_uops(w).allocate_brtag
    dec_brmask_logic.io.will_fire(w) :=  dec_fire(w) &&
                                         dec_uops(w).allocate_brtag // ren, dis can back pressure us
    dec_uops(w).br_tag  := dec_brmask_logic.io.br_tag(w)
    dec_uops(w).br_mask := dec_brmask_logic.io.br_mask(w)
  }

  branch_mask_full := dec_brmask_logic.io.is_full
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

### src/main/scala/util/util.scala

```scala
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
```

### src/main/scala/common/micro-op.scala

```scala
class MicroOp(implicit p: Parameters) extends BoomBundle
  // ...
  val br_mask          = UInt(maxBrCount.W)  // which branches are we being speculated under?
  val br_tag           = UInt(brTagSz.W)
  // ...
  // Do we allocate a branch tag for this?
  // SFB branches don't get a mask, they get a predicate bit
  def allocate_brtag   = (is_br && !is_sfb) || is_jalr
```

### src/main/scala/common/parameters.scala

```scala
trait HasBoomCoreParameters extends freechips.rocketchip.tile.HasCoreParameters
{
  // ...
  // coreWidth is width of decode, width of integer rename, width of ROB, and commit width
  val coreWidth = decodeWidth
  // ...
  val maxBrCount    = boomParams.maxBrCount          // number of branches we can speculate simultaneously
  // ...
  val brTagSz         = log2Ceil(maxBrCount)
```

## Documentation

### docs/sections/execution-stages.rst

```text
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
```

## Additional requirement

`br_mask` and the next `debug_branch_mask` exclude the tags in the current cycle's `brupdate.b1.resolve_mask`, and no tag in that mask is handed out on `br_tag` in the same cycle.
