# Implement `SrcPlugin`

Implement the complete `SrcPlugin` class.

Return only the complete `class SrcPlugin` definition in a single Scala code block, with no text outside the block.

## Class declaration

### src/main/scala/vexriscv/plugin/SrcPlugin.scala

```scala
package vexriscv.plugin

import vexriscv._
import spinal.core._
import spinal.lib.KeepAttribute


class SrcPlugin(separatedAddSub : Boolean = false, executeInsertion : Boolean = false, decodeAddSub : Boolean = false) extends Plugin[VexRiscv]{
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
class SrcDimension extends VexRiscvDimension("Src") {

  override def randomPositionImpl(universes: Seq[ConfigUniverse], r: Random) = {
    val separatedAddSub = r.nextBoolean()
    val executeInsertion = universes.contains(VexRiscvUniverse.EXECUTE_RF) || r.nextBoolean()
    new VexRiscvPosition((if (separatedAddSub) "AddSub" else "") + (if (executeInsertion) "Execute" else "")) {
      override def applyOn(config: VexRiscvConfig): Unit = config.plugins += new SrcPlugin(
        separatedAddSub = separatedAddSub,
        executeInsertion = executeInsertion
      )
    }
  }
}
```

## Dependency declarations

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
  implicit class implicitsPipeline(stage: Pipeline){
    def plug[T <: Area](area : T) = {area.setName(getName()).reflectNames();area}
  }
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

### src/main/scala/vexriscv/VexRiscv.scala

```scala
case class VexRiscvConfig(){
// ...
  def withRvc = plugins.find(_.isInstanceOf[IBusFetcher]) match {
    case Some(x) => x.asInstanceOf[IBusFetcher].withRvc
    case None => false
  }
// ...
  object IS_RVC extends Stageable(Bool)
// ...
  object RS1   extends Stageable(Bits(32 bits))
  object RS2   extends Stageable(Bits(32 bits))
// ...
  object PC extends Stageable(UInt(32 bits))
// ...
  object INSTRUCTION extends Stageable(Bits(32 bits))
// ...
  object SRC1   extends Stageable(Bits(32 bits))
  object SRC2   extends Stageable(Bits(32 bits))
  object SRC_ADD_SUB extends Stageable(Bits(32 bits))
  object SRC_ADD extends Stageable(Bits(32 bits))
  object SRC_SUB extends Stageable(Bits(32 bits))
  object SRC_LESS extends Stageable(Bool)
  object SRC_USE_SUB_LESS extends Stageable(Bool)
  object SRC_LESS_UNSIGNED extends Stageable(Bool)
  object SRC_ADD_ZERO extends Stageable(Bool)
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
  def rs1Range = 19 downto 15
// ...
  case class IMM(instruction  : Bits) extends Area{
    // immediates
    def i = instruction(31 downto 20)
    def h = instruction(31 downto 24)
    def s = instruction(31 downto 25) ## instruction(11 downto 7)
    def b = instruction(31) ## instruction(7) ## instruction(30 downto 25) ## instruction(11 downto 8)
    def u = instruction(31 downto 12) ## U"x000"
    def j = instruction(31) ## instruction(19 downto 12) ## instruction(20) ## instruction(30 downto 21)
    def z = instruction(19 downto 15)

    // sign-extend immediates
    def i_sext = B((19 downto 0) -> i(11)) ## i
    def h_sext = B((23 downto 0) -> h(7))  ## h
    def s_sext = B((19 downto 0) -> s(11)) ## s
    def b_sext = B((18 downto 0) -> b(11)) ## b ## False
    def j_sext = B((10 downto 0) -> j(19)) ## j ## False
  }
// ...
}
```

### src/main/scala/vexriscv/Pipeline.scala

```scala
trait Pipeline {
  type T <: Pipeline
  val plugins = ArrayBuffer[Plugin[T]]()
  var stages = ArrayBuffer[Stage]()
  var unremovableStages = mutable.Set[Stage]()
  val things = mutable.LinkedHashMap[PipelineThing[_], Any]()
//  val services = ArrayBuffer[Any]()

  def stageBefore(stage : Stage) = stages(indexOf(stage)-1)

  def indexOf(stage : Stage) = stages.indexOf(stage)

  def service[T](clazz : Class[T]) = {
    val filtered = plugins.filter(o => clazz.isAssignableFrom(o.getClass))
    assert(filtered.length == 1, s"??? ${clazz.getName}")
    filtered.head.asInstanceOf[T]
  }
// ...
}
```

