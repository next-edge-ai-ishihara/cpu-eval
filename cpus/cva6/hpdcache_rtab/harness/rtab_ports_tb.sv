module testbench;
import hpdcache_pkg::*;
`include "hpdcache_typedef.svh"
// The HPDcache configuration and RTAB types that cv32a60x instantiates.
function automatic hpdcache_cfg_t config_value();
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
localparam hpdcache_cfg_t C=config_value();
`HPDCACHE_TYPEDEF_REQ_ATTR_T(off_t,word_t,wordbe_t,data_t,be_t,sid_t,tid_t,tag_t,C);
`HPDCACHE_TYPEDEF_REQ_T(req_t,off_t,data_t,be_t,sid_t,tid_t,tag_t);
typedef logic [29:0] nline_t;
typedef logic [1:0] ptr_t;
typedef logic [0:0] way_t;
typedef struct packed {req_t req;logic from_rtab;logic is_error;logic err_scrubbing;} x_t;
typedef struct packed {x_t req;way_t way_fetch;} entry_t;
logic clk=0;always #5 clk=~clk;
logic rst=0,empty,full,fence,check=0,hit,alloc=0,link=0,popv,try_pop=0,commit=0,rollback=0;
logic[29:0] checkline=0,refillline=0,flushline=0;
ptr_t popped,committed=0,rolled=0;
entry_t newreq,returned;
hpdcache_rtab_deps_t deps;
logic[33:0] waddr;logic wread;
logic hopen=0,hpend=0,hsent=0,wnotready=0,missready=0,refill=0,refillerror=0,refillway=0,flushack=0,flushready=0,nopending=0;
hpdcache_rtab #(.HPDcacheCfg(C),.hpdcache_nline_t(nline_t),.hpdcache_way_t(way_t),.hpdcache_req_addr_t(logic[33:0]),.rtab_ptr_t(ptr_t),.rtab_cnt_t(logic[2:0]),.rtab_entry_t(entry_t)) dut(
.clk_i(clk),.rst_ni(rst),.empty_o(empty),.full_o(full),.fence_o(fence),.check_i(check),.check_nline_i(checkline),.check_hit_o(hit),
.alloc_i(alloc),.alloc_and_link_i(link),.alloc_req_i(newreq),.alloc_deps_i(deps),
.pop_try_valid_o(popv),.pop_try_i(try_pop),.pop_try_req_o(returned),.pop_try_ptr_o(popped),
.pop_commit_i(commit),.pop_commit_ptr_i(committed),.pop_rback_i(rollback),.pop_rback_ptr_i(rolled),
.wbuf_addr_o(waddr),.wbuf_is_read_o(wread),.wbuf_hit_open_i(hopen),.wbuf_hit_pend_i(hpend),.wbuf_hit_sent_i(hsent),.wbuf_not_ready_i(wnotready),
.miss_ready_i(missready),.refill_i(refill),.refill_is_error_i(refillerror),.refill_nline_i(refillline),.refill_way_index_i(refillway),
.flush_ack_i(flushack),.flush_ack_nline_i(flushline),.flush_ready_i(flushready),.cfg_single_entry_i(1'b0),.no_pend_trans_i(nopending));
task automatic step(); @(posedge clk);#1;@(negedge clk);endtask
function automatic entry_t request(input logic[33:0] address,input int id);
entry_t e;e='0;e.req.req.addr_tag=address[33:10];e.req.req.addr_offset=address[9:0];e.req.req.op=HPDCACHE_REQ_LOAD;e.req.req.size=3'd2;e.req.req.sid=sid_t'(id);return e;
endfunction
task automatic add(input logic[33:0] address,input int id,input hpdcache_rtab_deps_t d,input bit is_link,
                   input hpdcache_req_size_t size=3'd2);
newreq=request(address,id);
newreq.req.req.size=size;
deps=d;check=1;checkline=address[33:4];alloc=!is_link;link=is_link;step();alloc=0;link=0;check=0;
endtask
task automatic take_and_commit(input int id,input hpdcache_req_size_t size=3'd2);
int cycles;cycles=0;while(!popv && cycles<20)begin step();cycles++;end
if(!popv || returned.req.req.sid!==sid_t'(id))$fatal(1,"FAIL pop expected sid %0d valid=%0d sid=%0d",id,popv,returned.req.req.sid);
if(returned.req.req.size!==size)$fatal(1,"FAIL replayed request size expected %0d got %0d",size,returned.req.req.size);
committed=popped;try_pop=1;step();try_pop=0;commit=1;step();commit=0;
endtask
initial begin
int mode;hpdcache_rtab_deps_t d;ptr_t rp;newreq='0;deps='0;
if(!$value$plusargs("mode=%d",mode))mode=0;
step();step();rst=1;step();
if(!empty || full || fence)$fatal(1,"FAIL reset");
case(mode)
0:begin
d='0;d.mshr_hit=1;add(34'h1000,1,d,0);
d='0;add(34'h1000,2,d,1,3'd1);
refillline=30'h100;refill=1;step();refill=0;
take_and_commit(1);take_and_commit(2,3'd1);step();
if(!empty)$fatal(1,"FAIL linked FIFO final empty");
$display("PASS linked same-line FIFO and commit");
end
1:begin
hopen=1;d='0;d.wbuf_hit=1;add(34'h1000,1,d,0);
d='0;d.pend_trans=1;add(34'h2000,2,d,0);
if(!fence)$fatal(1,"FAIL pending fence signal");
hopen=0;nopending=1;
take_and_commit(1);take_and_commit(2);step();
if(!empty || fence)$fatal(1,"FAIL fence completion");
$display("PASS older retained request precedes fence after write buffer becomes empty");
end
2:begin
d='0;add(34'h1000,1,d,0);
if(!popv)$fatal(1,"FAIL ready request");rp=popped;
try_pop=1;step();try_pop=0;
rolled=rp;newreq=request(34'h1000,1);newreq.way_fetch=1;deps='0;deps.mshr_ready=1;rollback=1;step();rollback=0;
step();if(popv)$fatal(1,"FAIL rollback dependency held");
missready=1;step();missready=0;step();
if(!popv || returned.way_fetch!==1'b1)$fatal(1,"FAIL rollback updated way_fetch valid=%0d way=%0d",popv,returned.way_fetch);
take_and_commit(1);step();if(!empty)$fatal(1,"FAIL rollback completion");
$display("PASS rollback retains order and updates shared request input way_fetch");
end
3:begin
d='0;d.mshr_full=1;add(34'h1000,1,d,0);add(34'h2000,2,d,0);
refillline=30'h300;refill=1;step();refill=0;
begin
int cycles, first_id;cycles=0;
while(!popv && cycles<20)begin step();cycles++;end
if(!popv)$fatal(1,"FAIL resource first waiter");
first_id=int'(returned.req.req.sid);
if(first_id!=1 && first_id!=2)$fatal(1,"FAIL unknown resource waiter");
take_and_commit(first_id);step();$display("OBS after one released resource second_valid=%0d",popv);
refillline=30'h400;refill=1;step();refill=0;
take_and_commit(first_id==1 ? 2 : 1);step();
if(!empty)$fatal(1,"FAIL resource waiters completion");
end
$display("PASS two resource releases retire both waiting heads without fixed release-count condition");
end
endcase
$finish;
end
endmodule
