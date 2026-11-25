# Implement `hpdcache_sync_buffer`

Implement the complete `hpdcache_sync_buffer` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_sync_buffer` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

```systemverilog
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

```

## Parent instantiation

### `rtl/src/common/hpdcache_fifo_reg.sv`

```systemverilog
    /*
     *  Bypass: no buffering
     */
    if (FIFO_DEPTH == 0) begin : gen_bypass
        assign wok_o   = r_i;
        assign rok_o   = w_i;
        assign rdata_o = wdata_i;

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

```

## Related source code

### `rtl/src/common/hpdcache_fifo_reg.sv`

```systemverilog
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
// ...
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
