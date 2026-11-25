# Implement `hpdcache`

Implement the complete `hpdcache` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv32a60x_config_pkg.sv`

```systemverilog
  localparam CVA6ConfigXlen = 32;
// ...
  localparam CVA6ConfigAxiIdWidth = 4;  // axi_pkg.sv
  localparam CVA6ConfigAxiAddrWidth = 64;  // axi_pkg.sv
  localparam CVA6ConfigAxiDataWidth = 64;  // axi_pkg.sv
  localparam CVA6ConfigDataUserWidth = 32;  // axi_pkg.sv
// ...
      AxiAddrWidth: unsigned'(CVA6ConfigAxiAddrWidth),
      AxiDataWidth: unsigned'(CVA6ConfigAxiDataWidth),
      AxiIdWidth: unsigned'(CVA6ConfigAxiIdWidth),
      AxiUserWidth: unsigned'(CVA6ConfigDataUserWidth),
      MemTidWidth: unsigned'(CVA6ConfigAxiIdWidth),
      NrLoadBufEntries: unsigned'(2),
// ...
      NOCType: config_pkg::NOC_TYPE_AXI4_ATOP,
// ...
      IcacheByteSize: unsigned'(2048),
      IcacheSetAssoc: unsigned'(2),
      IcacheLineWidth: unsigned'(128),
      DCacheType: config_pkg::HPDCACHE_WT,
      DcacheByteSize: unsigned'(2028),
      DcacheSetAssoc: unsigned'(2),
      DcacheLineWidth: unsigned'(128),
      DcacheFlushOnFence: bit'(0),
      DcacheFlushOnFenceI: bit'(0),
      DcacheInvalidateOnFlush: bit'(0),
      DcacheEccEnable: bit'(0),
      DcacheEccScrubberEnable: bit'(0),
      DataUserEn: unsigned'(1),
      WtDcacheWbufDepth: int'(8),
      FetchUserWidth: unsigned'(32),
      FetchUserEn: unsigned'(1),
```

### `core/include/build_config_pkg.sv`

```systemverilog
    int unsigned ICACHE_INDEX_WIDTH = $clog2(CVA6Cfg.IcacheByteSize / CVA6Cfg.IcacheSetAssoc);
    int unsigned DCACHE_INDEX_WIDTH = $clog2(CVA6Cfg.DcacheByteSize / CVA6Cfg.DcacheSetAssoc);
    int unsigned DCACHE_OFFSET_WIDTH = $clog2(CVA6Cfg.DcacheLineWidth / 8);
// ...
    cfg.XLEN = CVA6Cfg.XLEN;
    cfg.VLEN = CVA6Cfg.VLEN;
    cfg.PLEN = IS_XLEN32 ? 34 : 56;
    cfg.GPLEN = IS_XLEN32 ? 34 : 41;
    cfg.IS_XLEN32 = IS_XLEN32;
    cfg.IS_XLEN64 = IS_XLEN64;
    cfg.XLEN_ALIGN_BYTES = $clog2(CVA6Cfg.XLEN / 8);
// ...
    cfg.AxiAddrWidth = CVA6Cfg.AxiAddrWidth;
    cfg.AxiDataWidth = CVA6Cfg.AxiDataWidth;
    cfg.AxiIdWidth = CVA6Cfg.AxiIdWidth;
    cfg.AxiUserWidth = CVA6Cfg.AxiUserWidth;
    cfg.MEM_TID_WIDTH = CVA6Cfg.MemTidWidth;
    cfg.NrLoadBufEntries = CVA6Cfg.NrLoadBufEntries;
// ...
    cfg.NOCType = CVA6Cfg.NOCType;
// ...
    cfg.ICACHE_SET_ASSOC = CVA6Cfg.IcacheSetAssoc;
    cfg.ICACHE_SET_ASSOC_WIDTH = CVA6Cfg.IcacheSetAssoc > 1 ? $clog2(CVA6Cfg.IcacheSetAssoc) :
        CVA6Cfg.IcacheSetAssoc;
    cfg.ICACHE_INDEX_WIDTH = ICACHE_INDEX_WIDTH;
    cfg.ICACHE_TAG_WIDTH = cfg.PLEN - ICACHE_INDEX_WIDTH;
    cfg.ICACHE_LINE_WIDTH = CVA6Cfg.IcacheLineWidth;
    cfg.ICACHE_USER_LINE_WIDTH = (CVA6Cfg.AxiUserWidth == 1) ? 4 : CVA6Cfg.IcacheLineWidth;
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

    cfg.DcacheEccEnable = CVA6Cfg.DcacheEccEnable;
    cfg.DcacheEccScrubberEnable = CVA6Cfg.DcacheEccScrubberEnable;

    cfg.DATA_USER_EN = CVA6Cfg.DataUserEn;
    cfg.WtDcacheWbufDepth = CVA6Cfg.WtDcacheWbufDepth;
    cfg.FETCH_USER_WIDTH = CVA6Cfg.FetchUserWidth;
    cfg.FETCH_USER_EN = CVA6Cfg.FetchUserEn;
    cfg.AXI_USER_EN = CVA6Cfg.DataUserEn | CVA6Cfg.FetchUserEn;
```

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
    //  Definition of interface with memory
    //  {{{
    typedef logic [7:0]                           hpdcache_mem_len_t;
    typedef logic [2:0]                           hpdcache_mem_size_t;

    typedef enum logic [1:0] {
        HPDCACHE_MEM_RESP_OK  = 2'b00,
        HPDCACHE_MEM_RESP_NOK = 2'b01
    } hpdcache_mem_error_e;

    typedef enum logic [1:0] {
        HPDCACHE_MEM_READ     = 2'b00,
        HPDCACHE_MEM_WRITE    = 2'b01,
        HPDCACHE_MEM_ATOMIC   = 2'b10
        //  Reserved        = 2'b11 - TODO: CMO ?
    } hpdcache_mem_command_e;

    typedef enum logic [3:0] {
        HPDCACHE_MEM_ATOMIC_ADD  = 4'b0000,
        HPDCACHE_MEM_ATOMIC_CLR  = 4'b0001,
        HPDCACHE_MEM_ATOMIC_SET  = 4'b0010,
        HPDCACHE_MEM_ATOMIC_EOR  = 4'b0011,
        HPDCACHE_MEM_ATOMIC_SMAX = 4'b0100,
        HPDCACHE_MEM_ATOMIC_SMIN = 4'b0101,
        HPDCACHE_MEM_ATOMIC_UMAX = 4'b0110,
        HPDCACHE_MEM_ATOMIC_UMIN = 4'b0111,
        HPDCACHE_MEM_ATOMIC_SWAP = 4'b1000,
        //  Reserved           = 4'b1001,
        //  Reserved           = 4'b1010,
        //  Reserved           = 4'b1011,
        HPDCACHE_MEM_ATOMIC_LDEX = 4'b1100,
        HPDCACHE_MEM_ATOMIC_STEX = 4'b1101
        //  Reserved           = 4'b1110,
        //  Reserved           = 4'b1111
    } hpdcache_mem_atomic_e;
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

### `rtl/include/hpdcache_typedef.svh`

```systemverilog
`ifndef __HPDCACHE_TYPEDEF_SVH__
`define __HPDCACHE_TYPEDEF_SVH__

