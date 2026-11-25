# Implement `DBusCachedPlugin`

Implement the complete `DBusCachedPlugin` class. Keep the companion bus definitions fixed.

Return only the complete `class DBusCachedPlugin` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### cpus/vexriscv/REGRESSION_CONFIGURATION.txt

```text
VexRiscvConfig
  withMemoryStage = true
  withWriteBackStage = false
...
DBus Cached64d64cS2048W2BPL8Amo
  catchAll = true
  twoStageMmu = false
  mmuConfig = null
  memDataWidth = 64
  cpuDataWidth = 64
  bytePerLine = 8
  cacheSize = 2048
  wayCount = 2
  withLrSc = true
  withSmp = false
  withAmo = true
  dBusRspSlavePipe = false
  relaxedMemoryTranslationRegister = false
  earlyWaysHits = false
  directTlbHit = false
  dBusCmdMasterPipe = false
  dBusCmdSlavePipe = false
  asyncTagMemory = false
```

## Class declaration

### src/main/scala/vexriscv/plugin/DBusCachedPlugin.scala

```scala
package vexriscv.plugin

import vexriscv.ip._
import vexriscv._
import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axi.Axi4
import spinal.lib.bus.misc.SizeMapping
import spinal.lib.misc.HexTools

import scala.collection.mutable.ArrayBuffer
// ...
class DBusCachedPlugin(val config : DataCacheConfig,
                       memoryTranslatorPortConfig : Any = null,
                       var dBusCmdMasterPipe : Boolean = false,
                       dBusCmdSlavePipe : Boolean = false,
                       dBusRspSlavePipe : Boolean = false,
                       relaxedMemoryTranslationRegister : Boolean = false,
                       csrInfo : Boolean = false,
                       tightlyCoupledAddressStage : Boolean = false)  extends Plugin[VexRiscv] with DBusAccessService with DBusEncodingService with VexRiscvRegressionArg {
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
      new VexRiscvPosition(s"Cached${memDataWidth}d${cpuDataWidth}c" + "S" + cacheSize + "W" + wayCount + "BPL" + bytePerLine + (if(dBusCmdMasterPipe) "Cmp " else "") + (if(dBusCmdSlavePipe) "Csp " else "") + (if(dBusRspSlavePipe) "Rsp " else "") + (if(relaxedMemoryTranslationRegister) "Rmtr " else "") + (if(earlyWaysHits) "Ewh " else "") + (if(withAmo) "Amo " else "") + (if(withSmp) "Smp " else "") + (if(directTlbHit) "Dtlb " else "") + (if(twoStageMmu) "Tsmmu " else "") + (if(asyncTagMemory) "Atm" else "")) {
        override def testParam = s"DBUS=CACHED DBUS_LOAD_DATA_WIDTH=$memDataWidth DBUS_STORE_DATA_WIDTH=$cpuDataWidth " + (if(withLrSc) "LRSC=yes " else "")  + (if(withAmo) "AMO=yes " else "")  + (if(withSmp) "DBUS_EXCLUSIVE=yes DBUS_INVALIDATE=yes " else "")

        override def applyOn(config: VexRiscvConfig): Unit = {
          config.plugins += new DBusCachedPlugin(
            config = new DataCacheConfig(
              cacheSize = cacheSize,
              bytePerLine = bytePerLine,
              wayCount = wayCount,
              addressWidth = 32,
              cpuDataWidth = cpuDataWidth, //Not tested
              memDataWidth = memDataWidth,
              catchAccessError = catchAll,
              catchIllegal = catchAll,
              catchUnaligned = catchAll,
              withLrSc = withLrSc,
              withAmo = withAmo,
              earlyWaysHits = earlyWaysHits,
              withExclusive = withSmp,
              withInvalidate = withSmp,
              directTlbHit = directTlbHit,
              asyncTagMemory = asyncTagMemory
            ),
            dBusCmdMasterPipe = dBusCmdMasterPipe,
            dBusCmdSlavePipe = dBusCmdSlavePipe,
            dBusRspSlavePipe = dBusRspSlavePipe,
            relaxedMemoryTranslationRegister = relaxedMemoryTranslationRegister,
            memoryTranslatorPortConfig = mmuConfig
          )
        }
      }
```

## Dependency declarations

### src/main/scala/vexriscv/plugin/DBusCachedPlugin.scala

