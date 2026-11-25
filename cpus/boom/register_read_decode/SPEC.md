# Implement `RegisterReadDecode`

Implement the complete `RegisterReadDecode` module. Preserve its class declaration and public interface shown below. Return only the complete `class RegisterReadDecode` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
//******************************************************************************
// Copyright (c) 2015 - 2018, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE and LICENSE.SiFive for license details.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// Functional Unit Decode
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//
// Generate the functional unit control signals from the micro-op opcodes.

package boom.exu

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.rocket.ALU._
import freechips.rocketchip.util.uintToBitPat
import freechips.rocketchip.rocket.CSR

import boom.common._
```

## Class declaration

```scala
/**
 * Register read decoder
 *
 * @param supportedUnits indicate what functional units are being used
 */
class RegisterReadDecode(supportedUnits: SupportedFuncUnits)(implicit p: Parameters) extends BoomModule
  with freechips.rocketchip.rocket.constants.MemoryOpConstants
{
  val io = IO(new BoomBundle {
    val iss_valid = Input(Bool())
    val iss_uop   = Input(new MicroOp())

    val rrd_valid = Output(Bool())
    val rrd_uop   = Output(new MicroOp())
  })
```

## Parent instantiation

### `src/main/scala/exu/register-read/register-read.scala`

```scala
  //-------------------------------------------------------------
  // hook up inputs

  for (w <- 0 until issueWidth) {
    val rrd_decode_unit = Module(new RegisterReadDecode(supportedUnitsArray(w)))
    rrd_decode_unit.io.iss_valid := io.iss_valids(w)
    rrd_decode_unit.io.iss_uop   := io.iss_uops(w)

    rrd_valids(w) := RegNext(rrd_decode_unit.io.rrd_valid &&
                !IsKilledByBranch(io.brupdate, rrd_decode_unit.io.rrd_uop))
    rrd_uops(w)   := RegNext(GetNewUopAndBrMask(rrd_decode_unit.io.rrd_uop, io.brupdate))
  }
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/exu/register-read/func-unit-decode.scala`

```scala
/**
 * Control signal bundle for register renaming
 */
class RRdCtrlSigs(implicit p: Parameters) extends BoomBundle
{
  val br_type          = UInt(BR_N.getWidth.W)
  val use_alupipe      = Bool()
  val use_muldivpipe   = Bool()
  val use_mempipe      = Bool()
  val op_fcn      = Bits(SZ_ALU_FN.W)
  val fcn_dw      = Bool()
  val op1_sel     = UInt(OP1_X.getWidth.W)
  val op2_sel     = UInt(OP2_X.getWidth.W)
  val imm_sel     = UInt(IS_X.getWidth.W)
  val rf_wen      = Bool()
  val csr_cmd     = Bits(CSR.SZ.W)

  def decode(uopc: UInt, table: Iterable[(BitPat, List[BitPat])]) = {
    val decoder = freechips.rocketchip.rocket.DecodeLogic(uopc, AluRRdDecode.default, table)
    val sigs = Seq(br_type, use_alupipe, use_muldivpipe, use_mempipe, op_fcn,
                   fcn_dw, op1_sel, op2_sel, imm_sel, rf_wen, csr_cmd)
    sigs zip decoder map {case(s,d) => s := d}
    this
  }
}

/**
 * Default register read constants
 */
abstract trait RRdDecodeConstants
{
  val default: List[BitPat] =
               List[BitPat](BR_N , Y, N, N, FN_ADD , DW_X  , OP1_X   , OP2_X   , IS_X, REN_0, CSR.N)
  val table: Array[(BitPat, List[BitPat])]
}

/**
 * ALU register read constants
 */
object AluRRdDecode extends RRdDecodeConstants
{
  val table: Array[(BitPat, List[BitPat])] =
             Array[(BitPat, List[BitPat])](
                              // br type
                               // |      use alu pipe              op1 sel   op2 sel
                               // |      |  use muldiv pipe        |         |         immsel       csr_cmd
                               // |      |  |  use mem pipe        |         |         |     rf wen |
                               // |      |  |  |  alu fcn  wd/word?|         |         |     |      |
                               // |      |  |  |  |        |       |         |         |     |      |
         BitPat(uopLUI)   -> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_ZERO, OP2_IMM , IS_U, REN_1, CSR.N),

         BitPat(uopADDI)  -> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopANDI)  -> List(BR_N , Y, N, N, FN_AND , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopORI)   -> List(BR_N , Y, N, N, FN_OR  , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopXORI)  -> List(BR_N , Y, N, N, FN_XOR , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSLTI)  -> List(BR_N , Y, N, N, FN_SLT , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSLTIU) -> List(BR_N , Y, N, N, FN_SLTU, DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSLLI)  -> List(BR_N , Y, N, N, FN_SL  , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSRAI)  -> List(BR_N , Y, N, N, FN_SRA , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSRLI)  -> List(BR_N , Y, N, N, FN_SR  , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),

         BitPat(uopADDIW) -> List(BR_N , Y, N, N, FN_ADD , DW_32 , OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSLLIW) -> List(BR_N , Y, N, N, FN_SL  , DW_32 , OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSRAIW) -> List(BR_N , Y, N, N, FN_SRA , DW_32 , OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),
         BitPat(uopSRLIW) -> List(BR_N , Y, N, N, FN_SR  , DW_32 , OP1_RS1 , OP2_IMM , IS_I, REN_1, CSR.N),

         BitPat(uopADD)   -> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSLL)   -> List(BR_N , Y, N, N, FN_SL  , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSUB)   -> List(BR_N , Y, N, N, FN_SUB , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSLT)   -> List(BR_N , Y, N, N, FN_SLT , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSLTU)  -> List(BR_N , Y, N, N, FN_SLTU, DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopAND)   -> List(BR_N , Y, N, N, FN_AND , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopOR)    -> List(BR_N , Y, N, N, FN_OR  , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopXOR)   -> List(BR_N , Y, N, N, FN_XOR , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSRA)   -> List(BR_N , Y, N, N, FN_SRA , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSRL)   -> List(BR_N , Y, N, N, FN_SR  , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),

         BitPat(uopADDW)  -> List(BR_N , Y, N, N, FN_ADD , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSUBW)  -> List(BR_N , Y, N, N, FN_SUB , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSLLW)  -> List(BR_N , Y, N, N, FN_SL  , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSRAW)  -> List(BR_N , Y, N, N, FN_SRA , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopSRLW)  -> List(BR_N , Y, N, N, FN_SR  , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),

         BitPat(uopBEQ)   -> List(BR_EQ ,Y, N, N, FN_SUB , DW_XPR, OP1_X   , OP2_X   , IS_B, REN_0, CSR.N),
         BitPat(uopBNE)   -> List(BR_NE ,Y, N, N, FN_SUB , DW_XPR, OP1_X   , OP2_X   , IS_B, REN_0, CSR.N),
         BitPat(uopBGE)   -> List(BR_GE ,Y, N, N, FN_SLT , DW_XPR, OP1_X   , OP2_X   , IS_B, REN_0, CSR.N),
         BitPat(uopBGEU)  -> List(BR_GEU,Y, N, N, FN_SLTU, DW_XPR, OP1_X   , OP2_X   , IS_B, REN_0, CSR.N),
         BitPat(uopBLT)   -> List(BR_LT ,Y, N, N, FN_SLT , DW_XPR, OP1_X   , OP2_X   , IS_B, REN_0, CSR.N),
         BitPat(uopBLTU)  -> List(BR_LTU,Y, N, N, FN_SLTU, DW_XPR, OP1_X   , OP2_X   , IS_B, REN_0, CSR.N))
}

