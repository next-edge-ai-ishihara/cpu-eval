# Implement `FetchBuffer`

Implement one complete `FetchBuffer` source-level hardware definition for the selected BOOM configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below. Keep `FetchBufferResp` and the other declarations shown below outside your definition; they already exist in the fixed source.

Return only the complete `class FetchBuffer` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### `src/main/scala/common/config-mixins.scala`

```scala
              fetchWidth = 8,
              decodeWidth = 3,
              // ...
              numFetchBufferEntries = 24,
              // ...
              ICacheParams(rowBits = site(SystemBusKey).beatBits, nSets=64, nWays=8, fetchBytes=4*4)
```

### `src/main/scala/common/parameters.scala`

```scala
case class BoomCoreParams(
  // ...
  enableSFBOpt: Boolean = false,
```

## Package and imports

### `src/main/scala/ifu/fetch-buffer.scala`

```scala
package boom.ifu

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.{Parameters}
// ...
import boom.common._
```

## Class declaration

### `src/main/scala/ifu/fetch-buffer.scala`

```scala
class FetchBuffer(implicit p: Parameters) extends BoomModule
  with HasBoomCoreParameters
  with HasBoomFrontendParameters
{
  val numEntries = numFetchBufferEntries
  val io = IO(new BoomBundle {
    val enq = Flipped(Decoupled(new FetchBundle()))
    val deq = new DecoupledIO(new FetchBufferResp())

    // Was the pipeline redirected? Clear/reset the fetchbuffer.
    val clear = Input(Bool())
  })
```

## Parent instantiation

### `src/main/scala/ifu/frontend.scala`

```scala
  val fb  = Module(new FetchBuffer)
  // ...
  f4_ready := f4.io.enq.ready
  f4.io.enq.valid := f3.io.deq.valid && !f3_clear
  f4.io.enq.bits  := f3_fetch_bundle
  f4.io.deq.ready := fb.io.enq.ready && ftq.io.enq.ready && !f4_delay

  fb.io.enq.valid := f4.io.deq.valid && ftq.io.enq.ready && !f4_delay
  fb.io.enq.bits  := f4.io.deq.bits
  fb.io.enq.bits.ftq_idx := ftq.io.enq_idx
  fb.io.enq.bits.sfbs    := Mux(f4_sfb_valid, UIntToOH(f4_sfb_idx), 0.U(fetchWidth.W)).asBools
  fb.io.enq.bits.shadowed_mask := (
    Mux(f4_sfb_valid, f4_sfb_mask(fetchWidth-1,0), 0.U(fetchWidth.W)) |
    f4.io.deq.bits.shadowed_mask.asUInt
  ).asBools
  // ...
  io.cpu.fetchpacket <> fb.io.deq
  // ...
  fb.io.clear := false.B

  when (io.cpu.sfence.valid) {
    fb.io.clear := true.B
  // ...
  }.elsewhen (io.cpu.redirect_flush) {
    fb.io.clear := true.B
```

