# Implement `cva6_hpdcache_if_adapter`

Implement the complete `cva6_hpdcache_if_adapter` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module cva6_hpdcache_if_adapter` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

```systemverilog
module cva6_hpdcache_if_adapter
//  Parameters
//  {{{
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    parameter type dcache_req_i_t = logic,
    parameter type dcache_req_o_t = logic,
    parameter bit InvalidateOnFlush = 1'b0,
    parameter bit IsLoadPort = 1'b1
)
//  }}}

//  Ports
//  {{{
(
    //  Clock and active-low reset pins
    input logic clk_i,
    input logic rst_ni,

    //  Port ID
    input hpdcache_req_sid_t hpdcache_req_sid_i,

    //  Request/response ports from/to the CVA6 core
    input  dcache_req_i_t         cva6_req_i,
    output dcache_req_o_t         cva6_req_o,
    input  ariane_pkg::amo_req_t  cva6_amo_req_i,
    output ariane_pkg::amo_resp_t cva6_amo_resp_o,

    //  Dcache flush signal
    input  logic cva6_dcache_flush_i,
    output logic cva6_dcache_flush_ack_o,

    //  Request port to the L1 Dcache
    output logic                        hpdcache_req_valid_o,
    input  logic                        hpdcache_req_ready_i,
    output hpdcache_req_t               hpdcache_req_o,
    output logic                        hpdcache_req_abort_o,
    output hpdcache_tag_t               hpdcache_req_tag_o,
    output hpdcache_pkg::hpdcache_pma_t hpdcache_req_pma_o,

    //  Response port from the L1 Dcache
    input logic          hpdcache_rsp_valid_i,
    input hpdcache_rsp_t hpdcache_rsp_i
);
```

## Parent instantiation

```systemverilog
      cva6_hpdcache_if_adapter #(
          .CVA6Cfg              (CVA6Cfg),
          .HPDcacheCfg          (HPDcacheCfg),
          .hpdcache_tag_t       (hpdcache_tag_t),
          .hpdcache_req_offset_t(hpdcache_req_offset_t),
          .hpdcache_req_sid_t   (hpdcache_req_sid_t),
          .hpdcache_req_t       (hpdcache_req_t),
          .hpdcache_rsp_t       (hpdcache_rsp_t),
          .dcache_req_i_t       (dcache_req_i_t),
          .dcache_req_o_t       (dcache_req_o_t),
          .InvalidateOnFlush    (1'b0),
          .IsLoadPort           (1'b1)
      ) i_cva6_hpdcache_load_if_adapter (
          .clk_i,
          .rst_ni,

          .hpdcache_req_sid_i(hpdcache_req_sid_t'(r)),

          .cva6_req_i     (dcache_req_ports[r]),
          .cva6_req_o     (dcache_req_ports_o[r]),
          .cva6_amo_req_i ('0),
          .cva6_amo_resp_o(  /* unused */),

          .cva6_dcache_flush_i    (1'b0),
          .cva6_dcache_flush_ack_o(  /* unused */),

          .hpdcache_req_valid_o(dcache_req_valid[r]),
          .hpdcache_req_ready_i(dcache_req_ready[r]),
          .hpdcache_req_o      (dcache_req[r]),
          .hpdcache_req_abort_o(dcache_req_abort[r]),
          .hpdcache_req_tag_o  (dcache_req_tag[r]),
          .hpdcache_req_pma_o  (dcache_req_pma[r]),

          .hpdcache_rsp_valid_i(dcache_rsp_valid[r]),
          .hpdcache_rsp_i      (dcache_rsp[r])
      );

// ...

    cva6_hpdcache_if_adapter #(
        .CVA6Cfg              (CVA6Cfg),
        .HPDcacheCfg          (HPDcacheCfg),
        .hpdcache_tag_t       (hpdcache_tag_t),
        .hpdcache_req_offset_t(hpdcache_req_offset_t),
        .hpdcache_req_sid_t   (hpdcache_req_sid_t),
        .hpdcache_req_t       (hpdcache_req_t),
        .hpdcache_rsp_t       (hpdcache_rsp_t),
        .dcache_req_i_t       (dcache_req_i_t),
        .dcache_req_o_t       (dcache_req_o_t),
        .InvalidateOnFlush    (CVA6Cfg.DcacheInvalidateOnFlush),
        .IsLoadPort           (1'b0)
    ) i_cva6_hpdcache_store_if_adapter (
        .clk_i,
        .rst_ni,

        .hpdcache_req_sid_i(hpdcache_req_sid_t'(NumPorts - 1)),

        .cva6_req_i     (dcache_req_ports_i[NumPorts-1]),
        .cva6_req_o     (dcache_req_ports_o[NumPorts-1]),
        .cva6_amo_req_i (dcache_amo_req_i),
        .cva6_amo_resp_o(dcache_amo_resp_o),

        .cva6_dcache_flush_i    (dcache_flush_i),
        .cva6_dcache_flush_ack_o(dcache_flush_ack_o),

        .hpdcache_req_valid_o(dcache_req_valid[NumPorts-1]),
        .hpdcache_req_ready_i(dcache_req_ready[NumPorts-1]),
        .hpdcache_req_o      (dcache_req[NumPorts-1]),
        .hpdcache_req_abort_o(dcache_req_abort[NumPorts-1]),
        .hpdcache_req_tag_o  (dcache_req_tag[NumPorts-1]),
        .hpdcache_req_pma_o  (dcache_req_pma[NumPorts-1]),

        .hpdcache_rsp_valid_i(dcache_rsp_valid[NumPorts-1]),
        .hpdcache_rsp_i      (dcache_rsp[NumPorts-1])
    );
```

## Dependency declarations

### core/cva6.sv

```systemverilog
    // D$ data requests
    localparam type dcache_req_i_t = struct packed {
      logic [CVA6Cfg.DCACHE_INDEX_WIDTH-1:0] address_index;
      logic [CVA6Cfg.DCACHE_TAG_WIDTH-1:0]   address_tag;
      logic [CVA6Cfg.XLEN-1:0]               data_wdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0]  data_wuser;
      logic                                  data_req;
      logic                                  data_we;
      logic [(CVA6Cfg.XLEN/8)-1:0]           data_be;
      logic [1:0]                            data_size;
      logic [CVA6Cfg.DcacheIdWidth-1:0]      data_id;
      logic                                  kill_req;
      logic                                  tag_valid;
      cbo_t                                  cbo_op;
    },

    localparam type dcache_req_o_t = struct packed {
      logic                                 data_gnt;
      logic                                 data_rvalid;
      logic [CVA6Cfg.DcacheIdWidth-1:0]     data_rid;
      logic [CVA6Cfg.XLEN-1:0]              data_rdata;
      logic [CVA6Cfg.DCACHE_USER_WIDTH-1:0] data_ruser;
      logic                                 data_error;
    },
```

### core/include/ariane_pkg.sv

```systemverilog
    // cache block operations (CBO)
    CBO_CLEAN,
    CBO_FLUSH,
    CBO_INVAL,
    CBO_NONE,

// ...

  // --------------------
  // Atomics
  // --------------------
  typedef enum logic [3:0] {
    AMO_NONE = 4'b0000,
    AMO_LR   = 4'b0001,
    AMO_SC   = 4'b0010,
    AMO_SWAP = 4'b0011,
    AMO_ADD  = 4'b0100,
    AMO_AND  = 4'b0101,
    AMO_OR   = 4'b0110,
    AMO_XOR  = 4'b0111,
    AMO_MAX  = 4'b1000,
    AMO_MAXU = 4'b1001,
    AMO_MIN  = 4'b1010,
    AMO_MINU = 4'b1011,
    AMO_CAS1 = 4'b1100,  // unused, not part of riscv spec, but provided in OpenPiton
    AMO_CAS2 = 4'b1101   // unused, not part of riscv spec, but provided in OpenPiton
  } amo_t;

// ...

  // AMO request going to cache. this request is unconditionally valid as soon
  // as request goes high.
  // Furthermore, those signals are kept stable until the response indicates
  // completion by asserting ack.
  typedef struct packed {
    logic        req;        // this request is valid
    amo_t        amo_op;     // atomic memory operation to perform
    logic [1:0]  size;       // 2'b10 --> word operation, 2'b11 --> double word operation
    logic [63:0] operand_a;  // address
    logic [63:0] operand_b;  // data as layouted in the register
  } amo_req_t;

  // AMO response coming from cache.
  typedef struct packed {
    logic        ack;     // response is valid
    logic [63:0] result;  // sign-extended, result
  } amo_resp_t;
```

### core/include/config_pkg.sv

```systemverilog
  function automatic logic is_inside_cacheable_regions(cva6_cfg_t Cfg, logic [63:0] address);
    automatic logic [NrMaxRules-1:0] pass;
    pass = '0;
    for (int unsigned k = 0; k < Cfg.NrCachedRegionRules; k++) begin
      pass[k] = range_check(Cfg.CachedRegionAddrBase[k], Cfg.CachedRegionLength[k], address);
    end
    return |pass;
  endfunction : is_inside_cacheable_regions
```

### core/cache_subsystem/cva6_hpdcache_subsystem.sv

```systemverilog
  //  D$ instantiation
  //  {{{
  `include "hpdcache_typedef.svh"

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

// ...

  localparam hpdcache_pkg::hpdcache_user_cfg_t HPDcacheUserCfg = hpdcacheSetConfig();
  localparam hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = hpdcache_pkg::hpdcacheBuildConfig(
      HPDcacheUserCfg
  );

  `HPDCACHE_TYPEDEF_MEM_ATTR_T(hpdcache_mem_addr_t, hpdcache_mem_id_t, hpdcache_mem_data_t,
                               hpdcache_mem_be_t, HPDcacheCfg);
  `HPDCACHE_TYPEDEF_MEM_REQ_T(hpdcache_mem_req_t, hpdcache_mem_addr_t, hpdcache_mem_id_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_R_T(hpdcache_mem_resp_r_t, hpdcache_mem_id_t, hpdcache_mem_data_t);
  `HPDCACHE_TYPEDEF_MEM_REQ_W_T(hpdcache_mem_req_w_t, hpdcache_mem_data_t, hpdcache_mem_be_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_W_T(hpdcache_mem_resp_w_t, hpdcache_mem_id_t);

  `HPDCACHE_TYPEDEF_REQ_ATTR_T(hpdcache_req_offset_t, hpdcache_data_word_t, hpdcache_data_be_t,
                               hpdcache_req_data_t, hpdcache_req_be_t, hpdcache_req_sid_t,
                               hpdcache_req_tid_t, hpdcache_tag_t, HPDcacheCfg);
  `HPDCACHE_TYPEDEF_REQ_T(hpdcache_req_t, hpdcache_req_offset_t, hpdcache_req_data_t,
                          hpdcache_req_be_t, hpdcache_req_sid_t, hpdcache_req_tid_t,
                          hpdcache_tag_t);
  `HPDCACHE_TYPEDEF_RSP_T(hpdcache_rsp_t, hpdcache_req_data_t, hpdcache_req_sid_t,
                          hpdcache_req_tid_t);
```

### rtl/src/hpdcache_pkg.sv

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
```

### rtl/include/hpdcache_typedef.svh

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

## Related source code

### core/load_unit.sv

```systemverilog
  // this is a read-only interface so set the write enable to 0
  assign req_port_o.data_we = 1'b0;
  assign req_port_o.data_wdata = '0;
  assign req_port_o.cbo_op = ariane_pkg::CBO_NONE;
  // compose the load buffer write data, control is handled in the FSM
  assign ldbuf_wdata = {lsu_ctrl_i.trans_id, lsu_ctrl_i.vaddr, lsu_ctrl_i.operation};
  // output address
  // we can now output the lower 12 bit as the index to the cache
  assign req_port_o.address_index = lsu_ctrl_i.vaddr[CVA6Cfg.DCACHE_INDEX_WIDTH-1:0];
  // translation from last cycle, again: control is handled in the FSM
  assign req_port_o.address_tag   = paddr_i[CVA6Cfg.DCACHE_TAG_WIDTH     +
                                              CVA6Cfg.DCACHE_INDEX_WIDTH-1 :
                                              CVA6Cfg.DCACHE_INDEX_WIDTH];
  // request id = index of the load buffer's entry
  assign req_port_o.data_id = ldbuf_windex;
  // user field not used
  assign req_port_o.data_wuser = '0;

// ...

  always_comb begin : load_control
    automatic logic accept_req;

    // default assignments
    state_d              = state_q;
    translation_req_o    = 1'b0;
    req_port_o.data_req  = 1'b0;
    // tag control
    req_port_o.kill_req  = 1'b0;
    req_port_o.tag_valid = 1'b0;
    req_port_o.data_be   = lsu_ctrl_i.be;
    req_port_o.data_size = extract_transfer_size(lsu_ctrl_i.operation);

// ...

        WAIT_GNT: begin
          // keep the translation request up
          translation_req_o   = 1'b1;
          // keep the request up
          req_port_o.data_req = 1'b1;
          // we finally got a data grant
          if (req_port_i.data_gnt) begin
            // so we send the tag in the next cycle
            if (CVA6Cfg.MmuPresent && !dtlb_hit_i) begin
              state_d = ABORT_TRANSACTION;
            end else begin
              if (!stall_ni) begin
                // we got a grant and a hit on the DTLB so we can send the tag in the next cycle
                state_d  = SEND_TAG;
                pop_ld_o = 1'b1;
                // translation valid but this is to NC and the WB is not yet empty.
              end else if (CVA6Cfg.NonIdemPotenceEn) begin
                state_d = ABORT_TRANSACTION_NI;
              end
            end

          end
          // otherwise we keep waiting on our grant
        end
        // we know for sure that the tag we want to send is valid
        SEND_TAG: begin
          req_port_o.tag_valid = 1'b1;
          state_d = IDLE;

// ...

          // ----------
          // Exception
          // ----------
          // if we got an exception we need to kill the request immediately
          if (ex_i.valid) begin
            req_port_o.kill_req = 1'b1;
          end
        end

        WAIT_FLUSH: begin
          // the D$ arbiter will take care of presenting this to the memory only in case we
          // have an outstanding request
          req_port_o.kill_req = 1'b1;
          req_port_o.tag_valid = 1'b1;
          // we've killed the current request so we can go back to idle
          state_d = IDLE;
        end

// ...

  // track the load data for later usage
  assign ldbuf_w = req_port_o.data_req & req_port_i.data_gnt;

  // ---------------
  // Retire Load
  // ---------------
  assign ldbuf_rindex = (CVA6Cfg.NrLoadBufEntries > 1) ? ldbuf_id_t'(req_port_i.data_rid) : 1'b0;
  assign ldbuf_rdata = ldbuf_q[ldbuf_rindex];

  // decoupled rvalid process
  always_comb begin : rvalid_output
    //  read the pending load buffer
    ldbuf_r = req_port_i.data_rvalid;
```

### core/store_buffer.sv

```systemverilog
  // we will never kill a request in the store buffer since we already know that the translation is valid
  // e.g.: a kill request will only be necessary if we are not sure if the requested memory address will result in a TLB fault
  assign req_port_o.kill_req = 1'b0;
  assign req_port_o.data_we = 1'b1;  // we will always write in the store queue
  assign req_port_o.tag_valid = 1'b0;

  // we do not require an acknowledgement for writes, thus we do not need to identify uniquely the responses
  assign req_port_o.data_id = '0;
  // those signals can directly be output to the memory
  assign req_port_o.address_index = commit_queue_q[commit_read_pointer_q].address[CVA6Cfg.DCACHE_INDEX_WIDTH-1:0];
  // if we got a new request we already saved the tag from the previous cycle
  assign req_port_o.address_tag   = commit_queue_q[commit_read_pointer_q].address[CVA6Cfg.DCACHE_TAG_WIDTH     +
                                                                                    CVA6Cfg.DCACHE_INDEX_WIDTH-1 :
                                                                                    CVA6Cfg.DCACHE_INDEX_WIDTH];
  assign req_port_o.data_wdata = commit_queue_q[commit_read_pointer_q].data;
  assign req_port_o.data_wuser = '0;
  assign req_port_o.data_be = commit_queue_q[commit_read_pointer_q].be;
  assign req_port_o.data_size = commit_queue_q[commit_read_pointer_q].data_size;

  assign rvfi_mem_paddr_o = speculative_queue_q[speculative_read_pointer_q].address;

  always_comb begin : store_if
    automatic logic [$clog2(DEPTH_COMMIT):0] commit_status_cnt;
    commit_status_cnt      = commit_status_cnt_q;

    commit_ready_o         = (commit_status_cnt_q < DEPTH_COMMIT);
    // no store is pending if we don't have any element in the commit queue e.g.: it is empty
    no_st_pending_o        = (commit_status_cnt_q == 0);
    // default assignments
    commit_read_pointer_n  = commit_read_pointer_q;
    commit_write_pointer_n = commit_write_pointer_q;

    commit_queue_n         = commit_queue_q;

    req_port_o.data_req    = 1'b0;
    req_port_o.cbo_op      = commit_queue_q[commit_read_pointer_q].cbo_op;

    // there should be no commit when we are flushing
    // if the entry in the commit queue is valid and not speculative anymore we can issue this instruction
    if (commit_queue_q[commit_read_pointer_q].valid && !stall_st_pending_i && !commit_queue_q[commit_read_pointer_q].wait_rvalid) begin
      req_port_o.data_req = 1'b1;
      if (req_port_i.data_gnt) begin
        if (commit_queue_q[commit_read_pointer_q].cbo_op == ariane_pkg::CBO_NONE || req_port_i.data_rvalid) begin
          // not CBO or rvalid as well -> we can evict it from the commit buffer
          // check for rvalid is technically superfluous, as CBO latency is >= 1 cycle, but check it anyway just to be safe
          commit_queue_n[commit_read_pointer_q].valid = 1'b0;
          // advance the read_pointer
          commit_read_pointer_n = commit_read_pointer_q + 1'b1;
          commit_status_cnt--;
        end else if (commit_queue_q[commit_read_pointer_q].cbo_op != ariane_pkg::CBO_NONE) begin
          // CBO and have gotten data grant -> proceed to wait for rvalid
          commit_queue_n[commit_read_pointer_q].wait_rvalid = 1'b1;
        end
      end
    end

    if(commit_queue_q[commit_read_pointer_q].valid && commit_queue_q[commit_read_pointer_q].wait_rvalid)
    begin
      // wait for rvalid, but no need to raise another request / wait for grant
      if (req_port_i.data_rvalid) begin
        // CMO did commit
        // we can evict the entry from the commit buffer
        commit_queue_n[commit_read_pointer_q].valid = 1'b0;
        // advance the read_pointer
        commit_read_pointer_n = commit_read_pointer_q + 1'b1;
        commit_status_cnt--;
      end
    end

    // we ignore the rvalid signal for now as we assume that the store
    // happened if we got a grant
```

## Documentation

### docs/source/interface.rst

```text
Cache-Requesters Interface
--------------------------------------

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
```
