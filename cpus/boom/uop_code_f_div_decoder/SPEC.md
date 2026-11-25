# Implement `UOPCodeFDivDecoder`

Implement the complete `UOPCodeFDivDecoder` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class UOPCodeFDivDecoder` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
//******************************************************************************
// Copyright (c) 2016 - 2018, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE and LICENSE.SiFive for license details.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// FDiv/FSqrt Unit
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

package boom.exu

import chisel3._
import chisel3.util._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.tile.FPConstants._
import freechips.rocketchip.tile
import boom.common._
import boom.util._
import freechips.rocketchip.tile.HasFPUParameters
import freechips.rocketchip.util.uintToBitPat
```

## Class declaration

```scala
/**
 * Decoder for FPU divide and square root signals
 */
class UOPCodeFDivDecoder(implicit p: Parameters) extends BoomModule
  with HasFPUParameters
{
  val io = IO(new Bundle {
    val uopc = Input(Bits(UOPC_SZ.W))
    val sigs = Output(new tile.FPUCtrlSigs())
  })
```

## Parent instantiation

```scala
class FDivSqrtUnit(implicit p: Parameters)
  extends FunctionalUnit(
    isPipelined = false,
    numStages = 1,
    numBypassStages = 0,
    dataWidth = 65,
    needsFcsr = true)
  with tile.HasFPUParameters
{
  //--------------------------------------
  // buffer inputs and upconvert as needed

  // provide a one-entry queue to store incoming uops while waiting for the fdiv/fsqrt unit to become available.
  val r_buffer_val = RegInit(false.B)
  val r_buffer_req = Reg(new FuncUnitReq(dataWidth=65))
  val r_buffer_fin = Reg(new tile.FPInput)

  val fdiv_decoder = Module(new UOPCodeFDivDecoder)
  fdiv_decoder.io.uopc := io.req.bits.uop.uopc
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
```

### src/main/scala/common/consts.scala

```scala
  val uopFDIV_S    = 101.U(UOPC_SZ.W)
  val uopFDIV_D    = 102.U(UOPC_SZ.W)
  val uopFSQRT_S   = 103.U(UOPC_SZ.W)
  val uopFSQRT_D   = 104.U(UOPC_SZ.W)
```

## Documentation

### src/f-st-ext.adoc

```text
=== Single-Precision Floating-Point Computational Instructions

Floating-point arithmetic instructions with one or two source operands
use the R-type format with the OP-FP major opcode. FADD.S and FMUL.S
perform single-precision floating-point addition and multiplication
respectively, between _rs1_ and _rs2_. FSUB.S performs the
single-precision floating-point subtraction of _rs2_ from _rs1_. FDIV.S performs the single-precision floating-point division of _rs1_ by _rs2_. FSQRT.S computes the square root of _rs1_. In each case, the result is written to _rd_.
```

### src/d-st-ext.adoc

```text
=== Double-Precision Floating-Point Computational Instructions

The double-precision floating-point computational instructions are
defined analogously to their single-precision counterparts, but operate
on double-precision operands and produce double-precision results.
```
