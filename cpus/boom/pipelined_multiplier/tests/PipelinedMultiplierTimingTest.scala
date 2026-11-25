// SPDX-License-Identifier: Apache-2.0
package boom.tests

import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.rocket.PipelinedMultiplier
import org.scalatest.flatspec.AnyFlatSpec

class PipelinedMultiplierTimingTester(dut: PipelinedMultiplier, latency: Int) extends PeekPokeTester(dut) {
  private case class Operation(fn: Int, widthCode: Int, left: BigInt, right: BigInt, result: BigInt)
  private val max = (BigInt(1) << 64) - 1
  private val requests = Seq(
    None,
    Some(Operation(0, 1, 5, 9, 45)),
    Some(Operation(1, 1, max - 1, 3, max)),
    None,
    Some(Operation(2, 1, max - 1, max, max - 1)),
    Some(Operation(3, 1, max, 2, 1)),
    Some(Operation(0, 0, BigInt("1234567880000000", 16), 3, BigInt("ffffffff80000000", 16))),
    None,
    None,
    Some(Operation(0, 1, 17, 19, 323)),
    None
  )
  println("PIPELINED_MULTIPLIER_TIMING_START")
  for ((request, cycle) <- (requests ++ Seq.fill(latency)(None)).zipWithIndex) {
    val stimulus = request.getOrElse(Operation(0, 1, 11, 13, 143))
    poke(dut.io.req.valid, if (request.isDefined) 1 else 0)
    poke(dut.io.req.bits.fn, stimulus.fn)
    poke(dut.io.req.bits.dw, stimulus.widthCode)
    poke(dut.io.req.bits.in1, stimulus.left)
    poke(dut.io.req.bits.in2, stimulus.right)
    poke(dut.io.req.bits.tag, 0)
    step(1)

    val expected = requests.lift(cycle + 1 - latency).flatten
    expect(dut.io.resp.valid, if (expected.isDefined) 1 else 0, s"response valid at observation ${cycle + 1}")
    expected.foreach(operation =>
      expect(dut.io.resp.bits.data, operation.result, s"response product at observation ${cycle + 1}"))
  }
  println("PIPELINED_MULTIPLIER_TIMING_OBSERVED")
}

class PipelinedMultiplierTimingTest extends AnyFlatSpec {
  "PipelinedMultiplier" should "align each valid product with its request across empty and adjacent cycles" in {
    val latency = 3
    assert(Driver.execute(Array("--backend-name", "treadle", "--target-dir",
      sys.env.getOrElse("CPU_EVAL_DIRECTED_TARGET", "test_run_dir")),
      () => new PipelinedMultiplier(64, latency))(dut => new PipelinedMultiplierTimingTester(dut, latency)))
  }
}
