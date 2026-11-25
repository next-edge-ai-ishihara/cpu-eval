# Implement `VexRiscv`

Implement the complete `VexRiscv` class. Keep the configuration, pipeline, stage, and plugin definitions fixed.

Return only the complete `class VexRiscv` definition in a single Scala code block, with no text outside the block.

## Class declaration

### src/main/scala/vexriscv/VexRiscv.scala

```scala
package vexriscv

import vexriscv.plugin._
import spinal.core._

import scala.collection.mutable.ArrayBuffer
import scala.collection.Seq
// ...
class VexRiscv(val config : VexRiscvConfig) extends Component with Pipeline{
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
      //Generate RTL
      FileUtils.deleteQuietly(new File("VexRiscv.v"))
      SpinalConfig(targetDirectory = project).generateVerilog{
        val config = VexRiscvConfig(
          withMemoryStage = !noMemory,
          withWriteBackStage = !noWriteback,
          plugins = List(
            new IntAluPlugin,
            new YamlPlugin("cpu0.yaml")
          )
        )
        for (positionToApply <- positionsToApply) positionToApply.applyOn(config)
        new VexRiscv(config)
      }
```

## Dependency declarations

### src/main/scala/vexriscv/VexRiscv.scala

```scala
object VexRiscvConfig{
  def apply(withMemoryStage : Boolean, withWriteBackStage : Boolean, plugins : Seq[Plugin[VexRiscv]]): VexRiscvConfig = {
    val config = VexRiscvConfig()
    config.plugins ++= plugins
    config.withMemoryStage = withMemoryStage
    config.withWriteBackStage = withWriteBackStage
    config
  }

  def apply(plugins : Seq[Plugin[VexRiscv]] = ArrayBuffer()) : VexRiscvConfig = apply(true,true,plugins)
}
trait VexRiscvRegressionArg{
  def getVexRiscvRegressionArgs() : Seq[String]
}
case class VexRiscvConfig(){
  var withMemoryStage = true
  var withWriteBackStage = true
  val plugins = ArrayBuffer[Plugin[VexRiscv]]()

  def add(that : Plugin[VexRiscv]) : this.type = {plugins += that;this}
  def find[T](clazz: Class[T]): Option[T] = {
    plugins.find(_.getClass == clazz) match {
      case Some(x) => Some(x.asInstanceOf[T])
      case None => None
    }
  }
  def get[T](clazz: Class[T]): T = {
    plugins.find(_.getClass == clazz) match {
      case Some(x) => x.asInstanceOf[T]
    }
  }

  def withRvc = plugins.find(_.isInstanceOf[IBusFetcher]) match {
    case Some(x) => x.asInstanceOf[IBusFetcher].withRvc
    case None => false
  }

  def withRvf = find(classOf[FpuPlugin]) match {
    case Some(x) => true
    case None => false
  }

  def withRvd = find(classOf[FpuPlugin]) match {
    case Some(x) => x.p.withDouble
    case None => false
  }

  def withSupervisor = find(classOf[CsrPlugin]) match {
    case Some(x) => x.config.supervisorGen
    case None => false
  }

  def FLEN = if(withRvd) 64 else if(withRvf) 32 else 0

  //Default Stageables
  object IS_RVC extends Stageable(Bool)
  object BYPASSABLE_EXECUTE_STAGE   extends Stageable(Bool)
  object BYPASSABLE_MEMORY_STAGE   extends Stageable(Bool)
  object RS1   extends Stageable(Bits(32 bits))
  object RS2   extends Stageable(Bits(32 bits))
  object RS1_USE extends Stageable(Bool)
  object RS2_USE extends Stageable(Bool)
  object RESULT extends Stageable(UInt(32 bits))
  object PC extends Stageable(UInt(32 bits))
  object PC_CALC_WITHOUT_JUMP extends Stageable(UInt(32 bits))
  object INSTRUCTION extends Stageable(Bits(32 bits))
  object INSTRUCTION_ANTICIPATED extends Stageable(Bits(32 bits))
  object LEGAL_INSTRUCTION extends Stageable(Bool)
  object REGFILE_WRITE_VALID extends Stageable(Bool)
  object REGFILE_WRITE_DATA extends Stageable(Bits(32 bits))

  object MPP extends PipelineThing[UInt]
  object DEBUG_BYPASS_CACHE extends PipelineThing[Bool]

  object SRC1   extends Stageable(Bits(32 bits))
  object SRC2   extends Stageable(Bits(32 bits))
  object SRC_ADD_SUB extends Stageable(Bits(32 bits))
  object SRC_ADD extends Stageable(Bits(32 bits))
  object SRC_SUB extends Stageable(Bits(32 bits))
  object SRC_LESS extends Stageable(Bool)
  object SRC_USE_SUB_LESS extends Stageable(Bool)
  object SRC_LESS_UNSIGNED extends Stageable(Bool)
  object SRC_ADD_ZERO extends Stageable(Bool)


  object HAS_SIDE_EFFECT extends Stageable(Bool)

  //Formal verification purposes
  object FORMAL_HALT       extends Stageable(Bool)
  object FORMAL_PC_NEXT    extends Stageable(UInt(32 bits))
  object FORMAL_MEM_ADDR   extends Stageable(UInt(32 bits))
  object FORMAL_MEM_RMASK  extends Stageable(Bits(4 bits))
  object FORMAL_MEM_WMASK  extends Stageable(Bits(4 bits))
  object FORMAL_MEM_RDATA  extends Stageable(Bits(32 bits))
  object FORMAL_MEM_WDATA  extends Stageable(Bits(32 bits))
  object FORMAL_INSTRUCTION extends Stageable(Bits(32 bits))
  object FORMAL_MODE       extends Stageable(Bits(2 bits))


  object Src1CtrlEnum extends SpinalEnum(binarySequential){
    val RS, IMU, PC_INCREMENT, URS1 = newElement()   //IMU, IMZ IMJB
  }

  object Src2CtrlEnum extends SpinalEnum(binarySequential){
    val RS, IMI, IMS, PC = newElement() //TODO remplacing ZERO could avoid 32 muxes if SRC_ADD can be disabled
  }
  object SRC1_CTRL  extends Stageable(Src1CtrlEnum())
  object SRC2_CTRL  extends Stageable(Src2CtrlEnum())

  def getRegressionArgs() : Seq[String] = {
    val str = ArrayBuffer[String]()
    plugins.foreach{
      case e : VexRiscvRegressionArg => str ++= e.getVexRiscvRegressionArgs()
      case _ =>
    }
    str
  }
}
```

