# Implement `Issue`

Implement the complete `Issue` class. Preserve the class name and interface shown below.

Return only the complete `class Issue` definition in a single Scala code block, with no text outside the block.

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

### src/main/scala/rift2Core/backend/Issue.scala

```scala
package rift2Core.backend

import chisel3._
import chisel3.util._
import rift2Core.define._
import base._

import rift2Core.privilege._
import rift2Chip._
import org.chipsalliance.cde.config._
```

## Class declaration

### src/main/scala/rift2Core/backend/Issue.scala

```scala
class Issue()(implicit p: Parameters) extends IssueSel
```

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val iss_stage = Module(new Issue)
// ...
  preIssue_stage.io.deq <> iss_stage.io.dptReq
// ...
  iss_stage.io.alu_iss_exe <> exe_stage.io.alu_iss_exe
  iss_stage.io.bru_iss_exe <> exe_stage.io.bru_iss_exe
  iss_stage.io.lsu_iss_exe <> exe_stage.io.lsu_iss_exe
  iss_stage.io.csr_iss_exe <> exe_stage.io.csr_iss_exe
  iss_stage.io.mul_iss_exe <> exe_stage.io.mul_iss_exe
  iss_stage.io.fpu_iss_exe <> exe_stage.io.fpu_iss_exe
// ...
  iss_stage.io.irgLog := iwb_stage.io.irgLog
  iss_stage.io.frgLog := iwb_stage.io.frgLog

  iwb_stage.io.irgReq := iss_stage.io.irgReq
  iwb_stage.io.frgReq := iss_stage.io.frgReq

  iss_stage.io.irgRsp := iwb_stage.io.irgRsp
  iss_stage.io.frgRsp := iwb_stage.io.frgRsp
// ...
  iss_stage.io.csrfiles := cmm_stage.io.csrfiles
// ...
  iss_stage.io.flush := cmm_stage.io.cmmRedirect.fire
```

## Dependency declarations

### src/main/scala/rift2Core/backend/Issue.scala

```scala
abstract class DptBase ()(implicit p: Parameters) extends RiftModule with HasFPUParameters{
  // def dptEntry = 16

  class IssueIO extends Bundle{
    val dptReq = Vec(rnChn, Flipped(new DecoupledIO(new Dpt_info)))

    val alu_iss_exe = Vec(aluNum, new DecoupledIO(new Alu_iss_info))
    val mul_iss_exe = Vec(mulNum max 1, new DecoupledIO(new Mul_iss_info))
    val bru_iss_exe = new DecoupledIO(new Bru_iss_info)
    val csr_iss_exe = new DecoupledIO(new Csr_iss_info)
    val lsu_iss_exe = new DecoupledIO(new Lsu_iss_info)
    val fpu_iss_exe = Vec(fpuNum max 1, new DecoupledIO(new Fpu_iss_info))

    val irgLog = Input( Vec(xRegNum, UInt(2.W)) )
    val frgLog = Input( Vec(fRegNum, UInt(2.W)) )
            // val vrgLog = Input( Vec(vRegNum, UInt(2.W)) )

    val irgReq = Vec( opChn, Valid( UInt((log2Ceil(xRegNum)).W) ) )
    val frgReq = Vec( opChn, Valid( UInt((log2Ceil(fRegNum)).W) ) )    
            // val vrgReq = Vec( vParams.opChn, Valid( UInt((log2Ceil(vRegNum)).W) ) )    

    val irgRsp = Vec( opChn, Flipped(Valid(new ReadOp_Rsp_Bundle(64)) ) )
    val frgRsp = Vec( opChn, Flipped(Valid(new ReadOp_Rsp_Bundle(65)) ) )
            // val vrgRsp = Vec( vParams.opChn, Flipped(Valid(new ReadOp_Rsp_Bundle(vParams.vlen)) ) )

    val csrfiles = Input(new CSR_Bundle)

    val flush = Input(Bool())    
  } 

  val io: IssueIO = IO(new IssueIO)
}


trait DptBoard{ this: DptBase =>
  val bufValidDnxt = Wire( Vec(rnChn, Vec( dptEntry, Bool() ) ))
  val bufValid     = RegInit( VecInit( Seq.fill(dptEntry){false.B} ))
  val bufInfo      = Reg(  Vec( dptEntry, new Dpt_info              ))
  val bufReqNum    = Wire( Vec( dptEntry, Vec( 4, UInt((log2Ceil(xRegNum max fRegNum)).W)) ))
  val isBufXop     = Reg(  Vec( dptEntry, Vec( 4, Bool()    )) ) //skip op0 op3
  val isBufFop     = Reg(  Vec( dptEntry, Vec( 4, Bool()    )) ) //skip op0
  val isBufVop     = Reg(  Vec( dptEntry, Vec( 4, Bool()    )) )
  val isOpReady    = Reg(  Vec( dptEntry, Vec( 4, Bool()    )) )
  val bufOperator  = Reg(  Vec( dptEntry, Vec( 4, UInt(65.W))) )

  val entrySel     = for( i <- 0 until rnChn ) yield {
    if( i == 0 ) {
      bufValid.indexWhere( (x:Bool) => (x === false.B) )
    } else {
      bufValidDnxt(i-1).indexWhere( (x:Bool) => (x === false.B) )
    }
  }

  bufValid := bufValidDnxt( rnChn-1 )

  for( i <- 0 until rnChn ) {
    io.dptReq(i).ready := PopCount( bufValid.map{ x => (x === false.B) } ) > i.U


    if ( i == 0 ) {
      bufValidDnxt(i) := bufValid
    } else {
      bufValidDnxt(i) := bufValidDnxt(i-1)
    }

    when( io.flush ) {
      bufValidDnxt(i) := 0.U.asTypeOf(bufValidDnxt(i))
    } .elsewhen( io.dptReq(i).fire ) {
      bufValidDnxt(i)(entrySel(i)) := true.B
      bufInfo(entrySel(i)) := io.dptReq(i).bits
    }
  }

  for( i <- 0 until rnChn ) {
    when( io.dptReq(i).fire ) {
      isBufXop(entrySel(i))(1) := io.dptReq(i).bits.isRS1
      isBufXop(entrySel(i))(2) := io.dptReq(i).bits.isRS2

      isBufFop(entrySel(i))(1) := io.dptReq(i).bits.isFS1
      isBufFop(entrySel(i))(2) := io.dptReq(i).bits.isFS2
      isBufFop(entrySel(i))(3) := io.dptReq(i).bits.isFS3

      isBufVop(entrySel(i))(0) := io.dptReq(i).bits.isVM0
      isBufVop(entrySel(i))(1) := io.dptReq(i).bits.isVS1
      isBufVop(entrySel(i))(2) := io.dptReq(i).bits.isVS2
      isBufVop(entrySel(i))(3) := io.dptReq(i).bits.isVS3

    }
  }



