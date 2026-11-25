# Implement `hpdcache_miss_handler`

Implement the complete `hpdcache_miss_handler` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_miss_handler` definition in a single SystemVerilog code
block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv32a60x_config_pkg.sv`

```systemverilog
  localparam CVA6ConfigXlen = 32;

  localparam CVA6ConfigRvfiTrace = 1;

  localparam CVA6ConfigAxiIdWidth = 4;  // axi_pkg.sv
  localparam CVA6ConfigAxiAddrWidth = 64;  // axi_pkg.sv
  localparam CVA6ConfigAxiDataWidth = 64;  // axi_pkg.sv
  localparam CVA6ConfigDataUserWidth = 32;  // axi_pkg.sv

  localparam config_pkg::cva6_user_cfg_t cva6_cfg = '{
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(32),
      FpgaEn: bit'(0),
      FpgaAlteraEn: bit'(0),
      TechnoCut: bit'(1),
      SuperscalarEn: bit'(0),
      ALUBypass: bit'(0),
      NrCommitPorts: unsigned'(1),
      AxiAddrWidth: unsigned'(CVA6ConfigAxiAddrWidth),
      AxiDataWidth: unsigned'(CVA6ConfigAxiDataWidth),
      AxiIdWidth: unsigned'(CVA6ConfigAxiIdWidth),
      AxiUserWidth: unsigned'(CVA6ConfigDataUserWidth),
      MemTidWidth: unsigned'(CVA6ConfigAxiIdWidth),
      NrLoadBufEntries: unsigned'(2),

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

### `core/cache_subsystem/cva6_hpdcache_subsystem.sv`

```systemverilog
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

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
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

    function automatic hpdcache_mem_size_t get_hpdcache_mem_size(int unsigned bytes);
        if      (bytes ==   0) return 0;
        else if (bytes <=   2) return 1;
        else if (bytes <=   4) return 2;
        else if (bytes <=   8) return 3;
        else if (bytes <=  16) return 4;
        else if (bytes <=  32) return 5;
        else if (bytes <=  64) return 6;
        else if (bytes <= 128) return 7;
        else begin
`ifndef HPDCACHE_ASSERT_OFF
            assert (1) $error("hpdcache: unsupported number of bytes");
`endif
            return 0;
        end
    endfunction

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

## Module declaration

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

## Parent instantiation

### `rtl/src/hpdcache.sv`

