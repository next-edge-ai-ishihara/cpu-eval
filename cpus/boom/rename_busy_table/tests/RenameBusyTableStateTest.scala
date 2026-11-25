// SPDX-License-Identifier: Apache-2.0
package boom.tests

import boom.common.{BoomTileAttachParams, WithNLargeBooms}
import boom.exu.RenameBusyTable
import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}
import org.scalatest.flatspec.AnyFlatSpec

class RenameBusyTableHarness(val floatingPoint: Boolean)(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new RenameBusyTableHarnessModule(this)
}

class RenameBusyTableHarnessModule(outer: RenameBusyTableHarness) extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  implicit val testP: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  val floatingPoint = outer.floatingPoint
  val registerCount = if (floatingPoint) tile.core.numFpPhysRegisters else tile.core.numIntPhysRegisters
  private val wakeupCount = if (floatingPoint) 2 else 7
  private val dut = Module(new RenameBusyTable(tile.core.decodeWidth, registerCount, wakeupCount, false, floatingPoint))
  val io = IO(chiselTypeOf(dut.io))
  io <> dut.io
}

class RenameBusyTableStateTester(c: RenameBusyTableHarnessModule) extends PeekPokeTester(c) {
  private val high = c.registerCount - 1
  private val lastLane = c.io.ren_uops.length - 1
  private val lastWakeup = c.io.wb_valids.length - 1
  private val mode = if (c.floatingPoint) "fp" else "integer"
  private def logical(register: Int): Int = if (register == high) 3 else register

  private def allocate(lane: Int, register: Int, valid: Boolean): Unit = {
    val uop = c.io.ren_uops(lane)
    poke(uop.pdst, register)
    poke(uop.ldst, logical(register))
    poke(uop.ldst_val, if (valid) 1 else 0)
    poke(uop.dst_rtype, if (c.floatingPoint) 1 else 0)
    poke(c.io.rebusy_reqs(lane), if (valid) 1 else 0)
  }

  private def notify(port: Int, register: Int, valid: Boolean): Unit = {
    poke(c.io.wb_pdsts(port), register)
    poke(c.io.wb_valids(port), if (valid) 1 else 0)
  }

  private def query(first: Int, second: Int, third: Int): Unit = {
    val uop = c.io.ren_uops(0)
    poke(uop.prs1, first)
    poke(uop.prs2, second)
    poke(uop.prs3, third)
    poke(uop.lrs1, logical(first))
    poke(uop.lrs2, logical(second))
    poke(uop.lrs3, logical(third))
    poke(uop.lrs1_rtype, if (c.floatingPoint) 1 else 0)
    poke(uop.lrs2_rtype, if (c.floatingPoint) 1 else 0)
    poke(uop.frs3_en, if (c.floatingPoint) 1 else 0)
  }

  private def observe(label: String, busy: Set[Int], sources: Seq[Int]): Unit = {
    val mask = busy.foldLeft(BigInt(0))((bits, id) => bits.setBit(id))
    val resp = c.io.busy_resps(0)
    val readiness = if (c.floatingPoint) Seq(resp.prs1_busy, resp.prs2_busy, resp.prs3_busy)
                    else Seq(resp.prs1_busy, resp.prs2_busy)
    val expected = sources.map(id => if (busy(id)) 1 else 0)
    val observed = readiness.map(port => peek(port)).mkString(",")
    println(s"RENAME_BUSY $mode $label busy=${peek(c.io.debug.busytable).toString(16)} sources=$observed")
    expect(c.io.debug.busytable, mask, s"$mode $label bitmap")
    for ((port, value) <- readiness.zip(expected)) {
      expect(port, value, s"$mode $label source")
    }
  }

  private val initialSources = Seq(0, 0, 0)
  private val liveSources = Seq(1, 2, high)
  query(0, 0, 0)
  observe("initial", Set.empty, initialSources)

  allocate(0, 1, valid = true)
  allocate(lastLane, high, valid = true)
  step(1)
  allocate(0, 1, valid = false)
  allocate(lastLane, high, valid = false)
  query(1, 0, high)
  observe("two-allocations", Set(1, high), Seq(1, 0, high))

  notify(0, 1, valid = true)
  allocate(lastLane, 2, valid = true)
  step(1)
  notify(0, 1, valid = false)
  allocate(lastLane, 2, valid = false)
  query(1, 2, high)
  observe("distinct-allocate-and-wakeup", Set(2, high), liveSources)

  notify(0, 2, valid = true)
  notify(lastWakeup, high, valid = true)
  step(1)
  notify(0, 2, valid = false)
  notify(lastWakeup, high, valid = false)
  observe("two-wakeups", Set.empty, liveSources)

  query(0, 0, 0)
  allocate(lastLane, 4, valid = true)
  step(1)
  allocate(lastLane, 4, valid = false)
  observe("before-reset", Set(4), initialSources)
  reset(2)
  observe("after-reset", Set.empty, initialSources)
}

class RenameBusyTableStateTest extends AnyFlatSpec {
  for (floatingPoint <- Seq(false, true)) {
    val name = if (floatingPoint) "floating-point" else "integer"
    s"The $name RenameBusyTable" should "track allocation and wakeup and clear its bitmap on reset" in {
      implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
      assert(Driver.execute(Array("--backend-name", "treadle"),
        () => LazyModule(new RenameBusyTableHarness(floatingPoint)).module)(c => new RenameBusyTableStateTester(c)))
    }
  }
}
