package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import org.scalatest.flatspec.AnyFlatSpec

import boom.common._
import boom.exu.{RegisterRead, SupportedFuncUnits}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}

class RegisterReadFlushHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(AddressSet(BigInt("80000000", 16), 0xffff), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new RegisterReadFlushHarnessModule(this)
}

class RegisterReadFlushHarnessModule(outer: RegisterReadFlushHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  private val units = Seq(
    new SupportedFuncUnits(mem = true),
    new SupportedFuncUnits(alu = true, jmp = true, muld = true),
    new SupportedFuncUnits(alu = true, csr = true, ifpu = true),
    new SupportedFuncUnits(alu = true, muld = true)
  )
  private val lane = 1
  val dut = Module(new RegisterRead(4, units, 8, Seq.fill(4)(2), 5, 1, 64))
  val io = IO(new Bundle {
    val issued = Input(Bool())
    val flush = Input(Bool())
    val execute = Output(Bool())
    val lhs = Output(UInt(64.W))
    val rhs = Output(UInt(64.W))
  })
  dut.io <> DontCare
  dut.io.iss_valids.foreach(_ := false.B)
  dut.io.iss_valids(lane) := io.issued
  dut.io.iss_uops.foreach(uop => uop := 0.U.asTypeOf(uop))
  dut.io.iss_uops(lane).uopc := uopADD
  dut.io.iss_uops(lane).prs1 := 5.U
  dut.io.iss_uops(lane).prs2 := 7.U
  dut.io.iss_uops(lane).lrs1_rtype := RT_FIX
  dut.io.iss_uops(lane).lrs2_rtype := RT_FIX
  dut.io.bypass.foreach(_.valid := false.B)
  dut.io.pred_bypass.foreach(_.valid := false.B)
  dut.io.kill := io.flush
  dut.io.brupdate.b1.resolve_mask := 0.U
  dut.io.brupdate.b1.mispredict_mask := 0.U
  dut.io.brupdate.b2.valid := false.B
  dut.io.brupdate.b2.mispredict := false.B
  dut.io.brupdate.b2.target_offset := 0.S
  dut.io.rf_read_ports.foreach(port => port.data := RegNext((port.addr << 1) + 1.U))
  dut.io.prf_read_ports.foreach(_.data := false.B)
  dut.io.exe_reqs.foreach(_.ready := true.B)
  io.execute := dut.io.exe_reqs(lane).valid
  io.lhs := dut.io.exe_reqs(lane).bits.rs1_data
  io.rhs := dut.io.exe_reqs(lane).bits.rs2_data
}

class RegisterReadFlushTester(dut: RegisterReadFlushHarnessModule) extends PeekPokeTester(dut) {
  poke(dut.io.issued, 0)
  poke(dut.io.flush, 0)
  step(2)
  println("REGISTER_READ_FLUSH_OBSERVATIONS_STARTED")
  poke(dut.io.issued, 1)
  step(1)
  expect(dut.io.execute, 0, "the request is still reading its operands")
  poke(dut.io.issued, 0)
  step(1)
  expect(dut.io.execute, 1, "the unflushed request reaches execution")
  expect(dut.io.lhs, 11, "the first operand came from the one-cycle register file")
  expect(dut.io.rhs, 15, "the second operand came from the one-cycle register file")
  poke(dut.io.issued, 1)
  step(1)
  poke(dut.io.issued, 0)
  poke(dut.io.flush, 1)
  step(1)
  println(s"REGISTER_READ_FLUSH_OBSERVED valid=${peek(dut.io.execute)}")
  expect(dut.io.execute, 0, "a global pipeline flush cancels the request in register read")
}

class RegisterReadFlushTest extends AnyFlatSpec {
  it should "cancel an issued request when the core flushes the register-read stage" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    assert(Driver.execute(Array("--backend-name", "verilator", "--target-dir", "test_run_dir/register-read-flush"),
      () => LazyModule(new RegisterReadFlushHarness()).module)(dut => new RegisterReadFlushTester(dut)))
  }
}
