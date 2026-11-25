package boom.tests

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import chisel3.stage.ChiselStage

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._

class BundleBridgeNexusHarness(implicit p: Parameters) extends LazyModule {
  private val source0 = BundleBridgeSource(() => UInt(8.W))
  private val source1 = BundleBridgeSource(() => UInt(8.W))
  private val nexus = LazyModule(new BundleBridgeNexus[UInt](
    inputFn = inputs => inputs.reduce(_ | _),
    outputFn = (value, count) => Seq.tabulate(count)(i => value + i.U),
    default = Some(() => "h80".U(8.W))))
  private val sink0 = BundleBridgeSink[UInt]()
  private val sink1 = BundleBridgeSink[UInt]()
  nexus.node := source0
  nexus.node := source1
  sink0 := nexus.node
  sink1 := nexus.node

  lazy val module = new BundleBridgeNexusHarnessModule(this, source0, source1, sink0, sink1)
}

class BundleBridgeNexusHarnessModule(
  outer: BundleBridgeNexusHarness,
  source0: BundleBridgeSource[UInt],
  source1: BundleBridgeSource[UInt],
  sink0: BundleBridgeSink[UInt],
  sink1: BundleBridgeSink[UInt]) extends LazyModuleImp(outer) {
  val input0 = source0.makeIO("input0")
  val input1 = source1.makeIO("input1")
  val output0 = sink0.makeIO("output0")
  val output1 = sink1.makeIO("output1")
}

class BundleBridgeNexusTester(c: BundleBridgeNexusHarnessModule)
  extends PeekPokeTester(c) {
  poke(c.input0, 0x12)
  poke(c.input1, 0x41)
  expect(c.output0, 0x53)
  expect(c.output1, 0x54)
}

class BundleBridgeNexusDefaultHarness(implicit p: Parameters) extends LazyModule {
  private val nexus = LazyModule(new BundleBridgeNexus[UInt](
    inputFn = _ => throw new AssertionError("inputFn must not receive an empty input sequence"),
    outputFn = (value, count) => Seq.fill(count)(value + 1.U),
    default = Some(() => "h24".U(8.W))))
  private val sink = BundleBridgeSink[UInt]()
  sink := nexus.node

  lazy val module = new BundleBridgeNexusDefaultHarnessModule(this, sink)
}

class BundleBridgeNexusDefaultHarnessModule(outer: BundleBridgeNexusDefaultHarness, sink: BundleBridgeSink[UInt])
  extends LazyModuleImp(outer) {
  val output = sink.makeIO("output")
}

class BundleBridgeNexusDefaultTester(c: BundleBridgeNexusDefaultHarnessModule)
  extends PeekPokeTester(c) {
  expect(c.output, 0x25)
}

class BundleBridgeNexusNoOutputHarness(implicit p: Parameters) extends LazyModule {
  private val source = BundleBridgeSource(() => UInt(8.W))
  private val nexus = LazyModule(new BundleBridgeNexus[UInt](
    inputFn = _.head,
    outputFn = (value, count) => Seq.fill(count)(value),
    inputRequiresOutput = false))
  nexus.node := source

  lazy val module = new LazyModuleImp(this) {
    source.makeIO("input")
  }
}

class BundleBridgeNexusBadInputTypeHarness(implicit p: Parameters) extends LazyModule {
  private val source0 = BundleBridgeSource(() => UInt(8.W))
  private val source1 = BundleBridgeSource(() => UInt(16.W))
  private val nexus = LazyModule(new BundleBridgeNexus[UInt](
    inputFn = _.head,
    outputFn = (value, count) => Seq.fill(count)(value)))
  private val sink = BundleBridgeSink[UInt]()
  nexus.node := source0
  nexus.node := source1
  sink := nexus.node

  lazy val module = new LazyModuleImp(this) {
    source0.makeIO("input0")
    source1.makeIO("input1")
    sink.makeIO("output")
  }
}

class BundleBridgeNexusBadOutputHarness(makeOutputs: (UInt, Int) => Seq[UInt])
  (implicit p: Parameters) extends LazyModule {
  private val source = BundleBridgeSource(() => UInt(8.W))
  private val nexus = LazyModule(new BundleBridgeNexus[UInt](
    inputFn = _.head,
    outputFn = makeOutputs))
  private val sink = BundleBridgeSink[UInt]()
  nexus.node := source
  sink := nexus.node

  lazy val module = new LazyModuleImp(this) {
    source.makeIO("input")
    sink.makeIO("output")
  }
}

class BundleBridgeNexusTest extends AnyFlatSpec with Matchers {
  behavior of "BundleBridgeNexus"

  it should "reduce every input and generate each transformed public output" in {
    implicit val p: Parameters = Parameters.empty
    Driver(() => LazyModule(new BundleBridgeNexusHarness).module)(
      c => new BundleBridgeNexusTester(c)) should be(true)
  }

  it should "transform the default when no source is connected" in {
    implicit val p: Parameters = Parameters.empty
    Driver(() => LazyModule(new BundleBridgeNexusDefaultHarness).module)(
      c => new BundleBridgeNexusDefaultTester(c)) should be(true)
  }

  it should "elaborate an input-only graph when no sink is required" in {
    implicit val p: Parameters = Parameters.empty
    ChiselStage.emitChirrtl(LazyModule(new BundleBridgeNexusNoOutputHarness).module)
  }

  it should "reject inputs with incompatible Chisel data types" in {
    implicit val p: Parameters = Parameters.empty
    the[IllegalArgumentException] thrownBy {
      ChiselStage.emitChirrtl(LazyModule(new BundleBridgeNexusBadInputTypeHarness).module)
    }
  }

  it should "reject an output function that returns the wrong number of values" in {
    implicit val p: Parameters = Parameters.empty
    the[IllegalArgumentException] thrownBy {
      ChiselStage.emitChirrtl(LazyModule(new BundleBridgeNexusBadOutputHarness(
        (value, count) => Seq.fill(count + 1)(value))).module)
    }
  }

  it should "reject an output function with an incompatible result type" in {
    implicit val p: Parameters = Parameters.empty
    the[IllegalArgumentException] thrownBy {
      ChiselStage.emitChirrtl(LazyModule(new BundleBridgeNexusBadOutputHarness(
        (_, count) => Seq.fill(count)("h1234".U(16.W)))).module)
    }
  }
}
