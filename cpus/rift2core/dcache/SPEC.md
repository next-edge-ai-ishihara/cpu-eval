# Implement `Dcache`

Implement the complete `Dcache` class. Preserve the class name and interface shown below.

Return only the complete `class Dcache` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/Config.scala

```scala
class Rift2330 extends Config((_, _, _) => {
  case RiftParamsKey => RiftSetting(
    hasL2  = true,
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
```

## Package and imports

### src/main/scala/rift2Core/backend/LSU/Dcache.scala

```scala
package rift2Core.backend.lsu

import chisel3._
import chisel3.util._

import rift2Core.define._

import rift2Chip._

import org.chipsalliance.cde.config._
import freechips.rocketchip.tilelink._
import chisel3.experimental.dataview._
```

## Parent instantiation

### src/main/scala/rift2Core/backend/LSU/Lsu.scala

```scala
  val cache = for ( i <- 0 until bk ) yield { val mdl = Module(new Dcache(dEdge(0), i)); mdl }
// ...
    io.missUnit_dcache_acquire.get  <>  acquireArb.io.out
    io.missUnit_dcache_grantAck.get <> grantAckArb.io.out
    for ( i <- 0 until bk ) {
      acquireArb.io.in(i) <> cache(i).io.missUnit_dcache_acquire.get

      when( io.missUnit_dcache_grant.get.bits.source === i.U ) {
        cache(i).io.missUnit_dcache_grant.get <> io.missUnit_dcache_grant.get
      }

      grantAckArb.io.in(i) <> cache(i).io.missUnit_dcache_grantAck.get

      when( (if( bk > 1 ) {io.probeUnit_dcache_probe.get.bits.address(addr_lsb+bk_w-1,addr_lsb)} else {0.U}) === i.U ) {
        cache(i).io.probeUnit_dcache_probe.get <> io.probeUnit_dcache_probe.get  
      }

      when( io.writeBackUnit_dcache_grant.get.bits.source === i.U ) {
        cache(i).io.writeBackUnit_dcache_grant.get <> io.writeBackUnit_dcache_grant.get
// ...
      val is_chnc_busy = RegInit(VecInit(Seq.fill(bk)(false.B)))
      val is_release_done = for ( i <- 0 until bk ) yield { dEdge(0).count(cache(i).io.writeBackUnit_dcache_release.get)._3 }
      for( i <- 0 until bk ) yield {
        when( cache(i).io.writeBackUnit_dcache_release.get.fire ) { is_chnc_busy(i) := Mux( is_release_done(i), false.B, true.B )}
      }

      for ( i <- 0 until bk ) {
        releaseArb.io.in(i) <> cache(i).io.writeBackUnit_dcache_release.get
      }
      when( is_chnc_busy.forall((x:Bool) => (x === false.B)) ) {
        io.writeBackUnit_dcache_release.get <> releaseArb.io.out
      } .otherwise {
        releaseArb.io.out.ready := false.B
        for ( i <- 0 until bk ) {
          when( is_chnc_busy(i) === true.B  ) { io.writeBackUnit_dcache_release.get <> cache(i).io.writeBackUnit_dcache_release.get }
        }
      }
// ...
    cache(i).io.enq.valid := cacheBankIO(i).valid
    cache(i).io.enq.bits  := cacheBankIO(i).bits
    cacheBankIO(i).ready  := cache(i).io.enq.ready
    cache(i).io.flush := io.flush    
// ...
  for ( i <- 0 until bk ) {
    lu_wb_arb.io.in(i).valid := cache(i).io.deq.valid & cache(i).io.deq.bits.is_load_amo
    lu_wb_arb.io.in(i).bits := Mux( lu_wb_arb.io.in(i).valid, cache(i).io.deq.bits, 0.U.asTypeOf(new Dcache_Deq_Bundle) )
    cache(i).io.deq.ready := lu_wb_arb.io.in(i).ready | ~cache(i).io.deq.bits.is_load_amo
    when( cache(i).io.deq.bits.is_load_amo ) { assert(cache(i).io.deq.fire === lu_wb_arb.io.in(i).fire) }
  }
// ...
  is_empty := 
    stQueue.io.is_empty & 
    VecInit(cache.map{x => x.io.is_empty}).forall((x:Bool) => (x === true.B)) &
```

