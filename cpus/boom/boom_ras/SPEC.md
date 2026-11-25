# Implement `BoomRAS`

Implement one complete `BoomRAS` Chisel definition. Preserve the definition name and public interface shown below.

Return only the complete `class BoomRAS` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package boom.ifu

import chisel3._
import chisel3.util._
// ...
import freechips.rocketchip.config._
// ...
import boom.common._
```

## Class declaration

```scala
class BoomRAS(implicit p: Parameters) extends BoomModule()(p)
{
  val io = IO(new Bundle {
    val read_idx   = Input(UInt(log2Ceil(nRasEntries).W))
    val read_addr  = Output(UInt(vaddrBitsExtended.W))

    val write_valid = Input(Bool())
    val write_idx   = Input(UInt(log2Ceil(nRasEntries).W))
    val write_addr  = Input(UInt(vaddrBitsExtended.W))
  })
```

## Parent instantiation

```scala
    new_history.ras_idx := Mux(cfi_valid && cfi_is_call, WrapInc(ras_idx, nRasEntries),
                           Mux(cfi_valid && cfi_is_ret , WrapDec(ras_idx, nRasEntries), ras_idx))
  // ...
  // RAS takes a cycle to read
  val ras_read_idx = RegInit(0.U(log2Ceil(nRasEntries).W))
  ras.io.read_idx := ras_read_idx
  when (f3.io.enq.fire) {
    ras_read_idx := f3.io.enq.bits.ghist.ras_idx
    ras.io.read_idx := f3.io.enq.bits.ghist.ras_idx
  }
  // ...
  f3_fetch_bundle.ras_top := ras.io.read_addr
  // Redirect earlier stages only if the later stage
  // can consume this packet

  val f3_predicted_target = Mux(f3_redirects.reduce(_||_),
    Mux(f3_fetch_bundle.cfi_is_ret && useBPD.B && useRAS.B,
      ras.io.read_addr,
      f3_targs(PriorityEncoder(f3_redirects))
    ),
    nextFetch(f3_fetch_bundle.pc)
  )
  // ...
  ras.io.write_valid := false.B
  ras.io.write_addr  := f3_aligned_pc + (f3_fetch_bundle.cfi_idx.bits << 1) + Mux(
    f3_fetch_bundle.cfi_npc_plus4, 4.U, 2.U)
  ras.io.write_idx   := WrapInc(f3_fetch_bundle.ghist.ras_idx, nRasEntries)
  // ...
  when (f3.io.deq.valid && f4_ready) {
    when (f3_fetch_bundle.cfi_is_call && f3_fetch_bundle.cfi_idx.valid) {
      ras.io.write_valid := true.B
    }
    // ...
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/common/types.scala

```scala
abstract class BoomModule(implicit p: Parameters) extends freechips.rocketchip.tile.CoreModule
  with HasBoomCoreParameters
```

### src/main/scala/common/parameters.scala

```scala
case class BoomCoreParams(
  // ...
  numRasEntries: Int = 32,
// ...
trait HasBoomCoreParameters extends freechips.rocketchip.tile.HasCoreParameters
{
  val boomParams: BoomCoreParams = tileParams.core.asInstanceOf[BoomCoreParams]
  // ...
  val nRasEntries = boomParams.numRasEntries max 2
```

### src/main/scala/tile/Core.scala

```scala
trait HasCoreParameters extends HasTileParameters {
```

### src/main/scala/tile/BaseTile.scala

```scala
trait HasTileParameters extends HasNonDiplomaticTileParameters {
  // ...
  def vaddrBitsExtended: Int = vpnBitsExtended + pgIdxBits
```

## Documentation

```text
If the BTB entry contains a *return* instruction, the RAS stack is
used to provide the predicted return PC as the next :term:`Fetch PC`. The
actual RAS management (of when to or the stack) is governed externally.

...

RAS Updates
^^^^^^^^^^^

The RAS is updated during the Fetch stages once the
instructions in the :term:`Fetch Packet` have been decoded. If the taken
instruction is a call [4]_ , the return address is pushed onto the RAS. If
the taken instruction is a return, then the RAS is popped.
```

## Additional requirement

When a rising clock edge samples `write_valid` asserted and `write_idx` equal to `read_idx`, `read_addr` after that edge is the `write_addr` sampled at that edge.
