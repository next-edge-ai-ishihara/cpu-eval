# Implement `hpdcache_ctrl_pe`

Implement the complete `hpdcache_ctrl_pe` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_ctrl_pe` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv32a60x_config_pkg.sv`

```systemverilog
      DCacheType: config_pkg::HPDCACHE_WT,
// ...
      DcacheEccEnable: bit'(0),
      DcacheEccScrubberEnable: bit'(0),
```

### `core/cache_subsystem/cva6_hpdcache_subsystem.sv`

```systemverilog
    userCfg.wtEn =
        (CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT) ||
        (CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT_WB);
    userCfg.wbEn =
        (CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WB) ||
        (CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT_WB);
    userCfg.lowLatency = 1'b1;
    userCfg.eccEn = CVA6Cfg.DcacheEccEnable;
    userCfg.eccScrubberEn = CVA6Cfg.DcacheEccScrubberEnable;
    return userCfg;
  endfunction

  localparam hpdcache_pkg::hpdcache_user_cfg_t HPDcacheUserCfg = hpdcacheSetConfig();
  localparam hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = hpdcache_pkg::hpdcacheBuildConfig(
      HPDcacheUserCfg
  );
```

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
    typedef struct packed {
// ...
        //  Enable support for the write-through policy
        bit wtEn;
        //  Enable support for the write-back policy
        bit wbEn;
        //  Enable fast loads.
        //  Perform loads in 1 cycle at the cost of structural hazard for stores
        bit lowLatency;
        //  Enable ECC in cache SRAMs
        bit eccEn;
        //  Enable error correction scrubber
        bit eccScrubberEn;
    } hpdcache_user_cfg_t;

    typedef struct packed {
        //  User configuration parameters
        hpdcache_user_cfg_t u;
// ...
    } hpdcache_cfg_t;
```

## Module declaration

```systemverilog
module hpdcache_ctrl_pe
    // Package imports
    // {{{
import hpdcache_pkg::*;
    // }}}
    // Parameters
    // {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0
)
    // }}}
    // Ports
    // {{{
