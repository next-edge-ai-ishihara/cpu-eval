package boom.tests
import chisel3._
import chisel3.util._
import chisel3.iotesters.{Driver,PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.subsystem.{InSubsystem,TilesLocated}
import freechips.rocketchip.tile.{TileKey,TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._
import freechips.rocketchip.rocket._
import boom.common._
import boom.ifu._
class ICacheContractHarness(implicit p:Parameters) extends LazyModule {
 val visibilityNode=TLEphemeralNode()
 private val originalTile=p(TilesLocated(InSubsystem)).collectFirst{case a:BoomTileAttachParams=>a.tileParams}.get
 val testP:Parameters=p.alterPartial{case TileKey=>originalTile;case TileVisibilityNodeKey=>visibilityNode}
 val cache=LazyModule(new boom.ifu.ICache(originalTile.icache.get,0)(testP))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(BigInt("80000000",16),BigInt("0000ffff",16))),regionType=RegionType.UNCACHED,supportsGet=TransferSizes(1,64))),beatBytes=16,minLatency=1)))
 DisableMonitors { implicit p => manager := visibilityNode := cache.masterNode }
 lazy val module=new ICacheContractHarnessModule(this)
}
class ICacheContractHarnessModule(outer:ICacheContractHarness) extends LazyModuleImp(outer) {
 val cache=outer.cache.module
 val edge=outer.manager.in.head._2
 val io=IO(new Bundle {
  val req=Flipped(Decoupled(new ICacheReq()(outer.testP)))
  val s1_paddr=Input(UInt(40.W));val s1_kill=Input(Bool());val s2_kill=Input(Bool());val invalidate=Input(Bool())
  val response=Output(Valid(UInt(128.W)))
  val tl=new TLBundle(edge.bundle)
 })
 cache.io.req<>io.req
 cache.io.s1_paddr:=io.s1_paddr;cache.io.s1_kill:=io.s1_kill;cache.io.s2_kill:=io.s2_kill;cache.io.invalidate:=io.invalidate;cache.io.s2_prefetch:=false.B
 io.response.valid:=cache.io.resp.valid;io.response.bits:=cache.io.resp.bits.data
 io.tl<>outer.manager.in.head._1
}
class ICacheContractTester(c:ICacheContractHarnessModule) extends PeekPokeTester(c) {
 def zero(x:Data):Unit=x match {case b:Record=>b.elements.values.foreach(zero);case v:Vec[_]=>v.foreach(zero);case u:UInt=>poke(u,0);case s:SInt=>poke(s,0)}
 zero(c.io);poke(c.io.tl.a.ready,0);reset(5);step(3)
 val pc=BigInt("80000000",16)
 def req(addr:BigInt,s1kill:Boolean=false,s2kill:Boolean=false,physical:Option[BigInt]=None):Unit={
  poke(c.io.req.bits.addr,addr);poke(c.io.req.valid,1)
  var waits=0
  while(peek(c.io.req.ready)==0 && waits<128){step(1);waits+=1}
  if(peek(c.io.req.ready)==0)throw new RuntimeException("CPU_EVAL_PROGRESS_BUDGET: request readiness")
  step(1);poke(c.io.req.valid,0);poke(c.io.s1_paddr,physical.getOrElse(addr));poke(c.io.s1_kill,if(s1kill)1 else 0);poke(c.io.s2_kill,0)
  step(1);poke(c.io.s1_kill,0);poke(c.io.s2_kill,if(s2kill)1 else 0)
 }
 def beat(n:Int,offset:Int):BigInt=(0 until 16).map(i=>BigInt((offset+n*16+i)&255)<<(8*i)).reduce(_|_)
 def acceptRefill(addr:BigInt):Unit={
  var waits=0
  while(peek(c.io.tl.a.valid)==0 && waits<128){step(1);waits+=1}
  if(peek(c.io.tl.a.valid)==0)throw new RuntimeException("CPU_EVAL_PROGRESS_BUDGET: refill request")
  val expected=addr>>6<<6
  val observed=peek(c.io.tl.a.bits.address)
  assert(observed==expected,s"refill requested physical block: expected 0x${expected.toString(16)}, got 0x${observed.toString(16)}")
  poke(c.io.tl.a.ready,1);step(1);poke(c.io.tl.a.ready,0)
 }
 def sendBeat(n:Int,offset:Int):Unit={
  poke(c.io.tl.d.valid,1);poke(c.io.tl.d.bits.opcode,1);poke(c.io.tl.d.bits.size,6);poke(c.io.tl.d.bits.source,0);poke(c.io.tl.d.bits.data,beat(n,offset))
  var waits=0
  while(peek(c.io.tl.d.ready)==0 && waits<128){step(1);waits+=1}
  if(peek(c.io.tl.d.ready)==0)throw new RuntimeException("CPU_EVAL_PROGRESS_BUDGET: refill acceptance")
  step(1);poke(c.io.tl.d.valid,0)
 }
 def refill(addr:BigInt,offset:Int):Unit={
  acceptRefill(addr)
  for(n<-0 until 4)sendBeat(n,offset)
  step(3)
 }
 def fetch(addr:BigInt,offset:Int,expectMiss:Boolean=false,physical:Option[BigInt]=None,missReason:String="invalidated or unfilled block must miss"):Unit={
  var attempts=0;var delivered=false
  while(!delivered && attempts<16){
   req(addr,physical=physical)
   if(peek(c.io.response.valid)==1){
    assert(!expectMiss || attempts>0,missReason)
    val low=(addr&63).toInt
    val expected=(0 until 16).map(i=>BigInt((offset+low+i)&255)<<(8*i)).reduce(_|_)
    assert(peek(c.io.response.bits)==expected,"address-order instruction data")
    delivered=true;step(2)
   } else {refill(physical.getOrElse(addr),offset);attempts+=1}
  }
  if(!delivered)throw new RuntimeException("CPU_EVAL_PROGRESS_BUDGET: finite fetch retries")
 }
 fetch(pc,0,true);fetch(pc,0);fetch(pc+8,0)
 req(pc,true);assert(peek(c.io.response.valid)==0,"s1 kill removes lookup response");step(2)
 req(pc+64,false,true);assert(peek(c.io.tl.a.valid)==0,"s2 kill cancels miss request");poke(c.io.s2_kill,0);step(2)
 poke(c.io.invalidate,1);step(1);poke(c.io.invalidate,0);step(2)
 fetch(pc,64,true);fetch(pc,64)
 for(i<-1 to 10)fetch(pc+i*4096,(i*19)&255)
 for(i<-10 to 1 by -1)fetch(pc+i*4096,(i*19)&255)

