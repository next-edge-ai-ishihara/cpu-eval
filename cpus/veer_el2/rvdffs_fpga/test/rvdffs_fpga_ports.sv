// SPDX-License-Identifier: Apache-2.0
module rvdffs_fpga_ports;
   localparam int Width = 8;
   logic [Width-1:0] din = '0;
   logic en = 0;
   logic clken = 0;
   logic rawclk = 0;
   logic rst_l = 1;
   logic [Width-1:0] stored;
   logic [Width-1:0] bypassed;
   int mismatches = 0;

   // The FPGA branch in el2_dma_ctrl ties dma_bus_clk low.
   rvdffs_fpga #(.WIDTH(Width)) held (
      .din(din), .en(en), .clk(1'b0), .clken(clken), .rawclk(rawclk),
      .rst_l(rst_l), .dout(stored)
   );
   rvdffs_fpga #(.WIDTH(Width), .SHORT(1)) bypass (
      .din(din), .en(en), .clk(1'b0), .clken(clken), .rawclk(rawclk),
      .rst_l(rst_l), .dout(bypassed)
   );

   task automatic check_value(
      input string label, input logic [Width-1:0] expected,
      input logic [Width-1:0] actual
   );
      if (actual !== expected) begin
         $display("PORT_MISMATCH %s expected=%02h actual=%02h", label, expected, actual);
         mismatches++;
      end
   endtask

   task automatic clock_step(
      input logic data_enable, input logic clock_enable, input logic [Width-1:0] data,
      input logic [Width-1:0] expected, input string label
   );
      en = data_enable;
      clken = clock_enable;
      din = data;
      #2;
      rawclk = 1;
      #2;
      check_value(label, expected, stored);
      rawclk = 0;
      #2;
   endtask

   initial begin
      #2;
      rst_l = 0;
      #2;
      rst_l = 1;
      clock_step(1, 1, 8'hA5, 8'hA5, "rawclk capture");
      clock_step(0, 1, 8'h12, 8'hA5, "hold with en low");
      clock_step(1, 0, 8'h34, 8'hA5, "hold with clken low");
      clock_step(0, 0, 8'h56, 8'hA5, "hold with both enables low");
      clock_step(1, 1, 8'hC3, 8'hC3, "capture after hold");
      en = 0;
      clken = 0;
      din = 8'h69;
      #2;
      check_value("SHORT with clocks stopped", 8'h69, bypassed);
      check_value("hold with clocks stopped", 8'hC3, stored);
      rst_l = 0;
      #2;
      check_value("asynchronous reset", 8'h00, stored);
      check_value("SHORT during reset", 8'h69, bypassed);
      $display("PORT_CHECKS_COMPLETE mismatches=%0d", mismatches);
      $finish;
   end
endmodule
