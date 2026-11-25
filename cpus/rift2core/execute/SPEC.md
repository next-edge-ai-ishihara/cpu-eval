# Implement `Execute`

Implement the complete `Execute` class. Preserve the class name and interface shown below.

Return only the complete `class Execute` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/Config.scala

```scala
class Rift2330 extends Config((_, _, _) => {
  case RiftParamsKey => RiftSetting(
    hasL2  = true,
// ...
  )
})

```

### src/main/scala/Parameters.scala

```scala
case class RiftSetting(
// ...
  aluNum: Int = 2,
  mulNum: Int = 1,
  fpuNum: Int = 0,

```

## Class declaration

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

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val exe_stage = Module(new Execute( (Seq( dcache_edge, system_edge, periph_edge ) ) ) )
// ...
  iss_stage.io.alu_iss_exe <> exe_stage.io.alu_iss_exe
  iss_stage.io.bru_iss_exe <> exe_stage.io.bru_iss_exe
  iss_stage.io.lsu_iss_exe <> exe_stage.io.lsu_iss_exe
  iss_stage.io.csr_iss_exe <> exe_stage.io.csr_iss_exe
  iss_stage.io.mul_iss_exe <> exe_stage.io.mul_iss_exe
  iss_stage.io.fpu_iss_exe <> exe_stage.io.fpu_iss_exe

  iwb_stage.io.xLookup <> rnm_stage.io.xLookup
  iwb_stage.io.fLookup <> rnm_stage.io.fLookup

  iwb_stage.io.xRename <> rnm_stage.io.xRename
  iwb_stage.io.fRename <> rnm_stage.io.fRename


  iss_stage.io.irgLog := iwb_stage.io.irgLog
  iss_stage.io.frgLog := iwb_stage.io.frgLog

  iwb_stage.io.irgReq := iss_stage.io.irgReq
  iwb_stage.io.frgReq := iss_stage.io.frgReq

  iss_stage.io.irgRsp := iwb_stage.io.irgRsp
  iss_stage.io.frgRsp := iwb_stage.io.frgRsp

  iwb_stage.io.alu_iWriteBack <> exe_stage.io.alu_exe_iwb
  iwb_stage.io.bru_iWriteBack <> exe_stage.io.bru_exe_iwb
  iwb_stage.io.csr_iWriteBack <> exe_stage.io.csr_exe_iwb
  iwb_stage.io.mul_iWriteBack <> exe_stage.io.mul_exe_iwb

  iwb_stage.io.mem_iWriteBack <> exe_stage.io.lsu_exe_iwb
  iwb_stage.io.mem_fWriteBack <> exe_stage.io.lsu_exe_fwb
  iwb_stage.io.mem_vWriteBack <> exe_stage.io.lsu_exe_vwb

  iwb_stage.io.fpu_iWriteBack <> exe_stage.io.fpu_exe_iwb
  iwb_stage.io.fpu_fWriteBack <> exe_stage.io.fpu_exe_fwb

  iwb_stage.io.xpuCsrWriteBack := exe_stage.io.xpuCsrWriteBack
  iwb_stage.io.fpuCsrWriteBack := exe_stage.io.fpuCsrWriteBack
  iwb_stage.io.vpuCsrWriteBack.valid := false.B
  iwb_stage.io.vpuCsrWriteBack.bits  := DontCare

```

## Dependency declarations

### src/main/scala/rift2Core/backend/Alu.scala

```scala
class Alu(implicit p: Parameters) extends RiftModule {

  class AluIO extends Bundle{
    val alu_iss_exe = Flipped(new DecoupledIO(new Alu_iss_info))
    val alu_exe_iwb = new DecoupledIO(new WriteBack_info(dw=64))

    val flush = Input(Bool())    
  }
  
  val io = IO(new AluIO)

```

### src/main/scala/rift2Core/backend/Bru.scala

```scala
abstract class BruBase()(implicit p: Parameters) extends RiftModule {
  class BruIO extends Bundle{
    val bru_iss_exe = Flipped(new DecoupledIO(new Bru_iss_info))
    val bru_exe_iwb = new DecoupledIO(new WriteBack_info(dw=64))

    val bftq = Flipped(Decoupled(new Branch_FTarget_Bundle))
    val jftq = Flipped(Decoupled(new Jump_FTarget_Bundle))

    val bctq = Decoupled(new Branch_CTarget_Bundle)
    val jctq = Decoupled(new Jump_CTarget_Bundle)

    val bcmm_update = Valid(new Branch_CTarget_Bundle)
    val jcmm_update = Valid(new Jump_CTarget_Bundle)

    val flush = Input(Bool())    
  }

  val io: BruIO = IO(new BruIO)

```

### src/main/scala/rift2Core/backend/LSU/Lsu.scala

```scala
abstract class LsuBase (edge: Seq[TLEdgeOut])(implicit p: Parameters) extends DcacheModule with HasFPUParameters {
  val dEdge = edge

