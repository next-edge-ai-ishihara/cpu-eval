# Implement `hpdcache_cmo`

Implement the complete `hpdcache_cmo` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_cmo` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv64a6_imafdc_sv39_hpdcache_wb_config_pkg.sv`

```systemverilog
  localparam CVA6ConfigDcacheByteSize = 32768;
  localparam CVA6ConfigDcacheSetAssoc = 8;
  localparam CVA6ConfigDcacheLineWidth = 128;
  // do not flush Dcache for EVERY fence - dramatic performance impact
  // use RVZiCbom to synchronize caches with DMA devices instead
  // CAUTION - a configuration with CVA6ConfigDcacheFlushOnFence might be required for different SoCs, e.g., cache-coherent SMP configurations
  localparam CVA6ConfigDcacheFlushOnFence = 1'b0;
  localparam CVA6ConfigDcacheFlushOnFenceI = 1'b1;
  localparam CVA6ConfigDcacheInvalidateOnFlush = 1'b0;
// ...
  localparam config_pkg::cache_type_t CVA6ConfigDcacheType = config_pkg::HPDCACHE_WB;

```

### `core/include/build_config_pkg.sv`

```systemverilog
    cfg.DCacheType = CVA6Cfg.DCacheType;
    cfg.DcacheIdWidth = CVA6Cfg.DcacheIdWidth;
    cfg.DCACHE_SET_ASSOC = CVA6Cfg.DcacheSetAssoc;
    cfg.DCACHE_SET_ASSOC_WIDTH = CVA6Cfg.DcacheSetAssoc > 1 ? $clog2(CVA6Cfg.DcacheSetAssoc) :
        CVA6Cfg.DcacheSetAssoc;
    cfg.DCACHE_INDEX_WIDTH = DCACHE_INDEX_WIDTH;
    cfg.DCACHE_TAG_WIDTH = cfg.PLEN - DCACHE_INDEX_WIDTH;
    cfg.DCACHE_LINE_WIDTH = CVA6Cfg.DcacheLineWidth;
    cfg.DCACHE_USER_LINE_WIDTH = (CVA6Cfg.AxiUserWidth == 1) ? 4 : CVA6Cfg.DcacheLineWidth;
    cfg.DCACHE_USER_WIDTH = CVA6Cfg.AxiUserWidth;
    cfg.DCACHE_OFFSET_WIDTH = DCACHE_OFFSET_WIDTH;
    cfg.DCACHE_NUM_WORDS = 2 ** (DCACHE_INDEX_WIDTH - DCACHE_OFFSET_WIDTH);

    cfg.DCACHE_MAX_TX = unsigned'(2 ** CVA6Cfg.MemTidWidth);

    cfg.DcacheFlushOnFence = CVA6Cfg.DcacheFlushOnFence;
    cfg.DcacheFlushOnFenceI = CVA6Cfg.DcacheFlushOnFenceI;
    cfg.DcacheInvalidateOnFlush = CVA6Cfg.DcacheInvalidateOnFlush;

```

### `core/cache_subsystem/cva6_hpdcache_subsystem.sv`

```systemverilog
  function automatic hpdcache_pkg::hpdcache_user_cfg_t hpdcacheSetConfig();
    hpdcache_pkg::hpdcache_user_cfg_t userCfg;
    userCfg.nRequesters = HPDCACHE_NREQUESTERS;
    userCfg.paWidth = CVA6Cfg.PLEN;
    userCfg.wordWidth = CVA6Cfg.XLEN;
    userCfg.sets = CVA6Cfg.DCACHE_NUM_WORDS;
    userCfg.ways = CVA6Cfg.DCACHE_SET_ASSOC;
// ...
    userCfg.wbEn =
        (CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WB) ||
        (CVA6Cfg.DCacheType == config_pkg::HPDCACHE_WT_WB);

```

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
    //  Definition of constants and types for the CMO request handler (CMOH)
    //  {{{
    typedef struct packed {
        logic is_flush_inval_all;
        logic is_flush_all;
        logic is_inval_all;
    } hpdcache_cmoh_op_t;
    //  }}}
