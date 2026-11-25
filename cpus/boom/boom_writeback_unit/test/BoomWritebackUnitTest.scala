package boom.tests

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, IdRange, LazyModule, LazyModuleImp, RegionType, TransferSizes}
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._

import boom.common.BoomTileAttachParams
import boom.common.WithNLargeBooms
import boom.lsu.BoomWritebackUnit

class BoomWritebackUnitHarness(implicit p: Parameters) extends LazyModule {
  val clientNode = TLClientNode(Seq(TLMasterPortParameters.v1(Seq(
    TLMasterParameters.v1(
      name = "BoomWritebackUnit directed test",
      sourceId = IdRange(0, 8),
      supportsProbe = TransferSizes(64, 64))),
    minLatency = 1)))
  val managerNode = TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(
    TLSlaveParameters.v1(
      address = Seq(AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16))),
      regionType = RegionType.TRACKED,
      supportsAcquireT = TransferSizes(64, 64),
      supportsAcquireB = TransferSizes(64, 64))),
    beatBytes = 16,
    endSinkId = 8)))
  DisableMonitors { implicit p => managerNode := clientNode }

  lazy val module = new BoomWritebackUnitHarnessModule(this)
}

class BoomWritebackUnitHarnessModule(outer: BoomWritebackUnitHarness)
  extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.clientNode
  }
  implicit val edge: TLEdgeOut = outer.clientNode.edges.out.head
  private val (tl, _) = outer.managerNode.in.head
  tl.a.ready := true.B
  tl.c.ready := true.B
  tl.e.ready := true.B
  tl.b.valid := false.B
  tl.b.bits := DontCare
  tl.d.valid := false.B
  tl.d.bits := DontCare
  val dut = Module(new BoomWritebackUnit)
  val io = IO(chiselTypeOf(dut.io))
  io <> dut.io
}

