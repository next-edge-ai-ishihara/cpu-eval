// SPDX-License-Identifier: Apache-2.0
package boom.tests

import boom.common.{BoomTileAttachParams, WithNLargeBooms}
import boom.ifu.LoopBranchPredictorBank
import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.system.BaseConfig
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._
import org.scalatest.flatspec.AnyFlatSpec

class LoopColumnRepairHarness(implicit p: Parameters) extends LazyModule {
  val visibility = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("00000fff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibility := fuzz.node }
  lazy val module = new LoopColumnRepairModule(this)
}

class LoopColumnRepairModule(outer: LoopColumnRepairHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  private val parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibility
  }
  private val bank = Module(new LoopBranchPredictorBank()(parameters))
  bank.io := DontCare
  private val target = Module(new bank.LoopBranchPredictorColumn)

  val io = IO(new Bundle {
    val request = Input(UInt(16.W))
    val update = Input(UInt(16.W))
    val train = Input(Bool())
    val repair = Input(Bool())
    val count = Input(UInt(10.W))
    val predictedCount = Output(UInt(10.W))
  })
  target.io.f2_req_valid := true.B
  target.io.f2_req_idx := io.request
  target.io.f3_req_fire := false.B
  target.io.f3_pred_in := false.B
  target.io.update_mispredict := io.train
  target.io.update_repair := io.repair
  target.io.update_idx := io.update
  target.io.update_resolve_dir := false.B
  target.io.update_meta.s_cnt := io.count
  io.predictedCount := target.io.f3_meta.s_cnt
}

class LoopColumnRepairTester(dut: LoopColumnRepairModule) extends PeekPokeTester(dut) {
  private val io = dut.io
  private val original = 0x35
  private val alias = 0x45
  poke(io.request, original)
  poke(io.update, original)
  poke(io.train, 0)
  poke(io.repair, 0)
  poke(io.count, 0)
  step(20)

  println("LOOP_COLUMN_REPAIR_START")
  poke(io.train, 1)
  poke(io.count, 5)
  step(1)
  poke(io.train, 0)
  step(1)
  val learned = peek(io.predictedCount)
  val aliasCount = if (learned == 9) 10 else 9
  val repairCount = if (learned == 6) 7 else 6

  poke(io.update, alias)
  poke(io.repair, 1)
  poke(io.count, aliasCount)
  expect(io.predictedCount, learned, "f3 does not forward the repair of a different tag in the same row")
  step(1)
  poke(io.repair, 0)
  expect(io.predictedCount, learned, "f2 does not capture the repair of a different tag in the same row")

  poke(io.update, original)
  poke(io.repair, 1)
  poke(io.count, repairCount)
  expect(io.predictedCount, repairCount, "f3 forwards a repair for its full request index")
  step(1)
  poke(io.repair, 0)
  expect(io.predictedCount, repairCount, "f2 captures a repair for its full request index")
  println("LOOP_COLUMN_REPAIR_OBSERVED")
}

class LoopColumnRepairTest extends AnyFlatSpec {
  "LoopBranchPredictorColumn" should "forward repairs by the full request index" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new BaseConfig
    assert(Driver.execute(Array("--backend-name", "treadle"), () => LazyModule(new LoopColumnRepairHarness).module)(
      dut => new LoopColumnRepairTester(dut)))
  }
}