(
    //   Requests
    //   {{{
    input  logic                   core_req_valid_i,
    output logic                   core_req_ready_o,

    input  logic                   scrub_req_valid_i,
    output logic                   scrub_req_ready_o,

    input  logic                   rtab_req_valid_i,
    output logic                   rtab_req_ready_o,

    input  logic                   refill_req_valid_i,
    output logic                   refill_req_ready_o,
    //   }}}

    //   Pipeline stage 0
    //   {{{
    input  logic                   st0_req_is_error_i,
    input  logic                   st0_req_is_uncacheable_i,
    input  logic                   st0_req_need_rsp_i,
    input  logic                   st0_req_is_load_i,
    input  logic                   st0_req_is_scrub_i,
    input  logic                   st0_req_is_store_i,
    input  logic                   st0_req_is_amo_i,
    input  logic                   st0_req_is_cmo_fence_i,
    input  logic                   st0_req_is_cmo_inval_i,
    input  logic                   st0_req_is_cmo_flush_i,
    input  logic                   st0_req_is_cmo_prefetch_i,
    input  logic                   st0_req_is_partial_i,
    output logic                   st0_req_mshr_check_o,
    output logic                   st0_req_cachedir_read_o,
    //   }}}

    //   Pipeline stage 1
    //   {{{
    input  logic                   st1_req_valid_i,
    input  logic                   st1_req_abort_i,
    input  logic                   st1_req_rtab_i,
    input  logic                   st1_req_is_error_i,
    input  logic                   st1_req_is_uncacheable_i,
    input  logic                   st1_req_need_rsp_i,
    input  logic                   st1_req_is_load_i,
    input  logic                   st1_req_is_store_i,
    input  logic                   st1_req_is_amo_i,
    input  logic                   st1_req_is_cmo_inval_i,
    input  logic                   st1_req_is_cmo_inval_nline_i,
    input  logic                   st1_req_is_cmo_flush_i,
    input  logic                   st1_req_is_cmo_flush_nline_i,
    input  logic                   st1_req_is_cmo_flush_inval_nline_i,
    input  logic                   st1_req_is_cmo_fence_i,
    input  logic                   st1_req_is_cmo_prefetch_i,
    input  logic                   st1_req_is_partial_i,
    input  logic                   st1_req_wr_wt_i,
    input  logic                   st1_req_wr_wb_i,
    input  logic                   st1_req_wr_auto_i,
    input  logic                   st1_dir_hit_i,
    input  logic                   st1_dir_hit_wback_i,
    input  logic                   st1_dir_hit_dirty_i,
    input  logic                   st1_dir_hit_fetch_i,
    input  logic                   st1_dir_victim_unavailable_i,
    input  logic                   st1_dir_victim_valid_i,
    input  logic                   st1_dir_victim_wback_i,
    input  logic                   st1_dir_victim_dirty_i,
    input  logic                   st1_dir_err_cor_i,
    input  logic                   st1_dir_err_unc_i,
    input  logic                   st1_dat_err_cor_i,
    input  logic                   st1_dat_err_unc_i,
    input  logic                   st1_dat_err_unc_dirty_i,
    output logic                   st1_err_o,
    input  logic                   err_busy_i,
    input  logic                   err_wait_i,
    output logic                   st1_req_valid_o,
    output logic                   st1_rsp_valid_o,
    output logic                   st1_rsp_error_o,
    output logic                   st1_rsp_aborted_o,
    output logic                   st1_req_cachedir_sel_victim_o,
    output logic                   st1_req_cachedir_updt_sel_victim_o,
    output logic                   st1_req_cachedata_write_o,
    output logic                   st1_req_cachedata_write_enable_o,
    output logic                   st1_req_cachedata_write_merge_o,
    input  logic                   st1_mshr_alloc_ready_i,
    input  logic                   st1_mshr_hit_i,
    input  logic                   st1_mshr_full_i,
    input  logic                   st1_mshr_cbuf_full_i,
    input  logic                   st1_no_pend_trans_i,
    //   }}}

    //   Pipeline stage 2
    //   {{{
    input  logic                   st2_mshr_alloc_i,
    input  logic                   st2_mshr_alloc_is_prefetch_i,
    input  logic                   st2_mshr_alloc_wback_i,
    input  logic                   st2_mshr_alloc_dirty_i,
    output logic                   st2_mshr_alloc_o,
    output logic                   st2_mshr_alloc_cs_o,
    output logic                   st2_mshr_alloc_need_rsp_o,
    output logic                   st2_mshr_alloc_wback_o,
    output logic                   st2_mshr_alloc_dirty_o,

    input  logic                   st2_dir_updt_i,
    input  logic                   st2_dir_updt_valid_i,
    input  logic                   st2_dir_updt_wback_i,
    input  logic                   st2_dir_updt_dirty_i,
    input  logic                   st2_dir_updt_fetch_i,
    output logic                   st2_dir_updt_o,
    output logic                   st2_dir_updt_valid_o,
    output logic                   st2_dir_updt_wback_o,
    output logic                   st2_dir_updt_dirty_o,
    output logic                   st2_dir_updt_fetch_o,
    //   }}}

    //   Cache data
    //   {{{
    output logic                   req_cachedata_read_o,
    input  logic                   rd_wr_conflict_i,
    //   }}}

    //   Replay
    //   {{{
    input  logic                   rtab_full_i,
    input  logic                   rtab_fence_i,
    output logic                   rtab_check_o,
    input  logic                   rtab_check_hit_i,
    output logic                   st1_rtab_alloc_o,
    output logic                   st1_rtab_alloc_and_link_o,
    output logic                   st1_rtab_commit_o,
    output logic                   st1_rtab_rback_o,
    output logic                   st1_rtab_mshr_hit_o,
    output logic                   st1_rtab_mshr_full_o,
    output logic                   st1_rtab_mshr_ready_o,
    output logic                   st1_rtab_write_miss_o,
    output logic                   st1_rtab_wbuf_hit_o,
    output logic                   st1_rtab_wbuf_not_ready_o,
    output logic                   st1_rtab_dir_unavailable_o,
    output logic                   st1_rtab_dir_fetch_o,
    output logic                   st1_rtab_flush_hit_o,
    output logic                   st1_rtab_flush_not_ready_o,
    output logic                   st1_rtab_pend_trans_o,
    //   }}}

    //   Cache directory
    //   {{{
    input  logic                   cachedir_init_ready_i,
    //   }}}

    //   Refill interface
    //   {{{
    input  logic                   refill_busy_i,
    input  logic                   refill_core_rsp_valid_i,
    //   }}}

    //   Write buffer
    //   {{{
    input  logic                   wbuf_write_ready_i,
    input  logic                   wbuf_read_hit_i,
    output logic                   wbuf_write_valid_o,
    output logic                   wbuf_write_uncacheable_o,
    output logic                   wbuf_read_flush_hit_o,
    output logic                   wbuf_flush_all_o,
    //   }}}

    //   Flush controller
    input  logic                   flush_busy_i,
    input  logic                   st1_flush_check_hit_i,
    input  logic                   st1_flush_alloc_ready_i,
    input  logic                   st2_flush_alloc_i,
    output logic                   st2_flush_alloc_o,

    //   Uncacheable request handler
    //   {{{
    input  logic                   uc_busy_i,
    output logic                   uc_req_valid_o,
    output logic                   uc_core_rsp_ready_o,
    //   }}}

    //   Cache Management Operation (CMO)
    //   {{{
    input  logic                   cmo_busy_i,
    output logic                   cmo_req_valid_o,
    output logic                   cmo_core_rsp_ready_o,
    //   }}}

    //   Configuration
    //   {{{
    input  logic                   cfg_prefetch_updt_plru_i,
    input  logic                   cfg_default_wb_i,
    //   }}}

    //   Performance events
    //   {{{
    output logic                   evt_cache_write_miss_o,
    output logic                   evt_cache_read_miss_o,
    output logic                   evt_cache_dir_unc_err_o,
    output logic                   evt_cache_dir_cor_err_o,
    output logic                   evt_cache_dat_unc_err_o,
    output logic                   evt_cache_dat_cor_err_o,
    output logic                   evt_uncached_req_o,
    output logic                   evt_cmo_req_o,
    output logic                   evt_write_req_o,
    output logic                   evt_read_req_o,
    output logic                   evt_prefetch_req_o,
    output logic                   evt_req_on_hold_o,
    output logic                   evt_rtab_rollback_o,
    output logic                   evt_stall_refill_o,
    output logic                   evt_stall_o
    //   }}}
);
```

## Parent instantiation

### `rtl/src/hpdcache_ctrl.sv`

```systemverilog
    assign st1_dat_err_unc_dirty = st1_dir_err_valid & st1_dir_err_dirty & st1_dat_err_unc;

    hpdcache_ctrl_pe #(
        .HPDcacheCfg(HPDcacheCfg)
    ) hpdcache_ctrl_pe_i(
        .core_req_valid_i,
        .core_req_ready_o,
        .scrub_req_valid_i                  (scrub_req_valid),
        .scrub_req_ready_o                  (scrub_req_ready),
        .rtab_req_valid_i                   (st0_rtab_pop_try_valid),
        .rtab_req_ready_o                   (st0_rtab_pop_try_ready),
        .refill_req_valid_i,
        .refill_req_ready_o,

        .st0_req_is_error_i                 (st0_req.is_error),
        .st0_req_is_uncacheable_i           (st0_req_is_uncacheable),
        .st0_req_need_rsp_i                 (st0_req.req.need_rsp),
        .st0_req_is_load_i                  (st0_req_is_load),
        .st0_req_is_scrub_i                 (st0_req_is_scrub),
        .st0_req_is_store_i                 (st0_req_is_store),
        .st0_req_is_amo_i                   (st0_req_is_amo),
        .st0_req_is_cmo_fence_i             (st0_req_is_cmo_fence),
        .st0_req_is_cmo_inval_i             (st0_req_is_cmo_inval),
        .st0_req_is_cmo_flush_i             (st0_req_is_cmo_flush),
        .st0_req_is_cmo_prefetch_i          (st0_req_is_cmo_prefetch),
        .st0_req_is_partial_i               (st0_req_is_partial),
        .st0_req_mshr_check_o               (st0_mshr_check_o),
        .st0_req_cachedir_read_o            (st0_req_cachedir_read),

        .st1_req_valid_i                    (st1_req_valid_q),
        .st1_req_abort_i                    (st1_req_abort),
        .st1_req_rtab_i                     (st1_req.from_rtab),
        .st1_req_is_error_i                 (st1_req.is_error),
        .st1_req_is_uncacheable_i           (st1_req_is_uncacheable),
        .st1_req_need_rsp_i                 (st1_req.req.need_rsp),
        .st1_req_is_load_i                  (st1_req_is_load),
        .st1_req_is_store_i                 (st1_req_is_store),
        .st1_req_is_amo_i                   (st1_req_is_amo),
        .st1_req_is_cmo_inval_i             (st1_req_is_cmo_inval),
        .st1_req_is_cmo_inval_nline_i       (st1_req_is_cmo_inval_nline),
        .st1_req_is_cmo_flush_i             (st1_req_is_cmo_flush),
        .st1_req_is_cmo_flush_nline_i       (st1_req_is_cmo_flush_nline),
        .st1_req_is_cmo_flush_inval_nline_i (st1_req_is_cmo_flush_inval_nline),
        .st1_req_is_cmo_fence_i             (st1_req_is_cmo_fence),
        .st1_req_is_cmo_prefetch_i          (st1_req_is_cmo_prefetch),
        .st1_req_is_partial_i               (st1_req_is_partial),
        .st1_req_wr_wt_i                    (st1_req_wr_wt),
        .st1_req_wr_wb_i                    (st1_req_wr_wb),
        .st1_req_wr_auto_i                  (st1_req_wr_auto),
        .st1_dir_hit_i                      (st1_dir_hit),
        .st1_dir_hit_wback_i                (st1_dir_hit_wback),
        .st1_dir_hit_dirty_i                (st1_dir_hit_dirty),
        .st1_dir_hit_fetch_i                (st1_dir_hit_fetch),
        .st1_dir_victim_unavailable_i       (st1_dir_victim_unavailable),
        .st1_dir_victim_valid_i             (st1_dir_victim_valid),
        .st1_dir_victim_wback_i             (st1_dir_victim_wback),
        .st1_dir_victim_dirty_i             (st1_dir_victim_dirty),
        .st1_dir_err_cor_i                  (|st1_dir_err_cor),
        .st1_dir_err_unc_i                  (|st1_dir_err_unc),
        .st1_dat_err_cor_i                  (|st1_dat_err_cor),
        .st1_dat_err_unc_i                  (|st1_dat_err_unc),
        .st1_dat_err_unc_dirty_i            (|st1_dat_err_unc_dirty),
        .st1_err_o                          (st1_err_trigger),
        .err_busy_i                         (err_busy),
        .err_wait_i                         (err_wait),
        .st1_req_valid_o                    (st1_req_valid_d),
        .st1_rsp_valid_o                    (st1_rsp_valid),
        .st1_rsp_error_o                    (st1_rsp_error),
        .st1_rsp_aborted_o                  (st1_rsp_aborted),
        .st1_req_cachedir_sel_victim_o      (st1_victim_sel),
        .st1_req_cachedir_updt_sel_victim_o (st1_req_updt_sel_victim),
        .st1_req_cachedata_write_o          (st1_req_cachedata_write),
        .st1_req_cachedata_write_enable_o   (st1_req_cachedata_write_enable),
        .st1_req_cachedata_write_merge_o    (st1_req_cachedata_write_merge),
        .st1_no_pend_trans_i                (st1_no_pend_trans),

        .st2_mshr_alloc_i                   (st2_mshr_alloc_q),
        .st2_mshr_alloc_is_prefetch_i       (st2_mshr_alloc_is_prefetch_q),
        .st2_mshr_alloc_wback_i             (st2_mshr_alloc_wback_q),
        .st2_mshr_alloc_dirty_i             (st2_mshr_alloc_dirty_q),
        .st2_mshr_alloc_o                   (st2_mshr_alloc_d),
        .st2_mshr_alloc_cs_o                (st2_mshr_alloc_cs_o),
        .st2_mshr_alloc_need_rsp_o          (st2_mshr_alloc_need_rsp_d),
        .st2_mshr_alloc_wback_o             (st2_mshr_alloc_wback_d),
        .st2_mshr_alloc_dirty_o             (st2_mshr_alloc_dirty_d),

        .st2_dir_updt_i                     (st2_dir_updt_q),
        .st2_dir_updt_valid_i               (st2_dir_updt_valid_q),
        .st2_dir_updt_wback_i               (st2_dir_updt_wback_q),
        .st2_dir_updt_dirty_i               (st2_dir_updt_dirty_q),
        .st2_dir_updt_fetch_i               (st2_dir_updt_fetch_q),
        .st2_dir_updt_o                     (st2_dir_updt_d),
        .st2_dir_updt_valid_o               (st2_dir_updt_valid_d),
        .st2_dir_updt_wback_o               (st2_dir_updt_wback_d),
        .st2_dir_updt_dirty_o               (st2_dir_updt_dirty_d),
        .st2_dir_updt_fetch_o               (st2_dir_updt_fetch_d),

        .req_cachedata_read_o               (data_req_read),
        .rd_wr_conflict_i                   (rd_wr_conflict),

        .flush_busy_i,
        .st1_flush_check_hit_i              (flush_check_hit_i),
        .st1_flush_alloc_ready_i            (flush_alloc_ready_i),
        .st2_flush_alloc_i                  (st2_flush_alloc_q),
        .st2_flush_alloc_o                  (st2_flush_alloc_d),

        .rtab_full_i                        (rtab_full),
        .rtab_fence_i                       (rtab_fence),
        .rtab_check_o                       (st1_rtab_check),
        .rtab_check_hit_i                   (st1_rtab_check_hit),
        .st1_rtab_alloc_o                   (st1_rtab_alloc),
        .st1_rtab_alloc_and_link_o          (st1_rtab_alloc_and_link),
        .st1_rtab_commit_o                  (st1_rtab_pop_try_commit),
        .st1_rtab_rback_o                   (st1_rtab_pop_try_rback),
        .st1_rtab_mshr_hit_o                (st1_rtab_deps.mshr_hit),
        .st1_rtab_mshr_full_o               (st1_rtab_deps.mshr_full),
        .st1_rtab_mshr_ready_o              (st1_rtab_deps.mshr_ready),
        .st1_rtab_write_miss_o              (st1_rtab_deps.write_miss),
        .st1_rtab_wbuf_hit_o                (st1_rtab_deps.wbuf_hit),
        .st1_rtab_wbuf_not_ready_o          (st1_rtab_deps.wbuf_not_ready),
        .st1_rtab_dir_unavailable_o         (st1_rtab_deps.dir_unavailable),
        .st1_rtab_dir_fetch_o               (st1_rtab_deps.dir_fetch),
        .st1_rtab_flush_hit_o               (st1_rtab_deps.flush_hit),
        .st1_rtab_flush_not_ready_o         (st1_rtab_deps.flush_not_ready),
        .st1_rtab_pend_trans_o              (st1_rtab_deps.pend_trans),

        .cachedir_init_ready_i              (hpdcache_init_ready),

        .st1_mshr_alloc_ready_i             (st1_mshr_alloc_ready_i),
        .st1_mshr_hit_i                     (st1_mshr_hit_i),
        .st1_mshr_full_i                    (st1_mshr_alloc_full_i),
        .st1_mshr_cbuf_full_i               (st1_mshr_alloc_cbuf_full_i),

        .refill_busy_i,
        .refill_core_rsp_valid_i,

        .wbuf_write_valid_o                 (wbuf_write_o),
        .wbuf_write_ready_i,
        .wbuf_read_hit_i,
        .wbuf_write_uncacheable_o,
        .wbuf_read_flush_hit_o,
        .wbuf_flush_all_o                   (st1_wbuf_flush_all),

        .uc_busy_i,
        .uc_req_valid_o,
        .uc_core_rsp_ready_o,

        .cmo_busy_i,
        .cmo_req_valid_o,
        .cmo_core_rsp_ready_o,

        .cfg_prefetch_updt_plru_i,
        .cfg_default_wb_i,

        .evt_cache_write_miss_o,
        .evt_cache_read_miss_o,
        .evt_cache_dir_unc_err_o,
        .evt_cache_dir_cor_err_o,
        .evt_cache_dat_unc_err_o,
        .evt_cache_dat_cor_err_o,
        .evt_uncached_req_o,
        .evt_cmo_req_o,
        .evt_write_req_o,
        .evt_read_req_o,
        .evt_prefetch_req_o,
        .evt_req_on_hold_o,
        .evt_rtab_rollback_o,
        .evt_stall_refill_o,
        .evt_stall_o
    );
