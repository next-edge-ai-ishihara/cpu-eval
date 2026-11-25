// SPDX-License-Identifier: Apache-2.0
module lfsr_width_probe #(parameter int WIDTH = 8) (
  input logic clk,
  output bit finished,
  output bit passed
);
  typedef logic [WIDTH-1:0] word_t;
  localparam int PERIOD = (1 << WIDTH) - 1;
  localparam word_t SEED = '1;
  bit rst_n = 1;
  bit shift = 0;
  word_t value;
  bit visited [1:PERIOD];
  word_t successor [1:PERIOD];

  hpdcache_lfsr #(.WIDTH(WIDTH)) dut (
    .clk_i(clk), .rst_ni(rst_n), .shift_i(shift), .val_o(value)
  );

  task automatic check(output bit success);
    word_t previous, first, linear_value;
    success = 0;
    #1 rst_n = 0;
    #1;
    if (value !== SEED) begin
      $display("LFSR_PORTS_REJECT width=%0d reset=%h", WIDTH, value);
      return;
    end
    @(negedge clk);
    rst_n = 1;
    for (int step = 0; step < PERIOD; step++) begin
      previous = value;
      if ($isunknown(previous) || previous == 0 || visited[previous]) begin
        $display("LFSR_PORTS_REJECT width=%0d step=%0d repeated_or_zero=%h", WIDTH, step, previous);
        return;
      end
      visited[previous] = 1;
      @(posedge clk);
      #1;
      if (value !== previous) begin
        $display("LFSR_PORTS_REJECT width=%0d step=%0d hold=%h expected=%h", WIDTH, step, value, previous);
        return;
      end
      @(negedge clk);
      shift = 1;
      @(posedge clk);
      #1;
      successor[previous] = value;
      if (step == 0) first = value;
      @(negedge clk);
      shift = 0;
    end
    if (value !== SEED) begin
      $display("LFSR_PORTS_REJECT width=%0d final=%h expected=%h", WIDTH, value, SEED);
      return;
    end
    for (int word = 1; word <= PERIOD; word++) begin
      linear_value = '0;
      for (int index = 0; index < WIDTH; index++)
        if ((word & (1 << index)) != 0) linear_value ^= successor[1 << index];
      if (successor[word] !== linear_value) begin
        $display("LFSR_PORTS_REJECT width=%0d nonlinear_state=%h next=%h expected=%h",
                 WIDTH, word_t'(word), successor[word], linear_value);
        return;
      end
    end
    shift = 1;
    @(posedge clk);
    #1;
    if (value !== first) begin
      $display("LFSR_PORTS_REJECT width=%0d repeated_start=%h expected=%h", WIDTH, value, first);
      return;
    end
    #1 rst_n = 0;
    #1;
    if (value !== SEED) begin
      $display("LFSR_PORTS_REJECT width=%0d second_reset=%h", WIDTH, value);
      return;
    end
    $display("LFSR_PORTS_OBS width=%0d first=%h period=%0d hold_checks=%0d linear_checks=%0d",
             WIDTH, first, PERIOD, PERIOD, PERIOD);
    success = 1;
  endtask

  initial begin
    check(passed);
    finished = 1;
  end
endmodule

module lfsr_ports_tb;
  logic clk = 0;
  always #5 clk = ~clk;
  bit finished, passed;

  // The cv32a60x victim selector instantiates hpdcache_lfsr with WIDTH=8.
  lfsr_width_probe #(.WIDTH(8)) probe (.clk(clk), .finished(finished), .passed(passed));

  initial begin
    wait (finished);
    if (passed) $display("LFSR_PORTS_PASS 1 width");
    else $display("LFSR_PORTS_FAIL");
    $finish;
  end
endmodule
