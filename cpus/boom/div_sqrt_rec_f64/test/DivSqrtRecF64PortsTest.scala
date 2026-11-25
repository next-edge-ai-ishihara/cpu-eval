package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import hardfloat.{DivSqrtRecF64, fNFromRecFN, recFNFromFN}
import org.scalatest.flatspec.AnyFlatSpec

class DivSqrtRecF64PortHarness extends Module {
  val io = IO(new Bundle {
    val inValid = Input(Bool())
    val sqrtOp = Input(Bool())
    val a = Input(UInt(64.W))
    val b = Input(UInt(64.W))
    val roundingMode = Input(UInt(3.W))
    val detectTininess = Input(UInt(1.W))
    val divReady = Output(Bool())
    val sqrtReady = Output(Bool())
    val divValid = Output(Bool())
    val sqrtValid = Output(Bool())
    val result = Output(UInt(64.W))
    val flags = Output(UInt(5.W))
  })

  private val target = Module(new DivSqrtRecF64)
  target.io.inValid := io.inValid
  target.io.sqrtOp := io.sqrtOp
  target.io.a := recFNFromFN(11, 53, io.a)
  target.io.b := recFNFromFN(11, 53, io.b)
  target.io.roundingMode := io.roundingMode
  target.io.detectTininess := io.detectTininess
  io.divReady := target.io.inReady_div
  io.sqrtReady := target.io.inReady_sqrt
  io.divValid := target.io.outValid_div
  io.sqrtValid := target.io.outValid_sqrt
  io.result := fNFromRecFN(11, 53, target.io.out)
  io.flags := target.io.exceptionFlags
}

class DivSqrtRecF64PortTester(c: DivSqrtRecF64PortHarness) extends PeekPokeTester(c) {
  case class Request(name: String, sqrt: Boolean, a: BigInt, b: BigInt,
                     result: Option[BigInt], flags: Int = 0, rounding: Int = 0)

  private def bits(value: String): BigInt = BigInt(value, 16)
  private val one = bits("3ff0000000000000")
  private val two = bits("4000000000000000")
  private val three = bits("4008000000000000")
  private val four = bits("4010000000000000")
  private val six = bits("4018000000000000")
  private val nine = bits("4022000000000000")
  private val negative = bits("bff0000000000000")
  private val negativeZero = bits("8000000000000000")
  private val infinity = bits("7ff0000000000000")
  private val fractionMask = bits("000fffffffffffff")
  private val exactDiv = Request("6/2", false, six, two, Some(three))
  private val exactSqrt = Request("sqrt(9)", true, negative, nine, Some(three))
  private val requests = Seq(
    exactDiv,
    exactDiv.copy(name = "8/2", a = bits("4020000000000000"), result = Some(four)),
    exactSqrt,
    exactSqrt.copy(name = "sqrt(4)", b = four, result = Some(two)),
    Request("1/3 nearest", false, one, three, Some(bits("3fd5555555555555")), flags = 1),
    Request("sqrt(-1)", true, nine, negative, None, flags = 16),
    Request("1/3 upward", false, one, three, Some(bits("3fd5555555555556")), flags = 1, rounding = 3),
    Request("sqrt(-0)", true, one, negativeZero, Some(negativeZero)),
    Request("1/0", false, one, 0, Some(infinity), flags = 8),
    Request("least subnormal / 2", false, 1, two, Some(0), flags = 3))

  private def drive(request: Request, valid: Boolean): Unit = {
    poke(c.io.inValid, if (valid) 1 else 0)
    poke(c.io.sqrtOp, if (request.sqrt) 1 else 0)
    poke(c.io.a, request.a)
    poke(c.io.b, request.b)
    poke(c.io.roundingMode, request.rounding)
    poke(c.io.detectTininess, 1)
  }

  drive(exactDiv, valid = false)
  step(2)
  println("DIV_SQRT_PORTS_START")

  private def resultValid: Boolean = peek(c.io.divValid) == 1 || peek(c.io.sqrtValid) == 1

  private def awaitSignal(context: String)(condition: => Boolean): Int = {
    var waited = 0
    while (!condition && waited < 4096) {
      step(1)
      waited += 1
    }
    assert(condition, s"$context: timed out")
    waited
  }

  for (request <- requests) {
    drive(request, valid = true)
    val ready = if (request.sqrt) c.io.sqrtReady else c.io.divReady
    awaitSignal(s"${request.name}: request not accepted")(peek(ready) == 1)
    assert(!resultValid, s"${request.name}: unexpected result before acceptance")
    step(1)
    drive(exactDiv, valid = false)

    val waited = awaitSignal(s"${request.name}: result missing")(resultValid)
    assert((peek(c.io.divValid) == 1) == !request.sqrt && (peek(c.io.sqrtValid) == 1) == request.sqrt,
      s"${request.name}: result valid asserted on the wrong operation port")
    val output = peek(c.io.result)
    val correct = request.result.fold((output & infinity) == infinity && (output & fractionMask) != 0)(_ == output)
    assert(correct, s"${request.name}: result was 0x${output.toString(16)}")
    assert(peek(c.io.flags) == request.flags, s"${request.name}: exception flags differ")
    println(s"DIV_SQRT_RESULT name=${request.name} latency=${waited + 2} flags=${request.flags}")
    step(1)
    assert(!resultValid, s"${request.name}: repeated result")
  }
  println(s"DIV_SQRT_PORTS_PASS completed=${requests.size}")
}

class DivSqrtRecF64PortsTest extends AnyFlatSpec {
  behavior of "DivSqrtRecF64 request and result ports"

  it should "return ordered division and square-root results with distinct valid signals" in {
    val arguments = Array("--backend-name", "verilator", "--target-dir", "test_run_dir/div-sqrt-rec-f64-ports")
    assert(Driver.execute(arguments, () => new DivSqrtRecF64PortHarness)(new DivSqrtRecF64PortTester(_)))
  }
}
