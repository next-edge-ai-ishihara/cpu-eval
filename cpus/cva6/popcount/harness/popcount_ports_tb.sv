// SPDX-License-Identifier: Apache-2.0
// INPUT_WIDTH=32 and 2 are the widths that cv32a60x instantiates.
module testbench;
  logic [31:0] word;
  logic [5:0] word_weight;
  logic [1:0] pair;
  logic [1:0] pair_weight;

  popcount #(.INPUT_WIDTH(32)) word_count (.data_i(word), .popcount_o(word_weight));
  popcount #(.INPUT_WIDTH(2)) pair_count (.data_i(pair), .popcount_o(pair_weight));

  task automatic check_word(input string pattern, input logic [31:0] bits, input logic [5:0] expected);
    word = bits;
    #1;
    if (word_weight !== expected)
      $fatal(1, "FAIL: %s weight=%0d expected=%0d", pattern, word_weight, expected);
  endtask

  task automatic check_pair(input logic [1:0] bits, input logic [1:0] expected);
    pair = bits;
    #1;
    if (pair_weight !== expected)
      $fatal(1, "FAIL: two-bit input %b weight=%0d expected=%0d", bits, pair_weight, expected);
  endtask

  initial begin
    check_word("highest input bit only", 32'h1 << 31, 6'd1);
    check_word("all 32 input bits set", '1, 6'd32);
    check_word("alternating bits", 32'h5a5a_c3c3, 6'd16);
    for (int value = 0; value < 4; value++) check_pair(2'(value), 2'($countones(2'(value))));
    $display("PASS: population count at the instantiated widths");
    $finish;
  end
endmodule
