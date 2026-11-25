# Implement `DcacheStage`

Implement the complete `DcacheStage` class. Preserve the class name and interface shown below.

Return only the complete `class DcacheStage` definition in a single Scala code block, with no text outside the block.

## Package and imports

### src/main/scala/rift2Core/backend/LSU/DcacheStage.scala

```scala
package rift2Core.backend.lsu

import chisel3._
import chisel3.util._
import chisel3.util.random._

import rift2Chip._
import base._

import org.chipsalliance.cde.config._
```

## Class declaration

### src/main/scala/rift2Core/backend/LSU/DcacheStage.scala

```scala
class DcacheStage(idx: Int)(implicit p: Parameters) extends DcacheStageBase((idx))
```

## Parent instantiation

### src/main/scala/rift2Core/backend/LSU/Dcache.scala

```scala
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
// ...
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
// ...
  if ( hasL2 ) {
    stage.io.missUnit_req      <> missUnit.get.io.req
    stage.io.wb_req <> writeBackUnit.get.io.wb_req
// ...
    rd_arb.io.in(0).bits  := pkg_Dcache_Enq_Bundle( missUnit.get.io.rsp.bits )
    rd_arb.io.in(0).valid := missUnit.get.io.rsp.valid
    missUnit.get.io.rsp.ready := rd_arb.io.in(0).ready

    rd_arb.io.in(1).bits  := pkg_Dcache_Enq_Bundle(probeUnit.get.io.req.bits) 
    rd_arb.io.in(1).valid := probeUnit.get.io.req.valid
    probeUnit.get.io.req.ready := rd_arb.io.in(1).ready
// ...
  } else {
    stage.io.missUnit_req      <> getUnit.get.io.req
    stage.io.wb_req <> putUnit.get.io.wb_req
// ...
    rd_arb.io.in(0).bits  := pkg_Dcache_Enq_Bundle( getUnit.get.io.rsp.bits )
    rd_arb.io.in(0).valid := getUnit.get.io.rsp.valid
    getUnit.get.io.rsp.ready := rd_arb.io.in(0).ready
// ...
  }
// ...
  reload_fifo.io.enq.valid := stage.io.reload.valid
  reload_fifo.io.enq.bits  := stage.io.reload.bits
// ...
  reload_fifo.io.deq <> op_arb.io.in(0)
  io.enq.ready := op_arb.io.in(1).ready & sbEnqReady
  op_arb.io.in(1).valid := io.enq.fire
  op_arb.io.in(1).bits  := io.enq.bits
  op_arb.io.in(1).bits.chkIdx := sbIdx //override
  op_arb.io.out <> lsEntry.io.enq 
// ...
  stage.io.flush := io.flush
// ...
  lsEntry.io.deq <> rd_arb.io.in(2)
  stage.io.enq <> rd_arb.io.out
// ...
  rtn_fifo.io.enq.valid := stage.io.deq.valid
  rtn_fifo.io.enq.bits  := stage.io.deq.bits
// ...
  io.is_empty := isSBEmpty
  stage.io.isCacheEmpty := isSBEmpty
```

