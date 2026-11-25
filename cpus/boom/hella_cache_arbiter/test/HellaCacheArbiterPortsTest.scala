// SPDX-License-Identifier: Apache-2.0
package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{AddressSet, DisableMonitors, LazyModule, LazyModuleImp}
import freechips.rocketchip.rocket.HellaCacheArbiter
import freechips.rocketchip.rocket.constants.MemoryOpConstants
import freechips.rocketchip.subsystem.{InSubsystem, TilesLocated}
import freechips.rocketchip.tile.{TileKey, TileVisibilityNodeKey}
import freechips.rocketchip.tilelink.{TLEphemeralNode, TLFuzzer, TLRAM}
import org.scalatest.flatspec.AnyFlatSpec

import boom.common.{BoomTileAttachParams, WithNLargeBooms}

class HellaCacheArbiterHarness(implicit p: Parameters) extends LazyModule {
  val visibilityNode = TLEphemeralNode()
  private val fuzz = LazyModule(new TLFuzzer(1))
  private val ram = LazyModule(new TLRAM(AddressSet(BigInt("80000000", 16), BigInt("0fffffff", 16)), beatBytes = 16))
  DisableMonitors { implicit p => ram.node := visibilityNode := fuzz.node }
  lazy val module = new HellaCacheArbiterHarnessModule(this)
}

class HellaCacheArbiterHarnessModule(outer: HellaCacheArbiterHarness) extends LazyModuleImp(outer) with MemoryOpConstants {
  private val tile = p(TilesLocated(InSubsystem)).collectFirst {
    case attach: BoomTileAttachParams => attach.tileParams
  }.get
  private implicit val configured: Parameters = p.alterPartial {
    case TileKey => tile
    case TileVisibilityNodeKey => outer.visibilityNode
  }

  val io = IO(new Bundle {
    val requestValid = Input(Vec(2, Bool()))
    val requestReady = Output(Vec(2, Bool()))
    val cacheReady = Input(Bool())
    val cacheValid = Output(Bool())
    val cacheAddress = Output(UInt(32.W))
    val cacheCommand = Output(UInt(5.W))
    val cacheTag = Output(UInt(16.W))
    val stageOneData = Output(UInt(64.W))
    val requesterStageOneKill = Input(Vec(2, Bool()))
    val stageOneKill = Output(Bool())
    val requesterStageTwoKill = Input(Vec(2, Bool()))
    val stageTwoKill = Output(Bool())
    val cacheNack = Input(Bool())
    val requesterNack = Output(Vec(2, Bool()))
    val responseValid = Input(Bool())
    val responseAddress = Input(UInt(32.W))
    val responseTag = Input(UInt(16.W))
    val responseData = Input(UInt(64.W))
    val requesterResponseValid = Output(Vec(2, Bool()))
    val requesterResponseTag = Output(Vec(2, UInt(16.W)))
    val requesterResponseData = Output(Vec(2, UInt(64.W)))
  })

  private val target = Module(new HellaCacheArbiter(2))
  private val memory = target.io.mem
  for (index <- 0 until 2) {
    val requester = target.io.requestor(index)
    requester.req.valid := io.requestValid(index)
    requester.req.bits := 0.U.asTypeOf(requester.req.bits)
    requester.req.bits.addr := (0x1000 + 8 * index).U
    requester.req.bits.tag := 7.U
    requester.req.bits.cmd := M_XA_SWAP
    requester.req.bits.size := 3.U
    requester.req.bits.phys := true.B
    requester.s1_data := 0.U.asTypeOf(requester.s1_data)
    requester.s1_data.data := (0x1230 + index).U
    requester.s1_kill := io.requesterStageOneKill(index)
    requester.s2_kill := io.requesterStageTwoKill(index)
    requester.keep_clock_enabled := false.B
    requester.uncached_resp.foreach(_.ready := true.B)
    io.requestReady(index) := requester.req.ready
    io.requesterNack(index) := requester.s2_nack
    io.requesterResponseValid(index) := requester.resp.valid
    io.requesterResponseTag(index) := requester.resp.bits.tag
    io.requesterResponseData(index) := requester.resp.bits.data
  }

  memory.req.ready := io.cacheReady
  memory.s2_nack := io.cacheNack
  memory.s2_nack_cause_raw := false.B
  memory.s2_uncached := false.B
  memory.s2_paddr := 0.U
  memory.resp.valid := io.responseValid
  memory.resp.bits := 0.U.asTypeOf(memory.resp.bits)
  memory.resp.bits.addr := io.responseAddress
  memory.resp.bits.tag := io.responseTag
  memory.resp.bits.data := io.responseData
  memory.resp.bits.cmd := M_XA_SWAP
  memory.resp.bits.size := 3.U
  memory.resp.bits.has_data := true.B
  memory.replay_next := false.B
  memory.s2_xcpt := 0.U.asTypeOf(memory.s2_xcpt)
  memory.s2_gpa := 0.U
  memory.s2_gpa_is_pte := false.B
  memory.uncached_resp.foreach { response =>
    response.valid := false.B
    response.bits := 0.U.asTypeOf(response.bits)
  }
  memory.ordered := true.B
  memory.perf := 0.U.asTypeOf(memory.perf)
  memory.clock_enabled := true.B

