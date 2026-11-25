# Implement `Commit`

Implement the complete `Commit` class. Preserve the class name and interface shown below.

Return only the complete `class Commit` definition in a single Scala code block, with no text outside the block.

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

### src/main/scala/rift2Core/backend/Commit.scala

```scala
package rift2Core.backend

import chisel3._
import chisel3.util._

import rift2Core.define._
import rift2Core.backend._
import rift2Core.privilege._
import debug._
import chisel3.experimental._
import base._
import rift2Chip._
import org.chipsalliance.cde.config._
import rift2Core.diff._
```

## Class declaration

### src/main/scala/rift2Core/backend/Commit.scala

```scala
class Commit()(implicit p: Parameters) extends CommitState
```

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val cmm_stage = Module(new Commit)
// ...
  preRename_stage.io.csrfiles := cmm_stage.io.csrfiles
  preIssue_stage.io.csrfiles := cmm_stage.io.csrfiles
  iss_stage.io.csrfiles := cmm_stage.io.csrfiles
// ...
  iwb_stage.io.xCommit <> cmm_stage.io.xCommit
  iwb_stage.io.fCommit <> cmm_stage.io.fCommit
  iwb_stage.io.vCommit <> cmm_stage.io.vCommit

  cmm_stage.io.rod <> rnm_stage.io.rod_i

  cmm_stage.io.cmm_lsu <> exe_stage.io.cmm_lsu
  cmm_stage.io.lsu_cmm <> exe_stage.io.lsu_cmm

  preIssue_stage.io.isPndVStore := cmm_stage.io.isPndVStore
  preRename_stage.io.isVStartRsv := cmm_stage.io.isVStartRsv
  preRename_stage.io.isVSetRsv   := cmm_stage.io.isVSetRsv
  preRename_stage.io.isFoFRsv    := cmm_stage.io.isFoFRsv


  cmm_stage.io.bctq <> exe_stage.io.bctq
  cmm_stage.io.jctq <> exe_stage.io.jctq
  cmm_stage.io.cmmRedirect <> if1.io.cmmRedirect
  cmm_stage.io.if_cmm := if2.io.if_cmm
  cmm_stage.io.aclint := io.aclint
  cmm_stage.io.plic := io.plic
  if2.io.ifence := cmm_stage.io.ifence
// ...
  iwb_stage.io.xpuCsrCommit <> cmm_stage.io.xpuCsrCommit
  iwb_stage.io.fpuCsrCommit <> cmm_stage.io.fpuCsrCommit
  iwb_stage.io.vpuCsrCommit <> cmm_stage.io.vpuCsrCommit
// ...
  cmm_stage.io.rtc_clock := io.rtc_clock
  if (hasDebugger) {cmm_stage.io.dm <> io.dm.get}
  else {
    cmm_stage.io.dm.hartResetReq := false.B
    cmm_stage.io.dm.hartHaltReq := false.B
  }
// ...
  i_mmu.io.if_flush  := cmm_stage.io.cmmRedirect.fire | if4.io.if4Redirect.valid
  i_mmu.io.lsu_flush := cmm_stage.io.cmmRedirect.fire

  if2.io.flush := cmm_stage.io.cmmRedirect.fire | if4.io.if4Redirect.valid
  if3.io.flush := cmm_stage.io.cmmRedirect.fire
  if4.io.flush := cmm_stage.io.cmmRedirect.fire

  preRename_stage.io.flush := cmm_stage.io.cmmRedirect.fire
  rnm_stage.reset := cmm_stage.io.cmmRedirect.fire | reset.asBool
  preIssue_stage.io.flush := cmm_stage.io.cmmRedirect.fire
  iss_stage.io.flush := cmm_stage.io.cmmRedirect.fire
  exe_stage.io.flush := cmm_stage.io.cmmRedirect.fire
// ...
  diff.io.commit   := cmm_stage.io.diff_commit
  diff.io.csr      := cmm_stage.io.diff_csr
```

## Dependency declarations

### src/main/scala/rift2Core/backend/Commit.scala

```scala
class ExInt_Bundle extends Bundle {
  val is_single_step = Bool()
  val is_trigger = Bool()
  val hartHaltReq = Bool()

  val emu_reset = Bool()
	val msi = Bool()
	val ssi = Bool()
	val mti = Bool()
	val sti = Bool()
	val mei = Bool()
	val sei = Bool()  
}

abstract class BaseCommit()(implicit p: Parameters) extends RiftModule {

  class CommitIO extends Bundle{
    // val cm_op = Vec(cmChn, new Info_commit_op(32, maxRegNum))

    val xCommit = Vec(cmChn, new Info_commit_op(32, xRegNum))
    val fCommit = Vec(cmChn, new Info_commit_op(32, fRegNum))
    val vCommit = Vec(cmChn, new Vector_Commit_Bundle)
              // val csrCmm = Vec(cmChn, new SeqReg_Commit_Bundle(cRegNum))
              // val csrOp = Input(Vec(cmChn, new Exe_Port))
    val rod = Vec(cmChn, Flipped(new DecoupledIO( new Info_reorder_i ) ))
    val cmm_lsu = Output(new Info_cmm_lsu)
    val lsu_cmm = Input( new Info_lsu_cmm )
    val bctq = Flipped(Decoupled(new Branch_CTarget_Bundle))
    val jctq = Flipped(Decoupled(new Jump_CTarget_Bundle))
    val cmmRedirect = new ValidIO(new Commit_Redirect_Bundle)
    val if_cmm = Input( new Info_if_cmm )
    val ifence = Output(Bool())
    val cmm_mmu = Output( new Info_cmm_mmu )
    val dm = Flipped(new Info_DM_cmm)
    val rtc_clock = Input(Bool())
    val aclint = Input(new AClint_Bundle)
    val plic   = Input(new Plic_Bundle)
    val csrfiles = Output(new CSR_Bundle)
    val diff_commit = Output(new Info_cmm_diff)
    val diff_csr = Output(new Info_csr_reg)

