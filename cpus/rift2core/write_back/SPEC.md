# Implement `WriteBack`

Implement the complete `WriteBack` class. Preserve the class name and interface shown below.

Return only the complete `class WriteBack` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class WriteBack(implicit p: Parameters) extends RiftModule {

  class WriteBackIO extends Bundle{
    val xLookup = Vec( rnChn, Flipped(new Lookup_Bundle) )
    val fLookup = Vec( rnChn, Flipped(new Lookup_Bundle) )
              // val vLookup = Vec( rnChn, Flipped(new Lookup_Bundle) )
              // val cLookup = Vec( rnChn, new SeqReg_Lookup_Bundle(cRegNum))

    val xRename = Vec( rnChn, Flipped(new Rename_Bundle) )
    val fRename = Vec( rnChn, Flipped(new Rename_Bundle) )
              // val vRename = Vec( rnChn, Flipped(new Rename_Bundle) )
              // val cRename = Vec( rnChn, new SeqReg_Rename_Bundle(cRegNum))

    val irgLog = Output( Vec(xRegNum, UInt(2.W)) )
    val frgLog = Output( Vec(fRegNum, UInt(2.W)) )
              // val vrgLog = Output( Vec(fRegNum, UInt(2.W)) )

    val irgReq = Flipped(Vec( opChn, Valid( UInt((log2Ceil(xRegNum)).W) ) ))
    val frgReq = Flipped(Vec( opChn, Valid( UInt((log2Ceil(fRegNum)).W) ) ))
              // val vrgReq = Flipped(Vec( vParams.opChn, Valid( UInt((log2Ceil(vRegNum)).W) ) ))

    val irgRsp =  Vec( opChn, Valid(new ReadOp_Rsp_Bundle(64) ))
    val frgRsp =  Vec( opChn, Valid(new ReadOp_Rsp_Bundle(65) ))
              // val vrgRsp =  Vec( vParams.opChn, Valid(new ReadOp_Rsp_Bundle(vParams.vlen) ))

    val vMolloc = Flipped(Decoupled(new Vector_Molloc_Bundle ) ) //molloc at read op
    val vReadOp = Vec( 32, Valid(UInt( (vParams.vlen).W )) )




    val alu_iWriteBack = Vec(aluNum, Flipped(new DecoupledIO(new WriteBack_info(dw = 64))))
    val bru_iWriteBack = Flipped(new DecoupledIO(new WriteBack_info(dw = 64)))
    val csr_iWriteBack = Flipped(new DecoupledIO(new WriteBack_info(dw = 64)))
    val mem_iWriteBack = Flipped(new DecoupledIO(new WriteBack_info(dw = 64)))
    val mul_iWriteBack = Vec(mulNum max 1, Flipped(new DecoupledIO(new WriteBack_info(dw = 64))))
    val fpu_iWriteBack = Vec(fpuNum max 1, Flipped(new DecoupledIO(new WriteBack_info(dw = 64))))

    val mem_fWriteBack = Flipped(new DecoupledIO(new WriteBack_info(dw = 65)))
    val fpu_fWriteBack = Vec(fpuNum max 1, Flipped(new DecoupledIO(new WriteBack_info(dw = 65))))

    val mem_vWriteBack = Flipped(new DecoupledIO(new Vector_WriteBack_Bundle))

                // val cWriteBack     = Vec(3, Flipped(Valid(new SeqReg_WriteBack_Bundle(64, cRegNum))))


    
    val xCommit = Vec(cmChn, Flipped((new Info_commit_op(32, xRegNum))))
    val fCommit = Vec(cmChn, Flipped((new Info_commit_op(32, fRegNum))))
    val vCommit = Vec(cmChn, Flipped(new Vector_Commit_Bundle))
                // val cCommit = Vec(cmChn, Flipped(new SeqReg_Commit_Bundle(cRegNum)))

                // val csrIsReady = Output(new CSR_LOG_Bundle(cRegNum))
                // val csrOp= Output(Vec(cmChn, new Exe_Port) )

    val xpuCsrMolloc    = Flipped(Vec(rnChn, Decoupled(UInt(12.W))))
    val xpuCsrWriteBack = Flipped(Valid(new Exe_Port))
    val xpuCsrCommit    = Decoupled(new Exe_Port)
    val fpuCsrMolloc    = Flipped(Vec(rnChn, Decoupled(Bool())))
    val fpuCsrWriteBack = Flipped(Valid(new Exe_Port))
    val fpuCsrCommit    = Decoupled(new Exe_Port)
    val vpuCsrMolloc    = Flipped(Vec(rnChn, Decoupled(Bool())))
    val vpuCsrWriteBack = Flipped(Valid(new Exe_Port))
    val vpuCsrCommit    = Decoupled(new Exe_Port)
    val isCSRMMUReady   = Output(Bool())

    val diffXReg = Output(Vec(32, UInt(64.W)))
    val diffFReg = Output(Vec(32, UInt(65.W)))
    val diffVReg = Output(Vec(32, UInt((vParams.vlen).W)))
  }

  val io: WriteBackIO = IO(new WriteBackIO)
```

## Parent instantiation

```scala
  val iwb_stage = Module(new WriteBack)
// ...
  preRename_stage.io.vpuCsrMolloc <> iwb_stage.io.vpuCsrMolloc
// ...
  preIssue_stage.io.molloc <> iwb_stage.io.vMolloc
  preIssue_stage.io.readOp <> iwb_stage.io.vReadOp
// ...
  iwb_stage.io.xLookup <> rnm_stage.io.xLookup
  iwb_stage.io.fLookup <> rnm_stage.io.fLookup

  iwb_stage.io.xRename <> rnm_stage.io.xRename
  iwb_stage.io.fRename <> rnm_stage.io.fRename
// ...
  iss_stage.io.irgLog := iwb_stage.io.irgLog
  iss_stage.io.frgLog := iwb_stage.io.frgLog

  iwb_stage.io.irgReq := iss_stage.io.irgReq
  iwb_stage.io.frgReq := iss_stage.io.frgReq

  iss_stage.io.irgRsp := iwb_stage.io.irgRsp
  iss_stage.io.frgRsp := iwb_stage.io.frgRsp
// ...
  iwb_stage.io.alu_iWriteBack <> exe_stage.io.alu_exe_iwb
  iwb_stage.io.bru_iWriteBack <> exe_stage.io.bru_exe_iwb
  iwb_stage.io.csr_iWriteBack <> exe_stage.io.csr_exe_iwb
  iwb_stage.io.mul_iWriteBack <> exe_stage.io.mul_exe_iwb
// ...
  iwb_stage.io.mem_iWriteBack <> exe_stage.io.lsu_exe_iwb
  iwb_stage.io.mem_fWriteBack <> exe_stage.io.lsu_exe_fwb
  iwb_stage.io.mem_vWriteBack <> exe_stage.io.lsu_exe_vwb
// ...
  iwb_stage.io.fpu_iWriteBack <> exe_stage.io.fpu_exe_iwb
  iwb_stage.io.fpu_fWriteBack <> exe_stage.io.fpu_exe_fwb

  iwb_stage.io.xpuCsrWriteBack := exe_stage.io.xpuCsrWriteBack
  iwb_stage.io.fpuCsrWriteBack := exe_stage.io.fpuCsrWriteBack
  iwb_stage.io.vpuCsrWriteBack.valid := false.B
  iwb_stage.io.vpuCsrWriteBack.bits  := DontCare
// ...
  iwb_stage.io.xpuCsrMolloc    <> rnm_stage.io.xpuCsrMolloc
  iwb_stage.io.fpuCsrMolloc    <> rnm_stage.io.fpuCsrMolloc
// ...
  iwb_stage.io.xCommit <> cmm_stage.io.xCommit
  iwb_stage.io.fCommit <> cmm_stage.io.fCommit
  iwb_stage.io.vCommit <> cmm_stage.io.vCommit
```

## Dependency declarations

### src/main/scala/rift2Core/backend/Regfiles.scala

```scala
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
// ...
class XRegFiles (dw: Int, dp: Int, rnc: Int, rop: Int, wbc: Int, cmm: Int)(implicit p: Parameters) extends RegFilesReal(dw, dp, arc = 32, rnc, rop, wbc, cmm)
// ...
class FRegFiles (dw: Int, dp: Int, rnc: Int, rop: Int, wbc: Int, cmm: Int)(implicit p: Parameters) extends RegFilesReal(dw, dp, arc = 32, rnc, rop, wbc, cmm)
```

### src/main/scala/rift2Core/vector/VRegfiles.scala

```scala
class VRegFilesIO()(implicit p: Parameters) extends RiftBundle{
  val molloc = Flipped(Decoupled(new Vector_Molloc_Bundle ) ) //molloc at read op
  val readOp = Vec( 32, Valid(UInt( (vParams.vlen).W )) )

  val writeBack  = Flipped(Decoupled(new Vector_WriteBack_Bundle))

  val commit = Vec(cmChn, Flipped(new Vector_Commit_Bundle))
  val diffReg = Output(Vec(32, UInt((vParams.vlen/8).W)))
}
// ...
class VRegFiles()(implicit p: Parameters) extends VRegFilesBase
with VRegMolloc
with VRegReadOp
with VRegWriteBack
with VRegCommit{
  for( i <- 0 until 32 ) {
    io.diffReg(i) := files(i)
  }
}
```

### src/main/scala/rift2Core/privilege/CsrScoreBoard.scala

```scala
class XPUCsrIO(implicit p: Parameters) extends RiftBundle{
  /** The csr allocation signal, used at rename stage */
  val molloc    = Vec(rnChn, Flipped(Decoupled(UInt(12.W))))
  /** The write-back signal, used at execute stage */
  val writeBack = Flipped(Valid(new Exe_Port))
  /** The commit signal, used at commit stage */
  val commit    = Decoupled(new Exe_Port)
}

/**
  * An interface for FPUCsrIO signals.
  * @param p The parameters of the system.
  */
class FPUCsrIO(implicit p: Parameters) extends RiftBundle{
  /** The csr allocation signal, used at rename stage while a FAlu instruction is renaming */
  val molloc    = Vec(rnChn, Flipped(Decoupled(Bool())))
  /** The write-back signal, used at execute stage */
  val writeBack = Flipped(Valid(new Exe_Port))
  /** The commit signal, used at commit stage */
  val commit    = Decoupled(new Exe_Port)
}

/**
  * An interface for VPUCsrIO signals.
  * @param p The parameters of the system.
  */
class VPUCsrIO(implicit p: Parameters) extends FPUCsrIO

/**
  * An interface for the CSR scoreboard signals.
  * @param p The parameters of the system.
  */
class CsrScoreBoardIO(implicit p: Parameters) extends RiftBundle{
  val xpu: XPUCsrIO      = new XPUCsrIO
  val fpu: FPUCsrIO      = new FPUCsrIO
  val vpu: VPUCsrIO      = new VPUCsrIO

  val isMMUReady: Bool = Output(Bool())
  val isAbort: Bool      = Input(Bool())
}
// ...
class CsrScoreBoard(implicit p: Parameters) extends CsrScoreBoardBase
```

## Related source code

### src/main/scala/rift2Core/backend/Commit.scala

```scala
  val commit_state = Wire( Vec( cmChn, UInt(2.W)) )
  val commit_state_is_comfirm     = for ( i <- 0 until cmChn ) yield commit_state(i) === 3.U
  val commit_state_is_misPredict  = for ( i <- 0 until cmChn ) yield commit_state(i) === 2.U
  val commit_state_is_abort       = for ( i <- 0 until cmChn ) yield commit_state(i) === 1.U
  val commit_state_is_idle        = for ( i <- 0 until cmChn ) yield commit_state(i) === 0.U
// ...
    io.xCommit(i).phy := io.rod(i).bits.rd0_phy
    io.xCommit(i).raw := io.rod(i).bits.rd0_raw
// ...
  ( 0 until cmChn ).map{ i =>
    io.xCommit(i).is_comfirm      := io.rod(i).bits.isXwb & commit_state_is_comfirm(i)
    io.xCommit(i).is_MisPredict   := io.rod(i).bits.isXwb & commit_state_is_misPredict(i)
```
