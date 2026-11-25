# Implement `TLB`

Implement the complete `TLB` class. Preserve the class name and interface shown below.

Return only the complete `class TLB` definition in a single Scala code block, with no text outside the block.

## Class declaration

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

## Parent instantiation

### src/main/scala/rift2Core/privilege/MMU.scala

```scala
  val itlb = Module( new TLB )
  val dtlb = Module( new TLB )
  val iptw  = Module( new PTW(edge, id = 0) )
  val dptw  = Module( new PTW(edge, id = 1) )

  val is_bypass_if = io.cmm_mmu.satp(63,60) === 0.U | io.cmm_mmu.priv_lvl_if === "b11".U
  val is_bypass_ls = io.cmm_mmu.satp(63,60) === 0.U | io.cmm_mmu.priv_lvl_ls === "b11".U
// ...
  itlb.io.req.valid := io.if_mmu.valid
  itlb.io.req.bits  := io.if_mmu.bits
  itlb.io.asid_i  := io.cmm_mmu.satp(59,44)
// ...
  dtlb.io.req.valid := io.lsu_mmu.valid
  dtlb.io.req.bits  := io.lsu_mmu.bits
  dtlb.io.asid_i  := io.cmm_mmu.satp(59,44)
// ...
  iptw.io.ptw_i.valid := io.if_mmu.valid & ~itlb.io.is_hit & ~is_bypass_if & ~kill_iptw
  iptw.io.ptw_i.bits  := io.if_mmu.bits

  dptw.io.ptw_i.valid := io.lsu_mmu.valid & ~dtlb.io.is_hit & ~is_bypass_ls & ~kill_dptw
  dptw.io.ptw_i.bits  := io.lsu_mmu.bits
// ...
    val pte = Mux( itlb.io.is_hit, itlb.io.pte_o, iptw.io.ptw_o.bits.renew.viewAsSupertype(new Info_pte_sv39) )
    val ivaddr = io.if_mmu.bits.vaddr
    val ipaddr = Mux( is_bypass_if, ivaddr, v2paddr( ivaddr, pte ) )
// ...
    val pte = Mux( dtlb.io.is_hit, dtlb.io.pte_o, dptw.io.ptw_o.bits.renew.viewAsSupertype(new Info_pte_sv39) )
    val dvaddr = io.lsu_mmu.bits.vaddr

    val dpaddr = Mux( is_bypass_ls, dvaddr, v2paddr( dvaddr, pte ) )
// ...
  itlb.io.tlb_renew.bits := iptw.io.ptw_o.bits.renew
  dtlb.io.tlb_renew.bits := dptw.io.ptw_o.bits.renew

  itlb.io.tlb_renew.valid := iptw.io.ptw_o.fire &  iptw.io.ptw_o.bits.is_X & ~iptw.io.ptw_o.bits.is_ptw_fail & ~kill_iptw
  dtlb.io.tlb_renew.valid := dptw.io.ptw_o.fire & ~dptw.io.ptw_o.bits.is_X & ~dptw.io.ptw_o.bits.is_ptw_fail & ~kill_dptw
// ...
  itlb.io.sfence_vma := io.cmm_mmu.sfence_vma
  dtlb.io.sfence_vma := io.cmm_mmu.sfence_vma
// ...
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
```

## Related source code

### src/main/scala/rift2Core/privilege/PTW.scala

```scala
    is( PTWState.Lvl0.U ) {
      nextState :=
        Mux(
          (is_trans_done) | is_hit,
          Mux( is_ptw_end | is_ptw_fail | kill_trans, PTWState.Free.U, PTWState.Free.U ),
          PTWState.Lvl0.U
        )
    }
// ...
  is_ptw_end := 
    pte.R === true.B & 
    pte.X === true.B
// ...
  pte.is_4K_page   := is_ptw_end & currState === PTWState.Lvl0.U
  pte.is_mega_page := is_ptw_end & currState === PTWState.Lvl1.U      
  pte.is_giga_page := is_ptw_end & currState === PTWState.Lvl2.U
// ...
    walkRspBits.renew.viewAsSupertype(new Info_pte_sv39) := pte
    walkRspBits.renew.vpn(0) := walkReq.vaddr(20,12)
    walkRspBits.renew.vpn(1) := walkReq.vaddr(29,21)
    walkRspBits.renew.vpn(2) := walkReq.vaddr(38,30)
    walkRspBits.renew.asid   := asidReq
```

## Documentation

### src/priv/supervisor.adoc

```text
* [#norm:sfence_vma_all_asid_va]#If __rs1__=`x0` and __rs2__=`x0`, the fence orders all reads and writes
made to any level of the page tables, for all address spaces. The fence
also invalidates all address-translation cache entries, for all address
spaces.#
...
The [#norm:Sv39_vpn_sz]#27-bit VPN# is translated into a
[#norm:satp_ppn_sv39_sz]#44-bit PPN# via a
[#norm:Sv39_levels]#three-level page table#, while the
[#norm:Sv39_page_offset_sz]#12-bit page offset is untranslated#.
...
[#norm:Sv39_leaf_any_level]#Any level of PTE may be a leaf PTE#, so in
addition to 4 KiB pages, Sv39 supports
[#norm:Sv39_page_sizes]#2 MiB megapages and 1 GiB gigapages#, each of
which [#norm:Sv39_superpage_align]#must be virtually and physically
aligned to a boundary equal to its size#.
```
