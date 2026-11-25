package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.rocket.{PMP, PMPChecker, PRV}
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers
import boom.common.{BoomTileAttachParams, WithNLargeBooms}

class PMPCheckerPermissionHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new PMPCheckerPermissionHarnessModule(this)
}

class PMPCheckerPermissionHarnessModule(outer: PMPCheckerPermissionHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  val io = IO(new Bundle {
    val permits = Input(UInt(3.W))
    val actual = Output(UInt(3.W))
  })

  val checker = Module(new PMPChecker(3))
  val region = BigInt("80000000", 16)
  checker.io.prv := PRV.M.U
  checker.io.addr := region.U
  checker.io.size := 2.U
  val entries = Wire(chiselTypeOf(checker.io.pmp))
  entries := 0.U.asTypeOf(entries)
  checker.io.pmp := entries
  val entry = entries(0)
  entry.addr := (region >> PMP.lgAlign).U
  entry.cfg.a := 2.U
  entry.cfg.l := true.B
  entry.cfg.r := io.permits(0)
  entry.cfg.w := io.permits(1)
  entry.cfg.x := io.permits(2)
  entry.mask := entry.computeMask
  io.actual := chisel3.util.Cat(checker.io.x, checker.io.w, checker.io.r)
}

class PMPCheckerPermissionsTester(c: PMPCheckerPermissionHarnessModule) extends PeekPokeTester(c) {
  // R=0, W=1 is reserved. Exercise every other permission setting on the same matching region.
  for (permissions <- Seq(0, 1, 3, 4, 5, 7)) {
    poke(c.io.permits, permissions)
    step(1)
    println(s"PMP permissions=$permissions actual=${peek(c.io.actual)}")
    expect(c.io.actual, BigInt(permissions))
  }
}

class PMPCheckerPermissionsTest extends AnyFlatSpec with Matchers {
  behavior of "PMPChecker permissions for a fully contained machine-mode access"

  it should "return the locked region's configured read, write and execute permissions" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver.execute(Array("--backend-name", "treadle"), () => LazyModule(new PMPCheckerPermissionHarness).module)(
      c => new PMPCheckerPermissionsTester(c)) should be(true)
  }
}
