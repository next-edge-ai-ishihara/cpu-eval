# Implement `cva6_hpdcache_subsystem_axi_arbiter`

Implement the complete `cva6_hpdcache_subsystem_axi_arbiter` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module cva6_hpdcache_subsystem_axi_arbiter` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

### core/include/cv32a60x_config_pkg.sv

```systemverilog
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

      IcacheByteSize: unsigned'(2048),
      IcacheSetAssoc: unsigned'(2),
      IcacheLineWidth: unsigned'(128),
      DCacheType: config_pkg::HPDCACHE_WT,
      DcacheByteSize: unsigned'(2028),
      DcacheSetAssoc: unsigned'(2),
      DcacheLineWidth: unsigned'(128),
```

## Module declaration

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

## Parent instantiation

```systemverilog
  //  I$ instantiation
  //  {{{
  logic icache_miss_valid, icache_miss_ready;
  icache_req_t icache_miss;

  logic icache_miss_resp_valid;
  icache_rtrn_t icache_miss_resp;

  localparam int ICACHE_RDTXID = 1 << (CVA6Cfg.MEM_TID_WIDTH - 1);

  cva6_icache #(
      .CVA6Cfg(CVA6Cfg),
      .icache_areq_t(icache_areq_t),
      .icache_arsp_t(icache_arsp_t),
      .icache_dreq_t(icache_dreq_t),
      .icache_drsp_t(icache_drsp_t),
      .icache_req_t(icache_req_t),
      .icache_rtrn_t(icache_rtrn_t),
      .RdTxId(ICACHE_RDTXID)
  ) i_cva6_icache (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .flush_i       (icache_flush_i),
      .en_i          (icache_en_i),
      .miss_o        (icache_miss_o),
      .areq_i        (icache_areq_i),
      .areq_o        (icache_areq_o),
      .dreq_i        (icache_dreq_i),
      .dreq_o        (icache_dreq_o),
      .mem_rtrn_vld_i(icache_miss_resp_valid),
      .mem_rtrn_i    (icache_miss_resp),
      .mem_data_req_o(icache_miss_valid),
      .mem_data_ack_i(icache_miss_ready),
      .mem_data_o    (icache_miss)
  );