    val xpuCsrCommit    = Flipped(Decoupled(new Exe_Port))
    val fpuCsrCommit    = Flipped(Decoupled(new Exe_Port))
    val vpuCsrCommit    = Flipped(Decoupled(new Exe_Port))

    val isPndVStore = Output(Bool())
    val isVStartRsv = Output(Bool())
    val isVSetRsv   = Output(Bool())
    val isFoFRsv    = Output(UInt((log2Ceil(cmChn)+1).W))
  }

  val io: CommitIO = IO(new CommitIO)


  val csrfiles = Reg(new CSR_Bundle); io.csrfiles := csrfiles
  val commit_state = Wire( Vec( cmChn, UInt(2.W)) )
  val commit_state_is_comfirm     = for ( i <- 0 until cmChn ) yield commit_state(i) === 3.U
  val commit_state_is_misPredict  = for ( i <- 0 until cmChn ) yield commit_state(i) === 2.U
  val commit_state_is_abort       = for ( i <- 0 until cmChn ) yield commit_state(i) === 1.U
  val commit_state_is_idle        = for ( i <- 0 until cmChn ) yield commit_state(i) === 0.U


  val cmm_state = Wire( Vec(cmChn, new CMMState_Bundle ) )
  val csr_state = Wire( Vec(cmChn, new CSR_Bundle ) )

  val is_retired = ( 0 until cmChn ).map{ i => {commit_state_is_comfirm(i) | commit_state_is_misPredict(i) } }

}

trait CommitBranch{ this: BaseCommit =>
  // val emptyBCTQ = {
  //   val res = Wire(Vec(cmChn, Flipped(DecoupledIO( new Branch_CTarget_Bundle ) )))
  //   res := 0.U.asTypeOf(Vec(cmChn, Flipped(DecoupledIO( new Branch_CTarget_Bundle ) )))
  //   res(0) <> io.bctq
  //   res
  // }

  // val emptyJCTQ = {
  //   val res = Wire(Vec(cmChn, Flipped(DecoupledIO( new Jump_CTarget_Bundle ) )))
  //   res := 0.U.asTypeOf(Vec(cmChn, Flipped(DecoupledIO( new Jump_CTarget_Bundle ) )))
  //   res(0) <> io.jctq
  //   res
  // }

  // val bctq = ReDirect( emptyBCTQ, VecInit( io.rod.map{_.bits.is_branch} ) )
  // val jctq = ReDirect( emptyJCTQ, VecInit( io.rod.map{_.bits.is_jalr} ) )

  // ( 0 until cmChn ).map{ i =>
  //   bctq(i).ready := is_retired(i) & io.rod(i).bits.is_branch
  //   assert( bctq(i).fire === (is_retired(i) & io.rod(i).bits.is_branch) )
  //   assert( bctq.map{_.fire}.reduce(_|_) === io.bctq.fire )
  // }

  // ( 0 until cmChn ).map{ i =>
  //   jctq(i).ready := is_retired(i) & io.rod(i).bits.is_jalr
  //   assert( jctq(i).fire === (is_retired(i) & io.rod(i).bits.is_jalr) )
  //   assert( jctq.map{_.fire}.reduce(_|_) === io.jctq.fire )
  // }

  io.bctq.ready := ( 0 until cmChn ).map{ i => is_retired(i) & io.rod(i).bits.is_branch }.foldLeft(false.B)(_|_)
  assert( ~(io.bctq.ready & ~io.bctq.valid) )
  assert( PopCount( ( 0 until cmChn ).map{ i => is_retired(i) & io.rod(i).bits.is_branch } ) <= 1.U )

  io.jctq.ready := ( 0 until cmChn ).map{ i => is_retired(i) & io.rod(i).bits.is_jalr }.foldLeft(false.B)(_|_)
  assert( ~(io.jctq.ready & ~io.jctq.valid) )
  assert( PopCount( ( 0 until cmChn ).map{ i => is_retired(i) & io.rod(i).bits.is_jalr } ) <= 1.U )
}

trait CommitDebug{ this: BaseCommit =>
  val is_single_step = RegInit(false.B)
  val is_trigger = false.B
  val emu_reset = RegInit( false.B )

  io.dm.hartIsInReset := emu_reset

  when( io.dm.hartResetReq ){
    emu_reset := true.B
  }.elsewhen( emu_reset ){
    emu_reset := false.B
  }



  when ((is_retired(0) | commit_state_is_abort(0)) & cmm_state(0).is_step){
    is_single_step := true.B
  }.elsewhen( csrfiles.DMode ){
    is_single_step := false.B
  }
}



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
class CMMState_Bundle(implicit p: Parameters) extends RiftBundle{
  val rod = new Info_reorder_i
  val csrfiles = new CSR_Bundle
  val lsu_cmm = new Info_lsu_cmm

