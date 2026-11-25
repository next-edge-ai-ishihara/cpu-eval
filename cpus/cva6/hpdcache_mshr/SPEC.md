# Implement `hpdcache_mshr`

Implement the complete `hpdcache_mshr` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_mshr` definition in a single SystemVerilog code
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

```

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
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

```

## Parent instantiation

### `rtl/src/hpdcache_miss_handler.sv`

```systemverilog
            REFILL_IDLE: begin
                if (refill_fifo_resp_meta_rok) begin
                    //  anticipate the activation of the MSHR independently of the grant signal from
                    //  the refill arbiter. This is to avoid the introduction of unnecessary timing
                    //  paths (however there could be a minor augmentation of the power consumption)
                    mshr_ack_cs = ~refill_fifo_resp_meta_rdata.is_inval;

                    //  if the permission is granted, start refilling
                    if (refill_req_ready_i) begin
                        refill_set_o = mshr_ack_cache_set;

// ...

    assign mshr_check_tag = mshr_check_nline_i[HPDcacheCfg.setWidth +: HPDcacheCfg.tagWidth];
    assign mshr_check_set = mshr_check_offset_i[HPDcacheCfg.clOffsetWidth +: HPDcacheCfg.setWidth];

// ...

    //  Miss Status Holding Register component
    //  {{{
    hpdcache_mshr #(
        .HPDcacheCfg              (HPDcacheCfg),
        .hpdcache_nline_t         (hpdcache_nline_t),
        .hpdcache_tag_t           (hpdcache_tag_t),
        .hpdcache_set_t           (hpdcache_set_t),
        .hpdcache_word_t          (hpdcache_word_t),
        .hpdcache_way_t           (hpdcache_way_t),

        .hpdcache_req_tid_t       (hpdcache_req_tid_t),
        .hpdcache_req_sid_t       (hpdcache_req_sid_t),

        .mshr_way_t               (mshr_way_t),
        .mshr_set_t               (mshr_set_t),

        .cbuf_id_t                (cbuf_id_t)
    ) hpdcache_mshr_i(
        .clk_i,
        .rst_ni,

        .empty_o                  (mshr_empty),
        .full_o                   (mshr_full_o),

        .check_i                  (mshr_check_i),
        .check_set_i              (mshr_check_set),
        .check_tag_i              (mshr_check_tag),
        .hit_o                    (mshr_check_hit_o),
        .alloc_i                  (mshr_alloc),
        .alloc_cs_i               (mshr_alloc_cs),
        .alloc_nline_i            (mshr_alloc_nline_i),
        .alloc_req_id_i           (mshr_alloc_tid_i),
        .alloc_src_id_i           (mshr_alloc_sid_i),
        .alloc_word_i             (mshr_alloc_word_i),
        .alloc_victim_way_i       (mshr_alloc_victim_way),
        .alloc_need_rsp_i         (mshr_alloc_need_rsp_i),
        .alloc_is_prefetch_i      (mshr_alloc_is_prefetch_i),
        .alloc_wback_i            (mshr_alloc_wback_i),
        .alloc_dirty_i            (mshr_alloc_dirty_i),
        .alloc_cbuf_id_i          (mshr_alloc_cbuf_id),
        .alloc_full_o             (mshr_alloc_full_o),
        .alloc_way_o              (mshr_alloc_way_d),

        .ack_i                    (mshr_ack),
        .ack_cs_i                 (mshr_ack_cs),
        .ack_set_i                (mshr_ack_set),
        .ack_way_i                (mshr_ack_way),
        .ack_req_id_o             (mshr_ack_req_id),
        .ack_src_id_o             (mshr_ack_src_id),
        .ack_cache_set_o          (mshr_ack_cache_set),
        .ack_cache_way_o          (mshr_ack_cache_way),
        .ack_cache_tag_o          (mshr_ack_cache_tag),
        .ack_word_o               (mshr_ack_word),
        .ack_need_rsp_o           (mshr_ack_need_rsp),
        .ack_is_prefetch_o        (mshr_ack_is_prefetch),
        .ack_wback_o              (mshr_ack_wback),
        .ack_dirty_o              (mshr_ack_dirty),
        .ack_cbuf_id_o            (mshr_ack_cbuf_id)
    );

    hpdcache_1hot_to_binary #(.N(HPDcacheCfg.u.ways)) victim_way_encoder_i(
        .val_i(mshr_alloc_victim_way_i),
        .val_o(mshr_alloc_victim_way)
    );

    hpdcache_decoder #(.N(HPDcacheCfg.wayIndexWidth)) victim_way_decoder_i(
        .en_i (refill_busy_o),
        .val_i(refill_way),
        .val_o(refill_way_o)
    );

    //    Indicate to the cache controller that there is no pending miss. This
    //    is, when the MSHR is empty, and the MISS handler has finished of
    //    processing the last miss response.
    assign mshr_empty_o = mshr_empty & ~refill_busy_o;
    //  }}}

