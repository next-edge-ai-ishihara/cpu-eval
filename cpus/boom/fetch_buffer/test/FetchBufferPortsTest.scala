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

import boom.common.{BoomTileAttachParams, WithNLargeBooms}
import boom.ifu.FetchBuffer

class FetchBufferPortsHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new FetchBufferPortsModule(this)
}

class FetchBufferPortsModule(outer: FetchBufferPortsHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  private implicit val configured: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }

  private val target = Module(new FetchBuffer)
  private val in = target.io.enq.bits
  private val entries = target.io.deq.bits.uops
  private val entry = entries.head.bits
  val io = IO(new Bundle {
    val enqValid = Input(Bool())
    val enqReady = Output(Bool())
    val deqReady = Input(Bool())
    val deqValid = Output(Bool())
    val clear = Input(Bool())
    val pc = Input(UInt(in.pc.getWidth.W))
    val mask = Input(UInt(8.W))
    val edges = Input(Vec(2, Bool()))
    val raw = Input(Vec(8, UInt(32.W)))
    val expanded = Input(Vec(8, UInt(32.W)))
    val ftq = Input(UInt(in.ftq_idx.getWidth.W))
    val cfi = Input(UInt(3.W))
    val cfiValid = Input(Bool())
    val pageFault = Input(Bool())
    val accessFault = Input(Bool())
    val slots = Output(Vec(3, new Bundle {
      val valid = Bool()
      val raw = UInt(32.W)
      val expanded = UInt(32.W)
      val debugPc = UInt(entry.debug_pc.getWidth.W)
      val pcLow = UInt(entry.pc_lob.getWidth.W)
      val edge = Bool()
      val compressed = Bool()
      val ftq = UInt(entry.ftq_idx.getWidth.W)
      val taken = Bool()
      val pageFault = Bool()
      val accessFault = Bool()
    }))
  })
  target.io.enq.valid := io.enqValid
  io.enqReady := target.io.enq.ready
  target.io.deq.ready := io.deqReady
  io.deqValid := target.io.deq.valid
  target.io.clear := io.clear
  in := DontCare
  in.bpd_meta.foreach(_ := 0.U(1.W))
  in.pc := io.pc
  in.mask := io.mask
  in.edge_inst := io.edges
  in.insts := io.raw
  in.exp_insts := io.expanded
  in.ftq_idx := io.ftq
  in.cfi_idx.bits := io.cfi
  in.cfi_idx.valid := io.cfiValid
  in.sfbs.foreach(_ := false.B)
  in.shadowed_mask.foreach(_ := false.B)
  in.xcpt_pf_if := io.pageFault
  in.xcpt_ae_if := io.accessFault
  in.bp_debug_if_oh.foreach(_ := false.B)
  in.bp_xcpt_if_oh.foreach(_ := false.B)
  in.fsrc := 0.U
  for ((output, uop) <- io.slots.zip(entries)) {
    output.valid := uop.valid
    output.raw := uop.bits.debug_inst
    output.expanded := uop.bits.inst
    output.debugPc := uop.bits.debug_pc
    output.pcLow := uop.bits.pc_lob
    output.edge := uop.bits.edge_inst
    output.compressed := uop.bits.is_rvc
    output.ftq := uop.bits.ftq_idx
    output.taken := uop.bits.taken
    output.pageFault := uop.bits.xcpt_pf_if
    output.accessFault := uop.bits.xcpt_ae_if
  }
}

class FetchBufferPortsTester(c: FetchBufferPortsModule) extends PeekPokeTester(c) {
  case class Instruction(index: Int, raw: BigInt, expanded: BigInt, pc: Int, pcLow: Int,
                         ftq: Int, edge: Boolean = false, taken: Boolean = false,
                         pageFault: Boolean = false, accessFault: Boolean = false)

  private val add = BigInt("00458593", 16)
  private val jump = BigInt("0040006f", 16)
  private val compressed = BigInt("00000085", 16)
  private val expanded = BigInt("00108093", 16)
  private var groups = 0

  private def bit(value: Boolean): Int = if (value) 1 else 0

  private def awaitSignal(message: String)(condition: => Boolean): Unit = {
    var elapsed = 0
    while (!condition && elapsed < 16) {
      step(1)
      elapsed += 1
    }
    assert(condition, message)
  }

  private def drive(base: Int, lane: Seq[Instruction]): Unit = {
    poke(c.io.pc, base)
    poke(c.io.mask, lane.foldLeft(0)((mask, inst) => mask | (1 << inst.index)))
    poke(c.io.ftq, lane.head.ftq)
    for (i <- 0 until 8) {
      val selected = lane.find(_.index == i)
      poke(c.io.raw(i), selected.map(_.raw).getOrElse(jump))
      poke(c.io.expanded(i), selected.map(_.expanded).getOrElse(jump))
    }
    for (bank <- 0 until 2) poke(c.io.edges(bank), bit(lane.exists(inst => inst.index == bank * 4 && inst.edge)))
    poke(c.io.cfiValid, bit(lane.exists(_.taken)))
    poke(c.io.cfi, lane.find(_.taken).map(_.index).getOrElse(0))
    poke(c.io.pageFault, bit(lane.head.pageFault))
    poke(c.io.accessFault, bit(lane.head.accessFault))
    poke(c.io.enqValid, 1)
  }