// ...
    //  Definition of parameters
    //  {{{
    typedef struct packed {
        //  Number of requesters
        int unsigned nRequesters;
        //  Physical Address Width
        int unsigned paWidth;
        //  Word width (bits)
        int unsigned wordWidth;
        //  Number of sets
        int unsigned sets;
        //  Number of ways
        int unsigned ways;
        //  Cache-Line width (words)
        int unsigned clWords;
        //  Number of words in the request data channels (request and response)
        int unsigned reqWords;
        //  Request transaction ID width (bits)
        int unsigned reqTransIdWidth;
        //  Request source ID width (bits)
        int unsigned reqSrcIdWidth;
        //  Victim select
        hpdcache_victim_sel_policy_t victimSel;
        //  Number of ways per RAM entry
        int unsigned dataWaysPerRamWord;
        //  Number of sets per RAM
        int unsigned dataSetsPerRam;
        //  DATA RAM macros implement write byte enable
        //  -  Write byte enable (1'b1)
        //  -  Write bit mask (1'b0)
        bit dataRamByteEnable;
        //  Define the number of memory contiguous words that can be accessed
        //  simultaneously from the cache.
        //  -  This limits the maximum width for the data channel from requesters
        //  -  This impacts the refill latency (more ACCESS_WORDS -> less REFILL LATENCY)
        int unsigned accessWords;
        //  MSHR number of sets
        int unsigned mshrSets;
        //  MSHR number of ways
        int unsigned mshrWays;
        //  MSHR number of ways in the same SRAM word (entry)
        int unsigned mshrWaysPerRamWord;
        //  MSHR number of sets in the same SRAM
        int unsigned mshrSetsPerRam;
        //  MSHR macros implement write byte enable
        //  -  Write byte enable (1'b1)
        //  -  Write bit mask (1'b0)
        bit mshrRamByteEnable;
        //  MSHR uses whether FFs or SRAM
        bit mshrUseRegbank;
        //  Store and refill coalesce buffer entries
        int unsigned cbufEntries;
        //  Use feedthrough FIFOs from the refill handler to the core
        bit refillCoreRspFeedthrough;
        //  Depth of the refill FIFO
        int refillFifoDepth;
        //  Write-Buffer number of entries in the directory
        int unsigned wbufDirEntries;
        //  Write-Buffer number of entries in the data buffer
        int unsigned wbufDataEntries;
        //  Write-Buffer number of words per entry
        int unsigned wbufWords;
        //  Write-Buffer threshold counter width (in bits)
        int unsigned wbufTimecntWidth;
        //  Number of entries in the replay table
        int unsigned rtabEntries;
        //  Number of entries in the flush directory
        int unsigned flushEntries;
        //  Depth of the flush FIFO
        int unsigned flushFifoDepth;
        //  Width of the address in the memory interface
        int unsigned memAddrWidth;
        //  Width of the ID in the memory interface
        int unsigned memIdWidth;
        //  Width of the data in the memory interface
        int unsigned memDataWidth;
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

        //  Internal parameters
        int unsigned clWidth;
        int unsigned clWordIdxWidth;
        int unsigned clOffsetWidth;
        int unsigned wordByteIdxWidth;
        int unsigned wayIndexWidth;
        int unsigned setWidth;
        int unsigned nlineWidth;
        int unsigned tagWidth;
        int unsigned reqWordIdxWidth;
        int unsigned reqOffsetWidth;
        int unsigned reqDataWidth;
        int unsigned reqDataBytes;
        int unsigned mshrSetWidth;
        int unsigned mshrWayWidth;
        int unsigned cbufEntryWidth;
        int unsigned wbufDataWidth;
        int unsigned wbufDirPtrWidth;
        int unsigned wbufDataPtrWidth;
        int unsigned accessWidth;
        int unsigned accessBytes;
    } hpdcache_cfg_t;