```scala
  val f3_aligned_pc   = bankAlign(f3_imemresp.pc)
  // ...
  f3_fetch_bundle.pc := f3_imemresp.pc
  // ...
  for (b <- 0 until nBanks) {
    val bank_data  = f3_data((b+1)*bankWidth*16-1, b*bankWidth*16)
    val bank_mask  = Wire(Vec(bankWidth, Bool()))
    val bank_insts = Wire(Vec(bankWidth, UInt(32.W)))

    for (w <- 0 until bankWidth) {
      val i = (b * bankWidth) + w
      // ...
      if (w == 0) {
        val inst0 = Cat(bank_data(15,0), f3_prev_half)
        val inst1 = bank_data(31,0)
        val exp_inst0 = ExpandRVC(inst0)
        val exp_inst1 = ExpandRVC(inst1)
        val pc0 = (f3_aligned_pc + (i << log2Ceil(coreInstBytes)).U - 2.U)
        val pc1 = (f3_aligned_pc + (i << log2Ceil(coreInstBytes)).U)
        // ...
        when (bank_prev_is_half) {
          bank_insts(w)                := inst0
          f3_fetch_bundle.insts(i)     := inst0
          f3_fetch_bundle.exp_insts(i) := exp_inst0
          bpu.io.pc                    := pc0
          brsigs                       := bpd_decoder0.io.out
          f3_fetch_bundle.edge_inst(b) := true.B
        // ...
        } .otherwise {
          bank_insts(w)                := inst1
          f3_fetch_bundle.insts(i)     := inst1
          f3_fetch_bundle.exp_insts(i) := exp_inst1
          bpu.io.pc                    := pc1
          brsigs                       := bpd_decoder1.io.out
          f3_fetch_bundle.edge_inst(b) := false.B
      // ...
      } else {
        val inst = Wire(UInt(32.W))
        val exp_inst = ExpandRVC(inst)
        val pc = f3_aligned_pc + (i << log2Ceil(coreInstBytes)).U
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### `src/main/scala/ifu/fetch-buffer.scala`

```scala
class FetchBufferResp(implicit p: Parameters) extends BoomBundle
{
  val uops = Vec(coreWidth, Valid(new MicroOp()))
}
```

### `src/main/scala/ifu/frontend.scala`

```scala
class FetchBundle(implicit p: Parameters) extends BoomBundle
  with HasBoomFrontendParameters
{
  val pc            = UInt(vaddrBitsExtended.W)
  // ...
  val edge_inst     = Vec(nBanks, Bool()) // True if 1st instruction in this bundle is pc - 2
  val insts         = Vec(fetchWidth, Bits(32.W))
  val exp_insts     = Vec(fetchWidth, Bits(32.W))
  // ...
  // Information for sfb folding
  // NOTE: This IS NOT equivalent to uop.pc_lob, that gets calculated in the FB
  val sfbs                 = Vec(fetchWidth, Bool())
  // ...
  val shadowed_mask        = Vec(fetchWidth, Bool())

  val cfi_idx       = Valid(UInt(log2Ceil(fetchWidth).W))
  // ...
  val ftq_idx       = UInt(log2Ceil(ftqSz).W)
  val mask          = UInt(fetchWidth.W) // mark which words are valid instructions
  // ...
  val xcpt_pf_if    = Bool() // I-TLB miss (instruction fetch fault).
  val xcpt_ae_if    = Bool() // Access exception.

  val bp_debug_if_oh= Vec(fetchWidth, Bool())
  val bp_xcpt_if_oh = Vec(fetchWidth, Bool())
  // ...
  // Source of the prediction from this bundle
  val fsrc    = UInt(BSRC_SZ.W)
  // ...
}
```

### `src/main/scala/common/micro-op.scala`

```scala
class MicroOp(implicit p: Parameters) extends BoomBundle
  with freechips.rocketchip.rocket.constants.MemoryOpConstants
  with freechips.rocketchip.rocket.constants.ScalarOpConstants
{
  // ...
  val inst             = UInt(32.W)
  val debug_inst       = UInt(32.W)
  val is_rvc           = Bool()
  val debug_pc         = UInt(coreMaxAddrBits.W)
  // ...
  val is_sfb           = Bool()                      // is this a sfb or in the shadow of a sfb
  // ...

  // Index into FTQ to figure out our fetch PC.
  val ftq_idx          = UInt(log2Ceil(ftqSz).W)
  // This inst straddles two fetch packets
  val edge_inst        = Bool()
  // Low-order bits of our own PC. Combine with ftq[ftq_idx] to get PC.
  // Aligned to a cache-line size, as that is the greater fetch granularity.
  // TODO: Shouldn't this be aligned to fetch-width size?
  val pc_lob           = UInt(log2Ceil(icBlockBytes).W)

  // Was this a branch that was predicted taken?
  val taken            = Bool()
  // ...
  // frontend exception information
  val xcpt_pf_if       = Bool()             // I-TLB page fault.
  val xcpt_ae_if       = Bool()             // I$ access exception.
  // ...
  val bp_debug_if      = Bool()             // Breakpoint
  val bp_xcpt_if       = Bool()             // Breakpoint


  // What prediction structure provides the prediction FROM this op
  val debug_fsrc       = UInt(BSRC_SZ.W)
```

### `src/main/scala/ifu/frontend.scala`

```scala
trait HasBoomFrontendParameters extends HasL1ICacheParameters
{
  // How many banks does the ICache use?
  val nBanks = if (cacheParams.fetchBytes <= 8) 1 else 2
  // How many bytes wide is a bank?
  val bankBytes = fetchBytes/nBanks

  val bankWidth = fetchWidth/nBanks

  require(nBanks == 1 || nBanks == 2)
  // ...
  def blockAlign(addr: UInt) = ~(~addr | (cacheParams.blockBytes-1).U)
  def bankAlign(addr: UInt) = ~(~addr | (bankBytes-1).U)
```

### `src/main/scala/common/parameters.scala`

```scala
trait HasBoomCoreParameters extends freechips.rocketchip.tile.HasCoreParameters
{
  // ...
  // fetchWidth provided by CoreParams class.
  // decodeWidth provided by CoreParams class.

  // coreWidth is width of decode, width of integer rename, width of ROB, and commit width
  val coreWidth = decodeWidth

  require (isPow2(fetchWidth))
  require (coreWidth <= fetchWidth)
  // ...
  val ftqSz         = boomParams.ftq.nEntries        // number of FTQ entries
  val numFetchBufferEntries = boomParams.numFetchBufferEntries // number of instructions that stored between fetch&decode
  // ...
  val icacheParams: ICacheParams = tileParams.icache.get
  val icBlockBytes = icacheParams.blockBytes
```

### `src/main/scala/rocket/ICache.scala`

```scala
case class ICacheParams(
    // ...
    blockBytes: Int = 64,
```

## Related source code

### `src/main/scala/exu/core.scala`

```scala
  // track mask of finished instructions in the bundle
  // use this to mask out insts coming from FetchBuffer that have been finished
  // for example, back pressure may cause us to only issue some instructions from FetchBuffer
  // but on the next cycle, we only want to retry a subset
  val dec_finished_mask = RegInit(0.U(coreWidth.W))

  //-------------------------------------------------------------
  // Pull out instructions and send to the Decoders

  io.ifu.fetchpacket.ready := dec_ready
  val dec_fbundle = io.ifu.fetchpacket.bits

  //-------------------------------------------------------------
  // Decoders

  for (w <- 0 until coreWidth) {
    dec_valids(w)                      := io.ifu.fetchpacket.valid && dec_fbundle.uops(w).valid &&
                                          !dec_finished_mask(w)
    decode_units(w).io.enq.uop         := dec_fbundle.uops(w).bits
    decode_units(w).io.status          := csr.io.status
  // ...
  val dec_hazards = (0 until coreWidth).map(w =>
                      dec_valids(w) &&
                      (  !dis_ready
                      || rob.io.commit.rollback
                      || dec_xcpt_stall
                      || branch_mask_full(w)
                      || brupdate.b1.mispredict_mask =/= 0.U
                      || brupdate.b2.mispredict
                      || io.ifu.redirect_flush))

  val dec_stalls = dec_hazards.scanLeft(false.B) ((s,h) => s || h).takeRight(coreWidth)
  dec_fire := (0 until coreWidth).map(w => dec_valids(w) && !dec_stalls(w))

  // all decoders are empty and ready for new instructions
  dec_ready := dec_fire.last

  when (dec_ready || io.ifu.redirect_flush) {
    dec_finished_mask := 0.U
  } .otherwise {
    dec_finished_mask := dec_fire.asUInt | dec_finished_mask
  }
      // ...
      // To allow for diffs against spike :/
      def printf_inst(uop: MicroOp) = {
        when (uop.is_rvc) {
          printf("(0x%x)", uop.debug_inst(15,0))
        } .otherwise {
          printf("(0x%x)", uop.debug_inst)
        }
      }
```

### `src/main/scala/exu/decode.scala`

```scala
class DecodeUnit(implicit p: Parameters) extends BoomModule
  with freechips.rocketchip.rocket.constants.MemoryOpConstants
{
  val io = IO(new DecodeUnitIo)

  val uop = Wire(new MicroOp())
  uop := io.enq.uop

  var decode_table = XDecode.table
  if (usingFPU) decode_table ++= FDecode.table
  if (usingFPU && usingFDivSqrt) decode_table ++= FDivSqrtDecode.table
  if (usingRoCC) decode_table ++= RoCCDecode.table
  decode_table ++= (if (xLen == 64) X64Decode.table else X32Decode.table)

  val inst = uop.inst

  val cs = Wire(new CtrlSigs()).decode(inst, decode_table)
```

### `src/main/scala/exu/execution-units/functional-unit.scala`

```scala
    // Get the uop PC for jumps
    val block_pc = AlignPCToBoundary(io.get_ftq_pc.pc, icBlockBytes)
    val uop_pc = (block_pc | uop.pc_lob) - Mux(uop.edge_inst, 2.U, 0.U)
```

## Documentation

### `docs/sections/instruction-fetch-stage.rst`

```text
Since superscalar fetch is supported, the :term:`Front-end` retrieves a :term:`Fetch Packet`
of instructions from instruction memory and puts them into the
:term:`Fetch Buffer` to give to the rest of the pipeline. The :term:`Fetch Packet` also
contains other meta-data, such as a valid mask (which instructions in the
packet are valid?) and some branch prediction information that is used
later in the pipeline. Additionally, the PC and branch prediction information
is stored inside of the :term:`Fetch Target Queue` which holds this information
for the rest of the pipeline.
...
-  The :term:`Front-end` returns :term:`Fetch Packet` s of :term:`fetchWidth<Fetch Width>` \*16 bits wide. This
   was supported inherently in the BOOM :term:`Front-end` .

-  Maintain statefulness in **F3**, in the cycle where :term:`Fetch Packet` s
   are dequeued from the i-cache response queue and enqueued onto the
   :term:`Fetch Buffer` .

-  **F3** tracks the trailing 16b, PC, and instruction boundaries of the
   last :term:`Fetch Packet` . These bits are combined with the current
   :term:`Fetch Packet` and expanded to :term:`fetchWidth<Fetch Width>` \*32 bits for enqueuing onto the
   :term:`Fetch Buffer` . Predecode determines the start address of every
   instruction in this :term:`Fetch Packet` and masks the :term:`Fetch Packet` for the
   :term:`Fetch Buffer` .

-  The :term:`Fetch Buffer` now compacts away invalid, or misaligned instructions
   when storing to its memory.
...
-  A challenging problem is dealing with instructions that cross a
   :term:`Fetch Boundary`. We track these instructions as belonging to the
   :term:`Fetch Packet` that contains their higher-order 16 bits. We have to
   be careful when determining the PC of these instructions, by tracking
   all instructions which were initially misaligned across a :term:`Fetch Boundary` .

-  The pipeline must also track whether an instruction was originally
   16b or 32b, for calculating ``PC+4`` or ``PC+2``.
```

### `docs/sections/intro-overview/boom-pipeline.rst`

```text
.. [1] While the :term:`Fetch Buffer` is ``N``-entries deep, it can instantly read
    out the first instruction on the front of the FIFO. Put another way,
    instructions don’t need to spend ``N`` cycles moving their way through
    the :term:`Fetch Buffer` if there are no instructions in front of
    them.
```

### `src/intro.adoc`

```text
<<instlengthcode>> illustrates the standard
RISC-V instruction-length encoding convention. All the 32-bit
instructions in the base ISA have their lowest two bits set to `11`. The
optional compressed 16-bit instruction-set extensions have their lowest
two bits equal to `00`, `01`, or `10`.
```