  val csrExe = new Exe_Port
  val is_wb = Bool()
  val ill_ivaddr = UInt(64.W)
	val ill_dvaddr = UInt(64.W)

  val exint = new ExInt_Bundle

  val isVException = Bool()
  val exceptionIdx = UInt((log2Ceil(vParams.vlen/8).W))

  def is_load_accessFault: Bool = {
    val is_load_accessFault = 
      lsu_cmm.is_access_fault & (
        (rod.is_lu & is_wb) | (rod.isVLoad & isVException & ~(rod.isFoF & exceptionIdx =/= 0.U) )
      )

    return is_load_accessFault
  }

  def is_store_accessFault: Bool = {
    val is_store_accessFault =
      lsu_cmm.is_access_fault & (
        ( ( rod.isXFStore | rod.is_amo ) & is_wb ) | (rod.isVStore & isVException)
      )

    return is_store_accessFault
  }

  def is_load_pagingFault: Bool = {
    val is_load_pagingFault =
      lsu_cmm.is_paging_fault & (
        ( rod.is_lu & is_wb ) | (rod.isVLoad & isVException & ~(rod.isFoF & exceptionIdx =/= 0.U) )
      )

    return is_load_pagingFault
  }

  def is_store_pagingFault: Bool = {
    val is_store_pagingFault =
      lsu_cmm.is_paging_fault & (
        (( rod.isXFStore | rod.is_amo ) & is_wb) | (rod.isVStore & isVException)
      )

    return is_store_pagingFault
  }

  def is_load_misAlign: Bool = {
    val is_load_misAlign =
      lsu_cmm.is_misAlign & (
        ( rod.is_lu & is_wb ) | (rod.isVLoad & isVException & ~(rod.isFoF & exceptionIdx =/= 0.U) )
      )

    return is_load_misAlign
  }

  def is_instr_misAlign: Bool = {
    return false.B
  }

  def is_store_misAlign: Bool = {
    val is_store_misAlign =
      lsu_cmm.is_misAlign & (
        ( (rod.isXFStore | rod.is_amo) & is_wb ) | (rod.isVStore & isVException)
      )

    return is_store_misAlign
  }

  def is_ecall: Bool = {
    val is_ecall = rod.privil.ecall
    return is_ecall
  }

  def is_ecall_U: Bool = {
    val is_ecall_U = is_ecall & csrfiles.priv_lvl === "b00".U
    return is_ecall_U    
  }

  def is_ecall_S: Bool = {
    val is_ecall_S = is_ecall & csrfiles.priv_lvl === "b01".U
    return is_ecall_S    
  }

  def is_ecall_M: Bool = {
    val is_ecall_M = is_ecall & csrfiles.priv_lvl === "b11".U
    return is_ecall_M    
  }

  def is_ebreak_exc: Bool = {
    val is_ebreak_exc = rod.privil.ebreak & ~is_ebreak_breakpointn
    return is_ebreak_exc
  }

  def is_instr_access_fault: Bool = {
    val is_instr_access_fault = rod.privil.is_access_fault
    return is_instr_access_fault
  }

  def is_instr_paging_fault: Bool = {
    val is_instr_paging_fault = rod.privil.is_paging_fault
    return is_instr_paging_fault
  }

  def is_csrr_illegal: Bool = {
    val is_csrr_illegal = csrfiles.isViolateCSRR(csrExe.addr)
    return is_csrr_illegal
  }

  def is_csrw_illegal: Bool = {
    val is_csrw_illegal =
      ( csrExe.op_rc | csrExe.op_rs | csrExe.op_rw ) &
      csrfiles.isViolateCSRW(csrExe.addr)
    return is_csrw_illegal
  }

      

  def is_illeage: Bool = {
    val is_csr_illegal = 
      (is_csrr_illegal  & rod.is_csr &  is_wb) |
      (is_csrw_illegal  & rod.is_csr &  is_wb)

    val is_ill_sfence = is_wb & rod.is_sfence_vma & ( (csrfiles.mstatus.tvm & csrfiles.priv_lvl === "b01".U) | csrfiles.priv_lvl === "b00".U)
    val is_ill_wfi  = is_wb & rod.is_wfi        & (  csrfiles.mstatus.tw & csrfiles.priv_lvl < "b11".U )

    val is_ill_mRet = rod.privil.mret & csrfiles.priv_lvl =/= "b11".U
    val is_ill_sRet = rod.privil.sret & ( csrfiles.priv_lvl === "b00".U | ( csrfiles.priv_lvl === "b01".U & csrfiles.mstatus.tsr) )
    val is_ill_dRet = rod.privil.dret & ~csrfiles.DMode
    val is_ill_fpus =
      (is_wb &
      ( rod.is_fpu | // fpu and fload fstore
        (rod.is_csr & (csrExe.addr === "h001".U | csrExe.addr === "h002".U | csrExe.addr === "h003".U))
      ) & csrfiles.mstatus.fs === 0.U)

    val is_illeage = rod.is_illeage | is_csr_illegal | is_ill_sfence | is_ill_wfi | is_ill_mRet | is_ill_sRet | is_ill_dRet | is_ill_fpus
    return is_illeage.asBool
  }
     
  def is_mRet: Bool = {
    val is_mRet = rod.privil.mret & csrfiles.priv_lvl === "b11".U
    return is_mRet
  }

