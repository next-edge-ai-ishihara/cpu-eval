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
class IssueContractHarness(implicit p:Parameters) extends LazyModule {
 val visibilityNode=TLEphemeralNode()
 val client=TLClientNode(Seq(TLMasterPortParameters.v1(Seq(TLMasterParameters.v1(name="client",sourceId=IdRange(0,32),supportsProbe=TransferSizes(64))))))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(BigInt("80000000",16),BigInt("0000ffff",16))),regionType=RegionType.CACHED,supportsGet=TransferSizes(1,64),supportsPutFull=TransferSizes(1,64),supportsPutPartial=TransferSizes(1,64),supportsAcquireB=TransferSizes(64),supportsAcquireT=TransferSizes(64))),beatBytes=16,endSinkId=4)))
 DisableMonitors { implicit p => manager := visibilityNode := client }
 lazy val module=new IssueContractHarnessModule(this)
}
class IssueContractHarnessModule(outer:IssueContractHarness) extends LazyModuleImp(outer) {
 for((out,_)<-outer.client.out){out.a.valid:=false.B;out.a.bits:=0.U.asTypeOf(out.a.bits);out.c.valid:=false.B;out.c.bits:=0.U.asTypeOf(out.c.bits);out.e.valid:=false.B;out.e.bits:=0.U.asTypeOf(out.e.bits);out.b.ready:=true.B;out.d.ready:=true.B}
 for((in,_)<-outer.manager.in){in.a.ready:=true.B;in.c.ready:=true.B;in.e.ready:=true.B;in.b.valid:=false.B;in.b.bits:=0.U.asTypeOf(in.b.bits);in.d.valid:=false.B;in.d.bits:=0.U.asTypeOf(in.d.bits)}
 private val tile=p(TilesLocated(InSubsystem)).collectFirst{case a:BoomTileAttachParams=>a.tileParams}.get
 implicit val testP:Parameters=p.alterPartial{case TileKey=>tile;case TileVisibilityNodeKey=>outer.visibilityNode}
 val dut=Module(new boom.exu.IssueUnitCollapsing(boom.exu.IssueParams(issueWidth=3,numEntries=32,iqType=boom.common.IQT_INT.litValue,dispatchWidth=3),7))
 val io=IO(new IssueUnitIO(3,7,3) { override val brupdate=Input(new BrUpdateInfo()(testP) { override val b2=new BrResolutionInfo()(testP) { override val target_offset=SInt(21.W) } }) })
 io <> dut.io
}