### src/main/scala/vexriscv/Pipeline.scala

```scala
trait PipelineThing[T]

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

  def build(): Unit ={
    plugins.foreach(_.pipeline = this.asInstanceOf[T])
    plugins.foreach(_.setup(this.asInstanceOf[T]))

    plugins.foreach{ p =>
      p.parentScope = Component.current.dslBody //Put the given plugin as a child of the current component
      p.reflectNames()
    }

    //Build plugins
    plugins.foreach(_.build(this.asInstanceOf[T]))



    //Interconnect stages
    class KeyInfo{
      var insertStageId = Int.MaxValue
      var lastInputStageId = Int.MinValue
      var lastOutputStageId = Int.MinValue

      def addInputStageIndex(stageId : Int): Unit = {
        require(stageId >= insertStageId)
        lastInputStageId = Math.max(lastInputStageId,stageId)
        lastOutputStageId = Math.max(lastOutputStageId,stageId-1)
      }


      def addOutputStageIndex(stageId : Int): Unit = {
        require(stageId >= insertStageId)
        lastInputStageId = Math.max(lastInputStageId,stageId)
        lastOutputStageId = Math.max(lastOutputStageId,stageId)
      }

      def setInsertStageId(stageId : Int) = insertStageId = stageId
    }

    val inputOutputKeys = mutable.LinkedHashMap[Stageable[Data],KeyInfo]()
    val insertedStageable = mutable.Set[Stageable[Data]]()
    for(stageIndex <- 0 until stages.length; stage = stages(stageIndex)){
      stage.inserts.keysIterator.foreach(signal => inputOutputKeys.getOrElseUpdate(signal,new KeyInfo).setInsertStageId(stageIndex))
      stage.inserts.keysIterator.foreach(insertedStageable += _)
    }

    val missingInserts = mutable.Set[Stageable[Data]]()
    for(stageIndex <- 0 until stages.length; stage = stages(stageIndex)){
      stage.inputs.keysIterator.foreach(key => if(!insertedStageable.contains(key)) missingInserts += key)
      stage.outputs.keysIterator.foreach(key => if(!insertedStageable.contains(key)) missingInserts += key)
    }

    if(missingInserts.nonEmpty){
      throw new Exception("Missing inserts : " + missingInserts.map(_.getName()).mkString(", "))
    }

    for(stageIndex <- 0 until stages.length; stage = stages(stageIndex)){
      stage.inputs.keysIterator.foreach(key => inputOutputKeys.getOrElseUpdate(key,new KeyInfo).addInputStageIndex(stageIndex))
      stage.outputs.keysIterator.foreach(key => inputOutputKeys.getOrElseUpdate(key,new KeyInfo).addOutputStageIndex(stageIndex))
    }

    for((key,info) <- inputOutputKeys) {
      //Interconnect inputs -> outputs
      for (stageIndex <- info.insertStageId to info.lastOutputStageId;
           stage = stages(stageIndex)) {
        stage.output(key)
        val outputDefault = stage.outputsDefault.getOrElse(key, null)
        if (outputDefault != null) {
          outputDefault := stage.input(key)
        }
      }

      //Interconnect outputs -> inputs
      for (stageIndex <- info.insertStageId to info.lastInputStageId) {
        val stage = stages(stageIndex)
        stage.input(key)
        val inputDefault = stage.inputsDefault.getOrElse(key, null)
        if (inputDefault != null) {
          if (stageIndex == info.insertStageId) {
            inputDefault := stage.inserts(key)
          } else {
            val stageBefore = stages(stageIndex - 1)
            inputDefault := RegNextWhen(stageBefore.output(key), stage.dontSample.getOrElse(key, Nil).foldLeft(!stage.arbitration.isStuck)(_ && !_)).setName(s"${stageBefore.getName()}_to_${stage.getName()}_${key.getName()}")
          }
        }
      }
    }

    //Arbitration
    for(stageIndex <- 0 until stages.length; stage = stages(stageIndex)) {
      stage.arbitration.isFlushed := stages.drop(stageIndex+1).map(_.arbitration.flushNext).orR || stages.drop(stageIndex).map(_.arbitration.flushIt).orR
      if(!unremovableStages.contains(stage))
        stage.arbitration.removeIt setWhen stage.arbitration.isFlushed
      else
        assert(stage.arbitration.removeIt === False,"removeIt should never be asserted on this stage")

    }

    for(stageIndex <- 0 until stages.length; stage = stages(stageIndex)){
      stage.arbitration.isStuckByOthers := stage.arbitration.haltByOther || stages.takeRight(stages.length - stageIndex - 1).map(s => s.arbitration.isStuck/* && !s.arbitration.removeIt*/).foldLeft(False)(_ || _)
      stage.arbitration.isStuck := stage.arbitration.haltItself || stage.arbitration.isStuckByOthers
      stage.arbitration.isMoving := !stage.arbitration.isStuck && !stage.arbitration.removeIt
      stage.arbitration.isFiring := stage.arbitration.isValid && !stage.arbitration.isStuck && !stage.arbitration.removeIt
    }

    for(stageIndex <- 1 until stages.length){
      val stageBefore = stages(stageIndex - 1)
      val stage = stages(stageIndex)
      stage.arbitration.isValid.setAsReg() init(False)
      when(!stage.arbitration.isStuck || stage.arbitration.removeIt) {
        stage.arbitration.isValid := False
      }
      when(!stageBefore.arbitration.isStuck && !stageBefore.arbitration.removeIt) {
        stage.arbitration.isValid := stageBefore.arbitration.isValid
      }
    }
  }


  Component.current.addPrePopTask(() => build())
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

### src/main/scala/vexriscv/plugin/RegFilePlugin.scala

```scala
  override def readStage(): Stage = if(readInExecute) pipeline.execute else pipeline.decode
