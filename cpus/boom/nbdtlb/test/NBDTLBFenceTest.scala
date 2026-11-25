package boom.tests
import chisel3._
import chisel3.iotesters.{Driver,PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.subsystem.{InSubsystem,TilesLocated}
import freechips.rocketchip.tile.{TileKey,TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._
import freechips.rocketchip.rocket._
import boom.common._
import boom.lsu._
class FenceHarness(implicit p:Parameters) extends LazyModule {
 val visibilityNode=TLEphemeralNode()
 val client=TLClientNode(Seq(TLMasterPortParameters.v1(Seq(TLMasterParameters.v1(name="fence",sourceId=IdRange(0,32),supportsProbe=TransferSizes(64))))))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(BigInt("80000000",16),BigInt("0000ffff",16))),regionType=RegionType.CACHED,supportsGet=TransferSizes(1,64),supportsPutFull=TransferSizes(1,64),supportsPutPartial=TransferSizes(1,64),supportsAcquireB=TransferSizes(64),supportsAcquireT=TransferSizes(64))),beatBytes=16,endSinkId=4)))
 DisableMonitors { implicit p => manager := visibilityNode := client }
 lazy val module=new FenceHarnessModule(this)
}
class FenceHarnessModule(outer:FenceHarness) extends LazyModuleImp(outer) {
 for((out,_)<-outer.client.out){out.a.valid:=false.B;out.a.bits:=0.U.asTypeOf(out.a.bits);out.c.valid:=false.B;out.c.bits:=0.U.asTypeOf(out.c.bits);out.e.valid:=false.B;out.e.bits:=0.U.asTypeOf(out.e.bits);out.b.ready:=true.B;out.d.ready:=true.B}
 for((in,_)<-outer.manager.in){in.a.ready:=true.B;in.c.ready:=true.B;in.e.ready:=true.B;in.b.valid:=false.B;in.b.bits:=0.U.asTypeOf(in.b.bits);in.d.valid:=false.B;in.d.bits:=0.U.asTypeOf(in.d.bits)}
 private val tile=p(TilesLocated(InSubsystem)).collectFirst{case a:BoomTileAttachParams=>a.tileParams}.get
 implicit val testP:Parameters=p.alterPartial{case TileKey=>tile;case TileVisibilityNodeKey=>outer.visibilityNode}
 implicit val edge:TLEdgeOut=outer.visibilityNode.edges.out.head
 val dc=tile.dcache.get
 val dut=Module(new NBDTLB(false,3,TLBConfig(dc.nTLBSets,dc.nTLBWays)))
 val io=IO(chiselTypeOf(dut.io))
 io <> dut.io
}
class FenceTester(c:FenceHarnessModule) extends PeekPokeTester(c) {
 private val progressLimit = 4096
 def awaitCondition(label:String)(condition: => Boolean):Unit = {
  var remaining=progressLimit
  while(!condition && remaining>0) {step(1);remaining-=1}
  if(!condition) throw new RuntimeException("CPU_EVAL_DIRECTED_TIMEOUT: "+label)
 }
 def requestWalk(label:String):Unit = {
  poke(c.io.ptw.req.ready,1)
  poke(c.io.req(0).valid,1)
  var requestAccepted=false
  var walkAccepted=false
  var remaining=progressLimit
  while((!requestAccepted || !walkAccepted) && remaining>0) {
   val requestFire= !requestAccepted && peek(c.io.req(0).ready)==1
   val walkFire=peek(c.io.ptw.req.valid)==1
   if(requestFire) assert(peek(c.io.resp(0).miss)==1,label+" must miss")
   if(walkFire) assert(peek(c.io.ptw.req.bits.valid)==1,label+" walk must not be killed")
   step(1);remaining-=1
   if(requestFire) {requestAccepted=true;poke(c.io.req(0).valid,0)}
   if(walkFire) walkAccepted=true
  }
  if(!requestAccepted || !walkAccepted) throw new RuntimeException("CPU_EVAL_DIRECTED_TIMEOUT: "+label)
 }
 poke(c.io.kill,0);poke(c.io.sfence.valid,0);poke(c.io.sfence.bits.rs1,0);poke(c.io.sfence.bits.rs2,0);poke(c.io.sfence.bits.addr,0)
 poke(c.io.req(0).valid,0);poke(c.io.req(0).bits.vaddr,0x1000);poke(c.io.req(0).bits.passthrough,0);poke(c.io.req(0).bits.size,3);poke(c.io.req(0).bits.cmd,0);poke(c.io.req(0).bits.prv,1);poke(c.io.req(0).bits.v,0)
 poke(c.io.ptw.req.ready,1);poke(c.io.ptw.resp.valid,0);poke(c.io.ptw.ptbr.mode,8);poke(c.io.ptw.status.dprv,1);poke(c.io.ptw.status.prv,1)
 for(i <- 0 until c.io.ptw.pmp.length) {
  poke(c.io.ptw.pmp(i).cfg.a,if(i==0)1 else 0);poke(c.io.ptw.pmp(i).cfg.l,0);poke(c.io.ptw.pmp(i).cfg.res,0)
  poke(c.io.ptw.pmp(i).cfg.r,1);poke(c.io.ptw.pmp(i).cfg.w,1);poke(c.io.ptw.pmp(i).cfg.x,1)
  poke(c.io.ptw.pmp(i).addr,if(i==0)BigInt("3fffffff",16) else BigInt(0));poke(c.io.ptw.pmp(i).mask,0)
 }
 step(2)
 requestWalk("initial")
 poke(c.io.sfence.valid,1);step(1);poke(c.io.sfence.valid,0);step(1)
 poke(c.io.ptw.resp.bits.ae_ptw,0);poke(c.io.ptw.resp.bits.ae_final,0);poke(c.io.ptw.resp.bits.gf,0);poke(c.io.ptw.resp.bits.hr,1);poke(c.io.ptw.resp.bits.hw,1);poke(c.io.ptw.resp.bits.hx,1);poke(c.io.ptw.resp.bits.fragmented_superpage,0);poke(c.io.ptw.resp.bits.gpa.valid,0)
 poke(c.io.ptw.resp.bits.level,2);poke(c.io.ptw.resp.bits.homogeneous,1)
 poke(c.io.ptw.resp.bits.pte.ppn,0x80000);poke(c.io.ptw.resp.bits.pte.v,1);poke(c.io.ptw.resp.bits.pte.r,1);poke(c.io.ptw.resp.bits.pte.w,1);poke(c.io.ptw.resp.bits.pte.x,1);poke(c.io.ptw.resp.bits.pte.a,1);poke(c.io.ptw.resp.bits.pte.d,1);poke(c.io.ptw.resp.bits.pte.u,0);poke(c.io.ptw.resp.bits.pte.g,0)
 poke(c.io.ptw.resp.valid,1);step(1);poke(c.io.ptw.resp.valid,0);step(1)
 awaitCondition("completion of invalidated walk")(peek(c.io.miss_rdy)==1)
 poke(c.io.req(0).valid,1)
 awaitCondition("old-response lookup readiness")(peek(c.io.req(0).ready)==1)
 val afterOld=peek(c.io.resp(0).miss)
 println("FENCE_AFTER_OLD_RESPONSE miss="+afterOld+" paddr="+peek(c.io.resp(0).paddr)+" ae.ld="+peek(c.io.resp(0).ae.ld)+" pf.ld="+peek(c.io.resp(0).pf.ld))
 assert(afterOld==1,"old response must not repopulate a globally invalidated translation")
 poke(c.io.req(0).valid,0);poke(c.io.sfence.valid,1);step(1);poke(c.io.sfence.valid,0);step(1)
 requestWalk("fresh request after second fence")
 poke(c.io.ptw.resp.bits.pte.ppn,0x80001);poke(c.io.ptw.resp.valid,1);step(1);poke(c.io.ptw.resp.valid,0);step(1)
 poke(c.io.req(0).valid,1)
 awaitCondition("fresh translation result")(peek(c.io.req(0).ready)==1 && peek(c.io.resp(0).miss)==0)
 println("FENCE_FRESH_RESPONSE miss="+peek(c.io.resp(0).miss)+" paddr="+peek(c.io.resp(0).paddr))
 assert(peek(c.io.resp(0).miss)==0,"uninvalidated fresh translation must refill")
 assert(peek(c.io.resp(0).paddr)==BigInt("80001000",16),"fresh translation value")
 println("FENCE_FRESH_PERMISSIONS ae.ld="+peek(c.io.resp(0).ae.ld)+" pf.ld="+peek(c.io.resp(0).pf.ld))
 assert(peek(c.io.resp(0).ae.ld)==0,"permitted fresh read must not fault");assert(peek(c.io.resp(0).pf.ld)==0,"valid fresh leaf must not page-fault")
}
class NBDTLBFenceTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "NBDTLB outstanding translation"
 it should "discard a pre-fence response invalidated by a global SFENCE" in {
  implicit val p:Parameters=new WithNLargeBooms(1)++new freechips.rocketchip.system.BaseConfig
  assert(Driver.execute(Array("--backend-name","firrtl"),()=>LazyModule(new FenceHarness).module)(c=>new FenceTester(c)))
 }
}
