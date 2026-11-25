# Implement `hpdcache_fifo_reg`

Implement the complete `hpdcache_fifo_reg` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_fifo_reg` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```systemverilog
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
```

## Parent instantiation

### `rtl/src/hpdcache_cmo.sv`

```systemverilog
        assign cmoh_flush_req_wdata = '{
            nline: {cmoh_flush_req_tag, cmoh_flush_req_set},
            way  :  cmoh_flush_req_way
        };

        hpdcache_fifo_reg #(
            .FIFO_DEPTH  (3),
            .FEEDTHROUGH (1'b1),
            .fifo_data_t (cmoh_flush_req_t)
        ) flush_req_fifo_i(
            .clk_i,
            .rst_ni,
            .w_i     (cmoh_flush_req_w),
            .wok_o   (cmoh_flush_req_wok),
            .wdata_i (cmoh_flush_req_wdata),
            .r_i     (flush_alloc_ready_i),
            .rok_o   (flush_alloc_o),
            .rdata_o (cmoh_flush_req_rdata)
        );

        assign flush_alloc_nline_o = cmoh_flush_req_rdata.nline;
        assign flush_alloc_way_o   = cmoh_flush_req_rdata.way;
```

### `rtl/src/hpdcache_flush.sv`

```systemverilog
    hpdcache_fifo_reg #(
        .FIFO_DEPTH     (2),
        .FEEDTHROUGH    (1'b0),
        .fifo_data_t    (hpdcache_mem_req_t)
    ) mem_req_meta_fifo_i(
        .clk_i,
        .rst_ni,
        .w_i            (flush_mem_req_w),
        .wok_o          (flush_mem_req_wok),
        .wdata_i        (flush_mem_req_wmeta),
        .r_i            (mem_req_write_ready_i),
        .rok_o          (mem_req_write_valid_o),
        .rdata_o        (mem_req_write_o)
    );
```

## Dependency declarations

### `rtl/src/common/hpdcache_sync_buffer.sv`

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

## Related source code

### `vendor/pulp-platform/common_cells/src/fifo_v3.sv`

```systemverilog
module fifo_v3 #(
    parameter bit          FALL_THROUGH = 1'b0, // fifo is in fall-through mode
    parameter int unsigned DATA_WIDTH   = 32,   // default data width if the fifo is of type logic
    parameter int unsigned DEPTH        = 8,    // depth can be arbitrary from 0 to 2**32
    parameter type dtype                = logic [DATA_WIDTH-1:0],
    // DO NOT OVERWRITE THIS PARAMETER
    parameter int unsigned ADDR_DEPTH   = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
    input  logic  clk_i,            // Clock
    input  logic  rst_ni,           // Asynchronous reset active low
    input  logic  flush_i,          // flush the queue
    input  logic  testmode_i,       // test_mode to bypass clock gating
    // status flags
    output logic  full_o,           // queue is full
    output logic  empty_o,          // queue is empty
    output logic  [ADDR_DEPTH-1:0] usage_o,  // fill pointer
    // as long as the queue is not full we can push new data
    input  dtype  data_i,           // data to push into the queue
    input  logic  push_i,           // data is valid and can be pushed to the queue
    // as long as the queue is not empty we can pop new elements
    output dtype  data_o,           // output data
    input  logic  pop_i             // pop head from queue
);
    // local parameter
    // FIFO depth - handle the case of pass-through, synthesizer will do constant propagation
    localparam int unsigned FifoDepth = (DEPTH > 0) ? DEPTH : 1;
// ...
    assign usage_o = status_cnt_q[ADDR_DEPTH-1:0];

    if (DEPTH == 0) begin : gen_pass_through
        assign empty_o     = ~push_i;
        assign full_o      = ~pop_i;
    end else begin : gen_fifo
        assign full_o       = (status_cnt_q == FifoDepth[ADDR_DEPTH:0]);
        assign empty_o      = (status_cnt_q == 0) & ~(FALL_THROUGH & push_i);
    end
    // status flags

    // read and write queue logic
    always_comb begin : read_write_comb
        // default assignment
        read_pointer_n  = read_pointer_q;
        write_pointer_n = write_pointer_q;
        status_cnt_n    = status_cnt_q;
        data_o          = (DEPTH == 0) ? data_i : mem_q[read_pointer_q];
        mem_n           = mem_q;
        gate_clock      = 1'b1;

        // push a new element to the queue
        if (push_i && ~full_o) begin
            // push the data onto the queue
            mem_n[write_pointer_q] = data_i;
            // un-gate the clock, we want to write something
            gate_clock = 1'b0;
            // increment the write counter
            // this is dead code when DEPTH is a power of two
            if (write_pointer_q == FifoDepth[ADDR_DEPTH-1:0] - 1)
                write_pointer_n = '0;
            else
                write_pointer_n = write_pointer_q + 1;
            // increment the overall counter
            status_cnt_n    = status_cnt_q + 1;
        end

        if (pop_i && ~empty_o) begin
            // read from the queue is a default assignment
            // but increment the read pointer...
            // this is dead code when DEPTH is a power of two
            if (read_pointer_n == FifoDepth[ADDR_DEPTH-1:0] - 1)
                read_pointer_n = '0;
            else
                read_pointer_n = read_pointer_q + 1;
            // ... and decrement the overall count
            status_cnt_n   = status_cnt_q - 1;
        end

        // keep the count pointer stable if we push and pop at the same time
        if (push_i && pop_i &&  ~full_o && ~empty_o)
            status_cnt_n   = status_cnt_q;

        // FIFO is in pass through mode -> do not change the pointers
        if (FALL_THROUGH && (status_cnt_q == 0) && push_i) begin
            data_o = data_i;
            if (pop_i) begin
                status_cnt_n = status_cnt_q;
                read_pointer_n = read_pointer_q;
                write_pointer_n = write_pointer_q;
            end
        end
    end
```
