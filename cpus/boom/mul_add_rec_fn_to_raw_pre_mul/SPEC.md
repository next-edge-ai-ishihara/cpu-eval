# Implement `MulAddRecFNToRaw_preMul`

Implement the complete `MulAddRecFNToRaw_preMul` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Keep the declarations under Dependency declarations in the fixed source and do not resubmit them.

Return only the complete `class MulAddRecFNToRaw_preMul` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package hardfloat

import Chisel._
import consts._
```

## Class declaration

```scala
class MulAddRecFNToRaw_preMul(expWidth: Int, sigWidth: Int) extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val op = Bits(INPUT, 2)
        val a = Bits(INPUT, expWidth + sigWidth + 1)
        val b = Bits(INPUT, expWidth + sigWidth + 1)
        val c = Bits(INPUT, expWidth + sigWidth + 1)
        val mulAddA = UInt(OUTPUT, sigWidth)
        val mulAddB = UInt(OUTPUT, sigWidth)
        val mulAddC = UInt(OUTPUT, sigWidth * 2)
        val toPostMul = new MulAddRecFN_interIo(expWidth, sigWidth).asOutput
    })
```

## Parent instantiation

```scala
    val mulAddRecFNToRaw_preMul =
        Module(new MulAddRecFNToRaw_preMul(expWidth, sigWidth))
    val mulAddRecFNToRaw_postMul =
        Module(new MulAddRecFNToRaw_postMul(expWidth, sigWidth))

    mulAddRecFNToRaw_preMul.io.op := io.op
    mulAddRecFNToRaw_preMul.io.a  := io.a
    mulAddRecFNToRaw_preMul.io.b  := io.b
    mulAddRecFNToRaw_preMul.io.c  := io.c

    val mulAddResult =
        (mulAddRecFNToRaw_preMul.io.mulAddA *
             mulAddRecFNToRaw_preMul.io.mulAddB) +&
            mulAddRecFNToRaw_preMul.io.mulAddC

    mulAddRecFNToRaw_postMul.io.fromPreMul :=
        mulAddRecFNToRaw_preMul.io.toPostMul
    mulAddRecFNToRaw_postMul.io.mulAddResult := mulAddResult
    mulAddRecFNToRaw_postMul.io.roundingMode := io.roundingMode
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/MulAddRecFN.scala`

```scala
class MulAddRecFN_interIo(expWidth: Int, sigWidth: Int) extends Bundle
{
//*** ENCODE SOME OF THESE CASES IN FEWER BITS?:
    val isSigNaNAny     = Bool()
    val isNaNAOrB       = Bool()
    val isInfA          = Bool()
    val isZeroA         = Bool()
    val isInfB          = Bool()
    val isZeroB         = Bool()
    val signProd        = Bool()
    val isNaNC          = Bool()
    val isInfC          = Bool()
    val isZeroC         = Bool()
    val sExpSum         = SInt(width = expWidth + 2)
    val doSubMags       = Bool()
    val CIsDominant     = Bool()
    val CDom_CAlignDist = UInt(width = log2Up(sigWidth + 1))
    val highAlignedSigC = UInt(width = sigWidth + 2)
    val bit0AlignedSigC = UInt(width = 1)

}
```

### `src/main/scala/common.scala`

```scala
class RawFloat(val expWidth: Int, val sigWidth: Int) extends Bundle
{
    val isNaN  = Bool()              // overrides all other fields
    val isInf  = Bool()              // overrides 'isZero', 'sExp', and 'sig'
    val isZero = Bool()              // overrides 'sExp' and 'sig'
    val sign   = Bool()
    val sExp = SInt(width = expWidth + 2)
    val sig  = UInt(width = sigWidth + 1)   // 2 m.s. bits cannot both be 0

}

