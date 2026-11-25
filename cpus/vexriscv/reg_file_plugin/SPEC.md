# Implement `RegFilePlugin`

Implement the complete `RegFilePlugin` class. Keep the read-kind definitions fixed.

Return only the complete `class RegFilePlugin` definition in a single Scala code block, with no text outside the block.

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

### src/main/scala/vexriscv/plugin/RegFilePlugin.scala

```scala
package vexriscv.plugin

import vexriscv._
import spinal.core._
import spinal.lib._

import scala.collection.mutable
// ...
class RegFilePlugin(regFileReadyKind : RegFileReadKind,
                    zeroBoot : Boolean = false,
                    x0Init : Boolean = true,
                    writeRfInMemoryStage : Boolean = false,
                    readInExecute : Boolean = false,
                    syncUpdateOnStall : Boolean = true,
                    rv32e : Boolean = false,
                    withShadow : Boolean = false //shadow registers aren't transition hazard free
                   ) extends Plugin[VexRiscv] with RegFileService{
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
class RegFileDimension extends VexRiscvDimension("RegFile") {
  override def randomPositionImpl(universes: Seq[ConfigUniverse], r: Random) = {
    val executeRf = universes.contains(VexRiscvUniverse.EXECUTE_RF)
    random(r, List(
// ...
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

## Dependency declarations

### src/main/scala/vexriscv/plugin/RegFilePlugin.scala

```scala
trait RegFileReadKind
object ASYNC extends RegFileReadKind
object SYNC extends RegFileReadKind
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
  object RS1   extends Stageable(Bits(32 bits))
  object RS2   extends Stageable(Bits(32 bits))
  object RS1_USE extends Stageable(Bool)
  object RS2_USE extends Stageable(Bool)
// ...
  object INSTRUCTION extends Stageable(Bits(32 bits))
  object INSTRUCTION_ANTICIPATED extends Stageable(Bits(32 bits))
