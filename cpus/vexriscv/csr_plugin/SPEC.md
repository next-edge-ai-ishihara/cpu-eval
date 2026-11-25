# Implement `CsrPlugin`

Implement the complete `CsrPlugin` class. Keep the CSR configuration, mapping and service definitions fixed. Preserve every `CsrPlugin` member that the related source code reads.

Return only the complete `class CsrPlugin` definition in a single Scala code block, with no text outside the block.

## Class declaration

### src/main/scala/vexriscv/plugin/CsrPlugin.scala

```scala
package vexriscv.plugin

import spinal.core._
import spinal.lib._
import vexriscv._
import vexriscv.Riscv._
import vexriscv.plugin.IntAluPlugin.{ALU_BITWISE_CTRL, ALU_CTRL, AluBitwiseCtrlEnum, AluCtrlEnum}

import scala.collection.mutable.ArrayBuffer
import scala.collection.mutable
import spinal.core.sim._
import spinal.lib.cpu.riscv.debug._
import spinal.lib.fsm.{State, StateMachine}
// ...
class CsrPlugin(val config: CsrPluginConfig) extends Plugin[VexRiscv] with ExceptionService with PrivilegeService with InterruptionInhibitor with ExceptionInhibitor with IContextSwitching with CsrInterface with IWake with VexRiscvRegressionArg {
// ...
    timerInterrupt    = in Bool() setName("timerInterrupt")
    externalInterrupt = in Bool() setName("externalInterrupt")
    softwareInterrupt = in Bool() setName("softwareInterrupt") default(False)
// ...
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
      new VexRiscvPosition("MachineOs") with CatchAllPosition{
        override def applyOn(config: VexRiscvConfig): Unit = config.plugins += new CsrPlugin(CsrPluginConfig.all(0x80000020l))
        override def testParam = s"CSR=yes CSR_SKIP_TEST=yes FREERTOS=$freertos ZEPHYR=$zephyr"
      }
```

## Dependency declarations

### src/main/scala/vexriscv/plugin/CsrPlugin.scala

