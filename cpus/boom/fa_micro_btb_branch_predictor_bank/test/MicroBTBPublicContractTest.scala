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
class MicroBTBContractHarness(implicit p:Parameters) extends LazyModule {
 val visibilityNode=TLEphemeralNode()
 val client=TLClientNode(Seq(TLMasterPortParameters.v1(Seq(TLMasterParameters.v1(name="btb",sourceId=IdRange(0,32),supportsProbe=TransferSizes(64))))))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(BigInt("80000000",16),BigInt("0000ffff",16))),regionType=RegionType.CACHED,supportsGet=TransferSizes(1,64),supportsPutFull=TransferSizes(1,64),supportsPutPartial=TransferSizes(1,64),supportsAcquireB=TransferSizes(64),supportsAcquireT=TransferSizes(64))),beatBytes=16,endSinkId=4)))
 DisableMonitors { implicit p => manager := visibilityNode := client }
 lazy val module=new MicroBTBContractHarnessModule(this)
}
class MicroBTBContractHarnessModule(outer:MicroBTBContractHarness) extends LazyModuleImp(outer) {
 for((out,_)<-outer.client.out){out.a.valid:=false.B;out.a.bits:=0.U.asTypeOf(out.a.bits);out.c.valid:=false.B;out.c.bits:=0.U.asTypeOf(out.c.bits);out.e.valid:=false.B;out.e.bits:=0.U.asTypeOf(out.e.bits);out.b.ready:=true.B;out.d.ready:=true.B}
 for((in,_)<-outer.manager.in){in.a.ready:=true.B;in.c.ready:=true.B;in.e.ready:=true.B;in.b.valid:=false.B;in.b.bits:=0.U.asTypeOf(in.b.bits);in.d.valid:=false.B;in.d.bits:=0.U.asTypeOf(in.d.bits)}
 private val tile=p(TilesLocated(InSubsystem)).collectFirst{case a:BoomTileAttachParams=>a.tileParams}.get
 implicit val testP:Parameters=p.alterPartial{case TileKey=>tile;case TileVisibilityNodeKey=>outer.visibilityNode}
 val dut=Module(new FAMicroBTBBranchPredictorBank())
 val io=IO(chiselTypeOf(dut.io))
 io <> dut.io
}

class MicroBTBContractTester(c:MicroBTBContractHarnessModule) extends PeekPokeTester(c) {
 val pc=BigInt("80000000",16)
 def update(base:BigInt,target:BigInt,taken:Int,idx:Int,br:Int,meta:BigInt,cfiValid:Int=1,mispredict:Int=0,repair:Int=0,btbCorrection:Int=0):Unit={
 poke(c.io.update.valid,1);poke(c.io.update.bits.pc,base);poke(c.io.update.bits.target,target)
 poke(c.io.update.bits.is_mispredict_update,mispredict);poke(c.io.update.bits.is_repair_update,repair)
 poke(c.io.update.bits.btb_mispredicts,btbCorrection);poke(c.io.update.bits.br_mask,br)
 poke(c.io.update.bits.cfi_idx.valid,cfiValid);poke(c.io.update.bits.cfi_idx.bits,idx)
 poke(c.io.update.bits.cfi_taken,taken);poke(c.io.update.bits.cfi_mispredicted,0)
 poke(c.io.update.bits.cfi_is_br,if(br!=0)1 else 0);poke(c.io.update.bits.cfi_is_jal,if(br==0)1 else 0);poke(c.io.update.bits.cfi_is_jalr,0)
 poke(c.io.update.bits.ghist,0);poke(c.io.update.bits.lhist,0);poke(c.io.update.bits.meta,meta)
 step(1);poke(c.io.update.valid,0);step(2)
 }
 def request(base:BigInt):BigInt={poke(c.io.f0_valid,1);poke(c.io.f0_pc,base);step(3);val m=peek(c.io.f3_meta);poke(c.io.f0_valid,0);m}
 poke(c.io.f0_valid,0);poke(c.io.f0_pc,pc);poke(c.io.f0_mask,15)
 poke(c.io.f1_ghist,0);poke(c.io.f1_lhist,0);poke(c.io.f3_fire,0);poke(c.io.update.valid,0)
 for(b<-c.io.resp_in.indices;s<-Seq(c.io.resp_in(b).f1,c.io.resp_in(b).f2,c.io.resp_in(b).f3);i<-s.indices){
 poke(s(i).taken,0);poke(s(i).is_br,0);poke(s(i).is_jal,0);poke(s(i).predicted_pc.valid,0);poke(s(i).predicted_pc.bits,0)}
 reset(5);step(4)
 println("MICRO_BTB_PUBLIC_CONTRACT_START")
 var m=request(pc)
 assert(peek(c.io.resp.f1(2).predicted_pc.valid)==0,"empty nonzero tag")
 update(pc,pc+64,1,2,4,m);m=request(pc)
 for(stage<-Seq(c.io.resp.f1,c.io.resp.f2,c.io.resp.f3)){
 assert(peek(stage(2).predicted_pc.valid)==1,"learned target valid")
 assert(peek(stage(2).predicted_pc.bits)==pc+64,"learned near target")
 assert(peek(stage(2).is_br)==1 && peek(stage(2).taken)==1,"conditional direction learned")}

