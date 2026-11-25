# Implement `DebugPlugin`

Implement the complete `DebugPlugin` class. Keep the debug-bus types and CPU service interfaces fixed.

Return only the complete `class DebugPlugin` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### cpus/vexriscv/REGRESSION_CONFIGURATION.txt

```text
VexRiscvConfig
  withMemoryStage = true
  withWriteBackStage = false
```

## Class declaration

### src/main/scala/vexriscv/plugin/DebugPlugin.scala

```scala
package vexriscv.plugin

import spinal.lib.com.jtag.{Jtag, JtagTapInstructionCtrl}
import spinal.lib.system.debugger.{JtagBridge, JtagBridgeNoTap, VJtagBridge, SystemDebugger, SystemDebuggerConfig, SystemDebuggerMemBus}
import vexriscv.plugin.IntAluPlugin.{ALU_CTRL, AluCtrlEnum}
import vexriscv._
import vexriscv.ip._
import spinal.core._
import spinal.lib._
import spinal.lib.blackbox.xilinx.s7.BSCANE2
import spinal.lib.bus.amba3.apb.{Apb3, Apb3Config}
import spinal.lib.bus.avalon.{AvalonMM, AvalonMMConfig}
import spinal.lib.bus.bmb.{Bmb, BmbAccessCapabilities, BmbAccessParameter, BmbParameter}
import spinal.lib.bus.simple.PipelinedMemoryBus

import scala.collection.mutable.ArrayBuffer
// ...
class DebugPlugin(var debugClockDomain : ClockDomain, hardwareBreakpointCount : Int = 0, BreakpointReadback : Boolean = false) extends Plugin[VexRiscv] {
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
    new VexRiscvPosition("Enable") {
      override def applyOn(config: VexRiscvConfig): Unit = config.plugins += new DebugPlugin(ClockDomain.current.clone(reset = Bool().setName("debugReset")))
// ...
```

## Dependency declarations

### src/main/scala/vexriscv/plugin/DebugPlugin.scala

```scala
case class DebugExtensionCmd() extends Bundle{
  val wr = Bool
  val address = UInt(8 bit)
  val data = Bits(32 bit)
}
case class DebugExtensionRsp() extends Bundle{
  val data = Bits(32 bit)
}
// ...
case class DebugExtensionBus() extends Bundle with IMasterSlave{
  val cmd = Stream(DebugExtensionCmd())
  val rsp = DebugExtensionRsp() //one cycle latency

  override def asMaster(): Unit = {
    master(cmd)
    in(rsp)
  }
// ...
}

case class DebugExtensionIo() extends Bundle with IMasterSlave{
  val bus = DebugExtensionBus()
  val resetOut = Bool

  override def asMaster(): Unit = {
    master(bus)
    in(resetOut)
  }
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
trait IBusFetcher{
  def haltIt() : Unit
  def incoming() : Bool
  def pcValid(stage : Stage) : Bool
  def getInjectionPort() : Stream[Bits]
  def withRvc() : Boolean
  def forceNoDecode() : Unit
}


trait DecoderService{
  def add(key : MaskedLiteral,values : Seq[(Stageable[_ <: BaseType],Any)])
  def add(encoding :Seq[(MaskedLiteral,Seq[(Stageable[_ <: BaseType],Any)])])
  def addDefault(key : Stageable[_ <: BaseType], value : Any)
  def forceIllegal() : Unit
}
// ...
trait PrivilegeService{
  def isUser() : Bool
  def isSupervisor() : Bool
  def isMachine() : Bool
  def forceMachine() : Unit
// ...
}
// ...
trait InterruptionInhibitor{
  def inhibateInterrupts() : Unit
}

trait ExceptionInhibitor{
  def inhibateException() : Unit
  def inhibateEbreakException() : Unit
}
// ...
trait ReportService{
  def add(that : (String,Object)) : Unit
}
// ...
class DebugReport {
  @BeanProperty var hardwareBreakpointCount = 0
}
```

### src/main/scala/vexriscv/plugin/CsrPlugin.scala

```scala
trait IWake{
  def askWake() : Unit
}
```

### src/main/scala/vexriscv/plugin/BranchPlugin.scala

```scala
trait PredictionInterface{
// ...
  def inDebugNoFetch() : Unit
}
```

### src/main/scala/vexriscv/VexRiscv.scala

```scala
case class VexRiscvConfig(){
// ...
  object PC extends Stageable(UInt(32 bits))
// ...
  object REGFILE_WRITE_DATA extends Stageable(Bits(32 bits))
// ...
  object DEBUG_BYPASS_CACHE extends PipelineThing[Bool]
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
  def EBREAK             = M"00000000000100000000000001110011"
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
  val things = mutable.LinkedHashMap[PipelineThing[_], Any]()
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

  def serviceElse[T](clazz : Class[T], default : => T) : T = {
    if(!serviceExist(clazz)) return default
    val filtered = plugins.filter(o => clazz.isAssignableFrom(o.getClass))
    assert(filtered.length == 1)
    filtered.head.asInstanceOf[T]
  }
// ...
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

## Related source code

### src/main/scala/vexriscv/TestsWorkspace.scala

```scala
          case plugin: DebugPlugin => {
            plugin.io.bus.asDirectionLess()
            slave(plugin.io.bus.fromAvalon())
              .setName("debugBusAvalon")
              .addTag(ClockDomainTag(plugin.debugClockDomain))
              .parent = null  //Avoid the io bundle to be interpreted as a QSys conduit
            plugin.io.resetOut
              .addTag(ResetEmitterTag(plugin.debugClockDomain))
              .parent = null //Avoid the io bundle to be interpreted as a QSys conduit
          }