```scala
trait CsrAccess{
  def canWrite : Boolean = false
  def canRead : Boolean = false
}
object CsrAccess {
  object WRITE_ONLY extends CsrAccess{
    override def canWrite : Boolean = true
  }
  object READ_ONLY extends CsrAccess{
    override def canRead : Boolean = true
  }
  object READ_WRITE extends CsrAccess{
    override def canWrite : Boolean = true
    override def canRead : Boolean = true
  }
  object NONE extends CsrAccess
}



case class ExceptionPortInfo(port : Flow[ExceptionCause],stage : Stage, priority : Int, codeWidth : Int)
case class CsrPluginConfig(
                            catchIllegalAccess  : Boolean,
                            var mvendorid       : BigInt,
                            var marchid         : BigInt,
                            var mimpid          : BigInt,
                            var mhartid         : BigInt,
                            misaExtensionsInit  : Int,
                            misaAccess          : CsrAccess,
                            mtvecAccess         : CsrAccess,
                            var mtvecInit       : BigInt,
                            mepcAccess          : CsrAccess,
                            mscratchGen         : Boolean,
                            mcauseAccess        : CsrAccess,
                            mbadaddrAccess      : CsrAccess,
                            mcycleAccess        : CsrAccess,
                            minstretAccess      : CsrAccess,
                            ucycleAccess        : CsrAccess,
                            uinstretAccess      : CsrAccess = CsrAccess.NONE,
                            wfiGenAsWait        : Boolean,
                            ecallGen            : Boolean,
                            xtvecModeGen        : Boolean = false,
                            noCsrAlu            : Boolean = false,
                            wfiGenAsNop         : Boolean = false,
                            ebreakGen           : Boolean = false,
                            userGen             : Boolean = false,
                            supervisorGen       : Boolean = false,
                            sscratchGen         : Boolean = false,
                            stvecAccess         : CsrAccess = CsrAccess.NONE,
                            sepcAccess          : CsrAccess = CsrAccess.NONE,
                            scauseAccess        : CsrAccess = CsrAccess.NONE,
                            sbadaddrAccess      : CsrAccess = CsrAccess.NONE,
                            scycleAccess        : CsrAccess = CsrAccess.NONE,
                            sinstretAccess      : CsrAccess = CsrAccess.NONE,
                            satpAccess          : CsrAccess = CsrAccess.NONE,
                            utimeAccess         :CsrAccess = CsrAccess.NONE,
                            medelegAccess       : CsrAccess = CsrAccess.NONE,
                            midelegAccess       : CsrAccess = CsrAccess.NONE,
                            withExternalMhartid : Boolean = false,
                            mhartidWidth        : Int = 0,
                            pipelineCsrRead     : Boolean = false,
                            pipelinedInterrupt  : Boolean = true,
                            csrOhDecoder        : Boolean = true,
                            deterministicInteruptionEntry : Boolean = false, //Only used for simulatation purposes
                            wfiOutput           : Boolean = false,
                            exportPrivilege     : Boolean = false,
                            var withPrivilegedDebug : Boolean = false, //For the official RISC-V debug spec implementation
                            var debugTriggers       : Int     = 2
                          ){
  assert(!ucycleAccess.canWrite)
  def privilegeGen = userGen || supervisorGen || withPrivilegedDebug
  def noException = this.copy(ecallGen = false, ebreakGen = false, catchIllegalAccess = false)
  def noExceptionButEcall = this.copy(ecallGen = true, ebreakGen = false, catchIllegalAccess = false)
  def withEbreak = ebreakGen || withPrivilegedDebug
}

object CsrPluginConfig{
  def all : CsrPluginConfig = all(0x00000020l)
  def small : CsrPluginConfig = small(0x00000020l)
  def smallest : CsrPluginConfig = smallest(0x00000020l)
// ...

  def all(mtvecInit : BigInt) : CsrPluginConfig = CsrPluginConfig(
    catchIllegalAccess = true,
    mvendorid          = 11,
    marchid            = 22,
    mimpid             = 33,
    mhartid            = 0,
    misaExtensionsInit = 66,
    misaAccess         = CsrAccess.READ_WRITE,
    mtvecAccess        = CsrAccess.READ_WRITE,
    mtvecInit          = mtvecInit,
    mepcAccess         = CsrAccess.READ_WRITE,
    mscratchGen        = true,
    mcauseAccess       = CsrAccess.READ_WRITE,
    mbadaddrAccess     = CsrAccess.READ_WRITE,
    mcycleAccess       = CsrAccess.READ_WRITE,
    minstretAccess     = CsrAccess.READ_WRITE,
    ecallGen           = true,
    wfiGenAsWait       = true,
    ucycleAccess       = CsrAccess.READ_ONLY,
    uinstretAccess     = CsrAccess.READ_ONLY
  )
// ...

}
case class CsrWrite(that : Data, bitOffset : Int)
case class CsrRead(that : Data , bitOffset : Int)
case class CsrReadToWriteOverride(that : Data, bitOffset : Int) //Used for special cases, as MIP where there shadow stuff
case class CsrOnWrite(doThat :() => Unit)
case class CsrDuringWrite(doThat :() => Unit)
case class CsrDuringRead(doThat :() => Unit)
case class CsrDuring(doThat :() => Unit)
case class CsrOnRead(doThat : () => Unit)


case class CsrMapping() extends Area with CsrInterface {
  val mapping = mutable.LinkedHashMap[Int,ArrayBuffer[Any]]()
  val always = ArrayBuffer[Any]()
  val readDataSignal, readDataInit, writeDataSignal = Bits(32 bits)
  val allowCsrSignal = False
  val hazardFree = Bool()
  val doForceFailCsr = False

  readDataSignal := readDataInit
  def addMappingAt(address : Int,that : Any) = mapping.getOrElseUpdate(address,new ArrayBuffer[Any]) += that
  override def r(csrAddress : Int, bitOffset : Int, that : Data): Unit = addMappingAt(csrAddress, CsrRead(that,bitOffset))
  override def w(csrAddress : Int, bitOffset : Int, that : Data): Unit = addMappingAt(csrAddress, CsrWrite(that,bitOffset))
  override def r2w(csrAddress : Int, bitOffset : Int, that : Data): Unit = addMappingAt(csrAddress, CsrReadToWriteOverride(that,bitOffset))
  override def onWrite(csrAddress: Int)(body: => Unit): Unit = addMappingAt(csrAddress, CsrOnWrite(() => body))
  override def duringWrite(csrAddress: Int)(body: => Unit): Unit = addMappingAt(csrAddress, CsrDuringWrite(() => body))
  override def duringRead(csrAddress: Int)(body: => Unit): Unit = addMappingAt(csrAddress, CsrDuringRead(() => body))
  override def during(csrAddress: Int)(body: => Unit): Unit = addMappingAt(csrAddress, CsrDuring(() => body))
  override def onRead(csrAddress: Int)(body: => Unit): Unit =  addMappingAt(csrAddress, CsrOnRead(() => {body}))
  override def duringAny(): Bool = ???
  override def duringAnyRead(body: => Unit) : Unit = always += CsrDuringRead(() => body)
  override def duringAnyWrite(body: => Unit) : Unit = always += CsrDuringWrite(() => body)
  override def onAnyRead(body: => Unit) : Unit = always += CsrOnRead(() => body)
  override def onAnyWrite(body: => Unit) : Unit = always += CsrOnWrite(() => body)
  override def readData() = readDataSignal
  override def writeData() = writeDataSignal
  override def allowCsr() = allowCsrSignal := True
  override def isHazardFree() = hazardFree
  override def forceFailCsr() = doForceFailCsr := True
  override def inDebugMode(): Bool = ???
}


trait CsrInterface{
  def onWrite(csrAddress : Int)(doThat : => Unit) : Unit
  def onRead(csrAddress : Int)(doThat : => Unit) : Unit
  def duringWrite(csrAddress: Int)(body: => Unit): Unit
  def duringRead(csrAddress: Int)(body: => Unit): Unit
  def during(csrAddress: Int)(body: => Unit): Unit
  def duringAny(): Bool
  def r(csrAddress : Int, bitOffset : Int, that : Data): Unit
  def w(csrAddress : Int, bitOffset : Int, that : Data): Unit
  def rw(csrAddress : Int, bitOffset : Int,that : Data): Unit ={
// ...
  }
  def duringAnyRead(body: => Unit) : Unit //Called all the durration of a Csr write instruction in the execute stage
  def duringAnyWrite(body: => Unit) : Unit //same than above for read
  def onAnyRead(body: => Unit) : Unit
  def onAnyWrite(body: => Unit) : Unit
  def allowCsr() : Unit  //In case your csr do not use the regular API with csrAddress but is implemented using "side channels", you can call that if the current csr is implemented
  def isHazardFree() : Bool // You should not have any side effect nor use readData() until this return True
  def forceFailCsr() : Unit

  def r2w(csrAddress : Int, bitOffset : Int,that : Data): Unit

  def rw(csrAddress : Int, thats : (Int, Data)*) : Unit = for(that <- thats) rw(csrAddress,that._1, that._2)
  def w(csrAddress : Int, thats : (Int, Data)*) : Unit = for(that <- thats) w(csrAddress,that._1, that._2)
  def r(csrAddress : Int, thats : (Int, Data)*) : Unit = for(that <- thats) r(csrAddress,that._1, that._2)
  def rw[T <: Data](csrAddress : Int, that : T): Unit = rw(csrAddress,0,that)
  def w[T <: Data](csrAddress : Int, that : T): Unit = w(csrAddress,0,that)
  def r [T <: Data](csrAddress : Int, that : T): Unit = r(csrAddress,0,that)
  def isWriting(csrAddress : Int) : Bool = {
// ...
  }

  def isReading(csrAddress : Int) : Bool = {
// ...
  }

  def readData() : Bits //Return the 32 bits internal signal of the CsrPlugin for you to override (if you want)
  def writeData() : Bits //Return the 32 bits value that the CsrPlugin want to write in the CSR (depend on readData combinatorialy)
  def inDebugMode() : Bool
}


trait IContextSwitching{
  def isContextSwitching : Bool
}
trait IWake{
  def askWake() : Unit
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
trait JumpService{
  def createJumpInterface(stage : Stage, priority : Int = 0) : Flow[UInt] //High priority win
}
// ...
trait IBusFetcher{
  def haltIt() : Unit
  def incoming() : Bool
  def pcValid(stage : Stage) : Bool
  def getInjectionPort() : Stream[Bits]
  def withRvc() : Boolean
  def forceNoDecode() : Unit
}
// ...
trait DecoderService{
  def add(key : MaskedLiteral,values : Seq[(Stageable[_ <: BaseType],Any)])
  def add(encoding :Seq[(MaskedLiteral,Seq[(Stageable[_ <: BaseType],Any)])])
  def addDefault(key : Stageable[_ <: BaseType], value : Any)
  def forceIllegal() : Unit
}

case class ExceptionCause(codeWidth : Int) extends Bundle{
  val code = UInt(codeWidth bits)
  val badAddr = UInt(32 bits)

  def resizeCode(width : Int): ExceptionCause ={
    val ret = ExceptionCause(width)
    ret.badAddr := badAddr
    ret.code := code.resized
    ret
  }
}

trait ExceptionService{
  def newExceptionPort(stage : Stage, priority : Int = 0, codeWidth : Int = 4) : Flow[ExceptionCause]
  def isExceptionPending(stage : Stage) : Bool
}

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
// ...
  object RS1_USE extends Stageable(Bool)
// ...
  object PC extends Stageable(UInt(32 bits))
// ...
  object INSTRUCTION extends Stageable(Bits(32 bits))
// ...
  object REGFILE_WRITE_VALID extends Stageable(Bool)
  object REGFILE_WRITE_DATA extends Stageable(Bits(32 bits))

  object MPP extends PipelineThing[UInt]
// ...
  object SRC1   extends Stageable(Bits(32 bits))
// ...
  object HAS_SIDE_EFFECT extends Stageable(Bool)
// ...
  object Src1CtrlEnum extends SpinalEnum(binarySequential){
    val RS, IMU, PC_INCREMENT, URS1 = newElement()   //IMU, IMZ IMJB
  }
// ...
  object SRC1_CTRL  extends Stageable(Src1CtrlEnum())
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
  def ECALL              = M"00000000000000000000000001110011"
  def EBREAK             = M"00000000000100000000000001110011"
  def FENCEI             = M"00000000000000000001000000001111"
  def MRET               = M"00110000001000000000000001110011"
  def SRET               = M"00010000001000000000000001110011"
  def WFI                = M"00010000010100000000000001110011"
// ...
  object CSR{
    def MVENDORID = 0xF11 // MRO Vendor ID.
    def MARCHID   = 0xF12 // MRO Architecture ID.
    def MIMPID    = 0xF13 // MRO Implementation ID.
    def MHARTID   = 0xF14 // MRO Hardware thread ID.Machine Trap Setup
    def MSTATUS   = 0x300 // MRW Machine status register.
    def MSTATUSH  = 0x310 // MRW Upper 32 bits of mstatus, RV32I only.
    def MISA      = 0x301 // MRW ISA and extensions
    def MEDELEG   = 0x302 // MRW Machine exception delegation register.
    def MIDELEG   = 0x303 // MRW Machine interrupt delegation register.
    def MIE       = 0x304 // MRW Machine interrupt-enable register.
    def MTVEC     = 0x305 // MRW Machine trap-handler base address. Machine Trap Handling
    def MSCRATCH  = 0x340 // MRW Scratch register for machine trap handlers.
    def MEPC      = 0x341 // MRW Machine exception program counter.
    def MCAUSE    = 0x342 // MRW Machine trap cause.
    def MBADADDR  = 0x343 // MRW Machine bad address.
    def MIP       = 0x344 // MRW Machine interrupt pending.
    def MBASE     = 0x380 // MRW Base register.
    def MBOUND    = 0x381 // MRW Bound register.
    def MIBASE    = 0x382 // MRW Instruction base register.
    def MIBOUND   = 0x383 // MRW Instruction bound register.
    def MDBASE    = 0x384 // MRW Data base register.
    def MDBOUND   = 0x385 // MRW Data bound register.
    def MCYCLE    = 0xB00 // MRW Machine cycle counter.
    def MINSTRET  = 0xB02 // MRW Machine instructions-retired counter.
    def MCYCLEH   = 0xB80 // MRW Upper 32 bits of mcycle, RV32I only.
    def MINSTRETH = 0xB82 // MRW Upper 32 bits of minstret, RV32I only.
    val MCOUNTEREN  = 0x306

    val SSTATUS     = 0x100
    val SIE         = 0x104
    val STVEC       = 0x105
    val SCOUNTEREN  = 0x106
    val SSCRATCH    = 0x140
    val SEPC        = 0x141
    val SCAUSE      = 0x142
    val SBADADDR    = 0x143
    val SIP         = 0x144
    val SATP        = 0x180

    def UCYCLE   = 0xC00 // UR Machine ucycle counter.
    def UCYCLEH  = 0xC80
    def UTIME    = 0xC01 // rdtime
    def UTIMEH   = 0xC81
    def UINSTRET  = 0xC02 // UR Machine instructions-retired counter.
    def UINSTRETH = 0xC82 // UR Upper 32 bits of minstret, RV32I only.

    val FFLAGS = 0x1
    val FRM = 0x2
    val FCSR = 0x3

    val DCSR      = 0x7B0
    val DPC       = 0x7B1
    val TSELECT   = 0x7A0
    val TDATA1    = 0x7A1
    val TDATA2    = 0x7A2
    val TINFO     = 0x7a4
    val TCONTROL  = 0x7A5
  }
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

// ...
  def indexOf(stage : Stage) = stages.indexOf(stage)

  def service[T](clazz : Class[T]) = {
    val filtered = plugins.filter(o => clazz.isAssignableFrom(o.getClass))
    assert(filtered.length == 1, s"??? ${clazz.getName}")
    filtered.head.asInstanceOf[T]
// ...

  def update[T](that : PipelineThing[T], value : T) : Unit = things(that) = value
  def apply[T](that : PipelineThing[T]) : T = things(that).asInstanceOf[T]
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

  def dontSampleStageable(s : Stageable[_], cond : Bool): Unit ={
    dontSample.getOrElseUpdate(s, ArrayBuffer[Bool]()) += cond
  }
  def inputInit[T <: BaseType](stageable : Stageable[T],initValue : T) =
    Component.current.addPrePopTask(() => inputsDefault(stageable.asInstanceOf[Stageable[Data]]).asInstanceOf[T].getDrivingReg().init(initValue))
}
```

