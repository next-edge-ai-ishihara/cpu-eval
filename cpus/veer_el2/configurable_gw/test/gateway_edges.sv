module gateway_edges;
  bit clk, rst_l, request, clear, polarity;
  logic pending;
  bit mismatch;

  el2_configurable_gw dut(
    .gw_clk(clk), .rawclk(clk), .clken(1'b1), .rst_l(rst_l),
    .extintsrc_req(request), .meigwctrl_polarity(polarity),
    .meigwctrl_type(1'b1), .meigwclr(clear), .extintsrc_req_config(pending)
  );

  task automatic tick;
    #2; clk = 1; #2; clk = 0; #2;
  endtask

  task automatic settle;
    repeat (8) tick();
  endtask

  task automatic observe(input string phase, input bit expected);
    $display("gateway %s %s expected=%b observed=%b",
             polarity ? "active-low" : "active-high", phase, expected, pending);
    if (pending !== expected) mismatch = 1;
  endtask

  task automatic exercise(input bit inverted);
    rst_l = 0;
    polarity = inverted;
    request = inverted;
    clear = 0;
    tick();
    rst_l = 1;
    if (inverted) begin
      // The synchronized input must reach its inactive level before clearing pending.
      settle();
      clear = 1;
      tick();
      clear = 0;
      settle();
      observe("idle before request", 0);
    end
    request = !inverted;
    settle();
    observe("asserted request", 1);
    clear = 1;
    tick();
    observe("active request during clear", 1);
    clear = 0;
    settle();
    request = inverted;
    settle();
    observe("retained after input becomes inactive", 1);
    clear = 1;
    tick();
    clear = 0;
    settle();
    observe("clear with inactive input", 0);
  endtask

  initial begin
    exercise(1'b0);
    exercise(1'b1);
    if (mismatch) $display("GATEWAY_EDGES_FAIL");
    else $display("GATEWAY_EDGES_PASS");
    $finish;
  end
endmodule
