# Implement `AMOALU`

Implement one complete `AMOALU` source-level hardware definition for BOOM. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class AMOALU` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
// See LICENSE.SiFive for license details.
// See LICENSE.Berkeley for license details.

package freechips.rocketchip.rocket

import Chisel._
import freechips.rocketchip.config.Parameters
```

## Class declaration

```scala
class AMOALU(operandBits: Int)(implicit p: Parameters) extends Module {
  val minXLen = 32
  val widths = (0 to log2Ceil(operandBits / minXLen)).map(minXLen << _)

  val io = new Bundle {
    val mask = UInt(INPUT, operandBits/8)
    val cmd = Bits(INPUT, M_SZ)
    val lhs = Bits(INPUT, operandBits)
    val rhs = Bits(INPUT, operandBits)
    val out = Bits(OUTPUT, operandBits)
    val out_unmasked = Bits(OUTPUT, operandBits)
  }
```

## Parent instantiation

### src/main/scala/lsu/dcache.scala

```scala
  // Store/amo hits
  val s3_req   = RegNext(s2_req(0))
  val s3_valid = RegNext(s2_valid(0) && s2_hit(0) && isWrite(s2_req(0).uop.mem_cmd) &&
                         !s2_sc_fail && !(s2_send_nack(0) && s2_nack(0)))
  // ...
  val amoalu   = Module(new AMOALU(xLen))
  amoalu.io.mask := new StoreGen(s2_req(0).uop.mem_size, s2_req(0).addr, 0.U, xLen/8).mask
  amoalu.io.cmd  := s2_req(0).uop.mem_cmd
  amoalu.io.lhs  := s2_data_word(0)
  amoalu.io.rhs  := s2_req(0).data


  s3_req.data := amoalu.io.out
  val s3_way   = RegNext(s2_tag_match_way(0))

  dataWriteArb.io.in(0).valid       := s3_valid
  dataWriteArb.io.in(0).bits.addr   := s3_req.addr
  dataWriteArb.io.in(0).bits.wmask  := UIntToOH(s3_req.addr.extract(rowOffBits-1,offsetlsb))
  dataWriteArb.io.in(0).bits.data   := Fill(rowWords, s3_req.data)
  dataWriteArb.io.in(0).bits.way_en := s3_way
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/rocket/package.scala

```scala
package freechips.rocketchip

package object rocket extends rocket.constants.ScalarOpConstants with rocket.constants.MemoryOpConstants
```

### src/main/scala/rocket/Consts.scala

```scala
trait MemoryOpConstants {
  val NUM_XA_OPS = 9
  val M_SZ      = 5
  def M_X       = BitPat("b?????");
  def M_XRD     = UInt("b00000"); // int load
  def M_XWR     = UInt("b00001"); // int store
  def M_PFR     = UInt("b00010"); // prefetch with intent to read
  def M_PFW     = UInt("b00011"); // prefetch with intent to write
  def M_XA_SWAP = UInt("b00100");
  def M_FLUSH_ALL = UInt("b00101")  // flush all lines
  def M_XLR     = UInt("b00110");
  def M_XSC     = UInt("b00111");
  def M_XA_ADD  = UInt("b01000");
  def M_XA_XOR  = UInt("b01001");
  def M_XA_OR   = UInt("b01010");
  def M_XA_AND  = UInt("b01011");
  def M_XA_MIN  = UInt("b01100");
  def M_XA_MAX  = UInt("b01101");
  def M_XA_MINU = UInt("b01110");
  def M_XA_MAXU = UInt("b01111");
  def M_FLUSH   = UInt("b10000") // write back dirty data and cede R/W permissions
  def M_PWR     = UInt("b10001") // partial (masked) store
  def M_PRODUCE = UInt("b10010") // write back dirty data and cede W permissions
  def M_CLEAN   = UInt("b10011") // write back dirty data and retain R/W permissions
  def M_SFENCE  = UInt("b10100") // SFENCE.VMA
  def M_HFENCEV = UInt("b10101") // HFENCE.VVMA
  def M_HFENCEG = UInt("b10110") // HFENCE.GVMA
  def M_WOK     = UInt("b10111") // check write permissions but don't perform a write
  def M_HLVX    = UInt("b10000") // HLVX instruction