  class LsuIO extends Bundle{
    val lsu_iss_exe = Flipped(Decoupled(new Lsu_iss_info))
    val lsu_exe_iwb = Decoupled(new WriteBack_info(dw=64))
    val lsu_exe_fwb = Decoupled(new WriteBack_info(dw=65))
    val lsu_exe_vwb = Decoupled(new Vector_WriteBack_Bundle)

            // val lsu_cWriteBack = Valid(new SeqReg_WriteBack_Bundle(64, cRegNum))

    val cmm_lsu = Input(new Info_cmm_lsu)
    val lsu_cmm = Output( new Info_lsu_cmm )

    val lsu_mmu = DecoupledIO(new Info_mmu_req)
    val mmu_lsu = Flipped(DecoupledIO(new Info_mmu_rsp))

    val missUnit_dcache_acquire      = if( hasL2 ) Some(new DecoupledIO(new TLBundleA(dEdge(0).bundle)))          else {None}
    val missUnit_dcache_grant        = if( hasL2 ) Some(Flipped(new DecoupledIO(new TLBundleD(dEdge(0).bundle)))) else {None}
    val missUnit_dcache_grantAck     = if( hasL2 ) Some(DecoupledIO(new TLBundleE(dEdge(0).bundle)))              else {None}
    val probeUnit_dcache_probe       = if( hasL2 ) Some(Flipped(new DecoupledIO(new TLBundleB(dEdge(0).bundle)))) else {None}
    val writeBackUnit_dcache_release = if( hasL2 ) Some(new DecoupledIO(new TLBundleC(dEdge(0).bundle))         ) else {None}
    val writeBackUnit_dcache_grant   = if( hasL2 ) Some(Flipped(new DecoupledIO(new TLBundleD(dEdge(0).bundle)))) else {None}

    val dcache_getPut = if ( hasL2 ) { None } else { Some(        new DecoupledIO(new TLBundleA(dEdge(0).bundle)) ) }
    val dcache_access = if ( hasL2 ) { None } else { Some(Flipped(new DecoupledIO(new TLBundleD(dEdge(0).bundle)))) }


    val system_getPut = new DecoupledIO(new TLBundleA(dEdge(1).bundle))
    val system_access = Flipped(new DecoupledIO(new TLBundleD(dEdge(1).bundle)))

    val periph_getPut = new DecoupledIO(new TLBundleA(dEdge(2).bundle))
    val periph_access = Flipped(new DecoupledIO(new TLBundleD(dEdge(2).bundle)))

    val preFetch = ValidIO( new PreFetch_Req_Bundle )

    val flush = Input(Bool())    
  }


  val io: LsuIO = IO(new LsuIO)
// ...
class Lsu(edge: Seq[TLEdgeOut])(implicit p: Parameters) extends LsuBase(edge)

```

### src/main/scala/rift2Core/backend/Csr.scala

```scala
abstract class CSRBase(implicit p: Parameters) extends RiftModule {

  class CsrIO extends Bundle {

    val csr_iss_exe = Flipped(new DecoupledIO(new Csr_iss_info))
    val csr_exe_iwb = new DecoupledIO(new WriteBack_info(dw=64))
    val xpuCsrWriteBack = Valid(new Exe_Port)

    val flush = Input(Bool())    
  }

  val io: CsrIO = IO(new CsrIO)
// ...
class CSR(implicit p: Parameters) extends CSRBase 

```

### src/main/scala/rift2Core/backend/Mul.scala

```scala
abstract class MulDivBase(implicit p: Parameters) extends RiftModule {
  
  class MulDivIO extends Bundle{
    val mul_iss_exe = Flipped(new DecoupledIO(new Mul_iss_info))
    val mul_exe_iwb = new DecoupledIO(new WriteBack_info(dw=64))
    val flush = Input(Bool())    
  }

  val io: MulDivIO = IO(new MulDivIO)

```

### src/main/scala/rift2Core/backend/FPU/FAlu.scala

```scala
class FAluIO(implicit p: Parameters) extends RiftBundle{
  val fpu_iss_exe = Flipped(DecoupledIO(new Fpu_iss_info))
  val fpu_exe_iwb = DecoupledIO(new WriteBack_info(dw=65))
  val fpu_exe_fwb = DecoupledIO(new WriteBack_info(dw=65))
          // val fpu_cWriteBack = Valid(new SeqReg_WriteBack_Bundle(64, cRegNum))
  val fpuCsrWriteBack = Valid(new Exe_Port)

  val flush = Input(Bool())
}


class FAlu(latency: Int = 5, infly: Int = 8)(implicit p: Parameters) extends RiftModule with HasFPUParameters{
  val io: FAluIO = IO(new FAluIO)
// ...
class FakeFAlu(implicit p: Parameters) extends RiftModule with HasFPUParameters{

  val io: FAluIO = IO(new FAluIO)

```