```

## Documentation

### `docs/source/architecture.rst`

```text
Cache Controller
----------------

The cache controller is responsible for decoding and issuing the requests to the
appropriate handler. The cache controller implements a 3-stage pipeline. This
pipeline is capable of accepting one request per cycle. However, there are some
scenarios where the pipeline may either stall or put a request on hold in a side
buffer called Replay Table (RTAB).

The first stage (stage 0) of the pipeline arbitrates between requests from the
miss handler (refill), RTAB, and requesters; the second stage (stage 1) responds
to loads (in case of hit) and to stores; the third stage (stage 2) is only used
by loads in case of miss. In this last stage, the cache triggers a read miss
transaction to the memory and allocates a new entry in the Miss Status Holding
Register (MSHR) to track the progress of the miss transaction.

A request on stage 0 can either be consumed on that cycle (forwarded to the
stage 1) or stalled. A request on stage 1 or stage 2 always progresses. In stage
1 the request is either acknowledged (load hit or write acknowledgement),
forwarded to stage 2 (load miss), or put into the RTAB. In stage 2, the request
quits the pipeline and it is written in the MSHR.

The arbiter in stage 0 uses a fixed-priority policy: refills have the higher
priority, followed by the RTAB, and finally core request (lower priority).

Pipeline Stalls in Stage 0
''''''''''''''''''''''''''

