# Implement `hpdcache_mux`

Implement the complete `hpdcache_mux` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_mux` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

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

## Parent instantiation

### `rtl/src/hpdcache_core_arbiter.sv`

```systemverilog
    hpdcache_mux #(
        .NINPUT         (HPDcacheCfg.u.nRequesters),
        .DATA_WIDTH     ($bits(hpdcache_req_t)),
        .ONE_HOT_SEL    (1'b1)
    ) core_req_mux_i (
        .data_i         (core_req),
        .sel_i          (arb_req_gnt_d),
        .data_o         (arb_req_o)
    );

```

### `rtl/src/hpdcache_miss_handler.sv`

```systemverilog
    //  refill's width is bigger than the width of the core's interface
    if (REFILL_REQ_RATIO > 1) begin : gen_core_rsp_data_mux
        hpdcache_mux #(
            .NINPUT      (REFILL_REQ_RATIO),
            .DATA_WIDTH  (HPDcacheCfg.reqDataWidth)
        ) data_read_rsp_mux_i(
            .data_i      (refill_data_o),
            .sel_i       (refill_core_rsp_word[0 +: $clog2(REFILL_REQ_RATIO)]),
            .data_o      (refill_core_rsp_rdata)
        );
    end

```
