# Implement `IF3`

Implement the complete `IF3` class. Preserve the class name and interface shown below.

Return only the complete `class IF3` definition in a single Scala code block, with no text outside the block.

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

### src/main/scala/rift2Core/frontend/IF3.scala

```scala
import chisel3._
import chisel3.util._
import chisel3.experimental.dataview._
import org.chipsalliance.cde.config._

import rift2Core.define._
import base._

/**
```

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val if3 = Module(new IF3)
// ...
  if2.io.if2_resp <> if3.io.if3_req
  if3.io.if3_resp <> if4.io.if4_req

  if3.io.btbResp  <> if4.io.btbResp
  if3.io.bimResp  <> if4.io.bimResp
  if3.io.tageResp <> if4.io.tageResp
  
  if3.io.if4_update_ghist := if4.io.if4_update_ghist
  if3.io.if4Redirect := if4.io.if4Redirect
// ...
  if3.io.jcmm_update := exe_stage.io.jcmm_update
  if3.io.bcmm_update := exe_stage.io.bcmm_update
// ...
  if3.io.flush := cmm_stage.io.cmmRedirect.fire
```

## Dependency declarations

### src/main/scala/rift2Core/frontend/IF3.scala

```scala
abstract class IF3Base()(implicit p: Parameters) extends IFetchModule {
  /**
    * @param if3_req a vector of 4 decoupled IF2 bundle input ports for each read channel
    * @param if3_resp a vector of decoupled IF3 bundle output ports for each read channel
    * @param btbResp a vector of decoupled BTBResp_Bundle output ports for each read channel
    * @param bimResp a vector of decoupled BIMResp_Bundle output ports for each read channel
    * @param tageResp a vector of decoupled arrays of 6 TageTableResp_Bundle output ports for each read channel
    * @param jcmm_update a valid Jump_CTarget_Bundle input port for updating the jump prediction
    * @param bcmm_update a valid Branch_CTarget_Bundle input port for updating the branch prediction
    * @param if4_update_ghist a vector of valid Ghist_reflash_Bundle input ports for updating the global history for each read channel
    * @param if4Redirect a valid IF4_Redirect_Bundle input port for redirecting the fetch pipeline to a new address
    * @param flush an input Boolean for flushing the pipeline
    */
  class IF3IO extends Bundle{
    val if3_req = Vec(4, Flipped(new DecoupledIO(new IF2_Bundle) ))
    val if3_resp = Vec(rnChn, Decoupled(new IF3_Bundle))

    val btbResp  = Vec(rnChn, Decoupled(new BTBResp_Bundle))
    val bimResp  = Vec(rnChn, Decoupled(new BIMResp_Bundle))
    val tageResp = Vec(rnChn, Decoupled(Vec(6, new TageTableResp_Bundle )))

    val jcmm_update = Flipped(Valid(new Jump_CTarget_Bundle))
    val bcmm_update = Flipped(Valid(new Branch_CTarget_Bundle))

    val if4_update_ghist = Vec(rnChn, Flipped(Valid(new Ghist_reflash_Bundle)))
    val if4Redirect = Flipped(Valid(new IF4_Redirect_Bundle))

    val flush = Input(Bool())    
  }

  val io: IF3IO = IO(new IF3IO)

  val ghist_snap   = RegInit( 0.U(64.W) )
  val ghist_active = RegInit( 0.U(64.W) )

  val reAlign = Wire(Vec(4, DecoupledIO(new IF3_Bundle)))
  val reAlignPreDecode = Wire( Vec( 4, new PreDecode_Bundle ) )
  val combPDT = Module(new RePort( new IF3_Bundle, 4))

  val pipeLineLock = RegInit(false.B)

  val btb = Module(new BTB)
  val bim = Module(new BIM)
  val tage = Module(new TAGE)

