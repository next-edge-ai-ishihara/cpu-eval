# Implement `IF2`

Implement the complete `IF2` class. Preserve the class name and interface shown below.

Return only the complete `class IF2` definition in a single Scala code block, with no text outside the block.

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

### src/main/scala/rift2Core/frontend/IF2.scala

```scala
package rift2Core.frontend

import chisel3._
import chisel3.util._
import chisel3.util.random._

import rift2Chip._
import base._

import rift2Core.define._
import rift2Core.privilege._

import org.chipsalliance.cde.config._
import freechips.rocketchip.tilelink._
```

## Class declaration

### src/main/scala/rift2Core/frontend/IF2.scala

```scala
class IF2(edge: TLEdgeOut)(implicit p: Parameters) extends IF2Base(edge)
```

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val ( icache_bus, icache_edge ) = outer.icacheClientNode.out.head
// ...
  val if2 = Module(new IF2(icache_edge))
// ...
  if1.io.pc_gen <> if2.io.if2_req
  if2.io.if2_resp <> if3.io.if3_req
// ...
  if2.io.icache_access.bits := icache_bus.d.bits
  if2.io.icache_access.valid := icache_bus.d.valid
  icache_bus.d.ready := if2.io.icache_access.ready

  icache_bus.a.valid := if2.io.icache_get.valid
  icache_bus.a.bits := if2.io.icache_get.bits
  if2.io.icache_get.ready := icache_bus.a.ready
// ...
  prefetcher.io.icacheRefillReq := if2.io.preFetch
// ...
  i_mmu.io.if_mmu <> if2.io.if_mmu
  i_mmu.io.mmu_if <> if2.io.mmu_if
// ...
  cmm_stage.io.if_cmm := if2.io.if_cmm
// ...
  if2.io.ifence := cmm_stage.io.ifence
// ...
  if2.io.flush := cmm_stage.io.cmmRedirect.fire | if4.io.if4Redirect.valid
```

## Dependency declarations

### src/main/scala/rift2Core/frontend/IF2.scala

```scala
abstract class IF2Base(edge: TLEdgeOut)(implicit p: Parameters) extends IcacheModule {
  val iEdge = edge

  /**
   * @constructor Create a new IF2IO bundle instance with the following signals:
   * @param if2_req a Flipped (input) DecoupledIO bundle of type IF1_Bundle used to receive instruction fetch requests from IF1 stage
   * @param if2_resp a vector of 4 DecoupledIO bundles of type IF2_Bundle used to send instruction fetch responses to IF3 stage
   * @param if_mmu a DecoupledIO bundle of type Info_mmu_req used to address translation requests to MMU
   * @param mmu_if a Flipped (input) DecoupledIO bundle of type Info_mmu_rsp used to receive MMU responses
   * @param if_cmm an Output bundle of type Info_if_cmm used to provide information to CMM stage about IF stage status
   * @param icache_get a DecoupledIO bundle of type TLBundleA from instruction cache which used to request data
   * @param icache_access a Flipped DecoupledIO bundle of type TLBundleD from instruction cache which used to receive data 
   * @param flush an Input boolean used to signal the IF2 stage to flush the pipeline
   * @param ifence an Input boolean used to signal that an instruction fetch fence should be inserted
   * @param preFetch a ValidIO bundle of type PreFetch_Req_Bundle used for requesting data prefetching
   */
  class IF2IO extends Bundle{
    val if2_req  = Flipped(new DecoupledIO( new IF1_Bundle ))
    val if2_resp = Vec( 4, new DecoupledIO(new IF2_Bundle) )

    val if_mmu = DecoupledIO(new Info_mmu_req)
    val mmu_if = Flipped(DecoupledIO(new Info_mmu_rsp))

    val if_cmm = Output(new Info_if_cmm)

    val icache_get    = new DecoupledIO(new TLBundleA(iEdge.bundle))
    val icache_access = Flipped(new DecoupledIO(new TLBundleD(iEdge.bundle)))

    val flush = Input(Bool())

    val ifence = Input(Bool())

    /** prefetch is not guarantee to be accepted by cache*/
    val preFetch = ValidIO( new PreFetch_Req_Bundle )    
  }

  val io: IF2IO = IO(new IF2IO)

  /** Count the memory transactions using TLEdgeOut object. */
  val (_, _, is_trans_done, transCnt) = iEdge.count(io.icache_access)
  val icache_access_data = Wire(UInt(dw.W))
  val icache_sramrd_data = Wire(UInt(dw.W))
  val icache_access_data_lo = Reg( Vec((dw/l1BeatBits-1), UInt(l1BeatBits.W) ))
  val kill_trans = RegInit(false.B)

