# Implement `hpdcache_lfsr`

Implement the complete `hpdcache_lfsr` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_lfsr` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
module hpdcache_lfsr
//  Parameters
//  {{{
#(
    parameter int WIDTH = 8,

    localparam type data_t = logic [WIDTH-1:0]
)
//  }}}

//  Ports
//  {{{
(
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        shift_i,
    output data_t       val_o
);
```

## Parent instantiation

### `rtl/src/hpdcache_victim_random.sv`

```systemverilog
    logic [7:0]   lfsr_val;
// ...
    hpdcache_lfsr #(.WIDTH(8))
        lfsr_i(
            .clk_i,
            .rst_ni,
            .shift_i   (sel_victim_i & ~unused_available & rand_available),
            .val_o     (lfsr_val)
        );

    hpdcache_decoder #(.N(HPDcacheCfg.wayIndexWidth))
        rand_way_decoder_i(
            .en_i      (1'b1),
            .val_i     (lfsr_val[0 +: HPDcacheCfg.wayIndexWidth]),
            .val_o     (rand_victim_way)
        );
```

## Additional requirement

A low `rst_ni` asynchronously sets `val_o` to all ones, and each rising edge of `clk_i` with `shift_i` set advances `val_o` by one step of a maximal-length linear feedback shift register that visits all `2**WIDTH - 1` nonzero values before it returns to all ones, while `val_o` holds its value when `shift_i` is clear.
