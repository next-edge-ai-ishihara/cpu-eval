package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import chisel3.util.log2Ceil
import org.scalatest.flatspec.AnyFlatSpec

import boom.common._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.devices.debug.DebugModuleKey
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.rocket.{TLB, TLBConfig}
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._

class InstructionTLBTranslationHarness(implicit p: Parameters) extends LazyModule {
  private val fuzzer = LazyModule(new TLFuzzer(1))
  val visibilityNode = TLEphemeralNode()
  val memory = TLManagerNode(Seq(TLSlavePortParameters.v1(
    Seq(TLSlaveParameters.v1(
      address = Seq(AddressSet(BigInt("80000000", 16), BigInt("3fffffff", 16))),
      regionType = RegionType.CACHED,
      executable = true,
      supportsGet = TransferSizes(1, 64),
      supportsPutFull = TransferSizes(1, 64),
      supportsPutPartial = TransferSizes(1, 64),
      supportsAcquireB = TransferSizes(64),
      supportsAcquireT = TransferSizes(64))),
    beatBytes = 16, endSinkId = 4)))
  DisableMonitors { implicit p => memory := visibilityNode := fuzzer.node }
  lazy val module = new InstructionTLBTranslationHarnessModule(this)
}

class InstructionTLBTranslationHarnessModule(outer: InstructionTLBTranslationHarness)
    extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val tileParameters: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
    case DebugModuleKey => None
  }
  implicit val edge: TLEdgeOut = outer.visibilityNode.edges.out.head
  private val icache = tile.icache.get
  private val dut = Module(new TLB(true, log2Ceil(icache.fetchBytes),
    TLBConfig(icache.nTLBSets, icache.nTLBWays)))
  val io = IO(chiselTypeOf(dut.io))
  io <> dut.io

  for ((port, _) <- outer.memory.in) {
    port.a.ready := false.B
    port.b.valid := false.B
    port.b.bits := 0.U.asTypeOf(port.b.bits)
    port.c.ready := true.B
    port.d.valid := false.B
    port.d.bits := 0.U.asTypeOf(port.d.bits)
    port.e.ready := true.B
  }
}