```

## Module declaration

```systemverilog
module hpdcache_cmo
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_data_word_t = logic,
    parameter type hpdcache_way_vector_t = logic,

    parameter type hpdcache_rsp_t = logic,
    parameter type hpdcache_req_addr_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_data_t = logic
)
//  }}}

//  Ports
//  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //  Request interface
    //  {{{
    input  logic                  req_valid_i,
    output logic                  req_ready_o,
    input  hpdcache_cmoh_op_t     req_op_i,
    input  hpdcache_req_addr_t    req_addr_i,
    input  hpdcache_req_sid_t     req_sid_i,
    input  hpdcache_req_tid_t     req_tid_i,
    input  logic                  req_need_rsp_i,
    //  }}}

    //  Dirty/Valid tracking interface
    //  {{{
    input logic                   dirty_set_en_i,
    input hpdcache_set_t          dirty_min_set_i,
    input hpdcache_set_t          dirty_max_set_i,
    input logic                   valid_set_en_i,
    input hpdcache_set_t          valid_min_set_i,
    input hpdcache_set_t          valid_max_set_i,
    output logic                  flush_all_o,
    output logic                  inval_all_o,
    //  }}}

    //  Core response interface
    //  {{{
    input  logic                  core_rsp_ready_i,
    output logic                  core_rsp_valid_o,
    output hpdcache_rsp_t         core_rsp_o,
    //  }}}

    //  Cache Directory Interface
    //  {{{
    output logic                  dir_check_entry_o,
    output hpdcache_set_t         dir_check_entry_set_o,
    output hpdcache_way_vector_t  dir_check_entry_way_o,
    input  logic                  dir_check_entry_valid_i,
    input  logic                  dir_check_entry_wback_i,
    input  logic                  dir_check_entry_dirty_i,
    input  hpdcache_tag_t         dir_check_entry_tag_i,

    output logic                  dir_updt_o,
    output hpdcache_set_t         dir_updt_set_o,
    output hpdcache_way_vector_t  dir_updt_way_o,
    output logic                  dir_updt_valid_o,
    output logic                  dir_updt_wback_o,
    output logic                  dir_updt_dirty_o,
    output logic                  dir_updt_fetch_o,
    output hpdcache_tag_t         dir_updt_tag_o,
    // }}}

    //  Flush Controller Interface
    //  {{{
    input  logic                  flush_empty_i,
    output logic                  flush_alloc_o,
    input  logic                  flush_alloc_ready_i,
    output hpdcache_nline_t       flush_alloc_nline_o,
    output hpdcache_way_vector_t  flush_alloc_way_o
    // }}}
);

