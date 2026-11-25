// SPDX-License-Identifier: Apache-2.0
module test_rvdff_ports;
  timeunit 1ns;
  timeprecision 1ps;

  logic clk = 0;
  logic rst_l = 1;
  logic [8:0] din = '0;
  wire [8:0] stored, bypassed;
  wire bit_stored;

  rvdff #(.WIDTH(9)) reg_word(.din(din), .clk(clk), .rst_l(rst_l), .dout(stored));
  rvdff #(.WIDTH(9), .SHORT(1)) bypass(.din(din), .clk(clk), .rst_l(rst_l), .dout(bypassed));
  rvdff reg_bit(.din(din[0]), .clk(clk), .rst_l(rst_l), .dout(bit_stored));

  task automatic check_outputs(input string phase, input logic [8:0] expected);
    if (stored !== expected || bit_stored !== expected[0] || bypassed !== din) begin
      $display("RVDFF_PORT_MISMATCH %s stored=%h expected=%h bit=%b expected_bit=%b bypass=%h din=%h",
               phase, stored, expected, bit_stored, expected[0], bypassed, din);
      $finish;
    end
  endtask

  initial begin
    #2 rst_l = 0;
    #2 check_outputs("initial reset", '0);
    rst_l = 1;
    din = 9'h1a5;
    #2 check_outputs("input before first clock edge", '0);
    clk = 1;
    #2 check_outputs("first rising edge", 9'h1a5);
    din = 9'h066;
    #2 check_outputs("input changed with clock high", 9'h1a5);
    clk = 0;
    #2 check_outputs("falling edge", 9'h1a5);
    rst_l = 0;
    #2 check_outputs("reset asserted between edges", '0);
    din = 9'h17b;
    #2 check_outputs("input changed during reset", '0);
    clk = 1;
    #2 check_outputs("rising edge during reset", '0);
    clk = 0;
    rst_l = 1;
    #2 check_outputs("reset released with clock low", '0);
    clk = 1;
    #2 check_outputs("rising edge after reset", 9'h17b);
    $display("RVDFF_PORT_PASS");
    $finish;
  end
endmodule
