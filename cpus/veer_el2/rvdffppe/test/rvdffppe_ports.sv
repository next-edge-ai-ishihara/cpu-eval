// SPDX-License-Identifier: Apache-2.0

module rvdffppe_ports;
  import el2_pkg::*;
  localparam integer PACKET = $bits(el2_predict_pkt_t);
  logic clk = 0;
  logic rst_l = 1;
  logic en = 0;
  logic scan_mode = 0;
  logic [PACKET:0] din = '0;
  logic [PACKET:0] pattern = '1;
  logic [PACKET-1:0] narrow;
  logic [PACKET:0] wide;
  int failures = 0;

  rvdffppe #(.WIDTH(PACKET)) predict (
    .din(din[PACKET-1:0]), .dout(narrow), .clk, .rst_l, .en, .scan_mode
  );
  rvdffppe #(.WIDTH(PACKET + 1)) recovery (
    .din, .dout(wide), .clk, .rst_l, .en, .scan_mode
  );

  task automatic check(input string phase, input logic [PACKET:0] expected);
    #1;
    $display("RVDFFPPE_PORTS %s expected=%h narrow=%h wide=%h", phase, expected, narrow, wide);
    if (narrow !== expected[PACKET-1:0] || wide !== expected)
      failures++;
  endtask

  initial begin
    $display("RVDFFPPE_WIDTHS %0d %0d", PACKET, PACKET + 1);
    pattern[31] = 0;
    #1; rst_l = 0;
    check("initial_reset", '0);
    rst_l = 1;
    en = 1;
    din = pattern;
    check("before_rising_edge", '0);
    clk = 1;
    check("capture_full_packet", pattern);
    clk = 0;
    en = 0;
    din = '0;
    #1; clk = 1;
    check("disabled_hold", pattern);
    clk = 0;
    #1; rst_l = 0;
    check("reset_without_rising_edge", '0);
    if (failures == 0)
      $display("RVDFFPPE_PORTS_PASS");
    else
      $display("RVDFFPPE_PORTS_FAIL mismatches=%0d", failures);
    $finish;
  end
endmodule
