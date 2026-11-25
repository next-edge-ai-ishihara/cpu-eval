# Implement `MulDiv`

Implement the complete `MulDiv` class. Preserve the class name and interface shown below.

Return only the complete `class MulDiv` definition in a single Scala code block, with no text outside the block.

## Package and imports

### src/main/scala/rift2Core/backend/Mul.scala

```scala
package rift2Core.backend


import chisel3._
import chisel3.util._
import rift2Core.define._
import base._


import rift2Chip._

import org.chipsalliance.cde.config._
```

## Parent instantiation

### src/main/scala/rift2Core/backend/Execute.scala

```scala
  val mulDiv = (if( mulNum > 0 ) { for ( _ <- 0 until mulNum ) yield Module(new MulDiv) } else { Seq(Module(new FakeMulDiv)) })
```

## Dependency declarations

### src/main/scala/rift2Core/backend/Mul.scala

```scala
/** the RV64M will be executed in this module */
abstract class MulDivBase(implicit p: Parameters) extends RiftModule {
  
  class MulDivIO extends Bundle{
    val mul_iss_exe = Flipped(new DecoupledIO(new Mul_iss_info))
    val mul_exe_iwb = new DecoupledIO(new WriteBack_info(dw=64))
    val flush = Input(Bool())    
  }

  val io: MulDivIO = IO(new MulDivIO)

  val mul_exe_iwb_fifo = Module( new Queue( new WriteBack_info(dw=64), 1, true, false ) )
  mul_exe_iwb_fifo.reset := reset.asBool | io.flush
  io.mul_exe_iwb <> mul_exe_iwb_fifo.io.deq

}
// ...
class MultiplierIO[T<:Data]( pipeType: T, dw: Int ) extends Bundle{
  val enq = Flipped(new DecoupledIO(pipeType))
  val deq = Decoupled(pipeType)
  val op1 = Input(UInt(dw.W))
  val op2 = Input(UInt(dw.W))
  val res = Output(UInt((2*dw).W))
  val flush = Input(Bool())     
}
// ...
class NorMultiplier[T<:Data]( pipeType: T, dw: Int ) extends Module {
  val io: MultiplierIO[T] = IO(new MultiplierIO( pipeType, dw ))

  io.deq <> io.enq
  io.res := (io.op1.asSInt * io.op2.asSInt).asUInt
}
// ...
class Dividor(implicit p: Parameters) extends RiftModule {

  class DividorIO extends Bundle{
    val enq = Flipped(new DecoupledIO(new Mul_iss_info))
    val deq = Decoupled(new WriteBack_info(dw=64))
    val flush = Input(Bool())  
  }
  val io: DividorIO = IO(new DividorIO)
// ...
}
```

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class Mul_isa extends Bundle {
  val mul     = Bool()
  val mulh    = Bool()
  val mulhsu = Bool()
  val mulhu   = Bool()
  val div     = Bool()
  val divu    = Bool()
  val rem     = Bool()
  val remu    = Bool()
  val mulw    = Bool()
  val divw    = Bool()
  val divuw   = Bool()
  val remw    = Bool()
  val remuw   = Bool()

  def isDiv32w = divw | divuw | remw  | remuw
  def isDivusi = divu | remu  | divuw | remuw


  def isMul = mul | mulh | mulhsu | mulhu | mulw
  def isDiv = div | divu | divw | divuw | rem | remu | remw | remuw

  def is_mulDiv = isMul | isDiv



}
// ...
class RD_PHY(implicit p: Parameters) extends RiftBundle {
  val rd0 = UInt((log2Ceil(maxRegNum)).W)
}

class Operation_source(dw: Int)(implicit p: Parameters) extends RiftBundle {
  val op0 = UInt(dw.W)
  val op1 = UInt(dw.W)
  val op2 = UInt(dw.W)
  val op3 = UInt(dw.W)
}
// ...
class Mul_param(implicit p: Parameters) extends RD_PHY {
  val dat = new Operation_source(dw=64)

// override def cloneType = ( new Mul_param ).asInstanceOf[this.type]
}

class Mul_iss_info(implicit p: Parameters) extends RiftBundle {
  val fun = new Mul_isa
  val param = new Mul_param
}



class WriteBack_info(dw:Int)(implicit p: Parameters) extends RD_PHY {
  val res = UInt(dw.W)
}
```

### src/main/scala/base/Util.scala

```scala
object sextXTo{
  def apply(x: UInt, n: Int): UInt = {
    require(x.getWidth <= n)
    if (x.getWidth == n) x
    else Cat(Fill(n - x.getWidth, x(x.getWidth-1)), x)
  }  
}
```

## Related source code

### src/main/scala/rift2Core/backend/Issue.scala

```scala
    res.fun := bufInfo(idx).mulIsa

    res.param.dat.op0 := 0.U
    res.param.dat.op1 := postBufOperator(idx)(1)
    res.param.dat.op2 := postBufOperator(idx)(2)
    res.param.dat.op3 := 0.U
```

## Documentation

### src/unpriv/m-st-ext.adoc

```text
[#norm:mul_op]#insn:mul[] performs an XLEN-bit×XLEN-bit multiplication of
`rs1` by `rs2` and places the lower XLEN bits in the destination
register.# [#norm:mulh_mulhu_mulhsu_op]#insn:mulh[], insn:mulhu[], and insn:mulhsu[] perform the same multiplication but
return the upper XLEN bits of the full 2×XLEN-bit
product, for signed×signed,
unsigned×unsigned, and `rs1`×unsigned `rs2` multiplication.#
...
[#norm:mulw_op]#insn:mulw[] is an RV64 instruction that multiplies the lower 32 bits of the
source registers, placing the sign extension of the lower 32 bits of the
result into the destination register.#
```

## Additional requirement

`mul_iss_exe` accepts a multiply request without waiting for an earlier divide to finish, and each accepted request produces exactly one `mul_exe_iwb` transfer carrying its `rd0` unless `flush` is asserted before that transfer, in which case it produces none.
