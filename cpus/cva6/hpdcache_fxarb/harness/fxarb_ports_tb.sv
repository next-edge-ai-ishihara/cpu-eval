module tb;
 logic clk=0,rst=1,ready=1;
 logic [7:0] req=0,gnt;
 int count=0,errors=0;
 hpdcache_fxarb #(.N(8)) dut(.clk_i(clk),.rst_ni(rst),.req_i(req),.gnt_o(gnt),.ready_i(ready));
 task automatic pulse; #1;clk=1;#1;clk=0;#1;endtask
 task automatic check(input logic[7:0] expected,input string label);
  #1;count++;
  $display("OBS %s req=%h ready=%b gnt=%h expected=%h",label,req,ready,gnt,expected);
  if(gnt!==expected) begin errors++;$display("MISMATCH %s",label);end
 endtask
 function automatic logic[7:0] low(input logic[7:0] r);
  low=0;for(int k=7;k>=0;k--) if(r[k])begin low=0;low[k]=1;end
 endfunction
 initial begin
  #1;rst=0;#1;rst=1;#1;
  for(int r=0;r<256;r++) begin req=8'(r);ready=1;check(low(req),"priority");pulse();end
  req=8'h80;ready=0;check(8'h80,"stall-start");pulse();
  req=8'h81;check(8'h80,"lower-request-added");pulse();
  req=8'h83;check(8'h80,"continued-stall");pulse();
  ready=1;check(8'h80,"accept-held-request");pulse();
  check(8'h01,"next-selection");
  $display("SUMMARY checks=%0d errors=%0d",count,errors);
  if(errors) $fatal(1,"FAIL");
  $display("FXARB_PORT_TEST_COMPLETE");$finish;
 end
endmodule