  def is_sRet: Bool = {
    val is_sRet = rod.privil.sret & ( csrfiles.priv_lvl === "b11".U | ( csrfiles.priv_lvl === "b01".U & ~csrfiles.mstatus.tsr.asBool) )
    return is_sRet
  }

  def is_dRet: Bool = {
    val is_dRet = rod.privil.dret & csrfiles.DMode
    return is_dRet
  }

  def is_fence_i: Bool = {
    val is_fence_i = rod.is_fence_i & is_wb
    return is_fence_i
  }

  def is_sfence_vma: Bool = {
    val is_sfence_vma = rod.is_sfence_vma & is_wb & ( (~csrfiles.mstatus.tvm.asBool & csrfiles.priv_lvl === "b01".U) | csrfiles.priv_lvl === "b11".U)
    return is_sfence_vma
  }


  def isException: Bool = {
    val isException = 
      is_ecall                 |
      is_ebreak_exc            |
      is_instr_access_fault    |
      is_instr_paging_fault    |
      is_illeage               |
      is_load_accessFault      |
      is_store_accessFault     |
      is_load_misAlign         |
      is_store_misAlign        |
      is_load_pagingFault      |
      is_store_pagingFault
    return isException
  }

  def isInterrupt: Bool = {
    val isInterrupt = (((csrfiles.is_m_interrupt | csrfiles.is_s_interrupt) & ~is_step_int_block) ) & ~csrfiles.DMode
    return isInterrupt
  }

  def is_xRet: Bool = {
    val is_xRet = is_mRet | is_sRet | is_dRet
    return is_xRet
  }

  def is_fpu_state_change: Bool = {
    val is_fpu_state_change =
      (~isInterrupt & ~isException & ~isNomaskInterrupt & ~isEbreakDM) &
      (
        (rod.is_fpu) |
        (rod.is_csr & (csrExe.addr === "h001".U | csrExe.addr === "h002".U | csrExe.addr === "h003".U))
      )
    return is_fpu_state_change
  }


  def is_ebreak_breakpointn: Bool = {
    val is_ebreak_breakpointn = ~csrfiles.DMode & 
      Mux1H(Seq(
        ( csrfiles.priv_lvl === "b11".U) -> csrfiles.dcsr.ebreakm,
        ( csrfiles.priv_lvl === "b01".U) -> csrfiles.dcsr.ebreaks,
        ( csrfiles.priv_lvl === "b00".U) -> csrfiles.dcsr.ebreaku,
      ))
    return is_ebreak_breakpointn.asBool
  }

  def is_step_int_block: Bool = {
    val is_step_int_block = ~csrfiles.dcsr.stepie & csrfiles.DMode
    return is_step_int_block.asBool
  }

  def is_step: Bool = {
    val is_step = csrfiles.dcsr.step & ~csrfiles.DMode
    return is_step.asBool
  }

  def commit_pc: UInt = {
    val commit_pc = extVaddr(rod.pc, vlen)
    return commit_pc
  } 
  
  def isEbreakDM: Bool = {
    val isEbreakDM = rod.privil.ebreak & is_ebreak_breakpointn
    return isEbreakDM
  }

  def isDebugInterrupt: Bool = {
    val isDebugInterrupt = 
      exint.is_single_step | exint.is_trigger | exint.hartHaltReq 

    return isDebugInterrupt
  }

  def isNomaskInterrupt: Bool = {
    val isNomaskInterrupt =  ~csrfiles.DMode & (isDebugInterrupt | exint.emu_reset)
    return isNomaskInterrupt
  }

  // def isVStartMdf: Bool = {
  //   val isVStartMdf = 
  //   return isVStartMdf
  // }

  // def isVlMdf: Bool = {
  //   val isVlMdf
  //   return isVlMdf
  // }

  // def isFoFTrg: Bool = {
  //   val isFoFTrg
  //   return isFoFTrg
  // }

  // def isVecRedirect: Bool = {
  //   val isVecRedirect
  //   return isVecRedirect
  // }
}

```

### src/main/scala/rift2Core/privilege/CsrFiles.scala

```scala
class CsrOperator extends Bundle{
  val dat_i = UInt(64.W)
  val op_rw = Bool()
  val op_rs = Bool()
  val op_rc = Bool()
}

class Exe_Port extends CsrOperator {
  val addr = UInt(12.W)
}


object Reg_Exe_Port {

  def apply( csr_reg: UInt, addr: UInt, ep: Exe_Port ): (Bool, UInt) = {
    val enable = (ep.addr === addr) & (ep.op_rw | ep.op_rs | ep.op_rc)
    val dnxt = Mux1H(Seq(
        ep.op_rw -> ( ep.dat_i),
        ep.op_rs -> (csr_reg | ep.dat_i),
        ep.op_rc -> (csr_reg & ~ep.dat_i),
      ))
    return (enable, dnxt)
  }
}


// abstract class  BaseCsrFiles extends BaseCommit

class FCSRBundle extends Bundle{
  val frm      = UInt(3.W)
  val fflags   = UInt(5.W)
}

class VCSRBundle extends Bundle{
  val vxrm     = UInt(2.W)
  val vxsat    = UInt(1.W)
}

