# Implement `DatRAM`

Implement the complete `DatRAM` class. Preserve the class name and interface shown below.

Return only the complete `class DatRAM` definition in a single Scala code block, with no text outside the block.

## Class declaration

### src/main/scala/base/CacheRAM.scala

```scala
class DatRAM(dw: Int, cl: Int) extends Module {
// ...
  def line_w   = log2Ceil(cl)

  class DatRAMIO extends Bundle{
    val addrr  = Input(UInt(line_w.W))
    val addrw  = Input(UInt(line_w.W))

    val dataw  = Input( Vec( dw/8, UInt(8.W) ) )
    val datawm = Input( Vec( dw/8, Bool()) )

    val datar = Output( Vec( dw/8, UInt(8.W) ) )
    val enw   = Input(Bool())
    val enr   = Input(Bool())    
  }

  val io: DatRAMIO = IO(new DatRAMIO)
```

## Parent instantiation

### src/main/scala/rift2Core/backend/LSU/DcacheStage.scala

```scala
  val datRAM = for ( _ <- 0 until cb ) yield { Module(new DatRAM(dw, cl)) }
// ...
  val pipeStage1Valid = RegNext(io.enq.fire, false.B)
  val pipeStage1Bits  = RegNext(io.enq.bits)
// ...
  datInfoWM :=
    Mux1H(Seq(
      (pipeStage1Bits.fun.grant)     -> Fill(dw/8, 1.U),
      (pipeStage1Bits.fun.is_access) -> pipeStage1Bits.wstrb
    )).asBools

  for( i <- 0 until cb ) {

    val isTagBypass   = RegEnable( tagEnW(i) & (addrSelR === addrSelW), io.enq.fire )
    val tagBypassData = RegEnable( tagInfoW, io.enq.fire & tagEnW(i) & (addrSelR === addrSelW) )
    val isDatBypass   = RegEnable( datEnW(i) & (addrSelR === addrSelW), io.enq.fire )
    val datBypassData = RegEnable( datInfoW, io.enq.fire & datEnW(i) & (addrSelR === addrSelW) )
    val datBypassWM   = RegEnable( datInfoWM, io.enq.fire & datEnW(i) & (addrSelR === addrSelW) )
    

    tagRAM(i).io.addrr  := addrSelR
    tagRAM(i).io.addrw  := addrSelW
    tagRAM(i).io.dataw  := tagInfoW
    tagInfoR(i)         := Mux( isTagBypass, tagBypassData, tagRAM(i).io.datar ) 
    tagRAM(i).io.enw   := tagEnW(i)
    tagRAM(i).io.enr   := io.enq.fire


    datRAM(i).io.addrr  := addrSelR
    datRAM(i).io.addrw  := addrSelW
    datRAM(i).io.dataw  := datInfoW
    datRAM(i).io.datawm := datInfoWM
    datInfoR(i)         := (for( w <- 0 until dw/8 ) yield { Mux(isDatBypass & datBypassWM(w), datBypassData(w), datRAM(i).io.datar(w)) })
    datRAM(i).io.enw    := datEnW(i)
    datRAM(i).io.enr    := io.enq.fire

  }
```

### src/main/scala/rift2Core/frontend/IF2.scala

```scala
  val datRAM = for ( _ <- 0 until cb ) yield { Module(new DatRAM(dw, cl)) }
```

### src/main/scala/rift2Core/privilege/PTW.scala

```scala
  val datRAM = Module(new DatRAM(dw, cl))
```

## Additional requirement

When `enr` is high at a rising clock edge, `datar` presents the row at `addrr` throughout the following cycle whatever the value of `enr` in that cycle, and when `enw` is high at a rising clock edge, each byte `i` of the row at `addrw` whose `datawm(i)` is set takes the value of `dataw(i)` while the other bytes keep their values.