Stalls in stage 0 are necessary in some specific scenarios, that are listed
below. When there is a stall in stage 0, a new request from a requester cannot
be accepted, this is, the corresponding :math:`\mathsf{ready}` signal is kept
low (set to 0). Requests in the other stages (1 and 2) are processed normally
(even in case of a stall in stage 0).

.. list-table:: Events that Stall the Pipeline
   :widths: 5 50 40
   :header-rows: 1
   :align: center

   * - Event
     - Description
     - Stall Latency (Clock Cycles)
   * - **1**
     - The RTAB is full
     - It depends on when an entry of the RTAB is freed
   * - **2**
     - A CMO invalidation or fence operation is being processed by the
       corresponding handler
     - It depends on the latency of the operation
   * - **3**
     - An uncacheable or atomic operation is being processed by the
       corresponding handler
     - It depends on the latency of the operation
   * - **4**
     - There is a load miss in stage 1
     - One cycle
   * - **5**
     - There is a store in stage 1 and the request in stage 0 is a load
       (structural hazard on access to the internal cache data memory)
     - One cycle

.. _sec_onhold:

On-Hold Requests
''''''''''''''''

In some scenarios, a request that has been accepted in the pipeline can be
later put on-hold by the cache controller. The cache controller puts a request
on-hold by removing it from the cache pipeline and writing it into the Replay
Table (RTAB). When a request is put on-hold, it is re-executed when all the
blocking conditions have been removed. The blocking conditions putting a
request on-hold are the following:

.. _tab_onhold:

.. list-table:: Conditions Putting a Request On-hold
   :widths: 3 37 60
   :header-rows: 1

   * - #
     - Condition
     - Description
   * - **1**
     - **Cacheable LOAD or PREFETCH, and there is a hit on a pending miss (hit
       on the MSHR)**
     - When there is a read miss on a given cacheline for which there is a
       pending read miss, then the more recent one needs to wait for the
       previous one to be served. This allows the latest one to read the data
       from the cache after the refill operation completes. More importantly,
       this frees the pipeline to accept the corresponding refill and prevent a
       deadlock.
   * - **2**
     - **Cacheable LOAD or PREFETCH, there is a miss on the cache, and there is
       a hit (cacheline granularity) on an opened, pending or sent entry of the
       WBUF**
     - When there is a read miss on an address, the cache controller needs to
       read from the memory the missing cacheline. As the NoC implements
       different physical channels for read and write requests, there is a race
       condition between the read miss and a pending write operation.  If the
       read miss arrives first to the memory, it would read the old data (which
       violates :ref:`sec_mcrs`). This blocking condition causes that the LOAD
       or PREFETCH will have a delay penalty of up to two transaction delays:
       one for the write to complete, then one for the read.
   * - **3**
     - **Cacheable STORE, there is a miss on the cache, and there is a hit on a
       pending miss (hit on the MSHR)**
     - When writing, as the NoC implements different physical channels for read
       and write requests, there is a race condition between the STORE and the
       pending read miss. If the STORE arrives first to the memory, the earlier
       read miss would read the new data (which violates :ref:`sec_mcrs`).
   * - **4**
     - **Cacheable LOAD/PREFETCH/STORE, and there is a hit on an entry of the
       RTAB**
     - Accesses to the same cacheline SHALL be processed in order (to respect
       :ref:`sec_mcrs`). In case of a hit with a valid entry in the RTAB, the
       new request shall wait for previous requests on the same cacheline to
       finish.
   * - **5**
     - **Cacheable LOAD or PREFETCH, there is a miss on the cache, and the MSHR
       has no available slots**
     - When there is a read miss on an address, the cache controller needs to
       allocate a new entry in the MSHR. If there is no available entry, the
       read request needs to wait for an entry in the MSHR to be freed. This
       frees the pipeline to accept the corresponding refill and prevent a
       deadlock.
   * - **6**
     - **Cacheable LOAD or PREFETCH, there is a miss on the cache, and the miss
       handler FSM cannot send the read miss request**
     - When there is a read miss on an address, the cache controller needs to
       read from memory the missing cacheline. The read miss request is sent by
       the miss handler FSM, but if there is congestion in the NoC, this read
       request cannot be issued. This frees the pipeline to prevent a potential
       deadlock.

The cache controller checks all these conditions in the second stage (stage 1)
of the pipeline. If one of the conditions is met, the cache controller puts the
request into the RTAB and holds it there until its blocking condition is
resolved. At that moment, the cache can replay the request from the RTAB.

The RTAB can store multiple on-hold requests. The idea is to improve the
throughput of the cache by reducing the number of cases where there is a head
of line blocking at the client interface. As mentioned in
:numref:`Table %s <tab_onhold>`, this also prevents deadlocks. To always allow
the cache controller to retire a request from the pipeline, the cache controller
does not accept new requests if the RTAB is full.

Requests from the RTAB may be executed in an order that is different from
the order in which they were accepted (if they target different cachelines).
The requests, that target the same cacheline, are replayed by the RTAB in the
order they were accepted.

Requests within the RTAB that have their dependencies resolved may be replayed.
These have higher priority than the new requests from requesters.


.. _sec_mcrs:

Memory Consistency Rules (MCRs)
'''''''''''''''''''''''''''''''

The cache controller processes requests following a set of Memory Consistency
Rules (MCRs). These rules allow the requesters to have a predictable behavior.

The set MCRs respected by the cache controller are those defined by the RISC-V
Weak Memory Ordering (RVWMO) memory consistency model. [RISCVUP2019]_ specifies
this model. The following statement summarizes these rules: **if one memory
access (read or write), A, precedes another memory access (read or write), B,
and they access overlapping addresses, then they MUST be executed in program
order (A then B)**. It can be deduced from this statement, that non-overlapping
accesses can be executed in any order.

The cache controller also needs to respect the progress axiom: **no memory
operation may be preceded by an infinite number of memory operations**. That
is, all memory operations need to be processed at some point in time. They
cannot wait indefinitely.

Hybrid Write-Policy
'''''''''''''''''''

The HPDcache can handle writes in both write-back and write-through policies.
The HPDcache handles the write policy at cacheline granularity. This means that
at any given time, the HPDcache has two logical subsets of cachelines: one
subset containing cachelines in write-back policy, and another subset
containing cachelines in write-through policy. Any of these two subsets may be
empty, meaning that all cachelines may be either write-back or write-through.

If only one write-policy is required, the system designer can:

  - Disable the write-back policy setting to 0 the ``CONF_HPDCACHE_WB_ENABLE``
    parameter.

  - Disable the write-through policy setting to 0 the ``CONF_HPDCACHE_WT_ENABLE``
    parameter.

When both write-policies are enabled, the request interface may set dynamically
the write-policy (write-back or write-through) for the target cacheline. In the
request interface, there are specific flags (hints) to indicate the desired
policy for a given request.

The HPDcache keeps the policy for subsequent accesses until a request/response
force it to a specific policy. It accepts policy changes for any cacheline.
This is, a request/response may ask for write-back policy (respectively
write-through) for a given cacheline, and another request/response may ask for
write-through policy (respectively write-back) for that same cacheline later.


Cache Directory and Data
------------------------

State Bits in the Cache Directory
'''''''''''''''''''''''''''''''''