class VConfigBundle(implicit p: Parameters) extends RiftBundle{
  require( log2Ceil(vParams.vlmax+1) <= 55 )
  val vill     = UInt(1.W)
  val vl       = UInt(55.W)
  val vtype    = UInt(8.W)
}

/**
  * Machine Status Registers
  * @param SD (63) whether either fs or xs is dirty
  * @param MBE (37) endian of M-mode, when 0, is little-endian, hard-wire to 0.U(64.bits)
  * @param SBE (36) endian of S-mode, when 0, is little-endian, hard-wire to 0.U(64.bits)
  * @param SXL (35,34) XLEN of S-mode, hard-wire to 2.U(64.bits)
  * @param UXL (33,32) XLEN of U-mode, hard-wire to 2.U(64.bits)
  * @param TSR (22) trap sret, when 1, sret in s-mode cause illegal instruction exception
  * @param TW (21) Time out wait for WFI, when 1 wfi cause illegal instruction exception in U\S-MODE
  * @param TVM (20) Trap Virtual Memory, when 1, access satp or Sfence.vma will cause illegal instruction exception
  * @param MXR (19) Make executable Readable. When 0, only loads form pages marked readable
  * @param SUM (18) permit Supervisor User Memory access. When 0, S-mode accesses to page.U === 1 will fault.
  * @param MPRV (17) Memory Privilege; When 1, load store using trans&protect in M-mode; When MRET or SRet to S\U-mode, set to 0.
  * @param XS (16,15) aditional user-mode extension and associated state
  * @param FS (14,13) float point statuw=s
  * @param MPP (12,11) Previous Mode is U-mode or S-mode or M-mode? When MRet, privilege mode update to MPP, MPP set to "U"
  * @param SPP (8) Previous Mode is U-mode or S-mode? When SRet, privilege mode update to SPP, SPP set to "U"
  * @param MPIE (7)  When MRet, MPIE set to 1
  * @param UBE (6) endian of U-mode, when 0, is little-endian, hard-wire to 0.U(64.bits)
  * @param SPIE (5) When SRet, SPIE set to 1
  * @param MIE (3) M-mode Interrupt Enable; When MRet, update to MPIE
  * @param SIE (1) S-mode Interrupt Enable; When SRet, update to SPIE
  */
class MStatusBundle extends Bundle{
  val sd = UInt(1.W)
  val reserved0 = UInt(25.W)
  val mbe = UInt(1.W)
  val sbe = UInt(1.W)
  val sxl = UInt(2.W)
  val uxl = UInt(2.W)
  val reserved1 = UInt(9.W)
  val tsr = UInt(1.W)
  val tw = UInt(1.W)
  val tvm = UInt(1.W)
  val mxr = UInt(1.W)
  val sum = UInt(1.W)
  val mprv = UInt(1.W)
  val xs = UInt(2.W)
  val fs = UInt(2.W)
  val mpp = UInt(2.W)
  val reserved2 = UInt(2.W)
  val spp = UInt(1.W)
  val mpie = UInt(1.W)
  val ube = UInt(1.W)
  val spie = UInt(1.W)
  val reserved3 = UInt(1.W)
  val mie = UInt(1.W)
  val reserved4 = UInt(1.W)
  val sie = UInt(1.W)
  val reserved5 = UInt(1.W)
}

class MSIntBundle extends Bundle{
  val reserved0 = UInt(4.W)
  val mei       = UInt(1.W)
  val reserved1 = UInt(1.W)
  val sei       = UInt(1.W)
  val reserved2 = UInt(1.W)
  val mti       = UInt(1.W)
  val reserved3 = UInt(1.W)
  val sti       = UInt(1.W)
  val reserved4 = UInt(1.W)
  val msi       = UInt(1.W)
  val reserved5 = UInt(1.W)
  val ssi       = UInt(1.W)
  val reserved6 = UInt(1.W)
}

class TVecBundle extends Bundle{
  val base = UInt(62.W)
  val mode = UInt(2.W)
}

class CounterenBundle extends Bundle{
  val hpm = UInt(32.W)
  def ir = hpm(2)
  def tm = hpm(1)
  def cy = hpm(0)
}

class CauseBundle extends Bundle{
  val interrupt = UInt(1.W)
  val exception_code = UInt(63.W)
}

class PmpcfgBundle extends Bundle{
  val L = UInt(1.W)
  val reserved0 = UInt(2.W)
  val A = UInt(2.W)
  val X = UInt(1.W)
  val W = UInt(1.W)
  val R = UInt(1.W)
}

class SatpBundle extends Bundle{
  val mode = UInt(4.W)
  val asid = UInt(16.W)
  val ppn = UInt(44.W)
}

