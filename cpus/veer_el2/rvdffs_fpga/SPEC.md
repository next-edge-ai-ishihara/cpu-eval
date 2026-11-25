# Implement `rvdffs_fpga`

Implement the complete `rvdffs_fpga` module. Preserve the module name, parameters, and ports shown below. Return only the complete `module rvdffs_fpga` definition in a single SystemVerilog code block, with no text outside the block.

## CPU configuration used for evaluation

```text
     -fpga_optimize =   { 0, 1 }
          if 1, minimize clock-gating to facilitate FPGA builds
...
my $fpga_optimize = 1;

```

## Module declaration

```verilog
module rvdffs_fpga #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic             en,
     input logic           clk,
     input logic           clken,
     input logic           rawclk,
     input logic           rst_l,

     output logic [WIDTH-1:0] dout
     );

```

## Parent instantiation

### design/el2_dma_ctrl.sv

```verilog
`ifdef RV_FPGA_OPTIMIZE
   assign dma_bus_clk = 1'b0;
`else
   rvclkhdr  dma_bus_cgc (.en(dma_bus_clk_en), .l1clk(dma_bus_clk), .*);
`endif
// ...
   rvdffs_fpga   #(.WIDTH(pt.DMA_BUS_TAG)) wrbuf_tagff       (.din(dma_axi_awid[pt.DMA_BUS_TAG-1:0]), .dout(wrbuf_tag[pt.DMA_BUS_TAG-1:0]), .en(wrbuf_en), .clk(dma_bus_clk), .clken(dma_bus_clk_en), .rawclk(clk), .*);
   rvdffs_fpga   #(.WIDTH(3))              wrbuf_szff        (.din(dma_axi_awsize[2:0]),  .dout(wrbuf_sz[2:0]),     .en(wrbuf_en),                  .clk(dma_bus_clk), .clken(dma_bus_clk_en), .rawclk(clk), .*);
// ...
   rvdffs_fpga   #(.WIDTH(8))              wrbuf_byteenff    (.din(dma_axi_wstrb[7:0]),   .dout(wrbuf_byteen[7:0]), .en(wrbuf_data_en),             .clk(dma_bus_clk), .clken(dma_bus_clk_en), .rawclk(clk), .*);
// ...
   rvdffs_fpga   #(.WIDTH(pt.DMA_BUS_TAG)) rdbuf_tagff  (.din(dma_axi_arid[pt.DMA_BUS_TAG-1:0]), .dout(rdbuf_tag[pt.DMA_BUS_TAG-1:0]), .en(rdbuf_en), .clk(dma_bus_clk), .clken(dma_bus_clk_en), .rawclk(clk), .*);
   rvdffs_fpga   #(.WIDTH(3))              rdbuf_szff   (.din(dma_axi_arsize[2:0]),  .dout(rdbuf_sz[2:0]),    .en(rdbuf_en), .clk(dma_bus_clk), .clken(dma_bus_clk_en), .rawclk(clk), .*);
// ...
   rvdffs_fpga #(.WIDTH(1)) mstr_prtyff(.din(axi_mstr_prty_in), .dout(axi_mstr_priority), .en(axi_mstr_prty_en), .clk(dma_bus_clk), .clken(dma_bus_clk_en), .rawclk(clk), .*);

```

### design/ifu/el2_ifu_bp_ctl.sv

```verilog
          rvdffs_fpga #(2) bht_bank (.*,
                    .clk        (bht_bank_clk[i][k]),
                    .en         (bank_sel),
                    .rawclk     (clk),
                    .clken      (bank_sel),
                    .din        (wdata),
                    .dout       (bht_bank_rd_data_out[i][(16*k)+j]));

```

### design/ifu/el2_ifu_mem_ctl.sv

```verilog
`ifdef RV_FPGA_OPTIMIZE
   assign busclk_reset = 1'b0;
`else
   rvclkhdr bus_clk_reset(.en(bus_ifu_bus_clk_en | ic_act_miss_f | dec_tlu_force_halt), .l1clk(busclk_reset), .*);
