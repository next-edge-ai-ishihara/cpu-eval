package boom.tests

import boom.common._
import boom.ifu._
import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import chisel3.util.RegEnable
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.system.BaseConfig
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._
import org.scalatest.flatspec.AnyFlatSpec

class ComposedPredictorHarness(implicit p: Parameters) extends LazyModule {
  val visibility = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("00000fff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibility := fuzz.node }
  lazy val module = new ComposedPredictorHarnessModule(this)
}

class ComposedPredictorHarnessModule(outer: ComposedPredictorHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case a: BoomTileAttachParams => a.tileParams
  }.get
  private implicit val parameters: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibility
  }
  private val candidate = Module(new ComposedBranchPredictorBank()(parameters))
  val io = IO(chiselTypeOf(candidate.io))
  io <> candidate.io

  private val (components, response) = tile.core.branchPredictor(io.resp_in(0), parameters)
  val expected = IO(Output(chiselTypeOf(response)))
  expected := response
  val memoryInventoryMatches = IO(Output(Bool()))
  memoryInventoryMatches := (candidate.mems.sorted == components.flatMap(_.mems).sorted).B

  // The control saves each component's metadata separately. Its predicted
  // outputs are independent of the candidate's choice of packet encoding.
  for (component <- components) {
    component.io.f0_valid := io.f0_valid
    component.io.f0_pc := io.f0_pc
    component.io.f0_mask := io.f0_mask
    component.io.f1_ghist := io.f1_ghist
    component.io.f1_lhist := io.f1_lhist
    component.io.f3_fire := io.f3_fire
    component.io.update := io.update
    val saved = RegEnable(component.io.f3_meta, io.f3_fire)
    component.io.update.bits.meta := saved
  }
}

class ComposedPredictorPortsTester(c: ComposedPredictorHarnessModule) extends PeekPokeTester(c) {
  private val base = BigInt("80000000", 16)
  private val pc = base + 0x108
  private val destination = base + 0x840
  private val position = 1
  private val stages = Seq(c.io.resp.f1 -> c.expected.f1, c.io.resp.f2 -> c.expected.f2,
                           c.io.resp.f3 -> c.expected.f3)
  private var comparisons = 0

  private def compare(port: Bits, value: BigInt, field: String): Unit = {
    val observed = peek(port)
    if (value != observed)
      println(s"COMPOSED_PREDICTOR_MISMATCH $field expected=$value observed=$observed")
    expect(port, value)
    comparisons += 1
  }

  private def request(address: BigInt, history: BigInt, cycles: Int = 3): Unit = {
    poke(c.io.f0_valid, 1)
    poke(c.io.f0_pc, address)
    poke(c.io.f0_mask, 15)
    poke(c.io.f1_ghist, history)
    step(cycles)
  }

  private def response(label: String, stage: Int = 3): Unit = {
    val (actualBank, expectedBank) = stages(stage - 1)
    val expected = expectedBank(position)
    val actual = actualBank(position)
    compare(actual.is_br, peek(expected.is_br), s"$label branch")
    compare(actual.is_jal, peek(expected.is_jal), s"$label jump")
    compare(actual.predicted_pc.valid, peek(expected.predicted_pc.valid), s"$label target valid")
    if (peek(expected.predicted_pc.valid) != 0)
      compare(actual.predicted_pc.bits, peek(expected.predicted_pc.bits), s"$label target")
    if (peek(expected.is_br) != 0)
      compare(actual.taken, peek(expected.taken), s"$label direction")
  }

