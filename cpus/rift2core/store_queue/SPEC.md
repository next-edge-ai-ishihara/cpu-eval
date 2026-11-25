# Implement `Store_queue`

Implement the complete `Store_queue` class. Preserve the class name and interface shown below.

Return only the complete `class Store_queue` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/Config.scala

```scala
class Rift2330 extends Config((_, _, _) => {
  case RiftParamsKey => RiftSetting(
    hasL2  = true,
    hasDebugger = true,
    hasPreFetch = false,
    hasuBTB = false,
```

## Package and imports

### src/main/scala/rift2Core/backend/LSU/Store_queue.scala

```scala
package rift2Core.backend.lsu

import chisel3._
import chisel3.util._

import rift2Core.define._

import rift2Chip._

import org.chipsalliance.cde.config._
```

## Parent instantiation

### src/main/scala/rift2Core/backend/LSU/Lsu.scala

```scala
  /** when a flush comes, flush all uncommit write & amo request in pending-fifo, and block all request from issue until scoreboard is empty */
  val trans_kill = RegInit(false.B)

  /** decoupled output of addrTrans */
  val addrTransIO = Wire(DecoupledIO(new Lsu_iss_info))

  /** decoupled output of OP_mux */
  val opStIO = Wire(DecoupledIO(new Lsu_iss_info))
  val opLdIO = Wire(DecoupledIO(new Lsu_iss_info))
  val opAmIO = Wire(DecoupledIO(new Lsu_iss_info) )

  /** for store and amo, they should be push into stQueue waiting for commited and pending commit */
  val stQueue = Module(new Store_queue)

  /** Merge the request from 1) opMux (load is bypassing the stQueue) 2) store and amo form stQueue */
  val ls_arb = Module(new Arbiter(new Lsu_iss_info, 2))
// ...
  /** indicate the mem unit is empty by all seq-element is empty*/
  val is_empty = Wire(Bool())
// ...
  stQueue.io.enq.valid := opStIO.fire | opAmIO.fire
  stQueue.io.enq.bits :=
    Mux1H(Seq(
      opStIO.fire -> opStIO.bits,
      opAmIO.fire -> opAmIO.bits,
    ))
  stQueue.io.cmm_lsu := io.cmm_lsu
  io.preFetch := stQueue.io.preFetch
  stQueue.io.flush := io.flush
// ...
  stQueue.io.overlapReq.bits.paddr := opLdIO.bits.param.dat.op1
  stQueue.io.overlapReq.valid := opLdIO.valid

  ls_arb.io.in(0).valid := opLdIO.valid & stQueue.io.overlapResp.valid
  ls_arb.io.in(0).bits := opLdIO.bits
  opLdIO.ready := ls_arb.io.in(0).ready & stQueue.io.overlapResp.valid
  
  ls_arb.io.in(1) <> stQueue.io.deq
// ...
  opStIO.ready := su_wb_fifo.io.enq.ready & stQueue.io.enq.ready
  opAmIO.ready := stQueue.io.enq.ready
// ...
  is_empty := 
    stQueue.io.is_empty & 
```

## Dependency declarations

### src/main/scala/rift2Core/backend/LSU/Store_queue.scala