Each cacheline in the HPDcache has the following state bits:

  - **valid**: when this bit is set, it means that the cacheline is valid.
    Otherwise, the slot is available.
  - **wback**: when this bit is set, it means that the cacheline is in
    write-back mode. It is only valid when the valid bit is set.
  - **dirty**: when this bit is set, it means that the cacheline is in
    write-back mode and it is dirty (it has locally modified data which has not
    been transmitted to the next memory level). It is only valid when the valid
    bit is set.
  - **fetch**: when this bit is set, it means that the cacheline has been
    pre-selected to be replaced by a new one. While this bit is set, the refill
    response for the miss has not yet arrived.
...
.. _sec_uncacheable_handler:

Uncacheable Handler
-------------------

This block is responsible for processing uncacheable load and store requests
(see :ref:`sec_req_cacheability`), as well as atomic requests (regardless of
whether they are cacheable or not). For more information about atomic requests
see :ref:`sec_amo`.

If :math:`\scriptsize\mathsf{CONF\_HPDCACHE\_SUPPORT\_AMO}` is set to 0, the
HPDcache does not support AMOs from requesters. In this case, the AMO has no
effect and the Uncacheable Handler responds with an error to the corresponding
requester (when ``core_req_i.need_rsp`` is set to 1). If ``core_req_i.need_rsp``
is set to 0, the Uncacheable Handler ignores the AMO.

All requests handled by this block produce a request to the memory. These
requests to the memory are issued through the CMI interfaces. Uncacheable read
requests are forwarded to the memory through the CMI read. Uncacheable write
requests or atomic requests are forwarded through the CMI write.


.. _sec_cmo_handler:

