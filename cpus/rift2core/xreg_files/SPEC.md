# Implement `XRegFiles`

Implement the complete `XRegFiles` class. Preserve the class name and interface shown below.

Return only the complete `class XRegFiles` definition in a single Scala code block, with no text outside the block.

## Package and imports

### src/main/scala/rift2Core/backend/Regfiles.scala

```scala
package rift2Core.backend

import chisel3._
import chisel3.util._
import rift2Core.define._

import rift2Chip._
import org.chipsalliance.cde.config._
```

## Class declaration

### src/main/scala/rift2Core/backend/Regfiles.scala

```scala
class XRegFiles (dw: Int, dp: Int, rnc: Int, rop: Int, wbc: Int, cmm: Int)(implicit p: Parameters) extends RegFilesReal(dw, dp, arc = 32, rnc, rop, wbc, cmm)
```

## Parent instantiation

### src/main/scala/rift2Core/backend/WriteBack.scala

```scala
  val iReg = Module(new XRegFiles(dw = 64, dp = xRegNum, rnChn, opChn, wbChn, cmChn))
// ...
  iReg.io.rename <> io.xRename
  iReg.io.lookup <> io.xLookup
  iReg.io.commit <> io.xCommit
// ...
  iReg.io.diffReg <> io.diffXReg
// ...
  iReg.io.rgReq := io.irgReq
  io.irgRsp := iReg.io.rgRsp
// ...
  io.irgLog := iReg.io.rgLog
// ...
  val iwriteBack_arb = {
    val mdl = Module(new XArbiter(new WriteBack_info(dw=64), in = 3 + aluNum + (mulNum max 1) + (fpuNum max 1), out = wbChn))
    val iwbIO = io.alu_iWriteBack ++ Seq(io.bru_iWriteBack, io.csr_iWriteBack, io.mem_iWriteBack) ++ io.mul_iWriteBack ++ io.fpu_iWriteBack
    mdl.io.enq <> iwbIO
// ...
    mdl.io.deq <> iReg.io.exe_writeBack

    mdl
  }
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

abstract class RegFilesReal(val dw: Int, val dp: Int, val arc: Int, val rnc: Int, val rop: Int, val wbc: Int, val cmm: Int)(implicit p: Parameters) extends RegFilesBase(dw, dp, arc, rnc, rop, wbc, cmm){

  val raw = io.commit.map{ x => x.raw }
  val phy = io.commit.map{ x => x.phy }


  /**
    * there are dp-1 active log,
    * @note the log(0) is assert to be "b11".U
    */ 
  val log_reg = 
    RegInit( VecInit( Seq.fill(arc+1)("b11".U(2.W) ) ++ Seq.fill(dp-arc-1)(0.U(2.W) )))

  val log = {
    val res = Wire( Vec(dp, UInt(2.W)) )
    for ( i <- 1 until dp ) yield { res(i) := log_reg(i) }
    res(0) := "b11".U
    res
  }
  assert( log(0) === "b11".U )

  /**
    * there are dp-1 files,
    * @note the file(dp) is assert to be Zero
    */
  val files_reg = RegInit( VecInit( Seq.fill(dp)(0.U(dw.W)) ))
  val files = {
    val res = Wire( Vec(dp, UInt(dw.W)) )
    for ( i <- 1 until dp ) yield { res(i) := files_reg(i) }
    res(0) := 0.U
    res
  }

  /** index that arc(32) renamed register-sources point to, Avoid pointing to file-0*/
  val rename_ptr = RegInit( VecInit( for( i <- 0 until arc ) yield {(i+1).U(log2Ceil(dp).W)} ) )

  /** index that arc(32) commited register-sources point to, Avoid pointing to file-0 */  
  val archit_ptr = RegInit( VecInit( for( i <- 0 until arc ) yield {(i+1).U(log2Ceil(dp).W)} ) )

  for ( i <- 0 until arc ) yield {
    io.diffReg(i) := files(archit_ptr(i))
  }


}
```

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class RS_RAW(implicit p: Parameters) extends RiftBundle {
  val vm0 = UInt((log2Ceil(32)).W)
  val rs1 = UInt((log2Ceil(32)).W)
  val rs2 = UInt((log2Ceil(32)).W)
  val rs3 = UInt((log2Ceil(32)).W)

}

class RS_PHY(implicit p: Parameters) extends RiftBundle {
  val vm0 = UInt((log2Ceil(maxRegNum)).W)
  val rs1 = UInt((log2Ceil(maxRegNum)).W)
  val rs2 = UInt((log2Ceil(maxRegNum)).W)
  val rs3 = UInt((log2Ceil(maxRegNum)).W)
}

class RD_RAW(implicit p: Parameters) extends RiftBundle {
  val rd0 = UInt((log2Ceil(32)).W)
}