## Dependency declarations

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


  val datInfoR = Wire( Vec(cb, Vec(dw/8, UInt(8.W))) )
  val tagInfoR = Wire( Vec(cb, UInt(tag_w.W)) )

  val datInfoWM = Wire( Vec(dw/8, Bool()   ) )
  val datInfoW  = Wire( Vec(dw/8, UInt(8.W)) )

  val tagEnW = Wire( Vec(cb, Bool()) )
  val datEnW = Wire( Vec(cb, Bool()) )

  val datRAM = for ( _ <- 0 until cb ) yield { Module(new DatRAM(dw, cl)) }
  val tagRAM = for ( _ <- 0 until cb ) yield { Module(new TagRAM(tag_w, cl)) }

  val addrSelW = Wire(UInt(line_w.W))
  val addrSelR = Wire(UInt(line_w.W))
  val tagInfoW = Wire(UInt(tag_w.W))


  io.enq.ready := true.B
  val pipeStage1Valid = RegNext(io.enq.fire, false.B)
  val pipeStage1Bits  = RegNext(io.enq.bits)

   /** one hot code indicated which blcok is hit */
  val isHitOH = Wire(Vec(cb, Bool()))
  /** flag that indicated that if there is a cache block hit */
  val isHit = isHitOH.asUInt.orR
  /** when no block is hit or a new grant req comes, we should 1) find out an empty block 2) evict a valid block */
  val rplSel = Wire(UInt( (1 max cb_w).W))
  /** convert one hot hit to UInt */
  val hitSel = WireDefault(OHToUInt(isHitOH))
  val cbSel = Wire(UInt( (1 max cb_w).W))
  /** flag that indicated that if a cache block is valid */
  val isCBValid = RegInit( VecInit( Seq.fill(cl)(VecInit(Seq.fill(cb)(false.B))) ) )
  /** flag that indicated that if a cache block is dirty */
  val isCBDirty = RegInit( VecInit( Seq.fill(cl)(VecInit(Seq.fill(cb)(false.B))) ) )
  
  val is_sc_fail = Wire(Bool())
}
```

### src/main/scala/rift2Core/backend/LSU/Dcache.scala

```scala
/** the operation that dcache support
  * @note Lsu isa
  * @note probe
  * @note grant
  * @note preft
  */
class Cache_op extends Lsu_isa {

  val probe = Bool()
  val grant = Bool()
  val preft = Bool()

