// SPDX-License-Identifier: Apache-2.0
package boom.tests

import boom.common.{BoomTileAttachParams, WithNLargeBooms, uopSFENCE}
import boom.exu.FUConstants.FU_MEM
import boom.exu.MemAddrCalcUnit
import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import chisel3.util.Cat
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.rocket.constants.MemoryOpConstants
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.system.BaseConfig
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}
import org.scalatest.flatspec.AnyFlatSpec

class MemAddrFenceHarness(implicit p: Parameters) extends LazyModule {
  val visibility = TLEphemeralNode()
  private val client = LazyModule(new TLFuzzer(1))
  private val memory = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("00000fff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => memory.node := visibility := client.node }
  lazy val module = new MemAddrFenceModule(this)
}

class MemAddrFenceModule(outer: MemAddrFenceHarness)
  extends LazyModuleImp(outer) with MemoryOpConstants {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  private val parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibility
  }
  private val unit = Module(new MemAddrCalcUnit()(parameters))
  val io = IO(new Bundle {
    val request = Input(Bool())
    val selectors = Input(UInt(2.W))
    val rs1 = Input(UInt(64.W))
    val rs2 = Input(UInt(64.W))
    val fence = Output(Bool())
    val selected = Output(UInt(2.W))
    val address = Output(chiselTypeOf(unit.io.resp.bits.sfence.bits.addr))
  })
  private val logicalRs1 = Mux(io.selectors(0), 10.U(5.W), 0.U(5.W))
  private val logicalRs2 = Mux(io.selectors(1), 11.U(5.W), 0.U(5.W))
  unit.io.req.valid := io.request
  unit.io.req.bits := 0.U.asTypeOf(unit.io.req.bits)
  unit.io.req.bits.uop.uopc := uopSFENCE
  unit.io.req.bits.uop.fu_code := FU_MEM
  unit.io.req.bits.uop.mem_cmd := M_SFENCE
  unit.io.req.bits.uop.mem_size := io.selectors
  unit.io.req.bits.uop.lrs1 := logicalRs1
  unit.io.req.bits.uop.lrs2 := logicalRs2
  unit.io.req.bits.uop.prs1 := logicalRs1
  unit.io.req.bits.uop.prs2 := logicalRs2
  unit.io.req.bits.uop.imm_packed := Cat("b0001001".U(7.W), logicalRs2, logicalRs1, 0.U(3.W))
  unit.io.req.bits.rs1_data := io.rs1
  unit.io.req.bits.rs2_data := io.rs2
  unit.io.resp.ready := true.B
  unit.io.brupdate.b1.resolve_mask := 0.U
  unit.io.brupdate.b1.mispredict_mask := 0.U
  unit.io.brupdate.b2 := DontCare
  unit.io.brupdate.b2.valid := false.B
  unit.io.brupdate.b2.mispredict := false.B
  unit.io.brupdate.b2.target_offset := 0.S
  unit.io.status := 0.U.asTypeOf(unit.io.status)
  unit.io.status.prv := 1.U
  unit.io.bp := DontCare
  unit.io.mcontext := 0.U
  unit.io.scontext := 0.U
  val fence = unit.io.resp.bits.sfence
  io.fence := fence.valid
  io.selected := Cat(fence.bits.rs2, fence.bits.rs1)
  io.address := fence.bits.addr
}

class MemAddrFenceTester(dut: MemAddrFenceModule) extends PeekPokeTester(dut) {
  private val io = dut.io
  poke(io.request, 0)
  poke(io.selectors, 0)
  poke(io.rs1, 0)
  poke(io.rs2, 0)
  step(2)
  println("MEMADDR_FENCE_START")
  expect(io.fence, 0, "the invalid request does not issue a fence")

  private def fence(selectors: Int, rs1: BigInt, rs2: BigInt, name: String): Unit = {
    poke(io.selectors, selectors)
    poke(io.rs1, rs1)
    poke(io.rs2, rs2)
    expect(io.fence, 1, s"$name issues a fence")
    expect(io.selected, selectors, s"$name preserves operand selection")
    if ((selectors & 1) != 0) {
      expect(io.address, rs1, s"$name forwards the selected virtual address")
    }
    step(1)
  }
  poke(io.request, 1)
  fence(0, 0, 0, "global fence")
  fence(1, BigInt("23000", 16), 0, "one virtual page")
  fence(1, 0, 0, "a selected address with value zero")
  fence(2, 0, 1, "non-global translations")
  fence(3, BigInt("85000", 16), 0, "two selected operands including a zero ASID value")
  println("MEMADDR_FENCE_OBSERVED")
}

class MemAddrFenceTest extends AnyFlatSpec {
  "MemAddrCalcUnit" should "forward the selected SFENCE.VMA operands" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new BaseConfig
    assert(Driver.execute(Array("--backend-name", "treadle", "--target-dir",
      sys.env.getOrElse("CPU_EVAL_DIRECTED_TARGET", "test_run_dir")),
      () => LazyModule(new MemAddrFenceHarness).module)(dut => new MemAddrFenceTester(dut)))
  }
}
