# Implement `FullBarrelShifterPlugin`

Implement the complete `FullBarrelShifterPlugin` class.

Return only the complete `class FullBarrelShifterPlugin` definition in a single Scala code block, with no text outside the block.

## Class declaration

### src/main/scala/vexriscv/plugin/ShiftPlugins.scala

```scala
package vexriscv.plugin

import vexriscv._
import spinal.core._
import spinal.lib.Reverse



class FullBarrelShifterPlugin(earlyInjection : Boolean = false) extends Plugin[VexRiscv]{
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
    if(!universes.contains(VexRiscvUniverse.NO_MEMORY)) l = new VexRiscvPosition("FullLate") {
      override def applyOn(config: VexRiscvConfig): Unit = config.plugins += new FullBarrelShifterPlugin(earlyInjection = false)
    } :: l
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
  object BYPASSABLE_EXECUTE_STAGE   extends Stageable(Bool)
  object BYPASSABLE_MEMORY_STAGE   extends Stageable(Bool)
  object RS1   extends Stageable(Bits(32 bits))
  object RS2   extends Stageable(Bits(32 bits))
  object RS1_USE extends Stageable(Bool)
  object RS2_USE extends Stageable(Bool)
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

  def serviceExist[T](clazz : Class[T]) = {
    val filtered = plugins.filter(o => clazz.isAssignableFrom(o.getClass))
     filtered.length != 0
  }

  def serviceElse[T](clazz : Class[T], default : => T) : T = {
    if(!serviceExist(clazz)) return default
    val filtered = plugins.filter(o => clazz.isAssignableFrom(o.getClass))
    assert(filtered.length == 1)
    filtered.head.asInstanceOf[T]
  }

  def update[T](that : PipelineThing[T], value : T) : Unit = things(that) = value
  def apply[T](that : PipelineThing[T]) : T = things(that).asInstanceOf[T]
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


  val inputs   = mutable.LinkedHashMap[Stageable[Data],Data]()
  val outputs  = mutable.LinkedHashMap[Stageable[Data],Data]()
  val signals  = mutable.LinkedHashMap[Stageable[Data],Data]()
  val inserts  = mutable.LinkedHashMap[Stageable[Data],Data]()

  val inputsDefault   = mutable.LinkedHashMap[Stageable[Data],Data]()
  val outputsDefault  = mutable.LinkedHashMap[Stageable[Data],Data]()

  val dontSample      = mutable.LinkedHashMap[Stageable[_], ArrayBuffer[Bool]]()

  def dontSampleStageable(s : Stageable[_], cond : Bool): Unit ={
    dontSample.getOrElseUpdate(s, ArrayBuffer[Bool]()) += cond
  }
  def inputInit[T <: BaseType](stageable : Stageable[T],initValue : T) =
    Component.current.addPrePopTask(() => inputsDefault(stageable.asInstanceOf[Stageable[Data]]).asInstanceOf[T].getDrivingReg().init(initValue))
}
```

### src/main/scala/vexriscv/Riscv.scala

```scala
object Riscv{
// ...
  def SLL                = M"0000000----------001-----0110011"
// ...
  def SRL                = M"0000000----------101-----0110011"
  def SRA                = M"0100000----------101-----0110011"
// ...
  def SLLI               = M"0000000----------001-----0010011"
// ...
  def SRLI               = M"0000000----------101-----0010011"
  def SRAI               = M"0100000----------101-----0010011"
// ...
}
```

## Related source code

### src/main/scala/vexriscv/plugin/DecoderSimplePlugin.scala

```scala
class DecoderSimplePlugin(catchIllegalInstruction : Boolean = false,
                          throwIllegalInstruction : Boolean = false,
                          assertIllegalInstruction : Boolean = false,
                          forceLegalInstructionComputation : Boolean = false,
                          decoderIsolationBench : Boolean = false,
                          stupidDecoder : Boolean = false) extends Plugin[VexRiscv] with DecoderService {
  override def add(encoding: Seq[(MaskedLiteral, Seq[(Stageable[_ <: BaseType], Any)])]): Unit = encoding.foreach(e => this.add(e._1,e._2))
  override def add(key: MaskedLiteral, values: Seq[(Stageable[_ <: BaseType], Any)]): Unit = {
    val instructionModel = encodings.getOrElseUpdate(key,ArrayBuffer[(Stageable[_ <: BaseType], BaseType)]())
    values.map{case (a,b) => {
      assert(!instructionModel.contains(a), s"Over specification of $a")
      val value = b match {
        case e: SpinalEnumElement[_] => e()
        case e: BaseType => e
      }
      instructionModel += (a->value)
    }}
  }

  override def addDefault(key: Stageable[_  <: BaseType], value: Any): Unit = {
    assert(!defaults.contains(key))
    defaults(key) = value match{
      case e : SpinalEnumElement[_] => e()
      case e : BaseType => e
    }
  }
// ...
}
```

## Documentation

### README.md

```text
#### FullBarrelShifterPlugin

Implements SLL/SRL/SRA instructions by using a full barrel shifter, so it executes all shifts in a single cycle.

| Parameters | type | description |
| ------ | ----------- | ------ |
| earlyInjection | Boolean | By default the result of the shift is injected into the pipeline in the Memory stage to relax timings, but if this option is true it will be done in the Execute stage |
```

### src/rv32.adoc

```text
Shifts by a constant are encoded as a specialization of the I-type
format. The operand to be shifted is in _rs1_, and the shift amount is
encoded in the lower 5 bits of the I-immediate field. The right shift
type is encoded in bit 30. SLLI is a logical left shift (zeros are
shifted into the lower bits); SRLI is a logical right shift (zeros are
shifted into the upper bits); and SRAI is an arithmetic right shift (the
original sign bit is copied into the vacated upper bits).
...
SLL, SRL, and SRA perform logical left, logical right, and arithmetic
right shifts on the value in register _rs1_ by the shift amount held in
the lower 5 bits of register _rs2_.
```
