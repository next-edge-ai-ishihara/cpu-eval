# Implement `TageTable`

Implement the complete `TageTable` module. Preserve the definition name, constructor parameters, inheritance, and public interface. Keep `TageResp` unchanged in the fixed source and do not redefine it. Return only the complete `class TageTable` definition in a single Scala code block, with no text outside the block.

## Package and imports

```scala
package boom.ifu

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.{Field, Parameters}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tilelink._

import boom.common._
import boom.util.{BoomCoreStringPrefix, MaskLower, WrapInc}

import scala.math.min
```

## Class declaration

```scala
class TageTable(val nRows: Int, val tagSz: Int, val histLength: Int, val uBitPeriod: Int)
  (implicit p: Parameters) extends BoomModule()(p)
  with HasBoomFrontendParameters
{
  require(histLength <= globalHistoryLength)
  // ...
  val io = IO( new Bundle {
    val f1_req_valid = Input(Bool())
    val f1_req_pc    = Input(UInt(vaddrBitsExtended.W))
    val f1_req_ghist = Input(UInt(globalHistoryLength.W))

    val f3_resp = Output(Vec(bankWidth, Valid(new TageResp)))

    val update_mask    = Input(Vec(bankWidth, Bool()))
    val update_taken   = Input(Vec(bankWidth, Bool()))
    val update_alloc   = Input(Vec(bankWidth, Bool()))
    val update_old_ctr = Input(Vec(bankWidth, UInt(3.W)))

    val update_pc    = Input(UInt())
    val update_hist  = Input(UInt())

    val update_u_mask = Input(Vec(bankWidth, Bool()))
    val update_u = Input(Vec(bankWidth, UInt(2.W)))
  })
```

## Parent instantiation

### src/main/scala/ifu/bpd/tage.scala