// ...

    cva6_hpdcache_subsystem_axi_arbiter #(
        .CVA6Cfg              (CVA6Cfg),
        .hpdcache_mem_id_t    (hpdcache_mem_id_t),
        .hpdcache_mem_req_t   (hpdcache_mem_req_t),
        .hpdcache_mem_req_w_t (hpdcache_mem_req_w_t),
        .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
        .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t),
        .icache_req_t         (icache_req_t),
        .icache_rtrn_t        (icache_rtrn_t),

        .AxiAddrWidth (CVA6Cfg.AxiAddrWidth),
        .AxiDataWidth (CVA6Cfg.AxiDataWidth),
        .AxiIdWidth   (CVA6Cfg.AxiIdWidth),
        .AxiUserWidth (CVA6Cfg.AxiUserWidth),
        .axi_ar_chan_t(axi_ar_chan_t),
        .axi_aw_chan_t(axi_aw_chan_t),
        .axi_w_chan_t (axi_w_chan_t),
        .axi_b_chan_t (axi_b_chan_t),
        .axi_r_chan_t (axi_r_chan_t),
        .axi_req_t    (noc_req_t),
        .axi_rsp_t    (noc_resp_t)
    ) i_axi_arbiter (
        .clk_i,
        .rst_ni,

        .icache_miss_valid_i(icache_miss_valid),
        .icache_miss_ready_o(icache_miss_ready),
        .icache_miss_i      (icache_miss),
        .icache_miss_id_i   (hpdcache_mem_id_t'(ICACHE_RDTXID)),

        .icache_miss_resp_valid_o(icache_miss_resp_valid),
        .icache_miss_resp_o      (icache_miss_resp),

        .dcache_read_ready_o(dcache_read_ready),
        .dcache_read_valid_i(dcache_read_valid),
        .dcache_read_i      (dcache_read),

        .dcache_read_resp_ready_i(dcache_read_resp_ready),
        .dcache_read_resp_valid_o(dcache_read_resp_valid),
        .dcache_read_resp_o      (dcache_read_resp),

        .dcache_write_ready_o(dcache_write_ready),
        .dcache_write_valid_i(dcache_write_valid),
        .dcache_write_i      (dcache_write),

        .dcache_write_data_ready_o(dcache_write_data_ready),
        .dcache_write_data_valid_i(dcache_write_data_valid),
        .dcache_write_data_i      (dcache_write_data),

        .dcache_write_resp_ready_i(dcache_write_resp_ready),
        .dcache_write_resp_valid_o(dcache_write_resp_valid),
        .dcache_write_resp_o      (dcache_write_resp),

        .axi_req_o (noc_req_o),
        .axi_resp_i(noc_resp_i)
    );
```

## Dependency declarations

### core/cva6.sv

```systemverilog
    localparam type icache_req_t = struct packed {
      logic [CVA6Cfg.ICACHE_SET_ASSOC_WIDTH-1:0] way;  // way to replace
      logic [CVA6Cfg.PLEN-1:0] paddr;  // physical address
      logic nc;  // noncacheable
      logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
    },
    localparam type icache_rtrn_t = struct packed {
      wt_cache_pkg::icache_in_t rtype;  // see definitions above
      logic [CVA6Cfg.ICACHE_LINE_WIDTH-1:0] data;  // full cache line width
      logic [CVA6Cfg.ICACHE_USER_LINE_WIDTH-1:0] user;  // user bits
      struct packed {
        logic                                      vld;  // invalidate only affected way
        logic                                      all;  // invalidate all ways
        logic [CVA6Cfg.ICACHE_INDEX_WIDTH-1:0]     idx;  // physical address to invalidate
        logic [CVA6Cfg.ICACHE_SET_ASSOC_WIDTH-1:0] way;  // way to invalidate
      } inv;  // invalidation vector
      logic [CVA6Cfg.MEM_TID_WIDTH-1:0] tid;  // thread id (used as transaction id in Ariane)
    },
```

### core/include/wt_cache_pkg.sv

```systemverilog
  typedef enum logic [0:0] {
    ICACHE_INV_REQ,   // no ack from the core required
    ICACHE_IFILL_ACK
  } icache_in_t;
```

### rtl/src/hpdcache_pkg.sv

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
```

### rtl/src/common/hpdcache_fifo_reg.sv

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : FIFO buffer (using registers)
 *  History       :
 */
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

### rtl/src/common/hpdcache_data_upsize.sv

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : November 22, 2022
 *  Description   : Refill data upsize
 *  History       :
 */
module hpdcache_data_upsize
//  {{{
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter int WR_WIDTH = 0,
    parameter int RD_WIDTH = 0,

    /*  The actual number of words in the upsizer is computed as
     *  FIFO_WORDS = DEPTH * (RD_WIDTH/WR_WIDTH)
     *
     *  The size of a word in this component is defined as the number of bytes
     *  consumed by the reader at each read access
     *  WORD_WIDTH = WR_WIDTH
     */
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
    output rdata_t rdata_o
);
```

### rtl/src/utils/hpdcache_mem_req_read_arbiter.sv

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : Dcache Memory Read Request Channel Arbiter
 *  History       :
 */
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

### rtl/src/utils/hpdcache_mem_resp_demux.sv

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : June, 2022
 *  Description   : Dcache Memory Response Demultiplexer
 *  History       :
 */
module hpdcache_mem_resp_demux
//  Parameters
//  {{{
#(
  parameter int         N  = 0,
  parameter type resp_t    = logic,
  parameter type resp_id_t = logic,

  localparam int RT_DEPTH  = (1 << $bits(resp_id_t)),
  localparam type rt_t     = resp_id_t [RT_DEPTH-1:0]
)
//  }}}

//  Ports
//  {{{
(
  input  logic           clk_i,
  input  logic           rst_ni,

  output logic           mem_resp_ready_o,
  input  logic           mem_resp_valid_i,
  input  resp_id_t       mem_resp_id_i,
  input  resp_t          mem_resp_i,

  input  logic           mem_resp_ready_i [N-1:0],
  output logic           mem_resp_valid_o [N-1:0],
  output resp_t          mem_resp_o       [N-1:0],

  input  rt_t            mem_resp_rt_i
);
```

### rtl/src/utils/hpdcache_mem_to_axi_read.sv

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : Dcache memory request to axi read channels
 *  History       :
 */
