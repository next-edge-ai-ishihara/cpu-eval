# Implement `PMPChecker`

Implement the complete `PMPChecker` module. Preserve its declaration and I/O. Return only the complete `class PMPChecker` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/parameters.scala`

```scala
case class BoomCoreParams(
// ...
  nPMPs: Int = 8,
// ...
  val pmpGranularity: Int = 4
// ...
```

## Package and imports

### `src/main/scala/rocket/PMP.scala`

```scala
package freechips.rocketchip.rocket

import chisel3._
import chisel3.util.{Cat, log2Ceil}
import Chisel.ImplicitConversions._
import freechips.rocketchip.config._
import freechips.rocketchip.tile._
import freechips.rocketchip.util._
```

## Class declaration

```scala
class PMPChecker(lgMaxSize: Int)(implicit val p: Parameters) extends Module
    with HasCoreParameters {
  val io = IO(new Bundle {
    val prv = Input(UInt(PRV.SZ.W))
    val pmp = Input(Vec(nPMPs, new PMP))
    val addr = Input(UInt(paddrBits.W))
    val size = Input(UInt(log2Ceil(lgMaxSize + 1).W))
    val r = Output(Bool())
    val w = Output(Bool())
    val x = Output(Bool())
  })
```

## Parent instantiation

### `src/main/scala/lsu/tlb.scala`

```scala
  val pmp = Seq.fill(memWidth) { Module(new PMPChecker(lgMaxSize)) }
  for (w <- 0 until memWidth) {
    pmp(w).io.addr := mpu_physaddr(w)
    pmp(w).io.size := io.req(w).bits.size
    pmp(w).io.pmp := (io.ptw.pmp: Seq[PMP])
    pmp(w).io.prv := Mux(usingVM.B && (do_refill || io.req(w).bits.passthrough /* PTW */), PRV.S.U, priv) // TODO should add separate bit to track PTW
  }
// ...
  val prot_r   = widthMap(w => fastCheck(_.supportsGet, w) && pmp(w).io.r)
  val prot_w   = widthMap(w => fastCheck(_.supportsPutFull, w) && pmp(w).io.w)
// ...
  val prot_x   = widthMap(w => fastCheck(_.executable, w) && pmp(w).io.x)
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/rocket/PMP.scala`

```scala
class PMPConfig extends Bundle {
  val l = Bool()
  val res = UInt(2.W)
  val a = UInt(2.W)
  val x = Bool()
  val w = Bool()
  val r = Bool()
}

object PMP {
  def lgAlign = 2

  def apply(reg: PMPReg): PMP = {
    val pmp = Wire(new PMP()(reg.p))
    pmp.cfg := reg.cfg
    pmp.addr := reg.addr
    pmp.mask := pmp.computeMask
    pmp
  }
}

class PMPReg(implicit p: Parameters) extends CoreBundle()(p) {
  val cfg = new PMPConfig
  val addr = UInt((paddrBits - PMP.lgAlign).W)
// ...
  def napot = cfg.a(1)
  def torNotNAPOT = cfg.a(0)
  def tor = !napot && torNotNAPOT
// ...
}

class PMP(implicit p: Parameters) extends PMPReg {
  val mask = UInt(paddrBits.W)

  import PMP._
  def computeMask = {
    val base = Cat(addr, cfg.a(0)) | ((pmpGranularity - 1) >> lgAlign)
    Cat(base & ~(base + 1), ((1 << lgAlign) - 1).U)
  }
  private def comparand = ~(~(addr << lgAlign) | (pmpGranularity - 1))

  private def pow2Match(x: UInt, lgSize: UInt, lgMaxSize: Int) = {
    def eval(a: UInt, b: UInt, m: UInt) = ((a ^ b) & ~m) === 0
    if (lgMaxSize <= pmpGranularity.log2) {
      eval(x, comparand, mask)
    } else {
      // break up the circuit; the MSB part will be CSE'd
      val lsbMask = mask | UIntToOH1(lgSize, lgMaxSize)
      val msbMatch = eval(x >> lgMaxSize, comparand >> lgMaxSize, mask >> lgMaxSize)
      val lsbMatch = eval(x(lgMaxSize-1, 0), comparand(lgMaxSize-1, 0), lsbMask(lgMaxSize-1, 0))
      msbMatch && lsbMatch
    }
  }

  private def boundMatch(x: UInt, lsbMask: UInt, lgMaxSize: Int) = {
    if (lgMaxSize <= pmpGranularity.log2) {
      x < comparand
    } else {
      // break up the circuit; the MSB part will be CSE'd
      val msbsLess = (x >> lgMaxSize) < (comparand >> lgMaxSize)
      val msbsEqual = ((x >> lgMaxSize) ^ (comparand >> lgMaxSize)) === 0
      val lsbsLess =  (x(lgMaxSize-1, 0) | lsbMask) < comparand(lgMaxSize-1, 0)
      msbsLess || (msbsEqual && lsbsLess)
    }
  }

  private def lowerBoundMatch(x: UInt, lgSize: UInt, lgMaxSize: Int) =
    !boundMatch(x, UIntToOH1(lgSize, lgMaxSize), lgMaxSize)

  private def upperBoundMatch(x: UInt, lgMaxSize: Int) =
    boundMatch(x, 0.U, lgMaxSize)

  private def rangeMatch(x: UInt, lgSize: UInt, lgMaxSize: Int, prev: PMP) =
    prev.lowerBoundMatch(x, lgSize, lgMaxSize) && upperBoundMatch(x, lgMaxSize)
// ...
  // returns whether this matching PMP fully contains the access
  def aligned(x: UInt, lgSize: UInt, lgMaxSize: Int, prev: PMP): Bool = if (lgMaxSize <= pmpGranularity.log2) true.B else {
    val lsbMask = UIntToOH1(lgSize, lgMaxSize)
    val straddlesLowerBound = ((x >> lgMaxSize) ^ (prev.comparand >> lgMaxSize)) === 0 && (prev.comparand(lgMaxSize-1, 0) & ~x(lgMaxSize-1, 0)) =/= 0
    val straddlesUpperBound = ((x >> lgMaxSize) ^ (comparand >> lgMaxSize)) === 0 && (comparand(lgMaxSize-1, 0) & (x(lgMaxSize-1, 0) | lsbMask)) =/= 0
    val rangeAligned = !(straddlesLowerBound || straddlesUpperBound)
    val pow2Aligned = (lsbMask & ~mask(lgMaxSize-1, 0)) === 0
    Mux(napot, pow2Aligned, rangeAligned)
  }

  // returns whether this PMP matches at least one byte of the access
  def hit(x: UInt, lgSize: UInt, lgMaxSize: Int, prev: PMP): Bool =
    Mux(napot, pow2Match(x, lgSize, lgMaxSize), torNotNAPOT && rangeMatch(x, lgSize, lgMaxSize, prev))
}
```

### `src/main/scala/rocket/CSR.scala`

```scala
object PRV
{
  val SZ = 2
  val U = 0
  val S = 1
  val H = 2
  val M = 3
}
```

## Documentation

### `src/machine.adoc`

```text
<<pmpcfg>> shows the layout of a PMP configuration
register. The R, W, and X bits, when set, indicate that the PMP entry
permits read, write, and instruction execution, respectively. When one
of these bits is clear, the corresponding access type is denied. The R,
W, and X fields form a collective *WARL* field for which the combinations with R=0 and W=1 are reserved. The remaining two fields, A and L, are described in the following sections.
...
===== Address Matching

The A field in a PMP entry's configuration register encodes the
address-matching mode of the associated PMP address register. The
encoding of this field is shown in <<pmpcfg-a>>.
When A=0, this PMP entry is disabled and matches no addresses. Two other
address-matching modes are supported: naturally aligned power-of-2
regions (NAPOT), including the special case of naturally aligned
four-byte regions (NA4); and the top boundary of an arbitrary range
(TOR). These modes support four-byte granularity.
...
If TOR is selected, the associated address register forms the top of the
address range, and the preceding PMP address register forms the bottom
of the address range. If PMP entry __i__'s A field is set to
TOR, the entry matches any address _y_ such that `pmpaddr~i-1~`&#8804;__y__<``pmpaddr~i~`` (irrespective of the value of `pmpcfg~i-1~`). If PMP entry 0's A field is set to TOR, zero is used for the lower bound, and so it matches
any address `y<pmpaddr~0~`.

[NOTE]
====
If  `pmpaddr~i-1~&#8805;``pmpaddr~i~``` and `pmpcfg~i~.A`=TOR, then PMP entry _i_ matches no addresses.
====
...
In addition to locking the PMP entry, the L bit indicates whether the
R/W/X permissions are enforced on M-mode accesses. When the L bit is
set, these permissions are enforced for all privilege modes. When the L
bit is clear, any M-mode access matching the PMP entry will succeed; the
R/W/X permissions apply only to S and U modes.

===== Priority and Matching Logic

PMP entries are statically prioritized. The lowest-numbered PMP entry
that matches any byte of an access determines whether that access
succeeds or fails. The matching PMP entry must match all bytes of an
access, or the access fails, irrespective of the L, R, W, and X bits.
For example, if a PMP entry is configured to match the four-byte range
`0xC`–`0xF`, then an 8-byte access to the range `0x8`–`0xF` will fail,
assuming that PMP entry is the highest-priority entry that matches those
addresses.

If a PMP entry matches all bytes of an access, then the L, R, W, and X
bits determine whether the access succeeds or fails. If the L bit is
clear and the privilege mode of the access is M, the access succeeds.
Otherwise, if the L bit is set or the privilege mode of the access is S
or U, then the access succeeds only if the R, W, or X bit corresponding
to the access type is set.

If no PMP entry matches an M-mode access, the access succeeds. If no PMP
entry matches an S-mode or U-mode access, but at least one PMP entry is
implemented, the access fails.
```