//*** CHANGE THIS INTO A '.isSigNaN' METHOD OF THE 'RawFloat' CLASS:
object isSigNaNRawFloat
{
    def apply(in: RawFloat): Bool = in.isNaN && !in.sig(in.sigWidth - 2)
}
```

### `src/main/scala/rawFloatFromRecFN.scala`

```scala
/*----------------------------------------------------------------------------
| In the result, no more than one of 'isNaN', 'isInf', and 'isZero' will be
| set.
*----------------------------------------------------------------------------*/
object rawFloatFromRecFN
{
    def apply(expWidth: Int, sigWidth: Int, in: Bits): RawFloat =
    {
        val exp = in(expWidth + sigWidth - 1, sigWidth - 1)
        val isZero    = (exp(expWidth, expWidth - 2) === UInt(0))
        val isSpecial = (exp(expWidth, expWidth - 1) === UInt(3))

        val out = Wire(new RawFloat(expWidth, sigWidth))
        out.isNaN  := isSpecial &&   exp(expWidth - 2)
        out.isInf  := isSpecial && ! exp(expWidth - 2)
        out.isZero := isZero
        out.sign   := in(expWidth + sigWidth)
        out.sExp   := exp.zext
        out.sig    := Cat(UInt(0, 1), ! isZero, in(sigWidth - 2, 0))
        out
    }
}
```

## Related source code

### `src/main/scala/MulAddRecFN.scala`

```scala
class MulAddRecFNToRaw_postMul(expWidth: Int, sigWidth: Int) extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val fromPreMul = new MulAddRecFN_interIo(expWidth, sigWidth).asInput
        val mulAddResult = UInt(INPUT, sigWidth * 2 + 1)
        val roundingMode = UInt(INPUT, 3)
        val invalidExc  = Bool(OUTPUT)
        val rawOut = new RawFloat(expWidth, sigWidth + 2).asOutput
    })

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val sigSumWidth = sigWidth * 3 + 3

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val roundingMode_min = (io.roundingMode === round_min)

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val opSignC = io.fromPreMul.signProd ^ io.fromPreMul.doSubMags
    val sigSum =
        Cat(Mux(io.mulAddResult(sigWidth * 2),
                io.fromPreMul.highAlignedSigC + UInt(1),
                io.fromPreMul.highAlignedSigC
               ),
            io.mulAddResult(sigWidth * 2 - 1, 0),
            io.fromPreMul.bit0AlignedSigC
        )

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val CDom_sign = opSignC
    val CDom_sExp = io.fromPreMul.sExpSum - io.fromPreMul.doSubMags.zext
    val CDom_absSigSum =
        Mux(io.fromPreMul.doSubMags,
            ~sigSum(sigSumWidth - 1, sigWidth + 1),
            Cat(UInt(0, 1),
//*** IF GAP IS REDUCED TO 1 BIT, MUST REDUCE THIS COMPONENT TO 1 BIT TOO:
                io.fromPreMul.highAlignedSigC(sigWidth + 1, sigWidth),
                sigSum(sigSumWidth - 3, sigWidth + 2)
            )
        )
    val CDom_absSigSumExtra =
        Mux(io.fromPreMul.doSubMags,
            (~sigSum(sigWidth, 1)).orR,
            sigSum(sigWidth + 1, 1).orR
        )
    val CDom_mainSig =
        (CDom_absSigSum<<io.fromPreMul.CDom_CAlignDist)(
            sigWidth * 2 + 1, sigWidth - 3)
    val CDom_reduced4SigExtra =
        (orReduceBy4(CDom_absSigSum(sigWidth - 1, 0)<<(~sigWidth & 3)) &
             lowMask(io.fromPreMul.CDom_CAlignDist>>2, 0, sigWidth>>2)).orR
    val CDom_sig =
        Cat(CDom_mainSig>>3,
            CDom_mainSig(2, 0).orR || CDom_reduced4SigExtra ||
                CDom_absSigSumExtra
        )

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val notCDom_signSigSum = sigSum(sigWidth * 2 + 3)
    val notCDom_absSigSum =
        Mux(notCDom_signSigSum,
            ~sigSum(sigWidth * 2 + 2, 0),
            sigSum(sigWidth * 2 + 2, 0) + io.fromPreMul.doSubMags
        )
    val notCDom_reduced2AbsSigSum = orReduceBy2(notCDom_absSigSum)
    val notCDom_normDistReduced2 = countLeadingZeros(notCDom_reduced2AbsSigSum)
    val notCDom_nearNormDist = notCDom_normDistReduced2<<1
    val notCDom_sExp = io.fromPreMul.sExpSum - notCDom_nearNormDist.zext
    val notCDom_mainSig =
        (notCDom_absSigSum<<notCDom_nearNormDist)(
            sigWidth * 2 + 3, sigWidth - 1)
    val notCDom_reduced4SigExtra =
        (orReduceBy2(
             notCDom_reduced2AbsSigSum(sigWidth>>1, 0)<<((sigWidth>>1) & 1)) &
             lowMask(notCDom_normDistReduced2>>1, 0, (sigWidth + 2)>>2)
        ).orR
    val notCDom_sig =
        Cat(notCDom_mainSig>>3,
            notCDom_mainSig(2, 0).orR || notCDom_reduced4SigExtra
        )
    val notCDom_completeCancellation =
        (notCDom_sig(sigWidth + 2, sigWidth + 1) === UInt(0))
    val notCDom_sign =
        Mux(notCDom_completeCancellation,
            roundingMode_min,
            io.fromPreMul.signProd ^ notCDom_signSigSum
        )

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val notNaN_isInfProd = io.fromPreMul.isInfA || io.fromPreMul.isInfB
    val notNaN_isInfOut = notNaN_isInfProd || io.fromPreMul.isInfC
    val notNaN_addZeros =
        (io.fromPreMul.isZeroA || io.fromPreMul.isZeroB) &&
            io.fromPreMul.isZeroC

    io.invalidExc :=
        io.fromPreMul.isSigNaNAny ||
        (io.fromPreMul.isInfA && io.fromPreMul.isZeroB) ||
        (io.fromPreMul.isZeroA && io.fromPreMul.isInfB) ||
        (! io.fromPreMul.isNaNAOrB &&
             (io.fromPreMul.isInfA || io.fromPreMul.isInfB) &&
             io.fromPreMul.isInfC &&
             io.fromPreMul.doSubMags)
    io.rawOut.isNaN := io.fromPreMul.isNaNAOrB || io.fromPreMul.isNaNC
    io.rawOut.isInf := notNaN_isInfOut
