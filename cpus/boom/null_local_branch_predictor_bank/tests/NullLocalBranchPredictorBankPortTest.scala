package boom.tests

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers
import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}
import boom.common.{BoomTileAttachParams, WithNLargeBooms}
import boom.ifu.NullLocalBranchPredictorBank

class NullLocalPortHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new NullLocalPortHarnessModule(this)
}

class NullLocalPortHarnessModule(outer: NullLocalPortHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile.copy(core = tile.core.copy(localHistoryLength = 32, localHistoryNSets = 128))
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  val dut = Module(new NullLocalBranchPredictorBank)
  val io = IO(chiselTypeOf(dut.io))
  io <> dut.io
}

class NullLocalPortTester(c: NullLocalPortHarnessModule) extends PeekPokeTester(c) {
  def observe(label: String): Unit = {
    println(s"PORT $label f1=${peek(c.io.f1_lhist)} f3=${peek(c.io.f3_lhist)}")
    expect(c.io.f1_lhist, BigInt(0))
    expect(c.io.f3_lhist, BigInt(0))
  }
  private val pcWidth = c.io.f0_pc.getWidth
  private val historyWidth = c.io.update.lhist.getWidth
  require(c.io.update.pc.getWidth == pcWidth)
  println(s"PORT widths address=$pcWidth history=$historyWidth")
  for (mask <- 0 until 64; bit <- 0 until (pcWidth max historyWidth)) {
    poke(c.io.f0_valid, (mask >> 0) & 1)
    poke(c.io.f3_taken_br, (mask >> 1) & 1)
    poke(c.io.f3_fire, (mask >> 2) & 1)
    poke(c.io.update.valid, (mask >> 3) & 1)
    poke(c.io.update.mispredict, (mask >> 4) & 1)
    poke(c.io.update.repair, (mask >> 5) & 1)
    val addressMask = BigInt(1) << (bit % pcWidth)
    val historyMask = BigInt(1) << (bit % historyWidth)
    poke(c.io.f0_pc, BigInt(0x80000000L) ^ addressMask)
    poke(c.io.update.pc, BigInt(0x80000040L) ^ addressMask)
    poke(c.io.update.lhist, historyMask ^ BigInt("aaaaaaaa", 16))
    observe(s"before-$mask-$bit")
    step(1)
    observe(s"after-$mask-$bit")
  }
}

class NullLocalBranchPredictorBankPortTest extends AnyFlatSpec with Matchers {
  behavior of "NullLocalBranchPredictorBank external outputs"
  it should "keep both histories zero while request, update and f3 inputs change" in {
    implicit val p: Parameters =
      new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver.execute(Array("--backend-name", "treadle"), () => LazyModule(new NullLocalPortHarness).module)(
      c => new NullLocalPortTester(c)) should be(true)
  }
}
