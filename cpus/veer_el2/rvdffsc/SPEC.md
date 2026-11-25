# Implement `rvdffsc`

Implement the complete `rvdffsc` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module rvdffsc` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module rvdffsc #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic             clear,
     input logic           clk,
     input logic                   rst_l,
     output logic [WIDTH-1:0] dout
     );

```

## Parent instantiation

### design/el2_dma_ctrl.sv

```verilog
      rvdffsc #(1) fifo_valid_dff (.din(1'b1), .dout(fifo_valid[i]), .en(fifo_cmd_en[i]), .clear(fifo_reset[i]), .clk(dma_free_clk), .*);
      rvdffsc #(2) fifo_error_dff (.din(fifo_error_in[i]), .dout(fifo_error[i]), .en(fifo_error_en[i]), .clear(fifo_reset[i]), .clk(dma_free_clk), .*);
      rvdffsc #(1) fifo_error_bus_dff (.din(1'b1), .dout(fifo_error_bus[i]), .en(fifo_error_bus_en[i]), .clear(fifo_reset[i]), .clk(dma_free_clk), .*);
      rvdffsc #(1) fifo_rpend_dff (.din(1'b1), .dout(fifo_rpend[i]), .en(fifo_pend_en[i]), .clear(fifo_reset[i]), .clk(dma_free_clk), .*);
      rvdffsc #(1) fifo_done_dff (.din(1'b1), .dout(fifo_done[i]), .en(fifo_done_en[i]), .clear(fifo_reset[i]), .clk(dma_free_clk), .*);
      rvdffsc #(1) fifo_done_bus_dff (.din(1'b1), .dout(fifo_done_bus[i]), .en(fifo_done_bus_en[i]), .clear(fifo_reset[i]), .clk(dma_free_clk), .*);

```

### design/lsu/el2_lsu_bus_buffer.sv

```verilog
   rvdffsc #(.WIDTH(1))              ibuf_valid_ff     (.din(1'b1),                      .dout(ibuf_valid),      .en(ibuf_wr_en), .clear(ibuf_rst), .clk(lsu_free_c2_clk), .*);
// ...
   rvdffsc     #(.WIDTH(1))              obuf_valid_ff     (.din(1'b1),                        .dout(obuf_valid),      .en(obuf_wr_en), .clear(obuf_rst), .clk(lsu_free_c2_clk),                                                  .*);
// ...
      rvdffsc #(.WIDTH(1))              buf_errorff      (.din(1'b1),                        .dout(buf_error[i]),      .en(buf_error_en[i]),                    .clear(buf_rst[i]), .clk(lsu_bus_buf_c1_clk), .*);

```

### design/lsu/el2_lsu_dccm_ctl.sv

```verilog
      rvdffsc #(.WIDTH(1)) dccm_wr_rdbk_pend_ffi
         (.din(1'b1), .dout(dccm_wr_rdbk_pend_ff),
          .en(dccm_wr_rdbk_arm), .clear(dccm_wr_rdbk_resolve), .clk(clk), .*);
// ...
      rvdffsc #(.WIDTH(1)) dccm_wr_rdbk_fault_valid_ffi
         (.din(1'b1), .dout(dccm_wr_rdbk_fault_valid),
          .en(dccm_wr_rdbk_fault_capture_en), .clear(dccm_wr_rdbk_fault_clear), .clk(clk), .*);

```

### design/lsu/el2_lsu_stbuf.sv

```verilog
         rvdffsc #(.WIDTH(1))              stbuf_vldff         (.din(1'b1),                                .dout(stbuf_vld[i]),                      .en(stbuf_wr_en[i]), .clear(stbuf_reset[i]), .clk(lsu_free_c2_clk), .*);
         rvdffsc #(.WIDTH(1))              stbuf_killff        (.din(1'b1),                                .dout(stbuf_dma_kill[i]),                 .en(stbuf_dma_kill_en[i]), .clear(stbuf_reset[i]), .clk(lsu_free_c2_clk), .*);
// ...
         rvdffsc #(.WIDTH(BYTE_WIDTH))     stbuf_byteenff      (.din(stbuf_byteenin[i][BYTE_WIDTH-1:0]),   .dout(stbuf_byteen[i][BYTE_WIDTH-1:0]),   .en(stbuf_wr_en[i]), .clear(stbuf_reset[i]), .clk(lsu_stbuf_c1_clk), .*);

```

### design/lib/beh_lib.sv

```verilog
   rvdffsc #(WIDTH)   dffsc (.*);

```

## Dependency declarations

```verilog
module rvdff #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic                   rst_l,

     output logic [WIDTH-1:0] dout
     );

// ...
// rvdff with 2:1 input mux to flop din iff sel==1
module rvdffs #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic                   rst_l,
     output logic [WIDTH-1:0] dout
     );

```

## Documentation

### docs/source/clocks.md

All core complex flops are reset asynchronously.

## Additional requirement

When `clear` is high at a rising edge of `clk`, that edge loads zero into all `WIDTH` bits of `dout` even if `en` is also high.
