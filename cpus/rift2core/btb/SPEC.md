# Implement `BTB`

Implement the complete `BTB` class. Preserve the class name and interface shown below. Keep the nested `BTBIO` class and the `io` declaration inside the submitted class.

Return only the complete `class BTB` definition in a single Scala code block, with no text outside the block.

## Class declaration

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

## Parent instantiation

### src/main/scala/rift2Core/frontend/IF3.scala

```scala
  val btb = Module(new BTB)
// ...
  btb.io.req.bits.pc := 0.U
// ...
  btb.io.req.valid := false.B
// ...
  for ( i <- 3 to 0 by -1 ) {

    when( is_req_btb(i) ) {
      when( if ( i == 0 ) {false.B} else { ( 0 until i ).map{ j => is_req_btb(j) }.reduce(_|_) } ) {

      } .otherwise{
        btb.io.req.valid := reAlign(i).valid & ~(io.flush | io.if4Redirect.fire)
        btb.io.req.bits.pc := reAlign(i).bits.pc
        reAlign(i).ready := combPDT.io.enq(i).ready & btb.io.req.ready
      }
    }
// ...
  btb.io.update.valid           := io.jcmm_update.valid
  btb.io.update.bits.pc         := io.jcmm_update.bits.pc
  btb.io.update.bits.target     := io.jcmm_update.bits.finalTarget
// ...
  btb.io.flush  := false.B
// ...
  btbFifo.io.enq(0)  <> btb.io.resp
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
  * Bundle for Branch Target Buffer (BTB) request interface.
  * @constructor Create a new instance of BTBReq_Bundle.
  * @param p The implicit Parameters object for the processor.
  * @extends IFetchBundle
  */
class BTBReq_Bundle(implicit p: Parameters) extends IFetchBundle {
  /** Program counter for the requesting instruction. */
  val pc = UInt(vlen.W) 
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
// ...
/**
  * This class represents a bundle for updating the Branch Target Buffer (BTB).
  * @param p implicit parameter of type Parameters.
  */
class BTBUpdate_Bundle(implicit p: Parameters) extends BTBResp_Bundle {
  /** Program counter for the updating instruction. */
  val pc = UInt(vlen.W)
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

After `isReady` is asserted, each accepted request produces exactly one `resp` transfer, whose `resp.valid` is first asserted in the cycle after the request is accepted and whose `target` is the `target` of the most recent update with the same `pc`, and an update produces no `resp` transfer.