  val ibuf = Module(new MultiPortFifo( new IF2_Bundle, aw= (if (!isMinArea) 6 else log2Ceil(2*ftChn)), in=ftChn, out=4 ) )
  ibuf.io.flush := io.flush
  io.if2_resp <> ibuf.io.deq

  val cl_sel = io.mmu_if.bits.paddr(addr_lsb+line_w-1, addr_lsb)
  val tag_sel = io.mmu_if.bits.paddr(plen-1,plen-tag_w)

  /** one hot code indicated which blcok is hit */
  val is_hit_oh = Wire(Vec(cb, Bool()))

  /** flag that indicated that if there is a cache block hit */
  val is_hit = is_hit_oh.asUInt.orR

  /** convert one hot hit to UInt */
  val hit_sel = WireDefault(OHToUInt(is_hit_oh))







  val icache_state_dnxt = Wire(UInt(4.W))
  val icache_state_qout = RegNext( icache_state_dnxt, 0.U )

  val fault_lock = RegInit( false.B )
  val is_access_fault = Wire(Bool())
  val is_paging_fault = Wire(Bool())
}

trait IF2MMU { this: IF2Base =>
  io.if_mmu.valid := io.if2_req.valid
  io.if_mmu.bits.vaddr := io.if2_req.bits.pc
  io.if_mmu.bits.is_R := true.B
  io.if_mmu.bits.is_W := false.B
  io.if_mmu.bits.is_X := true.B
  io.if2_req.ready := io.if_mmu.ready

  io.mmu_if.ready := ibuf.io.enq(0).fire & ~fault_lock & ~io.mmu_if.bits.is_fault
}

trait IF2Fault { this: IF2Base =>
  is_access_fault := io.mmu_if.valid & io.mmu_if.bits.is_access_fault
  is_paging_fault := io.mmu_if.valid & io.mmu_if.bits.is_paging_fault

  when( io.flush ) { fault_lock := false.B }
  .elsewhen( io.mmu_if.valid & io.mmu_if.bits.is_fault & ~io.flush & ibuf.io.enq(0).fire ) { fault_lock := true.B }
  // val fault_push = io.mmu_if.valid & io.mmu_if.bits.is_fault & ~io.flush & ibuf.io.enq(7).ready
  assert( ~(is_access_fault & is_paging_fault) )

  io.if_cmm.ill_vaddr := io.mmu_if.bits.vaddr
  // io.if_cmm.is_access_fault := is_access_fault
  // io.if_cmm.is_paging_fault := is_paging_fault
}
```

### src/main/scala/Parameters.scala

```scala
trait HasIcacheParameters extends HasRiftParameters {
  val icacheParams: IcacheParameters

  def dw = l1DW
  def bk = icacheParams.bk
  def cb = icacheParams.cb
  def cl = icacheParams.cl


  def addr_lsb = log2Ceil(dw/8)
  def line_w   = log2Ceil(cl)
  def cb_w = log2Ceil(cb)

  // require( (addr_lsb + line_w) == 12 )
  require( bk == 1 )
 
  def tag_w    = plen - addr_lsb - line_w
}

case class IcacheParameters(
  bk: Int = 1,
  cb: Int = 4,
  cl: Int = 128,
)

abstract class IcacheModule(implicit val p: Parameters) extends Module with HasIcacheParameters { def io: Record }
abstract class IcacheBundle(implicit val p: Parameters) extends Bundle with HasIcacheParameters
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

### src/main/scala/rift2Core/define/frontend.scala

