// SPDX-License-Identifier: Apache-2.0
module testbench;
import hpdcache_pkg::*;
// The HPDcache configuration and types that cv32a60x instantiates.
function automatic hpdcache_cfg_t configuration();
  hpdcache_user_cfg_t u;
  u.nRequesters = 5; u.paWidth = 34; u.wordWidth = 32; u.sets = 64; u.ways = 2; u.clWords = 4;
  u.reqWords = 1; u.reqTransIdWidth = 1; u.reqSrcIdWidth = 3;
  u.victimSel = HPDCACHE_VICTIM_RANDOM; u.dataWaysPerRamWord = 2; u.dataSetsPerRam = 64;
  u.dataRamByteEnable = 1; u.accessWords = 2; u.mshrSets = 1; u.mshrWays = 2;
  u.mshrWaysPerRamWord = 2; u.mshrSetsPerRam = 1; u.mshrRamByteEnable = 1;
  u.mshrUseRegbank = 1; u.cbufEntries = 8; u.refillCoreRspFeedthrough = 1;
  u.refillFifoDepth = 4; u.wbufDirEntries = 8; u.wbufDataEntries = 8; u.wbufWords = 1;
  u.wbufTimecntWidth = 3; u.rtabEntries = 4; u.flushEntries = 8; u.flushFifoDepth = 8;
  u.memAddrWidth = 64; u.memIdWidth = 4; u.memDataWidth = 64; u.wtEn = 1; u.wbEn = 0;
  u.lowLatency = 1; u.eccEn = 0; u.eccScrubberEn = 0;
  return hpdcacheBuildConfig(u);
endfunction
localparam hpdcache_cfg_t C=configuration();
logic clk=0;always #5 clk=~clk;
logic rst=0,empty,full,check=0,hit,alloc=0,alloccs=0,afull,away,ack=0,ackcs=0,ackway=0;
logic[5:0] cset=0,aset;logic[23:0] ctag=0,atag;
logic[29:0] newline=0;logic tid=0,rtid;logic[2:0] sid=0,rsid,cb=0,rcb;logic[1:0] wordidx=0,rword;logic victim=0,rvictim,needrsp=1,prefetch=0,wback=0,dirty=0,rneed,rpre,rwb,rdirty;
hpdcache_mshr #(.HPDcacheCfg(C),.hpdcache_nline_t(logic[29:0]),.hpdcache_tag_t(logic[23:0]),.hpdcache_set_t(logic[5:0]),.hpdcache_word_t(logic[1:0]),.hpdcache_way_t(logic[0:0]),.hpdcache_req_tid_t(logic[0:0]),.hpdcache_req_sid_t(logic[2:0]),.mshr_way_t(logic[0:0]),.mshr_set_t(logic[0:0]),.cbuf_id_t(logic[2:0])) dut(
.clk_i(clk),.rst_ni(rst),.empty_o(empty),.full_o(full),.check_i(check),.check_set_i(cset),.check_tag_i(ctag),.hit_o(hit),
.alloc_i(alloc),.alloc_cs_i(alloccs),.alloc_nline_i(newline),.alloc_req_id_i(tid),.alloc_src_id_i(sid),.alloc_word_i(wordidx),.alloc_victim_way_i(victim),.alloc_need_rsp_i(needrsp),.alloc_is_prefetch_i(prefetch),.alloc_wback_i(wback),.alloc_dirty_i(dirty),.alloc_cbuf_id_i(cb),.alloc_full_o(afull),.alloc_way_o(away),
.ack_i(ack),.ack_cs_i(ackcs),.ack_set_i(1'b0),.ack_way_i(ackway),.ack_req_id_o(rtid),.ack_src_id_o(rsid),.ack_cache_set_o(aset),.ack_cache_way_o(rvictim),.ack_cache_tag_o(atag),.ack_word_o(rword),.ack_need_rsp_o(rneed),.ack_is_prefetch_o(rpre),.ack_wback_o(rwb),.ack_dirty_o(rdirty),.ack_cbuf_id_o(rcb));
task automatic step();@(posedge clk);#1;@(negedge clk);endtask
task automatic add(input logic[23:0] tag,input logic[5:0] setval,input int id,
                   input logic[2:0] source_id,output logic allocated);
newline={tag,setval};tid=id[0];sid=source_id;wordidx=2'(id);victim=id[0];cb=0;alloc=1;alloccs=1;#1;allocated=away;step();alloc=0;alloccs=0;
endtask
initial begin
int mode;logic firstway,secondway;
if(!$value$plusargs("mode=%d",mode))mode=0;
step();step();rst=1;step();if(!empty || full)$fatal(1,"FAIL reset");
add(24'h15,6'd1,5,3'd1,firstway);add(24'h22,6'd2,6,3'd2,secondway);
if(firstway===secondway || !full || empty)$fatal(1,"FAIL capacity or allocation identities");
if(mode==0)begin
check=1;cset=1;ctag=24'h22;step();
cset=2;ctag=24'h15;#1;
if(hit!==1)$fatal(1,"FAIL st0 set A and st1 tag A hit");
step();cset=3;ctag=24'h22;#1;
if(hit!==1)$fatal(1,"FAIL st0 set B and st1 tag B hit");
check=0;$display("PASS staged check compares prior set and current tag");
end else begin
check=0;ackcs=1;ackway=secondway;#1;
if(aset!==6'd2)$fatal(1,"FAIL grant-cycle ack cache set expected2 actual%0d",aset);
ack=1;step();ack=0;ackcs=0;
if(rsid!==3'd2)$fatal(1,"FAIL source ID B expected 2 actual %0d",rsid);
if(rtid!==0 || rword!==2 || rvictim!==0 || atag!==24'h22 || rneed!==1 || rpre!==0)$fatal(1,"FAIL acknowledged payload B");
ackway=firstway;ackcs=1;#1;if(aset!==1)$fatal(1,"FAIL next ack set A");ack=1;step();ack=0;ackcs=0;
if(rsid!==3'd1)$fatal(1,"FAIL source ID A expected 1 actual %0d",rsid);
if(rtid!==1 || rword!==1 || rvictim!==1 || atag!==24'h15 || !empty)$fatal(1,"FAIL acknowledged payload A and release");
$display("PASS grant-cycle set and subsequent ack payload release");
end
$finish;
end
endmodule