`endif



   rvdffs_fpga #(pt.ICACHE_BEAT_BITS)  bus_cmd_beat_ff (.*, .clk(busclk_reset), .clken (bus_ifu_bus_clk_en | ic_act_miss_f | dec_tlu_force_halt), .rawclk(clk), .en (bus_cmd_beat_en), .din ({bus_new_cmd_beat_count[pt.ICACHE_BEAT_BITS-1:0]}),
                    .dout({bus_cmd_beat_count[pt.ICACHE_BEAT_BITS-1:0]}));
// ...
     `ifdef RV_FPGA_OPTIMIZE
        assign way_status_clk[i] = 1'b0;
     `else
           rvclkhdr way_status_cgc ( .en(way_status_clken[i]),   .l1clk(way_status_clk[i]), .* );
     `endif


      for (genvar j=0 ; j<8 ; j++) begin : WAY_STATUS
         rvdffs_fpga #(pt.ICACHE_STATUS_BITS) ic_way_status (.*,
                   .clk(way_status_clk[i]),
                   .clken(way_status_clken[i]),
                   .rawclk(clk),
                   .en(((ifu_status_wr_addr_ff[pt.ICACHE_TAG_INDEX_LO+2:pt.ICACHE_TAG_INDEX_LO] == j) & way_status_wr_en_ff)),
                   .din(way_status_new_ff[pt.ICACHE_STATUS_BITS-1:0]),
                   .dout(way_status_out[8*i+j]));
// ...
     `ifdef RV_FPGA_OPTIMIZE
        assign tag_valid_clk[i][j]  = 1'b0;
     `else
           rvclkhdr way_status_cgc ( .en(tag_valid_clken[i][j]),   .l1clk(tag_valid_clk[i][j]), .* );
     `endif



      for (genvar k=0 ; k<32 ; k++) begin : TAG_VALID
         rvdffs_fpga #(1) ic_way_tagvalid_dup (.*,
                   .clk(tag_valid_clk[i][j]),
                   .clken(tag_valid_clken[i][j]),
                   .rawclk(clk),
                   .en(((ifu_ic_rw_int_addr_ff[pt.ICACHE_INDEX_HI:pt.ICACHE_TAG_INDEX_LO] == (k + 32*i)) & ifu_tag_wren_ff[j] ) |
                       ((perr_ic_index_ff     [pt.ICACHE_INDEX_HI:pt.ICACHE_TAG_INDEX_LO] == (k + 32*i)) & perr_err_inv_way[j]) | reset_all_tags),
                   .din(ic_valid_ff & ~reset_all_tags & ~perr_sel_invalidate),
                   .dout(ic_tag_valid_out[j][32*i+k]));

```

### design/lsu/el2_lsu_bus_buffer.sv

```verilog
   rvdffs_fpga #(.WIDTH(pt.LSU_BUS_TAG)) obuf_tag0ff       (.din(obuf_tag0_in),                .dout(obuf_tag0),       .en(obuf_wr_en),                   .clk(lsu_bus_obuf_c1_clk), .clken(lsu_bus_obuf_c1_clken), .rawclk(clk), .*);
   rvdffs_fpga #(.WIDTH(pt.LSU_BUS_TAG)) obuf_tag1ff       (.din(obuf_tag1_in),                .dout(obuf_tag1),       .en(obuf_wr_en),                   .clk(lsu_bus_obuf_c1_clk), .clken(lsu_bus_obuf_c1_clken), .rawclk(clk), .*);
   rvdffs_fpga #(.WIDTH(1))              obuf_mergeff      (.din(obuf_merge_in),               .dout(obuf_merge),      .en(obuf_wr_en),                   .clk(lsu_bus_obuf_c1_clk), .clken(lsu_bus_obuf_c1_clken), .rawclk(clk), .*);
   rvdffs_fpga #(.WIDTH(1))              obuf_writeff      (.din(obuf_write_in),               .dout(obuf_write),      .en(obuf_wr_en),                   .clk(lsu_bus_obuf_c1_clk), .clken(lsu_bus_obuf_c1_clken), .rawclk(clk), .*);
   rvdffs_fpga #(.WIDTH(1))              obuf_sideeffectff (.din(obuf_sideeffect_in),          .dout(obuf_sideeffect), .en(obuf_wr_en),                   .clk(lsu_bus_obuf_c1_clk), .clken(lsu_bus_obuf_c1_clken), .rawclk(clk), .*);
   rvdffs_fpga #(.WIDTH(2))              obuf_szff         (.din(obuf_sz_in[1:0]),             .dout(obuf_sz),         .en(obuf_wr_en),                   .clk(lsu_bus_obuf_c1_clk), .clken(lsu_bus_obuf_c1_clken), .rawclk(clk), .*);
   rvdffs_fpga #(.WIDTH(8))              obuf_byteenff     (.din(obuf_byteen_in[7:0]),         .dout(obuf_byteen),     .en(obuf_wr_en),                   .clk(lsu_bus_obuf_c1_clk), .clken(lsu_bus_obuf_c1_clken), .rawclk(clk), .*);

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

if (SHORT == 1) begin : genblock
   assign dout = din;
end

// ...

```

## Documentation

### docs/source/clocks.md

All core complex flops are reset asynchronously.