```scala
case class BoomTageParams(
  //                                           nSets, histLen, tagSz
  tableInfo: Seq[Tuple3[Int, Int, Int]] = Seq((  128,       2,     7),
                                              (  128,       4,     7),
                                              (  256,       8,     8),
                                              (  256,      16,     8),
                                              (  128,      32,     9),
                                              (  128,      64,     9)),
  uBitPeriod: Int = 2048
)


class TageBranchPredictorBank(params: BoomTageParams = BoomTageParams())(implicit p: Parameters) extends BranchPredictorBank()(p)
{
  val tageUBitPeriod = params.uBitPeriod
  val tageNTables    = params.tableInfo.size

  class TageMeta extends Bundle
  {
    val provider      = Vec(bankWidth, Valid(UInt(log2Ceil(tageNTables).W)))
    val alt_differs   = Vec(bankWidth, Output(Bool()))
    val provider_u    = Vec(bankWidth, Output(UInt(2.W)))
    val provider_ctr  = Vec(bankWidth, Output(UInt(3.W)))
    val allocate      = Vec(bankWidth, Valid(UInt(log2Ceil(tageNTables).W)))
  }

  val f3_meta = Wire(new TageMeta)
  override val metaSz = f3_meta.asUInt.getWidth
  require(metaSz <= bpdMaxMetaLength)

  def inc_u(u: UInt, alt_differs: Bool, mispredict: Bool): UInt = {
    Mux(!alt_differs, u,
    Mux(mispredict, Mux(u === 0.U, 0.U, u - 1.U),
                    Mux(u === 3.U, 3.U, u + 1.U)))
  }

  val tt = params.tableInfo map {
    case (n, l, s) => {
      val t = Module(new TageTable(n, s, l, params.uBitPeriod))
      t.io.f1_req_valid := RegNext(io.f0_valid)
      t.io.f1_req_pc    := RegNext(io.f0_pc)
      t.io.f1_req_ghist := io.f1_ghist
      (t, t.mems)
    }
  }
  val tables = tt.map(_._1)
  val mems = tt.map(_._2).flatten

  val f3_resps = VecInit(tables.map(_.io.f3_resp))

  val s1_update_meta = s1_update.bits.meta.asTypeOf(new TageMeta)
  val s1_update_mispredict_mask = UIntToOH(s1_update.bits.cfi_idx.bits) &
    Fill(bankWidth, s1_update.bits.cfi_mispredicted)

  val s1_update_mask  = WireInit((0.U).asTypeOf(Vec(tageNTables, Vec(bankWidth, Bool()))))
  val s1_update_u_mask  = WireInit((0.U).asTypeOf(Vec(tageNTables, Vec(bankWidth, UInt(1.W)))))

  val s1_update_taken   = Wire(Vec(tageNTables, Vec(bankWidth, Bool())))
  val s1_update_old_ctr = Wire(Vec(tageNTables, Vec(bankWidth, UInt(3.W))))
  val s1_update_alloc   = Wire(Vec(tageNTables, Vec(bankWidth, Bool())))
  val s1_update_u       = Wire(Vec(tageNTables, Vec(bankWidth, UInt(2.W))))

  s1_update_taken   := DontCare
  s1_update_old_ctr := DontCare
  s1_update_alloc   := DontCare
  s1_update_u       := DontCare


  for (w <- 0 until bankWidth) {
    var altpred = io.resp_in(0).f3(w).taken
    val final_altpred = WireInit(io.resp_in(0).f3(w).taken)
    var provided = false.B
    var provider = 0.U
    io.resp.f3(w).taken := io.resp_in(0).f3(w).taken

    for (i <- 0 until tageNTables) {
      val hit = f3_resps(i)(w).valid
      val ctr = f3_resps(i)(w).bits.ctr
      when (hit) {
        io.resp.f3(w).taken := Mux(ctr === 3.U || ctr === 4.U, altpred, ctr(2))
        final_altpred       := altpred
      }

      provided = provided || hit
      provider = Mux(hit, i.U, provider)
      altpred  = Mux(hit, f3_resps(i)(w).bits.ctr(2), altpred)
    }
    f3_meta.provider(w).valid := provided
    f3_meta.provider(w).bits  := provider
    f3_meta.alt_differs(w)    := final_altpred =/= io.resp.f3(w).taken
    f3_meta.provider_u(w)     := f3_resps(provider)(w).bits.u
    f3_meta.provider_ctr(w)   := f3_resps(provider)(w).bits.ctr

    // Create a mask of tables which did not hit our query, and also contain useless entries
    // and also uses a longer history than the provider
    val allocatable_slots = (
      VecInit(f3_resps.map(r => !r(w).valid && r(w).bits.u === 0.U)).asUInt &
      ~(MaskLower(UIntToOH(provider)) & Fill(tageNTables, provided))
    )
    val alloc_lfsr = random.LFSR(tageNTables max 2)

    val first_entry = PriorityEncoder(allocatable_slots)
    val masked_entry = PriorityEncoder(allocatable_slots & alloc_lfsr)
    val alloc_entry = Mux(allocatable_slots(masked_entry),
      masked_entry,
      first_entry)

    f3_meta.allocate(w).valid := allocatable_slots =/= 0.U
    f3_meta.allocate(w).bits  := alloc_entry

    val update_was_taken = (s1_update.bits.cfi_idx.valid &&
                            (s1_update.bits.cfi_idx.bits === w.U) &&
                            s1_update.bits.cfi_taken)
    when (s1_update.bits.br_mask(w) && s1_update.valid && s1_update.bits.is_commit_update) {
      when (s1_update_meta.provider(w).valid) {
        val provider = s1_update_meta.provider(w).bits

        s1_update_mask(provider)(w) := true.B
        s1_update_u_mask(provider)(w) := true.B

        val new_u = inc_u(s1_update_meta.provider_u(w),
                          s1_update_meta.alt_differs(w),
                          s1_update_mispredict_mask(w))
        s1_update_u      (provider)(w) := new_u
        s1_update_taken  (provider)(w) := update_was_taken
        s1_update_old_ctr(provider)(w) := s1_update_meta.provider_ctr(w)
        s1_update_alloc  (provider)(w) := false.B

      }
    }
  }
  when (s1_update.valid && s1_update.bits.is_commit_update && s1_update.bits.cfi_mispredicted && s1_update.bits.cfi_idx.valid) {
    val idx = s1_update.bits.cfi_idx.bits
    val allocate = s1_update_meta.allocate(idx)
    when (allocate.valid) {
      s1_update_mask (allocate.bits)(idx) := true.B
      s1_update_taken(allocate.bits)(idx) := s1_update.bits.cfi_taken
      s1_update_alloc(allocate.bits)(idx) := true.B

      s1_update_u_mask(allocate.bits)(idx) := true.B
      s1_update_u     (allocate.bits)(idx) := 0.U

    } .otherwise {
      val provider = s1_update_meta.provider(idx)
      val decr_mask = Mux(provider.valid, ~MaskLower(UIntToOH(provider.bits)), 0.U)

      for (i <- 0 until tageNTables) {
        when (decr_mask(i)) {
          s1_update_u_mask(i)(idx) := true.B
          s1_update_u     (i)(idx) := 0.U
        }
      }
    }

  }


  for (i <- 0 until tageNTables) {
    for (w <- 0 until bankWidth) {
      tables(i).io.update_mask(w)    := RegNext(s1_update_mask(i)(w))
      tables(i).io.update_taken(w)   := RegNext(s1_update_taken(i)(w))
      tables(i).io.update_alloc(w)   := RegNext(s1_update_alloc(i)(w))
      tables(i).io.update_old_ctr(w) := RegNext(s1_update_old_ctr(i)(w))

      tables(i).io.update_u_mask(w) := RegNext(s1_update_u_mask(i)(w))
      tables(i).io.update_u(w)      := RegNext(s1_update_u(i)(w))
    }
    tables(i).io.update_pc    := RegNext(s1_update.bits.pc)
    tables(i).io.update_hist  := RegNext(s1_update.bits.ghist)
  }


  //io.f3_meta := Cat(f3_meta.asUInt, micro.io.f3_meta(micro.metaSz-1,0), base.io.f3_meta(base.metaSz-1, 0))
  io.f3_meta := f3_meta.asUInt
}
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/ifu/bpd/tage.scala

```scala
class TageResp extends Bundle {
  val ctr = UInt(3.W)
  val u   = UInt(2.W)
}
```

### src/main/scala/ifu/bpd/predictor.scala

```scala
// A branch update to a single bank
class BranchPredictionBankUpdate(implicit p: Parameters) extends BoomBundle()(p)
  with HasBoomFrontendParameters
{
  val is_mispredict_update     = Bool()
  val is_repair_update         = Bool()

  val btb_mispredicts  = UInt(bankWidth.W)
  def is_btb_mispredict_update = btb_mispredicts =/= 0.U

  def is_commit_update = !(is_mispredict_update || is_repair_update || is_btb_mispredict_update)

  val pc               = UInt(vaddrBitsExtended.W)

  val br_mask          = UInt(bankWidth.W)
  val cfi_idx          = Valid(UInt(log2Ceil(bankWidth).W))
  val cfi_taken        = Bool()
  val cfi_mispredicted = Bool()

  val cfi_is_br        = Bool()
  val cfi_is_jal       = Bool()
  val cfi_is_jalr      = Bool()

  val ghist            = UInt(globalHistoryLength.W)
  val lhist            = UInt(localHistoryLength.W)

  val target           = UInt(vaddrBitsExtended.W)

  val meta             = UInt(bpdMaxMetaLength.W)
}

