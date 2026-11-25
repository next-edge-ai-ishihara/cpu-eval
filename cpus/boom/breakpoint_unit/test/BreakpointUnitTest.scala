package boom.tests

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.rocket.BreakpointUnit
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}

import boom.common.{BoomTileAttachParams, WithNLargeBooms}

class BreakpointUnitHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new BreakpointUnitHarnessModule(this)
}

class BreakpointUnitHarnessModule(outer: BreakpointUnitHarness)
  extends LazyModuleImp(outer) {
  val io = IO(new Bundle {
    val pc = Input(UInt(64.W))
    val ea = Input(UInt(64.W))
    val address = Input(Vec(2, UInt(64.W)))
    val execute = Input(Vec(2, Bool()))
    val load = Input(Vec(2, Bool()))
    val store = Input(Vec(2, Bool()))
    val action = Input(Vec(2, UInt(1.W)))
    val chain = Input(Vec(2, Bool()))
    val xcptIf = Output(Bool())
    val xcptLd = Output(Bool())
    val xcptSt = Output(Bool())
    val debugIf = Output(Bool())
    val debugLd = Output(Bool())
    val debugSt = Output(Bool())
    val watchValid = Output(Vec(2, Bool()))
    val watchI = Output(Vec(2, Bool()))
    val watchR = Output(Vec(2, Bool()))
    val watchW = Output(Vec(2, Bool()))
    val watchAction = Output(Vec(2, UInt(3.W)))
  })
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  val dut = Module(new BreakpointUnit(2))
  dut.io.status := 0.U.asTypeOf(dut.io.status)
  dut.io.status.prv := 3.U
  dut.io.pc := io.pc
  dut.io.ea := io.ea
  dut.io.mcontext := 0.U
  dut.io.scontext := 0.U
  for (i <- 0 until 2) {
    dut.io.bp(i) := 0.U.asTypeOf(dut.io.bp(i))
    dut.io.bp(i).address := io.address(i)
    dut.io.bp(i).control.m := true.B
    dut.io.bp(i).control.x := io.execute(i)
    dut.io.bp(i).control.r := io.load(i)
    dut.io.bp(i).control.w := io.store(i)
    dut.io.bp(i).control.action := io.action(i)
    dut.io.bp(i).control.dmode := io.action(i) === 1.U
    dut.io.bp(i).control.chain := io.chain(i)
  }
  io.xcptIf := dut.io.xcpt_if
  io.xcptLd := dut.io.xcpt_ld
  io.xcptSt := dut.io.xcpt_st
  io.debugIf := dut.io.debug_if
  io.debugLd := dut.io.debug_ld
  io.debugSt := dut.io.debug_st
  for (i <- 0 until 2) {
    io.watchValid(i) := dut.io.bpwatch(i).valid(0)
    io.watchI(i) := dut.io.bpwatch(i).ivalid(0)
    io.watchR(i) := dut.io.bpwatch(i).rvalid(0)
    io.watchW(i) := dut.io.bpwatch(i).wvalid(0)
    io.watchAction(i) := dut.io.bpwatch(i).action
  }
}

class BreakpointUnitTester(c: BreakpointUnitHarnessModule) extends PeekPokeTester(c) {
  private def clear(): Unit = {
    poke(c.io.pc, 0)
    poke(c.io.ea, 0)
    for (i <- 0 until 2) {
      poke(c.io.address(i), 0)
      poke(c.io.execute(i), 0)
      poke(c.io.load(i), 0)
      poke(c.io.store(i), 0)
      poke(c.io.action(i), 0)
      poke(c.io.chain(i), 0)
    }
  }

  private def enable(index: Int, address: BigInt, execute: Boolean = false,
                     load: Boolean = false, store: Boolean = false,
                     action: Int = 0, chain: Boolean = false): Unit = {
    poke(c.io.address(index), address)
    poke(c.io.execute(index), if (execute) 1 else 0)
    poke(c.io.load(index), if (load) 1 else 0)
    poke(c.io.store(index), if (store) 1 else 0)
    poke(c.io.action(index), action)
    poke(c.io.chain(index), if (chain) 1 else 0)
  }

