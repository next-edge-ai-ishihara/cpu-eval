# Implement `XArbiter`

Implement the complete `XArbiter` class. Preserve the class name and interface shown below.

Return only the complete `class XArbiter` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class XArbiter[T <: Data]( gen: T, in: Int,out: Int) extends Module {

  class XArbiterIO extends Bundle{
    val enq = Vec(in, Flipped(Decoupled(gen)))
    val deq = Vec(out, Decoupled(gen))
    val chosen = Output(Vec(out, UInt(log2Ceil(in).W) ))    
  }

  val io: XArbiterIO = IO(new XArbiterIO)
```

## Parent instantiation

```scala
    val mdl = Module(new XArbiter(new WriteBack_info(dw=64), in = 3 + aluNum + (mulNum max 1) + (fpuNum max 1), out = wbChn))
```

## Documentation

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
// ...
/** A concrete subclass of ReadyValidIO signaling that the user expects a
  * "decoupled" interface: 'valid' indicates that the producer has
  * put valid data in 'bits', and 'ready' indicates that the consumer is ready
  * to accept the data this cycle. No requirements are placed on the signaling
  * of ready or valid.
  * @param gen the type of data to be wrapped in DecoupledIO
  */
```
