# Implement `RAS`

Implement the complete `RAS` class. Preserve the class name and interface shown below.

Return only the complete `class RAS` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/Config.scala

```scala
class Rift2330 extends Config((_, _, _) => {
  case RiftParamsKey => RiftSetting(
// ...
    ifetchParameters = IFParameters(
      uBTB_entry = 8,

      btb_cl = 4,
      bim_cl = 8,
      ras_dp = 4,
    ),
// ...
  )
})

```

## Class declaration

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

## Parent instantiation

### src/main/scala/rift2Core/frontend/IF4.scala

```scala
  val ras = Module(new RAS)
// ...
  val jalr_pc = for( i <- 0 until rnChn ) yield {
    extVaddr( Mux( is_return(i) & ras.io.deq.valid, ras.io.deq.bits.target, btb_decode(i).target), vlen )
  }
  //ignore ras-pop-valid
  ras.io.deq.ready := ( 0 until rnChn ).map{ i => (is_return(i) & io.if4_req(i).fire)}.reduce(_|_)

  ras.io.enq.valid := ( 0 until rnChn ).map{ i =>
    is_call(i) & io.if4_req(i).fire
  }.reduce(_|_)

  ras.io.enq.bits.target := MuxCase( 0.U, (0 until rnChn).map{ i => 
    (is_call(i) -> (pc(i) + Mux(is_rvc(i), 2.U, 4.U)))
  })
// ...
  //only when ras make a wrong prediction will it flush, Warning: we don't care abort other pipeline flush this time
  // ras.io.flush := io.jcmm_update.valid & io.jcmm_update.bits.isRas & io.jcmm_update.bits.isMisPredict
  
  //ras flush immediately when pipeline flush
  ras.io.flush := io.flush

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
// ...
/**
  * This class represents the bundle for Return Address Stack Pop/Push Interface from Instruction Fetch
  * @param p an implicit parameter of type Parameters, which is used by the Processor's implicit Parameters object.
  */ 
class RASPP_Bundle(implicit p: Parameters) extends IFetchBundle {
  /** a UInt indicating the target address for pop/push operation on the Return Address Stack */
  val target = UInt(vlen.W)
}

```

## Related source code

### src/main/scala/rift2Core/frontend/IF3.scala

```scala
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
// ...

```

## Documentation

### src/rv32.adoc

```text
Return-address prediction stacks are a common feature of
high-performance instruction-fetch units, but require accurate detection
of instructions used for procedure calls and returns to be effective.
For RISC-V, hints as to the instructions' usage are encoded implicitly
via the register numbers used. A JAL instruction should push the return
address onto a return-address stack (RAS) only when _rd_ is 'x1' or
`x5`. JALR instructions should push/pop a RAS as shown in <<rashints>>.

[[rashints]]
.Return-address stack prediction hints encoded in the register operands of a JALR instruction.
[%autowidth,float="center",align="center",cols="^,^,^,<",options="header"]
|===
|_rd_ is _x1/x5_ |_rs1_ is _x1/x5_ |_rd_=_rs1_ |RAS action

|No |No |-- |None

|No |Yes |-- |Pop

|Yes |No |-- |Push

|Yes |Yes |No |Pop, then push

|Yes |Yes |Yes |Push
|===

```

## Additional requirement

When `ras_dp` return addresses are already held, a push must discard the oldest held address.
