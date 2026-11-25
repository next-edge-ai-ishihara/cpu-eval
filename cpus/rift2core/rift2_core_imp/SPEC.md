# Implement `Rift2CoreImp`

Implement the complete `Rift2CoreImp` class. Preserve the class name and interface shown below.

Return only the complete `class Rift2CoreImp` definition in a single Scala code block, with no text outside the block.

## Package and imports

### src/main/scala/rift2Core/rift2Core.scala

```scala
package rift2Core

import chisel3._
import chisel3.util._
import rift2Chip._
import rift2Core.frontend._
import rift2Core.backend._
import rift2Core.diff._
import rift2Core.privilege._
import debug._

import rift2Core.define._

import org.chipsalliance.cde.config._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tilelink._

import chisel3.util.experimental.{FlattenInstance, InlineInstance}
```

## Class declaration

### src/main/scala/rift2Core/rift2Core.scala

```scala
class Rift2CoreImp(outer: Rift2Core, isFlatten: Boolean = false)(implicit p: Parameters) extends Rift2CoreImpBase(outer, isFlatten)
```

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  lazy val module: Rift2CoreImp = if(isFlatten) {new Rift2CoreImp(this) with FlattenInstance} else {new Rift2CoreImp(this)}
```

## Dependency declarations

### src/main/scala/rift2Core/rift2Core.scala

```scala
abstract class Rift2CoreImpBase(outer: Rift2Core, isFlatten: Boolean = false) extends LazyModuleImp(outer) with HasRiftParameters { 
  class Rift2CoreIO extends Bundle{
    val dm        = if (hasDebugger) {Some(Flipped(new Info_DM_cmm))} else {None}
    val rtc_clock = Input(Bool())
    val aclint = Input(new AClint_Bundle)
    val plic = Input(new Plic_Bundle)    
  }
  
  val io: Rift2CoreIO = IO(new Rift2CoreIO)

  val ( icache_bus, icache_edge ) = outer.icacheClientNode.out.head
  val ( dcache_bus, dcache_edge ) = outer.dcacheClientNode.out.head
  val ( system_bus, system_edge ) = outer.systemClientNode.out.head
  val ( periph_bus, periph_edge ) = outer.periphClientNode.out.head
  val (    mmu_bus,    mmu_edge ) = outer.mmuClientNode.out.head
  val ( prefetch_bus, prefetch_edge) = outer.prefetchClinetNode.out.head


  val if1 = (if (hasuBTB) {Module(new IF1Predict)} else {Module(new IF1NPredict)})
  val if2 = Module(new IF2(icache_edge))
  val if3 = Module(new IF3)
  val if4 = Module(new IF4)
  val preRename_stage = if(hasVector) { Module(new VecPreRename) } else { Module(new FakeVecPreRename) }
  val rnm_stage = Module(new Rename)
  val preIssue_stage = if(hasVector) { Module(new VecPreIssue) } else { Module(new FakeVecPreIssue) }
  val iss_stage = Module(new Issue)
  val exe_stage = Module(new Execute( (Seq( dcache_edge, system_edge, periph_edge ) ) ) )
  val iwb_stage = Module(new WriteBack)
  val cmm_stage = Module(new Commit)
  val i_mmu = Module(new MMU(edge = mmu_edge ))
  val diff = Module(new diff)




}
```

### src/main/scala/rift2Core/frontend/IF1.scala

```scala
abstract class IF1Base()(implicit p: Parameters) extends IFetchModule {
// ...
  class IF1IO extends Bundle{
    val if4Redirect = Flipped(Valid(new IF4_Redirect_Bundle))
    val cmmRedirect = Flipped(Valid(new Commit_Redirect_Bundle))

    val pc_gen = Decoupled(new IF1_Bundle)

    val jcmm_update = Flipped(Valid(new Jump_CTarget_Bundle))
    val bcmm_update = Flipped(Valid(new Branch_CTarget_Bundle))    
  }


  val io: IF1IO = IO(new IF1IO)
```

### src/main/scala/rift2Core/frontend/IF2.scala

```scala
abstract class IF2Base(edge: TLEdgeOut)(implicit p: Parameters) extends IcacheModule {
  val iEdge = edge
// ...
  class IF2IO extends Bundle{
    val if2_req  = Flipped(new DecoupledIO( new IF1_Bundle ))
    val if2_resp = Vec( 4, new DecoupledIO(new IF2_Bundle) )

