# Implement `hpdcache_memctrl`

Implement the complete `hpdcache_memctrl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_memctrl` definition in a single SystemVerilog code
block, with no text outside the block.

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
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

    function automatic hpdcache_cfg_t hpdcacheBuildConfig(input hpdcache_user_cfg_t p);
        hpdcache_cfg_t ret;

        ret.u = p;

        ret.clWidth = p.clWords * p.wordWidth;
        ret.clOffsetWidth = $clog2(ret.clWidth / 8);
        ret.clWordIdxWidth = $clog2(p.clWords);
        ret.wordByteIdxWidth = $clog2(p.wordWidth / 8);
        ret.wayIndexWidth = (p.ways > 1) ? $clog2(p.ways) : 1;
        ret.setWidth = $clog2(p.sets);
        ret.nlineWidth = p.paWidth - ret.clOffsetWidth;
        ret.tagWidth = ret.nlineWidth - ret.setWidth;
        ret.reqWordIdxWidth = $clog2(p.reqWords);
        ret.reqOffsetWidth = p.paWidth - ret.tagWidth;
        ret.reqDataWidth = p.reqWords * p.wordWidth;
        ret.reqDataBytes = ret.reqDataWidth/8;

        ret.mshrSetWidth = (p.mshrSets > 1) ? $clog2(p.mshrSets) : 1;
        ret.mshrWayWidth = (p.mshrWays > 1) ? $clog2(p.mshrWays) : 1;

        ret.cbufEntryWidth = (p.cbufEntries > 1) ? $clog2(p.cbufEntries) : 1;

        ret.wbufDataWidth = ret.reqDataWidth*p.wbufWords;
        ret.wbufDirPtrWidth = $clog2(p.wbufDirEntries);
        ret.wbufDataPtrWidth = $clog2(p.wbufDataEntries);

        ret.accessWidth = p.accessWords * p.wordWidth;
        ret.accessBytes = ret.accessWidth/8;

        return ret;
    endfunction

```

## Module declaration

```systemverilog
module hpdcache_memctrl
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_word_t = logic,
    parameter type hpdcache_way_vector_t = logic,
    parameter type hpdcache_dir_entry_t = logic,

    parameter type hpdcache_data_word_t = logic,
    parameter type hpdcache_data_be_t = logic,

    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,

    parameter type hpdcache_access_data_t = logic,
    parameter type hpdcache_access_be_t = logic
)
    //  }}}

    //  Ports
    //  {{{
