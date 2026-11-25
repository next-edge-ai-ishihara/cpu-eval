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
import boom.ifu.BoomRAS

class BoomRASTestHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }

  lazy val module = new BoomRASTestHarnessModule(this)
}

class BoomRASTestHarnessModule(outer: BoomRASTestHarness)
  extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  val dut = Module(new BoomRAS)
  val io = IO(chiselTypeOf(dut.io))
  io <> dut.io
}

class BoomRASTester(c: BoomRASTestHarnessModule) extends PeekPokeTester(c) {
  private val first = BigInt("123456789a", 16)
  private val second = BigInt("23456789ab", 16)
  private val third = BigInt("3456789abc", 16)

  poke(c.io.write_valid, 1)
  poke(c.io.write_idx, 1)
  poke(c.io.write_addr, first)
  poke(c.io.read_idx, 1)
  step(1)
  expect(c.io.read_addr, first)

  poke(c.io.write_valid, 1)
  poke(c.io.write_idx, 2)
  poke(c.io.write_addr, second)
  poke(c.io.read_idx, 1)
  step(1)
  expect(c.io.read_addr, first)

  poke(c.io.write_valid, 0)
  poke(c.io.read_idx, 2)
  step(1)
  expect(c.io.read_addr, second)

  poke(c.io.read_idx, 1)
  step(1)
  expect(c.io.read_addr, first)

  poke(c.io.read_idx, 2)
  expect(c.io.read_addr, first)
  step(1)
  expect(c.io.read_addr, second)

  poke(c.io.write_valid, 1)
  poke(c.io.write_idx, 2)
  poke(c.io.write_addr, third)
  expect(c.io.read_addr, second)
  step(1)
  expect(c.io.read_addr, third)

  poke(c.io.write_valid, 0)
  poke(c.io.write_addr, first)
  step(1)
  expect(c.io.read_addr, third)
  step(1)
  expect(c.io.read_addr, third)

  // Slots 15 and 31 have identical low bits.
  poke(c.io.write_valid, 1)
  poke(c.io.write_idx, 15)
  poke(c.io.write_addr, first)
  poke(c.io.read_idx, 15)
  step(1)
  expect(c.io.read_addr, first)

  poke(c.io.write_idx, 31)
  poke(c.io.write_addr, second)
  poke(c.io.read_idx, 31)
  step(1)
  expect(c.io.read_addr, second)

  poke(c.io.write_valid, 0)
  poke(c.io.read_idx, 15)
  step(1)
  expect(c.io.read_addr, first)
  poke(c.io.read_idx, 31)
  step(1)
  expect(c.io.read_addr, second)
}

class BoomRASTest extends AnyFlatSpec with Matchers {
  behavior of "BoomRAS"

  it should "sample reads and enabled writes once per clock edge" in {
    implicit val p: Parameters =
      new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver(() => LazyModule(new BoomRASTestHarness).module)(
      c => new BoomRASTester(c)) should be(true)
  }
}
