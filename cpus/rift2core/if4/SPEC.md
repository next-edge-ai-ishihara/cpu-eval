# Implement `IF4`

Implement the complete `IF4` class. Preserve the class name and interface shown below.

Return only the complete `class IF4` definition in a single Scala code block, with no text outside the block.

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

### src/main/scala/rift2Core/frontend/IF4.scala

```scala
package rift2Core.frontend

import chisel3._
import chisel3.util._
import rift2Core.define._
import org.chipsalliance.cde.config._
import base._
```

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val if4 = Module(new IF4)
// ...
  val exe_stage = Module(new Execute( (Seq( dcache_edge, system_edge, periph_edge ) ) ) )
// ...
  if1.io.if4Redirect := if4.io.if4Redirect
// ...
  if3.io.if3_resp <> if4.io.if4_req

  if3.io.btbResp  <> if4.io.btbResp
  if3.io.bimResp  <> if4.io.bimResp
  if3.io.tageResp <> if4.io.tageResp
  
  if3.io.if4_update_ghist := if4.io.if4_update_ghist
  if3.io.if4Redirect := if4.io.if4Redirect
// ...
  if4.io.if4_resp <> preRename_stage.io.enq
// ...
  if4.io.jcmm_update := exe_stage.io.jcmm_update
// ...
  exe_stage.io.bftq <> if4.io.bftq
  exe_stage.io.jftq <> if4.io.jftq
// ...
  i_mmu.io.if_flush  := cmm_stage.io.cmmRedirect.fire | if4.io.if4Redirect.valid
// ...
  if2.io.flush := cmm_stage.io.cmmRedirect.fire | if4.io.if4Redirect.valid
// ...
  if4.io.flush := cmm_stage.io.cmmRedirect.fire
```

## Dependency declarations

### src/main/scala/rift2Core/frontend/IF4.scala

```scala
abstract class IF4Base()(implicit p: Parameters) extends IFetchModule {


  /** 
    * A class representing input and output data for the IF4 stage of a processor pipeline.
    * @param if4_req A vector of "IF3_Bundle" objects representing input requests for the IF4 stage
    * @param btbResp A vector of "BTBResp_Bundle" objects representing BTB response data
    * @param bimResp A vector of "BIMResp_Bundle" objects representing BIM response data
    * @param tageResp A vector of "TageTableResp_Bundle" objects representing TAGE table response data
    * @param if4_resp A vector of "IF4_Bundle" objects representing output response data from the IF4 stage
    * @param if4_update_ghist A vector of "Ghist_reflash_Bundle" objects representing requests to update the global history table
    * @param if4Redirect A signal indicating whether the perivious stage should redirect instructions
    * @param jcmm_update A signal from backend containing updated data for a jump target
    * @param bftq A queue for branch target data
    * @param jftq A queue for jump target data
    * @param flush A boolean input that can be used to clear the pipeline
    */
  class IF4IO extends Bundle{
    val if4_req  = Vec(rnChn, Flipped(Decoupled(new IF3_Bundle)))
    val btbResp  = Vec(rnChn, Flipped(Decoupled(new BTBResp_Bundle)))
    val bimResp  = Vec(rnChn, Flipped(Decoupled(new BIMResp_Bundle)))
    val tageResp = Vec(rnChn, Flipped(Decoupled(Vec(6, new TageTableResp_Bundle ))))

    val if4_resp = Vec(rnChn, Decoupled(new IF4_Bundle))

    val if4_update_ghist = Vec(rnChn, Valid(new Ghist_reflash_Bundle))
    val if4Redirect = Valid(new IF4_Redirect_Bundle)

    val jcmm_update = Flipped(Valid(new Jump_CTarget_Bundle))

    val bftq = Decoupled(new Branch_FTarget_Bundle)
    val jftq = Decoupled(new Jump_FTarget_Bundle)

    val flush = Input(Bool())    
  }

  val io: IF4IO = IO(new IF4IO)

  val ras = Module(new RAS)
  val instr_fifo = Module(new MultiPortFifo( new IF4_Bundle, (if(!isMinArea) 4 else 1), rnChn, rnChn ))
  val bftq = Module(new MultiPortFifo( dw = new Branch_FTarget_Bundle, (if(!isMinArea) 4 else 1), rnChn, 1 ))
  val jftq = Module(new MultiPortFifo( dw = new Jump_FTarget_Bundle,   (if(!isMinArea) 4 else 1), rnChn, 1 ))