```systemverilog
    //  Cache Directory entry definition
    //  {{{
    typedef struct packed {
        //  Cacheline state
        //  Encoding: {valid, wb, dirty, fetch}
        //            {0,X,X,0}: Invalid
        //            {0,X,X,1}: Invalid and Fetching
        //            {1,X,X,1}: Valid and Fetching (cacheline being replaced is accessible)
        //            {1,0,0,0}: Write-through
        //            {1,1,0,0}: Write-back (clean)
        //            {1,1,1,0}: Write-back (dirty)
        //  {{{
        logic valid; //  valid cacheline
        logic wback; //  cacheline in write-back mode
        logic dirty; //  cacheline is locally modified (memory is obsolete)
        logic fetch; //  cacheline is reserved for a new cacheline being fetched
        //  }}}

        //  Cacheline address tag
        //  {{{
        hpdcache_tag_t tag;
        //  }}}
    } hpdcache_dir_entry_t;
    //  }}}

// ...

    localparam logic [HPDcacheCfg.u.memIdWidth-1:0] HPDCACHE_UC_READ_ID =
        {HPDcacheCfg.u.memIdWidth{1'b1}};

// ...

    //  Miss handler
    //  {{{
    hpdcache_miss_handler #(
        .HPDcacheCfg                        (HPDcacheCfg),
        .hpdcache_nline_t                   (hpdcache_nline_t),
        .hpdcache_set_t                     (hpdcache_set_t),
        .hpdcache_tag_t                     (hpdcache_tag_t),
        .hpdcache_word_t                    (hpdcache_word_t),
        .hpdcache_way_vector_t              (hpdcache_way_vector_t),
        .hpdcache_way_t                     (hpdcache_way_t),
        .hpdcache_dir_entry_t               (hpdcache_dir_entry_t),
        .hpdcache_refill_data_t             (hpdcache_access_data_t),
        .hpdcache_req_data_t                (hpdcache_req_data_t),
        .hpdcache_req_be_t                  (hpdcache_req_be_t),
        .hpdcache_req_offset_t              (hpdcache_req_offset_t),
        .hpdcache_req_sid_t                 (hpdcache_req_sid_t),
        .hpdcache_req_tid_t                 (hpdcache_req_tid_t),
        .hpdcache_req_t                     (hpdcache_req_t),
        .hpdcache_rsp_t                     (hpdcache_rsp_t),
        .hpdcache_mem_id_t                  (hpdcache_mem_id_t),
        .hpdcache_mem_req_t                 (hpdcache_mem_req_t),
        .hpdcache_mem_resp_r_t              (hpdcache_mem_resp_r_t)
    ) hpdcache_miss_handler_i(
        .clk_i,
        .rst_ni,

        .mshr_empty_o                       (miss_mshr_empty),
        .mshr_full_o                        (/* unused */),

        .cfg_prefetch_updt_sel_victim_i     (cfg_prefetch_updt_plru_i),

        .mshr_check_i                       (miss_mshr_check),
        .mshr_check_offset_i                (miss_mshr_check_offset),
        .mshr_check_nline_i                 (miss_mshr_check_nline),
        .mshr_check_hit_o                   (miss_mshr_hit),

        .mshr_alloc_ready_o                 (miss_mshr_alloc_ready),
        .mshr_alloc_i                       (miss_mshr_alloc),
        .mshr_alloc_cs_i                    (miss_mshr_alloc_cs),
        .mshr_alloc_nline_i                 (miss_mshr_alloc_nline),
        .mshr_alloc_full_o                  (miss_mshr_alloc_full),
        .mshr_alloc_cbuf_full_o             (miss_mshr_alloc_cbuf_full),
        .mshr_alloc_tid_i                   (miss_mshr_alloc_tid),
        .mshr_alloc_sid_i                   (miss_mshr_alloc_sid),
        .mshr_alloc_word_i                  (miss_mshr_alloc_word),
        .mshr_alloc_victim_way_i            (miss_mshr_alloc_victim_way),
        .mshr_alloc_need_rsp_i              (miss_mshr_alloc_need_rsp),
        .mshr_alloc_is_prefetch_i           (miss_mshr_alloc_is_prefetch),
        .mshr_alloc_wback_i                 (miss_mshr_alloc_wback),
        .mshr_alloc_dirty_i                 (miss_mshr_alloc_dirty),
        .mshr_alloc_wdata_i                 (miss_mshr_alloc_wdata),
        .mshr_alloc_be_i                    (miss_mshr_alloc_be),

        .refill_req_ready_i                 (refill_req_ready),
        .refill_req_valid_o                 (refill_req_valid),
        .refill_is_error_o                  (refill_is_error),
        .refill_busy_o                      (refill_busy),
        .refill_updt_sel_victim_o           (refill_updt_sel_victim),
        .refill_set_o                       (refill_set),
        .refill_way_o                       (refill_way),
        .refill_dir_entry_o                 (refill_dir_entry),
        .refill_write_dir_o                 (refill_write_dir),
        .refill_write_data_o                (refill_write_data),
        .refill_data_o                      (refill_data),
        .refill_word_o                      (refill_word),
        .refill_nline_o                     (refill_nline),
        .refill_updt_rtab_o                 (refill_updt_rtab),

        .inval_check_dir_o                  (inval_check_dir),
        .inval_write_dir_o                  (inval_write_dir),
        .inval_nline_o                      (inval_nline),
        .inval_hit_i                        (inval_hit),

        .refill_core_rsp_valid_o            (refill_core_rsp_valid),
        .refill_core_rsp_o                  (refill_core_rsp),

        .mem_req_ready_i                    (mem_req_read_miss_ready),
        .mem_req_valid_o                    (mem_req_read_miss_valid),
        .mem_req_o                          (mem_req_read_miss),

        .mem_resp_ready_o                   (mem_resp_read_miss_ready),
        .mem_resp_valid_i                   (mem_resp_read_miss_valid),
        .mem_resp_i                         (mem_resp_read_miss),
        .mem_resp_inval_i                   (mem_resp_read_miss_inval),
        .mem_resp_inval_nline_i             (mem_resp_read_miss_inval_nline)
    );
    //  }}}

// ...

    //      Read response interface
    always_comb
    begin : mem_resp_read_demux_comb
        mem_resp_read_uc_valid = 1'b0;
        mem_resp_read_miss_valid = 1'b0;
        mem_resp_read_ready_o = 1'b0;
        if (mem_resp_read_valid_i) begin
            if (mem_resp_read_i.mem_resp_r_id == {HPDcacheCfg.u.memIdWidth{1'b1}}
                && ~mem_resp_read_miss_inval) begin
                mem_resp_read_uc_valid = 1'b1;
                mem_resp_read_ready_o = mem_resp_read_uc_ready;
            end else begin
                mem_resp_read_miss_valid = 1'b1;
                mem_resp_read_ready_o = mem_resp_read_miss_ready;
            end
        end
    end

```

