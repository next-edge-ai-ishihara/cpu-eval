# Implement `MulDivIterativePlugin`

Implement the complete `MulDivIterativePlugin` class. The companion object remains fixed.

Return only the complete `class MulDivIterativePlugin` definition in a single Scala code block, with no text outside the block.

## Class declaration

### src/main/scala/vexriscv/plugin/MulDivIterativePlugin.scala

```scala
package vexriscv.plugin

import spinal.core._
import spinal.lib._
import vexriscv.{VexRiscv, _}
// ...
class MulDivIterativePlugin(genMul : Boolean = true,
                            genDiv : Boolean = true,
                            mulUnrollFactor : Int = 1,
                            divUnrollFactor : Int = 1,
                            dhrystoneOpt : Boolean = false,
                            customMul : (UInt, UInt, Stage, VexRiscv) => Area = null) extends Plugin[VexRiscv] with VexRiscvRegressionArg {
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
          config.plugins += new MulDivIterativePlugin(
            genMul = true,
            genDiv = true,
            mulUnrollFactor = 8,
            divUnrollFactor = 1
          )
```

## Dependency declarations

### src/main/scala/vexriscv/plugin/MulDivIterativePlugin.scala

```scala
object MulDivIterativePlugin{
  object IS_MUL extends Stageable(Bool)
  object IS_DIV extends Stageable(Bool)
  object IS_REM extends Stageable(Bool)
  object IS_RS1_SIGNED extends Stageable(Bool)
  object IS_RS2_SIGNED extends Stageable(Bool)
  object FAST_DIV_VALID extends Stageable(Bool)
  object FAST_DIV_VALUE extends Stageable(UInt(4 bits))
}
```

### src/main/scala/vexriscv/plugin/Plugin.scala

```scala
trait Plugin[T <: Pipeline] extends Nameable{
  var pipeline : T = null.asInstanceOf[T]
  setName(this.getClass.getSimpleName.replace("$",""))

  // Used to setup things with other plugins
  def setup(pipeline: T) : Unit = {}

  //Used to flush out the required hardware (called after setup)
  def build(pipeline: T) : Unit

  implicit class implicitsStage(stage: Stage){
    def plug[T <: Area](area : T) : T = {area.setCompositeName(stage,getName()).reflectNames();area}
  }
// ...
}
```

### src/main/scala/vexriscv/Services.scala

```scala
trait DecoderService{
  def add(key : MaskedLiteral,values : Seq[(Stageable[_ <: BaseType],Any)])
  def add(encoding :Seq[(MaskedLiteral,Seq[(Stageable[_ <: BaseType],Any)])])
  def addDefault(key : Stageable[_ <: BaseType], value : Any)
  def forceIllegal() : Unit
}
```

### src/main/scala/vexriscv/plugin/HazardSimplePlugin.scala

```scala
trait HazardService{
  def hazardOnExecuteRS : Bool
}
```

### src/main/scala/vexriscv/VexRiscv.scala

```scala
trait VexRiscvRegressionArg{
  def getVexRiscvRegressionArgs() : Seq[String]
}
case class VexRiscvConfig(){
// ...
  object BYPASSABLE_EXECUTE_STAGE   extends Stageable(Bool)
  object BYPASSABLE_MEMORY_STAGE   extends Stageable(Bool)
  object RS1   extends Stageable(Bits(32 bits))
  object RS2   extends Stageable(Bits(32 bits))
  object RS1_USE extends Stageable(Bool)
  object RS2_USE extends Stageable(Bool)
// ...
  object INSTRUCTION extends Stageable(Bits(32 bits))
// ...
  object REGFILE_WRITE_VALID extends Stageable(Bool)
  object REGFILE_WRITE_DATA extends Stageable(Bits(32 bits))
// ...
  object SRC1   extends Stageable(Bits(32 bits))
  object SRC2   extends Stageable(Bits(32 bits))
// ...
  object Src1CtrlEnum extends SpinalEnum(binarySequential){
    val RS, IMU, PC_INCREMENT, URS1 = newElement()   //IMU, IMZ IMJB
  }

  object Src2CtrlEnum extends SpinalEnum(binarySequential){
    val RS, IMI, IMS, PC = newElement() //TODO remplacing ZERO could avoid 32 muxes if SRC_ADD can be disabled
  }
  object SRC1_CTRL  extends Stageable(Src1CtrlEnum())
  object SRC2_CTRL  extends Stageable(Src2CtrlEnum())
// ...
}
// ...
class VexRiscv(val config : VexRiscvConfig) extends Component with Pipeline{
  type  T = VexRiscv
  import config._

  //Define stages
  def newStage(): Stage = { val s = new Stage; stages += s; s }
  val decode    = newStage()
  val execute   = newStage()
  val memory    = ifGen(config.withMemoryStage)    (newStage())
  val writeBack = ifGen(config.withWriteBackStage) (newStage())

  def stagesFromExecute = stages.dropWhile(_ != execute)
// ...
}
```

### src/main/scala/vexriscv/Riscv.scala

```scala
object Riscv{
// ...
  def MUL                = M"0000001----------000-----0110011"
  def MULH               = M"0000001----------001-----0110011"
  def MULHSU             = M"0000001----------010-----0110011"
  def MULHU              = M"0000001----------011-----0110011"


  def DIV                = M"0000001----------100-----0110011"
  def DIVU               = M"0000001----------101-----0110011"
  def REM                = M"0000001----------110-----0110011"
  def REMU               = M"0000001----------111-----0110011"
// ...
}
```

### src/main/scala/vexriscv/Pipeline.scala

