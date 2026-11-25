# Implement `IF1NPredict`

Implement the complete `IF1NPredict` class. Preserve the class name and interface shown below.

Return only the complete `class IF1NPredict` definition in a single Scala code block, with no text outside the block.

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

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val if1 = (if (hasuBTB) {Module(new IF1Predict)} else {Module(new IF1NPredict)})
// ...
  if1.io.if4Redirect := if4.io.if4Redirect
// ...
  if1.io.pc_gen <> if2.io.if2_req
// ...
  cmm_stage.io.cmmRedirect <> if1.io.cmmRedirect
```

## Dependency declarations

### src/main/scala/rift2Core/frontend/IF1.scala

```scala
/**
  * instract fetch stage 1, generate pc
  */
abstract class IF1Base()(implicit p: Parameters) extends IFetchModule {

  /**
    * @constructor Create a new IF1IO bundle instance with the following signals:
    * @param if4Redirect a Flipped (input) Valid bundle of type IF4_Redirect_Bundle used to handle instruction fetch pipeline redirection from IF4
    * @param cmmRedirect a Flipped (input) Valid bundle of type Commit_Redirect_Bundle used to handle instruction fetch pipeline redirection from Commit
    * @param pc_gen a Decoupled (in/out) bundle of type IF1_Bundle used to generate program counter addresses to if2
    * @param jcmm_update a Flipped (input) Valid bundle of type Jump_CTarget_Bundle used to handle updates to jump targets for the CPU
    * @param bcmm_update a Flipped (input) Valid bundle of type Branch_CTarget_Bundle used to handle updates to branch targets for the CPU
    */
  class IF1IO extends Bundle{
    val if4Redirect = Flipped(Valid(new IF4_Redirect_Bundle))
    val cmmRedirect = Flipped(Valid(new Commit_Redirect_Bundle))

    val pc_gen = Decoupled(new IF1_Bundle)

    val jcmm_update = Flipped(Valid(new Jump_CTarget_Bundle))
    val bcmm_update = Flipped(Valid(new Branch_CTarget_Bundle))    
  }


  val io: IF1IO = IO(new IF1IO)

  val pc_qout = RegInit("h80000000".U(64.W))
}
```

### src/main/scala/rift2Core/define/frontend.scala

```scala
abstract class IFetchModule(implicit p: Parameters) extends RiftModule with HasIFParameters
abstract class IFetchBundle(implicit p: Parameters) extends RiftBundle with HasIFParameters

class Ghist_reflash_Bundle(implicit p: Parameters) extends IFetchBundle {
  val isTaken = Bool()
}

/**
  * This class represents the output bundle for the Redirect Request Interface from Instruction
  * Fetch Stage-4. It extends the IFetchBundle class and contains additional fields
  * @param p an implicit parameter of type Parameters, which is used by the Processor's implicit Parameters object.
  */
class IF4_Redirect_Bundle(implicit p: Parameters) extends IFetchBundle {
  /** a UInt indicating the target address for redirect, which predicted at IF4*/
  val target     = UInt(vlen.W)
  /** a UInt indicating the current program counter */
  val pc         = UInt(vlen.W)
  /** a Bool indicating whether the current branch prediction(at IF4) disagrees with the actual branch outcome(at IF1)*/
  val isDisAgree = Bool()
}


/**
  * This class represents the bundle for Return Address Stack Pop/Push Interface from Instruction Fetch
  * @param p an implicit parameter of type Parameters, which is used by the Processor's implicit Parameters object.
  */ 
class RASPP_Bundle(implicit p: Parameters) extends IFetchBundle {
  /** a UInt indicating the target address for pop/push operation on the Return Address Stack */
  val target = UInt(vlen.W)
}



/**
  * This class represents the output bundle for the Instruction Fetch Stage 1 (IF1) of the Processor. It extends the uBTBResp_Bundle
  * and contains an additional field
  * @param p an implicit parameter of type Parameters, which is used by the Processor's implicit Parameters object.
  */
class IF1_Bundle(implicit p: Parameters) extends uBTBResp_Bundle {
  /** a UInt indicating the program counter value for the following instructions to be fetched from the cache. */
  val pc = UInt(64.W)
  // val BHR  = UInt(64.W)
}
// ...
/**
  * Bundle for Branch Target Buffer (BTB) response interface.
  * @constructor Create a new instance of BTBResp_Bundle.
  * @param p The implicit Parameters object for the processor.
  * @extends IFetchBundle
  */
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
class Commit_Redirect_Bundle(implicit p: Parameters) extends RiftBundle{
  val pc = UInt(64.W)
}
```

### src/main/scala/base/Util.scala

```scala
object extVaddr{
  def apply(vaddr: UInt, vlen: Int): UInt = {
    require(vaddr.getWidth == vlen)
    val v64 = Wire(UInt(64.W))

    v64 := Cat( Fill(25, vaddr(vlen-1)), vaddr(vlen-1, 0) )
    return v64
  }  
}
```

### src/main/scala/Parameters.scala

```scala
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
// ...
  def vlen = riftSetting.vlen
// ...
```

## Related source code

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
// ...
  for( i <- 0 until ftChn ) yield {
// ...
    if(hasuBTB) {
      ibuf.io.enq(i).bits.isRedirect := io.if2_req.bits.isRedirect(i)
      ibuf.io.enq(i).bits.target := Mux( io.if2_req.bits.isRedirect(i), io.if2_req.bits.target, 0.U )      
    } else {
      ibuf.io.enq(i).bits.isRedirect := false.B
      ibuf.io.enq(i).bits.target := 0.U
    }
  }
// ...
  ibuf.io.enq(0).valid :=
    (~kill_trans & io.mmu_if.valid & icache_state_qout =/= 0.U & icache_state_dnxt === 0.U & ibuf.io.enq(ftChn-1).ready & ( io.mmu_if.bits.paddr((log2Ceil(ftChn*16/8)-1),1) <= (ftChn-1).U ) & io.if2_req.bits.isActive(0)) |
    (~kill_trans & io.mmu_if.valid & io.mmu_if.bits.is_fault & ~fault_lock)

  for ( i <- 1 until ftChn ) {
    ibuf.io.enq(i).valid := ~kill_trans & io.mmu_if.valid & icache_state_qout =/= 0.U & icache_state_dnxt === 0.U & ibuf.io.enq(ftChn-1).ready & ( io.mmu_if.bits.paddr((log2Ceil(ftChn*16/8)-1),1) <= (ftChn-1-i).U )  & io.if2_req.bits.isActive(i)
  }
```