## Dependency declarations

### `rtl/src/hpdcache_mshr.sv`

```systemverilog
module hpdcache_mshr
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_word_t = logic,
    parameter type hpdcache_way_t = logic,

    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_sid_t = logic,

    parameter type mshr_way_t = logic,
    parameter type mshr_set_t = logic,

    parameter type cbuf_id_t = logic
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

    //  Check and allocation interface
    input  logic                  check_i,
    input  hpdcache_set_t         check_set_i,
    input  hpdcache_tag_t         check_tag_i,
    output logic                  hit_o,
    input  logic                  alloc_i,
    input  logic                  alloc_cs_i,
    input  hpdcache_nline_t       alloc_nline_i,
    input  hpdcache_req_tid_t     alloc_req_id_i,
    input  hpdcache_req_sid_t     alloc_src_id_i,
    input  hpdcache_word_t        alloc_word_i,
    input  hpdcache_way_t         alloc_victim_way_i,
    input  logic                  alloc_need_rsp_i,
    input  logic                  alloc_is_prefetch_i,
    input  logic                  alloc_wback_i,
    input  logic                  alloc_dirty_i,
    input  cbuf_id_t              alloc_cbuf_id_i,
    output logic                  alloc_full_o,
    output mshr_way_t             alloc_way_o,

    //  Acknowledge interface
    input  logic                  ack_i,
    input  logic                  ack_cs_i,
    input  mshr_set_t             ack_set_i,
    input  mshr_way_t             ack_way_i,
    output hpdcache_req_tid_t     ack_req_id_o,
    output hpdcache_req_sid_t     ack_src_id_o,
    output hpdcache_set_t         ack_cache_set_o,
    output hpdcache_way_t         ack_cache_way_o,
    output hpdcache_tag_t         ack_cache_tag_o,
    output hpdcache_word_t        ack_word_o,
    output logic                  ack_need_rsp_o,
    output logic                  ack_is_prefetch_o,
    output logic                  ack_wback_o,
    output logic                  ack_dirty_o,
    output cbuf_id_t              ack_cbuf_id_o
);
    //  }}}

    //  Definition of constants and types
    //  {{{
    typedef struct packed {
        hpdcache_tag_t     tag;
        hpdcache_req_tid_t req_id;
        hpdcache_req_sid_t src_id;
        hpdcache_word_t    word_idx;
        hpdcache_way_t     victim_way_idx;
        logic              wback;
        logic              dirty;
        logic              need_rsp;
        logic              is_prefetch;
        cbuf_id_t          cbuf_id;
    } mshr_entry_t;

```

### `rtl/src/common/hpdcache_data_resize.sv`

```systemverilog
module hpdcache_data_resize
//  {{{
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter int WR_WIDTH = 0,
    parameter int RD_WIDTH = 0,
    parameter int DEPTH    = 0,

    localparam type wdata_t = logic [WR_WIDTH-1:0],
    localparam type rdata_t = logic [RD_WIDTH-1:0]
)
//  }}}
//  Ports
//  {{{
(
    input  logic   clk_i,
    input  logic   rst_ni,

    input  logic   w_i,
    output logic   wok_o,
    input  wdata_t wdata_i,
    input  logic   wlast_i,

    input  logic   r_i,
    output logic   rok_o,
    output rdata_t rdata_o,
    output logic   rlast_o
);

```

