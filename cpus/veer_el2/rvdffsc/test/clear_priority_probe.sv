// SPDX-License-Identifier: Apache-2.0

module clear_priority_probe;
   timeunit 1ns;
   timeprecision 1ps;

   logic clk = 0;
   logic rst_l = 0;
   logic en = 0;
   logic clear = 0;
   logic [3:0] din = 0;
   wire [3:0] out4;
   wire [1:0] out2;
   wire out1;
   int mismatches = 0;

   rvdffsc #(.WIDTH(4)) dut4 (.din(din), .dout(out4), .*);
   rvdffsc #(.WIDTH(2)) dut2 (.din(din[1:0]), .dout(out2), .*);
   rvdffsc #(.WIDTH(1)) dut1 (.din(din[0]), .dout(out1), .*);

   task automatic observe(input string phase, input logic [3:0] expected);
      $display("CLEAR_PRIORITY phase=%s expected=%h out4=%h out2=%h out1=%h",
               phase, expected, out4, out2, out1);
      if ({out4, out2, out1} !== {expected, expected[1:0], expected[0]})
         mismatches++;
   endtask

   initial begin
      #1 clk = 1;
      #1 clk = 0;
      rst_l = 1;
      en = 1;
      din = '1;
      #1 clk = 1;
      #1 observe("capture", 4'hf);
      clk = 0;
      clear = 1;
      #1 observe("before_clear_edge", 4'hf);
      clk = 1;
      #1 observe("after_clear_edge", 4'h0);
      $display("CLEAR_PRIORITY_DONE mismatches=%0d", mismatches);
      $finish;
   end
endmodule
