# Implement `hpdcache_data_resize`

Implement the complete `hpdcache_data_resize` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_data_resize` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

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

## Parent instantiation

### `rtl/src/hpdcache_flush.sv`

```systemverilog
    hpdcache_data_resize #(
        .WR_WIDTH       (HPDcacheCfg.accessWidth),
        .RD_WIDTH       (HPDcacheCfg.u.memDataWidth),
        .DEPTH          (HPDcacheCfg.u.flushFifoDepth)
    ) flush_data_resizer_i(
        .clk_i,
        .rst_ni,

        .w_i            (flush_resizer_w),
        .wok_o          (flush_resizer_wok),
        .wdata_i        (flush_data_read_data_i),
        .wlast_i        (flush_resizer_wlast),

        .r_i            (mem_req_write_data_ready_i),
        .rok_o          (mem_req_write_data_valid_o),
        .rdata_o        (flush_mem_req_rdata),
        .rlast_o        (/* open */)
    );
```

### `rtl/src/hpdcache_miss_handler.sv`

```systemverilog
    hpdcache_data_resize #(
        .WR_WIDTH (HPDcacheCfg.u.memDataWidth),
        .RD_WIDTH (HPDcacheCfg.accessWidth),
        .DEPTH    (HPDcacheCfg.u.refillFifoDepth)
    ) i_data_resize(
        .clk_i,
        .rst_ni,

        .w_i    (refill_fifo_resp_data_w),
        .wok_o  (refill_fifo_resp_data_wok),
        .wdata_i(mem_resp_i.mem_resp_r_data),
        .wlast_i(mem_resp_i.mem_resp_r_last),

        .r_i    (refill_fifo_resp_data_r),
        .rok_o  (/* unused */),
        .rdata_o(refill_fifo_resp_data_rdata),
        .rlast_o(/* unused */)
    );
```

## Dependency declarations

### `rtl/src/common/hpdcache_data_downsize.sv`

```systemverilog
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
```

### `rtl/src/common/hpdcache_data_upsize.sv`

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
