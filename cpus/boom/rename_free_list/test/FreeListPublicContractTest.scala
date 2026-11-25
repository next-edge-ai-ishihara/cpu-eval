package boom.tests
import chisel3._
import chisel3.util._
import chisel3.iotesters.{Driver,PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.subsystem.{InSubsystem,TilesLocated}
import freechips.rocketchip.tile.{TileKey,TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._
import boom.common._
import boom.exu._
class FreeListContractHarness(val physicals:Int,val logicals:Int)(implicit p:Parameters) extends LazyModule {
 val visibilityNode=TLEphemeralNode()
 val client=TLClientNode(Seq(TLMasterPortParameters.v1(Seq(TLMasterParameters.v1(name="client",sourceId=IdRange(0,32),supportsProbe=TransferSizes(64))))))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(BigInt("80000000",16),BigInt("0000ffff",16))),regionType=RegionType.CACHED,supportsGet=TransferSizes(1,64),supportsPutFull=TransferSizes(1,64),supportsPutPartial=TransferSizes(1,64),supportsAcquireB=TransferSizes(64),supportsAcquireT=TransferSizes(64))),beatBytes=16,endSinkId=4)))
 DisableMonitors { implicit p => manager := visibilityNode := client }
 lazy val module=new FreeListContractHarnessModule(this)
}
class FreeListContractHarnessModule(outer:FreeListContractHarness) extends LazyModuleImp(outer) {
 for((out,_)<-outer.client.out){out.a.valid:=false.B;out.a.bits:=0.U.asTypeOf(out.a.bits);out.c.valid:=false.B;out.c.bits:=0.U.asTypeOf(out.c.bits);out.e.valid:=false.B;out.e.bits:=0.U.asTypeOf(out.e.bits);out.b.ready:=true.B;out.d.ready:=true.B}
 for((in,_)<-outer.manager.in){in.a.ready:=true.B;in.c.ready:=true.B;in.e.ready:=true.B;in.b.valid:=false.B;in.b.bits:=0.U.asTypeOf(in.b.bits);in.d.valid:=false.B;in.d.bits:=0.U.asTypeOf(in.d.bits)}
 private val originalTile=p(TilesLocated(InSubsystem)).collectFirst{case a:BoomTileAttachParams=>a.tileParams}.get
 private val tile=originalTile
 implicit val testP:Parameters=p.alterPartial{case TileKey=>tile;case TileVisibilityNodeKey=>outer.visibilityNode}
 val numPregs=outer.physicals
 val dut=Module(new RenameFreeList(3,outer.physicals,outer.logicals))
 val io=IO(new Bundle {
  val reqs=Input(Vec(3,Bool()))
  val alloc_pregs=Output(Vec(3,Valid(UInt(7.W))))
  val dealloc_pregs=Input(Vec(3,Valid(UInt(7.W))))
  val ren_br_tags=Input(Vec(3,Valid(UInt(4.W))))
  val brupdate=Input(new BrUpdateInfo()(testP){override val b2=new BrResolutionInfo()(testP){override val target_offset=SInt(21.W)}})
  val debug=new Bundle{val pipeline_empty=Input(Bool());val freelist=Output(UInt(outer.physicals.W));val isprlist=Output(UInt(outer.physicals.W))}
 })
 io <> dut.io
}
class FreeListContractTester(c:FreeListContractHarnessModule) extends PeekPokeTester(c){
 def zero(x:Data):Unit=x match {case b:Bundle=>b.elements.values.foreach(zero);case v:Vec[_]=>v.foreach(y=>zero(y));case u:UInt=>poke(u,0);case s:SInt=>poke(s,0)}
 def budget(reason:String):Nothing=throw new IllegalStateException("CPU_EVAL_PROGRESS_BUDGET: "+reason)
 val progressBudget=4096
 zero(c.io.reqs);zero(c.io.dealloc_pregs);zero(c.io.ren_br_tags);zero(c.io.brupdate);poke(c.io.debug.pipeline_empty,0);reset(5);step(8)
 var live=Set.empty[BigInt]
 def offered:Seq[(Int,BigInt)]=(0 until 3).filter(i=>peek(c.io.alloc_pregs(i).valid)==1).map(i=>(i,peek(c.io.alloc_pregs(i).bits)))
 def check(got:Seq[(Int,BigInt)]):Unit={
  assert(got.map(_._2).distinct.size==got.size,"simultaneous accepted allocations distinct")
  got.foreach{case(_,v)=>assert(v>0&&v<c.numPregs&& !live(v),"accepted allocation nonzero and not already live")}
 }
 def requestOffered():Seq[(Int,BigInt)]={
  val lanes=offered.map(_._1)
  lanes.foreach(lane=>poke(c.io.reqs(lane),1))
  val accepted=offered.filter{case(lane,_)=>lanes.contains(lane)}
  assert(accepted.map(_._1)==lanes,"requested lanes remain valid in the accepted cycle")
  check(accepted)
  accepted
 }
 def consume(branchSlot:Int = -1, unavailable:String = "no allocation observed within execution budget"):Seq[(Int,BigInt)]={
  var waits=0;while(offered.isEmpty&&waits<progressBudget){step(1);waits+=1}
  if(offered.isEmpty)budget(unavailable)
  if(branchSlot>=0){poke(c.io.ren_br_tags(branchSlot).valid,1);poke(c.io.ren_br_tags(branchSlot).bits,1)}
  val got=requestOffered()
  live++=got.map(_._2);step(1);zero(c.io.reqs);zero(c.io.ren_br_tags);got
 }
 def mispredict():Unit={
  poke(c.io.brupdate.b1.resolve_mask,2)
  poke(c.io.brupdate.b1.mispredict_mask,2)
  step(1);zero(c.io.brupdate)
  poke(c.io.brupdate.b2.uop.br_tag,1)
  poke(c.io.brupdate.b2.mispredict,1)
  step(1);zero(c.io.brupdate)
 }
 // Unconsumed Valid offers may change; only the accepted cycle determines ownership.
 step(7)
 val first=consume().map(_._2)
 val branchGroup=consume(1)
 var younger=branchGroup.filter(_._1>1).map(_._2).toSet
 younger++=consume().map(_._2);younger++=consume().map(_._2)
 for(_<-0 until 24){
  val got=requestOffered()
  live++=got.map(_._2);younger++=got.map(_._2);step(1);zero(c.io.reqs)
 }

