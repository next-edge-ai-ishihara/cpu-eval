# Implement `BoomIOMSHR`

Implement one complete `BoomIOMSHR` source-level hardware definition for the selected BOOM configuration. Preserve the definition name, constructor parameters, inheritance, and public interface shown below.

Return only the complete `class BoomIOMSHR` definition in a single Scala code block, with no text outside the block.

## CPU configuration used for evaluation

### src/main/scala/common/config-mixins.scala

```scala
// DOC include start: LargeBoomConfig
/**
 * 3-wide BOOM. Try to match the Cortex-A15.
 */
class WithNLargeBooms(n: Int = 1, overrideIdOffset: Option[Int] = None) extends Config(
// ...
            dcache = Some(
              DCacheParams(rowBits = site(SystemBusKey).beatBits, nSets=64, nWays=8, nMSHRs=4, nTLBWays=16)
            ),
// ...
    case SystemBusKey => up(SystemBusKey, site).copy(beatBytes = 16)
    case XLen => 64
  })
)
// DOC include end: LargeBoomConfig
```

## Package and imports

```scala
package boom.lsu

import chisel3._
import chisel3.util._

import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.tile._
import freechips.rocketchip.util._
import freechips.rocketchip.rocket._

import boom.common._
import boom.exu.BrUpdateInfo
import boom.util.{IsKilledByBranch, GetNewBrMask, BranchKillableQueue, IsOlder, UpdateBrMask, AgePriorityEncoder, WrapInc}
```

## Class declaration

```scala
class BoomIOMSHR(id: Int)(implicit edge: TLEdgeOut, p: Parameters) extends BoomModule()(p)
  with HasL1HellaCacheParameters
{
  val io = IO(new Bundle {
    val req  = Flipped(Decoupled(new BoomDCacheReq))
    val resp = Decoupled(new BoomDCacheResp)
    val mem_access = Decoupled(new TLBundleA(edge.bundle))
    val mem_ack    = Flipped(Valid(new TLBundleD(edge.bundle)))

    // We don't need brupdate in here because uncacheable operations are guaranteed non-speculative
  })
```

## Parent instantiation

### src/main/scala/lsu/mshrs.scala

```scala
  val req_idx = OHToUInt(io.req.map(_.valid))
  val req     = io.req(req_idx)
  val req_is_probe = io.req_is_probe(0)

  for (w <- 0 until memWidth)
    io.req(w).ready := false.B
// ...
  val cacheable = edge.manager.supportsAcquireBFast(req.bits.addr, lgCacheBlockBytes.U)
// ...
  val resp_arb       = Module(new Arbiter(new BoomDCacheResp           , cfg.nMSHRs + nIOMSHRs))
// ...
  io.mem_grant.ready := false.B
// ...
  val mmio_alloc_arb = Module(new Arbiter(Bool(), nIOMSHRs))


  var mmio_rdy = false.B

  val mmios = (0 until nIOMSHRs) map { i =>
    val id = cfg.nMSHRs + 1 + i // +1 for wb unit
    val mshr = Module(new BoomIOMSHR(id))

    mmio_alloc_arb.io.in(i).valid := mshr.io.req.ready
    mmio_alloc_arb.io.in(i).bits  := DontCare
    mshr.io.req.valid := mmio_alloc_arb.io.in(i).ready
    mshr.io.req.bits  := req.bits

    mmio_rdy = mmio_rdy || mshr.io.req.ready

    mshr.io.mem_ack.bits  := io.mem_grant.bits
    mshr.io.mem_ack.valid := io.mem_grant.valid && io.mem_grant.bits.source === id.U
    when (io.mem_grant.bits.source === id.U) {
      io.mem_grant.ready := true.B
    }

    resp_arb.io.in(cfg.nMSHRs + i) <> mshr.io.resp
    when (!mshr.io.req.ready) {
      io.fence_rdy := false.B
    }
    mshr
  }

  mmio_alloc_arb.io.out.ready := req.valid && !cacheable

  TLArbiter.lowestFromSeq(edge, io.mem_acquire, mshrs.map(_.io.mem_acquire) ++ mmios.map(_.io.mem_access))
// ...
  val respq = Module(new BranchKillableQueue(new BoomDCacheResp, 4, u => u.uses_ldq, flow = false))
  respq.io.brupdate := io.brupdate
  respq.io.flush    := io.exception
  respq.io.enq      <> resp_arb.io.out
  io.resp           <> respq.io.deq

  for (w <- 0 until memWidth) {
    io.req(w).ready      := (w.U === req_idx) &&
      Mux(!cacheable, mmio_rdy, sdq_rdy && Mux(idx_match(w), tag_match(w) && sec_rdy, pri_rdy))
```

