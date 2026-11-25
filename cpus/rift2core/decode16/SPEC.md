# Implement `Decode16`

Implement the complete `Decode16` class. Preserve the class name and interface shown below.

Return only the complete `class Decode16` definition in a single Scala code block, with no text outside the block.

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

### src/main/scala/Parameters.scala

```scala
case class RiftSetting(
// ...
  fpuNum: Int = 0,
// ...
```

## Class declaration

```scala
class Decode16(implicit p: Parameters) extends DecodeBase{
```

## Parent instantiation

### src/main/scala/rift2Core/frontend/Decoder.scala

```scala
    val dec16 = Module(new Decode16 with NVDecode)
```

## Dependency declarations

### src/main/scala/rift2Core/frontend/Decoder.scala

```scala
/**
  * This class defines the input and output ports for a RISC-V 16-bit decoder.
  * @param x The 32-bit instruction to decode, taken as input.
  * @param pc The current program counter, taken as input.
  * @param info The decoded instruction, returned as an output of type Info_instruction.
  */
class DecodeIO(implicit p: Parameters) extends RiftBundle{
  val x  = Input(UInt(32.W))
  val pc = Input(UInt(64.W))
  val info = Output( new Info_instruction )    
}

abstract class DecodeBase (implicit p: Parameters) extends RiftModule {
  val io: DecodeIO = IO(new DecodeIO)

  val x  = WireDefault(io.x)
  val pc = WireDefault(io.pc)
  val info = Wire(new Info_instruction)

  io.info := info
  info.param.pc := pc

}
```

### src/main/scala/Parameters.scala