### src/main/scala/vexriscv/Stage.scala

```scala
class Stageable[T <: Data](_dataType : => T) extends HardType[T](_dataType) with Nameable{
  def dataType = apply()
  setWeakName(this.getClass.getSimpleName.replace("$",""))
}

class Stage() extends Area{
  def outsideCondScope[T](that : => T) : T = {
    val body = Component.current.dslBody  // Get the head of the current component symboles tree (AST in other words)
    val ctx = body.push()                           // Now all access to the SpinalHDL API will be append to it (instead of the current context)
    val swapContext = body.swap()         // Empty the symbole tree (but keep a reference to the old content)
    val ret = that                        // Execute the block of code (will be added to the recently empty body)
    ctx.restore()                            // Restore the original context in which this function was called
    swapContext.appendBack()              // append the original symboles tree to the modified body
    ret                                   // return the value returned by that
  }

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
// ...
}
```

## Related source code

### src/main/scala/vexriscv/plugin/IntAluPlugin.scala

```scala
    val immediateActions = List[(Stageable[_ <: BaseType],Any)](
      SRC1_CTRL                -> Src1CtrlEnum.RS,
      SRC2_CTRL                -> Src2CtrlEnum.IMI,
      REGFILE_WRITE_VALID      -> True,
      BYPASSABLE_EXECUTE_STAGE -> True,
      BYPASSABLE_MEMORY_STAGE  -> True,
      RS1_USE -> True
    )

    val nonImmediateActions = List[(Stageable[_ <: BaseType],Any)](
      SRC1_CTRL                -> Src1CtrlEnum.RS,
      SRC2_CTRL                -> Src2CtrlEnum.RS,
      REGFILE_WRITE_VALID      -> True,
      BYPASSABLE_EXECUTE_STAGE -> True,
      BYPASSABLE_MEMORY_STAGE  -> True,
      RS1_USE -> True,
      RS2_USE -> True
    )

    val otherAction = List[(Stageable[_ <: BaseType],Any)](
      REGFILE_WRITE_VALID      -> True,
      BYPASSABLE_EXECUTE_STAGE -> True,
      BYPASSABLE_MEMORY_STAGE  -> True
    )



    val decoderService = pipeline.service(classOf[DecoderService])
    decoderService.add(List(
      ADD  -> (nonImmediateActions ++ List(ALU_CTRL -> AluCtrlEnum.ADD_SUB,  SRC_USE_SUB_LESS -> False)),
      SUB  -> (nonImmediateActions ++ List(ALU_CTRL -> AluCtrlEnum.ADD_SUB,  SRC_USE_SUB_LESS -> True)),
      SLT  -> (nonImmediateActions ++ List(ALU_CTRL -> AluCtrlEnum.SLT_SLTU, SRC_USE_SUB_LESS -> True, SRC_LESS_UNSIGNED -> False)),
      SLTU -> (nonImmediateActions ++ List(ALU_CTRL -> AluCtrlEnum.SLT_SLTU, SRC_USE_SUB_LESS -> True, SRC_LESS_UNSIGNED -> True)),
      XOR  -> (nonImmediateActions ++ List(ALU_CTRL -> AluCtrlEnum.BITWISE,  ALU_BITWISE_CTRL -> AluBitwiseCtrlEnum.XOR)),
      OR   -> (nonImmediateActions ++ List(ALU_CTRL -> AluCtrlEnum.BITWISE,  ALU_BITWISE_CTRL -> AluBitwiseCtrlEnum.OR)),
      AND  -> (nonImmediateActions ++ List(ALU_CTRL -> AluCtrlEnum.BITWISE,  ALU_BITWISE_CTRL -> AluBitwiseCtrlEnum.AND))
    ))

    decoderService.add(List(
      ADDI  -> (immediateActions ++ List(ALU_CTRL -> AluCtrlEnum.ADD_SUB,  SRC_USE_SUB_LESS -> False)),
      SLTI  -> (immediateActions ++ List(ALU_CTRL -> AluCtrlEnum.SLT_SLTU, SRC_USE_SUB_LESS -> True, SRC_LESS_UNSIGNED -> False)),
      SLTIU -> (immediateActions ++ List(ALU_CTRL -> AluCtrlEnum.SLT_SLTU, SRC_USE_SUB_LESS -> True, SRC_LESS_UNSIGNED -> True)),
      XORI  -> (immediateActions ++ List(ALU_CTRL -> AluCtrlEnum.BITWISE,  ALU_BITWISE_CTRL -> AluBitwiseCtrlEnum.XOR)),
      ORI   -> (immediateActions ++ List(ALU_CTRL -> AluCtrlEnum.BITWISE,  ALU_BITWISE_CTRL -> AluBitwiseCtrlEnum.OR)),
      ANDI  -> (immediateActions ++ List(ALU_CTRL -> AluCtrlEnum.BITWISE,  ALU_BITWISE_CTRL -> AluBitwiseCtrlEnum.AND))
    ))

    decoderService.add(List(
      LUI   -> (otherAction ++ List(ALU_CTRL -> AluCtrlEnum.ADD_SUB, SRC1_CTRL -> Src1CtrlEnum.IMU, SRC_USE_SUB_LESS -> False, SRC_ADD_ZERO -> True)),
      AUIPC -> (otherAction ++ List(ALU_CTRL -> AluCtrlEnum.ADD_SUB, SRC_USE_SUB_LESS -> False, SRC1_CTRL -> Src1CtrlEnum.IMU, SRC2_CTRL -> Src2CtrlEnum.PC))
    ))
```