 val virtual=pc+0xb088
 val firstPhysical=pc+0xc088
 val secondPhysical=pc+0xd088
 fetch(virtual,11,expectMiss=true,physical=Some(firstPhysical))
 fetch(virtual,37,expectMiss=true,physical=Some(secondPhysical),missReason="different physical page must not hit the old translation")
 fetch(virtual,11,physical=Some(firstPhysical))
 println("ICACHE_TRANSLATED_REMAP_PASS")

 val interrupted=pc+0xe0c0
 req(interrupted)
 acceptRefill(interrupted)
 sendBeat(0,73)
 poke(c.io.invalidate,1);step(1);poke(c.io.invalidate,0)
 for(n<-1 until 4)sendBeat(n,73)
 step(3)
 fetch(interrupted,91,expectMiss=true,missReason="refill interrupted by invalidation must miss")
 println("ICACHE_INFLIGHT_INVALIDATION_PASS")

 println("ICACHE_PUBLIC_RELATION_PASS")
}
class ICachePublicContractTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "Instruction cache public ports"
 it should "preserve translated lookup refill bank ordering kill and invalidate" in {
  implicit val p:Parameters=new boom.common.WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
  assert(Driver.execute(Array("--backend-name","treadle","--target-dir",sys.props.getOrElse("cpu.eval.icache.target",sys.env.getOrElse("CPU_EVAL_ICACHE_TARGET","target/cpu-eval-icache-public"))),()=>LazyModule(new ICacheContractHarness).module){c=>new ICacheContractTester(c)})
 }
}