## Dependency declarations

### build.sbt

```scala
val chiselVersion = "3.5-SNAPSHOT"

lazy val chiselSettings = Seq(
  libraryDependencies ++= Seq("edu.berkeley.cs" %% "chisel3" % chiselVersion),
  addCompilerPlugin("edu.berkeley.cs" % "chisel3-plugin" % chiselVersion cross CrossVersion.full))
```

### src/main/scala/lsu/lsu.scala

```scala
class BoomDCacheReq(implicit p: Parameters) extends BoomBundle()(p)
  with HasBoomUOP
{
  val addr  = UInt(coreMaxAddrBits.W)
  val data  = Bits(coreDataBits.W)
  val is_hella = Bool() // Is this the hellacache req? If so this is not tracked in LDQ or STQ
}

class BoomDCacheResp(implicit p: Parameters) extends BoomBundle()(p)
  with HasBoomUOP
{
  val data = Bits(coreDataBits.W)
  val is_hella = Bool()
}
```

### src/main/scala/common/micro-op.scala

```scala
/**
 * Extension to BoomBundle to add a MicroOp
 */
abstract trait HasBoomUOP extends BoomBundle
{
  val uop = new MicroOp()
}

/**
 * MicroOp passing through the pipeline
 */
class MicroOp(implicit p: Parameters) extends BoomBundle
  with freechips.rocketchip.rocket.constants.MemoryOpConstants
  with freechips.rocketchip.rocket.constants.ScalarOpConstants
{
// ...
  val mem_cmd          = UInt(M_SZ.W)          // sync primitives/cache flushes
  val mem_size         = UInt(2.W)
  val mem_signed       = Bool()
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
// ...
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
// ...
  def M_PWR     = UInt("b10001") // partial (masked) store
// ...
  def M_HLVX    = UInt("b10000") // HLVX instruction

  def isAMOLogical(cmd: UInt) = cmd.isOneOf(M_XA_SWAP, M_XA_XOR, M_XA_OR, M_XA_AND)
  def isAMOArithmetic(cmd: UInt) = cmd.isOneOf(M_XA_ADD, M_XA_MIN, M_XA_MAX, M_XA_MINU, M_XA_MAXU)
  def isAMO(cmd: UInt) = isAMOLogical(cmd) || isAMOArithmetic(cmd)
// ...
  def isRead(cmd: UInt) = cmd.isOneOf(M_XRD, M_HLVX, M_XLR, M_XSC) || isAMO(cmd)
  def isWrite(cmd: UInt) = cmd === M_XWR || cmd === M_PWR || cmd === M_XSC || isAMO(cmd)
```

### src/main/scala/rocket/HellaCache.scala

```scala
    nMMIOs: Int = 1,
// ...
trait HasL1HellaCacheParameters extends HasL1CacheParameters with HasCoreParameters {
  val cacheParams = tileParams.dcache.get
  val cfg = cacheParams

  def wordBits = coreDataBits
  def wordBytes = coreDataBytes
  def subWordBits = cacheParams.subWordBits.getOrElse(wordBits)
  def subWordBytes = subWordBits / 8
  def wordOffBits = log2Up(wordBytes)
  def beatBytes = cacheBlockBytes / cacheDataBeats
  def beatWords = beatBytes / wordBytes
  def beatOffBits = log2Up(beatBytes)
// ...
  def nIOMSHRs = cacheParams.nMMIOs
  def maxUncachedInFlight = cacheParams.nMMIOs
```

### src/main/scala/tilelink/Bundles.scala