```scala
abstract class Stq_Base()(implicit p: Parameters) extends DcacheModule{

  def st_w = log2Ceil(stEntry)

  class StqIO extends Bundle{
    val enq = Flipped(DecoupledIO(new Lsu_iss_info))
    val deq = DecoupledIO(new Lsu_iss_info)

    val cmm_lsu = Input(new Info_cmm_lsu)
    val is_empty = Output(Bool())

    val overlapReq  = Flipped(Valid(new Stq_req_Bundle))
    val overlapResp = Valid(new Stq_resp_Bundle)

    val flush = Input(Bool())

    /** prefetch is not guarantee to be accepted by cache*/
    val preFetch = ValidIO( new PreFetch_Req_Bundle )
  }


  val io: StqIO = IO( new StqIO )

  val buff = RegInit(VecInit(Seq.fill(stEntry)(0.U.asTypeOf(new Lsu_iss_info))))
  
  val cm_ptr_reg = RegInit( 0.U((st_w+1).W) )
  val wr_ptr_reg = RegInit( 0.U((st_w+1).W) )
  val rd_ptr_reg = RegInit( 0.U((st_w+1).W) )

  val cm_ptr = cm_ptr_reg(st_w-1,0)
  val wr_ptr = wr_ptr_reg(st_w-1,0)
  val rd_ptr = rd_ptr_reg(st_w-1,0)

  val full = (wr_ptr_reg(st_w) =/= rd_ptr_reg(st_w)) & (wr_ptr_reg(st_w-1,0) === rd_ptr_reg(st_w-1,0))
  val emty = cm_ptr_reg === rd_ptr_reg

  val rd_buff = buff(rd_ptr)

  val is_amo = RegInit(false.B)


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
class Operation_source(dw: Int)(implicit p: Parameters) extends RiftBundle {
  val op0 = UInt(dw.W)
  val op1 = UInt(dw.W)
  val op2 = UInt(dw.W)
  val op3 = UInt(dw.W)
}
// ...
class Lsu_param(implicit p: Parameters) extends RD_PHY {
  val dat    = new Operation_source(dw=64)

  // override def cloneType = ( new Lsu_param ).asInstanceOf[this.type]
}
// ...
class Lsu_iss_info(implicit p: Parameters) extends RiftBundle {
  val fun = new Lsu_isa
  val param = new Lsu_param

  val vAttach = if(hasVector){Some(new VLsu_Attach_Bundle)} else {None}

  def is_misAlign =
    Mux1H( Seq(
      fun.isHalf -> (param.dat.op1(0)   =/= 0.U),
      fun.isWord -> (param.dat.op1(1,0) =/= 0.U),
      fun.isDubl -> (param.dat.op1(2,0) =/= 0.U),
    ) ++
      (if(hasVector){
        Seq(fun.isDynamic -> Mux1H(Seq(
          (vAttach.get.vsew === "b001".U) -> (param.dat.op1(0)   =/= 0.U),
          (vAttach.get.vsew === "b010".U) -> (param.dat.op1(1,0) =/= 0.U),
          (vAttach.get.vsew === "b011".U) -> (param.dat.op1(2,0) =/= 0.U),
      )))} else {Seq()}) 
    )

  def paddr = param.dat.op1

  def wdata_align(dw: Int) = {
      val res = Wire(UInt(dw.W))
      res := param.dat.op2 << ( paddr((log2Ceil(dw/8)-1),0) << 3 )
      res
    }

  def wstrb_align(dw: Int) = {
    val wstrb = Wire(UInt((dw/8).W))
    wstrb := Mux1H(Seq(
        fun.isByte -> "b00000001".U, fun.isHalf -> "b00000011".U,
        fun.isWord -> "b00001111".U, fun.isDubl -> "b11111111".U,
      ) ++
        (if(hasVector){
          Seq(fun.isDynamic -> Mux1H(Seq(
            (vAttach.get.vsew === "b000".U) -> "b00000001".U,
            (vAttach.get.vsew === "b001".U) -> "b00000011".U,
            (vAttach.get.vsew === "b010".U) -> "b00001111".U,
            (vAttach.get.vsew === "b011".U) -> "b11111111".U,
        )))} else {Seq()})
      ) << paddr((log2Ceil(dw/8)-1),0)
    wstrb
  }
}
// ...
class Info_cmm_lsu(implicit p: Parameters) extends RiftBundle {
  // val isVstorePending = Bool()
  val is_amo_pending  = Bool()
  val is_store_commit = Vec(cmChn, Bool())
}
// ...
class Stq_req_Bundle(implicit p: Parameters) extends RiftBundle {
  val paddr = UInt(plen.W)
}

class Stq_resp_Bundle(implicit p: Parameters) extends RiftBundle {
  val wdata = UInt(64.W)
  val wstrb = UInt(8.W)
}
// ...
class PreFetch_Req_Bundle(implicit p: Parameters) extends RiftBundle {
  val paddr = UInt(plen.W)
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
  val CacheMuxBits = pkg_Dcache_Enq_Bundle(regionDCacheIO.bits, stQueue.io.overlapReq.bits, stQueue.io.overlapResp.bits)
```

### src/main/scala/rift2Core/backend/Commit.scala

```scala
  io.cmm_lsu.is_amo_pending := {
    io.rod(0).valid & ( io.rod(0).bits.is_amo | io.rod(0).bits.is_sc) & ~io.xCommit(0).is_writeback //only pending amo in rod0 is send out
  }
// ...
    io.cmm_lsu.is_store_commit(i) := ( io.rod(i).bits.isXFStore & ~io.rod(i).bits.is_sc )& commit_state_is_comfirm(i)
  }
  
```
