package boom.tests
import chisel3._
import chisel3.iotesters.{Driver,PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.subsystem.{InSubsystem,TilesLocated}
import freechips.rocketchip.tile.{TileKey,TileVisibilityNodeKey}
import freechips.rocketchip.tilelink._
import boom.common._
import boom.ifu._
class BTBContractHarness(implicit p:Parameters) extends LazyModule {
 val visibilityNode=TLEphemeralNode()
 val client=TLClientNode(Seq(TLMasterPortParameters.v1(Seq(TLMasterParameters.v1(name="btb",sourceId=IdRange(0,32),supportsProbe=TransferSizes(64))))))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(BigInt("80000000",16),BigInt("0000ffff",16))),regionType=RegionType.CACHED,supportsGet=TransferSizes(1,64),supportsPutFull=TransferSizes(1,64),supportsPutPartial=TransferSizes(1,64),supportsAcquireB=TransferSizes(64),supportsAcquireT=TransferSizes(64))),beatBytes=16,endSinkId=4)))
 DisableMonitors { implicit p => manager := visibilityNode := client }
 lazy val module=new BTBContractHarnessModule(this)
}
class BTBContractHarnessModule(outer:BTBContractHarness) extends LazyModuleImp(outer) {
 for((out,_)<-outer.client.out){out.a.valid:=false.B;out.a.bits:=0.U.asTypeOf(out.a.bits);out.c.valid:=false.B;out.c.bits:=0.U.asTypeOf(out.c.bits);out.e.valid:=false.B;out.e.bits:=0.U.asTypeOf(out.e.bits);out.b.ready:=true.B;out.d.ready:=true.B}
 for((in,_)<-outer.manager.in){in.a.ready:=true.B;in.c.ready:=true.B;in.e.ready:=true.B;in.b.valid:=false.B;in.b.bits:=0.U.asTypeOf(in.b.bits);in.d.valid:=false.B;in.d.bits:=0.U.asTypeOf(in.d.bits)}
 private val tile=p(TilesLocated(InSubsystem)).collectFirst{case a:BoomTileAttachParams=>a.tileParams}.get
 implicit val testP:Parameters=p.alterPartial{case TileKey=>tile;case TileVisibilityNodeKey=>outer.visibilityNode}
 val dut=Module(new BTBBranchPredictorBank())
 val io=IO(chiselTypeOf(dut.io))
 io <> dut.io
}
class BTBContractTester(c:BTBContractHarnessModule) extends PeekPokeTester(c) {
 val pc=BigInt("80000000",16)
 def input(taken:Int=0):Unit={
  for(b<-c.io.resp_in.indices;s<-Seq(c.io.resp_in(b).f1,c.io.resp_in(b).f2,c.io.resp_in(b).f3);i<-s.indices){
   poke(s(i).taken,taken);poke(s(i).is_br,0);poke(s(i).is_jal,0);poke(s(i).predicted_pc.valid,0);poke(s(i).predicted_pc.bits,0)
  }
 }
 def update(base:BigInt,target:BigInt,taken:Int,idx:Int,br:Int,meta:BigInt,correction:Int=0):Unit={
  poke(c.io.update.valid,1);poke(c.io.update.bits.pc,base);poke(c.io.update.bits.target,target)
  poke(c.io.update.bits.is_mispredict_update,0);poke(c.io.update.bits.is_repair_update,0)
  poke(c.io.update.bits.btb_mispredicts,correction);poke(c.io.update.bits.br_mask,br)
  poke(c.io.update.bits.cfi_idx.valid,if(correction==0)1 else 0);poke(c.io.update.bits.cfi_idx.bits,idx)
  poke(c.io.update.bits.cfi_taken,taken);poke(c.io.update.bits.cfi_mispredicted,0)
  poke(c.io.update.bits.cfi_is_br,if(br!=0)1 else 0);poke(c.io.update.bits.cfi_is_jal,if(br==0)1 else 0);poke(c.io.update.bits.cfi_is_jalr,0)
  poke(c.io.update.bits.ghist,0);poke(c.io.update.bits.lhist,0);poke(c.io.update.bits.meta,meta)
  step(1);poke(c.io.update.valid,0);step(2)
 }
 def request(base:BigInt):BigInt={
  poke(c.io.f0_valid,1);poke(c.io.f0_pc,base);step(3)
  val m=peek(c.io.f3_meta);poke(c.io.f0_valid,0);m
 }
 poke(c.io.f0_valid,0);poke(c.io.f0_pc,pc);poke(c.io.f0_mask,15)
 poke(c.io.f1_ghist,0);poke(c.io.f1_lhist,0);poke(c.io.f3_fire,0);poke(c.io.update.valid,0)
 input();update(pc,pc+64,1,2,4,0);step(140)
 println("BTB_PUBLIC_CONTRACT_START")
 val missMeta=request(pc)
 assert(peek(c.io.resp.f2(2).predicted_pc.valid)==0,"empty high-tag lookup must preserve invalid input")
 update(pc,pc+64,1,2,4,missMeta)
 val learnedMeta=request(pc)
 assert(peek(c.io.resp.f1(2).predicted_pc.valid)==0,"F1 input response retained")
 assert(peek(c.io.resp.f2(2).predicted_pc.valid)==1,"committed taken branch target learned")
 assert(peek(c.io.resp.f2(2).predicted_pc.bits)==pc+64,"learned target value")
 assert(peek(c.io.resp.f2(2).is_br)==1 && peek(c.io.resp.f2(2).taken)==0,"conditional direction retained from incoming response")
 assert(peek(c.io.resp.f3(2).predicted_pc.bits)==pc+64 && peek(c.io.resp.f3(2).predicted_pc.valid)==1,"F3 learned target retained")
 update(pc,pc+16,0,2,4,learnedMeta)
 val keptMeta=request(pc)
 assert(peek(c.io.resp.f2(2).predicted_pc.bits)==pc+64,"not-taken successor must not overwrite taken target")
 input(1);request(pc)
 assert(peek(c.io.resp.f2(2).taken)==1,"incoming taken direction retained")
 val jp=pc+256
 input();val jm=request(jp);update(jp,jp+96,1,1,0,jm);val jLearned=request(jp)
 assert(peek(c.io.resp.f2(1).is_jal)==1 && peek(c.io.resp.f2(1).taken)==1,"learned JAL redirects independently of incoming direction")
 assert(peek(c.io.resp.f2(1).predicted_pc.bits)==jp+96,"JAL target")
 update(jp,jp-80,1,2,0,jLearned);val twoTargets=request(jp)
 assert(peek(c.io.resp.f2(1).predicted_pc.bits)==jp+96,"learning another slot preserves the existing JAL target")
 assert(peek(c.io.resp.f2(2).predicted_pc.valid)==1 && peek(c.io.resp.f2(2).predicted_pc.bits)==jp-80,"backward JAL target")
 update(jp,0,0,3,8,twoTargets,2);request(jp)
 assert(peek(c.io.resp.f2(1).predicted_pc.valid)==0,"BTB correction must remove erroneous learned target")
 assert(peek(c.io.resp.f2(2).predicted_pc.valid)==1 && peek(c.io.resp.f2(2).predicted_pc.bits)==jp-80,"BTB correction preserves the unmasked JAL target")
 val ep=pc+512
 val em=request(ep);update(ep,ep+65536,1,3,0,em);request(ep)
 assert(peek(c.io.resp.f2(3).predicted_pc.valid)==1 && peek(c.io.resp.f2(3).predicted_pc.bits)==ep+65536,"far jump target retained without offset truncation")
 val missPc=pc+16384
 input()
 poke(c.io.f0_valid,1);poke(c.io.f0_pc,pc);step(1)
 poke(c.io.f0_pc,jp);step(1)
 poke(c.io.f0_pc,missPc);step(1)
 assert(peek(c.io.resp.f2(2).predicted_pc.valid)==1 && peek(c.io.resp.f2(2).predicted_pc.bits)==jp-80,"F2 uses the second request")
 assert(peek(c.io.resp.f3(2).predicted_pc.valid)==1 && peek(c.io.resp.f3(2).predicted_pc.bits)==pc+64,"F3 uses the first request")
 input(1)
 poke(c.io.resp_in(0).f2(0).predicted_pc.valid,1);poke(c.io.resp_in(0).f2(0).predicted_pc.bits,123)
 poke(c.io.resp_in(0).f3(0).predicted_pc.valid,1);poke(c.io.resp_in(0).f3(0).predicted_pc.bits,456)
 request(missPc)
 assert(peek(c.io.resp.f2(0).predicted_pc.valid)==1 && peek(c.io.resp.f2(0).predicted_pc.bits)==123,"miss preserves incoming F2 target")
 assert(peek(c.io.resp.f3(0).predicted_pc.valid)==1 && peek(c.io.resp.f3(0).predicted_pc.bits)==456,"miss preserves incoming F3 target")
}
class BTBPublicContractTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "BTB public learning contract"
 it should "preserve target learning, input directions and correction semantics" in {
  implicit val p:Parameters=new WithNLargeBooms(1)++new freechips.rocketchip.system.BaseConfig
  assert(Driver.execute(Array("--backend-name","verilator","--target-dir",sys.props.getOrElse("cpu.eval.btb.target","test_run_dir/btb-public-contract")),()=>LazyModule(new BTBContractHarness).module)(c=>new BTBContractTester(c)))
 }
}