  for( i <- 0 until rnChn ) {
    when( io.dptReq(i).fire ) {
      when(io.dptReq(i).bits.isVM0) {
        isOpReady (entrySel(i))(0) := true.B
        bufOperator(entrySel(i))(0) := (if(hasVector) {io.dptReq(i).bits.vAttach.get.vop0} else {0.U})
      } .elsewhen( io.dptReq(i).bits.phy.vm0 === 0.U ) {
        isOpReady (entrySel(i))(0) := true.B
        bufOperator(entrySel(i))(0) := 0.U
      } .otherwise {
        isOpReady (entrySel(i))(0) := false.B
      }
      when(io.dptReq(i).bits.isVS1) {
        isOpReady (entrySel(i))(1) := true.B
        bufOperator(entrySel(i))(1) := (if(hasVector) {io.dptReq(i).bits.vAttach.get.vop1} else {0.U})
      } .elsewhen( io.dptReq(i).bits.phy.rs1 === 0.U ) {
        isOpReady (entrySel(i))(1) := true.B
        bufOperator(entrySel(i))(1) := 0.U
      } .otherwise {
        isOpReady (entrySel(i))(1) := false.B
      }
      when(io.dptReq(i).bits.isVS2) {
        isOpReady (entrySel(i))(2) := true.B
        bufOperator(entrySel(i))(2) := (if(hasVector) {io.dptReq(i).bits.vAttach.get.vop2} else {0.U})
      } .elsewhen( io.dptReq(i).bits.phy.rs2 === 0.U ) {
        isOpReady (entrySel(i))(2) := true.B
        bufOperator(entrySel(i))(2) := 0.U
      }  .otherwise{
        isOpReady (entrySel(i))(2) := false.B
      }
      when(io.dptReq(i).bits.isVS3) {
        isOpReady (entrySel(i))(3) := true.B
        bufOperator(entrySel(i))(3) := (if(hasVector) {io.dptReq(i).bits.vAttach.get.vop1} else {0.U})
      } .elsewhen( io.dptReq(i).bits.phy.rs3 === 0.U ) {
        isOpReady (entrySel(i))(3) := true.B
        bufOperator(entrySel(i))(3) := 0.U
      } .otherwise {
        isOpReady (entrySel(i))(3) := false.B
      }
    }
  }

  for( i <- 0 until dptEntry ){
    dontTouch(bufReqNum)
    bufReqNum(i)(0) := bufInfo(i).phy.vm0
    bufReqNum(i)(1) := bufInfo(i).phy.rs1
    bufReqNum(i)(2) := bufInfo(i).phy.rs2
    bufReqNum(i)(3) := bufInfo(i).phy.rs3
  }

}

trait VecDptBoard { this: DptBase =>
  val vecBufOperator  = Reg( Vec( 4, UInt((vParams.vlen).W)) )
}


abstract class DptAgeMatrix()(implicit p: Parameters) extends DptBase with DptBoard with VecDptBoard {


  val ageMatrixR = Wire( Vec( dptEntry, Vec(dptEntry, Bool()) ) )
  val ageMatrixW = Reg( Vec( dptEntry, Vec(dptEntry, Bool()) ) )
  // dontTouch(ageMatrixR)

  for ( i <- 0 until dptEntry ) {
    for( j <- 0 until i ) {
      ageMatrixR(i)(j) := ~ageMatrixW(j)(i)
    }
    ageMatrixR(i)(i) := DontCare
    for( j <- i until dptEntry ) {
      ageMatrixR(i)(j) :=  ageMatrixW(i)(j)
    }
  }

  for( i <- 0 until rnChn ) {
    when( io.dptReq(i).fire ) {
      ageMatrixW(entrySel(i)).map{ x => {x := true.B} }
      ageMatrixW.map{ x => {x(entrySel(i)) := false.B} }
    }
  }

  val ageMatrixPostR  = Wire( Vec( dptEntry+rnChn, Vec(dptEntry+rnChn, Bool()) ) )
  for( i <- 0 until dptEntry+rnChn ) {
    ageMatrixPostR(i)(i) := DontCare
    for( j <- 0 until dptEntry+rnChn ) {
      if( i < dptEntry  && j < dptEntry  )  ageMatrixPostR(i)(j) := ageMatrixR(i)(j)
      if( i < dptEntry  && j >= dptEntry )  ageMatrixPostR(i)(j) := false.B
      if( i >= dptEntry && j < dptEntry  )  ageMatrixPostR(i)(j) := true.B
      if( i >= dptEntry && j >= dptEntry ) {
        if( i < j ) ageMatrixPostR(i)(j) := false.B
        if( i > j ) ageMatrixPostR(i)(j) := true.B
      }
    }
  }


  def MatrixMask( matrixIn: Vec[Vec[Bool]], maskCond: Vec[Bool] ): Vec[Vec[Bool]]= {
    val len = matrixIn.length
    require( matrixIn.length    == len )
    require( matrixIn(0).length == len )
    require( maskCond.length    == len )

    val matrixOut = Wire( Vec( len, Vec(len, Bool()) ))
    for ( i <- 0 until len ){
      for ( j <- 0 until len ){
        matrixOut(i)(j) := (matrixIn(i)(j) & ~maskCond(j)) | maskCond(i)
      }
    }
    return matrixOut
  }
}

trait DptReadIOp { this: DptAgeMatrix =>
  val rIOpNum = Wire( Vec( opChn, UInt((log2Ceil(xRegNum)).W)) )


  /** Whether this rs can request operator reading */
  val canIOpReq     = Wire( Vec( dptEntry, Vec( 4, Bool() )))


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



  /** Who is the highest priority to read operator in each chn */
  val selMatrixIRS1 = Wire( Vec( opChn, Vec( dptEntry+rnChn, Vec(dptEntry+rnChn, Bool() ) ) ) )
  val selMatrixIRS2 = Wire( Vec( opChn, Vec( dptEntry+rnChn, Vec(dptEntry+rnChn, Bool() ) ) ) )
  val maskCondSelIRS1 = Wire( Vec( opChn, Vec( dptEntry+rnChn, Bool() ) ) )
  val maskCondSelIRS2 = Wire( Vec( opChn, Vec( dptEntry+rnChn, Bool() ) ) )



  for( chn <- 0 until opChn ){
    if( chn == 0 ){
      for ( i <- 0 until dptEntry ){
        maskCondSelIRS1(chn)(i) := ~bufValid(i) | ~canIOpReq(i)(1)
        maskCondSelIRS2(chn)(i) := ~bufValid(i) | ~canIOpReq(i)(2)
      }
      for ( i <- 0 until rnChn ){
        maskCondSelIRS1(chn)(dptEntry+i) := ~io.dptReq(i).fire | ~canIOpPostReq(i)(1)
        maskCondSelIRS2(chn)(dptEntry+i) := ~io.dptReq(i).fire | ~canIOpPostReq(i)(2)
      }
    } else {
      for ( i <- 0 until dptEntry ){
        maskCondSelIRS1(chn)(i) := maskCondSelIRS1(chn-1)(i) | (bufReqNum(i)(1) === rIOpNum(chn-1))
        maskCondSelIRS2(chn)(i) := maskCondSelIRS2(chn-1)(i) | (bufReqNum(i)(2) === rIOpNum(chn-1))
      }
      for( i <- 0 until rnChn ){
        maskCondSelIRS1(chn)(dptEntry+i) := maskCondSelIRS1(chn-1)(dptEntry+i) | (io.dptReq(i).bits.phy.rs1 === rIOpNum(chn-1))
        maskCondSelIRS2(chn)(dptEntry+i) := maskCondSelIRS2(chn-1)(dptEntry+i) | (io.dptReq(i).bits.phy.rs2 === rIOpNum(chn-1))        
      }
    }
    selMatrixIRS1(chn) := MatrixMask( ageMatrixPostR, maskCondSelIRS1(chn) )
    selMatrixIRS2(chn) := MatrixMask( ageMatrixPostR, maskCondSelIRS2(chn) )

    assert(
      selMatrixIRS1(chn).forall( (x: Vec[Bool]) => x.forall{(y: Bool) => (y === true.B)} ) |
      PopCount( selMatrixIRS1(chn).map{(x: Vec[Bool]) => x.forall{(y: Bool) => (y === false.B)} } ) === 1.U
    )

    assert(
      selMatrixIRS2(chn).forall( (x: Vec[Bool]) => x.forall{ (y: Bool) => (y === true.B)} ) |
      PopCount( selMatrixIRS2(chn).map{(x: Vec[Bool]) => x.forall{(y: Bool) => (y === false.B)} } ) === 1.U
    )
  }



