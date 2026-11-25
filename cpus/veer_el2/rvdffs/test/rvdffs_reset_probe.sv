// SPDX-License-Identifier: Apache-2.0
module rvdffs_reset_probe;
  timeunit 1ns;
  timeprecision 1ps;

  bit clk = 0;
  bit rst_l = 1;
  bit en = 1;
  bit [7:0] din = 8'ha5;
  wire [7:0] word_out;
  wire bit_out;

  rvdffs #(.WIDTH(8)) word_reg (.din(din), .en(en), .clk(clk), .rst_l(rst_l), .dout(word_out));
  rvdffs bit_reg (.din(din[0]), .en(en), .clk(clk), .rst_l(rst_l), .dout(bit_out));

  task automatic check_value(input string phase, input bit [7:0] expected);
    if (word_out !== expected || bit_out !== expected[0]) begin
      $display("RVDFFS_MISMATCH %s word=%h bit=%b expected=%h", phase, word_out, bit_out, expected);
      $finish;
    end else begin
      $display("RVDFFS_OK %s", phase);
    end
  endtask

  initial begin
    #2 rst_l = 0;
    #2 rst_l = 1;
    #2 clk = 1;
    #2 check_value("capture", 8'ha5);
    clk = 0;
    en = 0;
    din = 8'h5a;
    #2 clk = 1;
    #2 check_value("disabled_edge", 8'ha5);
    clk = 0;
    #2 rst_l = 0;
    #2 check_value("reset_between_edges", 8'h00);
    rst_l = 1;
    #2 check_value("reset_release", 8'h00);
    en = 1;
    #2 clk = 1;
    #2 check_value("enabled_after_reset", 8'h5a);
    $display("RVDFFS_PASS");
    $finish;
  end
endmodule
