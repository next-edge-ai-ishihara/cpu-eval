# Implement `ZipPort`

Implement the complete `ZipPort` class. Preserve the class name and interface shown below.

Return only the complete `class ZipPort` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class ZipPort[T<:Data]( dw: T, port: Int) extends Module{

  class ZipPortIO extends Bundle{
    val enq = Vec(port, Flipped(new DecoupledIO(dw)) )
    val deq  = Vec(port, new DecoupledIO(dw) )    
  }
  val io: ZipPortIO = IO( new ZipPortIO)
```

## Parent instantiation

### src/main/scala/base/MultiPortFifo.scala

```scala
class MultiPortFifo[T<:Data]( dw: T, aw: Int, in: Int, out: Int, flow: Boolean = false )(implicit p: Parameters) extends RiftModule{
  class MultiPortFifoIO extends Bundle{
    val enq = Vec(in, Flipped(new DecoupledIO(dw)) )
    val deq  = Vec(out, new DecoupledIO(dw) )

    val flush = Input(Bool())
  }
  val io: MultiPortFifoIO = IO(new MultiPortFifoIO)
// ...
    } else { //flow == true

      val fifo = Module(new MultiPortFifo( dw, aw, in, out, flow = false ))
      val rePortIn = Module(new RePort( dw, port = in))
      val zipPort = Module(new ZipPort( dw, port = in + out))

      rePortIn.io.enq <> io.enq
      rePortIn.io.deq <> fifo.io.enq

      for ( i <- 0 until out  ) {
        zipPort.io.enq(i) <> fifo.io.deq(i)
      }

      for ( i <- out until out+in ) {
        zipPort.io.enq(i).valid := io.enq(i-out).valid
        zipPort.io.enq(i).bits  := io.enq(i-out).bits
      }


      for ( i <- 0 until out ) {
        zipPort.io.deq(i) <> io.deq(i)
      }
      for ( i <- out until out+in  ) {
        zipPort.io.deq(i).ready := false.B
      }

      fifo.io.flush := io.flush

      for ( i <- 0 until in ) {
        when( zipPort.io.enq(out+i).fire ) {
          rePortIn.io.enq(i).valid := false.B
          rePortIn.io.enq(i).bits  := 0.U.asTypeOf(dw)
        }
      }
    }
// ...
    for ( i <- 0 until in; j <- 0 until in )
      assert( !(io.enq(i).valid === true.B && io.enq(j).valid === false.B && i.U >= j.U), "Assert Fail! in port illegal")

    for ( i <- 0 until out; j <- 0 until out )
      assert( !(io.deq(i).valid === true.B && io.deq(j).valid === false.B && i.U >= j.U), "Assert Fail! out port illegal")

    for ( i <- 0 until in ) {
      when( io.enq(i).fire ) {
        for ( j <- 0 until i ) {
          assert( io.enq(j).fire, "Assert Failed, illegal multi-port-fifo behavior" )
        }
      }
    }

    for ( i <- 0 until out ) {
      when( io.deq(i).fire ) {
        for ( j <- 0 until i ) {
          assert( io.deq(j).fire, "Assert Failed, illegal multi-port-fifo behavior" )
        }
      }
    }
```