(
    //      Global clock and reset signals
    //      {{{
    input  logic                                clk_i,
    input  logic                                rst_ni,
    //      }}}

    //      Global control signals
    //      {{{
    output logic                                ready_o,
    output logic                                rd_wr_conflict_o,
    //      }}}

    //      DIR array access interface
    //      {{{
    input  logic                                dir_match_i,
    input  hpdcache_set_t                       dir_match_set_i,
    input  hpdcache_tag_t                       dir_match_tag_i,
    input  logic                                dir_updt_sel_victim_i,
    output hpdcache_way_vector_t                dir_hit_way_o,
    output hpdcache_tag_t                       dir_hit_tag_o,
    output logic                                dir_hit_wback_o,
    output logic                                dir_hit_dirty_o,
    output logic                                dir_hit_fetch_o,

    input  logic                                dir_updt_i,
    input  hpdcache_set_t                       dir_updt_set_i,
    input  hpdcache_way_vector_t                dir_updt_way_i,
    input  hpdcache_tag_t                       dir_updt_tag_i,
    input  logic                                dir_updt_valid_i,
    input  logic                                dir_updt_wback_i,
    input  logic                                dir_updt_dirty_i,
    input  logic                                dir_updt_fetch_i,

    input  logic                                dir_refill_i,
    input  hpdcache_set_t                       dir_refill_set_i,
    input  hpdcache_way_vector_t                dir_refill_way_i,
    input  hpdcache_dir_entry_t                 dir_refill_entry_i,
    input  logic                                dir_refill_updt_sel_victim_i,

    input  logic                                dir_victim_sel_i,
    input  hpdcache_set_t                       dir_victim_set_i,
    output logic                                dir_victim_valid_o,
    output logic                                dir_victim_wback_o,
    output logic                                dir_victim_dirty_o,
    output hpdcache_tag_t                       dir_victim_tag_o,
    output hpdcache_way_vector_t                dir_victim_way_o,

    input  logic                                dir_inval_check_i,
    input  hpdcache_nline_t                     dir_inval_nline_i,
    input  logic                                dir_inval_write_i,
    output logic                                dir_inval_hit_o,

    input  logic                                dir_cmo_check_entry_i,
    input  hpdcache_set_t                       dir_cmo_check_entry_set_i,
    input  hpdcache_way_vector_t                dir_cmo_check_entry_way_i,
    output logic                                dir_cmo_check_entry_valid_o,
    output logic                                dir_cmo_check_entry_wback_o,
    output logic                                dir_cmo_check_entry_dirty_o,
    output hpdcache_tag_t                       dir_cmo_check_entry_tag_o,

    input  logic                                dir_cmo_updt_i,
    input  hpdcache_set_t                       dir_cmo_updt_set_i,
    input  hpdcache_way_vector_t                dir_cmo_updt_way_i,
    input  hpdcache_tag_t                       dir_cmo_updt_tag_i,
    input  logic                                dir_cmo_updt_valid_i,
    input  logic                                dir_cmo_updt_wback_i,
    input  logic                                dir_cmo_updt_dirty_i,
    input  logic                                dir_cmo_updt_fetch_i,

    //          Directory Error Correction
    //          {{{
    //              To stage 1
    output hpdcache_way_vector_t                dir_err_cor_o,
    output hpdcache_way_vector_t                dir_err_unc_o,
    output hpdcache_way_vector_t                dir_err_valid_o,
    output hpdcache_way_vector_t                dir_err_dirty_o,

    //              From/to error recovery handler
    input  hpdcache_set_t                       dir_err_set_i,
    input  hpdcache_way_vector_t                dir_err_way_i,
    input  logic                                dir_err_read_i,
    output hpdcache_dir_entry_t                 dir_err_rdata_o,
    input  logic                                dir_err_write_i,
    input  hpdcache_dir_entry_t                 dir_err_wdata_i,
    //          }}}
    //      }}}

    //      DATA array access interface
    //      {{{
    input  logic                                data_req_read_i,
    input  hpdcache_set_t                       data_req_read_set_i,
    input  hpdcache_req_size_t                  data_req_read_size_i,
    input  hpdcache_word_t                      data_req_read_word_i,
    input  hpdcache_way_vector_t                data_req_read_way_i,
    output hpdcache_req_data_t                  data_req_read_data_o,

    input  logic                                data_req_write_i,
    input  logic                                data_req_write_enable_i,
    input  logic                                data_req_write_merge_i,
    input  hpdcache_set_t                       data_req_write_set_i,
    input  hpdcache_way_vector_t                data_req_write_way_i,
    input  hpdcache_req_size_t                  data_req_write_size_i,
    input  hpdcache_word_t                      data_req_write_word_i,
    input  hpdcache_req_data_t                  data_req_write_data_i,
    input  hpdcache_req_be_t                    data_req_write_be_i,

    input  logic                                data_amo_write_i,
    input  logic                                data_amo_write_enable_i,
    input  hpdcache_set_t                       data_amo_write_set_i,
    input  hpdcache_req_size_t                  data_amo_write_size_i,
    input  hpdcache_word_t                      data_amo_write_word_i,
    input  hpdcache_way_vector_t                data_amo_write_way_i,
    input  hpdcache_req_data_t                  data_amo_write_data_i,
    input  hpdcache_req_be_t                    data_amo_write_be_i,

    input  logic                                data_flush_read_i,
    input  hpdcache_set_t                       data_flush_read_set_i,
    input  hpdcache_word_t                      data_flush_read_word_i,
    input  hpdcache_way_vector_t                data_flush_read_way_i,
    output hpdcache_access_data_t               data_flush_read_data_o,

    input  logic                                data_refill_i,
    input  hpdcache_set_t                       data_refill_set_i,
    input  hpdcache_way_vector_t                data_refill_way_i,
    input  hpdcache_word_t                      data_refill_word_i,
    input  hpdcache_access_data_t               data_refill_data_i,

    output hpdcache_way_vector_t                data_err_cor_o,
    output hpdcache_way_vector_t                data_err_unc_o,
    input  hpdcache_set_t                       data_err_set_i,
    input  hpdcache_way_vector_t                data_err_way_i,
    input  hpdcache_word_t                      data_err_word_i,
    input  logic                                data_err_read_i,
    output hpdcache_access_data_t               data_err_rdata_o,
    input  logic                                data_err_write_i,
    input  hpdcache_access_data_t               data_err_wdata_i
    //      }}}
);