  val btbFifo =  Module(new MultiPortFifo( new BTBResp_Bundle, aw = (if(!isMinArea) 4 else 1), in = 1, out = rnChn, flow = true ) )
  val bimFifo =  Module(new MultiPortFifo( new BIMResp_Bundle, aw = (if(!isMinArea) 4 else 1), in = 1, out = rnChn, flow = true ) )
  val tageFifo = Module(new MultiPortFifo( Vec(6, new TageTableResp_Bundle ), aw = (if(!isMinArea) 4 else 1), in = 1, out = rnChn, flow = true ) )


  val predictor_ready = btb.io.isReady & bim.io.isReady & (if (!isMinArea) { tage.io.isReady } else {true.B})

  val if3_resp_fifo = Module(new MultiPortFifo( new IF3_Bundle, (if(!isMinArea) 4 else 2), 4, rnChn ))

  if3_resp_fifo.io.flush := io.if4Redirect.fire | io.flush
  if3_resp_fifo.io.enq <> combPDT.io.deq
  io.if3_resp <> if3_resp_fifo.io.deq
 
}




// ...
object PreDecode16{
  def apply( instr16: UInt )(implicit p: Parameters): PreDecode_Bundle = {
    require( instr16.getWidth == 16 )

    val info16 = Wire( new PreDecode_Bundle )

    info16.is_rvc := true.B

    info16.is_jal    := (instr16 === BitPat("b101???????????01"))
    info16.is_jalr   := (instr16 === BitPat("b100??????0000010") & instr16(11,7) =/= 0.U)
    info16.is_branch := (instr16 === BitPat("b11????????????01"))
    info16.is_call   := (instr16 === BitPat("b1001?????0000010") & instr16(11,7) =/= 0.U)
    info16.is_return := (instr16 === BitPat("b100000?010000010"))
    info16.is_fencei := false.B
    info16.is_sfencevma := false.B
    info16.imm       :=
      Mux1H( Seq(
        info16.is_jal    -> Cat( Fill(52, instr16(12)), instr16(12), instr16(8), instr16(10,9), instr16(6), instr16(7), instr16(2), instr16(11), instr16(5,3), 0.U(1.W)),
        info16.is_jalr   -> 0.U,
        info16.is_branch -> Cat( Fill(55, instr16(12)), instr16(12), instr16(6,5), instr16(2), instr16(11,10), instr16(4,3), 0.U(1.W))
      ))
    return info16
  }
}


object PreDecode32{
  def apply(instr32: UInt)(implicit p: Parameters): PreDecode_Bundle = {
    require( instr32.getWidth == 32 )

    val info32 = Wire(new PreDecode_Bundle)

    info32.is_rvc := false.B

    info32.is_jal    := (instr32(6,0) === "b1101111".U)
    info32.is_jalr   := (instr32(6,0) === "b1100111".U)
    info32.is_branch := (instr32(6,0) === "b1100011".U)
    info32.is_call   := ( info32.is_jal | info32.is_jalr ) & ( instr32(11,7) === BitPat("b00?01") ) //is 1 or 5
    info32.is_return := info32.is_jalr & ( instr32(19,15) === BitPat("b00?01") ) & (instr32(19,15) =/= instr32(11,7))
    info32.is_fencei := ( instr32 === BitPat("b?????????????????001?????0001111") )
    info32.is_sfencevma := ( instr32 === BitPat("b0001001??????????000000001110011") )
    info32.imm       :=
      Mux1H( Seq(
        info32.is_jal    -> Cat( Fill(44, instr32(31)), instr32(19,12), instr32(20), instr32(30,21), 0.U(1.W) ),
        info32.is_jalr   -> Cat( Fill(52, instr32(31)), instr32(31,20) ),
        info32.is_branch -> Cat( Fill(52, instr32(31)), instr32(7), instr32(30,25), instr32(11,8), 0.U(1.W) )
      ))
    return info32
  }
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
// ...
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

/**
  * This class represents the output bundle for the Pre-Decoder.
  * @param p an implicit parameter of type Parameters, which is used by the Processor's implicit Parameters object.
  */
class PreDecode_Bundle(implicit p: Parameters) extends IFetchBundle {
  /** Indicates if the instruction is a JAL */
  val is_jal = Bool()
  /** Indicates if the instruction is a JALR */
  val is_jalr = Bool()
  /** Indicates if the instruction is a branch instruction */
  val is_branch = Bool()
  /** Indicates if the instruction is a CALL instruction */
  val is_call = Bool()
  /** Indicates if the instruction is a RETURN instruction */
  val is_return = Bool()
  /** Indicates if the instruction is a RISC V Compressed instruction */
  val is_rvc = Bool()
  /** Indicates if the instruction is a instruction fence instruction */
  val is_fencei = Bool()
  /** Indicates if the instruction is an sfencevma instruction */
  val is_sfencevma = Bool()
  /** Represents the immediate value of the instruction */
  val imm = UInt(64.W)