## Related source code

### src/main/scala/vexriscv/VexRiscvBmbGenerator.scala

```scala
  val externalInterrupt = Handle[Bool]
  val externalSupervisorInterrupt = Handle[Bool]
  val timerInterrupt = Handle[Bool]
  val softwareInterrupt = Handle[Bool]

  def setTimerInterrupt(that: Handle[Bool]) =    Dependable(that, timerInterrupt){timerInterrupt := that}
// ...
  val debugRiscv = withRiscvDebug.produce(withRiscvDebug.get generate DebugHartBus())
// ...
      case plugin: CsrPlugin => {
        doExport(plugin.config.supervisorGen, "supervisor")
        externalInterrupt load plugin.externalInterrupt
        timerInterrupt load plugin.timerInterrupt
        softwareInterrupt load plugin.softwareInterrupt
        if (plugin.config.supervisorGen) externalSupervisorInterrupt load plugin.externalInterruptS
        if(withRiscvDebug.get) {
          assert(plugin.debugBus != null, "You need to enable CsrPluginConfig.withPrivilegedDebug")
          debugRiscv <> plugin.debugBus
        }
// ...
```

### src/main/scala/vexriscv/plugin/MmuPlugin.scala

```scala
    val csrService = pipeline.service(classOf[CsrPlugin])
// ...
    val csr = pipeline plug new Area{
      val status = new Area{
        val sum, mxr, mprv = RegInit(False)
        mprv clearWhen(csrService.xretAwayFromMachine)
// ...
```

### src/main/scala/vexriscv/demo/smp/VexRiscvSmpCluster.scala

```scala
      val clintStop =  (cores.map(e => e.cpu.logic.cpu.service(classOf[CsrPlugin]).stoptime).andR)
// ...
    plic.addTarget(core.cpu.externalInterrupt)
    if(core.cpu.config.withSupervisor) {
      plic.addTarget(core.cpu.externalSupervisorInterrupt)
    }
    List(clint.logic, core.cpu.logic).produce {
      for (plugin <- core.cpu.config.plugins) plugin match {
        case plugin: CsrPlugin if plugin.utime != null => plugin.utime := clint.logic.io.time
// ...
```

### src/main/scala/vexriscv/plugin/EmbeddedRiscvJtag.scala

```scala
    val privBus = pipeline.service(classOf[CsrPlugin]).debugBus.setAsDirectionLess()
    privBus <> dm.io.harts(0)
    privBus.dmToHart.removeAssignments() <-< dm.io.harts(0).dmToHart
```

### src/main/scala/vexriscv/plugin/CsrPlugin.scala

