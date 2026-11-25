# Implement `CsrScoreBoard`

Implement the complete `CsrScoreBoard` class. Preserve the class name and interface shown below.

Return only the complete `class CsrScoreBoard` definition in a single Scala code block, with no text outside the block.

## Package and imports

### src/main/scala/rift2Core/privilege/CsrScoreBoard.scala

```scala
package rift2Core.privilege


import chisel3._
import chisel3.util._
import base._
import rift2Core.backend._

import rift2Chip._
import org.chipsalliance.cde.config._
```

## Class declaration

### src/main/scala/rift2Core/privilege/CsrScoreBoard.scala

```scala
class CsrScoreBoard(implicit p: Parameters) extends CsrScoreBoardBase
```

## Parent instantiation

### src/main/scala/rift2Core/backend/WriteBack.scala

```scala
  val cReg = Module(new CsrScoreBoard)
// ...
  io.xpuCsrMolloc    <> cReg.io.xpu.molloc
  io.xpuCsrWriteBack <> cReg.io.xpu.writeBack
  io.xpuCsrCommit    <> cReg.io.xpu.commit
  io.fpuCsrMolloc    <> cReg.io.fpu.molloc
  io.fpuCsrWriteBack <> cReg.io.fpu.writeBack
  io.fpuCsrCommit    <> cReg.io.fpu.commit
  io.vpuCsrMolloc    <> cReg.io.vpu.molloc
  io.vpuCsrWriteBack <> cReg.io.vpu.writeBack
  io.vpuCsrCommit    <> cReg.io.vpu.commit
  io.isCSRMMUReady   := cReg.io.isMMUReady
// ...
  cReg.io.isAbort := ( 0 until cmChn ).map{ i => io.xCommit(i).is_abort | io.xCommit(i).is_MisPredict }.foldLeft(false.B)(_|_)
```

## Dependency declarations

### src/main/scala/rift2Core/privilege/CsrScoreBoard.scala

