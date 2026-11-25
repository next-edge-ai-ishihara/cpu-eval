# Implement `RePort`

Implement the complete `RePort` class. Preserve the class name and interface shown below.

Return only the complete `class RePort` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class RePort[T<:Data]( dw: T, port: Int) extends Module{

  class RePortIO extends Bundle{
    val enq = Vec(port, Flipped(new DecoupledIO(dw)) )
    val deq  = Vec(port, new DecoupledIO(dw) )
  }

  val io: RePortIO = IO( new RePortIO)
```

## Parent instantiation

### src/main/scala/base/RePort.scala

```scala
object RePort{
  def apply[T <: Data]( enq: Vec[DecoupledIO[T]] ): Vec[DecoupledIO[T]] = {
    val mdl = Module(new RePort( chiselTypeOf(enq(0).bits), enq.length ))
    enq <> mdl.io.enq
    return mdl.io.deq
  }
}
```

### src/main/scala/base/MultiPortFifo.scala

```scala
      val fifo = Module(new MultiPortFifo( dw, aw, in, out, flow = false ))
      val rePortIn = Module(new RePort( dw, port = in))
      val zipPort = Module(new ZipPort( dw, port = in + out))

      rePortIn.io.enq <> io.enq
      rePortIn.io.deq <> fifo.io.enq
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
```

### src/main/scala/rift2Core/frontend/IF3.scala

```scala
  val reAlign = Wire(Vec(4, DecoupledIO(new IF3_Bundle)))
  val reAlignPreDecode = Wire( Vec( 4, new PreDecode_Bundle ) )
  val combPDT = Module(new RePort( new IF3_Bundle, 4))
// ...
  val if3_resp_fifo = Module(new MultiPortFifo( new IF3_Bundle, (if(!isMinArea) 4 else 2), 4, rnChn ))

  if3_resp_fifo.io.flush := io.if4Redirect.fire | io.flush
  if3_resp_fifo.io.enq <> combPDT.io.deq
  io.if3_resp <> if3_resp_fifo.io.deq
// ...
            reAlign(i).valid      := io.if3_req(i).fire & io.if3_req(i+1).fire & predictor_ready & ~pipeLineLock
            io.if3_req(i).ready   := reAlign(i).ready & predictor_ready & ~pipeLineLock & io.if3_req(i+1).valid
            io.if3_req(i+1).ready := reAlign(i).ready & predictor_ready & ~pipeLineLock
// ...
              reAlign(i).valid      := io.if3_req(i).fire & predictor_ready & ~pipeLineLock
              io.if3_req(i).ready   := reAlign(i).ready & predictor_ready & ~pipeLineLock
// ...
  reAlign <> combPDT.io.enq//waiting for overriding
// ...
        btb.io.req.valid := reAlign(i).valid & ~(io.flush | io.if4Redirect.fire)
        btb.io.req.bits.pc := reAlign(i).bits.pc
        reAlign(i).ready := combPDT.io.enq(i).ready & btb.io.req.ready
// ...
        bim.io.req.valid := reAlign(i).valid & ~(io.flush | io.if4Redirect.fire)
        bim.io.req.bits.pc := reAlign(i).bits.pc
        reAlign(i).ready := combPDT.io.enq(i).ready & bim.io.req.ready
// ...
        tage.io.req.valid      := reAlign(i).valid & ~(io.flush | io.if4Redirect.fire)
        tage.io.req.bits.pc    := reAlign(i).bits.pc
        tage.io.req.bits.ghist := ghist_active
        reAlign(i).ready       := combPDT.io.enq(i).ready & tage.io.req.ready
```

### src/main/scala/rift2Core/frontend/IF4.scala

```scala
  val bRePort = Module(new RePort( new Branch_FTarget_Bundle, port = rnChn) )
  val jRePort = Module(new RePort( new Jump_FTarget_Bundle,   port = rnChn) )
// ...
  bftq.io.enq <> bRePort.io.deq
  jftq.io.enq <> jRePort.io.deq
// ...
    bRePort.io.enq(i).valid := io.if4_req(i).fire & is_branch(i)
    jRePort.io.enq(i).valid := io.if4_req(i).fire & is_jalr(i)
// ...
  io.if4_req(0).ready := bRePort.io.enq(0).ready & jRePort.io.enq(0).ready & instr_fifo.io.enq(0).ready
// ...
    io.if4_req(i).ready := bRePort.io.enq(i).ready & jRePort.io.enq(i).ready & instr_fifo.io.enq(i).ready
```

## Dependency declarations

### src/main/scala/chisel3/util/Decoupled.scala

```scala
/** An I/O Bundle containing 'valid' and 'ready' signals that handshake
  * the transfer of data stored in the 'bits' subfield.
  * The base protocol implied by the directionality is that
  * the producer uses the interface as-is (outputs bits)
  * while the consumer uses the flipped interface (inputs bits).
  * The actual semantics of ready/valid are enforced via the use of concrete subclasses.
  * @param gen the type of data to be wrapped in Ready/Valid
  * @groupdesc Signals The actual hardware fields of the Bundle
  */
abstract class ReadyValidIO[+T <: Data](gen: T) extends Bundle {

  /** Indicates that the consumer is ready to accept the data this cycle
    * @group Signals
    */
  val ready = Input(Bool())

  /** Indicates that the producer has put valid data in 'bits'
    * @group Signals
    */
  val valid = Output(Bool())

  /** The data to be transferred when ready and valid are asserted at the same cycle
    * @group Signals
    */
  val bits = Output(gen)

  /** A stable typeName for this `ReadyValidIO` and any of its implementations
    * using the supplied `Data` generator's `typeName`
    */
  override def typeName = s"${this.getClass.getSimpleName}_${gen.typeName}"
}
// ...
/** A concrete subclass of ReadyValidIO signaling that the user expects a
  * "decoupled" interface: 'valid' indicates that the producer has
  * put valid data in 'bits', and 'ready' indicates that the consumer is ready
  * to accept the data this cycle. No requirements are placed on the signaling
  * of ready or valid.
  * @param gen the type of data to be wrapped in DecoupledIO
  */
class DecoupledIO[+T <: Data](gen: T) extends ReadyValidIO[T](gen) {
  // ...
}
```
