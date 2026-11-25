// SPDX-License-Identifier: Apache-2.0
package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}
import org.scalatest.flatspec.AnyFlatSpec

import boom.common.{BoomTileAttachParams, WithNLargeBooms}
import boom.exu.RegisterFileSynthesizable

class RegisterFileWriteTimingHarness(implicit p: Parameters) extends LazyModule {
  val visibility = TLEphemeralNode()
  private val source = LazyModule(new TLFuzzer(1))
  private val memory = LazyModule(new TLRAM(AddressSet(BigInt("80000000", 16), 0xffff), beatBytes = 16))
  DisableMonitors { implicit p => memory.node := visibility := source.node }
  lazy val module = new RegisterFileWriteTimingModule(this)
}

class RegisterFileWriteTimingModule(outer: RegisterFileWriteTimingHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attached: BoomTileAttachParams => attached.tileParams
  }.get
  implicit val testParameters: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibility
  }
  // Large BOOM's FP issue unit has one three-operand reader and one writer.
  // The other write port is the long-latency writeback, and neither forwards.
  private val registerFile = Module(new RegisterFileSynthesizable(96, 3, 2, 65, Seq(false, false)))
  val io = IO(new Bundle {
    val address = Input(UInt(7.W))
    val valid = Input(Bool())
    val data = Input(UInt(65.W))
    val read = Output(UInt(65.W))
  })
  registerFile.io.read_ports.foreach(_.addr := io.address)
  registerFile.io.write_ports(0).valid := io.valid
  registerFile.io.write_ports(0).bits.addr := io.address
  registerFile.io.write_ports(0).bits.data := io.data
  registerFile.io.write_ports(1) := 0.U.asTypeOf(registerFile.io.write_ports(1))
  io.read := registerFile.io.read_ports(0).data
}

class RegisterFileWriteTimingTester(dut: RegisterFileWriteTimingModule) extends PeekPokeTester(dut) {
  private val io = dut.io
  private val oldValue = BigInt(29)
  private val newValue = (BigInt(1) << 64) + 73
  poke(io.address, 11)
  poke(io.valid, 1)
  poke(io.data, oldValue)
  step(1)
  poke(io.valid, 0)
  expect(io.read, oldValue)

  poke(io.data, newValue)
  poke(io.valid, 1)
  println(s"FP register file before write edge: observed=${peek(io.read)} expected=$oldValue")
  val beforeEdge = expect(io.read, oldValue, "a disabled bypass returns the stored value before the write edge")
  step(1)
  poke(io.valid, 0)
  println(s"FP register file after write edge: observed=${peek(io.read)} expected=$newValue")
  val afterEdge = expect(io.read, newValue, "the same valid write updates storage at the edge")
  if (!beforeEdge || !afterEdge) println("REGISTER_FILE_WRITE_TIMING_MISMATCH")
}

class RegisterFileWriteTimingTest extends AnyFlatSpec {
  "RegisterFileSynthesizable" should "write through the FP ports without forwarding before the edge" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    assert(Driver.execute(Array("--backend-name", "firrtl"), () => LazyModule(new RegisterFileWriteTimingHarness).module)(
      dut => new RegisterFileWriteTimingTester(dut)))
  }
}