```scala
class UserInterruptPlugin(interruptName : String, code : Int, privilege : Int = 3) extends Plugin[VexRiscv]{
  var interrupt, interruptEnable : Bool = null
  override def setup(pipeline: VexRiscv): Unit = {
    val csr = pipeline.service(classOf[CsrPlugin])
    interrupt = in.Bool().setName(interruptName)
    val interruptPending =  RegNext(interrupt) init(False)
    val interruptEnable = RegInit(False).setName(interruptName + "_enable")
    csr.addInterrupt(interruptPending && interruptEnable, code, privilege, Nil)
    csr.r(csrAddress = CSR.MIP, bitOffset = code,interruptPending)
    csr.rw(csrAddress = CSR.MIE, bitOffset = code, interruptEnable)
  }
  override def build(pipeline: VexRiscv): Unit = {}
}
```

## Documentation

### README.md

```text
#### CsrPlugin

Implements most of the Machine mode and a few of the User mode registers, as specified in the RISC-V priviledged spec.
The access mode of most of the CSR is parameterizable to reduce the area usage of unneeded features.

(CsrAccess can be `NONE/READ_ONLY/WRITE_ONLY/READ_WRITE`)

| Parameters | type | description |
| ------ | ----------- | ------ |
| catchIllegalAccess   | Boolean |  |
| mvendorid            | BigInt |  |
| marchid              | BigInt |  |
| mimpid               | BigInt |  |
| mhartid              | BigInt |  |
| misaExtensionsInit   | Int |  |
| misaAccess           | CsrAccess |  |
| mtvecAccess          | CsrAccess |  |
| mtvecInit            | BigInt |  |
| mepcAccess           | CsrAccess |  |
| mscratchGen          | Boolean |  |
| mcauseAccess         | CsrAccess |  |
| mbadaddrAccess       | CsrAccess |  |
| mcycleAccess         | CsrAccess |  |
| minstretAccess       | CsrAccess |  |
| ucycleAccess         | CsrAccess |  |
| wfiGen               | Boolean |  |
| ecallGen             | Boolean |  |

If an interrupt occurs, before jumping to mtvec, the plugin will stop the Prefetch stage and wait for all the instructions in the later pipeline stages to complete their execution.

If an exception occur, the plugin will kill the corresponding instruction, flush all previous instructions, and wait until the previously killed instructions reach the WriteBack
stage before jumping to mtvec.

```

### src/zicsr.adoc

```text
[[csrinsts]]
== "Zicsr", Extension for Control and Status Register (CSR) Instructions, Version 2.0

RISC-V defines a separate address space of 4096 Control and Status
registers associated with each hart. This chapter defines the full set
of CSR instructions that operate on these CSRs.

[NOTE]
====
While CSRs are primarily used by the privileged architecture, there are
several uses in unprivileged code including for counters and timers, and
for floating-point status.

The counters and timers are no longer considered mandatory parts of the
standard base ISAs, and so the CSR instructions required to access them
have been moved out of <<rv32>> into this separate
chapter.
====

=== CSR Instructions

All CSR instructions atomically read-modify-write a single CSR, whose
CSR specifier is encoded in the 12-bit _csr_ field of the instruction
held in bits 31-20. The immediate forms use a 5-bit zero-extended
immediate encoded in the _rs1_ field.

include::images/wavedrom/csr-instr.edn[]

The CSRRW (Atomic Read/Write CSR) instruction atomically swaps values in
the CSRs and integer registers. CSRRW reads the old value of the CSR,
zero-extends the value to XLEN bits, then writes it to integer register
_rd_. The initial value in _rs1_ is written to the CSR. If _rd_=`x0`,
then the instruction shall not read the CSR and shall not cause any of
the side effects that might occur on a CSR read.

The CSRRS (Atomic Read and Set Bits in CSR) instruction reads the value
of the CSR, zero-extends the value to XLEN bits, and writes it to
integer register _rd_. The initial value in integer register _rs1_ is
treated as a bit mask that specifies bit positions to be set in the CSR.
Any bit that is high in _rs1_ will cause the corresponding bit to be set
in the CSR, if that CSR bit is writable.

The CSRRC (Atomic Read and Clear Bits in CSR) instruction reads the
value of the CSR, zero-extends the value to XLEN bits, and writes it to
integer register _rd_. The initial value in integer register _rs1_ is
treated as a bit mask that specifies bit positions to be cleared in the
CSR. Any bit that is high in _rs1_ will cause the corresponding bit to
be cleared in the CSR, if that CSR bit is writable.

For both CSRRS and CSRRC, if _rs1_=`x0`, then the instruction will not
write to the CSR at all, and so shall not cause any of the side effects
that might otherwise occur on a CSR write, nor raise illegal-instruction
exceptions on accesses to read-only CSRs. Both CSRRS and CSRRC always
read the addressed CSR and cause any read side effects regardless of
_rs1_ and _rd_ fields.
Note that if _rs1_ specifies a register other than `x0`, and that register
holds a zero value, the instruction will not action any attendant per-field
side effects, but will action any side effects caused by writing to the entire
CSR.

A CSRRW with _rs1_=`x0` will attempt to write zero to the destination CSR.

The CSRRWI, CSRRSI, and CSRRCI variants are similar to CSRRW, CSRRS, and
CSRRC respectively, except they update the CSR using an XLEN-bit value
obtained by zero-extending a 5-bit unsigned immediate (uimm[4:0]) field
encoded in the _rs1_ field instead of a value from an integer register.
For CSRRSI and CSRRCI, if the uimm[4:0] field is zero, then these
instructions will not write to the CSR, and shall not cause any of the
side effects that might otherwise occur on a CSR write, nor raise
illegal-instruction exceptions on accesses to read-only CSRs. For
CSRRWI, if _rd_=`x0`, then the instruction shall not read the CSR and
shall not cause any of the side effects that might occur on a CSR read.
Both CSRRSI and CSRRCI will always read the CSR and cause any read side
effects regardless of _rd_ and _rs1_ fields.

[[csrsideeffects]]
.Conditions determining whether a CSR instruction reads or writes the specified CSR.
[%autowidth,float="center",align="center",cols="<,^,^,^,^",options="header",]
|===
5+^|*Register operand* 
|Instruction |_rd_ is `x0` |_rs1_ is `x0` |Reads CSR |Writes CSR

|CSRRW |Yes |- |No |Yes

|CSRRW |No |- |Yes |Yes

|CSRRS/CSRRC |- |Yes |Yes |No

|CSRRS/CSRRC |- |No |Yes |Yes

5+^|*Immediate operand* 

|Instruction |_rd_ is `x0` |__uimm__latexmath:[$=$]0 |Reads CSR |Writes
CSR

|CSRRWI |Yes |- |No |Yes

|CSRRWI |No |- |Yes |Yes

|CSRRSI/CSRRCI |- |Yes |Yes |No

|CSRRSI/CSRRCI |- |No |Yes |Yes
|===
```

### src/images/wavedrom/csr-instr.edn

