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
class PredContractHarness(implicit p:Parameters) extends LazyModule {
 val visibilityNode=TLEphemeralNode()
 val client=TLClientNode(Seq(TLMasterPortParameters.v1(Seq(TLMasterParameters.v1(name="client",sourceId=IdRange(0,32),supportsProbe=TransferSizes(64))))))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(BigInt("80000000",16),BigInt("0000ffff",16))),regionType=RegionType.CACHED,supportsGet=TransferSizes(1,64),supportsPutFull=TransferSizes(1,64),supportsPutPartial=TransferSizes(1,64),supportsAcquireB=TransferSizes(64),supportsAcquireT=TransferSizes(64))),beatBytes=16,endSinkId=4)))
 DisableMonitors { implicit p => manager := visibilityNode := client }
 lazy val module=new PredContractHarnessModule(this)
}
class PredContractHarnessModule(outer:PredContractHarness) extends LazyModuleImp(outer) {
 for((out,_)<-outer.client.out){out.a.valid:=false.B;out.a.bits:=0.U.asTypeOf(out.a.bits);out.c.valid:=false.B;out.c.bits:=0.U.asTypeOf(out.c.bits);out.e.valid:=false.B;out.e.bits:=0.U.asTypeOf(out.e.bits);out.b.ready:=true.B;out.d.ready:=true.B}
 for((in,_)<-outer.manager.in){in.a.ready:=true.B;in.c.ready:=true.B;in.e.ready:=true.B;in.b.valid:=false.B;in.b.bits:=0.U.asTypeOf(in.b.bits);in.d.valid:=false.B;in.d.bits:=0.U.asTypeOf(in.d.bits)}
 private val originalTile=p(TilesLocated(InSubsystem)).collectFirst{case a:BoomTileAttachParams=>a.tileParams}.get
 private val tile=originalTile.copy(core=originalTile.core.copy(enableSFBOpt=true))
 implicit val testP:Parameters=p.alterPartial{case TileKey=>tile;case TileVisibilityNodeKey=>outer.visibilityNode}
 val dut=Module(new PredRenameStage(3,tile.core.ftq.nEntries,1))
 val io=IO(new Bundle {
  val ren_stalls=Output(Vec(3,Bool()))
  val kill=Input(Bool())
  val dec_fire=Input(Vec(3,Bool()))
  val dec_uops=Input(Vec(3,new MicroOp()))
  val ren2_mask=Output(Vec(3,Bool()))
  val ren2_uops=Output(Vec(3,new MicroOp()))
  val brupdate=Input(new BrUpdateInfo()(testP){override val b2=new BrResolutionInfo()(testP){override val target_offset=SInt(21.W)}})
  val dis_fire=Input(Vec(3,Bool()))
  val dis_ready=Input(Bool())
  val wakeups=Flipped(Vec(1,Valid(new ExeUnitResp(64))))
  val com_valids=Input(Vec(3,Bool()))
  val com_uops=Input(Vec(3,new MicroOp()))
  val rbk_valids=Input(Vec(3,Bool()))
  val rollback=Input(Bool())
  val debug_rob_empty=Input(Bool())
  val debug=Output(new DebugRenameStageIO(tile.core.ftq.nEntries))
 })
 io <> dut.io
}


