package boom.tests

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import chisel3.util._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}

import boom.common.{BoomBundle, BoomTileAttachParams, HasBoomUOP, WithNLargeBooms}
import boom.util.BranchKillableQueue

class BranchQueueTestEntry(implicit p: Parameters) extends BoomBundle()(p) with HasBoomUOP {
  val tag = UInt(8.W)
}

class BranchQueueTestPort(maskWidth: Int) extends Bundle {
  val tag = UInt(8.W)
  val mask = UInt(maskWidth.W)
  val load = Bool()
}

class BranchQueueHarness(flow: Boolean)(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }

  lazy val module = new BranchQueueHarnessModule(this, flow)
}

class BranchQueueHarnessModule(outer: BranchQueueHarness, flow: Boolean)
  extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  private val dut = Module(new BranchKillableQueue(new BranchQueueTestEntry, 3, _.uses_ldq, flow))
  private val maskWidth = dut.io.enq.bits.uop.br_mask.getWidth
  val io = IO(new Bundle {
    val enq = Flipped(Decoupled(new BranchQueueTestPort(maskWidth)))
    val deq = Decoupled(new BranchQueueTestPort(maskWidth))
    val resolve = Input(UInt(maskWidth.W))
    val mispredict = Input(UInt(maskWidth.W))
    val flush = Input(Bool())
    val empty = Output(Bool())
  })

  dut.io.enq.valid := io.enq.valid
  io.enq.ready := dut.io.enq.ready
  dut.io.enq.bits := 0.U.asTypeOf(dut.io.enq.bits)
  dut.io.enq.bits.tag := io.enq.bits.tag
  dut.io.enq.bits.uop.br_mask := io.enq.bits.mask
  dut.io.enq.bits.uop.uses_ldq := io.enq.bits.load
  io.deq.valid := dut.io.deq.valid
  dut.io.deq.ready := io.deq.ready
  io.deq.bits.tag := dut.io.deq.bits.tag
  io.deq.bits.mask := dut.io.deq.bits.uop.br_mask
  io.deq.bits.load := dut.io.deq.bits.uop.uses_ldq
  dut.io.brupdate.b2 := DontCare
  dut.io.brupdate.b2.valid := false.B
  dut.io.brupdate.b2.target_offset := 0.S
  dut.io.brupdate.b1.resolve_mask := io.resolve
  dut.io.brupdate.b1.mispredict_mask := io.mispredict
  dut.io.flush := io.flush
  io.empty := dut.io.empty
}

class BranchQueuePortsTester(c: BranchQueueHarnessModule, flow: Boolean) extends PeekPokeTester(c) {
  private val io = c.io
  poke(io.enq.valid, 0)
  poke(io.deq.ready, 0)
  poke(io.resolve, 0)
  poke(io.mispredict, 0)
  poke(io.flush, 0)
  step(1)
  expect(io.empty, 1)

  def offer(tag: Int, mask: Int, load: Int): Unit = {
    poke(io.enq.bits.tag, tag)
    poke(io.enq.bits.mask, mask)
    poke(io.enq.bits.load, load)
    poke(io.enq.valid, 1)
    expect(io.enq.ready, 1)
  }

  def expectHead(tag: Int, mask: Int): Unit = {
    expect(io.deq.valid, 1, s"Expected entry $tag at the dequeue port")
    expect(io.deq.bits.tag, tag)
    expect(io.deq.bits.mask, mask)
  }

  def waitForHead(tag: Int, mask: Int): Unit = {
    var cycles = 0
    while (peek(io.deq.valid) == 0 && cycles < 32) {
      step(1)
      cycles += 1
    }
    expectHead(tag, mask)
  }

  if (flow) {
    poke(io.deq.ready, 1)
    offer(11, 3, 1)
    poke(io.flush, 1)
    poke(io.resolve, 1)
    expectHead(11, 2)
    step(1)
    poke(io.enq.valid, 0)
    expect(io.deq.valid, 0)
    expect(io.empty, 1)

    poke(io.deq.ready, 0)
    offer(12, 3, 1)
    expectHead(12, 2)
    step(1)
    poke(io.enq.valid, 0)
    poke(io.flush, 0)
    poke(io.resolve, 0)
    expectHead(12, 2)
    step(2)
    expectHead(12, 2)
    poke(io.deq.ready, 1)
    step(1)
    expect(io.deq.valid, 0)
    expect(io.empty, 1)
  } else {
    offer(21, 1, 0)
    expect(io.deq.valid, 0)
    step(1)
    offer(22, 6, 0)
    expectHead(21, 1)
    step(1)
    poke(io.enq.valid, 0)

    // Cancel the head while the consumer remains stopped.
    poke(io.resolve, 3)
    poke(io.mispredict, 1)
    if (peek(io.deq.valid) == 1) {
      expectHead(22, 4)
    }
    step(1)
    poke(io.resolve, 0)
    poke(io.mispredict, 2)
    waitForHead(22, 4)
    poke(io.mispredict, 0)

    offer(23, 0, 1)
    step(1)
    offer(24, 0, 1)
    poke(io.flush, 1)
    expectHead(22, 4)
    step(1)
    poke(io.enq.valid, 0)
    poke(io.flush, 0)
    expectHead(22, 4)
    poke(io.deq.ready, 1)
    step(1)
    poke(io.deq.ready, 0)
    waitForHead(24, 0)
    poke(io.deq.ready, 1)
    step(1)
    expect(io.deq.valid, 0)
    expect(io.empty, 1)
  }
}

class BranchKillableQueuePortsTest extends AnyFlatSpec with Matchers {
  behavior of "BranchKillableQueue"

  it should "expose the surviving FIFO entries despite cancellation and a stalled consumer" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver(() => LazyModule(new BranchQueueHarness(flow = false)).module)(
      c => new BranchQueuePortsTester(c, flow = false)) should be(true)
  }

  it should "transfer an empty flow queue input directly or retain it until accepted" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver(() => LazyModule(new BranchQueueHarness(flow = true)).module)(
      c => new BranchQueuePortsTester(c, flow = true)) should be(true)
  }
}