// ...

abstract class BranchPredictorBank(implicit p: Parameters) extends BoomModule()(p)
  with HasBoomFrontendParameters
{
  val metaSz = 0
  def nInputs = 1

  val mems: Seq[Tuple3[String, Int, Int]]

  val io = IO(new Bundle {
    val f0_valid = Input(Bool())
    val f0_pc    = Input(UInt(vaddrBitsExtended.W))
    val f0_mask  = Input(UInt(bankWidth.W))
    // Local history not available until end of f1
    val f1_ghist = Input(UInt(globalHistoryLength.W))
    val f1_lhist = Input(UInt(localHistoryLength.W))

    val resp_in = Input(Vec(nInputs, new BranchPredictionBankResponse))
    val resp = Output(new BranchPredictionBankResponse)

    // Store the meta as a UInt, use width inference to figure out the shape
    val f3_meta = Output(UInt(bpdMaxMetaLength.W))

    val f3_fire = Input(Bool())

    val update = Input(Valid(new BranchPredictionBankUpdate))
  })
  io.resp := io.resp_in(0)

  io.f3_meta := 0.U

  val s0_idx       = fetchIdx(io.f0_pc)
  val s1_idx       = RegNext(s0_idx)
  val s2_idx       = RegNext(s1_idx)
  val s3_idx       = RegNext(s2_idx)

  val s0_valid = io.f0_valid
  val s1_valid = RegNext(s0_valid)
  val s2_valid = RegNext(s1_valid)
  val s3_valid = RegNext(s2_valid)

  val s0_mask = io.f0_mask
  val s1_mask = RegNext(s0_mask)
  val s2_mask = RegNext(s1_mask)
  val s3_mask = RegNext(s2_mask)

  val s0_pc = io.f0_pc
  val s1_pc = RegNext(s0_pc)

  val s0_update     = io.update
  val s0_update_idx = fetchIdx(io.update.bits.pc)
  val s0_update_valid = io.update.valid

  val s1_update     = RegNext(s0_update)
  val s1_update_idx = RegNext(s0_update_idx)
  val s1_update_valid = RegNext(s0_update_valid)



}
```

### src/main/scala/ifu/frontend.scala

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

  def fetchIdx(addr: UInt) = addr >> log2Ceil(fetchBytes)
```

### src/main/scala/rocket/ICache.scala

```scala
trait HasL1ICacheParameters extends HasL1CacheParameters with HasCoreParameters {
  val cacheParams = tileParams.icache.get
}
```

### src/main/scala/tile/L1Cache.scala