  val isIRS1NoneReq = Wire( Vec(opChn, Bool()) )
  val isIRS2NoneReq = Wire( Vec(opChn, Bool()) )



  val selIRS1 = Wire( Vec(opChn, UInt((log2Ceil(xRegNum)).W) ) )
  val selIRS2 = Wire( Vec(opChn, UInt((log2Ceil(xRegNum)).W) ) )

  for( chn <- 0 until opChn ){
    isIRS1NoneReq(chn) := selMatrixIRS1(chn).forall{(x: Vec[Bool]) => x.forall{ (y: Bool) => (y === true.B) }} //all ture
    isIRS2NoneReq(chn) := selMatrixIRS2(chn).forall{(x: Vec[Bool]) => x.forall{ (y: Bool) => (y === true.B) }} //all ture

    selIRS1(chn) :=
      Mux1H(
        ( 0 until dptEntry ).map{ i => { (selMatrixIRS1(chn)(i).forall         ( (y: Bool) => (y === false.B) )) -> bufReqNum(i)(1) } } ++
        ( 0 until rnChn    ).map{ i => { (selMatrixIRS1(chn)(dptEntry+i).forall( (y: Bool) => (y === false.B) )) -> io.dptReq(i).bits.phy.rs1 }}
      ) //index a row which all zero
    selIRS2(chn) :=
      Mux1H(
        ( 0 until dptEntry ).map{ i => { (selMatrixIRS2(chn)(i).forall         ( (y: Bool) => (y === false.B) )) -> bufReqNum(i)(2) } } ++
        ( 0 until rnChn    ).map{ i => { (selMatrixIRS2(chn)(dptEntry+i).forall( (y: Bool) => (y === false.B) )) -> io.dptReq(i).bits.phy.rs2 }}
      ) //index a row which all zero

    if( chn % 2 == 0 ){
      rIOpNum(chn) := Mux( ~isIRS1NoneReq(chn), selIRS1(chn), Mux( ~isIRS2NoneReq(chn), selIRS2(chn), 0.U ))
    } else {
      rIOpNum(chn) := Mux( ~isIRS2NoneReq(chn), selIRS2(chn), Mux( ~isIRS1NoneReq(chn), selIRS1(chn), 0.U ))
    }

    io.irgReq(chn).valid := ~isIRS1NoneReq(chn) | ~isIRS2NoneReq(chn)
    io.irgReq(chn).bits  := rIOpNum(chn)
  }




}

trait DptReadFOp { this: DptAgeMatrix =>
  val rFOpNum = Wire( Vec( opChn, UInt((log2Ceil(fRegNum)).W)) )


  /** Whether this rs can request operator reading */
  val canFOpReq = Wire( Vec( dptEntry, Vec( 4, Bool() )))

  for( i <- 0 until dptEntry ) {
    canFOpReq(i)(0) := DontCare

    canFOpReq(i)(1) := 
      io.frgLog(bufInfo(i).phy.rs1) === "b11".U & //reg-log is ready
      isBufFop(i)(1) & //is a fop req
      ~isOpReady(i)(1) & ~io.frgRsp.map{x => {x.valid & (x.bits.phy === bufReqNum(i)(1))}}.reduce(_|_) //pending and non-rsp in same cycle

    canFOpReq(i)(2) :=
      io.frgLog(bufInfo(i).phy.rs2) === "b11".U & //reg-log is ready
      isBufFop(i)(2) & //is a fop req
      ~isOpReady(i)(2) & ~io.frgRsp.map{x => {x.valid & (x.bits.phy === bufReqNum(i)(2))}}.reduce(_|_) //pending and non-rsp in same cycle

    canFOpReq(i)(3) :=
      io.frgLog(bufInfo(i).phy.rs3) === "b11".U & //reg-log is ready
      isBufFop(i)(3) & //is a fop req
      ~isOpReady(i)(3) & ~io.frgRsp.map{x => {x.valid & (x.bits.phy === bufReqNum(i)(3))}}.reduce(_|_) //pending and non-rsp in same cycle
  }

  val canFOpPostReq = Wire( Vec( rnChn, Vec( 4, Bool() )) )

  for( i <- 0 until rnChn ) {
    canFOpPostReq(i)(0) := DontCare

    canFOpPostReq(i)(1) := 
      io.frgLog(io.dptReq(i).bits.phy.rs1) === "b11".U & //reg-log is ready
      io.dptReq(i).bits.phy.rs1 =/= 0.U &
      io.dptReq(i).bits.isFS1
    
    canFOpPostReq(i)(2) :=
      io.frgLog(io.dptReq(i).bits.phy.rs2) === "b11".U & //reg-log is ready
      io.dptReq(i).bits.phy.rs2 =/= 0.U &
      io.dptReq(i).bits.isFS2

    canFOpPostReq(i)(3) :=
      io.frgLog(io.dptReq(i).bits.phy.rs3) === "b11".U & //reg-log is ready
      io.dptReq(i).bits.phy.rs3 =/= 0.U &
      io.dptReq(i).bits.isFS3
  }


  /** Who is the highest priority to read operator in each chn */
  val selMatrixFRS1   = Wire( Vec( opChn, Vec( dptEntry+rnChn, Vec(dptEntry+rnChn, Bool() ) ) ) )
  val selMatrixFRS2   = Wire( Vec( opChn, Vec( dptEntry+rnChn, Vec(dptEntry+rnChn, Bool() ) ) ) )
  val selMatrixFRS3   = Wire( Vec( opChn, Vec( dptEntry+rnChn, Vec(dptEntry+rnChn, Bool() ) ) ) )
  val maskCondSelFRS1 = Wire( Vec( opChn, Vec( dptEntry+rnChn, Bool() ) ) )
  val maskCondSelFRS2 = Wire( Vec( opChn, Vec( dptEntry+rnChn, Bool() ) ) )
  val maskCondSelFRS3 = Wire( Vec( opChn, Vec( dptEntry+rnChn, Bool() ) ) )



  for( chn <- 0 until opChn ){
    if( chn == 0 ){
      for ( i <- 0 until dptEntry ){
        maskCondSelFRS1(chn)(i) := ~bufValid(i) | ~canFOpReq(i)(1)
        maskCondSelFRS2(chn)(i) := ~bufValid(i) | ~canFOpReq(i)(2)
        maskCondSelFRS3(chn)(i) := ~bufValid(i) | ~canFOpReq(i)(3)
      }
      for ( i <- 0 until rnChn ){
        maskCondSelFRS1(chn)(dptEntry+i) := ~io.dptReq(i).fire | ~canFOpPostReq(i)(1)
        maskCondSelFRS2(chn)(dptEntry+i) := ~io.dptReq(i).fire | ~canFOpPostReq(i)(2)
        maskCondSelFRS3(chn)(dptEntry+i) := ~io.dptReq(i).fire | ~canFOpPostReq(i)(3)
      }
    } else {
      for ( i <- 0 until dptEntry ){
        maskCondSelFRS1(chn)(i) := maskCondSelFRS1(chn-1)(i) | (bufReqNum(i)(1) === rFOpNum(chn-1))
        maskCondSelFRS2(chn)(i) := maskCondSelFRS2(chn-1)(i) | (bufReqNum(i)(2) === rFOpNum(chn-1))
        maskCondSelFRS3(chn)(i) := maskCondSelFRS3(chn-1)(i) | (bufReqNum(i)(3) === rFOpNum(chn-1))
      }
      for( i <- 0 until rnChn ){
        maskCondSelFRS1(chn)(dptEntry+i) := maskCondSelFRS1(chn-1)(dptEntry+i) | (io.dptReq(i).bits.phy.rs1 === rFOpNum(chn-1))
        maskCondSelFRS2(chn)(dptEntry+i) := maskCondSelFRS2(chn-1)(dptEntry+i) | (io.dptReq(i).bits.phy.rs2 === rFOpNum(chn-1))        
        maskCondSelFRS3(chn)(dptEntry+i) := maskCondSelFRS3(chn-1)(dptEntry+i) | (io.dptReq(i).bits.phy.rs3 === rFOpNum(chn-1))        
      }
    }
    selMatrixFRS1(chn) := MatrixMask( ageMatrixPostR, maskCondSelFRS1(chn) )
    selMatrixFRS2(chn) := MatrixMask( ageMatrixPostR, maskCondSelFRS2(chn) )
    selMatrixFRS3(chn) := MatrixMask( ageMatrixPostR, maskCondSelFRS3(chn) )

    assert(
      selMatrixFRS1(chn).forall( (x: Vec[Bool]) => x.forall{(y: Bool) => (y === true.B)} ) |
      PopCount( selMatrixFRS1(chn).map{(x: Vec[Bool]) => x.forall{(y: Bool) => (y === false.B)} } ) === 1.U
    )

    assert(
      selMatrixFRS2(chn).forall( (x: Vec[Bool]) => x.forall{ (y: Bool) => (y === true.B)} ) |
      PopCount( selMatrixFRS2(chn).map{(x: Vec[Bool]) => x.forall{(y: Bool) => (y === false.B)} } ) === 1.U
    )

    assert(
      selMatrixFRS3(chn).forall( (x: Vec[Bool]) => x.forall{ (y: Bool) => (y === true.B)} ) |
      PopCount( selMatrixFRS3(chn).map{(x: Vec[Bool]) => x.forall{(y: Bool) => (y === false.B)} } ) === 1.U
    )
  }