`define HPDCACHE_DECL_MEM_REQ_T(__addr_t, __id_t) \
    struct packed { \
        __addr_t                              mem_req_addr; \
        hpdcache_pkg::hpdcache_mem_len_t      mem_req_len; \
        hpdcache_pkg::hpdcache_mem_size_t     mem_req_size; \
        __id_t                                mem_req_id; \
        hpdcache_pkg::hpdcache_mem_command_e  mem_req_command; \
        hpdcache_pkg::hpdcache_mem_atomic_e   mem_req_atomic; \
        logic                                 mem_req_cacheable; \
    }

`define HPDCACHE_DECL_MEM_RESP_R_T(__id_t, __data_t) \
    struct packed { \
        hpdcache_pkg::hpdcache_mem_error_e    mem_resp_r_error; \
        __id_t                                mem_resp_r_id; \
        __data_t                              mem_resp_r_data; \
        logic                                 mem_resp_r_last; \
    }

`define HPDCACHE_DECL_MEM_REQ_W_T(__data_t, __be_t) \
    struct packed { \
        __data_t                              mem_req_w_data; \
        __be_t                                mem_req_w_be; \
        logic                                 mem_req_w_last; \
    }

`define HPDCACHE_DECL_MEM_RESP_W_T(__id_t) \
    struct packed { \
        logic                                 mem_resp_w_is_atomic; \
        hpdcache_pkg::hpdcache_mem_error_e    mem_resp_w_error; \
        __id_t                                mem_resp_w_id; \
    }

`define HPDCACHE_TYPEDEF_MEM_ATTR_T(__addr_t, __id_t, __data_t, __be_t, __params) \
    typedef logic [  __params.u.memAddrWidth-1:0] __addr_t; \
    typedef logic [    __params.u.memIdWidth-1:0] __id_t; \
    typedef logic [  __params.u.memDataWidth-1:0] __data_t; \
    typedef logic [__params.u.memDataWidth/8-1:0] __be_t

`define HPDCACHE_TYPEDEF_MEM_REQ_T(__name__, __addr_t, __id_t) \
    typedef `HPDCACHE_DECL_MEM_REQ_T(__addr_t, __id_t) __name__

`define HPDCACHE_TYPEDEF_MEM_RESP_R_T(__name__, __id_t, __data_t) \
    typedef `HPDCACHE_DECL_MEM_RESP_R_T(__id_t, __data_t) __name__

`define HPDCACHE_TYPEDEF_MEM_REQ_W_T(__name__, __data_t, __be_t) \
    typedef `HPDCACHE_DECL_MEM_REQ_W_T(__data_t, __be_t) __name__

`define HPDCACHE_TYPEDEF_MEM_RESP_W_T(__name__, __id_t) \
    typedef `HPDCACHE_DECL_MEM_RESP_W_T(__id_t) __name__

`define HPDCACHE_DECL_REQ_T(__offset_t, __data_t, __be_t, __sid_t, __tid_t, __tag_t) \
    struct packed { \
        __offset_t                        addr_offset; \
        __data_t                          wdata; \
        hpdcache_pkg::hpdcache_req_op_t   op; \
        __be_t                            be; \
        hpdcache_pkg::hpdcache_req_size_t size; \
        __sid_t                           sid; \
        __tid_t                           tid; \
        logic                             need_rsp; \
        logic                             phys_indexed; \
        __tag_t                           addr_tag; \
        hpdcache_pkg::hpdcache_pma_t      pma; \
    }

