# Implement `WriteBackUnit`

Implement the complete `WriteBackUnit` class. Preserve the class name and interface shown below.

Return only the complete `class WriteBackUnit` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

```scala
class Rift2330 extends Config((_, _, _) => {
  case RiftParamsKey => RiftSetting(
    // ...
    l1BeatBits = 64,
    // ...
    l1DW = 128,
    // ...
  )
})
```

## Class declaration

```scala
/**
  * a writeBack Unit accept data and paddr from l1cache and write it back to l2cache Probe-Release-Mode
  */
class WriteBackUnit(edge: TLEdgeOut, setting: Int, id: Int)(implicit p: Parameters) extends RiftModule with HasDcacheParameters{

  class WriteBackUnitIO extends Bundle{
    val wb_req = Flipped(new ValidIO(new Info_writeBack_req))

    val cache_release = new DecoupledIO(new TLBundleC(edge.bundle))
    val cache_grant   = Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))


    val release_ban = Input(Bool())
    val miss_ban = Output(Bool())    
  }

  val io: WriteBackUnitIO = IO(new WriteBackUnitIO)
```

## Parent instantiation

### src/main/scala/rift2Core/backend/LSU/Dcache.scala

```scala
  val missUnit      = if( hasL2 ) Some(Module(new MissUnit(edge = edge, setting = 2, id = id)))      else {None}
  val probeUnit     = if( hasL2 ) Some(Module(new ProbeUnit(edge = edge)))                  else {None}
  val writeBackUnit = if( hasL2 ) Some(Module(new WriteBackUnit(edge = edge, setting = 2, id = id))) else {None}
// ...
  if ( hasL2 ) {
    stage.io.missUnit_req      <> missUnit.get.io.req
    stage.io.wb_req <> writeBackUnit.get.io.wb_req
  
    probeUnit.get.io.probeBan := writeBackUnit.get.io.miss_ban
    missUnit.get.io.miss_ban  := writeBackUnit.get.io.miss_ban
    writeBackUnit.get.io.release_ban := missUnit.get.io.release_ban
    // ...
  } else {
    // ...
  }
```

## Dependency declarations

### src/main/scala/rift2Core/backend/LSU/wrtieBackUnit.scala