object JmpRRdDecode extends RRdDecodeConstants
{
  val table: Array[(BitPat, List[BitPat])] =
             Array[(BitPat, List[BitPat])](
                               // br type
                               // |      use alu pipe              op1 sel   op2 sel
                               // |      |  use muldiv pipe        |         |         immsel       csr_cmd
                               // |      |  |  use mem pipe        |         |         |     rf wen |
                               // |      |  |  |  alu fcn  wd/word?|         |         |     |      |
                               // |      |  |  |  |        |       |         |         |     |      |
         BitPat(uopJAL)   -> List(BR_J , Y, N, N, FN_ADD , DW_XPR, OP1_PC  , OP2_NEXT, IS_J, REN_1, CSR.N),
         BitPat(uopJALR)  -> List(BR_JR, Y, N, N, FN_ADD , DW_XPR, OP1_PC  , OP2_NEXT, IS_I, REN_1, CSR.N),
         BitPat(uopAUIPC) -> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_PC  , OP2_IMM , IS_U, REN_1, CSR.N))
}

/**
 * Multiply divider register read constants
 */
object MulDivRRdDecode extends RRdDecodeConstants
{
  val table: Array[(BitPat, List[BitPat])] =
             Array[(BitPat, List[BitPat])](
                               // br type
                               // |      use alu pipe              op1 sel   op2 sel
                               // |      |  use muldiv pipe        |         |         immsel       csr_cmd
                               // |      |  |  use mem pipe        |         |         |     rf wen |
                               // |      |  |  |  alu fcn  wd/word?|         |         |     |      |
                               // |      |  |  |  |        |       |         |         |     |      |
         BitPat(uopMUL)   -> List(BR_N , N, Y, N, FN_MUL,   DW_XPR,OP1_RS1 , OP2_RS2 , IS_X,  REN_1,CSR.N),
         BitPat(uopMULH)  -> List(BR_N , N, Y, N, FN_MULH,  DW_XPR,OP1_RS1 , OP2_RS2 , IS_X,  REN_1,CSR.N),
         BitPat(uopMULHU) -> List(BR_N , N, Y, N, FN_MULHU, DW_XPR,OP1_RS1 , OP2_RS2 , IS_X,  REN_1,CSR.N),
         BitPat(uopMULHSU)-> List(BR_N , N, Y, N, FN_MULHSU,DW_XPR,OP1_RS1 , OP2_RS2 , IS_X,  REN_1,CSR.N),
         BitPat(uopMULW)  -> List(BR_N , N, Y, N, FN_MUL,   DW_32 ,OP1_RS1 , OP2_RS2 , IS_X,  REN_1,CSR.N),

         BitPat(uopDIV)   -> List(BR_N , N, Y, N, FN_DIV , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopDIVU)  -> List(BR_N , N, Y, N, FN_DIVU, DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopREM)   -> List(BR_N , N, Y, N, FN_REM , DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopREMU)  -> List(BR_N , N, Y, N, FN_REMU, DW_XPR, OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopDIVW)  -> List(BR_N , N, Y, N, FN_DIV , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopDIVUW) -> List(BR_N , N, Y, N, FN_DIVU, DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopREMW)  -> List(BR_N , N, Y, N, FN_REM , DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N),
         BitPat(uopREMUW) -> List(BR_N , N, Y, N, FN_REMU, DW_32 , OP1_RS1 , OP2_RS2 , IS_X, REN_1, CSR.N))
}