`define HPDCACHE_TYPEDEF_REQ_ATTR_T(__offset_t, __word_t, __word_be_t, __data_t, __be_t, __sid_t, __tid_t, __tag_t, __params) \
    typedef logic       [         __params.tagWidth-1:0] __tag_t; \
    typedef logic       [      __params.u.wordWidth-1:0] __word_t; \
    typedef logic       [    __params.u.wordWidth/8-1:0] __word_be_t; \
    typedef logic       [   __params.reqOffsetWidth-1:0] __offset_t; \
    typedef __word_t    [       __params.u.reqWords-1:0] __data_t; \
    typedef __word_be_t [       __params.u.reqWords-1:0] __be_t; \
    typedef logic       [  __params.u.reqSrcIdWidth-1:0] __sid_t; \
    typedef logic       [__params.u.reqTransIdWidth-1:0] __tid_t

`define HPDCACHE_TYPEDEF_REQ_T(__name__, __offset_t, __data_t, __be_t, __sid_t, __tid_t, __tag_t) \
    typedef `HPDCACHE_DECL_REQ_T(__offset_t, __data_t, __be_t, __sid_t, __tid_t, __tag_t) __name__

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

`endif //  __HPDCACHE_TYPEDEF_SVH__
```

## Module declaration

### `rtl/src/hpdcache.sv`

```systemverilog
module hpdcache
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type wbuf_timecnt_t = logic,

    //  Request Interface Definitions
    //  {{{
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_data_word_t = logic,
    parameter type hpdcache_data_be_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    //  }}}

    //  Memory Interface Definitions
    //  {{{
    parameter type hpdcache_mem_addr_t = logic,
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_data_t = logic,
    parameter type hpdcache_mem_be_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,
    //  }}}

    localparam type hpdcache_nline_t = logic [HPDcacheCfg.nlineWidth-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    //      Clock and reset signals
    input  logic                          clk_i,
    input  logic                          rst_ni,

    //      Force the write buffer to send all pending writes
    input  logic                          wbuf_flush_i,

    //      Core request interface
    //         1st cycle
    input  logic                          core_req_valid_i [HPDcacheCfg.u.nRequesters],
    output logic                          core_req_ready_o [HPDcacheCfg.u.nRequesters],
    input  hpdcache_req_t                 core_req_i       [HPDcacheCfg.u.nRequesters],
    //         2nd cycle
    input  logic                          core_req_abort_i [HPDcacheCfg.u.nRequesters],
    input  hpdcache_tag_t                 core_req_tag_i   [HPDcacheCfg.u.nRequesters],
    input  hpdcache_pma_t                 core_req_pma_i   [HPDcacheCfg.u.nRequesters],

    //      Core response interface
    output logic                          core_rsp_valid_o [HPDcacheCfg.u.nRequesters],
    output hpdcache_rsp_t                 core_rsp_o       [HPDcacheCfg.u.nRequesters],

    //      Read / Invalidation memory interface
    input  logic                          mem_req_read_ready_i,
    output logic                          mem_req_read_valid_o,
    output hpdcache_mem_req_t             mem_req_read_o,

    output logic                          mem_resp_read_ready_o,
    input  logic                          mem_resp_read_valid_i,
    input  hpdcache_mem_resp_r_t          mem_resp_read_i,

    input  logic                          mem_resp_read_inval_i,
    input  hpdcache_nline_t               mem_resp_read_inval_nline_i,

    //      Write memory interface
    input  logic                          mem_req_write_ready_i,
    output logic                          mem_req_write_valid_o,
    output hpdcache_mem_req_t             mem_req_write_o,

    input  logic                          mem_req_write_data_ready_i,
    output logic                          mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t           mem_req_write_data_o,

    output logic                          mem_resp_write_ready_o,
    input  logic                          mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t          mem_resp_write_i,

    //      Performance events
    output logic                          evt_cache_write_miss_o,
    output logic                          evt_cache_read_miss_o,
    output logic                          evt_cache_dir_unc_err_o,
    output logic                          evt_cache_dir_cor_err_o,
    output logic                          evt_cache_dat_unc_err_o,
    output logic                          evt_cache_dat_cor_err_o,
    output logic                          evt_scrub_complete_o,
    output logic                          evt_uncached_req_o,
    output logic                          evt_cmo_req_o,
    output logic                          evt_write_req_o,
    output logic                          evt_read_req_o,
    output logic                          evt_prefetch_req_o,
    output logic                          evt_req_on_hold_o,
    output logic                          evt_rtab_rollback_o,
    output logic                          evt_stall_refill_o,
    output logic                          evt_stall_o,

    //      Status interface
    output logic                          wbuf_empty_o,

    //      Configuration interface
    input  logic                          cfg_enable_i,
    input  wbuf_timecnt_t                 cfg_wbuf_threshold_i,
    input  logic                          cfg_wbuf_reset_timecnt_on_write_i,
    input  logic                          cfg_wbuf_sequential_waw_i,
    input  logic                          cfg_wbuf_inhibit_write_coalescing_i,
    input  logic                          cfg_prefetch_updt_plru_i,
    input  logic                          cfg_error_on_cacheable_amo_i,
    input  logic                          cfg_rtab_single_entry_i,
    input  logic                          cfg_default_wb_i,
    input  logic                          cfg_scrub_enable_i,
    input  logic unsigned [5:0]           cfg_scrub_period_i,
    input  logic                          cfg_scrub_restart_i
);
```

## Parent instantiation

### `core/cache_subsystem/cva6_hpdcache_subsystem.sv`

```systemverilog
  //    0: Page-Table Walk (PTW)
  //    1: Load unit
  //    2: Accelerator load
  //    3: Store/AMO
  //    .
  //    .
  //    .
  //    NumPorts: Hardware Memory Prefetcher (hwpf)
  localparam int HPDCACHE_NREQUESTERS = NumPorts + 1;

  function automatic hpdcache_pkg::hpdcache_user_cfg_t hpdcacheSetConfig();
    hpdcache_pkg::hpdcache_user_cfg_t userCfg;
    userCfg.nRequesters = HPDCACHE_NREQUESTERS;
    userCfg.paWidth = CVA6Cfg.PLEN;
    userCfg.wordWidth = CVA6Cfg.XLEN;
    userCfg.sets = CVA6Cfg.DCACHE_NUM_WORDS;
    userCfg.ways = CVA6Cfg.DCACHE_SET_ASSOC;
    userCfg.clWords = CVA6Cfg.DCACHE_LINE_WIDTH / userCfg.wordWidth;
    userCfg.reqWords = 1;
    userCfg.reqTransIdWidth = CVA6Cfg.DcacheIdWidth;
    userCfg.reqSrcIdWidth = 3;  // Up to 8 requesters
    userCfg.victimSel = hpdcache_pkg::HPDCACHE_VICTIM_RANDOM;
    userCfg.dataWaysPerRamWord = __minu(CVA6Cfg.DCACHE_SET_ASSOC, 128 / CVA6Cfg.XLEN);
    userCfg.dataSetsPerRam = CVA6Cfg.DCACHE_NUM_WORDS;
    userCfg.dataRamByteEnable = 1'b1;
    userCfg.accessWords = __maxu(CVA6Cfg.AxiDataWidth / userCfg.wordWidth, userCfg.reqWords);
    userCfg.mshrSets = CVA6Cfg.NrLoadBufEntries < 16 ? 1 : CVA6Cfg.NrLoadBufEntries / 2;
    userCfg.mshrWays = CVA6Cfg.NrLoadBufEntries < 16 ? CVA6Cfg.NrLoadBufEntries : 2;
    userCfg.mshrWaysPerRamWord = CVA6Cfg.NrLoadBufEntries < 16 ? CVA6Cfg.NrLoadBufEntries : 2;
    userCfg.mshrSetsPerRam = CVA6Cfg.NrLoadBufEntries < 16 ? 1 : CVA6Cfg.NrLoadBufEntries / 2;
    userCfg.mshrRamByteEnable = 1'b1;
    userCfg.mshrUseRegbank = (CVA6Cfg.NrLoadBufEntries < 16);
    userCfg.cbufEntries = CVA6Cfg.WtDcacheWbufDepth;
    userCfg.refillCoreRspFeedthrough = 1'b1;
    if (CVA6Cfg.NOCType == config_pkg::NOC_TYPE_L15_BIG_ENDIAN || CVA6Cfg.NOCType == config_pkg::NOC_TYPE_L15_LITTLE_ENDIAN) begin
      // OpenPiton needs a larger refill FIFO to store as many invalidations as in-flight requests (plus some extra to be safe)
      userCfg.refillFifoDepth = (userCfg.mshrSets * userCfg.mshrWays) + 10;
    end else begin
      userCfg.refillFifoDepth = 2 * (CVA6Cfg.DCACHE_LINE_WIDTH / CVA6Cfg.AxiDataWidth);
    end
    userCfg.wbufDirEntries = CVA6Cfg.WtDcacheWbufDepth;
    userCfg.wbufDataEntries = CVA6Cfg.WtDcacheWbufDepth;
    userCfg.wbufWords = 1;
    userCfg.wbufTimecntWidth = 3;
    userCfg.rtabEntries = 4;
    userCfg.flushEntries = CVA6Cfg.WtDcacheWbufDepth;  /*FIXME add additional CVA6 parameter*/
    userCfg.flushFifoDepth = CVA6Cfg.WtDcacheWbufDepth;  /*FIXME add additional CVA6 parameter*/
    userCfg.memAddrWidth = CVA6Cfg.AxiAddrWidth;
    userCfg.memIdWidth = CVA6Cfg.MEM_TID_WIDTH;
    userCfg.memDataWidth = CVA6Cfg.AxiDataWidth;
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

### `core/cache_subsystem/cva6_hpdcache_wrapper.sv`