```scala
object TLMessages
{
  //                                  A    B    C    D    E
  def PutFullData    = UInt(0) //     .    .                   => AccessAck
  def PutPartialData = UInt(1) //     .    .                   => AccessAck
  def ArithmeticData = UInt(2) //     .    .                   => AccessAckData
  def LogicalData    = UInt(3) //     .    .                   => AccessAckData
  def Get            = UInt(4) //     .    .                   => AccessAckData
  def Hint           = UInt(5) //     .    .                   => HintAck
  def AcquireBlock   = UInt(6) //     .                        => Grant[Data]
  def AcquirePerm    = UInt(7) //     .                        => Grant[Data]
  def Probe          = UInt(6) //          .                   => ProbeAck[Data]
  def AccessAck      = UInt(0) //               .    .
  def AccessAckData  = UInt(1) //               .    .
  def HintAck        = UInt(2) //               .    .
  def ProbeAck       = UInt(4) //               .
  def ProbeAckData   = UInt(5) //               .
  def Release        = UInt(6) //               .              => ReleaseAck
  def ReleaseData    = UInt(7) //               .              => ReleaseAck
  def Grant          = UInt(4) //                    .         => GrantAck
  def GrantData      = UInt(5) //                    .         => GrantAck
  def ReleaseAck     = UInt(6) //                    .
  def GrantAck       = UInt(0) //                         .

  def isA(x: UInt) = x <= AcquirePerm
  def isB(x: UInt) = x <= Probe
  def isC(x: UInt) = x <= ReleaseData
  def isD(x: UInt) = x <= ReleaseAck

  def adResponse = Vec(AccessAck, AccessAck, AccessAckData, AccessAckData, AccessAckData, HintAck, Grant, Grant)
  def bcResponse = Vec(AccessAck, AccessAck, AccessAckData, AccessAckData, AccessAckData, HintAck, ProbeAck, ProbeAck)
// ...
object TLAtomics
{
  val width = 3

  // Arithmetic types
  def MIN  = UInt(0, width)
  def MAX  = UInt(1, width)
  def MINU = UInt(2, width)
  def MAXU = UInt(3, width)
  def ADD  = UInt(4, width)
  def isArithmetic(x: UInt) = x <= ADD

  // Logical types
  def XOR  = UInt(0, width)
  def OR   = UInt(1, width)
  def AND  = UInt(2, width)
  def SWAP = UInt(3, width)
  def isLogical(x: UInt) = x <= SWAP

  def ArithMsg:Seq[String] = Seq("MIN", "MAX", "MINU", "MAXU", "ADD")
  def LogicMsg:Seq[String] = Seq("XOR", "OR", "AND", "SWAP")
}
// ...
final class TLBundleA(params: TLBundleParameters)
  extends TLBundleBase(params) with TLAddrChannel
{
  val channelName = "'A' channel"
  // fixed fields during multibeat:
  val opcode  = UInt(width = 3)
  val param   = UInt(width = List(TLAtomics.width, TLPermissions.aWidth, TLHints.width).max) // amo_opcode || grow perms || hint
  val size    = UInt(width = params.sizeBits)
  val source  = UInt(width = params.sourceBits) // from
  val address = UInt(width = params.addressBits) // to
  val user    = BundleMap(params.requestFields)
  val echo    = BundleMap(params.echoFields)
  // variable fields during multibeat:
  val mask    = UInt(width = params.dataBits/8)
  val data    = UInt(width = params.dataBits)
  val corrupt = Bool() // only applies to *Data messages
// ...
final class TLBundleD(params: TLBundleParameters)
  extends TLBundleBase(params) with TLDataChannel
{
  val channelName = "'D' channel"
  // fixed fields during multibeat:
  val opcode  = UInt(width = 3)
  val param   = UInt(width = TLPermissions.bdWidth) // cap perms
  val size    = UInt(width = params.sizeBits)
  val source  = UInt(width = params.sourceBits) // to
  val sink    = UInt(width = params.sinkBits)   // from
  val denied  = Bool() // implies corrupt iff *Data
  val user    = BundleMap(params.responseFields)
  val echo    = BundleMap(params.echoFields)
  // variable fields during multibeat:
  val data    = UInt(width = params.dataBits)
  val corrupt = Bool() // only applies to *Data messages
}
```

### src/main/scala/tilelink/Edges.scala

