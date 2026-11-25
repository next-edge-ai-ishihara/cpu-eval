# Implement `IBusSimplePlugin`

Implement the complete `IBusSimplePlugin` class. Keep the bus and instruction-fetch definitions fixed.

Return only the complete `class IBusSimplePlugin` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### cpus/vexriscv/REGRESSION_CONFIGURATION.txt

```text
IBus Simple2InjStagevexriscv.plugin.DYNAMIC_TARGET
  mmuConfig = null
  latency = 2
  compressed = false
  injectorStage = true
  prediction = DYNAMIC_TARGET
  catchAll = true
  cmdForkOnSecondStage = false
  cmdForkPersistence = false
```

## Class declaration

### src/main/scala/vexriscv/plugin/IBusSimplePlugin.scala

```scala
package vexriscv.plugin

import vexriscv._
import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba3.ahblite.{AhbLite3, AhbLite3Config, AhbLite3Master}
import spinal.lib.bus.amba4.axi._
import spinal.lib.bus.avalon.{AvalonMM, AvalonMMConfig}
import spinal.lib.bus.bmb.{Bmb, BmbParameter}
import spinal.lib.bus.wishbone.{AddressGranularity, Wishbone, WishboneConfig}
import spinal.lib.bus.simple._
import vexriscv.Riscv.{FENCE, FENCE_I}
// ...
class IBusSimplePlugin(    resetVector : BigInt,
                       val cmdForkOnSecondStage : Boolean,
                       val cmdForkPersistence : Boolean,
                       val catchAccessFault : Boolean = false,
                           prediction : BranchPrediction = NONE,
                           historyRamSizeLog2 : Int = 10,
                           keepPcPlus4 : Boolean = false,
                           compressedGen : Boolean = false,
                       val busLatencyMin : Int = 1,
                       val pendingMax : Int = 7,
                           injectorStage : Boolean = true,
                       val rspHoldValue : Boolean = false,
                       val singleInstructionPipeline : Boolean = false,
                       val memoryTranslatorPortConfig : Any = null,
                           relaxPredictorAddress : Boolean = true,
                           predictionBuffer : Boolean = true,
                           bigEndian : Boolean = false,
                           vecRspBuffer : Boolean = false
                      ) extends IBusFetcherImpl(
    resetVector = resetVector,
    keepPcPlus4 = keepPcPlus4,
    decodePcGen = compressedGen,
    compressedGen = compressedGen,
    cmdToRspStageCount = busLatencyMin + (if(cmdForkOnSecondStage) 1 else 0),
    allowPcRegReusedForSecondStage = !(cmdForkOnSecondStage && cmdForkPersistence),
    injectorReadyCutGen = false,
    prediction = prediction,
    historyRamSizeLog2 = historyRamSizeLog2,
    injectorStage = injectorStage,
    relaxPredictorAddress = relaxPredictorAddress,
    fetchRedoGen = memoryTranslatorPortConfig != null,
  predictionBuffer = predictionBuffer){
```

## Parent instantiation

### src/test/scala/vexriscv/TestIndividualFeatures.scala

```scala
      val latency = r.nextInt(5) + 1
      val compressed = r.nextDouble() < rvcRate
      val injectorStage = r.nextBoolean() || latency == 1
      val prediction = random(r, List(NONE, STATIC, DYNAMIC, DYNAMIC_TARGET))
      val catchAll = universes.contains(VexRiscvUniverse.CATCH_ALL)
      val cmdForkOnSecondStage = r.nextBoolean()
      val cmdForkPersistence = r.nextBoolean()
      new VexRiscvPosition("Simple" + latency + (if(cmdForkOnSecondStage) "S2" else "") + (if(cmdForkPersistence) "P" else "")  + (if(injectorStage) "InjStage" else "") + (if(compressed) "Rvc" else "") + prediction.getClass.getTypeName().replace("$","")) with InstructionAnticipatedPosition{
        override def testParam = "IBUS=SIMPLE" + (if(compressed) " COMPRESSED=yes" else "")
        override def applyOn(config: VexRiscvConfig): Unit = config.plugins += new IBusSimplePlugin(
          resetVector = 0x80000000l,
          cmdForkOnSecondStage = cmdForkOnSecondStage,
          cmdForkPersistence = cmdForkPersistence,
          prediction = prediction,
          catchAccessFault = catchAll,
          compressedGen = compressed,
          busLatencyMin = latency,
          injectorStage = injectorStage,
          memoryTranslatorPortConfig = mmuConfig
        )
        override def instructionAnticipatedOk() = injectorStage
      }
```