  def is_atom = is_amo
  def is_access = is_atom | is_lu | is_su | is_lr | is_sc | isVLoad | isVStore
  def is_tag_r = is_atom | is_lu | is_su | is_lr | is_sc | isVLoad | isVStore | grant | probe | preft
  // def is_dat_r = is_atom | is_lu | isVLoad | is_lr | grant | probe
  def is_tag_w = grant
  def is_dat_w = is_atom | is_su | is_sc | isVStore | grant
  def isDirtyOp = is_atom | is_su | is_sc | isVStore
  def is_wb = is_atom | is_lu | is_lr | is_sc | isVStore

}


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
```

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class Lsu_isa extends Bundle {
  val lb  = Bool()
  val lh  = Bool()
  val lw  = Bool()
  val ld  = Bool()
  val lbu = Bool()
  val lhu = Bool()
  val lwu = Bool()
  val sb  = Bool()
  val sh  = Bool()
  val sw  = Bool()
  val sd  = Bool()
  val fence = Bool()
  val fence_i = Bool()
  val sfence_vma = Bool()

  val lr_w      = Bool()
  val sc_w      = Bool()
  val amoswap_w = Bool()
  val amoadd_w  = Bool()
  val amoxor_w  = Bool()
  val amoand_w  = Bool()
  val amoor_w   = Bool()
  val amomin_w  = Bool()
  val amomax_w  = Bool()
  val amominu_w = Bool()
  val amomaxu_w = Bool()
  val lr_d      = Bool()
  val sc_d      = Bool()
  val amoswap_d = Bool()
  val amoadd_d  = Bool()
  val amoxor_d  = Bool()
  val amoand_d  = Bool()
  val amoor_d   = Bool()
  val amomin_d  = Bool()
  val amomax_d  = Bool()
  val amominu_d = Bool()
  val amomaxu_d = Bool()

  val flw = Bool()
  val fsw = Bool()
  val fld = Bool()
  val fsd = Bool()


  val vle8  = Bool()
  val vle16 = Bool()
  val vle32 = Bool()
  val vle64 = Bool()
  def vle   = vle8 | vle16 | vle32 | vle64

  val vse8  = Bool()
  val vse16 = Bool()
  val vse32 = Bool()
  val vse64 = Bool()
  def vse   = vse8 | vse16 | vse32 | vse64

  val vlm      = Bool()
  val vsm      = Bool()

  val vlse8  = Bool()
  val vlse16 = Bool()
  val vlse32 = Bool()
  val vlse64 = Bool()
  def vlse   = vlse8 | vlse16 | vlse32 | vlse64

  val vsse8  = Bool()
  val vsse16 = Bool()
  val vsse32 = Bool()
  val vsse64 = Bool()
  def vsse   = vsse8 | vsse16 | vsse32 | vsse64

  val vloxei8  = Bool()
  val vloxei16 = Bool()
  val vloxei32 = Bool()
  val vloxei64 = Bool()
  def vloxei   = vloxei8 | vloxei16 | vloxei32 | vloxei64

  val vsoxei8  = Bool()
  val vsoxei16 = Bool()
  val vsoxei32 = Bool()
  val vsoxei64 = Bool()
  def vsoxei   = vsoxei8 | vsoxei16 | vsoxei32 | vsoxei64

  val vlre8  = Bool()
  val vlre16 = Bool()
  val vlre32 = Bool()
  val vlre64 = Bool()
  def vlre   = vlre8 | vlre16 | vlre32 | vlre64

  val vsr    = Bool()

  val vle8ff  = Bool()
  val vle16ff = Bool()
  val vle32ff = Bool()
  val vle64ff = Bool()
  def vleNff  = vle8ff | vle16ff | vle32ff | vle64ff

  def is_sc = sc_d | sc_w
  def is_lr = lr_d | lr_w

  def is_lu  =
    lb | lh | lw | ld | lbu | lhu | lwu | flw | fld | is_lr |
    vle | vlm | vlse | vloxei | vlre | vleNff

  def is_su  =
    sb | sh | sw | sd | fsw | fsd |
    vse | vsm | vsse | vsoxei | vsr

  def is_xls = lb | lh | lw | ld | lbu | lhu | lwu | sb | sh | sw | sd
  def is_lrsc = is_sc | is_lr
  def is_amo =
    amoswap_w | amoadd_w | amoxor_w | amoand_w | amoor_w | amomin_w | amomax_w | amominu_w | amomaxu_w | amoswap_d | amoadd_d | amoxor_d | amoand_d | amoor_d | amomin_d | amomax_d | amominu_d | amomaxu_d 
  def is_fls = flw | fsw | fld | fsd

  def is_vls = vle | vse | vlm | vsm | vlse | vsse | vloxei | vsoxei | vlre | vsr | vleNff


  def is_fence = fence | fence_i | sfence_vma
  def is_lsu = is_xls | is_lrsc | is_amo | is_fls | is_fence | is_vls


  def isByte =
    lb | lbu | sb |
    vle8 | vse8 | vlse8 | vsse8 |  vlre8 | vle8ff |
    vlm | vsm

  def isHalf =
    lh | lhu | sh |
    vle16 | vse16 | vlse16 | vsse16 | vlre16 | vle16ff

  def isWord =
    lw | lwu | sw | amoswap_w | amoadd_w | amoxor_w | amoand_w | amoor_w | amomin_w | amomax_w | amominu_w | amomaxu_w | flw | fsw | lr_w | sc_w |
    vle32 | vse32 | vlse32 | vsse32 | vlre32 | vle32ff
  
  def isDubl =
    ld | lr_d | fld | sd | sc_d | fsd | amoswap_d | amoadd_d | amoxor_d | amoand_d | amoor_d | amomin_d | amomax_d | amominu_d | amomaxu_d |
    vle64 | vse64 | vlse64 | vsse64 | vlre64 | vle64ff |
    vsr

  def isDynamic = vloxei | vsoxei

  def is_usi = lbu | lhu | lwu


  def is_R = is_lu | is_lr | is_amo
  def is_W = is_su | is_sc | is_amo

  def isXLoad  = lb | lh | lw | ld | lbu | lhu | lwu | is_lr
  def isXStore = sb | sh | sw | sd | is_sc

  def isFLoad  = flw | fld
  def isFStore = fsw | fsd

  def isVLoad  = vle | vlm | vlse | vloxei | vlre | vleNff
  def isVStore = vse | vsm | vsse | vsoxei | vsr
  def isVConstant = vlse | vsse
  def isVIndex = vloxei | vsoxei

  def isRS1 = is_xls | is_lrsc | is_amo | is_fence | is_fls | is_vls
  def isRS2 = ((is_xls | is_lrsc | is_amo ) & ~is_lu) | sfence_vma | isVConstant
  def isFS2 = isFStore
  def isVS2 = isVIndex
  def isVS3 = isVStore

  def isXwb =
    lb | lh | lw | ld | lbu | lhu | lwu | sb | sh | sw | sd |
    fence | fence_i | sfence_vma | lr_w | sc_w |
    amoswap_w | amoadd_w | amoxor_w | amoand_w | amoor_w | amomin_w | amomax_w | amominu_w | amomaxu_w |
    lr_d | sc_d | amoswap_d | amoadd_d | amoxor_d | amoand_d | amoor_d | amomin_d | amomax_d | amominu_d | amomaxu_d |
    fsw | fsd



  def isFwb = flw | fld

  def isVwb = is_vls

  def isUnitStride = vle | vse | vlm | vsm | vlre | vsr | vleNff
  def isStridde = vlse | vsse
  def isIndex = vloxei | vsoxei

  def is_fpu = flw | fsw | fld | fsd
  def isVector = is_vls

}
// ...
class RD_PHY(implicit p: Parameters) extends RiftBundle {
  val rd0 = UInt((log2Ceil(maxRegNum)).W)
}
// ...
class WriteBack_info(dw:Int)(implicit p: Parameters) extends RD_PHY {
  val res = UInt(dw.W)
}
```

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

