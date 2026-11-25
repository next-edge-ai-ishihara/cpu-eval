# Implement `MMU`

Implement the complete `MMU` class. Preserve the class name and interface shown below.

Return only the complete `class MMU` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class MMU(edge: TLEdgeOut)(implicit p: Parameters) extends RiftModule {

  class MMUIO extends Bundle{
    val if_mmu = Flipped(DecoupledIO(new Info_mmu_req))
    val mmu_if = DecoupledIO(new Info_mmu_rsp)
    val if_flush = Input(Bool())

    val lsu_mmu = Flipped(DecoupledIO(new Info_mmu_req))
    val mmu_lsu = DecoupledIO(new Info_mmu_rsp)
    val lsu_flush = Input(Bool())

    val cmm_mmu = Input( new Info_cmm_mmu )

    val ptw_get    = new DecoupledIO(new TLBundleA(edge.bundle))
    val ptw_access = Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))
  }

  val io: MMUIO = IO(new MMUIO)

```

## Parent instantiation

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val mmuClientParameters = TLMasterPortParameters.v1(
    Seq(TLMasterParameters.v1(
      name = "mmu",
      sourceId = IdRange(0, 2),
    ))
  )
// ...
  val (    mmu_bus,    mmu_edge ) = outer.mmuClientNode.out.head
// ...
  val i_mmu = Module(new MMU(edge = mmu_edge ))
// ...
  mmu_bus.a.valid := i_mmu.io.ptw_get.valid
  mmu_bus.a.bits := i_mmu.io.ptw_get.bits
  i_mmu.io.ptw_get.ready := mmu_bus.a.ready
  mmu_bus.d.ready := i_mmu.io.ptw_access.ready
  i_mmu.io.ptw_access.bits  := mmu_bus.d.bits
  i_mmu.io.ptw_access.valid := mmu_bus.d.valid
// ...
  i_mmu.io.if_mmu <> if2.io.if_mmu
  i_mmu.io.mmu_if <> if2.io.mmu_if
  i_mmu.io.lsu_mmu <> exe_stage.io.lsu_mmu
  i_mmu.io.mmu_lsu <> exe_stage.io.mmu_lsu
  i_mmu.io.cmm_mmu <> cmm_stage.io.cmm_mmu
// ...
  i_mmu.io.if_flush  := cmm_stage.io.cmmRedirect.fire | if4.io.if4Redirect.valid
  i_mmu.io.lsu_flush := cmm_stage.io.cmmRedirect.fire

```

## Dependency declarations

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



class Info_mmu_rsp(implicit p: Parameters) extends RiftBundle {
  val vaddr  = UInt(64.W)
  val paddr  = UInt(64.W)
  val is_paging_fault = Bool()
  val is_access_fault = Bool()

  def is_fault = is_access_fault | is_paging_fault
}


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

### src/main/scala/rift2Core/privilege/TLB.scala

```scala
class TLB()(implicit p: Parameters) extends RiftModule {

  class TLBIO extends Bundle{
    val req = Flipped(ValidIO( new Info_mmu_req ))
    val pte_o = Output(new Info_pte_sv39)
    val is_hit = Output(Bool())

    val asid_i = Input(UInt(16.W))

    val tlb_renew = Flipped(ValidIO(new TLB_Renew_Bundle))

    val sfence_vma = Input(Bool())    
  }

  val io: TLBIO = IO(new TLBIO)

```

### src/main/scala/rift2Core/privilege/PTW.scala

```scala
class Info_ptw_rsp extends Bundle with Info_access_lvl{
  val renew = new TLB_Renew_Bundle
  val is_ptw_fail = Bool()
  val is_access_fault = Bool()

}
// ...
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
// ...
class PTW(edge: TLEdgeOut, id: Int)(implicit p: Parameters) extends PTWBase(edge, id) 

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

## Related source code

### src/main/scala/rift2Core/frontend/IF2.scala

```scala
trait IF2MMU { this: IF2Base =>
  io.if_mmu.valid := io.if2_req.valid
  io.if_mmu.bits.vaddr := io.if2_req.bits.pc
  io.if_mmu.bits.is_R := true.B
  io.if_mmu.bits.is_W := false.B
  io.if_mmu.bits.is_X := true.B
  io.if2_req.ready := io.if_mmu.ready