```scala
  // Accesses
  def Get(fromSource: UInt, toAddress: UInt, lgSize: UInt) = {
    require (manager.anySupportGet, s"TileLink: No managers visible from this edge support Gets, but one of these clients would try to request one: ${client.clients}")
    val legal = manager.supportsGetFast(toAddress, lgSize)
    val a = Wire(new TLBundleA(bundle))
    a.opcode  := TLMessages.Get
    a.param   := UInt(0)
    a.size    := lgSize
    a.source  := fromSource
    a.address := toAddress
    a.mask    := mask(toAddress, lgSize)
    a.data    := UInt(0)
    a.corrupt := Bool(false)
    (legal, a)
  }

  def Put(fromSource: UInt, toAddress: UInt, lgSize: UInt, data: UInt): (Bool, TLBundleA) =
    Put(fromSource, toAddress, lgSize, data, Bool(false))

  def Put(fromSource: UInt, toAddress: UInt, lgSize: UInt, data: UInt, corrupt: Bool): (Bool, TLBundleA) = {
    require (manager.anySupportPutFull, s"TileLink: No managers visible from this edge support Puts, but one of these clients would try to request one: ${client.clients}")
    val legal = manager.supportsPutFullFast(toAddress, lgSize)
    val a = Wire(new TLBundleA(bundle))
    a.opcode  := TLMessages.PutFullData
    a.param   := UInt(0)
    a.size    := lgSize
    a.source  := fromSource
    a.address := toAddress
    a.mask    := mask(toAddress, lgSize)
    a.data    := data
    a.corrupt := corrupt
    (legal, a)
// ...
  def Arithmetic(fromSource: UInt, toAddress: UInt, lgSize: UInt, data: UInt, atomic: UInt, corrupt: Bool = Bool(false)): (Bool, TLBundleA) = {
    require (manager.anySupportArithmetic, s"TileLink: No managers visible from this edge support arithmetic AMOs, but one of these clients would try to request one: ${client.clients}")
    val legal = manager.supportsArithmeticFast(toAddress, lgSize)
    val a = Wire(new TLBundleA(bundle))
    a.opcode  := TLMessages.ArithmeticData
    a.param   := atomic
    a.size    := lgSize
    a.source  := fromSource
    a.address := toAddress
    a.mask    := mask(toAddress, lgSize)
    a.data    := data
    a.corrupt := corrupt
    (legal, a)
  }

  def Logical(fromSource: UInt, toAddress: UInt, lgSize: UInt, data: UInt, atomic: UInt, corrupt: Bool = Bool(false)) = {
    require (manager.anySupportLogical, s"TileLink: No managers visible from this edge support logical AMOs, but one of these clients would try to request one: ${client.clients}")
    val legal = manager.supportsLogicalFast(toAddress, lgSize)
    val a = Wire(new TLBundleA(bundle))
    a.opcode  := TLMessages.LogicalData
    a.param   := atomic
    a.size    := lgSize
    a.source  := fromSource
    a.address := toAddress
    a.mask    := mask(toAddress, lgSize)
    a.data    := data
    a.corrupt := corrupt
    (legal, a)
  }
```

### src/main/scala/rocket/AMOALU.scala

```scala
class StoreGen(typ: UInt, addr: UInt, dat: UInt, maxSize: Int) {
  val size = typ(log2Up(log2Up(maxSize)+1)-1,0)
// ...
class LoadGen(typ: UInt, signed: Bool, addr: UInt, dat: UInt, zero: Bool, maxSize: Int) {
  private val size = new StoreGen(typ, addr, dat, maxSize).size

  private def genData(logMinSize: Int): UInt = {
    var res = dat
    for (i <- log2Up(maxSize)-1 to logMinSize by -1) {
      val pos = 8 << i
      val shifted = Mux(addr(i), res(2*pos-1,pos), res(pos-1,0))
      val doZero = Bool(i == 0) && zero
      val zeroed = Mux(doZero, UInt(0), shifted)
      res = Cat(Mux(size === UInt(i) || doZero, Fill(8*maxSize-pos, signed && zeroed(pos-1)), res(8*maxSize-1,pos)), zeroed)
    }
    res
  }

  def wordData = genData(2)
  def data = genData(0)
}
```

### src/main/scala/chisel3/util/Decoupled.scala