```scala
/**
  * An interface for XPUCsrIO signals.
  * @param p The parameters of the system.
  */
class XPUCsrIO(implicit p: Parameters) extends RiftBundle{
  /** The csr allocation signal, used at rename stage */
  val molloc    = Vec(rnChn, Flipped(Decoupled(UInt(12.W))))
  /** The write-back signal, used at execute stage */
  val writeBack = Flipped(Valid(new Exe_Port))
  /** The commit signal, used at commit stage */
  val commit    = Decoupled(new Exe_Port)
}

/**
  * An interface for FPUCsrIO signals.
  * @param p The parameters of the system.
  */
class FPUCsrIO(implicit p: Parameters) extends RiftBundle{
  /** The csr allocation signal, used at rename stage while a FAlu instruction is renaming */
  val molloc    = Vec(rnChn, Flipped(Decoupled(Bool())))
  /** The write-back signal, used at execute stage */
  val writeBack = Flipped(Valid(new Exe_Port))
  /** The commit signal, used at commit stage */
  val commit    = Decoupled(new Exe_Port)
}

/**
  * An interface for VPUCsrIO signals.
  * @param p The parameters of the system.
  */
class VPUCsrIO(implicit p: Parameters) extends FPUCsrIO

/**
  * An interface for the CSR scoreboard signals.
  * @param p The parameters of the system.
  */
class CsrScoreBoardIO(implicit p: Parameters) extends RiftBundle{
  val xpu: XPUCsrIO      = new XPUCsrIO
  val fpu: FPUCsrIO      = new FPUCsrIO
  val vpu: VPUCsrIO      = new VPUCsrIO

  val isMMUReady: Bool = Output(Bool())
  val isAbort: Bool      = Input(Bool())
}

/**
  * An abstract class that extends RiftModule and defines a CSR scoreboard base module.
  * @param p Represents the Parameters
  */
abstract class CsrScoreBoardBase(implicit p: Parameters) extends RiftModule{
  /** An instance of CsrScoreBoardIO that has two sub-interfaces of XPUCsrIO and FPUCsrIO and a Boolean input called isAbort */
  val io: CsrScoreBoardIO = IO(new CsrScoreBoardIO)

  /** A class to create CSR which Read & Write in order with given name and address.
    * @param name The name of the CSR
    * @param address The memory address of the CSR
    */
  class CSRInOrderReadWrite(val name: String, val address: Int) {
    /** interface */
    val isFlush  = Wire(Bool())
    val isClear  = Wire(Bool())
    val isMolloc = Wire(Bool())

    val isReady4Molloc = Wire(Bool()) //used at renmae

    /** Read-State and Write-State as binary values */
    def RDSTATE = "b0".U
    def WRSTATE = "b1".U

    /** Current state of the CSR */
    val curState = RegInit(RDSTATE)

    /** Flushes the current state if isFlush flag is high */
    when(isFlush){
      curState := RDSTATE
    } .elsewhen(isMolloc){
      curState := ~curState //WRSTATE
      assert(curState === RDSTATE, cf"Assert Failed at ${name}($address%X), Write requesting when not ready" )
    }.elsewhen( (curState === WRSTATE) & isClear){ //the same csr cannot molloc again until the counter is committed to empty once
      curState := ~curState //RDSTATE
    }
    isReady4Molloc := curState === RDSTATE
  }

  
  val XPUStatus: Seq[CSRInOrderReadWrite] = CSRInfoTable.XPUCSRGroup.map{ x => new CSRInOrderReadWrite( x.name, x.address ) }
  val FPUStatus: Seq[CSRInOrderReadWrite] = CSRInfoTable.FPUCSRGroup.map{ x => new CSRInOrderReadWrite( x.name, x.address ) }
  val VPUStatus: Seq[CSRInOrderReadWrite] = CSRInfoTable.VPUCSRGroup.map{ x => new CSRInOrderReadWrite( x.name, x.address ) }

  val fflags : CSRInOrderReadWrite = FPUStatus.apply(0); require(fflags.address == 0x001)
  val frm    : CSRInOrderReadWrite = FPUStatus.apply(1); require(frm.address    == 0x002)
  val fcsr   : CSRInOrderReadWrite = FPUStatus.apply(2); require(fcsr.address   == 0x003)
  val mstatus: CSRInOrderReadWrite = XPUStatus.find( _.name == "mstatus").get

  val vstart  : CSRInOrderReadWrite = VPUStatus.apply(0); require( vstart.address == 0x008)
  val vxsat   : CSRInOrderReadWrite = VPUStatus.apply(1); require( vxsat.address == 0x009)
  val vxrm    : CSRInOrderReadWrite = VPUStatus.apply(2); require( vxrm.address == 0x00A)
  val vcsr    : CSRInOrderReadWrite = VPUStatus.apply(3); require( vcsr.address == 0x00F)
  val vl      : CSRInOrderReadWrite = VPUStatus.apply(4); require( vl.address == 0xC20)
  val vtype   : CSRInOrderReadWrite = VPUStatus.apply(5); require( vtype.address == 0xC21)
  val vConfig : CSRInOrderReadWrite = VPUStatus.apply(6); require( vConfig.address == 0xFFE)
  val vlenb   : CSRInOrderReadWrite = VPUStatus.apply(7); require( vlenb.address == 0xC22)

  /** create all implemented CSR register from the preset Array CSRInfoTable */
  val CSRStatus = XPUStatus ++ FPUStatus ++ VPUStatus

  /** Maximum inflight number of CSR Instruction */
  def xpuInfly = 4
  val xpuInflyCounter  = Module( new Queue(new Bool(),   entries = xpuInfly, pipe = false, flow = false) )
  val xpuWriteBackFifo = Module( new Queue(new Exe_Port, entries = xpuInfly, pipe = false, flow = false) )
  val isXpuInfly = xpuInflyCounter.io.deq.valid

  /** Maximum inflight number of FALU */
  def fpuInfly = 4
  val fpuInflyCounter  = Module( new Queue(new Bool(),   entries = fpuInfly, pipe = false, flow = false) )
  val fpuWriteBackFifo = Module( new Queue(new Exe_Port, entries = fpuInfly, pipe = false, flow = false) )
  val isFpuInfly = fpuInflyCounter.io.deq.valid

  /** Maximum inflight number of VALU, Works in Ping-ping Mode */
  def vpuInfly = 2
  val vpuInflyCounter  = Module( new Queue(new Bool(),   entries = vpuInfly, pipe = true, flow = false) )
  val vpuWriteBackFifo = Module( new Queue(new Exe_Port, entries = vpuInfly, pipe = true, flow = false) )
  val isVpuInfly = vpuInflyCounter.io.deq.valid
  val isVtypeLock = RegInit(false.B)

}
```