/**
 * Memory unit register read constants
 */
object MemRRdDecode extends RRdDecodeConstants
{
  val table: Array[(BitPat, List[BitPat])] =
             Array[(BitPat, List[BitPat])](
                               // br type
                               // |      use alu pipe              op1 sel   op2 sel
                               // |      |  use muldiv pipe        |         |         immsel       csr_cmd
                               // |      |  |  use mem pipe        |         |         |     rf wen |
                               // |      |  |  |  alu fcn  wd/word?|         |         |     |      |
                               // |      |  |  |  |        |       |         |         |     |      |
         BitPat(uopLD)    -> List(BR_N , N, N, Y, FN_ADD , DW_XPR, OP1_RS1 , OP2_IMM , IS_I, REN_0, CSR.N),
         BitPat(uopSTA)   -> List(BR_N , N, N, Y, FN_ADD , DW_XPR, OP1_RS1 , OP2_IMM , IS_S, REN_0, CSR.N),
         BitPat(uopSTD)   -> List(BR_N , N, N, Y, FN_X   , DW_X  , OP1_RS1 , OP2_RS2 , IS_X, REN_0, CSR.N),
         BitPat(uopSFENCE)-> List(BR_N , N, N, Y, FN_X   , DW_X  , OP1_RS1 , OP2_RS2 , IS_X, REN_0, CSR.N),

         BitPat(uopAMO_AG)-> List(BR_N , N, N, Y, FN_ADD , DW_XPR, OP1_RS1 , OP2_ZERO, IS_X, REN_0, CSR.N))
}