  val isFRS1NoneReq = Wire( Vec(opChn, Bool()) )
  val isFRS2NoneReq = Wire( Vec(opChn, Bool()) )
  val isFRS3NoneReq = Wire( Vec(opChn, Bool()) )
  // dontTouch(isFRS1NoneReq)
  // dontTouch(isFRS2NoneReq)
  val selFRS1 = Wire( Vec(opChn,  UInt((log2Ceil(fRegNum)).W) ) )
  val selFRS2 = Wire( Vec(opChn,  UInt((log2Ceil(fRegNum)).W) ) )
  val selFRS3 = Wire( Vec(opChn,  UInt((log2Ceil(fRegNum)).W) ) )

  for( chn <- 0 until opChn ){
    isFRS1NoneReq(chn) := selMatrixFRS1(chn).forall{(x: Vec[Bool]) => x.forall{ (y: Bool) => (y === true.B) }} //all ture
    isFRS2NoneReq(chn) := selMatrixFRS2(chn).forall{(x: Vec[Bool]) => x.forall{ (y: Bool) => (y === true.B) }} //all ture
    isFRS3NoneReq(chn) := selMatrixFRS3(chn).forall{(x: Vec[Bool]) => x.forall{ (y: Bool) => (y === true.B) }} //all ture

    selFRS1(chn) :=
      Mux1H(
        ( 0 until dptEntry ).map{ i => { (selMatrixFRS1(chn)(i).forall         ( (y: Bool) => (y === false.B) )) -> bufReqNum(i)(1) } } ++
        ( 0 until rnChn    ).map{ i => { (selMatrixFRS1(chn)(dptEntry+i).forall( (y: Bool) => (y === false.B) )) -> io.dptReq(i).bits.phy.rs1 }}
      ) //index a row which all zero
    selFRS2(chn) :=
      Mux1H(
        ( 0 until dptEntry ).map{ i => { (selMatrixFRS2(chn)(i).forall         ( (y: Bool) => (y === false.B) )) -> bufReqNum(i)(2) } } ++
        ( 0 until rnChn    ).map{ i => { (selMatrixFRS2(chn)(dptEntry+i).forall( (y: Bool) => (y === false.B) )) -> io.dptReq(i).bits.phy.rs2 }}

      ) //index a row which all zero
    selFRS3(chn) :=
      Mux1H(
        ( 0 until dptEntry ).map{ i => { (selMatrixFRS3(chn)(i).forall         ( (y: Bool) => (y === false.B) )) -> bufReqNum(i)(3) } } ++
        ( 0 until rnChn    ).map{ i => { (selMatrixFRS3(chn)(dptEntry+i).forall( (y: Bool) => (y === false.B) )) -> io.dptReq(i).bits.phy.rs3 }}
      ) //index a row which all zero

    if( chn % 3 == 0 ){
      rFOpNum(chn) := Mux( ~isFRS1NoneReq(chn), selFRS1(chn), Mux( ~isFRS2NoneReq(chn), selFRS2(chn), Mux( ~isFRS3NoneReq(chn), selFRS3(chn), 0.U) ))
    } else if( chn % 3 == 1 ){
      rFOpNum(chn) := Mux( ~isFRS2NoneReq(chn), selFRS2(chn), Mux( ~isFRS3NoneReq(chn), selFRS3(chn), Mux( ~isFRS1NoneReq(chn), selFRS1(chn), 0.U) ))
    } else {
      rFOpNum(chn) := Mux( ~isFRS3NoneReq(chn), selFRS3(chn), Mux( ~isFRS1NoneReq(chn), selFRS1(chn), Mux( ~isFRS2NoneReq(chn), selFRS2(chn), 0.U) ))
    }


    io.frgReq(chn).valid := ~isFRS1NoneReq(chn) | ~isFRS2NoneReq(chn) | ~isFRS3NoneReq(chn)
    io.frgReq(chn).bits  := rFOpNum(chn)
  }


}

// trait DptReadVOp { this: DptAgeMatrix =>

//   /** Whether this vs can request operator reading */
//   val canVOpReq = Wire( Vec( dptEntry,Bool() ))
  
//   for( i <- 0 until dptEntry ) {
//     canVOpReq(i) := isBufVop(i)(0) | isBufVop(i)(1) | isBufVop(i)(2) | isBufVop(i)(3)   
//   }

//   /** Who is the highest priority to read operator in each dpt Entry */
//   val selMatrixReadVOp   = Wire( Vec( dptEntry, Vec(dptEntry, Bool() ) ) )
//   val maskCondSelReadVOp = Wire( Vec( dptEntry, Bool() ) )

//   for ( i <- 0 until dptEntry ){
//     maskCondSelReadVOp(i) := ~bufValid(i) | ~canVOpReq(i)
//   }

//   selMatrixReadVOp := MatrixMask( ageMatrixPostR, maskCondSelReadVOp )

//   assert(
//     selMatrixReadVOp.forall( (x: Vec[Bool]) => x.forall{ (y: Bool) => (y === true.B)} ) |
//     PopCount( selMatrixReadVOp.map{(x: Vec[Bool]) => x.forall{(y: Bool) => (y === false.B)} } ) === 1.U
//   )

//   // val isReadVOpNoneReq = Wire( Bool())
//   val selReadVOpEntry = Wire( UInt((log2Ceil(dptEntry)).W) )




// }

abstract class IssueBase()(implicit p: Parameters) extends DptAgeMatrix
with DptReadIOp
with DptReadFOp
// with DptReadVOp




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

}

trait IssLoadFOp { this: IssueBase =>
  for( chn <- 0 until opChn ){
    when( io.frgRsp(chn).valid ){
      for( i <- 0 until dptEntry ){
        for( rs <- 1 to 3 ){
          when( bufValid(i) & (bufReqNum(i)(rs) === io.frgRsp(chn).bits.phy) & isBufFop(i)(rs) ){
            when( isOpReady(i)(rs) === true.B ) { /*printf(s"Warning, re-request op at chn $chn, Entry $i, rs( $rs )")*/ }
            isOpReady(i)(rs)   := true.B
            bufOperator(i)(rs) := io.frgRsp(chn).bits.op
          }
        }
      }
    }    
  }
}

