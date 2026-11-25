// SPDX-License-Identifier: Apache-2.0
module memctrl_probe (
  input logic clk_i,
  input logic start,
  output bit finished
);
import hpdcache_pkg::*;
logic rst_ni = 0;
// The HPDcache configuration that cv32a60x instantiates.
function automatic hpdcache_cfg_t cfg();
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
localparam hpdcache_cfg_t HPDcacheCfg=cfg();
typedef logic[23:0] hpdcache_tag_t;typedef logic[29:0] hpdcache_nline_t;typedef logic[5:0] hpdcache_set_t;typedef logic[1:0] hpdcache_word_t;typedef logic[1:0] hpdcache_way_vector_t;
typedef struct packed {logic valid,wback,dirty,fetch;hpdcache_tag_t tag;} hpdcache_dir_entry_t;
typedef logic[31:0] hpdcache_data_word_t;typedef logic[3:0] hpdcache_data_be_t;typedef logic[0:0][31:0] hpdcache_req_data_t;typedef logic[0:0][3:0] hpdcache_req_be_t;typedef logic[1:0][31:0] hpdcache_access_data_t;typedef logic[1:0][3:0] hpdcache_access_be_t;
logic ready_o;
logic rd_wr_conflict_o;
logic dir_match_i;
hpdcache_set_t dir_match_set_i;
hpdcache_tag_t dir_match_tag_i;
logic dir_updt_sel_victim_i;
hpdcache_way_vector_t dir_hit_way_o;
hpdcache_tag_t dir_hit_tag_o;
logic dir_hit_wback_o;
logic dir_hit_dirty_o;
logic dir_hit_fetch_o;
logic dir_updt_i;
hpdcache_set_t dir_updt_set_i;
hpdcache_way_vector_t dir_updt_way_i;
hpdcache_tag_t dir_updt_tag_i;
logic dir_updt_valid_i;
logic dir_updt_wback_i;
logic dir_updt_dirty_i;
logic dir_updt_fetch_i;
logic dir_refill_i;
hpdcache_set_t dir_refill_set_i;
hpdcache_way_vector_t dir_refill_way_i;
hpdcache_dir_entry_t dir_refill_entry_i;
logic dir_refill_updt_sel_victim_i;
logic dir_victim_sel_i;
hpdcache_set_t dir_victim_set_i;
logic dir_victim_valid_o;
logic dir_victim_wback_o;
logic dir_victim_dirty_o;
hpdcache_tag_t dir_victim_tag_o;
hpdcache_way_vector_t dir_victim_way_o;
logic dir_inval_check_i;
hpdcache_nline_t dir_inval_nline_i;
logic dir_inval_write_i;
logic dir_inval_hit_o;
logic dir_cmo_check_entry_i;
hpdcache_set_t dir_cmo_check_entry_set_i;
hpdcache_way_vector_t dir_cmo_check_entry_way_i;
logic dir_cmo_check_entry_valid_o;
logic dir_cmo_check_entry_wback_o;
logic dir_cmo_check_entry_dirty_o;
hpdcache_tag_t dir_cmo_check_entry_tag_o;
logic dir_cmo_updt_i;
hpdcache_set_t dir_cmo_updt_set_i;
hpdcache_way_vector_t dir_cmo_updt_way_i;
hpdcache_tag_t dir_cmo_updt_tag_i;
logic dir_cmo_updt_valid_i;
logic dir_cmo_updt_wback_i;
logic dir_cmo_updt_dirty_i;
logic dir_cmo_updt_fetch_i;
hpdcache_way_vector_t dir_err_cor_o;
hpdcache_way_vector_t dir_err_unc_o;
hpdcache_way_vector_t dir_err_valid_o;
hpdcache_way_vector_t dir_err_dirty_o;
hpdcache_set_t dir_err_set_i;
hpdcache_way_vector_t dir_err_way_i;
logic dir_err_read_i;
hpdcache_dir_entry_t dir_err_rdata_o;
logic dir_err_write_i;
hpdcache_dir_entry_t dir_err_wdata_i;
logic data_req_read_i;
hpdcache_set_t data_req_read_set_i;
hpdcache_req_size_t data_req_read_size_i;
hpdcache_word_t data_req_read_word_i;
hpdcache_way_vector_t data_req_read_way_i;
hpdcache_req_data_t data_req_read_data_o;
logic data_req_write_i;
logic data_req_write_enable_i;
logic data_req_write_merge_i;
hpdcache_set_t data_req_write_set_i;
hpdcache_way_vector_t data_req_write_way_i;
hpdcache_req_size_t data_req_write_size_i;
hpdcache_word_t data_req_write_word_i;
hpdcache_req_data_t data_req_write_data_i;
hpdcache_req_be_t data_req_write_be_i;
logic data_amo_write_i;
logic data_amo_write_enable_i;
hpdcache_set_t data_amo_write_set_i;
hpdcache_req_size_t data_amo_write_size_i;
hpdcache_word_t data_amo_write_word_i;
hpdcache_way_vector_t data_amo_write_way_i;
hpdcache_req_data_t data_amo_write_data_i;
hpdcache_req_be_t data_amo_write_be_i;
logic data_flush_read_i;
hpdcache_set_t data_flush_read_set_i;
hpdcache_word_t data_flush_read_word_i;
hpdcache_way_vector_t data_flush_read_way_i;
hpdcache_access_data_t data_flush_read_data_o;
logic data_refill_i;
hpdcache_set_t data_refill_set_i;
hpdcache_way_vector_t data_refill_way_i;
hpdcache_word_t data_refill_word_i;
hpdcache_access_data_t data_refill_data_i;
hpdcache_way_vector_t data_err_cor_o;
hpdcache_way_vector_t data_err_unc_o;
hpdcache_set_t data_err_set_i;
hpdcache_way_vector_t data_err_way_i;
hpdcache_word_t data_err_word_i;
logic data_err_read_i;
hpdcache_access_data_t data_err_rdata_o;
logic data_err_write_i;
hpdcache_access_data_t data_err_wdata_i;
hpdcache_memctrl #(.HPDcacheCfg(HPDcacheCfg),.hpdcache_tag_t(hpdcache_tag_t),.hpdcache_nline_t(hpdcache_nline_t),.hpdcache_set_t(hpdcache_set_t),.hpdcache_word_t(hpdcache_word_t),.hpdcache_way_vector_t(hpdcache_way_vector_t),.hpdcache_dir_entry_t(hpdcache_dir_entry_t),.hpdcache_data_word_t(hpdcache_data_word_t),.hpdcache_data_be_t(hpdcache_data_be_t),.hpdcache_req_data_t(hpdcache_req_data_t),.hpdcache_req_be_t(hpdcache_req_be_t),.hpdcache_access_data_t(hpdcache_access_data_t),.hpdcache_access_be_t(hpdcache_access_be_t)) dut (.clk_i(clk_i),
.rst_ni(rst_ni),
.ready_o(ready_o),
.rd_wr_conflict_o(rd_wr_conflict_o),
.dir_match_i(dir_match_i),
.dir_match_set_i(dir_match_set_i),
.dir_match_tag_i(dir_match_tag_i),
.dir_updt_sel_victim_i(dir_updt_sel_victim_i),
.dir_hit_way_o(dir_hit_way_o),
.dir_hit_tag_o(dir_hit_tag_o),
.dir_hit_wback_o(dir_hit_wback_o),
.dir_hit_dirty_o(dir_hit_dirty_o),
.dir_hit_fetch_o(dir_hit_fetch_o),
.dir_updt_i(dir_updt_i),
.dir_updt_set_i(dir_updt_set_i),
.dir_updt_way_i(dir_updt_way_i),
.dir_updt_tag_i(dir_updt_tag_i),
.dir_updt_valid_i(dir_updt_valid_i),
.dir_updt_wback_i(dir_updt_wback_i),
.dir_updt_dirty_i(dir_updt_dirty_i),
.dir_updt_fetch_i(dir_updt_fetch_i),
.dir_refill_i(dir_refill_i),
.dir_refill_set_i(dir_refill_set_i),
.dir_refill_way_i(dir_refill_way_i),
.dir_refill_entry_i(dir_refill_entry_i),
.dir_refill_updt_sel_victim_i(dir_refill_updt_sel_victim_i),
.dir_victim_sel_i(dir_victim_sel_i),
.dir_victim_set_i(dir_victim_set_i),
.dir_victim_valid_o(dir_victim_valid_o),
.dir_victim_wback_o(dir_victim_wback_o),
.dir_victim_dirty_o(dir_victim_dirty_o),
.dir_victim_tag_o(dir_victim_tag_o),
.dir_victim_way_o(dir_victim_way_o),
.dir_inval_check_i(dir_inval_check_i),
.dir_inval_nline_i(dir_inval_nline_i),
.dir_inval_write_i(dir_inval_write_i),
.dir_inval_hit_o(dir_inval_hit_o),
.dir_cmo_check_entry_i(dir_cmo_check_entry_i),
.dir_cmo_check_entry_set_i(dir_cmo_check_entry_set_i),
.dir_cmo_check_entry_way_i(dir_cmo_check_entry_way_i),
.dir_cmo_check_entry_valid_o(dir_cmo_check_entry_valid_o),
.dir_cmo_check_entry_wback_o(dir_cmo_check_entry_wback_o),
.dir_cmo_check_entry_dirty_o(dir_cmo_check_entry_dirty_o),
.dir_cmo_check_entry_tag_o(dir_cmo_check_entry_tag_o),
.dir_cmo_updt_i(dir_cmo_updt_i),
.dir_cmo_updt_set_i(dir_cmo_updt_set_i),
.dir_cmo_updt_way_i(dir_cmo_updt_way_i),
.dir_cmo_updt_tag_i(dir_cmo_updt_tag_i),
.dir_cmo_updt_valid_i(dir_cmo_updt_valid_i),
.dir_cmo_updt_wback_i(dir_cmo_updt_wback_i),
.dir_cmo_updt_dirty_i(dir_cmo_updt_dirty_i),
.dir_cmo_updt_fetch_i(dir_cmo_updt_fetch_i),
.dir_err_cor_o(dir_err_cor_o),
.dir_err_unc_o(dir_err_unc_o),
.dir_err_valid_o(dir_err_valid_o),
.dir_err_dirty_o(dir_err_dirty_o),
.dir_err_set_i(dir_err_set_i),
.dir_err_way_i(dir_err_way_i),
.dir_err_read_i(dir_err_read_i),
.dir_err_rdata_o(dir_err_rdata_o),
.dir_err_write_i(dir_err_write_i),
.dir_err_wdata_i(dir_err_wdata_i),
.data_req_read_i(data_req_read_i),
.data_req_read_set_i(data_req_read_set_i),
.data_req_read_size_i(data_req_read_size_i),
.data_req_read_word_i(data_req_read_word_i),
.data_req_read_way_i(data_req_read_way_i),
.data_req_read_data_o(data_req_read_data_o),
.data_req_write_i(data_req_write_i),
.data_req_write_enable_i(data_req_write_enable_i),
.data_req_write_merge_i(data_req_write_merge_i),
.data_req_write_set_i(data_req_write_set_i),
.data_req_write_way_i(data_req_write_way_i),
.data_req_write_size_i(data_req_write_size_i),
.data_req_write_word_i(data_req_write_word_i),
.data_req_write_data_i(data_req_write_data_i),
.data_req_write_be_i(data_req_write_be_i),
.data_amo_write_i(data_amo_write_i),
.data_amo_write_enable_i(data_amo_write_enable_i),
.data_amo_write_set_i(data_amo_write_set_i),
.data_amo_write_size_i(data_amo_write_size_i),
.data_amo_write_word_i(data_amo_write_word_i),
.data_amo_write_way_i(data_amo_write_way_i),
.data_amo_write_data_i(data_amo_write_data_i),
.data_amo_write_be_i(data_amo_write_be_i),
.data_flush_read_i(data_flush_read_i),
.data_flush_read_set_i(data_flush_read_set_i),
.data_flush_read_word_i(data_flush_read_word_i),
.data_flush_read_way_i(data_flush_read_way_i),
.data_flush_read_data_o(data_flush_read_data_o),
.data_refill_i(data_refill_i),
.data_refill_set_i(data_refill_set_i),
.data_refill_way_i(data_refill_way_i),
.data_refill_word_i(data_refill_word_i),
.data_refill_data_i(data_refill_data_i),
.data_err_cor_o(data_err_cor_o),
.data_err_unc_o(data_err_unc_o),
.data_err_set_i(data_err_set_i),
.data_err_way_i(data_err_way_i),
.data_err_word_i(data_err_word_i),
.data_err_read_i(data_err_read_i),
.data_err_rdata_o(data_err_rdata_o),
.data_err_write_i(data_err_write_i),
.data_err_wdata_i(data_err_wdata_i));
task tick;@(posedge clk_i);#1;endtask
initial begin
dir_match_i='0;
dir_match_set_i='0;
dir_match_tag_i='0;
dir_updt_sel_victim_i='0;
dir_updt_i='0;
dir_updt_set_i='0;
dir_updt_way_i='0;
dir_updt_tag_i='0;
dir_updt_valid_i='0;
dir_updt_wback_i='0;
dir_updt_dirty_i='0;
dir_updt_fetch_i='0;
dir_refill_i='0;
dir_refill_set_i='0;
dir_refill_way_i='0;
dir_refill_entry_i='0;
dir_refill_updt_sel_victim_i='0;
dir_victim_sel_i='0;
dir_victim_set_i='0;
dir_inval_check_i='0;
dir_inval_nline_i='0;
dir_inval_write_i='0;
dir_cmo_check_entry_i='0;
dir_cmo_check_entry_set_i='0;
dir_cmo_check_entry_way_i='0;
dir_cmo_updt_i='0;
dir_cmo_updt_set_i='0;
dir_cmo_updt_way_i='0;
dir_cmo_updt_tag_i='0;
dir_cmo_updt_valid_i='0;
dir_cmo_updt_wback_i='0;
dir_cmo_updt_dirty_i='0;
dir_cmo_updt_fetch_i='0;
dir_err_set_i='0;
dir_err_way_i='0;
dir_err_read_i='0;
dir_err_write_i='0;
dir_err_wdata_i='0;
data_req_read_i='0;
data_req_read_set_i='0;
data_req_read_size_i='0;
data_req_read_word_i='0;
data_req_read_way_i='0;
data_req_write_i='0;
data_req_write_enable_i='0;
data_req_write_merge_i='0;
data_req_write_set_i='0;
data_req_write_way_i='0;
data_req_write_size_i='0;
data_req_write_word_i='0;
data_req_write_data_i='0;
data_req_write_be_i='0;
data_amo_write_i='0;
data_amo_write_enable_i='0;
data_amo_write_set_i='0;
data_amo_write_size_i='0;
data_amo_write_word_i='0;
data_amo_write_way_i='0;
data_amo_write_data_i='0;
data_amo_write_be_i='0;
data_flush_read_i='0;
data_flush_read_set_i='0;
data_flush_read_word_i='0;
data_flush_read_way_i='0;
data_refill_i='0;
data_refill_set_i='0;
data_refill_way_i='0;
data_refill_word_i='0;
data_refill_data_i='0;
data_err_set_i='0;
data_err_way_i='0;
data_err_word_i='0;
data_err_read_i='0;
data_err_write_i='0;
data_err_wdata_i='0;
tick();@(negedge clk_i);rst_ni=1;begin integer cycles; cycles=0; while(!ready_o && cycles<1000)begin tick();cycles++;end end
if(!ready_o)$fatal(1,"directory initialization did not complete");
wait (start);
$display("ready=%0d",ready_o);
@(negedge clk_i);dir_refill_i=1;dir_refill_set_i=3;dir_refill_way_i=1;dir_refill_entry_i='{valid:1,wback:0,dirty:0,fetch:0,tag:24'd7};data_refill_i=1;data_refill_set_i=3;data_refill_way_i=1;data_refill_word_i=0;data_refill_data_i=64'hbbbb2222aaaa1111;tick();
@(negedge clk_i);dir_refill_i=0;data_refill_i=0;dir_match_i=1;dir_match_set_i=3;dir_match_tag_i=7;data_req_read_i=1;data_req_read_set_i=3;data_req_read_word_i=0;data_req_read_size_i=2;data_req_read_way_i=1;tick();$display("hit=%0d read0=%08x",dir_hit_way_o,data_req_read_data_o); if(dir_hit_way_o!==2'b01 || data_req_read_data_o!==32'haaaa1111)$fatal(1,"refill lookup or first word differs");
@(negedge clk_i);data_req_read_word_i=1;tick();$display("read1=%08x",data_req_read_data_o); if(data_req_read_data_o!==32'hbbbb2222)$fatal(1,"second refill word differs");
@(negedge clk_i);dir_match_i=0;data_req_read_i=0;data_req_write_i=1;data_req_write_enable_i=1;data_req_write_set_i=3;data_req_write_way_i=1;data_req_write_word_i=0;data_req_write_size_i=0;data_req_write_data_i=32'hffee0099;data_req_write_be_i=1;data_req_write_merge_i=0;tick();
@(negedge clk_i);data_req_write_i=0;data_req_read_i=1;data_req_read_word_i=0;tick();$display("partial=%08x",data_req_read_data_o); if(data_req_read_data_o!==32'haaaa1199)$fatal(1,"disabled byte lanes were overwritten");
finished = 1;
end
endmodule

module testbench;
  logic clk = 0;
  bit refill_complete;
  always #5 clk = ~clk;
  memctrl_probe refill (.clk_i(clk), .start(1'b1), .finished(refill_complete));
  initial begin
    wait (refill_complete);
    $display("PASS: refill, lookup, and byte-enable preservation matched");
    $finish;
  end
endmodule