```

## Parent instantiation

### `rtl/src/hpdcache.sv`

```systemverilog
    hpdcache_cmo #(
        .HPDcacheCfg                   (HPDcacheCfg),

        .hpdcache_nline_t              (hpdcache_nline_t),
        .hpdcache_tag_t                (hpdcache_tag_t),
        .hpdcache_set_t                (hpdcache_set_t),
        .hpdcache_data_word_t          (hpdcache_data_word_t),
        .hpdcache_way_vector_t         (hpdcache_way_vector_t),

        .hpdcache_rsp_t                (hpdcache_rsp_t),
        .hpdcache_req_addr_t           (hpdcache_req_addr_t),
        .hpdcache_req_tid_t            (hpdcache_req_tid_t),
        .hpdcache_req_sid_t            (hpdcache_req_sid_t),
        .hpdcache_req_data_t           (hpdcache_req_data_t)
    ) hpdcache_cmo_i(
        .clk_i,
        .rst_ni,

        .req_valid_i                   (cmo_req_valid),
        .req_ready_o                   (cmo_ready),
        .req_op_i                      (cmo_req_op),
        .req_addr_i                    (cmo_req_addr),
        .req_sid_i                     (cmo_req_sid),
        .req_tid_i                     (cmo_req_tid),
        .req_need_rsp_i                (cmo_req_need_rsp),

        .dirty_set_en_i                (cmo_dirty_set_en),
        .dirty_min_set_i               (cmo_dirty_min_set),
        .dirty_max_set_i               (cmo_dirty_max_set),
        .valid_set_en_i                (cmo_valid_set_en),
        .valid_min_set_i               (cmo_valid_min_set),
        .valid_max_set_i               (cmo_valid_max_set),
        .flush_all_o                   (cmo_flush_all),
        .inval_all_o                   (cmo_inval_all),

        .core_rsp_ready_i              (cmo_core_rsp_ready),
        .core_rsp_valid_o              (cmo_core_rsp_valid),
        .core_rsp_o                    (cmo_core_rsp),


        .dir_check_entry_o             (cmo_dir_check_entry),
        .dir_check_entry_set_o         (cmo_dir_check_entry_set),
        .dir_check_entry_way_o         (cmo_dir_check_entry_way),
        .dir_check_entry_valid_i       (cmo_dir_check_entry_valid),
        .dir_check_entry_wback_i       (cmo_dir_check_entry_wback),
        .dir_check_entry_dirty_i       (cmo_dir_check_entry_dirty),
        .dir_check_entry_tag_i         (cmo_dir_check_entry_tag),

        .dir_updt_o                    (cmo_dir_updt),
        .dir_updt_set_o                (cmo_dir_updt_set),
        .dir_updt_way_o                (cmo_dir_updt_way),
        .dir_updt_valid_o              (cmo_dir_updt_valid),
        .dir_updt_wback_o              (cmo_dir_updt_wback),
        .dir_updt_dirty_o              (cmo_dir_updt_dirty),
        .dir_updt_fetch_o              (cmo_dir_updt_fetch),
        .dir_updt_tag_o                (cmo_dir_updt_tag),

        .flush_empty_i                 (flush_empty),
        .flush_alloc_o                 (cmo_flush_alloc),
        .flush_alloc_ready_i           (flush_alloc_ready),
        .flush_alloc_nline_o           (cmo_flush_alloc_nline),
        .flush_alloc_way_o             (cmo_flush_alloc_way)
    );
// ...
    //  Flush controller
    //  {{{
    if (HPDcacheCfg.u.wbEn) begin : gen_flush
        assign flush_alloc = ctrl_flush_alloc | cmo_flush_alloc;
        assign flush_alloc_nline =
            ctrl_flush_alloc ? ctrl_flush_alloc_nline : cmo_flush_alloc_nline;
        assign flush_alloc_way =
            ctrl_flush_alloc ? ctrl_flush_alloc_way : cmo_flush_alloc_way;

```

## Dependency declarations

### `rtl/include/hpdcache_typedef.svh`

```systemverilog
`define HPDCACHE_DECL_RSP_T(__data_t, __sid_t, __tid_t) \
    struct packed { \
        __data_t rdata; \
        __sid_t  sid; \
        __tid_t  tid; \
        logic    error; \
        logic    aborted; \
    }

`define HPDCACHE_TYPEDEF_RSP_T(__name__, __data_t, __sid_t, __tid_t) \
    typedef `HPDCACHE_DECL_RSP_T(__data_t, __sid_t, __tid_t) __name__

```

### `rtl/src/common/hpdcache_sync_buffer.sv`

```systemverilog
module hpdcache_sync_buffer
    //  Parameters
    //  {{{
#(
    parameter bit FEEDTHROUGH = 1'b0,
    parameter type data_t = logic
)
    //  }}}
    //  Ports
    //  {{{
(
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        w_i,
    output logic        wok_o,
    input  data_t       wdata_i,
    input  logic        r_i,
    output logic        rok_o,
    output data_t       rdata_o
);

```

## Related source code

### `core/include/config_pkg.sv`

