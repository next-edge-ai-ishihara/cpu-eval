package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import chisel3.util.random.{LFSRReduce, MaxPeriodFibonacciLFSR, PRNGIO, XNOR, XOR}
import org.scalatest.flatspec.AnyFlatSpec

class MaxPeriodFibonacciLFSRHarness(width: Int, seed: Option[BigInt], reduction: LFSRReduce) extends Module {
  val io = IO(new PRNGIO(width))
  val generator = Module(new MaxPeriodFibonacciLFSR(width, seed, reduction))
  io <> generator.io
}

class MaxPeriodFibonacciLFSRTester(
  dut: MaxPeriodFibonacciLFSRHarness,
  width: Int,
  initial: Option[Int],
  inverted: Boolean,
  choices: Seq[Seq[Int]]
) extends PeekPokeTester(dut) {
  private val mask = (1 << width) - 1
  private var remaining = choices

  private def check(condition: Boolean, description: => String): Unit = {
    if (!condition) {
      val message = s"CPU_EVAL_LFSR_PORT_MISMATCH: width=$width inverted=$inverted $description"
      println(message)
      assert(condition, message)
    }
  }

  private def readState(): Int =
    (0 until width).foldLeft(0)((value, bit) => value | (peek(dut.io.out(bit)).toInt << bit))

  private def feedback(state: Int, taps: Seq[Int]): Int = {
    val parity = taps.foldLeft(0)((value, tap) => value ^ ((state >> (tap - 1)) & 1))
    ((state << 1) & mask) | (if (inverted) parity ^ 1 else parity)
  }

  private def advance(state: Int, increment: Boolean, load: Option[Int], label: String): Int = {
    poke(dut.io.increment, if (increment) 1 else 0)
    poke(dut.io.seed.valid, if (load.isDefined) 1 else 0)
    (0 until width).foreach(bit => poke(dut.io.seed.bits(bit), (load.getOrElse(0) >> bit) & 1))
    step(1)
    val observed = readState()
    def expected(taps: Seq[Int]): Int = load.getOrElse(if (increment) feedback(state, taps) else state)
    val expectedStates = remaining.map(expected).distinct
    check(expectedStates.contains(observed), s"$label expected=${expectedStates.mkString(",")} observed=$observed")
    remaining = remaining.filter(expected(_) == observed)
    observed
  }

  poke(dut.io.increment, 0)
  poke(dut.io.seed.valid, 0)
  (0 until width).foreach(bit => poke(dut.io.seed.bits(bit), 0))
  reset(5)
  val resetState = readState()
  initial match {
    case Some(value) => check(resetState == value, s"reset expected=$value observed=$resetState")
    case None =>
      val safeBit = if (inverted) 0 else 1
      check((resetState & 1) == safeBit, s"reset without seed expected bit 0=$safeBit observed=$resetState")
  }

  val held = advance(resetState, false, None, "hold")
  val first = advance(held, true, None, "advance")
  val seeded = advance(first, true, Some(3), "load over increment")
  val newSeed = advance(seeded, false, Some(1), "load while paused")
  advance(newSeed, false, None, "hold loaded seed")
  val steps = if (width == 6) mask else 64
  val visited = (0 until steps).scanLeft(newSeed)((state, _) => advance(state, true, None, "sequence"))
  if (width == 6) {
    check(visited.last == newSeed && visited.dropRight(1).distinct.size == mask, "period must be 63")
  }
  println(s"CPU_EVAL_LFSR_PORT_PASS width=$width inverted=$inverted initial=$initial steps=$steps")
}

class MaxPeriodFibonacciLFSRPortsTest extends AnyFlatSpec {
  private val six = Seq(Seq(6, 5), Seq(6, 5, 3, 2))
  private val sixteen = Seq(Seq(16, 14, 13, 11))

  private def check(width: Int, seed: Option[Int], reduction: LFSRReduce, choices: Seq[Seq[Int]], target: String): Unit = {
    val arguments = Array("--backend-name", "firrtl", "--test-seed", "1", "--target-dir",
      sys.props("cpu.eval.lfsr.target") + "/" + target)
    assert(Driver.execute(arguments, () => new MaxPeriodFibonacciLFSRHarness(width, seed.map(BigInt(_)), reduction))(
      dut => new MaxPeriodFibonacciLFSRTester(dut, width, seed, reduction == XNOR, choices)))
  }

  "A maximal-period Fibonacci LFSR" should "advance the 16-bit BOOM replacement generator" in {
    check(16, Some(1), XOR, sixteen, "boom-replacement")
  }

  it should "accept either width-six tap set and preserve XOR seed loading" in {
    check(6, Some(17), XOR, six, "six-xor")
  }

  it should "honor the XNOR reduction argument with an explicit seed" in {
    check(6, Some(9), XNOR, six, "six-xnor")
  }

  it should "choose a safe reset bit for XOR without a constructor seed" in {
    check(6, None, XOR, six, "none-xor")
  }

  it should "choose a safe reset bit for XNOR without a constructor seed" in {
    check(6, None, XNOR, six, "none-xnor")
  }
}
