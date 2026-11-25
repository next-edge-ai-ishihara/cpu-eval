module dec_operand_tb
  import el2_pkg::*;
#(
`include "el2_param.vh"
) ();
`include "dec_ports.svh"
el2_dec #(.pt(pt)) dut (.*);
logic [31:0] expected_register[32];
logic [31:0] first_operand, second_operand;
int checks = 0;
int instructions = 0;
int trace_index = 0;
int trace_checks = 0;
bit debug_phase = 0;
bit interrupt_phase = 0;
int interrupt_checks = 0;
int interrupt_events = 0;
int debug_checks = 0;
int csr_checks = 0;
logic [31:0] debug_write_data;
logic [31:0] expected_scratch = 0;
logic [31:0] expected_trace_instruction[128];
logic [31:0] expected_trace_pc[128];
logic [31:0] next_pc = 32'h80000000;
localparam logic [31:0] ILLEGAL_SHIFT = 32'h02001013;

function automatic bit raises_exception(input logic [31:0] instruction);
  return instruction == 32'h00000073 || instruction == ILLEGAL_SHIFT;
endfunction

always_comb begin
  first_operand = dec_i0_rs1_en_d ? gpr_i0_rs1_d : 0;
  if (dec_debug_wdata_rs1_d) first_operand = debug_write_data;
  second_operand = ({32{dec_i0_rs2_en_d}} & gpr_i0_rs2_d) | dec_i0_immed_d;
  if (|dec_i0_rs1_bypass_en_d)
    first_operand = ({32{dec_i0_rs1_bypass_en_d[0]}} & dec_i0_result_r) |
                    ({32{dec_i0_rs1_bypass_en_d[1]}} & lsu_result_m) |
                    ({32{dec_i0_rs1_bypass_en_d[2]}} & exu_i0_result_x) |
                    ({32{dec_i0_rs1_bypass_en_d[3]}} & lsu_nonblock_load_data);
  if (|dec_i0_rs2_bypass_en_d)
    second_operand = ({32{dec_i0_rs2_bypass_en_d[0]}} & dec_i0_result_r) |
                     ({32{dec_i0_rs2_bypass_en_d[1]}} & lsu_result_m) |
                     ({32{dec_i0_rs2_bypass_en_d[2]}} & exu_i0_result_x) |
                     ({32{dec_i0_rs2_bypass_en_d[3]}} & lsu_nonblock_load_data);
end

