# Implement `TageBranchPredictorBank`

Implement the complete `TageBranchPredictorBank` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Keep the declarations under Dependency declarations in the fixed source and do not resubmit them.

Return only the complete `class TageBranchPredictorBank` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package boom.ifu

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.{Field, Parameters}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tilelink._

import boom.common._
import boom.util.{BoomCoreStringPrefix, MaskLower, WrapInc}

import scala.math.min
```

## Class declaration

```scala
class TageBranchPredictorBank(params: BoomTageParams = BoomTageParams())(implicit p: Parameters) extends BranchPredictorBank()(p)
{
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/ifu/bpd/tage.scala`

```scala
class TageResp extends Bundle {
  val ctr = UInt(3.W)
  val u   = UInt(2.W)
}

class TageTable(val nRows: Int, val tagSz: Int, val histLength: Int, val uBitPeriod: Int)
  (implicit p: Parameters) extends BoomModule()(p)
  with HasBoomFrontendParameters
{
  require(histLength <= globalHistoryLength)

  val nWrBypassEntries = 2
  val io = IO( new Bundle {
    val f1_req_valid = Input(Bool())
    val f1_req_pc    = Input(UInt(vaddrBitsExtended.W))
    val f1_req_ghist = Input(UInt(globalHistoryLength.W))

    val f3_resp = Output(Vec(bankWidth, Valid(new TageResp)))

    val update_mask    = Input(Vec(bankWidth, Bool()))
    val update_taken   = Input(Vec(bankWidth, Bool()))
    val update_alloc   = Input(Vec(bankWidth, Bool()))
    val update_old_ctr = Input(Vec(bankWidth, UInt(3.W)))

    val update_pc    = Input(UInt())
    val update_hist  = Input(UInt())

    val update_u_mask = Input(Vec(bankWidth, Bool()))
    val update_u = Input(Vec(bankWidth, UInt(2.W)))
  })

// ...

  val mems = Seq((f"tage_l$histLength", nRows, bankWidth * tageEntrySz))

// ...

case class BoomTageParams(
  //                                           nSets, histLen, tagSz
  tableInfo: Seq[Tuple3[Int, Int, Int]] = Seq((  128,       2,     7),
                                              (  128,       4,     7),
                                              (  256,       8,     8),
                                              (  256,      16,     8),
                                              (  128,      32,     9),
                                              (  128,      64,     9)),
  uBitPeriod: Int = 2048
)
```

### `src/main/scala/ifu/bpd/predictor.scala`

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

// ...

// A branch update to a single bank
class BranchPredictionBankUpdate(implicit p: Parameters) extends BoomBundle()(p)
  with HasBoomFrontendParameters
{
  val is_mispredict_update     = Bool()
  val is_repair_update         = Bool()

  val btb_mispredicts  = UInt(bankWidth.W)
  def is_btb_mispredict_update = btb_mispredicts =/= 0.U

  def is_commit_update = !(is_mispredict_update || is_repair_update || is_btb_mispredict_update)

  val pc               = UInt(vaddrBitsExtended.W)

  val br_mask          = UInt(bankWidth.W)
  val cfi_idx          = Valid(UInt(log2Ceil(bankWidth).W))
  val cfi_taken        = Bool()
  val cfi_mispredicted = Bool()

  val cfi_is_br        = Bool()
  val cfi_is_jal       = Bool()
  val cfi_is_jalr      = Bool()

  val ghist            = UInt(globalHistoryLength.W)
  val lhist            = UInt(localHistoryLength.W)

  val target           = UInt(vaddrBitsExtended.W)

  val meta             = UInt(bpdMaxMetaLength.W)
}

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

abstract class BranchPredictorBank(implicit p: Parameters) extends BoomModule()(p)
  with HasBoomFrontendParameters
{
  val metaSz = 0
  def nInputs = 1

  val mems: Seq[Tuple3[String, Int, Int]]

  val io = IO(new Bundle {
    val f0_valid = Input(Bool())
    val f0_pc    = Input(UInt(vaddrBitsExtended.W))
    val f0_mask  = Input(UInt(bankWidth.W))
    // Local history not available until end of f1
    val f1_ghist = Input(UInt(globalHistoryLength.W))
    val f1_lhist = Input(UInt(localHistoryLength.W))

    val resp_in = Input(Vec(nInputs, new BranchPredictionBankResponse))
    val resp = Output(new BranchPredictionBankResponse)

    // Store the meta as a UInt, use width inference to figure out the shape
    val f3_meta = Output(UInt(bpdMaxMetaLength.W))

    val f3_fire = Input(Bool())

    val update = Input(Valid(new BranchPredictionBankUpdate))
  })
  io.resp := io.resp_in(0)

  io.f3_meta := 0.U

  val s0_idx       = fetchIdx(io.f0_pc)
  val s1_idx       = RegNext(s0_idx)
  val s2_idx       = RegNext(s1_idx)
  val s3_idx       = RegNext(s2_idx)

  val s0_valid = io.f0_valid
  val s1_valid = RegNext(s0_valid)
  val s2_valid = RegNext(s1_valid)
  val s3_valid = RegNext(s2_valid)

  val s0_mask = io.f0_mask
  val s1_mask = RegNext(s0_mask)
  val s2_mask = RegNext(s1_mask)
  val s3_mask = RegNext(s2_mask)

  val s0_pc = io.f0_pc
  val s1_pc = RegNext(s0_pc)

  val s0_update     = io.update
  val s0_update_idx = fetchIdx(io.update.bits.pc)
  val s0_update_valid = io.update.valid

  val s1_update     = RegNext(s0_update)
  val s1_update_idx = RegNext(s0_update_idx)
  val s1_update_valid = RegNext(s0_update_valid)



}
```

## Documentation

### `docs/sections/branch-prediction/backing-predictor.rst`

```text
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

...

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

...

**TAGE (TAgged GEometric)** is implemented as a collection of predictor
tables. Each table entry contains a *prediction counter*, a
*usefulness counter*, and a *tag*. The *prediction counter*
provides the prediction (and maintains some hysteresis as to how
strongly biased the prediction is towards taken or not-taken). The
*usefulness counter* tracks how useful the particular entry has been
in the past for providing correct predictions. The *tag* allows the
table to only make a prediction if there is a tag match for the
particular requesting instruction address and global history.

Each table has a different (and geometrically increasing) amount of
history associated with it. Each table’s history is used to hash with
the requesting instruction address to produce an index hash and a tag
hash. Each table will make its own prediction (or no prediction, if
there is no tag match). The table with the longest history making a
prediction wins.

On a misprediction, **TAGE** attempts to allocate a new entry. It will only
overwrite an entry that is "not useful" (ubits == 0).

...

Usefulness counters (u-bits)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The “usefulness” of an entry is stored in the *u-bit* counters.
Roughly speaking, if an entry provides a correct prediction, the u-bit
counter is incremented. If an entry provides an incorrect prediction,
the u-bit counter is decremented. When a misprediction occurs, **TAGE**
attempts to allocate a new entry. To prevent overwriting a useful entry,
it will only allocate an entry if the existing entry has a usefulness of
zero. However, if an entry allocation fails because all of the potential
entries are useful, then all of the potential entries are decremented to
potentially make room for an allocation in the future.

To prevent **TAGE** from filling up with only useful but rarely-used
entries, **TAGE** must provide a scheme for "degrading" the u-bits over
time. A number of schemes are available. One option is a timer that
periodically degrades the u-bit counters. Another option is to track the
number of failed allocations (incrementing on a failed allocation and
decremented on a successful allocation). Once the counter has saturated,
all u-bits are degraded.
```

## Additional requirement

In the evaluated configuration `bpdMaxMetaLength` is 64, so `io.f3_meta` and `io.update.bits.meta` carry 64 bits.
