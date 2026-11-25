# Implement `Lsu`

Implement the complete `Lsu` class. Preserve the class name and interface shown below.

Return only the complete `class Lsu` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/Config.scala

```scala
class Rift2330 extends Config((_, _, _) => {
  case RiftParamsKey => RiftSetting(
    hasL2  = true,
    hasDebugger = true,
    hasPreFetch = false,
    hasuBTB = false,

    ftChn = 4,

    rnChn = 2,
    opChn = 2,
    wbChn = 2,
    cmChn = 2,

    pmpNum = 0,
    hpmNum  = 0,

    xRegNum = 34,
    fRegNum = 34,
    vRegNum = 34,

    l1BeatBits = 64,
    memBeatBits = 64,

    tlbEntry = 2,

    ifetchParameters = IFParameters(
      uBTB_entry = 8,

      btb_cl = 4,
      bim_cl = 8,
      ras_dp = 4,
    ),

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

    dptEntry = 4,

    isMinArea = true,
    isLowPower = false,
  )
})
```

## Package and imports

### src/main/scala/rift2Core/backend/LSU/Lsu.scala

```scala
package rift2Core.backend.lsu

import chisel3._
import chisel3.util._

import rift2Core.define._
import rift2Chip._

import rift2Core.privilege._
import rift2Core.backend._

import org.chipsalliance.cde.config._
import freechips.rocketchip.tilelink._
import chisel3.experimental.dataview._
```

## Class declaration

### src/main/scala/rift2Core/backend/LSU/Lsu.scala

```scala
class Lsu(edge: Seq[TLEdgeOut])(implicit p: Parameters) extends LsuBase(edge)
```

## Parent instantiation

### src/main/scala/rift2Core/backend/Execute.scala

```scala
  val lsu = {
    val mdl = Module(new Lsu((edge)))

    mdl.io.lsu_iss_exe <> io.lsu_iss_exe
    mdl.io.lsu_exe_iwb <> io.lsu_exe_iwb
    mdl.io.lsu_exe_fwb <> io.lsu_exe_fwb
    mdl.io.lsu_exe_vwb <> io.lsu_exe_vwb


    mdl.io.lsu_mmu <> io.lsu_mmu
    mdl.io.mmu_lsu <> io.mmu_lsu

    mdl.io.cmm_lsu <> io.cmm_lsu

    if ( hasL2 ) {
      io.missUnit_dcache_acquire.get.valid := mdl.io.missUnit_dcache_acquire.get.valid
      io.missUnit_dcache_acquire.get.bits  := mdl.io.missUnit_dcache_acquire.get.bits
      mdl.io.missUnit_dcache_acquire.get.ready := io.missUnit_dcache_acquire.get.ready

      mdl.io.missUnit_dcache_grant.get.valid := io.missUnit_dcache_grant.get.valid
      mdl.io.missUnit_dcache_grant.get.bits  := io.missUnit_dcache_grant.get.bits
      io.missUnit_dcache_grant.get.ready := mdl.io.missUnit_dcache_grant.get.ready

      io.missUnit_dcache_grantAck.get.valid := mdl.io.missUnit_dcache_grantAck.get.valid
      io.missUnit_dcache_grantAck.get.bits := mdl.io.missUnit_dcache_grantAck.get.bits
      mdl.io.missUnit_dcache_grantAck.get.ready := io.missUnit_dcache_grantAck.get.ready

      mdl.io.probeUnit_dcache_probe.get.valid := io.probeUnit_dcache_probe.get.valid
      mdl.io.probeUnit_dcache_probe.get.bits := io.probeUnit_dcache_probe.get.bits
      io.probeUnit_dcache_probe.get.ready := mdl.io.probeUnit_dcache_probe.get.ready

      io.writeBackUnit_dcache_release.get.valid := mdl.io.writeBackUnit_dcache_release.get.valid
      io.writeBackUnit_dcache_release.get.bits := mdl.io.writeBackUnit_dcache_release.get.bits
      mdl.io.writeBackUnit_dcache_release.get.ready := io.writeBackUnit_dcache_release.get.ready

      mdl.io.writeBackUnit_dcache_grant.get.valid := io.writeBackUnit_dcache_grant.get.valid
      mdl.io.writeBackUnit_dcache_grant.get.bits := io.writeBackUnit_dcache_grant.get.bits
      io.writeBackUnit_dcache_grant.get.ready := mdl.io.writeBackUnit_dcache_grant.get.ready      
    } else {
      io.dcache_getPut.get.valid := mdl.io.dcache_getPut.get.valid
      io.dcache_getPut.get.bits  := mdl.io.dcache_getPut.get.bits
      mdl.io.dcache_getPut.get.ready := io.dcache_getPut.get.ready

      mdl.io.dcache_access.get.valid := io.dcache_access.get.valid
      mdl.io.dcache_access.get.bits  := io.dcache_access.get.bits
      io.dcache_access.get.ready := mdl.io.dcache_access.get.ready
    }
   


    io.system_getPut.valid := mdl.io.system_getPut.valid
    io.system_getPut.bits := mdl.io.system_getPut.bits
    mdl.io.system_getPut.ready := io.system_getPut.ready
    mdl.io.system_access.valid := io.system_access.valid
    mdl.io.system_access.bits := io.system_access.bits
    io.system_access.ready := mdl.io.system_access.ready

    io.periph_getPut.valid := mdl.io.periph_getPut.valid
    io.periph_getPut.bits := mdl.io.periph_getPut.bits
    mdl.io.periph_getPut.ready := io.periph_getPut.ready
    mdl.io.periph_access.valid := io.periph_access.valid
    mdl.io.periph_access.bits := io.periph_access.bits
    io.periph_access.ready := mdl.io.periph_access.ready

    io.preFetch := mdl.io.preFetch

    io.lsu_cmm := mdl.io.lsu_cmm
    // mdl.io.lsu_cWriteBack <> io.cWriteBack(1)

    mdl.io.flush := io.flush
    mdl
```