### src/main/scala/rift2Core/backend/LSU/wrtieBackUnit.scala

```scala
class Info_writeBack_req(implicit p: Parameters) extends RiftBundle with HasDcacheParameters{
  val paddr = UInt(plen.W)
  val data = UInt(dw.W)
  val is_releaseData = Bool()
  val is_release = Bool()
  val is_probe = Bool()
  val is_probeData = Bool()

  // assert( PopCount(Cat(is_releaseData, is_release, is_probe, is_probeData)) === 1.U )
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

abstract class DcacheModule(implicit val p: Parameters) extends Module with HasDcacheParameters { def io: Record }
// ...
trait HasRiftParameters {
  implicit val p: Parameters

  val riftSetting = p(RiftParamsKey)

  val ifParams     = riftSetting.ifetchParameters
  val vParams      = riftSetting.vectorParameters
  val icacheParams = riftSetting.icacheParameters
  val dcacheParams = riftSetting.dcacheParameters

  def hasL2  = riftSetting.hasL2
  def hasDebugger = riftSetting.hasDebugger
  def hasPreFetch = riftSetting.hasPreFetch
  def hasuBTB  = riftSetting.hasuBTB
  def hasLRU  = riftSetting.hasLRU
  def hasVector = riftSetting.hasVector

  
  def ftChn = riftSetting.ftChn

  def cmChn = riftSetting.cmChn
  def rnChn = riftSetting.rnChn
  def opChn = riftSetting.opChn
  def wbChn = riftSetting.wbChn

  def xRegNum = riftSetting.xRegNum
  def fRegNum = riftSetting.fRegNum
  def vRegNum = riftSetting.vRegNum
  def maxRegNum = xRegNum max fRegNum max vRegNum

  // def cRegNum = riftSetting.cRegNum

  def pmpNum = riftSetting.pmpNum
  def hpmNum = riftSetting.hpmNum

  def l1DW = riftSetting.l1DW
  def l1BeatBits = riftSetting.l1BeatBits
  def memBeatBits = riftSetting.memBeatBits

  def vlen = riftSetting.vlen
  def plen = riftSetting.plen

  def tlbEntry = riftSetting.tlbEntry

  def dptEntry = riftSetting.dptEntry

  def aluNum = riftSetting.aluNum
  def mulNum = riftSetting.mulNum
  def fpuNum = riftSetting.fpuNum


  def isMinArea = riftSetting.isMinArea
  def isLowPower = riftSetting.isLowPower
}
```

