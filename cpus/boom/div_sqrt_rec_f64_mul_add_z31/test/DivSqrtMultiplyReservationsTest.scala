package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import hardfloat.{DivSqrtRecF64_mulAddZ31, Mul54, fNFromRecFN, recFNFromFN}
import org.scalatest.flatspec.AnyFlatSpec

class DivSqrtMultiplyReservationsHarness extends Module {
  val io = IO(new Bundle {
    val valid = Input(Bool())
    val squareRoot = Input(Bool())
    val a = Input(UInt(64.W))
    val b = Input(UInt(64.W))
    val divisionReady = Output(Bool())
    val rootReady = Output(Bool())
    val divisionValid = Output(Bool())
    val rootValid = Output(Bool())
    val reservation = Output(UInt(4.W))
    val latchA = Output(Bool())
    val latchB = Output(Bool())
    val result = Output(UInt(64.W))
    val flags = Output(UInt(5.W))
  })
  private val divide = Module(new DivSqrtRecF64_mulAddZ31(0))
  private val multiply = Module(new Mul54)
  divide.io.inValid := io.valid
  divide.io.sqrtOp := io.squareRoot
  divide.io.a := recFNFromFN(11, 53, io.a)
  divide.io.b := recFNFromFN(11, 53, io.b)
  divide.io.roundingMode := 0.U
  divide.io.detectTininess := 1.U
  io.divisionReady := divide.io.inReady_div
  io.rootReady := divide.io.inReady_sqrt
  io.divisionValid := divide.io.outValid_div
  io.rootValid := divide.io.outValid_sqrt
  io.reservation := divide.io.usingMulAdd
  io.latchA := divide.io.latchMulAddA_0
  io.latchB := divide.io.latchMulAddB_0
  io.result := fNFromRecFN(11, 53, divide.io.out)
  io.flags := divide.io.exceptionFlags

  multiply.io.val_s0 := divide.io.usingMulAdd(0)
  multiply.io.latch_a_s0 := divide.io.latchMulAddA_0
  multiply.io.a_s0 := divide.io.mulAddA_0
  multiply.io.latch_b_s0 := divide.io.latchMulAddB_0
  multiply.io.b_s0 := divide.io.mulAddB_0
  multiply.io.c_s2 := divide.io.mulAddC_2
  divide.io.mulAddResult_3 := multiply.io.result_s3
}

class DivSqrtMultiplyReservationsTester(c: DivSqrtMultiplyReservationsHarness) extends PeekPokeTester(c) {
  private var comparisons = 0
  private var mismatches = 0

  private def compare(observed: BigInt, expected: BigInt, field: String): Unit = {
    comparisons += 1
    if (observed != expected) {
      mismatches += 1
      println(s"DIV_SQRT_RESERVATION_MISMATCH $field expected=$expected observed=$observed")
    }
  }

  private def observe(label: String, root: Boolean, a: String, b: String, answer: String,
                      flags: Int, needsMultiplier: Boolean): Unit = {
    val ready = if (root) c.io.rootReady else c.io.divisionReady
    poke(c.io.squareRoot, if (root) 1 else 0)
    poke(c.io.a, BigInt(a, 16))
    poke(c.io.b, BigInt(b, 16))
    var waited = 0
    while (peek(ready) == 0 && waited < 4096) { step(1); waited += 1 }
    if (peek(ready) == 0) {
      compare(0, 1, s"$label request accepted")
      return
    }
    poke(c.io.valid, 1)
    step(1)
    poke(c.io.valid, 0)

    val reservations = scala.collection.mutable.Queue.empty[(Int, Int)]
    val trace = scala.collection.mutable.ArrayBuffer.empty[Int]
    var cycle = 0
    var usedMultiplier = false
    var completed = -1
    while ((completed < 0 && cycle < 4096) || (completed >= 0 && cycle <= completed + 3)) {
      val word = peek(c.io.reservation).toInt
      for ((earlier, prediction) <- reservations) {
        val offset = cycle - earlier
        compare((prediction >> offset) & 1, word & 1, s"$label cycle $earlier reservation $offset cycles ahead")
      }
      reservations.enqueue((cycle, word))
      if (reservations.size > 3) reservations.dequeue()
      if (trace.size < 128) trace += word
      usedMultiplier = usedMultiplier || ((word & 1) != 0)
      if ((word & 1) == 0) {
        compare(peek(c.io.latchA), 0, s"$label cycle $cycle factor A while idle")
        compare(peek(c.io.latchB), 0, s"$label cycle $cycle factor B while idle")
      }
      val division = peek(c.io.divisionValid)
      val squareRoot = peek(c.io.rootValid)
      if (division != 0 || squareRoot != 0) {
        compare(if (completed < 0) 0 else 1, 0, s"$label repeated result at cycle $cycle")
        if (completed < 0) completed = cycle
        compare(division, if (root) 0 else 1, s"$label division result valid")
        compare(squareRoot, if (root) 1 else 0, s"$label square-root result valid")
        compare(peek(c.io.result), BigInt(answer, 16), s"$label IEEE binary64 result")
        compare(peek(c.io.flags), flags, s"$label exception flags")
      }
      step(1)
      cycle += 1
    }
    if (completed < 0) compare(0, 1, s"$label result produced")
    println(s"DIV_SQRT_RESERVATION_LATENCY $label ${completed + 2}")
    if (needsMultiplier)
      compare(if (usedMultiplier) 1 else 0, 1, s"$label uses the external multiplier")
    println(s"DIV_SQRT_RESERVATION_TRACE $label ${trace.mkString(",")}")
  }

  poke(c.io.valid, 0)
  poke(c.io.squareRoot, 0)
  poke(c.io.a, 0)
  poke(c.io.b, 0)
  step(4)
  println("DIV_SQRT_RESERVATION_OBSERVATION_STARTED")
  observe("10/3", false, "4024000000000000", "4008000000000000", "400aaaaaaaaaaaab", 1, true)
  observe("sqrt(2)", true, "bff0000000000000", "4000000000000000", "3ff6a09e667f3bcd", 1, true)
  observe("1/0", false, "3ff0000000000000", "0000000000000000", "7ff0000000000000", 8, false)
  println(s"DIV_SQRT_RESERVATION_COMPARISONS $comparisons")
  assert(mismatches == 0, s"$mismatches observed differences")
}

class DivSqrtMultiplyReservationsTest extends AnyFlatSpec {
  "DivSqrtRecF64_mulAddZ31" should "announce scheduled multiplier uses and return the rounded result" in {
    assert(Driver.execute(Array("--backend-name", "verilator", "--target-dir",
      "test_run_dir/div-sqrt-multiply-reservations"), () => new DivSqrtMultiplyReservationsHarness)(
      dut => new DivSqrtMultiplyReservationsTester(dut)))
  }
}
