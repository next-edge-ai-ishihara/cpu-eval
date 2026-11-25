# Implement `hpdcache_prio_1hot_encoder`

Implement the complete `hpdcache_prio_1hot_encoder` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_prio_1hot_encoder` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

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

```

## Parent instantiation

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

```

## Related source code

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

```

## Documentation

### `docs/source/overview.rst`

```text
- Fixed priority arbiter between requesters: the requester port with the lowest
  index has the highest priority.

```
