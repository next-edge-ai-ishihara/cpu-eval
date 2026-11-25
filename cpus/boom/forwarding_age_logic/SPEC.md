# Implement `ForwardingAgeLogic`

Implement one complete `ForwardingAgeLogic` source-level hardware definition for the selected BOOM configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class ForwardingAgeLogic` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/config-mixins.scala`

```scala
              numStqEntries = 24,
```

## Package and imports

### `src/main/scala/lsu/lsu.scala`

```scala
package boom.lsu

import chisel3._
import chisel3.util._
// ...
import freechips.rocketchip.config.Parameters
// ...
import boom.common._
```

## Class declaration

### `src/main/scala/lsu/lsu.scala`

```scala
class ForwardingAgeLogic(num_entries: Int)(implicit p: Parameters) extends BoomModule()(p)
{
   val io = IO(new Bundle
   {
      val addr_matches    = Input(UInt(num_entries.W)) // bit vector of addresses that match
                                                       // between the load and the SAQ
      val youngest_st_idx = Input(UInt(stqAddrSz.W)) // needed to get "age"

      val forwarding_val  = Output(Bool())
      val forwarding_idx  = Output(UInt(stqAddrSz.W))
   })
```

## Parent instantiation

### `src/main/scala/lsu/lsu.scala`

```scala
  // Find the youngest store which the load is dependent on
  val forwarding_age_logic = Seq.fill(memWidth) { Module(new ForwardingAgeLogic(numStqEntries)) }
  for (w <- 0 until memWidth) {
    forwarding_age_logic(w).io.addr_matches    := ldst_addr_matches(w).asUInt
    forwarding_age_logic(w).io.youngest_st_idx := lcam_uop(w).stq_idx
  }
  val forwarding_idx = widthMap(w => forwarding_age_logic(w).io.forwarding_idx)

  // Forward if st-ld forwarding is possible from the writemask and loadmask
  mem_forward_valid       := widthMap(w =>
                                  (ldst_forward_matches(w)(forwarding_idx(w))        &&
                                 !IsKilledByBranch(io.core.brupdate, lcam_uop(w))    &&
                                 !io.core.exception && !RegNext(io.core.exception)))
  mem_forward_stq_idx     := forwarding_idx
```

```scala
    io.core.dis_stq_idx(w) := st_enq_idx
    // ...
      ldq(ld_enq_idx).bits.youngest_stq_idx  := st_enq_idx
      ldq(ld_enq_idx).bits.st_dep_mask     := next_live_store_mask
    // ...
    next_live_store_mask = Mux(dis_st_val, next_live_store_mask | (1.U << st_enq_idx),
                                           next_live_store_mask)
    st_enq_idx = Mux(dis_st_val, WrapInc(st_enq_idx, numStqEntries),
                                 st_enq_idx)
```

### `src/main/scala/exu/core.scala`

```scala
    dis_uops(w).stq_idx := io.lsu.dis_stq_idx(w)
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/lsu/lsu.scala`

```scala
class LDQEntry(implicit p: Parameters) extends BoomBundle()(p)
    with HasBoomUOP
{
  // ...
  val st_dep_mask         = UInt(numStqEntries.W) // list of stores older than us
  val youngest_stq_idx    = UInt(stqAddrSz.W) // index of the oldest store younger than us
```

### `src/main/scala/common/micro-op.scala`

```scala
class MicroOp(implicit p: Parameters) extends BoomBundle
  with freechips.rocketchip.rocket.constants.MemoryOpConstants
  with freechips.rocketchip.rocket.constants.ScalarOpConstants
{
  // ...
  val stq_idx          = UInt(stqAddrSz.W)
```

### `src/main/scala/common/parameters.scala`

```scala
trait HasBoomCoreParameters extends freechips.rocketchip.tile.HasCoreParameters
{
  // ...
  val numStqEntries = boomParams.numStqEntries       // number of SAQ/SDQ entries
  // ...
  val stqAddrSz       = log2Ceil(numStqEntries)
```

### `src/main/scala/util/util.scala`

```scala
/**
 * Object to increment an input value, wrapping it if
 * necessary.
 */
object WrapInc
{
  // "n" is the number of increments, so we wrap at n-1.
  def apply(value: UInt, n: Int): UInt = {
    if (isPow2(n)) {
      (value + 1.U)(log2Ceil(n)-1,0)
    } else {
      val wrap = (value === (n-1).U)
      Mux(wrap, 0.U, value + 1.U)
    }
  }
}
// ...
/**
  * Object to determine whether queue
  * index i0 is older than index i1.
 */
object IsOlder
{
  def apply(i0: UInt, i1: UInt, head: UInt) = ((i0 < i1) ^ (i0 < head) ^ (i1 < head))
}
```

## Documentation

### `docs/sections/load-store-unit.rst`

```text
Entries in the Load Queue (LDQ) are allocated in the *Decode* stage
(``ldq(i).valid``). In **Decode**, each load entry is also given a *store
mask* (``ldq(i).bits.st\_dep\_mask``), which marks which stores in the Store
Queue the given load depends on. When a store is fired to memory and
leaves the Store Queue, the appropriate bit in the *store mask* is cleared.
...
Simultaneously, the load instruction compares its address with all of
the store addresses that it depends on. If there is a match, the memory
request is killed. If the corresponding store data is present, then the
store data is *forwarded* to the load and the load marks itself as
having *succeeded*. If the store data is not present, then the load goes
to *sleep*. Loads that have been put to sleep are retried at a later
time. [1]_
```
