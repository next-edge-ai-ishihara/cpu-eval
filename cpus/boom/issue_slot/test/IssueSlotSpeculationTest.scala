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
import org.scalatest.matchers.should.Matchers

import boom.common._
import boom.exu.{IssueSlot, IssueUnitConstants}

class IssueSlotSpeculationHarness(splitStore: Boolean)(implicit p: Parameters) extends LazyModule {
  val visibility = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibility := fuzz.node }

  lazy val module = new IssueSlotSpeculationHarnessModule(this, splitStore)
}

class IssueSlotSpeculationHarnessModule(outer: IssueSlotSpeculationHarness, splitStore: Boolean)
    extends LazyModuleImp(outer) with IssueUnitConstants {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibility
  }
  private val slot = Module(new IssueSlot(1))
  val io = IO(new Bundle {
    val insert = Input(Bool())
    val speculate = Input(Bool())
    val miss = Input(Bool())
    val wake = Input(Bool())
    val grant = Input(Bool())
    val valid = Output(Bool())
    val request = Output(Bool())
    val remains = Output(Bool())
    val travellingState = Output(UInt(2.W))
    val travellingOpcode = Output(chiselTypeOf(slot.io.out_uop.uopc))
    val issuedWithPoison = Output(Bool())
    val issuedAddressSource = Output(chiselTypeOf(slot.io.uop.prs1))
  })

  slot.io.kill := false.B
  slot.io.clear := false.B
  slot.io.brupdate.b1.resolve_mask := 0.U
  slot.io.brupdate.b1.mispredict_mask := 0.U
  slot.io.brupdate.b2 := DontCare
  slot.io.brupdate.b2.valid := false.B
  slot.io.brupdate.b2.target_offset := 0.S
  slot.io.pred_wakeup_port := 0.U.asTypeOf(slot.io.pred_wakeup_port)
  slot.io.in_uop.valid := io.insert
  slot.io.in_uop.bits := 0.U.asTypeOf(slot.io.in_uop.bits)
  slot.io.in_uop.bits.iw_state := (if (splitStore) s_valid_2 else s_valid_1)
  slot.io.in_uop.bits.uopc := (if (splitStore) uopSTA else uopADD)
  slot.io.in_uop.bits.prs1 := 17.U
  slot.io.in_uop.bits.lrs1_rtype := RT_FIX
  slot.io.in_uop.bits.prs1_busy := true.B
  slot.io.in_uop.bits.prs2 := 19.U
  slot.io.in_uop.bits.lrs2_rtype := RT_FIX
  slot.io.in_uop.bits.prs2_busy := splitStore.B
  slot.io.wakeup_ports(0).valid := io.wake
  slot.io.wakeup_ports(0).bits.pdst := 17.U
  slot.io.wakeup_ports(0).bits.poisoned := false.B
  slot.io.spec_ld_wakeup := 0.U.asTypeOf(slot.io.spec_ld_wakeup)
  slot.io.spec_ld_wakeup(0).valid := io.speculate
  slot.io.spec_ld_wakeup(0).bits := 17.U
  slot.io.ldspec_miss := io.miss
  slot.io.grant := io.grant
  io.valid := slot.io.valid
  io.request := slot.io.request
  io.remains := slot.io.will_be_valid
  io.travellingState := slot.io.out_uop.iw_state
  io.travellingOpcode := slot.io.out_uop.uopc
  io.issuedWithPoison := slot.io.uop.iw_p1_poisoned
  io.issuedAddressSource := slot.io.uop.prs1
}

class IssueSlotSpeculationTester(dut: IssueSlotSpeculationHarnessModule, splitStore: Boolean)
    extends PeekPokeTester(dut) {
  private val io = dut.io
  private val tag = if (splitStore) "split store" else "single operation"
  poke(io.insert, 0)
  poke(io.speculate, 0)
  poke(io.miss, 0)
  poke(io.wake, 0)
  poke(io.grant, 0)
  step(1)
  println(s"IssueSlot speculation observations started: $tag")

  poke(io.insert, 1)
  step(1)
  poke(io.insert, 0)
  expect(io.valid, 1)
  expect(io.request, 0)
  val waitingState = peek(io.travellingState)
  val waitingOpcode = peek(io.travellingOpcode)

  poke(io.speculate, 1)
  step(1)
  poke(io.speculate, 0)
  expect(io.request, 1)
  expect(io.issuedWithPoison, 1)
  poke(io.grant, 1)
  poke(io.miss, 1)
  println(s"IssueSlot failed speculation: $tag remains=${peek(io.remains)} state=${peek(io.travellingState)} expectedState=$waitingState")
  expect(io.remains, 1, s"$tag must remain available to the parent queue when speculation fails")
  expect(io.travellingState, waitingState, s"$tag must retain its unissued work")
  expect(io.travellingOpcode, waitingOpcode)
  step(1)
  poke(io.grant, 0)
  poke(io.miss, 0)
  expect(io.valid, 1)
  expect(io.request, 0)

  poke(io.wake, 1)
  step(1)
  poke(io.wake, 0)
  expect(io.request, 1)
  expect(io.issuedWithPoison, 0)
  expect(io.issuedAddressSource, 17)
  poke(io.grant, 1)
  expect(io.remains, if (splitStore) 1 else 0)
  step(1)
  poke(io.grant, 0)
  expect(io.valid, if (splitStore) 1 else 0)
  println(s"IssueSlot ordinary wakeup reissued: $tag")
}

class IssueSlotSpeculationTest extends AnyFlatSpec with Matchers {
  behavior of "IssueSlot"

  for (splitStore <- Seq(false, true)) {
    it should s"retry after failed load speculation with splitStore=$splitStore" in {
      implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
      Driver(() => LazyModule(new IssueSlotSpeculationHarness(splitStore)).module)(
        dut => new IssueSlotSpeculationTester(dut, splitStore)) should be(true)
    }
  }
}
