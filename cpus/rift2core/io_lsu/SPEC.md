# Implement `IO_Lsu`

Implement the complete `IO_Lsu` class. Preserve the class name and interface shown below.

Return only the complete `class IO_Lsu` definition in a single Scala code block, with no text outside the block.

## Class declaration

```scala
class IO_Lsu(edge: TLEdgeOut)(implicit p: Parameters) extends RiftModule{

  class IOLSUIO extends Bundle{
    val enq = Flipped(new DecoupledIO(new Lsu_iss_info))
    val deq = new DecoupledIO(new Dcache_Deq_Bundle)
    val is_empty = Output(Bool())

    val getPut    = new DecoupledIO(new TLBundleA(edge.bundle))
    val access = Flipped(new DecoupledIO(new TLBundleD(edge.bundle)))

    // val flush = Input(Bool())    
  }
  val io: IOLSUIO = IO(new IOLSUIO)

```

## Parent instantiation

### src/main/scala/rift2Core/backend/LSU/Lsu.scala

```scala
  val system = Module(new IO_Lsu(dEdge(2)))
  val periph = Module(new IO_Lsu(dEdge(1)))
// ...
  system.io.enq.valid  := regionSystemIO.valid
  system.io.enq.bits   := regionSystemIO.bits
  regionSystemIO.ready := system.io.enq.ready

  io.system_getPut.valid := system.io.getPut.valid
  io.system_getPut.bits  := system.io.getPut.bits
  system.io.getPut.ready := io.system_getPut.ready
  system.io.access.valid := io.system_access.valid
  system.io.access.bits  := io.system_access.bits
  io.system_access.ready := system.io.access.ready

  periph.io.enq.valid  := regionPeriphIO.valid
  periph.io.enq.bits   := regionPeriphIO.bits
  regionPeriphIO.ready := periph.io.enq.ready

  io.periph_getPut.valid := periph.io.getPut.valid
  io.periph_getPut.bits  := periph.io.getPut.bits
  periph.io.getPut.ready := io.periph_getPut.ready
  periph.io.access.valid := io.periph_access.valid
  periph.io.access.bits  := io.periph_access.bits
  io.periph_access.ready := periph.io.access.ready
// ...
  lu_wb_arb.io.in(bk).valid := system.io.deq.valid & system.io.deq.bits.is_load_amo
  lu_wb_arb.io.in(bk).bits := Mux( lu_wb_arb.io.in(bk).valid, system.io.deq.bits, 0.U.asTypeOf(new Dcache_Deq_Bundle) )
  system.io.deq.ready := lu_wb_arb.io.in(bk).ready | ~system.io.deq.bits.is_load_amo
  when( system.io.deq.bits.is_load_amo ) { assert(system.io.deq.fire === lu_wb_arb.io.in(bk).fire) }

  lu_wb_arb.io.in(bk+1).valid := periph.io.deq.valid & periph.io.deq.bits.is_load_amo
  lu_wb_arb.io.in(bk+1).bits := Mux( lu_wb_arb.io.in(bk+1).valid, periph.io.deq.bits, 0.U.asTypeOf(new Dcache_Deq_Bundle) )
  periph.io.deq.ready := lu_wb_arb.io.in(bk+1).ready | ~periph.io.deq.bits.is_load_amo
  when( periph.io.deq.bits.is_load_amo ) { assert(periph.io.deq.fire === lu_wb_arb.io.in(bk+1).fire) }

```

## Dependency declarations

### src/main/scala/rift2Core/define/riscv_isa.scala

