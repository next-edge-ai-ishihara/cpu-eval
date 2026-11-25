# Implement `cva6_hpdcache_subsystem`

Implement the complete `cva6_hpdcache_subsystem` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module cva6_hpdcache_subsystem` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

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

// ...

      DcacheIdWidth: int'(1)
```

### core/include/build_config_pkg.sv

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

## Module declaration

```systemverilog
module cva6_hpdcache_subsystem
//  Parameters
//  {{{
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type icache_areq_t = logic,
    parameter type icache_arsp_t = logic,
    parameter type icache_dreq_t = logic,
    parameter type icache_drsp_t = logic,
    parameter type icache_req_t = logic,
    parameter type icache_rtrn_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter int NumPorts = 4,
    parameter int NrHwPrefetchers = 4,
    // AXI types
    parameter type axi_ar_chan_t = logic,
    parameter type axi_aw_chan_t = logic,
    parameter type axi_w_chan_t = logic,
    parameter type axi_b_chan_t = logic,
    parameter type axi_r_chan_t = logic,
    parameter type noc_req_t = logic,
    parameter type noc_resp_t = logic
)
//  }}}

//  Ports
//  {{{
(

    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,

    //  AXI port to upstream memory/peripherals
    //  {{{
    // noc request, can be AXI or OpenPiton - SUBSYSTEM
    output noc_req_t  noc_req_o,
    // noc response, can be AXI or OpenPiton - SUBSYSTEM
    input  noc_resp_t noc_resp_i,
    //  }}}

    //  I$
    //  {{{
    // Instruction cache enable - CSR_REGFILE
    input logic icache_en_i,
    // Flush the instruction cache - CONTROLLER
    input logic icache_flush_i,
    // instruction cache miss - PERF_COUNTERS
    output logic icache_miss_o,
    // Input address translation request - EX_STAGE
    input icache_areq_t icache_areq_i,
    // Output address translation request - EX_STAGE
    output icache_arsp_t icache_areq_o,
    // Input data translation request - FRONTEND
    input icache_dreq_t icache_dreq_i,
    // Output data translation request - FRONTEND
    output icache_drsp_t icache_dreq_o,
    //   }}}

    //  D$
    //  {{{
    //    Cache management
    // Data cache enable - CSR_REGFILE
    input logic dcache_enable_i,
    // Data cache flush - CONTROLLER
    input logic dcache_flush_i,
    // Flush acknowledge - CONTROLLER
    output logic dcache_flush_ack_o,
    // Load or store miss - PERF_COUNTERS
    output logic dcache_miss_o,
    // Data cache scrubber enable - CSR_REGFILE
    input logic dcache_scrub_enable_i,
    // Data cache scrubber period - CSR_REGFILE
    input logic [5:0] dcache_scrub_period_i,
    // Data cache scrubber cycle - CSR_REGFILE
    output logic dcache_scrub_cycle_o,
    // Data cache data error corrected - CSR_REGFILE
    output logic dcache_dat_cor_err_o,
    // Data cache data error detected but not corrected - CSR_REGFILE
    output logic dcache_dat_unc_err_o,
    // Data cache tag error corrected - CSR_REGFILE
    output logic dcache_dir_cor_err_o,
    // Data cache tag error detected but not corrected - CSR_REGFILE
    output logic dcache_dir_unc_err_o,

    // AMO request - EX_STAGE
    input  ariane_pkg::amo_req_t                 dcache_amo_req_i,
    // AMO response - EX_STAGE
    output ariane_pkg::amo_resp_t                dcache_amo_resp_o,
    // Data cache input request ports - EX_STAGE
    input  dcache_req_i_t         [NumPorts-1:0] dcache_req_ports_i,
    // Data cache output request ports - EX_STAGE
    output dcache_req_o_t         [NumPorts-1:0] dcache_req_ports_o,
    // Write buffer status to know if empty - EX_STAGE
    output logic                                 wbuffer_empty_o,
    // Write buffer status to know if not non idempotent - EX_STAGE
    output logic                                 wbuffer_not_ni_o,

    //  Hardware memory prefetcher configuration
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0]       hwpf_base_set_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_base_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_base_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0]       hwpf_param_set_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_param_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_param_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0]       hwpf_throttle_set_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_throttle_i,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_throttle_o,
    // TO_BE_COMPLETED - TO_BE_COMPLETED
    output logic [               63:0]       hwpf_status_o
    //  }}}
);
```

