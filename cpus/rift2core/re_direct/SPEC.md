# Implement `ReDirect`

Implement the complete `ReDirect` class. Preserve the class name and interface shown below.

Return only the complete `class ReDirect` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class ReDirect[T<:Data]( dw: T, port: Int) extends Module{

  class ReDirectIO extends Bundle{
    val enq = Vec(port, Flipped(new DecoupledIO(dw)) )
    val deq  = Vec(port, new DecoupledIO(dw) )
    val mapper = Input(Vec(port, Bool()))    
  }

  val io: ReDirectIO = IO( new ReDirectIO)
```

## Parent instantiation

### src/main/scala/base/RePort.scala

```scala
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

### src/main/scala/rift2Core/frontend/IF3.scala

```scala
  val btbFifo =  Module(new MultiPortFifo( new BTBResp_Bundle, aw = (if(!isMinArea) 4 else 1), in = 1, out = rnChn, flow = true ) )
  val bimFifo =  Module(new MultiPortFifo( new BIMResp_Bundle, aw = (if(!isMinArea) 4 else 1), in = 1, out = rnChn, flow = true ) )
  val tageFifo = Module(new MultiPortFifo( Vec(6, new TageTableResp_Bundle ), aw = (if(!isMinArea) 4 else 1), in = 1, out = rnChn, flow = true ) )
// ...
  btbFifo.io.deq  <> io.btbResp
  bimFifo.io.deq  <> io.bimResp
  tageFifo.io.deq <> io.tageResp
```

### src/main/scala/rift2Core/rift2Core.scala

```scala
  if3.io.if3_resp <> if4.io.if4_req

  if3.io.btbResp  <> if4.io.btbResp
  if3.io.bimResp  <> if4.io.bimResp
  if3.io.tageResp <> if4.io.tageResp
```

### src/main/scala/rift2Core/frontend/IF4.scala

```scala
    val if4_req  = Vec(rnChn, Flipped(Decoupled(new IF3_Bundle)))
    val btbResp  = Vec(rnChn, Flipped(Decoupled(new BTBResp_Bundle)))
    val bimResp  = Vec(rnChn, Flipped(Decoupled(new BIMResp_Bundle)))
    val tageResp = Vec(rnChn, Flipped(Decoupled(Vec(6, new TageTableResp_Bundle ))))
// ...
  val preDecodeAgn = io.if4_req.map{ x => Mux(x.bits.isRVC, PreDecode16(x.bits.instr(15,0)), PreDecode32(x.bits.instr) ) }
// ...
  val is_req_btb   = (if ( btb_cl != 0 ) {preDecodeAgn.map{ _.is_req_btb}} else {preDecodeAgn.map{_ => false.B}})
  val is_req_bim   = preDecodeAgn.map{ _.is_req_bim}
  val is_req_tage  = if (false) { preDecodeAgn.map{ _.is_req_tage} } else {io.if4_req.map{ _ => false.B}}


  val tageRedirect = ReDirect(io.tageResp, VecInit(is_req_tage) )
  val bimRedirect  = ReDirect(io.bimResp,  VecInit(is_req_bim ) )
  val btbRedirect  = ReDirect(io.btbResp,  VecInit(is_req_btb ) )
// ...
    btbRedirect(i).ready := is_req_btb(i) & io.if4_req(i).fire
    bimRedirect(i).ready := is_req_bim(i) & io.if4_req(i).fire
// ...
    assert( ~(btbRedirect(i).ready  & ~btbRedirect(i).valid) )
    assert( ~(bimRedirect(i).ready  & ~bimRedirect(i).valid) )
```
