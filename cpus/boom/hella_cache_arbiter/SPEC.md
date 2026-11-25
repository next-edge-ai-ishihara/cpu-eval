# Implement `HellaCacheArbiter`

Implement the complete `HellaCacheArbiter` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class HellaCacheArbiter` definition in a single Scala code block, with no text outside the block.

## Package and imports

### `src/main/scala/rocket/HellaCacheArbiter.scala`

```scala
package freechips.rocketchip.rocket

import Chisel._
import freechips.rocketchip.config.Parameters
```

## Class declaration

### `src/main/scala/rocket/HellaCacheArbiter.scala`

```scala
class HellaCacheArbiter(n: Int)(implicit p: Parameters) extends Module
{
  val io = new Bundle {
    val requestor = Vec(n, new HellaCacheIO).flip
    val mem = new HellaCacheIO
  }
```

## Parent instantiation

### `src/main/scala/common/tile.scala`

```scala
  if (outer.roccs.size > 0) {
    val (respArb, cmdRouter) = {
      val respArb = Module(new RRArbiter(new RoCCResponse()(outer.p), outer.roccs.size))
      val cmdRouter = Module(new RoccCommandRouter(outer.roccs.map(_.opcodes))(outer.p))
      outer.roccs.zipWithIndex.foreach { case (rocc, i) =>
        ptwPorts ++= rocc.module.io.ptw
        rocc.module.io.cmd <> cmdRouter.io.out(i)
        val dcIF = Module(new SimpleHellaCacheIF()(outer.p))
        dcIF.io.requestor <> rocc.module.io.mem
        hellaCachePorts += dcIF.io.cache
  // ...
  // PTW
  val ptw  = Module(new PTW(ptwPorts.length)(outer.dcache.node.edges.out(0), outer.p))
  core.io.ptw <> ptw.io.dpath
  ptw.io.requestor <> ptwPorts
  hellaCachePorts += ptw.io.mem

   // LSU IO
  val hellaCacheArb = Module(new HellaCacheArbiter(hellaCachePorts.length)(outer.p))
  hellaCacheArb.io.requestor <> hellaCachePorts
  lsu.io.hellacache <> hellaCacheArb.io.mem
  outer.dcache.module.io.lsu <> lsu.io.dmem
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/rocket/HellaCache.scala`

```scala
/** Bundle definitions for HellaCache interfaces */

trait HasCoreMemOp extends HasL1HellaCacheParameters {
  val addr = UInt(width = coreMaxAddrBits)
  val idx  = (usingVM && untagBits > pgIdxBits).option(UInt(coreMaxAddrBits.W))
  val tag  = Bits(width = coreParams.dcacheReqTagBits + log2Ceil(dcacheArbPorts))
  val cmd  = Bits(width = M_SZ)
  val size = Bits(width = log2Ceil(coreDataBytes.log2 + 1))
  val signed = Bool()
  val dprv = UInt(width = PRV.SZ)
  val dv = Bool()
}

trait HasCoreData extends HasCoreParameters {
  val data = Bits(width = coreDataBits)
  val mask = UInt(width = coreDataBytes)
}

class HellaCacheReqInternal(implicit p: Parameters) extends CoreBundle()(p) with HasCoreMemOp {
  val phys = Bool()
  val no_alloc = Bool()
  val no_xcpt = Bool()
}

class HellaCacheReq(implicit p: Parameters) extends HellaCacheReqInternal()(p) with HasCoreData

class HellaCacheResp(implicit p: Parameters) extends CoreBundle()(p)
    with HasCoreMemOp
    with HasCoreData {
  val replay = Bool()
  val has_data = Bool()
  val data_word_bypass = Bits(width = coreDataBits)
  val data_raw = Bits(width = coreDataBits)
  val store_data = Bits(width = coreDataBits)
}

class AlignmentExceptions extends Bundle {
  val ld = Bool()
  val st = Bool()
}

class HellaCacheExceptions extends Bundle {
  val ma = new AlignmentExceptions
  val pf = new AlignmentExceptions
  val gf = new AlignmentExceptions
  val ae = new AlignmentExceptions
}

class HellaCacheWriteData(implicit p: Parameters) extends CoreBundle()(p) with HasCoreData

class HellaCachePerfEvents extends Bundle {
  val acquire = Bool()
  val release = Bool()
  val grant = Bool()
  val tlbMiss = Bool()
  val blocked = Bool()
  val canAcceptStoreThenLoad = Bool()
  val canAcceptStoreThenRMW = Bool()
  val canAcceptLoadThenLoad = Bool()
  val storeBufferEmptyAfterLoad = Bool()
  val storeBufferEmptyAfterStore = Bool()
}

// interface between D$ and processor/DTLB
class HellaCacheIO(implicit p: Parameters) extends CoreBundle()(p) {
  val req = Decoupled(new HellaCacheReq)
  val s1_kill = Bool(OUTPUT) // kill previous cycle's req
  val s1_data = new HellaCacheWriteData().asOutput // data for previous cycle's req
  val s2_nack = Bool(INPUT) // req from two cycles ago is rejected
  val s2_nack_cause_raw = Bool(INPUT) // reason for nack is store-load RAW hazard (performance hint)
  val s2_kill = Bool(OUTPUT) // kill req from two cycles ago
  val s2_uncached = Bool(INPUT) // advisory signal that the access is MMIO
  val s2_paddr = UInt(INPUT, paddrBits) // translated address

  val resp = Valid(new HellaCacheResp).flip
  val replay_next = Bool(INPUT)
  val s2_xcpt = (new HellaCacheExceptions).asInput
  val s2_gpa = UInt(vaddrBitsExtended.W).asInput
  val s2_gpa_is_pte = Bool(INPUT)
  val uncached_resp = tileParams.dcache.get.separateUncachedResp.option(Decoupled(new HellaCacheResp).flip)
  val ordered = Bool(INPUT)
  val perf = new HellaCachePerfEvents().asInput

  val keep_clock_enabled = Bool(OUTPUT) // should D$ avoid clock-gating itself?
  val clock_enabled = Bool(INPUT) // is D$ currently being clocked?
}
```
