package boom.tests
import chisel3._
import chisel3.iotesters.{Driver,PeekPokeTester}
import freechips.rocketchip.config.{Parameters}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.subsystem.{InSubsystem,TilesLocated}
import freechips.rocketchip.tile.{TileKey,TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._
import freechips.rocketchip.rocket._
import boom.common._
import boom.lsu._
class SecondaryHarness(implicit p:Parameters) extends LazyModule {
 val visibilityNode=TLEphemeralNode()
 val client=TLClientNode(Seq(TLMasterPortParameters.v1(Seq(TLMasterParameters.v1(name="secondary",sourceId=IdRange(0,32),supportsProbe=TransferSizes(64))))))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(BigInt("80000000",16),BigInt("0000ffff",16))),regionType=RegionType.CACHED,supportsGet=TransferSizes(1,64),supportsPutFull=TransferSizes(1,64),supportsPutPartial=TransferSizes(1,64),supportsArithmetic=TransferSizes(1,8),supportsLogical=TransferSizes(1,8),supportsAcquireB=TransferSizes(64),supportsAcquireT=TransferSizes(64))),beatBytes=16,endSinkId=4)))
 DisableMonitors { implicit p => manager := visibilityNode := client }
 lazy val module=new SecondaryHarnessModule(this)
}
class SecondaryHarnessModule(outer:SecondaryHarness) extends LazyModuleImp(outer) {
 for((out,_)<-outer.client.out){out.a.valid:=false.B;out.a.bits:=0.U.asTypeOf(out.a.bits);out.c.valid:=false.B;out.c.bits:=0.U.asTypeOf(out.c.bits);out.e.valid:=false.B;out.e.bits:=0.U.asTypeOf(out.e.bits);out.b.ready:=true.B;out.d.ready:=true.B}
 for((in,_)<-outer.manager.in){in.a.ready:=true.B;in.c.ready:=true.B;in.e.ready:=true.B;in.b.valid:=false.B;in.b.bits:=0.U.asTypeOf(in.b.bits);in.d.valid:=false.B;in.d.bits:=0.U.asTypeOf(in.d.bits)}
 private val tile=p(TilesLocated(InSubsystem)).collectFirst{case a:BoomTileAttachParams=>a.tileParams}.get
 implicit val testP:Parameters=p.alterPartial{case TileKey=>tile;case TileVisibilityNodeKey=>outer.visibilityNode}
 implicit val edge:TLEdgeOut=outer.visibilityNode.edges.out.head
 val dut=Module(new BoomMSHRFile)
 val io=IO(new Bundle { val req=chiselTypeOf(dut.io.req);val req_is_probe=chiselTypeOf(dut.io.req_is_probe);val resp=chiselTypeOf(dut.io.resp);val secondary_miss=chiselTypeOf(dut.io.secondary_miss);val block_hit=chiselTypeOf(dut.io.block_hit);val exception=chiselTypeOf(dut.io.exception);val rob_pnr_idx=chiselTypeOf(dut.io.rob_pnr_idx);val rob_head_idx=chiselTypeOf(dut.io.rob_head_idx);val mem_acquire=chiselTypeOf(dut.io.mem_acquire);val mem_grant=chiselTypeOf(dut.io.mem_grant);val mem_finish=chiselTypeOf(dut.io.mem_finish);val refill=chiselTypeOf(dut.io.refill);val meta_write=chiselTypeOf(dut.io.meta_write);val meta_read=chiselTypeOf(dut.io.meta_read);val meta_resp=chiselTypeOf(dut.io.meta_resp);val replay=chiselTypeOf(dut.io.replay);val prefetch=chiselTypeOf(dut.io.prefetch);val wb_req=chiselTypeOf(dut.io.wb_req);val prober_state=chiselTypeOf(dut.io.prober_state);val clear_all=chiselTypeOf(dut.io.clear_all);val wb_resp=chiselTypeOf(dut.io.wb_resp);val fence_rdy=chiselTypeOf(dut.io.fence_rdy);val probe_rdy=chiselTypeOf(dut.io.probe_rdy) })
 for((n,v)<-io.elements) dut.io.elements(n) <> v
 def zero(d:Data):Unit=d match {case a:Aggregate=>a.getElements.foreach(zero);case s:SInt=>s:=0.S(21.W);case u:UInt=>u:=0.U}
 zero(dut.io.brupdate)
}
class SecondaryTester(c:SecondaryHarnessModule) extends PeekPokeTester(c) {
 val got=scala.collection.mutable.ArrayBuffer[(BigInt,BigInt)]()
 val metadataDelay=scala.collection.mutable.Queue(false,false)
 val acquired=scala.collection.mutable.Map[BigInt,BigInt]()
 def tick():Unit={
  if(peek(c.io.resp.valid)==1 && peek(c.io.resp.ready)==1){
   val r=(peek(c.io.resp.bits.uop.ldq_idx),peek(c.io.resp.bits.data));got+=r
  }
  if(peek(c.io.mem_acquire.valid)==1 && peek(c.io.mem_acquire.ready)==1)
   acquired(peek(c.io.mem_acquire.bits.address))=peek(c.io.mem_acquire.bits.source)
  metadataDelay.enqueue(peek(c.io.meta_read.valid)==1 && peek(c.io.meta_read.ready)==1)
  step(1)
  poke(c.io.meta_resp.valid,if(metadataDelay.dequeue())1 else 0)
 }
 def waitFor(f: =>Boolean,msg:String):Unit={var n=0;while(!f&&n<64){tick();n+=1};assert(f,msg)}
 poke(c.io.req(0).valid,0);poke(c.io.req_is_probe(0),0)
 poke(c.io.exception,0);poke(c.io.rob_pnr_idx,63);poke(c.io.rob_head_idx,0)
 poke(c.io.mem_acquire.ready,1);poke(c.io.mem_grant.valid,0);poke(c.io.mem_finish.ready,1)
 poke(c.io.resp.ready,1);poke(c.io.refill.ready,1);poke(c.io.meta_write.ready,1);poke(c.io.meta_read.ready,1)
 poke(c.io.meta_resp.bits.coh.state,ClientStates.Nothing.litValue);poke(c.io.meta_resp.bits.tag,0);poke(c.io.meta_resp.valid,0);poke(c.io.replay.ready,1);poke(c.io.prefetch.ready,0);poke(c.io.wb_req.ready,0)
 poke(c.io.prober_state.valid,0);poke(c.io.clear_all,0);poke(c.io.wb_resp,0)
 tick();tick()
 def req(addr:BigInt,id:Int):Unit={
  val b=c.io.req(0).bits
  poke(b.addr,addr);poke(b.data,0);poke(b.is_hella,0);poke(b.tag_match,0);poke(b.way_en,1)
  poke(b.old_meta.coh.state,ClientStates.Nothing.litValue);poke(b.old_meta.tag,0)
  poke(b.uop.mem_cmd,M_XRD.litValue);poke(b.uop.mem_size,3);poke(b.uop.mem_signed,0)
  poke(b.uop.uses_ldq,1);poke(b.uop.uses_stq,0);poke(b.uop.ldq_idx,id);poke(b.uop.br_mask,0);poke(b.uop.rob_idx,id)
  poke(c.io.req(0).valid,1);waitFor(peek(c.io.req(0).ready)==1,"request not accepted")
  tick();poke(c.io.req(0).valid,0);tick()
 }
 val a=BigInt("80000000",16);val b=a+64
 req(a,0);waitFor(acquired.contains(a),"first acquire missing")
 req(b,1);waitFor(acquired.contains(b),"second acquire missing")
 req(a+8,2)
 def grant(address:BigInt,word:BigInt):Unit={
  poke(c.io.mem_grant.bits.opcode,TLMessages.GrantData.litValue)
  poke(c.io.mem_grant.bits.param,TLPermissions.toT.litValue)
  poke(c.io.mem_grant.bits.size,6);poke(c.io.mem_grant.bits.source,acquired(address))
  poke(c.io.mem_grant.bits.sink,0);poke(c.io.mem_grant.bits.denied,0);poke(c.io.mem_grant.bits.corrupt,0)
  poke(c.io.mem_grant.bits.data,(word<<64)|word)
  for(i<-0 until 4){poke(c.io.mem_grant.valid,1);waitFor(peek(c.io.mem_grant.ready)==1,"grant backpressure");tick()}
  poke(c.io.mem_grant.valid,0)
  for(i<-0 until 16)tick()
 }
 val av=BigInt("1111111111111111",16);val bv=BigInt("2222222222222222",16)
 grant(b,bv);grant(a,av)
 for(i<-0 until 16)tick()
 assert(got.count(_._1==0)==1,"primary A response count")
 assert(got.count(_._1==1)==1,"primary B response count")
 assert(got.count(_._1==2)==1,"secondary response count")
 assert(got.size==3,"response for an unaccepted load")
 assert(got.filter(_._1==0).forall(_._2==av),"primary A wrong data")
 assert(got.filter(_._1==1).forall(_._2==bv),"primary B wrong data")
 assert(got.filter(_._1==2).forall(_._2==av),"secondary wrong line data")
}
class BoomMSHRFileSecondaryTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "BoomMSHRFile"
 it should "return one correctly valued response per accepted load with concurrent distinct-set misses" in {
  implicit val p:Parameters=new WithNLargeBooms(1)++new freechips.rocketchip.system.BaseConfig
  assert(Driver.execute(Array("--backend-name","firrtl"),()=>LazyModule(new SecondaryHarness).module)(c=>new SecondaryTester(c)))
 }
}
