# Implement `UOPCodeFPUDecoder`

Implement the complete `UOPCodeFPUDecoder` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class UOPCodeFPUDecoder` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
//******************************************************************************
// Copyright (c) 2015 - 2018, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE and LICENSE.SiFive for license details.
//------------------------------------------------------------------------------

package boom.exu

import chisel3._
import chisel3.util._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.tile.FPConstants._
import freechips.rocketchip.tile.{FPUCtrlSigs, HasFPUParameters}
import freechips.rocketchip.tile
import freechips.rocketchip.rocket
import freechips.rocketchip.util.uintToBitPat
import boom.common._
import boom.util.{ImmGenRm, ImmGenTyp}
```

## Class declaration

```scala
class UOPCodeFPUDecoder(implicit p: Parameters) extends BoomModule with HasFPUParameters
{
  val io = IO(new Bundle {
    val uopc = Input(Bits(UOPC_SZ.W))
    val sigs = Output(new FPUCtrlSigs())
  })
```

## Parent instantiation

### src/main/scala/exu/execution-units/fpu.scala

```scala
/**
 * FPU unit that wraps the RocketChip FPU units (which in turn wrap hardfloat)
 */
class FPU(implicit p: Parameters) extends BoomModule with tile.HasFPUParameters
{
  val io = IO(new Bundle {
    val req = Flipped(new ValidIO(new FpuReq))
    val resp = new ValidIO(new ExeUnitResp(65))
  })

  // all FP units are padded out to the same latency for easy scheduling of the write port
  val fpu_latency = dfmaLatency
  val io_req = io.req.bits

  val fp_decoder = Module(new UOPCodeFPUDecoder)
  fp_decoder.io.uopc := io_req.uop.uopc
  val fp_ctrl = fp_decoder.io.sigs
  val fp_rm = Mux(ImmGenRm(io_req.uop.imm_packed) === 7.U, io_req.fcsr_rm, ImmGenRm(io_req.uop.imm_packed))

  def fuInput(minT: Option[tile.FType]): tile.FPInput = {
    val req = Wire(new tile.FPInput)
    val tag = fp_ctrl.typeTagIn
    req <> fp_ctrl
    req.rm := fp_rm
    req.in1 := unbox(io_req.rs1_data, tag, minT)
    req.in2 := unbox(io_req.rs2_data, tag, minT)
    req.in3 := unbox(io_req.rs3_data, tag, minT)
    when (fp_ctrl.swap23) { req.in3 := req.in2 }
    req.typ := ImmGenTyp(io_req.uop.imm_packed)
    req.fmt := Mux(tag === S, 0.U, 1.U) // TODO support Zfh and avoid special-case below
    when (io_req.uop.uopc === uopFMV_X_S) {
      req.fmt := 0.U
    }

    val fma_decoder = Module(new FMADecoder)
    fma_decoder.io.uopc := io_req.uop.uopc
    req.fmaCmd := fma_decoder.io.cmd // ex_reg_inst(3,2) | (!fp_ctrl.ren3 && ex_reg_inst(27))
    req
  }

  val dfma = Module(new tile.FPUFMAPipe(latency = fpu_latency, t = tile.FType.D))
  dfma.io.in.valid := io.req.valid && fp_ctrl.fma && (fp_ctrl.typeTagOut === D)
  dfma.io.in.bits := fuInput(Some(dfma.t))

  val sfma = Module(new tile.FPUFMAPipe(latency = fpu_latency, t = tile.FType.S))
  sfma.io.in.valid := io.req.valid && fp_ctrl.fma && (fp_ctrl.typeTagOut === S)
  sfma.io.in.bits := fuInput(Some(sfma.t))

  val fpiu = Module(new tile.FPToInt)
  fpiu.io.in.valid := io.req.valid && (fp_ctrl.toint || (fp_ctrl.fastpipe && fp_ctrl.wflags))
  fpiu.io.in.bits := fuInput(None)
  val fpiu_out = Pipe(RegNext(fpiu.io.in.valid && !fp_ctrl.fastpipe),
                              fpiu.io.out.bits, fpu_latency-1)
  val fpiu_result  = Wire(new tile.FPResult)
  fpiu_result.data := fpiu_out.bits.toint
  fpiu_result.exc  := fpiu_out.bits.exc

  val fpmu = Module(new tile.FPToFP(fpu_latency)) // latency 2 for rocket
  fpmu.io.in.valid := io.req.valid && fp_ctrl.fastpipe
  fpmu.io.in.bits := fpiu.io.in.bits
  fpmu.io.lt := fpiu.io.out.bits.lt
  val fpmu_double = Pipe(io.req.valid && fp_ctrl.fastpipe, fp_ctrl.typeTagOut === D, fpu_latency).bits
```

