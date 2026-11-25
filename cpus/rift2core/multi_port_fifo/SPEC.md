# Implement `MultiPortFifo`

Implement the complete `MultiPortFifo` class. Preserve the class name and interface shown below.

Return only the complete `class MultiPortFifo` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
//dw:data type aw:address width, in: input port num, out: output port num 

class MultiPortFifo[T<:Data]( dw: T, aw: Int, in: Int, out: Int, flow: Boolean = false )(implicit p: Parameters) extends RiftModule{
  class MultiPortFifoIO extends Bundle{
    val enq = Vec(in, Flipped(new DecoupledIO(dw)) )
    val deq  = Vec(out, new DecoupledIO(dw) )

    val flush = Input(Bool())
  }
  val io: MultiPortFifoIO = IO(new MultiPortFifoIO)
```

## Parent instantiation

### src/main/scala/base/ZipQueue.scala

```scala
    val mdl = Module(new MultiPortFifo( dw, aw, in, out ) with chisel3.util.experimental.InlineInstance)
```

### src/main/scala/rift2Core/backend/Rename.scala

```scala
  val rnRspFifo = Module(new MultiPortFifo(new Dpt_info, aw = (if(!isMinArea) 4 else 1 ), rnChn, rnChn))
// ...
    val mdl = Module(new MultiPortFifo(new Info_reorder_i, aw = (if(!isMinArea) 4 else 1 ), rnChn, cmChn))
```

### src/main/scala/rift2Core/frontend/IF2.scala

```scala
  val ibuf = Module(new MultiPortFifo( new IF2_Bundle, aw= (if (!isMinArea) 6 else log2Ceil(2*ftChn)), in=ftChn, out=4 ) )
// ...
  ibuf.io.enq(0).valid :=
    (~kill_trans & io.mmu_if.valid & icache_state_qout =/= 0.U & icache_state_dnxt === 0.U & ibuf.io.enq(ftChn-1).ready & ( io.mmu_if.bits.paddr((log2Ceil(ftChn*16/8)-1),1) <= (ftChn-1).U ) & io.if2_req.bits.isActive(0)) |
    (~kill_trans & io.mmu_if.valid & io.mmu_if.bits.is_fault & ~fault_lock)

  for ( i <- 1 until ftChn ) {
    ibuf.io.enq(i).valid := ~kill_trans & io.mmu_if.valid & icache_state_qout =/= 0.U & icache_state_dnxt === 0.U & ibuf.io.enq(ftChn-1).ready & ( io.mmu_if.bits.paddr((log2Ceil(ftChn*16/8)-1),1) <= (ftChn-1-i).U )  & io.if2_req.bits.isActive(i)
  }
```

### src/main/scala/rift2Core/frontend/IF3.scala

```scala
  val btbFifo =  Module(new MultiPortFifo( new BTBResp_Bundle, aw = (if(!isMinArea) 4 else 1), in = 1, out = rnChn, flow = true ) )
  val bimFifo =  Module(new MultiPortFifo( new BIMResp_Bundle, aw = (if(!isMinArea) 4 else 1), in = 1, out = rnChn, flow = true ) )
  val tageFifo = Module(new MultiPortFifo( Vec(6, new TageTableResp_Bundle ), aw = (if(!isMinArea) 4 else 1), in = 1, out = rnChn, flow = true ) )
// ...
  val if3_resp_fifo = Module(new MultiPortFifo( new IF3_Bundle, (if(!isMinArea) 4 else 2), 4, rnChn ))
```

### src/main/scala/rift2Core/frontend/IF4.scala

```scala
  val instr_fifo = Module(new MultiPortFifo( new IF4_Bundle, (if(!isMinArea) 4 else 1), rnChn, rnChn ))
  val bftq = Module(new MultiPortFifo( dw = new Branch_FTarget_Bundle, (if(!isMinArea) 4 else 1), rnChn, 1 ))
  val jftq = Module(new MultiPortFifo( dw = new Jump_FTarget_Bundle,   (if(!isMinArea) 4 else 1), rnChn, 1 ))
```

### src/main/scala/rift2Core/vector/VecPreRename.scala

```scala
  val vecSplitFifo = Module(new MultiPortFifo( new IF4_Bundle, aw = 3, 8, rnChn ) )
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
// ...
/** An I/O Bundle for Queues
  * @param gen The type of data to queue
  * @param entries The max number of entries in the queue.
  * @param hasFlush A boolean for whether the generated Queue is flushable
  * @groupdesc Signals The hardware fields of the Bundle
  */
class QueueIO[T <: Data](
  private val gen: T,
  val entries:     Int,
  val hasFlush:    Boolean = false)
    extends Bundle { // See github.com/freechipsproject/chisel3/issues/765 for why gen is a private val and proposed replacement APIs.

  /* These may look inverted, because the names (enq/deq) are from the perspective of the client,
   *  but internally, the queue implementation itself sits on the other side
   *  of the interface so uses the flipped instance.
   */
  /** I/O to enqueue data (client is producer, and Queue object is consumer), is [[chisel3.util.DecoupledIO]] flipped.
    * @group Signals
    */
  val enq = Flipped(EnqIO(gen))

  /** I/O to dequeue data (client is consumer and Queue object is producer), is [[chisel3.util.DecoupledIO]]
    * @group Signals
    */
  val deq = Flipped(DeqIO(gen))

  /** The current amount of data in the queue
    * @group Signals
    */
  val count = Output(UInt(log2Ceil(entries + 1).W))

  /** When asserted, reset the enqueue and dequeue pointers, effectively flushing the queue (Optional IO for a flushable Queue)
    * @group Signals
    */
  val flush = if (hasFlush) Some(Input(Bool())) else None

}

/** A hardware module implementing a Queue
  * @param gen The type of data to queue
  * @param entries The max number of entries in the queue
  * @param pipe True if a single entry queue can run at full throughput (like a pipeline). The ''ready'' signals are
  * combinationally coupled.
  * @param flow True if the inputs can be consumed on the same cycle (the inputs "flow" through the queue immediately).
  * The ''valid'' signals are coupled.
  * @param useSyncReadMem True uses SyncReadMem instead of Mem as an internal memory element.
  * @param hasFlush True if generated queue requires a flush feature
  * @example {{{
  * val q = Module(new Queue(UInt(), 16))
  * q.io.enq <> producer.io.out
  * consumer.io.in <> q.io.deq
  * }}}
  */
class Queue[T <: Data](
  val gen:            T,
  val entries:        Int,
  val pipe:           Boolean = false,
  val flow:           Boolean = false,
  val useSyncReadMem: Boolean = false,
  val hasFlush:       Boolean = false)
    extends Module() {
  // ...
}
```
