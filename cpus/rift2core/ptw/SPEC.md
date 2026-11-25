# Implement `PTW`

Implement the complete `PTW` class. Preserve the class name and interface shown below.

Return only the complete `class PTW` definition in a single Scala code block, with no text outside the block.

## Package and imports

### src/main/scala/rift2Core/privilege/PTW.scala

```scala
package rift2Core.privilege

import chisel3._
import chisel3.util._
import chisel3.experimental.dataview._

import rift2Chip._
import base._

import org.chipsalliance.cde.config._
import freechips.rocketchip.tilelink._
```

## Class declaration

### src/main/scala/rift2Core/privilege/PTW.scala

```scala
class PTW(edge: TLEdgeOut, id: Int)(implicit p: Parameters) extends PTWBase(edge, id) 
```

## Parent instantiation

### src/main/scala/rift2Core/privilege/MMU.scala

```scala
  val iptw  = Module( new PTW(edge, id = 0) )
  val dptw  = Module( new PTW(edge, id = 1) )
// ...
  val kill_iptw = RegInit(false.B)
  val kill_dptw = RegInit(false.B)
  

  when( io.if_flush ) {
    kill_iptw := true.B
  } .elsewhen ( iptw.io.ptw_i.ready ) {
    kill_iptw := false.B
  }
  when( io.lsu_flush ) {
    kill_dptw := true.B
  } .elsewhen ( dptw.io.ptw_i.ready ) {
    kill_dptw := false.B
  }
// ...
  iptw.io.cmm_mmu := io.cmm_mmu
  dptw.io.cmm_mmu := io.cmm_mmu




  iptw.io.ptw_i.valid := io.if_mmu.valid & ~itlb.io.is_hit & ~is_bypass_if & ~kill_iptw
  iptw.io.ptw_i.bits  := io.if_mmu.bits

  dptw.io.ptw_i.valid := io.lsu_mmu.valid & ~dtlb.io.is_hit & ~is_bypass_ls & ~kill_dptw
  dptw.io.ptw_i.bits  := io.lsu_mmu.bits
// ...
    val pte = Mux( itlb.io.is_hit, itlb.io.pte_o, iptw.io.ptw_o.bits.renew.viewAsSupertype(new Info_pte_sv39) )
    val ivaddr = io.if_mmu.bits.vaddr
    val ipaddr = Mux( is_bypass_if, ivaddr, v2paddr( ivaddr, pte ) )
// ...
        (iptw.io.ptw_o.bits.is_access_fault & iptw.io.ptw_o.bits.is_X & iptw.io.ptw_o.valid) |
// ...
        is_chk_page_fault( pte, io.if_mmu.bits.vaddr, io.cmm_mmu.priv_lvl_if, "b100".U) |
        (iptw.io.ptw_o.bits.is_ptw_fail & iptw.io.ptw_o.bits.is_X & iptw.io.ptw_o.valid)
// ...
        (io.if_mmu.valid & (iptw.io.ptw_o.bits.is_X & iptw.io.ptw_o.valid))         
// ...
    assert( ~((iptw.io.ptw_o.bits.is_X & iptw.io.ptw_o.valid) & itlb.io.is_hit & ~kill_iptw )  )
// ...
    val pte = Mux( dtlb.io.is_hit, dtlb.io.pte_o, dptw.io.ptw_o.bits.renew.viewAsSupertype(new Info_pte_sv39) )
    val dvaddr = io.lsu_mmu.bits.vaddr
// ...
        (dptw.io.ptw_o.bits.is_access_fault & (~dptw.io.ptw_o.bits.is_X & dptw.io.ptw_o.valid)) |
// ...
        is_chk_page_fault( pte, io.lsu_mmu.bits.vaddr, io.cmm_mmu.priv_lvl_ls, Cat(io.lsu_mmu.bits.is_X, io.lsu_mmu.bits.is_W, io.lsu_mmu.bits.is_R )) |
        dptw.io.ptw_o.bits.is_ptw_fail & ~dptw.io.ptw_o.bits.is_X & dptw.io.ptw_o.valid
// ...
        (io.lsu_mmu.valid & (~dptw.io.ptw_o.bits.is_X & dptw.io.ptw_o.valid))           
// ...
    assert( ~((~dptw.io.ptw_o.bits.is_X & dptw.io.ptw_o.valid) & dtlb.io.is_hit & ~kill_dptw)  )
// ...
  iptw.io.ptw_o.ready := io.mmu_if.ready  | kill_iptw | io.if_flush


  dptw.io.ptw_o.ready := io.mmu_lsu.ready | kill_dptw | io.lsu_flush


  itlb.io.tlb_renew.bits := iptw.io.ptw_o.bits.renew
  dtlb.io.tlb_renew.bits := dptw.io.ptw_o.bits.renew

  itlb.io.tlb_renew.valid := iptw.io.ptw_o.fire &  iptw.io.ptw_o.bits.is_X & ~iptw.io.ptw_o.bits.is_ptw_fail & ~kill_iptw
  dtlb.io.tlb_renew.valid := dptw.io.ptw_o.fire & ~dptw.io.ptw_o.bits.is_X & ~dptw.io.ptw_o.bits.is_ptw_fail & ~kill_dptw
// ...
  val ptwGetArb  = Module(new Arbiter(new TLBundleA(edge.bundle), n = 2))
  
  ptwGetArb.io.in(0) <> iptw.io.ptw_get
  ptwGetArb.io.in(1) <> dptw.io.ptw_get
  io.ptw_get <> ptwGetArb.io.out


  when( io.ptw_access.bits.source === 0.U ) {
    iptw.io.ptw_access <> io.ptw_access
  } .elsewhen( io.ptw_access.bits.source === 1.U ) {
    dptw.io.ptw_access <> io.ptw_access
  }

  itlb.io.sfence_vma := io.cmm_mmu.sfence_vma
  dtlb.io.sfence_vma := io.cmm_mmu.sfence_vma
  iptw.io.sfence_vma  := io.cmm_mmu.sfence_vma
  dptw.io.sfence_vma  := io.cmm_mmu.sfence_vma
// ...

  def is_chk_page_fault(
    pte: Info_pte_sv39,
    chk_vaddr: UInt,
    chk_priv: UInt,
    chk_type: UInt): Bool = {

      val is_vaddr_illegal = chk_vaddr(63,39) =/= Fill(25,chk_vaddr(38))
      val is_U_access_illegal =
        (chk_priv === "b00".U & pte.U === false.B) |
        (chk_priv === "b01".U & pte.U === true.B & (io.cmm_mmu.sstatus(18) === false.B | chk_type(2) === true.B) ) |
        ( io.cmm_mmu.mstatus(17) & io.cmm_mmu.mstatus(12,11) === "b01".U & pte.U === true.B & io.cmm_mmu.sstatus(18) === false.B )

      val is_A_illegal = pte.A === false.B
      val is_D_illegal = pte.D === false.B & chk_type(1) === true.B
      val is_MXR_illegal = io.cmm_mmu.mstatus(19) === false.B & pte.R === false.B & chk_type(0) === true.B

      return is_vaddr_illegal | is_U_access_illegal | is_A_illegal | is_D_illegal | is_MXR_illegal
  }


  def v2paddr( vaddr: UInt, pte: Info_pte_sv39 ): UInt = {
    val paddr = Wire( UInt(64.W) )

    val pa_ppn_2 = pte.ppn(2)
    val pa_ppn_1 = Mux( (pte.is_giga_page ), vaddr(29,21), pte.ppn(1) )
    val pa_ppn_0 = Mux( (pte.is_giga_page | pte.is_mega_page), vaddr(20,12), pte.ppn(0) )
    val pa_pgoff = vaddr(11,0)

    paddr := Cat( pa_ppn_2, pa_ppn_1, pa_ppn_0, pa_pgoff )
    return paddr
  }    

```

