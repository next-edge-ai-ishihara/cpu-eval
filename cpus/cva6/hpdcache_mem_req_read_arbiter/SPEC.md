# Implement `hpdcache_mem_req_read_arbiter`

Implement the complete `hpdcache_mem_req_read_arbiter` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_mem_req_read_arbiter` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

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

## Parent instantiation

### `rtl/src/hpdcache.sv`

```systemverilog
    //      Read request interface
    //
    //      There is a fixed-priority arbiter between:
    //      - the miss_handler (higher priority);
    //      - the uncacheable request handler (lower priority)
    logic              [1:0] arb_mem_req_read_ready;
    logic              [1:0] arb_mem_req_read_valid;
    hpdcache_mem_req_t [1:0] arb_mem_req_read;

    assign mem_req_read_miss_ready = arb_mem_req_read_ready[0];
    assign arb_mem_req_read_valid[0] = mem_req_read_miss_valid;
    assign arb_mem_req_read[0] = mem_req_read_miss;

    assign mem_req_read_uc_ready = arb_mem_req_read_ready[1];
    assign arb_mem_req_read_valid[1] = mem_req_read_uc_valid;
    assign arb_mem_req_read[1] = mem_req_read_uc;

    hpdcache_mem_req_read_arbiter #(
        .N                     (2),
        .hpdcache_mem_req_t    (hpdcache_mem_req_t)
    ) hpdcache_mem_req_read_arbiter_i(
        .clk_i,
        .rst_ni,

        .mem_req_read_ready_o  (arb_mem_req_read_ready),
        .mem_req_read_valid_i  (arb_mem_req_read_valid),
        .mem_req_read_i        (arb_mem_req_read),

        .mem_req_read_ready_i,
        .mem_req_read_valid_o,
        .mem_req_read_o        (mem_req_read_o),

        .gnt_index_o           (/*unused*/)
    );
```

## Dependency declarations

### `rtl/src/common/hpdcache_fxarb.sv`

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : Fixed-Priority Arbiter
 *  History       :
 */
module hpdcache_fxarb
    //  Parameters
    //  {{{
#(
    //    Number of requesters
    parameter int unsigned N = 0
)
    //  }}}
    //  Ports
    //  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  logic [N-1:0]          req_i,
    output logic [N-1:0]          gnt_o,
    input  logic                  ready_i
);
    //  }}}

    //  Declaration of internal wires and registers
    //  {{{
    logic [N-1:0]       gnt_q, gnt;
    logic               wait_q;
    //  }}}

    //  Compute the grant vector
    //  {{{
    hpdcache_prio_1hot_encoder #(.N(N)) prio_msk_i (.val_i(req_i), .val_o(gnt));
    //  }}}

    //  Compute the output grant vector
    //  {{{
    assign gnt_o = wait_q ? gnt_q : gnt;
    //  }}}

    //  Setting of internal state
    //  {{{
    always_ff @(posedge clk_i or negedge rst_ni)
    begin
        if (!rst_ni) begin
            wait_q <= 1'b0;
            gnt_q  <= '0;
        end else begin
            wait_q <= ~ready_i & (wait_q | (|req_i));
            if (!ready_i && !wait_q && (|req_i)) begin
                gnt_q <= gnt;
            end
        end
    end
    //  }}}

    //  Assertions
    //  {{{
`ifndef HPDCACHE_ASSERT_OFF
    gnt_at_most_one_requester: assert property (@(posedge clk_i) disable iff (rst_ni !== 1'b1)
            $onehot0(gnt_o)) else $error("arbiter: granting more than one requester");
`endif
    //  }}}

endmodule
```

### `rtl/src/common/hpdcache_prio_1hot_encoder.sv`

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : Priority One-hot Encoder
 *  History       :
 */
module hpdcache_prio_1hot_encoder
    //  Parameters
#(
    parameter int unsigned N = 0
)
    //  Ports
(
    input  logic [N-1:0] val_i,
    output logic [N-1:0] val_o
);

    assign val_o[0] = val_i[0];

    for (genvar i = 1; i < int'(N); i++) begin : gen_prio
        assign val_o[i] = val_i[i] & ~(|val_i[i-1:0]);
    end
endmodule
```

### `rtl/src/common/hpdcache_mux.sv`

```systemverilog
/*
 *  Author(s)     : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : Simple multiplexor
 *  History       :
 */
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
// ...
    end else begin : gen_multi_input
        //  Selector is one-hot encoded
        if (ONE_HOT_SEL == 1) begin : gen_onehot_sel
            always_comb
            begin : data_out_mux_comb
                data_o = '0;
                for (int unsigned i = 0; i < NINPUT; i++) begin
                    data_o |= sel_i[i] ? data_i[i] : '0;
                end
            end
```

### `rtl/src/common/hpdcache_1hot_to_binary.sv`

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : One-hot to binary decoder
 *  History       :
 */
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
    //  }}}

    always_comb
    begin : decode_comb
        val_o = 0;
        for (int unsigned i = 0; i < N; i++) begin
            if (val_i[i]) val_o = out_t'(i);
        end

    //  Assertions
    //  {{{
`ifndef HPDCACHE_ASSERT_OFF
        //  FIXME: The final keyword is not supported by the Spyglass linter
        //  assert final ($onehot0(val_i)) else $error("val_i shall be onehot or zero");
`endif
    //  }}}
    end
endmodule
```
