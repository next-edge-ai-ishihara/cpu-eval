# Implement `hpdcache_ctrl`

Implement the complete `hpdcache_ctrl` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_ctrl` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### `core/include/cv32a60x_config_pkg.sv`

```systemverilog
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

    cfg.DcacheEccEnable = CVA6Cfg.DcacheEccEnable;
    cfg.DcacheEccScrubberEnable = CVA6Cfg.DcacheEccScrubberEnable;

    cfg.DATA_USER_EN = CVA6Cfg.DataUserEn;
    cfg.WtDcacheWbufDepth = CVA6Cfg.WtDcacheWbufDepth;

```

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

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
    //  Definition of interface with requesters
    //  {{{
    typedef logic [2:0] hpdcache_req_size_t;

    //      Definition of operation codes
    //      {{{
    typedef enum logic [4:0] {
        HPDCACHE_REQ_LOAD                  = 5'h00,
        HPDCACHE_REQ_STORE                 = 5'h01,
        // RESERVED                        = 5'h02,
        // RESERVED                        = 5'h03,
        HPDCACHE_REQ_AMO_LR                = 5'h04,
        HPDCACHE_REQ_AMO_SC                = 5'h05,
        HPDCACHE_REQ_AMO_SWAP              = 5'h06,
        HPDCACHE_REQ_AMO_ADD               = 5'h07,
        HPDCACHE_REQ_AMO_AND               = 5'h08,
        HPDCACHE_REQ_AMO_OR                = 5'h09,
        HPDCACHE_REQ_AMO_XOR               = 5'h0a,
        HPDCACHE_REQ_AMO_MAX               = 5'h0b,
        HPDCACHE_REQ_AMO_MAXU              = 5'h0c,
        HPDCACHE_REQ_AMO_MIN               = 5'h0d,
        HPDCACHE_REQ_AMO_MINU              = 5'h0e,
        // RESERVED                        = 5'h0f,
        HPDCACHE_REQ_CMO_FENCE             = 5'h10,
        HPDCACHE_REQ_CMO_PREFETCH          = 5'h11,
        HPDCACHE_REQ_CMO_INVAL_NLINE       = 5'h12,
        HPDCACHE_REQ_CMO_INVAL_ALL         = 5'h13,
        HPDCACHE_REQ_CMO_FLUSH_NLINE       = 5'h14,
        HPDCACHE_REQ_CMO_FLUSH_ALL         = 5'h15,
        HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE = 5'h16,
        HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL   = 5'h17
    } hpdcache_req_op_t;
    //      }}}

    //      Definition of Write Policy Hint
    //      {{{
    typedef enum logic[2:0] {
        HPDCACHE_WR_POLICY_AUTO = 3'b001,
        HPDCACHE_WR_POLICY_WB   = 3'b010,
        HPDCACHE_WR_POLICY_WT   = 3'b100
    } hpdcache_wr_policy_hint_t;
    //      }}}

    //      Definition of PMA flags
    //      {{{
    typedef struct packed
    {
        logic uncacheable;
        logic io; //  FIXME: for future use

        //  Write Policy Hint
        hpdcache_wr_policy_hint_t wr_policy_hint;
    } hpdcache_pma_t;
    //      }}}

    //      Definition of functions
    //      {{{
    function automatic int unsigned hpdcache_max(int unsigned x, int unsigned y);
        return (x < y) ? y : x;
    endfunction

    function automatic int unsigned hpdcache_min(int unsigned x, int unsigned y);
        return (x < y) ? x : y;
    endfunction

    function automatic logic is_load(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_LOAD: return 1'b1;
            default:           return 1'b0;
        endcase
    endfunction

    function automatic logic is_store(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_STORE: return 1'b1;
            default:            return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_LR,
            HPDCACHE_REQ_AMO_SC,
            HPDCACHE_REQ_AMO_SWAP,
            HPDCACHE_REQ_AMO_ADD,
            HPDCACHE_REQ_AMO_AND,
            HPDCACHE_REQ_AMO_OR,
            HPDCACHE_REQ_AMO_XOR,
            HPDCACHE_REQ_AMO_MAX,
            HPDCACHE_REQ_AMO_MAXU,
            HPDCACHE_REQ_AMO_MIN,
            HPDCACHE_REQ_AMO_MINU:
                return 1'b1;
            default:
                return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_lr(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_LR: return 1'b1;
            default:             return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_sc(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_SC: return 1'b1;
            default:             return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_swap(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_SWAP: return 1'b1;
            default:               return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_add(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_ADD: return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_and(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_AND: return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_or(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_OR:  return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_xor(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_XOR: return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_max(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_MAX: return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_maxu(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_MAXU: return 1'b1;
            default:               return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_min(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_MIN: return 1'b1;
            default:              return 1'b0;
        endcase
    endfunction

    function automatic logic is_amo_minu(input hpdcache_req_op_t op);
        case (op)
            HPDCACHE_REQ_AMO_MINU: return 1'b1;
            default:               return 1'b0;
        endcase
    endfunction

    function automatic logic is_cmo_inval(input hpdcache_req_op_t op);
        return (op inside {HPDCACHE_REQ_CMO_INVAL_NLINE, HPDCACHE_REQ_CMO_INVAL_ALL});
    endfunction

    function automatic logic is_cmo_flush(input hpdcache_req_op_t op);
        return (op inside {HPDCACHE_REQ_CMO_FLUSH_NLINE,
                           HPDCACHE_REQ_CMO_FLUSH_ALL,
                           HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE,
                           HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL});
    endfunction

    function automatic logic is_cmo_fence(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_FENCE);
    endfunction

    function automatic logic is_cmo_prefetch(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_PREFETCH);
    endfunction

    function automatic logic is_cmo_inval_by_nline(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_INVAL_NLINE);
    endfunction

    function automatic logic is_cmo_inval_all(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_INVAL_ALL);
    endfunction

    function automatic logic is_cmo_flush_by_nline(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_FLUSH_NLINE);
    endfunction

    function automatic logic is_cmo_flush_all(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_FLUSH_ALL);
    endfunction

    function automatic logic is_cmo_flush_inval_by_nline(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE);
    endfunction

    function automatic logic is_cmo_flush_inval_all(input hpdcache_req_op_t op);
        return (op == HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL);
    endfunction

    function automatic logic is_cmo(input hpdcache_req_op_t op);
        return (is_cmo_flush(op) ||
                is_cmo_fence(op) ||
                is_cmo_inval(op) ||
                is_cmo_prefetch(op));
    endfunction
// ...
    //  Definition of constants and types for the uncacheable request handler (UC)
    //  {{{
    typedef struct packed {
        logic is_ld;
        logic is_st;
        logic is_amo_lr;
        logic is_amo_sc;
        logic is_amo_swap;
        logic is_amo_add;
        logic is_amo_and;
        logic is_amo_or;
        logic is_amo_xor;
        logic is_amo_max;
        logic is_amo_maxu;
        logic is_amo_min;
        logic is_amo_minu;
    } hpdcache_uc_op_t;
    //  }}}

    //  Definition of constants and types for the CMO request handler (CMOH)
    //  {{{
    typedef struct packed {
        logic is_flush_inval_all;
        logic is_flush_all;
        logic is_inval_all;
    } hpdcache_cmoh_op_t;
    //  }}}

    //  Definition Replay Table (RTAB) dependencies
    //  {{{
    typedef struct packed {
        logic mshr_hit;
        logic mshr_full;
        logic mshr_ready;
        logic write_miss;
        logic wbuf_hit;
        logic wbuf_not_ready;
        logic dir_unavailable;
        logic dir_fetch;
        logic flush_hit;
        logic flush_not_ready;
        logic pend_trans;
    } hpdcache_rtab_deps_t;
    //  }}}

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

## Parent instantiation

### `rtl/src/hpdcache.sv`

```systemverilog
    //  Declaration of internal types
    //  {{{
    typedef logic [HPDcacheCfg.u.paWidth-1:0] hpdcache_req_addr_t;
    typedef logic [HPDcacheCfg.setWidth-1:0] hpdcache_set_t;
    typedef logic [HPDcacheCfg.clOffsetWidth-1:0] hpdcache_offset_t;
    typedef logic unsigned [HPDcacheCfg.clWordIdxWidth-1:0] hpdcache_word_t;
    typedef logic unsigned [HPDcacheCfg.u.ways-1:0] hpdcache_way_vector_t;
    typedef logic unsigned [HPDcacheCfg.wayIndexWidth-1:0] hpdcache_way_t;

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

    typedef hpdcache_data_word_t [HPDcacheCfg.u.accessWords-1:0] hpdcache_access_data_t;
    typedef hpdcache_data_be_t [HPDcacheCfg.u.accessWords-1:0] hpdcache_access_be_t;

    typedef hpdcache_req_addr_t wbuf_addr_t;
    typedef hpdcache_req_data_t wbuf_data_t;
    typedef hpdcache_req_be_t wbuf_be_t;
    //  }}}