```text
//# 10 "Zicsr", Control and Status Register (CSR) Instructions, Version 2.0
//## 10.1 CSR Instructions 

[wavedrom, ,svg]
....
{reg: [
  {bits: 7,  name: 'opcode', attr: ['7', 'SYSTEM', 'SYSTEM', 'SYSTEM', 'SYSTEM', 'SYSTEM', 'SYSTEM'] },
  {bits: 5,  name: 'rd',     attr: ['5', 'dest', 'dest', 'dest', 'dest', 'dest', 'dest'] },
  {bits: 3,  name: 'funct3', attr: ['3', 'CSRRW', 'CSRRS', 'CSRRC', 'CSRRWI', 'CSRRSI', 'CSRRCI'] },
  {bits: 5,  name: 'rs1',    attr: ['5', 'source', 'source', 'source', 'uimm[4:0]', 'uimm[4:0]', 'uimm[4:0]'] },
  {bits: 12, name: 'csr',    attr: ['12', 'source/dest', 'source/dest', 'source/dest', 'source/dest', 'source/dest', 'source/dest'], },
]}
....

//[wavedrom, ,]
//....
//{reg: [
//  {bits: 7,  name: 'opcode', attr: ['7', 'SYSTEM','SYSTEM','SYSTEM'] },
//  {bits: 5,  name: 'rd',     attr: ['3', 'dest','dest', 'dest' ] },
//  {bits: 3,  name: 'funct3',  attr: ['3', 'CSRRWI', 'CSRRSI', 'CSRRCI'] },
//  {bits: 5,  name: 'rs1',    attr: ['5', 'uimm[4:0]','uimm[4:0]', 'uimm[4:0]'] },
//  {bits: 12, name: 'csr',    attr: ['12', 'source/dest','source/dest','source/dest'] },
//]}
//....
...
```

### src/machine.adoc

```text
==== Machine Status (`mstatus` and `mstatush`) Registers 

The `mstatus` register is an MXLEN-bit read/write register formatted as
shown in <<mstatusreg-rv32>> for RV32 and
<<mstatusreg>> for RV64. The `mstatus` register
keeps track of and controls the hart’s current operating state. A
restricted view of `mstatus` appears as the `sstatus` register in the
S-level ISA.

[[mstatusreg-rv32]]
.Machine-mode status (`mstatus`) register for RV32
include::images/wavedrom/mstatusreg-rv321.edn[]

[[mstatusreg]]
.Machine-mode status (`mstatus`) register for RV64
include::images/wavedrom/mstatusreg.edn[]

For RV32 only, `mstatush` is a 32-bit read/write register formatted as
shown in <<mstatushreg>>. Bits 30:4 of `mstatush` generally contain the same fields found in bits 62:36 of `mstatus` for RV64. Fields SD, SXL, and UXL do not exist in `mstatush`.

[[mstatushreg]]
.Additional machine-mode status (`mstatush`) register  for RV32.
include::images/wavedrom/mstatushreg.edn[]

[[privstack]]
===== Privilege and Global Interrupt-Enable Stack in `mstatus` register

Global interrupt-enable bits, MIE and SIE, are provided for M-mode and
S-mode respectively. These bits are primarily used to guarantee
atomicity with respect to interrupt handlers in the current privilege
mode.

[NOTE]
====
The global __x__IE bits are located in the low-order bits of `mstatus`,
allowing them to be atomically set or cleared with a single CSR
instruction.
====

When a hart is executing in privilege mode _x_, interrupts are globally
enabled when __x__IE=1 and globally disabled when __x__IE=0. Interrupts for
lower-privilege modes, __w__<__x__, are always globally
disabled regardless of the setting of any global __w__IE bit for the
lower-privilege mode. Interrupts for higher-privilege modes,
__y__>__x__, are always globally enabled regardless of the
setting of the global __y__IE bit for the higher-privilege mode.
Higher-privilege-level code can use separate per-interrupt enable bits
to disable selected higher-privilege-mode interrupts before ceding
control to a lower-privilege mode.

[NOTE]
====
A higher-privilege mode _y_ could disable all of its interrupts before
ceding control to a lower-privilege mode but this would be unusual as it
would leave only a synchronous trap, non-maskable interrupt, or reset as
means to regain control of the hart.
====

To support nested traps, each privilege mode _x_ that can respond to
interrupts has a two-level stack of interrupt-enable bits and privilege
modes. __x__PIE holds the value of the interrupt-enable bit active prior
to the trap, and __x__PP holds the previous privilege mode. The __x__PP
fields can only hold privilege modes up to _x_, so MPP is two bits wide
and SPP is one bit wide. When a trap is taken from privilege mode _y_
into privilege mode _x_, __x__PIE is set to the value of __x__IE; __x__IE is
set to 0; and __x__PP is set to _y_.

[NOTE]
====
For lower privilege modes, any trap (synchronous or asynchronous) is
usually taken at a higher privilege mode with interrupts disabled upon
entry. The higher-level trap handler will either service the trap and
return using the stacked information, or, if not returning immediately
to the interrupted context, will save the privilege stack before
re-enabling interrupts, so only one entry per stack is required.
====

An MRET or SRET instruction is used to return from a trap in M-mode or
S-mode respectively. When executing an __x__RET instruction, supposing
__x__PP holds the value _y_, __x__IE is set to __x__PIE; the privilege mode is
changed to _y_; __x__PIE is set to 1; and __x__PP is set to the
least-privileged supported mode (U if U-mode is implemented, else M). If
__y__&#8800;M, __x__RET also sets MPRV=0.
```

### src/images/wavedrom/mstatusreg-rv321.edn

```text
//.Machine-mode status (`mstatus`) register for RV32
[wavedrom, ,svg]
....
{reg: [
  {bits:  1, name: 'WPRI'},
  {bits:  1, name: 'SIE'},
  {bits:  1, name: 'WPRI'},
  {bits:  1, name: 'MIE'},
  {bits:  1, name: 'WPRI'},
  {bits:  1, name: 'SPIE'},
  {bits:  1, name: 'UBE'},
  {bits:  1, name: 'MPIE'},
  {bits:  1, name: 'SPP'},
  {bits:  2, name: 'VS[1:0]'},
  {bits:  2, name: 'MPP[1:0]'},
  {bits:  2, name: 'FS[1:0]'},
  {bits:  2, name: 'XS[1:0]'},
  {bits:  1, name: 'MPRV'},
  {bits:  1, name: 'SUM'},
  {bits:  1, name: 'MXR'},
  {bits:  1, name: 'TVM'},
  {bits:  1, name: 'TW'},
  {bits:  1, name: 'TSR'},
  {bits:  1, name: 'SPELP'},
  {bits:  1, name: 'SDT'},
  {bits:  6, name: 'WPRI'},
  {bits:  1, name: 'SD'},
], config:{lanes: 2, hspace:1024}}
....
...
```

### src/machine.adoc

