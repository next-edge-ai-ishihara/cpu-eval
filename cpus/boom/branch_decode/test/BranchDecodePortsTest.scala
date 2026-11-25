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

import boom.common.{BoomTileAttachParams, WithNLargeBooms}
import boom.exu.BranchDecode

class BranchDecodePortsHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }

  lazy val module = new BranchDecodePortsHarnessModule(this)
}

class BranchDecodePortsHarnessModule(outer: BranchDecodePortsHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  private implicit val configured: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  private val decoder = Module(new BranchDecode)
  val io = IO(chiselTypeOf(decoder.io))
  io <> decoder.io
}

class BranchDecodePortsTester(c: BranchDecodePortsHarnessModule) extends PeekPokeTester(c) {
  println("BranchDecode port observations started")
  private val pc = BigInt(0x200)

  private def check(instruction: BigInt, classification: Int, call: Boolean = false,
                    ret: Boolean = false, target: Option[BigInt] = None,
                    shortDistance: Option[Int] = None): Unit = {
    val instructionText = s"instruction 0x${instruction.toString(16)}"
    poke(c.io.inst, instruction)
    poke(c.io.pc, pc)
    step(1)
    expect(c.io.out.cfi_type, classification, instructionText)
    expect(c.io.out.is_call, if (call) 1 else 0, instructionText + " call")
    expect(c.io.out.is_ret, if (ret) 1 else 0, instructionText + " return")
    expect(c.io.out.sfb_offset.valid, if (shortDistance.isDefined) 1 else 0, instructionText + " short forward")
    target.foreach(address => expect(c.io.out.target, address, instructionText + " target"))
    shortDistance.foreach(distance => expect(c.io.out.sfb_offset.bits, distance, instructionText + " distance"))
  }

  private def jal(rd: Int, offset: Int): BigInt = {
    val bits = BigInt(offset) & 0x1fffff
    ((bits >> 20) << 31) | (((bits >> 1) & 0x3ff) << 21) | (((bits >> 11) & 1) << 20) |
      (((bits >> 12) & 0xff) << 12) | (rd << 7) | 0x6f
  }

  private def jalr(rd: Int, rs1: Int, immediate: Int): BigInt =
    (BigInt(immediate & 0xfff) << 20) | (rs1 << 15) | (rd << 7) | 0x67

  private def branch(function: Int, offset: Int): BigInt = {
    val bits = BigInt(offset) & 0x1fff
    ((bits >> 12) << 31) | (((bits >> 5) & 0x3f) << 25) | (function << 12) |
      (((bits >> 1) & 0xf) << 8) | (((bits >> 11) & 1) << 7) | 0x63
  }

  for (rd <- Seq(0, 1, 5, 9); offset <- Seq(16, -16)) {
    check(jal(rd, offset), 2, call = rd == 1, target = Some(pc + offset))
  }
  for (rd <- Seq(0, 1, 5, 9); rs1 <- Seq(1, 5, 6, 10); immediate <- Seq(0, 4, -4)) {
    check(jalr(rd, rs1, immediate), 3, call = rd == 1, ret = rd == 0 && Set(1, 5)(rs1))
  }
  for (function <- Seq(0, 1, 4, 5, 6, 7); offset <- Seq(-4, 0, 2, 62, 64, 66)) {
    val shortDistance = if (offset > 0 && offset < 64) Some(offset) else None
    check(branch(function, offset), 1, target = Some(pc + offset), shortDistance = shortDistance)
  }
  check(0x00001067, 0)
  check(0x00002063, 0)
  check(0x00000013, 0)
}

class BranchDecodePortsTest extends AnyFlatSpec with Matchers {
  behavior of "BranchDecode"

  it should "classify control flow and report direct targets at its public ports" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver.execute(Array("--backend-name", "verilator"), () => LazyModule(new BranchDecodePortsHarness).module)(
      c => new BranchDecodePortsTester(c)) should be(true)
  }
}