Cache Management Operation (CMO) Handler
----------------------------------------

This block is responsible for handling CMOs. CMOs are special requests from
requesters that address the cache itself, and not the memory or a peripheral.
CMOs allow to invalidate or prefetch designated cachelines, or produce explicit
memory read and write fences.

The complete list of supported CMOs is detailed in :ref:`sec_cmo`.

If :math:`\scriptsize\mathsf{CONF\_HPDCACHE\_SUPPORT\_CMO}` is set to 0, the
HPDcache does not support CMOs from requesters. In this case, the CMO has no
effect and the CMO Handler responds with an error to the corresponding requester
(when ``core_req_i.need_rsp`` is set to 1). If ``core_req_i.need_rsp`` is set to
0, the CMO Handler ignores the CMO.
...
Policy for taking new requests in the data cache
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The cache has three possible sources of requests:

- The core (new request from requesters)

- The RTAB (on-hold requests)

- The miss handler (refill requests)

The cache controller implements a fixed priority policy between these sources.
It accepts requests in the following order of priority:

#. Refill request (highest priority)

#. On-hold request

#. New request (lowest priority)
...
Memory Fences
'''''''''''''

In multi-core systems, or more generally, in systems with multiple DMA-capable
devices, when synchronization is needed, it is necessary to implement memory
fences from the software. In the case of RISC-V, there is specific instructions
for this (i.e. fence).

Fence instructions shall be forwarded to the cache to ensure ordering of writes.
The fence will force the write-buffer to send all pending writes before
accepting new ones. This cache implements two ways of signalling a fence:
sending a specific CMO instruction from the core (described later on
:ref:`sec_cmo`), or by asserting ``wbuf_flush_i`` pin (during one cycle).
```

### `docs/source/interface.rst`

```text
This section describes the basic protocol transaction requirements for the
different interfaces in the HPDcache.


..  _sec_ready_valid_handshake:

Valid/Ready handshake process
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

