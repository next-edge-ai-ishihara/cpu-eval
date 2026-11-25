# Implement `IntAluPlugin`

Implement the complete `IntAluPlugin` class. The companion object remains fixed.

Return only the complete `class IntAluPlugin` definition in a single Scala code block, with no text outside the block.

## Class declaration

### src/main/scala/vexriscv/plugin/IntAluPlugin.scala

```scala
package vexriscv.plugin

import vexriscv._
import spinal.core._
object IntAluPlugin{
  object AluBitwiseCtrlEnum extends SpinalEnum(binarySequential){
    val XOR, OR, AND = newElement()
  }
  object AluCtrlEnum extends SpinalEnum(binarySequential){
    val ADD_SUB, SLT_SLTU, BITWISE = newElement()
  }

  object ALU_BITWISE_CTRL extends Stageable(AluBitwiseCtrlEnum())
  object ALU_CTRL extends Stageable(AluCtrlEnum())
}

class IntAluPlugin extends Plugin[VexRiscv]{
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

### src/main/scala/vexriscv/VexRiscv.scala

```scala
case class VexRiscvConfig(){
// ...
  object IS_RVC extends Stageable(Bool)
  object BYPASSABLE_EXECUTE_STAGE   extends Stageable(Bool)
  object BYPASSABLE_MEMORY_STAGE   extends Stageable(Bool)
  object RS1   extends Stageable(Bits(32 bits))
  object RS2   extends Stageable(Bits(32 bits))
  object RS1_USE extends Stageable(Bool)
  object RS2_USE extends Stageable(Bool)
// ...
  object PC extends Stageable(UInt(32 bits))
// ...
  object INSTRUCTION extends Stageable(Bits(32 bits))
// ...
  object REGFILE_WRITE_VALID extends Stageable(Bool)
  object REGFILE_WRITE_DATA extends Stageable(Bits(32 bits))
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
```

### src/main/scala/vexriscv/Pipeline.scala

```scala
trait Pipeline {
  type T <: Pipeline
  val plugins = ArrayBuffer[Plugin[T]]()
// ...
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

### src/main/scala/vexriscv/Riscv.scala

```scala
object Riscv{
// ...
  def ADD                = M"0000000----------000-----0110011"
  def SUB                = M"0100000----------000-----0110011"
// ...
  def SLT                = M"0000000----------010-----0110011"
  def SLTU               = M"0000000----------011-----0110011"
  def XOR                = M"0000000----------100-----0110011"
// ...
  def OR                 = M"0000000----------110-----0110011"
  def AND                = M"0000000----------111-----0110011"

  def ADDI               = M"-----------------000-----0010011"
// ...
  def SLTI               = M"-----------------010-----0010011"
  def SLTIU              = M"-----------------011-----0010011"
  def XORI               = M"-----------------100-----0010011"
// ...
  def ORI                = M"-----------------110-----0010011"
  def ANDI               = M"-----------------111-----0010011"
// ...
  def LUI                = M"-------------------------0110111"
  def AUIPC              = M"-------------------------0010111"
// ...
}
```

## Related source code

### src/main/scala/vexriscv/plugin/RegFilePlugin.scala

```scala
  override def setup(pipeline: VexRiscv): Unit = {
    import pipeline.config._
    val decoderService = pipeline.service(classOf[DecoderService])
    decoderService.addDefault(RS1_USE,False)
    decoderService.addDefault(RS2_USE,False)
    decoderService.addDefault(REGFILE_WRITE_VALID,False)
  }
// ...
```

### src/main/scala/vexriscv/plugin/SrcPlugin.scala

```scala
class SrcPlugin(separatedAddSub : Boolean = false, executeInsertion : Boolean = false, decodeAddSub : Boolean = false) extends Plugin[VexRiscv]{
  object SRC2_FORCE_ZERO extends Stageable(Bool)


  override def setup(pipeline: VexRiscv): Unit = {
    import pipeline.config._

    val decoderService = pipeline.service(classOf[DecoderService])
    decoderService.addDefault(SRC_ADD_ZERO, False) //TODO avoid this default to simplify decoding ?
  }

  override def build(pipeline: VexRiscv): Unit = {
    import pipeline._
    import pipeline.config._

    decode.insert(SRC2_FORCE_ZERO) := decode.input(SRC_ADD_ZERO) && !decode.input(SRC_USE_SUB_LESS)

    val insertionStage = if(executeInsertion) execute else decode
    insertionStage plug new Area{
      import insertionStage._

      val imm = Riscv.IMM(input(INSTRUCTION))
      insert(SRC1) := input(SRC1_CTRL).mux(
        Src1CtrlEnum.RS   -> output(RS1),
        Src1CtrlEnum.PC_INCREMENT -> (if(pipeline.config.withRvc) Mux(input(IS_RVC), B(2), B(4)) else B(4)).resized,
        Src1CtrlEnum.IMU  -> imm.u.resized,
        Src1CtrlEnum.URS1 -> input(INSTRUCTION)(Riscv.rs1Range).resized
      )
      insert(SRC2) := input(SRC2_CTRL).mux(
        Src2CtrlEnum.RS -> output(RS2),
        Src2CtrlEnum.IMI -> imm.i_sext.resized,
        Src2CtrlEnum.IMS -> imm.s_sext.resized,
        Src2CtrlEnum.PC -> output(PC).asBits
      )
    }

    val addSubStage = if(decodeAddSub) decode else execute
    if(separatedAddSub) {
      addSubStage plug new Area {
        import addSubStage._

        // ADD, SUB
        val add = (U(input(SRC1)) + U(input(SRC2))).asBits.addAttribute("keep")
        val sub = (U(input(SRC1)) - U(input(SRC2))).asBits.addAttribute("keep")
        when(input(SRC_ADD_ZERO)){ add := input(SRC1) }

        // SLT, SLTU
        val less = Mux(input(SRC1).msb === input(SRC2).msb, sub.msb,
          Mux(input(SRC_LESS_UNSIGNED), input(SRC2).msb, input(SRC1).msb))

        insert(SRC_ADD_SUB) := input(SRC_USE_SUB_LESS) ? sub | add
        insert(SRC_ADD) := add
        insert(SRC_SUB) := sub
        insert(SRC_LESS) := less
      }
    }else{
      addSubStage plug new Area {
        import addSubStage._

        // ADD, SUB
        val addSub = (input(SRC1).asSInt + Mux(input(SRC_USE_SUB_LESS), ~input(SRC2), input(SRC2)).asSInt + Mux(input(SRC_USE_SUB_LESS), S(1, 32 bits), S(0, 32 bits))).asBits
        when(input(SRC2_FORCE_ZERO)){ addSub := input(SRC1) }


        // SLT, SLTU
        val less = Mux(input(SRC1).msb === input(SRC2).msb, addSub.msb,
          Mux(input(SRC_LESS_UNSIGNED), input(SRC2).msb, input(SRC1).msb))

        insert(SRC_ADD_SUB) := addSub
        insert(SRC_ADD) := addSub
        insert(SRC_SUB) := addSub
        insert(SRC_LESS) := less
      }
    }
  }
}
```

## Documentation

### README.md

```text
#### IntAluPlugin

This plugin implements all ADD/SUB/SLT/SLTU/XOR/OR/AND/LUI/AUIPC instructions in the execute stage by using the SrcPlugin outputs. It is a really simple plugin.

The result is injected into the pipeline directly at the end of the execute stage.
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

ANDI, ORI, XORI are logical operations that perform bitwise AND, OR, and
XOR on register _rs1_ and the sign-extended 12-bit immediate and place
the result in _rd_. Note, XORI _rd, rs1, -1_ performs a bitwise logical
inversion of register _rs1_ (assembler pseudoinstruction NOT _rd, rs_).
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