//*** IMPROVE?:
    io.rawOut.isZero :=
        notNaN_addZeros ||
            (! io.fromPreMul.CIsDominant && notCDom_completeCancellation)
    io.rawOut.sign :=
        (notNaN_isInfProd && io.fromPreMul.signProd) ||
        (io.fromPreMul.isInfC && opSignC) ||
        (notNaN_addZeros && ! roundingMode_min &&
            io.fromPreMul.signProd && opSignC) ||
        (notNaN_addZeros && roundingMode_min &&
            (io.fromPreMul.signProd || opSignC)) ||
        (! notNaN_isInfOut && ! notNaN_addZeros &&
             Mux(io.fromPreMul.CIsDominant, CDom_sign, notCDom_sign))
    io.rawOut.sExp := Mux(io.fromPreMul.CIsDominant, CDom_sExp, notCDom_sExp)
    io.rawOut.sig := Mux(io.fromPreMul.CIsDominant, CDom_sig, notCDom_sig)
```

### `src/main/scala/tile/FPU.scala`

```scala
  val S = new FType(8, 24)
  val D = new FType(11, 53)

// ...

  val valid = Reg(next=io.in.valid)
  val in = Reg(new FPInput)
  when (io.in.valid) {
    val one = UInt(1) << (t.sig + t.exp - 1)
    val zero = (io.in.bits.in1 ^ io.in.bits.in2) & (UInt(1) << (t.sig + t.exp))
    val cmd_fma = io.in.bits.ren3
    val cmd_addsub = io.in.bits.swap23
    in := io.in.bits
    when (cmd_addsub) { in.in2 := one }
    when (!(cmd_fma || cmd_addsub)) { in.in3 := zero }
  }

  val fma = Module(new MulAddRecFNPipe((latency-1) min 2, t.exp, t.sig))
  fma.io.validin := valid
  fma.io.op := in.fmaCmd
  fma.io.roundingMode := in.rm
  fma.io.detectTininess := hardfloat.consts.tininess_afterRounding
  fma.io.a := in.in1
  fma.io.b := in.in2
  fma.io.c := in.in3
```

### `src/main/scala/exu/execution-units/fpu.scala`

```scala
class FMADecoder extends Module
{
  val io = IO(new Bundle {
    val uopc = Input(UInt(UOPC_SZ.W))
    val cmd = Output(UInt(2.W))
  })

  val default: List[BitPat] = List(BitPat("b??"))
  val table: Array[(BitPat, List[BitPat])] =
    Array(
      BitPat(uopFADD_S)   -> List(BitPat("b00")),
      BitPat(uopFSUB_S)   -> List(BitPat("b01")),
      BitPat(uopFMUL_S)   -> List(BitPat("b00")),
      BitPat(uopFMADD_S)  -> List(BitPat("b00")),
      BitPat(uopFMSUB_S)  -> List(BitPat("b01")),
      BitPat(uopFNMADD_S) -> List(BitPat("b11")),
      BitPat(uopFNMSUB_S) -> List(BitPat("b10")),
      BitPat(uopFADD_D)   -> List(BitPat("b00")),
      BitPat(uopFSUB_D)   -> List(BitPat("b01")),
      BitPat(uopFMUL_D)   -> List(BitPat("b00")),
      BitPat(uopFMADD_D)  -> List(BitPat("b00")),
      BitPat(uopFMSUB_D)  -> List(BitPat("b01")),
      BitPat(uopFNMADD_D) -> List(BitPat("b11")),
      BitPat(uopFNMSUB_D) -> List(BitPat("b10"))
      )