```scala
class DAxiCachedPlugin(config : DataCacheConfig, memoryTranslatorPortConfig : Any = null) extends DBusCachedPlugin(config, memoryTranslatorPortConfig) {
  var dAxi  : Axi4 = null

  override def build(pipeline: VexRiscv): Unit = {
    super.build(pipeline)
    dBus.setAsDirectionLess()
    dAxi = master(dBus.toAxi4Shared().toAxi4()).setName("dAxi")
    dBus = null //For safety, as nobody should use it anymore :)
  }
}

trait DBusEncodingService {
  def addLoadWordEncoding(key: MaskedLiteral): Unit
  def addStoreWordEncoding(key: MaskedLiteral): Unit
  def bypassStore(data : Bits) : Unit
  def loadData() : Bits
}


case class TightlyCoupledDataBus() extends Bundle with IMasterSlave {
  val enable = Bool()
  val address = UInt(32 bits)
  val write_enable = Bool()
  val write_data = Bits(32 bits)
  val write_mask = Bits(4 bits)
  val read_data = Bits(32 bits)

  override def asMaster(): Unit = {
    out(enable, address, write_enable, write_data, write_mask)
    in(read_data)
  }
}

case class TightlyCoupledDataPortParameter(name : String, hit : UInt => Bool)
case class TightlyCoupledDataPort(p : TightlyCoupledDataPortParameter, var bus : TightlyCoupledDataBus)
```

### src/main/scala/vexriscv/ip/DataCache.scala

```scala
case class DataCacheConfig(cacheSize : Int,
                           bytePerLine : Int,
                           wayCount : Int,
                           addressWidth : Int,
                           cpuDataWidth : Int,
                           var rfDataWidth : Int = -1, //-1 mean cpuDataWidth
                           memDataWidth : Int,
                           catchAccessError : Boolean,
                           catchIllegal : Boolean,
                           catchUnaligned : Boolean,
                           earlyWaysHits : Boolean = true,
                           earlyDataMux : Boolean = false,
                           tagSizeShift : Int = 0, //Used to force infering ram
                           withLrSc : Boolean = false,
                           withAmo : Boolean = false,
                           withExclusive : Boolean = false,
                           withInvalidate : Boolean = false,
                           pendingMax : Int = 64,
                           directTlbHit : Boolean = false,
                           mergeExecuteMemory : Boolean = false,
                           asyncTagMemory : Boolean = false,
                           withWriteAggregation : Boolean = false){

  if(rfDataWidth == -1)  rfDataWidth = cpuDataWidth 
  assert(!(mergeExecuteMemory && (earlyDataMux || earlyWaysHits)))
  assert(!(earlyDataMux && !earlyWaysHits))
  assert(isPow2(pendingMax))
  assert(rfDataWidth <= memDataWidth)

  def lineCount = cacheSize/bytePerLine/wayCount
  def sizeMax = log2Up(bytePerLine)
  def sizeWidth = log2Up(sizeMax + 1)
  val aggregationWidth = if(withWriteAggregation) log2Up(memDataBytes+1) else 0
  def withWriteResponse = withExclusive
  def burstSize = bytePerLine*8/memDataWidth
  val burstLength = bytePerLine/(cpuDataWidth/8)
  def catchSomething = catchUnaligned || catchIllegal || catchAccessError
  def withInternalAmo = withAmo && !withExclusive
  def withInternalLrSc = withLrSc && !withExclusive
  def withExternalLrSc = withLrSc && withExclusive
  def withExternalAmo = withAmo && withExclusive
  def cpuDataBytes = cpuDataWidth/8
  def rfDataBytes = rfDataWidth/8
  def memDataBytes = memDataWidth/8
// ...
}

object DataCacheCpuExecute{
  implicit def implArgs(that : DataCacheCpuExecute): DataCacheCpuExecuteArgs = that.args
}

case class DataCacheCpuExecute(p : DataCacheConfig) extends Bundle with IMasterSlave{
  val isValid = Bool
  val address = UInt(p.addressWidth bit)
  val haltIt = Bool
  val args = DataCacheCpuExecuteArgs(p)
  val refilling = Bool

  override def asMaster(): Unit = {
    out(isValid, args, address)
    in(haltIt, refilling)
  }
}

case class DataCacheCpuExecuteArgs(p : DataCacheConfig) extends Bundle{
  val wr = Bool
  val size = UInt(log2Up(log2Up(p.cpuDataBytes)+1) bits)
  val isLrsc = p.withLrSc generate Bool()
  val isAmo = p.withAmo generate Bool()
  val amoCtrl = p.withAmo generate new Bundle {
    val swap = Bool()
    val alu = Bits(3 bits)
  }

  val totalyConsistent = Bool() //Only for AMO/LRSC
}

case class DataCacheCpuMemory(p : DataCacheConfig, mmu : MemoryTranslatorBusParameter) extends Bundle with IMasterSlave{
  val isValid = Bool
  val isStuck = Bool
  val isWrite = Bool
  val address = UInt(p.addressWidth bit)
  val mmuRsp  = MemoryTranslatorRsp(mmu)

  override def asMaster(): Unit = {
    out(isValid, isStuck, address)
    in(isWrite)
    out(mmuRsp)
  }
}


case class FenceFlags() extends Bundle {
  val SW,SR,SO,SI,PW,PR,PO,PI = Bool()
  val FM = Bits(4 bits)

  def SL = SR || SI
  def SS = SW || SO
  def PL = PR || PI
  def PS = PW || PO
  def forceAll(): Unit ={
    List(SW,SR,SO,SI,PW,PR,PO,PI).foreach(_ := True)
  }
  def clearFlags(): this.type ={
    List(SW,SR,SO,SI,PW,PR,PO,PI).foreach(_ := False)
    this
  }
}

case class DataCacheCpuWriteBack(p : DataCacheConfig) extends Bundle with IMasterSlave{
  val isValid = Bool()
  val isStuck = Bool()
  val isFiring = Bool()
  val isUser = Bool()
  val haltIt = Bool()
  val isWrite = Bool()
  val storeData = Bits(p.cpuDataWidth bit)
  val data = Bits(p.cpuDataWidth bit)
  val address = UInt(p.addressWidth bit)
  val mmuException, unalignedAccess, accessError = Bool()
  val keepMemRspData = Bool() //Used by external AMO to avoid having an internal buffer
  val fence = FenceFlags()
  val exclusiveOk = Bool()

  override def asMaster(): Unit = {
    out(isValid,isStuck,isUser, address, fence, storeData, isFiring)
    in(haltIt, data, mmuException, unalignedAccess, accessError, isWrite, keepMemRspData, exclusiveOk)
  }
}

case class DataCacheFlush(lineCount : Int) extends Bundle{
  val singleLine = Bool()
  val lineId = UInt(log2Up(lineCount) bits)
}

case class DataCacheCpuBus(p : DataCacheConfig, mmu : MemoryTranslatorBusParameter) extends Bundle with IMasterSlave{
  val execute   = DataCacheCpuExecute(p)
  val memory    = DataCacheCpuMemory(p, mmu)
  val writeBack = DataCacheCpuWriteBack(p)

  val redo = Bool()
  val flush = Stream(DataCacheFlush(p.lineCount))

  val writesPending = Bool()

  override def asMaster(): Unit = {
    master(execute)
    master(memory)
    master(writeBack)
    master(flush)
    in(redo, writesPending)
  }
}
// ...
class DataCache(val p : DataCacheConfig, mmuParameter : MemoryTranslatorBusParameter) extends Component{
  import p._

  val io = new Bundle{
    val cpu = slave(DataCacheCpuBus(p, mmuParameter))
    val mem = master(DataCacheMemBus(p))
  }
// ...
```