```systemverilog
    // three configurations for cache coherency after flush:
    // DcacheFlushOnFence causes dcache flush for every fence instruction
    // DcacheFlushOnFenceI causes dcache flush for every fence.I instruction
    // DcacheInvalidateOnFlush causes dcache to also be invalidated when flushed
    // tradeoff between coherence and efficiency, depending on remaining configuration:

    // DcacheFlushOnFenceI is required for write-back caches - otherwise, 
    // no way to reliably write instruction memory with store instructions, 
    // as data and instruction cache are currently not coherent
    // DcacheFlushOnFence is required for write-back caches to ensure coherency
    // with other harts or DMA devices --> a fence forces all stores to commit to memory
    // DcacheInvalidateOnFlush causes all dcache entries to become invalid, forcing the CPU
    // to fetch data from memory after each fence --> make writes from other harts or DMAs
    // visible to the CPU
    // thus, DcacheFlushOnFence and DcacheInvalidateOnFlush can ensure DMA coherency at high performance cost
    // using RVZiCbom can achieve the same effect at significantly lower performance cost
    // hence, on uniprocessor or not cache-coherent multiprocessor SoCs, one might want to disable both and use
    // explicit CBO operations for better overall performance
    bit          DcacheFlushOnFence;
    bit          DcacheFlushOnFenceI;
    bit          DcacheInvalidateOnFlush;

```

### `core/controller.sv`

```systemverilog
      // When handling fence.i, flush both caches and activate fence_i state
      if (CVA6Cfg.DcacheFlushOnFenceI) begin
        flush_dcache = 1'b1;
        fence_active_d = 1'b1;
        fence_i_active_d = 1'b1;
      end

```

### `core/cache_subsystem/cva6_hpdcache_wrapper.sv`

```systemverilog
        .InvalidateOnFlush    (CVA6Cfg.DcacheInvalidateOnFlush),

```

### `core/cache_subsystem/cva6_hpdcache_if_adapter.sv`

```systemverilog
      always_comb begin : flush_comb
        forward_flush = 1'b0;
        cva6_dcache_flush_ack_o = 1'b0;

        flush_fsm_d = flush_fsm_q;

        case (flush_fsm_q)
          FLUSH_IDLE: begin
            if (cva6_dcache_flush_i) begin
              forward_flush = 1'b1;
              if (hpdcache_req_ready_i) begin
                flush_fsm_d = FLUSH_PEND;
              end
            end
          end
          FLUSH_PEND: begin
            if (hpdcache_rsp_valid_i) begin
              if (hpdcache_rsp_i.tid == '0) begin
                cva6_dcache_flush_ack_o = 1'b1;
                flush_fsm_d = FLUSH_IDLE;
              end
            end
          end
// ...
      assign hpdcache_req_flush = '{
              addr_offset: '0,
              addr_tag: '0,
              wdata: '0,
              op:
              InvalidateOnFlush
              ?
              hpdcache_pkg::HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL
              :
              hpdcache_pkg::HPDCACHE_REQ_CMO_FLUSH_ALL,
              be: '0,
              size: '0,
              sid: hpdcache_req_sid_i,
              tid: '0,
              need_rsp: 1'b1,
              phys_indexed: 1'b0,

```

### `rtl/src/hpdcache_ctrl.sv`

