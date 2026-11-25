module decoder_port_tb
  import el2_pkg::*;
#(
`include "el2_param.vh"
) ();
`include "decoder_ports.svh"
el2_dec_decode_ctl #(.pt(pt)) dut (.*);
int checks=0;
task automatic require(input bit condition, input string label);
  checks++;
  if (!condition) $fatal(1,"DECODER_PORT_MISMATCH: %s",label);
endtask
task automatic tick;
  #5; clk=1; active_clk=1; free_l2clk=1;
  #5; clk=0; active_clk=0; free_l2clk=0; #1;
endtask
task automatic reset;
  zero_inputs(); lsu_idle_any=1; dec_csr_legal_d=1; dec_i0_pc4_d=1;
  rst_l=0; tick(); tick(); rst_l=1; repeat(3) tick();
endtask
task automatic begin_instruction(input logic [31:0] instruction);
  int count;
  dec_i0_instr_d=instruction; dec_ib0_valid_d=1; #1; count=0;
  while(dec_i0_decode_d!==1'b1 && count<128) begin tick(); count++; end
  if(dec_i0_decode_d!==1'b1) $fatal(1,"DECODER_PORT_TIMEOUT: D acceptance");
endtask
task automatic consume_instruction;
  tick(); dec_ib0_valid_d=0; #1;
endtask
task automatic wait_write(input bit csr);
  int count;
  count=0;
  while((csr ? dec_csr_wen_r : dec_i0_wen_r)!==1'b1 && count<128)
    begin tick(); count++; end
  if((csr ? dec_csr_wen_r : dec_i0_wen_r)!==1'b1)
    $fatal(1,"DECODER_PORT_TIMEOUT: R write csr=%b",csr);
endtask
function automatic logic [31:0] csr_instruction(
  input logic [2:0] operation, input logic [4:0] rd, rs1);
  return {12'h340,rs1,operation,rd,7'b1110011};
endfunction
task automatic test_lsu(input logic [31:0] instruction,
  input bit load_op, byte_op, word_op, unsigned_op,
  input logic [11:0] offset, input logic [4:0] rs1,rs2);
  reset(); begin_instruction(instruction);
  require(lsu_p.valid===1'b1,"LSU valid");
  require(lsu_p.load===load_op && lsu_p.store===!load_op,"LSU direction");
  require(lsu_p.by===byte_op && lsu_p.word===word_op && lsu_p.half===1'b0,"LSU width");
  if(load_op) require(lsu_p.unsign===unsigned_op,"LSU signedness");
  require(dec_lsu_offset_d===offset,"LSU offset");
  require(dec_i0_rs1_d===rs1 && dec_i0_rs1_en_d===1'b1,"LSU base");
  if(!load_op) require(dec_i0_rs2_d===rs2 && dec_i0_rs2_en_d===1'b1,"store data");
  consume_instruction();
endtask
task automatic test_stall(input logic [31:0] instruction,input int kind);
  reset();
  case(kind)
    0:lsu_load_stall_any=1;
    1:lsu_store_stall_any=1;
    2:dma_dccm_stall_any=1;
  endcase
  dec_i0_instr_d=instruction; dec_ib0_valid_d=1; #1;
  repeat(3) begin
    require(dec_i0_decode_d===1'b0 && lsu_p.valid===1'b0,"LSU blocked"); tick();
  end
  lsu_load_stall_any=0; lsu_store_stall_any=0; dma_dccm_stall_any=0;
  begin_instruction(instruction); require(lsu_p.valid===1'b1,"LSU released");
  consume_instruction();
endtask
task automatic test_csr(input logic [2:0] op,input logic [4:0] rd,rs1,
  input logic [31:0] mask,expected,input bit read_en);
  reset(); dec_csr_rddata_d=32'h00ff00ff; exu_csr_rs1_x=mask;
  exu_i0_result_x=read_en ? 32'h00ff00ff : mask;
  begin_instruction(csr_instruction(op,rd,rs1));
  require(dec_csr_ren_d===read_en,"CSR read");
  require(dec_csr_wen_unq_d===1'b1 && dec_csr_rdaddr_d===12'h340,"CSR write request");
  consume_instruction(); wait_write(1);
  require(dec_csr_wraddr_r===12'h340 && dec_csr_wrdata_r===expected,"CSR new value");
endtask
task automatic test_csr_zero(input logic [2:0] op);
  int count;
  reset(); dec_csr_rddata_d=32'h00ff00ff; exu_i0_result_x=32'h00ff00ff;
  begin_instruction(csr_instruction(op,5'd5,5'd0));
  require(dec_csr_ren_d===1'b1 && dec_csr_wen_unq_d===1'b0,"CSR zero source");
  consume_instruction(); count=0;
  while(dec_i0_wen_r!==1'b1 && count<128) begin
    require(dec_csr_wen_r===1'b0,"CSR zero source no write"); tick(); count++;
  end
  if(dec_i0_wen_r!==1'b1) $fatal(1,"DECODER_PORT_TIMEOUT: CSR old result");
  require(dec_csr_wen_r===1'b0 && dec_i0_waddr_r===5'd5 &&
          dec_i0_wdata_r===32'h00ff00ff,"CSR old result");
endtask
task automatic test_kill(input bit csr);
  reset(); dec_csr_rddata_d=32'h00ff00ff; exu_csr_rs1_x=32'h0f0f0f0f;
  exu_i0_result_x=csr ? 32'h00ff00ff : 32'd1;
  begin_instruction(csr ? csr_instruction(3'b010,5'd5,5'd6) : 32'h00100293);
  consume_instruction(); wait_write(csr);
  if(csr) require(dec_csr_wrdata_r===32'h0fff0fff,"CSR before kill");
  else require(dec_i0_waddr_r===5'd5 && dec_i0_wdata_r===32'd1,"GPR before kill");
  dec_tlu_i0_kill_writeb_r=1; #1;
  require((csr ? dec_csr_wen_r : dec_i0_wen_r)===1'b0,"R kill write");
endtask
task automatic test_branch(input bit taken,four_bytes);
  logic signed [12:0] delta;
  logic [31:0] recovery,expected;
  reset(); dec_i0_pc4_d=four_bytes; ifu_i0_cinst=16'hc005;
  dec_i0_brp.valid=1; dec_i0_brp.hist=taken ? 2'b10 : 2'b00;
  dec_i0_brp.toffset=12'h010;
  // C.BEQZ x8,+32 expands to BEQ x8,x0,+32 for the 2-byte input.
  begin_instruction(four_bytes ? 32'h02418063 : 32'h02040063);
  require(dec_i0_branch_d===1'b1 && i0_ap.beq===1'b1,"BEQ classification");
  require(i0_ap.predict_t===taken && i0_ap.predict_nt===!taken,"BEQ prediction");
  delta=$signed({dec_i0_br_immed_d,1'b0});
  recovery=32'h100+{{19{delta[12]}},delta};
  expected=taken ? (four_bytes ? 32'h104 : 32'h102) : 32'h120;
  require(recovery===expected,"BEQ opposite path"); consume_instruction();
endtask
task automatic test_fetch_fault(input bit ecc);
  int count;
  reset(); dec_i0_icaf_d=!ecc; dec_i0_dbecc_d=ecc;
  exu_i0_pc_x=31'h80;
  begin_instruction(32'h00100293); consume_instruction(); count=0;
  while(dec_tlu_i0_valid_r!==1'b1 && count<128) begin tick(); count++; end
  if(dec_tlu_i0_valid_r!==1'b1) $fatal(1,"DECODER_PORT_TIMEOUT: fetch fault R valid");
  require(dec_tlu_packet_r.icaf===1'b1,"fetch fault classification");
  dec_tlu_i0_kill_writeb_r=1; #1;
  require(dec_i0_wen_r===1'b0 && dec_csr_wen_r===1'b0,"fetch fault kill suppresses writes");
  require(dec_tlu_i0_pc_r===31'h80,"fetch fault PC");
endtask
task automatic start_nonblock_load(input bit cancel);
  reset(); begin_instruction(32'h0001a383); consume_instruction();
  lsu_nonblock_load_valid_m=1; lsu_nonblock_load_tag_m=3; tick();
  lsu_nonblock_load_valid_m=0; lsu_nonblock_load_inv_tag_r=3;
  lsu_nonblock_load_inv_r=cancel; dec_tlu_i0_kill_writeb_r=cancel; #1;
  require(dec_i0_wen_r===1'b0,"nonblock load waits for data");
  tick(); lsu_nonblock_load_inv_r=0; dec_tlu_i0_kill_writeb_r=0; #1;
endtask
task automatic test_nonblock_return(input bit error);
  start_nonblock_load(0);
  dec_i0_instr_d=32'h00138413; dec_ib0_valid_d=1; #1;
  repeat(3) begin require(dec_i0_decode_d===1'b0,"nonblock dependency waits"); tick(); end
  lsu_nonblock_load_data_tag=3;
  lsu_nonblock_load_data_valid=!error; lsu_nonblock_load_data_error=error; #1;
  require(dec_nonblock_load_wen===!error,"nonblock response write");
  if(!error) require(dec_nonblock_load_waddr===5'd7,"nonblock response destination");
  // A consumer accepted with the response must receive it through the supplied EXU mux.
  if(!error && dec_i0_decode_d===1'b1)
    require(dec_i0_rs1_bypass_en_d===4'b1000,"nonblock simultaneous operand");

  dec_ib0_valid_d=0; tick();
  lsu_nonblock_load_data_valid=0; lsu_nonblock_load_data_error=0; #1;
  require(dec_nonblock_load_wen===1'b0,"nonblock response consumed once");
  if(!error) begin
    begin_instruction(32'h00138413); consume_instruction();
  end
endtask
task automatic test_nonblock_cancel;
  start_nonblock_load(1);
  require(dec_nonblock_load_wen===1'b0,"cancelled nonblock has no write");
  begin_instruction(32'h00138413); consume_instruction();
endtask
task automatic test_nonblock_younger;
  int count;
  start_nonblock_load(0); dec_i0_instr_d=32'h00100393; dec_ib0_valid_d=1;
  exu_i0_result_x=1; #1; count=0;
  while(dec_i0_decode_d!==1'b1 && count<8) begin tick(); count++; end
  if(dec_i0_decode_d===1'b1) begin
    consume_instruction(); wait_write(0);
    require(dec_i0_waddr_r===5'd7,"younger nonblock destination");
    lsu_nonblock_load_data_tag=3; lsu_nonblock_load_data_valid=1; #1;
    require(dec_nonblock_load_wen===1'b0,"younger write wins over old load");
    tick(); lsu_nonblock_load_data_valid=0;
  end else begin
    // Waiting for the older result is also a valid ordering strategy.
    dec_ib0_valid_d=0; lsu_nonblock_load_data_tag=3;
    lsu_nonblock_load_data_valid=1; #1;
    require(dec_nonblock_load_wen===1'b1 && dec_nonblock_load_waddr===5'd7,
      "older load completes before younger");
    tick(); lsu_nonblock_load_data_valid=0;
    begin_instruction(32'h00100393); consume_instruction(); wait_write(0);
    require(dec_i0_waddr_r===5'd7,"deferred younger destination");
  end
endtask
task automatic test_division(input bit unsigned_op, remainder_op);
  int count;
  reset(); begin_instruction(32'h02b544b3 | (unsigned_op ? 32'h1000 : 0) |
    (remainder_op ? 32'h2000 : 0));
  require(div_p.valid===1'b1 && div_p.unsign===unsigned_op && div_p.rem===remainder_op,
    "division operation request");
  consume_instruction();
  require(dec_div_active===1'b1 && div_waddr_wb===5'd9,"division active destination");
  dec_i0_instr_d=32'h00148513; dec_ib0_valid_d=1; #1;
  repeat(3) begin require(dec_i0_decode_d===1'b0,"division dependency waits"); tick(); end
  dec_ib0_valid_d=0; exu_div_wren=1; tick(); exu_div_wren=0;
  begin_instruction(32'h00148513); consume_instruction();
  count=0;
  while(dec_div_active!==1'b0 && count<128) begin tick(); count++; end
  if(dec_div_active!==1'b0) $fatal(1,"DECODER_PORT_TIMEOUT: division completion");
endtask
task automatic test_division_cancel;
  reset(); begin_instruction(32'h02b544b3); consume_instruction();
  dec_tlu_flush_lower_r=1; exu_flush_final=1; #1;
  require(dec_div_cancel===1'b1,"flush cancels younger X division");
  tick(); dec_tlu_flush_lower_r=0; dec_tlu_flush_lower_wb=1;
  tick(); dec_tlu_flush_lower_wb=0; exu_flush_final=0;
  begin_instruction(32'h00148513); consume_instruction();
endtask
task automatic test_fast_interrupt;
  reset(); dec_i0_instr_d=0; dec_ib0_valid_d=0;
  dec_tlu_flush_extint=1; tick(); dec_tlu_flush_extint=0; #1;
  require(dec_extint_stall===1'b1 && dec_i0_decode_d===1'b0,"fast interrupt decode bubble");
  require(lsu_p.valid===1'b1 && lsu_p.fast_int===1'b1 && lsu_p.load===1'b1 &&
    lsu_p.word===1'b1 && lsu_p.store===1'b0,"fast interrupt word lookup");
  require(dec_lsu_valid_raw_d===1'b1 && dec_qual_lsu_d===1'b1 &&
    dec_lsu_offset_d===12'b0,"fast interrupt address selection");
  tick(); require(dec_extint_stall===1'b0 && lsu_p.valid===1'b0,
    "fast interrupt request released");
endtask
task automatic test_trace(input bit compressed);
  int count;
  reset(); dec_i0_pc4_d=!compressed; ifu_i0_cinst=16'h4285;
  exu_i0_pc_x=31'h80; exu_i0_result_x=1;
  begin_instruction(32'h00100293); consume_instruction(); count=0;
  while(dec_tlu_i0_valid_r!==1'b1 && count<128) begin tick(); count++; end
  if(dec_tlu_i0_valid_r!==1'b1) $fatal(1,"DECODER_PORT_TIMEOUT: trace R event");
  // The supplied TLU advances an ordinary committed R event to wb+1.
  tick();
  require(dec_i0_inst_wb===(compressed ? 32'h00004285 : 32'h00100293),
    "trace original instruction");
  require(dec_i0_pc_wb===31'h80,"trace associated PC");
endtask
task automatic test_debug_fence(input logic [1:0] bits);
  int count;
  reset(); dec_debug_fence_d=1; dec_debug_valid_d=1; dbg_cmd_wrdata=bits;
  dec_i0_instr_d={12'h7c4,5'd5,3'b001,5'd0,7'b1110011};
  lsu_idle_any=0; repeat(3) tick(); dec_ib0_valid_d=1; #1;
  repeat(3) begin require(dec_i0_decode_d===1'b0,"dmst waits LSU"); tick(); end
  lsu_idle_any=1; begin_instruction(dec_i0_instr_d); consume_instruction();
  dec_debug_fence_d=0; dec_debug_valid_d=0; dbg_cmd_wrdata=0; count=0;
  while(dec_tlu_i0_valid_r!==1'b1 && count<128) begin tick(); count++; end
  if(dec_tlu_i0_valid_r!==1'b1) $fatal(1,"DECODER_PORT_TIMEOUT: dmst R valid");
  require(dec_tlu_packet_r.fence_i===bits[0],"dmst bit0 fence.i");
endtask
task automatic test_pause_start;
  int remaining;
  reset();
  exu_csr_rs1_x=32'd8; exu_i0_result_x=32'd8;
  begin_instruction({12'h7c2,5'd1,3'b001,5'd0,7'b1110011});
  consume_instruction(); wait_write(1);
  require(dec_csr_wraddr_r===12'h7c2 && dec_csr_wrdata_r===32'd8,"mcpc write at R");

  // With no interrupt, the retiring MCPC write starts pause.
  // The fixed TLU reports its startup flush to R one cycle later, then to WB.
  dec_tlu_wr_pause_r=1; tick(); dec_tlu_wr_pause_r=0;
  dec_tlu_flush_pause_r=1; dec_tlu_flush_lower_r=1;
  tick(); dec_tlu_flush_pause_r=0; dec_tlu_flush_lower_r=0;
  require(dec_pause_state===1'b1,"MCPC startup flush preserves pause");
  dec_tlu_flush_lower_wb=1; tick(); dec_tlu_flush_lower_wb=0;

  // The reference expires within 8 clocks; the budget is 10 times that.
  remaining=80;
  while (dec_pause_state===1'b1 && remaining>0) begin
    tick(); remaining--;
  end
  require(dec_pause_state===1'b0,"MCPC pause expires without an interrupt");
endtask
initial begin
  test_lsu(32'hffc1a383,1,0,1,0,12'hffc,5'd3,5'd0);
  test_lsu(32'h0041c383,1,1,0,1,12'h004,5'd3,5'd0);
  test_lsu(32'h00910623,0,1,0,0,12'h00c,5'd2,5'd9);
  test_stall(32'hffc1a383,0); test_stall(32'h00910623,1);
  test_stall(32'hffc1a383,2); test_stall(32'h00910623,2);
  test_csr(3'b010,5'd5,5'd6,32'h0f0f0f0f,32'h0fff0fff,1);
  test_csr(3'b011,5'd5,5'd6,32'h0f0f0f0f,32'h00f000f0,1);
  test_csr(3'b001,5'd5,5'd6,32'h0f0f0f0f,32'h0f0f0f0f,1);
  test_csr_zero(3'b010); test_csr_zero(3'b011);
  test_csr(3'b001,5'd0,5'd0,32'h0,32'h0,0);
  test_csr(3'b001,5'd0,5'd6,32'h0f0f0f0f,32'h0f0f0f0f,0);
  test_kill(0); test_kill(1);
  test_branch(0,1); test_branch(1,1); test_branch(0,0); test_branch(1,0);
  test_debug_fence(2'b01); test_debug_fence(2'b10);
  test_fetch_fault(0); test_fetch_fault(1);
  test_nonblock_return(0); test_nonblock_return(1);
  test_nonblock_cancel(); test_nonblock_younger();
  test_division(0,0); test_division(1,0); test_division(0,1); test_division(1,1);
  test_division_cancel(); test_fast_interrupt(); test_trace(0); test_trace(1);
  test_pause_start();
  $display("DECODER_PORT_PASS: %0d assertions",checks); $finish;
end
endmodule
