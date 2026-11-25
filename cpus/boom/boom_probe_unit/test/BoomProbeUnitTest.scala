package boom.tests

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._

import boom.common.BoomTileAttachParams
import boom.common.WithNLargeBooms
import boom.lsu.BoomProbeUnit

class BoomProbeUnitHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }

  lazy val module = new BoomProbeUnitHarnessModule(this)
}

class BoomProbeUnitHarnessModule(outer: BoomProbeUnitHarness)
  extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  implicit val edge: TLEdgeOut = outer.visibilityNode.edges.out.head
  val dut = Module(new BoomProbeUnit)
  val io = IO(chiselTypeOf(dut.io))
  io <> dut.io
}

class BoomProbeUnitTester(c: BoomProbeUnitHarnessModule) extends PeekPokeTester(c) {
  private def await(condition: => Boolean, message: String): Unit = {
    var cycles = 0
    while (!condition && cycles < 64) { step(1); cycles += 1 }
    assert(condition, message)
  }

  poke(c.io.req.valid, 0)
  poke(c.io.rep.ready, 0)
  poke(c.io.meta_read.ready, 0)
  poke(c.io.meta_write.ready, 0)
  poke(c.io.wb_req.ready, 0)
  poke(c.io.lsu_release.ready, 0)
  poke(c.io.way_en, 0)
  poke(c.io.wb_rdy, 1)
  poke(c.io.mshr_rdy, 1)
  poke(c.io.block_state.state, ClientStates.Nothing.litValue)
  step(1)

