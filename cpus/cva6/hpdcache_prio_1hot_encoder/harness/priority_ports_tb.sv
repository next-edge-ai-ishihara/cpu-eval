module tb;
  logic [3:0] request = 0;
  wire [3:0] result;
  int checks = 0;
  int errors = 0;
  hpdcache_prio_1hot_encoder #(.N(4)) dut(.val_i(request), .val_o(result));
  function automatic logic [3:0] expected(input logic [3:0] value);
    expected = '0;
    for (int i = 3; i >= 0; i--) begin
      if (value[i]) begin
        expected = '0;
        expected[i] = 1'b1;
      end
    end
  endfunction
  initial begin
    for (int value = 0; value <= 16; value++) begin
      request = value == 16 ? '0 : 4'(value);
      #1;
      checks++;
      $display("OBS request=%h result=%h expected=%h", request, result, expected(request));
      if (result !== expected(request)) begin
        errors++;
        $display("MISMATCH request=%h", request);
      end
    end
    $display("SUMMARY checks=%0d errors=%0d", checks, errors);
    if (errors != 0) $fatal(1, "priority port mismatch");
    $display("PRIORITY_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