module hpdcache_mem_to_axi_read
import hpdcache_pkg::*;
#(
    parameter type hpdcache_mem_req_t    = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type ar_chan_t = logic,
    parameter type r_chan_t  = logic
)
(
    output logic                          req_ready_o,
    input  logic                          req_valid_i,
    input  hpdcache_mem_req_t             req_i,

    input  logic                          resp_ready_i,
    output logic                          resp_valid_o,
    output hpdcache_mem_resp_r_t          resp_o,

    output logic                          axi_ar_valid_o,
    output ar_chan_t                      axi_ar_o,
    input  logic                          axi_ar_ready_i,

    input  logic                          axi_r_valid_i,
    input  r_chan_t                       axi_r_i,
    output logic                          axi_r_ready_o
);
```

### rtl/src/utils/hpdcache_mem_to_axi_write.sv

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : Dcache memory request to axi write channels
 *  History       :
 */
module hpdcache_mem_to_axi_write
import hpdcache_pkg::*;
#(
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,
    parameter type aw_chan_t = logic,
    parameter type w_chan_t = logic,
    parameter type b_chan_t = logic
)
(
    output logic                          req_ready_o,
    input  logic                          req_valid_i,
    input  hpdcache_mem_req_t             req_i,

    output logic                          req_data_ready_o,
    input  logic                          req_data_valid_i,
    input  hpdcache_mem_req_w_t           req_data_i,

    input  logic                          resp_ready_i,
    output logic                          resp_valid_o,
    output hpdcache_mem_resp_w_t          resp_o,

    output logic                          axi_aw_valid_o,
    output aw_chan_t                      axi_aw_o,
    input  logic                          axi_aw_ready_i,

    output logic                          axi_w_valid_o,
    output w_chan_t                       axi_w_o,
    input  logic                          axi_w_ready_i,

    input  logic                          axi_b_valid_i,
    input  b_chan_t                       axi_b_i,
    output logic                          axi_b_ready_o
);
```

## Related source code

### core/cache_subsystem/cva6_icache_axi_wrapper.sv

```systemverilog
  // Keep read request asserted until we have an AXI grant. This is not guaranteed by icache (but
  // required by AXI).

// ...

  // Fetch a full cache line on a cache miss, or a single word on a bypassed access
  assign axi_rd_blen           = (req_data_d.nc) ? '0 : CVA6Cfg.ICACHE_LINE_WIDTH / 64 - 1;
  assign axi_rd_size           = $clog2(CVA6Cfg.AxiDataWidth / 8);  // Maximum
  assign axi_rd_id_in          = req_data_d.tid;
  assign axi_rd_rdy            = 1'b1;
  assign axi_rd_lock           = 1'b0;

  // Immediately acknowledge read request. This is an implicit requirement for the icache.
  assign icache_mem_data_ack   = icache_mem_data_req;

  // Return data as soon as last word arrives
  assign icache_mem_rtrn_vld   = axi_rd_valid & axi_rd_last;
  assign icache_mem_rtrn.data  = rd_shift_d;
  assign icache_mem_rtrn.tid   = req_data_q.tid;
  assign icache_mem_rtrn.rtype = wt_cache_pkg::ICACHE_IFILL_ACK;
  assign icache_mem_rtrn.inv   = '0;

// ...

      // If this is a single word transaction, we need to make sure that word is placed at offset 0
      if (first_q) begin
        rd_shift_d[0] = axi_rd_data;
      end
```

### rtl/src/common/hpdcache_data_upsize.sv