```scala
class Lsu_isa extends Bundle {
  val lb  = Bool()
  val lh  = Bool()
  val lw  = Bool()
  val ld  = Bool()
  val lbu = Bool()
  val lhu = Bool()
  val lwu = Bool()
  val sb  = Bool()
  val sh  = Bool()
  val sw  = Bool()
  val sd  = Bool()
  val fence = Bool()
  val fence_i = Bool()
  val sfence_vma = Bool()

  val lr_w      = Bool()
  val sc_w      = Bool()
  val amoswap_w = Bool()
  val amoadd_w  = Bool()
  val amoxor_w  = Bool()
  val amoand_w  = Bool()
  val amoor_w   = Bool()
  val amomin_w  = Bool()
  val amomax_w  = Bool()
  val amominu_w = Bool()
  val amomaxu_w = Bool()
  val lr_d      = Bool()
  val sc_d      = Bool()
  val amoswap_d = Bool()
  val amoadd_d  = Bool()
  val amoxor_d  = Bool()
  val amoand_d  = Bool()
  val amoor_d   = Bool()
  val amomin_d  = Bool()
  val amomax_d  = Bool()
  val amominu_d = Bool()
  val amomaxu_d = Bool()

  val flw = Bool()
  val fsw = Bool()
  val fld = Bool()
  val fsd = Bool()


  val vle8  = Bool()
  val vle16 = Bool()
  val vle32 = Bool()
  val vle64 = Bool()
  def vle   = vle8 | vle16 | vle32 | vle64

  val vse8  = Bool()
  val vse16 = Bool()
  val vse32 = Bool()
  val vse64 = Bool()
  def vse   = vse8 | vse16 | vse32 | vse64

  val vlm      = Bool()
  val vsm      = Bool()

  val vlse8  = Bool()
  val vlse16 = Bool()
  val vlse32 = Bool()
  val vlse64 = Bool()
  def vlse   = vlse8 | vlse16 | vlse32 | vlse64

  val vsse8  = Bool()
  val vsse16 = Bool()
  val vsse32 = Bool()
  val vsse64 = Bool()
  def vsse   = vsse8 | vsse16 | vsse32 | vsse64

  val vloxei8  = Bool()
  val vloxei16 = Bool()
  val vloxei32 = Bool()
  val vloxei64 = Bool()
  def vloxei   = vloxei8 | vloxei16 | vloxei32 | vloxei64

  val vsoxei8  = Bool()
  val vsoxei16 = Bool()
  val vsoxei32 = Bool()
  val vsoxei64 = Bool()
  def vsoxei   = vsoxei8 | vsoxei16 | vsoxei32 | vsoxei64

  val vlre8  = Bool()
  val vlre16 = Bool()
  val vlre32 = Bool()
  val vlre64 = Bool()
  def vlre   = vlre8 | vlre16 | vlre32 | vlre64

  val vsr    = Bool()

  val vle8ff  = Bool()
  val vle16ff = Bool()
  val vle32ff = Bool()
  val vle64ff = Bool()
  def vleNff  = vle8ff | vle16ff | vle32ff | vle64ff

  def is_sc = sc_d | sc_w
  def is_lr = lr_d | lr_w

  def is_lu  =
    lb | lh | lw | ld | lbu | lhu | lwu | flw | fld | is_lr |
    vle | vlm | vlse | vloxei | vlre | vleNff

  def is_su  =
    sb | sh | sw | sd | fsw | fsd |
    vse | vsm | vsse | vsoxei | vsr

  def is_xls = lb | lh | lw | ld | lbu | lhu | lwu | sb | sh | sw | sd
  def is_lrsc = is_sc | is_lr
  def is_amo =
    amoswap_w | amoadd_w | amoxor_w | amoand_w | amoor_w | amomin_w | amomax_w | amominu_w | amomaxu_w | amoswap_d | amoadd_d | amoxor_d | amoand_d | amoor_d | amomin_d | amomax_d | amominu_d | amomaxu_d 
  def is_fls = flw | fsw | fld | fsd

  def is_vls = vle | vse | vlm | vsm | vlse | vsse | vloxei | vsoxei | vlre | vsr | vleNff


  def is_fence = fence | fence_i | sfence_vma
  def is_lsu = is_xls | is_lrsc | is_amo | is_fls | is_fence | is_vls


  def isByte =
    lb | lbu | sb |
    vle8 | vse8 | vlse8 | vsse8 |  vlre8 | vle8ff |
    vlm | vsm

  def isHalf =
    lh | lhu | sh |
    vle16 | vse16 | vlse16 | vsse16 | vlre16 | vle16ff

  def isWord =
    lw | lwu | sw | amoswap_w | amoadd_w | amoxor_w | amoand_w | amoor_w | amomin_w | amomax_w | amominu_w | amomaxu_w | flw | fsw | lr_w | sc_w |
    vle32 | vse32 | vlse32 | vsse32 | vlre32 | vle32ff
  
  def isDubl =
    ld | lr_d | fld | sd | sc_d | fsd | amoswap_d | amoadd_d | amoxor_d | amoand_d | amoor_d | amomin_d | amomax_d | amominu_d | amomaxu_d |
    vle64 | vse64 | vlse64 | vsse64 | vlre64 | vle64ff |
    vsr

  def isDynamic = vloxei | vsoxei

  def is_usi = lbu | lhu | lwu


  def is_R = is_lu | is_lr | is_amo
  def is_W = is_su | is_sc | is_amo

  def isXLoad  = lb | lh | lw | ld | lbu | lhu | lwu | is_lr
  def isXStore = sb | sh | sw | sd | is_sc

  def isFLoad  = flw | fld
  def isFStore = fsw | fsd

  def isVLoad  = vle | vlm | vlse | vloxei | vlre | vleNff
  def isVStore = vse | vsm | vsse | vsoxei | vsr
  def isVConstant = vlse | vsse
  def isVIndex = vloxei | vsoxei

  def isRS1 = is_xls | is_lrsc | is_amo | is_fence | is_fls | is_vls
  def isRS2 = ((is_xls | is_lrsc | is_amo ) & ~is_lu) | sfence_vma | isVConstant
  def isFS2 = isFStore
  def isVS2 = isVIndex
  def isVS3 = isVStore

  def isXwb =
    lb | lh | lw | ld | lbu | lhu | lwu | sb | sh | sw | sd |
    fence | fence_i | sfence_vma | lr_w | sc_w |
    amoswap_w | amoadd_w | amoxor_w | amoand_w | amoor_w | amomin_w | amomax_w | amominu_w | amomaxu_w |
    lr_d | sc_d | amoswap_d | amoadd_d | amoxor_d | amoand_d | amoor_d | amomin_d | amomax_d | amominu_d | amomaxu_d |
    fsw | fsd



  def isFwb = flw | fld

  def isVwb = is_vls

  def isUnitStride = vle | vse | vlm | vsm | vlre | vsr | vleNff
  def isStridde = vlse | vsse
  def isIndex = vloxei | vsoxei

  def is_fpu = flw | fsw | fld | fsd
  def isVector = is_vls

}
// ...
class RD_PHY(implicit p: Parameters) extends RiftBundle {
  val rd0 = UInt((log2Ceil(maxRegNum)).W)
}

class Operation_source(dw: Int)(implicit p: Parameters) extends RiftBundle {
  val op0 = UInt(dw.W)
  val op1 = UInt(dw.W)
  val op2 = UInt(dw.W)
  val op3 = UInt(dw.W)
}
// ...
class Lsu_param(implicit p: Parameters) extends RD_PHY {
  val dat    = new Operation_source(dw=64)

  // override def cloneType = ( new Lsu_param ).asInstanceOf[this.type]
}






class Lsu_iss_info(implicit p: Parameters) extends RiftBundle {
  val fun = new Lsu_isa
  val param = new Lsu_param

  val vAttach = if(hasVector){Some(new VLsu_Attach_Bundle)} else {None}

  def is_misAlign =
    Mux1H( Seq(
      fun.isHalf -> (param.dat.op1(0)   =/= 0.U),
      fun.isWord -> (param.dat.op1(1,0) =/= 0.U),
      fun.isDubl -> (param.dat.op1(2,0) =/= 0.U),
    ) ++
      (if(hasVector){
        Seq(fun.isDynamic -> Mux1H(Seq(
          (vAttach.get.vsew === "b001".U) -> (param.dat.op1(0)   =/= 0.U),
          (vAttach.get.vsew === "b010".U) -> (param.dat.op1(1,0) =/= 0.U),
          (vAttach.get.vsew === "b011".U) -> (param.dat.op1(2,0) =/= 0.U),
      )))} else {Seq()}) 
    )

  def paddr = param.dat.op1

  def wdata_align(dw: Int) = {
      val res = Wire(UInt(dw.W))
      res := param.dat.op2 << ( paddr((log2Ceil(dw/8)-1),0) << 3 )
      res
    }

  def wstrb_align(dw: Int) = {
    val wstrb = Wire(UInt((dw/8).W))
    wstrb := Mux1H(Seq(
        fun.isByte -> "b00000001".U, fun.isHalf -> "b00000011".U,
        fun.isWord -> "b00001111".U, fun.isDubl -> "b11111111".U,
      ) ++
        (if(hasVector){
          Seq(fun.isDynamic -> Mux1H(Seq(
            (vAttach.get.vsew === "b000".U) -> "b00000001".U,
            (vAttach.get.vsew === "b001".U) -> "b00000011".U,
            (vAttach.get.vsew === "b010".U) -> "b00001111".U,
            (vAttach.get.vsew === "b011".U) -> "b11111111".U,
        )))} else {Seq()})
      ) << paddr((log2Ceil(dw/8)-1),0)
    wstrb
  }
}
// ...
class WriteBack_info(dw:Int)(implicit p: Parameters) extends RD_PHY {
  val res = UInt(dw.W)
}

```

