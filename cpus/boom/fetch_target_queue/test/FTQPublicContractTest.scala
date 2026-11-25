// Copyright (c) 2015 - 2019, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSES/license-texts/BOOM-BSD-3-Clause-2012-2020.txt and
// LICENSES/license-texts/SiFive-Apache-2.0.txt for license details.
// CPU-Eval modifies the FTQ interface declarations to bind fixture widths.
// The stimulus and assertions are CPU-Eval-authored; see THIRD_PARTY_NOTICES.md.
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
import boom.exu._
class FTQContractHarness(implicit p:Parameters) extends LazyModule {
 val visibilityNode=TLEphemeralNode()
 val client=TLClientNode(Seq(TLMasterPortParameters.v1(Seq(TLMasterParameters.v1(name="client",sourceId=IdRange(0,32),supportsProbe=TransferSizes(64))))))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(BigInt("80000000",16),BigInt("0000ffff",16))),regionType=RegionType.CACHED,supportsGet=TransferSizes(1,64),supportsPutFull=TransferSizes(1,64),supportsPutPartial=TransferSizes(1,64),supportsAcquireB=TransferSizes(64),supportsAcquireT=TransferSizes(64))),beatBytes=16,endSinkId=4)))
 DisableMonitors { implicit p => manager := visibilityNode := client }
 lazy val module=new FTQContractHarnessModule(this)
}
class FTQContractHarnessModule(outer:FTQContractHarness) extends LazyModuleImp(outer) {
 for((out,_)<-outer.client.out){out.a.valid:=false.B;out.a.bits:=0.U.asTypeOf(out.a.bits);out.c.valid:=false.B;out.c.bits:=0.U.asTypeOf(out.c.bits);out.e.valid:=false.B;out.e.bits:=0.U.asTypeOf(out.e.bits);out.b.ready:=true.B;out.d.ready:=true.B}
 for((in,_)<-outer.manager.in){in.a.ready:=true.B;in.c.ready:=true.B;in.e.ready:=true.B;in.b.valid:=false.B;in.b.bits:=0.U.asTypeOf(in.b.bits);in.d.valid:=false.B;in.d.bits:=0.U.asTypeOf(in.d.bits)}
 private val tile=p(TilesLocated(InSubsystem)).collectFirst{case a:BoomTileAttachParams=>a.tileParams}.get
 implicit val testP:Parameters=p.alterPartial{case TileKey=>tile;case TileVisibilityNodeKey=>outer.visibilityNode}
 val dut=Module(new FetchTargetQueue())
 val io=IO(new BoomBundle()(testP) {
 val enq=Flipped(Decoupled(new FetchBundle()(testP) {override val bpd_meta=Vec(nBanks,UInt(bpdMaxMetaLength.W))}))
 val enq_idx=Output(UInt(log2Ceil(ftqSz).W))
 val deq=Flipped(Valid(UInt(log2Ceil(ftqSz).W)))
 val get_ftq_pc=Vec(2,new GetPCFromFtqIO()(testP))
 val debug_ftq_idx=Input(Vec(coreWidth,UInt(log2Ceil(ftqSz).W)))
 val debug_fetch_pc=Output(Vec(coreWidth,UInt(vaddrBitsExtended.W)))
 val redirect=Input(Valid(UInt(log2Ceil(ftqSz).W)))
 val brupdate=Input(new BrUpdateInfo()(testP) {override val b2=new BrResolutionInfo()(testP) {override val target_offset=SInt(21.W)}})
 val bpdupdate=Output(Valid(new BranchPredictionUpdate()(testP)))
 val ras_update=Output(Bool());val ras_update_idx=Output(UInt(log2Ceil(nRasEntries).W));val ras_update_pc=Output(UInt(vaddrBitsExtended.W))
 })
 io <> dut.io
}