## Dependency declarations

### src/main/scala/vexriscv/plugin/IBusSimplePlugin.scala

```scala
case class IBusSimpleCmd() extends Bundle{
  val pc = UInt(32 bits)
}

case class IBusSimpleRsp() extends Bundle with IMasterSlave{
  val error = Bool
  val inst  = Bits(32 bits)

  override def asMaster(): Unit = {
    out(error,inst)
  }
}


object IBusSimpleBus{
  def getAxi4Config() = Axi4Config(
    addressWidth = 32,
    dataWidth = 32,
    useId = false,
    useRegion = false,
    useBurst = false,
    useLock = false,
    useQos = false,
    useLen = false,
    useResp = true,
    useSize = false
  )

  def getAvalonConfig() = AvalonMMConfig.pipelined(
    addressWidth = 32,
    dataWidth = 32
  ).getReadOnlyConfig.copy(
    useResponse = true,
    maximumPendingReadTransactions = 8
  )

  def getWishboneConfig() = WishboneConfig(
    addressWidth = 30,
    dataWidth = 32,
    selWidth = 4,
    useSTALL = false,
    useLOCK = false,
    useERR = true,
    useRTY = false,
    tgaWidth = 0,
    tgcWidth = 0,
    tgdWidth = 0,
    useBTE = true,
    useCTI = true,
    addressGranularity = AddressGranularity.WORD
  )

  def getPipelinedMemoryBusConfig() = PipelinedMemoryBusConfig(
    addressWidth = 32,
    dataWidth = 32
  )


  def getAhbLite3Config() = AhbLite3Config(
    addressWidth = 32,
    dataWidth = 32
  )

  def getBmbParameter(plugin : IBusSimplePlugin = null) = BmbParameter(
    addressWidth = 32,
    dataWidth = 32,
    lengthWidth = 2,
    sourceWidth = 0,
    contextWidth = 0,
    canRead = true,
    canWrite = false,
    alignment     = BmbParameter.BurstAlignement.LENGTH,
    maximumPendingTransaction = if(plugin != null) plugin.pendingMax else Int.MaxValue
  )
}


case class IBusSimpleBus(plugin: IBusSimplePlugin) extends Bundle with IMasterSlave {
  var cmd = Stream(IBusSimpleCmd())
  var rsp = Flow(IBusSimpleRsp())

  override def asMaster(): Unit = {
    master(cmd)
    slave(rsp)
  }


  def cmdS2mPipe() : IBusSimpleBus = {
    val s = IBusSimpleBus(plugin)
    s.cmd    << this.cmd.s2mPipe()
    this.rsp << s.rsp
    s
  }


  def toAxi4ReadOnly(): Axi4ReadOnly = {
    assert(plugin.cmdForkPersistence)
    val axi = Axi4ReadOnly(IBusSimpleBus.getAxi4Config())

    axi.ar.valid := cmd.valid
    axi.ar.addr  := cmd.pc(axi.readCmd.addr.getWidth -1 downto 2) @@ U"00"
    axi.ar.prot  := "110"
    axi.ar.cache := "1111"
    cmd.ready := axi.ar.ready


    rsp.valid := axi.r.valid
    rsp.inst := axi.r.data
    rsp.error := !axi.r.isOKAY()
    axi.r.ready := True

    axi
  }

  def toAvalon(): AvalonMM = {
    assert(plugin.cmdForkPersistence)
    val avalonConfig = IBusSimpleBus.getAvalonConfig()
    val mm = AvalonMM(avalonConfig)

    mm.read := cmd.valid
    mm.address := (cmd.pc >> 2) @@ U"00"
    cmd.ready := mm.waitRequestn

    rsp.valid := mm.readDataValid
    rsp.inst := mm.readData
    rsp.error := mm.response =/= AvalonMM.Response.OKAY

    mm
  }

  def toWishbone(): Wishbone = {
    val wishboneConfig = IBusSimpleBus.getWishboneConfig()
    val bus = Wishbone(wishboneConfig)
    val cmdPipe = cmd.stage()

    bus.ADR := (cmdPipe.pc >>  2)
    bus.CTI := B"000"
    bus.BTE := "00"
    bus.SEL := "1111"
    bus.WE  := False
    bus.DAT_MOSI.assignDontCare()
    bus.CYC := cmdPipe.valid
    bus.STB := cmdPipe.valid


    cmdPipe.ready := cmdPipe.valid && (bus.ACK || bus.ERR)
    rsp.valid := bus.CYC && (bus.ACK || bus.ERR)
    rsp.inst := bus.DAT_MISO
    rsp.error := bus.ERR
    bus
  }

  def toPipelinedMemoryBus(): PipelinedMemoryBus = {
    val pipelinedMemoryBusConfig = IBusSimpleBus.getPipelinedMemoryBusConfig()
    val bus = PipelinedMemoryBus(pipelinedMemoryBusConfig)
    bus.cmd.arbitrationFrom(cmd)
    bus.cmd.address := cmd.pc.resized
    bus.cmd.write := False
    bus.cmd.mask.assignDontCare()
    bus.cmd.data.assignDontCare()
    rsp.valid := bus.rsp.valid
    rsp.inst := bus.rsp.payload.data
    rsp.error := False
    bus
  }


  //cmdForkPersistence need to bet set
  def toAhbLite3Master(): AhbLite3Master = {
    assert(plugin.cmdForkPersistence)
    val bus = AhbLite3Master(IBusSimpleBus.getAhbLite3Config())
    bus.HADDR     := this.cmd.pc
    bus.HWRITE    := False
    bus.HSIZE     := 2
    bus.HBURST    := 0
    bus.HPROT     := "1110"
    bus.HTRANS    := this.cmd.valid ## B"0"
    bus.HMASTLOCK := False
    bus.HWDATA.assignDontCare()
    this.cmd.ready := bus.HREADY

    val pending = RegInit(False) clearWhen(bus.HREADY) setWhen(this.cmd.fire)
    this.rsp.valid := bus.HREADY && pending
    this.rsp.inst := bus.HRDATA
    this.rsp.error := bus.HRESP
    bus
  }
  
  def toBmb() : Bmb = {
    val pipelinedMemoryBusConfig = IBusSimpleBus.getBmbParameter(plugin)
    val bus = Bmb(pipelinedMemoryBusConfig)
    bus.cmd.arbitrationFrom(cmd)
    bus.cmd.opcode := Bmb.Cmd.Opcode.READ
    bus.cmd.address := cmd.pc.resized
    bus.cmd.length := 3
    bus.cmd.last := True
    rsp.valid := bus.rsp.valid
    rsp.inst := bus.rsp.data
    rsp.error := bus.rsp.isError
    bus.rsp.ready := True
    bus
  }
}
```

