# Implement `RVCExpander`

Implement the complete `RVCExpander` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Keep the declarations under Dependency declarations in the fixed source and do not resubmit them.

Return only the complete `class RVCExpander` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/parameters.scala`

```scala
  useCompressed: Boolean = true,
```

### `src/main/scala/common/config-mixins.scala`

```scala
    case XLen => 64
```

## Package and imports

```scala
// See LICENSE.SiFive for license details.

package freechips.rocketchip.rocket

import chisel3._
import chisel3.util._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.tile._
import freechips.rocketchip.util._
```

## Class declaration

```scala
class RVCExpander(implicit val p: Parameters) extends Module with HasCoreParameters {
  val io = IO(new Bundle {
    val in = Input(UInt(32.W))
    val out = Output(new ExpandedInstruction)
    val rvc = Output(Bool())
  })
```

## Parent instantiation

### `src/main/scala/common/consts.scala`

```scala
  def ExpandRVC(inst: UInt)(implicit p: Parameters): UInt = {
    val rvc_exp = Module(new RVCExpander)
    rvc_exp.io.in := inst
    Mux(rvc_exp.io.rvc, rvc_exp.io.out.bits, inst)
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

### `src/main/scala/rocket/RVC.scala`

```scala
class ExpandedInstruction extends Bundle {
  val bits = UInt(32.W)
  val rd = UInt(5.W)
  val rs1 = UInt(5.W)
  val rs2 = UInt(5.W)
  val rs3 = UInt(5.W)
}

// ...

class RVCDecoder(x: UInt, xLen: Int) {

// ...

  def q3 = Seq.fill(8)(passthrough)

  def passthrough = inst(x)

  def decode = {
    val s = q0 ++ q1 ++ q2 ++ q3
    s(Cat(x(1,0), x(15,13)))
  }
}
```

### `src/main/scala/tile/Core.scala`

```scala
case object XLen extends Field[Int]

// ...

trait HasCoreParameters extends HasTileParameters {

// ...

  val usingCompressed = coreParams.useCompressed
```

### `src/main/scala/tile/BaseTile.scala`

```scala
trait HasNonDiplomaticTileParameters {
  implicit val p: Parameters

// ...

  def xLen: Int = p(XLen)

// ...

trait HasTileParameters extends HasNonDiplomaticTileParameters {
```

## Documentation

### `src/c-st-ext.adoc`

```text
=== RVC Instruction Set Listings

<<rvcopcodemap>> shows a map of the major
opcodes for RVC. Each row of the table corresponds to one quadrant of
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
.RVC opcode map instructions.
[%autowidth,float="center",align="center",cols=">,^,^,^,^,^,^,^,^,^,<]
|===
2+>|inst[15:13] +
inst[1:0] ^.^s|000 ^.^s|001 ^.^s|010 ^.^s|011 ^.^s|100 ^.^s|101 ^.^s|110 ^.^s|111 |

2+>.^|00 .^|ADDI4SPN ^.^|FLD +
FLD +
LQ ^.^| LW ^.^| FLW +
LD +
LD ^.^| _Reserved_ ^.^| FSD +
FSD +
SQ ^.^| SW ^.^| FSW +
SD +
SD 
^.^| RV32 +
RV64 +
RV128

2+>.^|01 ^.^|ADDI ^.^|JAL +
ADDIW +
ADDIW ^.^|LI ^.^|LUI/ADDI16SP ^.^|MISC-ALU ^.^|J ^.^|BEQZ ^.^|BNEZ ^.^|RV32 +
RV64 +
RV128

2+>.^|10 ^.^|SLLI ^.^|FLDSP +
FLDSP +
LQSP ^.^|LWSP ^.^|FLWSP +
LDSP +
LDSP ^.^|J[AL]R/MV/ADD ^.^|FSDSP +
FSDSP +
SQSP ^.^|SWSP ^.^|FSWSP +
SDSP +
SDSP ^.^|RV32 +
RV64 +
RV128

2+>.^|11 9+^|>16b
|===
```
