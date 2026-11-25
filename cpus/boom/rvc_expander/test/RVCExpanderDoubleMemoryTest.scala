package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import org.scalatest.flatspec.AnyFlatSpec

import boom.common._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.rocket.RVCExpander
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}

class RVCExpanderMemoryHarness(implicit p: Parameters) extends LazyModule {
  val visibility = TLEphemeralNode()
  private val initiator = LazyModule(new TLFuzzer(1))
  private val memory = LazyModule(new TLRAM(AddressSet(BigInt("80000000", 16), 0xffff), beatBytes = 16))
  DisableMonitors { implicit p => memory.node := visibility := initiator.node }
  lazy val module = new RVCExpanderMemoryModule(this)
}

class RVCExpanderMemoryModule(outer: RVCExpanderMemoryHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val parameters: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibility
  }
  val io = IO(new Bundle {
    val fetched = Input(UInt(32.W))
    val expanded = Output(UInt(32.W))
    val compressed = Output(Bool())
  })
  private val expander = Module(new RVCExpander)
  expander.io.in := io.fetched
  io.expanded := expander.io.out.bits
  io.compressed := expander.io.rvc
}

class RVCExpanderDoubleMemoryTester(dut: RVCExpanderMemoryModule) extends PeekPokeTester(dut) {
  private val vectors = Seq(
    ("c.fld fa0,136(s1)", "24c8", "0884b507"),
    ("c.fsd fa1,136(a0)", "a54c", "08b53427"),
    ("c.fldsp fa2,264(sp)", "2632", "10813607"),
    ("c.fsdsp fa3,264(sp)", "a636", "10d13427")
  )
  println("RVC_DOUBLE_MEMORY_OBSERVATIONS_STARTED")
  for ((label, encoded, expanded) <- vectors) {
    val instruction = BigInt("a5a5" + encoded, 16)
    val expected = BigInt(expanded, 16)
    poke(dut.io.fetched, instruction)
    val actual = peek(dut.io.expanded)
    val compressed = peek(dut.io.compressed)
    println(s"RVC_DOUBLE_MEMORY $encoded ${actual.toString(16)} $compressed")
    expect(dut.io.compressed, 1, label)
    expect(dut.io.expanded, expected, label)
    step(1)
  }
}

class RVCExpanderDoubleMemoryTest extends AnyFlatSpec {
  "RVCExpander" should "expand RV64 compressed double-precision memory instructions" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    assert(Driver.execute(
      Array("--backend-name", "verilator", "--target-dir", "test_run_dir/rvc-double-memory"),
      () => LazyModule(new RVCExpanderMemoryHarness()).module
    )(new RVCExpanderDoubleMemoryTester(_)))
  }
}