## Dependency declarations

### rtl/src/hpdcache_pkg.sv

```systemverilog
    typedef enum logic {
        HPDCACHE_VICTIM_RANDOM = 1'b0,
        HPDCACHE_VICTIM_PLRU   = 1'b1
    } hpdcache_victim_sel_policy_t;

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

### rtl/include/hpdcache_typedef.svh

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

### core/cache_subsystem/cva6_icache.sv

```systemverilog
module cva6_icache
  import ariane_pkg::*;
  import wt_cache_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type icache_areq_t = logic,
    parameter type icache_arsp_t = logic,
    parameter type icache_dreq_t = logic,
    parameter type icache_drsp_t = logic,
    parameter type icache_req_t = logic,
    parameter type icache_rtrn_t = logic,
    /// ID to be used for read transactions
    parameter logic [CVA6Cfg.MEM_TID_WIDTH-1:0] RdTxId = 0
) (
    input logic clk_i,
    input logic rst_ni,

    /// flush the icache, flush and kill have to be asserted together
    input  logic         flush_i,
    /// enable icache
    input  logic         en_i,
    /// to performance counter
    output logic         miss_o,
    // address translation requests
    input  icache_areq_t areq_i,
    output icache_arsp_t areq_o,
    // data requests
    input  icache_dreq_t dreq_i,
    output icache_drsp_t dreq_o,
    // refill port
    input  logic         mem_rtrn_vld_i,
    input  icache_rtrn_t mem_rtrn_i,
    output logic         mem_data_req_o,
    input  logic         mem_data_ack_i,
    output icache_req_t  mem_data_o
);
```

### core/cache_subsystem/cva6_hpdcache_wrapper.sv

```systemverilog
module cva6_hpdcache_wrapper
//  Parameters
//  {{{
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter int NumPorts = 4,
    parameter int NrHwPrefetchers = 4,

    parameter type hpdcache_mem_addr_t = logic,
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_data_t = logic,
    parameter type hpdcache_mem_be_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_data_word_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    parameter type hpdcache_wbuf_timecnt_t = logic,
    parameter type hpdcache_data_be_t = logic,

    localparam type hpdcache_nline_t = logic [HPDcacheCfg.nlineWidth-1:0]
)
//  }}}