```systemverilog
//  Architecture
//  {{{
    //  Local definitions
    //  {{{
    localparam int WR_WORDS = RD_WIDTH/WR_WIDTH;
    localparam int PTR_WIDTH = $clog2(DEPTH);
    localparam int WORDCNT_WIDTH = $clog2(WR_WORDS);
    typedef logic [PTR_WIDTH-1:0]  bufptr_t;
    typedef logic [WORDCNT_WIDTH-1:0]  wordptr_t;
    typedef logic [PTR_WIDTH:0]  occupancy_t;
    //  }}}

    //  Internal registers and signals
    //  {{{
    wdata_t [DEPTH-1:0][WR_WORDS-1:0] buf_q;
    bufptr_t  wrptr_q, wrptr_d;
    bufptr_t  rdptr_q, rdptr_d;
    occupancy_t  used_q, used_d;
    wordptr_t [DEPTH-1:0]  words_q, words_d;
    logic  full, empty;
    logic  shift;
    //  }}}

    //  Control-Path
    //  {{{
    assign full = (hpdcache_uint'(used_q) == DEPTH),
           empty = (used_q == 0),
           wok_o = ~full,
           rok_o = ~empty;

    always_comb
    begin : ctrl_comb
        automatic logic used_inc, used_dec;
        automatic logic words_inc, words_reset;

        wrptr_d = wrptr_q;
        rdptr_d = rdptr_q;
        words_d = words_q;
        used_dec = 1'b0;
        used_inc = 1'b0;
        words_reset = 1'b0;
        words_inc = 1'b0;
        shift = 1'b0;

        if (w_i && wok_o) begin
            shift = 1'b1;
            words_inc = (hpdcache_uint'(words_q[wrptr_q]) < (WR_WORDS-1));
            if (hpdcache_uint'(words_q[wrptr_q]) == (WR_WORDS-1) || wlast_i) begin
                used_inc = 1'b1;
                if (hpdcache_uint'(wrptr_q) == (DEPTH-1)) begin
                    wrptr_d = 0;
                end else begin
                    wrptr_d = wrptr_q + 1;
                end
            end
        end

        if (r_i && rok_o) begin
            used_dec = 1'b1;
            words_reset = 1'b1;
            if (hpdcache_uint'(rdptr_q) == (DEPTH-1)) begin
                rdptr_d = 0;
            end else begin
                rdptr_d = rdptr_q + 1;
            end
        end

        case ({used_inc, used_dec})
            2'b10  : used_d = used_q + 1;
            2'b01  : used_d = used_q - 1;
            default: used_d = used_q;
        endcase

        if (words_inc)   words_d[wrptr_q] = words_q[wrptr_q] + 1;
        if (words_reset) words_d[rdptr_q] = 0;
    end


    always_ff @(posedge clk_i or negedge rst_ni)
    begin : ctrl_ff
        if (!rst_ni) begin
            rdptr_q <= 0;
            wrptr_q <= 0;
            used_q <= 0;
            words_q <= '0;
        end else begin
            rdptr_q <= rdptr_d;
            wrptr_q <= wrptr_d;
            used_q <= used_d;
            words_q <= words_d;
        end
    end
    //  }}}

    //  Data-Path
    //  {{{
    always_ff @(posedge clk_i or negedge rst_ni)
    begin : buf_ff
        if (!rst_ni) begin
            buf_q <= '0;
        end else begin
            if (shift) begin
                buf_q[wrptr_q][words_q[wrptr_q]] <= wdata_i;
            end
        end
    end

    assign rdata_o = buf_q[rdptr_q];
    //  }}}
```

### rtl/src/utils/hpdcache_mem_resp_demux.sv

```systemverilog
  typedef logic [$clog2(N)-1:0] sel_t;

  logic    [N-1:0] mem_resp_demux_valid;
  resp_t   [N-1:0] mem_resp_demux;
  logic    [N-1:0] mem_resp_demux_ready;
  sel_t            mem_resp_demux_sel;

  //  Route the response according to the response ID and the routing table
  assign mem_resp_demux_sel = mem_resp_rt_i[int'(mem_resp_id_i)];
```

### rtl/src/utils/hpdcache_mem_to_axi_read.sv

```systemverilog
    assign  req_ready_o       = axi_ar_ready_i,
            axi_ar_valid_o    = req_valid_i,
            axi_ar_o.id       = req_i.mem_req_id,
            axi_ar_o.addr     = req_i.mem_req_addr,
            axi_ar_o.len      = req_i.mem_req_len,
            axi_ar_o.size     = req_i.mem_req_size,
            axi_ar_o.burst    = axi_pkg::BURST_INCR,
            axi_ar_o.lock     = lock,
            axi_ar_o.cache    = cache,
            axi_ar_o.prot     = '0,
            axi_ar_o.qos      = '0,
            axi_ar_o.region   = '0,
            axi_ar_o.user     = '0;

    assign  axi_r_ready_o           = resp_ready_i,
            resp_valid_o            = axi_r_valid_i,
            resp_o.mem_resp_r_error = resp,
            resp_o.mem_resp_r_id    = axi_r_i.id,
            resp_o.mem_resp_r_data  = axi_r_i.data,
            resp_o.mem_resp_r_last  = axi_r_i.last;
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
