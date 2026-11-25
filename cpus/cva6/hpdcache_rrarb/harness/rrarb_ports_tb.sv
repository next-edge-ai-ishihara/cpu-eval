module exercise #(parameter N=1)(output bit done);
  bit clk=0; always #5 clk=~clk;
  bit rst=0,ready=1;
  logic [N-1:0] req=0,gnt;
  int checks=0,errors=0,previous,idx,expected_idx;
  logic [N-1:0] held;
  hpdcache_rrarb #(.N(N)) dut(.clk_i(clk),.rst_ni(rst),.req_i(req),.gnt_o(gnt),.ready_i(ready));
  task check(input bit ok);
    checks++;
    $display("OBS N=%0d check=%0d req=%h ready=%b gnt=%h",N,checks,req,ready,gnt);
    if(!ok) begin errors++; $display("MISMATCH N=%0d check=%0d",N,checks); end
  endtask
  task reset;
    @(negedge clk); rst=0;req=0;ready=1;
    @(negedge clk);rst=1; #1;
  endtask
  initial begin
    reset();
    check(gnt=='0);
    for(int i=0;i<N;i++) begin
      @(negedge clk);req=1<<i;#1;check(gnt==req);
      @(posedge clk); @(negedge clk);req=0;#1;check(gnt==0);
    end
    reset();
    @(negedge clk);req=1;ready=0;#1;held=gnt;check(held==1);
    @(posedge clk); @(negedge clk);req='1;#1;check(gnt==held);
    repeat(3) begin @(posedge clk);@(negedge clk);#1;check(gnt==held);end
    ready=1;#1;check(gnt==held);
    @(posedge clk);@(negedge clk);#1;check($onehot(gnt)&&((gnt&req)==gnt));
    for(int pattern=1;pattern<(1<<N);pattern++) begin
      reset();
      @(negedge clk);req=pattern;ready=1;#1;previous=-1;
      repeat(2*$countones(req)) begin
        idx=-1;for(int i=0;i<N;i++)if(gnt[i])idx=i;
        expected_idx=-1;
        if(previous>=0) begin
          for(int step=1;step<=N;step++) begin
            if(expected_idx<0 && req[(previous+step)%N])
              expected_idx=(previous+step)%N;
          end
        end
        check($onehot(gnt)&&((gnt&req)==gnt)&&
              (previous<0||idx==expected_idx));
        previous=idx;@(posedge clk);@(negedge clk);#1;
      end
    end
    reset();
    for(int pattern=1;pattern<(1<<N);pattern++) begin
      @(negedge clk);req=pattern;ready=1;#1;
      check($onehot(gnt)&&((gnt&req)==gnt));
      ready=0;held=gnt;
      @(posedge clk);@(negedge clk);req='1;#1;check(gnt==held);
      ready=1;@(posedge clk);@(negedge clk);req=0;#1;check(gnt==0);
    end
    $display("SUMMARY N=%0d checks=%0d errors=%0d",N,checks,errors);
    done=1;
  end
endmodule
module tb;
  // cv32a60x instantiates N=4 (stride prefetcher, RTAB) and N=8 (write buffer).
  wire d4,d8;
  exercise #(.N(4)) a(d4);
  exercise #(.N(8)) b(d8);
  initial begin wait(d4&&d8);$display("RRARB_PORT_TEST_COMPLETE");$finish;end
endmodule