```systemverilog
    //  CMO request handler outputs
    //  {{{
    assign cmo_req_addr_o                       = st1_req_addr;
    assign cmo_req_sid_o                        = st1_req.req.sid;
    assign cmo_req_tid_o                        = st1_req.req.tid;
    assign cmo_req_need_rsp_o                   = st1_req.req.need_rsp;
    assign cmo_req_op_o.is_inval_all            = st1_req_is_cmo_inval_all;
    assign cmo_req_op_o.is_flush_all            = st1_req_is_cmo_flush_all;
    assign cmo_req_op_o.is_flush_inval_all      = st1_req_is_cmo_flush_inval_all;
    //  }}}
// ...
    //  Dirty/valid cachelines tracking to accelerate flushes and invalidations triggered by CMOs
    //  {{{
    if (HPDcacheCfg.u.wbEn) begin : gen_cmo_dirty_set
        hpdcache_set_t cmo_dirty_min_set_q, cmo_dirty_min_set_d;
        hpdcache_set_t cmo_dirty_max_set_q, cmo_dirty_max_set_d;
        logic cmo_dirty_set_en_q, cmo_dirty_set_en_d;

        always_comb
        begin : cmo_dirty_min_max_set_comb
            automatic hpdcache_uint32 v_min;
            automatic hpdcache_uint32 v_max;
            unique if (st2_dir_updt_q && st2_dir_updt_dirty_q) begin
                //  Cacheline updated by the pipeline
                if (cmo_dirty_set_en_q) begin
                    v_min = hpdcache_min(hpdcache_uint32'(st2_dir_updt_set_q),
                        hpdcache_uint32'(cmo_dirty_min_set_q));
                    v_max = hpdcache_max(hpdcache_uint32'(st2_dir_updt_set_q),
                        hpdcache_uint32'(cmo_dirty_max_set_q));
                end else begin
                    v_min = hpdcache_uint32'(st2_dir_updt_set_q);
                    v_max = hpdcache_uint32'(st2_dir_updt_set_q);
                end
            end else if (refill_write_dir_i && refill_dir_entry_i.dirty) begin
                //  Cacheline directly written during refill
                if (cmo_dirty_set_en_q) begin
                    v_min = hpdcache_min(hpdcache_uint32'(refill_set_i),
                        hpdcache_uint32'(cmo_dirty_min_set_q));
                    v_max = hpdcache_max(hpdcache_uint32'(refill_set_i),
                        hpdcache_uint32'(cmo_dirty_max_set_q));
                end else begin
                    v_min = hpdcache_uint32'(refill_set_i);
                    v_max = hpdcache_uint32'(refill_set_i);
                end
            end else begin
                v_min = hpdcache_uint32'(cmo_dirty_min_set_q);
                v_max = hpdcache_uint32'(cmo_dirty_max_set_q);
            end
            cmo_dirty_min_set_d = hpdcache_set_t'(v_min);
            cmo_dirty_max_set_d = hpdcache_set_t'(v_max);
        end

        always_comb
        begin : cmo_dirty_set_en_comb
            unique if (
                (st2_dir_updt_q && st2_dir_updt_dirty_q) ||
                (refill_write_dir_i && refill_dir_entry_i.dirty))
            begin
                cmo_dirty_set_en_d = 1'b1;
            end else if (cmo_flush_all_i) begin
                cmo_dirty_set_en_d = 1'b0;
            end else begin
                cmo_dirty_set_en_d = cmo_dirty_set_en_q;
            end
        end

        always_ff @(posedge clk_i or negedge rst_ni)
        begin : cmo_dirty_ff
            if (!rst_ni) begin
                cmo_dirty_set_en_q <= 1'b0;
                cmo_dirty_min_set_q <= 0;
                cmo_dirty_max_set_q <= 0;
            end else begin
                cmo_dirty_set_en_q <= cmo_dirty_set_en_d;
                cmo_dirty_min_set_q <= cmo_dirty_min_set_d;
                cmo_dirty_max_set_q <= cmo_dirty_max_set_d;
            end
        end

        assign cmo_dirty_set_en_o = cmo_dirty_set_en_q;
        assign cmo_dirty_min_set_o = cmo_dirty_min_set_q;
        assign cmo_dirty_max_set_o = cmo_dirty_max_set_q;
    end else begin : gen_no_cmo_dirty_set
        assign cmo_dirty_set_en_o = 1'b0;
        assign cmo_dirty_min_set_o = '0;
        assign cmo_dirty_max_set_o = '0;
    end

    hpdcache_set_t cmo_valid_min_set_q, cmo_valid_min_set_d;
    hpdcache_set_t cmo_valid_max_set_q, cmo_valid_max_set_d;
    logic cmo_valid_set_en_q, cmo_valid_set_en_d;

    always_comb
    begin : cmo_valid_min_max_set_comb
        automatic hpdcache_uint32 v_min;
        automatic hpdcache_uint32 v_max;
        unique if (refill_write_dir_i && refill_dir_entry_i.valid) begin
            if (cmo_valid_set_en_q) begin
                v_min = hpdcache_min(hpdcache_uint32'(refill_set_i),
                    hpdcache_uint32'(cmo_valid_min_set_q));
                v_max = hpdcache_max(hpdcache_uint32'(refill_set_i),
                    hpdcache_uint32'(cmo_valid_max_set_q));
            end else begin
                v_min = hpdcache_uint32'(refill_set_i);
                v_max = hpdcache_uint32'(refill_set_i);
            end
        end else begin
            v_min = hpdcache_uint32'(cmo_valid_min_set_q);
            v_max = hpdcache_uint32'(cmo_valid_max_set_q);
        end
        cmo_valid_min_set_d = hpdcache_set_t'(v_min);
        cmo_valid_max_set_d = hpdcache_set_t'(v_max);
    end

    always_comb
    begin : cmo_valid_set_en_comb
        unique if (refill_write_dir_i && refill_dir_entry_i.valid) begin
            cmo_valid_set_en_d = 1'b1;
        end else if (cmo_inval_all_i) begin
            cmo_valid_set_en_d = 1'b0;
        end else begin
            cmo_valid_set_en_d = cmo_valid_set_en_q;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : cmo_valid_ff
        if (!rst_ni) begin
            cmo_valid_set_en_q <= 1'b0;
            cmo_valid_min_set_q <= 0;
            cmo_valid_max_set_q <= 0;
        end else begin
            cmo_valid_set_en_q <= cmo_valid_set_en_d;
            cmo_valid_min_set_q <= cmo_valid_min_set_d;
            cmo_valid_max_set_q <= cmo_valid_max_set_d;
        end
    end

    assign cmo_valid_set_en_o = cmo_valid_set_en_q;
    assign cmo_valid_min_set_o = cmo_valid_min_set_q;
    assign cmo_valid_max_set_o = cmo_valid_max_set_q;

```

