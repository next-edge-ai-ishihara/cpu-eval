`timescale 1ns/1ps
module pic_port_probe;
  import el2_pkg::*;
  `include "el2_param.vh"
;
  logic clk = 0;
  wire free_clk = clk;
  logic rst_l = 0;
  logic clk_override = 1;
  logic io_clk_override = 1;
  logic [pt.PIC_TOTAL_INT_PLUS1-1:0] extintsrc_req = 0;
  logic [31:0] picm_rdaddr = 0;
  logic [31:0] picm_wraddr = 0;
  logic [31:0] picm_wr_data = 0;
  logic picm_wren = 0;
  logic picm_rden = 0;
  logic picm_mken = 0;
  logic [3:0] meicurpl = 0;
  logic [3:0] meipt = 0;
  logic mexintpend;
  logic [7:0] claimid;
  logic [3:0] pl;
  logic [31:0] picm_rd_data;
  logic mhwakeup;
  logic scan_mode = 0;
  always #5 clk = ~clk;
  el2_pic_ctrl #(.pt(pt)) dut (.*);

  task automatic cycles(input integer count);
    repeat (count) @(negedge clk);
  endtask

  task automatic reset_pic;
    @(negedge clk);
    rst_l = 0;
    extintsrc_req = '0;
    picm_wren = 0;
    picm_rden = 0;
    picm_mken = 0;
    meipt = 0;
    meicurpl = 0;
    cycles(3);
    rst_l = 1;
    cycles(3);
  endtask

  task automatic raw_write(input logic [31:0] offset,
                           input logic [31:0] value);
    @(negedge clk);
    picm_wraddr = pt.PIC_BASE_ADDR + offset;
    picm_wr_data = value;
    picm_wren = 1;
    @(negedge clk);
    picm_wren = 0;
    cycles(3);
  endtask

  task automatic write_register(input logic [31:0] offset,
                                input logic [31:0] value);
    logic [31:0] masked_store;
    @(negedge clk);
    picm_rdaddr = pt.PIC_BASE_ADDR + offset;
    picm_mken = 1;
    @(posedge clk); #1;
    masked_store = value & picm_rd_data;
    @(negedge clk);
    picm_mken = 0;
    // Advance the masked M-stage store to R before requesting a write.
    @(posedge clk); #1;
    @(negedge clk);
    picm_wraddr = pt.PIC_BASE_ADDR + offset;
    picm_wr_data = masked_store;
    picm_wren = 1;
    @(negedge clk);
    picm_wren = 0;
    cycles(3);
  endtask

  task automatic read_check(input logic [31:0] offset,
                            input logic [31:0] expected);
    @(negedge clk);
    picm_rdaddr = pt.PIC_BASE_ADDR + offset;
    picm_rden = 1;
    @(posedge clk); #1;
    if (picm_rd_data !== expected)
      $fatal(1, "PIC read offset=%h expected=%h actual=%h",
             offset, expected, picm_rd_data);
    @(negedge clk);
    picm_rden = 0;
  endtask

  task automatic register_check(input logic [31:0] offset,
                                input logic [31:0] writable_bits);
    write_register(offset, 32'hffffffff);
    read_check(offset, writable_bits);
    write_register(offset, 0);
    read_check(offset, 0);
    // DMA writes bypass the LSU store mask.
    raw_write(offset, 32'hffffffff);
    read_check(offset, writable_bits);
    raw_write(offset, 0);
    read_check(offset, 0);
  endtask

  task automatic unused_check(input logic [31:0] offset);
    write_register(offset, 32'hffffffff);
    read_check(offset, 0);
    raw_write(offset, 32'hffffffff);
    read_check(offset, 0);
    for (integer source=1; source<=pt.PIC_TOTAL_INT; source++) begin
      read_check(4*source, 5);
      read_check(32'h2000+4*source, 0);
      read_check(32'h4000+4*source, 0);
    end
    read_check(32'h3000, 0);
    read_check(32'h1000, 0);
  endtask

  task automatic clear_check(input logic [31:0] value,
                             input logic bypass_mask);
    @(negedge clk);
    extintsrc_req[1] = 1;
    cycles(10);
    extintsrc_req[1] = 0;
    cycles(10);
    read_check(32'h1000, 2);
    read_check(32'h5004, 0);
    read_check(32'h1000, 2);
    if (bypass_mask)
      raw_write(32'h5004, value);
    else
      write_register(32'h5004, value);
    cycles(10);
    read_check(32'h1000, 0);
    read_check(32'h5004, 0);
  endtask

  initial begin
    reset_pic();
    for (integer source=1; source<=pt.PIC_TOTAL_INT; source++) begin
      register_check(4*source, 32'hf);
      register_check(32'h2000+4*source, 1);
      register_check(32'h4000+4*source, 3);
      read_check(32'h5000+4*source, 0);
    end
    register_check(32'h3000, 1);

    reset_pic();
    for (integer source=1; source<=pt.PIC_TOTAL_INT; source++)
      write_register(4*source, 5);
    unused_check(0);
    unused_check(32'h2000);
    unused_check(32'h4000);
    unused_check(32'h5000);
    unused_check(4*(pt.PIC_TOTAL_INT+1));
    unused_check(32'h2000+4*(pt.PIC_TOTAL_INT+1));
    unused_check(32'h4000+4*(pt.PIC_TOTAL_INT+1));
    unused_check(32'h5000+4*(pt.PIC_TOTAL_INT+1));
    unused_check(32'h6000);
    unused_check(32'h7ffc);
    write_register(32'h1000, 32'hffffffff);
    read_check(32'h1000, 0);
    raw_write(32'h1000, 32'hffffffff);
    read_check(32'h1000, 0);

    reset_pic();
    write_register(32'h4004, 2);
    write_register(32'h2004, 1);
    clear_check(0, 0);
    clear_check(32'hffffffff, 0);
    clear_check(32'hffffffff, 1);
    $display("PASS PIC masked stores and register behavior");

    reset_pic();
    write_register(4, 15);
    write_register(32'h2004, 1);
    meipt = 14; meicurpl = 15;
    extintsrc_req[1] = 1;
    cycles(10);
    if (!mhwakeup || mexintpend || claimid != 1 || pl != 15)
      $fatal(1, "current handler priority must block interrupt admission without blocking wakeup");
    meipt = 14; meicurpl = 14;
    cycles(10);
    if (!mhwakeup || !mexintpend || claimid != 1 || pl != 15)
      $fatal(1, "highest-priority interrupt was not admitted below both thresholds");
    extintsrc_req[1] = 0;
    cycles(10);
    write_register(32'h3000, 1);
    write_register(4, 0);
    meipt = 0; meicurpl = 0;
    extintsrc_req[1] = 1;
    cycles(10);
    if (!mhwakeup || mexintpend || claimid != 1 || pl != 0)
      $fatal(1, "reverse highest-priority wakeup must not depend on interrupt threshold admission");
    $display("PASS normal and reverse highest-priority wakeup independent of thresholds");
    $display("PIC_PORT_DIAGNOSTIC_PASS"); $finish;
  end
  // The reference passes at 56,150 ns; the watchdog is 17 times that.
  initial begin #1000000; $fatal(1, "PIC diagnostic watchdog"); end
endmodule
