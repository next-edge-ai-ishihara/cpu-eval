# Implement `HazardSimplePlugin`

Implement the complete `HazardSimplePlugin` class. Keep the `HazardService` definition fixed.

Return only the complete `class HazardSimplePlugin` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### cpus/vexriscv/REGRESSION_CONFIGURATION.txt

```text
VexRiscvConfig
  withMemoryStage = true
  withWriteBackStage = false
...
RegFile SyncDR
  executeRf = false
  regFileReadyKind = plugin.SYNC
```

## Class declaration

### src/main/scala/vexriscv/plugin/HazardSimplePlugin.scala

```scala
package vexriscv.plugin

import vexriscv._
import spinal.core._
import spinal.lib._
// ...
class HazardSimplePlugin(bypassExecute : Boolean = false,
                         bypassMemory: Boolean = false,
                         bypassWriteBack: Boolean = false,
                         bypassWriteBackBuffer : Boolean = false,
                         pessimisticUseSrc : Boolean = false,
                         pessimisticWriteRegFile : Boolean = false,
                         pessimisticAddressMatch : Boolean = false) extends Plugin[VexRiscv] with HazardService{
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
        new VexRiscvPosition("Interlock") {
          override def applyOn(config: VexRiscvConfig): Unit = config.plugins += new HazardSimplePlugin(
            bypassExecute = false,
            bypassMemory = false,
            bypassWriteBack = false,
            bypassWriteBackBuffer = false,
            pessimisticUseSrc = false,
            pessimisticWriteRegFile = false,
            pessimisticAddressMatch = false
          )
        },
```

## Dependency declarations

### src/main/scala/vexriscv/plugin/HazardSimplePlugin.scala

```scala
trait HazardService{
  def hazardOnExecuteRS : Bool
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
// ...
trait RegFileService{
  def readStage() : Stage
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
  object INSTRUCTION extends Stageable(Bits(32 bits))
// ...
  object REGFILE_WRITE_VALID extends Stageable(Bool)
  object REGFILE_WRITE_DATA extends Stageable(Bits(32 bits))
// ...
  object HAS_SIDE_EFFECT extends Stageable(Bool)
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
  def rdRange = 11 downto 7
  def funct3Range = 14 downto 12
  def rs1Range = 19 downto 15
  def rs2Range = 24 downto 20
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

## Related source code

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
class RegFileDimension extends VexRiscvDimension("RegFile") {
  override def randomPositionImpl(universes: Seq[ConfigUniverse], r: Random) = {
    val executeRf = universes.contains(VexRiscvUniverse.EXECUTE_RF)
    random(r, List(
      new VexRiscvPosition("Async" + (if(executeRf) "ER" else "DR")) {
        override def applyOn(config: VexRiscvConfig): Unit = config.plugins += new RegFilePlugin(
          regFileReadyKind = plugin.ASYNC,
          zeroBoot = true,
          readInExecute = executeRf
        )
      },
      new VexRiscvPosition("Sync" + (if(executeRf) "ER" else "DR")) {
        override def applyOn(config: VexRiscvConfig): Unit = config.plugins += new RegFilePlugin(
          regFileReadyKind = plugin.SYNC,
          zeroBoot = true,
          readInExecute = executeRf
        )

        override def isCompatibleWith(positions: Seq[ConfigPosition[VexRiscvConfig]]) = executeRf || positions.exists{
          case p : InstructionAnticipatedPosition => p.instructionAnticipatedOk()
          case _ => false
        }
      }
    ))
  }
}
```

### src/main/scala/vexriscv/plugin/RegFilePlugin.scala

```scala
class RegFilePlugin(regFileReadyKind : RegFileReadKind,
                    zeroBoot : Boolean = false,
                    x0Init : Boolean = true,
                    writeRfInMemoryStage : Boolean = false,
                    readInExecute : Boolean = false,
                    syncUpdateOnStall : Boolean = true,
                    rv32e : Boolean = false,
                    withShadow : Boolean = false //shadow registers aren't transition hazard free
                   ) extends Plugin[VexRiscv] with RegFileService{
  import Riscv._

  override def readStage(): Stage = if(readInExecute) pipeline.execute else pipeline.decode
// ...
```

### src/main/scala/vexriscv/plugin/BranchPlugin.scala

```scala
  def hasHazardOnBranch = if(earlyBranch) pipeline.service(classOf[HazardService]).hazardOnExecuteRS else False
```

### src/main/scala/vexriscv/plugin/MulDivIterativePlugin.scala

```scala
      //FrontendOK is only used for CPU configs without memory/writeback stages, were it is required to wait one extra cycle
      // to let's the frontend process rs1 rs2 registers
      val frontendOk = if(flushStage != execute) True else RegInit(False) setWhen(arbitration.isValid && !pipeline.service(classOf[HazardService]).hazardOnExecuteRS && ((if(genDiv) input(IS_DIV) else False) || (if(genMul) input(IS_MUL) else False))) clearWhen(arbitration.isMoving)
```

## Documentation

### README.md

```text
#### HazardSimplePlugin

This plugin checks the pipeline instruction dependencies and, if necessary or possible, will stop the instruction in the decoding stage or bypass the instruction results
from the later stages of the decode stage.

Since the register file is implemented with a `don't care` read-during-write policy, this plugin also manages these kind of hazards.

| Parameters | type | description |
| ------ | ----------- | ------ |
| bypassExecute | Boolean | Enable the bypassing of instruction results coming from the Execute stage |
| bypassMemory | Boolean | Enable the bypassing of instruction results coming from the Memory stage |
| bypassWriteBack | Boolean | Enable the bypassing of instruction results coming from the WriteBack stage |
| bypassWriteBackBuffer | Boolean | Enable the bypassing of the previous cycle register file written value  |
```