### `rtl/src/hpdcache_flush.sv`

```systemverilog
module hpdcache_flush
//  {{{
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_word_t = logic,
    parameter type hpdcache_way_vector_t = logic,

    parameter type hpdcache_access_data_t = logic,

    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_data_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic
)
//  }}}

//  Ports
//  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Global control signals
    //      {{{
    output logic                  flush_empty_o,
    output logic                  flush_full_o,
    output logic                  flush_busy_o,
    //      }}}

    //      CHECK interface
    //      {{{
    input  hpdcache_nline_t       flush_check_nline_i,
    output logic                  flush_check_hit_o,
    //      }}}

    //      ALLOC interface
    //      {{{
    input  logic                  flush_alloc_i,
    output logic                  flush_alloc_ready_o,
    input  hpdcache_nline_t       flush_alloc_nline_i,
    input  hpdcache_way_vector_t  flush_alloc_way_i,
    //      }}}

```

## Documentation

### `docs/source/interface.rst`

```text
   * - ``HPDCACHE_CMO_INVAL_ALL``
     - 0b10011
     - Invalidate all Cachelines
...
   * - ``HPDCACHE_CMO_FLUSH_ALL``
     - 0b10101
     - Flush All Cachelines
...
   * - ``HPDCACHE_CMO_FLUSH_INVAL_ALL``
     - 0b10111
     - Flush and invalidate all cachelines

```

### `docs/source/cmo.rst`

```text
Invalidate All Cachelines
-------------------------

With this operation, all the cachelines in the HPDcache are invalidated.
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

```

### `docs/source/architecture.rst`

```text
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
The HPDcache cache uses SRAM macros for the directory and data parts of the
cache. These RAM macros are synchronous, read/write, single-port RAMs.

```