```scala
/** the operation infomation of writeback Unit */
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

### src/main/scala/tilelink/Edges.scala

```scala
class TLEdgeOut(
  client:  TLClientPortParameters,
  manager: TLManagerPortParameters,
  params:  Parameters,
  sourceInfo: SourceInfo)
  extends TLEdge(client, manager, params, sourceInfo)
{
  // ...
  def Release(fromSource: UInt, toAddress: UInt, lgSize: UInt, shrinkPermissions: UInt): (Bool, TLBundleC) = {
    require (manager.anySupportAcquireB, s"TileLink: No managers visible from this edge support Acquires, but one of these clients would try to request one: ${client.clients}")
    val legal = manager.supportsAcquireBFast(toAddress, lgSize)
    val c = Wire(new TLBundleC(bundle))
    c :#= DontCare
    c.opcode  := TLMessages.Release
    c.param   := shrinkPermissions
    c.size    := lgSize
    c.source  := fromSource
    c.address := toAddress
    c.data    := 0.U
    c.corrupt := false.B
    (legal, c)
  }

  def Release(fromSource: UInt, toAddress: UInt, lgSize: UInt, shrinkPermissions: UInt, data: UInt, corrupt: Bool): (Bool, TLBundleC) = {
    require (manager.anySupportAcquireB, s"TileLink: No managers visible from this edge support Acquires, but one of these clients would try to request one: ${client.clients}")
    val legal = manager.supportsAcquireBFast(toAddress, lgSize)
    val c = Wire(new TLBundleC(bundle))
    c :#= DontCare
    c.opcode  := TLMessages.ReleaseData
    c.param   := shrinkPermissions
    c.size    := lgSize
    c.source  := fromSource
    c.address := toAddress
    c.data    := data
    c.corrupt := corrupt
    (legal, c)
  }

  def Release(fromSource: UInt, toAddress: UInt, lgSize: UInt, shrinkPermissions: UInt, data: UInt): (Bool, TLBundleC) =
    Release(fromSource, toAddress, lgSize, shrinkPermissions, data, false.B)

  def ProbeAck(b: TLBundleB, reportPermissions: UInt): TLBundleC =
    ProbeAck(b.source, b.address, b.size, reportPermissions)

  def ProbeAck(fromSource: UInt, toAddress: UInt, lgSize: UInt, reportPermissions: UInt): TLBundleC = {
    val c = Wire(new TLBundleC(bundle))
    c :#= DontCare
    c.opcode  := TLMessages.ProbeAck
    c.param   := reportPermissions
    c.size    := lgSize
    c.source  := fromSource
    c.address := toAddress
    c.data    := 0.U
    c.corrupt := false.B
    c
  }

  def ProbeAck(b: TLBundleB, reportPermissions: UInt, data: UInt): TLBundleC =
    ProbeAck(b.source, b.address, b.size, reportPermissions, data)

  def ProbeAck(fromSource: UInt, toAddress: UInt, lgSize: UInt, reportPermissions: UInt, data: UInt, corrupt: Bool): TLBundleC = {
    val c = Wire(new TLBundleC(bundle))
    c :#= DontCare
    c.opcode  := TLMessages.ProbeAckData
    c.param   := reportPermissions
    c.size    := lgSize
    c.source  := fromSource
    c.address := toAddress
    c.data    := data
    c.corrupt := corrupt
    c
  }

  def ProbeAck(fromSource: UInt, toAddress: UInt, lgSize: UInt, reportPermissions: UInt, data: UInt): TLBundleC =
    ProbeAck(fromSource, toAddress, lgSize, reportPermissions, data, false.B)
  // ...
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
  def isGrow(x: UInt) = x <= BtoT

  // Shrink types (ProbeAck, Release)
  def TtoB = 0.U(cWidth.W)
  def TtoN = 1.U(cWidth.W)
  def BtoN = 2.U(cWidth.W)
  def isShrink(x: UInt) = x <= BtoN

  // Report types (ProbeAck, Release)
  def TtoT = 3.U(cWidth.W)
  def BtoB = 4.U(cWidth.W)
  def NtoN = 5.U(cWidth.W)
  def isReport(x: UInt) = x <= NtoN

  def PermMsgGrow:Seq[String] = Seq("Grow NtoB", "Grow NtoT", "Grow BtoT")
  def PermMsgCap:Seq[String] = Seq("Cap toT", "Cap toB", "Cap toN")
  def PermMsgReport:Seq[String] = Seq("Shrink TtoB", "Shrink TtoN", "Shrink BtoN", "Report TotT", "Report BtoB", "Report NtoN")
  def PermMsgReserved:Seq[String] = Seq("Reserved")
}
```

## Related source code

### src/main/scala/rift2Core/backend/LSU/MissUnit.scala

```scala
class MissUnit(edge: TLEdgeOut, setting: Int, id: Int)(implicit p: Parameters) extends RiftModule with HasDcacheParameters{
  // ...
  mshr_state_dnxt := 
    Mux1H(Seq(
      (mshr_state_qout === 0.U) -> Mux(miss_valid.contains(true.B) & ~io.miss_ban, 1.U, 0.U) ,//cfree
      (mshr_state_qout === 1.U) -> Mux(io.cache_acquire.fire, 2.U, 1.U),//acquire
      (mshr_state_qout === 2.U) -> Mux(is_trans_done, 3.U, 2.U),//grant
      (mshr_state_qout === 3.U) -> Mux(io.cache_grantAck.fire, 0.U, 3.U)//grantack
    ))

  when( mshr_state_qout === 0.U & mshr_state_dnxt === 1.U ) {
    cache_acquire_vaild := true.B
  } .elsewhen( io.cache_acquire.fire ) {
    cache_acquire_vaild := false.B
    assert(mshr_state_qout === 1.U)
  }

  io.cache_acquire.bits := {
    def permit: UInt = {
      var res = 0.U
      if ( setting == 0 ) {
        res = TLPermissions.NtoB
      } else if ( setting == 2 ) {
        res = TLPermissions.NtoT
      }
      res
    }


    edge.AcquireBlock(
      fromSource = id.U,
      toAddress = miss_queue(acquire_sel).paddr & ("hFFFFFFFF".U << log2Ceil(dw/8).U),
      lgSize = log2Ceil(dw/8).U,
      growPermissions = permit

    )._2
  }

  

  cache_grant_ready := (mshr_state_qout === 2.U)
  // ...
  io.release_ban := mshr_state_dnxt === 2.U | mshr_state_qout === 2.U
  // ...
}
```