```scala
case class IFParameters(
  uBTB_entry: Int = 16,
  uBTB_tag_w: Int = 8,
  btb_cl: Int = 4096,
  bim_cl: Int = 4096,
  ras_dp: Int = 256,
  tage_table: Int = 6, 
)

trait HasIFParameters extends HasRiftParameters {
  val ifParams: IFParameters

  def uBTB_entry: Int = ifParams.uBTB_entry
  def uBTB_tag_w: Int = ifParams.uBTB_tag_w
  def btb_cl: Int = ifParams.btb_cl
  def bim_cl: Int = ifParams.bim_cl
  def ras_dp: Int = ifParams.ras_dp
  def tage_table: Int = ifParams.tage_table
}

abstract class IFetchModule(implicit p: Parameters) extends RiftModule with HasIFParameters
abstract class IFetchBundle(implicit p: Parameters) extends RiftBundle with HasIFParameters
// ...
class IF1_Bundle(implicit p: Parameters) extends uBTBResp_Bundle {
  /** a UInt indicating the program counter value for the following instructions to be fetched from the cache. */
  val pc = UInt(64.W)
  // val BHR  = UInt(64.W)
}

/**
  * This class represents the output bundle for the Instruction Fetch Stage 2 (IF2)
  * @param p an implicit parameter of type Parameters, which is used by the Processor's implicit Parameters object.
  */
class IF2_Bundle(implicit p: Parameters) extends IFetchBundle {
  /** indicates the program counter value for the instructions has been fetched */
  val pc    = UInt(vlen.W)
  /** the fetched instruction */
  val instr = UInt(16.W)
  // val isAccessFault = Bool()
  // val isPagingFault = Bool()
  // val BHR  = UInt(64.W)
  /** indicates if there's a fault while fetching the instruction */
  val isFault = Bool()
  /** indicates if there was a redirect record at this instruction (from uBTB in IF1) */
  val isRedirect = Bool()
  /** indicates the target address if there was a redirect. Else it is DontCare */
  val target = UInt(vlen.W)
}
// ...
class BTBResp_Bundle(implicit p: Parameters) extends IFetchBundle {
  /** given out the target Program counter */
  val target = UInt(vlen.W) 
}

/**
  * Bundle for Micro Branch Target Buffer (uBTB) response interface. Inherits from BTBResp_Bundle.
  * @constructor Create a new instance of uBTBResp_Bundle.
  * @param p The implicit Parameters object for the processor.
  * @extends BTBResp_Bundle
  */
class uBTBResp_Bundle(implicit p: Parameters) extends BTBResp_Bundle {
  /** The isRedirect vector indicates whether a redirect should be taken at each slot. */
  val isRedirect = Vec( ftChn, Bool() )
  /** The isActive vector indicates whether the instruction should be consider at each slot. */
  val isActive   = Vec( ftChn, Bool() )
}
```

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class PreFetch_Req_Bundle(implicit p: Parameters) extends RiftBundle {
  val paddr = UInt(plen.W)
}


class Info_if_cmm(implicit p: Parameters) extends RiftBundle {
  val ill_vaddr = UInt(64.W)
}
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
```

### src/main/scala/base/MultiPortFifo.scala

```scala
//dw:data type aw:address width, in: input port num, out: output port num 

class MultiPortFifo[T<:Data]( dw: T, aw: Int, in: Int, out: Int, flow: Boolean = false )(implicit p: Parameters) extends RiftModule{
  class MultiPortFifoIO extends Bundle{
    val enq = Vec(in, Flipped(new DecoupledIO(dw)) )
    val deq  = Vec(out, new DecoupledIO(dw) )

    val flush = Input(Bool())
  }
  val io: MultiPortFifoIO = IO(new MultiPortFifoIO)
// ...
    for ( i <- 0 until in; j <- 0 until in )
      assert( !(io.enq(i).valid === true.B && io.enq(j).valid === false.B && i.U >= j.U), "Assert Fail! in port illegal")

    for ( i <- 0 until out; j <- 0 until out )
      assert( !(io.deq(i).valid === true.B && io.deq(j).valid === false.B && i.U >= j.U), "Assert Fail! out port illegal")

    for ( i <- 0 until in ) {
      when( io.enq(i).fire ) {
        for ( j <- 0 until i ) {
          assert( io.enq(j).fire, "Assert Failed, illegal multi-port-fifo behavior" )
        }
      }
    }
```

## Related source code

### src/main/scala/rift2Core/privilege/MMU.scala

```scala
  io.if_mmu.ready :=
    io.mmu_if.fire & ~io.if_flush & ~kill_iptw
// ...
    io.mmu_if.bits.vaddr := ivaddr      
    io.mmu_if.bits.paddr := ipaddr
// ...
    io.mmu_if.valid :=
      ~kill_iptw & (
        (io.if_mmu.valid & is_bypass_if) |
        (io.if_mmu.valid & itlb.io.is_hit) |
        (io.if_mmu.valid & (iptw.io.ptw_o.bits.is_X & iptw.io.ptw_o.valid))         
      )
```

### src/main/scala/rift2Core/frontend/Decoder.scala

```scala
  info.privil_isa.is_access_fault := ( x === BitPat("b1001110001000001") )
  info.privil_isa.is_paging_fault := ( x === BitPat("b1001110001000101") )
```