### src/main/scala/vexriscv/plugin/BranchPlugin.scala

```scala
    val bActions = List[(Stageable[_ <: BaseType],Any)](
      SRC1_CTRL         -> Src1CtrlEnum.RS,
      SRC2_CTRL         -> Src2CtrlEnum.RS,
      SRC_USE_SUB_LESS  -> True,
      RS1_USE          -> True,
      RS2_USE          -> True,
      HAS_SIDE_EFFECT -> True
    )

    val jActions = List[(Stageable[_ <: BaseType],Any)](
      SRC1_CTRL           -> Src1CtrlEnum.PC_INCREMENT,
      SRC2_CTRL           -> Src2CtrlEnum.PC,
      SRC_USE_SUB_LESS    -> False,
      REGFILE_WRITE_VALID -> True,
      HAS_SIDE_EFFECT -> True
    )

    val decoderService = pipeline.service(classOf[DecoderService])


    decoderService.addDefault(BRANCH_CTRL, BranchCtrlEnum.INC)
    decoderService.add(List(
      JAL(true)  -> (jActions ++ List(BRANCH_CTRL -> BranchCtrlEnum.JAL, ALU_CTRL -> AluCtrlEnum.ADD_SUB)),
      JALR       -> (jActions ++ List(BRANCH_CTRL -> BranchCtrlEnum.JALR, ALU_CTRL -> AluCtrlEnum.ADD_SUB, RS1_USE -> True)),
      BEQ(true)  -> (bActions ++ List(BRANCH_CTRL -> BranchCtrlEnum.B)),
      BNE(true)  -> (bActions ++ List(BRANCH_CTRL -> BranchCtrlEnum.B)),
      BLT(true)  -> (bActions ++ List(BRANCH_CTRL -> BranchCtrlEnum.B, SRC_LESS_UNSIGNED -> False)),
      BGE(true)  -> (bActions ++ List(BRANCH_CTRL -> BranchCtrlEnum.B, SRC_LESS_UNSIGNED -> False)),
      BLTU(true) -> (bActions ++ List(BRANCH_CTRL -> BranchCtrlEnum.B, SRC_LESS_UNSIGNED -> True)),
      BGEU(true) -> (bActions ++ List(BRANCH_CTRL -> BranchCtrlEnum.B, SRC_LESS_UNSIGNED -> True))
    ))
```

### src/main/scala/vexriscv/plugin/DBusCachedPlugin.scala