   /** Returns true if the instruction flows will be cut.
     * The instruction flow will be cut if it is a JAL, JALR, Branch, FENCE.I, or SFENCE.VMA instruction.
     */
  def is_pineline_cut = is_jal | is_jalr | is_branch | is_fencei | is_sfencevma

  /** Returns true if BTB request is required */
  def is_req_btb  = is_jalr
  /** Returns true if RAS request is required */
  def is_req_ras  = is_return
  /** Returns true if BIM request is required */
  def is_req_bim  = is_branch
  /** Returns true if TAGE request is required */
  def is_req_tage = is_branch
  /** Returns true if the instruction will lockup the pipeline */
  def is_lock_pipe = is_fencei | is_sfencevma
}

/**
  * Bundle for Bi-Model Predictor requests.
  * @constructor Create a new instance of BIMReq_Bundle.
  * @param p The implicit Parameters object for the processor.
  */
class BIMReq_Bundle(implicit p: Parameters) extends IFetchBundle {
  /** Program Counter. */
  val pc = UInt(vlen.W) 
}

/**
  * Bundle for Bi-Model Predictor respond.
  * @constructor Create a new instance of BIMResp_Bundle.
  * @param p The implicit Parameters object for the processor.
  */
class BIMResp_Bundle(implicit p: Parameters) extends IFetchBundle {
  /** Prediction for Taken or Not-Taken for primary BIM. */
  val bim_p = Bool()
  /** Prediction for Taken or Not-Taken for history BIM. */
  val bim_h = Bool()
}

/**
  * Bundle for Bi-Model Predictor update.
  * @constructor Create a new instance of BIMUpdate_Bundle.
  * @param p The implicit Parameters object for the processor.
  * @extends BIMResp_Bundle
  */
class BIMUpdate_Bundle(implicit p: Parameters) extends BIMResp_Bundle {
  /** Program counter for the instruction should be updated */
  val pc = UInt(vlen.W)
  /** Flag indicating whether the instruction is taken or not taken. */
  val isFinalTaken = Bool()
  
  /** Function to determine whether the branch was mispredicted. */
  def isMisPredict = isFinalTaken =/= bim_p 
}

/** 
  * Bundle for Branch Target Buffer (BTB) request interface.
  * @constructor Create a new instance of BTBReq_Bundle.
  * @param p The implicit Parameters object for the processor.
  * @extends IFetchBundle
  */
class BTBReq_Bundle(implicit p: Parameters) extends IFetchBundle {
  /** Program counter for the requesting instruction. */
  val pc = UInt(vlen.W) 
}

/**
  * Bundle for Micro Branch Target Buffer (uBTB) request interface.
  * @constructor Create a new instance of uBTBReq_Bundle.
  * @param p The implicit Parameters object for the processor.
  * @extends BTBReq_Bundle
  */
class uBTBReq_Bundle(implicit p: Parameters) extends BTBReq_Bundle

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

/**
  * This class represents a bundle for updating the Branch Target Buffer (BTB).
  * @param p implicit parameter of type Parameters.
  */
class BTBUpdate_Bundle(implicit p: Parameters) extends BTBResp_Bundle {
  /** Program counter for the updating instruction. */
  val pc = UInt(vlen.W)
}

/**
  * This class represents a micro-Branch Target Buffer (uBTB) update bundle,
  * which is used to update the BTB on processing branches.
  * It extends the BTBUpdate_Bundle class and contains an additional field isTaken,
  * which is of type Bool and 
  * @param p an implicit parameter of type Parameters, which is used by the Processor's implicit Parameters object.
  */
class uBTBUpdate_Bundle(implicit p: Parameters) extends BTBUpdate_Bundle {
  /** indicates whether a branch is taken or not at the end */
  val isTaken = Bool()
}

class TageTableUpdate_Bundle(implicit p: Parameters) extends IFetchBundle {
  val use   = UInt(2.W)
  val ctl   = UInt(3.W)
  val pc    = UInt(vlen.W)
  val ghist = UInt(64.W)
}

class TageTableReq_Bundle(implicit p: Parameters) extends IFetchBundle {
  val pc = UInt(vlen.W)
  val ghist = UInt(64.W)
}

class TageReq_Bundle(implicit p: Parameters) extends TageTableReq_Bundle


class TageTableResp_Bundle(implicit p: Parameters) extends IFetchBundle {
  val ctl = UInt(3.W)
  val use = UInt(2.W)
  val is_hit = Bool()