  private def train(address: BigInt, target: BigInt, history: BigInt,
                    taken: Boolean, conditional: Boolean, label: String): Unit = {
    request(address, history)
    response(label)
    val saved = peek(c.io.f3_meta)
    val missed = conditional && ((peek(c.expected.f3(position).taken) != 0) != taken)
    poke(c.io.f0_valid, 0)
    poke(c.io.f3_fire, 1)
    step(1)
    poke(c.io.f3_fire, 0)
    if (conditional && history == 3) {
      // The commit belongs to the saved prediction, even after a different lookup.
      request(address + 0x180, history ^ 7)
      poke(c.io.f0_valid, 0)
    }
    val update = c.io.update.bits
    poke(update.pc, address)
    poke(update.br_mask, if (conditional) 1 << position else 0)
    poke(update.cfi_idx.valid, if (taken || missed) 1 else 0)
    poke(update.cfi_idx.bits, position)
    poke(update.cfi_taken, if (taken) 1 else 0)
    poke(update.cfi_mispredicted, if (missed) 1 else 0)
    poke(update.cfi_is_br, if (conditional) 1 else 0)
    poke(update.cfi_is_jal, if (conditional) 0 else 1)
    poke(update.ghist, history)
    poke(update.target, target)
    poke(update.meta, saved)
    poke(c.io.update.valid, 1)
    step(1)
    poke(c.io.update.valid, 0)
    step(3)
  }

  poke(c.io.f0_valid, 0)
  poke(c.io.f0_pc, 0)
  poke(c.io.f0_mask, 0)
  poke(c.io.f1_ghist, 0)
  poke(c.io.f1_lhist, 0)
  poke(c.io.f3_fire, 0)
  poke(c.io.update.valid, 0)
  val update = c.io.update.bits
  for (field <- Seq(update.is_mispredict_update, update.is_repair_update, update.btb_mispredicts,
         update.pc, update.br_mask, update.cfi_idx.valid, update.cfi_idx.bits, update.cfi_taken,
         update.cfi_mispredicted, update.cfi_is_br, update.cfi_is_jal, update.cfi_is_jalr,
         update.ghist, update.lhist, update.target, update.meta))
    poke(field, 0)
  for (stage <- Seq(c.io.resp_in(0).f1, c.io.resp_in(0).f2, c.io.resp_in(0).f3);
       prediction <- stage) {
    poke(prediction.taken, 0)
    poke(prediction.is_br, 0)
    poke(prediction.is_jal, 0)
    poke(prediction.predicted_pc.valid, 0)
    poke(prediction.predicted_pc.bits, 0)
  }
  step(2050)
  println("COMPOSED_PREDICTOR_OBSERVATION_STARTED")
  compare(c.memoryInventoryMatches, 1, "component memory inventory")

  val jump = base + 0x20
  train(jump, destination + 0x28, 0, taken = true, conditional = false, label = "initial jump")
  request(jump, 0, cycles = 1)
  response("trained jump F1", stage = 1)
  step(1)
  response("trained jump F2", stage = 2)
  step(1)
  response("trained jump F3")
  assert(peek(c.expected.f3(position).predicted_pc.bits) == destination + 0x28)
  for (round <- 0 until 8) {
    train(pc, destination, 3, taken = false, conditional = true, label = s"round $round history 3")
    for (repeat <- 0 until 4)
      train(pc, destination, 5, taken = true, conditional = true, label = s"round $round history 5 update $repeat")
  }
  request(pc, 5)
  response("trained history 5")
  assert(peek(c.expected.f3(position).taken) == 1)
  request(pc, 3)
  response("trained history 3")
  assert(peek(c.expected.f3(position).taken) == 0)
  println(s"COMPOSED_PREDICTOR_COMPARISONS $comparisons")
}

class ComposedPredictorPortsTest extends AnyFlatSpec {
  "ComposedBranchPredictorBank" should "preserve the configured bank's predictions and updates" in {
    implicit val parameters: Parameters = new WithNLargeBooms(1) ++ new BaseConfig
    assert(Driver.execute(Array("--backend-name", "verilator", "--target-dir",
      "test_run_dir/composed-predictor-ports"), () => LazyModule(new ComposedPredictorHarness).module)(
      dut => new ComposedPredictorPortsTester(dut)))
  }
}