class DcsrBundle extends Bundle{
  val xdebugver = UInt(4.W)
  val reserved0 = UInt(12.W)
  val ebreakm   = UInt(1.W)
  val reserved1 = UInt(1.W)
  val ebreaks   = UInt(1.W)
  val ebreaku   = UInt(1.W)
  val stepie    = UInt(1.W)
  val stopcount = UInt(1.W)
  val stoptime  = UInt(1.W)
  val cause     = UInt(3.W)
  val reserved2 = UInt(1.W)
  val mprven    = UInt(1.W)
  val nmip      = UInt(1.W)
  val step      = UInt(1.W)
  val prv       = UInt(2.W)
}

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

  def is_ssi: Bool = { 
    val is_ssi = mip.ssi & mie.ssi & mstatus.sie & ~( priv_lvl === "b11".U & mideleg(1) )
    return is_ssi.asBool
  }
  def is_msi: Bool = { 
    val is_msi = mip.msi & mie.msi & mstatus.mie
    return is_msi.asBool
  }
  def is_sti: Bool = { 
    val is_sti = mip.sti & mie.sti & mstatus.sie & ~( priv_lvl === "b11".U & mideleg(5) )
    return is_sti.asBool
  }
  def is_mti: Bool = { 
    val is_mti = mip.mti & mie.mti & mstatus.mie
    return is_mti.asBool
  }
  def is_sei: Bool = { 
    val is_sei = mip.sei & mie.sei & mstatus.sie & ~( priv_lvl === "b11".U & mideleg(9) )
    return is_sei.asBool
  }
  def is_mei: Bool = { 
    val is_mei = mip.mei & mie.mei & mstatus.mie
    return is_mei.asBool
  }
  def is_m_interrupt: Bool = {
    val is_m_interrupt = is_msi | is_mti | is_mei
    return is_m_interrupt
  }
  def is_s_interrupt: Bool = {
    val is_s_interrupt = is_ssi | is_sti | is_sei
    return is_s_interrupt
  }


  def isViolateCSRR(addr: UInt): Bool = {
    return MuxCase( true.B, //non-exist csr
      Seq( //special situation has higher priority
        ( addr === "h180".U ) -> ~((priv_lvl === "b11".U) | (priv_lvl === "b01".U & mstatus.tvm === 0.U)), //TVM IN S-MODE
        ( addr === "hB00".U ) -> ~((priv_lvl === "b11".U) | (priv_lvl === "b01".U & mcounteren.cy)),
        ( addr === "hB02".U ) -> ~((priv_lvl === "b11".U) | (priv_lvl === "b01".U & mcounteren.ir)),
      ) ++
      CSRInfoTable.CSRGroup.map{ csr =>
        (addr === (csr.address).U) -> 
          ( (priv_lvl < (csr.priv).U) | //wrong priv
            (if( csr.isDMode ) { ~DMode } else {false.B})
          )
      }
    )
  }

  def isViolateCSRW(addr: UInt): Bool = {
    return CSRInfoTable.CSRGroup.map{ csr =>
      (addr === (csr.address).U) & ((csr.isRO).B)
    }.reduce(_|_)
  }

}

trait UpdateCsrFilesFun { this: BaseCommit =>
// ...
  def update_priv_lvl( in: CMMState_Bundle ): UInt = {
    val priv_lvl = WireDefault( in.csrfiles.priv_lvl )

    when(in.exint.emu_reset) { priv_lvl := "b11".U}

    when( in.csrfiles.DMode ) {
      when(in.is_dRet) { priv_lvl := in.csrfiles.dcsr.prv }
    } .otherwise {
      when(in.is_mRet) { priv_lvl := in.csrfiles.mstatus.mpp }
      when(in.is_sRet) { priv_lvl := in.csrfiles.mstatus.spp }

      when(in.csrfiles.is_ssi) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux( ~in.csrfiles.mideleg(1), "b11".U, "b01".U ) ) }
      when(in.csrfiles.is_msi) { priv_lvl := "b11".U }
      when(in.csrfiles.is_sti) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux( ~in.csrfiles.mideleg(5), "b11".U, "b01".U ) ) }
      when(in.csrfiles.is_mti) { priv_lvl := "b11".U }
      when(in.csrfiles.is_sei) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux( ~in.csrfiles.mideleg(9), "b11".U, "b01".U ) ) }
      when(in.csrfiles.is_mei) { priv_lvl := "b11".U }


      when(in.is_instr_misAlign       ) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux(~in.csrfiles.medeleg(0),  "b11".U, "b01".U) )}
      when(in.is_instr_access_fault   ) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux(~in.csrfiles.medeleg(1),  "b11".U, "b01".U) )}
      when(in.is_illeage              ) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux(~in.csrfiles.medeleg(2),  "b11".U, "b01".U) )}
      when(in.is_ebreak_exc           ) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux(~in.csrfiles.medeleg(3),  "b11".U, "b01".U) )}
      when(in.is_load_misAlign        ) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux(~in.csrfiles.medeleg(4),  "b11".U, "b01".U) )}
      when(in.is_load_accessFault     ) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux(~in.csrfiles.medeleg(5),  "b11".U, "b01".U) )}
      when(in.is_store_misAlign       ) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux(~in.csrfiles.medeleg(6),  "b11".U, "b01".U) )}
      when(in.is_store_accessFault    ) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux(~in.csrfiles.medeleg(7),  "b11".U, "b01".U) )}
      when(in.is_ecall_U              ) { priv_lvl := Mux(~in.csrfiles.medeleg(8), "b11".U, "b01".U) }
      when(in.is_ecall_S              ) { priv_lvl := Mux(~in.csrfiles.medeleg(9), "b11".U, "b01".U) }
      when(in.is_ecall_M              ) { priv_lvl :=  "b11".U }
      when(in.is_instr_paging_fault   ) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux(~in.csrfiles.medeleg(12), "b11".U, "b01".U) )}
      when(in.is_load_pagingFault     ) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux(~in.csrfiles.medeleg(13), "b11".U, "b01".U) )}
      when(in.is_store_pagingFault    ) { priv_lvl := Mux( in.csrfiles.priv_lvl === "b11".U, "b11".U, Mux(~in.csrfiles.medeleg(15), "b11".U, "b01".U) )}

    }
    
    return priv_lvl
  }


