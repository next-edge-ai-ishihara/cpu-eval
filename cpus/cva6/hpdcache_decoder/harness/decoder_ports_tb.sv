module tb;
  logic en;
  logic [0:0] value;
  logic [1:0] decoded;
  int checks = 0, errors = 0;
  hpdcache_decoder #(.N(1)) dut(.en_i(en), .val_i(value), .val_o(decoded));
  initial begin
    for (int enabled = 0; enabled < 2; enabled++) begin
      for (int index = 0; index < 2; index++) begin
        logic [1:0] expected;
        en = 1'(enabled);
        value = 1'(index);
        expected = '0;
        if (enabled) expected[index] = 1'b1;
        #1;
        checks++;
        $display("OBS check=%0d en=%b value=%0d actual=%02b expected=%02b", checks, en, value, decoded, expected);
        if (decoded !== expected) begin
          errors++;
          $display("MISMATCH check=%0d", checks);
        end
      end
    end
    $display("SUMMARY checks=%0d errors=%0d", checks, errors);
    if (errors) $fatal(1, "decoder port mismatch");
    $display("DECODER_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