/**
 * CSR register read constants
 */
object CsrRRdDecode extends RRdDecodeConstants
{
  val table: Array[(BitPat, List[BitPat])] =
             Array[(BitPat, List[BitPat])](
                               // br type
                               // |      use alu pipe              op1 sel   op2 sel
                               // |      |  use muldiv pipe        |         |         immsel       csr_cmd
                               // |      |  |  use mem pipe        |         |         |     rf wen |
                               // |      |  |  |  alu fcn  wd/word?|         |         |     |      |
                               // |      |  |  |  |        |       |         |         |     |      |
         BitPat(uopCSRRW) -> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_RS1 , OP2_ZERO, IS_I, REN_1, CSR.W),
         BitPat(uopCSRRS) -> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_RS1 , OP2_ZERO, IS_I, REN_1, CSR.S),
         BitPat(uopCSRRC) -> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_RS1 , OP2_ZERO, IS_I, REN_1, CSR.C),

         BitPat(uopCSRRWI)-> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_ZERO, OP2_IMMC, IS_I, REN_1, CSR.W),
         BitPat(uopCSRRSI)-> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_ZERO, OP2_IMMC, IS_I, REN_1, CSR.S),
         BitPat(uopCSRRCI)-> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_ZERO, OP2_IMMC, IS_I, REN_1, CSR.C),

         BitPat(uopWFI)   -> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_ZERO, OP2_IMMC, IS_I, REN_0, CSR.I),
         BitPat(uopERET)  -> List(BR_N , Y, N, N, FN_ADD , DW_XPR, OP1_ZERO, OP2_IMMC, IS_I, REN_0, CSR.I))
}

/**
 * FPU register read constants
 */
object FpuRRdDecode extends RRdDecodeConstants
{
  val table: Array[(BitPat, List[BitPat])] =
             Array[(BitPat, List[BitPat])](
                               // br type
                               // |      use alu pipe              op1 sel   op2 sel
                               // |      |  use muldiv pipe        |         |         immsel       csr_cmd
                               // |      |  |  use mem pipe        |         |         |     rf wen |
                               // |      |  |  |  alu fcn  wd/word?|         |         |     |      |
                               // |      |  |  |  |        |       |         |         |     |      |
         BitPat(uopFCLASS_S)->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFCLASS_D)->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),

//         BitPat(uopFMV_S_X)->List(BR_N , Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
//         BitPat(uopFMV_D_X)->List(BR_N , Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFMV_X_S)->List(BR_N , Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFMV_X_D)->List(BR_N , Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFSGNJ_S)->List(BR_N , Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFSGNJ_D)->List(BR_N , Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),

         BitPat(uopFCVT_S_D) ->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFCVT_D_S) ->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),

