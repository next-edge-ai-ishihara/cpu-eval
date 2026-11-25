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
 val dut=Module(new TageBranchPredictorBank())
 val io=IO(chiselTypeOf(dut.io))
 io <> dut.io
}
class TageBankContractTester(c:TageContractHarnessModule) extends PeekPokeTester(c){
 def zero(x:Data):Unit=x match {case b:Bundle=>b.elements.values.foreach(zero);case v:Vec[_]=>v.foreach(y=>zero(y));case u:UInt=>poke(u,0);case s:SInt=>poke(s,0)}
 zero(c.io);reset(5);step(260)
 def query(pc:BigInt,base:Int):(BigInt,BigInt)={
  poke(c.io.f0_pc,pc);poke(c.io.f0_valid,1);poke(c.io.f0_mask,15);poke(c.io.f1_ghist,0);poke(c.io.resp_in(0).f3(0).taken,base)
  step(4);val result=(peek(c.io.resp.f3(0).taken),peek(c.io.f3_meta));poke(c.io.f0_valid,0);step(4);result
 }
 def update(pc:BigInt,meta:BigInt,taken:Int,mis:Int):Unit={
  zero(c.io.update);poke(c.io.update.valid,1);poke(c.io.update.bits.pc,pc);poke(c.io.update.bits.ghist,0);poke(c.io.update.bits.meta,meta)
  poke(c.io.update.bits.br_mask,1);poke(c.io.update.bits.cfi_idx.valid,1);poke(c.io.update.bits.cfi_idx.bits,0)
  poke(c.io.update.bits.cfi_is_br,1);poke(c.io.update.bits.cfi_taken,taken);poke(c.io.update.bits.cfi_mispredicted,mis)
  step(1);zero(c.io.update);step(4)
 }
 val pc=BigInt("80000000",16)
 assert(query(pc,0)._1==0,"unmatched input not-taken passes through")
 assert(query(pc,1)._1==1,"unmatched input taken passes through")
 val untouched=pc+2048
 for(_<-0 until 3){val q=query(untouched,0);assert(q._1==0,"correct untrained prediction");update(untouched,q._2,0,0)}
 assert(query(untouched,1)._1==1,"correct commit without provider cannot allocate a new tagged entry")
 for(_<-0 until 6){val q=query(pc,0);update(pc,q._2,1,if(q._1==0)1 else 0)}
 assert(query(pc,0)._1==1,"accepted taken training yields taken provider")
 for(_<-0 until 10){val q=query(pc,0);update(pc,q._2,0,if(q._1==1)1 else 0)}
 assert(query(pc,1)._1==0,"accepted not-taken training overrides incoming taken")
}
class TageBankPublicContractTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "TAGE bank public relationships"
 it should "preserve opaque-metadata commit training and prediction" in {
  implicit val p:Parameters=new boom.common.WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
  assert(Driver.execute(Array("--backend-name","treadle","--target-dir",sys.props.getOrElse("cpu.eval.tage.target",sys.env.getOrElse("CPU_EVAL_TAGE_TARGET","test_run_dir"))),()=>LazyModule(new TageContractHarness).module){c=>new TageBankContractTester(c)})
 }
}