## Dependency declarations

### src/main/scala/rift2Core/privilege/PTW.scala

```scala
class Info_ptw_rsp extends Bundle with Info_access_lvl{
  val renew = new TLB_Renew_Bundle
  val is_ptw_fail = Bool()
  val is_access_fault = Bool()

}

object PTWState {
  sealed abstract class State(val id: Int) {
    def U: UInt = id.U(State.width.W)
  }

  object State {
    import scala.language.implicitConversions

    implicit def toInt(x: State) = x.id
    implicit def toBigInt(x: State):BigInt = x.id

    val all: Set[State] = Set(
      Free,
      Lvl2,
      Lvl1,
      Lvl0,
    )
    val width = log2Ceil(all.size)
    def chiselType() = UInt(width.W)
  }

  case object Free extends State(0)
  case object Lvl2 extends State(1)
  case object Lvl1 extends State(2)
  case object Lvl0 extends State(3)
}



class PTWBase(edge: TLEdgeOut, id: Int)(implicit p: Parameters) extends RiftModule {
  val mEdge = edge
  val mid   = id
  def dw = l1DW
  def cl = 256
  

  class PTWIO extends Bundle{
    val ptw_i = Flipped(DecoupledIO(new Info_mmu_req))
    val ptw_o = DecoupledIO(new Info_ptw_rsp)

    val cmm_mmu = Input(new Info_cmm_mmu)

    val sfence_vma = Input(Bool())

    val ptw_get    = new DecoupledIO(new TLBundleA(mEdge.bundle))
    val ptw_access = Flipped(new DecoupledIO(new TLBundleD(mEdge.bundle)))    
  }

  val io: PTWIO = IO(new PTWIO)

  val nextState = WireInit(PTWState.Free.U)
  val currState = RegNext(next=nextState, init=PTWState.Free.U)

  val kill_trans = RegInit(false.B)

  val (_, _, is_trans_done, transCnt) = mEdge.count(io.ptw_access)
  val is_hit = Wire(Bool())

  val addr_dnxt = Wire(UInt(plen.W))
  val addr_qout = RegNext(addr_dnxt, 0.U(plen.W))

  val is_ptw_end = Wire(Bool())
  val is_ptw_fail = Wire(Bool())

  val pte = Wire(new Info_pte_sv39)

  val walkReq = RegEnable( io.ptw_i.bits,          (currState === PTWState.Free.U & nextState =/= PTWState.Free.U) )
  val asidReq = RegEnable( io.cmm_mmu.satp(59,44), (currState === PTWState.Free.U & nextState =/= PTWState.Free.U) )
  val walkRspBits = RegInit( 0.U.asTypeOf(new Info_ptw_rsp) )
  val walkRspValid = RegInit(false.B)
}
```

