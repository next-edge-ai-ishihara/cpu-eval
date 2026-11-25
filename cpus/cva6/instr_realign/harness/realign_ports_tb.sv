// SPDX-License-Identifier: Apache-2.0
module testbench;
logic clk=0, rst=0, flush=0, valid=0, serving;
logic [31:0] addr=0, data=0;
logic [1:0] ov;
logic [1:0][31:0] oa, oi;
instr_realign #(.CVA6Cfg(build_config_pkg::build_config(cva6_config_pkg::cva6_cfg))) dut(.clk_i(clk),.rst_ni(rst),.flush_i(flush),.valid_i(valid),.serving_unaligned_o(serving),.address_i(addr),.data_i(data),.valid_o(ov),.addr_o(oa),.instr_o(oi));
integer checked=0;
task automatic tick; #1; clk=1; #1; clk=0; #1; endtask
task automatic sample(input logic [31:0] a,d,input logic [1:0] ev,
                      input logic [31:0] a0,i0,a1,i1,input logic split=1'b0);
 addr=a; data=d; valid=1; #1;
 if(ov!==ev) $fatal(1,"FAIL: valid %h expected %h",ov,ev);
 if(ev[0]) begin
 if(serving!==split) $fatal(1,"FAIL: first valid slot serving_unaligned=%b expected %b",serving,split);
 if(oa[0]!==a0) $fatal(1,"FAIL: first PC %h expected %h",oa[0],a0);
 if(i0[1:0]==2'b11 ? oi[0]!==i0 : oi[0][15:0]!==i0[15:0]) $fatal(1,"FAIL: first instruction");
 end
 if(ev[1]) begin
 if(oa[1]!==a1) $fatal(1,"FAIL: second PC %h expected %h",oa[1],a1);
 if(oi[1][15:0]!==i1[15:0]) $fatal(1,"FAIL: second instruction");
 end
 checked++; $display("case=%0d addr=%h data=%h valid=%b PC0=%h PC1=%h serving=%b",checked,addr,data,ov,oa[0],oa[1],serving);tick();
endtask
initial begin
tick();rst=1;#1;
sample('h100,'h00850001,2'b11,'h100,'h0001,'h102,'h0085);
sample('h104,'h12340013,2'b01,'h104,'h12340013,0,0);
sample('h108,'h00130001,2'b01,'h108,'h0001,0,0);

valid=0;tick();tick();
sample('h10c,'h00851234,2'b11,'h10a,'h12340013,'h10e,'h0085,1'b1);

sample('h112,'hffff0085,2'b01,'h112,'h0085,0,0);
sample('h116,'hffff0013,2'b00,0,0,0,0);

sample('h118,'h00011234,2'b11,'h116,'h12340013,'h11a,'h0001,1'b1);
sample('h11c,'h00130001,2'b01,'h11c,'h0001,0,0);
flush=1;valid=0;tick();flush=0;
sample('h200,'h00850001,2'b11,'h200,'h0001,'h202,'h0085);

sample('h208,'h00850001,2'b11,'h208,'h0001,'h20a,'h0085);
$display("PASS: realigned instructions and start addresses; cases=%0d",checked);$finish;
end
endmodule
