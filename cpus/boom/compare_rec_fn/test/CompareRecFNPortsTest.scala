package boom.tests

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import hardfloat.{CompareRecFN, recFNFromFN}

class CompareRecFNPortHarness(expWidth: Int, sigWidth: Int) extends Module {
  val io = IO(new Bundle {
    val a = Input(UInt((expWidth + sigWidth).W))
    val b = Input(UInt((expWidth + sigWidth).W))
    val signaling = Input(Bool())
    val lt = Output(Bool())
    val eq = Output(Bool())
    val gt = Output(Bool())
    val flags = Output(UInt(5.W))
  })

  private val comparator = Module(new CompareRecFN(expWidth, sigWidth))
  comparator.io.a := recFNFromFN(expWidth, sigWidth, io.a)
  comparator.io.b := recFNFromFN(expWidth, sigWidth, io.b)
  comparator.io.signaling := io.signaling
  io.lt := comparator.io.lt
  io.eq := comparator.io.eq
  io.gt := comparator.io.gt
  io.flags := comparator.io.exceptionFlags
}

class CompareRecFNPortsTester(c: CompareRecFNPortHarness, expWidth: Int, sigWidth: Int)
  extends PeekPokeTester(c) {
  private val fractionWidth = sigWidth - 1
  private val sign = BigInt(1) << (expWidth + fractionWidth)
  private val infinity = ((BigInt(1) << expWidth) - 1) << fractionWidth
  private val one = ((BigInt(1) << (expWidth - 1)) - 1) << fractionWidth
  private val two = one + (BigInt(1) << fractionWidth)
  private val quietNaN = infinity | (BigInt(1) << (fractionWidth - 1))
  private val signalingNaN = infinity | 1

  def compare(a: BigInt, b: BigInt, ordering: Option[Int],
              signaling: Boolean = false, flags: Int = 0): Unit = {
    poke(c.io.a, a)
    poke(c.io.b, b)
    poke(c.io.signaling, if (signaling) 1 else 0)
    val pair = s"Comparison of 0x${a.toString(16)} and 0x${b.toString(16)}"
    expect(c.io.lt, if (ordering.contains(-1)) 1 else 0, pair)
    expect(c.io.eq, if (ordering.contains(0)) 1 else 0, pair)
    expect(c.io.gt, if (ordering.contains(1)) 1 else 0, pair)
    expect(c.io.flags, flags, pair)
  }

  compare(0, sign, Some(0))
  compare(sign, 0, Some(0))
  compare(one, two, Some(-1))
  compare(two, one, Some(1))
  compare(sign | one, sign | two, Some(1))
  compare(1, 0, Some(1))
  compare(infinity, infinity, Some(0))
  compare(sign | infinity, infinity, Some(-1))
  compare(quietNaN, one, None)
  compare(quietNaN, one, None, signaling = true, flags = 0x10)
  compare(one, signalingNaN, None, flags = 0x10)
}

class CompareRecFNPortsTest extends AnyFlatSpec with Matchers {
  behavior of "CompareRecFN"

  for ((expWidth, sigWidth) <- Seq((8, 24), (11, 53))) {
    it should s"drive all comparison outputs for ($expWidth, $sigWidth)" in {
      Driver(() => new CompareRecFNPortHarness(expWidth, sigWidth))(
        c => new CompareRecFNPortsTester(c, expWidth, sigWidth)) should be(true)
    }
  }
}