  io.cacheValid := memory.req.valid
  io.cacheAddress := memory.req.bits.addr
  io.cacheCommand := memory.req.bits.cmd
  io.cacheTag := memory.req.bits.tag
  io.stageOneData := memory.s1_data.data
  io.stageOneKill := memory.s1_kill
  io.stageTwoKill := memory.s2_kill
}

class HellaCacheArbiterPorts(dut: HellaCacheArbiterHarnessModule) extends PeekPokeTester(dut) {
  private val io = dut.io
  private val requesters = 0 until 2
  requesters.foreach { index =>
    poke(io.requestValid(index), 0)
    poke(io.requesterStageOneKill(index), 0)
    poke(io.requesterStageTwoKill(index), 0)
  }
  poke(io.cacheReady, 0)
  poke(io.cacheNack, 0)
  poke(io.responseValid, 0)
  poke(io.responseAddress, 0)
  poke(io.responseTag, 0)
  poke(io.responseData, 0)
  step(2)
  println("HELLA_CACHE_ARBITER_PORTS_START")

  requesters.foreach(index => poke(io.requestValid(index), 1))
  expect(io.cacheValid, 1, "valid while the shared cache is stalled")
  requesters.foreach(index => expect(io.requestReady(index), 0, s"no acceptance while stalled, requester=$index"))
  step(1)
  poke(io.cacheReady, 1)
  val accepted = requesters.filter(index => peek(io.requestReady(index)) == 1)
  expect(accepted.size == 1, "exactly one requester can be accepted")
  val older = accepted.headOption.getOrElse(0)
  val younger = 1 - older

  private def checkRequest(index: Int): BigInt = {
    expect(io.cacheValid, 1, s"cache request valid, requester=$index")
    expect(io.requestReady(index), 1, s"selected requester is ready, requester=$index")
    expect(io.cacheAddress, 0x1000 + 8 * index, s"selected address, requester=$index")
    expect(io.cacheCommand, 4, s"atomic swap command, requester=$index")
    peek(io.cacheTag)
  }

  private def checkStageOne(index: Int): Unit = {
    expect(io.stageOneData, 0x1230 + index, s"stage-one data, requester=$index")
  }

  val olderTag = checkRequest(older)
  step(1)
  poke(io.requestValid(older), 0)
  checkStageOne(older)
  val youngerTag = checkRequest(younger)
  expect(olderTag != youngerTag, "cache tags preserve the origin even for equal requester tags")
  step(1)
  poke(io.requestValid(younger), 0)
  checkStageOne(younger)
  step(2)

  private def respond(index: Int, tag: BigInt, data: BigInt): Unit = {
    poke(io.responseValid, 1)
    poke(io.responseAddress, 0x1000 + 8 * index)
    poke(io.responseTag, tag)
    poke(io.responseData, data)
    expect(io.requesterResponseValid(index), 1, s"response delivered to origin requester=$index")
    expect(io.requesterResponseValid(1 - index), 0, s"no duplicate response from requester=$index")
    expect(io.requesterResponseTag(index), 7, s"original tag reconstructed, requester=$index")
    expect(io.requesterResponseData(index), data, s"response data preserved, requester=$index")
    step(1)
  }

  respond(younger, youngerTag, BigInt("1234567887654321", 16))
  respond(older, olderTag, BigInt("fedcba9876543210", 16))
  poke(io.responseValid, 0)

  poke(io.requestValid(older), 1)
  step(1)
  poke(io.requestValid(older), 0)
  poke(io.requesterStageOneKill(younger), 1)
  expect(io.stageOneKill, 0, "stage-one kill from the other requester is ignored")
  poke(io.requesterStageOneKill(older), 1)
  expect(io.stageOneKill, 1, "stage-one kill follows the accepted requester")
  step(1)
  requesters.foreach(index => poke(io.requesterStageOneKill(index), 0))

  poke(io.requestValid(younger), 1)
  step(1)
  poke(io.requestValid(younger), 0)
  step(1)
  poke(io.requesterStageTwoKill(older), 1)
  expect(io.stageTwoKill, 0, "stage-two kill from the other requester is ignored")
  poke(io.requesterStageTwoKill(younger), 1)
  expect(io.stageTwoKill, 1, "stage-two kill follows the request two cycles earlier")
  step(1)
  requesters.foreach(index => poke(io.requesterStageTwoKill(index), 0))

  poke(io.requestValid(older), 1)
  step(1)
  poke(io.requestValid(older), 0)
  step(1)
  poke(io.cacheNack, 1)
  expect(io.requesterNack(older), 1, "negative acknowledgement reaches the stage-two requester")
  expect(io.requesterNack(younger), 0, "negative acknowledgement does not reach the other requester")
  println(s"HELLA_CACHE_ARBITER_PORTS_OBSERVED older=$older olderTag=$olderTag youngerTag=$youngerTag")
}

class HellaCacheArbiterPortsTest extends AnyFlatSpec {
  "HellaCacheArbiter" should "route accepted requests and tag responses independently of their completion order" in {
    implicit val p: Parameters = new WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
    assert(Driver.execute(Array("--backend-name", "treadle"),
      () => LazyModule(new HellaCacheArbiterHarness).module)(dut => new HellaCacheArbiterPorts(dut)))
  }
}