  val bRePort = Module(new RePort( new Branch_FTarget_Bundle, port = rnChn) )
  val jRePort = Module(new RePort( new Jump_FTarget_Bundle,   port = rnChn) )

  val preDecodeAgn = io.if4_req.map{ x => Mux(x.bits.isRVC, PreDecode16(x.bits.instr(15,0)), PreDecode32(x.bits.instr) ) }


  val is_jal       = preDecodeAgn.map{_.is_jal}
  val is_jalr      = preDecodeAgn.map{_.is_jalr}
  val is_branch    = preDecodeAgn.map{_.is_branch}
  val is_call      = preDecodeAgn.map{_.is_call}
  val is_return    = preDecodeAgn.map{_.is_return}
  val is_rvc       = io.if4_req.map{_.bits.isRVC}
  val is_fencei    = preDecodeAgn.map{_.is_fencei}
  val is_sfencevma = preDecodeAgn.map{_.is_sfencevma}
  val pc           = io.if4_req.map{_.bits.pc}
  val ghist        = if (!isMinArea) { io.if4_req.map{_.bits.ghist} } else { io.if4_req.map{_ => 0.U(64.W)} }
  val imm          = preDecodeAgn.map{_.imm}

  val is_req_btb   = (if ( btb_cl != 0 ) {preDecodeAgn.map{ _.is_req_btb}} else {preDecodeAgn.map{_ => false.B}})
  val is_req_bim   = preDecodeAgn.map{ _.is_req_bim}
  val is_req_tage  = if (false) { preDecodeAgn.map{ _.is_req_tage} } else {io.if4_req.map{ _ => false.B}}


  val tageRedirect = ReDirect(io.tageResp, VecInit(is_req_tage) )
  val bimRedirect  = ReDirect(io.bimResp,  VecInit(is_req_bim ) )
  val btbRedirect  = ReDirect(io.btbResp,  VecInit(is_req_btb ) )


  val tage_decode = tageRedirect.map{ x => Tage_Decode(x.bits)}
  val bim_decode  = bimRedirect.map{ _.bits}
  val btb_decode  = btbRedirect.map{ _.bits}

}
```

### src/main/scala/rift2Core/frontend/Decoder.scala

```scala
object Decode16 {
  /**
    * Decodes the 16-bit instruction using the given input signals and parameters.
    * @param x The 16-bit instruction to decode, taken as input of type UInt.
    * @param pc The current program counter, taken as input of type UInt.
    * @param hasFpu A boolean flag indicating whether the instruction includes a floating point unit.
    * @return Returns the decoded instruction as an instance of the Info_instruction class.
    */
  def apply(x:UInt, pc: UInt, hasFpu: Boolean)(implicit p: Parameters): Info_instruction = {
    // val info = Wire(new Info_instruction)
    val dec16 = Module(new Decode16 with NVDecode)
    dec16.io.x := x
    dec16.io.pc := pc
    return dec16.io.info
  }
}
// ...
object Decode32 {
  /**
    * Decodes the given 32-bit RISC-V instruction.
    *
    * @param x The 32-bit instruction to be decoded.
    * @param pc The program counter for the instruction.
    * @param hasFpu Indicates whether or not the processor has a floating point unit.
    * @param p The implicit Parameters object for the Rift2Core.
    * @return An Info_instruction object representing the decoded instruction.
    */
  def apply(x:UInt, pc: UInt, hasFpu: Boolean, hasVector: Boolean)(implicit p: Parameters): Info_instruction = {
    // val info = Wire(new Info_instruction)
    val dec32 = Module( (if(hasVector) {new Decode32 with VDecode32} else {new Decode32 with NVDecode}) )
    dec32.io.x := x
    dec32.io.pc := pc
    return dec32.io.info
  }
}
```

### src/main/scala/rift2Core/frontend/RAS.scala

```scala
class RAS()(implicit p: Parameters) extends IFetchModule {

  class RASIO extends Bundle{
    val enq = Flipped(Valid(new RASPP_Bundle))
    val deq  = new DecoupledIO(new RASPP_Bundle)

    // flush when RAS mis-predict
    val flush = Input(Bool())    
  }

  val io: RASIO = IO(new RASIO)

```

### src/main/scala/base/RePort.scala

```scala
class RePort[T<:Data]( dw: T, port: Int) extends Module{

  class RePortIO extends Bundle{
    val enq = Vec(port, Flipped(new DecoupledIO(dw)) )
    val deq  = Vec(port, new DecoupledIO(dw) )
  }

