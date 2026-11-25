# Implement `Decode32`

Implement the complete `Decode32` class. Preserve the class name and interface shown below.

Return only the complete `class Decode32` definition in a single Scala code block, with no text outside the block.

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
  hasVector: Boolean = false,
// ...
  aluNum: Int = 2,
  mulNum: Int = 1,
  fpuNum: Int = 0,
```

## Package and imports

### src/main/scala/rift2Core/frontend/Decoder.scala

```scala
package rift2Core.frontend

import chisel3._
import chisel3.util._
import rift2Core.define._

import rift2Chip._
import org.chipsalliance.cde.config._
```

## Class declaration

### src/main/scala/rift2Core/frontend/Decoder.scala

```scala
class Decode32(implicit p: Parameters) extends DecodeBase
```

## Parent instantiation

### src/main/scala/rift2Core/frontend/Decoder.scala

```scala
object Decode32 {
  /**
    * Decodes the given 32-bit RISC-V instruction.
    *
    * @param x The 32-bit instruction to be decoded.
    * @param pc The program counter for the instruction.
    * @param hasFpu Indicates whether or not the processor has a floating point unit.
    * @param p The implicit Parameters object for the Rift2Core.
    * @return An Info_instruction object representing the decoded instruction.
    */
  def apply(x:UInt, pc: UInt, hasFpu: Boolean, hasVector: Boolean)(implicit p: Parameters): Info_instruction = {
    // val info = Wire(new Info_instruction)
    val dec32 = Module( (if(hasVector) {new Decode32 with VDecode32} else {new Decode32 with NVDecode}) )
    dec32.io.x := x
    dec32.io.pc := pc
    return dec32.io.info
  }
}
```

## Dependency declarations

### src/main/scala/rift2Core/frontend/Decoder.scala

```scala
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
// ...
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
// ...
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
// ...
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
// ...
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
// ...
class Reg_RAW(implicit p: Parameters) extends RiftBundle {
  val vm0 = UInt((log2Ceil(32)).W)
  val rs1 = UInt((log2Ceil(32)).W)
  val rs2 = UInt((log2Ceil(32)).W)
  val rs3 = UInt((log2Ceil(32)).W)
  val rd0 = UInt((log2Ceil(32)).W)
}
// ...
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
// ...
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

### src/main/scala/rift2Core/vector/VDecode32.scala

```scala
trait NVDecode{ this: DecodeBase =>
  info.vecIsa := 0.U.asTypeOf( new VecIsa )

  info.csrIsa.vsetvli  := false.B
  info.csrIsa.vsetivli := false.B
  info.csrIsa.vsetvl   := false.B

  info.lsuIsa.vle8      := false.B
  info.lsuIsa.vle16     := false.B
  info.lsuIsa.vle32     := false.B
  info.lsuIsa.vle64     := false.B
  info.lsuIsa.vlm       := false.B
  info.lsuIsa.vsm       := false.B
  info.lsuIsa.vlse8     := false.B
  info.lsuIsa.vlse16    := false.B
  info.lsuIsa.vlse32    := false.B
  info.lsuIsa.vlse64    := false.B
  info.lsuIsa.vloxei8   := false.B
  info.lsuIsa.vloxei16  := false.B
  info.lsuIsa.vloxei32  := false.B
  info.lsuIsa.vloxei64  := false.B
  info.lsuIsa.vle8ff    := false.B
  info.lsuIsa.vle16ff   := false.B
  info.lsuIsa.vle32ff   := false.B
  info.lsuIsa.vle64ff   := false.B
  info.lsuIsa.vlre8    := false.B
  info.lsuIsa.vlre16   := false.B
  info.lsuIsa.vlre32   := false.B
  info.lsuIsa.vlre64   := false.B
  info.lsuIsa.vse8      := false.B
  info.lsuIsa.vse16     := false.B
  info.lsuIsa.vse32     := false.B
  info.lsuIsa.vse64     := false.B
  info.lsuIsa.vsse8     := false.B
  info.lsuIsa.vsse16    := false.B
  info.lsuIsa.vsse32    := false.B
  info.lsuIsa.vsse64    := false.B
  info.lsuIsa.vsoxei8   := false.B
  info.lsuIsa.vsoxei16  := false.B
  info.lsuIsa.vsoxei32  := false.B
  info.lsuIsa.vsoxei64  := false.B
  info.lsuIsa.vsr       := false.B

  if( hasVector ){
    info.vAttach.get := 0.U.asTypeOf(new VRename_Attach_Bundle)
  }
}
```

## Related source code

### src/main/scala/rift2Core/frontend/IF4.scala

```scala
    instr_fifo.io.enq(i).bits :=
      Mux( is_rvc(i),
        Decode16(x = io.if4_req(i).bits.instr(15,0), pc = io.if4_req(i).bits.pc, fpuNum > 0),
        Decode32(x = io.if4_req(i).bits.instr,       pc = io.if4_req(i).bits.pc, fpuNum > 0, hasVector)
      )
```

### src/main/scala/rift2Core/backend/Rename.scala