  def isTaken = (ctl(2) === 1.U).asBool
}

class TageResp_Bundle(implicit p: Parameters) extends IFetchBundle {

  val ftqTage = Vec( 6, new TageTableResp_Bundle )
  val isProvider = Vec( 6, Bool() )
  val isAltpred  = Vec( 6, Bool() )
  val isPredictTaken = Bool()

  def providerSel = OHToUInt( in = isProvider.asUInt, width = 6)

  def isAgree: Seq[Bool] = {
    for ( i <- 0 until 6 ) yield {
      isAltpred(i) & ftqTage(i).isTaken === isPredictTaken
    }
  }

  def isDisAgree: Seq[Bool] = {
    for ( i <- 0 until 6 ) yield {
      isAltpred(i) & ftqTage(i).isTaken =/= isPredictTaken
    }
  }

  def isAlloc: Seq[Bool] = {
    for ( i <- 0 until 6 ) yield {
      ~isAltpred(i) & ~isProvider(i)
    }
  }
}

class TageUpdate_Bundle(implicit p: Parameters) extends TageResp_Bundle {
  val pc = UInt(vlen.W)
  val ghist = UInt(64.W)
  val isFinalTaken = Bool()

  def isMisPredict = isAlloc.reduce(_|_) & (isPredictTaken =/= isFinalTaken)
}





/**
  * This class represents the output interface for the Instruction Fetch Stage 3.
  * @param p an implicit parameter of type Parameters, which is used by the Processor's implicit Parameters object.
  */
class IF3_Bundle(implicit p: Parameters) extends RiftBundle {
  /* Indicates if the instruction is an RISC V Compressed instruction */
  val isRVC = Bool()
  /* Bundle of Pre-Decode output parameters */
  val preDecode = new PreDecode_Bundle
  // val predict = new Predict_Bundle
  /* the instruction that re-align in IF3 */
  val instr = UInt(32.W)
  /* the Program Counter of the instruction */
  val pc = UInt(vlen.W)
  /* Global History Register */
  val ghist = UInt(64.W)
  /* Indicates if the next instruction is redirected */
  val isRedirect = Bool()
  /* The redirect Target address of the next instruction */
  val target = UInt(vlen.W)
}


/**
 * Represents the output of the fourth stage of the Instruction Fetch (IF4), which finishes the instruction decoding.
 * @param p An implicit parameter of type `Parameters` required by the `Info_instruction` parent class.
 * @note This class inherits from the `Info_instruction` class, which provides all information about the instruction.
 */
// ...
class Branch_FTarget_Bundle(implicit p: Parameters) extends RiftBundle {
  /** Program counter of the branch instruction. */
  val pc = UInt(vlen.W)
  /** Global history register value at the time of the branch. */
  val ghist = UInt(64.W)
  /** Respond of the Bi-Model Predictor */
  val bimResp  = new BIMResp_Bundle
  /** Respond of the TAGE predictor */
  val tageResp = new TageResp_Bundle
  /** Indicates whether the branch is predicted to be taken. */
  val isPredictTaken = Bool()
}

/**
  * Bundle definition for the jump fetch target interface.
  * This bundle represents the information that has been predicted for a jump instruction.
  * @param p the set of parameters defining the RISC-V core
  */
class Jump_FTarget_Bundle(implicit p: Parameters) extends RiftBundle {
  /* Program counter of the jump instruction. */
  val pc       = UInt(vlen.W)
  /* Response of the BTB predictor. */
  val btbResp = new BTBResp_Bundle
  /* Response of the RAS predictor. */
  val rasResp = new RASPP_Bundle
  /* Indicates whether the RAS predictor is being used. */
  val isRas = Bool()