  def isAMOLogical(cmd: UInt) = cmd.isOneOf(M_XA_SWAP, M_XA_XOR, M_XA_OR, M_XA_AND)
  def isAMOArithmetic(cmd: UInt) = cmd.isOneOf(M_XA_ADD, M_XA_MIN, M_XA_MAX, M_XA_MINU, M_XA_MAXU)
  def isAMO(cmd: UInt) = isAMOLogical(cmd) || isAMOArithmetic(cmd)
  def isPrefetch(cmd: UInt) = cmd === M_PFR || cmd === M_PFW
  def isRead(cmd: UInt) = cmd.isOneOf(M_XRD, M_HLVX, M_XLR, M_XSC) || isAMO(cmd)
  def isWrite(cmd: UInt) = cmd === M_XWR || cmd === M_PWR || cmd === M_XSC || isAMO(cmd)
  def isWriteIntent(cmd: UInt) = isWrite(cmd) || cmd === M_PFW || cmd === M_XLR
}
```

## Related source code

### src/main/scala/rocket/DCache.scala

```scala
  // AMOs
  if (usingRMW) {
    val amoalus = (0 until coreDataBits / xLen).map { i =>
      val amoalu = Module(new AMOALU(xLen))
      amoalu.io.mask := pstore1_mask >> (i * xBytes)
      amoalu.io.cmd := (if (usingAtomicsInCache) pstore1_cmd else M_XWR)
      amoalu.io.lhs := s2_data_word >> (i * xLen)
      amoalu.io.rhs := pstore1_data >> (i * xLen)
      amoalu
    }
    pstore1_storegen_data := (if (!usingDataScratchpad) amoalus.map(_.io.out).asUInt else {
      val mask = FillInterleaved(8, Mux(s2_correct, 0.U, pstore1_mask))
      amoalus.map(_.io.out_unmasked).asUInt & mask | s2_data_word_corrected & ~mask
    })
```

## Documentation

### src/a-st-ext.adoc

```text
[[sec:amo]]
=== "Zaamo" Extension for Atomic Memory Operations

include::images/wavedrom/atomic-mem.edn[]

The atomic memory operation (AMO) instructions perform read-modify-write
operations for multiprocessor synchronization and are encoded with an
R-type instruction format. These AMO instructions atomically load a data
value from the address in _rs1_, place the value into register _rd_,
apply a binary operator to the loaded value and the original value in
_rs2_, then store the result back to the original address in _rs1_. AMOs
can either operate on _doublewords_ (RV64 only) or _words_ in memory. For
RV64, 32-bit AMOs always sign-extend the value placed in _rd_, and
ignore the upper 32 bits of the original value of _rs2_.

For AMOs, the Zaamo extension requires that the address held in _rs1_ be
naturally aligned to the size of the operand (i.e., eight-byte aligned
for _doublewords_ and four-byte aligned for _words_). If the address
is not naturally aligned, an address-misaligned exception or an
access-fault exception will be generated. The access-fault exception can
be generated for a memory access that would otherwise be able to
complete except for the misalignment, if the misaligned access should
not be emulated.

The misaligned atomicity granule PMA, defined in Volume II of this manual,
optionally relaxes this alignment requirement.
If present, the misaligned atomicity granule PMA specifies the size
of a misaligned atomicity granule, a power-of-two number of bytes.
The misaligned atomicity granule PMA applies only to AMOs, loads and stores
defined in the base ISAs, and loads and stores of no more than XLEN bits
defined in the F, D, and Q extensions.
For an instruction in that set, if all accessed bytes lie within the same
misaligned atomicity granule, the instruction will not raise an exception for
reasons of address alignment, and the instruction will give rise to only one
memory operation for the purposes of RVWMO--i.e., it will execute atomically.

The operations supported are swap, integer add, bitwise AND, bitwise OR,
bitwise XOR, and signed and unsigned integer maximum and minimum.
Without ordering constraints, these AMOs can be used to implement
parallel reduction operations, where typically the return value would be
discarded by writing to `x0`.
```
