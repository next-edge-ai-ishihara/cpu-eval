// SPDX-License-Identifier: Apache-2.0
module testbench;
// The HPDcache configuration that cv32a60x instantiates.
function automatic hpdcache_pkg::hpdcache_cfg_t cfg();
  hpdcache_pkg::hpdcache_user_cfg_t u;
  u.nRequesters = 5; u.paWidth = 34; u.wordWidth = 32; u.sets = 64; u.ways = 2; u.clWords = 4;
  u.reqWords = 1; u.reqTransIdWidth = 1; u.reqSrcIdWidth = 3;
  u.victimSel = hpdcache_pkg::HPDCACHE_VICTIM_RANDOM; u.dataWaysPerRamWord = 2;
  u.dataSetsPerRam = 64; u.dataRamByteEnable = 1; u.accessWords = 2; u.mshrSets = 1;
  u.mshrWays = 2; u.mshrWaysPerRamWord = 2; u.mshrSetsPerRam = 1; u.mshrRamByteEnable = 1;
  u.mshrUseRegbank = 1; u.cbufEntries = 8; u.refillCoreRspFeedthrough = 1;
  u.refillFifoDepth = 4; u.wbufDirEntries = 8; u.wbufDataEntries = 8; u.wbufWords = 1;
  u.wbufTimecntWidth = 3; u.rtabEntries = 4; u.flushEntries = 8; u.flushFifoDepth = 8;
  u.memAddrWidth = 64; u.memIdWidth = 4; u.memDataWidth = 64; u.wtEn = 1; u.wbEn = 0;
  u.lowLatency = 1; u.eccEn = 0; u.eccScrubberEn = 0;
  return hpdcache_pkg::hpdcacheBuildConfig(u);
