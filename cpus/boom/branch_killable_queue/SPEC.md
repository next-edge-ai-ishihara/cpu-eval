# Implement `BranchKillableQueue`

Implement one complete `BranchKillableQueue` Chisel definition. Preserve the definition name, type and value parameters, defaults, inheritance, and public interface shown below.

Return only the complete `class BranchKillableQueue` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package boom.util

import chisel3._
import chisel3.util._
// ...
import boom.common.{MicroOp}
import boom.exu.{BrUpdateInfo}
```

## Class declaration

```scala
/**
 * Create a queue that can be killed with a branch kill signal.
 * Assumption: enq.valid only high if not killed by branch (so don't check IsKilled on io.enq).
 */
class BranchKillableQueue[T <: boom.common.HasBoomUOP](gen: T, entries: Int, flush_fn: boom.common.MicroOp => Bool = u => true.B, flow: Boolean = true)
  (implicit p: freechips.rocketchip.config.Parameters)
  extends boom.common.BoomModule()(p)
  with boom.common.HasBoomCoreParameters
{
  val io = IO(new Bundle {
    val enq     = Flipped(Decoupled(gen))
    val deq     = Decoupled(gen)

    val brupdate  = Input(new BrUpdateInfo())
    val flush   = Input(Bool())

    val empty   = Output(Bool())
    val count   = Output(UInt(log2Ceil(entries).W))
  })
```

## Parent instantiation

### src/main/scala/lsu/mshrs.scala

```scala
  val rpq = Module(new BranchKillableQueue(new BoomDCacheReqInternal, cfg.nRPQ, u => u.uses_ldq, false))
  rpq.io.brupdate := io.brupdate
  rpq.io.flush  := io.exception
  assert(!(state === s_invalid && !rpq.io.empty))

  rpq.io.enq.valid := ((io.req_pri_val && io.req_pri_rdy) || (io.req_sec_val && io.req_sec_rdy)) && !isPrefetch(io.req.uop.mem_cmd)
  rpq.io.enq.bits  := io.req
  rpq.io.deq.ready := false.B
  // ...
    rpq.io.deq.ready       := io.resp.ready && io.lb_read.ready && drain_load
    io.lb_read.valid       := rpq.io.deq.valid && drain_load
    io.lb_read.bits.id     := io.id
    io.lb_read.bits.offset := rpq.io.deq.bits.addr >> rowOffBits

    io.resp.valid     := rpq.io.deq.valid && io.lb_read.fire && drain_load
    io.resp.bits.uop  := rpq.io.deq.bits.uop
    io.resp.bits.data := loadgen.data
    io.resp.bits.is_hella := rpq.io.deq.bits.is_hella
  // ...
  } .elsewhen (state === s_drain_rpq) {
    io.replay <> rpq.io.deq
    io.replay.bits.way_en    := req.way_en
    io.replay.bits.addr := Cat(req_tag, req_idx, rpq.io.deq.bits.addr(blockOffBits-1,0))
  // ...
    when (rpq.io.empty && !rpq.io.enq.valid) {
      state := s_meta_write_req
  // ...
  val respq = Module(new BranchKillableQueue(new BoomDCacheResp, 4, u => u.uses_ldq, flow = false))
  respq.io.brupdate := io.brupdate
  respq.io.flush    := io.exception
  respq.io.enq      <> resp_arb.io.out
  io.resp           <> respq.io.deq
```

### src/main/scala/exu/execution-units/execution-unit.scala

```scala
    // buffer up results since we share write-port on integer regfile.
    val queue = Module(new BranchKillableQueue(new ExeUnitResp(dataWidth),
      entries = intToFpLatency + 3)) // TODO being overly conservative
    queue.io.enq.valid       := ifpu.io.resp.valid
    // ...
    queue.io.brupdate := io.brupdate
    queue.io.flush := io.req.bits.kill

    io.ll_fresp <> queue.io.deq
    ifpu_busy := !(queue.io.empty)
    assert (queue.io.enq.ready)
    // ...
    val queue = Module(new BranchKillableQueue(new ExeUnitResp(dataWidth),
      entries = dfmaLatency + 3)) // TODO being overly conservative
    // ...
    queue.io.brupdate          := io.brupdate
    queue.io.flush           := io.req.bits.kill

    assert (queue.io.enq.ready) // If this backs up, we've miscalculated the size of the queue.
    // ...
    val fp_sdq = Module(new BranchKillableQueue(new ExeUnitResp(dataWidth),
      entries = 3)) // Lets us backpressure floating point store data
    fp_sdq.io.enq.valid      := io.req.valid && io.req.bits.uop.uopc === uopSTA && !IsKilledByBranch(io.brupdate, io.req.bits.uop)
    // ...
    fp_sdq.io.brupdate         := io.brupdate
    fp_sdq.io.flush          := io.req.bits.kill

    assert(!(fp_sdq.io.enq.valid && !fp_sdq.io.enq.ready))

    val resp_arb = Module(new Arbiter(new ExeUnitResp(dataWidth), 2))
    resp_arb.io.in(0) <> queue.io.deq
    resp_arb.io.in(1) <> fp_sdq.io.deq
    io.ll_iresp       <> resp_arb.io.out

    fpiu_busy := !(queue.io.empty && fp_sdq.io.empty)
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/util/util.scala

```scala
/**
 * Object to check if MicroOp was killed due to a branch mispredict.
 * Uses "Fast" branch masks
 */
object IsKilledByBranch
{
  def apply(brupdate: BrUpdateInfo, uop: MicroOp): Bool = {
    return maskMatch(brupdate.b1.mispredict_mask, uop.br_mask)
  }

  def apply(brupdate: BrUpdateInfo, uop_mask: UInt): Bool = {
    return maskMatch(brupdate.b1.mispredict_mask, uop_mask)
  }
}
// ...
/**
 * Object to return a BR mask given a MicroOp mask and old BR mask.
 */
object GetNewBrMask
{
   def apply(brupdate: BrUpdateInfo, uop: MicroOp): UInt = {
     return uop.br_mask & ~brupdate.b1.resolve_mask
   }

   def apply(brupdate: BrUpdateInfo, br_mask: UInt): UInt = {
     return br_mask & ~brupdate.b1.resolve_mask
   }
}

object UpdateBrMask
{
  def apply(brupdate: BrUpdateInfo, uop: MicroOp): MicroOp = {
    val out = WireInit(uop)
    out.br_mask := GetNewBrMask(brupdate, uop)
    out
  }
  def apply[T <: boom.common.HasBoomUOP](brupdate: BrUpdateInfo, bundle: T): T = {
    val out = WireInit(bundle)
    out.uop.br_mask := GetNewBrMask(brupdate, bundle.uop.br_mask)
    out
  }
  def apply[T <: boom.common.HasBoomUOP](brupdate: BrUpdateInfo, bundle: Valid[T]): Valid[T] = {
    val out = WireInit(bundle)
    out.bits.uop.br_mask := GetNewBrMask(brupdate, bundle.bits.uop.br_mask)
    out.valid := bundle.valid && !IsKilledByBranch(brupdate, bundle.bits.uop.br_mask)
    out
  }
}

/**
 * Object to check if at least 1 bit matches in two masks
 */
object maskMatch
{
  def apply(msk1: UInt, msk2: UInt): Bool = (msk1 & msk2) =/= 0.U
}
```

### src/main/scala/exu/execution-units/functional-unit.scala

```scala
class BrUpdateInfo(implicit p: Parameters) extends BoomBundle
{
  // On the first cycle we get masks to kill registers
  val b1 = new BrUpdateMasks
  // On the second cycle we get indices to reset pointers
  val b2 = new BrResolutionInfo
}

class BrUpdateMasks(implicit p: Parameters) extends BoomBundle
{
  val resolve_mask = UInt(maxBrCount.W)
  val mispredict_mask = UInt(maxBrCount.W)
}
```

### src/main/scala/common/micro-op.scala

```scala
/**
 * Extension to BoomBundle to add a MicroOp
 */
abstract trait HasBoomUOP extends BoomBundle
{
  val uop = new MicroOp()
}
// ...
class MicroOp(implicit p: Parameters) extends BoomBundle
  // ...
  val br_mask          = UInt(maxBrCount.W)  // which branches are we being speculated under?
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
// ...
/** A concrete subclass of ReadyValidIO signaling that the user expects a
  * "decoupled" interface: 'valid' indicates that the producer has
  * put valid data in 'bits', and 'ready' indicates that the consumer is ready
  * to accept the data this cycle. No requirements are placed on the signaling
  * of ready or valid.
  * @param gen the type of data to be wrapped in DecoupledIO
  */
class DecoupledIO[+T <: Data](gen: T) extends ReadyValidIO[T](gen)
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
  // ...
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
  // ...
```

## Documentation

```text
[util] Let killed ops dequeue themselves from the bkqueue
```

```text
[util] Add option to disable flowthrough in branchkillablequeue
```

```text
[util] Fix flush interaction with the branch-killable-queue
```

### docs/sections/execution-stages.rst

```text
Branch Unit & Branch Speculation
--------------------------------

The :term:`Branch Unit` handles the resolution of all branch and jump
instructions.

All :term:`UOPs<Micro-Op (UOP)` that are "inflight" in the pipeline (have an allocated ROB
entry) are given a branch mask, where each bit in the branch mask
corresponds to an un-executed, inflight branch that the :term:`UOP<Micro-Op (UOP)` is
speculated under. Each branch in *Decode* is allocated a branch tag,
and all following :term:`UOPs<Micro-Op (UOP)` will have the corresponding bit in the
branch mask set (until the branch is resolved by the :term:`Branch Unit`).

If the branches (or jumps) have been correctly speculated by the
:term:`Front-end`, then the :term:`Branch Unit` s only action is to broadcast the
corresponding branch tag to *all* inflight :term:`UOPs<Micro-Op (UOP)` that the branch has
been resolved correctly. Each :term:`UOP<Micro-Op (UOP)` can then clear the corresponding
bit in its branch mask, and that branch tag can then be allocated to a
new branch in the *Decode* stage.

If a branch (or jump) is misspeculated, the :term:`Branch Unit` must redirect
the PC to the correct target, kill the :term:`Front-end` and :term:`Fetch Buffer`, and
broadcast the misspeculated branch tag so that all dependent, inflight
:term:`UOPs<Micro-Op (UOP)` may be killed. The PC redirect signal goes out immediately, to
decrease the misprediction penalty. However, the *kill* signal is
delayed a cycle for critical path reasons.
```

## Additional requirement

`deq` never presents an entry that the current cycle's `brupdate.b1.mispredict_mask` or `flush` cancels, the `uop.br_mask` it presents excludes every `brupdate.b1.resolve_mask` bit asserted in or after the cycle in which the entry was accepted, and `flush` cancels only entries stored before the cycle in which it is asserted.