// ...
  def update_csrfiles( in: CMMState_Bundle ): CSR_Bundle = {
    val csrfiles = Wire( new CSR_Bundle )
    csrfiles.priv_lvl      := update_priv_lvl(in)
    csrfiles.DMode         := update_DMode(in)
    csrfiles.fcsr          := update_fcsr(in)
    csrfiles.stvec         := update_stvec(in)
    csrfiles.scounteren    := update_scounteren(in)
    csrfiles.sscratch      := update_sscratch(in)
    csrfiles.sepc          := update_sepc(in)
    csrfiles.scause        := update_scause(in)
    csrfiles.stval         := update_stval(in)
    // csrfiles.sip           := update_sip(in)
    csrfiles.satp          := update_satp(in)
    csrfiles.mvendorid     := update_mvendorid(in)
    csrfiles.marchid       := update_marchid(in)
    csrfiles.mimpid        := update_mimpid(in)
    csrfiles.mhartid       := update_mhartid(in)
    csrfiles.mstatus       := update_mstatus(in)
    csrfiles.misa          := update_misa(in)
    csrfiles.medeleg       := update_medeleg(in)
    csrfiles.mideleg       := update_mideleg(in)
    csrfiles.mie           := update_mie(in)
    csrfiles.mtvec         := update_mtvec(in)
    csrfiles.mcounteren    := update_mcounteren(in)
    csrfiles.mscratch      := update_mscratch(in)
    csrfiles.mepc          := update_mepc(in)
    csrfiles.mcause        := update_mcause(in)
    csrfiles.mtval         := update_mtval(in)
    csrfiles.mip           := update_mip(in)
    csrfiles.mtinst        := update_mtinst(in)
    csrfiles.mtval2        := update_mtval2(in)
    csrfiles.mcycle        := update_mcycle(in)
    csrfiles.minstret      := update_minstret(in)
    csrfiles.mcountinhibit := update_mcountinhibit(in)
    csrfiles.tselect       := update_tselect (in)
    csrfiles.tdata1        := update_tdata1 (in)
    csrfiles.tdata2        := update_tdata2 (in)
    csrfiles.tdata3        := update_tdata3(in)
    csrfiles.dcsr          := update_dcsr (in)
    csrfiles.dpc           := update_dpc(in)
    csrfiles.dscratch0     := update_dscratch0 (in)
    csrfiles.dscratch1     := update_dscratch1 (in)
    csrfiles.dscratch2     := update_dscratch2 (in)
    csrfiles.pmpcfg        := update_pmpcfg(in)
    csrfiles.pmpaddr       := update_pmpaddr(in)
    csrfiles.mhpmcounter   := update_mhpmcounter(in)
    csrfiles.mhpmevent     := update_mhpmevent(in)

    csrfiles.time := DontCare

    if(hasVector){
      csrfiles.vstart  := update_vstart(in)
      csrfiles.vcsr    := update_vcsr(in)
      csrfiles.vl      := csrfiles.vConfig.vl
      csrfiles.vtype   := Cat( csrfiles.vConfig.vill, 0.U(55.W), csrfiles.vConfig.vtype)
      csrfiles.vConfig := update_vConfig(in)
      csrfiles.vlenb   := update_vlenb(in)      
    } else{
      csrfiles.vstart  := DontCare
      csrfiles.vcsr    := DontCare
      csrfiles.vl      := DontCare
      csrfiles.vtype   := DontCare
      csrfiles.vConfig := DontCare
      csrfiles.vlenb   := DontCare
    }

    csrfiles.sstatus    := (csrfiles.mstatus.asUInt & Cat( "b1".U, 0.U(29.W), "b11".U, 0.U(12.W), "b11011110000101100010".U )).asTypeOf(new MStatusBundle)
    csrfiles.sie        := csrfiles.mie
    csrfiles.sip        := csrfiles.mip
    csrfiles.cycle      := csrfiles.mcycle
    csrfiles.instret    := csrfiles.minstret
    csrfiles.hpmcounter := csrfiles.mhpmcounter

    csrfiles.fflags     := csrfiles.fcsr.fflags
    csrfiles.frm        := csrfiles.fcsr.frm

    return csrfiles
  }
}
```

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class Info_reorder_i(implicit p: Parameters) extends RiftBundle {
  val pc = UInt(vlen.W)
  val rd0_raw = UInt(5.W)
  val rd0_phy = UInt((log2Ceil(maxRegNum)).W)

  val is_branch = Bool()
  val is_jalr = Bool()

  val is_lu = Bool()
  val isXFStore = Bool()
  val is_amo = Bool()
  val is_sc = Bool()
  val is_fence = Bool()
  val is_fence_i = Bool()
  val is_sfence_vma = Bool()


  val is_wfi = Bool()
  val is_csr = Bool()
  val is_fpu = Bool()
  val is_fcsr = Bool()
  val is_rvc = Bool()

  val isXwb = Bool()
  val isFwb = Bool()
  val isVwb = Bool()

  val privil = new Privil_isa
  val is_illeage = Bool()

  val isVector = Bool()
  val isVLoad = Bool()
  val isVStore = Bool()
  val isFoF    = Bool()
  val vlIdx    = UInt( (log2Ceil(vParams.vlmax)+1).W )

}




// ...
class Info_cmm_lsu(implicit p: Parameters) extends RiftBundle {
  // val isVstorePending = Bool()
  val is_amo_pending  = Bool()
  val is_store_commit = Vec(cmChn, Bool())
}

class Info_lsu_cmm(implicit p: Parameters) extends RiftBundle {
  val is_access_fault = Bool()
  val is_paging_fault = Bool()
  val is_misAlign = Bool()
  val trap_addr = UInt(64.W)
}
// ...
class Commit_Redirect_Bundle(implicit p: Parameters) extends RiftBundle{
  val pc = UInt(64.W)
}
// ...
class Info_if_cmm(implicit p: Parameters) extends RiftBundle {
  val ill_vaddr = UInt(64.W)
}

class AClint_Bundle extends Bundle {
  val msi = Bool()
  val mti = Bool()

  val ssi = Bool()
  val sti = Bool()
}

class Plic_Bundle extends Bundle {
  val mei = Bool()
  val sei = Bool()
}

```

