# Implement `hpdcache_mem_req_write_arbiter`

Implement the complete `hpdcache_mem_req_write_arbiter` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_mem_req_write_arbiter` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
module hpdcache_mem_req_write_arbiter
//  Parameters
//  {{{
#(
    parameter int unsigned N = 0,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic
)
//  }}}
//  Ports
//  {{{
(
    input  logic                        clk_i,
    input  logic                        rst_ni,

    output logic                [N-1:0] mem_req_write_ready_o,
    input  logic                [N-1:0] mem_req_write_valid_i,
    input  hpdcache_mem_req_t   [N-1:0] mem_req_write_i,

    output logic                [N-1:0] mem_req_write_data_ready_o,
    input  logic                [N-1:0] mem_req_write_data_valid_i,
    input  hpdcache_mem_req_w_t [N-1:0] mem_req_write_data_i,

    input  logic                        mem_req_write_ready_i,
    output logic                        mem_req_write_valid_o,
    output hpdcache_mem_req_t           mem_req_write_o,

    input  logic                        mem_req_write_data_ready_i,
    output logic                        mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t         mem_req_write_data_o
);
```

## Parent instantiation

### `rtl/src/hpdcache.sv`

```systemverilog
    //      Write request interface
    //
    //      There is a fixed-priority arbiter between:
    //      - the flush controller (higher priority)
    //      - the write buffer
    //      - the uncacheable request handler (lower priority)
    logic                [2:0] arb_mem_req_write_ready;
    logic                [2:0] arb_mem_req_write_valid;
    hpdcache_mem_req_t   [2:0] arb_mem_req_write;

    logic                [2:0] arb_mem_req_write_data_valid;
    logic                [2:0] arb_mem_req_write_data_ready;
    hpdcache_mem_req_w_t [2:0] arb_mem_req_write_data;
// ...
    assign mem_req_write_wbuf_ready        = arb_mem_req_write_ready[0];
    assign arb_mem_req_write_valid[0]      = mem_req_write_wbuf_valid;
    assign arb_mem_req_write[0]            = hpdcache_req_write_sel_id(mem_req_write_wbuf, 0);

    assign mem_req_write_wbuf_data_ready   = arb_mem_req_write_data_ready[0];
    assign arb_mem_req_write_data_valid[0] = mem_req_write_wbuf_data_valid;
    assign arb_mem_req_write_data[0]       = mem_req_write_wbuf_data;

    assign mem_req_write_flush_ready       = arb_mem_req_write_ready[1];
    assign arb_mem_req_write_valid[1]      = mem_req_write_flush_valid;
    assign arb_mem_req_write[1]            = hpdcache_req_write_sel_id(mem_req_write_flush, 1);

    assign mem_req_write_flush_data_ready  = arb_mem_req_write_data_ready[1];
    assign arb_mem_req_write_data_valid[1] = mem_req_write_flush_data_valid;
    assign arb_mem_req_write_data[1]       = mem_req_write_flush_data;

    assign mem_req_write_uc_ready          = arb_mem_req_write_ready[2];
    assign arb_mem_req_write_valid[2]      = mem_req_write_uc_valid;
    assign arb_mem_req_write[2]            = hpdcache_req_write_sel_id(mem_req_write_uc, 2);

    assign mem_req_write_uc_data_ready     = arb_mem_req_write_data_ready[2];
    assign arb_mem_req_write_data_valid[2] = mem_req_write_uc_data_valid;
    assign arb_mem_req_write_data[2]       = mem_req_write_uc_data;

    hpdcache_mem_req_write_arbiter #(
        .N                             (3),
        .hpdcache_mem_req_t            (hpdcache_mem_req_t),
        .hpdcache_mem_req_w_t          (hpdcache_mem_req_w_t)
    ) hpdcache_mem_req_write_arbiter_i (
        .clk_i,
        .rst_ni,

        .mem_req_write_ready_o         (arb_mem_req_write_ready),
        .mem_req_write_valid_i         (arb_mem_req_write_valid),
        .mem_req_write_i               (arb_mem_req_write),

        .mem_req_write_data_ready_o    (arb_mem_req_write_data_ready),
        .mem_req_write_data_valid_i    (arb_mem_req_write_data_valid),
        .mem_req_write_data_i          (arb_mem_req_write_data),

        .mem_req_write_ready_i,
        .mem_req_write_valid_o,
        .mem_req_write_o               (mem_req_write_o),

        .mem_req_write_data_ready_i,
        .mem_req_write_data_valid_o,
        .mem_req_write_data_o          (mem_req_write_data_o)
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

### `rtl/src/common/hpdcache_fifo_reg.sv`

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
// ...
    /*
     *  Single-entry buffer -> synchronization buffer
     */
    end else if (FIFO_DEPTH == 1) begin : gen_buffer
        hpdcache_sync_buffer #(
            .FEEDTHROUGH     (FEEDTHROUGH),
            .data_t          (fifo_data_t)
        ) i_sync_buffer (
            .clk_i,
            .rst_ni,
            .w_i,
            .wok_o,
            .wdata_i,
            .r_i,
            .rok_o,
            .rdata_o
        );

    /*
     *  Multi-entry FIFO buffer
     */
    end else if (FIFO_DEPTH > 1) begin : gen_fifo
        //  Declaration of internal wires and registers
        //  {{{
        fifo_data_t [FIFO_DEPTH-1:0] fifo_mem_q;
        fifo_addr_t rptr_q, rptr_d; // read pointer
        fifo_addr_t wptr_q, wptr_d; // write pointer
        logic       crossover_q, crossover_d; // write pointer has wrap
        logic       rexec, wexec;
        logic       rptr_max, wptr_max;
        logic       match_ptr;
        logic       empty, full;
        //  }}}

        //  Global control signals
        //  {{{
        assign match_ptr = (wptr_q == rptr_q);

        assign empty = match_ptr & ~crossover_q,
               full  = match_ptr &  crossover_q;

        assign rok_o = ~empty | (FEEDTHROUGH & w_i),
               wok_o = ~full  | (FEEDTHROUGH & r_i);

        assign rexec = r_i & ~empty,
               wexec = w_i & (( FEEDTHROUGH & ((empty & ~r_i) | (full & r_i) | (~full & ~empty))) |
                              (~FEEDTHROUGH & ~full));

        //  }}}

        //  Control of read and write pointers
        //  {{{
        assign rptr_max = (rptr_q == fifo_addr_t'(FIFO_DEPTH-1));
        assign wptr_max = (wptr_q == fifo_addr_t'(FIFO_DEPTH-1));

        always_comb
        begin : fifo_ctrl_comb
            rptr_d = rptr_q;
            wptr_d = wptr_q;
            crossover_d = crossover_q;

            if (rexec) begin
                rptr_d = rptr_max ? 0 : rptr_q + 1;
            end

            if (wexec) begin
                wptr_d = wptr_max ? 0 : wptr_q + 1;
            end

            if (wexec && wptr_max) begin
                crossover_d = 1'b1;
            end else if (rexec && rptr_max) begin
                crossover_d = 1'b0;
            end
        end
        //  }}}

        //  FIFO buffer memory management
        //  {{{
        always_ff @(posedge clk_i or negedge rst_ni)
        begin
            if (!rst_ni) begin
                fifo_mem_q <= '0;
            end else begin
                if (wexec) fifo_mem_q[wptr_q] <= wdata_i;
            end
        end

        assign rdata_o = FEEDTHROUGH && empty ? wdata_i : fifo_mem_q[rptr_q];
        //  }}}

        //  Setting of internal state
        //  {{{
        always_ff @(posedge clk_i or negedge rst_ni)
        begin
            if (!rst_ni) begin
                rptr_q      <= 0;
                wptr_q      <= 0;
                crossover_q <= 1'b0;
            end else begin
                rptr_q      <= rptr_d;
                wptr_q      <= wptr_d;
                crossover_q <= crossover_d;
            end
        end
        //  }}}
```