## Dependency declarations

### src/main/scala/rift2Core/backend/LSU/Lsu.scala

```scala
abstract class LsuBase (edge: Seq[TLEdgeOut])(implicit p: Parameters) extends DcacheModule with HasFPUParameters {
  val dEdge = edge

  class LsuIO extends Bundle{
    val lsu_iss_exe = Flipped(Decoupled(new Lsu_iss_info))
    val lsu_exe_iwb = Decoupled(new WriteBack_info(dw=64))
    val lsu_exe_fwb = Decoupled(new WriteBack_info(dw=65))
    val lsu_exe_vwb = Decoupled(new Vector_WriteBack_Bundle)

            // val lsu_cWriteBack = Valid(new SeqReg_WriteBack_Bundle(64, cRegNum))

    val cmm_lsu = Input(new Info_cmm_lsu)
    val lsu_cmm = Output( new Info_lsu_cmm )

    val lsu_mmu = DecoupledIO(new Info_mmu_req)
    val mmu_lsu = Flipped(DecoupledIO(new Info_mmu_rsp))

    val missUnit_dcache_acquire      = if( hasL2 ) Some(new DecoupledIO(new TLBundleA(dEdge(0).bundle)))          else {None}
    val missUnit_dcache_grant        = if( hasL2 ) Some(Flipped(new DecoupledIO(new TLBundleD(dEdge(0).bundle)))) else {None}
    val missUnit_dcache_grantAck     = if( hasL2 ) Some(DecoupledIO(new TLBundleE(dEdge(0).bundle)))              else {None}
    val probeUnit_dcache_probe       = if( hasL2 ) Some(Flipped(new DecoupledIO(new TLBundleB(dEdge(0).bundle)))) else {None}
    val writeBackUnit_dcache_release = if( hasL2 ) Some(new DecoupledIO(new TLBundleC(dEdge(0).bundle))         ) else {None}
    val writeBackUnit_dcache_grant   = if( hasL2 ) Some(Flipped(new DecoupledIO(new TLBundleD(dEdge(0).bundle)))) else {None}

    val dcache_getPut = if ( hasL2 ) { None } else { Some(        new DecoupledIO(new TLBundleA(dEdge(0).bundle)) ) }
    val dcache_access = if ( hasL2 ) { None } else { Some(Flipped(new DecoupledIO(new TLBundleD(dEdge(0).bundle)))) }


    val system_getPut = new DecoupledIO(new TLBundleA(dEdge(1).bundle))
    val system_access = Flipped(new DecoupledIO(new TLBundleD(dEdge(1).bundle)))

    val periph_getPut = new DecoupledIO(new TLBundleA(dEdge(2).bundle))
    val periph_access = Flipped(new DecoupledIO(new TLBundleD(dEdge(2).bundle)))

    val preFetch = ValidIO( new PreFetch_Req_Bundle )

    val flush = Input(Bool())    
  }


  val io: LsuIO = IO(new LsuIO)

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

  val regionDCacheIO = Wire(DecoupledIO(new Lsu_iss_info) )
  val regionSystemIO = Wire(DecoupledIO(new Lsu_iss_info) )
  val regionPeriphIO = Wire(DecoupledIO(new Lsu_iss_info) )

  val cacheBankIO = Wire( Vec( bk, DecoupledIO(new Dcache_Enq_Bundle) ) )

  val system = Module(new IO_Lsu(dEdge(2)))
  val periph = Module(new IO_Lsu(dEdge(1)))
  val cache = for ( i <- 0 until bk ) yield { val mdl = Module(new Dcache(dEdge(0), i)); mdl }

  /** the load-and-amo operation write-back info from cache or bus
    * @param enq Vec[Dcache_Deq_Bundle]
    * @return Dcache_Deq_Bundle
    */
  val lu_wb_arb = Module(new Arbiter(new Dcache_Deq_Bundle, bk+2))

  /** the load-and-amo write-back fifo, flow !!!!!
    * @note when trans_kill, the load result will be abort here to prevent write-back
    * @param in Dcache_Deq_Bundle
    * @return WriteBack_info 
    */
  val lu_wb_fifo = Module( new Queue( new WriteBack_info(dw=64), 1, false, true ) )

  val flu_wb_fifo = Module( new Queue( new WriteBack_info(dw=65), 1, false, true ) )

  /** store operations will write-back dircetly from opMux, flow !!!!!
    * @param in Lsu_iss_info
    * @return WriteBack_info
    */
  val su_wb_fifo = Module( new Queue( new WriteBack_info(dw=64), 1, false, true ) )
  val fe_wb_fifo = Module( new Queue( new WriteBack_info(dw=64), 1, false, true ) )

  val vls_wb_fifo = Module( new Queue( new Vector_WriteBack_Bundle, 1, false, true ) )


  /** merge lu-writeback and su-writeback
    * @param in WriteBack_info
    * @return WriteBack_info
    */
  val irtn_arb = Module(new Arbiter( new WriteBack_info(dw=64), 4))
  val frtn_arb = Module(new Arbiter( new WriteBack_info(dw=65), 2))
  val vrtn_arb = Module(new Arbiter( new Vector_WriteBack_Bundle, 2))

  /** indicate the mem unit is empty by all seq-element is empty*/
  val is_empty = Wire(Bool())



  /** package write and amo operation*/
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
class RS_RAW(implicit p: Parameters) extends RiftBundle {
  val vm0 = UInt((log2Ceil(32)).W)
  val rs1 = UInt((log2Ceil(32)).W)
  val rs2 = UInt((log2Ceil(32)).W)
  val rs3 = UInt((log2Ceil(32)).W)

}

class RS_PHY(implicit p: Parameters) extends RiftBundle {
  val vm0 = UInt((log2Ceil(maxRegNum)).W)
  val rs1 = UInt((log2Ceil(maxRegNum)).W)
  val rs2 = UInt((log2Ceil(maxRegNum)).W)
  val rs3 = UInt((log2Ceil(maxRegNum)).W)
}

class RD_RAW(implicit p: Parameters) extends RiftBundle {
  val rd0 = UInt((log2Ceil(32)).W)
}

class RD_PHY(implicit p: Parameters) extends RiftBundle {
  val rd0 = UInt((log2Ceil(maxRegNum)).W)
}

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
class WriteBack_info(dw:Int)(implicit p: Parameters) extends RD_PHY {
  val res = UInt(dw.W)
}



// ...
class Info_cmm_lsu(implicit p: Parameters) extends RiftBundle {
  // val isVstorePending = Bool()
  val is_amo_pending  = Bool()
  val is_store_commit = Vec(cmChn, Bool())
}

class Info_lsu_cmm(implicit p: Parameters) extends RiftBundle {
  val is_access_fault = Bool()
  val is_paging_fault = Bool()
  val is_misAlign = Bool()
  val trap_addr = UInt(64.W)
}

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

### src/main/scala/rift2Core/backend/LSU/Dcache.scala

```scala
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
```

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

### src/main/scala/rift2Core/backend/LSU/IO_Lsu.scala

```scala
class IO_Lsu(edge: TLEdgeOut)(implicit p: Parameters) extends RiftModule{

