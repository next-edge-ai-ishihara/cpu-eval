# Implement `SRT4Divider`

Implement the complete `SRT4Divider` class. Preserve the class name and interface shown below.

Return only the complete `class SRT4Divider` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class SRT4Divider[T<:Data]( pipeType: T, dw: Int ) extends Module {
  class SRT4DividerIO extends Bundle{
    val enq = Flipped(new DecoupledIO(pipeType))
    val deq = Decoupled(pipeType)
    val op1 = Input(UInt(dw.W))
    val op2 = Input(UInt(dw.W))
    val quo = Output(UInt((dw).W))
    val rem = Output(UInt((dw).W))
    val flush = Input(Bool())     
  }

  val io: SRT4DividerIO = IO(new SRT4DividerIO)
```

## Parent instantiation

### src/main/scala/rift2Core/backend/Mul.scala

```scala
  val op1Pre   = io.enq.bits.param.dat.op1
  val op2Pre   = io.enq.bits.param.dat.op2
  val is32wPre = io.enq.bits.fun.isDiv32w;
  val isUsiPre = io.enq.bits.fun.isDivusi;


  val dividend_load =
    // Cat ( 0.U(64.W),
      Mux(
        isUsiPre, 
        Mux(is32wPre, op1Pre(31,0), op1Pre),
        Mux(  
          is32wPre,
          Cat( 0.U(32.W), Mux(op1Pre(31), (~op1Pre(31,0) + 1.U), op1Pre(31,0))),
          Mux( op1Pre(63), (~op1Pre + 1.U), op1Pre)
        )
      )
    // )

  val divisor_load =
    Mux(
      isUsiPre,
      Mux(is32wPre, op2Pre(31,0), op2Pre),
      Mux( 
        is32wPre,
        Cat( Fill(32, 0.U), Mux(op2Pre(31), (~op2Pre(31,0) + 1.U), op2Pre(31,0))),
        Mux( op2Pre(63), (~op2Pre + 1.U), op2Pre )
      )
    )
// ...
  val isDivByZero = (op2Pre === 0.U)
  val isDivOverflow = ~isUsiPre & 
              (
                ( is32wPre & (op1Pre(31).asBool & (op1Pre(30,0) === 0.U) ) & (op2Pre(31,0).andR.asBool))
                |
                (~is32wPre & (op1Pre(63).asBool & (op1Pre(62,0) === 0.U) ) & (op2Pre(63,0).andR.asBool))								
              )
  val divBypass = isDivByZero | isDivOverflow
// ...
  val algDivider = Module(new SRT4Divider(new Mul_iss_info, 64))

    algDivider.io.enq.valid := io.enq.valid & ~divBypass
    algDivider.io.enq.bits  := io.enq.bits
    
    algDivider.io.op1 := dividend_load
    algDivider.io.op2 := divisor_load

    algDivider.io.flush := io.flush
// ...
  val quot_sign_corrcet = 
    Mux(dividend_sign^divisor_sign, ~algDivider.io.quo + 1.U, algDivider.io.quo)

  val rema_sign_corrcet = 
    Mux(dividend_sign, ~algDivider.io.rem + 1.U, algDivider.io.rem)
// ...
  divRtnArb.io.in(0).valid := algDivider.io.deq.valid
  divRtnArb.io.in(0).bits.res := divRes
  divRtnArb.io.in(0).bits.rd0 := algDivider.io.deq.bits.param.rd0

  algDivider.io.deq.ready  := divRtnArb.io.in(0).ready
// ...
  io.enq.ready := Mux(divBypass, divRtnArb.io.in(1).ready, algDivider.io.enq.ready)
```

## Dependency declarations

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
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

## Documentation

### src/unpriv/m-st-ext.adoc

```text
==== Division Operations

include::images/wavedrom/division-op.edn[]
[[division-op]]
//.Division operation instructions
(((MUL, DIV))) (((MUL, DIVU)))
[#norm:div_divu_op]#insn:div[] and insn:divu[] perform an XLEN bits by XLEN bits signed and unsigned
integer division of `rs1` by `rs2`, rounding towards zero.# [#norm:rem_remu_op]#insn:rem[] and insn:remu[]
provide the remainder of the corresponding division operation.# [#norm:rem_result_sign]#For insn:rem[],
the sign of a nonzero result equals the sign of the dividend.#

[NOTE]
====
For both signed and unsigned division, except in the case of overflow, it holds
that dividend = divisor {times} quotient + remainder.
====
```