  io.mmu_if.ready := ibuf.io.enq(0).fire & ~fault_lock & ~io.mmu_if.bits.is_fault
}

```

### src/main/scala/rift2Core/backend/LSU/Lsu.scala

```scala
  io.mmu_lsu.ready :=
    ( addrTransIO.ready & ~io.mmu_lsu.bits.is_fault & ~io.lsu_iss_exe.bits.is_misAlign & ~(trans_kill | io.lsu_iss_exe.bits.fun.is_fence) ) |
    ( irtn_arb.io.in(3).fire ) |
    ( frtn_arb.io.in(1).fire ) |
    ( vrtn_arb.io.in(1).fire )
// ...
  io.lsu_mmu.valid := io.lsu_iss_exe.valid & ~io.lsu_iss_exe.bits.fun.is_fence
  io.lsu_mmu.bits.vaddr := io.lsu_iss_exe.bits.param.dat.op1
  io.lsu_mmu.bits.is_R := io.lsu_iss_exe.bits.fun.is_R
  io.lsu_mmu.bits.is_W := io.lsu_iss_exe.bits.fun.is_W
  io.lsu_mmu.bits.is_X := false.B

```

## Documentation

### src/priv/supervisor.adoc

```text
[NOTE]
====
Storing a PPN in `satp`, rather than a physical address, supports a
physical address space larger than 4 GiB for RV32.

The `satp`.PPN field might not be capable of holding all physical page
numbers. Some platform standards might place constraints on the values
`satp`.PPN may assume, e.g., by requiring that all physical page numbers
corresponding to main memory be representable.
====

[[rv64satp]]
.Supervisor address translation and protection (`satp`) register when SXLEN=64, for MODE values Bare, Sv39, Sv48, and Sv57.
include::images/bytefield/rv64satp.edn[]

[NOTE]
====
We store the ASID and the page table base address in the same CSR to
allow the pair to be changed atomically on a context switch. Swapping
them non-atomically could pollute the old virtual address space with new
translations, or vice-versa. This approach also slightly reduces the
cost of a context switch.
====

[[norm:satp_mode]]
<<satp_mode>> shows the encodings of the MODE field when
SXLEN=32 and SXLEN=64. When MODE=Bare, supervisor virtual addresses are
equal to supervisor physical addresses, and there is no additional
memory protection beyond the physical memory protection scheme described
in <<pmp>>. To select MODE=Bare, software must write
zero to the remaining fields of `satp` (bits 30–0 when SXLEN=32, or bits
59–0 when SXLEN=64). Attempting to select MODE=Bare with a nonzero
pattern in the remaining fields has an UNSPECIFIED effect on the value that the
remaining fields assume and an UNSPECIFIED effect on address translation and
protection behavior.

When SXLEN=32, the `satp` encodings corresponding to MODE=Bare and
ASID[8:7]=3 are designated for custom use, whereas the encodings
corresponding to MODE=Bare and ASID[8:7]≠3 are reserved
for future standard use. When SXLEN=64, all `satp` encodings
corresponding to MODE=Bare are reserved for future standard use.

[NOTE]
====
Version 1.11 of this standard stated that the remaining fields in `satp`
had no effect when MODE=Bare. Making these fields reserved facilitates
future definition of additional translation and protection modes,
particularly in RV32, for which all patterns of the existing MODE field
have already been allocated.
====

