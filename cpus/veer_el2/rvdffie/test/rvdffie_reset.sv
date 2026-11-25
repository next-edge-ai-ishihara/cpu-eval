// SPDX-License-Identifier: Apache-2.0

module rvdffie_reset;
  logic clk = 0;
  logic rst_l = 1;
  logic [7:0] din = 0;
  logic [7:0] dout;

  rvdffie #(.WIDTH(8)) dut (.clk, .rst_l, .din, .dout, .scan_mode(1'b0));

  initial begin
    logic [7:0] saved;

    #1 rst_l = 0;
    #1 clk = 1;
    #1 clk = 0;
    #1 rst_l = 1;
    din = 8'ha5;
    #1 clk = 1;
    #1 saved = dout;
    $display("saved value clk=%b rst_l=%b dout=%h expected=a5", clk, rst_l, saved);
    clk = 0;
    #1 rst_l = 0;
    #1 $display("reset without a clock edge clk=%b rst_l=%b dout=%h expected=00", clk, rst_l, dout);
    if (saved === 8'ha5 && dout === 8'h00)
      $display("RVDFFIE_RESET_PASS");
    else
      $display("RVDFFIE_RESET_FAIL");
    $finish;
  end
endmodule
