# Implement `hpdcache_1hot_to_binary`

Implement the complete `hpdcache_1hot_to_binary` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_1hot_to_binary` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
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

```

## Parent instantiation

### `rtl/src/hpdcache_ctrl.sv`

```systemverilog
    hpdcache_1hot_to_binary #(
        .N     (HPDcacheCfg.u.ways)
    ) dir_hit_way_encoder_i(
        .val_i (st1_dir_hit_way),
        .val_o (st1_dir_hit_way_index)
    );

    hpdcache_1hot_to_binary #(
        .N     (HPDcacheCfg.u.ways)
    ) refill_way_encoder_i(
        .val_i (refill_way_i),
        .val_o (refill_way_index)
    );

```

### `rtl/src/utils/hpdcache_mem_req_read_arbiter.sv`

```systemverilog
    //  Forward the grant index
    hpdcache_1hot_to_binary #(.N(N)) i_gnt_encoder(
        .val_i (mem_read_arb_req_gnt),
        .val_o (gnt_index_o)
    );

```

## Additional requirement

When `val_i` is zero, `val_o` is zero.