  class IOLSUIO extends Bundle{
    val enq = Flipped(new DecoupledIO(new Lsu_iss_info))
    val deq = new DecoupledIO(new Dcache_Deq_Bundle)
    val is_empty = Output(Bool())

    val getPut    = new DecoupledIO(new TLBundleA(edge.bundle))
    val access = Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))

    // val flush = Input(Bool())    
  }
  val io: IOLSUIO = IO(new IOLSUIO)
```

### src/main/scala/rift2Core/privilege/MMU.scala

```scala
trait Info_access_lvl extends Bundle {
  val is_X = Bool()
  val is_W = Bool()
  val is_R = Bool()
}


class Info_mmu_req(implicit p: Parameters) extends RiftBundle with Info_access_lvl{
  val vaddr = UInt(64.W)
}



class Info_mmu_rsp(implicit p: Parameters) extends RiftBundle {
  val vaddr  = UInt(64.W)
  val paddr  = UInt(64.W)
  val is_paging_fault = Bool()
  val is_access_fault = Bool()

  def is_fault = is_access_fault | is_paging_fault
}
```

### src/main/scala/rift2Core/vector/VRegfiles.scala

```scala
class Vector_WriteBack_Bundle()(implicit p: Parameters) extends WriteBack_info(dw = 64) {
  require( vParams.elen <= 64 )
  val eleIdx = UInt( (log2Ceil(vParams.vlen/8)).W )