```

## Dependency declarations

### `rtl/src/common/hpdcache_regbank_wbyteenable_1rw.sv`

```systemverilog
module hpdcache_regbank_wbyteenable_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE
)
(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   cs,
    input  logic                   we,
    input  logic [ADDR_SIZE-1:0]   addr,
    input  logic [DATA_SIZE-1:0]   wdata,
    input  logic [DATA_SIZE/8-1:0] wbyteenable,
    output logic [DATA_SIZE-1:0]   rdata
);

    /*
     *  Internal memory array declaration
     */
    typedef logic [DATA_SIZE-1:0] mem_t [DEPTH];
    mem_t mem;

    /*
     *  Process to update or read the memory array
     */
    always_ff @(posedge clk or negedge rst_n)
    begin : mem_update_ff
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= '0;
            end
            rdata <= '0;
        end else begin
            if (cs == 1'b1) begin
                if (we == 1'b1) begin
                    for (int i = 0; i < DATA_SIZE/8; i++) begin
                        if (wbyteenable[i]) mem[addr][i*8 +: 8] <= wdata[i*8 +: 8];
                    end
                end
                rdata <= mem[addr];
            end
        end
    end : mem_update_ff
endmodule : hpdcache_regbank_wbyteenable_1rw

```

## Related source code

### `rtl/src/hpdcache_ctrl.sv`

```systemverilog
    output logic                  st0_mshr_check_o,
    output hpdcache_req_offset_t  st0_mshr_check_offset_o,
    output hpdcache_nline_t       st1_mshr_check_nline_o,
    input  logic                  st1_mshr_hit_i,

// ...

    assign st0_mshr_check_offset_o      = st0_req.req.addr_offset;
    assign st1_mshr_check_nline_o       = st1_req_nline;

```

### `rtl/src/hpdcache.sv`

```systemverilog
        .st0_mshr_check_o                   (miss_mshr_check),
        .st0_mshr_check_offset_o            (miss_mshr_check_offset),
        .st1_mshr_check_nline_o             (miss_mshr_check_nline),
        .st1_mshr_hit_i                     (miss_mshr_hit),

// ...

        .mshr_check_i                       (miss_mshr_check),
        .mshr_check_offset_i                (miss_mshr_check_offset),
        .mshr_check_nline_i                 (miss_mshr_check_nline),
        .mshr_check_hit_o                   (miss_mshr_hit),

```

## Documentation

### `docs/source/architecture.rst`

```text
A request on stage 0 can either be consumed on that cycle (forwarded to the
stage 1) or stalled. A request on stage 1 or stage 2 always progresses. In stage
1 the request is either acknowledged (load hit or write acknowledgement),
forwarded to stage 2 (load miss), or put into the RTAB. In stage 2, the request
quits the pipeline and it is written in the MSHR.

...

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

...

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