// ...
  object REGFILE_WRITE_VALID extends Stageable(Bool)
  object REGFILE_WRITE_DATA extends Stageable(Bits(32 bits))
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
// ...
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
  override def build(pipeline: VexRiscv): Unit = {
    import pipeline.config._
    import pipeline.decode._

    val stageables = (encodings.flatMap(_._2.map(_._1)) ++ defaults.map(_._1)).toList.distinct


    if(stupidDecoder){
// ...
    } else {
      var offset = 0
      var defaultValue, defaultCare = BigInt(0)
      val offsetOf = mutable.LinkedHashMap[Stageable[_ <: BaseType], Int]()

      //Build defaults value and field offset map
      stageables.foreach(e => {
        defaults.get(e) match {
          case Some(value) => {
            value.head.source match {
              case literal: EnumLiteral[_] => literal.fixEncoding(e.dataType.asInstanceOf[SpinalEnumCraft[_]].getEncoding)
              case _ =>
            }
            defaultValue += value.head.source.asInstanceOf[Literal].getValue << offset
            defaultCare += ((BigInt(1) << e.dataType.getBitsWidth) - 1) << offset

          }
          case _ =>
        }
        offsetOf(e) = offset
        offset += e.dataType.getBitsWidth
      })

      //Build spec
      val spec = encodings.map { case (key, values) =>
        var decodedValue = defaultValue
        var decodedCare = defaultCare
        for ((e, literal) <- values) {
          literal.head.source match {
            case literal: EnumLiteral[_] => literal.fixEncoding(e.dataType.asInstanceOf[SpinalEnumCraft[_]].getEncoding)
            case _ =>
          }
          val offset = offsetOf(e)
          decodedValue |= literal.head.source.asInstanceOf[Literal].getValue << offset
          decodedCare |= ((BigInt(1) << e.dataType.getBitsWidth) - 1) << offset
        }
        (Masked(key.value, key.careAbout), Masked(decodedValue, decodedCare))
      }


      // logic implementation
      val decodedBits = Bits(stageables.foldLeft(0)(_ + _.dataType.getBitsWidth) bits)
      decodedBits := Symplify(input(INSTRUCTION), spec, decodedBits.getWidth)
// ...
}
```

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
class DecoderDimension extends VexRiscvDimension("Decoder") {

  override def randomPositionImpl(universes: Seq[ConfigUniverse], r: Random) = {
    val catchAll = universes.contains(VexRiscvUniverse.CATCH_ALL)
    new VexRiscvPosition("") {
      override def applyOn(config: VexRiscvConfig): Unit = config.plugins += new DecoderSimplePlugin(
        catchIllegalInstruction = catchAll,
        throwIllegalInstruction = false
      )

//      override def isCompatibleWith(positions: Seq[ConfigPosition[VexRiscvConfig]]) = catchAll == positions.exists(_.isInstanceOf[CatchAllPosition])
    }
  }
}
```

### src/test/cpp/regression/main.cpp

```cpp
        //Sync register file initial content
        for(int i = 1;i < 32;i++){
            riscvRef.regs[i] = top->VexRiscv->RegFilePlugin_regFile[i];
        }
// ...
                	bool rfWriteValid = false;
                	int32_t rfWriteAddress;
                	int32_t rfWriteData;

                    if(top->VexRiscv->lastStageRegFileWrite_valid == 1 && top->VexRiscv->lastStageRegFileWrite_payload_address != 0){
                    	rfWriteValid = true;
                    	rfWriteAddress = top->VexRiscv->lastStageRegFileWrite_payload_address;
                    	rfWriteData = top->VexRiscv->lastStageRegFileWrite_payload_data;
// ...
                    }
					if(riscvRefEnable) if(rfWriteValid != riscvRef.rfWriteValid ||
						(rfWriteValid && (rfWriteAddress!= riscvRef.rfWriteAddress || rfWriteData!= riscvRef.rfWriteData))){
                    	cout << "regFile write missmatch :" << endl;
                    	if(rfWriteValid) cout << " REF: RF[" << riscvRef.rfWriteAddress << "] = 0x" << hex << riscvRef.rfWriteData << dec << endl;
                    	if(rfWriteValid) cout << " DUT: RF[" << rfWriteAddress << "] = 0x" << hex << rfWriteData << dec << endl;
                    	fail();
                    }
```

## Documentation

### README.md

```text
#### RegFilePlugin

This plugin implements the register file.

| Parameters | type | description |
| ------ | ----------- | ------ |
| regFileReadyKind | RegFileReadKind | Can be set to ASYNC or SYNC. Specifies the kind of memory read used to implement the register file. ASYNC means zero cycle latency memory read, while SYNC means one cycle latency memory read which can be mapped into standard FPGA memory blocks   |
| zeroBoot | Boolean | Load all registers with zeroes at the beginning of the simulation to keep everything deterministic in logs/traces|

This register file use a `don't care` read-during-write policy, so the bypassing/hazard plugin should take care of this.

If you get a `Missing inserts : INSTRUCTION_ANTICIPATE` error, that's because the RegFilePlugin is configured to use SYNC memory read ports to access the register file, but the IBus plugin configuration can't provide the instruction's register file read address one cycle before the decode stage. To workaround that you can :

- Configure the RegFilePlugin to implement the register file read in a asyncronus manner (ASYNC), if your target device support such things
- If you use the IBusSimplePlugin, you need to enable the injectorStage configuration
- If you use the IBusCachedPlugin, you can either enable the injectorStage, or set twoCycleCache + twoCycleRam to false.
```

### src/rv32.adoc

```text
=== Programmers' Model for Base Integer ISA

<<gprs>> shows the unprivileged state for the base
integer ISA. For RV32I, the 32 `x` registers are each 32 bits wide,
i.e., `XLEN=32`. Register `x0` is hardwired with all bits equal to 0.
General purpose registers `x1-x31` hold values that various
instructions interpret as a collection of Boolean values, or as two's
complement signed binary integers or unsigned binary integers.
```

## Additional requirement

The generated Verilator model must contain the public signals `RegFilePlugin_regFile`, `lastStageRegFileWrite_valid`, `lastStageRegFileWrite_payload_address` and `lastStageRegFileWrite_payload_data` that the fixed C++ regression reads.
