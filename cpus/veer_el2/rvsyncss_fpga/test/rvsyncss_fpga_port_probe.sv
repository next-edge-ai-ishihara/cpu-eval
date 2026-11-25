// Checks the two gw_clk-edge synchronizer delay with rawclk tied to gw_clk and clken high.
module rvsyncss_fpga_port_case #(parameter WIDTH = 251) (output bit done);
   bit clk = 0;
   bit rst_l = 1;
   logic [WIDTH-1:0] din = '0;
   logic [WIDTH-1:0] dout;
   logic [WIDTH-1:0] previous_sample = '0;
   logic [WIDTH-1:0] expected_output = '0;

   rvsyncss_fpga #(.WIDTH(WIDTH)) dut (
      .gw_clk(clk), .rawclk(clk), .clken(1'b1), .rst_l(rst_l), .din(din), .dout(dout));

   task automatic check_output(input string phase);
      if (dout !== expected_output) begin
         $display("RVSYNCSS_FPGA_PORT_FAIL width=%0d phase=%s expected=%h actual=%h",
                  WIDTH, phase, expected_output, dout);
         $finish;
      end
   endtask

   task automatic sample(input logic [WIDTH-1:0] value);
      clk = 0;
      din = value;
      #5;
      check_output("before rising edge");
      clk = 1;
      expected_output = previous_sample;
      previous_sample = value;
      #5;
      check_output("after rising edge");
   endtask

   task automatic reset_between_edges;
      rst_l = 0;
      previous_sample = '0;
      expected_output = '0;
      #2;
      check_output("reset asserted without a rising edge");
      rst_l = 1;
      #2;
      check_output("reset released without a rising edge");
   endtask

   initial begin
      #2;
      reset_between_edges();
      for (int bit_index = 0; bit_index < WIDTH; bit_index++)
         sample(WIDTH'(1) << bit_index);
      sample('0);
      sample('1);
      sample('1);
      reset_between_edges();
      sample('0);
      done = 1;
   end
endmodule

module rvsyncss_fpga_port_probe;
   wire done_1, done_7, done_251;
   rvsyncss_fpga_port_case #(1) probe_1 (done_1);
   rvsyncss_fpga_port_case #(7) probe_7 (done_7);
   rvsyncss_fpga_port_case #(251) probe_251 (done_251);
   initial begin
      wait (done_1 && done_7 && done_251);
      $display("RVSYNCSS_FPGA_PORT_PASS widths=1,7,251");
      $finish;
   end
endmodule