// ...
    hpdcache_ctrl #(
        .HPDcacheCfg                        (HPDcacheCfg),
        .hpdcache_nline_t                   (hpdcache_nline_t),
        .hpdcache_tag_t                     (hpdcache_tag_t),
        .hpdcache_set_t                     (hpdcache_set_t),
        .hpdcache_word_t                    (hpdcache_word_t),
        .hpdcache_data_word_t               (hpdcache_data_word_t),
        .hpdcache_data_be_t                 (hpdcache_data_be_t),
        .hpdcache_dir_entry_t               (hpdcache_dir_entry_t),
        .hpdcache_way_vector_t              (hpdcache_way_vector_t),
        .hpdcache_way_t                     (hpdcache_way_t),
        .wbuf_addr_t                        (wbuf_addr_t),
        .wbuf_data_t                        (wbuf_data_t),
        .wbuf_be_t                          (wbuf_be_t),
        .hpdcache_access_data_t             (hpdcache_access_data_t),
        .hpdcache_access_be_t               (hpdcache_access_be_t),
        .hpdcache_req_addr_t                (hpdcache_req_addr_t),
        .hpdcache_req_offset_t              (hpdcache_req_offset_t),
        .hpdcache_req_tid_t                 (hpdcache_req_tid_t),
        .hpdcache_req_sid_t                 (hpdcache_req_sid_t),
        .hpdcache_req_data_t                (hpdcache_req_data_t),
        .hpdcache_req_be_t                  (hpdcache_req_be_t),
        .hpdcache_req_t                     (hpdcache_req_t),
        .hpdcache_rsp_t                     (hpdcache_rsp_t)
    ) hpdcache_ctrl_i(
        .clk_i,
        .rst_ni,

        .core_req_valid_i                   (arb_req_valid),
        .core_req_ready_o                   (arb_req_ready),
        .core_req_i                         (arb_req),
        .core_req_abort_i                   (arb_abort),
        .core_req_tag_i                     (arb_tag),
        .core_req_pma_i                     (arb_pma),

        .core_rsp_valid_o                   (core_rsp_valid),
        .core_rsp_o                         (core_rsp),

        .wbuf_flush_i,

        .st0_mshr_check_o                   (miss_mshr_check),
        .st0_mshr_check_offset_o            (miss_mshr_check_offset),
        .st1_mshr_check_nline_o             (miss_mshr_check_nline),
        .st1_mshr_hit_i                     (miss_mshr_hit),
        .st1_mshr_alloc_ready_i             (miss_mshr_alloc_ready),
        .st1_mshr_alloc_full_i              (miss_mshr_alloc_full),
        .st1_mshr_alloc_cbuf_full_i         (miss_mshr_alloc_cbuf_full),
        .st2_mshr_alloc_o                   (miss_mshr_alloc),
        .st2_mshr_alloc_cs_o                (miss_mshr_alloc_cs),
        .st2_mshr_alloc_nline_o             (miss_mshr_alloc_nline),
        .st2_mshr_alloc_tid_o               (miss_mshr_alloc_tid),
        .st2_mshr_alloc_sid_o               (miss_mshr_alloc_sid),
        .st2_mshr_alloc_word_o              (miss_mshr_alloc_word),
        .st2_mshr_alloc_wdata_o             (miss_mshr_alloc_wdata),
        .st2_mshr_alloc_be_o                (miss_mshr_alloc_be),
        .st2_mshr_alloc_victim_way_o        (miss_mshr_alloc_victim_way),
        .st2_mshr_alloc_need_rsp_o          (miss_mshr_alloc_need_rsp),
        .st2_mshr_alloc_is_prefetch_o       (miss_mshr_alloc_is_prefetch),
        .st2_mshr_alloc_wback_o             (miss_mshr_alloc_wback),
        .st2_mshr_alloc_dirty_o             (miss_mshr_alloc_dirty),

        .refill_req_valid_i                 (refill_req_valid),
        .refill_req_ready_o                 (refill_req_ready),
        .refill_is_error_i                  (refill_is_error),
        .refill_busy_i                      (refill_busy),
        .refill_updt_sel_victim_i           (refill_updt_sel_victim),
        .refill_set_i                       (refill_set),
        .refill_way_i                       (refill_way),
        .refill_dir_entry_i                 (refill_dir_entry),
        .refill_write_dir_i                 (refill_write_dir),
        .refill_write_data_i                (refill_write_data),
        .refill_word_i                      (refill_word),
        .refill_data_i                      (refill_data),
        .refill_core_rsp_valid_i            (refill_core_rsp_valid),
        .refill_core_rsp_i                  (refill_core_rsp),
        .refill_nline_i                     (refill_nline),
        .refill_updt_rtab_i                 (refill_updt_rtab),

        .flush_busy_i                       (flush_busy),
        .flush_check_nline_o                (flush_check_nline),
        .flush_check_hit_i                  (flush_check_hit),
        .flush_alloc_o                      (ctrl_flush_alloc),
        .flush_alloc_ready_i                (flush_alloc_ready),
        .flush_alloc_nline_o                (ctrl_flush_alloc_nline),
        .flush_alloc_way_o                  (ctrl_flush_alloc_way),
        .flush_data_read_i                  (flush_data_read),
        .flush_data_read_set_i              (flush_data_read_set),
        .flush_data_read_word_i             (flush_data_read_word),
        .flush_data_read_way_i              (flush_data_read_way),
        .flush_data_read_data_o             (flush_data_read_data),
        .flush_ack_i                        (flush_ack),
        .flush_ack_nline_i                  (flush_ack_nline),

        .inval_check_dir_i                  (inval_check_dir),
        .inval_write_dir_i                  (inval_write_dir),
        .inval_nline_i                      (inval_nline),
        .inval_hit_o                        (inval_hit),

        .wbuf_empty_i                       (wbuf_empty_o),
        .wbuf_flush_all_o                   (wbuf_flush_all),
        .wbuf_write_o                       (wbuf_write),
        .wbuf_write_ready_i                 (wbuf_write_ready),
        .wbuf_write_addr_o                  (wbuf_write_addr),
        .wbuf_write_data_o                  (wbuf_write_data),
        .wbuf_write_be_o                    (wbuf_write_be),
        .wbuf_write_uncacheable_o           (wbuf_write_uncacheable),
        .wbuf_read_hit_i                    (wbuf_read_hit),
        .wbuf_read_flush_hit_o              (wbuf_read_flush_hit),
        .wbuf_rtab_addr_o                   (wbuf_rtab_addr),
        .wbuf_rtab_is_read_o                (wbuf_rtab_is_read),
        .wbuf_rtab_hit_open_i               (wbuf_rtab_hit_open),
        .wbuf_rtab_hit_pend_i               (wbuf_rtab_hit_pend),
        .wbuf_rtab_hit_sent_i               (wbuf_rtab_hit_sent),
        .wbuf_rtab_not_ready_i              (wbuf_rtab_not_ready),

        .uc_busy_i                          (~uc_ready),
        .uc_lrsc_snoop_o                    (uc_lrsc_snoop),
        .uc_lrsc_snoop_addr_o               (uc_lrsc_snoop_addr),
        .uc_lrsc_snoop_size_o               (uc_lrsc_snoop_size),
        .uc_req_valid_o                     (uc_req_valid),
        .uc_req_op_o                        (uc_req_op),
        .uc_req_addr_o                      (uc_req_addr),
        .uc_req_size_o                      (uc_req_size),
        .uc_req_data_o                      (uc_req_data),
        .uc_req_be_o                        (uc_req_be),
        .uc_req_uc_o                        (uc_req_uncacheable),
        .uc_req_sid_o                       (uc_req_sid),
        .uc_req_tid_o                       (uc_req_tid),
        .uc_req_need_rsp_o                  (uc_req_need_rsp),
        .uc_req_dir_hit_way_o               (uc_req_dir_hit_way),
        .uc_req_old_data_o                  (uc_req_old_data),
        .uc_data_amo_write_i                (uc_data_amo_write),
        .uc_data_amo_write_enable_i         (uc_data_amo_write_enable),
        .uc_data_amo_write_set_i            (uc_data_amo_write_set),
        .uc_data_amo_write_size_i           (uc_data_amo_write_size),
        .uc_data_amo_write_word_i           (uc_data_amo_write_word),
        .uc_data_amo_write_way_i            (uc_data_amo_write_way),
        .uc_data_amo_write_data_i           (uc_data_amo_write_data),
        .uc_data_amo_write_be_i             (uc_data_amo_write_be),
        .uc_core_rsp_ready_o                (uc_core_rsp_ready),
        .uc_core_rsp_valid_i                (uc_core_rsp_valid),
        .uc_core_rsp_i                      (uc_core_rsp),

        .cmo_busy_i                         (~cmo_ready),
        .cmo_req_valid_o                    (cmo_req_valid),
        .cmo_req_op_o                       (cmo_req_op),
        .cmo_req_addr_o                     (cmo_req_addr),
        .cmo_req_sid_o                      (cmo_req_sid),
        .cmo_req_tid_o                      (cmo_req_tid),
        .cmo_req_need_rsp_o                 (cmo_req_need_rsp),
        .cmo_dirty_set_en_o                 (cmo_dirty_set_en),
        .cmo_dirty_min_set_o                (cmo_dirty_min_set),
        .cmo_dirty_max_set_o                (cmo_dirty_max_set),
        .cmo_valid_set_en_o                 (cmo_valid_set_en),
        .cmo_valid_min_set_o                (cmo_valid_min_set),
        .cmo_valid_max_set_o                (cmo_valid_max_set),
        .cmo_flush_all_i                    (cmo_flush_all),
        .cmo_inval_all_i                    (cmo_inval_all),
        .cmo_dir_check_entry_i              (cmo_dir_check_entry),
        .cmo_dir_check_entry_set_i          (cmo_dir_check_entry_set),
        .cmo_dir_check_entry_way_i          (cmo_dir_check_entry_way),
        .cmo_dir_check_entry_valid_o        (cmo_dir_check_entry_valid),
        .cmo_dir_check_entry_wback_o        (cmo_dir_check_entry_wback),
        .cmo_dir_check_entry_dirty_o        (cmo_dir_check_entry_dirty),
        .cmo_dir_check_entry_tag_o          (cmo_dir_check_entry_tag),
        .cmo_dir_updt_i                     (cmo_dir_updt),
        .cmo_dir_updt_set_i                 (cmo_dir_updt_set),
        .cmo_dir_updt_way_i                 (cmo_dir_updt_way),
        .cmo_dir_updt_valid_i               (cmo_dir_updt_valid),
        .cmo_dir_updt_wback_i               (cmo_dir_updt_wback),
        .cmo_dir_updt_dirty_i               (cmo_dir_updt_dirty),
        .cmo_dir_updt_fetch_i               (cmo_dir_updt_fetch),
        .cmo_dir_updt_tag_i                 (cmo_dir_updt_tag),
        .cmo_core_rsp_ready_o               (cmo_core_rsp_ready),
        .cmo_core_rsp_valid_i               (cmo_core_rsp_valid),
        .cmo_core_rsp_i                     (cmo_core_rsp),

        .mshr_empty_i                       (miss_mshr_empty),
        .flush_empty_i                      (flush_empty),

        .rtab_empty_o                       (rtab_empty),
        .ctrl_empty_o                       (ctrl_empty),

        .cfg_enable_i,
        .cfg_prefetch_updt_plru_i,
        .cfg_rtab_single_entry_i,
        .cfg_default_wb_i                   (cfg_default_wb),
        .cfg_scrub_enable_i,
        .cfg_scrub_period_i,
        .cfg_scrub_restart_i,

        .evt_cache_write_miss_o,
        .evt_cache_read_miss_o,
        .evt_cache_dir_unc_err_o,
        .evt_cache_dir_cor_err_o,
        .evt_cache_dat_unc_err_o,
        .evt_cache_dat_cor_err_o,
        .evt_scrub_complete_o,
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

## Dependency declarations

### `rtl/include/hpdcache_typedef.svh`

```systemverilog
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

```

### `rtl/src/hpdcache_ctrl_pe.sv`

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

### `rtl/src/hpdcache_memctrl.sv`

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

### `rtl/src/hpdcache_rtab.sv`

```systemverilog
module hpdcache_rtab
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_way_t = logic,

    parameter type hpdcache_req_addr_t = logic,

    parameter type rtab_ptr_t = logic,
    parameter type rtab_cnt_t = logic,
    parameter type rtab_entry_t = logic
)
//  }}}

//  Ports
//  {{{
(
    //  Clock and reset signals
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //  Global control signals
    output logic                  empty_o,  // RTAB is empty
    output logic                  full_o,   // RTAB is full
    output logic                  fence_o,  // There is a pending instruction with fence in the RTAB

    //  Check RTAB signals
    //     This interface allows to check if there is an address-overlapping
    //     request in the RTAB with respect to the given nline.
    input  logic                  check_i,          // Check for hit (nline) in the RTAB
    input  hpdcache_nline_t       check_nline_i,
    output logic                  check_hit_o,

    //  Allocate signals
    //     This interface allows to allocate a new request in a new linked list
    input  logic                  alloc_i,
    input  logic                  alloc_and_link_i,
    input  rtab_entry_t           alloc_req_i,
    input  hpdcache_rtab_deps_t   alloc_deps_i,

    //  Pop signals
    //     This interface allows to read (and remove) a request from the RTAB
    output logic                  pop_try_valid_o,  // Request ready to be replayed
    input  logic                  pop_try_i,
    output rtab_entry_t           pop_try_req_o,
    output rtab_ptr_t             pop_try_ptr_o,

    //  Pop Commit signals
    //     This interface allows to actually remove a popped request
    input  logic                  pop_commit_i,
    input  rtab_ptr_t             pop_commit_ptr_i,

    //  Pop Rollback signals
    //     This interface allows to put back a popped request
    input  logic                  pop_rback_i,
    input  rtab_ptr_t             pop_rback_ptr_i,

    //  Control signals from/to WBUF
    output hpdcache_req_addr_t    wbuf_addr_o,      // address to check against ongoing writes
    output logic                  wbuf_is_read_o,   // monitored request is read
    input  logic                  wbuf_hit_open_i,  // Hit on open entry in the write buf
    input  logic                  wbuf_hit_pend_i,  // Hit on pend entry in the write buf
    input  logic                  wbuf_hit_sent_i,  // Hit on sent entry in the write buf
    input  logic                  wbuf_not_ready_i, // Write buffer cannot accept the write

    //  Control signals from the Miss Handler
    input  logic                  miss_ready_i,     // Miss Handler is ready

    //  Control signals from the Refill Handler
    input  logic                  refill_i,           // Active refill
    input  logic                  refill_is_error_i,  // Active refill has error bit set
    input  hpdcache_nline_t       refill_nline_i,     // Cache-line index being refilled
    input  hpdcache_way_t         refill_way_index_i, // Way index being refilled

    //  Control signals from the Flush Controller
    input  logic                  flush_ack_i,        // Flush acknowledged
    input  hpdcache_nline_t       flush_ack_nline_i,  // Cache-line flush being acknowledged
    input  logic                  flush_ready_i,      // Flush controller is available

    //  Configuration parameters
    input  logic                  cfg_single_entry_i, // Enable only one entry of the table

    //  Global control signals
    input  logic                  no_pend_trans_i
);
// ...
        assign addr[gen_i] = {req_q[gen_i].req.req.addr_tag, req_q[gen_i].req.req.addr_offset};
        assign nline[gen_i] = addr[gen_i][HPDcacheCfg.clOffsetWidth +: HPDcacheCfg.nlineWidth];
        assign match_check_nline[gen_i] = (check_nline_i == nline[gen_i]);
        assign is_read_bv[gen_i] = is_load(req_q[gen_i].req.req.op) |
                                   is_cmo_prefetch(req_q[gen_i].req.req.op);
// ...
        assign match_refill_way[gen_i] = (refill_way_index_i == req_q[gen_i].way_fetch);
// ...
    //  Forward the error bit
    always_comb
    begin : pop_try_req_comb
        pop_try_req_o              = pop_try_req;
        pop_try_req_o.req.is_error = |(pop_sel & error_q);
    end

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

```

### `docs/source/interface.rst`

```text
This section describes the Cache-Requesters Interface (CRI) between requesters
and the HPDcache. It contains two channels: one for requests and one for
responses. There are as many CRIs as requesters from the core/accelerator to
the HPDcache.

This interface is synchronous to the rising edge of the global
clock ``clk_i``.

The address (``core_req_i.addr_offset``), size (``core_req_i.size``),
byte-enable (``core_req_i.be``), write data (``core_req_i.wdata``) and
read data (``core_rsp_o.rdata``) signals shall comply with the alignment
constraints defined in section
:ref:`Address, data, and byte enable alignment <sec_req_alignment>`.

CRI Signal Description
~~~~~~~~~~~~~~~~~~~~~~

.. _tab_req_channel_signals:

.. list-table:: CRI Request Channel Signals
   :widths: 31 13 52
   :align: center
   :header-rows: 1

   * - Signal
     - Source
     - Description
   * - ``core_req_valid_i``
     - Requester
     - Indicates that the corresponding requester has a valid request
   * - ``core_req_ready_o``
     - Cache
     - Indicates that the cache is ready to accept a request from the
       corresponding requester
   * - ``core_req_i.addr_offset``
     - Requester
     - Least significant bits of the target address of the request
   * - ``core_req_i.wdata``
     - Requester
     - Write data (little-endian)
   * - ``core_req_i.op``
     - Requester
     - Indicates the type of operation to be performed
   * - ``core_req_i.be``
     - Requester
     - Byte-enable for write data (little-endian)
   * - ``core_req_i.size``
     - Requester
     - Indicate the size of the access. The size is encoded as the power-of-two
       of the number of bytes (e.g.
       0 is :math:`\scriptsize\mathsf{2^0~=~1}`,
       5 is :math:`\scriptsize\mathsf{2^5~=~32}`)
   * - ``core_req_i.sid``
     - Requester
     - The identification tag for the requester. It shall be identical to the
       index of the request port bound to that requester
   * - ``core_req_i.tid``
     - Requester
     - The identification tag for the request. A requester can issue multiple
       requests. The corresponding response from the cache will return this tid
   * - ``core_req_i.need_rsp``
     - Requester
     - Indicates if the request needs a response from the cache. When unset,
       the cache will not issue a response for the corresponding request
   * - ``core_req_i.phys_indexed``
     - Requester
     - Indicates whether the access uses virtual (unset) or physical indexing
       (set)
   * - ``core_req_i.addr_tag``
     - Requester
     - Most significant bits of the target address of the request. It is only
       valid when using physical indexing (``core_req_i.phys_indexed = 1``)
   * - ``core_req_i.pma.uncacheable``
     - Requester
     - Indicates whether the access needs to be cached (unset) or not (set).
       Uncacheable accesses are directly forwarded to the memory. It is only
       valid when using physical indexing (``core_req_i.phys_indexed = 1``)
   * - ``core_req_i.pma.io``
     - Requester
     - Indicates whether the request targets input/output (IO) peripherals
       (set) or not (unset). IO accesses are directly forwarded to the memory.
       It is only valid when using physical indexing
       (``core_req_i.phys_indexed = 1``)
   * - ``core_req_i.pma.wr_policy_hint``
     - Requester
     - Indicates whether the target cacheline shall be managed as write-back
       (write allocate) or write-through (write non-allocate).
       It is only valid when using physical indexing
       (``core_req_i.phys_indexed = 1``)
   * - ``core_req_tag_i``
     - Requester
     - Most significant bits of the target address of the request. This signal
       must be delayed of 1 cycle after
       ``(core_req_valid_i & core_req_ready_o) = 1``.
       It is valid when using virtual indexing
       (``core_req_i.phys_indexed = 0``)
   * - ``core_req_pma_i.uncacheable``
     - Requester
     - Indicates whether the access needs to be cached (unset) or not (set).
       Uncacheable accesses are directly forwarded to the memory. This signal
       must be delayed of 1 cycle after
       ``(core_req_valid_i & core_req_ready_o) = 1``.
       It is only valid when using virtual indexing
       (``core_req_i.phys_indexed = 0``)
   * - ``core_req_pma_i.io``
     - Requester
     - Indicates whether the access targets input/output (IO) peripherals (set)
       or not (unset). IO accesses are directly forwarded to the memory. This
       signal must be delayed of 1 cycle after
       ``(core_req_valid_i & core_req_ready_o) = 1``.
       It is only valid when using virtual indexing
       (``core_req_i.phys_indexed = 0``)
   * - ``core_req_pma_i.wr_policy_hint``
     - Requester
     - Indicates whether the target cacheline shall be managed as write-back
       (write allocate) or write-through (write non-allocate).
       It is only valid when using virtual indexing
       (``core_req_i.phys_indexed = 0``)

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

```
