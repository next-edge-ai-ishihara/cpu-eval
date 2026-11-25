package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import chisel3.util.Cat
import hardfloat.{RoundAnyRawFNToRecFN, fNFromRecFN, rawFloatFromRecFN, recFNFromFN}
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class RoundAnyRawFNModesHarness extends Module {
  val io = IO(new Bundle {
    val lowerBits = Input(UInt(64.W))
    val fractionalTail = Input(UInt(2.W))
    val mode = Input(UInt(3.W))
    val result = Output(UInt(64.W))
    val flags = Output(UInt(5.W))
  })

  private val lower = rawFloatFromRecFN(11, 53, recFNFromFN(11, 53, io.lowerBits))
  private val round = Module(new RoundAnyRawFNToRecFN(11, 55, 11, 53, 0))
  round.io.in.isNaN := lower.isNaN
  round.io.in.isInf := lower.isInf
  round.io.in.isZero := lower.isZero
  round.io.in.sign := lower.sign
  round.io.in.sExp := lower.sExp
  round.io.in.sig := Cat(lower.sig, io.fractionalTail)
  round.io.invalidExc := false.B
  round.io.infiniteExc := false.B
  round.io.roundingMode := io.mode
  round.io.detectTininess := hardfloat.consts.tininess_afterRounding
  io.result := fNFromRecFN(11, 53, round.io.out)
  io.flags := round.io.exceptionFlags
}

class RoundAnyRawFNModesTester(c: RoundAnyRawFNModesHarness) extends PeekPokeTester(c) {
  private val one = BigInt("3ff0000000000000", 16)
  for (sign <- 0 until 2; parity <- 0 until 2; tail <- 0 until 4; mode <- 0 until 5) {
    val lowerBits = (BigInt(sign) << 63) | (one + parity)
    val increaseMagnitude = mode match {
      case 0 => tail > 2 || (tail == 2 && parity == 1)
      case 1 => false
      case 2 => sign == 1 && tail != 0
      case 3 => sign == 0 && tail != 0
      case 4 => tail >= 2
    }
    val expected = lowerBits + (if (increaseMagnitude) 1 else 0)
    val flags = if (tail == 0) 0 else 1
    poke(c.io.lowerBits, lowerBits)
    poke(c.io.fractionalTail, tail)
    poke(c.io.mode, mode)
    step(1)
    println(s"ROUND $sign $parity $tail $mode out=${peek(c.io.result).toString(16)} flags=${peek(c.io.flags)}")
    expect(c.io.result, expected)
    expect(c.io.flags, BigInt(flags))
  }
}

class RoundAnyRawFNToRecFNModesTest extends AnyFlatSpec with Matchers {
  behavior of "double-precision rounding"

  it should "round both signs around a halfway point in all five IEEE rounding modes" in {
    Driver(() => new RoundAnyRawFNModesHarness)(c => new RoundAnyRawFNModesTester(c)) should be(true)
  }
}