```scala
trait Pipeline {
  type T <: Pipeline
  val plugins = ArrayBuffer[Plugin[T]]()
  var stages = ArrayBuffer[Stage]()
// ...
  def service[T](clazz : Class[T]) = {
    val filtered = plugins.filter(o => clazz.isAssignableFrom(o.getClass))
    assert(filtered.length == 1, s"??? ${clazz.getName}")
    filtered.head.asInstanceOf[T]
  }

  def serviceExist[T](clazz : Class[T]) = {
    val filtered = plugins.filter(o => clazz.isAssignableFrom(o.getClass))
     filtered.length != 0
  }
// ...
```

### src/main/scala/vexriscv/Stage.scala

```scala
class Stageable[T <: Data](_dataType : => T) extends HardType[T](_dataType) with Nameable{
  def dataType = apply()
  setWeakName(this.getClass.getSimpleName.replace("$",""))
}

class Stage() extends Area{
// ...
  def input[T <: Data](key : Stageable[T]) : T = {
    inputs.getOrElseUpdate(key.asInstanceOf[Stageable[Data]],outsideCondScope{
      val input,inputDefault = key()
      inputsDefault(key.asInstanceOf[Stageable[Data]]) = inputDefault
      input := inputDefault
      input.setPartialName(this, key.getName())
    }).asInstanceOf[T]
  }

  def output[T <: Data](key : Stageable[T]) : T = {
    outputs.getOrElseUpdate(key.asInstanceOf[Stageable[Data]],outsideCondScope{
      val output,outputDefault = key()
      outputsDefault(key.asInstanceOf[Stageable[Data]]) = outputDefault
      output := outputDefault
      output //.setPartialName(this,"output_" + key.getName())
    }).asInstanceOf[T]
  }

  def insert[T <: Data](key : Stageable[T]) : T = inserts.getOrElseUpdate(key.asInstanceOf[Stageable[Data]],outsideCondScope(key())).asInstanceOf[T] //.setPartialName(this,key.getName())
//  def apply[T <: Data](key : Stageable[T]) : T = ???


  val arbitration = new Area{
    val haltItself  = False   //user settable, stuck the instruction, should only be set by the instruction itself
    val haltByOther = False   //When settable, stuck the instruction, should only be set by something else than the stucked instruction
    val removeIt    = False   //When settable, unschedule the instruction as if it was never executed (no side effect)
    val flushIt    = False   //When settable, unschedule the current instruction
    val flushNext    = False   //When settable, unschedule instruction above in the pipeline
    val isValid     = Bool //Inform if a instruction is in the current stage
    val isStuck     = Bool           //Inform if the instruction is stuck (haltItself || haltByOther)
    val isStuckByOthers = Bool       //Inform if the instruction is stuck by sombody else
    def isRemoved   = removeIt       //Inform if the instruction is going to be unschedule the current cycle
    val isFlushed   = Bool           //Inform if the instruction is flushed (flushAll set in the current or subsequents stages)
    val isMoving     = Bool           //Inform if the instruction is going somewere else (next stage or unscheduled)
    val isFiring    = Bool           //Inform if the current instruction will go to the next stage the next cycle (isValid && !isStuck && !removeIt)
  }


// ...
}
```

## Documentation

### README.md

```text
#### MulDivIterativePlugin

This plugin implements the multiplication, division and modulo of the RISC-V M extension in an iterative way, which is friendly for small FPGAs that don't have DSP blocks.

This plugin is able to unroll the iterative calculation process to reduce the number of cycles used to execute mul/div instructions.

| Parameters | type | description |
| ------ | ----------- | ------ |
| genMul    | Boolean | Enables multiplication support. Can be set to false if you want to use the MulPlugin instead |
| genDiv    | Boolean |  Enables division support |
| mulUnrollFactor    | Int | Number of combinatorial stages used to speed up the multiplication, should be > 0 |
| divUnrollFactor    | Int | Number of combinatorial stages used to speed up the division, should be > 0 |

The number of cycles used to execute a multiplication is '32/mulUnrollFactor'
The number of cycles used to execute a division is '32/divUnrollFactor + 1'

Both mul/div are processed in the memory stage (late result).
```

### src/m-st-ext.adoc

```text
=== Multiplication Operations

...
MUL performs an XLEN-bit×XLEN-bit multiplication of
_rs1_ by _rs2_ and places the lower XLEN bits in the destination
register. MULH, MULHU, and MULHSU perform the same multiplication but
return the upper XLEN bits of the full 2×XLEN-bit
product, for signed×signed,
unsigned×unsigned, and _rs1_×unsigned _rs2_ multiplication, respectively.
If both the high and low bits of the same product are required, then the recommended code sequence is: MULH[[S]U] _rdh, rs1, rs2_; MUL _rdl, rs1, rs2_ (source register specifiers must be in same order and _rdh_ cannot be the same as _rs1_ or _rs2_). Microarchitectures can then fuse these into a single multiply operation instead of performing two separate multiplies.

[NOTE]
====
MULHSU is used in multi-word signed multiplication to multiply the
most-significant word of the multiplicand (which contains the sign bit)
with the less-significant words of the multiplier (which are unsigned).
====
...
=== Division Operations

...
DIV and DIVU perform an XLEN bits by XLEN bits signed and unsigned
integer division of _rs1_ by _rs2_, rounding towards zero. REM and REMU
provide the remainder of the corresponding division operation. For REM,
the sign of a nonzero result equals the sign of the dividend.
...
The semantics for division by zero and division overflow are summarized
in <<divby0>>. The quotient of division by zero has all bits
set, and the remainder of division by zero equals the dividend. Signed
division overflow occurs only when the most-negative integer is divided
by latexmath:[$-1$]. The quotient of a signed division with overflow is
equal to the dividend, and the remainder is zero. Unsigned division
overflow cannot occur.
```
