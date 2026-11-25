# Implement `MissUnit`

Implement the complete `MissUnit` class. Preserve the class name and interface shown below.

Return only the complete `class MissUnit` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/Config.scala

```scala
class Rift2330 extends Config((_, _, _) => {
  case RiftParamsKey => RiftSetting(
// ...
    l1BeatBits = 64,
    memBeatBits = 64,
// ...
    l1DW = 128,

    icacheParameters = IcacheParameters(
      cb = 1,
      cl = 2,
    ),
    dcacheParameters = DcacheParameters(
      bk = 1,
      cb = 1,
      cl = 2,
      sbEntry = 2,
      stEntry = 2,
    ),
// ...
  )
})

```

## Class declaration

```scala
class MissUnit(edge: TLEdgeOut, setting: Int, id: Int)(implicit p: Parameters) extends RiftModule with HasDcacheParameters{

  class MissUnitIO extends Bundle{
    val req = Flipped(Valid(new Info_miss_req))
    val rsp = DecoupledIO(new Info_miss_rsp)

    val cache_acquire = new DecoupledIO(new TLBundleA(edge.bundle))
    val cache_grant   = Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))
    val cache_grantAck  = new DecoupledIO(new TLBundleE(edge.bundle))

    val miss_ban = Input(Bool())
    val release_ban = Output(Bool())    
  }

  val io: MissUnitIO = IO(new MissUnitIO)

```

## Parent instantiation

### src/main/scala/rift2Core/backend/LSU/Dcache.scala

```scala
  val missUnit      = if( hasL2 ) Some(Module(new MissUnit(edge = edge, setting = 2, id = id)))      else {None}
// ...
  if ( hasL2 ) {
    stage.io.missUnit_req      <> missUnit.get.io.req
    stage.io.wb_req <> writeBackUnit.get.io.wb_req
  
    probeUnit.get.io.probeBan := writeBackUnit.get.io.miss_ban
    missUnit.get.io.miss_ban  := writeBackUnit.get.io.miss_ban
    writeBackUnit.get.io.release_ban := missUnit.get.io.release_ban

    rd_arb.io.in(0).bits  := pkg_Dcache_Enq_Bundle( missUnit.get.io.rsp.bits )
    rd_arb.io.in(0).valid := missUnit.get.io.rsp.valid
    missUnit.get.io.rsp.ready := rd_arb.io.in(0).ready
// ...

```

### src/main/scala/rift2Core/backend/LSU/DcacheStage.scala

```scala

  io.missUnit_req.valid := missUnitReqValid
// ...
  
  when( pipeStage1Valid & ( pipeStage1Bits.fun.is_access | pipeStage1Bits.fun.preft ) & ( ~isHit ) ) {
    missUnitReqValid := true.B
// ...

```

### src/main/scala/rift2Core/rift2Core.scala

```scala
  if( hasL2 ) {
    exe_stage.io.missUnit_dcache_grant.get.bits  := dcache_bus.d.bits
    exe_stage.io.missUnit_dcache_grant.get.valid := dcache_bus.d.valid & ( dcache_bus.d.bits.opcode === TLMessages.Grant | dcache_bus.d.bits.opcode === TLMessages.GrantData )

    exe_stage.io.writeBackUnit_dcache_grant.get.bits  := dcache_bus.d.bits
    exe_stage.io.writeBackUnit_dcache_grant.get.valid := dcache_bus.d.valid & ( dcache_bus.d.bits.opcode === TLMessages.ReleaseAck )

    dcache_bus.d.ready := 
      Mux1H(Seq(
        ( dcache_bus.d.bits.opcode === TLMessages.Grant || dcache_bus.d.bits.opcode === TLMessages.GrantData ) -> exe_stage.io.missUnit_dcache_grant.get.ready,
        ( dcache_bus.d.bits.opcode === TLMessages.ReleaseAck )                                                 -> exe_stage.io.writeBackUnit_dcache_grant.get.ready
      ))

    dcache_bus.a.valid := exe_stage.io.missUnit_dcache_acquire.get.valid
    dcache_bus.a.bits  := exe_stage.io.missUnit_dcache_acquire.get.bits
    exe_stage.io.missUnit_dcache_acquire.get.ready := dcache_bus.a.ready

// ...
    dcache_bus.e.valid := exe_stage.io.missUnit_dcache_grantAck.get.valid
    dcache_bus.e.bits  := exe_stage.io.missUnit_dcache_grantAck.get.bits
    exe_stage.io.missUnit_dcache_grantAck.get.ready := dcache_bus.e.ready
// ...

```

## Dependency declarations

### src/main/scala/rift2Core/backend/LSU/MissUnit.scala

```scala
class Info_miss_req(implicit p: Parameters) extends RiftBundle {
  val paddr = UInt(plen.W)
}

class Info_miss_rsp(implicit p: Parameters) extends RiftBundle with HasDcacheParameters{
  val paddr = UInt(plen.W)
  val wdata = UInt(dw.W)
}

```

### src/main/scala/Parameters.scala

