package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import hardfloat.{RecFNToRecFN, fNFromRecFN, recFNFromFN}
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class RecFNToRecFNNaNHarness extends Module {
  val io = IO(new Bundle {
    val in = Input(UInt(64.W))
    val out = Output(UInt(32.W))
    val flags = Output(UInt(5.W))
  })

  private val converter = Module(new RecFNToRecFN(11, 53, 8, 24))
  converter.io.in := recFNFromFN(11, 53, io.in)
  converter.io.roundingMode := 0.U
  converter.io.detectTininess := hardfloat.consts.tininess_afterRounding
  io.out := fNFromRecFN(8, 24, converter.io.out)
  io.flags := converter.io.exceptionFlags
}

class RecFNToRecFNNaNTester(c: RecFNToRecFNNaNHarness) extends PeekPokeTester(c) {
  private val canonicalNaN = BigInt("7fc00000", 16)
  private val cases = Seq(
    ("quiet-positive", "7ff8000000000001", 0),
    ("quiet-negative", "fff8000000000001", 0),
    ("signaling-positive", "7ff0000000000001", 0x10),
    ("signaling-negative", "fff0000000000001", 0x10))
  for ((label, input, flags) <- cases) {
    poke(c.io.in, BigInt(input, 16))
    step(1)
    println(s"RECFN $label out=${peek(c.io.out).toString(16)} flags=${peek(c.io.flags)}")
    expect(c.io.out, canonicalNaN)
    expect(c.io.flags, BigInt(flags))
  }
}

class RecFNToRecFNNaNTest extends AnyFlatSpec with Matchers {
  behavior of "double-to-single recoded conversion"

  it should "return the canonical NaN and raise invalid only for signaling inputs" in {
    Driver(() => new RecFNToRecFNNaNHarness)(c => new RecFNToRecFNNaNTester(c)) should be(true)
  }
}
