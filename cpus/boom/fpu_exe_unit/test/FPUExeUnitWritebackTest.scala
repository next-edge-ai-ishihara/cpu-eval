package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}
import hardfloat.{fNFromRecFN, recFNFromFN}
import org.scalatest.flatspec.AnyFlatSpec

import boom.common._
import boom.exu.FPUExeUnit
import boom.exu.FUConstants.{FU_FDV, FU_FPU}

class FPUExeUnitWritebackHarness(implicit p: Parameters) extends LazyModule {
  val visibility = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibility := fuzz.node }
  lazy val module = new FPUExeUnitWritebackHarnessModule(this)
}

class FPUExeUnitWritebackHarnessModule(outer: FPUExeUnitWritebackHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibility
  }
  private val dut = Module(new FPUExeUnit(hasFpu = true, hasFdiv = true, hasFpiu = true))
  private val tagWidth = dut.io.req.bits.uop.rob_idx.getWidth
  val io = IO(new Bundle {
    val reqValid = Input(Bool())
    val reqDivide = Input(Bool())
    val reqTag = Input(UInt(tagWidth.W))
    val fuTypes = Output(UInt(dut.io.fu_types.getWidth.W))
    val respValid = Output(Bool())
    val respTag = Output(UInt(tagWidth.W))
    val respData = Output(UInt(64.W))
    val flagsValid = Output(Bool())
    val flagsTag = Output(UInt(tagWidth.W))
    val flags = Output(UInt(5.W))
  })

  dut.io.req.valid := io.reqValid
  dut.io.req.bits := 0.U.asTypeOf(dut.io.req.bits)
  dut.io.req.bits.uop.uopc := Mux(io.reqDivide, uopFDIV_D, uopFADD_D)
  dut.io.req.bits.uop.fu_code := Mux(io.reqDivide, FU_FDV, FU_FPU)
  dut.io.req.bits.uop.fp_val := true.B
  dut.io.req.bits.uop.ldst_val := true.B
  dut.io.req.bits.uop.dst_rtype := RT_FLT
  dut.io.req.bits.uop.rob_idx := io.reqTag
  dut.io.req.bits.rs1_data := recFNFromFN(11, 53, "h3ff0000000000000".U(64.W))
  dut.io.req.bits.rs2_data := recFNFromFN(11, 53,
    Mux(io.reqDivide, "h4008000000000000".U(64.W), "h4000000000000000".U(64.W)))
  dut.io.req.bits.rs3_data := recFNFromFN(11, 53, 0.U(64.W))
  dut.io.fcsr_rm := 0.U
  dut.io.status := 0.U.asTypeOf(dut.io.status)
  dut.io.brupdate.b1.resolve_mask := 0.U
  dut.io.brupdate.b1.mispredict_mask := 0.U
  dut.io.brupdate.b2 := DontCare
  dut.io.brupdate.b2.valid := false.B
  dut.io.brupdate.b2.target_offset := 0.S
  dut.io.fresp.ready := true.B
  dut.io.ll_iresp.ready := true.B
  io.fuTypes := dut.io.fu_types
  io.respValid := dut.io.fresp.valid
  io.respTag := dut.io.fresp.bits.uop.rob_idx
  io.respData := fNFromRecFN(11, 53, dut.io.fresp.bits.data)
  io.flagsValid := dut.io.fresp.bits.fflags.valid
  io.flagsTag := dut.io.fresp.bits.fflags.bits.uop.rob_idx
  io.flags := dut.io.fresp.bits.fflags.bits.flags
}

class FPUExeUnitWritebackTester(c: FPUExeUnitWritebackHarnessModule) extends PeekPokeTester(c) {
  private val io = c.io
  private val divideTag = 1
  private val addTags = 2 to 41
  private val expectedTags = (divideTag +: addTags).toSet
  private val seen = scala.collection.mutable.Set.empty[Int]
  private val sum = BigInt("4008000000000000", 16)
  private val third = BigInt("3fd5555555555555", 16)
  private var cycle = 0

  private def tick(): Unit = {
    if (peek(io.respValid) == 1) {
      val tag = peek(io.respTag).toInt
      assert(expectedTags(tag), s"unexpected writeback for tag $tag")
      assert(seen.add(tag), s"duplicate writeback for tag $tag")
      expect(io.respData, if (tag == divideTag) third else sum, s"writeback value for tag $tag")
      expect(io.flagsValid, 1, s"flags valid for tag $tag")
      expect(io.flagsTag, tag, s"flags tag for tag $tag")
      expect(io.flags, if (tag == divideTag) 1 else 0, s"exception flags for tag $tag")
      if (tag == divideTag) println(s"FPU_EXE_DIVIDE_WRITEBACK cycle=$cycle flags=1")
    }
    step(1)
    cycle += 1
  }

  poke(io.reqValid, 0)
  poke(io.reqDivide, 0)
  poke(io.reqTag, 0)
  step(4)
  println("FPU_EXE_WRITEBACK_OBSERVATION_STARTED")
  assert((peek(io.fuTypes) & 128) != 0, "division functional unit is available")
  poke(io.reqDivide, 1)
  poke(io.reqTag, divideTag)
  poke(io.reqValid, 1)
  tick()

  poke(io.reqDivide, 0)
  // Issue independent fixed-latency results while the division is in flight.
  // Collect writebacks by tag so the check does not prescribe an arbitration order.
  for (tag <- addTags) {
    val deadline = cycle + 100
    poke(io.reqValid, 0)
    while ((peek(io.fuTypes) & 64) == 0 && cycle < deadline) tick()
    assert((peek(io.fuTypes) & 64) != 0, s"addition functional unit became unavailable for tag $tag")
    poke(io.reqTag, tag)
    poke(io.reqValid, 1)
    tick()
  }
  poke(io.reqValid, 0)
  for (_ <- 0 until 100) tick()
  val missing = (expectedTags -- seen).toSeq.sorted
  println(s"FPU_EXE_WRITEBACKS received=${seen.size} missing=${missing.mkString(",")}")
  assert(missing.isEmpty, s"missing writeback for tags ${missing.mkString(",")}")
}

class FPUExeUnitWritebackTest extends AnyFlatSpec {
  it should "return every arithmetic result and its flags through the shared write port" in {
    implicit val p: Parameters =
      new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    assert(Driver.execute(Array("--backend-name", "firrtl", "--test-seed", "1"),
      () => LazyModule(new FPUExeUnitWritebackHarness).module)(c => new FPUExeUnitWritebackTester(c)))
  }
}