```systemverilog
  hpdcache #(
      .HPDcacheCfg          (HPDcacheCfg),
      .wbuf_timecnt_t       (hpdcache_wbuf_timecnt_t),
      .hpdcache_tag_t       (hpdcache_tag_t),
      .hpdcache_data_word_t (hpdcache_data_word_t),
      .hpdcache_data_be_t   (hpdcache_data_be_t),
      .hpdcache_req_offset_t(hpdcache_req_offset_t),
      .hpdcache_req_data_t  (hpdcache_req_data_t),
      .hpdcache_req_be_t    (hpdcache_req_be_t),
      .hpdcache_req_sid_t   (hpdcache_req_sid_t),
      .hpdcache_req_tid_t   (hpdcache_req_tid_t),
      .hpdcache_req_t       (hpdcache_req_t),
      .hpdcache_rsp_t       (hpdcache_rsp_t),
      .hpdcache_mem_addr_t  (hpdcache_mem_addr_t),
      .hpdcache_mem_id_t    (hpdcache_mem_id_t),
      .hpdcache_mem_data_t  (hpdcache_mem_data_t),
      .hpdcache_mem_be_t    (hpdcache_mem_be_t),
      .hpdcache_mem_req_t   (hpdcache_mem_req_t),
      .hpdcache_mem_req_w_t (hpdcache_mem_req_w_t),
      .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
      .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t)
  ) i_hpdcache (
      .clk_i,
      .rst_ni,

      .wbuf_flush_i(dcache_flush_i),

      .core_req_valid_i(dcache_req_valid),
      .core_req_ready_o(dcache_req_ready),
      .core_req_i      (dcache_req),
      .core_req_abort_i(dcache_req_abort),
      .core_req_tag_i  (dcache_req_tag),
      .core_req_pma_i  (dcache_req_pma),

      .core_rsp_valid_o(dcache_rsp_valid),
      .core_rsp_o      (dcache_rsp),

      .mem_req_read_ready_i(dcache_mem_req_read_ready_i),
      .mem_req_read_valid_o(dcache_mem_req_read_valid_o),
      .mem_req_read_o      (dcache_mem_req_read_o),

      .mem_resp_read_ready_o(dcache_mem_resp_read_ready_o),
      .mem_resp_read_valid_i(dcache_mem_resp_read_valid_i),
      .mem_resp_read_i      (dcache_mem_resp_read_i),

      .mem_resp_read_inval_i      (dcache_mem_resp_read_inval_i),
      .mem_resp_read_inval_nline_i(dcache_mem_resp_read_inval_nline_i),

      .mem_req_write_ready_i(dcache_mem_req_write_ready_i),
      .mem_req_write_valid_o(dcache_mem_req_write_valid_o),
      .mem_req_write_o      (dcache_mem_req_write_o),

      .mem_req_write_data_ready_i(dcache_mem_req_write_data_ready_i),
      .mem_req_write_data_valid_o(dcache_mem_req_write_data_valid_o),
      .mem_req_write_data_o      (dcache_mem_req_write_data_o),

      .mem_resp_write_ready_o(dcache_mem_resp_write_ready_o),
      .mem_resp_write_valid_i(dcache_mem_resp_write_valid_i),
      .mem_resp_write_i      (dcache_mem_resp_write_i),

      .evt_cache_write_miss_o (dcache_write_miss),
      .evt_cache_read_miss_o  (dcache_read_miss),
      .evt_cache_dir_unc_err_o(dcache_dir_unc_err_o),
      .evt_cache_dir_cor_err_o(dcache_dir_cor_err_o),
      .evt_cache_dat_unc_err_o(dcache_dat_unc_err_o),
      .evt_cache_dat_cor_err_o(dcache_dat_cor_err_o),
      .evt_scrub_complete_o   (dcache_scrub_cycle_o),
      .evt_uncached_req_o     (  /* unused */),
      .evt_cmo_req_o          (  /* unused */),
      .evt_write_req_o        (  /* unused */),
      .evt_read_req_o         (  /* unused */),
      .evt_prefetch_req_o     (  /* unused */),
      .evt_req_on_hold_o      (  /* unused */),
      .evt_rtab_rollback_o    (  /* unused */),
      .evt_stall_refill_o     (  /* unused */),
      .evt_stall_o            (  /* unused */),

      .wbuf_empty_o(wbuffer_empty_o),

      .cfg_enable_i                       (dcache_enable_i),
      .cfg_wbuf_threshold_i               (3'd2),
      .cfg_wbuf_reset_timecnt_on_write_i  (1'b1),
      .cfg_wbuf_sequential_waw_i          (1'b0),
      .cfg_wbuf_inhibit_write_coalescing_i(1'b0),
      .cfg_prefetch_updt_plru_i           (1'b1),
      .cfg_error_on_cacheable_amo_i       (1'b0),
      .cfg_rtab_single_entry_i            (1'b0),
      .cfg_default_wb_i                   (1'b0),
      .cfg_scrub_enable_i                 (dcache_scrub_enable_i),
      .cfg_scrub_period_i                 (dcache_scrub_period_i),
      .cfg_scrub_restart_i                (1'b0)
  );
```

## Dependency declarations

### `rtl/src/hpdcache_cmo.sv`

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

### `rtl/src/hpdcache_core_arbiter.sv`

```systemverilog
module hpdcache_core_arbiter
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic
)
    //  }}}

    //  Ports
    //  {{{
(
    //      Clock and reset signals
    input  logic                          clk_i,
    input  logic                          rst_ni,

    //      Core request interface
    //         1st cycle
    input  logic                          core_req_valid_i [HPDcacheCfg.u.nRequesters],
    output logic                          core_req_ready_o [HPDcacheCfg.u.nRequesters],
    input  hpdcache_req_t                 core_req_i       [HPDcacheCfg.u.nRequesters],
    //         2nd cycle
    input  logic                          core_req_abort_i [HPDcacheCfg.u.nRequesters],
    input  hpdcache_tag_t                 core_req_tag_i   [HPDcacheCfg.u.nRequesters],
    input  hpdcache_pma_t                 core_req_pma_i   [HPDcacheCfg.u.nRequesters],

    //      Core response interface
    input  logic                          core_rsp_valid_i,
    input  hpdcache_rsp_t                 core_rsp_i,
    output logic                          core_rsp_valid_o [HPDcacheCfg.u.nRequesters],
    output hpdcache_rsp_t                 core_rsp_o       [HPDcacheCfg.u.nRequesters],

    //      Granted request
    output logic                          arb_req_valid_o,
    input  logic                          arb_req_ready_i,
    output hpdcache_req_t                 arb_req_o,
    output logic                          arb_abort_o,
    output hpdcache_tag_t                 arb_tag_o,
    output hpdcache_pma_t                 arb_pma_o
);
```

### `rtl/src/hpdcache_ctrl.sv`