class BoomWritebackUnitTester(c: BoomWritebackUnitHarnessModule)
  extends PeekPokeTester(c) {
  private val rows = Vector.tabulate(4)(i =>
    BigInt("0123456789abcdeffedcba9876543210", 16) ^ (BigInt(i + 1) << 96))
  private val firstLine = BigInt("800020c0", 16)
  private val secondLine = BigInt("80003140", 16)
  private var lineAddress = firstLine
  private def lineTag = lineAddress >> 12
  private def lineIndex = (lineAddress >> 6) & 0x3f
  private val pending = scala.collection.mutable.Queue[Option[Int]](None, None)
  private val deliveredRows = scala.collection.mutable.Set[Int]()

  // Cache data is returned two cycles after the coupled read transfer.
  private def tick(): Unit = {
    val returnedRow = pending.dequeue()
    poke(c.io.data_resp, returnedRow.map(rows).getOrElse(BigInt(0)))
    returnedRow.foreach(row => deliveredRows += row)
    if (peek(c.io.resp) == 1) {
      assert(deliveredRows.size == rows.size,
        "writeback notified before the final data response")
    }
    val dataFire = peek(c.io.data_req.valid) == 1 && peek(c.io.data_req.ready) == 1
    val metaFire = peek(c.io.meta_read.valid) == 1 && peek(c.io.meta_read.ready) == 1
    assert(dataFire == metaFire, "metadata and data reads must transfer together")
    val response = if (dataFire) {
      val address = peek(c.io.data_req.bits.addr)
      val offset = address - (lineIndex << 6)
      assert(offset >= 0 && offset < 64 && (offset & 15) == 0,
        s"read address $address is outside the selected line or is unaligned")
      val row = (offset >> 4).toInt
      expect(c.io.meta_read.bits.idx, lineIndex)
      expect(c.io.meta_read.bits.tag, lineTag)
      expect(c.io.data_req.bits.way_en, 4)
      Some(row)
    } else None
    step(1)
    pending.enqueue(response)
  }

  private def await(condition: => Boolean, message: String): Unit = {
    var cycles = 0
    while (!condition && cycles < 64) { tick(); cycles += 1 }
    assert(condition, message)
  }

  poke(c.io.req.valid, 0)
  poke(c.io.meta_read.ready, 1)
  poke(c.io.data_req.ready, 1)
  poke(c.io.data_resp, 0)
  poke(c.io.mem_grant, 0)
  poke(c.io.release.ready, 0)
  poke(c.io.lsu_release.ready, 0)
  tick()

  private def issue(voluntary: Boolean, address: BigInt): Unit = {
    await(peek(c.io.req.ready) == 1, "writeback request never became ready")
    lineAddress = address
    deliveredRows.clear()
    poke(c.io.req.bits.tag, lineTag)
    poke(c.io.req.bits.idx, lineIndex)
    poke(c.io.req.bits.source, 1)
    poke(c.io.req.bits.param, TLPermissions.TtoN.litValue)
    poke(c.io.req.bits.way_en, 4)
    poke(c.io.req.bits.voluntary, if (voluntary) 1 else 0)
    poke(c.io.req.valid, 1)
    tick()
    poke(c.io.req.valid, 0)
    expect(c.io.idx.valid, 1)
    expect(c.io.idx.bits, lineIndex)
    poke(c.io.meta_read.ready, 0)
    poke(c.io.data_req.ready, 0)
    tick(); tick()
    poke(c.io.meta_read.ready, 1)
    poke(c.io.data_req.ready, 1)
    await(peek(c.io.resp) == 1, "writeback buffer never completed")
    tick()
  }

  private def expectRelease(local: Boolean, voluntary: Boolean, row: Int): Unit = {
    val opcode = if (voluntary && !local) TLMessages.ReleaseData.litValue
      else TLMessages.ProbeAckData.litValue
    if (local) {
      // The LSU reads only the address of this notification.
      expect(c.io.lsu_release.bits.address, lineAddress)
    } else {
      expect(c.io.release.bits.opcode, opcode)
      expect(c.io.release.bits.param, TLPermissions.TtoN.litValue)
      expect(c.io.release.bits.source, 4)
      expect(c.io.release.bits.address, lineAddress)
      expect(c.io.release.bits.data, rows(row))
    }
  }

  private def complete(voluntary: Boolean, earlyAck: Boolean = false): Unit = {
    await(peek(c.io.lsu_release.valid) == 1, "local release never arrived")
    expect(c.io.release.valid, 0)
    tick(); tick()
    poke(c.io.lsu_release.ready, 1)
    await(peek(c.io.lsu_release.valid) == 1, "local release disappeared")
    expectRelease(local = true, voluntary = voluntary, row = 0)
    tick()
    poke(c.io.lsu_release.ready, 0)
    for (row <- 0 until 4) {
      poke(c.io.release.ready, 0)
      tick(); tick()
      poke(c.io.release.ready, 1)
      await(peek(c.io.release.valid) == 1, s"release beat $row never arrived")
      expectRelease(local = false, voluntary = voluntary, row = row)
      tick()
      if (earlyAck && row == 0) {
        poke(c.io.release.ready, 0)
        poke(c.io.mem_grant, 1)
        tick()
        poke(c.io.mem_grant, 0)
      }
    }
    if (voluntary && !earlyAck) {
      expect(c.io.req.ready, 0)
      tick(); tick()
      expect(c.io.req.ready, 0)
      poke(c.io.mem_grant, 1)
      tick()
      poke(c.io.mem_grant, 0)
    }
    await(peek(c.io.req.ready) == 1, "writeback transaction never completed")
    expect(c.io.idx.valid, 0)
    expect(c.io.release.valid, 0)
    poke(c.io.release.ready, 0)
  }

  issue(voluntary = false, address = firstLine)
  complete(voluntary = false)
  issue(voluntary = true, address = secondLine)
  complete(voluntary = true)
  issue(voluntary = true, address = firstLine)
  complete(voluntary = true, earlyAck = true)
}

class BoomWritebackUnitTest extends AnyFlatSpec with Matchers {
  behavior of "BoomWritebackUnit"

  it should "emit ordered distinct cache rows through backpressured writeback interfaces" in {
    implicit val p: Parameters =
      new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver(() => LazyModule(new BoomWritebackUnitHarness).module)(
      c => new BoomWritebackUnitTester(c)) should be(true)
  }
}
