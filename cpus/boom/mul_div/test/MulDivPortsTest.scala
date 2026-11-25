package boom.tests

import chisel3.{Bits, Bool}
import chisel3.iotesters.{Driver, PeekPokeTester}
import freechips.rocketchip.rocket.{MulDiv, MulDivParams}
import freechips.rocketchip.rocket.ALU.FN_DIV
import org.scalatest.flatspec.AnyFlatSpec

class MulDivPortsTester(dut: MulDiv) extends PeekPokeTester(dut) {
  private def waitFor(signal: Bool, name: String): Unit = {
    var remaining = 1024
    while (peek(signal) == 0 && remaining > 0) {
      step(1)
      remaining -= 1
    }
    if (peek(signal) == 0) {
      println(s"MULDIV_PORT_RESOURCE_LIMIT waiting for $name")
      throw new AssertionError(s"Timed out waiting for $name")
    }
  }

  private def check(signal: Bits, value: Int, why: String): Unit =
    assert(expect(signal, value, why), why)

  private def request(dividend: Int, divisor: Int): Unit = {
    waitFor(dut.io.req.ready, "request acceptance")
    poke(dut.io.req.bits.in1, dividend)
    poke(dut.io.req.bits.in2, divisor)
    poke(dut.io.req.valid, 1)
    step(1)
    poke(dut.io.req.valid, 0)
  }

  private def answer(quotient: Int): Unit = {
    waitFor(dut.io.resp.valid, s"quotient $quotient")
    check(dut.io.resp.bits.data, quotient, "result belongs to the accepted request")
  }

  private def acceptResult(): Unit = {
    poke(dut.io.resp.ready, 1)
    step(1)
    poke(dut.io.resp.ready, 0)
    check(dut.io.resp.valid, 0, "one response per request")
  }

  private def cancel(label: String): Unit = {
    poke(dut.io.kill, 1)
    step(1)
    poke(dut.io.kill, 0)
    println(s"MULDIV_CANCEL $label valid=${peek(dut.io.resp.valid)}")
    check(dut.io.resp.valid, 0, s"$label is discarded after the cancellation edge")
  }

  poke(dut.io.req.valid, 0)
  poke(dut.io.req.bits.fn, FN_DIV.litValue)
  poke(dut.io.req.bits.dw, 1)
  poke(dut.io.req.bits.in1, 0)
  poke(dut.io.req.bits.in2, 0)
  poke(dut.io.req.bits.tag, 0)
  poke(dut.io.kill, 0)
  poke(dut.io.resp.ready, 0)
  step(1)
  println("MULDIV_PORT_OBSERVATIONS_STARTED")

  request(117, 7)
  poke(dut.io.req.bits.in1, 312)
  poke(dut.io.req.bits.in2, 8)
  answer(16)
  step(3)
  check(dut.io.resp.valid, 1, "response remains valid while stalled")
  check(dut.io.resp.bits.data, 16, "response data remains stable while stalled")
  check(dut.io.req.ready, 0, "a pending result occupies the divider while stalled")
  acceptResult()

  request(103, 9)
  cancel("accepted request")
  request(45, 5)
  answer(9)
  acceptResult()

  request(84, 7)
  answer(12)
  cancel("stalled response")
  request(32, 8)
  answer(4)
  acceptResult()
}

class MulDivPortsTest extends AnyFlatSpec {
  it should "hold an accepted result and cancel both accepted work and stalled results" in {
    assert(Driver(() => new MulDiv(MulDivParams(divEarlyOut = true), 64))(dut => new MulDivPortsTester(dut)))
  }
}