```systemverilog
module hpdcache_ctrl
    // Package imports
    // {{{
import hpdcache_pkg::*;
    // }}}

    // Parameters
    // {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_word_t = logic,
    parameter type hpdcache_data_word_t = logic,
    parameter type hpdcache_data_be_t = logic,
    parameter type hpdcache_dir_entry_t = logic,
    parameter type hpdcache_way_vector_t = logic,
    parameter type hpdcache_way_t = logic,

    parameter type wbuf_addr_t = logic,
    parameter type wbuf_data_t = logic,
    parameter type wbuf_be_t = logic,

    parameter type hpdcache_access_data_t = logic,
    parameter type hpdcache_access_be_t = logic,

    parameter type hpdcache_req_addr_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,

    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic
)
    // }}}

    // Ports
    // {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Core request interface
    input  logic                  core_req_valid_i,
    output logic                  core_req_ready_o,
    input  hpdcache_req_t         core_req_i,
    input  logic                  core_req_abort_i,
    input  hpdcache_tag_t         core_req_tag_i,
    input  hpdcache_pma_t         core_req_pma_i,

    //      Core response interface
    output logic                  core_rsp_valid_o,
    output hpdcache_rsp_t         core_rsp_o,

    //      Force the write buffer to send all pending writes
    input  logic                  wbuf_flush_i,

    //      Miss handler interface
    output logic                  st0_mshr_check_o,
    output hpdcache_req_offset_t  st0_mshr_check_offset_o,
    output hpdcache_nline_t       st1_mshr_check_nline_o,
    input  logic                  st1_mshr_hit_i,
    input  logic                  st1_mshr_alloc_ready_i,
    input  logic                  st1_mshr_alloc_full_i,
    input  logic                  st1_mshr_alloc_cbuf_full_i,
    output logic                  st2_mshr_alloc_o,
    output logic                  st2_mshr_alloc_cs_o,
    output hpdcache_nline_t       st2_mshr_alloc_nline_o,
    output hpdcache_req_tid_t     st2_mshr_alloc_tid_o,
    output hpdcache_req_sid_t     st2_mshr_alloc_sid_o,
    output hpdcache_word_t        st2_mshr_alloc_word_o,
    output hpdcache_req_data_t    st2_mshr_alloc_wdata_o,
    output hpdcache_req_be_t      st2_mshr_alloc_be_o,
    output hpdcache_way_vector_t  st2_mshr_alloc_victim_way_o,
    output logic                  st2_mshr_alloc_need_rsp_o,
    output logic                  st2_mshr_alloc_is_prefetch_o,
    output logic                  st2_mshr_alloc_wback_o,
    output logic                  st2_mshr_alloc_dirty_o,

    //      Refill interface
    input  logic                  refill_req_valid_i,
    output logic                  refill_req_ready_o,
    input  logic                  refill_is_error_i,
    input  logic                  refill_busy_i,
    input  logic                  refill_updt_sel_victim_i,
    input  hpdcache_set_t         refill_set_i,
    input  hpdcache_way_vector_t  refill_way_i,
    input  hpdcache_dir_entry_t   refill_dir_entry_i,
    input  logic                  refill_write_dir_i,
    input  logic                  refill_write_data_i,
    input  hpdcache_word_t        refill_word_i,
    input  hpdcache_access_data_t refill_data_i,
    input  logic                  refill_core_rsp_valid_i,
    input  hpdcache_rsp_t         refill_core_rsp_i,
    input  hpdcache_nline_t       refill_nline_i,
    input  logic                  refill_updt_rtab_i,

    //      Flush interface
    input  logic                  flush_busy_i,
    output hpdcache_nline_t       flush_check_nline_o,
    input  logic                  flush_check_hit_i,
    output logic                  flush_alloc_o,
    input  logic                  flush_alloc_ready_i,
    output hpdcache_nline_t       flush_alloc_nline_o,
    output hpdcache_way_vector_t  flush_alloc_way_o,
    input  logic                  flush_data_read_i,
    input  hpdcache_set_t         flush_data_read_set_i,
    input  hpdcache_word_t        flush_data_read_word_i,
    input  hpdcache_way_vector_t  flush_data_read_way_i,
    output hpdcache_access_data_t flush_data_read_data_o,
    input  logic                  flush_ack_i,
    input  hpdcache_nline_t       flush_ack_nline_i,

    //      Invalidate interface
    input  logic                  inval_check_dir_i,
    input  logic                  inval_write_dir_i,
    input  hpdcache_nline_t       inval_nline_i,
    output logic                  inval_hit_o,

    //      Write buffer interface
    input  logic                  wbuf_empty_i,
    output logic                  wbuf_flush_all_o,
    output logic                  wbuf_write_o,
    input  logic                  wbuf_write_ready_i,
    output wbuf_addr_t            wbuf_write_addr_o,
    output wbuf_data_t            wbuf_write_data_o,
    output wbuf_be_t              wbuf_write_be_o,
    output logic                  wbuf_write_uncacheable_o,
    input  logic                  wbuf_read_hit_i,
    output logic                  wbuf_read_flush_hit_o,
    output hpdcache_req_addr_t    wbuf_rtab_addr_o,
    output logic                  wbuf_rtab_is_read_o,
    input  logic                  wbuf_rtab_hit_open_i,
    input  logic                  wbuf_rtab_hit_pend_i,
    input  logic                  wbuf_rtab_hit_sent_i,
    input  logic                  wbuf_rtab_not_ready_i,

    //      Uncacheable request handler
    input  logic                  uc_busy_i,
    output logic                  uc_lrsc_snoop_o,
    output hpdcache_req_addr_t    uc_lrsc_snoop_addr_o,
    output hpdcache_req_size_t    uc_lrsc_snoop_size_o,
    output logic                  uc_req_valid_o,
    output hpdcache_uc_op_t       uc_req_op_o,
    output hpdcache_req_addr_t    uc_req_addr_o,
    output hpdcache_req_size_t    uc_req_size_o,
    output hpdcache_req_data_t    uc_req_data_o,
    output hpdcache_req_be_t      uc_req_be_o,
    output logic                  uc_req_uc_o,
    output hpdcache_req_sid_t     uc_req_sid_o,
    output hpdcache_req_tid_t     uc_req_tid_o,
    output logic                  uc_req_need_rsp_o,
    output hpdcache_way_vector_t  uc_req_dir_hit_way_o,
    output hpdcache_req_data_t    uc_req_old_data_o,
    input  logic                  uc_data_amo_write_i,
    input  logic                  uc_data_amo_write_enable_i,
    input  hpdcache_set_t         uc_data_amo_write_set_i,
    input  hpdcache_req_size_t    uc_data_amo_write_size_i,
    input  hpdcache_word_t        uc_data_amo_write_word_i,
    input  hpdcache_way_vector_t  uc_data_amo_write_way_i,
    input  hpdcache_req_data_t    uc_data_amo_write_data_i,
    input  hpdcache_req_be_t      uc_data_amo_write_be_i,
    output logic                  uc_core_rsp_ready_o,
    input  logic                  uc_core_rsp_valid_i,
    input  hpdcache_rsp_t         uc_core_rsp_i,

    //      Cache Management Operation (CMO)
    input  logic                  cmo_busy_i,
    output logic                  cmo_req_valid_o,
    output hpdcache_cmoh_op_t     cmo_req_op_o,
    output hpdcache_req_addr_t    cmo_req_addr_o,
    output hpdcache_req_sid_t     cmo_req_sid_o,
    output hpdcache_req_tid_t     cmo_req_tid_o,
    output logic                  cmo_req_need_rsp_o,
    output logic                  cmo_dirty_set_en_o,
    output hpdcache_set_t         cmo_dirty_min_set_o,
    output hpdcache_set_t         cmo_dirty_max_set_o,
    output logic                  cmo_valid_set_en_o,
    output hpdcache_set_t         cmo_valid_min_set_o,
    output hpdcache_set_t         cmo_valid_max_set_o,
    input  logic                  cmo_flush_all_i,
    input  logic                  cmo_inval_all_i,
    input  logic                  cmo_dir_check_entry_i,
    input  hpdcache_set_t         cmo_dir_check_entry_set_i,
    input  hpdcache_way_vector_t  cmo_dir_check_entry_way_i,
    output logic                  cmo_dir_check_entry_valid_o,
    output logic                  cmo_dir_check_entry_wback_o,
    output logic                  cmo_dir_check_entry_dirty_o,
    output hpdcache_tag_t         cmo_dir_check_entry_tag_o,
    input  logic                  cmo_dir_updt_i,
    input  hpdcache_set_t         cmo_dir_updt_set_i,
    input  hpdcache_way_vector_t  cmo_dir_updt_way_i,
    input  logic                  cmo_dir_updt_valid_i,
    input  logic                  cmo_dir_updt_wback_i,
    input  logic                  cmo_dir_updt_dirty_i,
    input  logic                  cmo_dir_updt_fetch_i,
    input  hpdcache_tag_t         cmo_dir_updt_tag_i,
    output logic                  cmo_core_rsp_ready_o,
    input  logic                  cmo_core_rsp_valid_i,
    input  hpdcache_rsp_t         cmo_core_rsp_i,

    input  logic                  mshr_empty_i,
    input  logic                  flush_empty_i,

    output logic                  rtab_empty_o,
    output logic                  ctrl_empty_o,

    //   Configuration signals
    input  logic                  cfg_enable_i,
    input  logic                  cfg_prefetch_updt_plru_i,
    input  logic                  cfg_rtab_single_entry_i,
    input  logic                  cfg_default_wb_i,
    input  logic                  cfg_scrub_enable_i,
    input  logic unsigned [5:0]   cfg_scrub_period_i,
    input  logic                  cfg_scrub_restart_i,

    //   Performance events
    output logic                  evt_cache_write_miss_o,
    output logic                  evt_cache_read_miss_o,
    output logic                  evt_cache_dir_unc_err_o,
    output logic                  evt_cache_dir_cor_err_o,
    output logic                  evt_cache_dat_unc_err_o,
    output logic                  evt_cache_dat_cor_err_o,
    output logic                  evt_scrub_complete_o,
    output logic                  evt_uncached_req_o,
    output logic                  evt_cmo_req_o,
    output logic                  evt_write_req_o,
    output logic                  evt_read_req_o,
    output logic                  evt_prefetch_req_o,
    output logic                  evt_req_on_hold_o,
    output logic                  evt_rtab_rollback_o,
    output logic                  evt_stall_refill_o,
    output logic                  evt_stall_o
);
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

    //      CACHE DATA interface
    //      {{{
    output logic                  flush_data_read_o,
    output hpdcache_set_t         flush_data_read_set_o,
    output hpdcache_word_t        flush_data_read_word_o,
    output hpdcache_way_vector_t  flush_data_read_way_o,
    input  hpdcache_access_data_t flush_data_read_data_i,
    //      }}}

    //      ACK monitoring interface
    //      {{{
    output logic                  flush_ack_o,
    output hpdcache_nline_t       flush_ack_nline_o,
    //      }}}

    //      MEMORY interface
    //      {{{
    input  logic                  mem_req_write_ready_i,
    output logic                  mem_req_write_valid_o,
    output hpdcache_mem_req_t     mem_req_write_o,

    input  logic                  mem_req_write_data_ready_i,
    output logic                  mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t   mem_req_write_data_o,

    output logic                  mem_resp_write_ready_o,
    input  logic                  mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t  mem_resp_write_i
    //      }}}
);
```

