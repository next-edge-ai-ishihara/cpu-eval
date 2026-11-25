# Implement `DataCache`

Implement the complete `DataCache` class.

Return only the complete `class DataCache` definition in a single Scala code block, with no text outside the block.

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

### src/main/scala/vexriscv/ip/DataCache.scala

```scala
package vexriscv.ip

import vexriscv._
import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axi.{Axi4Config, Axi4Shared}
import spinal.lib.bus.avalon.{AvalonMM, AvalonMMConfig}
import spinal.lib.bus.bmb.{Bmb, BmbAccessParameter, BmbCmd, BmbInvalidationParameter, BmbParameter, BmbSourceParameter}
import spinal.lib.bus.wishbone.{AddressGranularity, Wishbone, WishboneConfig}
import spinal.lib.bus.simple._
import vexriscv.plugin.DBusSimpleBus
// ...
class DataCache(val p : DataCacheConfig, mmuParameter : MemoryTranslatorBusParameter) extends Component{
  import p._

  val io = new Bundle{
    val cpu = slave(DataCacheCpuBus(p, mmuParameter))
    val mem = master(DataCacheMemBus(p))
  }
// ...
```

## Parent instantiation

### src/main/scala/vexriscv/plugin/DBusCachedPlugin.scala

```scala
    val cache = new DataCache(
      this.config.copy(
        mergeExecuteMemory = writeBack == null,
        rfDataWidth = 32
      ),
      mmuParameter = mmuBus.p
    )
```

## Dependency declarations

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
  def getAxi4SharedConfig() = Axi4Config(
    addressWidth = addressWidth,
    dataWidth = memDataWidth,
    useId = false,
    useRegion = false,
    useBurst = false,
    useLock = false,
    useQos = false
  )


  def getAvalonConfig() = AvalonMMConfig.bursted(
    addressWidth = addressWidth,
    dataWidth = memDataWidth,
    burstCountWidth = log2Up(burstSize + 1)).copy(
    useByteEnable = true,
    constantBurstBehavior = true,
    burstOnBurstBoundariesOnly = true,
    useResponse = true,
    maximumPendingReadTransactions = 2
  )

  def getWishboneConfig() = WishboneConfig(
    addressWidth = 32-log2Up(memDataWidth/8),
    dataWidth = memDataWidth,
    selWidth = memDataBytes,
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

  def getBmbParameter() = BmbParameter(
    BmbAccessParameter(
      addressWidth = 32,
      dataWidth = memDataWidth
    ).addSources(1, BmbSourceParameter(
      lengthWidth = log2Up(this.bytePerLine),
      contextWidth = (if(!withWriteResponse) 1 else 0) + aggregationWidth,
      alignment  = BmbParameter.BurstAlignement.LENGTH,
      canExclusive = withExclusive,
      withCachedRead = true,
      canInvalidate = withInvalidate,
      canSync = withInvalidate
    )),
    BmbInvalidationParameter(
      invalidateLength = log2Up(this.bytePerLine),
      invalidateAlignment = BmbParameter.BurstAlignement.LENGTH
    )
  )
}
// ...
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
```

### src/main/scala/vexriscv/Services.scala

```scala
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
```

## Related source code

### src/main/scala/vexriscv/plugin/DBusCachedPlugin.scala

```scala
      //Manage write to read hit ordering (ensure invalidation timings)
      val fence = new Area {
        insert(MEMORY_FORCE_CONSTISTENCY) := False
        when(input(INSTRUCTION)(25)) { //RL
          if (withLrSc) insert(MEMORY_FORCE_CONSTISTENCY) setWhen (input(MEMORY_LRSC))
          if (withAmo) insert(MEMORY_FORCE_CONSTISTENCY) setWhen (input(MEMORY_AMO))
        }
      }
// ...
      cache.io.cpu.flush.valid := arbitration.isValid && input(MEMORY_MANAGMENT)
      cache.io.cpu.flush.singleLine := input(INSTRUCTION)(Riscv.rs1Range) =/= 0
      cache.io.cpu.flush.lineId := U(input(RS1) >> log2Up(bytePerLine)).resized
      cache.io.cpu.execute.args.totalyConsistent := input(MEMORY_FORCE_CONSTISTENCY)
      arbitration.haltItself setWhen(cache.io.cpu.flush.isStall || cache.io.cpu.execute.haltIt)

      if(withLrSc) {
        cache.io.cpu.execute.args.isLrsc := False
        when(input(MEMORY_LRSC)){
          cache.io.cpu.execute.args.isLrsc := True
        }
      }

      if(withAmo){
        cache.io.cpu.execute.isAmo := input(MEMORY_AMO)
        cache.io.cpu.execute.amoCtrl.alu := input(INSTRUCTION)(31 downto 29)
        cache.io.cpu.execute.amoCtrl.swap := input(INSTRUCTION)(27)
      }


      when(cache.io.cpu.execute.refilling && arbitration.isValid){
        arbitration.haltByOther := True
      }