```scala
    io.xRename(i).req.valid    := io.rnReq(i).fire & io.rnReq(i).bits.isXwb
    io.xRename(i).req.bits.rd0 := io.rnReq(i).bits.param.raw.rd0
```

### src/main/scala/rift2Core/backend/Issue.scala

```scala
  def Pkg_alu_iss(idx: Int): Alu_iss_info = {

    val res = Wire(new Alu_iss_info)
    val src1 = postBufOperator(idx)(1)
    val src2 = postBufOperator(idx)(2)
    res.fun.add := bufInfo(idx).aluIsa.is_fun_add
    res.fun.slt := bufInfo(idx).aluIsa.is_fun_slt
    res.fun.xor := bufInfo(idx).aluIsa.is_fun_xor
    res.fun.or  := bufInfo(idx).aluIsa.is_fun_or
    res.fun.and := bufInfo(idx).aluIsa.is_fun_and
    res.fun.sll := bufInfo(idx).aluIsa.is_fun_sll
    res.fun.srl := bufInfo(idx).aluIsa.is_fun_srl
    res.fun.sra := bufInfo(idx).aluIsa.is_fun_sra

    res.param.is_32w  := bufInfo(idx).aluIsa.is_32w
    res.param.is_usi  := bufInfo(idx).aluIsa.is_usi


    res.param.dat.op1 :=
      Mux1H(Seq(
        bufInfo(idx).aluIsa.lui    -> 0.U,  bufInfo(idx).aluIsa.auipc  -> extVaddr(bufInfo(idx).param.pc, vlen),
        bufInfo(idx).aluIsa.addi   -> src1, bufInfo(idx).aluIsa.addiw  -> src1,
        bufInfo(idx).aluIsa.slti   -> src1, bufInfo(idx).aluIsa.sltiu  -> src1,
        bufInfo(idx).aluIsa.xori   -> src1, bufInfo(idx).aluIsa.ori    -> src1,
        bufInfo(idx).aluIsa.andi   -> src1, bufInfo(idx).aluIsa.slli   -> src1,
        bufInfo(idx).aluIsa.slliw  -> src1, bufInfo(idx).aluIsa.srli   -> src1,
        bufInfo(idx).aluIsa.srliw  -> src1, bufInfo(idx).aluIsa.srai   -> src1,
        bufInfo(idx).aluIsa.sraiw  -> src1, bufInfo(idx).aluIsa.add    -> src1,
        bufInfo(idx).aluIsa.addw   -> src1, bufInfo(idx).aluIsa.sub    -> src1,
        bufInfo(idx).aluIsa.subw   -> src1, bufInfo(idx).aluIsa.sll    -> src1,
        bufInfo(idx).aluIsa.sllw   -> src1, bufInfo(idx).aluIsa.slt    -> src1,
        bufInfo(idx).aluIsa.sltu   -> src1, bufInfo(idx).aluIsa.xor    -> src1,
        bufInfo(idx).aluIsa.srl    -> src1, bufInfo(idx).aluIsa.srlw   -> src1,
        bufInfo(idx).aluIsa.sra    -> src1, bufInfo(idx).aluIsa.sraw   -> src1,
        bufInfo(idx).aluIsa.or     -> src1, bufInfo(idx).aluIsa.and    -> src1,

        bufInfo(idx).aluIsa.wfi    -> 0.U,

    ))

    res.param.dat.op2 :=
      Mux1H(Seq(
        bufInfo(idx).aluIsa.lui    -> bufInfo(idx).param.imm,      bufInfo(idx).aluIsa.auipc  -> bufInfo(idx).param.imm,
        bufInfo(idx).aluIsa.addi   -> bufInfo(idx).param.imm,      bufInfo(idx).aluIsa.addiw  -> bufInfo(idx).param.imm,
        bufInfo(idx).aluIsa.slti   -> bufInfo(idx).param.imm,      bufInfo(idx).aluIsa.sltiu  -> bufInfo(idx).param.imm,
        bufInfo(idx).aluIsa.xori   -> bufInfo(idx).param.imm,      bufInfo(idx).aluIsa.ori    -> bufInfo(idx).param.imm,
        bufInfo(idx).aluIsa.andi   -> bufInfo(idx).param.imm,      bufInfo(idx).aluIsa.slli   -> bufInfo(idx).param.imm(5,0),
        bufInfo(idx).aluIsa.slliw  -> bufInfo(idx).param.imm(5,0), bufInfo(idx).aluIsa.srli   -> bufInfo(idx).param.imm(5,0),
        bufInfo(idx).aluIsa.srliw  -> bufInfo(idx).param.imm(5,0), bufInfo(idx).aluIsa.srai   -> bufInfo(idx).param.imm(5,0),
        bufInfo(idx).aluIsa.sraiw  -> bufInfo(idx).param.imm(5,0), bufInfo(idx).aluIsa.add    -> src2,
        bufInfo(idx).aluIsa.addw   -> src2,                        bufInfo(idx).aluIsa.sub    -> (~src2 + 1.U),
        bufInfo(idx).aluIsa.subw   -> (~src2 + 1.U),               bufInfo(idx).aluIsa.sll    -> src2,
        bufInfo(idx).aluIsa.sllw   -> src2,                        bufInfo(idx).aluIsa.slt    -> src2,
        bufInfo(idx).aluIsa.sltu   -> src2,                        bufInfo(idx).aluIsa.xor    -> src2,
        bufInfo(idx).aluIsa.srl    -> src2,                        bufInfo(idx).aluIsa.srlw   -> src2,
        bufInfo(idx).aluIsa.sra    -> src2,                        bufInfo(idx).aluIsa.sraw   -> src2,
        bufInfo(idx).aluIsa.or     -> src2,                        bufInfo(idx).aluIsa.and    -> src2,

        bufInfo(idx).aluIsa.wfi    -> 0.U
    ))
    res.param.dat.op0 := 0.U
    res.param.dat.op3 := 0.U

    res.param.rd0 := bufInfo(idx).phy.rd0
    return res
  }
// ...
  def Pkg_mul_iss(idx: Int): Mul_iss_info = {
    val res = Wire(new Mul_iss_info)
    res.fun := bufInfo(idx).mulIsa

    res.param.dat.op0 := 0.U
    res.param.dat.op1 := postBufOperator(idx)(1)
    res.param.dat.op2 := postBufOperator(idx)(2)
    res.param.dat.op3 := 0.U

    res.param.rd0     := bufInfo(idx).phy.rd0
    return res
  }
// ...
  def Pkg_bru_iss(idx: Int): Bru_iss_info = {
    val res = Wire(new Bru_iss_info)
    res.fun           := bufInfo(idx).bruIsa
    res.param.is_rvc  := bufInfo(idx).param.is_rvc
    res.param.pc      := extVaddr(bufInfo(idx).param.pc, vlen)
    res.param.imm     := bufInfo(idx).param.imm

    res.param.dat.op0 := 0.U
    res.param.dat.op1 := postBufOperator(idx)(1)
    res.param.dat.op2 := postBufOperator(idx)(2)
    res.param.dat.op3 := 0.U

    res.param.rd0     := bufInfo(idx).phy.rd0

    return res
  }
// ...
  def Pkg_csr_iss(idx: Int): Csr_iss_info = {
    val res = Wire(new Csr_iss_info)
    val csrSel = bufInfo(idx).param.imm(11,0)

    res.fun.rc  := bufInfo(idx).csrIsa.rc | bufInfo(idx).csrIsa.rci
    res.fun.rs  := bufInfo(idx).csrIsa.rs | bufInfo(idx).csrIsa.rsi
    res.fun.rw  := bufInfo(idx).csrIsa.rw | bufInfo(idx).csrIsa.rwi
    res.fun.vsetvli  := ( if(hasVector) {bufInfo(idx).csrIsa.vsetvli  } else {false.B} )
    res.fun.vsetivli := ( if(hasVector) {bufInfo(idx).csrIsa.vsetivli } else {false.B} )
    res.fun.vsetvl   := ( if(hasVector) {bufInfo(idx).csrIsa.vsetvl   } else {false.B} )

    res.param.dat.op1 := 
      Mux1H(
        Seq(
          bufInfo(idx).csrIsa.rw  -> postBufOperator(idx)(1), bufInfo(idx).csrIsa.rwi -> bufInfo(idx).param.raw.rs1,
          bufInfo(idx).csrIsa.rs  -> postBufOperator(idx)(1), bufInfo(idx).csrIsa.rsi -> bufInfo(idx).param.raw.rs1,
          bufInfo(idx).csrIsa.rc  -> postBufOperator(idx)(1), bufInfo(idx).csrIsa.rci -> bufInfo(idx).param.raw.rs1,
        ) ++
        ( if(hasVector){
          Seq(
            bufInfo(idx).csrIsa.vsetvli  -> Mux( bufInfo(idx).param.raw.rs1 =/= 0.U, postBufOperator(idx)(1), Mux(bufInfo(idx).param.raw.rd0 =/= 0.U, Fill(64,1.U), io.csrfiles.vl) ),
            bufInfo(idx).csrIsa.vsetivli -> bufInfo(idx).param.raw.rs1,
            bufInfo(idx).csrIsa.vsetvl   -> Mux( bufInfo(idx).param.raw.rs1 =/= 0.U, postBufOperator(idx)(1), Mux(bufInfo(idx).param.raw.rd0 =/= 0.U, Fill(64,1.U), io.csrfiles.vl) ),
          ) } else {Seq()})
      )




    /** automatically create csr address mux according CSRInfoTable */
    res.param.dat.op2 := 
      Mux(
        bufInfo(idx).csrIsa.isXCSR,
        Mux1H(
          (for ( info <- CSRInfoTable.CSRGroup; io <- io.csrfiles.elements; if( (info.name == io._1) ) ) yield {
            (csrSel === (info.address).U) -> ( io._2.asUInt )
          }) ++

          (for( i <- 0 until pmpNum by 2 ) yield{
            ((csrSel === ("h3A0".U + i.U)) -> io.csrfiles.pmpcfg(i).asUInt)
          }) ++

          (for( i <- 0 until pmpNum*8 ) yield{
            ((csrSel === ("h3B0".U + i.U)) -> io.csrfiles.pmpaddr(i).asUInt)
          }) ++

          (for( i <- 3 until 32 ) yield{
            ((csrSel === ("hB00".U + i.U)) -> io.csrfiles.mhpmcounter(i))
          }) ++

          (for( i <- 3 until 32 ) yield{
            ((csrSel === ("h320".U + i.U)) -> io.csrfiles.mhpmevent(i))
          }) ++ 

          (for( i <- 3 until 32 ) yield{
            ((csrSel === ("hC00".U + i.U)) -> io.csrfiles.hpmcounter(i))
          })
        ),
        (if(hasVector){ Mux1H(Seq(
          bufInfo(idx).csrIsa.vsetvli  -> bufInfo(idx).param.imm(10,0),
          bufInfo(idx).csrIsa.vsetivli -> bufInfo(idx).param.imm(9,0),
          bufInfo(idx).csrIsa.vsetvl   -> postBufOperator(idx)(2),
        ))} else {0.U})
      )


    res.param.dat.op0 := 0.U
    res.param.dat.op3 := 
      Mux(
        ( if(hasVector){ bufInfo(idx).csrIsa.vsetvli | bufInfo(idx).csrIsa.vsetivli | bufInfo(idx).csrIsa.vsetvl } else {false.B} ),
        "hffe".U(12.W),
        bufInfo(idx).param.imm(11,0)
      )
      

    res.param.rd0     := bufInfo(idx).phy.rd0

    return res
  }
// ...
  for( i <- 0 until dptEntry ) {

    lsuIssInfo(i).fun := bufInfo(i).lsuIsa

    lsuIssInfo(i).param.dat.op0 := Mux( bufInfo(i).lsuIsa.is_vls, vecBufOperator(0), 0.U )

    lsuIssInfo(i).param.dat.op1 := 
      Mux1H(Seq(
        (bufInfo(i).lsuIsa.is_xls  | bufInfo(i).lsuIsa.is_fls)  -> (postBufOperator(i)(1).asSInt + bufInfo(i).param.imm.asSInt).asUInt,
        (bufInfo(i).lsuIsa.is_lrsc | bufInfo(i).lsuIsa.is_amo)  -> postBufOperator(i)(1),
```

