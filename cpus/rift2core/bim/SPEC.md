# Implement `BIM`

Implement the complete `BIM` class. Preserve the class name and interface shown below. Keep the nested `BIMIO` class and the `io` declaration inside the submitted class.

Return only the complete `class BIM` definition in a single Scala code block, with no text outside the block.

## Class declaration

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

## Parent instantiation

### src/main/scala/rift2Core/frontend/IF3.scala

```scala
  val bim = Module(new BIM)
// ...
  val is_req_bim   = reAlignPreDecode.map{ _.is_req_bim}
// ...
  bim.io.req.bits.pc := 0.U
// ...
  bim.io.req.valid := false.B
// ...
  for ( i <- 3 to 0 by -1 ) {
// ...
    when( is_req_bim(i) ) {
      when( if ( i == 0 ) { false.B } else { ( 0 until i ).map{ j => is_req_bim(j) }.reduce(_|_) }  ) {

      } .otherwise{
        bim.io.req.valid := reAlign(i).valid & ~(io.flush | io.if4Redirect.fire)
        bim.io.req.bits.pc := reAlign(i).bits.pc
        reAlign(i).ready := combPDT.io.enq(i).ready & bim.io.req.ready
      }
    }
// ...
  bim.io.update.valid                := io.bcmm_update.valid
  bim.io.update.bits.viewAsSupertype( new BIMResp_Bundle ) := io.bcmm_update.bits.bimResp
  bim.io.update.bits.pc              := io.bcmm_update.bits.pc
  bim.io.update.bits.isFinalTaken    := io.bcmm_update.bits.isFinalTaken
// ...
  bim.io.flush  := false.B
// ...
  bimFifo.io.enq(0)  <> bim.io.resp
```

## Dependency declarations

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
```

### src/main/scala/base/Hash.scala

```scala
object HashHalf0{
  def apply( in: UInt ): UInt = {
    val in_w = in.getWidth
    // require(in_w % 2 == 0, "in_w is "+in_w )


    val out = 
      if(in_w % 2 == 0) {Wire( UInt((in_w/2).W) )}
      else {Wire( UInt(((in_w/2) + 1).W) )}

    out := in(in_w/2-1,0) ^ in(in_w-1 , in_w/2)

    return out
  }  
}
// ...
object HashTo0{
  def apply( in: UInt, len: Int ): UInt = {
    val in_w = in.getWidth
      
    require( in_w > len )

    val out = Wire( UInt(len.W) )
    if ( 2*len >= in_w ) {
      val in1 = ~in(len-1, 0)
      val in2 = in(in_w-1, in_w-1-len)


      out := in1 ^ in2
 
    } else {
      out := HashTo0( HashHalf0(in), len )
    }
    return out      
  }  
}
```

## Additional requirement

After `isReady` is asserted, each accepted request produces exactly one `resp` transfer, whose `resp.valid` is first asserted in the cycle after the request is accepted; a lookup of a PC that has never been updated returns `bim_p = 1` and `bim_h = 0`; and after an update of a PC with `isMisPredict` true and `update.bits.bim_h` 0, lookups of that PC return `bim_p = !update.bits.bim_p` and `bim_h = 1`.