### src/main/scala/base/CacheRAM.scala

```scala
class DatRAM(dw: Int, cl: Int) extends Module {
  // require( dw == 128 )
  // require( cl <= 256 )
  def line_w   = log2Ceil(cl)

  class DatRAMIO extends Bundle{
    val addrr  = Input(UInt(line_w.W))
    val addrw  = Input(UInt(line_w.W))

    val dataw  = Input( Vec( dw/8, UInt(8.W) ) )
    val datawm = Input( Vec( dw/8, Bool()) )

    val datar = Output( Vec( dw/8, UInt(8.W) ) )
    val enw   = Input(Bool())
    val enr   = Input(Bool())    
  }

  val io: DatRAMIO = IO(new DatRAMIO)

  val datMem = SyncReadMem( cl, Vec( dw/8, UInt(8.W) ) )
// ...
}
// ...
class TagRAM(tag_w: Int,  cl: Int) extends Module {
  def line_w   = log2Ceil(cl)

  class TagRAMIO extends Bundle{
    val addrr  = Input(UInt(line_w.W))
    val addrw  = Input(UInt(line_w.W))

    val dataw = Input( UInt(tag_w.W) )
    val datar = Output( UInt(tag_w.W) )
    val enw   = Input(Bool())
    val enr   = Input(Bool())    
  }

  val io: TagRAMIO = IO(new TagRAMIO)

  val tagMem = SyncReadMem( cl, UInt(tag_w.W) )
// ...
}
```

### src/main/scala/base/LRU.scala

```scala
class LRU( cb: Int, cl: Int ) {
  val history =
    for ( _ <- 0 until cl ) yield {
      RegInit( VecInit( Seq.fill(cb){ 0.U(cb.W) } ) )
    }

  def update( cbSel: UInt, clSel: UInt ) = {
    for( i <- 0 until cl ) {
      when( i.U === clSel ) {
        for( j <- 0 until cb ) {
          when( j.U === cbSel ) {
            history(i)(j) := Cat( history(i)(j), 1.U(1.W) )
          } .otherwise {
            history(i)(j) := Cat( history(i)(j), 0.U(1.W) )
          }
        }
      }
    }
  }

  def replace(clSel: UInt): UInt = {
    val historyInCl = 
      // for ( j <- 0 until cb ) yield {
        Mux1H( (0 until cl).map{ i => (clSel === i.U) -> history(i) } )
      // }

    historyInCl.indexWhere( (x:UInt) => (x === 0.U))
  }
}
```

### src/main/scala/rift2Core/backend/LSU/Util.scala

