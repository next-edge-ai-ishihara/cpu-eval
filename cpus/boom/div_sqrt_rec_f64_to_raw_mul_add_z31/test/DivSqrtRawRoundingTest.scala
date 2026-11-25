package boom.tests

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import hardfloat.{DivSqrtRecF64ToRaw_mulAddZ31, Mul54, RoundRawFNToRecFN, fNFromRecFN, recFNFromFN}
import hardfloat.consts.{flRoundOpt_sigMSBitAlwaysZero, tininess_afterRounding}

class DivSqrtRawRoundingHarness extends Module {
  val io = IO(new Bundle {
    val valid = Input(Bool())
    val sqrt = Input(Bool())
    val a = Input(UInt(64.W))
    val b = Input(UInt(64.W))
    val mode = Input(UInt(3.W))
    val ready = Output(Bool())
    val done = Output(Bool())
    val modeOut = Output(UInt(3.W))
    val result = Output(UInt(64.W))
    val exceptions = Output(UInt(5.W))
  })

  private val raw = Module(new DivSqrtRecF64ToRaw_mulAddZ31(0))
  private val mul = Module(new Mul54)
  private val round = Module(new RoundRawFNToRecFN(11, 53, flRoundOpt_sigMSBitAlwaysZero))

  raw.io.inValid := io.valid
  raw.io.sqrtOp := io.sqrt
  raw.io.a := recFNFromFN(11, 53, io.a)
  raw.io.b := recFNFromFN(11, 53, io.b)
  raw.io.roundingMode := io.mode
  io.ready := Mux(io.sqrt, raw.io.inReady_sqrt, raw.io.inReady_div)
  io.done := Mux(io.sqrt, raw.io.rawOutValid_sqrt, raw.io.rawOutValid_div)
  io.modeOut := raw.io.roundingModeOut

  mul.io.val_s0 := raw.io.usingMulAdd(0)
  mul.io.latch_a_s0 := raw.io.latchMulAddA_0
  mul.io.a_s0 := raw.io.mulAddA_0
  mul.io.latch_b_s0 := raw.io.latchMulAddB_0
  mul.io.b_s0 := raw.io.mulAddB_0
  mul.io.c_s2 := raw.io.mulAddC_2
  raw.io.mulAddResult_3 := mul.io.result_s3

  round.io.in := raw.io.rawOut
  round.io.invalidExc := raw.io.invalidExc
  round.io.infiniteExc := raw.io.infiniteExc
  round.io.roundingMode := raw.io.roundingModeOut
  round.io.detectTininess := tininess_afterRounding
  io.result := fNFromRecFN(11, 53, round.io.out)
  io.exceptions := round.io.exceptionFlags
}

class DivSqrtRawRoundingTester(c: DivSqrtRawRoundingHarness) extends PeekPokeTester(c) {
  private def bits(hex: String): BigInt = BigInt(hex, 16)
  private def until(signal: Bool, label: String): Unit = {
    var waited = 0
    while (peek(signal) == 0 && waited < 4096) { step(1); waited += 1 }
    assert(peek(signal) == 1, s"$label timed out")
  }

  private def evaluate(label: String, a: String, b: String, mode: Int,
                       result: String, flags: Int, sqrt: Boolean = false): Unit = {
    poke(c.io.sqrt, if (sqrt) 1 else 0)
    poke(c.io.a, bits(a))
    poke(c.io.b, bits(b))
    poke(c.io.mode, mode)
    poke(c.io.valid, 1)
    until(c.io.ready, label + " ready")
    step(1)
    poke(c.io.valid, 0)
    until(c.io.done, label + " done")
    expect(c.io.modeOut, mode, label + " rounding mode")
    expect(c.io.result, bits(result), label + " result")
    expect(c.io.exceptions, flags, label + " flags")
    step(1)
  }

  private val one = "3ff0000000000000"
  private val nextAboveOne = "3ff0000000000001"
  private val twoBelowOne = "3feffffffffffffe"
  private val nextBelowOne = "3fefffffffffffff"
  private val maxFinite = "7fefffffffffffff"
  private val minSubnormal = "0000000000000001"
  private val infinity = "7ff0000000000000"
  private val nearEven = 0
  private val towardZero = 1
  private val towardPositive = 3
  private val overflowAndInexact = 5

  poke(c.io.valid, 0)
  evaluate("div-overflow-rne", maxFinite, minSubnormal, nearEven, infinity, overflowAndInexact)
  evaluate("div-overflow-rtz", maxFinite, minSubnormal, towardZero, maxFinite, overflowAndInexact)
  evaluate("div-exact-rup", twoBelowOne, one, towardPositive, twoBelowOne, 0)
  // 1 / (1 + 2^-52) is just above 1 - 2^-52, which is itself exactly representable.
  evaluate("div-sticky-rne", one, nextAboveOne, nearEven, twoBelowOne, 1)
  evaluate("div-sticky-rup", one, nextAboveOne, towardPositive, nextBelowOne, 1)
  // sqrt(1 + 2^-52) lies strictly between 1 and the midpoint to its successor.
  evaluate("sqrt-sticky-rne", one, nextAboveOne, nearEven, one, 1, sqrt = true)
  evaluate("sqrt-sticky-rup", one, nextAboveOne, towardPositive, nextAboveOne, 1, sqrt = true)
}

class DivSqrtRawRoundingTest extends AnyFlatSpec with Matchers {
  behavior of "DivSqrtRecF64ToRaw_mulAddZ31"

  it should "preserve exponent range and discarded nonzero digits through the fixed rounder" in {
    Driver(() => new DivSqrtRawRoundingHarness)(c => new DivSqrtRawRoundingTester(c)) should be(true)
  }
}