### `rtl/src/hpdcache_miss_handler.sv`

```systemverilog
module hpdcache_miss_handler
//  {{{
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_word_t = logic,

    parameter type hpdcache_way_vector_t = logic,
    parameter type hpdcache_way_t = logic,

    parameter type hpdcache_dir_entry_t = logic,

    parameter type hpdcache_refill_data_t = logic,

    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_tid_t = logic,

    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,

    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic
)
//  }}}

//  Ports
//  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Global control signals
    //      {{{
    output logic                  mshr_empty_o,
    output logic                  mshr_full_o,
    //      }}}

    //      Configuration signals
    //      {{{
    input  logic                  cfg_prefetch_updt_sel_victim_i,
    //      }}}

    //      CHECK interface
    //      {{{
    input  logic                  mshr_check_i,
    input  hpdcache_req_offset_t  mshr_check_offset_i,
    input  hpdcache_nline_t       mshr_check_nline_i,
    output logic                  mshr_check_hit_o,
    //      }}}

    //      MISS interface
    //      {{{
    //          MISS request interface
    output logic                  mshr_alloc_ready_o,
    input  logic                  mshr_alloc_i,
    input  logic                  mshr_alloc_cs_i,
    input  hpdcache_nline_t       mshr_alloc_nline_i,
    output logic                  mshr_alloc_full_o,
    output logic                  mshr_alloc_cbuf_full_o,
    input  hpdcache_req_tid_t     mshr_alloc_tid_i,
    input  hpdcache_req_sid_t     mshr_alloc_sid_i,
    input  hpdcache_word_t        mshr_alloc_word_i,
    input  hpdcache_way_vector_t  mshr_alloc_victim_way_i,
    input  logic                  mshr_alloc_need_rsp_i,
    input  logic                  mshr_alloc_is_prefetch_i,
    input  logic                  mshr_alloc_wback_i,
    input  logic                  mshr_alloc_dirty_i,
    input  hpdcache_req_data_t    mshr_alloc_wdata_i,
    input  hpdcache_req_be_t      mshr_alloc_be_i,

    //          REFILL MISS / Invalidation interface
    input  logic                  refill_req_ready_i,
    output logic                  refill_req_valid_o,
    output logic                  refill_is_error_o,
    output logic                  refill_busy_o,
    output logic                  refill_updt_sel_victim_o,
    output hpdcache_set_t         refill_set_o,
    output hpdcache_way_vector_t  refill_way_o,
    output hpdcache_dir_entry_t   refill_dir_entry_o,
    output logic                  refill_write_dir_o,
    output logic                  refill_write_data_o,
    output hpdcache_refill_data_t refill_data_o,
    output hpdcache_word_t        refill_word_o,
    output hpdcache_nline_t       refill_nline_o,
    output logic                  refill_updt_rtab_o,

    output logic                  inval_check_dir_o,
    output logic                  inval_write_dir_o,
    output hpdcache_nline_t       inval_nline_o,
    input  logic                  inval_hit_i,

    //          REFILL core response interface
    output logic                  refill_core_rsp_valid_o,
    output hpdcache_rsp_t         refill_core_rsp_o,
    //      }}}

    //      MEMORY interface
    //      {{{
    input  logic                  mem_req_ready_i,
    output logic                  mem_req_valid_o,
    output hpdcache_mem_req_t     mem_req_o,

    output logic                  mem_resp_ready_o,
    input  logic                  mem_resp_valid_i,
    input  hpdcache_mem_resp_r_t  mem_resp_i,
    input  logic                  mem_resp_inval_i,
    input  hpdcache_nline_t       mem_resp_inval_nline_i
    //      }}}
);
```

### `rtl/src/hpdcache_uncached.sv`

```systemverilog
module hpdcache_uncached
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_offset_t = logic,
    parameter type hpdcache_word_t = logic,

    parameter type hpdcache_req_addr_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,

    parameter type hpdcache_way_vector_t = logic,

    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic
)
    //  }}}

    //  Ports
    //  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //  Cache-side request interface
    //  {{{
    input  logic                  req_valid_i,
    output logic                  req_ready_o,
    input  hpdcache_uc_op_t       req_op_i,
    input  hpdcache_req_addr_t    req_addr_i,
    input  hpdcache_req_size_t    req_size_i,
    input  hpdcache_req_data_t    req_data_i,
    input  hpdcache_req_be_t      req_be_i,
    input  logic                  req_uc_i,
    input  hpdcache_req_sid_t     req_sid_i,
    input  hpdcache_req_tid_t     req_tid_i,
    input  logic                  req_need_rsp_i,
    input  hpdcache_way_vector_t  req_hit_way_i,
    input  hpdcache_req_data_t    req_old_data_i,
    //  }}}

    //  AMO Cache Interface
    //  {{{
    output logic                  data_amo_write_o,
    output logic                  data_amo_write_enable_o,
    output hpdcache_set_t         data_amo_write_set_o,
    output hpdcache_req_size_t    data_amo_write_size_o,
    output hpdcache_word_t        data_amo_write_word_o,
    output hpdcache_way_vector_t  data_amo_write_way_o,
    output hpdcache_req_data_t    data_amo_write_data_o,
    output hpdcache_req_be_t      data_amo_write_be_o,
    // }}}

    //  LR/SC reservation buffer
    //  {{{
    input  logic                  lrsc_snoop_i,
    input  hpdcache_req_addr_t    lrsc_snoop_addr_i,
    input  hpdcache_req_size_t    lrsc_snoop_size_i,
    //  }}}

    //  Core response interface
    //  {{{
    input  logic                  core_rsp_ready_i,
    output logic                  core_rsp_valid_o,
    output hpdcache_rsp_t         core_rsp_o,
    //  }}}

    //  MEMORY interfaces
    //  {{{
    //      Memory request unique identifier
    input  hpdcache_mem_id_t      mem_read_id_i,
    input  hpdcache_mem_id_t      mem_write_id_i,

    //      Read interface
    input  logic                  mem_req_read_ready_i,
    output logic                  mem_req_read_valid_o,
    output hpdcache_mem_req_t     mem_req_read_o,

    output logic                  mem_resp_read_ready_o,
    input  logic                  mem_resp_read_valid_i,
    input  hpdcache_mem_resp_r_t  mem_resp_read_i,

    //      Write interface
    input  logic                  mem_req_write_ready_i,
    output logic                  mem_req_write_valid_o,
    output hpdcache_mem_req_t     mem_req_write_o,

    input  logic                  mem_req_write_data_ready_i,
    output logic                  mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t   mem_req_write_data_o,

    output logic                  mem_resp_write_ready_o,
    input  logic                  mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t  mem_resp_write_i,
    //  }}}

    //  Configuration interface
    //  {{{
    input  logic                  cfg_error_on_cacheable_amo_i
    //  }}}
);
```

### `rtl/src/hpdcache_wbuf.sv`