## Documentation

```text
[%autowidth.stretch,float="center",align="center",cols="^2m,^2m,^2m,^2m,<2m,>3m, <4m, >4m, <4m, >4m, <4m, >4m, <4m, >4m, <6m"]
|===
    |31 |27 |26  |25    |24 |  20|19  |  15| 14  |  12|11      |      7|6   |   0|
 4+^|funct7          2+^|rs2  2+^|rs1    2+^|funct3 2+^|rd           2+^|opcode  <|R-type
 6+^|imm[11:0]               2+^|rs1    2+^|funct3 2+^|rd           2+^|opcode  <|I-type
 4+^|imm[11:5]      2+^|rs2  2+^|rs1    2+^|funct3 2+^|imm[4:0]     2+^|opcode  <|S-type
 4+^|imm[12\|10:5]  2+^|rs2  2+^|rs1    2+^|funct3 2+^|imm[4:1\|11] 2+^|opcode  <|B-type
10+^|imm[31:12]                                    2+^|rd           2+^|opcode  <|U-type
10+^|imm[20\|10:1\|11\|19:12]                      2+^|rd           2+^|opcode  <|J-type
|===

[%autowidth.stretch,float="center",align="center",cols="^2m,^2m,^2m,^2m,<2m,>3m, <4m, >4m, <4m, >4m, <4m, >4m, <4m, >4m, <6m"]
|===
15+^|*RV32I Base Instruction Set*
10+^|imm[31:12]                                    2+^|rd           2+^|0110111 <|[#norm:lui_enc]#LUI#
10+^|imm[31:12]                                    2+^|rd           2+^|0010111 <|[#norm:auipc_enc]#AUIPC#
10+^|imm[20\|10:1\|11\|19:12]                      2+^|rd           2+^|1101111 <|[#norm:jal_enc]#JAL#
 6+^|imm[11:0]                2+^|rs1   2+^|000    2+^|rd           2+^|1100111 <|[#norm:jalr_enc]#JALR#
 4+^|imm[12\|10:5]  2+^|rs2   2+^|rs1   2+^|000    2+^|imm[4:1\|11] 2+^|1100011 <|[#norm:beq_enc]#BEQ#
 4+^|imm[12\|10:5]  2+^|rs2   2+^|rs1   2+^|001    2+^|imm[4:1\|11] 2+^|1100011 <|[#norm:bne_enc]#BNE#
 4+^|imm[12\|10:5]  2+^|rs2   2+^|rs1   2+^|100    2+^|imm[4:1\|11] 2+^|1100011 <|[#norm:blt_enc]#BLT#
 4+^|imm[12\|10:5]  2+^|rs2   2+^|rs1   2+^|101    2+^|imm[4:1\|11] 2+^|1100011 <|[#norm:bge_enc]#BGE#
 4+^|imm[12\|10:5]  2+^|rs2   2+^|rs1   2+^|110    2+^|imm[4:1\|11] 2+^|1100011 <|[#norm:bltu_enc]#BLTU#
 4+^|imm[12\|10:5]  2+^|rs2   2+^|rs1   2+^|111    2+^|imm[4:1\|11] 2+^|1100011 <|[#norm:bgeu_enc]#BGEU#
 6+^|imm[11:0]                2+^|rs1   2+^|000    2+^|rd           2+^|0000011 <|[#norm:lb_enc]#LB#
 6+^|imm[11:0]                2+^|rs1   2+^|001    2+^|rd           2+^|0000011 <|[#norm:lh_enc]#LH#
 6+^|imm[11:0]                2+^|rs1   2+^|010    2+^|rd           2+^|0000011 <|[#norm:lw_enc]#LW#
 6+^|imm[11:0]                2+^|rs1   2+^|100    2+^|rd           2+^|0000011 <|[#norm:lbu_enc]#LBU#
 6+^|imm[11:0]                2+^|rs1   2+^|101    2+^|rd           2+^|0000011 <|[#norm:lhu_enc]#LHU#
 4+^|imm[11:5]      2+^|rs2   2+^|rs1   2+^|000    2+^|imm[4:0]     2+^|0100011 <|[#norm:sb_enc]#SB#
 4+^|imm[11:5]      2+^|rs2   2+^|rs1   2+^|001    2+^|imm[4:0]     2+^|0100011 <|[#norm:sh_enc]#SH#
 4+^|imm[11:5]      2+^|rs2   2+^|rs1   2+^|010    2+^|imm[4:0]     2+^|0100011 <|[#norm:sw_enc]#SW#
 6+^|imm[11:0]                2+^|rs1   2+^|000    2+^|rd           2+^|0010011 <|[#norm:addi_enc]#ADDI#
 6+^|imm[11:0]                2+^|rs1   2+^|010    2+^|rd           2+^|0010011 <|[#norm:slti_enc]#SLTI#
 6+^|imm[11:0]                2+^|rs1   2+^|011    2+^|rd           2+^|0010011 <|[#norm:sltiu_enc]#SLTIU#
 6+^|imm[11:0]                2+^|rs1   2+^|100    2+^|rd           2+^|0010011 <|[#norm:xori_enc]#XORI#
 6+^|imm[11:0]                2+^|rs1   2+^|110    2+^|rd           2+^|0010011 <|[#norm:ori_enc]#ORI#
 6+^|imm[11:0]                2+^|rs1   2+^|111    2+^|rd           2+^|0010011 <|[#norm:andi_enc]#ANDI#
 4+^|0000000        2+^|shamt 2+^|rs1   2+^|001    2+^|rd           2+^|0010011 <|[#norm:slli_enc]#SLLI#
 4+^|0000000        2+^|shamt 2+^|rs1   2+^|101    2+^|rd           2+^|0010011 <|[#norm:srli_enc]#SRLI#
 4+^|0100000        2+^|shamt 2+^|rs1   2+^|101    2+^|rd           2+^|0010011 <|[#norm:srai_enc]#SRAI#
 4+^|0000000        2+^|rs2   2+^|rs1   2+^|000    2+^|rd           2+^|0110011 <|[#norm:add_enc]#ADD#
 4+^|0100000        2+^|rs2   2+^|rs1   2+^|000    2+^|rd           2+^|0110011 <|[#norm:sub_enc]#SUB#
 4+^|0000000        2+^|rs2   2+^|rs1   2+^|001    2+^|rd           2+^|0110011 <|[#norm:sll_enc]#SLL#
 4+^|0000000        2+^|rs2   2+^|rs1   2+^|010    2+^|rd           2+^|0110011 <|[#norm:slt_enc]#SLT#
 4+^|0000000        2+^|rs2   2+^|rs1   2+^|011    2+^|rd           2+^|0110011 <|[#norm:sltu_enc]#SLTU#
 4+^|0000000        2+^|rs2   2+^|rs1   2+^|100    2+^|rd           2+^|0110011 <|[#norm:xor_enc]#XOR#
 4+^|0000000        2+^|rs2   2+^|rs1   2+^|101    2+^|rd           2+^|0110011 <|[#norm:srl_enc]#SRL#
 4+^|0100000        2+^|rs2   2+^|rs1   2+^|101    2+^|rd           2+^|0110011 <|[#norm:sra_enc]#SRA#
 4+^|0000000        2+^|rs2   2+^|rs1   2+^|110    2+^|rd           2+^|0110011 <|[#norm:or_enc]#OR#
 4+^|0000000        2+^|rs2   2+^|rs1   2+^|111    2+^|rd           2+^|0110011 <|[#norm:and_enc]#AND#
 3+^|fm   2+^|pred  1+^|succ  2+^|rs1   2+^|000    2+^|rd           2+^|0001111 <|[#norm:fence_enc]#FENCE#
 3+^|1000 2+^|0011  1+^|0011  2+^|00000 2+^|000    2+^|00000        2+^|0001111 <|[#norm:fence-tso_enc]#FENCE.TSO#
 3+^|0000 2+^|0001  1+^|0000  2+^|00000 2+^|000    2+^|00000        2+^|0001111 <|[#norm:pause_enc]#PAUSE#
 6+^|000000000000             2+^|00000 2+^|000    2+^|00000        2+^|1110011 <|[#norm:ecall_enc]#ECALL#
 6+^|000000000001             2+^|00000 2+^|000    2+^|00000        2+^|1110011 <|[#norm:ebreak_enc]#EBREAK#
|===

<<<

[%autowidth.stretch,float="center",align="center",cols="^2m,^2m,^2m,^2m,<2m,>3m, <4m, >4m, <4m, >4m, <4m, >4m, <4m, >4m, <6m"]
|===
15+^|
    |31 |27 |26  |25    |24 |  20|19  |  15| 14  |  12|11      |      7|6   |     0|
 4+^|funct7          2+^|rs2  2+^|rs1    2+^|funct3 2+^|rd           2+^|opcode  <|R-type
 6+^|imm[11:0]               2+^|rs1    2+^|funct3 2+^|rd           2+^|opcode  <|I-type
 4+^|imm[11:5]      2+^|rs2  2+^|rs1    2+^|funct3 2+^|imm[4:0]     2+^|opcode  <|S-type
|===

[%autowidth.stretch,float="center",align="center",cols="^2m,^2m,^2m,^2m,<2m,>3m, <4m, >4m, <4m, >4m, <4m, >4m, <4m, >4m, <6m"]
|===
15+^|*RV64I Base Instruction Set (in addition to RV32I)*
 6+^|imm[11:0]                2+^|rs1   2+^|110    2+^|rd           2+^|0000011 <|[#norm:lwu_enc]#LWU#
 6+^|imm[11:0]                2+^|rs1   2+^|011    2+^|rd           2+^|0000011 <|[#norm:ld_enc]#LD#
 4+^|imm[11:5]      2+^|rs2   2+^|rs1   2+^|011    2+^|imm[4:0]     2+^|0100011 <|[#norm:sd_enc]#SD#
 3+^|000000         3+^|shamt 2+^|rs1   2+^|001    2+^|rd           2+^|0010011 <|SLLI
 3+^|000000         3+^|shamt 2+^|rs1   2+^|101    2+^|rd           2+^|0010011 <|SRLI
 3+^|010000         3+^|shamt 2+^|rs1   2+^|101    2+^|rd           2+^|0010011 <|SRAI
 6+^|imm[11:0]                2+^|rs1   2+^|000    2+^|rd           2+^|0011011 <|[#norm:addiw_enc]#ADDIW#
 4+^|0000000        2+^|shamt 2+^|rs1   2+^|001    2+^|rd           2+^|0011011 <|[#norm:slliw_enc]#SLLIW#
 4+^|0000000        2+^|shamt 2+^|rs1   2+^|101    2+^|rd           2+^|0011011 <|[#norm:srliw_enc]#SRLIW#
 4+^|0100000        2+^|shamt 2+^|rs1   2+^|101    2+^|rd           2+^|0011011 <|[#norm:sraiw_enc]#SRAIW#
 4+^|0000000        2+^|rs2   2+^|rs1   2+^|000    2+^|rd           2+^|0111011 <|[#norm:addw_enc]#ADDW#
 4+^|0100000        2+^|rs2   2+^|rs1   2+^|000    2+^|rd           2+^|0111011 <|[#norm:subw_enc]#SUBW#
 4+^|0000000        2+^|rs2   2+^|rs1   2+^|001    2+^|rd           2+^|0111011 <|[#norm:sllw_enc]#SLLW#
 4+^|0000000        2+^|rs2   2+^|rs1   2+^|101    2+^|rd           2+^|0111011 <|[#norm:srlw_enc]#SRLW#
 4+^|0100000        2+^|rs2   2+^|rs1   2+^|101    2+^|rd           2+^|0111011 <|[#norm:sraw_enc]#SRAW#
|===
[%autowidth.stretch,float="center",align="center",cols="^2m,^2m,^2m,^2m,<2m,>3m, <4m, >4m, <4m, >4m, <4m, >4m, <4m, >4m, <6m"]
|===
15+^|*RV32/RV64 _Zifencei_ Standard Extension*
 6+^|imm[11:0]                2+^|rs1   2+^|001    2+^|rd           2+^|0001111 <|FENCE.I
|===

[%autowidth.stretch,float="center",align="center",cols="^2m,^2m,^2m,^2m,<2m,>3m, <4m, >4m, <4m, >4m, <4m, >4m, <4m, >4m, <6m"]
|===
15+^|*RV32/RV64 _Zicsr_ Standard Extension*
 6+^|csr                      2+^|rs1   2+^|001    2+^|rd           2+^|1110011 <|CSRRW
 6+^|csr                      2+^|rs1   2+^|010    2+^|rd           2+^|1110011 <|CSRRS
 6+^|csr                      2+^|rs1   2+^|011    2+^|rd           2+^|1110011 <|CSRRC
 6+^|csr                      2+^|uimm  2+^|101    2+^|rd           2+^|1110011 <|CSRRWI
 6+^|csr                      2+^|uimm  2+^|110    2+^|rd           2+^|1110011 <|CSRRSI
 6+^|csr                      2+^|uimm  2+^|111    2+^|rd           2+^|1110011 <|CSRRCI
|===

[%autowidth.stretch,float="center",align="center",cols="^2m,^2m,^2m,^2m,<2m,>3m, <4m, >4m, <4m, >4m, <4m, >4m, <4m, >4m, <6m"]
|===
15+^|*RV32M Standard Extension*
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|000    2+^|rd           2+^|0110011 <|[#norm:mul_enc]#MUL#
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|001    2+^|rd           2+^|0110011 <|[#norm:mulh_enc]#MULH#
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|010    2+^|rd           2+^|0110011 <|[#norm:mulhsu_enc]#MULHSU#
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|011    2+^|rd           2+^|0110011 <|[#norm:mulhu_enc]#MULHU#
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|100    2+^|rd           2+^|0110011 <|[#norm:div_enc]#DIV#
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|101    2+^|rd           2+^|0110011 <|[#norm:divu_enc]#DIVU#
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|110    2+^|rd           2+^|0110011 <|[#norm:rem_enc]#REM#
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|111    2+^|rd           2+^|0110011 <|[#norm:remu_enc]#REMU#
|===

[%autowidth.stretch,float="center",align="center",cols="^2m,^2m,^2m,^2m,<2m,>3m, <4m, >4m, <4m, >4m, <4m, >4m, <4m, >4m, <6m"]
|===
15+^|*RV64M Standard Extension (in addition to RV32M)*
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|000    2+^|rd           2+^|0111011 <|[#norm:mulw_enc]#MULW#
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|100    2+^|rd           2+^|0111011 <|[#norm:divw_enc]#DIVW#
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|101    2+^|rd           2+^|0111011 <|[#norm:divuw_enc]#DIVUW#
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|110    2+^|rd           2+^|0111011 <|[#norm:remw_enc]#REMW#
 4+^|0000001        2+^|rs2   2+^|rs1   2+^|111    2+^|rd           2+^|0111011 <|[#norm:remuw_enc]#REMUW#
|===

<<<

[%autowidth.stretch,float="center",align="center",cols="^2m,^2m,^2m,^2m,<2m,>3m, <4m, >4m, <4m, >4m, <4m, >4m, <4m, >4m, <6m"]
|===
15+^|
    |31 |27 |26  |25    |24 |  20|19  |  15| 14  |  12|11      |      7|6   |     0|
 4+^|funct7          2+^|rs2  2+^|rs1    2+^|funct3 2+^|rd           2+^|opcode  <|R-type
|===

[%autowidth.stretch,float="center",align="center",cols="^2m,^2m,^2m,^2m,<2m,>3m, <4m, >4m, <4m, >4m, <4m, >4m, <4m, >4m, <6m"]
|===
15+^|*RV32A Standard Extension*
 2+^|00010 ^|aq ^|rl 2+^|00000 2+^|rs1  2+^|010    2+^|rd           2+^|0101111 <|LR.W
 2+^|00011 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|010    2+^|rd           2+^|0101111 <|SC.W
 2+^|00001 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|010    2+^|rd           2+^|0101111 <|AMOSWAP.W
 2+^|00000 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|010    2+^|rd           2+^|0101111 <|AMOADD.W
 2+^|00100 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|010    2+^|rd           2+^|0101111 <|AMOXOR.W
 2+^|01100 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|010    2+^|rd           2+^|0101111 <|AMOAND.W
 2+^|01000 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|010    2+^|rd           2+^|0101111 <|AMOOR.W
 2+^|10000 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|010    2+^|rd           2+^|0101111 <|AMOMIN.W
 2+^|10100 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|010    2+^|rd           2+^|0101111 <|AMOMAX.W
 2+^|11000 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|010    2+^|rd           2+^|0101111 <|AMOMINU.W
 2+^|11100 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|010    2+^|rd           2+^|0101111 <|AMOMAXU.W
|===

[%autowidth.stretch,float="center",align="center",cols="^2m,^2m,^2m,^2m,<2m,>3m, <4m, >4m, <4m, >4m, <4m, >4m, <4m, >4m, <6m"]
|===
15+^|*RV64A Standard Extension (in addition to RV32A)*
 2+^|00010 ^|aq ^|rl 2+^|00000 2+^|rs1  2+^|011    2+^|rd           2+^|0101111 <|LR.D
 2+^|00011 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|011    2+^|rd           2+^|0101111 <|SC.D
 2+^|00001 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|011    2+^|rd           2+^|0101111 <|AMOSWAP.D
 2+^|00000 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|011    2+^|rd           2+^|0101111 <|AMOADD.D
 2+^|00100 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|011    2+^|rd           2+^|0101111 <|AMOXOR.D
 2+^|01100 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|011    2+^|rd           2+^|0101111 <|AMOAND.D
 2+^|01000 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|011    2+^|rd           2+^|0101111 <|AMOOR.D
 2+^|10000 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|011    2+^|rd           2+^|0101111 <|AMOMIN.D
 2+^|10100 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|011    2+^|rd           2+^|0101111 <|AMOMAX.D
 2+^|11000 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|011    2+^|rd           2+^|0101111 <|AMOMINU.D
 2+^|11100 ^|aq ^|rl 2+^|rs2  2+^|rs1   2+^|011    2+^|rd           2+^|0101111 <|AMOMAXU.D
|===
```