### `rtl/src/common/hpdcache_sync_buffer.sv`

```systemverilog
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : October, 2023
 *  Description   : Synchronization buffer
 *  History       :
 */
module hpdcache_sync_buffer
    //  Parameters
    //  {{{
#(
    parameter bit FEEDTHROUGH = 1'b0,
    parameter type data_t = logic
)
    //  }}}
    //  Ports
    //  {{{
(
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        w_i,
    output logic        wok_o,
    input  data_t       wdata_i,
    input  logic        r_i,
    output logic        rok_o,
    output data_t       rdata_o
);
    //  }}}

    //  Declaration of internal wires and registers
    //  {{{
    data_t      buf_q;
    logic       buf_we;
    logic       valid_q, valid_d;
    //  }}}

    //  Global control signals
    //  {{{
    assign rok_o  =  valid_q | (FEEDTHROUGH & w_i),
           wok_o  = ~valid_q | (FEEDTHROUGH & r_i);

    assign buf_we = w_i & ((FEEDTHROUGH & ~(valid_q ^ r_i)) | (~FEEDTHROUGH & ~valid_q));
    //  }}}

    //  Control of buffer
    //  {{{
    assign valid_d = buf_we | (valid_q & ~r_i);
    //  }}}

    //  FIFO buffer memory management
    //  {{{
    always_ff @(posedge clk_i or negedge rst_ni)
    begin
        if (!rst_ni) begin
            buf_q <= '0;
        end else begin
            if (buf_we) buf_q <= wdata_i;
        end
    end

    assign rdata_o = FEEDTHROUGH && !valid_q ? wdata_i : buf_q;
    //  }}}

    //  Setting of internal state
    //  {{{
    always_ff @(posedge clk_i or negedge rst_ni)
    begin
        if (!rst_ni) begin
            valid_q <= 1'b0;
        end else begin
            valid_q <= valid_d;
        end
    end
    //  }}}
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

## Documentation

### `docs/source/interface.rst`

```text
The source sets to 1 the **valid** signal to indicate when the payload is
available. The destination sets to 1 the **ready** signal to indicate that it
can accept that payload. Transfer occurs only when both the **valid** and
**ready** signals are set to 1 on the next rising edge of the clock.

