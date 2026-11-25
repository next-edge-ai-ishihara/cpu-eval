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
import boom.lsu.ForwardingAgeLogic

class ForwardingTestHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new ForwardingTestHarnessModule(this)
}

class ForwardingTestHarnessModule(outer: ForwardingTestHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  val dut = Module(new ForwardingAgeLogic(24))
  val io = IO(chiselTypeOf(dut.io))
  io <> dut.io
}

class ForwardingTester(c: ForwardingTestHarnessModule) extends PeekPokeTester(c) {
  private val masks = Seq(BigInt(0), (BigInt(1) << 24) - 1,
    BigInt("aaaaaa", 16), BigInt("555555", 16)) ++
    (0 until 24).map(i => BigInt(1) << i) ++
    (0 until 24).map(i => (BigInt(1) << i) | (BigInt(1) << ((i + 1) % 24)))
  println("FORWARDING_AGE_OBSERVATION_STARTED")
  var cases = 0
  var indexChecks = 0
  for (boundary <- 0 until 24; mask <- masks.map(_.clearBit(boundary)).distinct) {
    poke(c.io.youngest_st_idx, boundary)
    poke(c.io.addr_matches, mask)
    val valid = if (mask == 0) 0 else 1
    val observedValid = peek(c.io.forwarding_val)
    assert(observedValid == valid,
      s"FORWARDING_AGE_MISMATCH valid before clock boundary=$boundary mask=${mask.toString(16)} expected=$valid observed=$observedValid")
    cases += 1
    if (mask != 0) {
      val selected = (1 to 24).map(distance => (boundary + 24 - distance) % 24)
        .find(index => mask.testBit(index)).get
      val observedIndex = peek(c.io.forwarding_idx)
      assert(observedIndex == selected,
        s"FORWARDING_AGE_MISMATCH index before clock boundary=$boundary mask=${mask.toString(16)} expected=$selected observed=$observedIndex")
      indexChecks += 1
    }
  }
  println(s"FORWARDING_AGE_CHECKS valid=$cases index=$indexChecks")
}

class ForwardingAgeLogicTest extends AnyFlatSpec with Matchers {
  behavior of "ForwardingAgeLogic"
  it should "select the newest matching store before the circular boundary" in {
    implicit val p: Parameters =
      new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver(() => LazyModule(new ForwardingTestHarness).module)(
      c => new ForwardingTester(c)) should be(true)
  }
}