```scala
object Strb2Mask{
  def apply(strb: UInt): UInt = {
    Cat(strb.asBools.map{ x => Fill(8, x) }.reverse)
  } 
}




object overlap_wr{
  def apply( ori: UInt, ori_wstrb: UInt, wdata: UInt, wstrb: UInt): (UInt, UInt) = {
    require( ori.getWidth == wdata.getWidth )
    require( ori_wstrb.getWidth == wstrb.getWidth )

    val wmask = Strb2Mask(wstrb)

    val new_data = (ori & ~wmask) | (wdata & wmask)
    val new_strb = ori_wstrb | wstrb

    return (new_data, new_strb)
  }
}

object get_loadRes{
  def apply( fun: Lsu_isa, vsew: UInt, paddr: UInt, rdata: UInt ) = {
    require( rdata.getWidth == 64 )
    val res = Wire(UInt(64.W))

    def load_byte(is_usi: Bool, rdata: UInt): UInt = Cat( Fill(56, Mux(is_usi, 0.U, rdata(7)) ),  rdata(7,0)  )
    def load_half(is_usi: Bool, rdata: UInt): UInt = Cat( Fill(48, Mux(is_usi, 0.U, rdata(15)) ), rdata(15,0) )
    def load_word(is_usi: Bool, rdata: UInt): UInt = Cat( Fill(32, Mux(is_usi, 0.U, rdata(31)) ), rdata(31,0) )

    val align = reAlign_data( from = 64, to = 8, rdata, paddr )

    res := Mux1H(Seq(
      fun.isByte    -> load_byte(fun.is_usi, align),
      fun.isHalf    -> load_half(fun.is_usi, align),
      fun.isWord    -> load_word(fun.is_usi, align),
      fun.isDubl    -> align,
      fun.isDynamic -> Mux1H(Seq(
                        (vsew === "b000".U) -> load_byte(fun.is_usi, align),
                        (vsew === "b001".U) -> load_half(fun.is_usi, align),
                        (vsew === "b010".U) -> load_word(fun.is_usi, align),
                        (vsew === "b011".U) -> align,
                      ))

    ))  

    res
  }
}

object reAlign_data{
  def apply( from: Int, to: Int, data: UInt, addr: UInt ): UInt = {
    require( isPow2(from) )
    require( isPow2(to) )
    require( data.getWidth == from )
    val from_lsb = log2Ceil(from/8)
    val to_lsb   = log2Ceil(to/8)

    val align_data = Wire(UInt( (to max 64).W ))
    if ( from > to ) {
      align_data := data >> ( addr( from_lsb-1, 0) >> to_lsb << to_lsb << 3 ) 
    } else if ( from < to ) {
      align_data := data << ( addr( to_lsb-1,0 ) >> from_lsb << from_lsb << 3 )
    } else {
      align_data := data
    }
    return align_data
  }
}
```

## Related source code

### src/main/scala/rift2Core/backend/LSU/Lsu.scala

```scala
  def pkg_Dcache_Enq_Bundle( ori: Lsu_iss_info, overlapReq: Stq_req_Bundle, overlapResp: Stq_resp_Bundle)(implicit p: Parameters) = {

    val res = Wire(new Dcache_Enq_Bundle)
    val dw = res.wdata.getWidth

    res.paddr := ori.paddr
    res.wdata := Mux( ori.fun.is_lu, reAlign_data( from = 64, to = dw, data = overlapResp.wdata, addr = overlapReq.paddr ), ori.wdata_align(dw))
    res.wstrb := Mux( ori.fun.is_lu, reAlign_strb( from = 64, to = dw, strb = overlapResp.wstrb, addr = overlapReq.paddr ), ori.wstrb_align(dw))

    {
      res.fun := 0.U.asTypeOf(new Cache_op)
      res.fun.viewAsSupertype(new Lsu_isa) := ori.fun.viewAsSupertype(new Lsu_isa)
    }
    res.rd.rd0 := ori.param.rd0

    res.chkIdx := 0.U

    if( hasVector ){
      res.vAttach.get := ori.vAttach.get
    }

    res
  
  }
// ...
  for ( i <- 0 until bk ) {
    lu_wb_arb.io.in(i).valid := cache(i).io.deq.valid & cache(i).io.deq.bits.is_load_amo
    lu_wb_arb.io.in(i).bits := Mux( lu_wb_arb.io.in(i).valid, cache(i).io.deq.bits, 0.U.asTypeOf(new Dcache_Deq_Bundle) )
    cache(i).io.deq.ready := lu_wb_arb.io.in(i).ready | ~cache(i).io.deq.bits.is_load_amo
    when( cache(i).io.deq.bits.is_load_amo ) { assert(cache(i).io.deq.fire === lu_wb_arb.io.in(i).fire) }
  }
// ...
  lu_wb_fifo.io.enq.valid := lu_wb_arb.io.out.valid & lu_wb_arb.io.out.bits.isXwb & ~trans_kill 
  lu_wb_fifo.io.enq.bits.rd0 := lu_wb_arb.io.out.bits.wb.rd0
  lu_wb_fifo.io.enq.bits.res := lu_wb_arb.io.out.bits.wb.res
  lu_wb_fifo.reset := reset.asBool | io.flush


  flu_wb_fifo.io.enq.valid := lu_wb_arb.io.out.valid & lu_wb_arb.io.out.bits.isFwb & ~trans_kill 
  flu_wb_fifo.io.enq.bits.rd0 := lu_wb_arb.io.out.bits.wb.rd0
  flu_wb_fifo.io.enq.bits.res := 
      Mux1H(Seq(
        lu_wb_arb.io.out.bits.is_flw -> box(recode(lu_wb_arb.io.out.bits.wb.res, 0), FType.D),
        lu_wb_arb.io.out.bits.is_fld -> box(recode(lu_wb_arb.io.out.bits.wb.res, 1), FType.D),
      ))
```

