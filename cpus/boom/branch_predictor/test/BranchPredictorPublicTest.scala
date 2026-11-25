package boom.tests

import boom.common._
import boom.ifu._
import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.system.BaseConfig
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._
import org.scalatest.flatspec.AnyFlatSpec

class BranchPredictorHarness(implicit p: Parameters) extends LazyModule {
  val visibility = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("00000fff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibility := fuzz.node }
  lazy val module = new BranchPredictorHarnessModule(this)
}

class BranchPredictorHarnessModule(outer: BranchPredictorHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case a: BoomTileAttachParams => a.tileParams
  }.get
  private val parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibility
  }
  private val predictor = Module(new BranchPredictor()(parameters))
  val io = IO(chiselTypeOf(predictor.io))
  io <> predictor.io
}

class BranchPredictorPublicTester(c: BranchPredictorHarnessModule) extends PeekPokeTester(c) {
  private val base = BigInt("80000000", 16)
  private val startInBank1 = base + 8
  private val nextBank0 = base + 16
  private val firstTarget = base + 0x420
  private val middleTarget = base + 0x4a0
  private val nextTarget = base + 0x530
  private var comparisons = 0

  private def clearHistory(history: GlobalHistory): Unit = {
    poke(history.old_history, 0)
    poke(history.current_saw_branch_not_taken, 0)
    poke(history.new_saw_branch_not_taken, 0)
    poke(history.new_saw_branch_taken, 0)
    poke(history.ras_idx, 0)
  }

  private def setHistory(history: GlobalHistory, older: BigInt, previousTaken: Boolean): Unit = {
    poke(history.old_history, older)
    poke(history.new_saw_branch_taken, if (previousTaken) 1 else 0)
  }

  private def request(pc: BigInt, history: BigInt = 0, previousTaken: Boolean = false): Unit = {
    poke(c.io.f0_req.valid, 1)
    poke(c.io.f0_req.bits.pc, pc)
    setHistory(c.io.f0_req.bits.ghist, history, previousTaken)
  }

  private def train(pc: BigInt, position: Int, target: BigInt, conditional: Boolean = false,
                    taken: Boolean = true, history: BigInt = 0, previousTaken: Boolean = false): Unit = {
    request(pc, history, previousTaken)
    step(3)
    val metadata = c.io.resp.f3.meta.map(value => peek(value)).toList
    val localHistory = c.io.resp.f3.lhist.map(value => peek(value)).toList
    val missed = (peek(c.io.resp.f3.preds(position).taken) != 0) != taken
    poke(c.io.f0_req.valid, 0)
    poke(c.io.f3_fire, 1)
    step(1)
    poke(c.io.f3_fire, 0)
    val update = c.io.update.bits
    poke(update.pc, pc)
    poke(update.br_mask, if (conditional) 1 << position else 0)
    poke(update.cfi_idx.valid, if (taken || missed) 1 else 0)
    poke(update.cfi_idx.bits, position)
    poke(update.cfi_taken, if (taken) 1 else 0)
    poke(update.cfi_mispredicted, if (conditional && missed) 1 else 0)
    poke(update.cfi_is_br, if (conditional) 1 else 0)
    poke(update.cfi_is_jal, if (conditional) 0 else 1)
    poke(update.target, target)
    setHistory(update.ghist, history, previousTaken)
    for (bank <- metadata.indices) {
      poke(update.meta(bank), metadata(bank))
      poke(update.lhist(bank), localHistory(bank))
    }
    poke(c.io.update.valid, 1)
    step(1)
    poke(c.io.update.valid, 0)
    step(3)
  }

  private def checkTarget(stage: BranchPredictionBundle, position: Int, target: BigInt,
                          label: String, conditional: Boolean = false, taken: Boolean = true): Unit = {
    val predicted = stage.preds(position)
    compare(predicted.predicted_pc.valid, 1, s"$label target is present")
    compare(predicted.predicted_pc.bits, target, s"$label target")
    compare(predicted.is_br, if (conditional) 1 else 0, s"$label branch type")
    compare(predicted.is_jal, if (conditional) 0 else 1, s"$label jump type")
    if (conditional) compare(predicted.taken, if (taken) 1 else 0, s"$label trained conditional direction")
  }