### src/main/scala/vexriscv/plugin/Fetcher.scala

```scala
abstract class IBusFetcherImpl(var resetVector : BigInt,
                               val keepPcPlus4 : Boolean,
                               val decodePcGen : Boolean,
                               val compressedGen : Boolean,
                               val cmdToRspStageCount : Int,
                               val allowPcRegReusedForSecondStage : Boolean,
                               val injectorReadyCutGen : Boolean,
                               val prediction : BranchPrediction,
                               val historyRamSizeLog2 : Int,
                               val injectorStage : Boolean,
                               val relaxPredictorAddress : Boolean,
                               val fetchRedoGen : Boolean,
                               val predictionBuffer : Boolean = true) extends Plugin[VexRiscv] with JumpService with IBusFetcher{
  var prefetchExceptionPort : Flow[ExceptionCause] = null
  var decodePrediction : DecodePredictionBus = null
  var fetchPrediction : FetchPredictionBus = null
  var dynamicTargetFailureCorrection : Flow[UInt] = null
  var externalResetVector : UInt = null
  assert(cmdToRspStageCount >= 1)
//  assert(!(cmdToRspStageCount == 1 && !injectorStage))
  assert(!(compressedGen && !decodePcGen))
  var fetcherHalt : Bool = null
  var forceNoDecodeCond : Bool = null
  var pcValids : Vec[Bool] = null
  def pcValid(stage : Stage) = pcValids(pipeline.indexOf(stage))
  var incomingInstruction : Bool = null
  override def incoming() = incomingInstruction


  override def withRvc(): Boolean = compressedGen

  val injectionPorts = ArrayBuffer[Stream[Bits]]()
  override def getInjectionPort() = {
    injectionPorts.addRet(Stream(Bits(32 bits)))
  }
  def pcRegReusedForSecondStage = allowPcRegReusedForSecondStage && prediction != DYNAMIC_TARGET //TODO might not be required for  DYNAMIC_TARGET
  var predictionJumpInterface : Flow[UInt] = null

  override def haltIt(): Unit = fetcherHalt := True
  override def forceNoDecode(): Unit = forceNoDecodeCond := True
  case class JumpInfo(interface :  Flow[UInt], stage: Stage, priority : Int)
  val jumpInfos = ArrayBuffer[JumpInfo]()
  override def createJumpInterface(stage: Stage, priority : Int = 0): Flow[UInt] = {
    assert(stage != null)
    val interface = Flow(UInt(32 bits))
    jumpInfos += JumpInfo(interface,stage, priority)
    interface
  }
// ...
  override def setup(pipeline: VexRiscv): Unit = {
    fetcherHalt = False
    forceNoDecodeCond = False
    incomingInstruction = False
    if(resetVector == null) externalResetVector = in(UInt(32 bits).setName("externalResetVector"))

    prediction match {
      case NONE =>
      case STATIC | DYNAMIC => {
        predictionJumpInterface = createJumpInterface(pipeline.decode)
        decodePrediction = pipeline.service(classOf[PredictionInterface]).askDecodePrediction()
      }
      case DYNAMIC_TARGET => {
        fetchPrediction = pipeline.service(classOf[PredictionInterface]).askFetchPrediction()
      }
    }

    pcValids = Vec(Bool, pipeline.stages.size)
  }
// ...
  class FetchArea(pipeline : VexRiscv) extends Area {
    import pipeline._
    import pipeline.config._
    val externalFlush = stages.map(_.arbitration.flushNext).orR

    def getFlushAt(s : Any, lastCond : Boolean = true): Bool = {
      if(isDrivingDecode(s) && lastCond)  pipeline.decode.arbitration.isRemoved else externalFlush
    }
// ...
    case class FetchRsp() extends Bundle {
      val pc = UInt(32 bits)
      val rsp = IBusSimpleRsp()
      val isRvc = Bool()
    }


    val iBusRsp = new Area {
      val redoFetch = False
      val stages = Array.fill(cmdToRspStageCount + 1)(new Bundle {
        val input = Stream(UInt(32 bits))
        val output = Stream(UInt(32 bits))
        val halt = Bool()
      })

      stages(0).input << fetchPc.output
      for(s <- stages) {
        s.halt := False
        s.output << s.input.haltWhen(s.halt)
      }

      if(fetchPc.redo != null) {
        fetchPc.redo.valid := redoFetch
        fetchPc.redo.payload := stages.last.input.payload
      }

      val flush = (if(isDrivingDecode(IBUS_RSP)) pipeline.decode.arbitration.isRemoved || decode.arbitration.flushNext && !decode.arbitration.isStuck else externalFlush) || redoFetch
      for((s,sNext) <- (stages, stages.tail).zipped) {
        val sFlushed = if(s != stages.head) flush else False
        val sNextFlushed = flush
        if(s == stages.head && pcRegReusedForSecondStage) {
          sNext.input.arbitrationFrom(s.output.toEvent().m2sPipeWithFlush(sNextFlushed, false, collapsBubble = false, flushInput = sFlushed))
          sNext.input.payload := fetchPc.pcReg
          fetchPc.pcRegPropagate setWhen(sNext.input.ready)
        } else {
          sNext.input << s.output.m2sPipeWithFlush(sNextFlushed, false, collapsBubble = false, flushInput = sFlushed)
        }
      }

      val readyForError = True
      val output = Stream(FetchRsp())
      incomingInstruction setWhen(stages.tail.map(_.input.valid).reduce(_ || _))
    }
// ...
    def stageXToIBusRsp[T <: Data](stage : Any, input : T): (T) ={
      iBusRsp.stages.dropWhile(_ != stage).tail.foldLeft(input)((data,stage) => RegNextWhen(data, stage.output.ready))
    }

  }
}
```