    val if_mmu = DecoupledIO(new Info_mmu_req)
    val mmu_if = Flipped(DecoupledIO(new Info_mmu_rsp))

    val if_cmm = Output(new Info_if_cmm)

    val icache_get    = new DecoupledIO(new TLBundleA(iEdge.bundle))
    val icache_access = Flipped(new DecoupledIO(new TLBundleD(iEdge.bundle)))

    val flush = Input(Bool())

    val ifence = Input(Bool())

    /** prefetch is not guarantee to be accepted by cache*/
    val preFetch = ValidIO( new PreFetch_Req_Bundle )    
  }

  val io: IF2IO = IO(new IF2IO)
// ...
class IF2(edge: TLEdgeOut)(implicit p: Parameters) extends IF2Base(edge)
```

### src/main/scala/rift2Core/frontend/IF3.scala

```scala
abstract class IF3Base()(implicit p: Parameters) extends IFetchModule {
// ...
  class IF3IO extends Bundle{
    val if3_req = Vec(4, Flipped(new DecoupledIO(new IF2_Bundle) ))
    val if3_resp = Vec(rnChn, Decoupled(new IF3_Bundle))

    val btbResp  = Vec(rnChn, Decoupled(new BTBResp_Bundle))
    val bimResp  = Vec(rnChn, Decoupled(new BIMResp_Bundle))
    val tageResp = Vec(rnChn, Decoupled(Vec(6, new TageTableResp_Bundle )))

    val jcmm_update = Flipped(Valid(new Jump_CTarget_Bundle))
    val bcmm_update = Flipped(Valid(new Branch_CTarget_Bundle))

    val if4_update_ghist = Vec(rnChn, Flipped(Valid(new Ghist_reflash_Bundle)))
    val if4Redirect = Flipped(Valid(new IF4_Redirect_Bundle))

    val flush = Input(Bool())    
  }

  val io: IF3IO = IO(new IF3IO)
```

### src/main/scala/rift2Core/frontend/IF4.scala

```scala
abstract class IF4Base()(implicit p: Parameters) extends IFetchModule {
// ...
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
```

### src/main/scala/rift2Core/vector/VecPreRename.scala

```scala
class VecPreRenameIO()(implicit p: Parameters) extends RiftBundle{
  val enq = Vec(rnChn, Flipped(new DecoupledIO(new IF4_Bundle)))
  val deq = Vec(rnChn, new DecoupledIO(new IF4_Bundle))

  val vpuCsrMolloc    = Vec(rnChn, Decoupled(Bool()))
  val csrfiles   = Input(new CSR_Bundle)

  val isVStartRsv = Input(Bool())
  val isVSetRsv   = Input(Bool())
  val isFoFRsv    = Input(UInt((log2Ceil(cmChn)+1).W))

  val flush = Input(Bool())
}
// ...
class FakeVecPreRename()(implicit p: Parameters) extends RiftModule{
  val io: VecPreRenameIO = IO(new VecPreRenameIO)
```

### src/main/scala/rift2Core/backend/Rename.scala

```scala
abstract class RenameBase()(implicit p: Parameters) extends RiftModule {

  class RenameIO extends Bundle{
    val rnReq = Vec(rnChn, Flipped(new DecoupledIO(new IF4_Bundle)))
    val rnRsp = Vec(rnChn, (new DecoupledIO(new Dpt_info)))

    val xLookup = Vec( rnChn, new Lookup_Bundle )
    val xRename = Vec( rnChn, new Rename_Bundle )

    val fLookup = Vec( rnChn, new Lookup_Bundle )
    val fRename = Vec( rnChn, new Rename_Bundle )

    val xpuCsrMolloc    = Vec(rnChn, Decoupled(UInt(12.W)))
    val fpuCsrMolloc    = Vec(rnChn, Decoupled(Bool()))
    val isCSRMMUReady   = Input(Bool())

    val rod_i = Vec(cmChn,new DecoupledIO(new Info_reorder_i))
  }

  val io: RenameIO = IO(new RenameIO)

  val rnRspFifo = Module(new MultiPortFifo(new Dpt_info, aw = (if(!isMinArea) 4 else 1 ), rnChn, rnChn))
  rnRspFifo.io.deq <> io.rnRsp

  val reOrder_fifo_i = {
    val mdl = Module(new MultiPortFifo(new Info_reorder_i, aw = (if(!isMinArea) 4 else 1 ), rnChn, cmChn))
    mdl.io.deq <> io.rod_i
    mdl
  }

