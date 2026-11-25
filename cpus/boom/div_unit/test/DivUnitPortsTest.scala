package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import org.scalatest.flatspec.AnyFlatSpec

import boom.common.{BoomTileAttachParams, WithNLargeBooms}
import boom.exu.DivUnit
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.rocket.ALU.FN_DIV
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}

class DivUnitHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(AddressSet(BigInt("80000000", 16), 0xffff), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new DivUnitHarnessModule(this)
}

class DivUnitHarnessModule(outer: DivUnitHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  val dut = Module(new DivUnit(64))
  val io = IO(new Bundle {
    val reqValid = Input(Bool())
    val reqReady = Output(Bool())
    val dividend = Input(UInt(64.W))
    val divisor = Input(UInt(64.W))
    val reqMask = Input(UInt(dut.io.req.bits.uop.br_mask.getWidth.W))
    val reqDestination = Input(UInt(dut.io.req.bits.uop.pdst.getWidth.W))
    val kill = Input(Bool())
    val resolved = Input(UInt(dut.io.brupdate.b1.resolve_mask.getWidth.W))
    val mispredicted = Input(UInt(dut.io.brupdate.b1.mispredict_mask.getWidth.W))
    val respReady = Input(Bool())
    val respValid = Output(Bool())
    val data = Output(UInt(64.W))
    val respMask = Output(UInt(dut.io.resp.bits.uop.br_mask.getWidth.W))
    val respDestination = Output(UInt(dut.io.resp.bits.uop.pdst.getWidth.W))
  })
  dut.io <> DontCare
  dut.io.req.valid := io.reqValid
  dut.io.req.bits := 0.U.asTypeOf(dut.io.req.bits)
  dut.io.req.bits.rs1_data := io.dividend
  dut.io.req.bits.rs2_data := io.divisor
  dut.io.req.bits.uop.ctrl.op_fcn := FN_DIV
  dut.io.req.bits.uop.ctrl.fcn_dw := true.B
  dut.io.req.bits.uop.br_mask := io.reqMask
  dut.io.req.bits.uop.pdst := io.reqDestination
  dut.io.req.bits.kill := io.kill
  dut.io.brupdate.b1.resolve_mask := io.resolved
  dut.io.brupdate.b1.mispredict_mask := io.mispredicted
  dut.io.brupdate.b2.valid := false.B
  dut.io.brupdate.b2.mispredict := false.B
  dut.io.brupdate.b2.target_offset := 0.S
  dut.io.resp.ready := io.respReady
  io.reqReady := dut.io.req.ready
  io.respValid := dut.io.resp.valid
  io.data := dut.io.resp.bits.data
  io.respMask := dut.io.resp.bits.uop.br_mask
  io.respDestination := dut.io.resp.bits.uop.pdst
}

class DivUnitPortsTester(c: DivUnitHarnessModule) extends PeekPokeTester(c) {
  private def waitFor(signal: Bool, name: String): Unit = {
    var waited = 0
    while (peek(signal) == 0 && waited < 256) {
      step(1)
      waited += 1
    }
    assert(peek(signal) == 1, s"Timed out waiting for $name")
  }

  private def driveRequest(dividend: Int, divisor: Int, mask: Int, destination: Int): Unit = {
    poke(c.io.dividend, dividend)
    poke(c.io.divisor, divisor)
    poke(c.io.reqMask, mask)
    poke(c.io.reqDestination, destination)
    poke(c.io.reqValid, 1)
    step(1)
    poke(c.io.reqValid, 0)
  }

  private def request(dividend: Int, divisor: Int, mask: Int, destination: Int): Unit = {
    waitFor(c.io.reqReady, "request ready")
    driveRequest(dividend, divisor, mask, destination)
  }

  private def expectAnswer(value: Int, mask: Int, destination: Int): Unit = {
    expect(c.io.respValid, 1, "response is available")
    expect(c.io.data, value, "quotient belongs to the accepted request")
    expect(c.io.respMask, mask, "resolved branch bits are removed from the saved mask")
    expect(c.io.respDestination, destination, "destination belongs to the accepted request")
  }

  private def flushStalledResponse(): Unit = {
    poke(c.io.respReady, 1)
    step(1)
    poke(c.io.respReady, 0)
    poke(c.io.resolved, 0)
    poke(c.io.mispredicted, 0)
    poke(c.io.kill, 0)
    expect(c.io.respValid, 0, "cancelled response is gone after the edge")
  }

  poke(c.io.reqValid, 0)
  poke(c.io.reqMask, 0)
  poke(c.io.reqDestination, 0)
  poke(c.io.dividend, 0)
  poke(c.io.divisor, 0)
  poke(c.io.resolved, 0)
  poke(c.io.mispredicted, 0)
  poke(c.io.kill, 0)
  poke(c.io.respReady, 0)
  step(1)
  println("DIV_UNIT_PORT_OBSERVATION_STARTED")

  request(117, 7, mask = 3, destination = 17)
  poke(c.io.resolved, 1)
  step(1)
  poke(c.io.resolved, 0)
  waitFor(c.io.respValid, "117 divided by 7")
  expectAnswer(16, 2, 17)
  poke(c.io.dividend, 42)
  poke(c.io.reqDestination, 19)
  poke(c.io.resolved, 1)
  poke(c.io.mispredicted, 1)
  step(3)
  expectAnswer(16, 2, 17)
  poke(c.io.resolved, 2)
  poke(c.io.mispredicted, 2)
  poke(c.io.respReady, 1)
  println(s"DIV_UNIT_BRANCH_CANCEL valid=${peek(c.io.respValid)}")
  expect(c.io.respValid, 0, "matching misprediction suppresses the response before transfer")
  flushStalledResponse()

  request(42, 6, mask = 0, destination = 19)
  waitFor(c.io.respValid, "42 divided by 6")
  expectAnswer(7, 0, 19)
  poke(c.io.kill, 1)
  poke(c.io.respReady, 1)
  println(s"DIV_UNIT_GLOBAL_CANCEL valid=${peek(c.io.respValid)}")
  expect(c.io.respValid, 0, "global kill suppresses the response before transfer")
  flushStalledResponse()

  waitFor(c.io.reqReady, "request ready before cancellation")
  poke(c.io.kill, 1)
  driveRequest(55, 5, mask = 0, destination = 23)
  poke(c.io.kill, 0)
  // A cancelled request must not produce a response at any later sample.
  var escapedResult = peek(c.io.respValid) != 0
  for (_ <- 0 until 256) {
    step(1)
    escapedResult = escapedResult || peek(c.io.respValid) != 0
  }
  println(s"DIV_UNIT_CANCELLED_REQUEST result=$escapedResult")
  expect(!escapedResult, "cancelled incoming request leaves no result")
  poke(c.io.kill, 1)
  step(1)
  poke(c.io.kill, 0)

  request(24, 8, mask = 0, destination = 29)
  waitFor(c.io.respValid, "24 divided by 8")
  expectAnswer(3, 0, 29)
  poke(c.io.respReady, 1)
  step(1)
  expect(c.io.respValid, 0, "accepted response is delivered once")
}

class DivUnitPortsTest extends AnyFlatSpec {
  behavior of "DivUnit request and response ports"

  it should "preserve stalled results and suppress both forms of cancelled transfers" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    assert(Driver.execute(Array("--backend-name", "verilator", "--target-dir", "test_run_dir/div-unit-ports"),
      () => LazyModule(new DivUnitHarness()).module)(c => new DivUnitPortsTester(c)))
  }
}
