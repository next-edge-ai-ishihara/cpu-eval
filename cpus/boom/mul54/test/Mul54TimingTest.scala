package boom.tests

import chisel3.iotesters.{Driver, PeekPokeTester}
import hardfloat.Mul54
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class Mul54TimingTester(dut: Mul54) extends PeekPokeTester(dut) {
  // The low two bits select the A and B latches. Start a new group with both factors.
  val timing = Vector(Some(3), Some(1), Some(2), Some(0), None, Some(3),
                      None, None, Some(3), Some(3), Some(0), None, None)
  val zeroA = timing.size
  val zeroB = zeroA + 1
  val requests = timing ++ Vector(Some(3), Some(3), None, None)
  val factorMask = (BigInt(1) << 54) - 1
  val resultMask = (BigInt(1) << 105) - 1
  val products = Array.fill[Option[BigInt]](requests.size)(None)
  var a = BigInt(0)
  var b = BigInt(0)

  println("MUL54_TIMING_OBSERVATIONS_STARTED")
  for ((request, cycle) <- requests.zipWithIndex) {
    val nextA = if (cycle == zeroA) BigInt(0)
                else if (cycle == zeroB) BigInt(3)
                else factorMask - (cycle + 1) * 17
    val nextB = if (cycle == zeroB) BigInt(0) else (BigInt(1) << 53) + (cycle + 1) * 31
    val addend = resultMask - ((BigInt(cycle) + 1) << 84) + cycle
    val latchA = (request.getOrElse(0) & 1) != 0
    val latchB = (request.getOrElse(0) & 2) != 0
    poke(dut.io.val_s0, if (request.isDefined) 1 else 0)
    poke(dut.io.latch_a_s0, if (latchA) 1 else 0)
    poke(dut.io.latch_b_s0, if (latchB) 1 else 0)
    poke(dut.io.a_s0, nextA)
    poke(dut.io.b_s0, nextB)
    poke(dut.io.c_s2, addend)
    if (latchA) a = nextA
    if (latchB) b = nextB
    products(cycle) = request.map(_ => a * b)
    step(1)
    if (cycle >= 2) {
      products(cycle - 2).foreach { product =>
        expect(dut.io.result_s3, (product + addend) & resultMask,
               s"result for request in cycle ${cycle - 2}")
      }
    }
  }
}

class Mul54TimingTest extends AnyFlatSpec with Matchers {
  it should "return each accepted multiply-add after three cycles" in {
    Driver(() => new Mul54)(dut => new Mul54TimingTester(dut)) should be(true)
  }
}
