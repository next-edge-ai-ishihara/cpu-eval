package boom.tests

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.rocket.Causes
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}

import boom.common.{BoomTileAttachParams, WithNLargeBooms}
import boom.exu.DecodeUnit

class DecodeUnitPortsHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new DecodeUnitPortsHarnessModule(this)
}

class DecodeUnitPortsHarnessModule(outer: DecodeUnitPortsHarness)
  extends LazyModuleImp(outer) with freechips.rocketchip.rocket.constants.MemoryOpConstants {
  val io = IO(new Bundle {
    val inst = Input(UInt(32.W))
    val systemIllegal = Input(Bool())
    val readIllegal = Input(Bool())
    val writeIllegal = Input(Bool())
    val csrInst = Output(UInt(32.W))
    val exception = Output(Bool())
    val cause = Output(UInt(64.W))
    val fence = Output(Bool())
    val fenceSelectors = Output(UInt(2.W))
  })

  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  private val dut = Module(new DecodeUnit)
  dut.io.enq.uop := 0.U.asTypeOf(dut.io.enq.uop)
  dut.io.enq.uop.inst := io.inst
  dut.io.status := 0.U.asTypeOf(dut.io.status)
  dut.io.status.prv := 1.U
  dut.io.interrupt := false.B
  dut.io.interrupt_cause := 0.U
  dut.io.csr_decode.fp_illegal := false.B
  dut.io.csr_decode.vector_illegal := false.B
  dut.io.csr_decode.fp_csr := false.B
  dut.io.csr_decode.rocc_illegal := false.B
  dut.io.csr_decode.read_illegal := io.readIllegal
  dut.io.csr_decode.write_illegal := io.writeIllegal
  dut.io.csr_decode.write_flush := false.B
  dut.io.csr_decode.system_illegal := io.systemIllegal
  dut.io.csr_decode.virtual_access_illegal := false.B
  dut.io.csr_decode.virtual_system_illegal := false.B

  io.csrInst := dut.io.csr_decode.inst
  io.exception := dut.io.deq.uop.exception
  io.cause := dut.io.deq.uop.exc_cause
  io.fence := dut.io.deq.uop.mem_cmd === M_SFENCE
  io.fenceSelectors := dut.io.deq.uop.mem_size
}

class DecodeUnitPortsTester(c: DecodeUnitPortsHarnessModule) extends PeekPokeTester(c) {
  private def check(label: String, inst: BigInt, systemIllegal: Boolean = false,
                    readIllegal: Boolean = false, writeIllegal: Boolean = false,
                    rejected: Boolean = false): Unit = {
    poke(c.io.inst, inst)
    poke(c.io.systemIllegal, if (systemIllegal) 1 else 0)
    poke(c.io.readIllegal, if (readIllegal) 1 else 0)
    poke(c.io.writeIllegal, if (writeIllegal) 1 else 0)
    expect(c.io.csrInst, inst)
    expect(peek(c.io.exception) == (if (rejected) 1 else 0), s"$label: exception")
    if (rejected) {
      expect(peek(c.io.cause) == Causes.illegal_instruction, s"$label: illegal-instruction cause")
    }
    println(s"DECODE_PORT_CASE $label")
  }

  for (rs1 <- Seq(0, 5); rs2 <- Seq(0, 7)) {
    val inst = BigInt(0x12000073 | (rs1 << 15) | (rs2 << 20))
    check(s"sfence-allow-$rs1-$rs2", inst)
    expect(c.io.fence, 1)
    expect(c.io.fenceSelectors, (if (rs2 != 0) 2 else 0) + (if (rs1 != 0) 1 else 0))
    check(s"sfence-deny-$rs1-$rs2", inst, systemIllegal = true, rejected = true)
  }

  // CSRRS reads cycle but may not write it, including when x5's value happens to be zero.
  check("csrrs-x0", BigInt("c00022f3", 16), writeIllegal = true)
  check("csrrs-x5", BigInt("c002a2f3", 16), writeIllegal = true, rejected = true)
  check("csrrsi-zero", BigInt("c00062f3", 16), writeIllegal = true)
  check("csrrsi-one", BigInt("c000e2f3", 16), writeIllegal = true, rejected = true)
  check("csrrs-read-denied", BigInt("c00022f3", 16), readIllegal = true,
    writeIllegal = true, rejected = true)
  check("addi-system-flag-inapplicable", BigInt("fff00293", 16), systemIllegal = true)
}

class DecodeUnitPortsTest extends AnyFlatSpec with Matchers {
  behavior of "DecodeUnit"

  it should "report applicable CSR legality and SFENCE.VMA operand selectors at its ports" in {
    implicit val p: Parameters =
      new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver(() => LazyModule(new DecodeUnitPortsHarness).module)(
      c => new DecodeUnitPortsTester(c)) should be(true)
  }
}