```text
==== Machine Trap-Vector Base-Address (`mtvec`) Register 

The `mtvec` register is an MXLEN-bit *WARL* read/write register that holds
trap vector configuration, consisting of a vector base address (BASE)
and a vector mode (MODE).


.Encoding of mtvec MODE field.
include::images/bytefield/mtvec.edn[]

The `mtvec` register must always be implemented, but can contain a
read-only value. If `mtvec` is writable, the set of values the register
may hold can vary by implementation. The value in the BASE field must
always be aligned on a 4-byte boundary, and the MODE setting may impose
additional alignment constraints on the value in the BASE field.

[NOTE]
====
We allow for considerable flexibility in implementation of the trap
vector base address. On the one hand, we do not wish to burden low-end
implementations with a large number of state bits, but on the other
hand, we wish to allow flexibility for larger systems.
====

[[mtvec-mode]]
.Encoding of mtvec MODE field.
[%autowidth,float="center",align="center",cols=">,^,<",options="header"]
|===
|Value |Name |Description
|0 +
1 +
&#8805;2
|Direct +
Vectored +
---
|All traps set `pc` to BASE. +
Asynchronous interrupts set `pc` to BASE+4&#215;cause. +
_Reserved_
|===

The encoding of the MODE field is shown in
<<mtvec-mode>>. When MODE=Direct, all traps into
machine mode cause the `pc` to be set to the address in the BASE field.
When MODE=Vectored, all synchronous exceptions into machine mode cause
the `pc` to be set to the address in the BASE field, whereas interrupts
cause the `pc` to be set to the address in the BASE field plus four
times the interrupt cause number. For example, a machine-mode timer
interrupt (see <<mcauses>>) causes the `pc`
to be set to BASE+`0x1c`.


An implementation may have different alignment constraints for different
modes. In particular, MODE=Vectored may have stricter alignment
constraints than MODE=Direct.
...
==== Machine Interrupt (`mip` and `mie`) Registers 

The `mip` register is an MXLEN-bit read/write register containing
information on pending interrupts, while `mie` is the corresponding
MXLEN-bit read/write register containing interrupt enable bits.
Interrupt cause number _i_ (as reported in CSR `mcause`,
<<mcause>>) corresponds with bit _i_ in both `mip` and
`mie`. Bits 15:0 are allocated to standard interrupt causes only, while
bits 16 and above are designated for platform use.

NOTE: Interrupts designated for platform use may be designated for custom use
at the platform's discretion.

.Machine Interrupt-Pending (`mip`) register.
include::images/bytefield/mideleg.edn[]

.Machine Interrupt-Enable (`mie`) register
include::images/bytefield/mideleg.edn[]

An interrupt _i_ will trap to M-mode (causing the privilege mode to
change to M-mode) if all of the following are true: (a) either the
current privilege mode is M and the MIE bit in the `mstatus` register is
set, or the current privilege mode has less privilege than M-mode;
(b) bit _i_ is set in both `mip` and `mie`; and (c) if register
`mideleg` exists, bit _i_ is not set in `mideleg`.

These conditions for an interrupt trap to occur must be evaluated in a
bounded amount of time from when an interrupt becomes, or ceases to be,
pending in `mip`, and must also be evaluated immediately following the
execution of an __x__RET instruction or an explicit write to a CSR on
which these interrupt trap conditions expressly depend (including `mip`,
`mie`, `mstatus`, and `mideleg`).

Interrupts to M-mode take priority over any interrupts to lower
privilege modes.

Each individual bit in register `mip` may be writable or may be
read-only. When bit _i_ in `mip` is writable, a pending interrupt _i_
can be cleared by writing 0 to this bit. If interrupt _i_ can become
pending but bit _i_ in `mip` is read-only, the implementation must
provide some other mechanism for clearing the pending interrupt.

A bit in `mie` must be writable if the corresponding interrupt can ever
become pending. Bits of `mie` that are not writable must be read-only
zero.

The standard portions (bits 15:0) of the `mip` and `mie` registers are
formatted as shown in <<mipreg-standard>> and <<miereg-standard>> respectively.

[[mipreg-standard]]
.Standard portion (bits 15:0) of `mip`.
include::images/bytefield/mipreg-standard.edn[]

[[miereg-standard]]
.Standard portion (bits 15:0) of `mie`.
include::images/bytefield/miereg-standard.edn[]

[NOTE]
====
The machine-level interrupt registers handle a few root interrupt
sources which are assigned a fixed service priority for simplicity,
while separate external interrupt controllers can implement a more
complex prioritization scheme over a much larger set of interrupts that
are then muxed into the machine-level interrupt sources.

'''

The non-maskable interrupt is not made visible via the `mip` register as
its presence is implicitly known when executing the NMI trap handler.
====

Bits `mip`.MEIP and `mie`.MEIE are the interrupt-pending and
interrupt-enable bits for machine-level external interrupts. MEIP is
read-only in `mip`, and is set and cleared by a platform-specific
interrupt controller.

Bits `mip`.MTIP and `mie`.MTIE are the interrupt-pending and
interrupt-enable bits for machine timer interrupts. MTIP is read-only in
the `mip` register, and is cleared by writing to the memory-mapped machine-mode timer
compare register.

Bits `mip`.MSIP and `mie`.MSIE are the interrupt-pending and
interrupt-enable bits for machine-level software interrupts. MSIP is
read-only in `mip`, and is written by accesses to memory-mapped control
registers, which are used by remote harts to provide machine-level
interprocessor interrupts. A hart can write its own MSIP bit using the
same memory-mapped control register. If a system has only one hart, or
if a platform standard supports the delivery of machine-level
interprocessor interrupts through external interrupts (MEI) instead,
then `mip`.MSIP and `mie`.MSIE may both be read-only zeros.

If supervisor mode is not implemented, bits SEIP, STIP, and SSIP of
`mip` and SEIE, STIE, and SSIE of `mie` are read-only zeros.
...
Multiple simultaneous interrupts destined for M-mode are handled in the
following decreasing priority order: MEI, MSI, MTI, SEI, SSI, STI, LCOFI.
...
==== Hardware Performance Monitor

M-mode includes a basic hardware performance-monitoring facility. The
`mcycle` CSR counts the number of clock cycles executed by the processor
core on which the hart is running. The `minstret` CSR counts the number
of instructions the hart has retired. The `mcycle` and `minstret`
registers have 64-bit precision on all RV32 and RV64 harts.

The counter registers have an arbitrary value after the hart is reset,
and can be written with a given value. Any CSR write takes effect after
the writing instruction has otherwise completed. The `mcycle` CSR may be
shared between harts on the same core, in which case writes to `mcycle`
will be visible to those harts. The platform should provide a mechanism
to indicate which harts share an `mcycle` CSR.

The hardware performance monitor includes 29 additional 64-bit event
counters, `mhpmcounter3`-`mhpmcounter31`. The event selector CSRs,
`mhpmevent3`-`mhpmevent31`, are 64-bit *WARL* registers that control which
event causes the corresponding counter to increment. The meaning of
these events is defined by the platform, but event 0 is defined to mean
"no event." All counters should be implemented, but a legal
implementation is to make both the counter and its corresponding event
selector be read-only 0.

.Hardware performance monitor counters.
include::images/bytefield/hpmevents.edn[]

The `mhpmcounters` are *WARL* registers that support up to 64 bits of
precision on RV32 and RV64.

When XLEN=32, reads of the `mcycle`, `minstret`, `mhpmcounter__n__`, and `mhpmevent__n__`
CSRs return bits 31-0 of the corresponding register, and writes change
only bits 31-0; reads of the `mcycleh`, `minstreth`, `mhpmcounter__n__h`, and `mhpmevent__n__h`
CSRs return bits 63-32 of the corresponding register, and writes change
only bits 63-32.
...
==== Machine Scratch (`mscratch`) Register 

The `mscratch` register is an MXLEN-bit read/write register dedicated
for use by machine mode. Typically, it is used to hold a pointer to a
machine-mode hart-local context space and swapped with a user register
upon entry to an M-mode trap handler.

.Machine-mode scratch register.
include::images/bytefield/mscratch.edn[]

[NOTE]
====
The MIPS ISA allocated two user registers (`k0`/`k1`) for use by the
operating system. Although the MIPS scheme provides a fast and simple
implementation, it also reduces available user registers, and does not
scale to further privilege levels, or nested traps. It can also require
both registers are cleared before returning to user level to avoid a
potential security hole and to provide deterministic debugging behavior.

The RISC-V user ISA was designed to support many possible privileged
system environments and so we did not want to infect the user-level ISA
with any OS-dependent features. The RISC-V CSR swap instructions can
quickly save/restore values to the `mscratch` register. Unlike the MIPS
design, the OS can rely on holding a value in the `mscratch` register
while the user context is running.
====

==== Machine Exception Program Counter (`mepc`) Register

`mepc` is an MXLEN-bit read/write register formatted as shown in
<<mepcreg>>. The low bit of `mepc` (`mepc[0]`) is
always zero. On implementations that support only IALIGN=32, the two low
bits (`mepc[1:0]`) are always zero.

If an implementation allows IALIGN to be either 16 or 32 (by changing
CSR `misa`, for example), then, whenever IALIGN=32, bit `mepc[1]` is
masked on reads so that it appears to be 0. This masking occurs also for
the implicit read by the MRET instruction. Though masked, `mepc[1]`
remains writable when IALIGN=32.

`mepc` is a *WARL* register that must be able to hold all valid virtual
addresses. It need not be capable of holding all possible invalid
addresses. Prior to writing `mepc`, implementations may convert an
invalid address into some other invalid address that `mepc` is capable
of holding.

[NOTE]
====
When address translation is not in effect, virtual addresses and
physical addresses are equal. Hence, the set of addresses `mepc` must be
able to represent includes the set of physical addresses that can be
used as a valid `pc` or effective address.
====

When a trap is taken into M-mode, `mepc` is written with the virtual
address of the instruction that was interrupted or that encountered the
exception. Otherwise, `mepc` is never written by the implementation,
though it may be explicitly written by software.

[[mepcreg]]
.Machine exception program counter register.
include::images/bytefield/mepcreg.edn[]
...
[[mcause]]
==== Machine Cause (`mcause`) Register 

The `mcause` register is an MXLEN-bit read-write register formatted as
shown in <<mcausereg>>. When a trap is taken into
M-mode, `mcause` is written with a code indicating the event that
caused the trap. Otherwise, `mcause` is never written by the
implementation, though it may be explicitly written by software.

The Interrupt bit in the `mcause` register is set if the trap was caused
by an interrupt. The Exception Code field contains a code identifying
the last exception or interrupt. <<mcauses>> lists
the possible machine-level exception codes. The Exception Code is a
*WLRL* field, so is only guaranteed to hold supported exception codes.

[[mcausereg]]
.Machine Cause (`mcause`) register.
include::images/bytefield/mcausereg.edn[]

Note that load and load-reserved instructions generate load exceptions,
whereas store, store-conditional, and AMO instructions generate
store/AMO exceptions.

[NOTE]
====
Interrupts can be separated from other traps with a single branch on the
sign of the `mcause` register value. A shift left can remove the
interrupt bit and scale the exception codes to index into a trap vector
table.

***

We do not distinguish privileged instruction exceptions from
illegal-instruction exceptions. This simplifies the architecture and also hides
details of which higher-privilege instructions are supported by an
implementation. The privilege level servicing the trap can implement a
policy on whether these need to be distinguished, and if so, whether a
given opcode should be treated as illegal or privileged.
====
If an instruction may raise multiple synchronous exceptions, the
decreasing priority order of
<<exception-priority>> indicates which
exception is taken and reported in `mcause`. The priority of any custom
synchronous exceptions is implementation-defined.

<<<

[[mcauses]]
.Machine cause (`mcause`) register values after trap.
[%autowidth,float="center",align="center",cols=">,>,<",options="header",]
|===
|Interrupt |Exception Code |Description 
|1 +
1 +
1 +
1
|0 +
1 +
2 +
3
|_Reserved_ +
Supervisor software interrupt +
_Reserved_ +
Machine software interrupt 

|1 +
1 +
1 +
1
|4 +
5 +
6 +
7
|_Reserved_ +
Supervisor timer interrupt +
_Reserved_ +
Machine timer interrupt 
|1 +
1 +
1 +
1
|8 +
9 +
10 +
11
|_Reserved_ +
Supervisor external interrupt +
_Reserved_ +
Machine external interrupt 
|1 +
1 +
1 +
1
|12 +
13 +
14-15 +
&#8805;16
|_Reserved_ +
Counter-overflow interrupt +
_Reserved_ +
_Designated for platform use_ 
|0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0 +
0
|0 +
1 +
2 +
3 +
4 +
5 +
6 +
7 +
8 +
9 +
10 +
11 +
12 +
13 +
14 +
15 +
16 +
17 +
18 +
19 +
20-23 +
24-31 +
32-47 +
48-63 +
&#8805;64
|Instruction address misaligned +
Instruction access fault +
Illegal instruction +
Breakpoint +
Load address misaligned +
Load access fault +
Store/AMO address misaligned +
Store/AMO access fault +
Environment call from U-mode +
Environment call from S-mode +
_Reserved_ +
Environment call from M-mode +
Instruction page fault +
Load page fault +
_Reserved_ +
Store/AMO page fault +
Double trap +
_Reserved_ +
Software check +
Hardware error +
_Reserved_ +
_Designated for custom use_ +
_Reserved_ +
_Designated for custom use_ +
_Reserved_ 
|===
```