  val io: RePortIO = IO( new RePortIO)
// ...
object RePort{
  def apply[T <: Data]( enq: Vec[DecoupledIO[T]] ): Vec[DecoupledIO[T]] = {
    val mdl = Module(new RePort( chiselTypeOf(enq(0).bits), enq.length ))
    enq <> mdl.io.enq
    return mdl.io.deq
  }
}

class ReDirect[T<:Data]( dw: T, port: Int) extends Module{

  class ReDirectIO extends Bundle{
    val enq = Vec(port, Flipped(new DecoupledIO(dw)) )
    val deq  = Vec(port, new DecoupledIO(dw) )
    val mapper = Input(Vec(port, Bool()))    
  }

  val io: ReDirectIO = IO( new ReDirectIO)

// ...
object ReDirect{
  def apply[T <: Data]( enq: Vec[DecoupledIO[T]], mapper: Vec[Bool] ): Vec[DecoupledIO[T]] = {
    require( enq.length == mapper.length )
    val mdl = Module(new ReDirect( chiselTypeOf(enq(0).bits), enq.length ))
    mdl.io.mapper := mapper
    enq <> mdl.io.enq
    return mdl.io.deq
  }
}

```

### src/main/scala/rift2Core/frontend/TAGE.scala

```scala
object Tage_Decode{
  def apply( in: Vec[TageTableResp_Bundle] )(implicit p: Parameters): TageResp_Bundle = {
    require( in.length == 6 )
    val resp = Wire(new TageResp_Bundle)
    val isTableSel = in.map{ x => (x.use =/= 0.U & x.is_hit) }

    // set is_provider by override
    for( i <- 0 until 6 ) yield {
      when( isTableSel(i) ) {
        resp.isProvider(i) := true.B
        for( j <- 0 until i ) yield {
          resp.isProvider(j) := false.B
        }
      } .otherwise { resp.isProvider(i) := false.B }
    }

    for( i <- 0 until 6 ) yield {
      resp.isAltpred(i) := isTableSel(i) & ~resp.isProvider(i)
    }

    resp.isPredictTaken := PriorityMux(isTableSel.reverse, in.map{ _.isTaken }.reverse )
    for( i <- 0 until 6 ) yield { resp.ftqTage(i) := in(i) }


    for ( i <- 0 until 6 ) yield {
      assert( resp.isAltpred(i) === (resp.isProvider(i) ^ isTableSel(i)) )
    }
    assert( PopCount( resp.isProvider ) <= 1.U )

    return resp
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
class IF4_Bundle(implicit p: Parameters) extends Info_instruction{}
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

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class Reg_RAW(implicit p: Parameters) extends RiftBundle {
  val vm0 = UInt((log2Ceil(32)).W)
  val rs1 = UInt((log2Ceil(32)).W)
  val rs2 = UInt((log2Ceil(32)).W)
  val rs3 = UInt((log2Ceil(32)).W)
  val rd0 = UInt((log2Ceil(32)).W)
}

class Reg_PHY(implicit p: Parameters) extends RiftBundle {
  val vm0 = UInt((log2Ceil(maxRegNum)).W)
  val rs1 = UInt((log2Ceil(maxRegNum)).W)
  val rs2 = UInt((log2Ceil(maxRegNum)).W)
  val rs3 = UInt((log2Ceil(maxRegNum)).W)
  val rd0 = UInt((log2Ceil(maxRegNum)).W)
}



/**
  * This class represents a bundle of all the supported Instruction Set Architectures (ISA).
  * It provides access to different ISA types such as Arithmetic logic Unit (ALU), Branch and Jump Unit (BRU),
  * Load Store Unit (LSU), Control and Status Register (CSR), Multiply and Divide Unit (MUL), Privileged instructions (Privilege_isa),
  * and Floating Point Unit (FPU).
  * @param p Implicit parameter containing information about the processor's configuration.
  */
class Instruction_set(implicit p: Parameters) extends RiftBundle{
  val aluIsa = new Alu_isa
  val bruIsa = new Bru_isa
  val lsuIsa = new Lsu_isa
  val csrIsa = new Csr_isa
  val mulIsa = new Mul_isa
  val privil_isa = new Privil_isa
  val fpuIsa = new Fpu_isa
  val vecIsa = new VecIsa




  /** @return A Boolean value indicating the whether a float point result will be written back. */
  def isFwb = lsuIsa.isFwb | fpuIsa.isFwb | vecIsa.isFwb
  /** @return A Boolean value indicating whether a integer result will be written back. */
  def isXwb = aluIsa.is_alu | bruIsa.is_bru | lsuIsa.isXwb | csrIsa.is_csr | mulIsa.is_mulDiv | fpuIsa.isXwb | vecIsa.isXwb
  def isVwb = vecIsa.isVwb | lsuIsa.isVwb

  /** @return A Boolean value indicating whether this a privileged instruction is dispatched. */
  def is_privil_dpt = privil_isa.is_privil
  /** @return A Boolean value indicating whether the instruction is dispatched to FPU.*/
  def is_fpu_dpt = fpuIsa.is_fpu
  /** @return A Boolean value indicating whether the instruction is legal or not.*/
  def is_illeage = ~(aluIsa.is_alu | bruIsa.is_bru | lsuIsa.is_lsu | csrIsa.is_csr | mulIsa.is_mulDiv | privil_isa.is_privil | fpuIsa.is_fpu) 

  def isRS1 = aluIsa.is_alu | bruIsa.is_bru | lsuIsa.isRS1 | csrIsa.is_csr | mulIsa.is_mulDiv | (fpuIsa.is_fpu & ~fpuIsa.is_fop) | vecIsa.isRS1
  def isRS2 = aluIsa.is_alu | bruIsa.is_bru | lsuIsa.isRS2 | csrIsa.is_csr | mulIsa.is_mulDiv | (fpuIsa.is_fpu & ~fpuIsa.is_fop) | vecIsa.isRS2

  def isFS1 = fpuIsa.is_fop | vecIsa.isFS1
  def isFS2 = fpuIsa.is_fop | lsuIsa.isFS2
  def isFS3 = fpuIsa.is_fop

  def isVM0 = vecIsa.isVector
  def isVS1 = vecIsa.isVS1
  def isVS2 = vecIsa.isVS2 | lsuIsa.isVS2
  def isVS3 = vecIsa.isVwb | lsuIsa.isVS3

}


/**
 * A class that extends RiftBundle and represents an instruction parameter.
 * @param p An implicit parameter of type Parameters.
 */
class Instruction_param(implicit p: Parameters) extends RiftBundle {
  /** Indicate whether the parameter is in compressed RISC-V format. */
  val is_rvc = Bool()
  /** Represents the program counter with 'vlen' bits. */
  val pc = UInt(vlen.W)
  /** Represents an immediate value with 64 bits. */
  val imm = UInt(64.W)
  /** Represents a 'RM' field with 3 bits (usually for a rounding mode). */
  val rm = UInt(3.W)
  /** Represents a raw source/destination register index. */
  val raw = new Reg_RAW

  // val vm = if(hasVector){Some(Bool())}    else{None}
  // val nf = if(hasVector){Some(UInt(3.W))} else{None}
  def vWidth = rm
  // val mew = Bool()
  // val mop = UInt(2.W)

  // def lumop = raw.rs2
  // def sumop = raw.rs2


}

/**
  * A class that extends Instruction_set and represents an information of the instruction.
  * @param p An implicit parameter of type Parameters.
  */
class Info_instruction(implicit p: Parameters) extends Instruction_set {
  /** the parameters of the instruction */
  val param = new Instruction_param

  val vAttach = if(hasVector){Some(new VRename_Attach_Bundle)} else {None}

}


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

## Related source code

### src/main/scala/rift2Core/backend/Execute.scala

```scala
  val bru = Module(new Bru)
// ...
  bru.io.flush <> io.flush

  bru.io.bftq <> io.bftq
  bru.io.jftq <> io.jftq
```

### src/main/scala/rift2Core/backend/Bru.scala

```scala
  io.bftq.ready := io.bru_iss_exe.fire & io.bru_iss_exe.bits.fun.is_branch
  io.jftq.ready := io.bru_iss_exe.fire & io.bru_iss_exe.bits.fun.jalr

  bru_exe_iwb_fifo.io.enq.valid := io.bru_iss_exe.fire
  bctq.io.enq.valid := io.bru_iss_exe.fire & io.bru_iss_exe.bits.fun.is_branch
  jctq.io.enq.valid := io.bru_iss_exe.fire & io.bru_iss_exe.bits.fun.jalr
// ...
  assert( jctq.io.enq.fire === (io.bru_iss_exe.fire & io.bru_iss_exe.bits.fun.jalr) )
  assert( io.jftq.fire === jctq.io.enq.fire )
  assert( bctq.io.enq.fire === (io.bru_iss_exe.fire & io.bru_iss_exe.bits.fun.is_branch)  )
  assert( io.bftq.fire === bctq.io.enq.fire )
```