### src/main/scala/vexriscv/plugin/MmuPlugin.scala

```scala
trait DBusAccessService{
  def newDBusAccess() : DBusAccess
}

case class DBusAccessCmd() extends Bundle {
  val address = UInt(32 bits)
  val size = UInt(2 bits)
  val write = Bool
  val data = Bits(32 bits)
  val writeMask = Bits(4 bits)
}

case class DBusAccessRsp() extends Bundle {
  val data = Bits(32 bits)
  val error = Bool()
  val redo = Bool()
}

case class DBusAccess() extends Bundle {
  val cmd = Stream(DBusAccessCmd())
  val rsp = Flow(DBusAccessRsp())
}
```

### src/main/scala/vexriscv/Services.scala

```scala
trait JumpService{
  def createJumpInterface(stage : Stage, priority : Int = 0) : Flow[UInt] //High priority win
}

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

  def encodeBits() : Bits = {
    val encoded = Bits(2 bits)

    when(this.isUser()) {
      encoded := "00"
    }.elsewhen(this.isSupervisor()) {
      encoded := "01"
    }.otherwise {
      encoded := "11"
    }

    encoded
  }
}

case class PrivilegeServiceDefault() extends PrivilegeService{
  override def isUser(): Bool = False
  override def isSupervisor(): Bool = False
  override def isMachine(): Bool = True
  override def forceMachine(): Unit = {}
}

trait InterruptionInhibitor{
  def inhibateInterrupts() : Unit
}

trait ExceptionInhibitor{
  def inhibateException() : Unit
  def inhibateEbreakException() : Unit
}


trait RegFileService{
  def readStage() : Stage
}


case class MemoryTranslatorCmd() extends Bundle{
  val isValid = Bool
  val isStuck = Bool
  val virtualAddress  = UInt(32 bits)
  val bypassTranslation = Bool
}
case class MemoryTranslatorRsp(p : MemoryTranslatorBusParameter) extends Bundle{
  val physicalAddress = UInt(32 bits)
  val isIoAccess = Bool
  val isPaging = Bool
  val allowRead, allowWrite, allowExecute = Bool
  val exception = Bool
  val refilling = Bool
  val bypassTranslation = Bool
  val ways = Vec(MemoryTranslatorRspWay(), p.wayCount)
}
case class MemoryTranslatorRspWay() extends Bundle{
  val sel = Bool()
  val physical = UInt(32 bits)
}

case class MemoryTranslatorBusParameter(wayCount : Int = 0, latency : Int = 0)
case class MemoryTranslatorBus(p : MemoryTranslatorBusParameter) extends Bundle with IMasterSlave{
  val cmd = Vec(MemoryTranslatorCmd(), p.latency + 1)
  val rsp = MemoryTranslatorRsp(p)
  val end = Bool
  val busy = Bool

  override def asMaster() : Unit = {
    out(cmd, end)
    in(rsp, busy)
  }
}

trait MemoryTranslator{
  def newTranslationPort(priority : Int, args : Any) : MemoryTranslatorBus
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

### src/main/scala/vexriscv/plugin/IntAluPlugin.scala

```scala
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
```

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
// ...
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
// ...
}
// ...
class VexRiscv(val config : VexRiscvConfig) extends Component with Pipeline{
// ...
  def newStage(): Stage = { val s = new Stage; stages += s; s }
  val decode    = newStage()
  val execute   = newStage()
  val memory    = ifGen(config.withMemoryStage)    (newStage())
  val writeBack = ifGen(config.withWriteBackStage) (newStage())

  def stagesFromExecute = stages.dropWhile(_ != execute)
// ...
}
```