 // A single-cycle hit must advance through the stages independently of the next request.
 val untrainedPc = pc + 0x800
 poke(c.io.f0_valid, 1)
 poke(c.io.f0_pc, pc)
 step(1)
 def expectHit(stage: BranchPrediction, label: String): Unit = {
   assert(peek(stage.predicted_pc.valid) == 1 && peek(stage.predicted_pc.bits) == pc + 64,
     s"MICRO_BTB_MISMATCH $label learned target")
 }
 def expectMiss(stage: BranchPrediction, label: String): Unit = {
   assert(peek(stage.predicted_pc.valid) == 0, s"MICRO_BTB_MISMATCH $label untrained target")
 }
 expectHit(c.io.resp.f1(2), "F1 for the first request")
 poke(c.io.f0_pc, untrainedPc)
 step(1)
 expectMiss(c.io.resp.f1(2), "F1 for the next request")
 expectHit(c.io.resp.f2(2), "F2 still for the first request")
 poke(c.io.f0_valid, 0)
 step(1)
 expectMiss(c.io.resp.f2(2), "F2 for the next request")
 expectHit(c.io.resp.f3(2), "F3 still for the first request")
 m = peek(c.io.f3_meta)
 step(1)
 expectMiss(c.io.resp.f3(2), "F3 for the next request")

 // Start from saturation to permit either taken-side initial counter value.
 for (_ <- 0 until 3) { update(pc, pc + 64, 1, 2, 4, m); m = request(pc) }
 update(pc, 0, 0, 2, 4, m, 0); m = request(pc)
 assert(peek(c.io.resp.f1(2).taken) == 1,
   "MICRO_BTB_MISMATCH one not-taken outcome must preserve a saturated taken prediction")
 update(pc, 0, 0, 2, 4, m, 0); m = request(pc)
 assert(peek(c.io.resp.f1(2).taken) == 0,
   "MICRO_BTB_MISMATCH the second not-taken outcome must change the taken prediction")
 for (_ <- 0 until 2) { update(pc, 0, 0, 2, 4, m, 0); m = request(pc) }
 assert(peek(c.io.resp.f1(2).taken)==0,"not-taken observations change conditional direction")
 assert(peek(c.io.resp.f1(2).predicted_pc.bits)==pc+64,"not-taken does not replace taken target")
 update(pc,pc+96,1,2,4,m,1,1,0);m=request(pc)
 assert(peek(c.io.resp.f1(2).predicted_pc.bits)==pc+64 && peek(c.io.resp.f1(2).taken)==0,"speculative update is not commit learning")
 update(pc,pc+96,1,2,4,m,1,0,1);m=request(pc)
 assert(peek(c.io.resp.f1(2).predicted_pc.bits)==pc+64 && peek(c.io.resp.f1(2).taken)==0,"repair update is not commit learning")
 update(pc, pc + 96, 1, 2, 4, m, btbCorrection = 4); m = request(pc)
 assert(peek(c.io.resp.f1(2).predicted_pc.bits) == pc + 64 && peek(c.io.resp.f1(2).taken) == 0,
   "MICRO_BTB_MISMATCH a BTB correction is not a commit update")
 val jp=pc+256;val jm=request(jp);update(jp,jp+96,1,1,0,jm);request(jp)
 assert(peek(c.io.resp.f1(1).is_jal)==1 && peek(c.io.resp.f1(1).taken)==1 && peek(c.io.resp.f1(1).predicted_pc.bits)==jp+96,"JAL target and direction")
}
class MicroBTBPublicContractTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "MicroBTB public learning"
 it should "learn committed targets and directions" in {
 implicit val p:Parameters=new WithNLargeBooms(1)++new freechips.rocketchip.system.BaseConfig
 assert(Driver.execute(Array("--backend-name","firrtl","--test-seed","1","--target-dir",sys.props.getOrElse("cpu.eval.micro.target","test_run_dir/micro-btb-public-contract")),()=>LazyModule(new MicroBTBContractHarness).module)(c=>new MicroBTBContractTester(c)))
 }
}