### lib/src/main/scala/spinal/lib/Stream.scala

```scala
object StreamFifoLowLatency{
  def apply[T <: Data](dataType: T, depth: Int) = new StreamFifoLowLatency(dataType,depth)
}

class StreamFifoLowLatency[T <: Data](val dataType: HardType[T],val depth: Int,val latency : Int = 0, useVec : Boolean = false, initPayload : => Option[T] = None) extends Component {
  assert(latency == 0 || latency == 1)

  val io = new Bundle with StreamFifoInterface[T]{
    val push = slave Stream (dataType)
    val pop = master Stream (dataType)
    val flush = in Bool() default(False)
    val occupancy    = out UInt (log2Up(depth + 1) bits)
    val availability = out UInt (log2Up(depth + 1) bits)
    override def pushOccupancy = occupancy
    override def popOccupancy = occupancy
  }

  val fifo = new StreamFifo(
    dataType = dataType,
    depth = depth,
    withAsyncRead = true,
    withBypass = latency == 0,
    useVec = useVec,
    initPayload = initPayload
  )

  io.push <> fifo.io.push
  io.pop <> fifo.io.pop
  io.flush <> fifo.io.flush
  io.occupancy <> fifo.io.occupancy
  io.availability <> fifo.io.availability
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

### src/test/cpp/regression/main.cpp

```cpp
				for(SimElement* simElement : simElements) simElement->preCycle();

				dump(i + 1);

				checks();
				//top->eval();
				top->clk = 1;
				top->eval();

				instanceCycles += 1;

				for(SimElement* simElement : simElements) simElement->postCycle();