### src/main/scala/rift2Core/privilege/MMU.scala

```scala
class Info_pte_sv39 extends Bundle {
  val value = UInt(64.W)

  def V = value(0).asBool
  def R = value(1).asBool
  def W = value(2).asBool
  def X = value(3).asBool
  def U = value(4).asBool
  def G = value(5).asBool
  def A = value(6).asBool
  def D = value(7).asBool
  def rsw = value(9,8)
  def ppn = MixedVecInit( Seq( value(18,10), value(27,19), value(53,28) ) )

  val is_4K_page = Bool()
  val is_giga_page = Bool()
  val is_mega_page = Bool()
}

class TLB_Renew_Bundle extends Info_pte_sv39 {
  val asid = UInt( 16.W )
  val vpn = Vec( 3, UInt(9.W) )
}



trait Info_access_lvl extends Bundle {
  val is_X = Bool()
  val is_W = Bool()
  val is_R = Bool()
}


class Info_mmu_req(implicit p: Parameters) extends RiftBundle with Info_access_lvl{
  val vaddr = UInt(64.W)
}
// ...
class Info_cmm_mmu(implicit p: Parameters) extends RiftBundle {
  val satp = UInt(64.W)

	val pmpcfg  = (if( pmpNum == 0 ) { Vec(1,   UInt(64.W)) } else { Vec(pmpNum,   UInt(64.W)) })
  val pmpaddr = (if( pmpNum == 0 ) { Vec(8*1, UInt(64.W)) } else { Vec(8*pmpNum, UInt(64.W)) })

  val priv_lvl_if = UInt(2.W)
  val priv_lvl_ls = UInt(2.W)

  val mstatus = UInt(64.W)
  val sstatus = UInt(64.W)

  val sfence_vma = Bool()

}
```

### src/main/scala/rift2Core/privilege/PMP.scala

```scala
object PMP{
  def apply(
    cmm_mmu: Info_cmm_mmu,
    chk_addr: UInt,
    chk_type: UInt
  )(implicit p: Parameters) = {
    val mdl = Module( new PMP )
    mdl.io.cmm_mmu  := cmm_mmu
    mdl.io.chk_addr := chk_addr
    mdl.io.chk_type := chk_type

    mdl.io.is_fault
  }

}
```