### src/main/scala/rift2Core/backend/LSU/MissUnit.scala

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
// ...
  /** when all missQueue BUFF is in used, miss req will be bypassed */
  val is_missQueue_full = miss_valid.forall( (x:Bool) => (x === true.B) )

  /** select an empty buff to load paddr, except when *buff full* or *can merge* */
  val load_sel = miss_valid.indexWhere( (x:Bool) => (x === false.B) )


  

  /** findout if there is no buff is valid and has the same paddr, or merge it! */
  val is_merge = {
    for ( i <- 0 until dcacheParams.sbEntry ) yield {
      (miss_queue(i).paddr === io.req.bits.paddr) & miss_valid(i) === true.B
    }
  }.reduce(_|_)


  when(io.req.fire) {
    when( ~is_merge & ~is_missQueue_full ) {
      miss_queue(load_sel) := io.req.bits
      miss_valid(load_sel) := true.B      
    }
  }


  // io.req.ready := true.B
  when( io.req.valid ) {
    assert(
      miss_valid.exists((x:Bool) => (x === false.B)) ||
      (miss_queue zip miss_valid).map{ case(a,b) => (a.paddr === io.req.bits.paddr) & b === true.B }.reduce(_|_),
      "Assert Failed at MissUnit, the Miss-Entry is equal to SB-Entry, which hints that missUnit never full!" )
  }
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
  /** a tiny fifo that temporarily store the writeback info from l1cache */
  val wb_fifo = Module(new Queue(new Info_writeBack_req, 2, false, true))

  wb_fifo.io.enq.valid := io.wb_req.valid
  wb_fifo.io.enq.bits  := io.wb_req.bits
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
    Mux1H(Seq(
      wb_fifo.io.deq.bits.is_probe       -> info_probe,
      wb_fifo.io.deq.bits.is_probeData   -> info_probeData,
      wb_fifo.io.deq.bits.is_release     -> info_release,
      wb_fifo.io.deq.bits.is_releaseData -> info_releaseData,
    ))    
// ...
  wb_fifo.io.deq.ready := 
    wb_state_qout =/= 0.U & wb_state_dnxt === 0.U

  io.miss_ban := wb_state_qout === 1.U | wb_state_qout === 2.U | wb_fifo.io.deq.valid



  when( ~wb_fifo.io.enq.ready ) {
    assert(~io.wb_req.valid, "When WriteBack Unit is busy, no new acquire will be emitted, and there is no wb request!")
  }
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

## Documentation

### src/unpriv/zalrsc.adoc