### src/main/scala/exu/execution-units/functional-unit.scala

```scala
/**
 * Int to FP conversion functional unit
 *
 * @param latency the amount of stages to delay by
 */
class IntToFPUnit(latency: Int)(implicit p: Parameters)
  extends PipelinedFunctionalUnit(
    numStages = latency,
    numBypassStages = 0,
    earliestBypassStage = 0,
    dataWidth = 65,
    needsFcsr = true)
  with tile.HasFPUParameters
{
  val fp_decoder = Module(new UOPCodeFPUDecoder) // TODO use a simpler decoder
  val io_req = io.req.bits
  fp_decoder.io.uopc := io_req.uop.uopc
  val fp_ctrl = fp_decoder.io.sigs
  val fp_rm = Mux(ImmGenRm(io_req.uop.imm_packed) === 7.U, io.fcsr_rm, ImmGenRm(io_req.uop.imm_packed))
  val req = Wire(new tile.FPInput)
  val tag = fp_ctrl.typeTagIn

  req <> fp_ctrl

  req.rm := fp_rm
  req.in1 := unbox(io_req.rs1_data, tag, None)
  req.in2 := unbox(io_req.rs2_data, tag, None)
  req.in3 := DontCare
  req.typ := ImmGenTyp(io_req.uop.imm_packed)
  req.fmt := DontCare // FIXME: this may not be the right thing to do here
  req.fmaCmd := DontCare

  assert (!(io.req.valid && fp_ctrl.fromint && req.in1(xLen).asBool),
    "[func] IntToFP integer input has 65th high-order bit set!")

  assert (!(io.req.valid && !fp_ctrl.fromint),
    "[func] Only support fromInt micro-ops.")

  val ifpu = Module(new tile.IntToFP(intToFpLatency))
  ifpu.io.in.valid := io.req.valid
  ifpu.io.in.bits := req
  ifpu.io.in.bits.in1 := io_req.rs1_data
  val out_double = Pipe(io.req.valid, fp_ctrl.typeTagOut === D, intToFpLatency).bits
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/tile/FPU.scala

```scala
object FPConstants
{
  val RM_SZ = 3
  val FLAGS_SZ = 5
}

trait HasFPUCtrlSigs {
  val ldst = Bool()
  val wen = Bool()
  val ren1 = Bool()
  val ren2 = Bool()
  val ren3 = Bool()
  val swap12 = Bool()
  val swap23 = Bool()
  val typeTagIn = UInt(2.W)
  val typeTagOut = UInt(2.W)
  val fromint = Bool()
  val toint = Bool()
  val fastpipe = Bool()
  val fma = Bool()
  val div = Bool()
  val sqrt = Bool()
  val wflags = Bool()
}

class FPUCtrlSigs extends Bundle with HasFPUCtrlSigs

class FPUDecoder(implicit p: Parameters) extends FPUModule()(p) {
  val io = new Bundle {
    val inst = Bits(INPUT, 32)
    val sigs = new FPUCtrlSigs().asOutput
  }