### src/main/scala/rift2Core/define/frontend.scala

```scala
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
```

### src/main/scala/rift2Core/vector/VRegfiles.scala

```scala
class Vector_Commit_Bundle()(implicit p: Parameters) extends RiftBundle{
  val isComfirm = Output(Bool())
  val isAbort   = Output(Bool())
  val phy       = Output(UInt(( log2Ceil(33) ).W))

  val isWroteback  = Input(Bool())
  val isException  = Input(Bool())
  val exceptionIdx = Input(UInt((log2Ceil(vParams.vlen/8).W)))
}
```

### src/main/scala/rift2Core/privilege/MMU.scala

```scala
class Info_cmm_mmu(implicit p: Parameters) extends RiftBundle {
  val satp = UInt(64.W)

	val pmpcfg  = (if( pmpNum == 0 ) { Vec(1,   UInt(64.W)) } else { Vec(pmpNum,   UInt(64.W)) })
  val pmpaddr = (if( pmpNum == 0 ) { Vec(8*1, UInt(64.W)) } else { Vec(8*pmpNum, UInt(64.W)) })

  val priv_lvl_if = UInt(2.W)
  val priv_lvl_ls = UInt(2.W)

  val mstatus = UInt(64.W)
  val sstatus = UInt(64.W)

  val sfence_vma = Bool()

}
```

### src/main/scala/rift2Core/diff.scala

```scala
class Info_cmm_diff(implicit p: Parameters) extends RiftBundle {
  val pc = Vec(cmChn, UInt(64.W))
  val comfirm = Vec(cmChn, Bool())
  val abort = Vec(cmChn, Bool())
  val priv_lvl = UInt(2.W)
  val is_ecall_M = Bool()
  val is_ecall_S = Bool()
  val is_ecall_U = Bool()
}

class Info_csr_reg(implicit p: Parameters) extends RiftBundle {
	val mstatus = UInt(64.W)
	val mtvec = UInt(64.W)
	val mscratch = UInt(64.W)
	val mepc = UInt(64.W)
	val mcause = UInt(64.W)
	val mtval = UInt(64.W)

  val mvendorid = UInt(64.W)
  val marchid = UInt(64.W)
  val mimpid = UInt(64.W)
  val mhartid = UInt(64.W)
  val misa = UInt(64.W)
  val mie = UInt(64.W)
  val mip = UInt(64.W)
  val medeleg = UInt(64.W)
  val mideleg = UInt(64.W)
  // val mcounteren = UInt(64.W)
  // val mcountinhibit = UInt(64.W)
  // val tselect = UInt(64.W)
  // val tdata1[MAX_TRIGGERS] = UInt(64.W)
  // val tdata2[MAX_TRIGGERS] = UInt(64.W)
  // val tdata3[MAX_TRIGGERS] = UInt(64.W)
  // val mhpmevent[32] = UInt(64.W)

  val pmpcfg  = (if( pmpNum == 0 ) { Vec(1, UInt(64.W))}        else {Vec(pmpNum, UInt(64.W))})
	val pmpaddr = (if( pmpNum == 0 ) { Vec(8, UInt(64.W))} else {Vec(8*pmpNum, UInt(64.W))})


  val stvec = UInt(64.W)
  val sscratch = UInt(64.W)
  val sepc = UInt(64.W)
  val scause = UInt(64.W)
  val stval = UInt(64.W)
  val satp = UInt(64.W)

  // val scounteren = UInt(64.W)
  // val dcsr = UInt(64.W)
  // val dpc = UInt(64.W)
  // val dscratch;  = UInt(64.W)

  val fflags = UInt(32.W)
  val frm = UInt(8.W)

  val mcycle      = UInt(64.W)
  val minstret    = UInt(64.W)
  val mhpmcounter = Vec( 32, UInt(64.W))
}
```

### src/main/scala/rift2Chip/Debug/DM.scala

```scala
class Info_DM_cmm() extends Bundle{
  val hartIsInReset = Input(Bool())
  val hartResetReq = Output(Bool())
  val hartHaltReq = Output(Bool())
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

## Related source code

### src/main/scala/rift2Core/frontend/IF2.scala

```scala
   * @param ifence an Input boolean used to signal that an instruction fetch fence should be inserted
// ...
    val ifence = Input(Bool())
```
