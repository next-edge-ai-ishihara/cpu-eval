// SPDX-License-Identifier: Apache-2.0
module testbench;
  bit clk, rst_n, enable;
  logic output_bit;
  logic [7:0] state;
  lfsr #(.LfsrWidth(8), .OutWidth(1)) dut (
    .clk_i(clk), .rst_ni(rst_n), .en_i(enable), .out_o(output_bit)
  );

  initial begin
    for (int cycle = 0; cycle < 525; cycle++) begin
      rst_n = cycle != 0;
      enable = cycle % 2;
      if (!rst_n) state = '1;
      else if (enable) state = (state >> 1) ^ ({8{state[0]}} & 8'hfa);
      #1; clk = 1; #1;
      if (output_bit !== state[0])
        $fatal(1, "FAIL: LFSR cycle=%0d enable=%b expected=%b observed=%b",
               cycle, enable, state[0], output_bit);
      clk = 0;
      #1;
    end
    if (output_bit !== 1'b0)
      $fatal(1, "FAIL: LFSR reset precondition expected=0 observed=%b", output_bit);
    rst_n = 0;
    #1;
    if (output_bit !== 1'b1)
      $fatal(1, "FAIL: LFSR reset while clock is low expected=1 observed=%b", output_bit);
    $display("PASS: selected eight-bit LFSR reset, update, and hold");
    $finish;
  end
endmodule