//  Ports
//  {{{
(

    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,

    //  D$
    //  {{{
    //    Cache management
    // Data cache enable - CSR_REGFILE
    input  logic dcache_enable_i,
    // Data cache flush - CONTROLLER
    input  logic dcache_flush_i,
    // Flush acknowledge - CONTROLLER
    output logic dcache_flush_ack_o,
    // Load or store miss - PERF_COUNTERS
    output logic dcache_miss_o,

    // AMO request/response - EX_STAGE
    input  ariane_pkg::amo_req_t                 dcache_amo_req_i,
    output ariane_pkg::amo_resp_t                dcache_amo_resp_o,
    // Data cache input request/response ports - EX_STAGE
    input  dcache_req_i_t         [NumPorts-1:0] dcache_req_ports_i,
    output dcache_req_o_t         [NumPorts-1:0] dcache_req_ports_o,
    // Data cache scrubber enable - CSR_REGFILE
    input  logic                                 dcache_scrub_enable_i,
    // Data cache scrubber period - CSR_REGFILE
    input  logic                  [         5:0] dcache_scrub_period_i,
    // Data cache scrub cycle - CSR_REGFILE
    output logic                                 dcache_scrub_cycle_o,
    // Data cache data error corrected - CSR_REGFILE
    output logic                                 dcache_dat_cor_err_o,
    // Data cache data error detected but not corrected - CSR_REGFILE
    output logic                                 dcache_dat_unc_err_o,
    // Data cache tag error corrected - CSR_REGFILE
    output logic                                 dcache_dir_cor_err_o,
    // Data cache tag error detected but not corrected - CSR_REGFILE
    output logic                                 dcache_dir_unc_err_o,

    // Write buffer status - EX_STAGE
    output logic wbuffer_empty_o,
    output logic wbuffer_not_ni_o,

    //  Hardware memory prefetcher configuration
    input  logic [NrHwPrefetchers-1:0]       hwpf_base_set_i,
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_base_i,
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_base_o,
    input  logic [NrHwPrefetchers-1:0]       hwpf_param_set_i,
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_param_i,
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_param_o,
    input  logic [NrHwPrefetchers-1:0]       hwpf_throttle_set_i,
    input  logic [NrHwPrefetchers-1:0][63:0] hwpf_throttle_i,
    output logic [NrHwPrefetchers-1:0][63:0] hwpf_throttle_o,
    output logic [               63:0]       hwpf_status_o,

    input  logic              dcache_mem_req_read_ready_i,
    output logic              dcache_mem_req_read_valid_o,
    output hpdcache_mem_req_t dcache_mem_req_read_o,

    output logic                 dcache_mem_resp_read_ready_o,
    input  logic                 dcache_mem_resp_read_valid_i,
    input  hpdcache_mem_resp_r_t dcache_mem_resp_read_i,

    input logic            dcache_mem_resp_read_inval_i,
    input hpdcache_nline_t dcache_mem_resp_read_inval_nline_i,

    input  logic              dcache_mem_req_write_ready_i,
    output logic              dcache_mem_req_write_valid_o,
    output hpdcache_mem_req_t dcache_mem_req_write_o,

    input  logic                dcache_mem_req_write_data_ready_i,
    output logic                dcache_mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t dcache_mem_req_write_data_o,

    output logic                 dcache_mem_resp_write_ready_o,
    input  logic                 dcache_mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t dcache_mem_resp_write_i
);
```

### core/cache_subsystem/cva6_hpdcache_subsystem_axi_arbiter.sv

```systemverilog
module cva6_hpdcache_subsystem_axi_arbiter
//  Parameters
//  {{{
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,
    parameter type icache_req_t = logic,
    parameter type icache_rtrn_t = logic,

    parameter int unsigned AxiAddrWidth = 1,
    parameter int unsigned AxiDataWidth = 1,
    parameter int unsigned AxiIdWidth = 1,
    parameter int unsigned AxiUserWidth = 1,
    parameter type axi_ar_chan_t = logic,
    parameter type axi_aw_chan_t = logic,
    parameter type axi_w_chan_t = logic,
    parameter type axi_b_chan_t = logic,
    parameter type axi_r_chan_t = logic,
    parameter type axi_req_t = logic,
    parameter type axi_rsp_t = logic
)
//  }}}

//  Ports
//  {{{
(
    input logic clk_i,
    input logic rst_ni,

    //  Interfaces from/to I$
    //  {{{
    input  logic             icache_miss_valid_i,
    output logic             icache_miss_ready_o,
    input  icache_req_t      icache_miss_i,
    input  hpdcache_mem_id_t icache_miss_id_i,

    output logic         icache_miss_resp_valid_o,
    output icache_rtrn_t icache_miss_resp_o,
    //  }}}

    //  Interfaces from/to D$
    //  {{{
    //      Read interface
    output logic              dcache_read_ready_o,
    input  logic              dcache_read_valid_i,
    input  hpdcache_mem_req_t dcache_read_i,

    input  logic                 dcache_read_resp_ready_i,
    output logic                 dcache_read_resp_valid_o,
    output hpdcache_mem_resp_r_t dcache_read_resp_o,

    //      Write interface
    output logic              dcache_write_ready_o,
    input  logic              dcache_write_valid_i,
    input  hpdcache_mem_req_t dcache_write_i,

    output logic                dcache_write_data_ready_o,
    input  logic                dcache_write_data_valid_i,
    input  hpdcache_mem_req_w_t dcache_write_data_i,

    input  logic                 dcache_write_resp_ready_i,
    output logic                 dcache_write_resp_valid_o,
    output hpdcache_mem_resp_w_t dcache_write_resp_o,
    //  }}}

    //  AXI port to upstream memory/peripherals
    //  {{{
    output axi_req_t axi_req_o,
    input  axi_rsp_t axi_resp_i
    //  }}}
);
```

## Related source code

### core/cache_subsystem/cva6_icache.sv

```systemverilog
  assign mem_data_o.tid = RdTxId;