### src/main/scala/rift2Core/define/defVector.scala

```scala
trait Vec_vType_Bundle{ this: RiftBundle =>
  val vtype   = UInt( 64.W )
  def vsew  = vtype(5,3)
  def vlmul = vtype(2,0)
}
// ...
class VLsu_Attach_Bundle(implicit p: Parameters) extends RiftBundle
with Vec_element_Index
with Vec_vType_Bundle

```

### src/main/scala/rift2Core/backend/LSU/Dcache.scala

```scala
abstract class Dcache_ScoreBoard_Bundle(implicit p: Parameters) extends DcacheBundle {
  val chkIdx = UInt((log2Ceil(sbEntry)).W)
}
// ...
class Dcache_Deq_Bundle(implicit p: Parameters) extends Dcache_ScoreBoard_Bundle {
  val wb = new WriteBack_info(dw=64)
  val is_load_amo = Bool()

  val vAttach = if(hasVector) {Some(new VLsu_Attach_Bundle)} else {None}

  val is_flw = Bool()
  val is_fld = Bool()

  val isXwb = Bool()
  val isFwb = Bool()
  val isVwb = Bool()

}

```

### src/main/scala/rift2Core/backend/LSU/Util.scala

```scala
object get_loadRes{
  def apply( fun: Lsu_isa, vsew: UInt, paddr: UInt, rdata: UInt ) = {
    require( rdata.getWidth == 64 )
    val res = Wire(UInt(64.W))

    def load_byte(is_usi: Bool, rdata: UInt): UInt = Cat( Fill(56, Mux(is_usi, 0.U, rdata(7)) ),  rdata(7,0)  )
    def load_half(is_usi: Bool, rdata: UInt): UInt = Cat( Fill(48, Mux(is_usi, 0.U, rdata(15)) ), rdata(15,0) )
    def load_word(is_usi: Bool, rdata: UInt): UInt = Cat( Fill(32, Mux(is_usi, 0.U, rdata(31)) ), rdata(31,0) )

    val align = reAlign_data( from = 64, to = 8, rdata, paddr )

    res := Mux1H(Seq(
      fun.isByte    -> load_byte(fun.is_usi, align),
      fun.isHalf    -> load_half(fun.is_usi, align),
      fun.isWord    -> load_word(fun.is_usi, align),
      fun.isDubl    -> align,
      fun.isDynamic -> Mux1H(Seq(
                        (vsew === "b000".U) -> load_byte(fun.is_usi, align),
                        (vsew === "b001".U) -> load_half(fun.is_usi, align),
                        (vsew === "b010".U) -> load_word(fun.is_usi, align),
                        (vsew === "b011".U) -> align,
                      ))

    ))  

    res
  }
}

```