  private def driveProbe(address: BigInt, way: BigInt, state: BigInt,
                         expectedReport: BigInt, dirty: Boolean = false,
                         retryWriteback: Boolean = false, retryMshr: Boolean = false): Unit = {
    await(peek(c.io.req.ready) == 1, "probe request never became ready")
    poke(c.io.way_en, 0)
    poke(c.io.block_state.state, ClientStates.Nothing.litValue)
    poke(c.io.wb_rdy, if (retryWriteback) 0 else 1)
    poke(c.io.mshr_rdy, if (retryMshr) 0 else 1)
    poke(c.io.req.bits.opcode, TLMessages.Probe.litValue)
    poke(c.io.req.bits.param, TLPermissions.toN.litValue)
    poke(c.io.req.bits.size, 6)
    poke(c.io.req.bits.source, 0)
    poke(c.io.req.bits.address, address)
    poke(c.io.req.bits.mask, 0xffff)
    poke(c.io.req.bits.data, 0)
    poke(c.io.req.bits.corrupt, 0)
    poke(c.io.req.valid, 1)
    step(1)
    poke(c.io.req.valid, 0)

    def acceptMetadataRead(returnedWay: BigInt, returnedState: BigInt): Unit = {
      poke(c.io.meta_read.ready, 1)
      await(peek(c.io.meta_read.valid) == 1, "metadata read disappeared")
      expect(c.io.meta_read.bits.idx, (address >> 6) & 0x3f)
      expect(c.io.meta_read.bits.tag, address >> 12)
      step(2)
      // The array response is registered again before reaching the Probe inputs.
      poke(c.io.way_en, returnedWay)
      poke(c.io.block_state.state, returnedState)
    }
    await(peek(c.io.meta_read.valid) == 1, "metadata read never arrived")
    step(2)
    val retry = retryWriteback || retryMshr
    if (retry) {
      acceptMetadataRead(0, ClientStates.Nothing.litValue)
      poke(c.io.meta_read.ready, 0)
      for (_ <- 0 until 4) {
        assert(peek(c.io.lsu_release.valid) == 0 && peek(c.io.rep.valid) == 0 &&
          peek(c.io.wb_req.valid) == 0 && peek(c.io.meta_write.valid) == 0,
          if (retryMshr) "probe acted before MSHR permitted it" else "probe acted during conflicting writeback")
        step(1)
      }
      poke(c.io.wb_rdy, 1)
      poke(c.io.mshr_rdy, 1)
      await(peek(c.io.meta_read.valid) == 1, "probe did not reread metadata after the conflict")
    }
    acceptMetadataRead(way, state)

    if (dirty) {
      await(peek(c.io.wb_req.valid) == 1, "dirty probe never requested writeback")
      poke(c.io.wb_req.ready, 1)
      expect(c.io.wb_req.bits.source, 0)
      expect(c.io.wb_req.bits.idx, (address >> 6) & 0x3f)
      expect(c.io.wb_req.bits.tag, address >> 12)
      expect(c.io.wb_req.bits.way_en, way)
      expect(c.io.wb_req.bits.param, expectedReport)
      expect(c.io.wb_req.bits.voluntary, 0)
      step(1)
      poke(c.io.wb_req.ready, 0)
      for (_ <- 0 until 4) {
        expect(c.io.meta_write.valid, 0)
        expect(c.io.lsu_release.valid, 0)
        expect(c.io.rep.valid, 0)
        step(1)
      }
      poke(c.io.wb_req.ready, 1)
    } else {
      await(peek(c.io.lsu_release.valid) == 1, "local probe notification never arrived")
      expect(c.io.rep.valid, 0)
      step(2)
      poke(c.io.lsu_release.ready, 1)
      await(peek(c.io.lsu_release.valid) == 1, "local probe notification disappeared")
      expect(c.io.lsu_release.bits.opcode, TLMessages.ProbeAck.litValue)
      expect(c.io.lsu_release.bits.param, expectedReport)
      expect(c.io.lsu_release.bits.address, address)
      step(1)
      poke(c.io.lsu_release.ready, 0)
      step(2)
      poke(c.io.rep.ready, 1)
      await(peek(c.io.rep.valid) == 1, "TileLink ProbeAck never arrived")
      expect(c.io.rep.bits.opcode, TLMessages.ProbeAck.litValue)
      expect(c.io.rep.bits.param, expectedReport)
      expect(c.io.rep.bits.source, 0)
      expect(c.io.rep.bits.address, address)
      step(1)
      poke(c.io.rep.ready, 0)
    }

    if (way != 0) {
      await(peek(c.io.meta_write.valid) == 1, "metadata update never arrived")
      step(2)
      poke(c.io.meta_write.ready, 1)
      await(peek(c.io.meta_write.valid) == 1, "metadata update disappeared")
      expect(c.io.meta_write.bits.idx, (address >> 6) & 0x3f)
      expect(c.io.meta_write.bits.way_en, way)
      expect(c.io.meta_write.bits.data.tag, address >> 12)
      expect(c.io.meta_write.bits.data.coh.state, ClientStates.Nothing.litValue)
      step(1)
      poke(c.io.meta_write.ready, 0)
    } else {
      // A metadata write that selects no way changes no line.
      poke(c.io.meta_write.ready, 1)
      var writes = 0
      var cycles = 0
      while (peek(c.io.req.ready) == 0 && cycles < 64) {
        if (peek(c.io.meta_write.valid) == 1) {
          expect(c.io.meta_write.bits.way_en, 0)
          writes += 1
        }
        step(1)
        cycles += 1
      }
      assert(writes <= 1, "absent line wrote metadata more than once")
      poke(c.io.meta_write.ready, 0)
    }
    await(peek(c.io.req.ready) == 1, "probe transaction never completed")
    expect(c.io.rep.valid, 0)
    expect(c.io.lsu_release.valid, 0)
    expect(c.io.meta_write.valid, 0)
    poke(c.io.meta_read.ready, 0)
    poke(c.io.wb_req.ready, 0)
  }

  driveProbe(0x80002040L, 0, ClientStates.Nothing.litValue, TLPermissions.NtoN.litValue)
  driveProbe(0x80003280L, 1, ClientStates.Branch.litValue, TLPermissions.BtoN.litValue)
  driveProbe(0x80004540L, 2, ClientStates.Branch.litValue, TLPermissions.BtoN.litValue,
    retryWriteback = true)
  driveProbe(0x800057c0L, 4, ClientStates.Dirty.litValue, TLPermissions.TtoN.litValue,
    dirty = true)
  driveProbe(0x80006f00L, 8, ClientStates.Branch.litValue, TLPermissions.BtoN.litValue,
    retryMshr = true)
}

class BoomProbeUnitTest extends AnyFlatSpec with Matchers {
  behavior of "BoomProbeUnit"

  it should "process clean, retried and dirty probes through external handshakes" in {
    implicit val p: Parameters =
      new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver(() => LazyModule(new BoomProbeUnitHarness).module)(
      c => new BoomProbeUnitTester(c)) should be(true)
  }
}