  val reg_phy = Wire(Vec(rnChn, new Reg_PHY ) )

}
// ...
class Rename()(implicit p: Parameters) extends RenameBase
```

### src/main/scala/rift2Core/vector/VecPreIssue.scala

```scala
class VecPreIssueIO()(implicit p: Parameters) extends RiftBundle{
  val enq = Vec(rnChn, Flipped(new DecoupledIO(new Dpt_info)))
  val deq = Vec(rnChn, new DecoupledIO(new Dpt_info))

  val molloc = Decoupled(new Vector_Molloc_Bundle) //molloc at read op
  val readOp = Flipped(Vec( 32, Valid(UInt( (vParams.vlen).W )) ) )

  val csrfiles = Input(new CSR_Bundle)
  val isPndVStore = Input(Bool())

  val flush = Input(Bool())
}
// ...
class FakeVecPreIssue()(implicit p: Parameters) extends RiftModule{
  val io: VecPreIssueIO = IO(new VecPreIssueIO)
```

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
// ...
abstract class DptAgeMatrix()(implicit p: Parameters) extends DptBase with DptBoard with VecDptBoard {
// ...
abstract class IssueBase()(implicit p: Parameters) extends DptAgeMatrix
with DptReadIOp
with DptReadFOp
// ...
abstract class IssueSel()(implicit p: Parameters) extends IssueBase
with IssLoadIOp
with IssLoadFOp{
// ...
class Issue()(implicit p: Parameters) extends IssueSel
```

### src/main/scala/rift2Core/backend/Execute.scala

```scala
class Execute(edge: Seq[TLEdgeOut])(implicit p: Parameters) extends RiftModule {
  class ExecuteIO extends Bundle{
    val alu_iss_exe = Vec(aluNum, Flipped(Decoupled(new Alu_iss_info)))
    val alu_exe_iwb = Vec(aluNum, Decoupled(new WriteBack_info(dw=64)))
    
    val bru_iss_exe = Flipped(Decoupled(new Bru_iss_info))
    val bru_exe_iwb = Decoupled(new WriteBack_info(dw=64))

    val csr_iss_exe = Flipped(Decoupled(new Csr_iss_info))
    val csr_exe_iwb = Decoupled(new WriteBack_info(dw=64))

    val lsu_iss_exe = Flipped(Decoupled(new Lsu_iss_info))
    val lsu_exe_iwb = Decoupled(new WriteBack_info(dw=64))
    val lsu_exe_fwb = Decoupled(new WriteBack_info(dw=65))
    val lsu_exe_vwb = Decoupled(new Vector_WriteBack_Bundle)

    val mul_iss_exe = Vec(mulNum max 1, Flipped(new DecoupledIO(new Mul_iss_info)))
    val mul_exe_iwb = Vec(mulNum max 1, new DecoupledIO(new WriteBack_info(dw=64)))

    val fpu_iss_exe = Vec(fpuNum max 1, Flipped(new DecoupledIO(new Fpu_iss_info)))
    val fpu_exe_iwb = Vec(fpuNum max 1, new DecoupledIO(new WriteBack_info(dw=64)))
    val fpu_exe_fwb = Vec(fpuNum max 1, new DecoupledIO(new WriteBack_info(dw=65)))


    val bftq = Flipped(Decoupled(new Branch_FTarget_Bundle))
    val jftq = Flipped(Decoupled(new Jump_FTarget_Bundle))

    val bctq = Decoupled(new Branch_CTarget_Bundle)
    val jctq = Decoupled(new Jump_CTarget_Bundle)

    val bcmm_update = Valid(new Branch_CTarget_Bundle)
    val jcmm_update = Valid(new Jump_CTarget_Bundle)

    // val cWriteBack = Vec(3, Valid(new SeqReg_WriteBack_Bundle(64, cRegNum)))
    val fpuCsrWriteBack = Valid(new Exe_Port)
    val xpuCsrWriteBack = Valid(new Exe_Port)

    val lsu_mmu = DecoupledIO(new Info_mmu_req)
    val mmu_lsu = Flipped(DecoupledIO(new Info_mmu_rsp))
    val cmm_lsu = Input(new Info_cmm_lsu)
    val lsu_cmm = Output( new Info_lsu_cmm )

    val missUnit_dcache_acquire  = if( hasL2 ) Some(new DecoupledIO(new TLBundleA(edge(0).bundle)))               else {None}
    val missUnit_dcache_grant    = if( hasL2 ) Some(Flipped(new DecoupledIO(new TLBundleD(edge(0).bundle))))      else {None}
    val missUnit_dcache_grantAck = if( hasL2 ) Some(DecoupledIO(new TLBundleE(edge(0).bundle)))                   else {None}
    val probeUnit_dcache_probe   = if( hasL2 )     Some(Flipped(new DecoupledIO(new TLBundleB(edge(0).bundle))))  else {None}
    val writeBackUnit_dcache_release = if( hasL2 ) Some(new DecoupledIO(new TLBundleC(edge(0).bundle))         )  else {None}
    val writeBackUnit_dcache_grant   = if( hasL2 ) Some(Flipped(new DecoupledIO(new TLBundleD(edge(0).bundle))))  else {None}

    val dcache_getPut = if ( hasL2 ) { None } else { Some(        new DecoupledIO(new TLBundleA(edge(0).bundle)) ) }
    val dcache_access = if ( hasL2 ) { None } else { Some(Flipped(new DecoupledIO(new TLBundleD(edge(0).bundle)))) }

    val system_getPut = new DecoupledIO(new TLBundleA(edge(1).bundle))
    val system_access = Flipped(new DecoupledIO(new TLBundleD(edge(1).bundle)))
    val periph_getPut = new DecoupledIO(new TLBundleA(edge(2).bundle))
    val periph_access = Flipped(new DecoupledIO(new TLBundleD(edge(2).bundle)))

    val preFetch = ValidIO( new PreFetch_Req_Bundle )

    val flush = Input(Bool())
  }

  val io: ExecuteIO = IO(new ExecuteIO)
```

### src/main/scala/rift2Core/backend/WriteBack.scala

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

### src/main/scala/rift2Core/backend/Commit.scala

```scala
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
// ...
abstract class CommitState(implicit p: Parameters) extends BaseCommit
with UpdateCsrFilesFun
with CommitBranch
with CommitDebug
{
// ...
class Commit()(implicit p: Parameters) extends CommitState
```

### src/main/scala/rift2Core/privilege/MMU.scala

```scala
class MMU(edge: TLEdgeOut)(implicit p: Parameters) extends RiftModule {

  class MMUIO extends Bundle{
    val if_mmu = Flipped(DecoupledIO(new Info_mmu_req))
    val mmu_if = DecoupledIO(new Info_mmu_rsp)
    val if_flush = Input(Bool())

    val lsu_mmu = Flipped(DecoupledIO(new Info_mmu_req))
    val mmu_lsu = DecoupledIO(new Info_mmu_rsp)
    val lsu_flush = Input(Bool())

    val cmm_mmu = Input( new Info_cmm_mmu )

    val ptw_get    = new DecoupledIO(new TLBundleA(edge.bundle))
    val ptw_access = Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))
  }

  val io: MMUIO = IO(new MMUIO)
```

### src/main/scala/rift2Core/diff.scala

```scala
class diff(implicit p: Parameters) extends RiftModule with HasFPUParameters{

  class DiffIO extends Bundle{
    val diffXReg = Input(Vec(32, UInt(64.W)))
    val diffFReg = Input(Vec(32, UInt(65.W)))

    val commit = Input(new Info_cmm_diff)
    val csr = Input(new Info_csr_reg)    
  }
  val io = IO(new DiffIO)
```

### src/main/scala/rift2Core/PreFetcher.scala

```scala
class PreFetcher(edge: TLEdgeOut)(implicit p: Parameters) extends RiftModule{

  class PreFetcherIO extends Bundle{
    val stqReq          = Flipped(Valid( new PreFetch_Req_Bundle))
    val icacheRefillReq = Flipped(Valid( new PreFetch_Req_Bundle))
    // val bruReq          = Flipped(Valid( new PreFetch_Req_Bundle))
    // val invPredictReq   = Flipped(Valid( new PreFetch_Req_Bundle))

    val intent    = new DecoupledIO(new TLBundleA(edge.bundle))
    val hintAck = Flipped(new DecoupledIO(new TLBundleD(edge.bundle))) 
  }

  val io = IO(new PreFetcherIO)
```

### src/main/scala/rift2Chip/Debug/DM.scala

```scala
class Info_DM_cmm() extends Bundle{
  val hartIsInReset = Input(Bool())
  val hartResetReq = Output(Bool())
  val hartHaltReq = Output(Bool())
}
```
