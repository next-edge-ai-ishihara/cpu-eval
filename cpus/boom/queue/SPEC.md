# Implement `Queue`

Implement the complete `Queue` module. Preserve its class declaration and public interface shown below. Return only the complete `class Queue` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
// SPDX-License-Identifier: Apache-2.0

/** Wrappers for ready-valid (Decoupled) interfaces and associated circuit generators using them.
  */

package chisel3.util

import chisel3._
import chisel3.experimental.{requireIsChiselType, DataMirror, Direction}
import chisel3.internal.naming._ // can't use chisel3_ version because of compile order
```

## Class declaration

```scala
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
@chiselName
class Queue[T <: Data](
  val gen:            T,
  val entries:        Int,
  val pipe:           Boolean = false,
  val flow:           Boolean = false,
  val useSyncReadMem: Boolean = false,
  val hasFlush:       Boolean = false
)(
  implicit compileOptions: chisel3.CompileOptions)
    extends Module() {
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/chisel3/util/Decoupled.scala`

```scala
abstract class ReadyValidIO[+T <: Data](gen: T) extends Bundle {
// ...
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
  val bits = Output(genType)
}

object ReadyValidIO {

  implicit class AddMethodsToReadyValid[T <: Data](target: ReadyValidIO[T]) {

    /** Indicates if IO is both ready and valid
      */
    def fire: Bool = target.ready && target.valid
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
  /** I/O to enqueue data (client is producer, and Queue object is consumer), is [[Chisel.DecoupledIO]] flipped.
    * @group Signals
    */
  val enq = Flipped(EnqIO(gen))

  /** I/O to dequeue data (client is consumer and Queue object is producer), is [[Chisel.DecoupledIO]]
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
```

### `core/src/main/scala/chisel3/CompileOptions.scala`

```scala
trait CompileOptions {
  // Should Record connections require a strict match of fields.
  // If true and the same fields aren't present in both source and sink, a MissingFieldException,
  // MissingLeftFieldException, or MissingRightFieldException will be thrown.
  val connectFieldsMustMatch: Boolean
  // When creating an object that takes a type argument, the argument must be unbound (a pure type).
  val declaredTypeMustBeUnbound: Boolean
  // If a connection operator fails, don't try the connection with the operands (source and sink) reversed.
  val dontTryConnectionsSwapped: Boolean
  // If connection directionality is not explicit, do not use heuristics to attempt to determine it.
  val dontAssumeDirectionality: Boolean
  // Check that referenced Data have actually been declared.
  val checkSynthesizable: Boolean
  // Require explicit assignment of DontCare to generate "x is invalid"
  val explicitInvalidate: Boolean
  // Should the reset type of Module be a Bool or a Reset
  val inferModuleReset: Boolean
}
// ...
  // Collection of "not strict" connection compile options.
  // These provide compatibility with existing code.
  implicit val NotStrict = new CompileOptionsClass(
    connectFieldsMustMatch = false,
    declaredTypeMustBeUnbound = false,
    dontTryConnectionsSwapped = false,
    dontAssumeDirectionality = false,
    checkSynthesizable = false,
    explicitInvalidate = false,
    inferModuleReset = false
  )

  // Collection of "strict" connection compile options, preferred for new code.
  implicit val Strict = new CompileOptionsClass(
    connectFieldsMustMatch = true,
    declaredTypeMustBeUnbound = true,
    dontTryConnectionsSwapped = true,
    dontAssumeDirectionality = true,
    checkSynthesizable = true,
    explicitInvalidate = true,
    inferModuleReset = true
  )
```

### `src/main/scala/chisel3/compatibility.scala`

```scala
package object Chisel {
// ...
  implicit val defaultCompileOptions = chisel3.ExplicitCompileOptions.NotStrict
```

## Related source code

### `design/craft/inclusivecache/src/SourceD.scala`

```scala
import Chisel._
// ...
  // Make a queue to catch BS readout during stalls
  val queue = Module(new Queue(io.bs_rdat, 3, flow=true))
  queue.io.enq.valid := RegNext(RegNext(io.bs_radr.fire()))
  queue.io.enq.bits := io.bs_rdat
  assert (!queue.io.enq.valid || queue.io.enq.ready)
```

### `src/test/scala/chiselTests/QueueSpec.scala`

```scala
class ThingsPassThroughTester(
  elements:       Seq[Int],
  queueDepth:     Int,
  bitWidth:       Int,
  tap:            Int,
  useSyncReadMem: Boolean,
  hasFlush:       Boolean)
    extends BasicTester {
  val q = Module(new Queue(UInt(bitWidth.W), queueDepth, useSyncReadMem = useSyncReadMem, hasFlush = hasFlush))
  val elems = VecInit(elements.map {
    _.asUInt()
  })
  val inCnt = Counter(elements.length + 1)
  val outCnt = Counter(elements.length + 1)

  q.io.enq.valid := (inCnt.value < elements.length.U)
  q.io.deq.ready := LFSR(16)(tap)
  q.io.flush.foreach { _ := false.B } //Flush behavior is tested in QueueFlushSpec
  q.io.enq.bits := elems(inCnt.value)
  when(q.io.enq.fire) {
    inCnt.inc()
  }
  when(q.io.deq.fire) {
    //ensure that what comes out is what comes in
    assert(elems(outCnt.value) === q.io.deq.bits)
    outCnt.inc()
  }
  when(outCnt.value === elements.length.U) {
    stop()
  }
}

class QueueReasonableReadyValid(elements: Seq[Int], queueDepth: Int, bitWidth: Int, tap: Int, useSyncReadMem: Boolean)
    extends BasicTester {
  val q = Module(new Queue(UInt(bitWidth.W), queueDepth, useSyncReadMem = useSyncReadMem))
  val elems = VecInit(elements.map {
    _.asUInt()
  })
  val inCnt = Counter(elements.length + 1)
  val outCnt = Counter(elements.length + 1)

  q.io.enq.valid := (inCnt.value < elements.length.U)
  //Queue should be full or ready
  assert(q.io.enq.ready || q.io.count === queueDepth.U)

  q.io.deq.ready := LFSR(16)(tap)
  //Queue should be empty or valid
  assert(q.io.deq.valid || q.io.count === 0.U)

  q.io.enq.bits := elems(inCnt.value)
  when(q.io.enq.fire) {
    inCnt.inc()
  }
  when(q.io.deq.fire) {
    outCnt.inc()
  }
  when(outCnt.value === elements.length.U) {
    stop()
  }
}

class CountIsCorrectTester(elements: Seq[Int], queueDepth: Int, bitWidth: Int, tap: Int, useSyncReadMem: Boolean)
    extends BasicTester {
  val q = Module(new Queue(UInt(bitWidth.W), queueDepth, useSyncReadMem = useSyncReadMem))
  val elems = VecInit(elements.map {
    _.asUInt(bitWidth.W)
  })
  val inCnt = Counter(elements.length + 1)
  val outCnt = Counter(elements.length + 1)

  q.io.enq.valid := (inCnt.value < elements.length.U)
  q.io.deq.ready := LFSR(16)(tap)

  q.io.enq.bits := elems(inCnt.value)
  when(q.io.enq.fire) {
    inCnt.inc()
    assert(q.io.count === (inCnt.value - outCnt.value))
  }
  when(q.io.deq.fire) {
    outCnt.inc()
    assert(q.io.count === (inCnt.value - outCnt.value))
  }
  //assert(q.io.count === (inCnt.value - outCnt.value))

  when(outCnt.value === elements.length.U) {
    stop()
  }
}

class QueueSinglePipeTester(elements: Seq[Int], bitWidth: Int, tap: Int, useSyncReadMem: Boolean) extends BasicTester {
  val q = Module(new Queue(UInt(bitWidth.W), 1, pipe = true, useSyncReadMem = useSyncReadMem))
  val elems = VecInit(elements.map {
    _.asUInt(bitWidth.W)
  })
  val inCnt = Counter(elements.length + 1)
  val outCnt = Counter(elements.length + 1)

  q.io.enq.valid := (inCnt.value < elements.length.U)
  q.io.deq.ready := LFSR(16)(tap)

  assert(q.io.enq.ready || (q.io.count === 1.U && !q.io.deq.ready))

  q.io.enq.bits := elems(inCnt.value)
  when(q.io.enq.fire) {
    inCnt.inc()
  }
  when(q.io.deq.fire) {
    outCnt.inc()
  }

  when(outCnt.value === elements.length.U) {
    stop()
  }
}

class QueuePipeTester(elements: Seq[Int], queueDepth: Int, bitWidth: Int, tap: Int, useSyncReadMem: Boolean)
    extends BasicTester {
  val q = Module(new Queue(UInt(bitWidth.W), queueDepth, pipe = true, useSyncReadMem = useSyncReadMem))
  val elems = VecInit(elements.map {
    _.asUInt(bitWidth.W)
  })
  val inCnt = Counter(elements.length + 1)
  val outCnt = Counter(elements.length + 1)

  q.io.enq.valid := (inCnt.value < elements.length.U)
  q.io.deq.ready := LFSR(16)(tap)

  assert(q.io.enq.ready || (q.io.count === queueDepth.U && !q.io.deq.ready))

  q.io.enq.bits := elems(inCnt.value)
  when(q.io.enq.fire) {
    inCnt.inc()
  }
  when(q.io.deq.fire) {
    outCnt.inc()
  }

  when(outCnt.value === elements.length.U) {
    stop()
  }
}

class QueueFlowTester(elements: Seq[Int], queueDepth: Int, bitWidth: Int, tap: Int, useSyncReadMem: Boolean)
    extends BasicTester {
  val q = Module(new Queue(UInt(bitWidth.W), queueDepth, flow = true, useSyncReadMem = useSyncReadMem))
  val elems = VecInit(elements.map {
    _.asUInt()
  })
  val inCnt = Counter(elements.length + 1)
  val outCnt = Counter(elements.length + 1)

  q.io.enq.valid := (inCnt.value < elements.length.U)
  //Queue should be full or ready
  assert(q.io.enq.ready || q.io.count === queueDepth.U)

  q.io.deq.ready := LFSR(16)(tap)
  //Queue should be empty or valid
  assert(q.io.deq.valid || (q.io.count === 0.U && !q.io.enq.fire))

  q.io.enq.bits := elems(inCnt.value)
  when(q.io.enq.fire) {
    inCnt.inc()
  }
  when(q.io.deq.fire) {
    outCnt.inc()
  }
  when(outCnt.value === elements.length.U) {
    stop()
  }
}
```

### `src/test/scala/chiselTests/QueueFlushSpec.scala`

```scala
abstract class FlushQueueTesterBase(
  elements:       Seq[Int],
  queueDepth:     Int,
  bitWidth:       Int,
  tap:            Int,
  useSyncReadMem: Boolean)
    extends BasicTester {
  val q = Module(new Queue(UInt(bitWidth.W), queueDepth, hasFlush = true))
  val elems = VecInit(elements.map(_.U))
  val inCnt = Counter(elements.length + 1)
  val outCnt = RegInit(0.U(log2Ceil(elements.length).W))
  val currQCnt = RegInit(0.U(log2Ceil(5).W))

  val flush: Bool = WireInit(false.B)
  val flushRegister = RegNext(flush, init = false.B)
  q.io.flush.get := flush
  q.io.enq.valid := (inCnt.value < elements.length.U)
  q.io.deq.ready := LFSR(16)(tap)

  q.io.enq.bits := elems(inCnt.value)
  when(q.io.enq.fire) {
    inCnt.inc()
    currQCnt := currQCnt + 1.U //counts how many items have been enqueued
  }
  when(q.io.deq.fire) {
    assert(flushRegister === false.B) //check queue isn't flushed (can't dequeue an empty queue)
  }
  when(flushRegister) { //Internal signal maybe_full is a register so some signals update on the next cycle
    //check that queue gets flushed when queue is full
    assert(q.io.count === 0.U)
    assert(!q.io.deq.valid, "Expected to not be able to dequeue when flush is asserted the previous cycle")
    assert(
      q.io.enq.ready,
      "Expected enqueue to be ready when flush was asserted the previous cycle because queue should be empty"
    )
  }
  when(inCnt.value === elements.length.U) { //stop when all entries are enqueued
    stop()
  }
}
// ...
/** Test queue can enqueue during a flush
  *
  * @param elements The sequence of elements used in the queue
  * @param queueDepth The max number of entries in the queue
  * @param bitWidth Integer size of the data type used in the queue
  * @param tap Integer tap('seed') for the LFSR
  * @param useSyncReadMem True uses SyncReadMem instead of Mem as an internal memory element
  */
class EnqueueEmptyFlushEdgecaseTester(
  elements:       Seq[Int],
  queueDepth:     Int,
  bitWidth:       Int,
  tap:            Int,
  useSyncReadMem: Boolean)
    extends FlushQueueTesterBase(elements, queueDepth, bitWidth, tap, useSyncReadMem) {
  val cycleCounter = Counter(elements.length + 1)
  val outCounter = Counter(elements.length + 1)

  //testing an enqueue during a flush
  flush := (cycleCounter.value === 0.U && inCnt.value === 0.U) //flushed only before anything is enqueued
  cycleCounter.inc() //counts every cycle

  when(q.io.deq.fire) {
    //flush and enqueue were both active on the first cycle,
    //so that element is flushed immediately which makes outCnt off by one
    assert(elems(outCounter.value + 1.U) === q.io.deq.bits) //ensure that what comes out is what comes in
    outCounter.inc()
  }
}
```