class InstructionTLBTranslationTester(harness: InstructionTLBTranslationHarnessModule)
    extends PeekPokeTester(harness) {
  private val io = harness.io
  private val progressLimit = 4096

  private def await(label: String)(condition: => Boolean): Unit = {
    var elapsed = 0
    while (!condition && elapsed < progressLimit) {
      step(1)
      elapsed += 1
    }
    require(condition, s"CPU_EVAL_DIRECTED_TIMEOUT: $label")
  }

  private def request(virtualAddress: BigInt, label: String): Unit = {
    poke(io.req.bits.vaddr, virtualAddress)
    poke(io.req.valid, 1)
    await(s"$label request")(peek(io.req.ready) == 1)
  }

  private def refill(label: String, virtualAddress: BigInt, ppn: BigInt, level: Int): Unit = {
    request(virtualAddress, label)
    require(peek(io.resp.miss) == 1, s"$label needs a new translation")
    step(1)
    poke(io.req.valid, 0)
    await(s"$label walk")(peek(io.ptw.req.valid) == 1)
    require(peek(io.ptw.req.bits.valid) == 1, s"$label walk was cancelled")
    require(peek(io.ptw.req.bits.bits.addr) == (virtualAddress >> 12), s"$label walk VPN")
    poke(io.ptw.req.ready, 1)
    step(1)
    poke(io.ptw.req.ready, 0)
    poke(io.ptw.resp.bits.level, level)
    poke(io.ptw.resp.bits.pte.ppn, ppn)
    poke(io.ptw.resp.valid, 1)
    step(1)
    poke(io.ptw.resp.valid, 0)
  }

  private def fetch(label: String, virtualAddress: BigInt, physicalAddress: BigInt): Unit = {
    request(virtualAddress, label)
    println(s"ITLB_FETCH $label va=${virtualAddress.toString(16)} " +
      s"pa=${peek(io.resp.paddr).toString(16)} miss=${peek(io.resp.miss)} " +
      s"pf.inst=${peek(io.resp.pf.inst)} ae.inst=${peek(io.resp.ae.inst)}")
    expect(io.resp.miss, 0, s"$label cached translation")
    expect(io.resp.paddr, physicalAddress, s"$label physical fetch address")
    expect(io.resp.pf.inst, 0, s"$label executable supervisor page")
    expect(io.resp.ae.inst, 0, s"$label permitted physical fetch")
    step(1)
    poke(io.req.valid, 0)
  }

  poke(io.kill, 0)
  poke(io.req.valid, 0)
  poke(io.req.bits.cmd, 0)
  poke(io.req.bits.prv, 1)
  poke(io.req.bits.v, 0)
  poke(io.req.bits.size, 4)
  poke(io.req.bits.passthrough, 0)
  poke(io.sfence.valid, 0)
  poke(io.sfence.bits.rs1, 0)
  poke(io.sfence.bits.rs2, 0)
  poke(io.sfence.bits.asid, 0)
  poke(io.sfence.bits.hv, 0)
  poke(io.sfence.bits.hg, 0)
  poke(io.ptw.ptbr.mode, 8)
  poke(io.ptw.ptbr.ppn, 0x80010)
  poke(io.ptw.status.prv, 1)
  poke(io.ptw.status.dprv, 1)
  poke(io.ptw.status.debug, 0)
  poke(io.ptw.req.ready, 0)
  poke(io.ptw.resp.valid, 0)
  poke(io.ptw.resp.bits.ae_ptw, 0)
  poke(io.ptw.resp.bits.ae_final, 0)
  poke(io.ptw.resp.bits.gf, 0)
  poke(io.ptw.resp.bits.hr, 1)
  poke(io.ptw.resp.bits.hw, 1)
  poke(io.ptw.resp.bits.hx, 1)
  poke(io.ptw.resp.bits.homogeneous, 1)
  poke(io.ptw.resp.bits.fragmented_superpage, 0)
  poke(io.ptw.resp.bits.gpa.valid, 0)
  poke(io.ptw.resp.bits.pte.v, 1)
  poke(io.ptw.resp.bits.pte.r, 1)
  poke(io.ptw.resp.bits.pte.w, 0)
  poke(io.ptw.resp.bits.pte.x, 1)
  poke(io.ptw.resp.bits.pte.u, 0)
  poke(io.ptw.resp.bits.pte.g, 0)
  poke(io.ptw.resp.bits.pte.a, 1)
  poke(io.ptw.resp.bits.pte.d, 0)
  for ((pmp, i) <- io.ptw.pmp.zipWithIndex) {
    poke(pmp.cfg.a, if (i == 0) 1 else 0)
    poke(pmp.cfg.l, 0)
    poke(pmp.cfg.res, 0)
    poke(pmp.cfg.r, 1)
    poke(pmp.cfg.w, 0)
    poke(pmp.cfg.x, 1)
    poke(pmp.addr, if (i == 0) BigInt("3fffffff", 16) else BigInt(0))
    poke(pmp.mask, 0)
  }
  step(2)
  println("ITLB_OBSERVATIONS_STARTED")

  refill("4 KiB", 0x4120, 0x80003, 2)
  fetch("4 KiB offset", 0x43a0, BigInt("800033a0", 16))

  // A VA-specific fence takes its VPN from the same frontend request.
  request(0x4120, "address-specific SFENCE.VMA")
  poke(io.sfence.bits.addr, 0x4120)
  poke(io.sfence.bits.rs1, 1)
  poke(io.sfence.valid, 1)
  step(1)
  poke(io.req.valid, 0)
  poke(io.sfence.valid, 0)
  refill("4 KiB remap", 0x4120, 0x80007, 2)
  fetch("4 KiB remapped offset", 0x4120, BigInt("80007120", 16))

  refill("2 MiB", 0x2217220, 0x80400, 1)
  fetch("2 MiB offset", 0x2217220, BigInt("80417220", 16))
  refill("1 GiB", 0x40418090, 0x80000, 0)
  fetch("1 GiB offset", 0x40418090, BigInt("80418090", 16))
}

class InstructionTLBTranslationTest extends AnyFlatSpec {
  it should "translate executable Sv39 pages at each leaf level and read a fenced remap" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    assert(Driver.execute(Array("--backend-name", "firrtl"),
      () => LazyModule(new InstructionTLBTranslationHarness()).module)(
      dut => new InstructionTLBTranslationTester(dut)))
  }
}
