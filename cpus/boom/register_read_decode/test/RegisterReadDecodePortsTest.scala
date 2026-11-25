package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import org.scalatest.flatspec.AnyFlatSpec

import boom.common._
import boom.exu.{RegisterReadDecode, SupportedFuncUnits}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.rocket.constants.MemoryOpConstants
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}

class RegisterReadDecodeTestHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(AddressSet(BigInt("80000000", 16), 0xffff), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new RegisterReadDecodeTestModule(this)
}

class RegisterReadDecodeTestModule(outer: RegisterReadDecodeTestHarness)
    extends LazyModuleImp(outer) with MemoryOpConstants {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  val decoder = Module(new RegisterReadDecode(new SupportedFuncUnits(alu = true, mem = true)))
  val io = IO(new Bundle {
    val opcodeClass = Input(UInt(2.W))
    val packed = Input(UInt(decoder.io.iss_uop.imm_packed.getWidth.W))
    val decoded = Output(UInt(decoder.io.rrd_uop.imm_packed.getWidth.W))
    val valid = Output(Bool())
  })
  decoder.io.iss_valid := true.B
  decoder.io.iss_uop := 0.U.asTypeOf(decoder.io.iss_uop)
  decoder.io.iss_uop.uopc := Mux(io.opcodeClass === 2.U, uopAMO_AG, uopLD)
  decoder.io.iss_uop.mem_cmd := Mux(io.opcodeClass === 0.U, M_XRD,
    Mux(io.opcodeClass === 1.U, M_XLR, M_XA_ADD))
  decoder.io.iss_uop.imm_packed := io.packed
  io.decoded := decoder.io.rrd_uop.imm_packed
  io.valid := decoder.io.rrd_valid
}

class RegisterReadDecodePortsTester(dut: RegisterReadDecodeTestModule) extends PeekPokeTester(dut) {
  private def compare(kind: Int, instruction: Int, expected: Int, label: String,
                      mask: BigInt = BigInt(-1)): Unit = {
    // DecodeUnit packs bits 31:12 for these instructions.
    poke(dut.io.opcodeClass, kind)
    poke(dut.io.packed, instruction >>> 12)
    val observed = peek(dut.io.decoded) & mask
    println(s"REGISTER_READ_DECODE_OBSERVATION $label expected=$expected actual=$observed")
    expect(dut.io.valid, 1, label)
    expect(observed == expected, label)
  }

  // The address calculation reads only imm_packed(19, 8).
  val offset = BigInt(0xfff00)
  compare(0, 0x00c2a303, 0x00c2a, "lw")
  compare(1, 0x1002a32f, 0, "lr-w", offset)
  compare(2, 0x0072a32f, 0, "amoadd-w", offset)
}

class RegisterReadDecodePortsTest extends AnyFlatSpec {
  it should "preserve load offsets and clear the offsets of LR and AMO" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    assert(Driver.execute(Array("--backend-name", "verilator", "--target-dir", "test_run_dir/register-read-decode"),
      () => LazyModule(new RegisterReadDecodeTestHarness()).module)(dut => new RegisterReadDecodePortsTester(dut)))
  }
}