### src/images/bytefield/mcausereg.edn

```text
[bytefield]
----
(defattrs :plain [:plain {:font-family "M+ 1p Fallback" :font-size 24}])
(def row-height 40 )
(def row-header-fn nil)
(def left-margin 200)
(def right-margin 200)
(def boxes-per-row 32)

(draw-box "MXLEN-1" {:span 4 :borders {}})
(draw-box "MXLEN-2" {:span 14 :borders {} :text-anchor "start"})
(draw-box "0" {:span 14 :borders {} :text-anchor "end"})

(draw-box "Interrupt" {:span 4})
(draw-box "Exception Code " {:span 15 :text-anchor "end" :borders {:top :border-unrelated :bottom :border-unrelated :left :border-unrelated}})
(draw-box (text "(WLRL)" {:font-weight "bold"}) {:span 13 :text-anchor "start" :borders {:top :border-unrelated :bottom :border-unrelated :right :border-unrelated}})

(draw-box "1" {:span 4 :borders {}})
(draw-box "MXLEN-1" {:font-size 24 :span 28 :borders {}})
----
...
```

### src/machine.adoc

```text
==== Machine Trap Value (`mtval`) Register 

The `mtval` register is an MXLEN-bit read-write register formatted as
shown in <<mtvalreg>>. When a trap is taken into
M-mode, `mtval` is either set to zero or written with exception-specific
information to assist software in handling the trap. Otherwise, `mtval`
is never written by the implementation, though it may be explicitly
written by software. The hardware platform will specify which exceptions
must set `mtval` informatively, which may unconditionally set it to
zero, and which may exhibit either behavior, depending on the underlying event
that caused the exception.
If the hardware platform specifies that no exceptions set `mtval`
to a nonzero value, then `mtval` is read-only zero.

If `mtval` is written with a nonzero value when a breakpoint,
address-misaligned, access-fault, or page-fault exception occurs on an
instruction fetch, load, or store, then `mtval` will contain the
faulting virtual address.

When page-based virtual memory is enabled, `mtval` is written with the
faulting virtual address, even for physical-memory access-fault
exceptions. This design reduces datapath cost for most implementations,
particularly those with hardware page-table walkers.

[[mtvalreg]]
.Machine Trap Value (`mtval`) register.
include::images/bytefield/mtvalreg.edn[]


If `mtval` is written with a nonzero value when a misaligned load or
store causes an access-fault or page-fault exception, then `mtval` will
contain the virtual address of the portion of the access that caused the
fault.

If `mtval` is written with a nonzero value when an instruction
access-fault or page-fault exception occurs on a hart with
variable-length instructions, then `mtval` will contain the virtual
address of the portion of the instruction that caused the fault, while
`mepc` will point to the beginning of the instruction.

The `mtval` register can optionally also be used to return the faulting
instruction bits on an illegal-instruction exception (`mepc` points to
the faulting instruction in memory). If `mtval` is written with a
nonzero value when an illegal-instruction exception occurs, then `mtval`
will contain the shortest of:

* the actual faulting instruction

* the first ILEN bits of the faulting instruction

* the first MXLEN bits of the faulting instruction

The value loaded into `mtval` on an illegal-instruction exception is
right-justified and all unused upper bits are cleared to zero.
...
=== Machine-Mode Privileged Instructions

==== Environment Call and Breakpoint

include::images/wavedrom/mm-env-call.edn[]

The ECALL instruction is used to make a request to the supporting
execution environment. When executed in U-mode, S-mode, or M-mode, it
generates an environment-call-from-U-mode exception,
environment-call-from-S-mode exception, or environment-call-from-M-mode
exception, respectively, and performs no other operation.

[NOTE]
====
ECALL generates a different exception for each originating privilege
mode so that environment call exceptions can be selectively delegated. A
typical use case for Unix-like operating systems is to delegate to
S-mode the environment-call-from-U-mode exception but not the others.
====

The EBREAK instruction is used by debuggers to cause control to be
transferred back to a debugging environment.
Unless overridden by an external debug environment, EBREAK raises
a breakpoint exception and performs no other operation.

[NOTE]
====
As described in the "C" Standard Extension for Compressed Instructions
in Volume I of this manual, the C.EBREAK instruction performs the same
operation as the EBREAK instruction.
====

ECALL and EBREAK cause the receiving privilege mode’s `epc` register to
be set to the address of the ECALL or EBREAK instruction itself, _not_
the address of the following instruction. As ECALL and EBREAK cause
synchronous exceptions, they are not considered to retire, and should
not increment the `minstret` CSR.

[[otherpriv]]
==== Trap-Return Instructions

Instructions to return from trap are encoded under the PRIV minor
opcode.

include::images/wavedrom/trap-return.edn[]

To return after handling a trap, there are separate trap return
instructions per privilege level, MRET and SRET. MRET is always
provided. SRET must be provided if supervisor mode is supported, and
should raise an illegal-instruction exception otherwise. SRET should
also raise an illegal-instruction exception when TSR=1 in `mstatus`, as
described in <<virt-control>>. An __x__RET instruction
can be executed in privilege mode _x_ or higher, where executing a
lower-privilege __x__RET instruction will pop the relevant lower-privilege
interrupt enable and privilege mode stack. In addition to manipulating
the privilege stack as described in <<privstack>>,
__x__RET sets the `pc` to the value stored in the `__x__epc` register.

If the A extension is supported, the __x__RET instruction is allowed to
clear any outstanding LR address reservation but is not required to.
Trap handlers should explicitly clear the reservation if required (e.g.,
by using a dummy SC) before executing the __x__RET.

[NOTE]
====
If __x__RET instructions always cleared LR reservations, it would be
impossible to single-step through LR/SC sequences using a debugger.
====

[[wfi]]
==== Wait for Interrupt

The Wait for Interrupt instruction (WFI) informs the
implementation that the current hart can be stalled until an interrupt
might need servicing. Execution of the WFI instruction can also be used
to inform the hardware platform that suitable interrupts should
preferentially be routed to this hart. WFI is available in all
privileged modes, and optionally available to U-mode. This instruction
may raise an illegal-instruction exception when TW=1 in `mstatus`, as
described in <<virt-control>>.

include::images/wavedrom/wfi.edn[]

If an enabled interrupt is present or later becomes present while the
hart is stalled, the interrupt trap will be taken on the following
instruction, i.e., execution resumes in the trap handler and `mepc` =
`pc` + 4.

[NOTE]
====
The following instruction takes the interrupt trap so that a simple
return from the trap handler will execute code after the WFI
instruction.
====

Implementations are permitted to resume execution for any reason, even if an
enabled interrupt has not become pending.  Hence, a legal implementation is to
simply implement the WFI instruction as a NOP.

[NOTE]
====
If the implementation does not stall the hart on execution of the
instruction, then the interrupt will be taken on some instruction in the
idle loop containing the WFI, and on a simple return from the handler,
the idle loop will resume execution.
====

The WFI instruction can also be executed when interrupts are disabled.
The operation of WFI must be unaffected by the global interrupt bits in
`mstatus` (MIE and SIE) and the delegation register `mideleg` (i.e.,
the hart must resume if a locally enabled interrupt becomes pending,
even if it has been delegated to a less-privileged mode), but should
honor the individual interrupt enables (e.g, MTIE) (i.e.,
implementations should avoid resuming the hart if the interrupt is
pending but not individually enabled). WFI is also required to resume
execution for locally enabled interrupts pending at any privilege level,
regardless of the global interrupt enable at each privilege level.

If the event that causes the hart to resume execution does not cause an
interrupt to be taken, execution will resume at `pc` + 4, and software
must determine what action to take, including looping back to repeat the
WFI if there was no actionable event.
```

## Additional requirement

Extend the class declaration shown above with the fixed trait `CsrObservationService` of package `vexriscv.plugin` and implement its member `def csrObservation: CsrObservationSignals` with a `CsrObservationSignals()` bundle created in `setup` or `build` whose fields, sampled while the clock is low, are:

- `waitingForInterrupt: Bool`, high while a WFI instruction waits in the execute stage;
- `interruptAccepted: Bool`, high only in the cycle in which an interrupt trap is entered;
- `interruptCause: UInt(4 bits)`, the exception code of that interrupt in that cycle;
- `exceptionAccepted: Bool`, high for exactly one cycle for each synchronous exception trap, in the cycle in which the trap is entered or in the next cycle.