## Documentation

### src/priv/supervisor.adoc

```text
The supervisor memory-management fence instruction SFENCE.VMA is used to
synchronize updates to in-memory memory-management data structures with
current execution. Instruction execution causes implicit reads and
writes to these data structures; however, these implicit references are
ordinarily not ordered with respect to explicit loads and stores.
[#norm:sfence_vma_ordering]#Executing an SFENCE.VMA instruction guarantees that any previous stores
already visible to the current RISC-V hart are ordered before certain
implicit references by subsequent instructions in that hart to the
memory-management data structures. The specific set of operations
ordered by SFENCE.VMA is determined by _rs1_ and _rs2_, as described
below.# [#norm:sfence_vma_invalidation]#SFENCE.VMA is also used to invalidate entries in the
address-translation cache associated with a hart (see <<sv32algorithm>>).# Further details on the behavior of this instruction are described in <<virt-control>> and <<pmp-vmem>>.

[NOTE]
====
The SFENCE.VMA is used to flush any local hardware caches related to
address translation. It is specified as a fence rather than a TLB flush
to provide cleaner semantics with respect to which instructions are
affected by the flush operation and to support a wider variety of
dynamic caching structures and memory-management schemes. SFENCE.VMA is
also used by higher privilege levels to synchronize page table writes
and the address translation hardware.
====
...
==== Virtual Address Translation Process

A virtual address _va_ is translated into a physical address _pa_ as follows:

. Let _a_ be ``satp``.__ppn__×PAGESIZE, and let __i__=LEVELS-1. (For Sv32, PAGESIZE=2^12^ and LEVELS=2.) The `satp` register must be
_active_, i.e., the effective privilege mode must be S-mode or U-mode.

. Let _pte_ be the value of the PTE at address __a__+__va__.__vpn__[__i__]×PTESIZE. (For Sv32, PTESIZE=4.)  If accessing _pte_ violates a PMA or PMP check, raise an access-fault exception corresponding to the original access type.

. If _pte_._v_=0, or if _pte_._r_=0 and _pte_._w_=1, or if any bits or encodings that are reserved for future standard use are set within _pte_, stop and raise a page-fault exception corresponding to the original access type.

. Otherwise, the PTE is valid. If __pte__.__r__=1 or __pte__.__x__=1, go to step 5. Otherwise, this PTE is a pointer to the next level of the page table. Let __i=i__-1. If __i__<0, stop and raise a page-fault exception corresponding to the original access type. Otherwise, let
__a__=__pte__.__ppn__×PAGESIZE and go to step 2.

. A leaf PTE has been reached. If _i>0_ and _pte_._ppn_[__i__-1:0] ≠ 0, this is a misaligned superpage; stop and raise a page-fault exception corresponding to the original access type.

. Determine if the requested memory access is allowed by the _pte_._u_ bit, given the current privilege mode and the value of the SUM and MXR fields of the *mstatus* register. If not, stop and raise a page-fault exception corresponding to the original access type.

. Determine if the requested memory access is allowed by the _pte_._r_, _pte_._w_, and _pte_._x_ bits, given the Shadow Stack Memory Protection rules. If not, stop and raise an access-fault exception.

. Determine if the requested memory access is allowed by the _pte_._r_, _pte_._w_, and _pte_._x_ bits. If not, stop and raise a page-fault exception corresponding to the original access type.

. If _pte_._a_=0, or if the original memory access is a store and _pte_._d_=0:

* If the Svade extension is implemented, stop and raise a page-fault exception corresponding to the original access type.
* If a store to the PTE at address __a__+__va.vpn__[__i__]×PTESIZE would violate a PMA or PMP check,
raise an access-fault exception corresponding to the original access
type.
* Perform the following steps atomically:
** Compare _pte_ to the value of the PTE at address __a__+__va.vpn__[__i__]×PTESIZE.
** If the values match, set _pte_._a_ to 1 and, if the
original memory access is a store, also set _pte_._d_ to 1. Then store _pte_ to the PTE at address __a__+__va.vpn__[__i__]×PTESIZE.
** If the comparison fails, return to step 2.

. The translation is successful. The translated physical address is
given as follows:
* _pa.pgoff_ = _va.pgoff_.
* If _i_>0, then this is a superpage translation and __pa.ppn__[__i__-1:0] = __va.vpn__[__i__-1:0].
* _pa.ppn_[LEVELS-1:__i__] = _pte_._ppn_[LEVELS-1:__i__].

All implicit accesses to the address-translation data structures in this
algorithm are performed using width PTESIZE.
...
==== Addressing and Memory Protection

Sv39 implementations support a 39-bit virtual address space, divided
into 4 KiB pages. An Sv39 address is partitioned as shown in
<<sv39va>>. Instruction fetch addresses and load and
store effective addresses, which are 64 bits,
[#norm:Sv39_va_signext]#must have bits 63–39 all equal to bit 38, or else
a page-fault exception will occur#.
The [#norm:Sv39_vpn_sz]#27-bit VPN# is translated into a
[#norm:satp_ppn_sv39_sz]#44-bit PPN# via a
[#norm:Sv39_levels]#three-level page table#, while the
[#norm:Sv39_page_offset_sz]#12-bit page offset is untranslated#.

[NOTE]
====
When mapping between narrower and wider addresses, RISC-V zero-extends a
narrower physical address to a wider size. The mapping between 64-bit
virtual addresses and the 39-bit usable address space of Sv39 is not
based on zero extension but instead follows an entrenched convention
that allows an OS to use one or a few of the most-significant bits of a
full-size (64-bit) virtual address to quickly distinguish user and
supervisor address regions.
====

[[sv39va]]
.Sv39 virtual address.
include::images/bytefield/sv39va.edn[]

[[sv39pa]]
.Sv39 physical address.
include::images/bytefield/sv39pa.edn[]

[[sv39pte]]
.Sv39 page table entry.
include::images/bytefield/sv39pte.edn[]

Sv39 page tables contain [#norm:Sv39_pte_count]#2^9^ page table entries
(PTEs)#, [#norm:Sv39_pte_sz]#eight bytes each#.
A page table is [#norm:Sv39_pt_sz]#exactly the size of a page# and
[#norm:Sv39_pt_align]#must always be aligned to a page boundary#.
The physical page number of the root page table is stored in the `satp`
register's PPN field.

The PTE format for Sv39 is shown in <<sv39pte>>.
Bits 9-0 have the same meaning as for Sv32.
Bit 63 is reserved for use by the extlink:svnapot[] extension.
[#norm:Sv39_pte_svnapot_rsv]#If Svnapot is not implemented, bit 63 remains
reserved and must be zeroed by software for forward compatibility, or
else a page-fault exception is raised#.
Bits 62-61 are reserved for use by the extlink:svpbmt[] extension.
[#norm:Sv39_pte_svpbmt_rsv]#If Svpbmt is not implemented, bits 62-61 remain
reserved and must be zeroed by software for forward compatibility, or
else a page-fault exception is raised#.
Bits 60-54 are reserved for future standard use and, until their use is
defined by some standard extension,
[#norm:Sv39_pte_future_rsv]#must be zeroed by software for forward
compatibility. If any of these bits are set, a page-fault exception is
raised#.

[NOTE]
====
We reserved several PTE bits for a possible extension that improves
support for sparse address spaces by allowing page-table levels to be
skipped, reducing memory usage and TLB refill latency. These reserved
bits may also be used to facilitate research experimentation. The cost
is reducing the physical address space, but 56 bits is presently ample. When it
no longer suffices, the reserved bits that remain unallocated could be
used to expand the physical address space.
====

[#norm:Sv39_leaf_any_level]#Any level of PTE may be a leaf PTE#, so in
addition to 4 KiB pages, Sv39 supports
[#norm:Sv39_page_sizes]#2 MiB megapages and 1 GiB gigapages#, each of
which [#norm:Sv39_superpage_align]#must be virtually and physically
aligned to a boundary equal to its size#.
[#norm:Sv39_superpage_align_fault]#A page-fault exception is raised if
the physical address is insufficiently aligned#.

The algorithm for virtual-to-physical address translation is the same as
in <<sv32algorithm>>, except
[#norm:Sv39_LEVELS]#LEVELS equals 3# and
[#norm:Sv39_PTESIZE]#PTESIZE equals 8#.
```
