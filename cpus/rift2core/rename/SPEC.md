# Implement `Rename`

Implement the complete `Rename` class. Preserve the class name and interface shown below.

Return only the complete `class Rename` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/Config.scala

```scala
class Rift2330 extends Config((_, _, _) => {
  case RiftParamsKey => RiftSetting(
// ...
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
// ...
  )
})
```

## Package and imports

### src/main/scala/rift2Core/backend/Rename.scala

```scala
package rift2Core.backend

import chisel3._
import chisel3.util._
import base._
import rift2Core.define._
import rift2Chip._
import org.chipsalliance.cde.config._
```

## Class declaration

### src/main/scala/rift2Core/backend/Rename.scala

```scala
class Rename()(implicit p: Parameters) extends RenameBase
```

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val rnm_stage = Module(new Rename)
// ...
  if4.io.if4_resp <> preRename_stage.io.enq
  preRename_stage.io.deq <> rnm_stage.io.rnReq
// ...
  rnm_stage.io.rnRsp <> preIssue_stage.io.enq
// ...
  iwb_stage.io.xLookup <> rnm_stage.io.xLookup
  iwb_stage.io.fLookup <> rnm_stage.io.fLookup

  iwb_stage.io.xRename <> rnm_stage.io.xRename
  iwb_stage.io.fRename <> rnm_stage.io.fRename
// ...
  iwb_stage.io.xpuCsrMolloc    <> rnm_stage.io.xpuCsrMolloc
  iwb_stage.io.fpuCsrMolloc    <> rnm_stage.io.fpuCsrMolloc
// ...
  cmm_stage.io.rod <> rnm_stage.io.rod_i
// ...
  rnm_stage.io.isCSRMMUReady := iwb_stage.io.isCSRMMUReady 
// ...
  rnm_stage.reset := cmm_stage.io.cmmRedirect.fire | reset.asBool
```

## Dependency declarations

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
```

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
```

### src/main/scala/base/MultiPortFifo.scala

```scala
//dw:data type aw:address width, in: input port num, out: output port num 

class MultiPortFifo[T<:Data]( dw: T, aw: Int, in: Int, out: Int, flow: Boolean = false )(implicit p: Parameters) extends RiftModule{
  class MultiPortFifoIO extends Bundle{
    val enq = Vec(in, Flipped(new DecoupledIO(dw)) )
    val deq  = Vec(out, new DecoupledIO(dw) )

    val flush = Input(Bool())
  }
  val io: MultiPortFifoIO = IO(new MultiPortFifoIO)
// ...
    for ( i <- 0 until in; j <- 0 until in )
      assert( !(io.enq(i).valid === true.B && io.enq(j).valid === false.B && i.U >= j.U), "Assert Fail! in port illegal")

    for ( i <- 0 until out; j <- 0 until out )
      assert( !(io.deq(i).valid === true.B && io.deq(j).valid === false.B && i.U >= j.U), "Assert Fail! out port illegal")

