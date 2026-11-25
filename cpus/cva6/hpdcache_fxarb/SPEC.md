# Implement `hpdcache_fxarb`

Implement the complete `hpdcache_fxarb` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_fxarb` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

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
```

## Parent instantiation

### `rtl/src/hpdcache_core_arbiter.sv`

```systemverilog
    //      Arbiter
    hpdcache_fxarb #(.N(HPDcacheCfg.u.nRequesters)) req_arbiter_i
    (
        .clk_i,
        .rst_ni,
        .req_i          (core_req_valid),
        .gnt_o          (arb_req_gnt_d),
        .ready_i        (arb_req_ready_i)
    );

    //      Request multiplexor
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

### `rtl/src/utils/hpdcache_mem_req_read_arbiter.sv`

```systemverilog
    //  Fixed-priority arbiter
    hpdcache_fxarb #(
        .N                   (N)
    ) hpdcache_fxarb_mem_req_write_i (
        .clk_i,
        .rst_ni,
        .req_i               (mem_req_read_valid_i),
        .gnt_o               (mem_read_arb_req_gnt),
        .ready_i             (mem_req_read_ready_i)
    );
```

## Dependency declarations

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

## Related source code

### `vendor/pulp-platform/common_cells/src/stream_arbiter.sv`

```systemverilog
// Stream arbiter: Arbitrates a parametrizable number of input streams (i.e., valid-ready
// handshaking with dependency rules as in AXI4) to a single output stream.  Once `oup_valid_o` is
// asserted, `oup_data_o` remains invariant until the output handshake has occurred.  The
// arbitration scheme is round-robin with "look ahead", see the `rrarbiter` for details.

module stream_arbiter #(
    parameter type      DATA_T = logic,   // Vivado requires a default value for type parameters.
    parameter integer   N_INP = -1,       // Synopsys DC requires a default value for parameters.
    parameter           ARBITER = "rr"    // "rr" or "prio"
) (
    input  logic              clk_i,
    input  logic              rst_ni,

    input  DATA_T [N_INP-1:0] inp_data_i,
    input  logic  [N_INP-1:0] inp_valid_i,
    output logic  [N_INP-1:0] inp_ready_o,

    output DATA_T             oup_data_o,
    output logic              oup_valid_o,
    input  logic              oup_ready_i
);
```

### `vendor/pulp-platform/common_cells/src/rr_arb_tree.sv`

```systemverilog
  /// The `LockIn` option prevents the arbiter from changing the arbitration
  /// decision when the arbiter is disabled. I.e., the index of the first request
  /// that wins the arbitration will be locked in case the destination is not
  /// able to grant the request in the same cycle.
  ///
  /// Set to `1'b1` to enable.
  parameter bit          LockIn     = 1'b0,
// ...
      // lock arbiter decision in case we got at least one req and no acknowledge
      if (LockIn) begin : gen_lock
        logic  lock_d, lock_q;
        logic [NumIn-1:0] req_q;

        assign lock_d     = req_o & ~gnt_i;
        assign req_d      = (lock_q) ? req_q : req_i;

        always_ff @(posedge clk_i or negedge rst_ni) begin : p_lock_reg
          if (!rst_ni) begin
            lock_q <= '0;
          end else begin
            if (flush_i) begin
              lock_q <= '0;
            end else begin
              lock_q <= lock_d;
            end
          end
        end
```