  clear()
  enable(0, 0x1000, execute = true)
  poke(c.io.pc, 0x1000)
  expect(c.io.xcptIf, 1)
  expect(c.io.debugIf, 0)

  poke(c.io.pc, 0x1004)
  expect(c.io.xcptIf, 0)

  clear()
  enable(0, 0x2000, load = true)
  poke(c.io.ea, 0x2000)
  expect(c.io.xcptLd, 1)
  expect(c.io.xcptSt, 0)

  clear()
  enable(0, 0x3000, store = true)
  poke(c.io.ea, 0x3000)
  expect(c.io.xcptSt, 1)
  expect(c.io.xcptLd, 0)

  clear()
  enable(0, 0x4000, execute = true, action = 1)
  poke(c.io.pc, 0x4000)
  expect(c.io.debugIf, 1)
  expect(c.io.xcptIf, 0)

  clear()
  enable(0, 0x6000, load = true, action = 1)
  poke(c.io.ea, 0x6000)
  expect(c.io.debugLd, 1)
  expect(c.io.debugSt, 0)
  expect(c.io.xcptLd, 0)
  poke(c.io.ea, 0x6004)
  expect(c.io.debugLd, 0)

  clear()
  enable(0, 0x7000, store = true, action = 1)
  poke(c.io.ea, 0x7000)
  expect(c.io.debugSt, 1)
  expect(c.io.debugLd, 0)
  expect(c.io.xcptSt, 0)
  poke(c.io.ea, 0x7004)
  expect(c.io.debugSt, 0)

  clear()
  enable(0, 0x5000, execute = true, chain = true)
  enable(1, 0x5000, execute = true)
  poke(c.io.pc, 0x5000)
  expect(c.io.xcptIf, 1)
  poke(c.io.address(0), 0x5004)
  expect(c.io.xcptIf, 0)

  private def watch(index: Int, direction: Int, action: Int): Unit = {
    expect(c.io.watchI(index), if (direction == 0) 1 else 0)
    expect(c.io.watchR(index), if (direction == 1) 1 else 0)
    expect(c.io.watchW(index), if (direction == 2) 1 else 0)
    expect(c.io.watchValid(index), if (direction >= 0) 1 else 0)
    if (direction >= 0) expect(c.io.watchAction(index), action)
  }

  val exceptions = Seq(c.io.xcptIf, c.io.xcptLd, c.io.xcptSt)
  val debug = Seq(c.io.debugIf, c.io.debugLd, c.io.debugSt)
  for (direction <- 0 until 3) {
    def setEntry(index: Int, action: Int, chain: Boolean = false): Unit =
      enable(index, 0x8000, execute = direction == 0,
        load = direction == 1, store = direction == 2,
        action = action, chain = chain)
    def setAddress(address: Int): Unit =
      if (direction == 0) poke(c.io.pc, address) else poke(c.io.ea, address)

    for (action <- 0 until 2) {
      clear()
      setEntry(0, action)
      setAddress(0x8000)
      watch(0, direction, action)
      watch(1, -1, 0)
      setAddress(0x8004)
      watch(0, -1, 0)
      watch(1, -1, 0)
    }

    clear()
    setEntry(0, 0, chain = true)
    setEntry(1, 0)
    setAddress(0x8000)
    watch(0, -1, 0)
    watch(1, direction, 0)
    poke(c.io.address(0), 0x8004)
    watch(0, -1, 0)
    watch(1, -1, 0)

    clear()
    setEntry(0, 0)
    setEntry(1, 1)
    setAddress(0x8000)
    watch(0, direction, 0)
    watch(1, direction, 1)
    expect(peek(exceptions(direction)) != 0 || peek(debug(direction)) != 0,
      "At least one matching action must be notified")
    for (other <- 0 until 3 if other != direction) {
      expect(exceptions(other), 0)
      expect(debug(other), 0)
    }
  }
}

class BreakpointUnitTest extends AnyFlatSpec with Matchers {
  behavior of "BreakpointUnit"

  it should "produce fixed exception and debug responses for execute, load, store, and chained matches" in {
    implicit val p: Parameters =
      new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver(() => LazyModule(new BreakpointUnitHarness).module)(
      c => new BreakpointUnitTester(c)) should be(true)
  }
}