## Dependency declarations

### src/main/scala/rift2Core/backend/LSU/Dcache.scala

```scala
abstract class Dcache_ScoreBoard_Bundle(implicit p: Parameters) extends DcacheBundle {
  val chkIdx = UInt((log2Ceil(sbEntry)).W)
}



class Dcache_Enq_Bundle(implicit p: Parameters) extends Dcache_ScoreBoard_Bundle {
  val paddr = UInt(plen.W)
  val wdata = UInt(dw.W)
  val wstrb = UInt((dw/8).W)

  val fun   = new Cache_op
  val rd    = new RD_PHY

  val vAttach = if(hasVector) {Some(new VLsu_Attach_Bundle)} else {None}


  def tagSel = paddr(plen-1,plen-tag_w)
  def clSel  = paddr(addr_lsb+bk_w + line_w-1, addr_lsb+bk_w)

  def wmask = Strb2Mask(wstrb)

}

class Dcache_Deq_Bundle(implicit p: Parameters) extends Dcache_ScoreBoard_Bundle {
  val wb = new WriteBack_info(dw=64)
  val is_load_amo = Bool()

  val vAttach = if(hasVector) {Some(new VLsu_Attach_Bundle)} else {None}

  val is_flw = Bool()
  val is_fld = Bool()

  val isXwb = Bool()
  val isFwb = Bool()
  val isVwb = Bool()

}
// ...
abstract class DcacheBase(edge: TLEdgeOut, id: Int)(implicit p: Parameters) extends DcacheModule {
  val dEdge = edge

  class DcacheIO extends Bundle{
    val enq = Flipped(new DecoupledIO(new Dcache_Enq_Bundle))
    val deq = new DecoupledIO(new Dcache_Deq_Bundle)
    val is_empty = Output(Bool())

    val flush = Input(Bool())

    // val dm        = if (hasDebugger) {Some(Flipped(new Info_DM_cmm))} else {None}

    val missUnit_dcache_acquire      = if( hasL2 ) Some(new DecoupledIO(new TLBundleA(dEdge.bundle)))          else {None}
    val missUnit_dcache_grant        = if( hasL2 ) Some(Flipped(new DecoupledIO(new TLBundleD(dEdge.bundle)))) else {None}
    val missUnit_dcache_grantAck     = if( hasL2 ) Some(DecoupledIO(new TLBundleE(dEdge.bundle)))              else {None}
    val probeUnit_dcache_probe       = if( hasL2 ) Some(Flipped(new DecoupledIO(new TLBundleB(dEdge.bundle)))) else {None}
    val writeBackUnit_dcache_release = if( hasL2 ) Some(new DecoupledIO(new TLBundleC(dEdge.bundle))         ) else {None}
    val writeBackUnit_dcache_grant   = if( hasL2 ) Some(Flipped(new DecoupledIO(new TLBundleD(dEdge.bundle)))) else {None}

    val dcache_getPut = if ( hasL2 ) { None } else { Some(        new DecoupledIO(new TLBundleA(edge.bundle)) ) }
    val dcache_access = if ( hasL2 ) { None } else { Some(Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))) }    
  } 

  val io: DcacheIO = IO(new DcacheIO)

  val missUnit      = if( hasL2 ) Some(Module(new MissUnit(edge = edge, setting = 2, id = id)))      else {None}
  val probeUnit     = if( hasL2 ) Some(Module(new ProbeUnit(edge = edge)))                  else {None}
  val writeBackUnit = if( hasL2 ) Some(Module(new WriteBackUnit(edge = edge, setting = 2, id = id))) else {None}

  val getUnit = if( hasL2 ) {None} else {Some(Module(new GetUnit(edge = edge, id = id)))}
  val putUnit = if( hasL2 ) {None} else {Some(Module(new PutUnit(edge = edge, id = id)))}

  val lsEntry = Module(new Queue(new Dcache_Enq_Bundle, sbEntry, pipe = false, flow = true))


  val rtn_fifo = Module(new Queue(new Dcache_Deq_Bundle, sbEntry, false, true)) // bypass Mode
  val op_arb = Module(new Arbiter( new Dcache_Enq_Bundle, 2))
  val rd_arb = Module(new Arbiter( new Dcache_Enq_Bundle, 3))

  val reload_fifo = Module( new Queue( new Dcache_Enq_Bundle, 1, true, false) )

  val stage = Module(new DcacheStage(id))



  def pkg_Dcache_Enq_Bundle( ori: Info_miss_rsp )(implicit p: Parameters): Dcache_Enq_Bundle = {
    val res = Wire(new Dcache_Enq_Bundle)

    res.paddr := ori.paddr
    res.wstrb := "hFFFFFFFF".U
    res.wdata := ori.wdata

    {
      res.fun := 0.U.asTypeOf(new Cache_op)
      res.fun.grant := true.B      
    }
    res.rd := 0.U.asTypeOf(new RD_PHY)
    res.chkIdx := 0.U

    if(hasVector){ res.vAttach.get := DontCare }

    res
  }
  
  def pkg_Dcache_Enq_Bundle( ori: Info_probe_req )(implicit p: Parameters): Dcache_Enq_Bundle = {
    val res = Wire(new Dcache_Enq_Bundle)
    res.paddr := ori.paddr
    res.wstrb := 0.U
    res.wdata := 0.U

    {
      res.fun := 0.U.asTypeOf(new Cache_op)
      res.fun.probe := true.B      
    }
    res.rd := 0.U.asTypeOf(new RD_PHY)
    res.chkIdx := 0.U

    if(hasVector){ res.vAttach.get := DontCare }

    res
  }





}
```

