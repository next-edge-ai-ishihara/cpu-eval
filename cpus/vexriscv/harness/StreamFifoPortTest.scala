package vexriscv

import spinal.core._
import spinal.core.sim._
import spinal.lib.StreamFifo

object StreamFifoPortTest {
  def check(mode: String, phase: String, port: String, actual: Int, expected: Int): Unit = {
    if (actual != expected) {
      println(s"STREAM_FIFO_PORT_MISMATCH mode=$mode phase=$phase port=$port actual=$actual expected=$expected")
      throw new AssertionError(port)
    }
  }

  private def bit(value: Boolean): Int = if (value) 1 else 0

  def main(args: Array[String]): Unit = {
    SimConfig.withVerilator.compile(StreamFifo(Bits(8 bits), 0)).doSim { dut =>
      for (valid <- 0 to 1; ready <- 0 to 1) {
        dut.io.flush #= false
        dut.io.push.valid #= (valid == 1)
        dut.io.push.payload #= 0x57
        dut.io.pop.ready #= (ready == 1)
        sleep(1)
        check("zero", "transfer", "push.ready", bit(dut.io.push.ready.toBoolean), ready)
        check("zero", "transfer", "pop.valid", bit(dut.io.pop.valid.toBoolean), valid)
        check("zero", "transfer", "occupancy", dut.io.occupancy.toInt, 0)
        check("zero", "transfer", "availability", dut.io.availability.toInt, 0)
        if (valid == 1) check("zero", "transfer", "pop.payload", dut.io.pop.payload.toInt, 0x57)
      }
    }

    for ((mode, depth, latency) <- Seq(("single", 1, 1), ("bypass", 2, 0), ("sync", 3, 2))) {
      SimConfig.withVerilator.compile(StreamFifo(Bits(8 bits), depth, latency)).doSim { dut =>
        val io = dut.io
        def tick(): Unit = {
          dut.clockDomain.waitSampling()
          sleep(1)
        }
        def count(phase: String, stored: Int): Unit = {
          check(mode, phase, "occupancy", io.occupancy.toInt, stored)
          check(mode, phase, "availability", io.availability.toInt, depth - stored)
        }
        def fill(base: Int): Unit = {
          for (index <- 0 until depth) {
            io.push.payload #= (base + index)
            io.push.valid #= true
            sleep(1)
            check(mode, "fill", "push.ready", bit(io.push.ready.toBoolean), 1)
            tick()
            count("stored", index + 1)
          }
          io.push.valid #= false
          sleep(1)
          check(mode, "full", "push.ready", bit(io.push.ready.toBoolean), 0)
        }
        def visible(phase: String, data: Int): Unit = {
          for (_ <- 0 until 3 if !io.pop.valid.toBoolean) tick()
          check(mode, phase, "pop.valid", bit(io.pop.valid.toBoolean), 1)
          check(mode, phase, "pop.payload", io.pop.payload.toInt, data)
        }

        io.flush #= false
        io.push.valid #= false
        io.push.payload #= 0
        io.pop.ready #= false
        dut.clockDomain.forkStimulus(10)
        tick()
        count("empty", 0)
        fill(0x31)
        visible("hold", 0x31)
        tick()
        visible("held", 0x31)
        io.flush #= true
        tick()
        io.flush #= false
        count("flushed", 0)
        check(mode, "flushed", "pop.valid", bit(io.pop.valid.toBoolean), 0)

        fill(0x71)
        for (index <- 0 until depth) {
          visible("drain", 0x71 + index)
          io.pop.ready #= true
          tick()
          io.pop.ready #= false
          sleep(1)
          count("removed", depth - index - 1)
        }
        check(mode, "drained", "pop.valid", bit(io.pop.valid.toBoolean), 0)
      }
    }
    println("STREAM_FIFO_PORT_PASS")
  }
}