  /** @return true if the BTB predictor is being used, false */
  def isBtb = ~isRas
}

/**
  * Bundle definition for the branch commit target interface.
  * This bundle represents the actual outcome of a branch instruction after execution.
  * @param p the set of parameters defining the RISC-V core
  */
class Branch_CTarget_Bundle(implicit p: Parameters) extends Branch_FTarget_Bundle {
  /** Indicates whether the actual branch outcome is taken or not. */
  val isFinalTaken = Bool()
  /** Actual target address of the branch instruction after execution. */
  val finalTarget = UInt(64.W)

  /** @return true if the actual branch outcome is mispredicted, false otherwise */
  def isMisPredict = isPredictTaken =/= isFinalTaken
}

/**
  * Bundle definition for the jump commit target interface.
  * This bundle represents the actual outcome of a jump instruction after execution.
  * @param p the set of parameters defining the RISC-V core
  */
class Jump_CTarget_Bundle(implicit p: Parameters) extends Jump_FTarget_Bundle {
  /** Actual target address of the jump instruction after execution. */
  val finalTarget = UInt(64.W)

  /** @return true if the actual branch outcome is mispredicted, false otherwise */
  def isMisPredict = Mux(isRas, rasResp.target =/= finalTarget, btbResp.target =/= finalTarget )
}

```

### src/main/scala/rift2Core/frontend/BTB.scala

```scala
class BTB()(implicit p: Parameters) extends IFetchModule {

  class BTBIO extends Bundle{
    val req  = Flipped(Decoupled(new BTBReq_Bundle))
    val resp = Decoupled( new BTBResp_Bundle )

    val update = Flipped(Valid(new BTBUpdate_Bundle))

    val isReady = Output(Bool())
    val flush = Input(Bool())    
  }

  val io: BTBIO = IO(new BTBIO)
```

### src/main/scala/rift2Core/frontend/BIM.scala

```scala
class BIM()(implicit p: Parameters) extends IFetchModule {

  class BIMIO extends Bundle{
    val req  = Flipped(Decoupled(new BIMReq_Bundle))
    val resp = Decoupled(new BIMResp_Bundle)
    val update   = Flipped(Valid(new BIMUpdate_Bundle))

    val isReady = Output(Bool())
    val flush    = Input(Bool())
  }

  val io: BIMIO = IO(new BIMIO)
```

### src/main/scala/rift2Core/frontend/TAGE.scala

```scala


class TAGE(param: TageParams = TageParams())(implicit p: Parameters) extends IFetchModule {

  class TAGEIO extends Bundle{
    val req = Flipped(Decoupled(new TageReq_Bundle))
    val resp = Decoupled( Vec(6, new TageTableResp_Bundle ) )
    val update = Flipped(Valid(new TageUpdate_Bundle))

    val isReady = Output(Bool())
    val flush = Input(Bool())    
  }
```

### src/main/scala/base/RePort.scala

```scala
class RePort[T<:Data]( dw: T, port: Int) extends Module{

  class RePortIO extends Bundle{
    val enq = Vec(port, Flipped(new DecoupledIO(dw)) )
    val deq  = Vec(port, new DecoupledIO(dw) )
  }

  val io: RePortIO = IO( new RePortIO)
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

### src/main/scala/Parameters.scala

```scala
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