class PredContractTester(c:PredContractHarnessModule) extends PeekPokeTester(c) {
 def zero(x:Data):Unit=x match {case b:Bundle=>b.elements.values.foreach(zero);case v:Vec[_]=>v.foreach(y=>zero(y));case u:UInt=>poke(u,0);case s:SInt=>poke(s,0)}
 def inputs():Unit={zero(c.io.dec_fire);zero(c.io.dec_uops);zero(c.io.dis_fire);zero(c.io.wakeups);zero(c.io.brupdate);zero(c.io.com_valids);zero(c.io.com_uops);zero(c.io.rbk_valids);poke(c.io.kill,0);poke(c.io.rollback,0);poke(c.io.dis_ready,1);poke(c.io.debug_rob_empty,1)}
 inputs();reset(5);step(2)
 def accept(br:Seq[Boolean],sfb:Seq[Boolean],ftq:Seq[Int],ids:Seq[Int]):Unit={
  zero(c.io.dec_uops);zero(c.io.dec_fire);zero(c.io.dis_fire)
  for(i<-ids.indices){poke(c.io.dec_fire(i),1);poke(c.io.dec_uops(i).is_br,if(br(i))1 else 0);poke(c.io.dec_uops(i).is_sfb,if(sfb(i))1 else 0);poke(c.io.dec_uops(i).ftq_idx,ftq(i));poke(c.io.dec_uops(i).debug_inst,ids(i))}
  poke(c.io.dis_ready,1);step(1);poke(c.io.dis_ready,0);zero(c.io.dec_fire);for(i<-ids.indices)assert(peek(c.io.ren2_mask(i))==1,"accepted operation retained")
 }
 def fire(ids:Seq[Int]):Unit={
  zero(c.io.dis_fire);var waits=0
  while(ids.exists(i=>peek(c.io.ren_stalls(i))!=0) && waits<4096){step(1);waits+=1}
  if(!ids.forall(i=>peek(c.io.ren_stalls(i))==0))throw new IllegalStateException("CPU_EVAL_PROGRESS_BUDGET: accepted operations remain stalled within execution budget")
  for(i<-ids)poke(c.io.dis_fire(i),1)
 }
 for(delay<-0 until 12){
  inputs();reset(5);step(2+delay)
  accept(Seq(false,false,false),Seq(false,false,false),Seq(0,0,0),Seq(10,11,12))
  fire(0 until 3);step(1);zero(c.io.dis_fire)
  accept(Seq(true,false,false),Seq(true,true,true),Seq(3,3,3),Seq(20,21,22))
  fire(0 until 3)
  val first=peek(c.io.ren2_uops(0).pdst)
  for(i<-1 until 3){assert(peek(c.io.ren2_uops(i).ppred)==first,"same accepted group shadow follows branch predicate");assert(peek(c.io.ren2_uops(i).ppred_busy)==1,"new branch predicate busy")}
  step(1);zero(c.io.dis_fire)
  accept(Seq(false),Seq(true),Seq(4),Seq(30));fire(Seq(0))
  assert(peek(c.io.ren2_uops(0).ppred)==first,"later group shadow follows latest dispatched branch");assert(peek(c.io.ren2_uops(0).ppred_busy)==1,"predicate retained busy until execution wake")
  // Wake the waiting shadow, then dispatch it.
  zero(c.io.dis_fire);poke(c.io.wakeups(0).valid,1);poke(c.io.wakeups(0).bits.uop.pdst,first)
  step(1);zero(c.io.wakeups);fire(Seq(0))
  assert(peek(c.io.ren2_uops(0).ppred_busy)==0,"wake clears waiting shadow readiness")
  step(1);zero(c.io.dis_fire)
  accept(Seq(true,false,true),Seq(true,true,true),Seq(7,7,9),Seq(40,41,42));fire(0 until 3)
  val middle=peek(c.io.ren2_uops(0).pdst);val last=peek(c.io.ren2_uops(2).pdst)
  assert(first!=middle && middle!=last && first!=last,"distinct active branch predicates")
  assert(peek(c.io.ren2_uops(1).ppred)==middle,"shadow follows earlier same-group branch")
  step(1);zero(c.io.dis_fire)
  accept(Seq(false),Seq(true),Seq(10),Seq(50));fire(Seq(0));assert(peek(c.io.ren2_uops(0).ppred)==last,"latest branch carries between groups");assert(peek(c.io.ren2_uops(0).ppred_busy)==1,"latest branch busy")
  poke(c.io.wakeups(0).valid,1);poke(c.io.wakeups(0).bits.uop.pdst,middle);assert(peek(c.io.ren2_uops(0).ppred_busy)==1,"unrelated branch wake cannot clear latest shadow")
  step(1);zero(c.io.wakeups);zero(c.io.dis_fire);poke(c.io.kill,1);step(1);poke(c.io.kill,0);assert(c.io.ren2_mask.indices.forall(i=>peek(c.io.ren2_mask(i))==0),"kill clears inherited accepted-valid pipeline")
 }
 inputs();reset(5);step(2)
 accept(Seq(true,false),Seq(true,true),Seq(3,3),Seq(60,61))
 fire(0 until 2)
 poke(c.io.dis_ready,1)
 val olderPredicate=peek(c.io.ren2_uops(0).pdst)
 step(1);zero(c.io.dis_fire)

 accept(Seq(false,true,false),Seq(true,true,true),Seq(4,7,7),Seq(62,63,64))
 step(1)
 fire(Seq(0))
 val shadowPredicate=peek(c.io.ren2_uops(0).ppred)
 assert(shadowPredicate==olderPredicate,"an undispatched branch cannot change the older shadow predicate")
 step(1);zero(c.io.dis_fire)

 fire(Seq(1,2))
 poke(c.io.dis_ready,1)
 val youngerPredicate=peek(c.io.ren2_uops(1).pdst)
 assert(youngerPredicate!=olderPredicate,"simultaneously live predicates remain distinct")
 assert(peek(c.io.ren2_uops(2).ppred)==youngerPredicate,"the later shadow follows its dispatched branch")
 step(1);zero(c.io.dis_fire)
}
class PredPublicContractTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "Predicate rename external relation"
 it should "preserve branch shadow and wakeup relationships without fixed predicate encoding" in {
  implicit val p:Parameters=new WithNLargeBooms(1)++new freechips.rocketchip.system.BaseConfig
  assert(Driver.execute(Array("--backend-name","firrtl","--test-seed","1","--target-dir",sys.props.getOrElse("cpu.eval.pred.target","test_run_dir/pred-contract")),()=>LazyModule(new PredContractHarness).module)(c=>new PredContractTester(c)))
 }
}