// TODO comment out I2F instructions.
         BitPat(uopFCVT_S_X) ->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFCVT_D_X) ->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),

         BitPat(uopFCVT_X_S) ->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFCVT_X_D) ->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),

         BitPat(uopCMPR_S)   ->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopCMPR_D)   ->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),

         BitPat(uopFMINMAX_S)->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFMINMAX_D)->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),

         BitPat(uopFADD_S)  ->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFSUB_S)  ->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFMUL_S)  ->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFADD_D)  ->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFSUB_D)  ->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFMUL_D)  ->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),

         BitPat(uopFMADD_S) ->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFMSUB_S) ->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFNMADD_S)->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFNMSUB_S)->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFMADD_D) ->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFMSUB_D) ->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFNMADD_D)->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFNMSUB_D)->List(BR_N, Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N))
}

/**
 * Fused multiple add register read constants
 */
object IfmvRRdDecode extends RRdDecodeConstants
{
  val table: Array[(BitPat, List[BitPat])] =
             Array[(BitPat, List[BitPat])](
                               // br type
                               // |      use alu pipe              op1 sel   op2 sel
                               // |      |  use muldiv pipe        |         |         immsel       csr_cmd
                               // |      |  |  use mem pipe        |         |         |     rf wen |
                               // |      |  |  |  alu fcn  wd/word?|         |         |     |      |
                               // |      |  |  |  |        |       |         |         |     |      |
         BitPat(uopFMV_S_X)->List(BR_N , Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFMV_D_X)->List(BR_N , Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),

         BitPat(uopFCVT_S_X) ->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFCVT_D_X) ->List(BR_N,Y, N, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N))
}

/**
 * Floating point divide and square root register read constants
 */
object FDivRRdDecode extends RRdDecodeConstants
{
  val table: Array[(BitPat, List[BitPat])] =
             Array[(BitPat, List[BitPat])](
                               // br type
                               // |      use alu pipe              op1 sel   op2 sel
                               // |      |  use muldiv pipe        |         |         immsel       csr_cmd
                               // |      |  |  use mem pipe        |         |         |     rf wen |
                               // |      |  |  |  alu fcn  wd/word?|         |         |     |      |
                               // |      |  |  |  |        |       |         |         |     |      |
         BitPat(uopFDIV_S)  ->List(BR_N, N, Y, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFDIV_D)  ->List(BR_N, N, Y, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFSQRT_S) ->List(BR_N, N, Y, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N),
         BitPat(uopFSQRT_D) ->List(BR_N, N, Y, N, FN_X   , DW_X  , OP1_X   , OP2_X   , IS_X, REN_1, CSR.N))
}

```

### `src/main/scala/exu/execution-units/functional-unit.scala`

```scala
/**
 * Class to tell the FUDecoders what units it needs to support
 *
 * @param alu support alu unit?
 * @param bru support br unit?
 * @param mem support mem unit?
 * @param muld support multiple div unit?
 * @param fpu support FP unit?
 * @param csr support csr writing unit?
 * @param fdiv support FP div unit?
 * @param ifpu support int to FP unit?
 */
class SupportedFuncUnits(
  val alu: Boolean  = false,
  val jmp: Boolean  = false,
  val mem: Boolean  = false,
  val muld: Boolean = false,
  val fpu: Boolean  = false,
  val csr: Boolean  = false,
  val fdiv: Boolean = false,
  val ifpu: Boolean = false)
{
}
```

### `src/main/scala/common/micro-op.scala`

```scala
/**
 * MicroOp passing through the pipeline
 */
