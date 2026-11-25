# Implement `FakeRegFiles`

Implement the complete `FakeRegFiles` class. Preserve the class name and interface shown below.

Return only the complete `class FakeRegFiles` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class FakeRegFiles(dw: Int, dp: Int, rnc: Int, rop: Int, wbc: Int, cmm: Int)(implicit p: Parameters) extends RegFilesBase(dw, dp, arc = 32, rnc, rop, wbc, cmm){
```

## Parent instantiation

### src/main/scala/rift2Core/backend/WriteBack.scala

```scala
  val fReg = if( fpuNum > 0 ) { Module(new FRegFiles(dw = 65, dp = fRegNum, rnChn, opChn, 2, cmChn)) } else {  Module(new FakeRegFiles(dw = 65, dp = fRegNum, rnChn, opChn, 2, cmChn) ) }
// ...
  fReg.io.rename <> io.fRename
  fReg.io.lookup <> io.fLookup
  fReg.io.commit <> io.fCommit
```

## Dependency declarations

### src/main/scala/rift2Core/backend/Regfiles.scala

```scala
class Lookup_Bundle()(implicit p: Parameters) extends RiftBundle{
  val rsp = Input(new RS_PHY)
  val req = Output(new RS_RAW)
}

/**
  * rename channel is located in dpt-stage,
  * the raw-rs needs lookup the phy-rs num ( 1x, 2x, 3x raw-rs -> phy-rs ),
  * the rd should rename and malloc 1 new phy, 
  */
class Rename_Bundle()(implicit p: Parameters) extends RiftBundle{
  val rsp = Input(new RD_PHY)
  val req = Decoupled(new RD_RAW)
}


class Info_commit_op(arc: Int, dp: Int)(implicit p: Parameters) extends RiftBundle{
  val is_comfirm = Output(Bool())
  val is_MisPredict = Output(Bool())
  val is_abort   = Output(Bool())
  val raw        = Output(UInt(( log2Ceil(arc)       ).W))
  val phy        = Output(UInt(( log2Ceil(maxRegNum) ).W))
  val is_writeback = Input(Bool())
}
// ...
abstract class RegFilesBase(dw: Int, dp: Int, arc: Int, rnc: Int, rop: Int, wbc: Int, cmm: Int )(implicit p: Parameters) extends RiftModule{

  class RegFilesIO extends Bundle{
    val lookup = Vec( rnc, Flipped(new Lookup_Bundle) )
    val rename = Vec( rnc, Flipped(new Rename_Bundle) )
    /** read operators based on idx, must success */
    val rgLog = Output( Vec(dp, UInt(2.W)) )
    val rgReq = Flipped(Vec( rop, Valid( UInt((log2Ceil(dp)).W) ) ))
    val rgRsp =         Vec( rop, Valid(new ReadOp_Rsp_Bundle(dw) ))
    /** writeBack request from exeUnit */
    val exe_writeBack = Vec(wbc, Flipped(new DecoupledIO(new WriteBack_info(dw))))
    /** Commit request from commitUnit */
    val commit = Vec(cmm, Flipped(new Info_commit_op(arc, dp)))
    val diffReg = Output(Vec(arc, UInt(dw.W)))    
  }

  val io: RegFilesIO = IO( new RegFilesIO)

}
```

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class RS_PHY(implicit p: Parameters) extends RiftBundle {
  val vm0 = UInt((log2Ceil(maxRegNum)).W)
  val rs1 = UInt((log2Ceil(maxRegNum)).W)
  val rs2 = UInt((log2Ceil(maxRegNum)).W)
  val rs3 = UInt((log2Ceil(maxRegNum)).W)
}
// ...
class RD_PHY(implicit p: Parameters) extends RiftBundle {
  val rd0 = UInt((log2Ceil(maxRegNum)).W)
}
// ...
class ReadOp_Rsp_Bundle(dw: Int)(implicit p: Parameters) extends RiftBundle{
  val phy = UInt((log2Ceil(maxRegNum)).W)
  val op  = UInt(dw.W)
}
```

## Related source code

### src/main/scala/rift2Core/rift2Core.scala

```scala
  iwb_stage.io.fRename <> rnm_stage.io.fRename
```

### src/main/scala/rift2Core/backend/Rename.scala

```scala
  for (i <- 0 until rnChn ) yield {
    io.rnReq(i).ready := (
      for ( j <- 0 to i by 1 ) yield {
        io.xRename(j).req.ready &
        io.fRename(j).req.ready &
```

### src/main/scala/rift2Core/backend/Regfiles.scala

```scala
  for( i <- 0 until rop ) {
    io.rgRsp(i).valid    := RegNext( io.rgReq(i).valid, init = false.B )
    io.rgRsp(i).bits.phy := RegEnable( io.rgReq(i).bits,        io.rgReq(i).valid )
    io.rgRsp(i).bits.op  := RegEnable( files(io.rgReq(i).bits), io.rgReq(i).valid )
```
