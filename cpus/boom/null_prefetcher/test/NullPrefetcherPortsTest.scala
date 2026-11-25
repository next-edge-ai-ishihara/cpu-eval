package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._
import boom.common._
import boom.lsu.NullPrefetcher

class NullPrefetcherHarness(implicit p: Parameters) extends LazyModule {
  val visibility = TLEphemeralNode()
  val client = TLClientNode(Seq(TLMasterPortParameters.v1(Seq(
    TLMasterParameters.v1(name = "prefetch-test", sourceId = IdRange(0, 4), supportsProbe = TransferSizes(64))))))
  val provider = TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(
    address = Seq(AddressSet(BigInt("80000000", 16), BigInt("3ffff", 16))),
    regionType = RegionType.CACHED, supportsGet = TransferSizes(1, 64),
    supportsPutFull = TransferSizes(1, 64), supportsPutPartial = TransferSizes(1, 64),
    supportsArithmetic = TransferSizes(1, 8), supportsLogical = TransferSizes(1, 8),
    supportsAcquireB = TransferSizes(64), supportsAcquireT = TransferSizes(64))),
    beatBytes = 16, endSinkId = 4)))
  DisableMonitors { implicit p => provider := visibility := client }
  lazy val module = new NullPrefetcherHarnessModule(this)
}

class NullPrefetcherHarnessModule(outer: NullPrefetcherHarness) extends LazyModuleImp(outer) {
  for ((out, _) <- outer.client.out) {
    out.a.valid := false.B
    out.a.bits := DontCare
    out.c.valid := false.B
    out.c.bits := DontCare
    out.e.valid := false.B
    out.e.bits := DontCare
    out.b.ready := true.B
    out.d.ready := true.B
  }
  for ((in, _) <- outer.provider.in) {
    in.a.ready := true.B
    in.c.ready := true.B
    in.e.ready := true.B
    in.b.valid := false.B
    in.b.bits := DontCare
    in.d.valid := false.B
    in.d.bits := DontCare
  }
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attached: BoomTileAttachParams => attached.tileParams
  }.get
  implicit val testParameters: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibility
  }
  implicit val edge: TLEdgeOut = outer.visibility.edges.out.head
  val dut = Module(new NullPrefetcher)
  val io = IO(chiselTypeOf(dut.io))
  io <> dut.io
}

class NullPrefetcherTester(dut: NullPrefetcherHarnessModule) extends PeekPokeTester(dut) {
  val addresses = Seq("80000000", "80000040", "80020000", "80020040").map(BigInt(_, 16))
  println("NULL_PREFETCH_PORT_CHECK")
  for {
    address <- addresses
    request <- 0 to 1
    available <- 0 to 1
    ready <- 0 to 1
    coherence <- 0 to 3
  } {
    poke(dut.io.req_addr, address)
    poke(dut.io.req_val, request)
    poke(dut.io.mshr_avail, available)
    poke(dut.io.prefetch.ready, ready)
    poke(dut.io.req_coh.state, coherence)
    val stimulus = s"address=0x${address.toString(16)} req=$request mshr=$available ready=$ready coh=$coherence"
    assert(peek(dut.io.prefetch.valid) == 0, s"unexpected prefetch valid before step: $stimulus")
    step(1)
    assert(peek(dut.io.prefetch.valid) == 0, s"unexpected prefetch valid after step: $stimulus")
  }
  println("NULL_PREFETCH_PORT_PASS 128")
}

class NullPrefetcherPortsTest extends org.scalatest.flatspec.AnyFlatSpec {
  behavior of "NullPrefetcher"
  it should "keep prefetch invalid across request inputs and receiver backpressure" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    assert(Driver.execute(Array("--backend-name", "firrtl"), () => LazyModule(new NullPrefetcherHarness).module)(
      dut => new NullPrefetcherTester(dut)))
  }
}