### src/priv/images/bytefield/priv-instr-set.edn

```text
[bytefield]
----
(defattrs :plain [:plain {:font-family "M+ 1p Fallback" :font-size 24}])
(def row-height 40)
(def row-header-fn nil)
(def boxes-per-row 32)

(draw-box "31" {:span 4 :text-anchor "start" :borders{}})
(draw-box "27" {:span 2 :text-anchor "start" :borders {}})
(draw-box "26" {:borders {}})
(draw-box "25" {:borders {}})
(draw-box "24" {:span 2 :text-anchor "start" :borders {}})
(draw-box "20" {:span 2 :text-anchor "end" :borders {}})
(draw-box "19" {:span 2 :text-anchor "start" :borders {}})
(draw-box "15" {:span 2 :text-anchor "end" :borders {}})
(draw-box "14" {:borders {}})
(draw-box nil {:borders {}})
(draw-box "12" {:borders {}})
(draw-box "11" {:span 2 :text-anchor "start" :borders {}})
(draw-box "7" {:span 2 :text-anchor "end" :borders {}})
(draw-box "6" {:span 2 :text-anchor "start" :borders {}})
(draw-box "0" {:span 2 :text-anchor "end" :borders {}})
(draw-box nil {:span 5 :borders {}})

(draw-box "funct7" {:span 8})
(draw-box "rs2" {:span 4})
(draw-box "rs1" {:span 4})
(draw-box "funct3" {:span 3})
(draw-box "rd" {:span 4})
(draw-box "opcode" {:span 4})
(draw-box "   R-type" {:span 5 :text-anchor "start" :borders {}})

(draw-box "imm[11:0]" {:span 12})
(draw-box "rs1" {:span 4})
(draw-box "funct3" {:span 3})
(draw-box "rd" {:span 4})
(draw-box "opcode" {:span 4})
(draw-box "   I-type" {:span 5 :text-anchor "start" :borders {}})

(draw-box nil {:span 32 :borders {}})
(draw-box (text "Trap-Return Instructions" {:font-weight "bold" :font-size 24}) {:span 27 :borders {}})
(draw-box nil {:span 5 :borders {}})

(draw-box "0001000" {:span 8})
(draw-box "00010" {:span 4})
(draw-box "00000" {:span 4})
(draw-box "000" {:span 3})
(draw-box "00000" {:span 4})
(draw-box "1110011" {:span 4})
(draw-box "   SRET" {:span 5 :text-anchor "start" :borders {}})

(draw-box "0011000" {:span 8})
(draw-box "00010" {:span 4})
(draw-box "00000" {:span 4})
(draw-box "000" {:span 3})
(draw-box "00000" {:span 4})
(draw-box "1110011" {:span 4})
(draw-box "   MRET" {:span 5 :text-anchor "start" :borders {}})

(draw-box "0111000" {:span 8})
(draw-box "00010" {:span 4})
(draw-box "00000" {:span 4})
(draw-box "000" {:span 3})
(draw-box "00000" {:span 4})
(draw-box "1110011" {:span 4})
(draw-box "   MNRET" {:span 5 :text-anchor "start" :borders {}})

(draw-box nil {:span 32 :borders {}})
(draw-box (text "Interrupt-Management Instructions" {:font-weight "bold" :font-size 24}) {:span 27 :borders {}})
(draw-box nil {:span 5 :borders {}})

(draw-box "0001000" {:span 8})
(draw-box "00101" {:span 4})
(draw-box "00000" {:span 4})
(draw-box "000" {:span 3})
(draw-box "00000" {:span 4})
(draw-box "1110011" {:span 4})
(draw-box "WFI" {:span 5 :text-anchor "start" :borders {}})

(draw-box nil {:span 32 :borders {}})
(draw-box (text "Control Transfer Records Management Instructions" {:font-weight "bold" :font-size 24}) {:span 27 :borders {}})
(draw-box nil {:span 5 :borders {}})

(draw-box "0001000" {:span 8})
(draw-box "00100" {:span 4})
(draw-box "00000" {:span 4})
(draw-box "000" {:span 3})
(draw-box "00000" {:span 4})
(draw-box "1110011" {:span 4})
(draw-box "SCTRCLR" {:span 5 :text-anchor "start" :borders {}})

(draw-box nil {:span 32 :borders {}})
(draw-box (text "Supervisor Memory-Management Instructions" {:font-weight "bold" :font-size 24}) {:span 27 :borders {}})
(draw-box nil {:span 5 :borders {}})

(draw-box "0001001" {:span 8})
(draw-box "rs2" {:span 4})
(draw-box "rs1" {:span 4})
(draw-box "000" {:span 3})
(draw-box "00000" {:span 4})
(draw-box "1110011" {:span 4})
(draw-box "SFENCE.VMA" {:span 5 :text-anchor "start" :borders {}})
```