// ...
      val regFileWrite = global.regFile.writePort.addAttribute(Verilator.public).setName("lastStageRegFileWrite")
```

### src/main/scala/vexriscv/plugin/BranchPlugin.scala

```scala
  def catchAddressMisalignedForReal = catchAddressMisaligned && !pipeline.config.withRvc
  lazy val branchStage = if(earlyBranch) pipeline.execute else pipeline.memory
// ...
    if(fenceiGenAsAJump) {
      import pipeline._
      import pipeline.config._
      when(decode.input(IS_FENCEI)) {
        decode.output(INSTRUCTION)(12) := False
        decode.output(INSTRUCTION)(22) := True
      }
      execute.arbitration.haltByOther setWhen(execute.arbitration.isValid && execute.input(IS_FENCEI) && stagesFromExecute.tail.map(_.arbitration.isValid).asBits.orR)
    }
```

### src/main/scala/vexriscv/plugin/DBusCachedPlugin.scala

```scala
    mmuBus = pipeline.service(classOf[MemoryTranslator]).newTranslationPort(MemoryTranslatorPort.PRIORITY_DATA ,memoryTranslatorPortConfig)
    redoBranch = pipeline.service(classOf[JumpService]).createJumpInterface(if(pipeline.writeBack != null) pipeline.writeBack else pipeline.memory)

    if(catchSomething)
      exceptionBus = pipeline.service(classOf[ExceptionService]).newExceptionPort(if(pipeline.writeBack == null) pipeline.memory else pipeline.writeBack)
