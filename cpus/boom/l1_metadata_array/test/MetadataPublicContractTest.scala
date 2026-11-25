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
class MetadataContractHarness(implicit p:Parameters) extends LazyModule {
 val visibilityNode=TLEphemeralNode()
 val client=TLClientNode(Seq(TLMasterPortParameters.v1(Seq(TLMasterParameters.v1(name="metadata-test",sourceId=IdRange(0,32),supportsProbe=TransferSizes(64))))))
 val manager=TLManagerNode(Seq(TLSlavePortParameters.v1(Seq(TLSlaveParameters.v1(address=Seq(AddressSet(BigInt("80000000",16),BigInt("0000ffff",16))),regionType=RegionType.CACHED,supportsGet=TransferSizes(1,64),supportsPutFull=TransferSizes(1,64),supportsPutPartial=TransferSizes(1,64),supportsAcquireB=TransferSizes(64),supportsAcquireT=TransferSizes(64))),beatBytes=16,endSinkId=4)))
 DisableMonitors { implicit p => manager := visibilityNode := client }
 lazy val module=new MetadataContractHarnessModule(this)
}
class MetadataContractHarnessModule(outer:MetadataContractHarness) extends LazyModuleImp(outer) {
 for((out,_)<-outer.client.out){out.a.valid:=false.B;out.a.bits:=0.U.asTypeOf(out.a.bits);out.c.valid:=false.B;out.c.bits:=0.U.asTypeOf(out.c.bits);out.e.valid:=false.B;out.e.bits:=0.U.asTypeOf(out.e.bits);out.b.ready:=true.B;out.d.ready:=true.B}
 for((in,_)<-outer.manager.in){in.a.ready:=true.B;in.c.ready:=true.B;in.e.ready:=true.B;in.b.valid:=false.B;in.b.bits:=0.U.asTypeOf(in.b.bits);in.d.valid:=false.B;in.d.bits:=0.U.asTypeOf(in.d.bits)}
 private val tile=p(TilesLocated(InSubsystem)).collectFirst{case a:BoomTileAttachParams=>a.tileParams}.get
 implicit val testP:Parameters=p.alterPartial{case TileKey=>tile;case TileVisibilityNodeKey=>outer.visibilityNode}
 implicit val edge:TLEdgeOut=outer.visibilityNode.edges.out.head
 val dut = Module(new L1MetadataArray(() => L1Metadata(0.U, ClientMetadata.onReset))(testP))
 val io = IO(new Bundle {
  val read = Flipped(Decoupled(new L1MetaReadReq()(testP)))
  val write = Flipped(Decoupled(new L1MetaWriteReq()(testP)))
  val resp = Output(Vec(8, new L1Metadata()(testP)))
 })
 io.read <> dut.io.read
 io.write <> dut.io.write
 io.resp := dut.io.resp
}
class MetadataContractTester(c:MetadataContractHarnessModule) extends PeekPokeTester(c) {
 def zero(x:Data):Unit=x match {
  case b:Record=>b.elements.values.foreach(zero)
  case v:Vec[_]=>v.foreach(zero)
  case u:UInt=>poke(u,0)
  case s:SInt=>poke(s,0)
 }
 poke(c.io.read.valid,0);zero(c.io.read.bits)
 poke(c.io.write.valid,0);zero(c.io.write.bits)
 reset(5)
 def waitReady(signal:Bool):Unit={
  var waits=0
  while(peek(signal)==0 && waits<512){step(1);waits+=1}
  if(peek(signal)==0)throw new RuntimeException("CPU_EVAL_PROGRESS_BUDGET: metadata request readiness")
 }
 val tags=Array.fill(64,8)(BigInt(0))
 val states=Array.fill(64,8)(BigInt(0))
 def checkResponse(index:Int):Unit={
  for(w<-0 until 8){
   expect(c.io.resp(w).tag,tags(index)(w),"metadata tag from accepted set")
   expect(c.io.resp(w).coh.state,states(index)(w),"metadata coherence from accepted set")
  }
 }
 def requestRead(index:Int,mask:Int=255,tag:Int=0):Unit={
  poke(c.io.read.bits.idx,index);poke(c.io.read.bits.way_en,mask);poke(c.io.read.bits.tag,tag)
  poke(c.io.read.valid,1)
 }
 def read(index:Int):Unit={
  requestRead(index);waitReady(c.io.read.ready);step(1);poke(c.io.read.valid,0)
  checkResponse(index)
 }
 def write(index:Int,mask:Int,tag:BigInt,state:BigInt):Unit={
  poke(c.io.write.bits.idx,index);poke(c.io.write.bits.way_en,mask)
  poke(c.io.write.bits.tag,0);poke(c.io.write.bits.data.tag,tag);poke(c.io.write.bits.data.coh.state,state)
  poke(c.io.write.valid,1);waitReady(c.io.write.ready);step(1);poke(c.io.write.valid,0)
  for(w<-0 until 8 if (mask&(1<<w))!=0){tags(index)(w)=tag;states(index)(w)=state}
 }
 for(i<-0 until 64)read(i)
 write(3,255,17,1);read(3);read(4)
 write(3,4,33,2);read(3);read(4)
 write(3,0,99,3);read(3)
 for(w<-0 until 8)write(4,1<<w,40+w,w%4)
 read(4);read(3)
 write(63,255,71,3);read(63);read(0)
 write(3,255,81,0);read(3);read(4)

 // Only idx selects the set, and the response belongs to the request accepted at the last edge.
 requestRead(3,0,123);waitReady(c.io.read.ready);step(1)
 requestRead(4,1,456);checkResponse(3)
 waitReady(c.io.read.ready);step(1)
 requestRead(63);poke(c.io.read.valid,0);checkResponse(4)

 reset(5)
 for(i<-0 until 64;w<-0 until 8){tags(i)(w)=0;states(i)(w)=0}
 for(i<-0 until 64)read(i)
 println("METADATA_PUBLIC_CONTRACT_COMPLETED")
}
class MetadataPublicContractTest extends org.scalatest.flatspec.AnyFlatSpec {
 behavior of "Cache metadata public ports"
 it should "preserve reset values masked writes and synchronous reads" in {
  implicit val p:Parameters=new WithNLargeBooms(1)++new freechips.rocketchip.system.BaseConfig
  assert(Driver.execute(Array("--backend-name","firrtl","--test-seed","1","--target-dir",sys.props.getOrElse("cpu.eval.metadata.target","test_run_dir/metadata-public-contract")),()=>LazyModule(new MetadataContractHarness).module)(c=>new MetadataContractTester(c)))
 }
}