// ...
#ifdef IBUS_SIMPLE
class IBusSimple : public SimElement{
public:
	uint32_t pendings[256];
	uint32_t rPtr = 0, wPtr = 0;

	Workspace *ws;
	VVexRiscv* top;
	IBusSimple(Workspace* ws){
		this->ws = ws;
		this->top = ws->top;
	}

	virtual void onReset(){
		top->iBus_cmd_ready = 1;
		top->iBus_rsp_valid = 0;
	}

	virtual void preCycle(){
		if (top->iBus_cmd_valid && top->iBus_cmd_ready) {
			//assertEq(top->iBus_cmd_payload_pc & 3,0);
			pendings[wPtr] = (top->iBus_cmd_payload_pc);
			wPtr = (wPtr + 1) & 0xFF;
			//ws->iBusAccess(top->iBus_cmd_payload_pc,&inst_next,&error_next);
		}
	}
	//TODO doesn't catch when instruction removed ?
	virtual void postCycle(){
		top->iBus_rsp_valid = 0;
		if(rPtr != wPtr && (!ws->iStall || VL_RANDOM_I_WIDTH(7) < 100)){
	        uint32_t inst_next;
	        bool error_next;
		    ws->iBusAccess(pendings[rPtr], &inst_next,&error_next);
        	rPtr = (rPtr + 1) & 0xFF;
			top->iBus_rsp_payload_inst = inst_next;
			top->iBus_rsp_valid = 1;
			top->iBus_rsp_payload_error = error_next;
		} else {
		    top->iBus_rsp_payload_inst = VL_RANDOM_I_WIDTH(32);
		    top->iBus_rsp_payload_error = VL_RANDOM_I_WIDTH(1);
		}
		if(ws->iStall) top->iBus_cmd_ready = VL_RANDOM_I_WIDTH(7) < 100;
	}
};
#endif
```

### src/main/scala/vexriscv/VexRiscvBmbGenerator.scala

```scala
      case plugin: IBusSimplePlugin => iBus.load(plugin.iBus.toBmb())
```

## Documentation

### README.md

```text
#### IBusSimplePlugin

This plugin implements the CPU frontend (instruction fetch) via a very simple and neutral memory interface going outside the CPU.

| Parameters | type | description |
| ------ | ----------- | ------ |
| catchAccessFault | Boolean | When true, an instruction read response with read error asserted results in a CPU exception trap. |
| resetVector | BigInt | Address of the program counter after the reset. |
| cmdForkOnSecondStage | Boolean | When false, branches immediately update the program counter. This minimizes branch penalties but might reduce FMax because the instruction bus address signal is a combinatorial path. When true, this combinatorial path is removed and the program counter is updated one cycle after a branch is detected. While FMax may improve, an additional branch penalty will be incurred as well. |
| cmdForkPersistence  | Boolean | When false, requests on the iBus can disappear/change before they are acknowledged. This reduces area but isn't safe/supported by many arbitration/slaves. When true, once initiated, iBus requests will stay until they are acknowledged. |
| compressedGen | Boolean | Enable RISC-V compressed instruction (RVC) support. |
| busLatencyMin | Int | Specifies the minimal latency between the iBus.cmd and iBus.rsp. A corresponding number of stages are added to the frontend to keep the IPC to 1.|
| injectorStage | Boolean | When true, a stage between the frontend and the decode stage of the CPU is added to improve FMax. (busLatencyMin + injectorStage) should be at least two. |
| prediction | BranchPrediction | Can be set to NONE/STATIC/DYNAMIC/DYNAMIC_TARGET to specify the branch predictor implementation. See below for more details. |
| historyRamSizeLog2 | Int | Specify the number of entries in the direct mapped prediction cache of DYNAMIC/DYNAMIC_TARGET implementation. 2 pow historyRamSizeLog2 entries. |
...
**Important** : check out the cmdForkPersistence parameter, because if it is not set, it can break the iBus compatibility with your memory system (unless you externaly add some buffers).

Setting cmdForkPersistence and cmdForkOnSecondStage improves iBus cmd timings.

The iBusSimplePlugin includes bridges to convert from the IBusSimpleBus to AXI4, Avalon, and Wishbone interfaces.
```