All interfaces in the HPDcache use a **valid**/**ready** handshake process to
transfer a payload between the source and the destination. The payload contains
the address, data and control information.

As a reminder, the 7 interfaces in the HPDcache are the following:

#. CRI request interface
#. CRI response interface
#. CMI read request interface
#. CMI read response interface
#. CMI write request interface
#. CMI write data request interface
#. CMI write response interface

The source sets to 1 the **valid** signal to indicate when the payload is
available. The destination sets to 1 the **ready** signal to indicate that it
can accept that payload. Transfer occurs only when both the **valid** and
**ready** signals are set to 1 on the next rising edge of the clock.

A source is not permitted to wait until **ready** is set to 1 before setting
**valid** to 1.

A destination may or not wait for **valid** to set the **ready** to 1
(:numref:`cases (a) and (d) in Table %s <tab_ready_valid_scenarios>`).
In other words, a destination may set **ready** to 1 before an actual transfer
is available.

When **valid** is set to 1, the source must keep it that way until the
handshake occurs. This is, at the next rising edge when both **valid** and
**ready** (from the destination) are set to 1. In other words, a source cannot
retire a pending **valid** transfer
(:numref:`Case (b) in Table %s <tab_ready_valid_scenarios>`).

After an effective transfer (**valid** and **ready** set to 1), the source may
keep **valid** set to 1 in the next cycle to signal a new transfer (with a new
payload). In the same manner, the destination may keep **ready** set to 1 if it
can accept a new transfer. This allows back-to-back transfers, with no idle
cycles, between a source and a destination
(:numref:`Case (d) in Table %s <tab_ready_valid_scenarios>`).

All interfaces are synchronous to the rising edge of the same global
clock (``clk_i``).

.. _tab_ready_valid_scenarios:

.. list-table:: valid/ready scenarios
   :class: borderless
   :align: center

   * - **(a)**
     - **(b)**
   * - .. image:: images/wave_ready_before_valid.*
     - .. image:: images/wave_valid_before_ready.*
   * - **(c)**
     - **(d)**
   * - .. image:: images/wave_ready_when_valid.*
     - .. image:: images/wave_back_to_back.*


CRI Response Interface
'''''''''''''''''''''''''''''

In the case of the CRI response interfaces, there is a particularity.
For these interfaces, it is assumed that the **ready** signal is always set to
1. That is why the **ready** signal is not actually implemented on those
interfaces. In other words, the requester unconditionally accepts any incoming
response.
...
.. _sec_req_abort:

Request Abortion
~~~~~~~~~~~~~~~~~~~~~

When using the virtual indexing, the requester can abort the request during the
second cycle of the addressing pipeline. In that case, the requester needs to
set the req_abort signal to 1.

When a request is aborted, and the ``core_req_i.need_rsp`` field was set to 1, the
HPDcache respond to the corresponding requester with the bit
``core_rsp_o.aborted`` set to 1.

CRI Type of Operation
~~~~~~~~~~~~~~~~~~~~~

A requester indicates the required operation on the 5-bit, ``HPDCACHE_REQ_OP``
signal. The supported operation are detailed in :numref:`tab_req_op_types`.

.. _tab_req_op_types:

.. list-table:: Requesters Operation Types
   :widths: 30 15 55
   :header-rows: 1

   * - Mnemonic
     - Encoding
     - Type
   * - ``HPDCACHE_REQ_LOAD``
     - 0b00000
     - Read operation
   * - ``HPDCACHE_REQ_STORE``
     - 0b00001
     - Write operation
   * - ``HPDCACHE_REQ_AMO_LR``
     - 0b00100
     - Atomic Load-reserved operation
   * - ``HPDCACHE_REQ_AMO_SC``
     - 0b00101
     - Atomic Store-conditional operation
   * - ``HPDCACHE_REQ_AMO_SWAP``
     - 0b00110
     - Atomic SWAP operation
   * - ``HPDCACHE_REQ_AMO_ADD``
     - 0b00111
     - Atomic integer ADD operation
   * - ``HPDCACHE_REQ_AMO_AND``
     - 0b01000
     - Atomic bitwise AND operation
   * - ``HPDCACHE_REQ_AMO_OR``
     - 0b01001
     - Atomic bitwise OR operation
   * - ``HPDCACHE_REQ_AMO_XOR``
     - 0b01010
     - Atomic bitwise XOR operation
   * - ``HPDCACHE_REQ_AMO_MAX``
     - 0b01011
     - Atomic integer signed MAX operation
   * - ``HPDCACHE_REQ_AMO_MAXU``
     - 0b01100
     - Atomic integer unsigned MAX operation
   * - ``HPDCACHE_REQ_AMO_MIN``
     - 0b01101
     - Atomic integer signed MIN operation
   * - ``HPDCACHE_REQ_AMO_MINU``
     - 0b01110
     - Atomic integer unsigned MIN operation
   * - ``HPDCACHE_CMO_FENCE``
     - 0b10000
     - Memory write fence
   * - ``HPDCACHE_CMO_PREFETCH``
     - 0b10001
     - Prefetch a cacheline given its address
   * - ``HPDCACHE_CMO_INVAL_NLINE``
     - 0b10010
     - Invalidate a cacheline given its address
   * - ``HPDCACHE_CMO_INVAL_ALL``
     - 0b10011
     - Invalidate all Cachelines
   * - ``HPDCACHE_CMO_FLUSH_NLINE``
     - 0b10100
     - Flush a cacheline given its Address
   * - ``HPDCACHE_CMO_FLUSH_ALL``
     - 0b10101
     - Flush All Cachelines
   * - ``HPDCACHE_CMO_FLUSH_INVAL_NLINE``
     - 0b10110
     - Flush and invalidate a cacheline given its address
   * - ``HPDCACHE_CMO_FLUSH_INVAL_ALL``
     - 0b10111
     - Flush and invalidate all cachelines
...
.. _sec_req_cacheability:

Cacheability
~~~~~~~~~~~~

This cache considers that the memory space is segmented. A segment corresponds
to an address range: a **base address** and an **end address**. Some segments
are cacheable and others not. The HPDcache needs to know which segments are
cacheable to determine if for a given read request, it needs to copy the read
data into the cache.

The request interface implements an uncacheable bit
(``core_req_i.pma.uncacheable`` or ``core_req_pma_i.uncacheable``).  When this
bit is set, the access is considered uncacheable. The
``core_req_i.pma.uncacheable`` signal shall be decoded when the
``core_req_valid_i`` signal is set to 1. The ``core_req_pma_i.uncacheable``
shall be decoded when the ``core_req_valid_i``, ``core_req_ready_o`` and the
``core_req_i.phys_indexed`` signals were set to 1 the previous cycle.

.. admonition:: Caution
   :class: caution

   For a given address, the uncacheable attribute must be consistent between
   accesses. The granularity is the cacheline. **In the event that the same
   address is accessed with different values in the uncacheable attribute, the
   behavior of the cache for that address is unpredictable**.

Need response
~~~~~~~~~~~~~

For any given request, a requester can set the bit ``core_req_i.need_rsp`` to 0
to indicate that it does not want a response for that request. The
``core_req_i.need_rsp`` signal shall be decoded when the ``core_req_valid_i``
signal is set to 1.

When ``core_req_i.need_rsp`` is set to 0, the HPDcache processes the request
but it does not send an acknowledgement to the corresponding requester when the
transaction is completed.

Write-Policy Hint
~~~~~~~~~~~~~~~~~

The CRI may set dynamically the write-policy (write-back or write-through) for
the target cacheline. In the request interface, there are specific flags (hint)
to indicate the desired policy for a given request.

The request interface drives the hint through the
``core_req_i.pma.wr_policy_hint`` or ``core_req_pma_i.wr_policy_hint`` signals.
The ``core_req_i.pma.wr_policy_hint`` signal shall be decoded when the
``core_req_valid_i`` signal is set to 1. The ``core_req_pma_i.wr_policy_hint``
shall be decoded when the ``core_req_valid_i``, ``core_req_ready_o`` and the
``core_req_i.phys_indexed`` signals were set to 1 the previous cycle.

The supported hints are detailed in :numref:`tab_req_wr_policy_hints`.

.. _tab_req_wr_policy_hints:

.. list-table:: Requesters Write-Policy Hint
   :widths: 30 15 55
   :header-rows: 1

   * - Mnemonic
     - Encoding
     - Type
   * - ``HPDCACHE_WR_POLICY_AUTO``
     - 0b001
     - Request to to keep the current write-policy for the target cacheline if
       there is a copy in the cache, or use the default policy otherwise.
   * - ``HPDCACHE_WR_POLICY_WB``
     - 0b010
     - Request a write-back (write allocate) policy for the target cacheline
   * - ``HPDCACHE_WR_POLICY_WT``
     - 0b100
     - Request a write-through (write non-allocate) policy for the target
       cacheline

Error response
~~~~~~~~~~~~~~

The response interface contains a single-bit ``core_rsp_o.error`` signal.  This
signal is set to 1 by the HPDcache when some error condition occurred during the
processing of the corresponding request. The ``core_rsp_o.error`` signal shall
be decoded when the ``core_rsp_valid_o`` signal is set to 1.

When the ``core_rsp_o.error`` signal is set to 1 in the response, the effect of
the corresponding request is undefined. If this **error** signal is set in the
case of **LOAD** or **AMOs** operations, the **rdata** signal does not contain
any valid data.
...
Event signals
-------------

In addition to the performance registers explained in :ref:`sec_perf_counters`,
the HPDcache provides a set of one-shot signals that indicate when a given event
is detected.  These signals are set to 1 for one cycle each time the
corresponding event is detected. If the same event is detected N cycles in a
row, the corresponding event signal will remain set to 1 for N cycles.
:numref:`Table %s <tab_events>` lists these event signals.

These event signals are output-only. They can be either left unconnected, if
they are not used, or connected with the remainder of the system. The system can
use those signals, for example, for counting those events externally or for
triggering some specific actions.

.. _tab_events:

.. list-table:: Event Signals in the HPDcache
   :widths: 31 13 52
   :header-rows: 1

   * - **Signal**
     - **Source**
     - **Description**
   * - ``evt_o.write_req``
     - Cache
     - Write request accepted
   * - ``evt_o.read_req``
     - Cache
     - Read request accepted
   * - ``evt_o.prefetch_req``
     - Cache
     - Prefetch request accepted
   * - ``evt_o.uncached_req``
     - Cache
     - Uncached request accepted
   * - ``evt_o.cmo_req``
     - Cache
     - CMO request accepted
   * - ``evt_o.accepted_req``
     - Cache
     - One request accepted (any type)
   * - ``evt_o.cache_write_miss``
     - Cache
     - Write miss event
   * - ``evt_o.cache_read_miss``
     - Cache
     - Read miss event
   * - ``evt_o.req_onhold``
     - Cache
     - Request put on-hold in the RTAB
   * - ``evt_o.req_onhold_mshr``
     - Cache
     - Request put on-hold because of a MSHR conflict
   * - ``evt_o.req_onhold_wbuf``
     - Cache
     - Request put on-hold because of a WBUF conflict
   * - ``evt_o.req_onhold_rollback``
     - Cache
     - Request put on-hold (again) after a rollback
   * - ``evt_o.stall``
     - Cache
     - Cache stalls request event
```

### `docs/source/cmo.rst`

```text
Memory Write Fence
------------------
...
As for any regular request, the request shall follow the **VALID**/**READY**
handshake protocol described in :ref:`sec_ready_valid_handshake`.

