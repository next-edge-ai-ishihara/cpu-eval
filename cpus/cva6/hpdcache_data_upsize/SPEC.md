# Implement `hpdcache_data_upsize`

Implement the complete `hpdcache_data_upsize` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_data_upsize` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
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

## Parent instantiation

### `rtl/src/common/hpdcache_data_resize.sv`

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : September, 2024
 *  Description   : Data Resizer
 *  History       :
m*/
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
//  }}}

//  Upsizer
//  {{{
if (WR_WIDTH < RD_WIDTH) begin : gen_upsize
    hpdcache_data_upsize #(
        .WR_WIDTH       (WR_WIDTH),
        .RD_WIDTH       (RD_WIDTH),
        .DEPTH          (DEPTH)
    ) upsizer_i(
        .clk_i,
        .rst_ni,

        .w_i,
        .wlast_i,
        .wok_o,
        .wdata_i,

        .r_i,
        .rok_o,
        .rdata_o
    );

    assign rlast_o = 1'b1;
end
```

### `core/cache_subsystem/cva6_hpdcache_subsystem_axi_arbiter.sv`

```systemverilog
  //    I$ response
  logic icache_miss_resp_w, icache_miss_resp_wok;
  hpdcache_mem_resp_r_t icache_miss_resp_wdata;

  logic icache_miss_resp_data_w, icache_miss_resp_data_wok;
  logic icache_miss_resp_data_r, icache_miss_resp_data_rok;
  icache_resp_data_t icache_miss_resp_data_rdata;

  logic icache_miss_resp_meta_w, icache_miss_resp_meta_wok;
  logic icache_miss_resp_meta_r, icache_miss_resp_meta_rok;
  hpdcache_mem_id_t  icache_miss_resp_meta_id;

  icache_resp_data_t icache_miss_rdata;

  generate
    if (CVA6Cfg.AxiDataWidth < CVA6Cfg.ICACHE_LINE_WIDTH) begin
      hpdcache_fifo_reg #(
          .FIFO_DEPTH (1),
          .fifo_data_t(hpdcache_mem_id_t)
      ) i_icache_refill_meta_fifo (
          .clk_i,
          .rst_ni,

          .w_i    (icache_miss_resp_meta_w),
          .wok_o  (icache_miss_resp_meta_wok),
          .wdata_i(icache_miss_resp_wdata.mem_resp_r_id),

          .r_i    (icache_miss_resp_meta_r),
          .rok_o  (icache_miss_resp_meta_rok),
          .rdata_o(icache_miss_resp_meta_id)
      );

      hpdcache_data_upsize #(
          .WR_WIDTH(CVA6Cfg.AxiDataWidth),
          .RD_WIDTH(CVA6Cfg.ICACHE_LINE_WIDTH),
          .DEPTH   (1)
      ) i_icache_hpdcache_data_upsize (
          .clk_i,
          .rst_ni,

          .w_i    (icache_miss_resp_data_w),
          .wlast_i(icache_miss_resp_wdata.mem_resp_r_last),
          .wok_o  (icache_miss_resp_data_wok),
          .wdata_i(icache_miss_resp_wdata.mem_resp_r_data),

          .r_i    (icache_miss_resp_data_r),
          .rok_o  (icache_miss_resp_data_rok),
          .rdata_o(icache_miss_resp_data_rdata)
      );

      assign icache_miss_resp_meta_r = 1'b1, icache_miss_resp_data_r = 1'b1;

      assign icache_miss_resp_meta_w = icache_miss_resp_w & icache_miss_resp_wdata.mem_resp_r_last;

      assign icache_miss_resp_data_w = icache_miss_resp_w;

      assign icache_miss_resp_wok = icache_miss_resp_data_wok & (
               icache_miss_resp_meta_wok | ~icache_miss_resp_wdata.mem_resp_r_last);

    end else begin
      assign icache_miss_resp_data_rok = icache_miss_resp_w;
      assign icache_miss_resp_meta_rok = icache_miss_resp_w;
      assign icache_miss_resp_wok = 1'b1;
      assign icache_miss_resp_meta_id = icache_miss_resp_wdata.mem_resp_r_id;
      assign icache_miss_resp_data_rdata = icache_miss_resp_wdata.mem_resp_r_data;
    end
  endgenerate

  //  In the case of uncacheable accesses, the Icache expects the data to be right-aligned
  always_comb begin : icache_miss_resp_data_comb
    if (!icache_miss_req_rdata.mem_req_cacheable) begin
      automatic logic [ICACHE_UC_WORD_INDEX - 1:0] icache_miss_word_index;
      automatic logic [63:0] icache_miss_word;
      if (CVA6Cfg.AxiDataWidth > 64) begin
        icache_miss_word_index = icache_miss_req_rdata.mem_req_addr[3+:ICACHE_UC_WORD_INDEX];
      end else begin
        icache_miss_word_index = 0;
      end
      icache_miss_word  = icache_miss_resp_data_rdata[icache_miss_word_index*64+:64];
      icache_miss_rdata = {{CVA6Cfg.ICACHE_LINE_WIDTH - 64{1'b0}}, icache_miss_word};
    end else begin
      icache_miss_rdata = icache_miss_resp_data_rdata;
    end
  end

  assign icache_miss_resp_valid_o = icache_miss_resp_meta_rok;
  assign icache_miss_resp_o.rtype = wt_cache_pkg::ICACHE_IFILL_ACK;
  assign icache_miss_resp_o.user = '0;
  assign icache_miss_resp_o.inv = '0;
  assign icache_miss_resp_o.tid = icache_miss_resp_meta_id;
  assign icache_miss_resp_o.data = icache_miss_rdata;
```