```scala
abstract class RiftModule(implicit val p: Parameters) extends Module with HasRiftParameters { def io: Record }
// ...
trait HasRiftParameters {
  implicit val p: Parameters

  val riftSetting = p(RiftParamsKey)
// ...
  def fpuNum = riftSetting.fpuNum
// ...
```

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
/*
  Copyright (c) 2020 - 2024 Wuhan University of Technology <295054118@whut.edu.cn>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

package rift2Core.define

import chisel3._
import chisel3.util._

import rift2Chip._
import org.chipsalliance.cde.config._





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

  val fmadd_s = Bool()
  val fmsub_s = Bool()
  val fnmsub_s = Bool()
  val fnmadd_s = Bool()
  val fadd_s = Bool()
  val fsub_s = Bool()
  val fmul_s = Bool()
  val fdiv_s = Bool()
  val fsqrt_s = Bool()
  val fsgnj_s = Bool()
  val fsgnjn_s = Bool()
  val fsgnjx_s = Bool()
  val fmin_s = Bool()
  val fmax_s = Bool()
  val fcvt_w_s = Bool()
  val fcvt_wu_s = Bool()
  val fmv_x_w = Bool()
  val feq_s = Bool()
  val flt_s = Bool()
  val fle_s = Bool()
  val fclass_s = Bool()
  val fcvt_s_w = Bool()
  val fcvt_s_wu = Bool()
  val fmv_w_x = Bool()

  val fcvt_l_s = Bool()
  val fcvt_lu_s = Bool()
  val fcvt_s_l = Bool()
  val fcvt_s_lu = Bool()


  val fmadd_d = Bool()
  val fmsub_d = Bool()
  val fnmsub_d = Bool()
  val fnmadd_d = Bool()
  val fadd_d = Bool()
  val fsub_d = Bool()
  val fmul_d = Bool()
  val fdiv_d = Bool()
  val fsqrt_d = Bool()
  val fsgnj_d = Bool()
  val fsgnjn_d = Bool()
  val fsgnjx_d = Bool()
  val fmin_d = Bool()
  val fmax_d = Bool()
  val fcvt_s_d = Bool()
  val fcvt_d_s = Bool()
  val feq_d = Bool()
  val flt_d = Bool()
  val fle_d = Bool()
  val fclass_d = Bool()
  val fcvt_w_d = Bool()
  val fcvt_wu_d = Bool()
  val fcvt_d_w = Bool()
  val fcvt_d_wu = Bool()

  val fcvt_l_d = Bool()
  val fcvt_lu_d = Bool()
  val fmv_x_d = Bool()
  val fcvt_d_l = Bool()
  val fcvt_d_lu = Bool()
  val fmv_d_x = Bool()

  // val fcsr_rw = Bool()
  // val fcsr_rs = Bool()
  // val fcsr_rc = Bool()

  // val fcsr_rwi = Bool()
  // val fcsr_rsi = Bool()
  // val fcsr_rci = Bool()

  // def is_fun_frw = fcsr_rw | fcsr_rwi
  // def is_fun_frs = fcsr_rs | fcsr_rsi
  // def is_fun_frc = fcsr_rc | fcsr_rci

  // def is_fun_fcsri = fcsr_rwi | fcsr_rsi | fcsr_rci

  // def is_fun_fcsr =   
  //   is_fun_frw | is_fun_frs | is_fun_frc


  def is_fun_class = fclass_s | fclass_d
  def is_fun_fcmp =  feq_s | flt_s | fle_s | feq_d | flt_d | fle_d
  def is_fun_maxMin = fmin_s | fmax_s | fmin_d | fmax_d
  def is_fun_fcvtX = 
    fcvt_w_s | fcvt_wu_s | fcvt_l_s | fcvt_lu_s |
    fcvt_w_d | fcvt_wu_d | fcvt_l_d | fcvt_lu_d 
  def is_fun_xcvtF = 
    fcvt_s_w | fcvt_s_wu | fcvt_s_l | fcvt_s_lu |
    fcvt_d_w | fcvt_d_wu | fcvt_d_l | fcvt_d_lu 
  def is_fun_fcvtF = 
    fcvt_s_d | fcvt_d_s
  def is_fun_fmvX =
    fmv_x_w | fmv_x_d
  def is_fun_xmvF =
    fmv_w_x | fmv_d_x
  def is_fun_fsgn = 
    fsgnj_s | fsgnjn_s | fsgnjx_s |
    fsgnj_d | fsgnjn_d | fsgnjx_d
  def is_fun_fma = 
    fmadd_s  | fmsub_s  | fnmsub_s | fnmadd_s | fadd_s   | fsub_s   | fmul_s   |
    fmadd_d  | fmsub_d  | fnmsub_d | fnmadd_d | fadd_d   | fsub_d   | fmul_d
  def is_fun_divSqrt = 
    fdiv_s  | fdiv_d  | fsqrt_s | fsqrt_d
    
  

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
  fclass_s | fclass_d |
  fcvt_s_w | fcvt_s_wu |
  fmv_w_x  | fmv_d_x |
  fcvt_l_s | fcvt_lu_s |
  fcvt_s_l | fcvt_s_lu |
  fcvt_s_d | fcvt_d_s |
  fcvt_w_d | fcvt_wu_d |
  fcvt_d_w | fcvt_d_wu |
  fcvt_l_d | fcvt_lu_d |
  fcvt_d_l | fcvt_d_lu

  def is_fop = 
    fmadd_s   | fmsub_s   | fnmsub_s  | fnmadd_s  |
    fmadd_d   | fmsub_d   | fnmsub_d  | fnmadd_d  |    
    fadd_s    | fsub_s    | fmul_s    | fdiv_s    | fsqrt_s   |
    fadd_d    | fsub_d    | fmul_d    | fdiv_d    | fsqrt_d   |    
    fsgnj_s   | fsgnjn_s  | fsgnjx_s  |
    fsgnj_d   | fsgnjn_d  | fsgnjx_d  |
    fmin_s    | fmax_s    | fmin_d    | fmax_d    |
    fmv_x_w   | fmv_x_d   |
    feq_s     | flt_s     | fle_s     |
    feq_d     | flt_d     | fle_d     |
    fclass_s  | fclass_d  |
    fcvt_w_s  | fcvt_wu_s | fcvt_l_s  | fcvt_lu_s |
    fcvt_w_d  | fcvt_wu_d | fcvt_l_d  | fcvt_lu_d |
    fcvt_s_d  | fcvt_d_s

  def isXwb = 
    feq_s | flt_s | fle_s | feq_d | flt_d | fle_d |
    fmv_x_w | fmv_x_d | fclass_s | fclass_d |
    fcvt_w_s | fcvt_wu_s | fcvt_l_s | fcvt_lu_s | fcvt_w_d | fcvt_wu_d | fcvt_l_d | fcvt_lu_d |
    fmv_x_w | fmv_x_d 
    //| fcsr_rw | fcsr_rs | fcsr_rc | fcsr_rwi | fcsr_rsi | fcsr_rci

  def isFwb =
    fmadd_s | fmsub_s | fnmsub_s | fnmadd_s | fadd_s | fsub_s | fmul_s | fdiv_s | fsqrt_s |
    fmadd_d | fmsub_d | fnmsub_d | fnmadd_d | fadd_d | fsub_d | fmul_d | fdiv_d | fsqrt_d |
    fsgnj_s | fsgnjn_s | fsgnjx_s |
    fsgnj_d | fsgnjn_d | fsgnjx_d |
    fmin_s | fmax_s | fmin_d | fmax_d |
    fcvt_s_w | fcvt_s_wu | fcvt_d_w | fcvt_d_wu |
    fcvt_s_l | fcvt_s_lu | fcvt_d_l | fcvt_d_lu |
    fcvt_s_d | fcvt_d_s |
    fmv_w_x | fmv_d_x
    


  def is_usi =
    fcvt_s_wu | fcvt_s_lu| fcvt_d_wu | fcvt_d_lu | fcvt_wu_s | fcvt_lu_s | fcvt_wu_d | fcvt_lu_d


  def FtypeTagIn = {
    def FtypeTagIn_0 =
    fmadd_s   | fmsub_s   | fnmsub_s  | fnmadd_s  |  
    fadd_s    | fsub_s    | fmul_s    | fdiv_s    | fsqrt_s   | 
    fsgnj_s   | fsgnjn_s  | fsgnjx_s  |
    fmin_s    | fmax_s    |
    feq_s     | flt_s     | fle_s     |
    fclass_s  |
    fcvt_w_s  | fcvt_wu_s | fcvt_l_s  | fcvt_lu_s |
    fcvt_d_s

    def FtypeTagIn_1 =
    fmadd_d   | fmsub_d   | fnmsub_d  | fnmadd_d  |    
    fadd_d    | fsub_d    | fmul_d    | fdiv_d    | fsqrt_d   |    
    fsgnj_d   | fsgnjn_d  | fsgnjx_d  |
    fmin_d    | fmax_d    |
    fmv_x_w   | fmv_x_d   |
    feq_d     | flt_d     | fle_d     |
    fclass_d  |
    fcvt_w_d  | fcvt_wu_d | fcvt_l_d  | fcvt_lu_d |
    fcvt_s_d
    
    Mux1H(Seq(
      FtypeTagIn_0 -> 0.U, FtypeTagIn_1 -> 1.U,
    ))
  }


  def FtypeTagOut = {
    def FtypeTagOut_0 =
      fmadd_s | fmsub_s | fnmsub_s | fnmadd_s |
      fadd_s | fsub_s | fmul_s |
      fsgnj_s | fsgnjn_s | fsgnjx_s |
      fmin_s | fmax_s |
      fcvt_s_w | fcvt_s_wu | fcvt_s_l | fcvt_s_lu |
      fcvt_s_d

    def FtypeTagOut_1 =
      fmadd_d | fmsub_d | fnmsub_d | fnmadd_d |
      fadd_d | fsub_d | fmul_d | 
      fsgnj_d | fsgnjn_d | fsgnjx_d |
      fmin_d | fmax_d |
      fmv_d_x   | fmv_w_x   |
      fcvt_d_w | fcvt_d_wu | fcvt_d_l | fcvt_d_lu |
      fcvt_d_s
    
    Mux1H(Seq(
      FtypeTagOut_0 -> 0.U, FtypeTagOut_1 -> 1.U,
    ))
  }

  def XtypeTagIn = {
    def XtypeTagIn_0 =
      fmv_w_x   |
      fcvt_s_w | fcvt_s_wu | fcvt_d_w | fcvt_d_wu 

    def XtypeTagIn_1 =
      fmv_d_x   |
      fcvt_s_l | fcvt_s_lu | fcvt_d_l | fcvt_d_lu
    
    Mux1H(Seq(
      XtypeTagIn_0 -> 0.U, XtypeTagIn_1 -> 1.U,
    ))
  }

  def XtypeTagOut = {
    def XtypeTagOut_0 =
    fmv_x_w |  
    fcvt_w_s | fcvt_wu_s | fcvt_w_d | fcvt_wu_d

    def XtypeTagOut_1 =
    feq_s | flt_s | fle_s | feq_d | flt_d | fle_d |
    fmv_x_d | 
    fcvt_l_s | fcvt_lu_s | fcvt_l_d | fcvt_lu_d
    
    Mux1H(Seq(
      XtypeTagOut_0 -> 0.U, XtypeTagOut_1 -> 1.U,
    ))
  }




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


}





class VecIsa extends Bundle {
  class OPI extends Bundle{
    val ivv = Bool()
    val ivx = Bool()
    val ivi = Bool()

    def sel = ivv | ivx | ivi

  }

  class OPM extends Bundle{
    val mvv = Bool()
    val mvx = Bool()

    def sel = mvv | mvx
  }

  class OPF extends Bundle{
    val fvv = Bool()
    val fvf = Bool()

    def sel = fvv | fvf
  }

  val vadd         = new OPI
  val vsub         = new OPI
  val vrsub        = new OPI
  val vminu        = new OPI
  val vmin         = new OPI
  val vmaxu        = new OPI
  val vmax         = new OPI
  val vand         = new OPI
  val vor          = new OPI
  val vxor         = new OPI
  val vrgather     = new OPI
  val vslideup     = new OPI
  val vrgatherei16 = new OPI
  val vslidedown   = new OPI
  val vredsum      = new OPM
  val vredand      = new OPM
  val vredor       = new OPM
  val vredxor      = new OPM
  val vredminu     = new OPM
  val vredmin      = new OPM
  val vredmaxu     = new OPM
  val vredmax      = new OPM
  val vaaddu       = new OPM
  val vaadd        = new OPM
  val vasubu       = new OPM
  val vasub        = new OPM
  val vslide1up    = new OPM
  val vslide1down  = new OPM
  val vfadd        = new OPF
  val vfredusum    = new OPF
  val vfsub        = new OPF
  val vfredosum    = new OPF
  val vfmin        = new OPF
  val vfredmin     = new OPF
  val vfmax        = new OPF
  val vfredmax     = new OPF
  val vfsgnj       = new OPF
  val vfsgnjn      = new OPF
  val vfsgnjx      = new OPF
  val vfslide1up   = new OPF
  val vfslide1down = new OPF

  val vadc      = new OPI
  val vmadc     = new OPI
  val vsbc      = new OPI
  val vmsbc     = new OPI
  val vmerge    = new OPI
  val vmv       = new OPI
  val vmseq     = new OPI
  val vmsne     = new OPI
  val vmsltu    = new OPI
  val vmslt     = new OPI
  val vmsleu    = new OPI
  val vmsle     = new OPI
  val vmsgtu    = new OPI
  val vmsgt     = new OPI
  val vmv_x_s   = Bool()
  val vpopc     = Bool()
  val vfirst    = Bool()
  val vmv_s_x   = Bool()
  val vzext_vf8 = Bool()
  val vsext_vf8 = Bool()
  val vzext_vf4 = Bool()
  val vsext_vf4 = Bool()
  val vzext_vf2 = Bool()
  val vsext_vf2 = Bool()
  val vmsbf = Bool()
  val vmsof = Bool()
  val vmsif = Bool()
  val viota = Bool()
  val vid   = Bool()
  val vcompress = new OPM
  val vmandnot  = new OPM
  val vmand     = new OPM
  val vmor      = new OPM
  val vmxor     = new OPM
  val vmornot   = new OPM
  val vmnand    = new OPM
  val vmnor     = new OPM
  val vmxnor    = new OPM
  val vfmv_f_s  = Bool()
  val vfmv_s_f  = Bool()
  val vfcvt_xu_f_v     = Bool()
  val vfcvt_x_f_v      = Bool()
  val vfcvt_f_xu_v     = Bool()
  val vfcvt_f_x_v      = Bool()
  val vfcvt_rtz_xu_f_v = Bool()
  val vfcvt_rtz_x_f_v  = Bool()

  val vfwcvt_xu_f_v     = Bool()
  val vfwcvt_x_f_v      = Bool()
  val vfwcvt_f_xu_v     = Bool()
  val vfwcvt_f_x_v      = Bool()
  val vfwcvt_f_f_v      = Bool()
  val vfwcvt_rtz_xu_f_v = Bool()
  val vfwcvt_rtz_x_f_v  = Bool()

  val vfncvt_xu_f_w     = Bool()
  val vfncvt_x_f_w      = Bool()
  val vfncvt_f_xu_w     = Bool()
  val vfncvt_f_x_w      = Bool()
  val vfncvt_f_f_w      = Bool()
  val vfncvt_rod_f_f_w  = Bool()
  val vfncvt_rtz_xu_f_w = Bool()
  val vfncvt_rtz_x_f_w  = Bool()

  val vfsqrt_v   = Bool()
  val vfrsqrt7_v = Bool()
  val vfrec7_v   = Bool()
  val vfclass_v  = Bool()

  val vfmerge   = new OPF
  val vfmv      = new OPF
  val vmfeq     = new OPF
  val vmfle     = new OPF
  val vmflt     = new OPF
  val vmfne     = new OPF
  val vmfgt     = new OPF
  val vmfge     = new OPF

  val vsaddu  = new OPI
  val vsadd   = new OPI
  val vssubu  = new OPI
  val vssub   = new OPI
  val vsll    = new OPI
  val vsmul   = new OPI
  val vmvnr   = new OPI

  val vsrl    = new OPI
  val vsra    = new OPI
  val vssrl   = new OPI
  val vssra   = new OPI
  val vnsrl   = new OPI
  val vnsra   = new OPI
  val vnclipu = new OPI
  val vnclip  = new OPI
  val vdivu   = new OPM
  val vdiv    = new OPM
  val vremu   = new OPM
  val vrem    = new OPM
  val vmulhu  = new OPM
  val vmul    = new OPM
  val vmulhsu = new OPM
  val vmulh   = new OPM
  val vmadd   = new OPM
  val vnmsub  = new OPM
  val vmacc   = new OPM
  val vnmsac  = new OPM
  val vfdiv   = new OPF
  val vfrdiv  = new OPF
  val vfmul   = new OPF
  val vfrsub  = new OPF
  val vfmadd  = new OPF
  val vfnmadd = new OPF
  val vfmsub  = new OPF
  val vfnmsub = new OPF
  val vfmacc  = new OPF
  val vfnmacc = new OPF
  val vfmsac  = new OPF
  val vfnmsac = new OPF

  val vwredsumu  = new OPI
  val vwredsum   = new OPI
  val vwaddu     = new OPM
  val vwadd      = new OPM
  val vwsubu     = new OPM
  val vwsub      = new OPM
  val vwaddu_w   = new OPM
  val vwadd_w    = new OPM
  val vwsubu_w   = new OPM
  val vwsub_w    = new OPM
  val vwmulu     = new OPM
  val vwmulsu    = new OPM
  val vwmul      = new OPM
  val vwmaccu    = new OPM
  val vwmacc     = new OPM
  val vwmaccus   = new OPM
  val vwmaccsu   = new OPM
  val vfwadd     = new OPF
  val vfwredusum = new OPF
  val vfwsub     = new OPF
  val vfwredosum = new OPF
  val vfwadd_w   = new OPF
  val vfwsub_w   = new OPF
  val vfwmul     = new OPF
  val vfwmacc    = new OPF
  val vfwnmacc   = new OPF
  val vfwmsac    = new OPF
  val vfwnmsac   = new OPF

  def isOPI = vadd.sel | vsub.sel | vrsub.sel | vminu.sel | vmin.sel | vmaxu.sel | vmax.sel | vand.sel | vor.sel | vxor.sel | vrgather.sel | vslideup.sel | vrgatherei16.sel | vslidedown.sel | vadc.sel | vmadc.sel | vsbc.sel | vmsbc.sel | vmerge.sel | vmv.sel | vmseq.sel | vmsne.sel | vmsltu.sel | vmslt.sel | vmsleu.sel | vmsle.sel | vmsgtu.sel | vmsgt.sel | vsaddu.sel | vsadd.sel | vssubu.sel  | vssub.sel | vsll.sel | vsmul.sel | vmvnr.sel | vsrl.sel | vsra.sel | vssrl.sel | vssra.sel  | vnsrl.sel | vnsra.sel | vnclipu.sel | vnclip.sel  | vwredsumu.sel | vwredsum.sel
  def isOPM = vredsum.sel | vredand.sel | vredor.sel | vredxor.sel | vredminu.sel | vredmin.sel | vredmaxu.sel | vredmax.sel | vaaddu.sel | vaadd.sel | vasubu.sel | vasub.sel | vslide1up.sel | vslide1down.sel | vcompress.sel | vmandnot.sel | vmand.sel | vmor.sel | vmxor.sel | vmornot.sel | vmnand.sel | vmnor.sel | vmxnor.sel | vdivu.sel | vdiv.sel | vremu.sel | vrem.sel | vmulhu.sel | vmul.sel | vmulhsu.sel | vmulh.sel | vmadd.sel | vnmsub.sel | vmacc.sel | vnmsac.sel | vwaddu.sel | vwadd.sel | vwsubu.sel | vwsub.sel | vwaddu_w.sel | vwadd_w.sel | vwsubu_w.sel | vwsub_w.sel | vwmulu.sel | vwmulsu.sel | vwmul.sel | vwmaccu.sel  | vwmacc.sel | vwmaccus.sel | vwmaccsu.sel
  def isOPF = vfadd.sel | vfredusum.sel | vfsub.sel | vfredosum.sel | vfmin.sel | vfredmin.sel | vfmax.sel | vfredmax.sel | vfsgnj.sel | vfsgnjn.sel | vfsgnjx.sel | vfslide1up.sel | vfslide1down.sel | vfmerge.sel | vfmv.sel | vmfeq.sel | vmfle.sel | vmflt.sel | vmfne.sel | vmfgt.sel | vmfge.sel | vfdiv.sel | vfrdiv.sel | vfmul.sel | vfrsub.sel | vfmadd.sel | vfnmadd.sel | vfmsub.sel | vfnmsub.sel | vfmacc.sel | vfnmacc.sel | vfmsac.sel | vfnmsac.sel | vfwadd.sel | vfwredusum.sel | vfwsub.sel | vfwredosum.sel | vfwadd_w.sel | vfwsub_w.sel | vfwmul.sel | vfwmacc.sel | vfwnmacc.sel | vfwmsac.sel | vfwnmsac.sel



  def isIVV = 
    vadd.ivv | vsub.ivv | vrsub.ivv | vminu.ivv | vmin.ivv | vmaxu.ivv | vmax.ivv | vand.ivv | vor.ivv | vxor.ivv | vrgather.ivv | vslideup.ivv | vrgatherei16.ivv | vslidedown.ivv | vadc.ivv | vmadc.ivv | vsbc.ivv | vmsbc.ivv | vmerge.ivv | vmv.ivv | vmseq.ivv | vmsne.ivv | vmsltu.ivv | vmslt.ivv | vmsleu.ivv | vmsle.ivv | vmsgtu.ivv | vmsgt.ivv | vsaddu.ivv | vsadd.ivv | vssubu .ivv | vssub.ivv | vsll.ivv | vsmul.ivv | vmvnr.ivv | vsrl.ivv | vsra.ivv | vssrl.ivv | vssra .ivv | vnsrl.ivv | vnsra.ivv | vnclipu.ivv | vnclip .ivv | vwredsumu.ivv | vwredsum.ivv
  def isIVX = 
    vadd.ivx | vsub.ivx | vrsub.ivx | vminu.ivx | vmin.ivx | vmaxu.ivx | vmax.ivx | vand.ivx | vor.ivx | vxor.ivx | vrgather.ivx | vslideup.ivx | vrgatherei16.ivx | vslidedown.ivx | vadc.ivx | vmadc.ivx | vsbc.ivx | vmsbc.ivx | vmerge.ivx | vmv.ivx | vmseq.ivx | vmsne.ivx | vmsltu.ivx | vmslt.ivx | vmsleu.ivx | vmsle.ivx | vmsgtu.ivx | vmsgt.ivx | vsaddu.ivx | vsadd.ivx | vssubu .ivx | vssub.ivx | vsll.ivx | vsmul.ivx | vmvnr.ivx | vsrl.ivx | vsra.ivx | vssrl.ivx | vssra .ivx | vnsrl.ivx | vnsra.ivx | vnclipu.ivx | vnclip .ivx | vwredsumu.ivx | vwredsum.ivx
  def isIVI = 
    vadd.ivi | vsub.ivi | vrsub.ivi | vminu.ivi | vmin.ivi | vmaxu.ivi | vmax.ivi | vand.ivi | vor.ivi | vxor.ivi | vrgather.ivi | vslideup.ivi | vrgatherei16.ivi | vslidedown.ivi | vadc.ivi | vmadc.ivi | vsbc.ivi | vmsbc.ivi | vmerge.ivi | vmv.ivi | vmseq.ivi | vmsne.ivi | vmsltu.ivi | vmslt.ivi | vmsleu.ivi | vmsle.ivi | vmsgtu.ivi | vmsgt.ivi | vsaddu.ivi | vsadd.ivi | vssubu .ivi | vssub.ivi | vsll.ivi | vsmul.ivi | vmvnr.ivi | vsrl.ivi | vsra.ivi | vssrl.ivi | vssra .ivi | vnsrl.ivi | vnsra.ivi | vnclipu.ivi | vnclip .ivi | vwredsumu.ivi | vwredsum.ivi

  def isMVV = 
    vredsum.mvv | vredand.mvv | vredor.mvv | vredxor.mvv | vredminu.mvv | vredmin.mvv | vredmaxu.mvv | vredmax.mvv | vaaddu.mvv | vaadd.mvv | vasubu.mvv | vasub.mvv | vslide1up.mvv | vslide1down.mvv | vcompress.mvv | vmandnot.mvv | vmand.mvv | vmor.mvv | vmxor.mvv | vmornot.mvv | vmnand.mvv | vmnor.mvv | vmxnor.mvv | vdivu.mvv | vdiv.mvv | vremu.mvv | vrem.mvv | vmulhu.mvv | vmul.mvv | vmulhsu.mvv | vmulh.mvv | vmadd.mvv | vnmsub.mvv | vmacc.mvv | vnmsac.mvv | vwaddu.mvv | vwadd.mvv | vwsubu.mvv | vwsub.mvv | vwaddu_w.mvv | vwadd_w.mvv | vwsubu_w.mvv | vwsub_w.mvv | vwmulu.mvv | vwmulsu.mvv | vwmul.mvv | vwmaccu .mvv | vwmacc.mvv | vwmaccus.mvv | vwmaccsu.mvv
  def isMVX = 
    vredsum.mvx | vredand.mvx | vredor.mvx | vredxor.mvx | vredminu.mvx | vredmin.mvx | vredmaxu.mvx | vredmax.mvx | vaaddu.mvx | vaadd.mvx | vasubu.mvx | vasub.mvx | vslide1up.mvx | vslide1down.mvx | vcompress.mvx | vmandnot.mvx | vmand.mvx | vmor.mvx | vmxor.mvx | vmornot.mvx | vmnand.mvx | vmnor.mvx | vmxnor.mvx | vdivu.mvx | vdiv.mvx | vremu.mvx | vrem.mvx | vmulhu.mvx | vmul.mvx | vmulhsu.mvx | vmulh.mvx | vmadd.mvx | vnmsub.mvx | vmacc.mvx | vnmsac.mvx | vwaddu.mvx | vwadd.mvx | vwsubu.mvx | vwsub.mvx | vwaddu_w.mvx | vwadd_w.mvx | vwsubu_w.mvx | vwsub_w.mvx | vwmulu.mvx | vwmulsu.mvx | vwmul.mvx | vwmaccu .mvx | vwmacc.mvx | vwmaccus.mvx | vwmaccsu.mvx

  def isFVV = 
    vfadd.fvv | vfredusum.fvv | vfsub.fvv | vfredosum.fvv | vfmin.fvv | vfredmin.fvv | vfmax.fvv | vfredmax.fvv | vfsgnj.fvv | vfsgnjn.fvv | vfsgnjx.fvv | vfslide1up.fvv | vfslide1down.fvv | vfmerge.fvv | vfmv.fvv | vmfeq.fvv | vmfle.fvv | vmflt.fvv | vmfne.fvv | vmfgt.fvv | vmfge.fvv | vfdiv.fvv | vfrdiv.fvv | vfmul.fvv | vfrsub.fvv | vfmadd.fvv | vfnmadd.fvv | vfmsub.fvv | vfnmsub.fvv | vfmacc.fvv | vfnmacc.fvv | vfmsac.fvv | vfnmsac.fvv | vfwadd.fvv | vfwredusum.fvv | vfwsub.fvv | vfwredosum.fvv | vfwadd_w.fvv | vfwsub_w.fvv | vfwmul.fvv | vfwmacc.fvv | vfwnmacc.fvv | vfwmsac.fvv | vfwnmsac.fvv
  def isFVF = 
    vfadd.fvf | vfredusum.fvf | vfsub.fvf | vfredosum.fvf | vfmin.fvf | vfredmin.fvf | vfmax.fvf | vfredmax.fvf | vfsgnj.fvf | vfsgnjn.fvf | vfsgnjx.fvf | vfslide1up.fvf | vfslide1down.fvf | vfmerge.fvf | vfmv.fvf | vmfeq.fvf | vmfle.fvf | vmflt.fvf | vmfne.fvf | vmfgt.fvf | vmfge.fvf | vfdiv.fvf | vfrdiv.fvf | vfmul.fvf | vfrsub.fvf | vfmadd.fvf | vfnmadd.fvf | vfmsub.fvf | vfnmsub.fvf | vfmacc.fvf | vfnmacc.fvf | vfmsac.fvf | vfnmsac.fvf | vfwadd.fvf | vfwredusum.fvf | vfwsub.fvf | vfwredosum.fvf | vfwadd_w.fvf | vfwsub_w.fvf | vfwmul.fvf | vfwmacc.fvf | vfwnmacc.fvf | vfwmsac.fvf | vfwnmsac.fvf






  def isVXpu =
    vadd.sel | vsub.sel | vrsub.sel | vminu.sel | vmin.sel | vmaxu.sel | vmax.sel | vand.sel | vor.sel | vxor.sel | 
    vwaddu.sel | vwadd.sel | vwsubu.sel | vwsub.sel | vwaddu_w.sel | vwadd_w.sel  | vwsubu_w.sel | vwsub_w.sel | vadc.sel | vmadc.sel | vsbc.sel | vmsbc.sel |
    vzext_vf8 | vsext_vf8 | vzext_vf4 | vsext_vf4 | vzext_vf2 | vsext_vf2 |
    vsll.sel  | vsrl.sel  | vsra.sel  | vnsrl.sel | vnsra.sel |
    vmseq.sel  | vmsne.sel  | vmsltu.sel | vmslt.sel  | vmsleu.sel | vmsle.sel  | vmsgtu.sel | vmsgt.sel  |
    vmerge.sel | vmv.sel |
    vredsum.sel | vredand.sel | vredor.sel | vredxor.sel | vredminu.sel | vredmin.sel | vredmaxu.sel | vredmax.sel |
    vwredsumu.sel | vwredsum.sel |
    vmand.sel | vmnand.sel | vmandnot.sel | vmxor.sel | vmor.sel | vmnor.sel | vmornot.sel | vmxnor.sel |
    vpopc | vfirst | vmsbf | vmsif | vmsof | viota | vid |
    vmv_x_s | vmv_s_x |
    vslideup.sel | vslidedown.sel | vslide1up.sel | vslide1down.sel |
    vrgather.sel | vrgatherei16.sel |
    vcompress.sel |
    vmvnr.sel |
    vdivu.sel | vdiv.sel  | vremu.sel | vrem.sel  |
    vmulhu.sel | vmul.sel | vmulhsu.sel | vmulh.sel |
    vmadd.sel  | vnmsub.sel | vmacc.sel  | vnmsac.sel |
    vwmulu.sel  | vwmulsu.sel | vwmul.sel   |
    vwmaccu.sel  | vwmacc.sel | vwmaccus.sel | vwmaccsu.sel

  def isVQpu = 
    vsaddu.sel | vsadd.sel | vssubu.sel | vssub.sel |
    vaaddu.sel | vaadd.sel | vasubu.sel | vasub.sel |
    vsmul.sel |
    vssrl.sel | vssra.sel |
    vnclipu.sel | vnclip.sel

  def isVFpu = 
    vfadd.sel | vfsub.sel | vfrsub.sel |
    vfwadd.sel | vfwsub.sel | vfwadd_w.sel | vfwsub_w.sel |
    vfdiv.sel | vfrdiv.sel | vfmul.sel | vfwmul.sel |
    vfmacc.sel | vfnmacc.sel | vfmsac.sel  | vfnmsac.sel | vfmadd.sel  | vfnmadd.sel | vfmsub.sel  | vfnmsub.sel |
    vfwmacc.sel | vfwnmacc.sel | vfwmsac.sel  | vfwnmsac.sel |
    vfsqrt_v | vfrsqrt7_v | vfrec7_v |
    vfmin.sel   | vfmax.sel   | vfsgnj.sel  | vfsgnjn.sel | vfsgnjx.sel |
    vmfeq.sel | vmfle.sel | vmflt.sel | vmfne.sel | vmfgt.sel | vmfge.sel |
    vfclass_v |
    vfmerge.sel | vfmv.sel |
    vfcvt_xu_f_v | vfcvt_x_f_v | vfcvt_f_xu_v | vfcvt_f_x_v | vfcvt_rtz_xu_f_v | vfcvt_rtz_x_f_v | vfwcvt_xu_f_v | vfwcvt_x_f_v | vfwcvt_f_xu_v | vfwcvt_f_x_v | vfwcvt_f_f_v | vfwcvt_rtz_xu_f_v | vfwcvt_rtz_x_f_v | vfncvt_xu_f_w | vfncvt_x_f_w | vfncvt_f_xu_w | vfncvt_f_x_w | vfncvt_f_f_w | vfncvt_rod_f_f_w | vfncvt_rtz_xu_f_w | vfncvt_rtz_x_f_w |
    vfredusum.sel | vfredosum.sel | vfredmin.sel  | vfredmax.sel  |
    vfwredusum.sel | vfwredosum.sel |
    vfmv_f_s | vfmv_s_f |
    vfslide1up.sel | vfslide1down.sel









  def isRS1 = isIVX | isMVX | vmv_s_x
  def isRS2 = isFVF



  def isFS1 = vfmv_s_f


  def isVS1 = isIVV | isMVV | isFVV
  def isVS2 =
    isOPI | isOPM | isOPF |
    vzext_vf8 | vsext_vf8 | vzext_vf4 | vsext_vf4 | vzext_vf2 | vsext_vf2 |
    vfsqrt_v | vfrsqrt7_v | vfrec7_v | vfclass_v |
    vfcvt_xu_f_v | vfcvt_x_f_v | vfcvt_rtz_xu_f_v | vfcvt_rtz_x_f_v | vfcvt_f_xu_v | vfcvt_f_x_v |
    vfwcvt_xu_f_v | vfwcvt_x_f_v | vfwcvt_rtz_xu_f_v | vfwcvt_rtz_x_f_v | vfwcvt_f_xu_v | vfwcvt_f_x_v | vfwcvt_f_f_v |
    vfncvt_xu_f_w | vfncvt_x_f_w | vfncvt_rtz_xu_f_w | vfncvt_rtz_x_f_w | vfncvt_f_xu_w | vfncvt_f_x_w | vfncvt_f_f_w | vfncvt_rod_f_f_w |
    vfirst | vmsbf | vmsif | vmsof | viota |
    vmv_x_s | vfmv_f_s | vpopc




  def isVS2P =
    vwaddu_w.sel | vwsubu_w.sel | vwadd_w.sel | vwsub_w.sel |
    vnclipu.sel | vnclip.sel |
    vfwadd_w.sel | vfwsub_w.sel |
    vfwmacc.sel | vfwnmacc.sel | vfwmsac.sel | vfwnmsac.sel | 
    vfncvt_xu_f_w | vfncvt_x_f_w | vfncvt_rtz_xu_f_w | vfncvt_rtz_x_f_w | vfncvt_f_xu_w | vfncvt_f_x_w | vfncvt_f_f_w | vfncvt_rod_f_f_w



  def isRD0 = isVXpu | isVQpu | isVFpu


  def is2Malloc = 
    vwaddu.sel | vwsubu.sel | vwadd.sel | vwsub.sel |
    vwaddu_w.sel | vwsubu_w.sel | vwadd_w.sel | vwsub_w.sel |
    vwmul.sel | vwmulu.sel | vwmulsu.sel |
    vwmaccu.sel | vwmacc.sel | vwmaccsu.sel | vwmaccus.sel |
    vfwadd.sel | vfwsub.sel | vfwadd_w.sel | vfwsub_w.sel |
    vfmul.sel |
    vfwmacc.sel | vfwnmacc.sel | vfwmsac.sel | vfwnmsac.sel | 
    vwredsumu.sel | vwredsum.sel | vfwredosum.sel |
    vfwcvt_xu_f_v | vfwcvt_x_f_v | vfwcvt_rtz_xu_f_v | vfwcvt_rtz_x_f_v | vfwcvt_f_xu_v | vfwcvt_f_x_v | vfwcvt_f_f_v



  def isXwb = vfirst | vpopc | vmv_x_s
  def isFwb = vfmv_f_s
  def isVwb =
    isOPI | isOPM | isOPF |
    vzext_vf8 | vsext_vf8 | vzext_vf4 | vsext_vf4 | vzext_vf2 | vsext_vf2 |
    vfsqrt_v | vfrsqrt7_v | vfrec7_v | vfclass_v | 
    vfcvt_xu_f_v | vfcvt_x_f_v | vfcvt_rtz_xu_f_v | vfcvt_rtz_x_f_v | vfcvt_f_xu_v | vfcvt_f_x_v |
    vfwcvt_xu_f_v | vfwcvt_x_f_v | vfwcvt_rtz_xu_f_v | vfwcvt_rtz_x_f_v | vfwcvt_f_xu_v | vfwcvt_f_x_v | vfwcvt_f_f_v |
    vfncvt_xu_f_w | vfncvt_x_f_w | vfncvt_rtz_xu_f_w | vfncvt_rtz_x_f_w | vfncvt_f_xu_w | vfncvt_f_x_w | vfncvt_f_f_w | vfncvt_rod_f_f_w |
    vmsbf | vmsif | vmsof | viota | vid |
    vmv_s_x | vfmv_s_f




  def isVALU = isVXpu | isVQpu | isVFpu


  def isVector = isVXpu | isVQpu | isVFpu //| isVConfig | isVMem




}











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
```

## Related source code

### src/main/scala/rift2Core/frontend/IF2.scala

```scala
  //override chn0
  when( io.mmu_if.valid & io.mmu_if.bits.is_access_fault ) {
    ibuf.io.enq(0).bits.instr := "b1001110001000001".U
    ibuf.io.enq(0).bits.pc    := io.if2_req.bits.pc 
    ibuf.io.enq(0).bits.isRedirect := false.B
    ibuf.io.enq(0).bits.target := 0.U
    ibuf.io.enq(0).bits.isFault := true.B

  } .elsewhen( io.mmu_if.valid & io.mmu_if.bits.is_paging_fault ) {
    ibuf.io.enq(0).bits.instr := "b1001110001000101".U
    ibuf.io.enq(0).bits.pc    := io.if2_req.bits.pc
    ibuf.io.enq(0).bits.isRedirect := false.B
    ibuf.io.enq(0).bits.target := 0.U
    ibuf.io.enq(0).bits.isFault := true.B
  }
```

## Documentation

### src/unpriv/c-st-ext.adoc

```text
[[ext:c]]
=== ext:c[] Extension for Compressed Instructions

This section describes the ext:c[] extension, which incorporates the
compressed instruction-set extensions designed for application-
and server-class processors.
The ext:c[] extension substantially improves code density across a wide
range of applications, thereby improving performance, area-efficiency,
and energy-efficiency of processors with instruction caches.
It excludes features that improve code density at the cost of performance.

The ext:c[] extension depends upon the extlink:zca[] extension.

If XLEN=32 and the ext:f[] extension is present, the ext:c[] extension additionally
depends upon the extlink:zcf[] extension.

If the ext:d[] extension is present, the ext:c[] extension additionally depends
upon the extlink:zcd[] extension.
```

### src/unpriv/zca.adoc

```text
[[ext:zca]]
=== ext:zca[] Extension for Integer Compressed Instructions

The compressed extensions use a simple compression scheme that offers shorter 16-bit versions
of common 32-bit RISC-V instructions when:

* the immediate or address offset is small, or
* one of the registers is the zero register (`x0`), the ABI link register
(`x1`), or the ABI stack pointer (`x2`), or
* the destination register and the first source register are identical, or
* the registers used are the 8 most popular ones.

The ext:zca[] extension is compatible with all other standard instruction
extensions. [#norm:Zca_align16]#The ext:zca[] extension allows 16-bit instructions to be freely
intermixed with 32-bit instructions, with the latter now able to start
on any 16-bit boundary, i.e., IALIGN=16.# [#norm:Zca_no_misaligned]#With the addition of the ext:zca[]
extension, no instructions can raise instruction-address-misaligned
exceptions.#

[NOTE]
====
Removing the 32-bit alignment constraint on the original 32-bit
instructions allows significantly greater code density.
====

The compressed instruction encodings are mostly common across XLEN=32 and
XLEN=64, but as shown in <<rvc-instr-table0>>, a few opcodes are used for
different purposes depending on base ISA.
For example, the XLEN=64 variant requires additional opcodes to compress loads
and stores of 64-bit integer values, whereas the XLEN=32-only extlink:zcf[] extension
uses the same opcodes to compress loads and stores of single-precision
floating-point values.
If the ext:c[] extension is implemented, the
appropriate compressed floating-point load and store instructions must
be provided whenever the relevant standard floating-point extension (ext:f[]
and/or ext:d[]) is also implemented.
In addition, the XLEN=32 variant includes a compressed jump and link
instruction to compress short-range subroutine calls, where the same opcode is
used to compress ADDIW for XLEN=64.

[NOTE]
====
Double-precision loads and stores are a significant fraction of static and
dynamic instructions, hence the motivation to provide the extlink:zcd[] extension.

Single-precision loads and stores are not a significant source of static or
dynamic compression for programs compiled for the LP64D and ILP32D calling
conventions.
However, for microcontrollers that only provide hardware single-precision
floating-point units and whose programs use the ILP32F calling convention, the
single-precision loads and stores are used at least as frequently as
double-precision loads and stores are used in LP64D and ILP32D--hence the
motivation to provide compressed support for these in the XLEN=32-only extlink:zcf[]
extension.

[[c-jal-rv32-rationale]]
Short-range subroutine calls are more likely in small binaries for
microcontrollers, hence the motivation to include insn:c.jal[] only in the
XLEN=32 variant of ext:zca[].

Although reusing opcodes for different purposes for different base ISAs
adds some complexity to documentation, the impact on implementation
complexity is small even for designs that support multiple base ISAs.
The compressed floating-point load and store variants use the same
instruction format with the same register specifiers as the wider
integer loads and stores.
====

ext:zca[] was designed under the constraint that each ext:zca[] instruction expands
into a single 32-bit instruction in the base ISA.
Adopting this constraint has two main benefits:

* Hardware designs can simply expand ext:zca[] instructions during decode,
simplifying verification and minimizing modifications to existing
microarchitectures.

* Compilers can be unaware of the ext:zca[] extension and leave code compression
to the assembler and linker, although a compression-aware compiler will
generally be able to produce better results.

[NOTE]
====
At the time we designed the ext:zca[] extension, we felt the multiple complexity
reductions of a simple one-one mapping between ext:zca[] and base instructions far
outweighed the potential gains of a slightly denser encoding that added
additional instructions only supported in the ext:zca[] extension, or that allowed
encoding of multiple base instructions in one ext:zca[] instruction.

Since then, additional extensions ext:zcmp[] and ext:zcmt[] have been defined
that further reduce code size at the expense of these complexities.
====

It is important to note that the ext:zca[] extension is not designed to be a
stand-alone ISA, and is meant to be used alongside a base ISA.

[NOTE]
====
Variable-length instruction sets have long been used to improve code
density. For example, the IBM Stretch cite:[stretch], developed in the late 1950s, had
an ISA with 32-bit and 64-bit instructions, where some of the 32-bit
instructions were compressed versions of the full 64-bit instructions.
Stretch also employed the concept of limiting the set of registers that
were addressable in some of the shorter instruction formats, with short
branch instructions that could only refer to one of the index registers.
The later IBM 360 architecture cite:[ibm360] supported a simple variable-length
instruction encoding with 16-bit, 32-bit, or 48-bit instruction formats.

In 1963, CDC introduced the Cray-designed CDC 6600 cite:[cdc6600], a precursor to RISC
architectures, that introduced a register-rich load-store architecture
with instructions of two lengths, 15-bits and 30-bits. The later Cray-1
design used a very similar instruction format, with 16-bit and 32-bit
instruction lengths.

The initial RISC ISAs from the 1980s all picked performance over code
size, which was reasonable for a workstation environment, but not for
embedded systems. Hence, both ARM and MIPS subsequently made versions of
the ISAs that offered smaller code size by offering an alternative
16-bit wide instruction set instead of the standard 32-bit wide
instructions. The compressed RISC ISAs reduced code size relative to
their starting points by about 25-30%, yielding code that was
significantly smaller than 80x86. This result surprised some, as their
intuition was that the variable-length CISC ISA should be smaller than
RISC ISAs that offered only 16-bit and 32-bit formats.

Since the original RISC ISAs did not leave sufficient opcode space free
to include these unplanned compressed instructions, they were instead
developed as complete new ISAs. This meant compilers needed different
code generators for the separate compressed ISAs. The first compressed
RISC ISA extensions (e.g., ARM Thumb and MIPS16) used only a fixed
16-bit instruction size, which gave good reductions in static code size
but caused an increase in dynamic instruction count, which led to lower
performance compared to the original fixed-width 32-bit instruction
size. This led to the development of a second generation of compressed
RISC ISA designs with mixed 16-bit and 32-bit instruction lengths (e.g.,
ARM Thumb2, microMIPS, PowerPC VLE), so that performance was similar to
pure 32-bit instructions but with significant code size savings.
Unfortunately, these different generations of compressed ISAs are
incompatible with each other and with the original uncompressed ISA,
leading to significant complexity in documentation, implementations, and
software tools support.

Of the commonly used 64-bit ISAs, only PowerPC and microMIPS currently
supports a compressed instruction format. It is surprising that the most
popular 64-bit ISA for mobile platforms (ARM v8) does not include a
compressed instruction format given that static code size and dynamic
instruction fetch bandwidth are important metrics. Although static code
size is not a major concern in larger systems, instruction fetch
bandwidth can be a major bottleneck in servers running commercial
workloads, which often have a large instruction working set.

Benefiting from 25 years of hindsight, RISC-V was designed to support
compressed instructions from the outset, leaving enough opcode space for
the compressed extensions to be added on top of the base ISA (along with
many other extensions). The philosophy of ext:zca[] is to reduce code size for
embedded applications _and_ to improve performance and energy-efficiency
for all applications due to fewer misses in the instruction cache.
Waterman shows a 25%-30% reduction in static instruction bits, which
reduces instruction cache misses by 20%-25%, or roughly the same
performance impact as doubling the instruction cache size. cite:[waterman-ms]
====

==== Compressed Instruction Formats
((((compressed, formats))))
<<rvc-form>> shows the nine compressed instruction
formats. CR, CI, and CSS can use any of the 32 RVI registers, but [#norm:Zca_regs8]#CIW,
CL, CS, CA, and CB are limited to just 8 of them.
<<registers>> lists these popular registers, which
correspond to registers `x8` to `x15`.# Note that there is a separate
version of load and store instructions that use the stack pointer as the
base address register, since saving to and restoring from the stack are
so prevalent, and that they use the CI and CSS formats to allow access
to all 32 data registers. CIW supplies an 8-bit immediate for the
insn:addi4spn[] instruction.

[NOTE]
====
The RISC-V ABI was changed to make the frequently used registers map to
registers `x8`-`x15`. This simplifies the decompression decoder by
having a contiguous naturally aligned set of register numbers, and is
also compatible with the RV32E and RV64E base ISAs, which only have 16 integer
registers.
====

((((register source specifiers, c-ext))))
The formats were designed to keep bits for the two register source
specifiers in the same place in all instructions, while the destination
register field can move. When the full 5-bit destination register
specifier is present, it is in the same place as in the 32-bit RISC-V
encoding. Where immediates are sign-extended, the sign extension is
always from bit 12. Immediate fields have been scrambled, as in the base
specification, to reduce the number of immediate multiplexers required.

[NOTE]
====
The immediate fields are scrambled in the instruction formats instead of
in sequential order so that as many bits as possible are in the same
position in every instruction, thereby simplifying implementations.
====

For many ext:zca[] instructions, zero-valued immediates are disallowed and
`x0` is not a valid 5-bit register specifier. These restrictions free up
encoding space for other instructions requiring fewer operand bits.

[[rvc-form]]
.Compressed 16-bit ext:zca[] instruction formats
//[%header]
[float="center",align="center",cols="1a, 2a",frame="none",grid="none"]
|===
|
[%autowidth,float="right",align="right",cols="^,^",frame="none",grid="none",options="noheader"]
!===
!Format ! Meaning
!CR ! Register
!CI ! Immediate
!CSS ! Stack-relative Store
!CIW ! Wide Immediate
!CL ! Load
!CS ! Store
!CA ! Arithmetic
!CB ! Branch/Arithmetic
!CJ ! Jump
!===
|
[float="left",align="left",cols="1,1,1,1,1,1,1",options="noheader"]
!===
^!15 14 13 ^!12 ^!11 10 ^!9 8 7 ^!6 5 ^!4 3 2 ^!1 0
2+^!funct4 2+^!rd/rs1 2+^!rs2 ^!  op
^!funct3 ^!imm 2+^!rd/rs1  2+^!imm ^!  op
^!funct3 3+^!imm  2+^!rs2 ^!  op
^!funct3 4+^!imm ^!rd{prime} ^! op
^!funct3 2+^!imm ^!rs1{prime} ^!imm ^!rd{prime} ^! op
^!funct3 2+^!imm ^!rs1{prime} ^! imm ^!rs2{prime} ^! op
3+^!funct6 ^!rd{prime}/rs1{prime} ^!funct2 ^!rs2{prime} ^! op
^!funct3 2+^!offset ^!rd{prime}/rs1{prime} 2+^!offset ^! op
^!funct3 5+^!jump target ^! op
!===
|===

[[registers]]
.Registers specified by the three-bit _rs1_{prime}, _rs2_{prime}, and _rd_{prime} fields of the CIW, CL, CS, CA, and CB formats.
//[cols="20%,10%,10%,10%,10%,10%,10%,10%,10%"]
[float="center",align="center",cols="1a, 1a",frame="none",grid="none"]
|===
|
[%autowidth,cols="<",frame="none",grid="none",options="noheader"]
!===
!ext:zca[] Register Number
!Integer Register Number
!Integer Register ABI Name
!===
|

[%autowidth,cols="^,^,^,^,^,^,^,^",options="noheader"]
!===
!`000` !`001` !`010` !`011` !`100` !`101` !`110` !`111`
!`x8` !`x9` !`x10` !`x11` !`x12` !`x13` !`x14`!`x15`
!`s0` !`s1` !`a0` !`a1` !`a2` !`a3` !`a4`!`a5`
!===
|===


==== Load and Store Instructions

To increase the reach of 16-bit instructions, data-transfer instructions
use zero-extended immediates that are scaled by the size of the data in
bytes: ×4 for words, ×8 for doublewords, and ×16 for quadwords.

ext:zca[] provides two variants of loads and stores. One uses the ABI stack
pointer, `x2`, as the base address and can target any data register. The
other can reference one of 8 base address registers and one of 8 data
registers.

===== Stack-Pointer-Based Loads and Stores

include::images/wavedrom/c-sp-load-store.edn[]
[[c-sp-load-store]]
//.Stack-Pointer-Based Loads and Stores--these instructions use the CI format.

These instructions use the CI format.

[#norm:c-lwsp_op]#insn:c.lwsp[] loads a 32-bit value from memory into register _rd_. It computes
an effective address by adding the _zero_-extended offset, scaled by 4,
to the stack pointer, `x2`. It expands to insn:lw[rd,offset(x2)].#
[#norm:c-lwsp_rsv]#insn:c.lwsp[] is
valid only when _rd_≠`x0`; the code points with _rd_=`x0` are reserved.#

[#norm:c-ldsp_op]#insn:c.ldsp[] is an XLEN=64-only instruction that loads a 64-bit value
from memory into register _rd_. It computes its effective address by
adding the zero-extended offset, scaled by 8, to the stack pointer,
`x2`. It expands to insn:ld[rd,offset(x2)].#
[#norm:c-ldsp_rsv]#insn:c.ldsp[] is valid only when
_rd_≠`x0`; the code points with
_rd_=`x0` are reserved.#

include::images/wavedrom/c-sp-load-store-css.edn[]
[[c-sp-load-store-css]]
//.Stack-Pointer-Based Loads and Stores--these instructions use the CSS format.

These instructions use the CSS format.

[#norm:c-swsp_op]#insn:c.swsp[] stores a 32-bit value in register _rs2_ to memory. It computes an
effective address by adding the _zero_-extended offset, scaled by 4, to
the stack pointer, `x2`. It expands to insn:sw[rs2,offset(x2)].#

[#norm:c-sdsp_op]#insn:c.sdsp[] is an XLEN=64-only instruction that stores a 64-bit value in
register _rs2_ to memory. It computes an effective address by adding the
_zero_-extended offset, scaled by 8, to the stack pointer, `x2`. It
expands to insn:sd[rs2,offset(x2)].#

[NOTE]
====
Register save/restore code at function entry/exit represents a
significant portion of static code size. The stack-pointer-based
compressed loads and stores in ext:zca[] are effective at reducing the
save/restore static code size by a factor of 2 while improving
performance by reducing dynamic instruction bandwidth.

A common mechanism used in other ISAs to further reduce save/restore
code size is load-multiple and store-multiple instructions. We
considered adopting these for RISC-V but noted the following drawbacks
to these instructions:

* These instructions complicate processor implementations.
* For virtual memory systems, some data accesses could be resident in
physical memory and some could not, which requires a new restart
mechanism for partially executed instructions.
* Unlike the rest of the ext:zca[] instructions, there is no base ISA equivalent to
Load Multiple and Store Multiple.
* Unlike the rest of the ext:zca[] instructions, the compiler would have to be aware
of these load-multiple and store-multiple instructions to both allocate
registers in the expected order and also to schedule the loads and
stores contiguously and in the proper order, to maximize the chances of them
being detected and replaced by an assembler or linker with the equivalent
load-multiple or store-multiple compressed instruction.
* Simple microarchitectural implementations will constrain how other
instructions can be scheduled around the load and store multiple
instructions, leading to a potential performance loss.
* The desire for sequential register allocation might conflict with the
featured registers selected for the CIW, CL, CS, CA, and CB formats.

Furthermore, much of the gains can be realized in software by replacing
prologue and epilogue code with subroutine calls to common prologue and
epilogue code, a technique described in Section 5.6 of cite:[waterman-phd].

While our rationale for omitting load-multiple and store-multiple remains
valid, the pressure to reduce code size is so great, even at the expense of
performance and microarchitectural complexity, that the ext:zcmp[] extension
has since been defined to compress most prologues and epilogues into two bytes
apiece.
====

===== Register-Based Loads and Stores

[[reg-based-ldnstr]]
include::images/wavedrom/reg-based-ldnstr.edn[]
//.Compressed, register-based load and stores--these instructions use the CL format.
(((compressed, register-based load and store)))
These instructions use the CL format.

[#norm:c-lw_op]#insn:c.lw[] loads a 32-bit value from memory into register
`_rd′_`. It computes an effective address by adding the
_zero_-extended offset, scaled by 4, to the base address in register
`_rs1′_`. It expands to insn:lw[rd′,offset(rs1′)].#

[#norm:c-ld_op]#insn:c.ld[] is an XLEN=64-only instruction that loads a 64-bit value from
memory into register `_rd′_`. It computes an effective
address by adding the _zero_-extended offset, scaled by 8, to the base
address in register `_rs1′_`. It expands to
insn:ld[rd′,offset(rs1′)].#

[[c-cs-format-ls]]
include::images/wavedrom/c-cs-format-ls.edn[]
//.Compressed, CS format load and store--these instructions use the CS format.
(((compressed, cs-format load and store)))
These instructions use the CS format.

[#norm:c-sw_op]#insn:c.sw[] stores a 32-bit value in register `_rs2′_` to memory.
It computes an effective address by adding the _zero_-extended offset,
scaled by 4, to the base address in register `_rs1′_`. It
expands to insn:sw[rs2′,offset(rs1′)].#

[#norm:c-sd_op]#insn:c.sd[] is an XLEN=64-only instruction that stores a 64-bit value in
register `_rs2′_` to memory. It computes an effective
address by adding the _zero_-extended offset, scaled by 8, to the base
address in register `_rs1′_`. It expands to
insn:sd[rs2′,offset(rs1′)].#

==== Control Transfer Instructions

ext:zca[] provides unconditional jump instructions and conditional branch
instructions. [#norm:Zca_offsets_mul2]#As with base RVI instructions, the offsets of all
ext:zca[] control transfer instructions are in multiples of 2 bytes.#

[[c-cj-format-ls]]
include::images/wavedrom/c-cj-format-ls.edn[]
//.Compressed, CJ format load and store--these instructions use the CJ format.
(((compressed, cj-format load and store)))
These instructions use the CJ format.

[#norm:c-j_op]#insn:c.j[] performs an unconditional control transfer. The offset is
sign-extended and added to the `pc` to form the jump target address. insn:c.j[] can
therefore target a {pm}2 KiB range. It expands to
insn:jal[x0,offset].#

[#norm:c-jal_op]#insn:c.jal[] is an XLEN=32-only instruction that performs the same operation as
insn:c.j[], but additionally writes the address of the instruction following
the jump (`pc+2`) to the link register, `x1`. It expands to
insn:jal[x1,offset].# (See <<c-jal-rv32-rationale, XLEN=32-only rationale>>.)

[[c-cr-format-ls]]
include::images/wavedrom/c-cr-format-ls.edn[]
//.Compressed, CR format load and store--these instructions use the CR format.
(((compressed, cr-format load and store)))
These instructions use the CR format.

[#norm:c-jr_op]#insn:c.jr[] (jump register) performs an unconditional control transfer to the
address in register _rs1_. It expands to insn:jalr[x0,0(rs1)].#
[#norm:c-jr_rsv]#insn:c.jr[] is
valid only when _rs1_≠`x0`; the code
point with _rs1_=`x0` is reserved.#

[#norm:c-jalr_op]#insn:c.jalr[] (jump and link register) performs the same operation as insn:c.jr[], but
additionally writes the address of the instruction following the jump
(`pc`+2) to the link register, `x1`. It expands to
insn:jalr[x1,0(rs1)].#
[#norm:c-jalr_ebreak]#insn:c.jalr[] is valid only when
_rs1_≠`x0`; the code point with
_rs1_=`x0` corresponds to the insn:c.ebreak[] instruction.#

[NOTE]
====
Strictly speaking, insn:c.jalr[] does not expand exactly to a base RVI
instruction as the value added to the PC to form the link address is 2
rather than 4 as in the base ISA, but supporting both offsets of 2 and 4
bytes is only a very minor change to the base microarchitecture.
====

[[c-cb-format-ls]]
include::images/wavedrom/c-cb-format-ls.edn[]
//.Compressed, CB format load and store--these instructions use the CB format.
(((compressed, cb-format load and store)))
These instructions use the CB format.

[#norm:c-beqz_op]#insn:c.beqz[] performs conditional control transfers. The offset is
sign-extended and added to the `pc` to form the branch target address.
It can therefore target a {pm}256 B range. insn:c.beqz[] takes the
branch if the value in register _rs1′_ is zero. It
expands to insn:beq[rs1′,x0,offset`].#

[#norm:c-bnez_op]#insn:c.bnez[] is defined analogously, but it takes the branch if
_rs1′_ contains a nonzero value. It expands to
insn:bne[rs1′,x0,offset`].#

==== Integer Computational Instructions

ext:zca[] provides several instructions for integer arithmetic and constant
generation.

===== Integer Constant-Generation Instructions

The two constant-generation instructions both use the CI instruction
format and can target any integer register.

[[c-integer-const-gen]]
include::images/wavedrom/c-integer-const-gen.edn[]
//.Integer constant generation format.
(((compressed, integer constant generation)))

[#norm:c-li_op]#insn:c.li[] loads the sign-extended 6-bit immediate, _imm_, into register _rd_.
It expands into insn:addi[rd,x0,imm].#
[#norm:c-li_hint]#The insn:c.li[] code points with _rd_=`x0` are HINTs.#

[#norm:c-lui_op]#insn:c.lui[] loads the non-zero 6-bit immediate field into bits 17–12 of the
destination register, clears the bottom 12 bits, and sign-extends bit 17
into all higher bits of the destination. It expands into
insn:lui[rd,imm].#
[#norm:c-lui_rsv]#insn:c.lui[] is valid only when
_rd_≠`x2`,
and when the immediate is not equal to zero. The code points with
_imm_=0 are reserved.
The code points with _rd_=`x2` and _imm_≠0 correspond to the
insn:c.addi16sp[] instruction.#
[#norm:c-lui_hint]#The code points with _rd_=`x0` and _imm_≠0 are HINTs.#

===== Integer Register-Immediate Operations

These integer register-immediate operations are encoded in the CI format
and perform operations on an integer register and a 6-bit immediate.

[[c-integer-register-immediate]]
include::images/wavedrom/c-int-reg-immed.edn[]
//.Integer register-immediate format.
(((compressed, integer register-immediate)))
[#norm:c-addi_op]#insn:c.addi[] adds the non-zero sign-extended 6-bit immediate to the value in
register _rd_ then writes the result to _rd_. It expands into
insn:addi[rd,rd,imm].#
[#norm:c-addi_hint]#The code points with _rd_≠0 and _imm_=0 are HINTs.#
[#norm:c-addi_nop]#The code points with _rd_=`x0` encode the insn:c.nop[] instruction, of
which the code points with _imm_≠0 are HINTs.#


[#norm:c-addiw_op]#insn:c.addiw[] is an XLEN=64-only instruction that performs the same
computation but produces a 32-bit result, then sign-extends result to 64
bits. It expands into insn:addiw[rd,rd,imm]. The immediate can be
zero for insn:c.addiw[], where this corresponds to insn:sext.w[rd].#
[#norm:c-addiw_rsv]#insn:c.addiw[] is
valid only when _rd_≠`x0`; the code points with
_rd_=`x0` are reserved.#

[#norm:c-addi16sp_op]#insn:c.addi16sp[] (add immediate to stack pointer)
shares the opcode with insn:c.lui[], but has a destination field of
`x2`. insn:c.addi16sp[] adds the non-zero sign-extended 6-bit immediate to the
value in the stack pointer (`sp=x2`), where the immediate is scaled to
represent multiples of 16 in the range [-512, 496]. insn:c.addi16sp[] is used to
adjust the stack pointer in procedure prologues and epilogues. It
expands into insn:addi[x2,x2,nzimm[9:4]].#
[#norm:c-addi16sp_rsv]#insn:c.addi16sp[] is valid only when
_nzimm_≠0; the code point with _nzimm_=0 is reserved.#

[NOTE]
====
In the standard RISC-V calling convention, the stack pointer `sp` is
always 16-byte aligned.
====

[[c-ciw]]
include::images/wavedrom/c-ciw.edn[]
//.CIW format.
(((compressed, CIW)))
[#norm:c-addi4spn_op]#insn:c.addi4spn[] (add immediate to stack pointer, non-destructive)
is a CIW-format instruction that adds a _zero_-extended
non-zero immediate, scaled by 4, to the stack pointer, `x2`, and writes
the result to `rd′`. This instruction is used to generate
pointers to stack-allocated variables, and expands to
insn:addi[rd′,x2,nzuimm[9:2]].#
[#norm:c-addi4spn_rsv]#insn:c.addi4spn[] is valid only when
_nzuimm_≠0; the code points with _nzuimm_=0 are
reserved.#

[[c-ci]]
include::images/wavedrom/c-ci.edn[]
//.CI format.
(((compressed, CI)))
[#norm:c-slli_op]#insn:c.slli[] is a CI-format instruction that performs a logical left shift of
the value in register _rd_ then writes the result to _rd_. The shift
amount is encoded in the _shamt_ field.
It expands into insn:slli[rd,rd,shamt[5:0]].#

[#norm:c-slli_hint]#The insn:c.slli[] code points with _shamt_=0 or with _rd_=`x0` are HINTs.#

[#norm:c-slli_shamt5]#For XLEN=32, _shamt[5]_ must be zero; the code points with _shamt[5]_=1
are designated for custom extensions.#

[[c-srli-srai]]

include::images/wavedrom/c-srli-srai.edn[]
//.C-SRLI-SRAI format.
(((compressed, C.SRLI, C.SRAI)))
[#norm:c-srli_op]#insn:c.srli[] is a CB-format instruction that performs a logical right shift of
the value in register _rd′_ then writes the result to
_rd′_. The shift amount is encoded in the _shamt_ field.
It expands into insn:srli[rd′,rd′,shamt].#

[#norm:c-srli_hint]#The insn:c.srli[] code points with _shamt_=0 are HINTs.#

[#norm:c-srli_shamt5]#For XLEN=32, _shamt[5]_ must be zero; the code points with _shamt[5]_=1
are designated for custom extensions.#

[#norm:c-srai_op]#insn:c.srai[] is defined analogously to insn:c.srli[], but instead performs an
arithmetic right shift. It expands to
insn:srai[rd′,rd′,shamt].#

[NOTE]
====
Left shifts are usually more frequent than right shifts, as left shifts
are frequently used to scale address values. Right shifts have therefore
been granted less encoding space and are placed in an encoding quadrant
where all other immediates are sign-extended.
====
[[c-andi]]
include::images/wavedrom/c-andi.edn[]
//.C.ANDI format
(((compressed, C.ANDI)))
[#norm:c-andi_op]#insn:c.andi[] is a CB-format instruction that computes the bitwise AND of the
value in register _rd′_ and the sign-extended 6-bit
immediate, then writes the result to _rd′_. It
expands to insn:andi[rd′,rd′,imm].#

===== Integer Register-Register Operations

[[c-cr]]
include::images/wavedrom/c-int-reg-to-reg-cr-format.edn[]
//C.CR format
((((compressed. C.CR))))
These instructions use the CR format.

[#norm:c-mv_op]#insn:c.mv[] copies the value in register _rs2_ into register _rd_. It expands
into insn:add[rd,x0,rs2].#
[#norm:c-mv_jr]#insn:c.mv[] is valid only when
_rs2_≠`x0`; the code points with _rs2_=`x0` correspond to the insn:c.jr[] instruction.#
[#norm:c-mv_hint]#The code points with _rs2_≠`x0` and _rd_=`x0` are HINTs.#

[NOTE]
====
insn:c.mv[] expands to a different instruction than the canonical
insn:mv[] pseudoinstruction, which instead uses insn:addi[]. Implementations that handle
insn:mv[] specially, e.g. using register-renaming hardware, may find it more
convenient to expand insn:c.mv[] to insn:mv[] instead of insn:add[], at slight additional
hardware cost.
====

[#norm:c-add_op]#insn:c.add[] adds the values in registers _rd_ and _rs2_ and writes the result
to register _rd_. It expands into insn:add[rd,rd,rs2].#
[#norm:c-add_val]#insn:c.add[] is only
valid when _rs2_≠`x0`; the code points with _rs2_=`x0` correspond to the
insn:c.jalr[] and insn:c.ebreak[] instructions.#
[#norm:c-add_hint]#The code points with _rs2_≠`x0` and _rd_=`x0` are HINTs.#

[[c-ca]]
include::images/wavedrom/c-int-reg-to-reg-ca-format.edn[]
//C.CA format
((((compressed. C.CA))))
These instructions use the CA format.

[#norm:c-and_op]#insn:c.and[] computes the bitwise `AND` of the values in registers
_rd′_ and _rs2′_, then writes the result
to register _rd′_. It expands into
insn:and[rd′,rd′,rs2′].#

[#norm:c-or_op]#insn:c.or[] computes the bitwise `OR` of the values in registers
_rd′_ and _rs2′_, then writes the result
to register _rd′_. It expands into
insn:or[rd′,rd′, rs2′].#

[#norm:c-xor_op]#insn:c.xor[] computes the bitwise `XOR` of the values in registers
_rd′_ and _rs2′_, then writes the result
to register _rd′_. It expands into
insn:xor[rd′,rd′,rs2′].#

[#norm:c-sub_op]#insn:c.sub[] subtracts the value in register _rs2′_ from the
value in register _rd′_, then writes the result to
register _rd′_. It expands into
insn:sub[rd′,rd′,rs2′].#

[#norm:c-addw_op]#insn:c.addw[] is an XLEN=64-only instruction that adds the values in
registers _rd′_ and _rs2′_, then
sign-extends the lower 32 bits of the sum before writing the result to
register _rd′_. It expands into
insn:addw[rd′,rd′,rs2′].#

[#norm:c-subw_op]#insn:c.subw[] is an XLEN=64-only instruction that subtracts the value in
register _rs2′_ from the value in register
_rd′_, then sign-extends the lower 32 bits of the
difference before writing the result to register _rd′_.
It expands into insn:subw[rd′,rd′,rs2′].#

[NOTE]
====
This group of six instructions do not provide large savings
individually, but do not occupy much encoding space and are
straightforward to implement, and as a group provide a worthwhile
improvement in static and dynamic compression.
====

===== Defined Illegal Instruction

[[c-def-illegal-inst]]
include::images/wavedrom/c-def-illegal-inst.edn[]
((((compressed. C.DIINST))))
[#norm:Zca_illegal]#A 16-bit instruction with all bits zero is permanently reserved as an
illegal instruction.#

[NOTE]
====
We reserve all-zero instructions to be illegal instructions to help trap
attempts to execute zero-ed or non-existent portions of the memory
space. The all-zero value should not be redefined in any non-standard
extension. Similarly, we reserve instructions with all bits set to 1
(corresponding to very long instructions in the RISC-V variable-length
encoding scheme) as illegal to capture another common value seen in
non-existent memory regions.
====

===== NOP Instruction

[[c-nop-instr]]
include::images/wavedrom/c-nop-instr.edn[]
((((compressed. C.NOPINSTR))))
[#norm:c-nop_op]#insn:c.nop[] is a CI-format instruction that does not change any user-visible
state, except for advancing the `pc` and incrementing any applicable
performance counters. insn:c.nop[] expands to insn:nop[].#
[#norm:c-nop_hint]#The insn:c.nop[] code points
with _imm_≠0 encode HINTs.#

[[insn:c.ebreak]]
===== Breakpoint Instruction

include::images/wavedrom/c-breakpoint-instr.edn[]
((((compressed. C.BREAKPOINTINSTR))))
[#norm:c-ebreak_op]#Debuggers can use the insn:c.ebreak[] instruction, which expands to insn:ebreak[],
to cause control to be transferred back to the debugging environment.
insn:c.ebreak[] shares the opcode with the insn:c.add[] instruction, but with _rd_ and
_rs2_ both zero, thus can also use the `CR` format.#

==== Usage of Compressed Instructions in insn:lr[]/insn:sc[] Sequences

On implementations that support the ext:zca[] extension, compressed forms of
instructions permitted inside constrained insn:lr[]/insn:sc[] sequences, as
described in <<sec:lrscseq>>, are also permitted
inside constrained insn:lr[]/insn:sc[] sequences.

[NOTE]
====
The implication is that any implementation that claims to support both
the extlink:a[] and ext:zca[] extensions must ensure that insn:lr[]/insn:sc[] sequences containing valid
ext:zca[] instructions will eventually complete.
====

[[rvc-hints]]
==== HINT Instructions

[#norm:Zca_hints]#A portion of the ext:zca[] encoding space is reserved for microarchitectural
HINTs. Like the HINTs in the RV32I base ISA (see
<<rv32i-hints>>), these instructions do not
modify any architectural state, except for advancing the `pc` and any
applicable performance counters. HINTs are executed as no-ops on
implementations that ignore them.#

ext:zca[] HINTs are encoded as computational instructions that do not modify
the architectural state, either because _rd_=`x0` (e.g.
insn:c.add[x0,t0]), or because _rd_ is overwritten with a copy of itself
(e.g. insn:c.addi[t0,0]).

[NOTE]
====
This HINT encoding has been chosen so that simple implementations can
ignore HINTs altogether, and instead execute a HINT as a regular
computational instruction that happens not to mutate the architectural
state.
====

ext:zca[] HINTs do not necessarily expand to their RVI HINT counterparts. For
example, insn:c.add[x0,a0] might not encode the same HINT as
insn:add[x0,x0,a0].

[NOTE]
====
The primary reason to not require an ext:zca[] HINT to expand to an RVI HINT
is that HINTs are unlikely to be compressible in the same manner as the
underlying computational instruction. Also, decoupling the ext:zca[] and RVI
HINT mappings allows the scarce ext:zca[] HINT space to be allocated to the
most popular HINTs, and in particular, to HINTs that are amenable to
macro-op fusion.
====

<<rvc-t-hints>> lists all ext:zca[] HINT code points. For XLEN=32, 78%
of the HINT space is reserved for standard HINTs. The remainder of the HINT space is designated for custom HINTs;
no standard HINTs will ever be defined in this subspace.

[[rvc-t-hints]]
.ext:zca[] HINT instructions.
[cols="<,<,>,<",options="header",]
|===
|Instruction |Constraints |Code Points |Purpose

|insn:c.nop[] |_imm_≠0 |63 .6+.^|_Designated for future standard use_

|insn:c.addi[] | _rd_≠`x0`, _imm_=0 |31

|insn:c.li[] | _rd_=`x0` |64

|insn:c.lui[] | _rd_=`x0`, _imm_≠0 |63

|insn:c.mv[] | _rd_=`x0`, _rs2_≠`x0` |31

|insn:c.add[] | _rd_=`x0`, _rs2_≠`x0`, _rs2_≠`x2-x5` | 27

|insn:c.add[] | _rd_=`x0`, _rs2_=`x2-x5` |4|(rs2=x2) insn:c.ntl.p1[] (rs2=x3) insn:c.ntl.pall[] (rs2=x4) insn:c.ntl.s1[] (rs2=x5) insn:c.ntl.all[]

|insn:c.slli[] |_rd_=`x0` or _imm_=0 |63 (RV32), 95 (RV64)  .3+.^|_Designated for custom use_

|insn:c.srli[] | _imm_=0 |8

|insn:c.srai[] | _imm_=0 |8
|===

==== ext:zca[] Instruction Set Listings

<<rvcopcodemap>> shows a map of the major
opcodes for the compressed extensions. Each row of the table corresponds to one quadrant of
the encoding space. The last quadrant, which has the two
least-significant bits set, corresponds to instructions wider than 16
bits, including those in the base ISAs. Several instructions are only
valid for certain operands; when invalid, they are marked either _RES_
to indicate that the opcode is reserved for future standard extensions;
_Custom_ to indicate that the opcode is designated for custom
extensions; or _HINT_ to indicate that the opcode is reserved for
microarchitectural hints (see <<rvc-hints>>).

<<<

[[rvcopcodemap]]
.ext:zca[] opcode map.
[%autowidth,float="center",align="center",cols=">,^,^,^,^,^,^,^,^,^,<]
|===
2+>|inst[15:13] +
inst[1:0] ^.^s|000 ^.^s|001 ^.^s|010 ^.^s|011 ^.^s|100 ^.^s|101 ^.^s|110 ^.^s|111 |

2+>.^|00 .^|ADDI4SPN ^.^|FLD +
FLD ^.^| LW ^.^| FLW +
LD ^.^| _Reserved_ ^.^| FSD +
FSD ^.^| SW ^.^| FSW +
SD
^.^| RV32 +
RV64

2+>.^|01 ^.^|ADDI ^.^|JAL +
ADDIW ^.^|LI ^.^|LUI/ADDI16SP ^.^|MISC-ALU ^.^|J ^.^|BEQZ ^.^|BNEZ ^.^|RV32 +
RV64

2+>.^|10 ^.^|SLLI ^.^|FLDSP +
FLDSP ^.^|LWSP ^.^|FLWSP +
LDSP ^.^|J[AL]R/MV/ADD ^.^|FSDSP +
FSDSP ^.^|SWSP ^.^|FSWSP +
SDSP ^.^|RV32 +
RV64

2+>.^|11 9+^|>16b
|===

<<rvc-instr-table0>>, <<rvc-instr-table1>>, and <<rvc-instr-table2>> list the ext:zca[] instructions.

[[rvc-instr-table0]]
.ext:zca[] Instruction listing, Quadrant 0
include::images/bytefield/rvc-instr-quad0.edn[]

[[rvc-instr-table1]]
.ext:zca[] Instruction listing, Quadrant 1
include::images/bytefield/rvc-instr-quad1.edn[]

[[rvc-instr-table2]]
.ext:zca[] Instruction listing, Quadrant 2
include::images/bytefield/rvc-instr-quad2.edn[]
```

### src/unpriv/images/wavedrom/c-sp-load-store.edn

```text
//## 16.3 Load and Store Instructions
//### Stack-Pointer-Based Loads and Stores

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',     attr: ['2','C2','C2','C2','C2']},
  {bits: 5, name: 'imm',    attr: ['5','offset[4:2|7:6]', 'offset[4:3|8:6]', 'offset[4:2|7:6]', 'offset[4:3|8:6]']},
  {bits: 5, name: 'rd',     attr: ['5','dest≠0', 'dest≠0', 'dest', 'dest']},
  {bits: 1, name: 'imm',    attr: ['1','offset[5]','offset[5]','offset[5]','offset[5]']},
  {bits: 3, name: 'funct3', attr: ['3','C.LWSP', 'C.LDSP', 'C.FLWSP', 'C.FLDSP']},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/c-sp-load-store-css.edn

```text
//c-sp load and store, css format--is this correct?

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',     attr: ['2','C2','C2','C2','C2']},
  {bits: 5, name: 'rs2',    attr: ['5', 'src', 'src', 'src', 'src']},
  {bits: 6, name: 'imm',    attr: ['6','offset[5:2|7:6]', 'offset[5:3|8:6]', 'offset[5:2|7:6]','offset[5:3|8:6]']},
  {bits: 3, name: 'funct3', attr: ['3','C.SWSP', 'C.SDSP', 'C.FSWSP', 'C.FSDSP']},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/reg-based-ldnstr.edn

```text
//Register-Based loads and Stores


[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2', 'C0', 'C0', 'C0', 'C0']},
  {bits: 3, name: 'rdʹ',  attr: ['3', 'dest','dest','dest','dest']},
  {bits: 2, name: 'imm', attr:['2', 'offset[2|6]', 'offset[7:6]', 'offset[2|6]', 'offset[7:6]']},
  {bits: 3, name: 'rs1ʹ', attr: ['3', 'base', 'base', 'base', 'base']},
  {bits: 3, name: 'imm',  attr: ['3', 'offset[5:3]', 'offset[5:3]', 'offset[5:3]', 'offset[5:3]']},
  {bits: 3, name: 'funct3',  attr: ['3', 'C.LW', 'C.LD', 'C.FLW', 'C.FLD']},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/c-cs-format-ls.edn

```text
//## 16.X Load and Store Instructions
//### c-cs-format-ls

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',     attr: ['2', 'C0','C0','C0','C0']},
  {bits: 3, name: 'rs2ʹ',   attr: ['3', 'src','src','src','src']},
  {bits: 2, name: 'imm',    attr: ['2', 'offset[2|6]','offset[7:6]','offset[2|6]','offset[7:6]']},
  {bits: 3, name: 'rs1ʹ',   attr: ['3', 'base','base','base','base']},
  {bits: 3, name: 'imm',    attr: ['3', 'offset[5:3]','offset[5:3]','offset[5:3]','offset[5:3]']},
  {bits: 3, name: 'funct3', attr: ['3', 'C.SW','C.SD','C.FSW','C.FSD']},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/c-cj-format-ls.edn

```text
//c-cj-format-ls

//[wavedrom, ,svg]
//....
//{reg: [
//   {bits: 2,  name: 'op', attr: ['2','CI','CI']},
//   {bits: 10, name: 'imm'},
//   {bits: 4,  name: 'funct3' attr:['3','CJ','CJAL']},
//] config: {bits: 16}}
//....


[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',     attr: ['2','C1','C1']},
  {bits: 11, name: 'imm',   attr: ['11','offset[11|4|9:8|10|6|7|3:1|5]','offset[11|4|9:8|10|6|7|3:1|5]']},
  {bits: 3, name: 'funct3', attr: ['3','C.J','C.JAL']},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/c-cr-format-ls.edn

```text
//These instructions use the CR format.

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C2', 'C2']},
  {bits: 5, name: 'rs2',     attr: ['5','0', '0']},
  {bits: 5, name: 'rs1',     attr: ['5','src≠0', 'src≠0']},
  {bits: 4, name: 'funct4',  attr: ['4','C.JR', 'C.JALR']},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/c-cb-format-ls.edn

```text
//c-cb-format-ls

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C1', 'C1']},
  {bits: 5, name: 'imm', attr: ['5','offset[7:6|2:1|5]', 'offset[7:6|2:1|5]']},
  {bits: 3, name: 'rs1′',     attr: ['3','src', 'src']},
  {bits: 3, name: 'imm',    attr: ['3','offset[8|4:3]', 'offset[8|4:3]'],},
  {bits: 3, name: 'funct3',    attr: ['3','C.BEQZ', 'C.BNEZ'],},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/c-integer-const-gen.edn

```text
//c-integer-const-gen

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C1', 'C1']},
  {bits: 5, name: 'imm[4:0]',    attr: ['5','imm[4:0]','nzimm[16:12]']},
  {bits: 5, name: 'rd',     attr: ['5','dest != 0', 'dest != {0, 2}']},
  {bits: 1, name: 'imm[5]',    attr: ['1','imm[5]', 'nzimm[17]'],},
  {bits: 3, name: 'funct3',    attr: ['3','C.LI', 'C.LUI'],},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/c-int-reg-immed.edn

```text
//c-int-reg-immed.adoc

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',        attr: ['2','C1', 'C1', 'C1']},
  {bits: 5, name: 'imm[4:0]',  attr: ['5','nzimm[4:0]', 'imm[4:0]', 'nzimm[4|6|8:7|5]']},
  {bits: 5, name: 'rd/rs1',    attr: ['5','dest != 0', 'dest != 0', '2']},
  {bits: 1, name: 'imm[5]',    attr: ['1','nzimm[5]', 'imm[5]', 'nzimm[9]']},
  {bits: 3, name: 'funct3',    attr: ['3','C.ADDI', 'C.ADDIW', 'C.ADDI16SP']},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/c-ciw.edn

```text
//c-ciw.adoc

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C0'],},
  {bits: 3, name: 'rd′',     attr: ['3','dest'],},
  {bits: 8, name: 'imm',    attr: ['8','nzuimm[5:4|9:6|2|3]']},
  {bits: 3, name: 'funct3',    attr: ['3','C.ADDI4SPN']},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/c-ci.edn

```text
//

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2', 'C2']},
  {bits: 5, name: 'shamt[4:0]',    attr: ['5', 'shamt[4:0]']},
  {bits: 5, name: 'rd/rs1',     attr: ['5', 'dest != 0']},
  {bits: 1, name: 'shamt[5]',    attr: ['1', 'shamt[5]']},
  {bits: 3, name: 'funct3',    attr: ['3', 'C.SLLI']},
]}
....
```

### src/unpriv/images/wavedrom/c-srli-srai.edn

```text
//c-srli-srai.adoc

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C1', 'C1'],},
  {bits: 5, name: 'shamt[4:0]',    attr: ['5','shamt[4:0]', 'shamt[4:0]'],},
  {bits: 3, name: 'rd′/rs1′',     attr: ['3','dest', 'dest'],},
  {bits: 2, name: 'funct2',    attr: ['2','C.SRLI', 'C.SRAI'],},
  {bits: 1, name: 'shamt[5]',    attr: ['1','shamt[5]', 'shamt[5]'],},
  {bits: 3, name: 'funct3',    attr: ['3','C.SRLI', 'C.SRAI'],},
]}
....
```

### src/unpriv/images/wavedrom/c-andi.edn

```text
//c-andi.adoc

[wavedrom, ,svg]
....
{reg: [
  {bits: 2, name: 'op',    attr: ['2','C1'],},
  {bits: 5, name: 'imm[4:0]',    attr: ['5','imm[4:0]']},
  {bits: 3, name: 'rd′/rs1′',    attr: ['3','dest'],},
  {bits: 2, name: 'funct2',     attr: ['2','C.ANDI'],},
  {bits: 1, name: 'imm[5]',    attr: ['1','imm[5]'],},
  {bits: 3, name: 'funct3', attr: ['3','C.ANDI'],},
]}
....
```

### src/unpriv/images/wavedrom/c-int-reg-to-reg-cr-format.edn

```text
//

[wavedrom, ,svg]

....
{reg: [
  {bits: 2, name: 'op',     attr: ['2', 'C2', 'C2'],},
  {bits: 5, name: 'rs2',    attr: ['5', 'src≠0', 'src≠0'],},
  {bits: 5, name: 'rd/rs1', attr: ['5', 'dest≠0', 'dest≠0'],},
  {bits: 4, name: 'funct4', attr: ['4', 'C.MV', 'C.ADD'],},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/c-int-reg-to-reg-ca-format.edn

```text
//

[wavedrom, ,svg]

....
{reg: [
  {bits: 2, name: 'op',     attr: ['2', 'C1', 'C1', 'C1', 'C1', 'C1', 'C1'],},
  {bits: 3, name: 'rs2′',    attr: ['3', 'src', 'src', 'src', 'src', 'src', 'src'],},
  {bits: 2, name: 'funct2', attr: ['2', 'C.AND', 'C.OR', 'C.XOR', 'C.SUB', 'C.ADDW', 'C.SUBW'],},
  {bits: 3, name: 'rd′/rs1′', attr: ['3', 'dest', 'dest', 'dest', 'dest', 'dest', 'dest'],},
  {bits: 6, name: 'funct6', attr: ['6', 'C.AND', 'C.OR', 'C.XOR', 'C.SUB', 'C.ADDW', 'C.SUBW'],},
]}
....
```

### src/unpriv/images/wavedrom/c-def-illegal-inst.edn

```text
//

[wavedrom, ,svg]

....
{reg: [
  {bits: 2, name: '0', attr: ['2','0'],},
  {bits: 5, name: '0', attr: ['5','0'],},
  {bits: 5, name: '0', attr: ['5','0'],},
  {bits: 1, name: '0', attr: ['1','0'],},
  {bits: 3, name: '0', attr: ['3','0'],},
], config: {bits: 16}}
....
```

### src/unpriv/images/wavedrom/c-nop-instr.edn

```text
//

[wavedrom, ,svg]

....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C1'],},
  {bits: 5, name: 'imm[4:0]', attr: ['5','0'],},
  {bits: 5, name: 'rd/rs1', attr: ['5','0'],},
  {bits: 1, name: 'imm[5]', attr: ['1','0'],},
  {bits: 3, name: 'funct3', attr: ['3','C.NOP'],},
]}
....
```

### src/unpriv/images/wavedrom/c-breakpoint-instr.edn

```text
//

[wavedrom, ,svg]

....
{reg: [
  {bits: 2, name: 'op', attr: ['2','C2'],},
  {bits: 10, name: '0', attr: ['10','0'],},
  {bits: 4, name: 'funct4', attr: ['4','C.EBREAK'],},
], config: {bits: 16}}
....
```

### src/unpriv/images/bytefield/rvc-instr-quad0.edn

```text
[bytefield]
----
(defattrs :plain [:plain {:font-family "M+ 1p Fallback"}])
(defattrs :math [:math {:font-family "M+ 1p Fallback"}])
(def row-height 35 )
(def row-header-fn nil)
(def left-margin 0)
(def right-margin 40)
(def boxes-per-row 23)
(draw-column-headers {:labels (reverse ["" "" "" "" "" "" "" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15"])})
(draw-box "000" {:span 3 :vertical-align "middle"})
(draw-box "0" {:span 8})
(draw-box "0" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "Illegal instruction" {:font-style "italic"}) {:span 7 :text-anchor "start" :borders {}})

(draw-box "000" {:span 3})
(draw-box "uimm[5:4|9:6|2|3]" {:span 8})
(draw-box (text "rd′" [:plain {:font-family "M+ 1p Fallback"}]) {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.ADDI4SPN" :math [:sub "(RES, uimm=0)"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "001" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[7:6]" {:font-size 16}) {:span 2})
(draw-box "rd′" {:span 3})
(draw-box "00" {:span 2})
(draw-box "C.FLD" {:span 7 :text-anchor "start" :borders {}})

(draw-box "010" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[2|6]" {:font-size 16}) {:span 2})
(draw-box "rd′" {:span 3})
(draw-box "00" {:span 2})
(draw-box "C.LW" {:span 7 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[2|6]" {:font-size 16}) {:span 2})
(draw-box "rd′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.FLW" :math [:sub "(RV32)"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[7:6]" {:font-size 16}) {:span 2})
(draw-box "rd′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.LD" :math [:sub "(RV64)"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "---" {:span 11})
(draw-box "00" {:span 2})
(draw-box (text "Reserved"  {:font-style "italic"}) {:span 7 :text-anchor "start" :borders {}})

(draw-box "101" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[7:6]" {:font-size 16}) {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "00" {:span 2})
(draw-box "C.FSD" {:span 7 :text-anchor "start" :borders {}})

(draw-box "110" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[2|6]" {:font-size 16}) {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "00" {:span 2})
(draw-box "C.SW" {:span 7 :text-anchor "start" :borders {}})

(draw-box "111" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[2|6]" {:font-size 16}) {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.FSW" :math [:sub "(RV32)"]) {:span 7 :text-anchor "start" :borders {}})

(draw-box "111" {:span 3})
(draw-box "uimm[5:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box (text "uimm[7:6]" {:font-size 16}) {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "00" {:span 2})
(draw-box (text "C.SD" :math [:sub "(RV64)"]) {:span 7 :text-anchor "start" :borders {}})
----
```

### src/unpriv/images/bytefield/rvc-instr-quad1.edn

```text
[bytefield]
----
(defattrs :plain [:plain {:font-weight "bold" :font-family "M+ 1p Fallback"}])
(defattrs :math [:math {:font-family "M+ 1p Fallback"}])
(def row-height 50 )
(def row-header-fn nil)
(def left-margin 0)
(def right-margin 0)
(def boxes-per-row 19)
(def box-width 70)
(draw-column-headers {:labels (reverse ["" "" "" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15"])})

(draw-box "000" {:span 3})
(draw-box "imm[5]" {:span 1})
(draw-box "0" {:span 5})
(draw-box "imm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.NOP" :math [:sub "(HINT, imm≠0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "000" {:span 3})
(draw-box "imm[5]") {:span 1}
(draw-box "rs1/rd≠0" {:span 5})
(draw-box "imm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.ADDI" :math [:sub "(HINT, imm=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "001" {:span 3})
(draw-box "imm[11|4|9:8|10|6|7|3:1|5]" {:span 11})
(draw-box "01" {:span 2})
(draw-box (text "C.JAL" :math [:sub "(RV32)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "001" {:span 3})
(draw-box "imm[5]" {:span 1})
(draw-box "rs1/rd≠0" {:span 5})
(draw-box "imm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.ADDIW" :math [:sub "(RV64; RES, rd=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "010" {:span 3})
(draw-box "imm[5]" {:span 1})
(draw-box "rd̸=0" {:span 5})
(draw-box "imm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.LI" :math [:sub "(HINT, rd=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box "imm[9]" {:span 1})
(draw-box "2" {:span 5})
(draw-box "imm[4|6|8:7|5]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.ADDI16SP" :math [:sub "(RES, imm=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box (text "imm[17]" {:font-width 11}) {:span 1})
(draw-box "rd≠{0, 2}" {:span 5})
(draw-box "imm[16:12]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.LUI" :math [:sub "(RES, imm=0; HINT, rd=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box (text "uimm[5]" {:font-width 11}) {:span 1})
(draw-box "00" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "uimm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.SRLI" :math [:sub "(HINT, uimm=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box (text "uimm[5]" {:font-width 11}) {:span 1})
(draw-box "01" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "uimm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box (text "C.SRAI" :math [:sub "(HINT, uimm=0)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "imm[5]" {:span 1})
(draw-box "10" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "imm[4:0]" {:span 5})
(draw-box "01" {:span 2})
(draw-box "C.ANDI" {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "00" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box "C.SUB" {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "01" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box "C.XOR" {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "10" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box "C.OR" {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "11" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box "C.AND" {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "00" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box (text "C.SUBW" :math [:sub "(RV64; RV32 RES)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "11" {:span 2})
(draw-box "rs1ʹ/rdʹ" {:span 3})
(draw-box "01" {:span 2})
(draw-box "rs2′" {:span 3})
(draw-box "01" {:span 2})
(draw-box (text "C.ADDW" :math [:sub "(RV64; RV32 RES)"]) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "11" {:span 2})
(draw-box "---" {:span 3})
(draw-box "10" {:span 2})
(draw-box "---" {:span 3})
(draw-box "01" {:span 2})
(draw-box (text "Reserved" {:font-style "italic"}) {:span 3 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "11" {:span 2})
(draw-box "---" {:span 3})
(draw-box "11" {:span 2})
(draw-box "---" {:span 3})
(draw-box "01" {:span 2})
(draw-box (text "Reserved" {:font-style "italic"}) {:span 3 :text-anchor "start" :borders {}})

(draw-box "101" {:span 3})
(draw-box "imm[11|4|9:8|10|6|7|3:1|5]" {:span 11})
(draw-box "01" {:span 2})
(draw-box "C.J" {:span 3 :text-anchor "start" :borders {}})

(draw-box "110" {:span 3})
(draw-box "imm[8|4:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box "imm[7:6|2:1|5]" {:span 5})
(draw-box "01" {:span 2})
(draw-box "C.BEQZ" {:span 3 :text-anchor "start" :borders {}})

(draw-box "111" {:span 3})
(draw-box "imm[8|4:3]" {:span 3})
(draw-box "rs1′" {:span 3})
(draw-box "imm[7:6|2:1|5]" {:span 5})
(draw-box "01" {:span 2})
(draw-box "C.BNEZ" {:span 3 :text-anchor "start" :borders {}})
----
```

### src/unpriv/images/bytefield/rvc-instr-quad2.edn

```text
[bytefield]
----
(defattrs :plain [:plain {:font-family "M+ 1p Fallback"}])
(defattrs :math [:math {:font-family "M+ 1p Fallback"}])
(def row-height 50 )
(def row-header-fn nil)
(def left-margin 0)
(def right-margin 40)
(def boxes-per-row 22)
(def box-width 70)
(draw-column-headers {:labels (reverse ["" "" "" "" "" "" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15"])})

(draw-box "000" {:span 3})
(draw-box (text "nzuimm[5]" {:font-size 16}) {:span 1})
(draw-box "rs1/rd≠0" {:span 5})
(draw-box "nzuimm[4:0]" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.SLLI" :math [:sub "(HINT, rd=0 or imm=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "001" {:span 3})
(draw-box (text "uimm[5]" {:font-size 16}) {:span 1})
(draw-box "rd" {:span 5})
(draw-box "uimm[4:3|8:6]" {:span 5})
(draw-box "10" {:span 2})
(draw-box "C.FLDSP" {:span 6 :text-anchor "start" :borders {}})

(draw-box "010" {:span 3})
(draw-box (text "uimm[5]" {:font-size 16}) {:span 1})
(draw-box "rd≠0" {:span 5})
(draw-box "uimm[4:2|7:6]" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.LWSP" :math [:sub "(RES, rd=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box (text "uimm[5]" {:font-size 16}) {:span 1})
(draw-box "rd" {:span 5})
(draw-box "uimm[4:2|7:6]" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.FLWSP" :math [:sub "(RV32)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "011" {:span 3})
(draw-box (text "uimm[5]" {:font-size 16}) {:span 1})
(draw-box "rd≠0" {:span 5})
(draw-box "uimm[4:3|8:6]" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.LDSP" :math [:sub "(RV64; RES, rd=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "rs1≠0" {:span 5})
(draw-box "0" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.JR" :math [:sub "(RES, rs1=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "0" {:span 1})
(draw-box "rd≠0" {:span 5})
(draw-box "rs2≠0" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.MV" :math [:sub "(HINT, rd=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "0" {:span 5})
(draw-box "0" {:span 5})
(draw-box "10" {:span 2})
(draw-box "C.EBREAK" {:span 6 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "rs1≠0" {:span 5})
(draw-box "0" {:span 5})
(draw-box "10" {:span 2})
(draw-box "C.JALR" {:span 6 :text-anchor "start" :borders {}})

(draw-box "100" {:span 3})
(draw-box "1" {:span 1})
(draw-box "rs1/rd≠0" {:span 5})
(draw-box "rs2≠0" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.ADD" :math [:sub "(HINT, rd=0)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "101" {:span 3})
(draw-box "uimm[5:3|8:6]" {:span 6})
(draw-box "rs2" {:span 5})
(draw-box "10" {:span 2})
(draw-box "C.FSDSP" {:span 6 :text-anchor "start" :borders {}})

(draw-box "110" {:span 3})
(draw-box "uimm[5:2|7:6]" {:span 6})
(draw-box "rs2" {:span 5})
(draw-box "10" {:span 2})
(draw-box "C.SWSP" {:span 6 :text-anchor "start" :borders {}})

(draw-box "111" {:span 3})
(draw-box "uimm[5:2|7:6]" {:span 6})
(draw-box "rs2" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.FSWSP" :math [:sub "(RV32)"]) {:span 6 :text-anchor "start" :borders {}})

(draw-box "111" {:span 3})
(draw-box "uimm[5:3|8:6]" {:span 6})
(draw-box "rs2" {:span 5})
(draw-box "10" {:span 2})
(draw-box (text "C.SDSP" :math [:sub "(RV64)"]) {:span 6 :text-anchor "start" :borders {}})
----
```
