# Implement `MulAddRecFNToRaw_postMul`

Implement the complete `MulAddRecFNToRaw_postMul` module. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Keep the declarations under Dependency declarations in the fixed source and do not resubmit them.

Return only the complete `class MulAddRecFNToRaw_postMul` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package hardfloat

import Chisel._
import consts._
```

## Class declaration

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

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val roundRawFNToRecFN =
        Module(new RoundRawFNToRecFN(expWidth, sigWidth, 0))
    roundRawFNToRecFN.io.invalidExc   := mulAddRecFNToRaw_postMul.io.invalidExc
    roundRawFNToRecFN.io.infiniteExc  := Bool(false)
    roundRawFNToRecFN.io.in           := mulAddRecFNToRaw_postMul.io.rawOut
    roundRawFNToRecFN.io.roundingMode := io.roundingMode
    roundRawFNToRecFN.io.detectTininess := io.detectTininess
    io.out            := roundRawFNToRecFN.io.out
    io.exceptionFlags := roundRawFNToRecFN.io.exceptionFlags
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
object consts {
    /*------------------------------------------------------------------------
    | For rounding to integer values, rounding mode 'odd' rounds to minimum
    | magnitude instead, same as 'minMag'.
    *------------------------------------------------------------------------*/
    def round_near_even   = UInt("b000", 3)
    def round_minMag      = UInt("b001", 3)
    def round_min         = UInt("b010", 3)
    def round_max         = UInt("b011", 3)
    def round_near_maxMag = UInt("b100", 3)
    def round_odd         = UInt("b110", 3)

// ...

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

## Related source code

### `src/main/scala/MulAddRecFN.scala`

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

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
//*** POSSIBLE TO REDUCE THIS BY 1 OR 2 BITS?  (CURRENTLY 2 BITS BETWEEN
//***  UNSHIFTED C AND PRODUCT):
    val sigSumWidth = sigWidth * 3 + 3

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val rawA = rawFloatFromRecFN(expWidth, sigWidth, io.a)
    val rawB = rawFloatFromRecFN(expWidth, sigWidth, io.b)
    val rawC = rawFloatFromRecFN(expWidth, sigWidth, io.c)

    val signProd = rawA.sign ^ rawB.sign ^ io.op(1)
//*** REVIEW THE BIAS FOR 'sExpAlignedProd':
    val sExpAlignedProd =
        rawA.sExp +& rawB.sExp + SInt(-(BigInt(1)<<expWidth) + sigWidth + 3)

    val doSubMags = signProd ^ rawC.sign ^ io.op(0)

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    val sNatCAlignDist = sExpAlignedProd - rawC.sExp
    val posNatCAlignDist = sNatCAlignDist(expWidth + 1, 0)
    val isMinCAlign = rawA.isZero || rawB.isZero || (sNatCAlignDist < SInt(0))
    val CIsDominant =
        ! rawC.isZero && (isMinCAlign || (posNatCAlignDist <= UInt(sigWidth)))
    val CAlignDist =
        Mux(isMinCAlign,
            UInt(0),
            Mux(posNatCAlignDist < UInt(sigSumWidth - 1),
                posNatCAlignDist(log2Up(sigSumWidth) - 1, 0),
                UInt(sigSumWidth - 1)
            )
        )
    val mainAlignedSigC =
        Cat(Mux(doSubMags, ~rawC.sig, rawC.sig),
            Fill(sigSumWidth - sigWidth + 2, doSubMags)
        ).asSInt>>CAlignDist
    val reduced4CExtra =
        (orReduceBy4(rawC.sig<<((sigSumWidth - sigWidth - 1) & 3)) &
             lowMask(
                 CAlignDist>>2,
//*** NOT NEEDED?:
//                 (sigSumWidth + 2)>>2,
                 (sigSumWidth - 1)>>2,
                 (sigSumWidth - sigWidth - 1)>>2
             )
        ).orR
    val alignedSigC =
        Cat(mainAlignedSigC>>3,
            Mux(doSubMags,
                mainAlignedSigC(2, 0).andR && ! reduced4CExtra,
                mainAlignedSigC(2, 0).orR  ||   reduced4CExtra
            )
        )

    //------------------------------------------------------------------------
    //------------------------------------------------------------------------
    io.mulAddA := rawA.sig
    io.mulAddB := rawB.sig
    io.mulAddC := alignedSigC(sigWidth * 2, 1)

    io.toPostMul.isSigNaNAny :=
        isSigNaNRawFloat(rawA) || isSigNaNRawFloat(rawB) ||
            isSigNaNRawFloat(rawC)
    io.toPostMul.isNaNAOrB := rawA.isNaN || rawB.isNaN
    io.toPostMul.isInfA    := rawA.isInf
    io.toPostMul.isZeroA   := rawA.isZero
    io.toPostMul.isInfB    := rawB.isInf
    io.toPostMul.isZeroB   := rawB.isZero
    io.toPostMul.signProd  := signProd
    io.toPostMul.isNaNC    := rawC.isNaN
    io.toPostMul.isInfC    := rawC.isInf
    io.toPostMul.isZeroC   := rawC.isZero
    io.toPostMul.sExpSum   :=
        Mux(CIsDominant, rawC.sExp, sExpAlignedProd - SInt(sigWidth))
    io.toPostMul.doSubMags := doSubMags
    io.toPostMul.CIsDominant := CIsDominant
    io.toPostMul.CDom_CAlignDist := CAlignDist(log2Up(sigWidth + 1) - 1, 0)
    io.toPostMul.highAlignedSigC :=
        alignedSigC(sigSumWidth - 1, sigWidth * 2 + 1)
    io.toPostMul.bit0AlignedSigC := alignedSigC(0)
```

### `src/main/scala/RoundAnyRawFNToRecFN.scala`

```scala
class
    RoundRawFNToRecFN(expWidth: Int, sigWidth: Int, options: Int)
    extends chisel3.RawModule
{
    val io = IO(new Bundle {
        val invalidExc  = Bool(INPUT)   // overrides 'infiniteExc' and 'in'
        val infiniteExc = Bool(INPUT)   // overrides 'in' except for 'in.sign'
        val in = new RawFloat(expWidth, sigWidth + 2).asInput
        val roundingMode   = UInt(INPUT, 3)
        val detectTininess = UInt(INPUT, 1)
        val out = Bits(OUTPUT, expWidth + sigWidth + 1)
        val exceptionFlags = Bits(OUTPUT, 5)
    })
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
[[rm]]
.Rounding mode encoding.
[%autowidth,float="center",align="center",cols="^,^,<",options="header"]
|===
|Rounding Mode |Mnemonic |Meaning
|000 |RNE |Round to Nearest, ties to Even
|001 |RTZ |Round towards Zero
|010 |RDN |Round Down (towards latexmath:[$-\infty$])
|011 |RUP |Round Up (towards latexmath:[$+\infty$])
|100 |RMM |Round to Nearest, ties to Max Magnitude
|101 | |_Reserved for future use._
|110 | |_Reserved for future use._
|111 |DYN |In instruction's _rm_ field, selects dynamic rounding mode; In Rounding Mode register, _reserved_.
|===

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
