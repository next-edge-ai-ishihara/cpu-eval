# Implement `hpdcache_rrarb`

Implement the complete `hpdcache_rrarb` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_rrarb` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

```systemverilog
module hpdcache_rrarb
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

```

## Parent instantiation

### `rtl/src/hpdcache_rtab.sv`

```systemverilog
    //  Choose in a round-robin manner a ready transaction waiting for a conflict in the wbuf
    hpdcache_rrarb #(
        .N              (N)
    ) wbuf_rd_pending_arb_i (
        .clk_i,
        .rst_ni,
        .req_i          (wbuf_rd_pending),
        .gnt_o          (wbuf_rd_gnt),
        .ready_i        (wbuf_gnt[0] & wbuf_ready)
    );

```

## Dependency declarations

### `rtl/src/common/hpdcache_prio_1hot_encoder.sv`

```systemverilog
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

## Related source code

### `rtl/src/common/hpdcache_fxarb.sv`

```systemverilog
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

```

### `vendor/pulp-platform/common_cells/src/rr_arb_tree.sv`

```systemverilog
/// The rr_arb_tree employs non-starving round robin-arbitration - i.e., the priorities
/// rotate each cycle.
// ...
/// * `1'b1`: The next state jumps to the next unserved request with higher index.
///           This is achieved by using two trailing-zero-counters (`lzc`). The upper has the masked
///           `req_i` signal with all indices which will have a higher priority in the next state.
///           The trailing zero count defines the input index with the next highest priority after
///           the current one is served. When the upper is empty the lower `lzc` provides the
///           wrapped index if there are outstanding requests with lower or same priority.
// ...
  /// The `LockIn` option prevents the arbiter from changing the arbitration
  /// decision when the arbiter is disabled. I.e., the index of the first request
  /// that wins the arbitration will be locked in case the destination is not
  /// able to grant the request in the same cycle.
  ///
  /// Set to `1'b1` to enable.
  parameter bit          LockIn     = 1'b0,

```