## Related source code

### `rtl/src/common/hpdcache_data_downsize.sv`

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : November 22, 2022
 *  Description   : Refill data downsize
 *  History       :
 */
module hpdcache_data_downsize
//  {{{
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter int WR_WIDTH = 0,
    parameter int RD_WIDTH = 0,

    /*  The actual number of words in the downsizer is computed as
     *  FIFO_WORDS = DEPTH * (WR_WIDTH/RD_WIDTH)
     *
     *  The size of a word in this component is defined as the number of bytes
     *  produced by the writer at each write access
     *  WORD_WIDTH = RD_WIDTH
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

    input  logic   r_i,
    output logic   rok_o,
    output rdata_t rdata_o,
    output logic   rlast_o
);
//  }}}
//  Architecture
//  {{{
    //  Local definitions
    //  {{{
    localparam int RD_WORDS = WR_WIDTH/RD_WIDTH;
    localparam int PTR_WIDTH = $clog2(DEPTH);
    localparam int WORDCNT_WIDTH = $clog2(RD_WORDS);
    typedef logic [PTR_WIDTH-1:0]  bufptr_t;
    typedef logic [WORDCNT_WIDTH-1:0]  wordptr_t;
    typedef logic [PTR_WIDTH:0]  occupancy_t;
    //  }}}

    //  Internal registers and signals
    //  {{{
    rdata_t [DEPTH-1:0][RD_WORDS-1:0] buf_q;
    bufptr_t wrptr_q, wrptr_d;
    bufptr_t rdptr_q, rdptr_d;
    occupancy_t used_q, used_d;
    wordptr_t [DEPTH-1:0] words_q, words_d;
    logic words_set;
    logic  full, empty;
    //  }}}

    //  Control-Path
    //  {{{
    assign full = (hpdcache_uint'(used_q) == DEPTH);
    assign empty = (used_q == 0);
    assign wok_o = ~full;
    assign rok_o = ~empty;

    always_comb
    begin : ctrl_comb
        automatic logic used_inc, used_dec;
        automatic logic words_dec;

        rdptr_d = rdptr_q;
        wrptr_d = wrptr_q;
        used_dec = 1'b0;
        used_inc = 1'b0;
        words_dec = 1'b0;
        words_set = 1'b0;

        if (w_i && wok_o) begin
            used_inc  = 1'b1;
            words_set = 1'b1;
            if (hpdcache_uint'(wrptr_q) == (DEPTH-1)) begin
                wrptr_d = 0;
            end else begin
                wrptr_d = wrptr_q + 1;
            end
        end

        if (r_i && rok_o) begin
            words_dec = (words_q[rdptr_q] > 0);
            if (words_q[rdptr_q] == 0) begin
                used_dec = 1'b1;
                if (hpdcache_uint'(rdptr_q) == (DEPTH-1)) begin
                    rdptr_d = 0;
                end else begin
                    rdptr_d = rdptr_q + 1;
                end
            end
        end

        case ({used_inc, used_dec})
            2'b10  : used_d = used_q + 1;
            2'b01  : used_d = used_q - 1;
            default: used_d = used_q;
        endcase

        words_d = words_q;
        if (words_set) begin
            words_d[wrptr_q] = wordptr_t'(RD_WORDS - 1);
        end
        if (words_dec) begin
            words_d[rdptr_q] = words_q[rdptr_q] - 1;
        end
    end

    assign rlast_o = rok_o & (words_q[rdptr_q] == 0);

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : ctrl_ff
        if (!rst_ni) begin
            rdptr_q <= 0;
            wrptr_q <= 0;
            used_q <= 0;
            words_q <= 0;
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
            if (words_set) begin
                buf_q[wrptr_q] <= wdata_i;
            end
        end
    end

    assign rdata_o = buf_q[rdptr_q][RD_WORDS - hpdcache_uint'(words_q[rdptr_q]) - 1];
    //  }}}
```

## Documentation

### `docs/source/interface.rst`

```text
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
