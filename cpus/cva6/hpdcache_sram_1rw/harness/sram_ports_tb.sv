// SPDX-License-Identifier: Apache-2.0
module tb;
  logic clk = 0;
  logic rst_n = 1;
  logic cs, we;
  logic [5:0] addr;
  logic [27:0] wdata, rdata;

  hpdcache_sram_1rw #(
    .ADDR_SIZE(6), .DATA_SIZE(28), .DEPTH(64), .NDATA(1)
  ) dut (.*);

  task automatic tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  task automatic write_word(input logic [5:0] address, input logic [27:0] data, input logic selected);
    cs = selected;
    we = 1;
    addr = address;
    wdata = data;
    tick();
  endtask

  task automatic check_read(input string label, input logic [27:0] expected);
    if (rdata !== expected)
      $fatal(1, "SRAM_MISMATCH %s expected=%07h observed=%07h", label, expected, rdata);
    $display("READ %s %07h", label, rdata);
  endtask

  initial begin
    write_word(6'd0, 28'h13579bd, 1);
    write_word(6'd32, 28'h2468ace, 1);
    cs = 1;
    we = 0;
    addr = 0;
    tick();
    check_read("lower-address", 28'h13579bd);

    addr = 32;
    #1;
    check_read("before-read-edge", 28'h13579bd);
    tick();
    check_read("upper-address", 28'h2468ace);

    write_word(6'd32, 28'h55aa33c, 0);
    cs = 1;
    we = 0;
    tick();
    check_read("after-unselected-write", 28'h2468ace);
    $display("SRAM_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
