# Implement `el2_lsu_clkdomain`

Implement the complete `el2_lsu_clkdomain` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_lsu_clkdomain` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_lsu_clkdomain
import el2_pkg::*;
#(
`include "el2_param.vh"
)(
   input logic      clk,                               // Clock only while core active.  Through one clock header.  For flops with    second clock header built in.  Connected to ACTIVE_L2CLK.
   input logic      active_clk,                        // Clock only while core active.  Through two clock headers. For flops without second clock header built in.
   input logic      rst_l,                             // reset, active low
   input logic      dec_tlu_force_halt,                // This will be high till TLU goes to debug halt

   // Inputs
   input logic      clk_override,                      // chciken bit to turn off clock gating
   input logic      dma_dccm_req,                      // dma is active
   input logic      ldst_stbuf_reqvld_r,               // allocating in to the store queue

   input logic      stbuf_reqvld_any,                  // stbuf is draining
   input logic      stbuf_reqvld_flushed_any,          // instruction going to stbuf is flushed
   input logic      lsu_busreq_r,                      // busreq in r
   input logic      lsu_bus_buffer_pend_any,           // bus buffer has a pending bus entry
   input logic      lsu_bus_buffer_empty_any,          // external bus buffer is empty
   input logic      lsu_stbuf_empty_any,               // stbuf is empty

   input logic      lsu_bus_clk_en,                    // bus clock enable

   input el2_lsu_pkt_t  lsu_p,                        // lsu packet in decode
   input el2_lsu_pkt_t  lsu_pkt_d,                    // lsu packet in d
   input el2_lsu_pkt_t  lsu_pkt_m,                    // lsu packet in m
   input el2_lsu_pkt_t  lsu_pkt_r,                    // lsu packet in r

   // Outputs
   output logic     lsu_bus_obuf_c1_clken,             // obuf clock enable
   output logic     lsu_busm_clken,                    // bus clock enable

   output logic     lsu_c1_m_clk,                      // m pipe single pulse clock
   output logic     lsu_c1_r_clk,                      // r pipe single pulse clock

   output logic     lsu_c2_m_clk,                      // m pipe double pulse clock
   output logic     lsu_c2_r_clk,                      // r pipe double pulse clock

   output logic     lsu_store_c1_m_clk,                // store in m
   output logic     lsu_store_c1_r_clk,                // store in r

   output logic     lsu_stbuf_c1_clk,
   output logic     lsu_bus_obuf_c1_clk,               // ibuf clock
   output logic     lsu_bus_ibuf_c1_clk,               // ibuf clock
   output logic     lsu_bus_buf_c1_clk,                // ibuf clock
   output logic     lsu_busm_clk,                      // bus clock

   output logic     lsu_free_c2_clk,                   // free double pulse clock

   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic     scan_mode                          // Scan mode
   /*pragma coverage on*/
);
```

## Parent instantiation

```verilog
   el2_lsu_clkdomain #(.pt(pt)) clkdomain (.*);
```

## Dependency declarations

### design/include/el2_def.sv

```verilog
typedef struct packed {
                       logic fast_int;
/* verilator lint_off SYMRSVDWORD */
                       logic stack;
/* verilator lint_on SYMRSVDWORD */
                       logic by;
                       logic half;
                       logic word;
                       logic dword;  // for dma
                       logic load;
                       logic store;
                       logic unsign;
                       logic dma;    // dma pkt
                       logic store_data_bypass_d;
                       logic load_ldst_bypass_d;
                       logic store_data_bypass_m;
                       logic valid;
                       } el2_lsu_pkt_t;
```

### design/lib/beh_lib.sv

```verilog
module rvdff #( parameter WIDTH=1, SHORT=0 )
   (
     input logic [WIDTH-1:0] din,
     input logic           clk,
     input logic                   rst_l,

     output logic [WIDTH-1:0] dout
     );
// ...
module rvclkhdr
  (
   input  logic en,
   input  logic clk,
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic scan_mode,
   /*pragma coverage on*/
   output logic l1clk
   );
// ...
module rvoclkhdr
  (
   input  logic en,
   input  logic clk,
   // Excluding scan_mode from coverage as its usage is determined by the integrator of the VeeR core.
   /*pragma coverage off*/
   input  logic scan_mode,
   /*pragma coverage on*/
   output logic l1clk
   );