// trait IssLoadVOp { this: IssueBase =>
//   ( 0 until dptEntry ).map{ i => 
//     when( selMatrixReadVOp(i).forall( (y: Bool) => (y === false.B) ) ){
//       for( rs <- 0 to 3 ){
//         val idx = bufReqNum(i)(rs)
//         when( isBufVop(i)(rs) & ~isOpReady(i)(rs) & io.vReadOp(idx).valid ){
//           vecBufOperator(rs) := io.vReadOp(idx).bits
//           isOpReady(i)(rs) := true.B
//         }
//       }
//     }
//   }
// }




abstract class IssueSel()(implicit p: Parameters) extends IssueBase
with IssLoadIOp
with IssLoadFOp{
  val postIsOpReady = Wire( Vec( dptEntry, Vec(4, Bool())) )
  val postBufOperator = Wire( Vec( dptEntry, Vec(4, UInt(65.W))) )

  for( i <- 0 until dptEntry ){
    postIsOpReady(i)(0)   := isOpReady(i)(0)
    postIsOpReady(i)(1)   := MuxCase( isOpReady(i)(1),    io.irgRsp.map{x => { ( isBufXop(i)(1) & x.valid & (x.bits.phy === bufReqNum(i)(1))) -> true.B }} ++ io.frgRsp.map{x => { ( isBufFop(i)(1) & x.valid & (x.bits.phy === bufReqNum(i)(1))) -> true.B }} )
    postIsOpReady(i)(2)   := MuxCase( isOpReady(i)(2),    io.irgRsp.map{x => { ( isBufXop(i)(2) & x.valid & (x.bits.phy === bufReqNum(i)(2))) -> true.B }} ++ io.frgRsp.map{x => { ( isBufFop(i)(2) & x.valid & (x.bits.phy === bufReqNum(i)(2))) -> true.B }} )
    postIsOpReady(i)(3)   := MuxCase( isOpReady(i)(3),                                                                                                        io.frgRsp.map{x => { ( isBufFop(i)(3) & x.valid & (x.bits.phy === bufReqNum(i)(3))) -> true.B }} )

    postBufOperator(i)(0) := bufOperator(i)(0)
    postBufOperator(i)(1) := MuxCase( bufOperator(i)(1) , io.irgRsp.map{x => { ( isBufXop(i)(1) & x.valid & (x.bits.phy === bufReqNum(i)(1))) -> x.bits.op }} ++ io.frgRsp.map{x => { ( isBufFop(i)(1) & x.valid & (x.bits.phy === bufReqNum(i)(1))) -> x.bits.op }} )
    postBufOperator(i)(2) := MuxCase( bufOperator(i)(2) , io.irgRsp.map{x => { ( isBufXop(i)(2) & x.valid & (x.bits.phy === bufReqNum(i)(2))) -> x.bits.op }} ++ io.frgRsp.map{x => { ( isBufFop(i)(2) & x.valid & (x.bits.phy === bufReqNum(i)(2))) -> x.bits.op }} )
    postBufOperator(i)(3) := MuxCase( bufOperator(i)(3) ,                                                                                                        io.frgRsp.map{x => { ( isBufFop(i)(3) & x.valid & (x.bits.phy === bufReqNum(i)(3))) -> x.bits.op }} )
  }

}
```

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class Alu_isa extends Bundle{
  val lui   = Bool()
  val auipc = Bool()
  val addi  = Bool()
  val addiw = Bool()
  val slti  = Bool()
  val sltiu = Bool()
  val xori  = Bool()
  val ori   = Bool()
  val andi  = Bool()
  val slli  = Bool()
  val slliw = Bool()
  val srli  = Bool()
  val srliw = Bool()
  val srai  = Bool()
  val sraiw = Bool()
  val add   = Bool()
  val addw  = Bool()
  val sub   = Bool()
  val subw  = Bool()
  val sll   = Bool()
  val sllw  = Bool()
  val slt   = Bool()
  val sltu  = Bool()
  val xor   = Bool()
  val srl   = Bool()
  val srlw  = Bool()
  val sra   = Bool()
  val sraw  = Bool()
  val or    = Bool()
  val and   = Bool()

  val wfi = Bool()

  def is_32w = addiw | addw | subw | slliw | sllw | srliw | srlw | sraiw | sraw;
  def is_usi = sltiu | sltu
  def is_imm =  lui | auipc | addi | addiw | slti | sltiu | xori | ori | andi | slli | slliw | srli | srliw | srai | sraiw

  def is_fun_add = addi | addiw | add | addw | lui | auipc | sub | subw | wfi
  def is_fun_slt = slti | sltiu | slt | sltu
  def is_fun_xor = xori | xor
  def is_fun_or  = ori | or
  def is_fun_and = andi | and
  def is_fun_sll = slli | slliw | sll | sllw
  def is_fun_srl = srli | srliw | srl | srlw
  def is_fun_sra = srai | sraiw | sra | sraw

  def is_alu = lui | auipc | addi | addiw | slti | sltiu | xori | ori | andi | slli | slliw | srli | srliw | srai | sraiw | add | addw | sub | subw | sll | sllw | slt | sltu | xor | srl | srlw | sra | sraw | or |and |wfi

} 

class Bru_isa extends Bundle {
  val jal  = Bool()
  val jalr = Bool()
  val beq  = Bool()
  val bne  = Bool()
  val blt  = Bool()
  val bge  = Bool()
  val bltu = Bool()
  val bgeu = Bool()

  def is_bru = jal | jalr | beq | bne | blt | bge | bltu | bgeu
  def is_branch = beq | bne | blt | bge | bltu | bgeu
}

class Lsu_isa extends Bundle {
  val lb  = Bool()
  val lh  = Bool()
  val lw  = Bool()
  val ld  = Bool()
  val lbu = Bool()
  val lhu = Bool()
  val lwu = Bool()
  val sb  = Bool()
  val sh  = Bool()
  val sw  = Bool()
  val sd  = Bool()
  val fence = Bool()
  val fence_i = Bool()
  val sfence_vma = Bool()

  val lr_w      = Bool()
  val sc_w      = Bool()
  val amoswap_w = Bool()
  val amoadd_w  = Bool()
  val amoxor_w  = Bool()
  val amoand_w  = Bool()
  val amoor_w   = Bool()
  val amomin_w  = Bool()
  val amomax_w  = Bool()
  val amominu_w = Bool()
  val amomaxu_w = Bool()
  val lr_d      = Bool()
  val sc_d      = Bool()
  val amoswap_d = Bool()
  val amoadd_d  = Bool()
  val amoxor_d  = Bool()
  val amoand_d  = Bool()
  val amoor_d   = Bool()
  val amomin_d  = Bool()
  val amomax_d  = Bool()
  val amominu_d = Bool()
  val amomaxu_d = Bool()

  val flw = Bool()
  val fsw = Bool()
  val fld = Bool()
  val fsd = Bool()


  val vle8  = Bool()
  val vle16 = Bool()
  val vle32 = Bool()
  val vle64 = Bool()
  def vle   = vle8 | vle16 | vle32 | vle64

  val vse8  = Bool()
  val vse16 = Bool()
  val vse32 = Bool()
  val vse64 = Bool()
  def vse   = vse8 | vse16 | vse32 | vse64

  val vlm      = Bool()
  val vsm      = Bool()

  val vlse8  = Bool()
  val vlse16 = Bool()
  val vlse32 = Bool()
  val vlse64 = Bool()
  def vlse   = vlse8 | vlse16 | vlse32 | vlse64

  val vsse8  = Bool()
  val vsse16 = Bool()
  val vsse32 = Bool()
  val vsse64 = Bool()
  def vsse   = vsse8 | vsse16 | vsse32 | vsse64

  val vloxei8  = Bool()
  val vloxei16 = Bool()
  val vloxei32 = Bool()
  val vloxei64 = Bool()
  def vloxei   = vloxei8 | vloxei16 | vloxei32 | vloxei64

  val vsoxei8  = Bool()
  val vsoxei16 = Bool()
  val vsoxei32 = Bool()
  val vsoxei64 = Bool()
  def vsoxei   = vsoxei8 | vsoxei16 | vsoxei32 | vsoxei64

  val vlre8  = Bool()
  val vlre16 = Bool()
  val vlre32 = Bool()
  val vlre64 = Bool()
  def vlre   = vlre8 | vlre16 | vlre32 | vlre64

  val vsr    = Bool()

  val vle8ff  = Bool()
  val vle16ff = Bool()
  val vle32ff = Bool()
  val vle64ff = Bool()
  def vleNff  = vle8ff | vle16ff | vle32ff | vle64ff

  def is_sc = sc_d | sc_w
  def is_lr = lr_d | lr_w

  def is_lu  =
    lb | lh | lw | ld | lbu | lhu | lwu | flw | fld | is_lr |
    vle | vlm | vlse | vloxei | vlre | vleNff

  def is_su  =
    sb | sh | sw | sd | fsw | fsd |
    vse | vsm | vsse | vsoxei | vsr

  def is_xls = lb | lh | lw | ld | lbu | lhu | lwu | sb | sh | sw | sd
  def is_lrsc = is_sc | is_lr
  def is_amo =
    amoswap_w | amoadd_w | amoxor_w | amoand_w | amoor_w | amomin_w | amomax_w | amominu_w | amomaxu_w | amoswap_d | amoadd_d | amoxor_d | amoand_d | amoor_d | amomin_d | amomax_d | amominu_d | amomaxu_d 
  def is_fls = flw | fsw | fld | fsd

  def is_vls = vle | vse | vlm | vsm | vlse | vsse | vloxei | vsoxei | vlre | vsr | vleNff


  def is_fence = fence | fence_i | sfence_vma
  def is_lsu = is_xls | is_lrsc | is_amo | is_fls | is_fence | is_vls


  def isByte =
    lb | lbu | sb |
    vle8 | vse8 | vlse8 | vsse8 |  vlre8 | vle8ff |
    vlm | vsm

  def isHalf =
    lh | lhu | sh |
    vle16 | vse16 | vlse16 | vsse16 | vlre16 | vle16ff

  def isWord =
    lw | lwu | sw | amoswap_w | amoadd_w | amoxor_w | amoand_w | amoor_w | amomin_w | amomax_w | amominu_w | amomaxu_w | flw | fsw | lr_w | sc_w |
    vle32 | vse32 | vlse32 | vsse32 | vlre32 | vle32ff
  
  def isDubl =
    ld | lr_d | fld | sd | sc_d | fsd | amoswap_d | amoadd_d | amoxor_d | amoand_d | amoor_d | amomin_d | amomax_d | amominu_d | amomaxu_d |
    vle64 | vse64 | vlse64 | vsse64 | vlre64 | vle64ff |
    vsr

  def isDynamic = vloxei | vsoxei

  def is_usi = lbu | lhu | lwu


  def is_R = is_lu | is_lr | is_amo
  def is_W = is_su | is_sc | is_amo

  def isXLoad  = lb | lh | lw | ld | lbu | lhu | lwu | is_lr
  def isXStore = sb | sh | sw | sd | is_sc

  def isFLoad  = flw | fld
  def isFStore = fsw | fsd

  def isVLoad  = vle | vlm | vlse | vloxei | vlre | vleNff
  def isVStore = vse | vsm | vsse | vsoxei | vsr
  def isVConstant = vlse | vsse
  def isVIndex = vloxei | vsoxei

  def isRS1 = is_xls | is_lrsc | is_amo | is_fence | is_fls | is_vls
  def isRS2 = ((is_xls | is_lrsc | is_amo ) & ~is_lu) | sfence_vma | isVConstant
  def isFS2 = isFStore
  def isVS2 = isVIndex
  def isVS3 = isVStore

  def isXwb =
    lb | lh | lw | ld | lbu | lhu | lwu | sb | sh | sw | sd |
    fence | fence_i | sfence_vma | lr_w | sc_w |
    amoswap_w | amoadd_w | amoxor_w | amoand_w | amoor_w | amomin_w | amomax_w | amominu_w | amomaxu_w |
    lr_d | sc_d | amoswap_d | amoadd_d | amoxor_d | amoand_d | amoor_d | amomin_d | amomax_d | amominu_d | amomaxu_d |
    fsw | fsd



  def isFwb = flw | fld

  def isVwb = is_vls

  def isUnitStride = vle | vse | vlm | vsm | vlre | vsr | vleNff
  def isStridde = vlse | vsse
  def isIndex = vloxei | vsoxei

  def is_fpu = flw | fsw | fld | fsd
  def isVector = is_vls

}

class Csr_isa extends Bundle {
  val rw  = Bool()
  val rs  = Bool()
  val rc  = Bool()
  val rwi = Bool()
  val rsi = Bool()
  val rci = Bool()

  val vsetvli  = Bool()
  val vsetivli = Bool()
  val vsetvl   = Bool()

  def isXCSR = rw | rs | rc | rwi | rsi | rci
  def isVSet = vsetvli | vsetivli | vsetvl

  def is_csr = isXCSR | isVSet

}

class Mul_isa extends Bundle {
  val mul     = Bool()
  val mulh    = Bool()
  val mulhsu = Bool()
  val mulhu   = Bool()
  val div     = Bool()
  val divu    = Bool()
  val rem     = Bool()
  val remu    = Bool()
  val mulw    = Bool()
  val divw    = Bool()
  val divuw   = Bool()
  val remw    = Bool()
  val remuw   = Bool()

  def isDiv32w = divw | divuw | remw  | remuw
  def isDivusi = divu | remu  | divuw | remuw


  def isMul = mul | mulh | mulhsu | mulhu | mulw
  def isDiv = div | divu | divw | divuw | rem | remu | remw | remuw

  def is_mulDiv = isMul | isDiv



}


// ...
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

class Operation_source(dw: Int)(implicit p: Parameters) extends RiftBundle {
  val op0 = UInt(dw.W)
  val op1 = UInt(dw.W)
  val op2 = UInt(dw.W)
  val op3 = UInt(dw.W)
}

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


class Dpt_info(implicit p: Parameters) extends Info_instruction {
  val phy = new Reg_PHY
}



class Alu_function(implicit p: Parameters) extends RiftBundle {

  val add = Bool()
  val slt = Bool()
  val xor = Bool()
  val or  = Bool()
  val and = Bool()
  val sll = Bool()
  val srl = Bool()
  val sra = Bool()
}

class Alu_param(implicit p: Parameters) extends RD_PHY {
  val is_32w = Bool()
  val is_usi = Bool()

  val dat = new Operation_source(dw=64)
}

class Alu_iss_info(implicit p: Parameters) extends RiftBundle {
  val fun = new Alu_function
  val param = new Alu_param
}





class Bru_param(implicit p: Parameters) extends RD_PHY {
  val is_rvc = Bool()
  val pc = UInt(64.W)
  val imm = UInt(64.W)

  val dat = new Operation_source(dw=64)

  // override def cloneType = ( new Bru_param ).asInstanceOf[this.type]
}

class Bru_iss_info(implicit p: Parameters) extends RiftBundle {
  val fun = new Bru_isa
  val param = new Bru_param
}





class Lsu_param(implicit p: Parameters) extends RD_PHY {
  val dat    = new Operation_source(dw=64)

  // override def cloneType = ( new Lsu_param ).asInstanceOf[this.type]
}






class Lsu_iss_info(implicit p: Parameters) extends RiftBundle {
  val fun = new Lsu_isa
  val param = new Lsu_param

  val vAttach = if(hasVector){Some(new VLsu_Attach_Bundle)} else {None}

  def is_misAlign =
    Mux1H( Seq(
      fun.isHalf -> (param.dat.op1(0)   =/= 0.U),
      fun.isWord -> (param.dat.op1(1,0) =/= 0.U),
      fun.isDubl -> (param.dat.op1(2,0) =/= 0.U),
    ) ++
      (if(hasVector){
        Seq(fun.isDynamic -> Mux1H(Seq(
          (vAttach.get.vsew === "b001".U) -> (param.dat.op1(0)   =/= 0.U),
          (vAttach.get.vsew === "b010".U) -> (param.dat.op1(1,0) =/= 0.U),
          (vAttach.get.vsew === "b011".U) -> (param.dat.op1(2,0) =/= 0.U),
      )))} else {Seq()}) 
    )

  def paddr = param.dat.op1

  def wdata_align(dw: Int) = {
      val res = Wire(UInt(dw.W))
      res := param.dat.op2 << ( paddr((log2Ceil(dw/8)-1),0) << 3 )
      res
    }

  def wstrb_align(dw: Int) = {
    val wstrb = Wire(UInt((dw/8).W))
    wstrb := Mux1H(Seq(
        fun.isByte -> "b00000001".U, fun.isHalf -> "b00000011".U,
        fun.isWord -> "b00001111".U, fun.isDubl -> "b11111111".U,
      ) ++
        (if(hasVector){
          Seq(fun.isDynamic -> Mux1H(Seq(
            (vAttach.get.vsew === "b000".U) -> "b00000001".U,
            (vAttach.get.vsew === "b001".U) -> "b00000011".U,
            (vAttach.get.vsew === "b010".U) -> "b00001111".U,
            (vAttach.get.vsew === "b011".U) -> "b11111111".U,
        )))} else {Seq()})
      ) << paddr((log2Ceil(dw/8)-1),0)
    wstrb
  }
}






// ...
class Csr_function(implicit p: Parameters) extends RiftBundle {
  val rw  = Bool()
  val rs  = Bool()
  val rc  = Bool()

  val vsetvli  = Bool()
  val vsetivli = Bool()
  val vsetvl   = Bool()
}

class Csr_param(implicit p: Parameters) extends RD_PHY {
  val dat = new Operation_source(dw=64)

  // override def cloneType = ( new Csr_param ).asInstanceOf[this.type]
}

class Csr_iss_info(implicit p: Parameters) extends RiftBundle {
  val fun = new Csr_function
  val param = new Csr_param
}

class Mul_param(implicit p: Parameters) extends RD_PHY {
  val dat = new Operation_source(dw=64)

// override def cloneType = ( new Mul_param ).asInstanceOf[this.type]
}

class Mul_iss_info(implicit p: Parameters) extends RiftBundle {
  val fun = new Mul_isa
  val param = new Mul_param
}


// ...
class ReadOp_Rsp_Bundle(dw: Int)(implicit p: Parameters) extends RiftBundle{
  val phy = UInt((log2Ceil(maxRegNum)).W)
  val op  = UInt(dw.W)
}
```

