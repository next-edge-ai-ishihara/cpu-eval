package boom.tests
import chisel3._
import chisel3.util._
import chisel3.iotesters.{Driver,PeekPokeTester}
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.subsystem.{InSubsystem,TilesLocated}
import freechips.rocketchip.tile.{TileKey,TileVisibilityNodeKey}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tilelink._
import boom.common._
import boom.exu._
class RobContractHarness(implicit p:Parameters) extends LazyModule {
 val tile=p(TilesLocated(InSubsystem)).collectFirst{case t:BoomTileAttachParams=>t.tileParams}.get
 val visibility=TLEphemeralNode()
 val client=TLClientNode(Seq(TLMasterPortParameters.v1(Seq(TLMasterParameters.v1(name="rob-contract",sourceId=IdRange(0,1))))))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(0,(BigInt(1)<<32)-1)),regionType=RegionType.UNCACHED,supportsGet=TransferSizes(1,8))),beatBytes=8)))
 manager:=visibility:=client
 val testP=p.alterPartial{case TileKey=>tile;case TileVisibilityNodeKey=>visibility}
 lazy val module=new RobContractHarnessModule(this)
}
class RobContractHarnessModule(outer:RobContractHarness) extends LazyModuleImp(outer) {
 val rob=Module(new Rob(3,1)(outer.testP))
 val io=IO(new Bundle{
  val ready=Output(Bool())
  val rob_tail_idx=Output(chiselTypeOf(rob.io.rob_tail_idx))
  val csr_stall=Input(Bool())
  val enq_valids=Input(chiselTypeOf(rob.io.enq_valids))
  val enq_uops=Input(chiselTypeOf(rob.io.enq_uops))
  val wb_resps=Input(chiselTypeOf(rob.io.wb_resps))
  val commit=Output(chiselTypeOf(rob.io.commit))
  val com_xcpt=Output(chiselTypeOf(rob.io.com_xcpt))
  val flush_valid=Output(Bool())
 })
 io.ready:=rob.io.ready;io.rob_tail_idx:=rob.io.rob_tail_idx
 rob.io.csr_stall:=io.csr_stall;rob.io.enq_valids:=io.enq_valids;rob.io.enq_uops:=io.enq_uops
 rob.io.wb_resps:=io.wb_resps;io.commit:=rob.io.commit;io.com_xcpt:=rob.io.com_xcpt
 io.flush_valid:=rob.io.flush.valid
 rob.io.enq_partial_stall:=false.B;rob.io.xcpt_fetch_pc:=0.U
 def tieZero(x:Data):Unit=x match{case b:Record=>b.elements.values.foreach(tieZero);case v:Vec[_]=>v.foreach(tieZero);case u:UInt=>u:=0.U;case s:SInt=>s:=0.S(21.W)}
 tieZero(rob.io.brupdate)
 rob.io.lsu_clr_bsy:=0.U.asTypeOf(rob.io.lsu_clr_bsy);rob.io.lsu_clr_unsafe:=0.U.asTypeOf(rob.io.lsu_clr_unsafe)
 rob.io.debug_wb_valids:=0.U.asTypeOf(rob.io.debug_wb_valids);rob.io.debug_wb_wdata:=0.U.asTypeOf(rob.io.debug_wb_wdata)
 rob.io.fflags:=0.U.asTypeOf(rob.io.fflags);rob.io.lxcpt:=0.U.asTypeOf(rob.io.lxcpt);rob.io.debug_tsc:=0.U
 for((tl,_)<-outer.client.out){tl.a.valid:=false.B;tl.a.bits:=0.U.asTypeOf(tl.a.bits);tl.d.ready:=true.B;tl.c.valid:=false.B;tl.c.bits:=0.U.asTypeOf(tl.c.bits);tl.e.valid:=false.B;tl.e.bits:=0.U.asTypeOf(tl.e.bits);tl.b.ready:=true.B}
 for((tl,_)<-outer.manager.in){tl.a.ready:=true.B;tl.d.valid:=false.B;tl.d.bits:=0.U.asTypeOf(tl.d.bits);tl.c.ready:=true.B;tl.e.ready:=true.B;tl.b.valid:=false.B;tl.b.bits:=0.U.asTypeOf(tl.b.bits)}
}
class RobContractTester(c:RobContractHarnessModule) extends PeekPokeTester(c) {
 def zero(x:Data):Unit=x match {case b:Record=>b.elements.values.foreach(zero);case v:Vec[_]=>v.foreach(zero);case u:UInt=>poke(u,0);case s:SInt=>poke(s,0)}
 zero(c.io);reset(5);step(3)
 for(round<-0 until 8){
  var wait=0
  while(peek(c.io.ready)==0 && wait<128){step(1);wait+=1}
  if(peek(c.io.ready)==0)throw new RuntimeException("CPU_EVAL_PROGRESS_BUDGET: ready")
  val tail=peek(c.io.rob_tail_idx)
  poke(c.io.csr_stall,1)
  for(i<-0 until 3){poke(c.io.enq_valids(i),1);poke(c.io.enq_uops(i).rob_idx,tail+i);poke(c.io.enq_uops(i).pdst,round*3+i+1)}
  step(1)
  for(i<-0 until 3){poke(c.io.enq_valids(i),0);poke(c.io.wb_resps(i).valid,1);poke(c.io.wb_resps(i).bits.uop.rob_idx,tail+i)}
  step(1)
  for(i<-0 until 3)poke(c.io.wb_resps(i).valid,0)
  step(round%4+1)
  for(i<-0 until 3)assert(peek(c.io.commit.valids(i))==0,"CSR stall must suppress commit")
  poke(c.io.csr_stall,0)
  for(i<-0 until 3){
   assert(peek(c.io.commit.valids(i))==1,"greedy completed row retirement")
   assert(peek(c.io.commit.arch_valids(i))==1,"ordinary completed instruction architecturally retires")
   assert(peek(c.io.commit.uops(i).rob_idx)==tail+i,"retire original row in order")
  }
  step(1)
  assert((0 until 3).forall(i=>peek(c.io.commit.valids(i))==0),"no duplicate retirement")
 }
 val tail=peek(c.io.rob_tail_idx)
 poke(c.io.enq_valids(0),1);poke(c.io.enq_uops(0).rob_idx,tail);poke(c.io.enq_uops(0).exception,1);poke(c.io.enq_uops(0).exc_cause,3)
 step(1);poke(c.io.enq_valids(0),0)
 var seen=false
 for(i<-0 until 16){
  assert((0 until 3).forall(j=>peek(c.io.commit.arch_valids(j))==0),"exception does not architecturally retire")
  if(peek(c.io.com_xcpt.valid)==1){
   assert(peek(c.io.com_xcpt.bits.cause)==3,"original exception cause")
   assert(peek(c.io.flush_valid)==1,"reported exception must flush in the same cycle")
   seen=true
  }
  step(1)
 }
 if(!seen)throw new RuntimeException("CPU_EVAL_PROGRESS_BUDGET: exception observation")
 println("ROB_PUBLIC_RELATION_PASS")
}
class RobPublicContractTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "ROB public retirement"
 it should "greedily retire a completed row, honor CSR stall, and flush a reported exception" in {
 implicit val p:Parameters=new boom.common.WithNLargeBooms(1) ++ new freechips.rocketchip.system.BaseConfig
 assert(Driver.execute(Array("--backend-name","treadle","--target-dir",sys.props.getOrElse("cpu.eval.rob.target","target/cpu-eval-rob-public")),()=>LazyModule(new RobContractHarness).module){c=>new RobContractTester(c)})
 }
}