```

### src/test/cpp/regression/main.cpp

```cpp
class DebugPlugin : public SimElement{
// ...
	virtual void postCycle(){
		top->reset = top->debug_resetOut;
// ...
};
// ...
class DebugPluginStd : public DebugPlugin{
public:
	DebugPluginStd(Workspace* ws) : DebugPlugin(ws){

	}

	virtual void onReset(){
		DebugPlugin::onReset();
		top->debug_bus_cmd_valid = 0;
	}

	bool rspFire = false;

	virtual void preCycle(){
		DebugPlugin::preCycle();

		if(rspFire){
			sendRsp(top->debug_bus_rsp_data);
			rspFire = false;
		}

		if(top->debug_bus_cmd_valid && top->debug_bus_cmd_ready){
			taskValid = false;
			if(!top->debug_bus_cmd_payload_wr){
				rspFire = true;
			}
		}
	}

	virtual void postCycle(){
		DebugPlugin::postCycle();

		if(taskValid){
			top->debug_bus_cmd_valid = 1;
			top->debug_bus_cmd_payload_wr = task.wr;
			top->debug_bus_cmd_payload_address = task.address;
			top->debug_bus_cmd_payload_data = task.data;
		}else {
			top->debug_bus_cmd_valid = 0;
			top->debug_bus_cmd_payload_wr = VL_RANDOM_I_WIDTH(1);
			top->debug_bus_cmd_payload_address = VL_RANDOM_I_WIDTH(8);
			top->debug_bus_cmd_payload_data = VL_RANDOM_I_WIDTH(32);
		}
	}
};
// ...
class DebugPluginTest : public WorkspaceRegression{
public:
// ...
	void clientThread(){
// ...
		uint32_t debugAddress = 0xF00F0000;
		uint32_t readValue;

		while(resetDone != true){usleep(100);}

		while((readCmd(2,debugAddress) & RISCV_SPINAL_FLAGS_HALT) == 0){usleep(100);}
		if((readValue = readCmd(2,debugAddress + 4)) != 0x8000000C){
			printf("wrong breakA PC %x\n",readValue);
			clientFail = true; return;
		}

		writeCmd(2, debugAddress + 4, 0x13 + (1 << 15)); //Read regfile
		if((readValue = readCmd(2,debugAddress + 4)) != 10){
			printf("wrong breakB PC %x\n",readValue);
			clientFail = true; return;
		}

		writeCmd(2, debugAddress + 4, 0x13 + (2 << 15)); //Read regfile
		if((readValue = readCmd(2,debugAddress + 4)) != 20){
			printf("wrong breakC PC %x\n",readValue);
			clientFail = true; return;
		}

		writeCmd(2, debugAddress + 4, 0x13 + (3 << 15)); //Read regfile
		if((readValue = readCmd(2,debugAddress + 4)) != 30){
			printf("wrong breakD PC %x\n",readValue);
			clientFail = true; return;
		}
// ...
```

## Documentation

### README.md

````text
#### DebugPlugin

This plugin implements enough CPU debug features to allow comfortable GDB/Eclipse debugging. To access those debug features, it provides a simple memory bus interface.
The JTAG interface is provided by another bridge, which makes it possible to efficiently connect multiple CPUs to the same JTAG.

| Parameters | type | description |
| ------ | ----------- | ------ |
| debugClockDomain   | ClockDomain | As the debug unit is able to reset the CPU itself, it should use another clock domain to avoid killing itself (only the reset wire should differ) |

The internals of the debug plugin are done in a manner which reduces the area usage and the FMax impact of this plugin.

Here is the simple bus to access it, the rsp comes one cycle after the request:

```scala
case class DebugExtensionCmd() extends Bundle{
  val wr = Bool
  val address = UInt(8 bit)
  val data = Bits(32 bit)
}
case class DebugExtensionRsp() extends Bundle{
  val data = Bits(32 bit)
}

case class DebugExtensionBus() extends Bundle with IMasterSlave{
  val cmd = Stream(DebugExtensionCmd())
  val rsp = DebugExtensionRsp()

  override def asMaster(): Unit = {
    master(cmd)
    in(rsp)
  }
}
```


Here is the register mapping:

```
Read address 0x00 ->
  bit 0  : resetIt
  bit 1  : haltIt
  bit 2  : isPipBusy
  bit 3  : haltedByBreak
  bit 4  : stepIt
Write address 0x00 ->
  bit 4  : stepIt
  bit 16 : set resetIt
  bit 17 : set haltIt
  bit 24 : clear resetIt
  bit 25 : clear haltIt and haltedByBreak

Read Address 0x04 ->
  bits (31 downto 0) : Last value written into the register file
Write Address 0x04 ->
  bits (31 downto 0) : Instruction that should be pushed into the CPU pipeline for debug purposes
```

The OpenOCD port is here: <https://github.com/SpinalHDL/openocd_riscv>
````
