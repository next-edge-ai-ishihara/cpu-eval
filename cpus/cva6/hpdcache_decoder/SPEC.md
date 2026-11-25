# Implement `hpdcache_decoder`

Implement the complete `hpdcache_decoder` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_decoder` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
module hpdcache_decoder
    //  Parameters
    //  {{{
#(
    parameter  int unsigned N     = 0,
    localparam int unsigned Pow2N = 2**N,
    localparam type in_t  = logic unsigned [N-1:0],
    localparam type out_t = logic unsigned [Pow2N-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    input  logic   en_i,
    input  in_t    val_i,
    output out_t   val_o
);
```

## Parent instantiation

### `rtl/src/hpdcache_flush.sv`

```systemverilog
    //  Acknowledgement interface
    assign flush_ack = mem_resp_write_valid_i;
    assign flush_dir_ack_ptr = flush_dir_index_t'(mem_resp_write_i.mem_resp_w_id);
// ...
    //  Directory valid
    assign flush_dir_alloc_bv = flush_dir_free_bv & {FlushEntries{flush_alloc}};

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : flush_dir_valid_ff
        if (!rst_ni) begin
            flush_dir_valid_q <= '0;
        end else begin
            flush_dir_valid_q <= (~flush_dir_valid_q &  flush_dir_alloc_bv) |
                                 ( flush_dir_valid_q & ~flush_dir_ack_bv  );
        end
    end
// ...
    hpdcache_decoder #(.N(FlushIndexWidth)) flush_ack_decoder_i(
        .en_i           (flush_ack),
        .val_i          (flush_dir_ack_ptr),
        .val_o          (flush_dir_ack_dec)
    );

    assign flush_dir_ack_bv = flush_dir_ack_dec[FlushEntries-1:0];
```

### `rtl/src/hpdcache_victim_random.sv`

```systemverilog
    hpdcache_decoder #(.N(HPDcacheCfg.wayIndexWidth))
        rand_way_decoder_i(
            .en_i      (1'b1),
            .val_i     (lfsr_val[0 +: HPDcacheCfg.wayIndexWidth]),
            .val_o     (rand_victim_way)
        );
```