```text
Complex atomic memory operations on a single memory word or doubleword
are performed with the load-reserved (insn:lr[]) and store-conditional (insn:sc[])
instructions. [#norm:lr_w_op]#insn:lr.w[] loads a word from the address in _rs1_, places the
sign-extended value in _rd_, and registers a _reservation set:_ a set of
bytes that subsumes the bytes in the addressed word.# [#norm:sc_w_success]#insn:sc.w[] conditionally
writes a word in _rs2_ to the address in _rs1_: the insn:sc.w[] succeeds only
if the reservation is still valid and the reservation set contains the
bytes being written. If the insn:sc.w[] succeeds, the instruction writes the
word in _rs2_ to memory, and it writes zero to _rd_.# [#norm:sc_w_failure]#If the insn:sc.w[] fails,
the instruction does not write to memory, and it writes a nonzero value
to _rd_.#
[#norm:sc_retire_permission]#No insn:sc.w[] instruction shall retire unless it passes memory permission checks,#
[#norm:sc_failed_side_effects]#but it is UNSPECIFIED whether any side effects of implicit address translation
and protection memory accesses (such as setting a page-table entry D bit)
occur on a failed insn:sc.w[].#
[#norm:sc_failed_as_store]#For the purposes of memory protection, a failed insn:sc.w[] may be
treated like a store.#
[#norm:sc_reservation_invalidate]#Regardless of success or failure, executing an
insn:sc.w[] instruction invalidates any reservation held by this hart.# [#norm:lr_sc_rv64]#insn:lr.d[] and
insn:sc.d[] act analogously on doublewords and are only available on RV64. For
RV64, insn:lr.w[] and insn:sc.w[] sign-extend the value placed in _rd_.#
...
[#norm:sc_failure_code]#The failure code with value 1 encodes an unspecified failure. Other
failure codes are reserved at this time. Portable software should only
assume the failure code will be non-zero.#
...
[#norm:lr_reservation_set_size]#An implementation can register an arbitrarily large reservation set on
each insn:lr[], provided the reservation set includes all bytes of the
addressed data word or doubleword.# [#norm:sc_pairs_latest_lr]#An insn:sc[] can only pair with the most
recent insn:lr[] in program order.# [#norm:sc_success_conditions]#An insn:sc[] may succeed only if no store from
another hart to the reservation set can be observed to have occurred
between the insn:lr[] and the insn:sc[], and if there is no other insn:sc[] between the
insn:lr[] and itself in program order.# [#norm:sc_device_write_failure]#An insn:sc[] may succeed only if no write from a
device other than a hart to the bytes accessed by the insn:lr[] instruction can
be observed to have occurred between the insn:lr[] and insn:sc[].# Note this insn:lr[] might
have had a different effective address and data size, but reserved the
insn:sc[]'s address as part of the reservation set.
...
[#norm:sc_addr_not_in_reservation_fail]#The insn:sc[] must fail if the address is not within the reservation set of the
most recent insn:lr[] in program order.# [#norm:sc_other_hart_store_fail]#The insn:sc[] must fail if a store to the
reservation set from another hart can be observed to occur between the
insn:lr[] and insn:sc[].# [#norm:sc_other_device_write_fail]#The insn:sc[] must fail if a write from some other device to the
bytes accessed by the insn:lr[] can be observed to occur between the insn:lr[] and insn:sc[].#
(If such a device writes the reservation set but does not write the
bytes accessed by the insn:lr[], the insn:sc[] may or may not fail.) [#norm:sc_intervening_sc_fail]#An insn:sc[] must fail
if there is another insn:sc[] (to any address) between the insn:lr[] and the insn:sc[] in
program order.# [#norm:lr_sc_atomicity_axiom]#The precise statement of the atomicity requirements for
successful insn:lr[]/insn:sc[] sequences is defined by the Atomicity Axiom in
<<rvwmo>>.#
```

### src/unpriv/zaamo.adoc

```text
The atomic memory operation (AMO) instructions perform read-modify-write
operations for multiprocessor synchronization and are encoded with an
R-type instruction format. These AMO instructions atomically load a data
value from the address in _rs1_, place the value into register _rd_,
apply a binary operator to the loaded value and the original value in
_rs2_, then store the result back to the original address in _rs1_. [#norm:amo_operand_size]#AMOs
can either operate on _doublewords_ (RV64 only) or _words_ in memory. For
RV64, 32-bit AMOs always sign-extend the value placed in _rd_, and
ignore the upper 32 bits of the original value of _rs2_.#
...
The operations supported are swap, integer add, bitwise AND, bitwise OR,
bitwise XOR, and signed and unsigned integer maximum and minimum.
```