```scala
case class DcacheParameters(
  bk: Int = 8,
  cb: Int = 8,
  cl: Int = 128,
  sbEntry: Int = 16,
  stEntry: Int = 16,
)

trait HasDcacheParameters extends HasRiftParameters {
  val dcacheParams: DcacheParameters

  def dw = l1DW
  def bk = dcacheParams.bk
  def cb = dcacheParams.cb
  def cl = dcacheParams.cl
  def sbEntry = dcacheParams.sbEntry
  def stEntry = dcacheParams.stEntry

  def addr_lsb = log2Ceil(dw/8)
  def bk_w = log2Ceil(bk)
  def line_w   = log2Ceil(cl)
  def cb_w = log2Ceil(cb)


  def tag_w    = plen - addr_lsb - line_w - bk_w

  // require( (addr_lsb + line_w) == 12 )
  
}

```

### src/main/scala/tilelink/Bundles.scala

```scala
object TLPermissions
{
  val aWidth = 2
  val bdWidth = 2
  val cWidth = 3

  // Cap types (Grant = new permissions, Probe = permisions <= target)
  def toT = 0.U(bdWidth.W)
  def toB = 1.U(bdWidth.W)
  def toN = 2.U(bdWidth.W)
  def isCap(x: UInt) = x <= toN

  // Grow types (Acquire = permissions >= target)
  def NtoB = 0.U(aWidth.W)
  def NtoT = 1.U(aWidth.W)
  def BtoT = 2.U(aWidth.W)
// ...
}

```

### src/main/scala/tilelink/Edges.scala

```scala
  def count(bits: TLChannel, fire: Bool): (Bool, Bool, Bool, UInt) = {
    val r = firstlastHelper(bits, fire)
    (r._1, r._2, r._3, r._4)
  }
  def count(x: DecoupledIO[TLChannel]): (Bool, Bool, Bool, UInt) = count(x.bits, x.fire)
// ...
  def AcquireBlock(fromSource: UInt, toAddress: UInt, lgSize: UInt, growPermissions: UInt) = {
    require (manager.anySupportAcquireB, s"TileLink: No managers visible from this edge support Acquires, but one of these clients would try to request one: ${client.clients}")
    val legal = manager.supportsAcquireBFast(toAddress, lgSize)
    val a = Wire(new TLBundleA(bundle))
    a :#= DontCare
    a.opcode  := TLMessages.AcquireBlock
    a.param   := growPermissions
    a.size    := lgSize
    a.source  := fromSource
    a.address := toAddress
    a.mask    := mask(toAddress, lgSize)
    a.data    := 0.U
    a.corrupt := false.B
    (legal, a)
  }
// ...
  def GrantAck(d: TLBundleD): TLBundleE = GrantAck(d.sink)
  def GrantAck(toSink: UInt): TLBundleE = {
    val e = Wire(new TLBundleE(bundle))
    e.sink := toSink
    e
  }

```

## Related source code

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val dcacheClientParameters = TLMasterPortParameters.v1(
    Seq(TLMasterParameters.v1(
      name = "dcache",
      sourceId = IdRange(0, dcacheParams.bk),
      supportsProbe = if (hasL2) { TransferSizes((l1DW)/8) } else { TransferSizes.none }
    ))
  )

```

### src/main/scala/rift2Core/backend/LSU/wrtieBackUnit.scala

```scala
class WriteBackUnit(edge: TLEdgeOut, setting: Int, id: Int)(implicit p: Parameters) extends RiftModule with HasDcacheParameters{

  class WriteBackUnitIO extends Bundle{
    val wb_req = Flipped(new ValidIO(new Info_writeBack_req))

    val cache_release = new DecoupledIO(new TLBundleC(edge.bundle))
    val cache_grant   = Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))


    val release_ban = Input(Bool())
    val miss_ban = Output(Bool())    
  }

  val io: WriteBackUnitIO = IO(new WriteBackUnitIO)
// ...
  wb_state_dnxt :=
    Mux1H(Seq(
      (wb_state_qout === 0.U) -> Mux(
        wb_fifo.io.deq.valid & (
          (~io.release_ban & ( wb_fifo.io.deq.bits.is_release | wb_fifo.io.deq.bits.is_releaseData )) |
          ( wb_fifo.io.deq.bits.is_probe | wb_fifo.io.deq.bits.is_probeData )
        )
        , 1.U, 0.U),
      (wb_state_qout === 1.U) ->
        Mux(~is_release_done, 1.U,
          Mux( wb_fifo.io.deq.bits.is_probeData | wb_fifo.io.deq.bits.is_probe, 0.U, 2.U )),
      (wb_state_qout === 2.U) -> Mux( io.cache_grant.fire, 0.U, 2.U )
    ))
// ...
  io.miss_ban := wb_state_qout === 1.U | wb_state_qout === 2.U | wb_fifo.io.deq.valid

```

## Additional requirement

Every AcquireBlock sent on `cache_acquire` must carry `TLPermissions.NtoT` in `param`, and `release_ban` must be high in every cycle in which `cache_grant` fires.
