# Implement `PipelinedMultiplier`

Implement the complete `PipelinedMultiplier` module. Preserve its declaration and I/O interface. Return only the complete `class PipelinedMultiplier` definition in a single Scala code block, with no text outside the block.

## Package and imports

### `src/main/scala/rocket/Multiplier.scala`

```scala
// See LICENSE.Berkeley for license details.
// See LICENSE.SiFive for license details.

package freechips.rocketchip.rocket

import chisel3._
import chisel3.util.{Cat, log2Up, log2Ceil, log2Floor, Log2, Decoupled, Enum, Fill, Valid, Pipe}
import Chisel.ImplicitConversions._
import freechips.rocketchip.util._
import ALU._
```

## Class declaration

```scala
class PipelinedMultiplier(width: Int, latency: Int, nXpr: Int = 32) extends Module with ShouldBeRetimed {
  val io = IO(new Bundle {
    val req = Flipped(Valid(new MultiplierReq(width, log2Ceil(nXpr))))
    val resp = Valid(new MultiplierResp(width, log2Ceil(nXpr)))
  })
```

## Parent instantiation

### `src/main/scala/exu/execution-units/functional-unit.scala`

```scala
class PipelinedMulUnit(numStages: Int, dataWidth: Int)(implicit p: Parameters)
  extends PipelinedFunctionalUnit(
    numStages = numStages,
    numBypassStages = 0,
    earliestBypassStage = 0,
    dataWidth = dataWidth)
{
  val imul = Module(new PipelinedMultiplier(xLen, numStages))
  // request
  imul.io.req.valid    := io.req.valid
  imul.io.req.bits.fn  := io.req.bits.uop.ctrl.op_fcn
  imul.io.req.bits.dw  := io.req.bits.uop.ctrl.fcn_dw
  imul.io.req.bits.in1 := io.req.bits.rs1_data
  imul.io.req.bits.in2 := io.req.bits.rs2_data
  imul.io.req.bits.tag := DontCare
  // response
  io.resp.bits.data    := imul.io.resp.bits.data
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

### `src/main/scala/rocket/Multiplier.scala`

```scala
class MultiplierReq(dataBits: Int, tagBits: Int) extends Bundle {
  val fn = Bits(SZ_ALU_FN.W)
  val dw = Bits(SZ_DW.W)
  val in1 = Bits(dataBits.W)
  val in2 = Bits(dataBits.W)
  val tag = UInt(tagBits.W)
}

class MultiplierResp(dataBits: Int, tagBits: Int) extends Bundle {
  val data = Bits(dataBits.W)
  val tag = UInt(tagBits.W)
}
```

### `src/main/scala/rocket/ALU.scala`

```scala
object ALU
{
  val SZ_ALU_FN = 4
// ...
  def FN_MUL    = FN_ADD
  def FN_MULH   = FN_SL
  def FN_MULHSU = FN_SEQ
  def FN_MULHU  = FN_SNE

  def isMulFN(fn: UInt, cmp: UInt) = fn(1,0) === cmp(1,0)
// ...
```

### `src/main/scala/rocket/package.scala`

```scala
package object rocket extends rocket.constants.ScalarOpConstants with rocket.constants.MemoryOpConstants
```

### `src/main/scala/rocket/Consts.scala`

```scala
trait ScalarOpConstants {
// ...
  val SZ_DW = 1
  def DW_X  = X
  def DW_32 = Bool(false)
  def DW_64 = Bool(true)
  def DW_XPR = DW_64
// ...
```

## Documentation

### `src/m-st-ext.adoc`

```text
MUL performs an XLEN-bit×XLEN-bit multiplication of
_rs1_ by _rs2_ and places the lower XLEN bits in the destination
register. MULH, MULHU, and MULHSU perform the same multiplication but
return the upper XLEN bits of the full 2×XLEN-bit
product, for signed×signed,
unsigned×unsigned, and _rs1_×unsigned _rs2_ multiplication, respectively.
...
MULW is an RV64 instruction that multiplies the lower 32 bits of the
source registers, placing the sign extension of the lower 32 bits of the
result into the destination register.
```

## Additional requirement

Each cycle's `req.valid` must appear on `resp.valid` exactly `latency` cycles later, together with the product of that request when it was valid.