### src/main/scala/rift2Core/backend/LSU/DcacheStage.scala

```scala
class DcacheStageBase(idx: Int)(implicit p: Parameters) extends DcacheModule {
  val id = idx

  class DcacheStageIO extends Bundle{
    val enq = Flipped(Decoupled(new Dcache_Enq_Bundle))
    val reload = Valid(new Dcache_Enq_Bundle)
    val deq = Valid(new Dcache_Deq_Bundle)

    val missUnit_req = Valid(new Info_miss_req)
    val wb_req = Valid(new Info_writeBack_req)

    val isCacheEmpty = Input(Bool())
    val flush = Input(Bool())    
  }

  val io: DcacheStageIO = IO(new DcacheStageIO)
```

### src/main/scala/rift2Core/backend/LSU/MissUnit.scala

```scala
  class MissUnitIO extends Bundle{
    val req = Flipped(Valid(new Info_miss_req))
    val rsp = DecoupledIO(new Info_miss_rsp)

    val cache_acquire = new DecoupledIO(new TLBundleA(edge.bundle))
    val cache_grant   = Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))
    val cache_grantAck  = new DecoupledIO(new TLBundleE(edge.bundle))

    val miss_ban = Input(Bool())
    val release_ban = Output(Bool())    
  }
// ...
  class GetUnitIO extends Bundle{
    val req = Flipped(Valid(new Info_miss_req))
    val rsp = DecoupledIO(new Info_miss_rsp)

    val getPut = new DecoupledIO(new TLBundleA(edge.bundle))
    val access = Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))

    val miss_ban = Input(Bool())
    val release_ban = Output(Bool())
  }
```

### src/main/scala/rift2Core/backend/LSU/ProbeUnit.scala

```scala
class ProbeUnitIO(edge: TLEdgeOut)(implicit p: Parameters) extends RiftBundle{
  val cache_probe = Flipped(new DecoupledIO(new TLBundleB(edge.bundle)))
  val req = new DecoupledIO(new Info_probe_req)

  val probeBan = Input(Bool())
}
```

### src/main/scala/rift2Core/backend/LSU/wrtieBackUnit.scala

```scala
  class WriteBackUnitIO extends Bundle{
    val wb_req = Flipped(new ValidIO(new Info_writeBack_req))

    val cache_release = new DecoupledIO(new TLBundleC(edge.bundle))
    val cache_grant   = Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))


    val release_ban = Input(Bool())
    val miss_ban = Output(Bool())    
  }
// ...
  class PutUnitIO extends Bundle{
    val wb_req = Flipped(new ValidIO(new Info_writeBack_req))

    val getPut    = new DecoupledIO(new TLBundleA(edge.bundle))
    val access = Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))

    val release_ban = Input(Bool())
    val miss_ban = Output(Bool())
  }
```