### src/main/scala/rift2Core/backend/Fpu.scala

```scala
class Fpu_iss_info()(implicit p: Parameters) extends RiftBundle {

  val fun = new Fpu_isa
  val param = new Fpu_param

}
```

### src/main/scala/rift2Core/privilege/CsrFiles.scala

```scala
class CSR_Bundle(implicit p: Parameters) extends RiftBundle {

  val priv_lvl = UInt(2.W)
  // val new_priv = UInt(2.W)
  val DMode    = Bool()

  val vstart  = UInt( (log2Ceil(vParams.vlmax)+1).W )
  val vcsr    = new VCSRBundle
  val vConfig = new VConfigBundle
  val vl    = UInt(64.W)
  val vtype = UInt(64.W)
  val vlenb   = UInt((log2Ceil(vParams.vlen/8)).W)

  // val ustatus  = UInt(64.W)
  // val uie      = UInt(64.W)
  // val utvec    = UInt(64.W)
  // val uscratch = UInt(64.W)
  // val uepc     = UInt(64.W)
  // val ucause   = UInt(64.W)
  // val utval    = UInt(64.W)
  // val uip      = UInt(64.W)
  val fflags   = UInt(64.W)
  val frm      = UInt(64.W)
  val fcsr        = new FCSRBundle
  /** Hardware Performance Monitor -- time (read-only) @return a count of the number of ***rtc*** cycles executed by the ***processor core*** on which the hart is running from an arbitrary start time in the past*/
  val time        = UInt(64.W)
  val sstatus     = new MStatusBundle
  // val sedeleg  = UInt(64.W)
  // val sideleg  = UInt(64.W)
  val sie         = new MSIntBundle
  val stvec       = new TVecBundle
  val scounteren  = new CounterenBundle
  val sscratch    = UInt(64.W)
  val sepc        = UInt(64.W)
  val scause      = new CauseBundle
  val stval       = UInt(64.W)
  val sip         = new MSIntBundle
  val satp        = new SatpBundle
  // val hstatus     = UInt(64.W)
  // val hedeleg     = UInt(64.W)
  // val hideleg     = UInt(64.W)
  // val hie         = UInt(64.W)
  // val hcounteren  = UInt(64.W)
  // val hgeie       = UInt(64.W)
  // val htval       = UInt(64.W)
  // val hip         = UInt(64.W)
  // val hvip        = UInt(64.W)
  // val htinst      = UInt(64.W)
  // val hgeip       = UInt(64.W)
  // val hgatp       = UInt(64.W)
  // val htimedelta  = UInt(64.W)
  // val vsstatus    = UInt(64.W)
  // val vsie        = UInt(64.W)
  // val vstvec      = UInt(64.W)
  // val vsscratch   = UInt(64.W)
  // val vsepc       = UInt(64.W)
  // val vscause     = UInt(64.W)
  // val vstval      = UInt(64.W)
  // val vsip        = UInt(64.W)
  // val vsatp       = UInt(64.W)
  val mvendorid   = UInt(64.W)
  val marchid     = UInt(64.W)
  val mimpid      = UInt(64.W)
  val mhartid     = UInt(64.W)
  val mstatus     = new MStatusBundle
  val misa        = UInt(64.W)
  val medeleg     = UInt(64.W)
  val mideleg     = UInt(64.W)
  val mie         = new MSIntBundle
  val mtvec       = new TVecBundle
  val mcounteren  = new CounterenBundle
  val mscratch    = UInt(64.W)
  val mepc        = UInt(64.W)
  val mcause      = new CauseBundle
  val mtval       = UInt(64.W)
  val mip         = new MSIntBundle
  val mtinst      = UInt(64.W)
  val mtval2      = UInt(64.W)
  val mcycle      = UInt(64.W)
  val minstret    = UInt(64.W)
  val mcountinhibit = UInt(64.W)
  val tselect     = UInt(64.W)
  val tdata1      = UInt(64.W)
  val tdata2      = UInt(64.W)
  val tdata3      = UInt(64.W)
  val dcsr        = new DcsrBundle
  val dpc         = UInt(64.W)
  val dscratch0   = UInt(64.W)
  val dscratch1   = UInt(64.W)
  val dscratch2   = UInt(64.W)

  val pmpcfg  = (if(pmpNum==0) { Vec( 1, Vec(8, new PmpcfgBundle) ) } else {Vec( pmpNum, Vec(8, new PmpcfgBundle) )})
  val pmpaddr = (if(pmpNum==0) { Vec( 8, UInt(64.W)) }      else {Vec( 8*pmpNum, UInt(64.W))})

  val mhpmcounter = Vec( 32, UInt(64.W))
  val mhpmevent   = Vec( 32, UInt(64.W))


  val cycle      = UInt(64.W)
  val instret    = UInt(64.W)
  val hpmcounter = Vec( 32, UInt(64.W))
```