```scala
trait HasL1CacheParameters extends HasTileParameters {
  val cacheParams: L1CacheParams

  def nSets = cacheParams.nSets
  def blockOffBits = lgCacheBlockBytes
  def idxBits = log2Up(cacheParams.nSets)
  def untagBits = blockOffBits + idxBits
  def pgUntagBits = if (usingVM) untagBits min pgIdxBits else untagBits
  def tagBits = tlBundleParams.addressBits - pgUntagBits
  def nWays = cacheParams.nWays
  def wayBits = log2Up(nWays)
  def isDM = nWays == 1
  def rowBits = cacheParams.rowBits
  def rowBytes = rowBits/8
  def rowOffBits = log2Up(rowBytes)
  def nTLBSets = cacheParams.nTLBSets
  def nTLBWays = cacheParams.nTLBWays

  def cacheDataBits = tlBundleParams.dataBits
  def cacheDataBytes = cacheDataBits / 8
  def cacheDataBeats = (cacheBlockBytes * 8) / cacheDataBits
  def refillCycles = cacheDataBeats
}
```

## Documentation

### docs/sections/branch-prediction/backing-predictor.rst

```text
The :term:`BPD<Backing Predictor (BPD)>` is accessed throughout the **Fetch** stages and in parallel with the instruction cache access and BTB (see
:numref:`front-end-bpu-bpd`). This allows the :term:`BPD<Backing Predictor (BPD)>` to be stored in sequential
memory (i.e., SRAM instead of flip-flops). With some clever
architecting, the :term:`BPD<Backing Predictor (BPD)>` can be stored in single-ported SRAM to achieve the
density desired.

...

**TAGE (TAgged GEometric)** is implemented as a collection of predictor
tables. Each table entry contains a *prediction counter*, a
*usefulness counter*, and a *tag*. The *prediction counter*
provides the prediction (and maintains some hysteresis as to how
strongly biased the prediction is towards taken or not-taken). The
*usefulness counter* tracks how useful the particular entry has been
in the past for providing correct predictions. The *tag* allows the
table to only make a prediction if there is a tag match for the
particular requesting instruction address and global history.

Each table has a different (and geometrically increasing) amount of
history associated with it. Each table’s history is used to hash with
the requesting instruction address to produce an index hash and a tag
hash. Each table will make its own prediction (or no prediction, if
there is no tag match). The table with the longest history making a
prediction wins.

On a misprediction, **TAGE** attempts to allocate a new entry. It will only
overwrite an entry that is "not useful" (ubits == 0).

...

Each **TAGE** table has associated with it its own global history (and each
table has geometrically more history than the last table). The histories
contain many more bits of history that can be used to index a **TAGE** table; therefore, the
history must be "folded" to fit. A table with 1024 entries uses 10 bits
to index the table. Therefore, if the table uses 20 bits of global
history, the top 10 bits of history are XOR’ed against the bottom 10
bits of history.

...

Usefulness counters (u-bits)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The “usefulness” of an entry is stored in the *u-bit* counters.
Roughly speaking, if an entry provides a correct prediction, the u-bit
counter is incremented. If an entry provides an incorrect prediction,
the u-bit counter is decremented. When a misprediction occurs, **TAGE**
attempts to allocate a new entry. To prevent overwriting a useful entry,
it will only allocate an entry if the existing entry has a usefulness of
zero. However, if an entry allocation fails because all of the potential
entries are useful, then all of the potential entries are decremented to
potentially make room for an allocation in the future.

To prevent **TAGE** from filling up with only useful but rarely-used
entries, **TAGE** must provide a scheme for "degrading" the u-bits over
time. A number of schemes are available. One option is a timer that
periodically degrades the u-bit counters. Another option is to track the
number of failed allocations (incrementing on a failed allocation and
decremented on a successful allocation). Once the counter has saturated,
all u-bits are degraded.
```

### `COMMIT_MESSAGE`

```text
[tage] Add write-bypass for TAGE counters, use ghist to compute tag
```

### `COMMIT_MESSAGE`

```text
[bpd] Switch to masked-mems for TAGE
```

## Additional requirement

With `idx` = `fetchIdx(pc)` and `h` = the low `histLength` bits of the history, a lookup with `f1_req_pc` and `f1_req_ghist` or an update with `update_pc` and `update_hist` selects the row given by the low `log2Ceil(nRows)` bits of `idx` XOR `h` folded to `log2Ceil(nRows)` bits and the tag given by the low `tagSz` bits of `idx >> log2Ceil(nRows)` XOR `h` folded to `tagSz` bits; an update with `update_alloc` set writes prediction counter 4 if `update_taken` is set and 3 otherwise; an update without `update_alloc` increments the counter if `update_taken` is set and decrements it otherwise, saturating at 7 and 0, starting from the counter that the previous update with that lane's `update_mask` bit set wrote to the same row and tag if no update with any `update_mask` bit set wrote another row or tag in between, or from `update_old_ctr` if no update has written that row, tag and lane since reset.