This memory fence operation has the following effects:

- All open entries in the write buffer (write requests waiting to be sent to the
  memory) are immediately closed;

- No new requests from any requester are acknowledged until all pending write
  requests in the cache have been acknowledged on the NoC interface.

When the memory fence transaction is completed, and the ``core_req_o.need_rsp``
signal was set to 1, an acknowledgement is sent to the corresponding requester.


Invalidate a Cacheline Given its Address
----------------------------------------
...
This CMO request supports both virtual or physical indexed requests (see
:ref:`sec_vipt`).

Regarding the latency of this operation, only one cycle is needed to invalidate
the corresponding cacheline. However, if there is a pending read miss on the
target address, the HPDcache waits for the response of the read miss then
invalidates the corresponding cacheline.

If the target address is not cached, the operation does nothing.

When the invalidation transaction is completed, and the ``core_req_o.need_rsp``
signal was set to 1, an acknowledgement is sent to the corresponding requester.


Invalidate All Cachelines
-------------------------
...
As for any regular request, the request shall follow the **VALID**/**READY**
handshake protocol (see :ref:`sec_ready_valid_handshake`).

This operation works as a memory read fence. This is, before handling the
operation, the HPDcache waits for all pending read misses to complete.

Regarding the latency of this operation, it has two aggregated components:

- The time to serve all pending reads.

- One cycle per set implemented in the HPDcache (all ways of a given set are
  invalidated simultaneously).

When the invalidation transaction is completed, and the ``core_req_o.need_rsp``
signal was set to 1, an acknowledgement is sent to the corresponding requester.


Prefetch a Cacheline given its Address
--------------------------------------
...
As for any regular request, the request shall follow the **VALID**/**READY**
handshake protocol (see :ref:`sec_ready_valid_handshake`). This CMO request
supports both virtual or physical indexed requests (see :ref:`sec_vipt`).

If the requested cacheline is already in the cache this request has no effect.
If the requested cacheline is not present in the cache, the cacheline is fetched
from the memory and replicated into the cache.

When the prefetch transaction is completed, and the ``core_req_o.need_rsp``
signal was set to 1, an acknowledgement is sent to the corresponding requester.
```

### `docs/source/amo.rst`

```text
Atomic Memory Operations (AMOs)
===============================

Background
----------

The AMOs are special load/store accesses that implements a read-modify-write
semantic. A single instruction is able to read a data from the memory, perform
an arithmetical/logical operation on that data, and store the result. All this
is performed as a single operation (no other operation can come in between the
read-modify-write operations).

These operations are meant for synchronization in multi-core environments. To
enable this synchronization, AMOs need to be performed on the PoS
(Point-of-Serialization), point where all accesses from the different cores
converge.  This is usually a shared cache memory (when multiple levels of cache
are implemented) or the external RAM controllers. Thus, the HPDcache needs to
forward these operations to the PoS through the NoC interface.

Supported AMOs
--------------

On the interface from requesters, the supported AMOs are the ones listed in
:numref:`Table %s <tab_req_op_types>`. The supported AMOs are the ones defined
in the atomic (A) extension of the RISC-V ISA specification [RISCVUP2019]_.

Implementation
--------------

If :math:`\scriptsize\mathsf{CONF\_HPDCACHE\_SUPPORT\_AMO}` is set to 0, the
HPDcache does not support AMOs from requesters.
See :ref:`sec_uncacheable_handler` for more details.

When a requester performs an AMO operation, the HPDcache needs to forward it to
the PoS. It is only at the PoS that AMOs from different caches converge and thus
where the correct result may be computed in case of multiple, simultaneous,
address-colliding AMOs. In the case a cache has a replica of the target address,
as the modification is performed at the PoS, that replica becomes obsolete
(cache obsolescence problem). This issue shall be solved through a hardware (or
software) cache coherency protocol.

To provide a consistent view of the data, the HPDcache updates the local replica
based on the result from the memory. The procedure is as follows: Forward the
AMO to the PoS, and wait for the response with the old data. If the target
address is replicated in the HPDcache, the HPDcache computes the new value
locally based on the data from the AMO request and the old data from the memory
(not the data of the local replica). Then it updates the replica. This allows
the core to have a consistent view with regards to its operations (single-thread
consistency). However, a cache coherency protocol (hardware or software) is
still required to ensure coherency in multi-core systems.

The HPDcache handle AMOs as non-allocating operations. This is, AMOs never fetch
a replica of the target cacheline from the memory to the cache. If the target
cacheline IS NOT replicated in the cache, the AMO modifies ONLY the memory. If
the target cacheline IS replicated in the cache, the AMO modifies BOTH the
memory and the cache.


AMO ordering
------------

As specified in the RISC-V ISA specification [RISCVUP2019]_, the base RISC-V ISA
has a relaxed memory model. To provide additional ordering constraints, AMOs
(including LR/SC) specify two bits, *aq* and *rl*, for *acquire* and *release*
semantics.

The HPDcache ignores *aq* and *rl* bits. It considers that they are always set.
Hence, HPDcache handles AMOs as sequentially consistent memory operations. The
HPDcache waits for all pending read and write operations to complete before
serving the AMO request.

This behavior implies that when the HPDcache forwards an AMO to the NoC, it will
be the only pending request from the HPDcache. In addition, no new requests from
the requesters are served until the AMO is completed.

```