```

## Related source code

### design/lsu/el2_lsu_lsc_ctl.sv

```verilog
   always_comb begin
      lsu_pkt_d = dec_lsu_valid_raw_d ? lsu_p : dma_pkt_d;
      lsu_pkt_m_in = lsu_pkt_d;
      lsu_pkt_r_in = lsu_pkt_m;

      lsu_pkt_d.valid = (lsu_p.valid & ~(flush_m_up & ~lsu_p.fast_int)) | dma_dccm_req;
      lsu_pkt_m_in.valid = lsu_pkt_d.valid & ~(flush_m_up & ~lsu_pkt_d.dma);
      lsu_pkt_r_in.valid = lsu_pkt_m.valid & ~(flush_m_up & ~lsu_pkt_m.dma) ;
   end

   // C2 clock for valid and C1 for other bits of packet
   rvdff #(1) lsu_pkt_vldmff (.*, .din(lsu_pkt_m_in.valid), .dout(lsu_pkt_m.valid), .clk(lsu_c2_m_clk));
   rvdff #(1) lsu_pkt_vldrff (.*, .din(lsu_pkt_r_in.valid), .dout(lsu_pkt_r.valid), .clk(lsu_c2_r_clk));

   rvdff #($bits(el2_lsu_pkt_t)-1) lsu_pkt_mff (.*, .din(lsu_pkt_m_in[$bits(el2_lsu_pkt_t)-1:1]), .dout(lsu_pkt_m[$bits(el2_lsu_pkt_t)-1:1]), .clk(lsu_c1_m_clk));
   rvdff #($bits(el2_lsu_pkt_t)-1) lsu_pkt_rff (.*, .din(lsu_pkt_r_in[$bits(el2_lsu_pkt_t)-1:1]), .dout(lsu_pkt_r[$bits(el2_lsu_pkt_t)-1:1]), .clk(lsu_c1_r_clk));
// ...
   rvdff #(32)  sdmff (.*, .din(store_data_m_in[31:0]), .dout(store_data_pre_m[31:0]),                       .clk(lsu_store_c1_m_clk));

   rvdff #(32) samff (.*, .din(lsu_addr_d[31:0]), .dout(lsu_addr_m[31:0]), .clk(lsu_c1_m_clk));
   rvdff #(32) sarff (.*, .din(lsu_addr_m[31:0]), .dout(lsu_addr_r[31:0]), .clk(lsu_c1_r_clk));
```

### design/lsu/el2_lsu_dccm_ctl.sv

```verilog
      rvdff #(1)   dccm_wren_ff       (.*, .din(lsu_stbuf_commit_any),  .dout(dccm_wren_Q),             .clk(lsu_free_c2_clk));   // ECC load errors writing to dccm shouldn't fwd to stores in pipe
// ...
      rvdff #(32)  store_data_rff     (.*, .din(store_data_m[31:0]),    .dout(store_data_r[31:0]),      .clk(lsu_store_c1_r_clk));
// ...
      rvdff #(1) dccm_rden_mff (.*, .din(lsu_dccm_rden_d), .dout(lsu_dccm_rden_m), .clk(lsu_c2_m_clk));
      rvdff #(1) dccm_rden_rff (.*, .din(lsu_dccm_rden_m), .dout(lsu_dccm_rden_r), .clk(lsu_c2_r_clk));
// ...
      rvdff #(1) ld_double_ecc_error_rff    (.*, .din(lsu_double_ecc_error_r),   .dout(lsu_double_ecc_error_r_ff),   .clk(lsu_free_c2_clk));
      rvdff #(1) ld_single_ecc_error_hi_rff (.*, .din(ld_single_ecc_error_hi_r_ns), .dout(ld_single_ecc_error_hi_r_ff), .clk(lsu_free_c2_clk));
      rvdff #(1) ld_single_ecc_error_lo_rff (.*, .din(ld_single_ecc_error_lo_r_ns), .dout(ld_single_ecc_error_lo_r_ff), .clk(lsu_free_c2_clk));
```

### design/lsu/el2_lsu_stbuf.sv

```verilog
         rvdffsc #(.WIDTH(1))              stbuf_vldff         (.din(1'b1),                                .dout(stbuf_vld[i]),                      .en(stbuf_wr_en[i]), .clear(stbuf_reset[i]), .clk(lsu_free_c2_clk), .*);
         rvdffsc #(.WIDTH(1))              stbuf_killff        (.din(1'b1),                                .dout(stbuf_dma_kill[i]),                 .en(stbuf_dma_kill_en[i]), .clear(stbuf_reset[i]), .clk(lsu_free_c2_clk), .*);
// ...
         rvdffsc #(.WIDTH(BYTE_WIDTH))     stbuf_byteenff      (.din(stbuf_byteenin[i][BYTE_WIDTH-1:0]),   .dout(stbuf_byteen[i][BYTE_WIDTH-1:0]),   .en(stbuf_wr_en[i]), .clear(stbuf_reset[i]), .clk(lsu_stbuf_c1_clk), .*);
