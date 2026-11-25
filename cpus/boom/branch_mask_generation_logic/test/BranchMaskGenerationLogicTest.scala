package boom.tests

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}

import boom.common.{BoomTileAttachParams, WithNLargeBooms}
import boom.exu.BranchMaskGenerationLogic

class BranchMaskGenerationLogicHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(
    AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }

  lazy val module = new BranchMaskGenerationLogicHarnessModule(this)
}

class BranchMaskGenerationLogicHarnessModule(outer: BranchMaskGenerationLogicHarness)
  extends LazyModuleImp(outer) {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  private val params = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }
  private val width = 3
  private val tags = 16
  private val dut = Module(new BranchMaskGenerationLogic(width)(params))
  val io = IO(new Bundle {
    val is_branch = Input(Vec(width, Bool()))
    val will_fire = Input(Vec(width, Bool()))
    val resolve_mask = Input(UInt(tags.W))
    val mispredict_mask = Input(UInt(tags.W))
    val recovery = Input(Bool())
    val recovery_mask = Input(UInt(tags.W))
    val flush_pipeline = Input(Bool())
    val br_tag = Output(Vec(width, UInt(chisel3.util.log2Ceil(tags).W)))
    val br_mask = Output(Vec(width, UInt(tags.W)))
    val is_full = Output(Vec(width, Bool()))
    val debug_branch_mask = Output(UInt(tags.W))
  })
  dut.io.is_branch := io.is_branch
  dut.io.will_fire := io.will_fire
  dut.io.flush_pipeline := io.flush_pipeline
  dut.io.brupdate.b1.resolve_mask := io.resolve_mask
  dut.io.brupdate.b1.mispredict_mask := io.mispredict_mask
  val b2 = dut.io.brupdate.b2
  b2.valid := io.recovery
  b2.mispredict := io.recovery
  b2.uop := 0.U.asTypeOf(b2.uop)
  b2.uop.br_mask := io.recovery_mask
  b2.taken := false.B
  b2.cfi_type := 0.U
  b2.pc_sel := 0.U
  b2.jalr_target := 0.U
  b2.target_offset := 0.S
  io.br_tag := dut.io.br_tag
  io.br_mask := dut.io.br_mask
  io.is_full := dut.io.is_full
  io.debug_branch_mask := dut.io.debug_branch_mask
}

class BranchMaskGenerationLogicTester(c: BranchMaskGenerationLogicHarnessModule)
  extends PeekPokeTester(c) {
  private val lanes = 0 until 3
  private val everyLane = lanes.toSet
  private val noLanes = Set.empty[Int]
  private val empty = BigInt(0)
  private val full = (BigInt(1) << 16) - 1

  private def drive(branches: Set[Int] = noLanes, fires: Set[Int] = noLanes,
                    resolved: BigInt = empty, mispredicted: BigInt = empty,
                    recovery: Option[BigInt] = None, flush: Boolean = false): Unit = {
    for (lane <- lanes) {
      poke(c.io.is_branch(lane), if (branches(lane)) 1 else 0)
      poke(c.io.will_fire(lane), if (fires(lane)) 1 else 0)
    }
    poke(c.io.resolve_mask, resolved)
    poke(c.io.mispredict_mask, mispredicted)
    poke(c.io.recovery, if (recovery.nonEmpty) 1 else 0)
    poke(c.io.recovery_mask, recovery.getOrElse(empty))
    poke(c.io.flush_pipeline, if (flush) 1 else 0)
  }

  private def accept(lane: Int, older: BigInt): BigInt = {
    assert(peek(c.io.is_full(lane)) == 0, s"lane $lane stalled with an available tag")
    expect(c.io.br_mask(lane), older)
    val bit = BigInt(1) << peek(c.io.br_tag(lane)).toInt
    assert((bit & older) == 0 && bit <= full, s"lane $lane reused an unresolved tag")
    bit
  }

  drive(branches = everyLane)
  step(1)
  expect(c.io.debug_branch_mask, empty)
  expect(c.io.br_mask(2), empty)

  var active = empty
  for (_ <- 0 until 5) {
    drive(branches = everyLane, fires = everyLane)
    for (lane <- lanes) active |= accept(lane, active)
    step(1)
    expect(c.io.debug_branch_mask, active)
  }
  drive(branches = everyLane, fires = Set(0))
  active |= accept(0, active)
  expect(c.io.is_full(1), 1)
  expect(c.io.is_full(2), 1)
  step(1)
  expect(c.io.debug_branch_mask, full)

  drive(branches = Set(1, 2))
  expect(c.io.is_full(0), 0)
  expect(c.io.is_full(1), 1)
  expect(c.io.br_mask(0), full)
  step(1)

  val released = BigInt("2400", 16)
  drive(resolved = released)
  expect(c.io.br_mask(0), full & ~released)
  step(1)
  expect(c.io.debug_branch_mask, full & ~released)
  drive(branches = Set(0), fires = Set(0))
  val reused = accept(0, full & ~released)
  expect(c.io.br_mask(1), (full & ~released) | reused)
  step(1)

  drive(flush = true)
  step(1)
  expect(c.io.debug_branch_mask, empty)

  drive(branches = everyLane, fires = everyLane)
  val older = accept(0, empty)
  val olderResolvedDuringRecovery = accept(1, older)
  val olderDependencies = older | olderResolvedDuringRecovery
  val mispredicted = accept(2, olderDependencies)
  step(1)
  drive(branches = Set(0), fires = Set(0))
  val younger = accept(0, olderDependencies | mispredicted)
  step(1)
  expect(c.io.debug_branch_mask, olderDependencies | mispredicted | younger)

  // The parent stalls decode in both phases of a branch recovery.
  drive(resolved = mispredicted, mispredicted = mispredicted)
  step(1)
  drive(resolved = olderResolvedDuringRecovery, recovery = Some(olderDependencies))
  step(1)
  expect(c.io.debug_branch_mask, older)

  drive(branches = everyLane, fires = everyLane, resolved = older)
  val first = accept(0, empty)
  val second = accept(1, first)
  val last = accept(2, first | second)
  // Rename strips the current resolution mask before registering younger uops.
  assert(((first | second) & older) == 0,
    "a same-group dependency would be cleared by the parent rename stage")
  step(1)
  expect(c.io.debug_branch_mask, first | second | last)
}

class BranchMaskGenerationLogicTest extends AnyFlatSpec with Matchers {
  behavior of "BranchMaskGenerationLogic"

  it should "track accepted tags, their dependencies, and recovery across decode lanes" in {
    implicit val p: Parameters =
      new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    Driver(() => LazyModule(new BranchMaskGenerationLogicHarness).module)(
      c => new BranchMaskGenerationLogicTester(c)) should be(true)
  }
}