### src/main/scala/rift2Core/privilege/CSRInfoTable.scala

```scala
case class CSRInfo( val name: String, val address: Int, val isRO: Boolean, val priv: Int, val isDMode: Boolean ){
}
// ...
object CSRInfoTable{

  val pmpcfg  = for( i <- 0 until 16 by 2 ) yield { CSRInfo( name = s"pmpcfg$i",     address = 0x3A0+i, isRO = false, priv = 3, isDMode = false ) }
  val pmpaddr = for( i <- 0 until 16*8 )    yield { CSRInfo( name = s"pmpaddr$i",    address = 0x3B0+i, isRO = false, priv = 3, isDMode = false ) }
  val mhpmcounter = for( i <- 3 until 32 )  yield { CSRInfo( name = s"mhpmcounter$i",address = 0xB00+i, isRO = false, priv = 3, isDMode = false ) }
  val mhpmevent  = for( i <- 3 until 32 )   yield { CSRInfo( name = s"mhpmevent$i",  address = 0x320+i, isRO = false, priv = 3, isDMode = false ) }
  val hpmcounter =for( i <- 3 until 32 )    yield { CSRInfo( name = s"hpmcounter$i", address = 0xC00+i, isRO = true,  priv = 0, isDMode = false ) }

  val XPUCSRGroup: Seq[CSRInfo] =
    Seq(
      CSRInfo( name = "ustatus",       address = 0x000, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "uie",           address = 0x004, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "utvec",         address = 0x005, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "uscratch",      address = 0x040, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "uepc",          address = 0x041, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "ucause",        address = 0x042, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "utval",         address = 0x043, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "uip",           address = 0x044, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "cycle",         address = 0xC00, isRO = true , priv = 0, isDMode = false ),
      CSRInfo( name = "time",          address = 0xC01, isRO = true , priv = 0, isDMode = false ),
      CSRInfo( name = "instret",       address = 0xC02, isRO = true , priv = 0, isDMode = false ),
      CSRInfo( name = "sstatus",       address = 0x100, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sedeleg",       address = 0x102, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sideleg",       address = 0x103, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sie",           address = 0x104, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "stvec",         address = 0x105, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "scounteren",    address = 0x106, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sscratch",      address = 0x140, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sepc",          address = 0x141, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "scause",        address = 0x142, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "stval",         address = 0x143, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sip",           address = 0x144, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "satp",          address = 0x180, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "hstatus",       address = 0x600, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hedeleg",       address = 0x602, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hideleg",       address = 0x603, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hie",           address = 0x604, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hcounteren",    address = 0x606, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hgeie",         address = 0x607, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "htval",         address = 0x643, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hip",           address = 0x644, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hvip",          address = 0x645, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "htinst",        address = 0x64A, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hgeip",         address = 0xE12, isRO = true , priv = 2, isDMode = false ),
      CSRInfo( name = "hgatp",         address = 0x680, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "htimedelta",    address = 0x605, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsstatus",      address = 0x200, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsie",          address = 0x204, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vstvec",        address = 0x205, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsscratch",     address = 0x240, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsepc",         address = 0x241, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vscause",       address = 0x242, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vstval",        address = 0x243, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsip",          address = 0x244, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsatp",         address = 0x280, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "mvendorid",     address = 0xF11, isRO = true , priv = 3, isDMode = false ),
      CSRInfo( name = "marchid",       address = 0xF12, isRO = true , priv = 3, isDMode = false ),
      CSRInfo( name = "mimpid",        address = 0xF13, isRO = true , priv = 3, isDMode = false),
      CSRInfo( name = "mhartid",       address = 0xF14, isRO = true , priv = 3, isDMode = false),
      CSRInfo( name = "mstatus",       address = 0x300, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "misa",          address = 0x301, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "medeleg",       address = 0x302, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mideleg",       address = 0x303, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mie",           address = 0x304, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mtvec",         address = 0x305, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mcounteren",    address = 0x306, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mscratch",      address = 0x340, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mepc",          address = 0x341, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mcause",        address = 0x342, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mtval",         address = 0x343, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mip",           address = 0x344, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mtinst",        address = 0x34A, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mtval2",        address = 0x34B, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mcycle",        address = 0xB00, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "minstret",      address = 0xB02, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mcountinhibit", address = 0x320, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "tselect",       address = 0x7A0, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "tdata1",        address = 0x7A1, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "tdata2",        address = 0x7A2, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "tdata3",        address = 0x7A3, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "dcsr",          address = 0x7B0, isRO = false, priv = 0, isDMode = true ),
      CSRInfo( name = "dpc",           address = 0x7B1, isRO = false, priv = 0, isDMode = true ),
      CSRInfo( name = "dscratch0",     address = 0x7B2, isRO = false, priv = 0, isDMode = true ),
      CSRInfo( name = "dscratch1",     address = 0x7B3, isRO = false, priv = 0, isDMode = true ),
      CSRInfo( name = "dscratch2",     address = 0x7B4, isRO = false, priv = 0, isDMode = true ),
    ) ++ pmpcfg ++ pmpaddr ++ mhpmcounter ++ mhpmevent ++ hpmcounter
  
  val FPUCSRGroup =
    Seq(
      CSRInfo( name = "fflags",        address = 0x001, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "frm",           address = 0x002, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "fcsr",          address = 0x003, isRO = false, priv = 0, isDMode = false ),
    )

  val VPUCSRGroup = 
    Seq(
      CSRInfo( name = "vstart",        address = 0x008, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vxsat",         address = 0x009, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vxrm",          address = 0x00A, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vcsr",          address = 0x00F, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vl",            address = 0xC20, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vtype",         address = 0xC21, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vConfig",       address = 0xFFE, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vlenb",         address = 0xC22, isRO = true , priv = 0, isDMode = false ),
    )

  val CSRGroup = XPUCSRGroup ++ FPUCSRGroup ++ VPUCSRGroup

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

### src/main/scala/rift2Core/backend/Alu.scala

```scala
  val op1 = io.alu_iss_exe.bits.param.dat.op1
  val op2 = io.alu_iss_exe.bits.param.dat.op2
