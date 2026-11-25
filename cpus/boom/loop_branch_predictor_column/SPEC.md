# Implement `LoopBranchPredictorColumn`

Implement one complete `LoopBranchPredictorColumn` source-level hardware definition. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class LoopBranchPredictorColumn` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package boom.ifu

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.{Field, Parameters}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tilelink._

import boom.common._
import boom.util.{BoomCoreStringPrefix}

import scala.math.min
```

## Class declaration

```scala
  class LoopBranchPredictorColumn extends Module {



    val io = IO(new Bundle {
      val f2_req_valid = Input(Bool())
      val f2_req_idx  = Input(UInt())
      val f3_req_fire = Input(Bool())

      val f3_pred_in  = Input(Bool())
      val f3_pred     = Output(Bool())
      val f3_meta     = Output(new LoopMeta)

      val update_mispredict = Input(Bool())
      val update_repair     = Input(Bool())
      val update_idx   = Input(UInt())
      val update_resolve_dir = Input(Bool())
      val update_meta  = Input(new LoopMeta)
    })
```

## Parent instantiation

### `src/main/scala/ifu/bpd/loop.scala`

```scala
class LoopBranchPredictorBank(implicit p: Parameters) extends BranchPredictorBank()(p)
{
  val tagSz = 10
  override val nSets = 16



  class LoopMeta extends Bundle {
    val s_cnt   = UInt(10.W)
  }

  class LoopEntry extends Bundle {
    val tag   = UInt(tagSz.W)
    val conf  = UInt(3.W)
    val age   = UInt(3.W)
    val p_cnt = UInt(10.W)
    val s_cnt = UInt(10.W)
  }
// ...
  val columns = Seq.fill(bankWidth) { Module(new LoopBranchPredictorColumn) }
  val mems = Nil // TODO fix
  val f3_meta = Wire(Vec(bankWidth, new LoopMeta))
  override val metaSz = f3_meta.asUInt.getWidth

  val update_meta = s1_update.bits.meta.asTypeOf(Vec(bankWidth, new LoopMeta))

  for (w <- 0 until bankWidth) {
    columns(w).io.f2_req_valid := s2_valid
    columns(w).io.f2_req_idx  := s2_idx
    columns(w).io.f3_req_fire := (s3_valid && s3_mask(w) && io.f3_fire &&
      RegNext(io.resp_in(0).f2(w).predicted_pc.valid && io.resp_in(0).f2(w).is_br))

    columns(w).io.f3_pred_in  := io.resp_in(0).f3(w).taken
    io.resp.f3(w).taken       := columns(w).io.f3_pred

    columns(w).io.update_mispredict      := (s1_update.valid &&
                                             s1_update.bits.br_mask(w) &&
                                             s1_update.bits.is_mispredict_update &&
                                             s1_update.bits.cfi_mispredicted)
    columns(w).io.update_repair          := (s1_update.valid &&
                                             s1_update.bits.br_mask(w) &&
                                            s1_update.bits.is_repair_update)
    columns(w).io.update_idx             := s1_update_idx
    columns(w).io.update_resolve_dir     := s1_update.bits.cfi_taken
    columns(w).io.update_meta            := update_meta(w)

    f3_meta(w) := columns(w).io.f3_meta
  }
```

### `src/main/scala/common/config-mixins.scala`

```scala
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
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

## Documentation

### `docs/sections/branch-prediction/backing-predictor.rst`

```text
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
```

## Additional requirement

When `update_repair` is asserted and `update_idx` equals the `f2_req_idx` of the request in f2 or in f3 in that cycle, `f3_meta.s_cnt` of that request is `update_meta.s_cnt`, and after a loop of at least 12 instructions has run 32 times with the same iteration count of at most 1000 while `f3_pred_in` was true for its closing conditional branch at every execution, `f3_pred` is false for that branch on the last iteration in at least half of the following runs.