### src/main/scala/rift2Core/privilege/CsrFiles.scala

```scala
class CsrOperator extends Bundle{
  val dat_i = UInt(64.W)
  val op_rw = Bool()
  val op_rs = Bool()
  val op_rc = Bool()
}

class Exe_Port extends CsrOperator {
  val addr = UInt(12.W)
}

```

### src/main/scala/rift2Core/privilege/CSRInfoTable.scala

```scala
case class CSRInfo( val name: String, val address: Int, val isRO: Boolean, val priv: Int, val isDMode: Boolean ){
}
// ...
object CSRInfoTable{

  val pmpcfg  = for( i <- 0 until 16 by 2 ) yield { CSRInfo( name = s"pmpcfg$i",     address = 0x3A0+i, isRO = false, priv = 3, isDMode = false ) }
  val pmpaddr = for( i <- 0 until 16*8 )    yield { CSRInfo( name = s"pmpaddr$i",    address = 0x3B0+i, isRO = false, priv = 3, isDMode = false ) }
  val mhpmcounter = for( i <- 3 until 32 )  yield { CSRInfo( name = s"mhpmcounter$i",address = 0xB00+i, isRO = false, priv = 3, isDMode = false ) }
  val mhpmevent  = for( i <- 3 until 32 )   yield { CSRInfo( name = s"mhpmevent$i",  address = 0x320+i, isRO = false, priv = 3, isDMode = false ) }
  val hpmcounter =for( i <- 3 until 32 )    yield { CSRInfo( name = s"hpmcounter$i", address = 0xC00+i, isRO = true,  priv = 0, isDMode = false ) }

  val XPUCSRGroup: Seq[CSRInfo] =
    Seq(
      CSRInfo( name = "ustatus",       address = 0x000, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "uie",           address = 0x004, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "utvec",         address = 0x005, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "uscratch",      address = 0x040, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "uepc",          address = 0x041, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "ucause",        address = 0x042, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "utval",         address = 0x043, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "uip",           address = 0x044, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "cycle",         address = 0xC00, isRO = true , priv = 0, isDMode = false ),
      CSRInfo( name = "time",          address = 0xC01, isRO = true , priv = 0, isDMode = false ),
      CSRInfo( name = "instret",       address = 0xC02, isRO = true , priv = 0, isDMode = false ),
      CSRInfo( name = "sstatus",       address = 0x100, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sedeleg",       address = 0x102, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sideleg",       address = 0x103, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sie",           address = 0x104, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "stvec",         address = 0x105, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "scounteren",    address = 0x106, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sscratch",      address = 0x140, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sepc",          address = 0x141, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "scause",        address = 0x142, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "stval",         address = 0x143, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "sip",           address = 0x144, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "satp",          address = 0x180, isRO = false, priv = 1, isDMode = false ),
      CSRInfo( name = "hstatus",       address = 0x600, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hedeleg",       address = 0x602, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hideleg",       address = 0x603, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hie",           address = 0x604, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hcounteren",    address = 0x606, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hgeie",         address = 0x607, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "htval",         address = 0x643, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hip",           address = 0x644, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hvip",          address = 0x645, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "htinst",        address = 0x64A, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "hgeip",         address = 0xE12, isRO = true , priv = 2, isDMode = false ),
      CSRInfo( name = "hgatp",         address = 0x680, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "htimedelta",    address = 0x605, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsstatus",      address = 0x200, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsie",          address = 0x204, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vstvec",        address = 0x205, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsscratch",     address = 0x240, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsepc",         address = 0x241, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vscause",       address = 0x242, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vstval",        address = 0x243, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsip",          address = 0x244, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "vsatp",         address = 0x280, isRO = false, priv = 2, isDMode = false ),
      CSRInfo( name = "mvendorid",     address = 0xF11, isRO = true , priv = 3, isDMode = false ),
      CSRInfo( name = "marchid",       address = 0xF12, isRO = true , priv = 3, isDMode = false ),
      CSRInfo( name = "mimpid",        address = 0xF13, isRO = true , priv = 3, isDMode = false),
      CSRInfo( name = "mhartid",       address = 0xF14, isRO = true , priv = 3, isDMode = false),
      CSRInfo( name = "mstatus",       address = 0x300, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "misa",          address = 0x301, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "medeleg",       address = 0x302, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mideleg",       address = 0x303, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mie",           address = 0x304, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mtvec",         address = 0x305, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mcounteren",    address = 0x306, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mscratch",      address = 0x340, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mepc",          address = 0x341, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mcause",        address = 0x342, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mtval",         address = 0x343, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mip",           address = 0x344, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mtinst",        address = 0x34A, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mtval2",        address = 0x34B, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mcycle",        address = 0xB00, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "minstret",      address = 0xB02, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "mcountinhibit", address = 0x320, isRO = false, priv = 3, isDMode = false ),
      CSRInfo( name = "tselect",       address = 0x7A0, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "tdata1",        address = 0x7A1, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "tdata2",        address = 0x7A2, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "tdata3",        address = 0x7A3, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "dcsr",          address = 0x7B0, isRO = false, priv = 0, isDMode = true ),
      CSRInfo( name = "dpc",           address = 0x7B1, isRO = false, priv = 0, isDMode = true ),
      CSRInfo( name = "dscratch0",     address = 0x7B2, isRO = false, priv = 0, isDMode = true ),
      CSRInfo( name = "dscratch1",     address = 0x7B3, isRO = false, priv = 0, isDMode = true ),
      CSRInfo( name = "dscratch2",     address = 0x7B4, isRO = false, priv = 0, isDMode = true ),
    ) ++ pmpcfg ++ pmpaddr ++ mhpmcounter ++ mhpmevent ++ hpmcounter
  
  val FPUCSRGroup =
    Seq(
      CSRInfo( name = "fflags",        address = 0x001, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "frm",           address = 0x002, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "fcsr",          address = 0x003, isRO = false, priv = 0, isDMode = false ),
    )

  val VPUCSRGroup = 
    Seq(
      CSRInfo( name = "vstart",        address = 0x008, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vxsat",         address = 0x009, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vxrm",          address = 0x00A, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vcsr",          address = 0x00F, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vl",            address = 0xC20, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vtype",         address = 0xC21, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vConfig",       address = 0xFFE, isRO = false, priv = 0, isDMode = false ),
      CSRInfo( name = "vlenb",         address = 0xC22, isRO = true , priv = 0, isDMode = false ),
    )

  val CSRGroup = XPUCSRGroup ++ FPUCSRGroup ++ VPUCSRGroup

}
```