  private def send(base: Int, lane: Instruction*): Unit = {
    drive(base, lane)
    awaitSignal("an input cannot be accepted with space available")(peek(c.io.enqReady) == 1)
    step(1)
    poke(c.io.enqValid, 0)
  }

  private def observe(context: String, expected: Instruction*): Unit = {
    if (expected.nonEmpty) {
      awaitSignal(s"$context: expected valid slots never appeared") {
        peek(c.io.deqValid) == 1 && expected.indices.forall(i => peek(c.io.slots(i).valid) == 1)
      }
    }
    expect(c.io.deqValid, bit(expected.nonEmpty), context)
    for ((slot, i) <- c.io.slots.zipWithIndex) {
      expect(slot.valid, bit(i < expected.length), context)
      if (i < expected.length) {
        val inst = expected(i)
        expect(slot.raw, inst.raw, context + " raw instruction")
        expect(slot.expanded, inst.expanded, context + " expanded instruction")
        expect(slot.debugPc, inst.pc, context + " debug PC")
        expect(slot.pcLow, inst.pcLow, context + " cache-line offset")
        expect(slot.edge, bit(inst.edge), context + " edge indication")
        expect(slot.compressed, bit((inst.raw & 3) != 3), context + " instruction length")
        expect(slot.ftq, inst.ftq, context + " FTQ index")
        expect(slot.taken, bit(inst.taken), context + " taken prediction")
        expect(slot.pageFault, bit(inst.pageFault), context + " page fault")
        expect(slot.accessFault, bit(inst.accessFault), context + " access fault")
      }
    }
    groups += 1
    println(s"FETCH_BUFFER_ROW name=$context slots=${expected.length}")
  }

  private def dequeue(): Unit = {
    poke(c.io.deqReady, 1)
    step(1)
    poke(c.io.deqReady, 0)
  }

  poke(c.io.enqValid, 0)
  poke(c.io.deqReady, 0)
  poke(c.io.clear, 0)
  step(2)
  println("FETCH_BUFFER_PORTS_START")
  observe("empty after reset")

  val fault = Instruction(0, add, add, 0x17e, 0, 2, edge = true, pageFault = true)
  send(0x180, fault)
  observe("single fault without a following fetch", fault)
  step(2)
  observe("partial fault holds until redirect", fault)
  poke(c.io.clear, 1)
  step(1)
  poke(c.io.clear, 0)
  observe("empty after redirect")

  val a = Instruction(1, compressed, expanded, 0x1aa, 42, 3)
  val b = Instruction(4, jump, jump, 0x1ae, 48, 3, edge = true, taken = true)
  send(0x1aa, a, b)
  observe("two valid slots from a sparse packet", a, b)
  step(2)
  observe("same slots while decode has a partial row", a, b)

  val d = Instruction(0, compressed, expanded, 0x1c0, 0, 9)
  val e = Instruction(2, add, add, 0x1c4, 4, 9)
  val f = Instruction(6, add + 0x100000, add + 0x100000, 0x1cc, 12, 9)
  send(0x1c0, d, e, f)
  observe("append without moving observed slots", a, b, d)
  dequeue()
  observe("remaining slots preserve packet order", e, f)

  val access = Instruction(2, add, add, 0x1d4, 20, 10, accessFault = true)
  send(0x1d4, access)
  observe("completed row with access fault", e, f, access)
  dequeue()
  observe("empty after consuming a complete row")

  send(0x1d4, access)
  observe("queued before simultaneous clear and enqueue", access)
  drive(0x1c0, Seq(d))
  poke(c.io.clear, 1)
  step(1)
  poke(c.io.enqValid, 0)
  poke(c.io.clear, 0)
  observe("no pre-redirect slots survive clear")

  for (i <- 0 until 10) {
    val origin = 0x200 + 8 * i
    val row = Seq(0, 1, 3).map(lane => Instruction(lane, compressed + (i << 2), expanded + (i << 20),
      origin + 2 * lane, (origin + 2 * lane) & 63, i))
    send(origin, row: _*)
    observe(s"in-order row $i across buffer wrap", row: _*)
    dequeue()
  }
  observe("empty after buffer wrap")
  println(s"FETCH_BUFFER_ROWS_CHECKED rows=$groups")
}

class FetchBufferPortsTest extends AnyFlatSpec {
  behavior of "FetchBuffer packets and per-slot decode readiness"

  it should "deliver partial rows, sparse packets, and metadata in place across redirects and wrap" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    val arguments = Array("--backend-name", "verilator", "--target-dir", "test_run_dir/fetch-buffer-ports")
    assert(Driver.execute(arguments, () => LazyModule(new FetchBufferPortsHarness).module)(new FetchBufferPortsTester(_)))
  }
}