### `rtl/src/common/hpdcache_fifo_reg.sv`

```systemverilog
module hpdcache_fifo_reg
    //  Parameters
    //  {{{
#(
    parameter int unsigned FIFO_DEPTH = 0,
    parameter bit FEEDTHROUGH = 1'b0,
    parameter type fifo_data_t = logic
)
    //  }}}
    //  Ports
    //  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  logic                  w_i,
    output logic                  wok_o,
    input  fifo_data_t            wdata_i,
    input  logic                  r_i,
    output logic                  rok_o,
    output fifo_data_t            rdata_o
);

```

### `rtl/src/common/hpdcache_1hot_to_binary.sv`

```systemverilog
module hpdcache_1hot_to_binary
    //  Parameters
    //  {{{
#(
    parameter  int unsigned N     = 0,
    localparam int unsigned Log2N = N > 1 ? $clog2(N) : 1,
    localparam type in_t  = logic unsigned [N-1:0],
    localparam type out_t = logic unsigned [Log2N-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    input  in_t    val_i,
    output out_t   val_o
);

```

### `rtl/src/common/hpdcache_decoder.sv`

```systemverilog
module hpdcache_decoder
    //  Parameters
    //  {{{
#(
    parameter  int unsigned N     = 0,
    localparam int unsigned Pow2N = 2**N,
    localparam type in_t  = logic unsigned [N-1:0],
    localparam type out_t = logic unsigned [Pow2N-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    input  logic   en_i,
    input  in_t    val_i,
    output out_t   val_o
);

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

```

## Related source code

### `core/cache_subsystem/cva6_hpdcache_subsystem.sv`

```systemverilog
  localparam int ICACHE_RDTXID = 1 << (CVA6Cfg.MEM_TID_WIDTH - 1);

// ...

        .icache_miss_ready_o(icache_miss_ready),
        .icache_miss_i      (icache_miss),
        .icache_miss_id_i   (hpdcache_mem_id_t'(ICACHE_RDTXID)),

```

### `core/cache_subsystem/cva6_hpdcache_subsystem_axi_arbiter.sv`

```systemverilog
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

```

## Documentation

### `docs/source/architecture.rst`

