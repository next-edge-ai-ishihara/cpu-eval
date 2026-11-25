# Implement `Arbiter`

Implement the complete `Arbiter` class. Preserve the class name and interface shown below.

Return only the complete `class Arbiter` definition in a single Scala code block, with no text outside the block.

## Class declaration

### src/main/scala/chisel3/util/Arbiter.scala

```scala
/** Hardware module that is used to sequence n producers into 1 consumer.
  * Priority is given to lower producer.
  *
  * @param gen data type
  * @param n number of inputs
  *
  * @example {{{
  * val arb = Module(new Arbiter(UInt(), 2))
  * arb.io.in(0) <> producer0.io.out
  * arb.io.in(1) <> producer1.io.out
  * consumer.io.in <> arb.io.out
  * }}}
  */
class Arbiter[T <: Data](val gen: T, val n: Int) extends Module {

  /** Give this Arbiter a default, stable desired name using the supplied `Data`
    * generator's `typeName` and input count parameter
    */
  override def desiredName = s"Arbiter${n}_${gen.typeName}"

  val io = IO(new ArbiterIO(gen, n))
```

## Parent instantiation

### src/main/scala/rift2Core/backend/LSU/Lsu.scala

```scala
  val ls_arb = Module(new Arbiter(new Lsu_iss_info, 2))
// ...
  val lu_wb_arb = Module(new Arbiter(new Dcache_Deq_Bundle, bk+2))
// ...
  val irtn_arb = Module(new Arbiter( new WriteBack_info(dw=64), 4))
  val frtn_arb = Module(new Arbiter( new WriteBack_info(dw=65), 2))
// ...
    val acquireArb  = Module(new Arbiter(new TLBundleA(dEdge(0).bundle), n = bk))
    val grantAckArb = Module(new Arbiter(new TLBundleE(dEdge(0).bundle), n = bk))
    val releaseArb  = Module(new Arbiter(new TLBundleC(dEdge(0).bundle), n = bk))
```

### src/main/scala/rift2Core/backend/LSU/Dcache.scala

```scala
  val op_arb = Module(new Arbiter( new Dcache_Enq_Bundle, 2))
  val rd_arb = Module(new Arbiter( new Dcache_Enq_Bundle, 3))
// ...
  reload_fifo.io.deq <> op_arb.io.in(0)
  io.enq.ready := op_arb.io.in(1).ready & sbEnqReady
  op_arb.io.in(1).valid := io.enq.fire
  op_arb.io.in(1).bits  := io.enq.bits
  op_arb.io.in(1).bits.chkIdx := sbIdx //override
  op_arb.io.out <> lsEntry.io.enq 
```

### src/main/scala/rift2Core/backend/Mul.scala

```scala
  val iwbArb = Module(new Arbiter(new WriteBack_info(dw=64), 2))
// ...
  val divRtnArb = Module(new Arbiter(gen = new WriteBack_info(dw=64), n = 2))
```

### src/main/scala/rift2Core/privilege/MMU.scala

```scala
  val ptwGetArb  = Module(new Arbiter(new TLBundleA(edge.bundle), n = 2))
```

## Dependency declarations

### src/main/scala/chisel3/util/Arbiter.scala

```scala
/** IO bundle definition for an Arbiter, which takes some number of ready-valid inputs and outputs
  * (selects) at most one.
  * @groupdesc Signals The actual hardware fields of the Bundle
  *
  * @param gen data type
  * @param n number of inputs
  */
class ArbiterIO[T <: Data](private val gen: T, val n: Int) extends Bundle {
  // See github.com/freechipsproject/chisel3/issues/765 for why gen is a private val and proposed replacement APIs.

  /** Input data, one per potential sender
    *
    * @group Signals
    */
  val in = Flipped(Vec(n, Decoupled(gen)))

  /** Output data after arbitration
    *
    * @group Signals
    */
  val out = Decoupled(gen)

  /** Index indicating which sender was chosen as output
    *
    * @group Signals
    */
  val chosen = Output(UInt(log2Ceil(n).W))
}
```

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

  /** Applies the supplied functor to the bits of this interface, returning a new
    * typed DecoupledIO interface.
    * @param f The function to apply to this DecoupledIO's 'bits' with return type B
    * @return a new DecoupledIO of type B
    */
  def map[B <: Data](f: T => B): DecoupledIO[B] = {
    val _map_bits = f(bits)
    val _map = Wire(Decoupled(chiselTypeOf(_map_bits)))
    _map.bits := _map_bits
    _map.valid := valid
    ready := _map.ready
    _map
  }
}
```