```

## Parent instantiation

### `rtl/src/hpdcache_ctrl.sv`

```systemverilog
    hpdcache_ctrl_pe #(
        .HPDcacheCfg(HPDcacheCfg)
    ) hpdcache_ctrl_pe_i(

// ...

        .req_cachedata_read_o               (data_req_read),
        .rd_wr_conflict_i                   (rd_wr_conflict),

// ...

    //  Controller for the HPDcache directory and data memory arrays
    //  {{{
    assign st0_req_set = st0_req.req.addr_offset[HPDcacheCfg.clOffsetWidth +:
                                                 HPDcacheCfg.setWidth];
    assign st0_req_word = st0_req.req.addr_offset[HPDcacheCfg.wordByteIdxWidth +:
                                                  HPDcacheCfg.clWordIdxWidth];

    assign st1_req_set = st1_req.req.addr_offset[HPDcacheCfg.clOffsetWidth +:
                                                 HPDcacheCfg.setWidth];
    assign st1_req_word = st1_req.req.addr_offset[HPDcacheCfg.wordByteIdxWidth +:
                                                  HPDcacheCfg.clWordIdxWidth];
    assign st1_req_addr = {st1_req.req.addr_tag, st1_req.req.addr_offset};
    assign st1_req_nline = st1_req_addr[HPDcacheCfg.clOffsetWidth +: HPDcacheCfg.nlineWidth];

    assign st1_victim_nline = {st1_dir_victim_tag, st1_req_set};

    //  When lowLatency, data SRAM is read at stage 0 but way selection is done at stage 1
    if (HPDcacheCfg.u.lowLatency) begin : gen_st0_data_sram_read
        assign data_req_read_set = st0_req_set;
        assign data_req_read_size = st0_req.req.size;
        assign data_req_read_word = st0_req_word;
        assign data_req_read_way = st1_dir_hit_way;
    end
    //  When not lowLatency, data SRAM is read at stage 1 but way selection is done at stage 2
    else begin : gen_st1_data_sram_read
        assign data_req_read_set = st1_req_set;
        assign data_req_read_size = st1_req.req.size;
        assign data_req_read_word = st1_req_word;
        always_ff @(posedge clk_i or negedge rst_ni)
        begin : data_req_read_way_ff
            if (!rst_ni) begin
                data_req_read_way <= '0;
            end else begin
                data_req_read_way <= st1_dir_hit_way;
            end
        end
    end

    hpdcache_memctrl #(
        .HPDcacheCfg                   (HPDcacheCfg),
        .hpdcache_nline_t              (hpdcache_nline_t),
        .hpdcache_tag_t                (hpdcache_tag_t),
        .hpdcache_set_t                (hpdcache_set_t),
        .hpdcache_word_t               (hpdcache_word_t),
        .hpdcache_way_vector_t         (hpdcache_way_vector_t),
        .hpdcache_dir_entry_t          (hpdcache_dir_entry_t),
        .hpdcache_data_word_t          (hpdcache_data_word_t),
        .hpdcache_data_be_t            (hpdcache_data_be_t),
        .hpdcache_req_data_t           (hpdcache_req_data_t),
        .hpdcache_req_be_t             (hpdcache_req_be_t),
        .hpdcache_access_data_t        (hpdcache_access_data_t),
        .hpdcache_access_be_t          (hpdcache_access_be_t)
    ) hpdcache_memctrl_i(
        .clk_i,
        .rst_ni,

        .ready_o                       (hpdcache_init_ready),
        .rd_wr_conflict_o              (rd_wr_conflict),

        .dir_match_i                   (st0_req_cachedir_read),
        .dir_match_set_i               (st0_req_set),
        .dir_match_tag_i               (st1_req.req.addr_tag),
        .dir_updt_sel_victim_i         (st1_req_updt_sel_victim),
        .dir_hit_way_o                 (st1_dir_hit_way),
        .dir_hit_tag_o                 (st1_dir_hit_tag),
        .dir_hit_wback_o               (st1_dir_hit_wback),
        .dir_hit_dirty_o               (st1_dir_hit_dirty),
        .dir_hit_fetch_o               (st1_dir_hit_fetch),

        .dir_updt_i                    (st2_dir_updt_q),
        .dir_updt_set_i                (st2_dir_updt_set_q),
        .dir_updt_way_i                (st2_dir_updt_way_q),
        .dir_updt_tag_i                (st2_dir_updt_tag_q),
        .dir_updt_valid_i              (st2_dir_updt_valid_q),
        .dir_updt_wback_i              (st2_dir_updt_wback_q),
        .dir_updt_dirty_i              (st2_dir_updt_dirty_q),
        .dir_updt_fetch_i              (st2_dir_updt_fetch_q),

        .dir_refill_i                  (refill_write_dir_i),
        .dir_refill_set_i              (refill_set_i),
        .dir_refill_way_i              (refill_way_i),
        .dir_refill_entry_i            (refill_dir_entry_i),
        .dir_refill_updt_sel_victim_i  (refill_updt_sel_victim_i),

        .dir_victim_sel_i              (st1_victim_sel),
        .dir_victim_set_i              (st1_req_set),
        .dir_victim_valid_o            (st1_dir_victim_valid),
        .dir_victim_wback_o            (st1_dir_victim_wback),
        .dir_victim_dirty_o            (st1_dir_victim_dirty),
        .dir_victim_tag_o              (st1_dir_victim_tag),
        .dir_victim_way_o              (st1_dir_victim_way),

        .dir_inval_check_i             (inval_check_dir_i),
        .dir_inval_nline_i             (inval_nline_i),
        .dir_inval_write_i             (inval_write_dir_i),
        .dir_inval_hit_o               (inval_hit_o),

        .dir_cmo_check_entry_i         (cmo_dir_check_entry_i),
        .dir_cmo_check_entry_set_i     (cmo_dir_check_entry_set_i),
        .dir_cmo_check_entry_way_i     (cmo_dir_check_entry_way_i),
        .dir_cmo_check_entry_valid_o   (cmo_dir_check_entry_valid_o),
        .dir_cmo_check_entry_wback_o   (cmo_dir_check_entry_wback_o),
        .dir_cmo_check_entry_dirty_o   (cmo_dir_check_entry_dirty_o),
        .dir_cmo_check_entry_tag_o     (cmo_dir_check_entry_tag_o),

        .dir_cmo_updt_i                (cmo_dir_updt_i),
        .dir_cmo_updt_set_i            (cmo_dir_updt_set_i),
        .dir_cmo_updt_way_i            (cmo_dir_updt_way_i),
        .dir_cmo_updt_tag_i            (cmo_dir_updt_tag_i),
        .dir_cmo_updt_valid_i          (cmo_dir_updt_valid_i),
        .dir_cmo_updt_wback_i          (cmo_dir_updt_wback_i),
        .dir_cmo_updt_dirty_i          (cmo_dir_updt_dirty_i),
        .dir_cmo_updt_fetch_i          (cmo_dir_updt_fetch_i),

        .dir_err_cor_o                 (st1_dir_err_cor),
        .dir_err_unc_o                 (st1_dir_err_unc),
        .dir_err_valid_o               (st1_dir_err_valid),
        .dir_err_dirty_o               (st1_dir_err_dirty),

        .dir_err_set_i                 (err_set_q),
        .dir_err_way_i                 (err_way_q),
        .dir_err_read_i                (err_dir_read),
        .dir_err_rdata_o               (err_dir_rdata_d),
        .dir_err_write_i               (err_dir_write),
        .dir_err_wdata_i               (err_dir_wdata),

        .data_req_read_i               (data_req_read),
        .data_req_read_set_i           (data_req_read_set),
        .data_req_read_size_i          (data_req_read_size),
        .data_req_read_word_i          (data_req_read_word),
        .data_req_read_way_i           (data_req_read_way),
        .data_req_read_data_o          (data_req_read_data),

        .data_req_write_i              (st1_req_cachedata_write),
        .data_req_write_enable_i       (st1_req_cachedata_write_enable),
        .data_req_write_merge_i        (st1_req_cachedata_write_merge),
        .data_req_write_set_i          (st1_req_set),
        .data_req_write_way_i          (st1_dir_hit_way),
        .data_req_write_size_i         (st1_req.req.size),
        .data_req_write_word_i         (st1_req_word),
        .data_req_write_data_i         (st1_req.req.wdata),
        .data_req_write_be_i           (st1_req.req.be),

        .data_amo_write_i              (uc_data_amo_write_i),
        .data_amo_write_enable_i       (uc_data_amo_write_enable_i),
        .data_amo_write_set_i          (uc_data_amo_write_set_i),
        .data_amo_write_size_i         (uc_data_amo_write_size_i),
        .data_amo_write_word_i         (uc_data_amo_write_word_i),
        .data_amo_write_way_i          (uc_data_amo_write_way_i),
        .data_amo_write_data_i         (uc_data_amo_write_data_i),
        .data_amo_write_be_i           (uc_data_amo_write_be_i),

        .data_flush_read_i             (flush_data_read_i),
        .data_flush_read_set_i         (flush_data_read_set_i),
        .data_flush_read_way_i         (flush_data_read_way_i),
        .data_flush_read_word_i        (flush_data_read_word_i),
        .data_flush_read_data_o        (flush_data_read_data_o),

        .data_refill_i                 (refill_write_data_i),
        .data_refill_set_i             (refill_set_i),
        .data_refill_way_i             (refill_way_i),
        .data_refill_word_i            (refill_word_i),
        .data_refill_data_i            (refill_data_i),

        .data_err_cor_o                (st1_dat_err_cor),
        .data_err_unc_o                (st1_dat_err_unc),
        .data_err_set_i                (err_set_q),
        .data_err_way_i                (err_way_q),
        .data_err_word_i               (err_dat_word_q),
        .data_err_read_i               (err_dat_read),
        .data_err_rdata_o              (err_dat_rdata_d),
        .data_err_write_i              (err_dat_write),
        .data_err_wdata_i              (err_dat_wdata)
    );

    assign st1_dir_hit = |st1_dir_hit_way;
    //  }}}

