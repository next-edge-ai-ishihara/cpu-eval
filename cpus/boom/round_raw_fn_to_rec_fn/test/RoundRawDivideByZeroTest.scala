// SPDX-License-Identifier: Apache-2.0
package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import hardfloat.RoundRawFNToRecFN
import hardfloat.consts.{flRoundOpt_sigMSBitAlwaysZero, round_near_even, tininess_afterRounding}
import org.scalatest.flatspec.AnyFlatSpec

class RoundRawDivideByZeroHarness extends Module {
  val io = IO(new Bundle {
    val divideByZero = Input(Bool())
    val flags = Output(UInt(5.W))
  })
  private val rounder = Module(new RoundRawFNToRecFN(11, 53, flRoundOpt_sigMSBitAlwaysZero))
  rounder.io.invalidExc := false.B
  rounder.io.infiniteExc := io.divideByZero
  rounder.io.in.isNaN := false.B
  rounder.io.in.isInf := true.B
  rounder.io.in.isZero := false.B
  rounder.io.in.sign := true.B
  rounder.io.in.sExp := 0.S
  rounder.io.in.sig := (BigInt(1) << 54).U
  rounder.io.roundingMode := round_near_even
  rounder.io.detectTininess := tininess_afterRounding
  io.flags := rounder.io.exceptionFlags
}

class RoundRawDivideByZeroTester(dut: RoundRawDivideByZeroHarness) extends PeekPokeTester(dut) {
  for ((divideByZero, flags) <- Seq(0 -> 0, 1 -> 8)) {
    poke(dut.io.divideByZero, divideByZero)
    println(s"RoundRaw divide-by-zero input=$divideByZero flags=${peek(dut.io.flags)} expected=$flags")
    if (!expect(dut.io.flags, flags)) println("ROUND_RAW_EXCEPTION_FLAGS_MISMATCH")
  }
}

class RoundRawDivideByZeroTest extends AnyFlatSpec {
  "RoundRawFNToRecFN" should "distinguish ordinary infinity from divide by zero" in {
    assert(Driver.execute(Array("--backend-name", "firrtl"), () => new RoundRawDivideByZeroHarness)(
      dut => new RoundRawDivideByZeroTester(dut)))
  }
}