```

### core/cache_subsystem/cva6_hpdcache_wrapper.sv

```systemverilog
  localparam int HPDCACHE_NREQUESTERS = NumPorts + 1;
```

### core/cache_subsystem/cva6_hpdcache_subsystem_axi_arbiter.sv

```systemverilog
  //  Internal type definitions
  //  {{{

  localparam int MEM_RESP_RT_DEPTH = (1 << CVA6Cfg.MEM_TID_WIDTH);
  typedef hpdcache_mem_id_t [MEM_RESP_RT_DEPTH-1:0] mem_resp_rt_t;
  typedef logic [CVA6Cfg.ICACHE_LINE_WIDTH-1:0] icache_resp_data_t;
  //  }}}

// ...

  //  Read response demultiplexor
  //  {{{
  logic                 mem_resp_read_ready;
  logic                 mem_resp_read_valid;
  hpdcache_mem_resp_r_t mem_resp_read;

  logic                 mem_resp_read_ready_arb[1:0];
  logic                 mem_resp_read_valid_arb[1:0];
  hpdcache_mem_resp_r_t mem_resp_read_arb      [1:0];

  mem_resp_rt_t         mem_resp_read_rt;

  always_comb begin
    for (int i = 0; i < MEM_RESP_RT_DEPTH; i++) begin
      mem_resp_read_rt[i] = (i == int'(icache_miss_id_i)) ? 0 : 1;
    end
  end

  hpdcache_mem_resp_demux #(
      .N        (2),
      .resp_t   (hpdcache_mem_resp_r_t),
      .resp_id_t(hpdcache_mem_id_t)
  ) i_mem_resp_read_demux (
      .clk_i,
      .rst_ni,

      .mem_resp_ready_o(mem_resp_read_ready),
      .mem_resp_valid_i(mem_resp_read_valid),
      .mem_resp_id_i   (mem_resp_read.mem_resp_r_id),
      .mem_resp_i      (mem_resp_read),

      .mem_resp_ready_i(mem_resp_read_ready_arb),
      .mem_resp_valid_o(mem_resp_read_valid_arb),
      .mem_resp_o      (mem_resp_read_arb),

      .mem_resp_rt_i(mem_resp_read_rt)
  );

  assign icache_miss_resp_w = mem_resp_read_valid_arb[0];
  assign icache_miss_resp_wdata = mem_resp_read_arb[0];
  assign mem_resp_read_ready_arb[0] = icache_miss_resp_wok;

  assign dcache_read_resp_valid_o = mem_resp_read_valid_arb[1];
  assign dcache_read_resp_o = mem_resp_read_arb[1];
  assign mem_resp_read_ready_arb[1] = dcache_read_resp_ready_i;
  //  }}}

// ...

  //  Assertions
  //  {{{
  //  pragma translate_off
  initial
    assert (CVA6Cfg.MEM_TID_WIDTH <= AxiIdWidth)
    else $fatal(1, "MEM_TID_WIDTH shall be less or equal to AxiIdWidth");
  initial
    assert (CVA6Cfg.AxiDataWidth <= CVA6Cfg.ICACHE_LINE_WIDTH)
    else $fatal(1, "AxiDataWidth shall be less or equal to the width of a Icache line");
  initial
    assert (CVA6Cfg.AxiDataWidth <= CVA6Cfg.DCACHE_LINE_WIDTH)
    else $fatal(1, "AxiDataWidth shall be less or equal to the width of a Dcache line");
  //  pragma translate_on
  //  }}}
```

## Documentation

### docs/source/interface.rst

```rst
CMI Transaction identifier
~~~~~~~~~~~~~~~~~~~~~~~~~~

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
```