```scala
/** An I/O Bundle containing 'valid' and 'ready' signals that handshake
  * the transfer of data stored in the 'bits' subfield.
  * The base protocol implied by the directionality is that
  * the producer uses the interface as-is (outputs bits)
  * while the consumer uses the flipped interface (inputs bits).
  * The actual semantics of ready/valid are enforced via the use of concrete subclasses.
  * @param gen the type of data to be wrapped in Ready/Valid
  * @groupdesc Signals The actual hardware fields of the Bundle
  */
abstract class ReadyValidIO[+T <: Data](gen: T) extends Bundle {
  // Compatibility hack for rocket-chip
  private val genType = (DataMirror.internal.isSynthesizable(gen), chisel3.internal.Builder.currentModule) match {
    case (true, Some(module: Module)) if !module.compileOptions.declaredTypeMustBeUnbound => chiselTypeOf(gen)
    case _ => gen
  }

  /** Indicates that the consumer is ready to accept the data this cycle
    * @group Signals
    */
  val ready = Input(Bool())

  /** Indicates that the producer has put valid data in 'bits'
    * @group Signals
    */
  val valid = Output(Bool())

  /** The data to be transferred when ready and valid are asserted at the same cycle
    * @group Signals
    */
  val bits = Output(genType)
}

object ReadyValidIO {

  implicit class AddMethodsToReadyValid[T <: Data](target: ReadyValidIO[T]) {

    /** Indicates if IO is both ready and valid
      */
    def fire: Bool = target.ready && target.valid
// ...
/** A concrete subclass of ReadyValidIO signaling that the user expects a
  * "decoupled" interface: 'valid' indicates that the producer has
  * put valid data in 'bits', and 'ready' indicates that the consumer is ready
  * to accept the data this cycle. No requirements are placed on the signaling
  * of ready or valid.
  * @param gen the type of data to be wrapped in DecoupledIO
  */
class DecoupledIO[+T <: Data](gen: T) extends ReadyValidIO[T](gen)
```

## Related source code

### src/main/scala/lsu/lsu.scala

```scala
    when (io.dmem.resp(w).valid)
    {
      when (io.dmem.resp(w).bits.uop.uses_ldq)
      {
        assert(!io.dmem.resp(w).bits.is_hella)
        val ldq_idx = io.dmem.resp(w).bits.uop.ldq_idx
        val send_iresp = ldq(ldq_idx).bits.uop.dst_rtype === RT_FIX
        val send_fresp = ldq(ldq_idx).bits.uop.dst_rtype === RT_FLT

        io.core.exe(w).iresp.bits.uop  := ldq(ldq_idx).bits.uop
        io.core.exe(w).fresp.bits.uop  := ldq(ldq_idx).bits.uop
        io.core.exe(w).iresp.valid     := send_iresp
        io.core.exe(w).iresp.bits.data := io.dmem.resp(w).bits.data
        io.core.exe(w).fresp.valid     := send_fresp
        io.core.exe(w).fresp.bits.data := io.dmem.resp(w).bits.data

        assert(send_iresp ^ send_fresp)
        dmem_resp_fired(w) := true.B

        ldq(ldq_idx).bits.succeeded      := io.core.exe(w).iresp.valid || io.core.exe(w).fresp.valid
        ldq(ldq_idx).bits.debug_wb_data  := io.dmem.resp(w).bits.data
      }
        .elsewhen (io.dmem.resp(w).bits.uop.uses_stq)
      {
        assert(!io.dmem.resp(w).bits.is_hella)
        stq(io.dmem.resp(w).bits.uop.stq_idx).bits.succeeded := true.B
        when (io.dmem.resp(w).bits.uop.is_amo) {
          dmem_resp_fired(w) := true.B
          io.core.exe(w).iresp.valid     := true.B
          io.core.exe(w).iresp.bits.uop  := stq(io.dmem.resp(w).bits.uop.stq_idx).bits.uop
          io.core.exe(w).iresp.bits.data := io.dmem.resp(w).bits.data

          stq(io.dmem.resp(w).bits.uop.stq_idx).bits.debug_wb_data := io.dmem.resp(w).bits.data
        }
      }
```

## Additional requirement

Keep `io.resp.valid` deasserted for an accepted request whose `uop.mem_cmd` satisfies `isWrite` but not `isRead`.