class FTQContractTester(c:FTQContractHarnessModule) extends PeekPokeTester(c) {
 def zero(x:Data):Unit=x match {case b:Bundle=>b.elements.values.foreach(zero);case v:Vec[_]=>v.foreach(y=>zero(y));case u:UInt=>poke(u,0);case s:SInt=>poke(s,0)}
 val pc=BigInt("80000000",16)
 var retirementAllowed=false
 val commitRows=scala.collection.mutable.ArrayBuffer[(BigInt,BigInt,BigInt,BigInt,BigInt)]()
 def tick(n:Int):Unit=for(i<-0 until n){
  step(1)
  if(peek(c.io.bpdupdate.valid)==1 && peek(c.io.bpdupdate.bits.is_mispredict_update)==0 && peek(c.io.bpdupdate.bits.is_repair_update)==0 && peek(c.io.bpdupdate.bits.pc)==pc && (peek(c.io.bpdupdate.bits.cfi_idx.valid)==1 || peek(c.io.bpdupdate.bits.br_mask)!=0)){
   assert(retirementAllowed,"commit-labelled predictor update requires a prior retirement index")
   commitRows+=((peek(c.io.bpdupdate.bits.pc),peek(c.io.bpdupdate.bits.target),peek(c.io.bpdupdate.bits.cfi_idx.bits),peek(c.io.bpdupdate.bits.cfi_taken),peek(c.io.bpdupdate.bits.ghist.ras_idx)))
  }
 }
 poke(c.io.enq.valid,0);zero(c.io.enq.bits);poke(c.io.deq.valid,0);poke(c.io.deq.bits,0)
 poke(c.io.redirect.valid,0);poke(c.io.redirect.bits,0);zero(c.io.brupdate)
 zero(c.io.debug_ftq_idx)
 for(i<-0 until 2)poke(c.io.get_ftq_pc(i).ftq_idx,1)
 reset(5)
 tick(3)
 def enqueue(base:BigInt,call:Int,idx:Int,ghistOverride:Int,cfiValid:Int=1,branchMask:Int=1,rasTop:BigInt=0):Int={
  var stalls=0;while(peek(c.io.enq.ready)==0 && stalls<20){tick(1);stalls+=1};assert(peek(c.io.enq.ready)==1,"legal enqueue eventually ready")
  val q=peek(c.io.enq_idx).toInt
  zero(c.io.enq.bits);poke(c.io.enq.bits.pc,base);poke(c.io.enq.bits.mask,255)
  poke(c.io.enq.bits.cfi_idx.valid,cfiValid);poke(c.io.enq.bits.cfi_idx.bits,idx)
  poke(c.io.enq.bits.cfi_type,if(call==1)2 else 1);poke(c.io.enq.bits.cfi_is_call,call)
  poke(c.io.enq.bits.cfi_npc_plus4,1);poke(c.io.enq.bits.br_mask,branchMask)
  poke(c.io.enq.bits.ras_top,rasTop)
  poke(c.io.enq.bits.ghist.ras_idx,5)
  poke(c.io.enq.bits.ghist.current_saw_branch_not_taken,ghistOverride)
  poke(c.io.enq.valid,1);tick(1);poke(c.io.enq.valid,0);q
 }
 val boot=enqueue(pc-64,0,0,1,0,0)
 retirementAllowed=true
 poke(c.io.deq.valid,1);poke(c.io.deq.bits,boot);tick(1);poke(c.io.deq.valid,0);tick(6)
 retirementAllowed=false
 val savedRasTop=pc+256
 val first=enqueue(pc,1,2,1,rasTop=savedRasTop)
 poke(c.io.get_ftq_pc(0).ftq_idx,first)
 val successor=enqueue(pc+64,0,0,0)
 assert(peek(c.io.get_ftq_pc(0).pc)==pc,"normal one-cycle PC")
 assert(peek(c.io.get_ftq_pc(0).next_val)==0 || peek(c.io.get_ftq_pc(0).next_pc)==pc+64,"normal successor PC")
 assert(peek(c.io.get_ftq_pc(0).entry.cfi_is_call)==1,"initial predicted call")
 val youngest=enqueue(pc+192,0,0,0)
 poke(c.io.redirect.valid,1);poke(c.io.redirect.bits,first)
 poke(c.io.brupdate.b2.mispredict,1);poke(c.io.brupdate.b2.uop.ftq_idx,first)
 poke(c.io.brupdate.b2.valid,1);poke(c.io.brupdate.b2.cfi_type,1);poke(c.io.brupdate.b2.pc_sel,1);poke(c.io.brupdate.b2.uop.is_br,1)
 poke(c.io.brupdate.b2.uop.pc_lob,0);poke(c.io.brupdate.b2.taken,1)
 val rasRepairs=scala.collection.mutable.ArrayBuffer[(BigInt,BigInt)]()
 def observeRasRepair():Unit={
  if(peek(c.io.ras_update)==1)
   rasRepairs+=((peek(c.io.ras_update_idx),peek(c.io.ras_update_pc)))
 }
 // Frontend clears its pending fetches on redirect and can read the RAS again
 // once the redirected request reaches stage 2.
 observeRasRepair()
 tick(1)
 poke(c.io.redirect.valid,0);poke(c.io.brupdate.b2.mispredict,0);poke(c.io.brupdate.b2.valid,0)
 observeRasRepair()
 tick(1)
 observeRasRepair()
 poke(c.io.get_ftq_pc(0).ftq_idx,first);tick(1)
 val call=peek(c.io.get_ftq_pc(0).entry.cfi_is_call)
 val next=enqueue(pc+128,0,0,0)
 poke(c.io.get_ftq_pc(1).ftq_idx,next);tick(1)
 val ras=peek(c.io.get_ftq_pc(1).ghist.ras_idx)
 assert(call==0,"redirect to earlier conditional branch must not retain later call")
 assert(ras==5,"conditional branch must not advance call stack position")
 assert(rasRepairs.nonEmpty && rasRepairs.forall(_==(BigInt(5),savedRasTop)),
  "redirect must restore the saved return address at its RAS index")
 retirementAllowed=true
 poke(c.io.deq.valid,1);poke(c.io.deq.bits,next);tick(1);poke(c.io.deq.valid,0);tick(64)
 val packetUpdates=commitRows.filter(_._1==pc)
 assert(packetUpdates.size==1,"the initialized retired packet produces one commit update")
 assert(packetUpdates.head==(pc,pc+128,BigInt(0),BigInt(1),BigInt(5)),"commit update preserves redirected CFI, successor target and original history")
}
class FTQPublicContractTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "FTQ redirect contract"
 it should "preserve synchronous PC and call identity after redirect" in {
 implicit val p:Parameters=new WithNLargeBooms(1)++new freechips.rocketchip.system.BaseConfig
 assert(Driver.execute(Array("--backend-name","firrtl","--test-seed","1","--target-dir",sys.props.getOrElse("cpu.eval.ftq.target","test_run_dir/ftq-public-contract")),()=>LazyModule(new FTQContractHarness).module)(c=>new FTQContractTester(c)))
 }
}
