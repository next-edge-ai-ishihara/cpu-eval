// SPDX-License-Identifier: Apache-2.0
package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import hardfloat.{MulAddRecFN, fNFromRecFN, recFNFromFN}
import org.scalatest.flatspec.AnyFlatSpec

class PostMulInvalidHarness(expWidth: Int, sigWidth: Int) extends Module {
  private val width = expWidth + sigWidth
  val io = IO(new Bundle {
    val a = Input(UInt(width.W))
    val b = Input(UInt(width.W))
    val c = Input(UInt(width.W))
    val result = Output(UInt(width.W))
    val flags = Output(UInt(5.W))
  })
  val operation = Module(new MulAddRecFN(expWidth, sigWidth))
  operation.io.op := 0.U
  operation.io.a := recFNFromFN(expWidth, sigWidth, io.a)
  operation.io.b := recFNFromFN(expWidth, sigWidth, io.b)
  operation.io.c := recFNFromFN(expWidth, sigWidth, io.c)
  operation.io.roundingMode := hardfloat.consts.round_near_even
  operation.io.detectTininess := hardfloat.consts.tininess_afterRounding
  io.result := fNFromRecFN(expWidth, sigWidth, operation.io.out)
  io.flags := operation.io.exceptionFlags
}

class PostMulInvalidTester(dut: PostMulInvalidHarness, infinity: BigInt, one: BigInt,
                           two: BigInt, qNaN: BigInt) extends PeekPokeTester(dut) {
  println("POST_MUL_INVALID_START")
  private def check(a: BigInt, b: BigInt, flags: Int, label: String): Unit = {
    poke(dut.io.a, a)
    poke(dut.io.b, b)
    poke(dut.io.c, qNaN)
    expect(dut.io.result, qNaN, s"$label returns the canonical quiet NaN")
    expect(dut.io.flags, flags, s"$label computes the invalid flag independently of the NaN result")
    step(1)
  }
  check(infinity, 0, 16, "infinity times zero with a quiet NaN addend")
  check(0, infinity, 16, "zero times infinity with a quiet NaN addend")
  check(one, two, 0, "finite product with a quiet NaN addend")
  println("POST_MUL_INVALID_OBSERVED")
}

class PostMulInvalidTest extends AnyFlatSpec {
  private def check(expWidth: Int, sigWidth: Int, infinity: String, one: String,
                    two: String, qNaN: String): Unit = {
    assert(Driver.execute(Array("--backend-name", "treadle", "--target-dir",
      sys.env.getOrElse("CPU_EVAL_DIRECTED_TARGET", "test_run_dir") + s"/$sigWidth"),
      () => new PostMulInvalidHarness(expWidth, sigWidth))(
      dut => new PostMulInvalidTester(dut, BigInt(infinity, 16), BigInt(one, 16),
        BigInt(two, 16), BigInt(qNaN, 16))))
  }

  "MulAddRecFNToRaw_postMul" should "preserve the invalid flag with a single-precision quiet NaN addend" in {
    check(8, 24, "7f800000", "3f800000", "40000000", "7fc00000")
  }
  it should "preserve the invalid flag with a double-precision quiet NaN addend" in {
    check(11, 53, "7ff0000000000000", "3ff0000000000000", "4000000000000000", "7ff8000000000000")
  }
}
