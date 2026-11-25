// SPDX-License-Identifier: Apache-2.0
module lzc_ports_tb;
  bit [1:0] two;
  logic two_count, two_empty;

  // WIDTH=2 with MODE=0 is the narrow instance that cv32a60x uses.
  lzc #(.WIDTH(2), .MODE(1'b0)) width_two (
    .in_i(two), .cnt_o(two_count), .empty_o(two_empty)
  );

  task automatic check_two(input bit [1:0] value, input bit count, input bit empty);
    two = value;
    #1;
    if (two_count !== count || two_empty !== empty)
      $fatal(1, "FAIL: WIDTH=2 in=%b cnt=%b empty=%b expected cnt=%b empty=%b",
             two, two_count, two_empty, count, empty);
  endtask

  initial begin
    check_two(2'b00, 1'b1, 1'b1);
    check_two(2'b01, 1'b0, 1'b0);
    check_two(2'b10, 1'b1, 1'b0);
    check_two(2'b11, 1'b0, 1'b0);
    $display("PASS: trailing-zero mode at WIDTH=2");
    $finish;
  end
endmodule
