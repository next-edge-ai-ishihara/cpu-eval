# Implement `FMADecoder`

Implement one complete `FMADecoder` source-level hardware definition. Preserve the definition name, inheritance, and public interface shown below.

Return only the complete `class FMADecoder` definition in a single Scala code block, with no text outside the block.

## Package and imports

### `src/main/scala/exu/execution-units/fpu.scala`

```scala
package boom.exu

import chisel3._
import chisel3.util._
// ...
import freechips.rocketchip.rocket
// ...
import boom.common._
```

## Class declaration

### `src/main/scala/exu/execution-units/fpu.scala`

```scala
class FMADecoder extends Module
{
  val io = IO(new Bundle {
    val uopc = Input(UInt(UOPC_SZ.W))
    val cmd = Output(UInt(2.W))
  })
```

## Parent instantiation

### `src/main/scala/exu/execution-units/fpu.scala`

```scala
    val fma_decoder = Module(new FMADecoder)
    fma_decoder.io.uopc := io_req.uop.uopc
    req.fmaCmd := fma_decoder.io.cmd // ex_reg_inst(3,2) | (!fp_ctrl.ren3 && ex_reg_inst(27))
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/common/consts.scala`

```scala
trait ScalarOpConstants
{
  // ...
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
```

### `src/main/scala/MulAddRecFN.scala`

```scala
package hardfloat
// ...
class MulAddRecFNToRaw_preMul(expWidth: Int, sigWidth: Int) extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val op = Bits(INPUT, 2)
    // ...
    val rawA = rawFloatFromRecFN(expWidth, sigWidth, io.a)
    val rawB = rawFloatFromRecFN(expWidth, sigWidth, io.b)
    val rawC = rawFloatFromRecFN(expWidth, sigWidth, io.c)

    val signProd = rawA.sign ^ rawB.sign ^ io.op(1)
    // ...
    val doSubMags = signProd ^ rawC.sign ^ io.op(0)
```

## Related source code

### `src/main/scala/tile/FPU.scala`

```scala
class FPUFMAPipe(val latency: Int, val t: FType)
                (implicit p: Parameters) extends FPUModule()(p) with ShouldBeRetimed {
  require(latency>0)

  val io = new Bundle {
    val in = Valid(new FPInput).flip
    val out = Valid(new FPResult)
  }

  val valid = Reg(next=io.in.valid)
  val in = Reg(new FPInput)
  when (io.in.valid) {
    val one = UInt(1) << (t.sig + t.exp - 1)
    val zero = (io.in.bits.in1 ^ io.in.bits.in2) & (UInt(1) << (t.sig + t.exp))
    val cmd_fma = io.in.bits.ren3
    val cmd_addsub = io.in.bits.swap23
    in := io.in.bits
    when (cmd_addsub) { in.in2 := one }
    when (!(cmd_fma || cmd_addsub)) { in.in3 := zero }
  }

  val fma = Module(new MulAddRecFNPipe((latency-1) min 2, t.exp, t.sig))
  fma.io.validin := valid
  fma.io.op := in.fmaCmd
  fma.io.roundingMode := in.rm
  fma.io.detectTininess := hardfloat.consts.tininess_afterRounding
  fma.io.a := in.in1
  fma.io.b := in.in2
  fma.io.c := in.in3
```

## Documentation

### `src/f-st-ext.adoc`

```text
Floating-point arithmetic instructions with one or two source operands
use the R-type format with the OP-FP major opcode. FADD.S and FMUL.S
perform single-precision floating-point addition and multiplication
respectively, between _rs1_ and _rs2_. FSUB.S performs the
single-precision floating-point subtraction of _rs2_ from _rs1_. FDIV.S performs the single-precision floating-point division of _rs1_ by _rs2_. FSQRT.S computes the square root of _rs1_. In each case, the result is written to _rd_.
```

```text
FMADD.S multiplies the values in _rs1_ and _rs2_, adds the value in
_rs3_, and writes the final result to _rd_. FMADD.S computes
_(rs1latexmath:[$\times$]rs2)latexmath:[$\+$]rs3_.

FMSUB.S multiplies the values in _rs1_ and _rs2_, subtracts the value in _rs3_, and writes the final result to _rd_. FMSUB.S computes
_(rs1latexmath:[$\times$]rs2)latexmath:[$\-$]rs3_.

FNMSUB.S multiplies the values in _rs1_ and _rs2_, negates the product, adds the value in _rs3_, and writes the final result to _rd_. FNMSUB.S computes _-(rs1latexmath:[$\times$]rs2)latexmath:[$\+$]rs3_.

FNMADD.S multiplies the values in _rs1_ and _rs2_, negates the product, subtracts the value in _rs3_, and writes the final result to _rd_. FNMADD.S computes _-(rs1latexmath:[$\times$]rs2)latexmath:[$\-$]rs3_.
```

### `src/d-st-ext.adoc`

```text
=== Double-Precision Floating-Point Computational Instructions

The double-precision floating-point computational instructions are
defined analogously to their single-precision counterparts, but operate
on double-precision operands and produce double-precision results.
```
