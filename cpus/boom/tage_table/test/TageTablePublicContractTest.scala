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
import boom.ifu._
class TageContractHarness(implicit p:Parameters) extends LazyModule {
 val visibilityNode=TLEphemeralNode()
 val client=TLClientNode(Seq(TLMasterPortParameters.v1(Seq(TLMasterParameters.v1(name="client",sourceId=IdRange(0,32),supportsProbe=TransferSizes(64))))))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(BigInt("80000000",16),BigInt("0000ffff",16))),regionType=RegionType.CACHED,supportsGet=TransferSizes(1,64),supportsPutFull=TransferSizes(1,64),supportsPutPartial=TransferSizes(1,64),supportsAcquireB=TransferSizes(64),supportsAcquireT=TransferSizes(64))),beatBytes=16,endSinkId=4)))
 DisableMonitors { implicit p => manager := visibilityNode := client }
 lazy val module=new TageContractHarnessModule(this)
}
class TageContractHarnessModule(outer:TageContractHarness) extends LazyModuleImp(outer) {
 for((out,_)<-outer.client.out){out.a.valid:=false.B;out.a.bits:=0.U.asTypeOf(out.a.bits);out.c.valid:=false.B;out.c.bits:=0.U.asTypeOf(out.c.bits);out.e.valid:=false.B;out.e.bits:=0.U.asTypeOf(out.e.bits);out.b.ready:=true.B;out.d.ready:=true.B}
 for((in,_)<-outer.manager.in){in.a.ready:=true.B;in.c.ready:=true.B;in.e.ready:=true.B;in.b.valid:=false.B;in.b.bits:=0.U.asTypeOf(in.b.bits);in.d.valid:=false.B;in.d.bits:=0.U.asTypeOf(in.d.bits)}
 private val originalTile=p(TilesLocated(InSubsystem)).collectFirst{case a:BoomTileAttachParams=>a.tileParams}.get
 private val tile=originalTile.copy(core=originalTile.core.copy(globalHistoryLength=64,bpdMaxMetaLength=64))
 implicit val testP:Parameters=p.alterPartial{case TileKey=>tile;case TileVisibilityNodeKey=>outer.visibilityNode}
 val dut=Module(new TageTable(128,7,2,2048))
 val io=IO(new Bundle {
  val f1_req_valid=Input(Bool());val f1_req_pc=Input(UInt(40.W));val f1_req_ghist=Input(UInt(64.W))
  val f3_resp=Output(Vec(4,Valid(new TageResp)))
  val update_mask=Input(Vec(4,Bool()));val update_taken=Input(Vec(4,Bool()));val update_alloc=Input(Vec(4,Bool()));val update_old_ctr=Input(Vec(4,UInt(3.W)))
  val update_pc=Input(UInt(40.W));val update_hist=Input(UInt(64.W))
  val update_u_mask=Input(Vec(4,Bool()));val update_u=Input(Vec(4,UInt(2.W)))
 })
 io <> dut.io
}
class TageTableContractTester(c:TageContractHarnessModule) extends PeekPokeTester(c){
 def zero(x:Data):Unit=x match {case b:Bundle=>b.elements.values.foreach(zero);case v:Vec[_]=>v.foreach(y=>zero(y));case u:UInt=>poke(u,0);case s:SInt=>poke(s,0)}
 zero(c.io);reset(5);step(132)
 def query(pc:BigInt,hist:BigInt,valid:Boolean,ctr:Int,u:Int):Unit={
  poke(c.io.f1_req_pc,pc);poke(c.io.f1_req_ghist,hist);poke(c.io.f1_req_valid,1);step(2)
  assert(peek(c.io.f3_resp(0).valid)==(if(valid)1 else 0),"initialized tag/hash match")
  if(valid){assert(peek(c.io.f3_resp(0).bits.ctr)==ctr,"prediction counter after accepted update")}
  assert(peek(c.io.f3_resp(0).bits.u)==u,"selected row usefulness, including on a miss")
  poke(c.io.f1_req_valid,0);step(2)
 }
 def update(pc:BigInt,hist:BigInt,alloc:Boolean,taken:Boolean,old:Int,u:Int):Unit={
  poke(c.io.update_pc,pc);poke(c.io.update_hist,hist);poke(c.io.update_mask(0),1);poke(c.io.update_taken(0),if(taken)1 else 0);poke(c.io.update_alloc(0),if(alloc)1 else 0);poke(c.io.update_old_ctr(0),old);poke(c.io.update_u_mask(0),1);poke(c.io.update_u(0),u);step(1)
  zero(c.io.update_mask);zero(c.io.update_u_mask);step(2)
 }
 val pc=BigInt("80000100",16)
 query(pc,1,false,0,0)
 update(pc,1,true,true,0,2);query(pc,1,true,4,2);query(pc,2,false,0,0)
 // One table span in bytes changes the tag and preserves the row.
 val aliasPc = pc + 128 * 16
 query(aliasPc,1,false,0,2)
 // Change usefulness only. The original entry must keep its tag and counter.
 poke(c.io.update_pc,aliasPc)
 poke(c.io.update_hist,1)
 poke(c.io.update_u_mask(0),1)
 poke(c.io.update_u(0),3)
 step(1)
 zero(c.io.update_u_mask)
 step(2)
 query(aliasPc,1,false,0,3)
 query(pc,1,true,4,3)
 update(pc,1,false,true,4,3);query(pc,1,true,5,3)
 update(pc,1,false,false,5,1);query(pc,1,true,4,1)
 for(i<-0 until 10)update(pc,1,false,true,4,0)
 query(pc,1,true,7,0)
 for(i<-0 until 10)update(pc,1,false,false,7,0)
 query(pc,1,true,0,0)
 update(pc+16,2,true,false,0,3);query(pc+16,2,true,3,3)
 zero(c.io);reset(5);step(132)
 def laneUpdate(lane:Int,alloc:Boolean,old:Int):Unit={
  zero(c.io.update_mask);zero(c.io.update_alloc);zero(c.io.update_old_ctr)
  poke(c.io.update_pc,pc);poke(c.io.update_hist,1)
  poke(c.io.update_mask(lane),1);poke(c.io.update_alloc(lane),if(alloc)1 else 0)
  poke(c.io.update_taken(lane),1);poke(c.io.update_old_ctr(lane),old)
  if(lane==1 && !alloc){poke(c.io.update_mask(0),1);poke(c.io.update_taken(0),0);poke(c.io.update_old_ctr(0),4)}
  step(1)
  zero(c.io.update_mask);step(2)
 }
 laneUpdate(1,true,0)
 laneUpdate(0,true,0)
 laneUpdate(1,false,4)
 poke(c.io.f1_req_pc,pc);poke(c.io.f1_req_ghist,1);poke(c.io.f1_req_valid,1);step(2)
 assert(peek(c.io.f3_resp(1).valid)==1,"lane1 valid entry")
 assert(peek(c.io.f3_resp(1).bits.ctr)==5,"unmasked lane cannot replace accepted lane1 counter")
}
class TageTablePublicContractTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "TAGE table public relationships"
 it should "preserve accepted lookup and training relationships" in {
  implicit val p:Parameters=new boom.common.WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
  assert(Driver.execute(Array("--backend-name","treadle","--target-dir",sys.props.getOrElse("cpu.eval.tage.target",sys.env.getOrElse("CPU_EVAL_TAGE_TARGET","test_run_dir"))),()=>LazyModule(new TageContractHarness).module){c=>new TageTableContractTester(c)})
 }
}