## Related source code

### src/main/scala/rift2Core/backend/Rename.scala

```scala
    io.xpuCsrMolloc(i).bits := 
      Mux1H(Seq(
        io.rnReq(i).bits.csrIsa.isXCSR -> io.rnReq(i).bits.param.imm,
        io.rnReq(i).bits.csrIsa.isVSet -> "hFFE".U,
      ))

    io.xpuCsrMolloc(i).valid :=
      io.rnReq(i).fire & io.rnReq(i).bits.csrIsa.is_csr
// ...
        (io.isCSRMMUReady & (0 until j).map{k => ~io.rnReq(k).bits.csrIsa.is_csr}.foldLeft(true.B)(_&_) | ~io.rnReq(j).bits.lsuIsa.is_lsu) &
```

### src/main/scala/rift2Core/backend/Csr.scala

```scala
  io.xpuCsrWriteBack.valid := csr_exe_iwb_fifo.io.enq.fire
```

### src/main/scala/rift2Core/backend/Commit.scala

```scala
/** commit
  * @note for every commit-chn, it can be:
  * comfirm: commit at this tick
  * abort: cancel and flush at this tick
  * cancel: the perivious chn abort
  * idle: empty line or waitting to check whether is comfirm or abort
  */
// ...
  io.xpuCsrCommit.ready := ( 0 until cmChn ).map{ i => commit_state_is_comfirm(i) & io.rod(i).bits.is_csr }.foldLeft(false.B)(_|_)
```

## Additional requirement

When `io.isAbort` is asserted, every pending CSR allocation and write-back result is discarded: in the following cycle no discarded result is offered on a `commit` port, and no discarded allocation blocks a later `molloc` request.