### src/main/scala/tilelink/Edges.scala

```scala
  // Accesses
  def Get(fromSource: UInt, toAddress: UInt, lgSize: UInt) = {
    require (manager.anySupportGet, s"TileLink: No managers visible from this edge support Gets, but one of these clients would try to request one: ${client.clients}")
    val legal = manager.supportsGetFast(toAddress, lgSize)
    val a = Wire(new TLBundleA(bundle))
    a :#= DontCare
    a.opcode  := TLMessages.Get
    a.param   := 0.U
    a.size    := lgSize
    a.source  := fromSource
    a.address := toAddress
    a.mask    := mask(toAddress, lgSize)
    a.data    := 0.U
    a.corrupt := false.B
    (legal, a)
  }
// ...
  def Put(fromSource: UInt, toAddress: UInt, lgSize: UInt, data: UInt, mask: UInt): (Bool, TLBundleA) =
    Put(fromSource, toAddress, lgSize, data, mask, false.B)

  def Put(fromSource: UInt, toAddress: UInt, lgSize: UInt, data: UInt, mask: UInt, corrupt: Bool): (Bool, TLBundleA) = {
    require (manager.anySupportPutPartial, s"TileLink: No managers visible from this edge support masked Puts, but one of these clients would try to request one: ${client.clients}")
    val legal = manager.supportsPutPartialFast(toAddress, lgSize)
    val a = Wire(new TLBundleA(bundle))
    a :#= DontCare
    a.opcode  := TLMessages.PutPartialData
    a.param   := 0.U
    a.size    := lgSize
    a.source  := fromSource
    a.address := toAddress
    a.mask    := mask
    a.data    := data
    a.corrupt := corrupt
    (legal, a)
  }

```

## Related source code

### src/main/scala/rift2Core/rift2Core.scala

```scala
  val systemClientParameters = TLMasterPortParameters.v1(
    Seq(TLMasterParameters.v1(
      name = "system",
      sourceId = IdRange(0, 1),
    ))
  )

  val periphClientParameters = TLMasterPortParameters.v1(
    Seq(TLMasterParameters.v1(
      name = "periph",
      sourceId = IdRange(0, 1),
    ))
  )

```

### src/main/scala/rift2Core/backend/LSU/Lsu.scala

```scala
  val psel = ls_arb.io.out.bits.param.dat.op1(31,28)
  val sel = Mux( psel(3), 0.U, Mux( psel(2), 1.U, 2.U) )
// ...
  when( sel === 2.U ) {
    regionPeriphIO.valid := ls_arb.io.out.valid
    regionPeriphIO.bits  := ls_arb.io.out.bits
    ls_arb.io.out.ready  := regionPeriphIO.ready 
// ...
  when( sel === 1.U ) {
    regionSystemIO.valid := ls_arb.io.out.valid
    regionSystemIO.bits  := ls_arb.io.out.bits
    ls_arb.io.out.ready  := regionSystemIO.ready

```