```systemverilog
module hpdcache_wbuf
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type wbuf_addr_t = logic,
    parameter type wbuf_timecnt_t = logic,

    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,

    localparam int unsigned WBUF_WORD_WIDTH = HPDcacheCfg.u.reqWords*HPDcacheCfg.u.wordWidth,
    localparam type wbuf_data_t = logic [WBUF_WORD_WIDTH-1:0],
    localparam type wbuf_be_t = logic [WBUF_WORD_WIDTH/8-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    //  Clock and reset signals
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //  Global control signals
    output logic                  empty_o,
    output logic                  full_o,
    input  logic                  flush_all_i,

    //  Configuration signals
    //    Timer threshold
    input  wbuf_timecnt_t         cfg_threshold_i,
    //    Reset timer on write
    input  logic                  cfg_reset_timecnt_on_write_i,
    //    Sequentialize write-after-write hazards
    input  logic                  cfg_sequential_waw_i,
    //    Inhibit write coalescing
    input  logic                  cfg_inhibit_write_coalescing_i,

    //  Write interface
    input  logic                  write_i,
    output logic                  write_ready_o,
    input  wbuf_addr_t            write_addr_i,
    input  wbuf_data_t            write_data_i,
    input  wbuf_be_t              write_be_i,  // byte-enable
    input  logic                  write_uc_i,  // uncacheable write

    //  Read hit interface
    input  wbuf_addr_t            read_addr_i,
    output logic                  read_hit_o,
    input  logic                  read_flush_hit_i,

    //  Replay hit interface
    input  wbuf_addr_t            replay_addr_i,
    input  logic                  replay_is_read_i,
    output logic                  replay_open_hit_o,
    output logic                  replay_pend_hit_o,
    output logic                  replay_sent_hit_o,
    output logic                  replay_not_ready_o,

    //  Memory interface
    input  logic                  mem_req_write_ready_i,
    output logic                  mem_req_write_valid_o,
    output hpdcache_mem_req_t     mem_req_write_o,

    input  logic                  mem_req_write_data_ready_i,
    output logic                  mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t   mem_req_write_data_o,

    output logic                  mem_resp_write_ready_o,
    input  logic                  mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t  mem_resp_write_i
);
```

### `rtl/src/utils/hpdcache_mem_req_read_arbiter.sv`

```systemverilog
module hpdcache_mem_req_read_arbiter
//  Parameters
//  {{{
#(
    parameter int unsigned N = 0,
    parameter type hpdcache_mem_req_t = logic,
    localparam type gnt_index_t = logic[(N > 1 ? $clog2(N) - 1 : 0):0]
)
//  }}}

//  Ports
//  {{{
(
    input  logic                      clk_i,
    input  logic                      rst_ni,

    output logic              [N-1:0] mem_req_read_ready_o,
    input  logic              [N-1:0] mem_req_read_valid_i,
    input  hpdcache_mem_req_t [N-1:0] mem_req_read_i,

    input  logic                      mem_req_read_ready_i,
    output logic                      mem_req_read_valid_o,
    output hpdcache_mem_req_t         mem_req_read_o,

    output gnt_index_t                gnt_index_o
);
```

### `rtl/src/utils/hpdcache_mem_req_write_arbiter.sv`

```systemverilog
module hpdcache_mem_req_write_arbiter
//  Parameters
//  {{{
#(
    parameter int unsigned N = 0,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic
)
//  }}}
//  Ports
//  {{{
(
    input  logic                        clk_i,
    input  logic                        rst_ni,

    output logic                [N-1:0] mem_req_write_ready_o,
    input  logic                [N-1:0] mem_req_write_valid_i,
    input  hpdcache_mem_req_t   [N-1:0] mem_req_write_i,

    output logic                [N-1:0] mem_req_write_data_ready_o,
    input  logic                [N-1:0] mem_req_write_data_valid_i,
    input  hpdcache_mem_req_w_t [N-1:0] mem_req_write_data_i,

    input  logic                        mem_req_write_ready_i,
    output logic                        mem_req_write_valid_o,
    output hpdcache_mem_req_t           mem_req_write_o,

    input  logic                        mem_req_write_data_ready_i,
    output logic                        mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t         mem_req_write_data_o
);
```

## Related source code

### `rtl/src/hpdcache_memctrl.sv`

```systemverilog
                    dir_wentry[i] = '{
                        valid: dir_cmo_updt_valid_i,
                        wback: dir_cmo_updt_wback_i,
                        dirty: dir_cmo_updt_dirty_i,
                        fetch: dir_cmo_updt_fetch_i,
                        tag  : dir_cmo_updt_tag_i
                    };
```

## Documentation

### `docs/source/overview.rst`

```text
Overview
========

This HPDcache is responsible for serving data accesses issued by a RISC-V core, tightly-coupled accelerators and hardware memory prefetchers.
All these "clients" are called requesters.

The HPDcache implements a hardware pipeline capable of serving one request per cycle.
An arbiter in the requesters’ interface of the HPDcache guarantees the correct behavior when there are multiple requesters.
This is illustrated in :numref:`Figure %s <fig_request_arbiter>`.

.. _fig_request_arbiter:

.. figure:: images/hpdcache_highlevel_integration.*
   :alt: High-Level View of the HPDcache Sub-System
   :align: center
   :width: 90%

   High-Level View of the HPDcache Sub-System

List of features
----------------

- Support for multiple outstanding requests per requester.

- Support for multiple outstanding read misses and writes to memory.

- Processes one request per cycle.

- Any given requester can access 1 to 64 bytes of a cacheline per cycle.

- Reduced energy consumption by limiting the number of RAMs consulted per
  request.

- Fixed priority arbiter between requesters: the requester port with the lowest
  index has the highest priority.

- Non-allocate, write-through policy or allocate, write-back policy. Either one
  or both are supported simultaneously at cacheline granularity.

- Hardware write-buffer to mask the latency of write acknowledgements from
  the memory system.

- Compliance with RVWMO.

- For address-overlapping transactions, the cache guarantees that these are
  committed in the order in which they are consumed from the requesters.

- For non-address-overlapping transactions, the cache may execute them in an
  out-of-order fashion to improve performance.

- Support for CMOs: cache invalidation operations, and memory fences for
  multi-core synchronisation.  Cache invalidation operations support the ones
  defined in the RISC-V CMO Standard.

- Memory-mapped CSRs for runtime configuration of the cache, status and
  performance monitoring.

- Ready-Valid, 5 channels (3 request/2 response), interface to the memory. This
  interface, cache memory interface (CMI), can be easily adapted to mainstream
  NoC interfaces like AMBA AXI [AXI2020]_.

- An adapter for interfacing with AXI5 is provided.

- External (optional), configurable, hardware, memory-prefetcher that supports
  up to 4 simultaneous prefetching streams.
```

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
```

### `docs/source/interface.rst`

```text
This section describes the Cache-Memory Interface (CMI) between the HPDcache
and the NoC/memory. It implements 5 different channels.

This interface is synchronous to the rising edge of the global clock
``clk_i``.

All CMI interfaces implements the ready-valid protocol described in section
:ref:`sec_ready_valid_handshake` for the handshake
between the HPDcache and the NoC/Memory.

The address (``mem_req_addr``), size (``mem_req_size``),
write data (``mem_req_w_data``) and write byte-enable (``mem_req_w_be``)
signals shall comply with the alignment constraints defined in section
:ref:`Address, data, and byte enable alignment <sec_req_alignment>`.


.. _sec_mi_signal_descriptions:

CMI Signal Descriptions
~~~~~~~~~~~~~~~~~~~~~~~

- **Memory Read Interfaces**

.. _tab_read_req_channel_signals:

.. list-table:: CMI Read Request Channel Signals
   :widths: 31 13 52
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``mem_req_read_valid_o``
     - Cache
     - Indicates that the channel is signaling a valid request
   * - ``mem_req_read_ready_i``
     - NoC
     - Indicates that the NoC is ready to accept a request
   * - ``mem_req_read_o.mem_req_addr``
     - Cache
     - Target physical address of the request. The address shall be aligned to
       the ``mem_req_read_o.mem_req_size`` field.
   * - ``mem_req_read_o.mem_req_len``
     - Cache
     - Indicates the number of transfers in a burst minus one
   * - ``mem_req_read_o.mem_req_size``
     - Cache
     - Indicate the size of the access. The size is encoded as the power-of-two
       of the number of bytes
   * - ``mem_req_read_o.mem_req_id``
     - Cache
     - The identification tag for the request. The HPDcache always use unique
       IDs on the memory interface (i.e. two or more in-flight requests cannot
       share the same ID).
   * - ``mem_req_read_o.mem_req_command``
     - Cache
     - Indicates the type of operation to be performed
   * - ``mem_req_read_o.mem_req_atomic``
     - Cache
     - In case of atomic operations, it indicates its type
   * - ``mem_req_read_o.mem_req_cacheable``
     - Cache
     - This is a hint for the cache hierarchy in the system. It indicates if
       the request can be allocated by the cache hierarchy. That is, data can
       be prefetched from memory or can be reused for multiple read
       transactions


.. _tab_read_miss_resp_channel_signals:

.. list-table:: CMI Read Response Channel Signals
   :widths: 31 13 52
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``mem_resp_read_valid_i``
     - NoC
     - Indicates that the channel is signaling a valid response
   * - ``mem_resp_read_ready_o``
     - Cache
     - Indicates that the cache is ready to accept a response
   * - ``mem_resp_read_i.mem_resp_r_error``
     - NoC
     - Indicates whether there was an error condition while processing the
       request
   * - ``mem_resp_read_i.mem_resp_r_id``
     - NoC
     - The identification tag for the request. It corresponds to the ID
       transferred with the request
   * - ``mem_resp_read_i.mem_resp_r_data``
     - NoC
     - Response read data. It shall be naturally aligned to the request address
   * - ``mem_resp_read_i.mem_resp_r_last``
     - NoC
     - Indicates the last transfer in a read response burst


- **Memory Write Interfaces**

.. _tab_write_req_channel_signals:

.. list-table:: CMI Write Request Channel Signals
   :widths: 31 13 52
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``mem_req_write_valid_o``
     - Cache
     - Indicates that the channel is signaling a valid request
   * - ``mem_req_write_ready_i``
     - NoC
     - Indicates that the cache is ready to accept a response
   * - ``mem_req_write_o.mem_req_addr``
     - Cache
     - Target physical address of the request
   * - ``mem_req_write_o.mem_req_len``
     - Cache
     - Indicates the number of transfers in a burst minus one
   * - ``mem_req_write_o.mem_req_size``
     - Cache
     - Indicate the size of the access. The size is encoded as the
       power-of-two of the number of bytes
   * - ``mem_req_write_o.mem_req_id``
     - Cache
     - The identification tag for the request. The HPDcache always use unique
       IDs on the memory interface (i.e. two or more in-flight requests cannot
       share the same ID).
   * - ``mem_req_write_o.mem_req_command``
     - Cache
     - Indicates the type of operation to be performed
   * - ``mem_req_write_o.mem_req_atomic``
     - Cache
     - In case of atomic operations, it indicates its type
   * - ``mem_req_write_o.mem_req_cacheable``
     - Cache
     - This is a hint for the cache hierarchy in the system. It indicates if
       the write is bufferable by the cache hierarchy. This means that the
       write must be visible in a timely manner at the final destination.
       However, write responses can be obtained from an intermediate point


.. _tab_write_data_channel_signals:

.. list-table:: CMI Write Data Channel Signals
   :widths: 31 13 52
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``mem_req_write_data_valid_o``
     - Cache
     - Indicates that the channel is transferring a valid data
   * - ``mem_req_write_data_ready_i``
     - NoC
     - Indicates that the target is ready to accept the data
   * - ``mem_req_write_data_o.mem_req_w_data``
     - Cache
     - Request write data. It shall be naturally aligned to the request
       address
   * - ``mem_req_write_data_o.mem_req_w_be``
     - Cache
     - Request write byte-enable. It shall be naturally aligned to the request
       address
   * - ``mem_req_write_data_o.mem_req_w_last``
     - Cache
     - Indicates the last transfer in a write request burst


.. _tab_write_resp_channel_signals:

.. list-table:: CMI Write Response Channel Signals
   :widths: 31 13 52
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``mem_resp_write_valid_i``
     - NoC
     - Indicates that the channel is transferring a valid write acknowledgement
   * - ``mem_resp_write_ready_o``
     - Cache
     - Indicates that the cache is ready to accept the acknowledgement
   * - ``mem_resp_write_i.mem_resp_w_is_atomic``
     - NoC
     - Indicates whether the atomic operation was successfully processed
       (atomically)
   * - ``mem_resp_write_i.mem_resp_w_error``
     - NoC
     - Indicates whether there was an error condition while processing the
       request
   * - ``mem_resp_write_i.mem_resp_w_id``
     - NoC
     - The identification tag for the request. It corresponds to the ID
       transferred with the request


Interfaces’ requirements
------------------------

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
...
Each request identifies transactions through the ``mem_req_*_o.mem_req_id``
signals. The ``mem_req_*_o.mem_req_id`` signal shall be decoded when the
``mem_req_*_valid_o`` signal is set to 1. The width of these ID signals is
:math:`\scriptsize\mathsf{CONF\_HPDCACHE\_MEM\_ID\_WIDTH}` bits.

The target (memory or peripheral) shall respond to a request by setting the
``mem_resp*_i.mem_resp_*_id`` signal to the corresponding
``mem_req*_i.mem_req_id``.

``mem_req_*_o.mem_req_id`` signals can contain any value from 0 to
:math:`\scriptsize\mathsf{2^CONF\_HPDCACHE\_MEM\_ID\_WIDTH - 1}`.

The HPDcache can issue multiple memory transactions without waiting for earlier
transactions to complete. The HPDcache uses unique IDs for each request.  Unique
IDs means that two or more in-flight requests never share the same ID. In-flight
requests are those that have been issued by the HPDcache but have not yet
received their respective response.

The target (memory or peripheral) of the in-flight request may respond to CMI
in-flight requests in any order.


- **Transaction IDs in the CMI read request channel**

The HPDcache can have the following number of in-flight read miss transactions:

   :math:`\scriptsize\mathsf{CONF\_HPDCACHE\_MSHR\_SETS{}\times{}CONF\_HPDCACHE\_MSHR\_WAYS}`

Each in-flight transaction has a unique transaction ID. This ID is formatted as
follows:

   - For cacheable requests:

   ``(mshr_way << log2(HPDCACHE_MSHR_SETS)) | mshr_set``

   The ID is the concatenation of two indexes: the MSHR set and the MSHR way
   occupied by the corresponding request.

   - For uncacheable requests

   The HPDcache can issue up to 1 in-flight, uncached, read transaction.
   Uncached transactions have a unique transaction ID with all bits set to 1.


- **Transaction IDs in the CMI wbuf write request channel**

The HPDcache can have the following number of in-flight write transactions:

   :math:`\scriptsize\mathsf{CONF\_HPDCACHE\_WBUF\_DIR\_ENTRIES}`

Each in-flight transaction has a unique transaction ID. This ID is formatted as
follows:

  - For cacheable requests:

   The ID corresponds to the index of the entry in the write-buffer directory.

   ``wbuf_dir_index``


  - For uncacheable requests

    The HPDcache can issue up to 1 in-flight, uncached, write transaction.
    Uncached transactions have a unique transaction ID with all bits set to 1.


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
