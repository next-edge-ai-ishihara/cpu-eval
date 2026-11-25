// SPDX-License-Identifier: Apache-2.0
module tb;
  logic clk = 0;
  logic rst_n = 0;
  logic cs, we;
  logic [79:0] wdata, rdata;
  logic [9:0] wbyteenable;

  hpdcache_regbank_wbyteenable_1rw #(
    .ADDR_SIZE(1), .DATA_SIZE(80), .DEPTH(1)
  ) dut (.clk, .rst_n, .cs, .we, .addr(1'b0), .wdata, .wbyteenable, .rdata);

  task automatic tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  task automatic write_word(input logic [79:0] data, input logic [9:0] mask);
    cs = 1;
    we = 1;
    wdata = data;
    wbyteenable = mask;
    tick();
  endtask

  task automatic check_read(input string label, input logic [79:0] expected);
    cs = 1;
    we = 0;
    tick();
    if (rdata !== expected)
      $fatal(1, "REGBANK_MISMATCH %s expected=%020h observed=%020h", label, expected, rdata);
    $display("READ %s %020h", label, rdata);
  endtask

  initial begin
    cs = 0;
    we = 0;
    wdata = '0;
    wbyteenable = '0;
    tick();
    rst_n = 1;
    write_word(80'h01_02_03_04_05_06_07_08_09_0a, 10'b11111_11111);
    check_read("full", 80'h01_02_03_04_05_06_07_08_09_0a);
    write_word(80'h11_12_13_14_15_16_17_18_19_1a, 10'b00000_11111);
    check_read("way-zero", 80'h01_02_03_04_05_16_17_18_19_1a);
    write_word(80'h21_22_23_24_25_26_27_28_29_2a, 10'b11111_00000);
    check_read("way-one", 80'h21_22_23_24_25_16_17_18_19_1a);
    write_word(80'h31_32_33_34_35_36_37_38_39_3a, 10'b10101_01010);
    check_read("separate-bytes", 80'h31_22_33_24_35_16_37_18_39_1a);
    write_word('1, '0);
    check_read("mask-zero", 80'h31_22_33_24_35_16_37_18_39_1a);
    $display("REGBANK_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