A source is not permitted to wait until **ready** is set to 1 before setting
**valid** to 1.

A destination may or not wait for **valid** to set the **ready** to 1
(:numref:`cases (a) and (d) in Table %s <tab_ready_valid_scenarios>`).
In other words, a destination may set **ready** to 1 before an actual transfer
is available.

When **valid** is set to 1, the source must keep it that way until the
handshake occurs. This is, at the next rising edge when both **valid** and
**ready** (from the destination) are set to 1. In other words, a source cannot
retire a pending **valid** transfer
(:numref:`Case (b) in Table %s <tab_ready_valid_scenarios>`).

After an effective transfer (**valid** and **ready** set to 1), the source may
keep **valid** set to 1 in the next cycle to signal a new transfer (with a new
payload). In the same manner, the destination may keep **ready** set to 1 if it
can accept a new transfer. This allows back-to-back transfers, with no idle
cycles, between a source and a destination
(:numref:`Case (d) in Table %s <tab_ready_valid_scenarios>`).

All interfaces are synchronous to the rising edge of the same global
clock (``clk_i``).
...
   * - ``mem_req_write_valid_o``
     - Cache
     - Indicates that the channel is signaling a valid request
   * - ``mem_req_write_ready_i``
     - NoC
     - Indicates that the cache is ready to accept a response
...
   * - ``mem_req_write_data_valid_o``
     - Cache
     - Indicates that the channel is transferring a valid data
   * - ``mem_req_write_data_ready_i``
     - NoC
     - Indicates that the target is ready to accept the data
   * - ``mem_req_write_data_o.mem_req_w_data``
     - Cache
     - Request write data. It shall be naturally aligned to the request
       address
   * - ``mem_req_write_data_o.mem_req_w_be``
     - Cache
     - Request write byte-enable. It shall be naturally aligned to the request
       address
   * - ``mem_req_write_data_o.mem_req_w_last``
     - Cache
     - Indicates the last transfer in a write request burst
```
