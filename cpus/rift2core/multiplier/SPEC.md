# Implement `Multiplier`

Implement the complete `Multiplier` class. Preserve the class name and interface shown below.

Return only the complete `class Multiplier` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class Multiplier[T<:Data]( pipeType: T, dw: Int ) extends Module {



  val io: MultiplierIO[T] = IO(new MultiplierIO( pipeType, dw ))
```

## Parent instantiation

```scala
  val mul_op1 =
    Mux(
      io.mul_iss_exe.bits.fun.mulw,
      Cat(Fill(33, mul_op1_sign), io.mul_iss_exe.bits.param.dat.op1(31,0)),
      Cat(mul_op1_sign, io.mul_iss_exe.bits.param.dat.op1)
    )

  val mul_op2 =
    Mux(
      io.mul_iss_exe.bits.fun.mulw,
      Cat(Fill(33, mul_op2_sign), io.mul_iss_exe.bits.param.dat.op2(31,0)),
      Cat(mul_op2_sign, io.mul_iss_exe.bits.param.dat.op2)
    )
// ...
  val multiplier = Module(new Multiplier(new Mul_iss_info, 65) )
// ...
  multiplier.io.enq.valid := io.mul_iss_exe.valid & io.mul_iss_exe.bits.fun.isMul
  multiplier.io.op1 := mul_op1
  multiplier.io.op2 := mul_op2
  multiplier.io.enq.bits := io.mul_iss_exe.bits
  multiplier.io.flush := io.flush
// ...
  val mulRes = Mux1H(Seq(
    multiplier.io.deq.bits.fun.mul    -> multiplier.io.res(63,0),
    multiplier.io.deq.bits.fun.mulh   -> multiplier.io.res(127,64),
    multiplier.io.deq.bits.fun.mulhsu -> multiplier.io.res(127,64),
    multiplier.io.deq.bits.fun.mulhu  -> multiplier.io.res(127,64),
    multiplier.io.deq.bits.fun.mulw   -> sextXTo(multiplier.io.res(31,0), 64 ),
  ))
// ...
  multiplier.io.deq.ready := iwbArb.io.in(0).ready
  iwbArb.io.in(0).valid := multiplier.io.deq.valid
  iwbArb.io.in(0).bits.rd0 := multiplier.io.deq.bits.param.rd0
```

## Dependency declarations

```scala
class MultiplierIO[T<:Data]( pipeType: T, dw: Int ) extends Bundle{
  val enq = Flipped(new DecoupledIO(pipeType))
  val deq = Decoupled(pipeType)
  val op1 = Input(UInt(dw.W))
  val op2 = Input(UInt(dw.W))
  val res = Output(UInt((2*dw).W))
  val flush = Input(Bool())     
}
```

## Related source code

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

## Documentation

### src/unpriv/m-st-ext.adoc

```asciidoc
[[m-mul]]
==== Multiplication Operations

include::images/wavedrom/m-st-ext-for-int-mult.edn[]
[[m-st-ext-for-int-mult]]
//.Multiplication operation instructions
(((MUL, MULH))) (((MUL, MULHU))) (((MUL, MULHSU)))
[#norm:mul_op]#insn:mul[] performs an XLEN-bit×XLEN-bit multiplication of
`rs1` by `rs2` and places the lower XLEN bits in the destination
register.# [#norm:mulh_mulhu_mulhsu_op]#insn:mulh[], insn:mulhu[], and insn:mulhsu[] perform the same multiplication but
return the upper XLEN bits of the full 2×XLEN-bit
product, for signed×signed,
unsigned×unsigned, and `rs1`×unsigned `rs2` multiplication.#

If both the high and low bits of the same product are required, the recommended
code sequence is insn:mulh[rdh,rs1,rs2] followed by insn:mul[rdl,rs1,rs2].
insn:mulhu[] or insn:mulhsu[] can be used instead of insn:mulh[] if appropriate.
Note that the source register specifiers, `rs1` and `rs2`, must be in same order
and `rdh` cannot be the same as `rs1` or `rs2`.
Microarchitectures can then fuse these into a single multiply operation instead
of performing two separate multiplies.

[NOTE]
====
insn:mulhsu[] is used in multi-word signed multiplication to multiply the
most-significant word of the multiplicand (which contains the sign bit)
with the less-significant words of the multiplier (which are unsigned).
====

[#norm:mulw_op]#insn:mulw[] is an RV64 instruction that multiplies the lower 32 bits of the
source registers, placing the sign extension of the lower 32 bits of the
result into the destination register.#
```