class IssueContractTester(c:IssueContractHarnessModule) extends PeekPokeTester(c) {
 def zero(x:Data):Unit=x match {case b:Bundle=>b.elements.values.foreach(zero);case v:Vec[_]=>v.foreach(y=>zero(y));case u:UInt=>poke(u,0);case s:SInt=>poke(s,0)}
 for(u<-c.io.dis_uops){poke(u.valid,0);zero(u.bits)}
 zero(c.io.brupdate);zero(c.io.wakeup_ports);zero(c.io.pred_wakeup_port);zero(c.io.spec_ld_wakeup)
 poke(c.io.flush_pipeline,0);poke(c.io.ld_miss,0);poke(c.io.tsc_reg,0)
 for(f<-c.io.fu_types)poke(f,0)
 reset(5);step(4)
 def dispatch(ids:Seq[Int], divideFirst:Boolean=false):Unit={
  var n=0;while(ids.indices.exists(i=>peek(c.io.dis_uops(i).ready)==0) && n<20){step(1);n+=1}
  assert(ids.indices.forall(i=>peek(c.io.dis_uops(i).ready)==1),"dispatch eventual readiness")
  for(i<-ids.indices){
   val u=c.io.dis_uops(i)
   val divide=divideFirst && i==0
   zero(u.bits)
   poke(u.bits.uopc,if(divide)boom.common.uopDIV.litValue else boom.common.uopADD.litValue)
   poke(u.bits.iq_type,boom.common.IQT_INT.litValue)
   poke(u.bits.fu_code,if(divide)boom.exu.FUConstants.FU_DIV.litValue else boom.exu.FUConstants.FU_ALU.litValue)
   poke(u.bits.prs1,10);poke(u.bits.prs1_busy,1);poke(u.bits.debug_inst,ids(i))
   poke(u.bits.lrs1_rtype,boom.common.RT_FIX.litValue)
   poke(u.bits.lrs2_rtype,if(divideFirst)boom.common.RT_FIX.litValue else boom.common.RT_X.litValue)
   if(divideFirst){
    poke(u.bits.prs2,11);poke(u.bits.dst_rtype,boom.common.RT_FIX.litValue)
    poke(u.bits.pdst,20+i);poke(u.bits.ldst_val,1)
   }
   poke(u.valid,1)
  }
  step(1);for(u<-c.io.dis_uops)poke(u.valid,0);step(4)
 }
 def wakeOperands():Unit={
  poke(c.io.wakeup_ports(0).valid,1);poke(c.io.wakeup_ports(0).bits.pdst,10);poke(c.io.wakeup_ports(0).bits.poisoned,0)
  step(1);poke(c.io.wakeup_ports(0).valid,0)
 }
 def issuedOperations():Seq[(Int,Int)]={
  val issued=c.io.iss_valids.indices.filter(i=>peek(c.io.iss_valids(i))==1)
  for(i<-issued){assert((peek(c.io.iss_uops(i).fu_code)&peek(c.io.fu_types(i)))!=0,"functional unit compatibility")}
  issued.map(i=>(i,peek(c.io.iss_uops(i).debug_inst).toInt))
 }
 for(round<-0 until 16){
 reset(5);step(4)
 for(f<-c.io.fu_types)poke(f,0)
 dispatch(Seq(101,102,103));dispatch(Seq(104,105,106))
 assert(peek(c.io.event_empty)==0,"accepted busy operations retained")
 step(2);assert(c.io.iss_valids.indices.forall(i=>peek(c.io.iss_valids(i))==0),"busy source cannot issue")
 wakeOperands();step(2+round)
 for(f<-c.io.fu_types)poke(f,boom.exu.FUConstants.FU_ALU.litValue)
 assert(c.io.iss_valids.indices.count(i=>peek(c.io.iss_valids(i))==1)==3,"available static-priority ports select retained ready operations")
 val seen=scala.collection.mutable.ArrayBuffer[Int]();var n=0
 while(seen.size<6 && n<20){
  if(seen.nonEmpty && seen.size<6)assert(c.io.iss_valids.indices.count(i=>peek(c.io.iss_valids(i))==1)==3,"available ports select pending ready operations")
  seen ++= issuedOperations().map(_._2).sorted
  step(1);n+=1
 }
 assert(seen.toSeq==Seq(101,102,103,104,105,106),"oldest accepted operation first; no loss or duplicate")
 step(4);assert(peek(c.io.event_empty)==1,"drained accepted operations")
 step(round)
 }
 for(f<-c.io.fu_types)poke(f,0);dispatch(Seq(201,202));poke(c.io.flush_pipeline,1);step(1);poke(c.io.flush_pipeline,0);step(4)
 assert(peek(c.io.event_empty)==1,"flush invalidates retained operations")

 import boom.exu.FUConstants._
 val alu=FU_ALU.litValue
 // Large BOOM integer execution ports while the divider is busy.
 val masks=Seq(alu|FU_JMP.litValue,alu|FU_CSR.litValue|FU_I2F.litValue,alu|FU_MUL.litValue)
 for(i<-masks.indices)poke(c.io.fu_types(i),masks(i))
 dispatch(Seq(301,302,303),divideFirst=true)
 wakeOperands()
 val whileBusy=issuedOperations().map(_._2).sorted
 assert(whileBusy==Seq(302,303),s"available ALUs must issue despite a busy divider: got ${whileBusy.mkString(",")}")
 step(1)
 assert(issuedOperations().isEmpty && peek(c.io.event_empty)==0,"blocked divide remains pending without issuing")
 poke(c.io.fu_types(0),masks(0)|FU_DIV.litValue)
 assert(issuedOperations()==Seq((0,301)),"retained divide issues on its compatible port")
 step(1);step(4)
 assert(peek(c.io.event_empty)==1,"drained mixed operations")
}
class IssuePublicContractTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "Issue queue public scheduling"
 it should "preserve accepted age, wakeup, compatibility and flush" in {
 implicit val p:Parameters=new WithNLargeBooms(1)++new freechips.rocketchip.system.BaseConfig
 assert(Driver.execute(Array("--backend-name","firrtl","--test-seed","1","--target-dir",sys.props.getOrElse("cpu.eval.issue.target","test_run_dir/issue-public-contract")),()=>LazyModule(new IssueContractHarness).module)(c=>new IssueContractTester(c)))
 }
}
