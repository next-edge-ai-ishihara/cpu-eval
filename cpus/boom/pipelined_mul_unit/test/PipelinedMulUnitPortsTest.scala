package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import org.scalatest.flatspec.AnyFlatSpec

import boom.common.{BoomTileAttachParams, WithNLargeBooms}
import boom.exu.PipelinedMulUnit
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.rocket.ALU.FN_MUL
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}

class PipelinedMulUnitHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(AddressSet(BigInt("80000000", 16), 0xffff), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new PipelinedMulUnitHarnessModule(this)
}

class PipelinedMulUnitHarnessModule(outer: PipelinedMulUnitHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  val dut = Module(new PipelinedMulUnit(numStages = 3, dataWidth = 64))
  val io = IO(new Bundle {
    val reqValid = Input(Bool())
    val reqReady = Output(Bool())
    val lhs = Input(UInt(64.W))
    val rhs = Input(UInt(64.W))
    val destination = Input(UInt(dut.io.req.bits.uop.pdst.getWidth.W))
    val branchMask = Input(UInt(dut.io.req.bits.uop.br_mask.getWidth.W))
    val resolve = Input(UInt(dut.io.brupdate.b1.resolve_mask.getWidth.W))
    val mispredict = Input(UInt(dut.io.brupdate.b1.mispredict_mask.getWidth.W))
    val respReady = Input(Bool())
    val respValid = Output(Bool())
    val result = Output(UInt(64.W))
    val resultDestination = Output(UInt(dut.io.resp.bits.uop.pdst.getWidth.W))
  })
  dut.io <> DontCare
  dut.io.req.valid := io.reqValid
  dut.io.req.bits := 0.U.asTypeOf(dut.io.req.bits)
  dut.io.req.bits.rs1_data := io.lhs
  dut.io.req.bits.rs2_data := io.rhs
  dut.io.req.bits.uop.ctrl.op_fcn := FN_MUL
  dut.io.req.bits.uop.ctrl.fcn_dw := true.B
  dut.io.req.bits.uop.pdst := io.destination
  dut.io.req.bits.uop.br_mask := io.branchMask
  dut.io.brupdate.b1.resolve_mask := io.resolve
  dut.io.brupdate.b1.mispredict_mask := io.mispredict
  dut.io.brupdate.b2.valid := false.B
  dut.io.brupdate.b2.mispredict := false.B
  dut.io.brupdate.b2.target_offset := 0.S
  dut.io.resp.ready := io.respReady
  io.reqReady := dut.io.req.ready
  io.respValid := dut.io.resp.valid
  io.result := dut.io.resp.bits.data
  io.resultDestination := dut.io.resp.bits.uop.pdst
}

class PipelinedMulUnitPortsTester(dut: PipelinedMulUnitHarnessModule) extends PeekPokeTester(dut) {
  private def request(lhs: Int, rhs: Int, destination: Int, mask: BigInt): Unit = {
    poke(dut.io.reqValid, 1)
    poke(dut.io.lhs, lhs)
    poke(dut.io.rhs, rhs)
    poke(dut.io.destination, destination)
    poke(dut.io.branchMask, mask)
    expect(dut.io.reqReady, 1, "the pipeline accepts an operand pair on each cycle")
    step(1)
  }

  private def result(value: Int, destination: Int): Unit = {
    expect(dut.io.respValid, 1, "the result is in its writeback slot")
    expect(dut.io.result, value, "the product belongs to the accepted operands")
    expect(dut.io.resultDestination, destination, "the result follows its destination")
  }

  poke(dut.io.reqValid, 0)
  poke(dut.io.lhs, 0)
  poke(dut.io.rhs, 0)
  poke(dut.io.destination, 0)
  poke(dut.io.branchMask, 0)
  poke(dut.io.resolve, 0)
  poke(dut.io.mispredict, 0)
  poke(dut.io.respReady, 0)
  step(1)
  println("PIPELINED_MUL_UNIT_OBSERVATIONS_STARTED")

  val affectedTag = BigInt(1) << (dut.io.branchMask.getWidth - 1)
  request(3, 7, 17, affectedTag)
  expect(dut.io.respValid, 0, "no result before the third stage")
  request(5, 11, 19, 1)
  expect(dut.io.respValid, 0, "no result before the third stage")
  poke(dut.io.reqValid, 0)
  step(1)
  result(21, 17)

  poke(dut.io.resolve, affectedTag)
  poke(dut.io.mispredict, affectedTag)
  println(s"PIPELINED_MUL_UNIT_CANCELLED valid=${peek(dut.io.respValid)}")
  expect(dut.io.respValid, 0, "an output-stage branch misprediction cancels the affected result")
  step(1)
  poke(dut.io.resolve, 0)
  poke(dut.io.mispredict, 0)
  poke(dut.io.respReady, 1)
  result(55, 19)
  step(1)
  expect(dut.io.respValid, 0, "no result from an empty request slot")
}

class PipelinedMulUnitPortsTest extends AnyFlatSpec {
  it should "align the product with its destination and suppress an output killed by a branch" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    assert(Driver.execute(Array("--backend-name", "verilator", "--target-dir", "test_run_dir/pipelined-mul-unit-ports"),
      () => LazyModule(new PipelinedMulUnitHarness()).module)(dut => new PipelinedMulUnitPortsTester(dut)))
  }
}