// ...
   // Flops
   rvdffs #(.WIDTH(DEPTH_LOG2)) WrPtrff (.din(NxtWrPtr[DEPTH_LOG2-1:0]), .dout(WrPtr[DEPTH_LOG2-1:0]), .en(WrPtrEn), .clk(lsu_stbuf_c1_clk), .*);
   rvdffs #(.WIDTH(DEPTH_LOG2)) RdPtrff (.din(NxtRdPtr[DEPTH_LOG2-1:0]), .dout(RdPtr[DEPTH_LOG2-1:0]), .en(RdPtrEn), .clk(lsu_stbuf_c1_clk), .*);
```

### design/lsu/el2_lsu_bus_buffer.sv

```verilog
   rvdffsc #(.WIDTH(1))              ibuf_valid_ff     (.din(1'b1),                      .dout(ibuf_valid),      .en(ibuf_wr_en), .clear(ibuf_rst), .clk(lsu_free_c2_clk), .*);
   rvdffs  #(.WIDTH(DEPTH_LOG2))     ibuf_tagff        (.din(ibuf_tag_in),               .dout(ibuf_tag),        .en(ibuf_wr_en),                   .clk(lsu_bus_ibuf_c1_clk), .*);
// ...
   rvdff   #(.WIDTH(TIMER_LOG2))     ibuf_timerff      (.din(ibuf_timer_in),             .dout(ibuf_timer),                                         .clk(lsu_free_c2_clk),     .*);
// ...
   rvdff_fpga  #(.WIDTH(1))              obuf_wren_ff      (.din(obuf_wr_en),                  .dout(obuf_wr_enQ),                                        .clk(lsu_busm_clk),        .clken(lsu_busm_clken), .rawclk(clk),        .*);
   rvdffsc     #(.WIDTH(1))              obuf_valid_ff     (.din(1'b1),                        .dout(obuf_valid),      .en(obuf_wr_en), .clear(obuf_rst), .clk(lsu_free_c2_clk),                                                  .*);
   rvdffs      #(.WIDTH(1))              obuf_nosend_ff    (.din(obuf_nosend_in),              .dout(obuf_nosend),     .en(obuf_wr_en),                   .clk(lsu_free_c2_clk),                                                  .*);
// ...
   rvdffs_fpga #(.WIDTH(pt.LSU_BUS_TAG)) obuf_tag0ff       (.din(obuf_tag0_in),                .dout(obuf_tag0),       .en(obuf_wr_en),                   .clk(lsu_bus_obuf_c1_clk), .clken(lsu_bus_obuf_c1_clken), .rawclk(clk), .*);
   rvdffs_fpga #(.WIDTH(pt.LSU_BUS_TAG)) obuf_tag1ff       (.din(obuf_tag1_in),                .dout(obuf_tag1),       .en(obuf_wr_en),                   .clk(lsu_bus_obuf_c1_clk), .clken(lsu_bus_obuf_c1_clken), .rawclk(clk), .*);
// ...
      rvdffs  #(.WIDTH($bits(state_t))) buf_state_ff     (.din(buf_nxtstate[i]),             .dout({buf_state[i]}),    .en(buf_state_en[i]),                                        .clk(lsu_bus_buf_c1_clk), .*);
      rvdff   #(.WIDTH(DEPTH))          buf_ageff        (.din(buf_age_in[i]),               .dout(buf_ageQ[i]),                                                                    .clk(lsu_bus_buf_c1_clk), .*);
      rvdff   #(.WIDTH(DEPTH))          buf_rspageff     (.din(buf_rspage_in[i]),            .dout(buf_rspageQ[i]),                                                                 .clk(lsu_bus_buf_c1_clk), .*);
// ...
   rvdff_fpga #(.WIDTH(1))               lsu_axi_awvalid_ff (.din(lsu_axi_awvalid),                .dout(lsu_axi_awvalid_q),                .clk(lsu_busm_clk), .clken(lsu_busm_clken), .rawclk(clk), .*);
// ...
   rvdff #(.WIDTH(DEPTH_LOG2)) lsu_WrPtr0_rff (.din(WrPtr0_m), .dout(WrPtr0_r), .clk(lsu_c2_r_clk), .*);
   rvdff #(.WIDTH(DEPTH_LOG2)) lsu_WrPtr1_rff (.din(WrPtr1_m), .dout(WrPtr1_r), .clk(lsu_c2_r_clk), .*);

   rvdff #(.WIDTH(1)) lsu_busreq_rff (.din(lsu_busreq_m & ~flush_r & ~ld_full_hit_m),      .dout(lsu_busreq_r), .clk(lsu_c2_r_clk), .*);
   rvdff #(.WIDTH(1)) lsu_nonblock_load_valid_rff  (.din(lsu_nonblock_load_valid_m),  .dout(lsu_nonblock_load_valid_r), .clk(lsu_c2_r_clk), .*);
```