```

## Dependency declarations

### `rtl/src/common/hpdcache_demux.sv`

```systemverilog
module hpdcache_demux
//  Parameters
//  {{{
#(
    //  Number of outputs
    parameter  int unsigned NOUTPUT     = 0,

    //  Width in bits of each input
    parameter  int unsigned DATA_WIDTH  = 0,

    //  Selector signal is one-hot encoded
    parameter  bit          ONE_HOT_SEL = 0,

    //  Compute the width of the selection signal
    localparam int unsigned NOUTPUT_LOG2 = $clog2(NOUTPUT),
    localparam int unsigned SEL_WIDTH    = ONE_HOT_SEL ? NOUTPUT : NOUTPUT_LOG2,

    localparam type data_t = logic [DATA_WIDTH-1:0],
    localparam type sel_t  = logic [SEL_WIDTH-1:0]
)
//  }}}

//  Ports
//  {{{
(
    input  data_t               data_i,
    input  sel_t                sel_i,
    output data_t [NOUTPUT-1:0] data_o
);
//  }}}

    if (ONE_HOT_SEL) begin : gen_onehot_sel
        always_comb
        begin : demux_comb
            for (int unsigned i = 0; i < NOUTPUT; i++) begin
                data_o[i] = sel_i[i] ? data_i : '0;
            end
        end
    end else begin : gen_bin_sel
        always_comb
        begin : demux_comb
            for (int unsigned i = 0; i < NOUTPUT; i++) begin
                data_o[i] = (sel_t'(i) == sel_i) ? data_i : '0;
            end
        end
    end
endmodule

```

### `rtl/src/common/hpdcache_mux.sv`

```systemverilog
module hpdcache_mux
    //  Parameters
    //  {{{
#(
    //  Number of inputs
    parameter  int unsigned NINPUT      = 0,

    //  Width in bits of each input
    parameter  int unsigned DATA_WIDTH  = 0,

    //  Selector signal is one-hot encoded
    parameter  bit          ONE_HOT_SEL = 0,

    //  Compute the width of the selection signal
    localparam int unsigned NINPUT_LOG2 = $clog2(NINPUT),
    localparam int unsigned SEL_WIDTH   = ONE_HOT_SEL ? NINPUT : NINPUT_LOG2,

    localparam type data_t = logic [DATA_WIDTH-1:0],
    localparam type sel_t  = logic [SEL_WIDTH-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    input  data_t [NINPUT-1:0] data_i,
    input  sel_t               sel_i,
    output data_t              data_o
);
    //  }}}

    typedef int unsigned uint32;

    if (NINPUT == 1) begin : gen_single_input
        assign data_o = data_i[0];

    end else begin : gen_multi_input
        //  Selector is one-hot encoded
        if (ONE_HOT_SEL == 1) begin : gen_onehot_sel
            always_comb
            begin : data_out_mux_comb
                data_o = '0;
                for (int unsigned i = 0; i < NINPUT; i++) begin
                    data_o |= sel_i[i] ? data_i[i] : '0;
                end
            end

        //  Selector is binary encoded
        end else begin : gen_binary_sel
            always_comb
            begin : data_out_mux_comb
                data_o = '0;
                for (int unsigned i = 0; i < NINPUT; i++) begin
                    data_o |= (i == uint32'(sel_i)) ? data_i[i] : '0;
                end
            end
        end
    end
endmodule

```

### `rtl/src/common/hpdcache_sram.sv`

```systemverilog
module hpdcache_sram
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1,
    parameter bit          ECC_EN = 1'b0
)
(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            cs,
    input  logic                            we,
    input  logic [ADDR_SIZE-1:0]            addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] wdata,
    output logic [NDATA-1:0][DATA_SIZE-1:0] rdata,

    input  logic                            err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] err_inj_msk_i,
    output logic [NDATA-1:0]                err_cor_o,
    output logic [NDATA-1:0]                err_unc_o
);
    if (ECC_EN) begin : gen_sram_ecc
        hpdcache_sram_ecc_1rw #(
            .ADDR_SIZE(ADDR_SIZE),
            .DATA_SIZE(DATA_SIZE),
            .DEPTH(DEPTH),
            .NDATA(NDATA)
        ) i_sram(
            .clk,
            .rst_n,
            .cs,
            .we,
            .addr,
            .wdata,
            .rdata,
            .err_inj_i,
            .err_inj_msk_i,
            .err_cor_o,
            .err_unc_o
        );
    end else begin : gen_sram
        logic _unused_err_inj;

        hpdcache_sram_1rw #(
            .ADDR_SIZE(ADDR_SIZE),
            .DATA_SIZE(DATA_SIZE),
            .DEPTH(DEPTH),
            .NDATA(NDATA)
        ) i_sram(
            .clk,
            .rst_n,
            .cs,
            .we,
            .addr,
            .wdata,
            .rdata
        );

        assign _unused_err_inj = 1'b0 && (err_inj_i & |err_inj_msk_i);
        assign err_cor_o = {NDATA{1'b0}};
        assign err_unc_o = {NDATA{1'b0}};
    end
endmodule

```

### `rtl/src/common/hpdcache_sram_wbyteenable.sv`

```systemverilog
module hpdcache_sram_wbyteenable
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1,
    parameter bit          ECC_EN = 1'b0
)
(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              cs,
    input  logic                              we,
    input  logic [ADDR_SIZE-1:0]              addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   wdata,
    input  logic [NDATA-1:0][DATA_SIZE/8-1:0] wbyteenable,
    output logic [NDATA-1:0][DATA_SIZE-1:0]   rdata,

    input  logic                              err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   err_inj_msk_i,
    output logic [NDATA-1:0]                  err_cor_o,
    output logic [NDATA-1:0]                  err_unc_o
);

    if (ECC_EN) begin : gen_sram_ecc
        hpdcache_sram_wbyteenable_ecc_1rw #(
            .ADDR_SIZE(ADDR_SIZE),
            .DATA_SIZE(DATA_SIZE),
            .DEPTH(DEPTH),
            .NDATA(NDATA)
        ) ram_i(
            .clk,
            .rst_n,
            .cs,
            .we,
            .addr,
            .wdata,
            .wbyteenable,
            .rdata,

            .err_inj_i,
            .err_inj_msk_i,
            .err_cor_o,
            .err_unc_o
        );
    end else begin : gen_sram
        logic _unused_err_inj;

        hpdcache_sram_wbyteenable_1rw #(
            .ADDR_SIZE(ADDR_SIZE),
            .DATA_SIZE(DATA_SIZE),
            .DEPTH(DEPTH),
            .NDATA(NDATA)
        ) ram_i(
            .clk,
            .rst_n,
            .cs,
            .we,
            .addr,
            .wdata,
            .wbyteenable,
            .rdata
        );

        assign _unused_err_inj = 1'b0 && (err_inj_i & |err_inj_msk_i);
        assign err_cor_o = {NDATA{1'b0}};
        assign err_unc_o = {NDATA{1'b0}};
    end
endmodule

```

### `rtl/src/hpdcache_victim_sel.sv`

```systemverilog
module hpdcache_victim_sel
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_way_vector_t = logic
)
//  }}}

//  Ports
//  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Victim policy update interface
    input  logic                  updt_i,
    input  hpdcache_set_t         updt_set_i,
    input  hpdcache_way_vector_t  updt_way_i,

    //      Victim selection interface
    input  logic                  sel_victim_i,
    input  hpdcache_way_vector_t  sel_dir_valid_i,
    input  hpdcache_way_vector_t  sel_dir_wback_i,
    input  hpdcache_way_vector_t  sel_dir_dirty_i,
    input  hpdcache_way_vector_t  sel_dir_fetch_i,
    input  hpdcache_set_t         sel_victim_set_i,
    output hpdcache_way_vector_t  sel_victim_way_o
);
//  }}}

    //  -----------------------------------------------------------------------
    //  Direct mapped cache (one way)
    if (HPDcacheCfg.u.ways == 1)
    begin : gen_single_way_victim_sel
        assign sel_victim_way_o = ~sel_dir_fetch_i;
    end

    //  -----------------------------------------------------------------------
    //  Set-associative cache with pseudo random victim selection
    else if (HPDcacheCfg.u.victimSel == HPDCACHE_VICTIM_RANDOM)
    begin : gen_random_victim_sel
        hpdcache_victim_random #(
            .HPDcacheCfg (HPDcacheCfg)
        ) victim_rand_i(
            .clk_i,
            .rst_ni,

            .updt_i,
            .updt_set_i,
            .updt_way_i,

            .sel_victim_i,
            .sel_dir_valid_i,
            .sel_dir_wback_i,
            .sel_dir_dirty_i,
            .sel_dir_fetch_i,
            .sel_victim_set_i,
            .sel_victim_way_o
        );
    end

    //  -----------------------------------------------------------------------
    //  Set-associative cache with pseudo least-recently-used victim selection
    else if (HPDcacheCfg.u.victimSel == HPDCACHE_VICTIM_PLRU)
    begin : gen_plru_victim_sel
        hpdcache_victim_plru #(
            .HPDcacheCfg (HPDcacheCfg)
        ) victim_plru_i(
            .clk_i,
            .rst_ni,

            .updt_i,
            .updt_set_i,
            .updt_way_i,

            .sel_victim_i,
            .sel_dir_valid_i,
            .sel_dir_wback_i,
            .sel_dir_dirty_i,
            .sel_dir_fetch_i,
            .sel_victim_set_i,
            .sel_victim_way_o
        );
    end

`ifndef HPDCACHE_ASSERT_OFF
    initial victim_sel_assert:
            assert (HPDcacheCfg.u.victimSel inside {HPDCACHE_VICTIM_RANDOM, HPDCACHE_VICTIM_PLRU})
                    else $fatal(1, "unsupported victim selection policy");
`endif

endmodule

```

## Related source code

### `rtl/src/hpdcache_ctrl_pe.sv`

```systemverilog
    //  Cachedata read enable
    //  {{{
    assign req_cachedata_read_o = st0_req_cachedata_read | st1_req_cachedata_read;
    //  }}}

// ...

        //  Wait for the cache to be initialized
        //  {{{
        if (!cachedir_init_ready_i) begin
            //  initialization of the cache RAMs
        end
        //  }}}

        //  Refilling the cache
        //  {{{
        else if (refill_busy_i) begin
            //  miss handler has the control of the cache pipeline
            evt_stall_refill_o = core_req_valid_i;
        end
        //  }}}

        //  Flush controller reading the cache
        //  {{{
        else if (flush_busy_i) begin
            //  flush controller has the control of the cache pipeline
        end
        //  }}}

        //  Normal pipeline operation
        //  {{{
        else begin

// ...

                    //  Store cacheable request
                    //  {{{
                    if (WRITE_AMO_SUPPORTED && st1_req_is_store_i && !st1_err_o) begin
                        //  Add a NOP in the pipeline when: Replaying a request, the cache cannot
                        //  accept a request from the core the next cycle. It can however accept
                        //  a new request from the replay table
                        if (!HPDcacheCfg.u.lowLatency) begin
                            st1_nop = st1_req_rtab_i & ~rtab_req_valid_i;
                        end

                        // Additional NOP case in lowLatency mode: Structural hazard on the cache
                        // data if the st0 request is a load operation with word access overlapping
                        // with the write
                        else begin
                            st1_nop = (st1_req_rtab_i & ~rtab_req_valid_i) |
                                      (rd_wr_conflict_i & st0_req_is_load_i);

// ...

            nop = st1_nop | st2_nop;

// ...

            core_req_ready_o = core_req_valid_i
                               & ~scrub_req_valid_i
                               & ~rtab_req_valid_i
                               & ~refill_req_valid_i
                               & ~rtab_full_i
                               & ~cmo_busy_i
                               & ~uc_busy_i
                               & ~err_busy_i
                               & ~rtab_fence_i
                               & ~nop;

// ...

            //      New cacheable stage 0 request granted
            //      {{{
            //          IMPORTANT: here the RAM is enabled independently if the
            //          request needs to be put on-hold.
            //          This increases the power consumption in that cases, but
            //          removes the timing paths RAM-to-RAM between the cache
            //          directory and the data array.
            if ((core_req_ready_o | rtab_req_ready_o | scrub_req_ready_o)
                && !st0_req_is_error_i)
            begin
                // cacheable-only data read path
                if(!st0_req_is_uncacheable_i) begin
                    if (HPDcacheCfg.u.lowLatency) begin
                        if (HPDcacheCfg.u.eccEn) begin
                            st0_req_cachedata_read = st0_req_is_load_i
                                                | st0_req_is_pstore
                                                | st0_req_is_pamo;

                            if (HPDcacheCfg.u.eccScrubberEn) begin
                                st0_req_cachedata_read |= st0_req_is_scrub_i;
                            end
                        end else begin
                            st0_req_cachedata_read = st0_req_is_load_i;
                        end
                    end
                end

```

## Documentation

### `docs/source/architecture.rst`

```text
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

Replacement Policy
''''''''''''''''''

The HPDcache supports the following two replacement policies: Pseudo Random or
Pseudo Least Recently Used (PLRU) replacement policy. The user selects the
actual policy at synthesis-time through the
:math:`\scriptsize\mathsf{CONF\_HPDCACHE\_VICTIM\_SEL}`
configuration parameter (:numref:`Table %s <tab_synthesis_parameters>`).

The cache uses the selected policy to select the victim way where a new
cacheline is written. In case of a read miss, CMO prefetch miss or a write miss
with the write-back policy the cache controller applies the replacement policy
to select the way of the corresponding set where the miss handler will write
the new cacheline.

The cache selects the victim way at the moment of a cache miss. At that moment,
it also asks for the missing cacheline to the memory. While waiting for the
refill response, the victim cacheline is still accessible but in **fetch** mode
(fetch bit set). This means that it has been pre-selected for replacement, and
cannot be a candidate for victim selection for a future miss (until the refill
response does not arrive).

...

The HPDcache cache uses SRAM macros for the directory and data parts of the
cache. These RAM macros are synchronous, read/write, single-port RAMs.

The organization of the RAMs, for the directory and the data, targets the
following:

#. **High memory bandwidth to/from the requesters**

   The organization allows to read 1, 2, 4, 8, 16, 32 or 64 bytes per cycle. The
   maximum number of bytes per cycle is a configuration parameter of the cache.
   Read latency is one cycle.

...

The HPDcache provides a set of parameters to tune the organization of the SRAM
macros. These parameters allow to adapt the HPDcache to the Performance, Power
and Area (PPA) requirements of the system.

The cache directory and data are both implemented using SRAM macros.

Cache Directory Parameters
~~~~~~~~~~~~~~~~~~~~~~~~~~

The cache directory contains the metadata that allows to identify the cachelines
which are present in the cache.

Each entry contains the following information:

.. list-table::
   :widths: 5 15 80
   :header-rows: 1

   * - Field
     - Description
     - Width (in bits)
   * - V
     - Valid
     - :math:`\mathsf{1}`
   * - W
     - Write-back (wback)
     - :math:`\mathsf{1}`
   * - D
     - Dirty
     - :math:`\mathsf{1}`
   * - F
     - Fetch
     - :math:`\mathsf{1}`
   * - T
     - Cache Tag
     - :math:`\mathsf{HPDCACHE\_NLINE\_WIDTH - HPDCACHE\_SET\_WIDTH}`

The depth of the macros is:

   :math:`\mathsf{CONF\_HPDCACHE\_SETS}`.

The width (in bits) of the macros is:

   :math:`\mathsf{4 + T}` bits.

Finally, the total number of SRAM macros for the cache directory is:

   :math:`\text{SRAM macros} = \mathsf{CONF\_HPDCACHE\_WAYS}`

...

Cache Data Parameters
~~~~~~~~~~~~~~~~~~~~~

The depth of the macros is:

   :math:`\mathsf{\lceil\frac{CONF\_HPDCACHE\_CL\_WORDS}{CONF\_HPDCACHE\_ACCESS\_WORDS}\rceil{}\times{}CONF\_HPDCACHE\_DATA\_SETS\_PER\_RAM}`

Multiple ways, for the same set, can be put side-by-side in the same SRAM word:

   :math:`\mathsf{CONF\_HPDCACHE\_DATA\_WAYS\_PER\_RAM\_WORD}`

The width (in bits) of the macros is:

.. math::

   \mathsf{CONF\_HPDCACHE\_DATA\_WAYS\_PER\_RAM\_WORD}\\
   \mathsf{\times{}CONF\_HPDCACHE\_WORD\_WIDTH}

Finally, the total number of SRAM macros is:

.. math::

   \mathsf{W}         &= \mathsf{CONF\_HPDCACHE\_DATA\_WAYS}\\
   \mathsf{WR}        &= \mathsf{CONF\_HPDCACHE\_DATA\_WAYS\_PER\_RAM\_WORD}\\
   \mathsf{S}         &= \mathsf{CONF\_HPDCACHE\_DATA\_SETS}\\
   \mathsf{SR}        &= \mathsf{CONF\_HPDCACHE\_DATA\_SETS\_PER\_RAM}\\
   \mathsf{A}         &= \mathsf{CONF\_HPDCACHE\_ACCESS\_WORDS}\\
   \text{SRAM macros} &= \mathsf{A{}\times{}\lceil\frac{W}{WR}\rceil{}\times{}\lceil\frac{S}{SR}\rceil}

The :math:`\mathsf{CONF\_HPDCACHE\_ACCESS\_WORDS}` defines the maximum number of
words that can be read or written in the same clock cycle. This parameter
affects both the refill latency and the maximum throughput (bytes/cycle) between
the HPDcache and the requesters.

```
