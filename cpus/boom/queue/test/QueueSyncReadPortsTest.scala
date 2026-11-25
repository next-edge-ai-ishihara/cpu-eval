package boom.tests

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import chisel3.util.Queue
import org.scalatest.flatspec.AnyFlatSpec

class QueueSyncReadPortsTester(dut: Queue[UInt]) extends PeekPokeTester(dut) {
  private def observe(port: UInt, expected: Int, label: String): Unit = {
    val actual = peek(port)
    println(s"CPU_EVAL_QUEUE_SYNC_OBSERVATION $label expected=$expected actual=$actual")
    if (actual != expected) {
      println(s"CPU_EVAL_QUEUE_SYNC_MISMATCH $label")
    }
    expect(port, expected, label)
  }

  val data = Seq(0x21, 0x4a, 0x67)
  poke(dut.io.enq.valid, 0)
  poke(dut.io.enq.bits, 0)
  poke(dut.io.deq.ready, 0)
  step(1)

  for (element <- data) {
    poke(dut.io.enq.valid, 1)
    poke(dut.io.enq.bits, element)
    observe(dut.io.enq.ready, 1, "enqueue")
    step(1)
  }
  // Settle the first synchronous read after all writes have finished.
  poke(dut.io.enq.valid, 0)
  step(1)
  poke(dut.io.deq.ready, 1)
  for ((element, index) <- data.zipWithIndex) {
    observe(dut.io.deq.valid, 1, s"valid-$index")
    observe(dut.io.deq.bits, element, s"head-$index")
    step(1)
  }
  observe(dut.io.deq.valid, 0, "empty")
}

class QueueSyncReadPortsTest extends AnyFlatSpec {
  it should "return the next stored item immediately after a dequeue with synchronous memory" in {
    val directory = sys.props("cpu.eval.queue.test.target")
    assert(Driver.execute(Array("--backend-name", "verilator", "--target-dir", directory),
      () => new Queue(UInt(8.W), entries = 3, useSyncReadMem = true))(dut => new QueueSyncReadPortsTester(dut)))
  }
}
