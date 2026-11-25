# Implement `ProbeUnit`

Implement the complete `ProbeUnit` class. Preserve the class name and interface shown below.

Return only the complete `class ProbeUnit` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class ProbeUnit(edge: TLEdgeOut)(implicit p: Parameters) extends RiftModule {


  val io: ProbeUnitIO = IO(new ProbeUnitIO(edge))

```

## Parent instantiation

### src/main/scala/rift2Core/backend/LSU/Dcache.scala

```scala
  val probeUnit     = if( hasL2 ) Some(Module(new ProbeUnit(edge = edge)))                  else {None}
// ...
    probeUnit.get.io.cache_probe <> io.probeUnit_dcache_probe.get
// ...
    probeUnit.get.io.probeBan := writeBackUnit.get.io.miss_ban
// ...
    rd_arb.io.in(1).bits  := pkg_Dcache_Enq_Bundle(probeUnit.get.io.req.bits) 
    rd_arb.io.in(1).valid := probeUnit.get.io.req.valid
    probeUnit.get.io.req.ready := rd_arb.io.in(1).ready

```

## Dependency declarations

### src/main/scala/rift2Core/backend/LSU/ProbeUnit.scala

```scala
class Info_probe_req(implicit p: Parameters) extends RiftBundle {
  val paddr = UInt(plen.W)
}


class ProbeUnitIO(edge: TLEdgeOut)(implicit p: Parameters) extends RiftBundle{
  val cache_probe = Flipped(new DecoupledIO(new TLBundleB(edge.bundle)))
  val req = new DecoupledIO(new Info_probe_req)

  val probeBan = Input(Bool())
}

```

## Additional requirement

`req` must not fire in any cycle in which `probeBan` is high.
