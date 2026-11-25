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

import boom.common._
import boom.exu.FDivSqrtUnit
import boom.exu.FUConstants.FU_FDV
import hardfloat.{fNFromRecFN, recFNFromFN}

class FDivSqrtWritebackHarness(implicit p: Parameters) extends LazyModule {
  val visibility = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibility := fuzz.node }
  lazy val module = new FDivSqrtWritebackHarnessModule(this)
}

class FDivSqrtWritebackHarnessModule(outer: FDivSqrtWritebackHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibility
  }
  private val dut = Module(new FDivSqrtUnit)
  private val maskWidth = dut.io.req.bits.uop.br_mask.getWidth
  private val tagWidth = dut.io.req.bits.uop.rob_idx.getWidth
  val io = IO(new Bundle {
    val reqValid = Input(Bool())
    val reqReady = Output(Bool())
    val reqSqrt = Input(Bool())
    val reqTag = Input(UInt(tagWidth.W))
    val reqMask = Input(UInt(maskWidth.W))
    val operand1 = Input(UInt(64.W))
    val operand2 = Input(UInt(64.W))
    val mispredict = Input(UInt(maskWidth.W))
    val respValid = Output(Bool())
    val respReady = Input(Bool())
    val respTag = Output(UInt(tagWidth.W))
    val respData = Output(UInt(64.W))
    val flagsValid = Output(Bool())
    val flagsTag = Output(UInt(tagWidth.W))
    val flags = Output(UInt(5.W))
  })
  dut.io.req.valid := io.reqValid
  dut.io.req.bits := 0.U.asTypeOf(dut.io.req.bits)
  dut.io.req.bits.uop.uopc := Mux(io.reqSqrt, uopFSQRT_D, uopFDIV_D)
  dut.io.req.bits.uop.fu_code := FU_FDV
  dut.io.req.bits.uop.fp_val := true.B
  dut.io.req.bits.uop.ldst_val := true.B
  dut.io.req.bits.uop.rob_idx := io.reqTag
  dut.io.req.bits.uop.br_mask := io.reqMask
  dut.io.req.bits.rs1_data := recFNFromFN(11, 53, io.operand1)
  dut.io.req.bits.rs2_data := recFNFromFN(11, 53, io.operand2)
  dut.io.fcsr_rm := 0.U
  dut.io.brupdate.b1.resolve_mask := io.mispredict
  dut.io.brupdate.b1.mispredict_mask := io.mispredict
  dut.io.brupdate.b2 := DontCare
  dut.io.brupdate.b2.valid := false.B
  dut.io.brupdate.b2.target_offset := 0.S
  io.reqReady := dut.io.req.ready
  dut.io.resp.ready := io.respReady
  io.respValid := dut.io.resp.valid
  io.respTag := dut.io.resp.bits.uop.rob_idx
  io.respData := fNFromRecFN(11, 53, dut.io.resp.bits.data)
  io.flagsValid := dut.io.resp.bits.fflags.valid
  io.flagsTag := dut.io.resp.bits.fflags.bits.uop.rob_idx
  io.flags := dut.io.resp.bits.fflags.bits.flags
}

class FDivSqrtWritebackTester(c: FDivSqrtWritebackHarnessModule) extends PeekPokeTester(c) {
  private val io = c.io
  private def bits(hex: String): BigInt = BigInt(hex, 16)
  private def waitReady(signal: Bool, label: String): Unit = {
    var waited = 0
    while (peek(signal) == 0 && waited < 4096) { step(1); waited += 1 }
    assert(peek(signal) == 1, s"$label timed out")
  }
  private def issue(tag: Int, mask: Int, a: String, b: String, sqrt: Boolean = false): Unit = {
    waitReady(io.reqReady, s"request $tag ready")
    poke(io.reqTag, tag)
    poke(io.reqMask, mask)
    poke(io.reqSqrt, if (sqrt) 1 else 0)
    poke(io.operand1, bits(a))
    poke(io.operand2, bits(b))
    poke(io.reqValid, 1)
    step(1)
    poke(io.reqValid, 0)
  }
  private def result(tag: Int, value: String, flagBits: Int, label: String): Unit = {
    expect(io.respValid, 1, s"$label response valid")
    expect(io.respTag, tag, s"$label response tag")
    expect(io.respData, bits(value), s"$label value")
    expect(io.flagsValid, 1, s"$label flags valid")
    expect(io.flagsTag, tag, s"$label flags tag")
    expect(io.flags, flagBits, s"$label flags")
  }
  private val one = "3ff0000000000000"
  private val two = "4000000000000000"
  private val three = "4008000000000000"
  private val four = "4010000000000000"
  private val third = "3fd5555555555555"

  poke(io.reqValid, 0)
  poke(io.respReady, 0)
  poke(io.mispredict, 0)
  issue(11, 0, one, three)
  step(32)
  // A design with a second entry may accept the next operation now.
  val queued = peek(io.reqReady) != 0
  def issueSecond(): Unit = issue(5, 0, "4022000000000000", two, sqrt = true)
  if (queued) issueSecond()
  step(2)
  poke(io.respReady, 1)
  waitReady(io.respValid, "held value and flags")
  result(11, third, 1, "held value and flags")
  step(1)
  if (!queued) {
    poke(io.respReady, 0)
    issueSecond()
    poke(io.respReady, 1)
  }
  waitReady(io.respValid, "independent queued result")
  result(5, three, 0, "independent queued result")
  step(1)

  poke(io.respReady, 0)
  issue(17, 1, one, three)
  step(32)
  poke(io.mispredict, 1)
  poke(io.respReady, 1)
  expect(io.respValid, 0, "mispredicted held result must not write back")
  expect(io.flagsValid, 0, "mispredicted held flags must not write back")
  step(1)
  poke(io.mispredict, 0)

  // Cancel an operation by misprediction before its result is produced.
  poke(io.respReady, 0)
  issue(19, 4, two, three, sqrt = true)
  step(3)
  poke(io.mispredict, 4)
  step(1)
  poke(io.mispredict, 0)
  issue(15, 0, "4028000000000000", three)
  poke(io.respReady, 1)
  waitReady(io.respValid, "only the survivor may write back")
  result(15, four, 0, "only the survivor may write back")
  step(1)
}

class FDivSqrtWritebackTest extends AnyFlatSpec with Matchers {
  behavior of "FDivSqrtUnit"

  it should "retain a blocked result and suppress wrong-path data and flags" in {
    implicit val p: Parameters =
      new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver(() => LazyModule(new FDivSqrtWritebackHarness).module)(
      c => new FDivSqrtWritebackTester(c)) should be(true)
  }
}