[[svbare]]
[#norm:svbare_satp_mode_bare]#If an implementation supports the Svbare extension, then the `satp`
register's MODE field must be capable of holding the value Bare.#

[[norm:satp_mode_sxlen32]]
When SXLEN=32, the only other valid setting for MODE is Sv32, a paged
virtual-memory scheme described in <<sv32>>.

[[norm:satp_mode_sxlen64]]
When SXLEN=64, three paged virtual-memory schemes are defined: Sv39,
Sv48, and Sv57, described in <<sv39>>, <<sv48>>,
and <<sv57>>, respectively. One additional scheme, Sv64, will be
defined in a later version of this specification. The remaining MODE
settings are reserved for future use and may define different
interpretations of the other fields in `satp`.

[[norm:satp_mode_op_unsupported]]
Implementations are not required to support all MODE settings, and if
`satp` is written with an unsupported MODE, the entire write has no
effect; no fields in `satp` are modified.

[[norm:asidlen]]
The number of ASID bits is UNSPECIFIED and may be zero. The number of implemented
ASID bits, termed _ASIDLEN_, may be determined by writing one to every
bit position in the ASID field, then reading back the value in `satp` to
see which bit positions in the ASID field hold a one. The
least-significant bits of ASID are implemented first: that is, if
ASIDLEN > 0, ASID[ASIDLEN-1:0] is writable. The maximal
value of ASIDLEN, termed ASIDMAX, is 9 for Sv32 or 16 for Sv39, Sv48,
and Sv57.

<<<

[[satp_mode]]
.Encoding of `satp` MODE field.
[%autowidth,float="center",align="center",cols="^,^,<",options="header"]
|===
3+|SXLEN=32
|Value |Name |Description

|0 |Bare |No translation or protection.
|1 |Sv32 |Page-based 32-bit virtual addressing (see <<sv32>>).

3+|*SXLEN=64*
|Value |Name |Description

|0    |Bare |No translation or protection.
|1-7  |-    |_Reserved for standard use_
|8    |Sv39 |Page-based 39-bit virtual addressing (see <<sv39>>).
|9    |Sv48 |Page-based 48-bit virtual addressing (see <<sv48>>).
|10   |Sv57 |Page-based 57-bit virtual addressing (see <<sv57>>).
|11   |Sv64 |_Reserved for page-based 64-bit virtual addressing._
|12-13|-    |_Reserved for standard use_
|14-15|-    |_Designated for custom use_
|===

```

```text
[[sv32algorithm]]
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

[NOTE]
====
This implies, for example, that an Sv48 implementation may not use two
separate 4{nbsp}B reads to non-atomically access a single 8{nbsp}B PTE, and that A/D
bit updates performed by the implementation are treated as atomically
updating the entire PTE, rather than just the A and/or D bit alone (even
though the PTE value does not otherwise change).
====

The results of implicit address-translation reads in step 2 may be held
in a read-only, incoherent _address-translation cache_ but not shared
with other harts. The address-translation cache may hold an arbitrary
number of entries, including an arbitrary number of entries for the same
address and ASID. Entries in the address-translation cache may then
satisfy subsequent step 2 reads if the ASID associated with the entry
matches the ASID loaded in step 1 or if the entry is associated with a
_global_ mapping. To ensure that implicit reads observe writes to the
same memory locations, an SFENCE.VMA instruction must be executed after
the writes to flush the relevant cached translations.

The address-translation cache cannot be used in step 9; accessed and
dirty bits may only be updated in memory directly.
[NOTE]
====
It is permitted for multiple address-translation cache entries to
co-exist for the same address. This represents the fact that in a
conventional TLB hierarchy, it is possible for multiple entries to match
a single address if, for example, a page is upgraded to a superpage
without first clearing the original non-leaf PTE’s valid bit and
executing an SFENCE.VMA with _rs1_=`x0`, or if multiple TLBs exist in
parallel at a given level of the hierarchy. In this case, just as if an
SFENCE.VMA is not executed between a write to the memory-management
tables and subsequent implicit read of the same address: it is
unpredictable whether the old non-leaf PTE or the new leaf PTE is used,
but the behavior is otherwise well defined.
====

Implementations may also execute the address-translation algorithm
speculatively at any time, for any virtual address, as long as `satp` is
active (as defined in <<satp>>). Such speculative
executions have the effect of pre-populating the address-translation
cache.

Speculative executions of the address-translation algorithm behave as
non-speculative executions of the algorithm do, except that they must
not set the dirty bit for a PTE, they must not trigger an exception, and
they must not create address-translation cache entries if those entries
would have been invalidated by any SFENCE.VMA instruction executed by
the hart since the speculative execution of the algorithm began.

[NOTE]
====
For instance, it is illegal for both non-speculative and speculative
executions of the translation algorithm to begin, read the level 2 page
table, pause while the hart executes an SFENCE.VMA with
_rs1_=_rs2_=`x0`, then resume using the now-stale level 2 PTE, as
subsequent implicit reads could populate the address-translation cache
with stale PTEs.

In many implementations, an SFENCE.VMA instruction with _rs1_=`x0` will
therefore either terminate all previously-launched speculative
executions of the address-translation algorithm (for the specified ASID,
if applicable), or simply wait for them to complete (in which case any
address-translation cache entries created will be invalidated by the
SFENCE.VMA as appropriate). Likewise, an SFENCE.VMA instruction with
__rs1__≠``x0`` generally must either ensure that
previously-launched speculative executions of the address-translation
algorithm (for the specified ASID, if applicable) are prevented from
creating new address-translation cache entries mapping leaf PTEs, or
wait for them to complete.

A consequence of implementations being permitted to read the translation
data structures arbitrarily early and speculatively is that at any time,
all page table entries reachable by executing the algorithm may be
loaded into the address-translation cache.

Although it would be uncommon to place page tables in non-idempotent
memory, there is no explicit prohibition against doing so. Since the
algorithm may only touch page tables reachable from the root page table
indicated in `satp`, the range of addresses that an implementation's
page-table walker will touch is fully under supervisor control.

***

The algorithm does not admit the possibility of ignoring high-order PPN
bits for implementations with narrower physical addresses.
====

```

```text
=== Sv39: Page-Based 39-bit Virtual-Memory System

This section describes a [#norm:Sv39_sxlen]#simple paged virtual-memory system for
SXLEN=64#, which [#norm:Sv39_va_sz]#supports 39-bit virtual address spaces#. The design of
Sv39 follows the overall scheme of Sv32, and this section details only
the differences between the schemes.

[NOTE]
====
We specified multiple virtual memory systems for RV64 to relieve the
tension between providing a large address space and minimizing
address-translation cost. For many systems, 39 bits of virtual-address space is
ample, and so Sv39 suffices. Sv48 increases the virtual address space to
48 bits, but increases the physical memory capacity dedicated to page tables,
the latency of page-table traversals, and the size of hardware
structures that store virtual addresses. Sv57 increases the virtual
address space, page table capacity requirement, and translation latency
even further.
====

[[addressing-and-memory-protection]]
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

### src/priv/images/bytefield/rv64satp.edn

```clojure
[bytefield]
----
(defattrs :plain [:plain {:font-family "M+ 1p Fallback" :font-size 24}])
(def row-height 40 )
(def row-header-fn nil)
(def left-margin 30)
(def right-margin 30)
(def boxes-per-row 32)

(draw-box "63" {:span 5 :text-anchor "start" :borders {}})
(draw-box "60" {:span 5 :text-anchor "end" :borders {}})
(draw-box "59" {:span 5 :text-anchor "start" :borders {}})
(draw-box "44" {:span 5 :text-anchor "end" :borders {}})
(draw-box "43" {:span 6 :text-anchor "start" :borders {}})
(draw-box "0" {:span 6 :text-anchor "end" :borders {}})

(draw-box "MODE" {:span 5 :text-anchor "end" :borders {:top :border-unrelated :bottom :border-unrelated :left :border-unrelated}})
(draw-box (text "(WARL)" {:font-weight "bold" :font-size 24}) {:span 5 :text-anchor "start" :borders {:top :border-unrelated :bottom :border-unrelated :right :border-unrelated}})
(draw-box "ASID" {:span 5 :text-anchor "end" :borders {:top :border-unrelated :bottom :border-unrelated :left :border-unrelated}})
(draw-box (text "(WARL)" {:font-weight "bold" :font-size 24}) {:span 5 :text-anchor "start" :borders {:top :border-unrelated :bottom :border-unrelated :right :border-unrelated}})
(draw-box "PPN" {:span 6 :text-anchor "end" :borders {:top :border-unrelated :bottom :border-unrelated :left :border-unrelated}})
(draw-box (text "(WARL)" {:font-weight "bold" :font-size 24}) {:span 6 :text-anchor "start" :borders {:top :border-unrelated :bottom :border-unrelated :right :border-unrelated}})

(draw-box "4" {:span 10 :borders {}})
(draw-box "16" {:span 10 :borders {}})
(draw-box "44" {:span 12 :borders {}})
----

```