  val isException = Bool()
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
abstract class DcacheBundle(implicit val p: Parameters) extends Bundle with HasDcacheParameters
// ...
case class RiftSetting(

  hasL2: Boolean = true,
  hasDebugger: Boolean = true,
  hasPreFetch: Boolean = false,
  hasuBTB: Boolean = true,
  hasLRU: Boolean = false,
  hasVector: Boolean = false,


  isMinArea: Boolean = false,
  isLowPower: Boolean = false,

  ftChn: Int = 8, //fetch width
  rnChn: Int = 2,
  cmChn: Int = 2,
  opChn: Int = 4,
  wbChn: Int = 4,

  xRegNum: Int = 64,
  fRegNum: Int = 64,
  vRegNum: Int = 64,
  // cRegNum: Int = 8,

  pmpNum: Int = 1,
  hpmNum: Int = 4,

  l1BeatBits: Int = 128,
  memBeatBits: Int = 128,

  vlen: Int = 39,
  plen: Int = 32,

  tlbEntry: Int = 16, 
  ifetchParameters: IFParameters = IFParameters(
    uBTB_entry = 16,
    uBTB_tag_w = 16,
    btb_cl = 4096,
    bim_cl = 4096,
    ras_dp = 256,
    tage_table = 6, 
  ),

  l1DW: Int = 256,

  dptEntry: Int = 16,

  aluNum: Int = 2,
  mulNum: Int = 1,
  fpuNum: Int = 0,

  vectorParameters: VectorParameters = VectorParameters(),


  icacheParameters: IcacheParameters = IcacheParameters(
    bk = 1,
    cb = 4,
    cl = 256
  ),
  dcacheParameters: DcacheParameters = DcacheParameters(
    bk = 8,
    cb = 8,
    cl = 256,
    stEntry = 16,
    sbEntry = 16,
  ),
){
  require( icacheParameters.bk == 1 )
  require( log2Ceil( ifetchParameters.uBTB_entry ) <= ifetchParameters.uBTB_tag_w )
  require( vlen == 39 )
  require( plen >=32 && plen <= 56 )
  require( memBeatBits <= l1BeatBits )
  //require( opChn % 2 == 0 )
  require( xRegNum > 33 & fRegNum > 33 && vRegNum > 33)
  require( pmpNum >= 0 && pmpNum <= 8 )
  require( isPow2(dcacheParameters.stEntry) )
  require( isPow2(ftChn) )
  require( aluNum > 0 )
  require( dptEntry >= 1 )


  if(hasVector){
    // require( rnChn >= 2 )
    require( fpuNum > 0 )
    require( dcacheParameters.stEntry >= vectorParameters.vlen/8, "Error! VStore will be stuck at Store Queue!" )
  }
}
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

## Related source code

### src/main/scala/rift2Core/privilege/MMU.scala

```scala
  io.lsu_mmu.ready :=
    io.mmu_lsu.fire & ~io.lsu_flush & ~kill_dptw

  assert( io.lsu_mmu.fire === io.mmu_lsu.fire )
// ...
    val dpaddr = Mux( is_bypass_ls, dvaddr, v2paddr( dvaddr, pte ) )
  
// ...

    io.mmu_lsu.valid :=
      ~io.lsu_flush & ~kill_dptw & (
        (io.lsu_mmu.valid & is_bypass_ls) |
        (io.lsu_mmu.valid & dtlb.io.is_hit) |
        (io.lsu_mmu.valid & (~dptw.io.ptw_o.bits.is_X & dptw.io.ptw_o.valid))           
```

### src/main/scala/rift2Core/backend/LSU/Store_queue.scala

```scala
    io.overlapResp.valid := io.overlapReq.valid //may be overlapped
```

### src/main/scala/rift2Core/backend/Commit.scala

```scala
  def is_load_accessFault: Bool = {
    val is_load_accessFault = 
      lsu_cmm.is_access_fault & (
        (rod.is_lu & is_wb) | (rod.isVLoad & isVException & ~(rod.isFoF & exceptionIdx =/= 0.U) )
      )

    return is_load_accessFault
  }

  def is_store_accessFault: Bool = {
    val is_store_accessFault =
      lsu_cmm.is_access_fault & (
        ( ( rod.isXFStore | rod.is_amo ) & is_wb ) | (rod.isVStore & isVException)
      )

    return is_store_accessFault
  }

  def is_load_pagingFault: Bool = {
    val is_load_pagingFault =
      lsu_cmm.is_paging_fault & (
        ( rod.is_lu & is_wb ) | (rod.isVLoad & isVException & ~(rod.isFoF & exceptionIdx =/= 0.U) )
      )

    return is_load_pagingFault
  }

  def is_store_pagingFault: Bool = {
    val is_store_pagingFault =
      lsu_cmm.is_paging_fault & (
        (( rod.isXFStore | rod.is_amo ) & is_wb) | (rod.isVStore & isVException)
      )

    return is_store_pagingFault
  }

  def is_load_misAlign: Bool = {
    val is_load_misAlign =
      lsu_cmm.is_misAlign & (
        ( rod.is_lu & is_wb ) | (rod.isVLoad & isVException & ~(rod.isFoF & exceptionIdx =/= 0.U) )
      )

    return is_load_misAlign
  }

  def is_instr_misAlign: Bool = {
    return false.B
  }

  def is_store_misAlign: Bool = {
    val is_store_misAlign =
      lsu_cmm.is_misAlign & (
        ( (rod.isXFStore | rod.is_amo) & is_wb ) | (rod.isVStore & isVException)
      )

    return is_store_misAlign
  }
```

### src/main/scala/rift2Chip/Rift2Chip.scala

```scala
  val memRange = AddressSet(0x00000000L, 0xffffffffL).subtract(AddressSet(0x0L, 0x7fffffffL))
// ...
  val sysRange = AddressSet(0x00000000L, 0x7fffffffL).subtract(AddressSet(0x00000000L, 0x1fffffffL))
```
