// SPDX-License-Identifier: Apache-2.0
module testbench;
logic [31:0] instr;
logic rb,rc,rj,rr,rjr,cb,cj,cr,cc,cjr,cjalr;
logic [31:0] ri,ci;
integer checked=0, raw,rd,rs,bit_index;
logic [12:0] branch_offset;
logic [20:0] jump_offset;
instr_scan #(.CVA6Cfg(build_config_pkg::build_config(cva6_config_pkg::cva6_cfg))) dut(
.instr_i(instr),.rvi_branch_o(rb),.rvi_call_o(rc),.rvi_jump_o(rj),.rvi_return_o(rr),.rvi_jalr_o(rjr),.rvi_imm_o(ri),
.rvc_branch_o(cb),.rvc_jump_o(cj),.rvc_return_o(cr),.rvc_call_o(cc),.rvc_jr_o(cjr),.rvc_jalr_o(cjalr),.rvc_imm_o(ci));
function automatic logic [31:0] cj_offset(input logic [15:0] i);
integer n;
n=(int'(i[12])<<11)|(int'(i[11])<<4)|(int'(i[10:9])<<8)|(int'(i[8])<<10)|(int'(i[7])<<6)|(int'(i[6])<<7)|(int'(i[5:3])<<1)|(int'(i[2])<<5);
return i[12] ? n-4096 : n;
endfunction
function automatic logic [31:0] cb_offset(input logic [15:0] i);
integer n;
n=(int'(i[12])<<8)|(int'(i[11:10])<<3)|(int'(i[6:5])<<6)|(int'(i[4:3])<<1)|(int'(i[2])<<5);
return i[12] ? n-512 : n;
endfunction
task automatic compressed(input logic [15:0] i,input logic [5:0] flags,input bit immediate_valid,input logic [31:0] immediate,input logic [5:0] flag_mask=6'b111111);
instr={16'hca5a,i};#1;
if(({cb,cj,cjr,cr,cjalr,cc}&flag_mask)!==(flags&flag_mask)) $fatal(1,"FAIL: compressed flags instruction=%h actual=%b expected=%b",i,{cb,cj,cjr,cr,cjalr,cc},flags);
if(immediate_valid && ci!==immediate) $fatal(1,"FAIL: compressed immediate instruction=%h actual=%h expected=%h",i,ci,immediate);
checked++;
endtask
task automatic base(input logic [31:0] i,input logic [4:0] flags,input bit immediate_valid,input logic [31:0] immediate);
instr=i;#1;
if({rb,rj,rjr,rr,rc}!==flags) $fatal(1,"FAIL: base flags instruction=%h",i);
if(immediate_valid && ri!==immediate) $fatal(1,"FAIL: base immediate instruction=%h actual=%h expected=%h",i,ri,immediate);
checked++;
endtask
task automatic relative_jump(input logic [20:0] offset,input logic [4:0] destination);
base({offset[20],offset[10:1],offset[11],offset[19:12],destination,7'b1101111},
     {2'b01,2'b00,(destination==1||destination==5)},1,{{11{offset[20]}},offset});
endtask
initial begin
for(raw=0;raw<2048;raw++) begin
compressed(16'ha001|(raw<<2),6'b010000,1,cj_offset(16'ha001|(raw<<2)));
compressed(16'h2001|(raw<<2),6'b010001,1,cj_offset(16'h2001|(raw<<2)));
compressed(16'hc001|(raw<<2),6'b100000,1,cb_offset(16'hc001|(raw<<2)));
compressed(16'he001|(raw<<2),6'b100000,1,cb_offset(16'he001|(raw<<2)));
end
for(rs=1;rs<32;rs++) begin
compressed(16'h8002|(rs<<7),{2'b00,1'b1,(rs==1||rs==5),2'b00},0,0);
compressed(16'h9002|(rs<<7),6'b000011,0,0,rs==5?6'b111011:6'b111111);
end
base(32'h00000013,5'b00000,0,0);
for(rd=0;rd<32;rd++) begin
base(32'h8000006f|(rd<<7),{2'b01,2'b00,(rd==1||rd==5)},1,32'hfff00000);
base(32'h0000006f|(rd<<7),{2'b01,2'b00,(rd==1||rd==5)},1,0);
for(rs=0;rs<32;rs++) base(32'h00000067|(rd<<7)|(rs<<15),{3'b001,((rs==1||rs==5)&&(rd!=rs)),(rd==1||rd==5)},0,0);
end
base(32'h80000063,5'b10000,1,32'hfffff000);
base(32'h00000063,5'b10000,1,0);
for(raw=0;raw<4096;raw++) begin
branch_offset={12'(raw),1'b0};
base({branch_offset[12],branch_offset[10:5],5'd0,5'd0,3'b000,
      branch_offset[4:1],branch_offset[11],7'b1100011},
     5'b10000,1,{{19{branch_offset[12]}},branch_offset});
end
for(bit_index=1;bit_index<=20;bit_index++) begin
jump_offset=21'b1<<bit_index;
relative_jump(jump_offset,5'd0);
relative_jump(jump_offset^21'h1ffffe,5'd1);
end
$display("PASS: scanner control transfers and signed offsets; cases=%0d",checked);$finish;
end
endmodule