endfunction
logic core_req_valid_i;
logic core_req_ready_o;
logic scrub_req_valid_i;
logic scrub_req_ready_o;
logic rtab_req_valid_i;
logic rtab_req_ready_o;
logic refill_req_valid_i;
logic refill_req_ready_o;
logic st0_req_is_error_i;
logic st0_req_is_uncacheable_i;
logic st0_req_need_rsp_i;
logic st0_req_is_load_i;
logic st0_req_is_scrub_i;
logic st0_req_is_store_i;
logic st0_req_is_amo_i;
logic st0_req_is_cmo_fence_i;
logic st0_req_is_cmo_inval_i;
logic st0_req_is_cmo_flush_i;
logic st0_req_is_cmo_prefetch_i;
logic st0_req_is_partial_i;
logic st0_req_mshr_check_o;
logic st0_req_cachedir_read_o;
logic st1_req_valid_i;
logic st1_req_abort_i;
logic st1_req_rtab_i;
logic st1_req_is_error_i;
logic st1_req_is_uncacheable_i;
logic st1_req_need_rsp_i;
logic st1_req_is_load_i;
logic st1_req_is_store_i;
logic st1_req_is_amo_i;
logic st1_req_is_cmo_inval_i;
logic st1_req_is_cmo_inval_nline_i;
logic st1_req_is_cmo_flush_i;
logic st1_req_is_cmo_flush_nline_i;
logic st1_req_is_cmo_flush_inval_nline_i;
logic st1_req_is_cmo_fence_i;
logic st1_req_is_cmo_prefetch_i;
logic st1_req_is_partial_i;
logic st1_req_wr_wt_i;
logic st1_req_wr_wb_i;
logic st1_req_wr_auto_i;
logic st1_dir_hit_i;
logic st1_dir_hit_wback_i;
logic st1_dir_hit_dirty_i;
logic st1_dir_hit_fetch_i;
logic st1_dir_victim_unavailable_i;
logic st1_dir_victim_valid_i;
logic st1_dir_victim_wback_i;
logic st1_dir_victim_dirty_i;
logic st1_dir_err_cor_i;
logic st1_dir_err_unc_i;
logic st1_dat_err_cor_i;
logic st1_dat_err_unc_i;
logic st1_dat_err_unc_dirty_i;
logic st1_err_o;
logic err_busy_i;
logic err_wait_i;
logic st1_req_valid_o;
logic st1_rsp_valid_o;
logic st1_rsp_error_o;
logic st1_rsp_aborted_o;
logic st1_req_cachedir_sel_victim_o;
logic st1_req_cachedir_updt_sel_victim_o;
logic st1_req_cachedata_write_o;
logic st1_req_cachedata_write_enable_o;
logic st1_req_cachedata_write_merge_o;
logic st1_mshr_alloc_ready_i;
logic st1_mshr_hit_i;
logic st1_mshr_full_i;
logic st1_mshr_cbuf_full_i;
logic st1_no_pend_trans_i;
logic st2_mshr_alloc_i;
logic st2_mshr_alloc_is_prefetch_i;
logic st2_mshr_alloc_wback_i;
logic st2_mshr_alloc_dirty_i;
logic st2_mshr_alloc_o;
logic st2_mshr_alloc_cs_o;
logic st2_mshr_alloc_need_rsp_o;
logic st2_mshr_alloc_wback_o;
logic st2_mshr_alloc_dirty_o;
logic st2_dir_updt_i;
logic st2_dir_updt_valid_i;
logic st2_dir_updt_wback_i;
logic st2_dir_updt_dirty_i;
logic st2_dir_updt_fetch_i;
logic st2_dir_updt_o;
logic st2_dir_updt_valid_o;
logic st2_dir_updt_wback_o;
logic st2_dir_updt_dirty_o;
logic st2_dir_updt_fetch_o;
logic req_cachedata_read_o;
logic rd_wr_conflict_i;
logic rtab_full_i;
logic rtab_fence_i;
logic rtab_check_o;
logic rtab_check_hit_i;
logic st1_rtab_alloc_o;
logic st1_rtab_alloc_and_link_o;
logic st1_rtab_commit_o;
logic st1_rtab_rback_o;
logic st1_rtab_mshr_hit_o;
logic st1_rtab_mshr_full_o;
logic st1_rtab_mshr_ready_o;
logic st1_rtab_write_miss_o;
logic st1_rtab_wbuf_hit_o;
logic st1_rtab_wbuf_not_ready_o;
logic st1_rtab_dir_unavailable_o;
logic st1_rtab_dir_fetch_o;
logic st1_rtab_flush_hit_o;
logic st1_rtab_flush_not_ready_o;
logic st1_rtab_pend_trans_o;
logic cachedir_init_ready_i;
logic refill_busy_i;
logic refill_core_rsp_valid_i;
logic wbuf_write_ready_i;
logic wbuf_read_hit_i;
logic wbuf_write_valid_o;
logic wbuf_write_uncacheable_o;
logic wbuf_read_flush_hit_o;
logic wbuf_flush_all_o;
logic flush_busy_i;
logic st1_flush_check_hit_i;
logic st1_flush_alloc_ready_i;
logic st2_flush_alloc_i;
logic st2_flush_alloc_o;
logic uc_busy_i;
logic uc_req_valid_o;
logic uc_core_rsp_ready_o;
logic cmo_busy_i;
logic cmo_req_valid_o;
logic cmo_core_rsp_ready_o;
logic cfg_prefetch_updt_plru_i;
logic cfg_default_wb_i;
logic evt_cache_write_miss_o;
logic evt_cache_read_miss_o;
logic evt_cache_dir_unc_err_o;
logic evt_cache_dir_cor_err_o;
logic evt_cache_dat_unc_err_o;
logic evt_cache_dat_cor_err_o;
logic evt_uncached_req_o;
logic evt_cmo_req_o;
logic evt_write_req_o;
logic evt_read_req_o;
logic evt_prefetch_req_o;
logic evt_req_on_hold_o;
logic evt_rtab_rollback_o;
logic evt_stall_refill_o;
logic evt_stall_o;
hpdcache_ctrl_pe #(.HPDcacheCfg(cfg())) dut(
  .core_req_valid_i(core_req_valid_i),
  .core_req_ready_o(core_req_ready_o),
  .scrub_req_valid_i(scrub_req_valid_i),
  .scrub_req_ready_o(scrub_req_ready_o),
  .rtab_req_valid_i(rtab_req_valid_i),
  .rtab_req_ready_o(rtab_req_ready_o),
  .refill_req_valid_i(refill_req_valid_i),
  .refill_req_ready_o(refill_req_ready_o),
  .st0_req_is_error_i(st0_req_is_error_i),
  .st0_req_is_uncacheable_i(st0_req_is_uncacheable_i),
  .st0_req_need_rsp_i(st0_req_need_rsp_i),
  .st0_req_is_load_i(st0_req_is_load_i),
  .st0_req_is_scrub_i(st0_req_is_scrub_i),
  .st0_req_is_store_i(st0_req_is_store_i),
  .st0_req_is_amo_i(st0_req_is_amo_i),
  .st0_req_is_cmo_fence_i(st0_req_is_cmo_fence_i),
  .st0_req_is_cmo_inval_i(st0_req_is_cmo_inval_i),
  .st0_req_is_cmo_flush_i(st0_req_is_cmo_flush_i),
  .st0_req_is_cmo_prefetch_i(st0_req_is_cmo_prefetch_i),
  .st0_req_is_partial_i(st0_req_is_partial_i),
  .st0_req_mshr_check_o(st0_req_mshr_check_o),
  .st0_req_cachedir_read_o(st0_req_cachedir_read_o),
  .st1_req_valid_i(st1_req_valid_i),
  .st1_req_abort_i(st1_req_abort_i),
  .st1_req_rtab_i(st1_req_rtab_i),
  .st1_req_is_error_i(st1_req_is_error_i),
  .st1_req_is_uncacheable_i(st1_req_is_uncacheable_i),
  .st1_req_need_rsp_i(st1_req_need_rsp_i),
  .st1_req_is_load_i(st1_req_is_load_i),
  .st1_req_is_store_i(st1_req_is_store_i),
  .st1_req_is_amo_i(st1_req_is_amo_i),
  .st1_req_is_cmo_inval_i(st1_req_is_cmo_inval_i),
  .st1_req_is_cmo_inval_nline_i(st1_req_is_cmo_inval_nline_i),
  .st1_req_is_cmo_flush_i(st1_req_is_cmo_flush_i),
  .st1_req_is_cmo_flush_nline_i(st1_req_is_cmo_flush_nline_i),
  .st1_req_is_cmo_flush_inval_nline_i(st1_req_is_cmo_flush_inval_nline_i),
  .st1_req_is_cmo_fence_i(st1_req_is_cmo_fence_i),
  .st1_req_is_cmo_prefetch_i(st1_req_is_cmo_prefetch_i),
  .st1_req_is_partial_i(st1_req_is_partial_i),
  .st1_req_wr_wt_i(st1_req_wr_wt_i),
  .st1_req_wr_wb_i(st1_req_wr_wb_i),
  .st1_req_wr_auto_i(st1_req_wr_auto_i),
  .st1_dir_hit_i(st1_dir_hit_i),
  .st1_dir_hit_wback_i(st1_dir_hit_wback_i),
  .st1_dir_hit_dirty_i(st1_dir_hit_dirty_i),
  .st1_dir_hit_fetch_i(st1_dir_hit_fetch_i),
  .st1_dir_victim_unavailable_i(st1_dir_victim_unavailable_i),
  .st1_dir_victim_valid_i(st1_dir_victim_valid_i),
  .st1_dir_victim_wback_i(st1_dir_victim_wback_i),
  .st1_dir_victim_dirty_i(st1_dir_victim_dirty_i),
  .st1_dir_err_cor_i(st1_dir_err_cor_i),
  .st1_dir_err_unc_i(st1_dir_err_unc_i),
  .st1_dat_err_cor_i(st1_dat_err_cor_i),
  .st1_dat_err_unc_i(st1_dat_err_unc_i),
  .st1_dat_err_unc_dirty_i(st1_dat_err_unc_dirty_i),
  .st1_err_o(st1_err_o),
  .err_busy_i(err_busy_i),
  .err_wait_i(err_wait_i),
  .st1_req_valid_o(st1_req_valid_o),
  .st1_rsp_valid_o(st1_rsp_valid_o),
  .st1_rsp_error_o(st1_rsp_error_o),
  .st1_rsp_aborted_o(st1_rsp_aborted_o),
  .st1_req_cachedir_sel_victim_o(st1_req_cachedir_sel_victim_o),
  .st1_req_cachedir_updt_sel_victim_o(st1_req_cachedir_updt_sel_victim_o),
  .st1_req_cachedata_write_o(st1_req_cachedata_write_o),
  .st1_req_cachedata_write_enable_o(st1_req_cachedata_write_enable_o),
  .st1_req_cachedata_write_merge_o(st1_req_cachedata_write_merge_o),
  .st1_mshr_alloc_ready_i(st1_mshr_alloc_ready_i),
  .st1_mshr_hit_i(st1_mshr_hit_i),
  .st1_mshr_full_i(st1_mshr_full_i),
  .st1_mshr_cbuf_full_i(st1_mshr_cbuf_full_i),
  .st1_no_pend_trans_i(st1_no_pend_trans_i),
  .st2_mshr_alloc_i(st2_mshr_alloc_i),
  .st2_mshr_alloc_is_prefetch_i(st2_mshr_alloc_is_prefetch_i),
  .st2_mshr_alloc_wback_i(st2_mshr_alloc_wback_i),
  .st2_mshr_alloc_dirty_i(st2_mshr_alloc_dirty_i),
  .st2_mshr_alloc_o(st2_mshr_alloc_o),
  .st2_mshr_alloc_cs_o(st2_mshr_alloc_cs_o),
  .st2_mshr_alloc_need_rsp_o(st2_mshr_alloc_need_rsp_o),
  .st2_mshr_alloc_wback_o(st2_mshr_alloc_wback_o),
  .st2_mshr_alloc_dirty_o(st2_mshr_alloc_dirty_o),
  .st2_dir_updt_i(st2_dir_updt_i),
  .st2_dir_updt_valid_i(st2_dir_updt_valid_i),
  .st2_dir_updt_wback_i(st2_dir_updt_wback_i),
  .st2_dir_updt_dirty_i(st2_dir_updt_dirty_i),
  .st2_dir_updt_fetch_i(st2_dir_updt_fetch_i),
  .st2_dir_updt_o(st2_dir_updt_o),
  .st2_dir_updt_valid_o(st2_dir_updt_valid_o),
  .st2_dir_updt_wback_o(st2_dir_updt_wback_o),
  .st2_dir_updt_dirty_o(st2_dir_updt_dirty_o),
  .st2_dir_updt_fetch_o(st2_dir_updt_fetch_o),
  .req_cachedata_read_o(req_cachedata_read_o),
  .rd_wr_conflict_i(rd_wr_conflict_i),
  .rtab_full_i(rtab_full_i),
  .rtab_fence_i(rtab_fence_i),
  .rtab_check_o(rtab_check_o),
  .rtab_check_hit_i(rtab_check_hit_i),
  .st1_rtab_alloc_o(st1_rtab_alloc_o),
  .st1_rtab_alloc_and_link_o(st1_rtab_alloc_and_link_o),
  .st1_rtab_commit_o(st1_rtab_commit_o),
  .st1_rtab_rback_o(st1_rtab_rback_o),
  .st1_rtab_mshr_hit_o(st1_rtab_mshr_hit_o),
  .st1_rtab_mshr_full_o(st1_rtab_mshr_full_o),
  .st1_rtab_mshr_ready_o(st1_rtab_mshr_ready_o),
  .st1_rtab_write_miss_o(st1_rtab_write_miss_o),
  .st1_rtab_wbuf_hit_o(st1_rtab_wbuf_hit_o),
  .st1_rtab_wbuf_not_ready_o(st1_rtab_wbuf_not_ready_o),
  .st1_rtab_dir_unavailable_o(st1_rtab_dir_unavailable_o),
  .st1_rtab_dir_fetch_o(st1_rtab_dir_fetch_o),
  .st1_rtab_flush_hit_o(st1_rtab_flush_hit_o),
  .st1_rtab_flush_not_ready_o(st1_rtab_flush_not_ready_o),
  .st1_rtab_pend_trans_o(st1_rtab_pend_trans_o),
  .cachedir_init_ready_i(cachedir_init_ready_i),
  .refill_busy_i(refill_busy_i),
  .refill_core_rsp_valid_i(refill_core_rsp_valid_i),
  .wbuf_write_ready_i(wbuf_write_ready_i),
  .wbuf_read_hit_i(wbuf_read_hit_i),
  .wbuf_write_valid_o(wbuf_write_valid_o),
  .wbuf_write_uncacheable_o(wbuf_write_uncacheable_o),
  .wbuf_read_flush_hit_o(wbuf_read_flush_hit_o),
  .wbuf_flush_all_o(wbuf_flush_all_o),
  .flush_busy_i(flush_busy_i),
  .st1_flush_check_hit_i(st1_flush_check_hit_i),
  .st1_flush_alloc_ready_i(st1_flush_alloc_ready_i),
  .st2_flush_alloc_i(st2_flush_alloc_i),
  .st2_flush_alloc_o(st2_flush_alloc_o),
  .uc_busy_i(uc_busy_i),
  .uc_req_valid_o(uc_req_valid_o),
  .uc_core_rsp_ready_o(uc_core_rsp_ready_o),
  .cmo_busy_i(cmo_busy_i),
  .cmo_req_valid_o(cmo_req_valid_o),
  .cmo_core_rsp_ready_o(cmo_core_rsp_ready_o),
  .cfg_prefetch_updt_plru_i(cfg_prefetch_updt_plru_i),
  .cfg_default_wb_i(cfg_default_wb_i),
  .evt_cache_write_miss_o(evt_cache_write_miss_o),
  .evt_cache_read_miss_o(evt_cache_read_miss_o),
  .evt_cache_dir_unc_err_o(evt_cache_dir_unc_err_o),
  .evt_cache_dir_cor_err_o(evt_cache_dir_cor_err_o),
  .evt_cache_dat_unc_err_o(evt_cache_dat_unc_err_o),
  .evt_cache_dat_cor_err_o(evt_cache_dat_cor_err_o),
  .evt_uncached_req_o(evt_uncached_req_o),
  .evt_cmo_req_o(evt_cmo_req_o),
  .evt_write_req_o(evt_write_req_o),
  .evt_read_req_o(evt_read_req_o),
  .evt_prefetch_req_o(evt_prefetch_req_o),
  .evt_req_on_hold_o(evt_req_on_hold_o),
  .evt_rtab_rollback_o(evt_rtab_rollback_o),
  .evt_stall_refill_o(evt_stall_refill_o),
  .evt_stall_o(evt_stall_o)
);
// $finish ends the run only at the end of the time step; stop this process here.
task automatic fail(input string message);
  $display("FAIL: %s", message);
  $finish;
  wait (0);