class RD_PHY(implicit p: Parameters) extends RiftBundle {
  val rd0 = UInt((log2Ceil(maxRegNum)).W)
}
// ...
class WriteBack_info(dw:Int)(implicit p: Parameters) extends RD_PHY {
  val res = UInt(dw.W)
}
// ...
class ReadOp_Rsp_Bundle(dw: Int)(implicit p: Parameters) extends RiftBundle{
  val phy = UInt((log2Ceil(maxRegNum)).W)
  val op  = UInt(dw.W)
}
```

## Related source code

### src/main/scala/rift2Core/backend/Rename.scala

```scala
    io.xRename(i).req.valid    := io.rnReq(i).fire & io.rnReq(i).bits.isXwb
    io.xRename(i).req.bits.rd0 := io.rnReq(i).bits.param.raw.rd0
// ...
    reg_phy(i).rd0 := 
      Mux1H(
        Seq(io.xRename(i).req.fire -> io.xRename(i).rsp.rd0) ++
// ...
    io.xLookup(i).req.vm0 := DontCare
    io.xLookup(i).req.rs1 := io.rnReq(i).bits.param.raw.rs1
    io.xLookup(i).req.rs2 := io.rnReq(i).bits.param.raw.rs2
// ...
    reg_phy(i).rs1 :=
      Mux1H( Seq(
        io.rnReq(i).bits.isRS1 -> io.xLookup(i).rsp.rs1,
// ...
  for (i <- 0 until rnChn ) yield {
    io.rnReq(i).ready := (
      for ( j <- 0 to i by 1 ) yield {
        io.xRename(j).req.ready &
```

### src/main/scala/rift2Core/backend/Issue.scala

```scala
  for( i <- 0 until dptEntry ) {
    canIOpReq(i)(0) := DontCare
    canIOpReq(i)(3) := DontCare

    canIOpReq(i)(1) := 
      io.irgLog(bufInfo(i).phy.rs1) === "b11".U & //reg-log is ready
      isBufXop(i)(1) & //is a Xop req
      ~isOpReady(i)(1) & ~io.irgRsp.map{x => {x.valid & (x.bits.phy === bufReqNum(i)(1))}}.reduce(_|_) //pending and non-rsp in same cycle
    
    canIOpReq(i)(2) :=
      io.irgLog(bufInfo(i).phy.rs2) === "b11".U & //reg-log is ready
      isBufXop(i)(2) & //is a Xop req
      ~isOpReady(i)(2) & ~io.irgRsp.map{x => {x.valid & (x.bits.phy === bufReqNum(i)(2))}}.reduce(_|_) //pending and non-rsp in same cycle
  }

  val canIOpPostReq = Wire( Vec( rnChn, Vec( 4, Bool() )) )

  for( i <- 0 until rnChn ) {
    canIOpPostReq(i)(0) := DontCare
    canIOpPostReq(i)(3) := DontCare

    canIOpPostReq(i)(1) := 
      io.irgLog(io.dptReq(i).bits.phy.rs1) === "b11".U & //reg-log is ready
      io.dptReq(i).bits.phy.rs1 =/= 0.U &
      io.dptReq(i).bits.isRS1
    
    canIOpPostReq(i)(2) :=
      io.irgLog(io.dptReq(i).bits.phy.rs2) === "b11".U & //reg-log is ready
      io.dptReq(i).bits.phy.rs2 =/= 0.U &
       io.dptReq(i).bits.isRS2
  }
// ...
    io.irgReq(chn).valid := ~isIRS1NoneReq(chn) | ~isIRS2NoneReq(chn)
    io.irgReq(chn).bits  := rIOpNum(chn)
// ...
trait IssLoadIOp { this: IssueBase =>
  for( chn <- 0 until opChn ){
    when( io.irgRsp(chn).valid ){
      for( i <- 0 until dptEntry ){
        for( rs <- 1 to 2 ){
          when( bufValid(i) & (bufReqNum(i)(rs) === io.irgRsp(chn).bits.phy) & isBufXop(i)(rs) ){
            when( isOpReady(i)(rs) === true.B ) { /*printf(s"Warning, re-request op at chn $chn, Entry $i, rs( $rs )")*/ }
            isOpReady(i)(rs)   := true.B
            bufOperator(i)(rs) := io.irgRsp(chn).bits.op
          }
        }
      }
    }    
  }
```

### src/main/scala/rift2Core/backend/Commit.scala

```scala
  val commit_state = Wire( Vec( cmChn, UInt(2.W)) )
  val commit_state_is_comfirm     = for ( i <- 0 until cmChn ) yield commit_state(i) === 3.U
  val commit_state_is_misPredict  = for ( i <- 0 until cmChn ) yield commit_state(i) === 2.U
  val commit_state_is_abort       = for ( i <- 0 until cmChn ) yield commit_state(i) === 1.U
// ...
  val is_retired = ( 0 until cmChn ).map{ i => {commit_state_is_comfirm(i) | commit_state_is_misPredict(i) } }
// ...
/** commit
  * @note for every commit-chn, it can be:
  * comfirm: commit at this tick
  * abort: cancel and flush at this tick
  * cancel: the perivious chn abort
  * idle: empty line or waitting to check whether is comfirm or abort
  */
abstract class CommitState(implicit p: Parameters) extends BaseCommit
with UpdateCsrFilesFun
with CommitBranch
with CommitDebug
{


  val abort_chn = Wire(UInt(log2Ceil(cmChn).W)); abort_chn := DontCare
  ( 1 until cmChn ).map{ i => assert( commit_state(i) <= commit_state(i-1) ) }
  
  for ( i <- 0 until cmChn ) {
    when( (~io.rod(i).valid)  ) {
      commit_state(i) := 0.U //IDLE
    }
    .otherwise {
      when( cmm_state(i).is_xRet | cmm_state(i).isException | cmm_state(i).isEbreakDM | cmm_state(i).isInterrupt | cmm_state(i).isNomaskInterrupt | cmm_state(i).is_fence_i | cmm_state(i).is_sfence_vma ) {
        commit_state(i) := 1.U //abort
        for ( j <- 0 until i ) { when( ~commit_state_is_comfirm(j) ) {commit_state(i) := 0.U}} //override to idle }
        abort_chn := i.U
      }
      .elsewhen( cmm_state(i).is_wb ) {
        when( io.rod(i).bits.is_branch ) {
          when( ( 0 until i ).map{ j => io.rod(j).bits.is_branch}.foldLeft(false.B)(_|_) ){//PopCount( (0 to i).map{ j => io.rod(j).bits.is_branch } ) > 1.U
            commit_state(i) := 0.U
          } .otherwise{
            commit_state(i) := Mux( io.bctq.bits.isMisPredict, 2.U, 3.U ) //mis-predict )
          }
        }
        .elsewhen( io.rod(i).bits.is_jalr ) {
          when( ( 0 until i ).map{ j => io.rod(j).bits.is_jalr}.foldLeft(false.B)(_|_) ){
            commit_state(i) := 0.U
          } .otherwise{
            commit_state(i) := Mux( io.jctq.bits.isMisPredict, 2.U, 3.U ) //mis-predict )
          }
        }
        .elsewhen( io.rod(i).bits.is_csr  & ( 0 until i ).map{ j => io.rod(j).bits.is_csr }.foldLeft(false.B)(_|_) ){
          commit_state(i) := 0.U
        }
        .elsewhen( io.rod(i).bits.is_fcsr & ( 0 until i ).map{ j => io.rod(j).bits.is_fcsr }.foldLeft(false.B)(_|_) ){
          commit_state(i) := 0.U
        }
        .elsewhen( io.rod(i).bits.isVStore & ( 0 until i ).map{ j => io.rod(j).bits.isVStore }.foldLeft(false.B)(_|_) ){
          commit_state(i) := 0.U
        }
        // .elsewhen( cmm_state(i).isMMUFlush) {
        //   commit_state(i) := 1.U //abort
        //   for ( j <- 0 until i ) { when( ~commit_state_is_comfirm(j) ) {commit_state(i) := 0.U}} //override to idle }
        //   abort_chn := i.U
        // }
        .otherwise {
          commit_state(i) := 3.U //confirm
        }
        for ( j <- 0 until i ) { when( ~commit_state_is_comfirm(j) ) {commit_state(i) := 0.U} } //override to idle }
      }
      .otherwise {
        commit_state(i) := 0.U //idle
      }
    }    
  }

  //assert
  ( 1 until cmChn ).map{ i =>  assert( ~((is_retired(i) | commit_state_is_abort(i)) & ~(is_retired(i-1) | commit_state_is_abort(i-1)) ) )}  //the following chn will not retired or abort if the perivious not



}
// ...
    cmm_state(i).is_wb   :=
      Mux1H(Seq(
        io.rod(i).bits.isXwb -> io.xCommit(i).is_writeback,
        io.rod(i).bits.isFwb -> io.fCommit(i).is_writeback,
// ...
    io.xCommit(i).phy := io.rod(i).bits.rd0_phy
    io.xCommit(i).raw := io.rod(i).bits.rd0_raw
// ...
  ( 0 until cmChn ).map{ i =>
    io.xCommit(i).is_comfirm      := io.rod(i).bits.isXwb & commit_state_is_comfirm(i)
    io.xCommit(i).is_MisPredict   := io.rod(i).bits.isXwb & commit_state_is_misPredict(i)
```

## Documentation

### src/unpriv/rv32.adoc

```text
[#norm:x0eq0]#Register `x0` is hardwired with all bits equal to 0.#
```