```text
Miss Handler
------------

This block is in charge of processing read miss requests to the memory. It has
three parts:

#. One in charge of forwarding read miss requests to the memory

#. One in charge of tracking the status of in-flight read misses

#. One in charge of selecting a victim cacheline and updating the cache with
   the response data from the memory

Multiple-entry MSHR
'''''''''''''''''''

The miss handler contains an essential component of the HPDcache: the
set-associative multi-entry MSHR. This components is the one responsible of
tracking the status of in-flight read miss requests to the memory. Each entry
of contains the status for each in-flight read miss request. Therefore, the
number of entries in the MSHR defines the maximum number of in-flight read miss
requests.

The number of entries in the MSHR depends on two configuration values:
:math:`\mathsf{CONF\_HPDCACHE\_MSHR\_WAYS}`
and
:math:`\mathsf{CONF\_HPDCACHE\_MSHR\_SETS}`.
The number of entries is computed as follows:

.. math:: \mathsf{CONF\_HPDCACHE\_MSHR\_SETS~\times~CONF\_HPDCACHE\_MSHR\_WAYS}

The MSHR accepts the following configurations:

.. list-table:: MSHR Configurations
   :widths: 20 20 60
   :header-rows: 1

   * - MSHR Ways
     - MSHR Sets
     - Configuration
   * - :math:`\mathsf{= 1}`
     - :math:`\mathsf{= 1}`
     - Single-Entry
   * - :math:`\mathsf{> 1}`
     - :math:`\mathsf{= 1}`
     - Fully-Associative Array
   * - :math:`\mathsf{= 1}`
     - :math:`\mathsf{> 1}`
     - Direct Access Array
   * - :math:`\mathsf{> 1}`
     - :math:`\mathsf{> 1}`
     - Set-Associative Access Array

...

An entry in the MSHR contains the following information:

.. list-table::
   :widths: 5 15 80
   :header-rows: 1

   * - Field
     - Description
     - Width (in bits)
   * - T
     - MSHR Tag
     - :math:`\mathsf{HPDCACHE\_NLINE\_WIDTH - log_2(CONF\_HPDCACHE\_MSHR\_SETS)}`
   * - R
     - Request ID
     - :math:`\mathsf{CONF\_HPDCACHE\_REQ\_TRANS\_ID\_WIDTH}`
   * - S
     - Source ID
     - :math:`\mathsf{CONF\_HPDCACHE\_REQ\_SRC\_ID\_WIDTH}`
   * - W
     - Word Index
     - :math:`\mathsf{log_2(CONF\_HPDCACHE\_CL\_WORDS})`
   * - N
     - Need Response
     - 1

MSHR Implementation
'''''''''''''''''''

In order to limit the area cost, the MSHR can be implemented using SRAM
macros. SRAM macros have higher bit density than flip-flops.

The depth of the macros is:

   :math:`\mathsf{CONF\_HPDCACHE\_MSHR\_SETS\_PER\_RAM}`

Multiple ways, for the same set, can be put side-by-side in the same SRAM word:

   :math:`\mathsf{CONF\_HPDCACHE\_MSHR\_WAYS\_PER\_RAM\_WORD}`

The width (in bits) of the macros is:

   :math:`\mathsf{CONF\_HPDCACHE\_MSHR\_WAYS\_PER\_RAM\_WORD{}\times{}(T + R + S + W + 1)}`

Finally, the total number of SRAM macros is:

.. math::

   \mathsf{W}         &= \mathsf{CONF\_HPDCACHE\_MSHR\_WAYS}\\
   \mathsf{WR}        &= \mathsf{CONF\_HPDCACHE\_MSHR\_WAYS\_PER\_RAM\_WORD}\\
   \mathsf{S}         &= \mathsf{CONF\_HPDCACHE\_MSHR\_SETS}\\
   \mathsf{SR}        &= \mathsf{CONF\_HPDCACHE\_MSHR\_SETS\_PER\_RAM}\\
   \text{SRAM macros} &= \mathsf{\lceil\frac{W}{WR}\rceil{}\times{}\lceil\frac{S}{SR}\rceil}

SRAM macros shall be selected depending on the required number of entries, and
the target technology node.

When the number of entries is low
(e.g. :math:`\mathsf{MSHR\_SETS \times MSHR\_WAYS \le 16}`),
it is generally better to implement the MSHR using flip-flops. In such
configurations, the designer may use a fully-associative configuration to
remove associativity conflicts.


MSHR Associativity Conflicts
''''''''''''''''''''''''''''
The MSHR implements a set-associative organization. In such organization, the
target "set" is designated by some bits of the cacheline address.

If there are multiple in-flight read miss requests addressing different
cachelines with the same "set", this is named an associativity conflict. When
this happens, the cache will place each read miss request in a different "way"
of the MSHR. However, if there is no available way, the request is put on hold
(case 5 in :numref:`Table %s <tab_onhold>`).

```

### `docs/source/interface.rst`

```text
.. _tab_resp_channel_signals:

.. list-table:: CRI Response Channel Signals
   :widths: 31 13 52
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``core_rsp_valid_o``
     - Cache
     - Indicates that the HPDcache has a valid response for the corresponding
       requester
   * - ``core_rsp_o.rdata``
     - Cache
     - Response read data
   * - ``core_rsp_o.sid``
     - Cache
     - The identification tag for the requester. It corresponds to the **sid**
       transferred with the request
   * - ``core_rsp_o.tid``
     - Cache
     - The identification tag for the request. It corresponds to the **tid**
       transferred with the request
   * - ``core_rsp_o.error``
     - Cache
     - Indicates whether there was an error condition while processing the
       request
   * - ``core_rsp_o.aborted``
     - Cache
     - Indicates if the request issued in the previous cycle shall be aborted.
       It is only considered if the previous request used virtual indexing

Cache Memory Interfaces
----------------------------------

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

```