endtask
initial begin
core_req_valid_i=0;
scrub_req_valid_i=0;
rtab_req_valid_i=0;
refill_req_valid_i=0;
st0_req_is_error_i=0;
st0_req_is_uncacheable_i=0;
st0_req_need_rsp_i=0;
st0_req_is_load_i=0;
st0_req_is_scrub_i=0;
st0_req_is_store_i=0;
st0_req_is_amo_i=0;
st0_req_is_cmo_fence_i=0;
st0_req_is_cmo_inval_i=0;
st0_req_is_cmo_flush_i=0;
st0_req_is_cmo_prefetch_i=0;
st0_req_is_partial_i=0;
st1_req_valid_i=0;
st1_req_abort_i=0;
st1_req_rtab_i=0;
st1_req_is_error_i=0;
st1_req_is_uncacheable_i=0;
st1_req_need_rsp_i=0;
st1_req_is_load_i=0;
st1_req_is_store_i=0;
st1_req_is_amo_i=0;
st1_req_is_cmo_inval_i=0;
st1_req_is_cmo_inval_nline_i=0;
st1_req_is_cmo_flush_i=0;
st1_req_is_cmo_flush_nline_i=0;
st1_req_is_cmo_flush_inval_nline_i=0;
st1_req_is_cmo_fence_i=0;
st1_req_is_cmo_prefetch_i=0;
st1_req_is_partial_i=0;
st1_req_wr_wt_i=0;
st1_req_wr_wb_i=0;
st1_req_wr_auto_i=0;
st1_dir_hit_i=0;
st1_dir_hit_wback_i=0;
st1_dir_hit_dirty_i=0;
st1_dir_hit_fetch_i=0;
st1_dir_victim_unavailable_i=0;
st1_dir_victim_valid_i=0;
st1_dir_victim_wback_i=0;
st1_dir_victim_dirty_i=0;
st1_dir_err_cor_i=0;
st1_dir_err_unc_i=0;
st1_dat_err_cor_i=0;
st1_dat_err_unc_i=0;
st1_dat_err_unc_dirty_i=0;
err_busy_i=0;
err_wait_i=0;
st1_mshr_alloc_ready_i=0;
st1_mshr_hit_i=0;
st1_mshr_full_i=0;
st1_mshr_cbuf_full_i=0;
st1_no_pend_trans_i=0;
st2_mshr_alloc_i=0;
st2_mshr_alloc_is_prefetch_i=0;
st2_mshr_alloc_wback_i=0;
st2_mshr_alloc_dirty_i=0;
st2_dir_updt_i=0;
st2_dir_updt_valid_i=0;
st2_dir_updt_wback_i=0;
st2_dir_updt_dirty_i=0;
st2_dir_updt_fetch_i=0;
rd_wr_conflict_i=0;
rtab_full_i=0;
rtab_fence_i=0;
rtab_check_hit_i=0;
cachedir_init_ready_i=0;
refill_busy_i=0;
refill_core_rsp_valid_i=0;
wbuf_write_ready_i=0;
wbuf_read_hit_i=0;
flush_busy_i=0;
st1_flush_check_hit_i=0;
st1_flush_alloc_ready_i=0;
st2_flush_alloc_i=0;
uc_busy_i=0;
cmo_busy_i=0;
cfg_prefetch_updt_plru_i=0;
cfg_default_wb_i=0;
cachedir_init_ready_i=1;
st1_req_wr_wt_i=1;
st1_no_pend_trans_i=1;
st1_req_valid_i=1;
st1_req_is_cmo_prefetch_i=1;
st1_dir_hit_i=1;
st1_req_need_rsp_i=1;
#1;
$display("PREFETCH_HIT need_rsp=1 rsp_valid=%0d",st1_rsp_valid_o);
if(st1_rsp_valid_o!==1) fail("completed prefetch needs response");
if(st2_mshr_alloc_o!==0) fail("cached prefetch must not allocate a miss");
st1_req_need_rsp_i=0;
#1;
if(st1_rsp_valid_o!==0) fail("need_rsp=0 must not acknowledge");
$display("PASS: acknowledged cacheable prefetch hits");
$finish;
end
endmodule