    for ( i <- 0 until in ) {
      when( io.enq(i).fire ) {
        for ( j <- 0 until i ) {
          assert( io.enq(j).fire, "Assert Failed, illegal multi-port-fifo behavior" )
        }
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


class Privil_isa extends Bundle {
  val ecall = Bool()
  val ebreak = Bool()
  val mret = Bool()

  val uret = Bool()
  val sret = Bool()
  val dret = Bool()





  val hfence_vvma = Bool()
  val hfence_gvma = Bool()

  val hlv_b = Bool()
  val hlv_bu = Bool()
  val hlv_h = Bool()
  val hlv_hu = Bool()
  val hlvx_hu = Bool()
  val hlv_w = Bool()
  val hlvx_wu = Bool()
  val hsv_b = Bool()
  val hsv_h = Bool()
  val hsv_w = Bool()

  val hlv_wu = Bool()
  val hlv_d = Bool()
  val hsv_d = Bool()

  val is_access_fault = Bool()
  val is_paging_fault = Bool()

  def is_privil = 
    ecall | ebreak | mret | uret | sret | dret | hfence_vvma | hfence_gvma | hlv_b | hlv_bu | hlv_h | hlv_hu | hlvx_hu | hlv_w | hlvx_wu | hsv_b | hsv_h | hsv_w | hlv_wu | hlv_d | hsv_d |
    is_access_fault | is_paging_fault


}


class Fpu_isa extends Bundle {
// ...
  def hasThreeRs = 
  fmadd_s | fmsub_s | fnmsub_s | fnmadd_s | 
  fmadd_d | fmsub_d | fnmsub_d | fnmadd_d

  def hasTwoRs = hasThreeRs |
  fadd_s | fsub_s | fmul_s | fdiv_s | fsqrt_s |
  fsgnj_s | fsgnjn_s | fsgnjx_s | fsgnj_d | fsgnjn_d | fsgnjx_d |
  fmin_s | fmax_s | fmin_d | fmax_d |
  feq_s | flt_s |fle_s | feq_d | flt_d | fle_d |
  fadd_d | fsub_d | fmul_d | fdiv_d | fsqrt_d 
  //| fcsr_rw | fcsr_rs | fcsr_rc | fcsr_rwi | fcsr_rsi | fcsr_rci

  def hasOneRs = hasTwoRs |
  fcvt_w_s | fcvt_wu_s |
  fmv_x_w  | fmv_x_d |
// ...
  def is_fpu =
    fmadd_s   | fmsub_s   | fnmsub_s  | fnmadd_s  | fadd_s    | fsub_s    | fmul_s    | fdiv_s    | fsqrt_s   |
    fmadd_d   | fmsub_d   | fnmsub_d  | fnmadd_d  | fadd_d    | fsub_d    | fmul_d    | fdiv_d    | fsqrt_d   |
    fsgnj_s   | fsgnjn_s  | fsgnjx_s  | fsgnj_d   | fsgnjn_d  | fsgnjx_d  |
    fmin_s    | fmax_s    | fmin_d    | fmax_d    |
    feq_s     | flt_s     | fle_s     | feq_d     | flt_d     | fle_d     |
    fclass_s  | fclass_d  |
    fmv_x_w   | fmv_w_x   | fmv_x_d   | fmv_d_x   |  
    fcvt_s_w  | fcvt_s_wu | fcvt_l_s  | fcvt_lu_s |
    fcvt_s_l  | fcvt_s_lu | fcvt_s_d  | fcvt_d_s  |
    fcvt_w_d  | fcvt_wu_d | fcvt_d_w  | fcvt_d_wu | fcvt_l_d  | fcvt_lu_d |
    fcvt_d_l  | fcvt_d_lu | fcvt_w_s  | fcvt_wu_s 
  //| fcsr_rw   | fcsr_rs   | fcsr_rc   | fcsr_rwi  | fcsr_rsi  | fcsr_rci


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



// ...
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




```

### src/main/scala/rift2Core/define/frontend.scala

```scala
/**
 * Represents the output of the fourth stage of the Instruction Fetch (IF4), which finishes the instruction decoding.
 * @param p An implicit parameter of type `Parameters` required by the `Info_instruction` parent class.
 * @note This class inherits from the `Info_instruction` class, which provides all information about the instruction.
 */
class IF4_Bundle(implicit p: Parameters) extends Info_instruction{}
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
// ...
  /** A class to create CSR which Read & Write in order with given name and address.
    * @param name The name of the CSR
    * @param address The memory address of the CSR
    */
  class CSRInOrderReadWrite(val name: String, val address: Int) {
    /** interface */
    val isFlush  = Wire(Bool())
    val isClear  = Wire(Bool())
    val isMolloc = Wire(Bool())

    val isReady4Molloc = Wire(Bool()) //used at renmae

    /** Read-State and Write-State as binary values */
    def RDSTATE = "b0".U
    def WRSTATE = "b1".U

    /** Current state of the CSR */
    val curState = RegInit(RDSTATE)

    /** Flushes the current state if isFlush flag is high */
    when(isFlush){
      curState := RDSTATE
    } .elsewhen(isMolloc){
      curState := ~curState //WRSTATE
      assert(curState === RDSTATE, cf"Assert Failed at ${name}($address%X), Write requesting when not ready" )
    }.elsewhen( (curState === WRSTATE) & isClear){ //the same csr cannot molloc again until the counter is committed to empty once
      curState := ~curState //RDSTATE
    }
    isReady4Molloc := curState === RDSTATE
  }
```

## Related source code

### src/main/scala/rift2Core/backend/WriteBack.scala

```scala
  io.xpuCsrMolloc    <> cReg.io.xpu.molloc
// ...
  io.isCSRMMUReady   := cReg.io.isMMUReady
```

### src/main/scala/rift2Core/privilege/CsrScoreBoard.scala

```scala
    io.xpu.molloc(i).ready := 
      Mux1H(CSRStatus.map{ x => ((x.address).U === io.xpu.molloc(i).bits) -> (
```

## Additional requirement

An instruction with `lsuIsa.is_lsu` set must not fire on `rnReq` while `isCSRMMUReady` is low or in the same cycle as an instruction with `csrIsa.is_csr` set fires on a lower-numbered `rnReq` lane.
