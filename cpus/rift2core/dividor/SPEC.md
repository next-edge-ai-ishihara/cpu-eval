# Implement `Dividor`

Implement the complete `Dividor` class. Preserve the class name and interface shown below.

Return only the complete `class Dividor` definition in a single Scala code block, with no text outside the block.

## Class declaration

### src/main/scala/rift2Core/backend/Mul.scala

```scala
class Dividor(implicit p: Parameters) extends RiftModule {

  class DividorIO extends Bundle{
    val enq = Flipped(new DecoupledIO(new Mul_iss_info))
    val deq = Decoupled(new WriteBack_info(dw=64))
    val flush = Input(Bool())  
  }
  val io: DividorIO = IO(new DividorIO)
```

## Parent instantiation

### src/main/scala/rift2Core/backend/Mul.scala

```scala
  val dividor = Module(new Dividor)

  dividor.io.enq.bits  := io.mul_iss_exe.bits
  dividor.io.enq.valid := io.mul_iss_exe.bits.fun.isDiv & io.mul_iss_exe.valid

  dividor.io.flush := io.flush
// ...
  io.mul_iss_exe.ready :=
    Mux( io.mul_iss_exe.bits.fun.isMul, multiplier.io.enq.ready, dividor.io.enq.ready )
// ...
  val iwbArb = Module(new Arbiter(new WriteBack_info(dw=64), 2))
// ...
  iwbArb.io.in(1) <> dividor.io.deq
```

## Dependency declarations

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
// ...
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

### src/main/scala/rift2Core/backend/Mul.scala

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


  def preProcess( preDividend: UInt, preDdivisor: UInt ): (UInt, UInt, UInt, UInt) = {

    require( preDividend.getWidth == dw )
    require( preDdivisor.getWidth == dw )


    val dividend = Wire( UInt((dw+4).W) )
    val divisor  = Wire( UInt((dw+4).W ) )
    val iterations = Wire( UInt( (log2Ceil(dw+1)).W) )
    val recovery   = Wire( UInt( (log2Ceil(dw+1)).W) )

    val aShift = PriorityEncoder(preDividend.asBools.reverse)
    val bShift = PriorityEncoder(preDdivisor.asBools.reverse)

    val shiftDiff = Cat(0.U(1.W), bShift).asSInt - Cat(0.U(1.W), aShift).asSInt
    val quoBits   = Mux( shiftDiff < 0.S, 0.U, shiftDiff.asUInt)


    dividend := 
      Mux( quoBits(0), 
        Mux( shiftDiff < 0.S, preDividend << bShift, preDividend << aShift ), 
        Mux( shiftDiff < 0.S, preDividend << bShift, preDividend << aShift )  << 1
      )
    divisor  := (preDdivisor << bShift) << 1 


    iterations := (quoBits + 1.U) >> 1
    // ( bShift + 1.U((log2Ceil(dw+1)).W) ) >> 1

    recovery   := dw.U((log2Ceil(dw+1)).W) - bShift
    return (dividend, divisor, iterations, recovery)
  }
// ...
  val ( dividendInit, divisorInit, iterationsInit, recoveryInit ) = preProcess( preDividend = io.op1, preDdivisor = io.op2 )

  val isDivBusy = RegInit(false.B)
  val isRecurrence = RegInit(false.B)




  val cnt        = Reg(UInt( (log2Ceil(dw)).W))
  val ws = Reg(UInt(( dw + 4 ).W))
  val d          = RegEnable(divisorInit, io.enq.fire)
  val qm = Reg(UInt(dw.W))
  val q  = Reg(UInt(dw.W))
  val iterations = RegEnable(iterationsInit, io.enq.fire)
  val recovery   = RegEnable(recoveryInit  , io.enq.fire)


  val dividendIdx = ws(dw+3, dw-3)

  dontTouch(dividendIdx)
  val divisorIdx  = d(dw, dw-3)
  when(isRecurrence) { assert( divisorIdx(3) === 1.U ) }

  val qSel = QDS( dividendIdx, divisorIdx )
```

## Related source code

### src/main/scala/rift2Core/backend/Issue.scala

```scala
    res.param.dat.op0 := 0.U
    res.param.dat.op1 := postBufOperator(idx)(1)
    res.param.dat.op2 := postBufOperator(idx)(2)
    res.param.dat.op3 := 0.U
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

If both the quotient and remainder are required from the same division, the
recommended code sequence is insn:div[rdq,rs1,rs2] followed by rem[rdr,rs1,rs2].
insn:divu[] and insn:remu[] can also be used if appropriate. Note that `rdq` can
not be the same as `rs1` or `rs2`.
Microarchitectures can then fuse these into a single divide operation instead of
performing two separate divides.

[#norm:divw_divuw_op]#insn:divw[] and insn:divuw[] are RV64 instructions that divide the lower 32 bits of
`rs1` by the lower 32 bits of `rs2`, treating them as signed and
unsigned integers, placing the 32-bit quotient in `rd`,
sign-extended to 64 bits.# [#norm:remw_remuw_op]#insn:remw[] and insn:remuw[] are RV64 instructions that
provide the corresponding signed and unsigned remainder
operations.# [#norm:remw_remuw_result_sign]#Both insn:remw[] and insn:remuw[] always sign-extend the 32-bit result
to 64 bits, including on a divide by zero.#
(((MUL, div by zero)))
The semantics for division by zero and division overflow are summarized
in <<divby0>>. [#norm:div_by_zero]#The quotient of division by zero has all bits
set#, and [#norm:rem_by_zero]#the remainder of division by zero equals the dividend.#
[#norm:signed_div_overflow]#Signed division overflow occurs only when the most-negative integer is divided
by −1. The quotient of a signed division with overflow is
equal to the dividend, and the remainder is zero.# Unsigned division
overflow cannot occur.

[[divby0]]
.Semantics for division by zero and division overflow. L is the width of the operation in bits: XLEN for insn:div[], insn:divu[], insn:rem[], and insn:remu[], or 32 for insn:divw[], insn:divuw[], insn:remw[], and insn:remuw[].
[cols="<2,^,^,^,^,^,^",options="header",]
|===
|Condition |Dividend |Divisor |insn:divu[]/insn:divuw[] |insn:remu[]/insn:remuw[] |insn:div[]/insn:divw[] |insn:rem[]/insn:remw[]

|Division by zero       |_x_     |0  |2^L^-1 |_x_ |−1      |_x_
|Overflow (signed only) |-2^L-1^ |−1 |--     |--  |-2^L-1^ |0
|===
```