  private def compare(port: Bits, expected: BigInt, description: String): Unit = {
    val observed = peek(port)
    if (observed != expected) {
      println(s"BRANCH_PREDICTOR_MISMATCH $description expected=$expected observed=$observed")
    }
    comparisons += 1
    expect(port, expected, description)
  }

  poke(c.io.f0_req.valid, 0)
  poke(c.io.f0_req.bits.pc, base)
  clearHistory(c.io.f0_req.bits.ghist)
  poke(c.io.f3_fire, 0)
  poke(c.io.update.valid, 0)
  val update = c.io.update.bits
  poke(update.is_mispredict_update, 0)
  poke(update.is_repair_update, 0)
  poke(update.btb_mispredicts, 0)
  poke(update.pc, base)
  poke(update.br_mask, 0)
  poke(update.cfi_idx.valid, 0)
  poke(update.cfi_idx.bits, 0)
  poke(update.cfi_taken, 0)
  poke(update.cfi_mispredicted, 0)
  poke(update.cfi_is_br, 0)
  poke(update.cfi_is_jal, 0)
  poke(update.cfi_is_jalr, 0)
  poke(update.target, 0)
  clearHistory(update.ghist)
  update.meta.foreach(value => poke(value, 0))
  update.lhist.foreach(value => poke(value, 0))
  // The configured BIM initializes one row per cycle before accepting updates.
  step(2050)
  println("BRANCH_PREDICTOR_OBSERVATION_STARTED")

  train(base, 1, firstTarget)
  train(base, 5, middleTarget)
  for (_ <- 0 until 8) train(nextBank0, 1, nextTarget, conditional = true)

  request(base)
  step(1)
  request(startInBank1)
  step(1)
  checkTarget(c.io.resp.f2, 1, firstTarget, "bank 0 first, F2")
  checkTarget(c.io.resp.f2, 5, middleTarget, "bank 1 second, F2")
  request(nextBank0)
  step(1)
  compare(c.io.resp.f3.pc, base, "first request at F3")
  checkTarget(c.io.resp.f3, 1, firstTarget, "bank 0 first, F3")
  checkTarget(c.io.resp.f3, 5, middleTarget, "bank 1 second, F3")
  checkTarget(c.io.resp.f2, 1, middleTarget, "bank 1 first, F2")
  checkTarget(c.io.resp.f2, 5, nextTarget, "next bank 0 second, F2", conditional = true)
  poke(c.io.f0_req.valid, 0)
  step(1)
  compare(c.io.resp.f3.pc, startInBank1, "second request at F3")
  checkTarget(c.io.resp.f3, 1, middleTarget, "bank 1 first, F3")
  checkTarget(c.io.resp.f3, 5, nextTarget, "next bank 0 second, F3", conditional = true)

  val contextualPc = base + 0x108
  val contextualTarget = base + 0x840
  for (_ <- 0 until 8) {
    train(contextualPc, 1, contextualTarget, conditional = true, taken = false, history = 1, previousTaken = true)
    for (_ <- 0 until 4) {
      train(contextualPc, 1, contextualTarget, conditional = true, history = 2, previousTaken = true)
    }
  }
  request(contextualPc, history = 2, previousTaken = true)
  step(3)
  checkTarget(c.io.resp.f3, 1, contextualTarget, "bank 1 history 2, F3", conditional = true)
  request(contextualPc, history = 1, previousTaken = true)
  step(3)
  checkTarget(c.io.resp.f3, 1, contextualTarget, "bank 1 history 1, F3", conditional = true, taken = false)
  println(s"BRANCH_PREDICTOR_COMPARISONS $comparisons")
}

class BranchPredictorPublicTest extends AnyFlatSpec {
  "BranchPredictor" should "route consecutive requests, learned targets and directions in fetch order" in {
    implicit val parameters: Parameters = new WithNLargeBooms(1) ++ new BaseConfig
    assert(Driver.execute(Array("--backend-name", "verilator", "--target-dir",
      "test_run_dir/branch-predictor-public"), () => LazyModule(new BranchPredictorHarness).module)(
      dut => new BranchPredictorPublicTester(dut)))
  }
}
