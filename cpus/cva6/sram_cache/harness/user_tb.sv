module user_tb;
  logic clk=0, rst_n=0, req=0, we=0;
  logic [5:0] addr=0;
  logic [127:0] wd=0, wu=0, rd, ru;
  logic [15:0] be=16'hffff;
  int errors=0, data_errors=0, user_errors=0, checks=0;
  sram_cache #(.DATA_WIDTH(128), .USER_WIDTH(128), .USER_EN(1),
    .NUM_WORDS(64), .SIM_INIT("none"), .BYTE_ACCESS(0),
    .TECHNO_CUT(1), .OUT_REGS(0)) dut
    (.clk_i(clk), .rst_ni(rst_n), .req_i(req), .we_i(we),
     .addr_i(addr), .wdata_i(wd), .wuser_i(wu), .be_i(be),
     .rdata_o(rd), .ruser_o(ru));
  function automatic logic [127:0] data_pattern(int a);
    return 128'h0123456789abcdeffedcba9876543210 ^ {4{32'(a)}};
  endfunction
  function automatic logic [127:0] user_pattern(int a, int phase);
    logic [127:0] v;
    v=128'h80000000a55aa55a55aa55aa00000001 ^ (128'(a) << 65);
    return phase ? ~v : v;
  endfunction
  task automatic tick;
    #5; clk=1; #1; clk=0; #4;
  endtask
  initial begin
    tick(); rst_n=1;
    for (int phase=0;phase<2;phase++) begin
      for (int a=0;a<64;a++) begin
        req=1; we=1; addr=6'(a); wd=data_pattern(a); wu=user_pattern(a,phase);
        $display("WRITE phase=%0d addr=%0d be=%h data=%h user=%h",phase,a,be,wd,wu);
        tick();
      end
      req=0; we=1; addr=6'd17; wd=~data_pattern(17); wu=~user_pattern(17,phase);
      $display("UNSELECTED_WRITE phase=%0d addr=%0d be=%h data=%h user=%h",phase,addr,be,wd,wu);
      tick();
      for (int a=63;a>=0;a--) begin
        req=1; we=0; addr=6'(a); tick(); checks++;
        $display("READ phase=%0d addr=%0d data=%h expected_data=%h user=%h expected_user=%h",phase,a,rd,data_pattern(a),ru,user_pattern(a,phase));
        if (rd !== data_pattern(a)) begin errors++; data_errors++; end
        if (ru !== user_pattern(a,phase)) begin errors++; user_errors++; end
      end
      req=0; tick();
    end
    $display("RESULT checks=%0d data_errors=%0d user_errors=%0d errors=%0d",checks,data_errors,user_errors,errors);
    if(errors) $fatal(1,"external data/user mismatch");
    $finish;
  end
endmodule