 mispredict();live--=younger
 var recovered=Set.empty[BigInt];var cycles=0
 while(recovered!=younger&&cycles<progressBudget){
  val got=requestOffered()
  recovered++=got.map(_._2).filter(younger);live++=got.map(_._2)
  step(1);zero(c.io.reqs);cycles+=1
 }
 if(recovered!=younger)budget("not all observed younger allocations reused within execution budget")
 val returned=first.take(3)
 returned.zipWithIndex.foreach{case(v,i)=>poke(c.io.dealloc_pregs(i).valid,1);poke(c.io.dealloc_pregs(i).bits,v)}
 step(1);zero(c.io.dealloc_pregs);live--=returned
 var again=Set.empty[BigInt];cycles=0
 while(again!=returned.toSet&&cycles<progressBudget){
  val got=requestOffered()
  again++=got.map(_._2).filter(returned.contains);live++=got.map(_._2)
  step(1);zero(c.io.reqs);cycles+=1
 }
 if(again!=returned.toSet)budget("not all committed returns reused within execution budget")

 // A register live at the branch can be returned by an older instruction and reused on the wrong path.
 val recycled=first.head
 poke(c.io.ren_br_tags(2).valid,1);poke(c.io.ren_br_tags(2).bits,1)
 step(1);zero(c.io.ren_br_tags)
 poke(c.io.dealloc_pregs(0).valid,1);poke(c.io.dealloc_pregs(0).bits,recycled)
 step(1);zero(c.io.dealloc_pregs);live-=recycled

 var wrongPath=Set.empty[BigInt]
 while(!wrongPath(recycled))wrongPath++=consume(unavailable="returned register was not reallocated before misprediction").map(_._2)
 mispredict();live--=wrongPath

 var reclaimed=Set.empty[BigInt]
 while(!reclaimed(recycled))reclaimed++=consume(unavailable="reallocated register was not recovered after misprediction").map(_._2)
}
class FreeListPublicContractTest extends org.scalatest.flatspec.AnyFlatSpec{
 behavior of "Free list external relation"
 it should "preserve valid allocation, return and branch recovery without fixed register order" in {
 implicit val p:Parameters=new WithNLargeBooms(1)++new freechips.rocketchip.system.BaseConfig
 for((physicals,logicals)<-Seq((100,31),(96,32))) {
 assert(Driver.execute(Array("--backend-name","treadle","--test-seed","1","--target-dir",sys.props.getOrElse("cpu.eval.freelist.target","test_run_dir/freelist-contract")+"/"+physicals),()=>LazyModule(new FreeListContractHarness(physicals,logicals)).module)(c=>new FreeListContractTester(c)))
 }
 }
}
