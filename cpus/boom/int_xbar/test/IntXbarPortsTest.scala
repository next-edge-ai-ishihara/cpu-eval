// SPDX-License-Identifier: Apache-2.0
package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy.{LazyModule, LazyModuleImp, Resource, SimpleDevice}
import freechips.rocketchip.interrupts._
import org.scalatest.flatspec.AnyFlatSpec

class IntXbarPortsHarness(implicit p: Parameters) extends LazyModule {
  val low = Resource(new SimpleDevice("int-low", Seq("cpu-eval,int-low")), "int")
  val high = Resource(new SimpleDevice("int-high", Seq("cpu-eval,int-high")), "int")
  val extra = Resource(new SimpleDevice("int-extra", Seq("cpu-eval,int-extra")), "int")

  val left = IntSourceNode(Seq(IntSourcePortParameters(Seq(
    IntSourceParameters(IntRange(1, 2), Seq(high)),
    IntSourceParameters(IntRange(0, 1), Seq(low))))))
  val right = IntSourceNode(Seq(IntSourcePortParameters(Seq(
    IntSourceParameters(IntRange(0, 1), Seq(extra))))))
  private val target = LazyModule(new IntXbar)
  val first = IntSinkNode(IntSinkPortSimple())
  val second = IntSinkNode(IntSinkPortSimple())
  target.intnode := left
  target.intnode := right
  first := target.intnode
  second := target.intnode

  lazy val module = new IntXbarPortsHarnessModule(this)
}

class IntXbarPortsHarnessModule(outer: IntXbarPortsHarness) extends LazyModuleImp(outer) {
  import outer._

  val io = IO(new Bundle {
    val interrupts = Input(Vec(3, Bool()))
    val sinkValues = Output(Vec(2, Vec(3, Bool())))
    val rangeMapping = Output(Vec(2, Bool()))
  })
  left.out.head._1.zip(io.interrupts.take(2)).foreach { case (signal, input) => signal := input }
  right.out.head._1.head := io.interrupts(2)

  val expected = Map(low -> (0, left), high -> (1, left), extra -> (2, right))
  val sinks = Seq(first.in.head, second.in.head)
  sinks.zipWithIndex.foreach { case ((signals, edge), index) =>
    val sources = edge.source.sources
    val mapped = sources.size == expected.size && expected.forall { case (resource, (number, origin)) =>
      sources.count(source => source.range == IntRange(number, number + 1) &&
        source.resources == Seq(resource) && source.nodePath.lastOption.contains(origin)) == 1
    }
    io.rangeMapping(index) := mapped.B
    io.sinkValues(index).zip(signals.toSeq.padTo(3, false.B)).foreach { case (output, signal) =>
      output := signal
    }
  }
}

class IntXbarPorts(dut: IntXbarPortsHarnessModule) extends PeekPokeTester(dut) {
  private val io = dut.io
  println("INT_XBAR_PORTS_START")
  for (sink <- 0 until 2) {
    expect(io.rangeMapping(sink), 1, s"sink $sink retains the interrupt number, resource and origin")
  }
  for (pattern <- 0 until 8) {
    for (line <- 0 until 3) poke(io.interrupts(line), (pattern >> line) & 1)
    for (sink <- 0 until 2) {
      for (line <- 0 until 3) {
        expect(io.sinkValues(sink)(line), (pattern >> line) & 1, s"pattern $pattern sink $sink interrupt $line")
      }
    }
  }
  println("INT_XBAR_PORTS_OBSERVED patterns=8 sinks=2 lines=3")
}

class IntXbarPortsTest extends AnyFlatSpec {
  "IntXbar" should "deliver ordered interrupt levels and source identities to both sinks" in {
    implicit val p: Parameters = Parameters.empty
    assert(Driver.execute(Array("--backend-name", "treadle"),
      () => LazyModule(new IntXbarPortsHarness).module)(dut => new IntXbarPorts(dut)))
  }
}