class MicroOp(implicit p: Parameters) extends BoomBundle
  with freechips.rocketchip.rocket.constants.MemoryOpConstants
  with freechips.rocketchip.rocket.constants.ScalarOpConstants
{
  val uopc             = UInt(UOPC_SZ.W)       // micro-op code
  val inst             = UInt(32.W)
  val debug_inst       = UInt(32.W)
  val is_rvc           = Bool()
  val debug_pc         = UInt(coreMaxAddrBits.W)
  val iq_type          = UInt(IQT_SZ.W)        // which issue unit do we use?
  val fu_code          = UInt(FUConstants.FUC_SZ.W) // which functional unit do we use?
  val ctrl             = new CtrlSignals
// ...
  val imm_packed       = UInt(LONGEST_IMM_SZ.W) // densely pack the imm in decode...
                                              // then translate and sign-extend in execute
// ...
  val prs1             = UInt(maxPregSz.W)
// ...
  val mem_cmd          = UInt(M_SZ.W)          // sync primitives/cache flushes
// ...
  val lrs2_rtype       = UInt(2.W)
// ...
/**
 * Control signals within a MicroOp
 *
 * TODO REFACTOR this, as this should no longer be true, as bypass occurs in stage before branch resolution
 */
class CtrlSignals extends Bundle()
{
  val br_type     = UInt(BR_N.getWidth.W)
  val op1_sel     = UInt(OP1_X.getWidth.W)
  val op2_sel     = UInt(OP2_X.getWidth.W)
  val imm_sel     = UInt(IS_X.getWidth.W)
  val op_fcn      = UInt(freechips.rocketchip.rocket.ALU.SZ_ALU_FN.W)
  val fcn_dw      = Bool()
  val csr_cmd     = UInt(freechips.rocketchip.rocket.CSR.SZ.W)
  val is_load     = Bool()   // will invoke TLB address lookup
  val is_sta      = Bool()   // will invoke TLB address lookup
  val is_std      = Bool()
}
```

### `src/main/scala/rocket/CSR.scala`

```scala
object CSR
{
  // commands
  val SZ = 3
  def X = BitPat.dontCare(SZ)
  def N = UInt(0,SZ)
  def R = UInt(2,SZ)
  def I = UInt(4,SZ)
  def W = UInt(5,SZ)
  def S = UInt(6,SZ)
  def C = UInt(7,SZ)
```

## Related source code

### `src/main/scala/exu/decode.scala`

```scala
  AMOADD_W-> List(Y, N, X, uopAMO_AG, IQT_MEM, FU_MEM, RT_FIX, RT_FIX, RT_FIX, N, IS_X, N, Y, Y, N, N, M_XA_ADD, 0.U,N, N, N, Y, Y, CSR.N), // TODO make AMOs higherperformance
// ...
  LR_W    -> List(Y, N, X, uopLD    , IQT_MEM, FU_MEM, RT_FIX, RT_FIX, RT_X  , N, IS_X, Y, N, N, N, N, M_XLR   , 0.U,N, N, N, Y, Y, CSR.N),
  LR_D    -> List(Y, N, X, uopLD    , IQT_MEM, FU_MEM, RT_FIX, RT_FIX, RT_X  , N, IS_X, Y, N, N, N, N, M_XLR   , 0.U,N, N, N, Y, Y, CSR.N),
// ...
  // repackage the immediate, and then pass the fewest number of bits around
  val di24_20 = Mux(cs.imm_sel === IS_B || cs.imm_sel === IS_S, inst(11,7), inst(24,20))
  uop.imm_packed := Cat(inst(31,25), di24_20, inst(19,12))
```

### `src/main/scala/exu/execution-units/functional-unit.scala`

```scala
  // perform address calculation
  val sum = (io.req.bits.rs1_data.asSInt + io.req.bits.uop.imm_packed(19,8).asSInt).asUInt
```

### `src/main/scala/exu/rename/rename-maptable.scala`

```scala
  // Figure out the new mappings seen by each pipeline slot.
  for (i <- 0 until numLregs) {
    if (i == 0 && !float) {
      for (j <- 0 until plWidth+1) {
        remap_table(j)(i) := 0.U
      }
    } else {
```

### `src/main/scala/exu/issue-units/issue-unit.scala`

```scala
      // For StoreAddrGen for Int, or AMOAddrGen, we go to addr gen state
      when ((io.dis_uops(w).bits.uopc === uopSTA && io.dis_uops(w).bits.lrs2_rtype === RT_FIX) ||
             io.dis_uops(w).bits.uopc === uopAMO_AG) {
        dis_uops(w).iw_state := s_valid_2
        // For store addr gen for FP, rs2 is the FP register, and we don't wait for that here
      } .elsewhen (io.dis_uops(w).bits.uopc === uopSTA && io.dis_uops(w).bits.lrs2_rtype =/= RT_FIX) {
        dis_uops(w).lrs2_rtype := RT_X
        dis_uops(w).prs2_busy  := false.B
      }
```

### `src/main/scala/exu/issue-units/issue-slot.scala`

```scala
  when (state === s_valid_2) {
    when (p1 && p2 && ppred) {
      ; // send out the entire instruction as one uop
    } .elsewhen (p1 && ppred) {
      io.uop.uopc := slot_uop.uopc
      io.uop.lrs2_rtype := RT_X
    } .elsewhen (p2 && ppred) {
      io.uop.uopc := uopSTD
      io.uop.lrs1_rtype := RT_X
    }
  }
```

### `src/main/scala/lsu/lsu.scala`

```scala
  // Can we fire an incoming store addrgen + store datagen
  val can_fire_stad_incoming = widthMap(w => exe_req(w).valid && exe_req(w).bits.uop.ctrl.is_sta
                                                              && exe_req(w).bits.uop.ctrl.is_std)

  // Can we fire an incoming store addrgen
  val can_fire_sta_incoming  = widthMap(w => exe_req(w).valid && exe_req(w).bits.uop.ctrl.is_sta
                                                              && !exe_req(w).bits.uop.ctrl.is_std)

  // Can we fire an incoming store datagen
  val can_fire_std_incoming  = widthMap(w => exe_req(w).valid && exe_req(w).bits.uop.ctrl.is_std
                                                              && !exe_req(w).bits.uop.ctrl.is_sta)
```

## Documentation

### `src/a-st-ext.adoc`

```text
Complex atomic memory operations on a single memory word or doubleword
are performed with the load-reserved (LR) and store-conditional (SC)
instructions. LR.W loads a word from the address in _rs1_, places the
sign-extended value in _rd_, and registers a _reservation set_—a set of
bytes that subsumes the bytes in the addressed word. SC.W conditionally
writes a word in _rs2_ to the address in _rs1_: the SC.W succeeds only
if the reservation is still valid and the reservation set contains the
bytes being written. If the SC.W succeeds, the instruction writes the
word in _rs2_ to memory, and it writes zero to _rd_. If the SC.W fails,
the instruction does not write to memory, and it writes a nonzero value
to _rd_.  For the purposes of memory protection, a failed SC.W may be
treated like a store.  Regardless of success or failure, executing an
SC.W instruction invalidates any reservation held by this hart. LR.D and
SC.D act analogously on doublewords and are only available on RV64. For
RV64, LR.W and SC.W sign-extend the value placed in _rd_.
...
The atomic memory operation (AMO) instructions perform read-modify-write
operations for multiprocessor synchronization and are encoded with an
R-type instruction format. These AMO instructions atomically load a data
value from the address in _rs1_, place the value into register _rd_,
apply a binary operator to the loaded value and the original value in
_rs2_, then store the result back to the original address in _rs1_. AMOs
can either operate on _doublewords_ (RV64 only) or _words_ in memory. For
RV64, 32-bit AMOs always sign-extend the value placed in _rd_, and
ignore the upper 32 bits of the original value of _rs2_.
```

### `src/zicsr.adoc`

```text
For both CSRRS and CSRRC, if _rs1_=`x0`, then the instruction will not
write to the CSR at all, and so shall not cause any of the side effects
that might otherwise occur on a CSR write, nor raise illegal-instruction
exceptions on accesses to read-only CSRs. Both CSRRS and CSRRC always
read the addressed CSR and cause any read side effects regardless of
_rs1_ and _rd_ fields.
```
