package vexriscv

import spinal.core._
import spinal.core.sim._
import spinal.lib.StreamFifoLowLatency

object FifoPortTest {
  def check(latency: Int, phase: String, port: String, actual: Int, expected: Int): Unit = {
    if (actual != expected) {
      println(s"FIFO_PORT_MISMATCH latency=$latency phase=$phase port=$port actual=$actual expected=$expected")
      throw new AssertionError(port)
    }
  }

  def main(args: Array[String]): Unit = {
    for ((latency, depth) <- Seq((0, 2), (1, 4))) {
      SimConfig.withVerilator.compile(new StreamFifoLowLatency(Bits(8 bits), depth, latency)).doSim { dut =>
        val io = dut.io
        def sample(phase: String, stored: Int, visible: Option[Int]): Unit = {
          sleep(1)
          check(latency, phase, "occupancy", io.occupancy.toInt, stored)
          check(latency, phase, "availability", io.availability.toInt, depth - stored)
          check(latency, phase, "pop.valid", if (io.pop.valid.toBoolean) 1 else 0, if (visible.isDefined) 1 else 0)
          visible.foreach(data => check(latency, phase, "pop.payload", io.pop.payload.toInt, data))
        }
        io.flush #= false
        io.push.valid #= false
        io.push.payload #= 0
        io.pop.ready #= false
        dut.clockDomain.forkStimulus(10)
        dut.clockDomain.waitSampling()
        sample("empty", 0, None)
        io.push.valid #= true
        io.push.payload #= 0x35
        sample("first-push", 0, if (latency == 0) Some(0x35) else None)
        check(latency, "first-push", "push.ready", if (io.push.ready.toBoolean) 1 else 0, 1)
        dut.clockDomain.waitSampling()
        io.push.payload #= 0x91
        sample("held", 1, Some(0x35))
        check(latency, "second-push", "push.ready", if (io.push.ready.toBoolean) 1 else 0, 1)
        dut.clockDomain.waitSampling()
        io.push.valid #= false
        sample("two-stored", 2, Some(0x35))
        io.flush #= true
        dut.clockDomain.waitSampling()
        io.flush #= false
        sample("flushed", 0, None)
        io.push.valid #= true
        io.push.payload #= 0x7b
        sample("refill", 0, if (latency == 0) Some(0x7b) else None)
        dut.clockDomain.waitSampling()
        io.push.valid #= false
        io.pop.ready #= true
        sample("new-head", 1, Some(0x7b))
        dut.clockDomain.waitSampling()
        sample("drained", 0, None)
      }
    }
    for (latency <- 0 to 1) {
      println(s"FIFO_ZERO_DEPTH latency=$latency")
      SimConfig.withVerilator.compile(new StreamFifoLowLatency(Bits(8 bits), 0, latency)).doSim { dut =>
        for (valid <- 0 to 1; ready <- 0 to 1) {
          dut.io.flush #= false
          dut.io.push.valid #= (valid == 1)
          dut.io.push.payload #= 0x57
          dut.io.pop.ready #= (ready == 1)
          sleep(1)
          check(latency, "zero-depth", "push.ready", if (dut.io.push.ready.toBoolean) 1 else 0, ready)
          check(latency, "zero-depth", "pop.valid", if (dut.io.pop.valid.toBoolean) 1 else 0, valid)
          if (valid == 1) check(latency, "zero-depth", "pop.payload", dut.io.pop.payload.toInt, 0x57)
        }
      }
    }
    println("FIFO_PORT_PASS")
  }
}