### src/main/scala/vexriscv/plugin/MemoryTranslatorPlugin.scala

```scala
object MemoryTranslatorPort{
  val PRIORITY_DATA = 1
  val PRIORITY_INSTRUCTION = 0
}
```

### src/main/scala/vexriscv/Riscv.scala

```scala
object Riscv{
  def misaToInt(values : String) = values.toLowerCase.map(e => 1 << (e-'a')).reduce(_ | _)

  def funct7Range = 31 downto 25
  def rdRange = 11 downto 7
  def funct3Range = 14 downto 12
  def rs1Range = 19 downto 15
  def rs2Range = 24 downto 20
  def rs3Range = 31 downto 27
  def csrRange = 31 downto 20
// ...
  def LB                 = M"-----------------000-----0000011"
  def LH                 = M"-----------------001-----0000011"
  def LW                 = M"-----------------010-----0000011"
  def LBU                = M"-----------------100-----0000011"
  def LHU                = M"-----------------101-----0000011"
  def SB                 = M"-----------------000-----0100011"
  def SH                 = M"-----------------001-----0100011"
  def SW                 = M"-----------------010-----0100011"

  def LR                 = M"00010--00000-----010-----0101111"
  def SC                 = M"00011------------010-----0101111"

  def AMOSWAP            = M"00001------------010-----0101111"
  def AMOADD             = M"00000------------010-----0101111"
  def AMOXOR             = M"00100------------010-----0101111"
  def AMOAND             = M"01100------------010-----0101111"
  def AMOOR              = M"01000------------010-----0101111"
  def AMOMIN             = M"10000------------010-----0101111"
  def AMOMAX             = M"10100------------010-----0101111"
  def AMOMINU            = M"11000------------010-----0101111"
  def AMOMAXU            = M"11100------------010-----0101111"
// ...
  def FENCE              = M"-----------------000-----0001111"
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

### src/main/scala/vexriscv/demo/GenFullWithTcm.scala

```scala
object GenFullWithTcm extends App{
  def config = VexRiscvConfig(
    plugins = List(
// ...
      new DBusCachedPlugin(
        config = new DataCacheConfig(
          cacheSize         = 4096,
          bytePerLine       = 32,
          wayCount          = 1,
          addressWidth      = 32,
          cpuDataWidth      = 32,
          memDataWidth      = 32,
          catchAccessError  = true,
          catchIllegal      = true,
          catchUnaligned    = true
        ),
        memoryTranslatorPortConfig = MmuPortConfig(
          portTlbSize = 6
        )
      ).newTightlyCoupledPort(
        TightlyCoupledDataPortParameter("dBusTc", a => a(31 downto 28) === 0x3)
      ),
// ...
    )
  )
// ...
}
```

### src/main/scala/vexriscv/plugin/DBusCachedPlugin.scala

```scala
class IBusDBusCachedTightlyCoupledRam(mapping : SizeMapping,
                                      withIBus : Boolean = true,
                                      withDBus : Boolean = true,
                                      ramAsBlackbox : Boolean = true,
                                      hexInit :   String = null,
                                      ramOffset : Long = -1) extends Plugin[VexRiscv]{
  var dbus : TightlyCoupledDataBus = null
  var ibus : TightlyCoupledBus = null

  override def setup(pipeline: VexRiscv) = {
    if(withDBus) {
      dbus = pipeline.service(classOf[DBusCachedPlugin]).newTightlyCoupledPort(addr => mapping.hit(addr))
      dbus.setCompositeName(this, "dbus").setAsDirectionLess()
    }
// ...
```

### src/test/cpp/regression/main.cpp

```cpp
	virtual void onReset(){
		top->dBus_cmd_ready = 1;
		top->dBus_rsp_valid = 0;
		#ifdef DBUS_AGGREGATION
		top->dBus_rsp_payload_aggregated = 0;
		#endif
		#ifdef DBUS_INVALIDATE
		top->dBus_inv_valid = 0;
		top->dBus_ack_ready = 0;
		top->dBus_sync_valid = 0;
		#ifdef DBUS_AGGREGATION
		top->dBus_sync_payload_aggregated = 0;
		#endif
		#endif
	}
```

## Documentation

### README.md

````text
#### DBusCachedPlugin

Multi way cache implementation with writh-through and allocate on read strategy. (Documentation is WIP)

You can invalidate the whole cache via the 0x500F instruction, and you can invalidate a address range (single line size) via the instruction 0x500F | RS1 << 15 where RS1 should not be X0 and point to one byte of the desired address to invalidate.


The memory bus is defined as :

```scala
case class DataCacheMemCmd(p : DataCacheConfig) extends Bundle{
  val wr = Bool
  val uncached = Bool
  val address = UInt(p.addressWidth bit)
  val data = Bits(p.cpuDataWidth bits)
  val mask = Bits(p.cpuDataWidth/8 bits)
  val size   = UInt(p.sizeWidth bits) //... 1 => 2 bytes ... 2 => 4 bytes ...
  val exclusive = p.withExclusive generate Bool()
  val last = Bool
}
case class DataCacheMemRsp(p : DataCacheConfig) extends Bundle{
  val aggregated = UInt(p.aggregationWidth bits)
  val last = Bool()
  val data = Bits(p.memDataWidth bit)
  val error = Bool
  val exclusive = p.withExclusive generate Bool()
}
case class DataCacheInv(p : DataCacheConfig) extends Bundle{
  val enable = Bool()
  val address = UInt(p.addressWidth bit)
}
case class DataCacheAck(p : DataCacheConfig) extends Bundle{
  val hit = Bool()
}

case class DataCacheSync(p : DataCacheConfig) extends Bundle{
  val aggregated = UInt(p.aggregationWidth bits)
}

case class DataCacheMemBus(p : DataCacheConfig) extends Bundle with IMasterSlave{
  val cmd = Stream (DataCacheMemCmd(p))
  val rsp = Flow (DataCacheMemRsp(p))

  val inv = p.withInvalidate generate Stream(Fragment(DataCacheInv(p)))
  val ack = p.withInvalidate generate Stream(Fragment(DataCacheAck(p)))
  val sync = p.withInvalidate generate Stream(DataCacheSync(p))

  override def asMaster(): Unit = {
    master(cmd)
    slave(rsp)

    if(p.withInvalidate) {
      slave(inv)
      master(ack)
      slave(sync)
    }
  }
}
```

If you don't use memory coherency you can ignore the inv/ack/sync streams, also write cmd should not generate any rsp transaction.

As the cache is write through, there is no write burst but only individual write transactions.
...
last should be set only on the last transaction of a burst.

Note that the cmd stream transaction need to be consumed before starting to send back some rsp transactions (1 cycle minimal latency)

Some documentation about Stream here : 

https://spinalhdl.github.io/SpinalDoc-RTD/master/SpinalHDL/Libraries/stream.html?highlight=stream

Flow are the same as Stream but without ready signal.
````