```

### src/test/cpp/regression/main.cpp

```cpp
                if(top->VexRiscv->lastStageIsFiring){
                   	if(riscvRefEnable) {
//                        privilegeCounters[riscvRef.privilege]++;
//                        if((riscvRef.stepCounter & 0xFFFFF) == 0){
//                            cout << "privilege report" << endl;
//                            cout << "- U " << privilegeCounters[0] << endl;
//                            cout << "- S " << privilegeCounters[1] << endl;
//                            cout << "- M " << privilegeCounters[3] << endl;
//                        }
                        riscvRef.dutRfWriteValue = top->VexRiscv->lastStageRegFileWrite_payload_data;
                   	    riscvRef.step();
                   	    bool mIntTimer = false;
                   	    bool mIntExt = false;
                   	}

                   	if(riscvRefEnable && top->VexRiscv->lastStagePc != riscvRef.lastPc){
						cout << hex << " pc missmatch " << top->VexRiscv->lastStagePc << " should be " << riscvRef.lastPc << dec << endl;
						fail();
					}
// ...
	virtual void checks(){
		if(top->VexRiscv->lastStageIsFiring && top->VexRiscv->lastStageInstruction == 0x00000013){
			uint32_t instruction;
			bool error;
			Workspace::mem.read(top->VexRiscv->lastStagePc, 4, (uint8_t*)&instruction);
			//printf("%x => %x\n", top->VexRiscv->lastStagePc, instruction );
// ...
```

## Documentation

### README.md

```text
## VexRiscv Architecture

VexRiscv is implemented via a 5 stage in-order pipeline on which many optional and complementary plugins add functionalities to provide a functional RISC-V CPU.
This approach is completely unconventional and only possible through meta hardware description languages (SpinalHDL, in the current case) but has proven its advantages
via the VexRiscv implementation:

- You can swap/turn on/turn off parts of the CPU directly via the plugin system
- You can add new functionalities/instructions without having to modify any of the sources of the CPU
- It allows the CPU configuration to cover a very large spectrum of implementations without cooking spaghetti code
- It allows your codebase to truly produce a parametrized CPU design

If you generate the CPU without any plugin, it will only contain the definition of the 5 pipeline stages and their basic arbitration, but nothing else,
and everything else, including the program counter is added into the CPU via plugins.
```

## Additional requirement

The generated Verilator model must contain the public signals `lastStageIsFiring`, `lastStagePc` and `lastStageInstruction` that the fixed C++ regression reads.