  val decoder = rocket.DecodeLogic(io.uopc, default, table)

  val (cmd: UInt) :: Nil = decoder
  io.cmd := cmd

// ...

  val dfma = Module(new tile.FPUFMAPipe(latency = fpu_latency, t = tile.FType.D))
  dfma.io.in.valid := io.req.valid && fp_ctrl.fma && (fp_ctrl.typeTagOut === D)
  dfma.io.in.bits := fuInput(Some(dfma.t))

  val sfma = Module(new tile.FPUFMAPipe(latency = fpu_latency, t = tile.FType.S))
  sfma.io.in.valid := io.req.valid && fp_ctrl.fma && (fp_ctrl.typeTagOut === S)
  sfma.io.in.bits := fuInput(Some(sfma.t))
```

## Documentation

### `README.md`

```text
Recoded Format
--------------

The floating-point units in this repository work on an internal recoded format
(exponent has an additional bit) to handle subnormal numbers more efficiently
in a microprocessor.  A more detailed explanation will come soon, but in the
mean time here are some example mappings for single-precision numbers.

    IEEE format                           Recoded format
    ----------------------------------    -----------------------------------
    s 00000000 00000000000000000000000    s 000------ 00000000000000000000000
    s 00000000 00000000000000000000001    s 001101011 00000000000000000000000
    s 00000000 0000000000000000000001f    s 001101100 f0000000000000000000000
    s 00000000 000000000000000000001ff    s 001101101 ff000000000000000000000
        ...              ...                   ...              ... 
    s 00000000 001ffffffffffffffffffff    s 001111111 ffffffffffffffffffff000
    s 00000000 01fffffffffffffffffffff    s 010000000 fffffffffffffffffffff00
    s 00000000 1ffffffffffffffffffffff    s 010000001 ffffffffffffffffffffff0
    s 00000001 fffffffffffffffffffffff    s 010000010 fffffffffffffffffffffff
    s 00000010 fffffffffffffffffffffff    s 010000011 fffffffffffffffffffffff
        ...              ...                   ...              ... 
    s 11111101 fffffffffffffffffffffff    s 101111110 fffffffffffffffffffffff
    s 11111110 fffffffffffffffffffffff    s 101111111 fffffffffffffffffffffff
    s 11111111 00000000000000000000000    s 110------ -----------------------
    s 11111111 fffffffffffffffffffffff    s 111------ fffffffffffffffffffffff
```

### `src/f-st-ext.adoc`

```text
Floating-point arithmetic instructions with one or two source operands
use the R-type format with the OP-FP major opcode. FADD.S and FMUL.S
perform single-precision floating-point addition and multiplication
respectively, between _rs1_ and _rs2_. FSUB.S performs the
single-precision floating-point subtraction of _rs2_ from _rs1_. FDIV.S performs the single-precision floating-point division of _rs1_ by _rs2_. FSQRT.S computes the square root of _rs1_. In each case, the result is written to _rd_.

...

FMADD.S multiplies the values in _rs1_ and _rs2_, adds the value in
_rs3_, and writes the final result to _rd_. FMADD.S computes
_(rs1latexmath:[$\times$]rs2)latexmath:[$\+$]rs3_.

FMSUB.S multiplies the values in _rs1_ and _rs2_, subtracts the value in _rs3_, and writes the final result to _rd_. FMSUB.S computes
_(rs1latexmath:[$\times$]rs2)latexmath:[$\-$]rs3_.

FNMSUB.S multiplies the values in _rs1_ and _rs2_, negates the product, adds the value in _rs3_, and writes the final result to _rd_. FNMSUB.S computes _-(rs1latexmath:[$\times$]rs2)latexmath:[$\+$]rs3_.

FNMADD.S multiplies the values in _rs1_ and _rs2_, negates the product, subtracts the value in _rs3_, and writes the final result to _rd_. FNMADD.S computes _-(rs1latexmath:[$\times$]rs2)latexmath:[$\-$]rs3_.

...

The fused multiply-add instructions must set the invalid operation
exception flag when the multiplicands are latexmath:[$\infty$] and zero, even when the addend is a quiet NaN.
```
