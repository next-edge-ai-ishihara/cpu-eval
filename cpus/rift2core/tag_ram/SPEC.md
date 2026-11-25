# Implement `TagRAM`

Implement the complete `TagRAM` class. Preserve the class name and interface shown below.

Return only the complete `class TagRAM` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class TagRAM(tag_w: Int,  cl: Int) extends Module {
  def line_w   = log2Ceil(cl)

  class TagRAMIO extends Bundle{
    val addrr  = Input(UInt(line_w.W))
    val addrw  = Input(UInt(line_w.W))

    val dataw = Input( UInt(tag_w.W) )
    val datar = Output( UInt(tag_w.W) )
    val enw   = Input(Bool())
    val enr   = Input(Bool())    
  }

  val io: TagRAMIO = IO(new TagRAMIO)
```

## Parent instantiation

```scala
  val tagRAM = for ( _ <- 0 until cb ) yield { Module(new TagRAM(tag_w, cl)) }
// ...
    tagRAM(i).io.addrr  := addrSelR
    tagRAM(i).io.addrw  := addrSelW
    tagRAM(i).io.dataw  := tagInfoW
    tagInfoR(i)         := Mux( isTagBypass, tagBypassData, tagRAM(i).io.datar ) 
    tagRAM(i).io.enw   := tagEnW(i)
    tagRAM(i).io.enr   := io.enq.fire
```

## Documentation

### core/src/main/scala/chisel3/Mem.scala

```scala
/** A sequential/synchronous-read, sequential/synchronous-write memory.
  *
  * Writes take effect on the rising clock edge after the request. Reads return
  * data on the rising edge after the request. Read-after-write behavior (when
  * a read and write to the same address are requested on the same cycle) is
  * undefined.
  *
  * @note when multiple conflicting writes are performed on a Mem element, the
  * result is undefined (unlike Vec, where the last assignment wins)
  */
```