always @(posedge clk) begin
  if (rst_l && dec_i0_decode_d && debug_phase) begin
    exu_i0_result_x <= dec_csr_ren_d ? dec_csr_rddata_d : first_operand | second_operand;
    exu_csr_rs1_x <= first_operand;
    exu_i0_pc_x <= dec_i0_pc_d;
  end
  if (rst_l && dec_i0_decode_d && !debug_phase) begin
    logic [4:0] rs1, rs2, rd;
    logic [31:0] expected_second, expected_result;
    bit load_operation, divide_operation, csr_operation, exception_operation;
    rs1 = ifu_i0_instr[19:15]; rs2 = ifu_i0_instr[24:20]; rd = ifu_i0_instr[11:7];
    load_operation = ifu_i0_instr[6:0] == 7'h03;
    exception_operation = raises_exception(ifu_i0_instr);
    csr_operation = ifu_i0_instr[6:0] == 7'h73 && !exception_operation;
    divide_operation = ifu_i0_instr[6:0] == 7'h33 && ifu_i0_instr[31:25] == 7'h01 && ifu_i0_instr[14];
    expected_second = ifu_i0_instr[6:0] == 7'h13 || load_operation ?
                      {{20{ifu_i0_instr[31]}}, ifu_i0_instr[31:20]} : expected_register[rs2];
    if (ifu_i0_instr != ILLEGAL_SHIFT && first_operand !== expected_register[rs1])
      $fatal(1, "DEC_OPERAND_MISMATCH: rs1 instruction=%h actual=%h expected=%h",
             ifu_i0_instr, first_operand, expected_register[rs1]);
    if (ifu_i0_instr != ILLEGAL_SHIFT && !csr_operation && second_operand !== expected_second)
      $fatal(1, "DEC_OPERAND_MISMATCH: rs2 instruction=%h actual=%h expected=%h",
             ifu_i0_instr, second_operand, expected_second);
    if (csr_operation) begin
      if (dec_csr_ren_d !== 1 || dec_csr_rddata_d !== expected_scratch)
        $fatal(1, "DEC_OPERAND_MISMATCH: CSR operand actual=%h expected=%h read=%b",
               dec_csr_rddata_d, expected_scratch, dec_csr_ren_d);
    end else if (load_operation) begin
      if (lsu_p.valid !== 1 || lsu_p.load !== 1 || lsu_p.word !== 1 || dec_lsu_offset_d !== 0)
        $fatal(1, "DEC_OPERAND_MISMATCH: word load request");
    end else if (divide_operation) begin
      if (div_p.valid !== 1 || div_p.unsign !== ifu_i0_instr[12] || div_p.rem !== ifu_i0_instr[13])
        $fatal(1, "DEC_OPERAND_MISMATCH: divide request");
    end else if (!exception_operation && ((ifu_i0_instr[30] && ifu_i0_instr[6:0] == 7'h33) ?
        (i0_ap.sub !== 1 || i0_ap.add !== 0) : (i0_ap.add !== 1 || i0_ap.sub !== 0))
      ) $fatal(1, "DEC_OPERAND_MISMATCH: ALU operation instruction=%h", ifu_i0_instr);
    if (ifu_i0_instr != ILLEGAL_SHIFT) checks += exception_operation ? 2 : 3;
    expected_result = ifu_i0_instr[30] && ifu_i0_instr[6:0] == 7'h33 ?
                      expected_register[rs1] - expected_second : expected_register[rs1] + expected_second;
    if (csr_operation) begin
      expected_result = expected_scratch;
      case (ifu_i0_instr[14:12])
        1: expected_scratch = expected_register[rs1];
        2: expected_scratch |= expected_register[rs1];
        3: expected_scratch &= ~expected_register[rs1];
        default: $fatal(1, "DEC_OPERAND_MISMATCH: unsupported CSR fixture instruction");
      endcase
    end
    exu_csr_rs1_x <= first_operand;
    exu_i0_result_x <= csr_operation ? dec_csr_rddata_d : ifu_i0_instr[30] && ifu_i0_instr[6:0] == 7'h33 ?
                       first_operand - second_operand : first_operand + second_operand;
    exu_i0_pc_x <= dec_i0_pc_d;
    if (rd != 0 && !load_operation && !divide_operation && !exception_operation)
      expected_register[rd] = expected_result;
    expected_trace_instruction[instructions] = ifu_i0_instr;
    expected_trace_pc[instructions] = {ifu_i0_pc, 1'b0};
    instructions++;
  end
  if (rst_l && trace_rv_trace_pkt.trace_rv_i_valid_ip && interrupt_phase) begin
    if (trace_rv_trace_pkt.trace_rv_i_exception_ip !== 1 ||
        trace_rv_trace_pkt.trace_rv_i_interrupt_ip !== 1 ||
        trace_rv_trace_pkt.trace_rv_i_ecause_ip !== 0 ||
        trace_rv_trace_pkt.trace_rv_i_tval_ip !== 0)
      $fatal(1, "DEC_OPERAND_MISMATCH: NMI classification cause=%h interrupt=%b exception=%b tval=%h",
             trace_rv_trace_pkt.trace_rv_i_ecause_ip, trace_rv_trace_pkt.trace_rv_i_interrupt_ip,
             trace_rv_trace_pkt.trace_rv_i_exception_ip, trace_rv_trace_pkt.trace_rv_i_tval_ip);
    interrupt_events++; interrupt_checks += 4;
  end
  if (rst_l && trace_rv_trace_pkt.trace_rv_i_valid_ip && !interrupt_phase) begin
    if (trace_index >= instructions)
      $fatal(1, "DEC_OPERAND_MISMATCH: unexpected trace event");
    if (trace_rv_trace_pkt.trace_rv_i_insn_ip !== expected_trace_instruction[trace_index])
      $fatal(1, "DEC_OPERAND_MISMATCH: trace instruction index=%0d actual=%h expected=%h",
             trace_index, trace_rv_trace_pkt.trace_rv_i_insn_ip, expected_trace_instruction[trace_index]);
    if (trace_rv_trace_pkt.trace_rv_i_address_ip !== expected_trace_pc[trace_index])
      $fatal(1, "DEC_OPERAND_MISMATCH: trace PC index=%0d actual=%h expected=%h",
             trace_index, trace_rv_trace_pkt.trace_rv_i_address_ip, expected_trace_pc[trace_index]);
    if (trace_rv_trace_pkt.trace_rv_i_exception_ip !== raises_exception(expected_trace_instruction[trace_index]) ||
        trace_rv_trace_pkt.trace_rv_i_interrupt_ip !== 0)
      $fatal(1, "DEC_OPERAND_MISMATCH: trace exception or interrupt classification");
    if (expected_trace_instruction[trace_index] == 32'h00000073) begin
      if (trace_rv_trace_pkt.trace_rv_i_ecause_ip !== 5'd11 || trace_rv_trace_pkt.trace_rv_i_tval_ip !== 0)
        $fatal(1, "DEC_OPERAND_MISMATCH: ECALL cause=%h tval=%h",
               trace_rv_trace_pkt.trace_rv_i_ecause_ip, trace_rv_trace_pkt.trace_rv_i_tval_ip);
      trace_checks += 2;
    end
    if (expected_trace_instruction[trace_index] == ILLEGAL_SHIFT) begin
      if (trace_rv_trace_pkt.trace_rv_i_ecause_ip !== 5'd2 ||
          trace_rv_trace_pkt.trace_rv_i_tval_ip !== ILLEGAL_SHIFT)
        $fatal(1, "DEC_OPERAND_MISMATCH: illegal instruction cause=%h tval=%h expected=%h",
               trace_rv_trace_pkt.trace_rv_i_ecause_ip, trace_rv_trace_pkt.trace_rv_i_tval_ip, ILLEGAL_SHIFT);
      trace_checks += 2;
    end
    trace_checks += 4;
    trace_index++;
  end
end

task automatic tick;
  #5; clk=1; active_clk=1; free_clk=1; free_l2clk=1;
  #5; clk=0; active_clk=0; free_clk=0; free_l2clk=0; #1;
endtask

task automatic debug_scratch(input bit writing, input logic [31:0] value);
  debug_write_data = value;
  dbg_cmd_addr = 32'h340; dbg_cmd_type = 1; dbg_cmd_write = writing; dbg_cmd_valid = 1;
  tick(); dbg_cmd_valid = 0;
  for (int cycle = 0; dec_dbg_cmd_done !== 1 && cycle < 128; cycle++) tick();
  if (dec_dbg_cmd_done !== 1) $fatal(1, "DEC_OPERAND_TIMEOUT: CSR debug command");
  if (dec_dbg_cmd_fail !== 0) $fatal(1, "DEC_OPERAND_MISMATCH: CSR debug command failed");
  if (!writing && dec_dbg_rddata !== value)
    $fatal(1, "DEC_OPERAND_MISMATCH: CSR readback actual=%h expected=%h", dec_dbg_rddata, value);
  csr_checks++;
  tick(); tick();
endtask

task automatic send(input logic [31:0] instruction);
  int cycles;
  ifu_i0_instr = instruction; ifu_i0_valid = 1; ifu_i0_pc = next_pc[31:1];
  #1; cycles = 0;
  while (dec_i0_decode_d !== 1 && cycles < 128) begin tick(); cycles++; end
  if (dec_i0_decode_d !== 1) $fatal(1, "DEC_OPERAND_TIMEOUT: D acceptance instruction=%h", instruction);
  tick(); ifu_i0_valid = 0; next_pc += 4;
endtask

function automatic logic [31:0] addi(input logic [4:0] rd, rs1, input logic [11:0] immediate);
  return {immediate, rs1, 3'b000, rd, 7'h13};
endfunction

task automatic test_nonblock_load(input bit simultaneous);
  bit accepted;
  send(32'h0001a383);
  lsu_nonblock_load_valid_m = 1; lsu_nonblock_load_tag_m = 3; tick();
  lsu_nonblock_load_valid_m = 0; lsu_nonblock_load_inv_tag_r = 3; tick();
  repeat(3) tick();
  lsu_nonblock_load_data_tag = 3;
  lsu_nonblock_load_data = simultaneous ? 32'h12345678 : 32'h87654321;
  lsu_nonblock_load_data_valid = 1;
  expected_register[7] = lsu_nonblock_load_data;
  accepted = 0;
  if (simultaneous) begin
    ifu_i0_instr = addi(0, 7, 0); ifu_i0_valid = 1; ifu_i0_pc = next_pc[31:1];
    #1; accepted = dec_i0_decode_d === 1;
    if (!accepted) ifu_i0_valid = 0;
  end
  tick(); ifu_i0_valid = 0; lsu_nonblock_load_data_valid = 0;
  if (accepted) next_pc += 4; else send(addi(0, 7, 0));
  repeat(4) tick(); send(addi(0, 7, 0));
endtask

task automatic test_division(input bit unsigned_operation, remainder_operation);
  logic [31:0] completion;
  send(32'h02b544b3 | (unsigned_operation ? 32'h1000 : 0) | (remainder_operation ? 32'h2000 : 0));
  repeat(8) tick();
  if (unsigned_operation)
    completion = remainder_operation ? expected_register[10] % expected_register[11] :
                                       expected_register[10] / expected_register[11];
  else
    completion = remainder_operation ? $signed(expected_register[10]) % $signed(expected_register[11]) :
                                       $signed(expected_register[10]) / $signed(expected_register[11]);
  exu_div_result = completion; exu_div_wren = 1;
  expected_register[9] = completion;
  tick(); exu_div_wren = 0;
  send(addi(0, 9, 0));
endtask

initial begin
  zero_inputs();
  foreach(expected_register[i]) expected_register[i] = 0;
  rst_vec = 31'h40000000; mpc_reset_run_req = 1;
  lsu_idle_any = 1; ifu_miss_state_idle = 1; ifu_i0_pc4 = 1;
  lsu_nonblock_load_data = 32'h5a5a5a5a;
  rst_l = 0; tick(); tick(); rst_l = 1; repeat(8) tick();
  send(addi(5, 0, 12'h135)); send(addi(6, 0, 12'h246));
  send(addi(10, 0, 1)); send(addi(11, 0, 2)); send(addi(12, 0, 3));
  send({7'b0, 5'd6, 5'd5, 3'b000, 5'd7, 7'h33});
  send({7'b0100000, 5'd6, 5'd5, 3'b000, 5'd8, 7'h33});
  for (int regnum = 1; regnum < 32; regnum++) send(addi(5'(regnum), 0, 12'(regnum * 17)));
  send(addi(10, 0, 1)); send(addi(11, 0, 2)); send(addi(12, 0, 3));
  for (int regnum = 1; regnum < 32; regnum++) send(addi(0, 5'(regnum), 0));
  send(addi(5, 0, 12'h321)); send(addi(5, 0, 12'h654));
  send(addi(10, 0, 1)); send(addi(11, 0, 2)); send(addi(12, 0, 3));
  send(addi(0, 5, 0));
  send(addi(3, 0, 1)); send(addi(10, 0, 1)); send(addi(11, 0, 2)); send(addi(12, 0, 3));
  send(addi(0, 3, 0)); send(addi(0, 0, 12'h123)); send(addi(0, 0, 0));
  test_nonblock_load(0); test_nonblock_load(1);
  send(addi(10, 0, 12'hf9c)); send(addi(11, 0, 7));
  test_division(0, 0); test_division(1, 0); test_division(0, 1); test_division(1, 1);
  send({12'h340, 5'd5, 3'b001, 5'd13, 7'h73}); send(addi(0, 13, 0));
  send({12'h340, 5'd6, 3'b010, 5'd14, 7'h73}); send(addi(0, 14, 0));
  send({12'h340, 5'd5, 3'b011, 5'd15, 7'h73}); send(addi(0, 15, 0));
  send(32'h00000073);
  repeat(8) tick();
  send(ILLEGAL_SHIFT);
  repeat(8) tick();
  for (int cycle = 0; trace_index < instructions && cycle < 128; cycle++) tick();
  if (trace_index != instructions) $fatal(1, "DEC_OPERAND_TIMEOUT: incomplete trace");
  interrupt_phase = 1;
  nmi_vec = 31'h40000100; nmi_int = 1;
  repeat(8) tick(); nmi_int = 0;
  for (int cycle = 0; interrupt_events == 0 && cycle < 128; cycle++) tick();
  if (interrupt_events == 0) $fatal(1, "DEC_OPERAND_TIMEOUT: missing NMI trace");
  repeat(8) tick();
  if (interrupt_events != 1) $fatal(1, "DEC_OPERAND_MISMATCH: duplicate NMI trace");
  interrupt_phase = 0;
  debug_phase = 1;
  dbg_halt_req = 1;
  for (int cycle = 0; dec_tlu_dbg_halted !== 1 && cycle < 128; cycle++) tick();
  if (dec_tlu_dbg_halted !== 1) $fatal(1, "DEC_OPERAND_TIMEOUT: debug halt");
  dbg_halt_req = 0;
  for (int regnum = 0; regnum < 32; regnum++) begin
    dbg_cmd_addr = regnum; dbg_cmd_type = 0; dbg_cmd_write = 0; dbg_cmd_valid = 1;
    tick(); dbg_cmd_valid = 0;
    for (int cycle = 0; dec_dbg_cmd_done !== 1 && cycle < 128; cycle++) tick();
    if (dec_dbg_cmd_done !== 1) $fatal(1, "DEC_OPERAND_TIMEOUT: debug command");
    if (dec_dbg_cmd_fail !== 0 || dec_dbg_rddata !== expected_register[regnum])
      $fatal(1, "DEC_OPERAND_MISMATCH: debug register=%0d actual=%h expected=%h failed=%b",
             regnum, dec_dbg_rddata, expected_register[regnum], dec_dbg_cmd_fail);
    debug_checks++;
    tick(); tick();
  end
  $display("DEC_DEBUG_PASS: reads=%0d", debug_checks);
  debug_scratch(0, expected_scratch);
  debug_scratch(1, 32'h12345678); debug_scratch(0, 32'h12345678);
  debug_scratch(1, 32'hfedcba98); debug_scratch(0, 32'hfedcba98);
  debug_scratch(1, 0); debug_scratch(0, 0);
  $display("DEC_INTERRUPT_PASS: events=%0d checks=%0d", interrupt_events, interrupt_checks);
  $display("DEC_CSR_PASS: commands=%0d", csr_checks);
  $display("DEC_TRACE_PASS: events=%0d checks=%0d", trace_index, trace_checks);
  $display("DEC_OPERAND_PASS: instructions=%0d checks=%0d", instructions, checks);
  $finish;
end
endmodule