// ...
  val adder_res = op1 + op2
// ...
  val shift_op2 = Mux(is_32w, op2(4,0), op2(5,0))
```

### src/main/scala/rift2Core/backend/Bru.scala

```scala
  val op1 = io.bru_iss_exe.bits.param.dat.op1
  val op2 = io.bru_iss_exe.bits.param.dat.op2
  val imm = io.bru_iss_exe.bits.param.imm
  val pc  = io.bru_iss_exe.bits.param.pc
  val isRVC = io.bru_iss_exe.bits.param.is_rvc
// ...
  bctq.io.enq.bits.finalTarget  := Mux( is_branchTaken, (pc + imm), (pc + Mux(isRVC, 2.U, 4.U)) )
// ...
  jctq.io.enq.bits.finalTarget := (op1 + imm) >> 1 << 1
// ...
  io.bftq.ready := io.bru_iss_exe.fire & io.bru_iss_exe.bits.fun.is_branch
  io.jftq.ready := io.bru_iss_exe.fire & io.bru_iss_exe.bits.fun.jalr
```

### src/main/scala/rift2Core/backend/Csr.scala

```scala
  val dat = io.csr_iss_exe.bits.param.dat.op1
  val addr = io.csr_iss_exe.bits.param.dat.op3(11,0)
// ...
      (io.csr_iss_exe.bits.fun.rw      | io.csr_iss_exe.bits.fun.rs       | io.csr_iss_exe.bits.fun.rc)     -> io.csr_iss_exe.bits.param.dat.op2,
```