```scala
    val stdActions = List[(Stageable[_ <: BaseType],Any)](
      SRC1_CTRL         -> Src1CtrlEnum.RS,
      SRC_USE_SUB_LESS  -> False,
      MEMORY_ENABLE     -> True,
      RS1_USE          -> True,
      IntAluPlugin.ALU_CTRL -> IntAluPlugin.AluCtrlEnum.ADD_SUB
    )

    val loadActions = stdActions ++ List(
      SRC2_CTRL -> Src2CtrlEnum.IMI,
      REGFILE_WRITE_VALID -> True,
      BYPASSABLE_EXECUTE_STAGE -> False,
      BYPASSABLE_MEMORY_STAGE -> False,
      MEMORY_WR -> False,
      HAS_SIDE_EFFECT -> True
    )

    val storeActions = stdActions ++ List(
      SRC2_CTRL -> Src2CtrlEnum.IMS,
      RS2_USE -> True,
      MEMORY_WR -> True,
      HAS_SIDE_EFFECT -> True
    )
```

### src/main/scala/vexriscv/plugin/CsrPlugin.scala

```scala
    val defaultCsrActions = List[(Stageable[_ <: BaseType],Any)](
      IS_CSR                   -> True,
      REGFILE_WRITE_VALID      -> True,
      BYPASSABLE_EXECUTE_STAGE -> False,
      BYPASSABLE_MEMORY_STAGE  -> True
    ) ++ (if(catchIllegalAccess) List(HAS_SIDE_EFFECT -> True) else Nil)

    val nonImmediatActions = defaultCsrActions ++ List(
      SRC1_CTRL                -> Src1CtrlEnum.RS,
      RS1_USE                 -> True
    )

    val immediatActions = defaultCsrActions ++ List(
      SRC1_CTRL -> Src1CtrlEnum.URS1
    )
```

## Documentation

### README.md

```text
#### SrcPlugin

This plugin muxes different input values to produce SRC1/SRC2/SRC_ADD/SRC_SUB/SRC_LESS values which are common values used by many plugins in the execute stage (ALU/Branch/Load/Store).

| Parameters | type | description |
| ------ | ----------- | ------ |
| separatedAddSub | RegFileReadKind | By default SRC_ADD/SRC_SUB are generated from a single controllable adder/substractor, but if this is set to true, it use separate adder/substractors |
| executeInsertion | Boolean | By default SRC1/SRC2 are generated in the Decode stage, but if this parameter is true, it is done in the Execute stage (It will relax the bypassing network) |

Except for SRC1/SRC2, this plugin does everything at the begining of Execute stage.
```

### src/rv32.adoc

```text
ADDI adds the sign-extended 12-bit immediate to register _rs1_.
Arithmetic overflow is ignored and the result is simply the low XLEN
bits of the result. ADDI _rd, rs1, 0_ is used to implement the MV _rd,
rs1_ assembler pseudoinstruction.

SLTI (set less than immediate) places the value 1 in register _rd_ if
register _rs1_ is less than the sign-extended immediate when both are
treated as signed numbers, else 0 is written to _rd_. SLTIU is similar
but compares the values as unsigned numbers (i.e., the immediate is
first sign-extended to XLEN bits then treated as an unsigned number).
Note, SLTIU _rd, rs1, 1_ sets _rd_ to 1 if _rs1_ equals zero, otherwise
sets _rd_ to 0 (assembler pseudoinstruction SEQZ _rd, rs_).
...
LUI (load upper immediate) is used to build 32-bit constants and uses
the U-type format. LUI places the 32-bit U-immediate value into the
destination register _rd_, filling in the lowest 12 bits with zeros.

AUIPC (add upper immediate to `pc`) is used to build `pc`-relative
addresses and uses the U-type format. AUIPC forms a 32-bit offset from
the U-immediate, filling in the lowest 12 bits with zeros, adds this
offset to the address of the AUIPC instruction, then places the result
in register _rd_.
...
RV32I defines several arithmetic R-type operations. All operations read
the _rs1_ and _rs2_ registers as source operands and write the result
into register _rd_. The _funct7_ and _funct3_ fields select the type of
operation.
...
ADD performs the addition of _rs1_ and _rs2_. SUB performs the
subtraction of _rs2_ from _rs1_. Overflows are ignored and the low XLEN
bits of results are written to the destination _rd_. SLT and SLTU
perform signed and unsigned compares respectively, writing 1 to _rd_ if
_rs1_ < _rs2_, 0 otherwise. Note, SLTU _rd_, _x0_, _rs2_ sets _rd_ to 1 if
_rs2_ is not equal to zero, otherwise sets _rd_ to zero (assembler
pseudoinstruction SNEZ _rd, rs_). AND, OR, and XOR perform bitwise
logical operations.
```