// ...
      val rspData = CombInit(cache.io.cpu.writeBack.data)
      val rspSplits = rspData.subdivideIn(8 bits)
      val rspShifted = Bits(cpuDataWidth bits)
      //Generate minimal mux to move from a wide aligned memory read to the register file shifter representation
      for(i <- 0 until cpuDataWidth/8){
        val srcSize = 1 << (log2Up(cpuDataBytes) - log2Up(i+1))
        val srcZipped = rspSplits.zipWithIndex.filter{case (v, b) => b % (cpuDataBytes/srcSize) == i}
        val src = srcZipped.map(_._1)
        val range = cache.cpuWordToRfWordRange.high downto cache.cpuWordToRfWordRange.high+1-log2Up(srcSize)
        val sel = cache.io.cpu.writeBack.address(range)
//        println(s"$i $srcSize $range ${srcZipped.map(_._2).mkString(",")}")
        rspShifted(i*8, 8 bits) := src.read(sel)
      }
// ...
```

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

### src/test/cpp/regression/main.cpp

```cpp
	virtual void preCycle(){
		if (top->dBus_cmd_valid && top->dBus_cmd_ready) {
            if(top->dBus_cmd_payload_wr){
                int size = 1 << top->dBus_cmd_payload_size;
                #ifdef DBUS_INVALIDATE
                    pendingSync += 1;
                #endif
                #ifndef DBUS_EXCLUSIVE
                    bool error;
                    int shift = top->dBus_cmd_payload_address & (DBUS_STORE_DATA_WIDTH/8-1);
                    ws->dBusAccess(top->dBus_cmd_payload_address,1,size,((uint8_t*)&top->dBus_cmd_payload_data) + shift,&error);
                #else
                    bool cancel = false, error = false;
                    if(top->dBus_cmd_payload_exclusive){
                        bool hit = reservationValid && reservationAddress == top->dBus_cmd_payload_address;
                        rsp.exclusive = hit;
                        cancel = !hit;
                    }
                    if(!cancel) {
                        for(int idx = 0;idx < 1;idx++){
                            bool localError = false;
                            int shift = top->dBus_cmd_payload_address & (DBUS_STORE_DATA_WIDTH/8-1);
                            ws->dBusAccess(top->dBus_cmd_payload_address,1,size,((uint8_t*)&top->dBus_cmd_payload_data) + shift,&localError);
                            error |= localError;
                        }
                    }

                    reservationValid = false;
                    rsp.last = true;
                    rsp.error = error;
                    rsps.push(rsp);
                #endif
            } else {
                bool error = false;
                uint32_t beatCount = (((1 << top->dBus_cmd_payload_size)*8+DBUS_LOAD_DATA_WIDTH-1) / DBUS_LOAD_DATA_WIDTH)-1;
                uint32_t startAt = top->dBus_cmd_payload_address;
                uint32_t endAt = top->dBus_cmd_payload_address + (1 << top->dBus_cmd_payload_size);
                uint32_t address = top->dBus_cmd_payload_address & ~(DBUS_LOAD_DATA_WIDTH/8-1);
                uint8_t buffer[64];
                ws->dBusAccess(top->dBus_cmd_payload_address,0,1 << top->dBus_cmd_payload_size,buffer, &error);
                for(int beat = 0;beat <= beatCount;beat++){
                    for(int i = 0;i < DBUS_LOAD_DATA_WIDTH/8;i++){
                        rsp.data[i] = (address >= startAt && address < endAt) ? buffer[address-top->dBus_cmd_payload_address] : VL_RANDOM_I_WIDTH(8);
                        address += 1;
                    }
                    rsp.last = beat == beatCount;
                    #ifdef DBUS_EXCLUSIVE
                        if(top->dBus_cmd_payload_exclusive){
                            rsp.exclusive = true;
                            reservationValid = true;
                            reservationAddress = top->dBus_cmd_payload_address;
                        }
                    #endif
                    rsp.error = error;
                    rsps.push(rsp);
                }

                #ifdef DBUS_INVALIDATE
                    if(ws->allowInvalidate){
                        if(VL_RANDOM_I_WIDTH(7) < 10){
                            invalidationHint.push(top->dBus_cmd_payload_address + VL_RANDOM_I_WIDTH(5));
                        }
                    }
                #endif
            }
		}
		#ifdef DBUS_INVALIDATE
            if(top->dBus_sync_valid && top->dBus_sync_ready){
                pendingSync -= 1;
            }
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