  val default =       List(X,X,X,X,X,X,X,X,X,X,X,X,X,X,X,X)
  val h: Array[(BitPat, List[BitPat])] =
    Array(FLH      -> List(Y,Y,N,N,N,X,X,X,X,N,N,N,N,N,N,N),
          FSH      -> List(Y,N,N,Y,N,Y,X,I,H,N,Y,N,N,N,N,N),
          FMV_H_X  -> List(N,Y,N,N,N,X,X,H,I,Y,N,N,N,N,N,N),
          FCVT_H_W -> List(N,Y,N,N,N,X,X,H,H,Y,N,N,N,N,N,Y),
          FCVT_H_WU-> List(N,Y,N,N,N,X,X,H,H,Y,N,N,N,N,N,Y),
          FCVT_H_L -> List(N,Y,N,N,N,X,X,H,H,Y,N,N,N,N,N,Y),
          FCVT_H_LU-> List(N,Y,N,N,N,X,X,H,H,Y,N,N,N,N,N,Y),
          FMV_X_H  -> List(N,N,Y,N,N,N,X,I,H,N,Y,N,N,N,N,N),
          FCLASS_H -> List(N,N,Y,N,N,N,X,H,H,N,Y,N,N,N,N,N),
          FCVT_W_H -> List(N,N,Y,N,N,N,X,H,X,N,Y,N,N,N,N,Y),
          FCVT_WU_H-> List(N,N,Y,N,N,N,X,H,X,N,Y,N,N,N,N,Y),
          FCVT_L_H -> List(N,N,Y,N,N,N,X,H,X,N,Y,N,N,N,N,Y),
          FCVT_LU_H-> List(N,N,Y,N,N,N,X,H,X,N,Y,N,N,N,N,Y),
          FCVT_S_H -> List(N,Y,Y,N,N,N,X,H,S,N,N,Y,N,N,N,Y),
          FCVT_H_S -> List(N,Y,Y,N,N,N,X,S,H,N,N,Y,N,N,N,Y),
          FEQ_H    -> List(N,N,Y,Y,N,N,N,H,H,N,Y,N,N,N,N,Y),
          FLT_H    -> List(N,N,Y,Y,N,N,N,H,H,N,Y,N,N,N,N,Y),
          FLE_H    -> List(N,N,Y,Y,N,N,N,H,H,N,Y,N,N,N,N,Y),
          FSGNJ_H  -> List(N,Y,Y,Y,N,N,N,H,H,N,N,Y,N,N,N,N),
          FSGNJN_H -> List(N,Y,Y,Y,N,N,N,H,H,N,N,Y,N,N,N,N),
          FSGNJX_H -> List(N,Y,Y,Y,N,N,N,H,H,N,N,Y,N,N,N,N),
          FMIN_H   -> List(N,Y,Y,Y,N,N,N,H,H,N,N,Y,N,N,N,Y),
          FMAX_H   -> List(N,Y,Y,Y,N,N,N,H,H,N,N,Y,N,N,N,Y),
          FADD_H   -> List(N,Y,Y,Y,N,N,Y,H,H,N,N,N,Y,N,N,Y),
          FSUB_H   -> List(N,Y,Y,Y,N,N,Y,H,H,N,N,N,Y,N,N,Y),
          FMUL_H   -> List(N,Y,Y,Y,N,N,N,H,H,N,N,N,Y,N,N,Y),
          FMADD_H  -> List(N,Y,Y,Y,Y,N,N,H,H,N,N,N,Y,N,N,Y),
          FMSUB_H  -> List(N,Y,Y,Y,Y,N,N,H,H,N,N,N,Y,N,N,Y),
          FNMADD_H -> List(N,Y,Y,Y,Y,N,N,H,H,N,N,N,Y,N,N,Y),
          FNMSUB_H -> List(N,Y,Y,Y,Y,N,N,H,H,N,N,N,Y,N,N,Y),
          FDIV_H   -> List(N,Y,Y,Y,N,N,N,H,H,N,N,N,N,Y,N,Y),
          FSQRT_H  -> List(N,Y,Y,N,N,N,X,H,H,N,N,N,N,N,Y,Y))
  val f: Array[(BitPat, List[BitPat])] =
    Array(FLW      -> List(Y,Y,N,N,N,X,X,X,X,N,N,N,N,N,N,N),
          FSW      -> List(Y,N,N,Y,N,Y,X,I,S,N,Y,N,N,N,N,N),
          FMV_S_X  -> List(N,Y,N,N,N,X,X,S,I,Y,N,N,N,N,N,N),
          FCVT_S_W -> List(N,Y,N,N,N,X,X,S,S,Y,N,N,N,N,N,Y),
          FCVT_S_WU-> List(N,Y,N,N,N,X,X,S,S,Y,N,N,N,N,N,Y),
          FCVT_S_L -> List(N,Y,N,N,N,X,X,S,S,Y,N,N,N,N,N,Y),
          FCVT_S_LU-> List(N,Y,N,N,N,X,X,S,S,Y,N,N,N,N,N,Y),
          FMV_X_S  -> List(N,N,Y,N,N,N,X,I,S,N,Y,N,N,N,N,N),
          FCLASS_S -> List(N,N,Y,N,N,N,X,S,S,N,Y,N,N,N,N,N),
          FCVT_W_S -> List(N,N,Y,N,N,N,X,S,X,N,Y,N,N,N,N,Y),
          FCVT_WU_S-> List(N,N,Y,N,N,N,X,S,X,N,Y,N,N,N,N,Y),
          FCVT_L_S -> List(N,N,Y,N,N,N,X,S,X,N,Y,N,N,N,N,Y),
          FCVT_LU_S-> List(N,N,Y,N,N,N,X,S,X,N,Y,N,N,N,N,Y),
          FEQ_S    -> List(N,N,Y,Y,N,N,N,S,S,N,Y,N,N,N,N,Y),
          FLT_S    -> List(N,N,Y,Y,N,N,N,S,S,N,Y,N,N,N,N,Y),
          FLE_S    -> List(N,N,Y,Y,N,N,N,S,S,N,Y,N,N,N,N,Y),
          FSGNJ_S  -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,N),
          FSGNJN_S -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,N),
          FSGNJX_S -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,N),
          FMIN_S   -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,Y),
          FMAX_S   -> List(N,Y,Y,Y,N,N,N,S,S,N,N,Y,N,N,N,Y),
          FADD_S   -> List(N,Y,Y,Y,N,N,Y,S,S,N,N,N,Y,N,N,Y),
          FSUB_S   -> List(N,Y,Y,Y,N,N,Y,S,S,N,N,N,Y,N,N,Y),
          FMUL_S   -> List(N,Y,Y,Y,N,N,N,S,S,N,N,N,Y,N,N,Y),
          FMADD_S  -> List(N,Y,Y,Y,Y,N,N,S,S,N,N,N,Y,N,N,Y),
          FMSUB_S  -> List(N,Y,Y,Y,Y,N,N,S,S,N,N,N,Y,N,N,Y),
          FNMADD_S -> List(N,Y,Y,Y,Y,N,N,S,S,N,N,N,Y,N,N,Y),
          FNMSUB_S -> List(N,Y,Y,Y,Y,N,N,S,S,N,N,N,Y,N,N,Y),
          FDIV_S   -> List(N,Y,Y,Y,N,N,N,S,S,N,N,N,N,Y,N,Y),
          FSQRT_S  -> List(N,Y,Y,N,N,N,X,S,S,N,N,N,N,N,Y,Y))
  val d: Array[(BitPat, List[BitPat])] =
    Array(FLD      -> List(Y,Y,N,N,N,X,X,X,X,N,N,N,N,N,N,N),
          FSD      -> List(Y,N,N,Y,N,Y,X,I,D,N,Y,N,N,N,N,N),
          FMV_D_X  -> List(N,Y,N,N,N,X,X,D,I,Y,N,N,N,N,N,N),
          FCVT_D_W -> List(N,Y,N,N,N,X,X,D,D,Y,N,N,N,N,N,Y),
          FCVT_D_WU-> List(N,Y,N,N,N,X,X,D,D,Y,N,N,N,N,N,Y),
          FCVT_D_L -> List(N,Y,N,N,N,X,X,D,D,Y,N,N,N,N,N,Y),
          FCVT_D_LU-> List(N,Y,N,N,N,X,X,D,D,Y,N,N,N,N,N,Y),
          FMV_X_D  -> List(N,N,Y,N,N,N,X,I,D,N,Y,N,N,N,N,N),
          FCLASS_D -> List(N,N,Y,N,N,N,X,D,D,N,Y,N,N,N,N,N),
          FCVT_W_D -> List(N,N,Y,N,N,N,X,D,X,N,Y,N,N,N,N,Y),
          FCVT_WU_D-> List(N,N,Y,N,N,N,X,D,X,N,Y,N,N,N,N,Y),
          FCVT_L_D -> List(N,N,Y,N,N,N,X,D,X,N,Y,N,N,N,N,Y),
          FCVT_LU_D-> List(N,N,Y,N,N,N,X,D,X,N,Y,N,N,N,N,Y),
          FCVT_S_D -> List(N,Y,Y,N,N,N,X,D,S,N,N,Y,N,N,N,Y),
          FCVT_D_S -> List(N,Y,Y,N,N,N,X,S,D,N,N,Y,N,N,N,Y),
          FEQ_D    -> List(N,N,Y,Y,N,N,N,D,D,N,Y,N,N,N,N,Y),
          FLT_D    -> List(N,N,Y,Y,N,N,N,D,D,N,Y,N,N,N,N,Y),
          FLE_D    -> List(N,N,Y,Y,N,N,N,D,D,N,Y,N,N,N,N,Y),
          FSGNJ_D  -> List(N,Y,Y,Y,N,N,N,D,D,N,N,Y,N,N,N,N),
          FSGNJN_D -> List(N,Y,Y,Y,N,N,N,D,D,N,N,Y,N,N,N,N),
          FSGNJX_D -> List(N,Y,Y,Y,N,N,N,D,D,N,N,Y,N,N,N,N),
          FMIN_D   -> List(N,Y,Y,Y,N,N,N,D,D,N,N,Y,N,N,N,Y),
          FMAX_D   -> List(N,Y,Y,Y,N,N,N,D,D,N,N,Y,N,N,N,Y),
          FADD_D   -> List(N,Y,Y,Y,N,N,Y,D,D,N,N,N,Y,N,N,Y),
          FSUB_D   -> List(N,Y,Y,Y,N,N,Y,D,D,N,N,N,Y,N,N,Y),
          FMUL_D   -> List(N,Y,Y,Y,N,N,N,D,D,N,N,N,Y,N,N,Y),
          FMADD_D  -> List(N,Y,Y,Y,Y,N,N,D,D,N,N,N,Y,N,N,Y),
          FMSUB_D  -> List(N,Y,Y,Y,Y,N,N,D,D,N,N,N,Y,N,N,Y),
          FNMADD_D -> List(N,Y,Y,Y,Y,N,N,D,D,N,N,N,Y,N,N,Y),
          FNMSUB_D -> List(N,Y,Y,Y,Y,N,N,D,D,N,N,N,Y,N,N,Y),
          FDIV_D   -> List(N,Y,Y,Y,N,N,N,D,D,N,N,N,N,Y,N,Y),
          FSQRT_D  -> List(N,Y,Y,N,N,N,X,D,D,N,N,N,N,N,Y,Y))
  val fcvt_hd: Array[(BitPat, List[BitPat])] =
    Array(FCVT_H_D -> List(N,Y,Y,N,N,N,X,D,H,N,N,Y,N,N,N,Y),
          FCVT_D_H -> List(N,Y,Y,N,N,N,X,H,D,N,N,Y,N,N,N,Y))

  val insns = (minFLen, fLen) match {
    case (32, 32) => f
    case (16, 32) => h ++ f
    case (32, 64) => f ++ d
    case (16, 64) => h ++ f ++ d ++ fcvt_hd

    case other => throw new Exception(s"minFLen = ${minFLen} & fLen = ${fLen} is an unsupported configuration")
  }
  val decoder = DecodeLogic(io.inst, default, insns)
  val s = io.sigs
  val sigs = Seq(s.ldst, s.wen, s.ren1, s.ren2, s.ren3, s.swap12,
                 s.swap23, s.typeTagIn, s.typeTagOut, s.fromint, s.toint,
                 s.fastpipe, s.fma, s.div, s.sqrt, s.wflags)
  sigs zip decoder map {case(s,d) => s := d}
}
// ...
trait HasFPUParameters {
// ...
  def typeTag(t: FType) = floatTypes.indexOf(t)
  def typeTagWbOffset = UInt(FType.all.indexOf(minType) + 1)
  def typeTagGroup(t: FType) = UInt(if (floatTypes.contains(t)) typeTag(t) else typeTag(maxType))
  // typeTag
  def H = typeTagGroup(FType.H)
  def S = typeTagGroup(FType.S)
  def D = typeTagGroup(FType.D)
  def I = UInt(typeTag(maxType))
```

### src/main/scala/rocket/Decode.scala

```scala
package freechips.rocketchip.rocket
// ...
object DecodeLogic
// ...
  def apply(addr: UInt, default: Seq[BitPat], mappingIn: Iterable[(BitPat, Seq[BitPat])]): Seq[UInt] = {
```

### src/main/scala/common/consts.scala

```scala
  val uopFMV_S_X   =  68.U(UOPC_SZ.W)
  val uopFMV_D_X   =  69.U(UOPC_SZ.W)
  val uopFMV_X_S   =  70.U(UOPC_SZ.W)
  val uopFMV_X_D   =  71.U(UOPC_SZ.W)

  val uopFSGNJ_S   =  72.U(UOPC_SZ.W)
  val uopFSGNJ_D   =  73.U(UOPC_SZ.W)

  val uopFCVT_S_D  =  74.U(UOPC_SZ.W)
  val uopFCVT_D_S  =  75.U(UOPC_SZ.W)

  val uopFCVT_S_X  =  76.U(UOPC_SZ.W)
  val uopFCVT_D_X  =  77.U(UOPC_SZ.W)

  val uopFCVT_X_S  =  78.U(UOPC_SZ.W)
  val uopFCVT_X_D  =  79.U(UOPC_SZ.W)

  val uopCMPR_S    =  80.U(UOPC_SZ.W)
  val uopCMPR_D    =  81.U(UOPC_SZ.W)

  val uopFCLASS_S  =  82.U(UOPC_SZ.W)
  val uopFCLASS_D  =  83.U(UOPC_SZ.W)

  val uopFMINMAX_S =  84.U(UOPC_SZ.W)
  val uopFMINMAX_D =  85.U(UOPC_SZ.W)

  //               =  86.U(UOPC_SZ.W)
  val uopFADD_S    =  87.U(UOPC_SZ.W)
  val uopFSUB_S    =  88.U(UOPC_SZ.W)
  val uopFMUL_S    =  89.U(UOPC_SZ.W)
  val uopFADD_D    =  90.U(UOPC_SZ.W)
  val uopFSUB_D    =  91.U(UOPC_SZ.W)
  val uopFMUL_D    =  92.U(UOPC_SZ.W)

  val uopFMADD_S   =  93.U(UOPC_SZ.W)
  val uopFMSUB_S   =  94.U(UOPC_SZ.W)
  val uopFNMADD_S  =  95.U(UOPC_SZ.W)
  val uopFNMSUB_S  =  96.U(UOPC_SZ.W)
  val uopFMADD_D   =  97.U(UOPC_SZ.W)
  val uopFMSUB_D   =  98.U(UOPC_SZ.W)
  val uopFNMADD_D  =  99.U(UOPC_SZ.W)
  val uopFNMSUB_D  = 100.U(UOPC_SZ.W)

  val uopFDIV_S    = 101.U(UOPC_SZ.W)
  val uopFDIV_D    = 102.U(UOPC_SZ.W)
  val uopFSQRT_S   = 103.U(UOPC_SZ.W)
  val uopFSQRT_D   = 104.U(UOPC_SZ.W)
```

## Documentation

### docs/sections/reg-file-bypass-network.rst

```text
BOOM uses the Berkeley hardfloat floating point units which use an
internal 65-bit operand format
(https://github.com/ucb-bar/berkeley-hardfloat). Therefore, all physical
floating point registers are 65-bits.
```
