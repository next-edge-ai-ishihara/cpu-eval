module cpu_eval_aln_ports
import el2_pkg::*;
#(
`include "el2_param.vh"
);
  logic clk=0;
  wire active_clk=clk;
  logic rst_l=0, scan_mode=0, ifu_async_error_start=0;
  logic [1:0] iccm_rd_ecc_double_err=0, ic_access_fault_f=0, ic_access_fault_type_f=0;
  logic exu_flush_final=0, dec_i0_decode_d=0;
  logic [31:0] ifu_fetch_data_f=0;
  logic [1:0] ifu_fetch_val=0;
  logic [31:1] ifu_fetch_pc=0;
  wire ifu_i0_valid, ifu_i0_icaf, ifu_i0_icaf_second, ifu_i0_dbecc, ifu_i0_pc4;
  wire [1:0] ifu_i0_icaf_type;
  wire [31:0] ifu_i0_instr;
  wire [31:1] ifu_i0_pc;
  wire ifu_fb_consume1, ifu_fb_consume2, ifu_pmu_instr_aligned;
  logic [pt.BHT_GHR_SIZE-1:0] ifu_bp_fghr_f=0;
  logic [31:1] ifu_bp_btb_target_f=0;
  logic [11:0] ifu_bp_poffset_f=0;
  logic [1:0][$clog2(pt.BTB_SIZE)-1:0] ifu_bp_fa_index_f=0;
  logic [1:0] ifu_bp_hist0_f=0,ifu_bp_hist1_f=0,ifu_bp_pc4_f=0;
  logic [1:0] ifu_bp_way_f=0,ifu_bp_valid_f=0,ifu_bp_ret_f=0;
  wire el2_br_pkt_t i0_brp;
  wire [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] ifu_i0_bp_index;
  wire [pt.BHT_GHR_SIZE-1:0] ifu_i0_bp_fghr;
  wire [pt.BTB_BTAG_SIZE-1:0] ifu_i0_bp_btag;
  wire [$clog2(pt.BTB_SIZE)-1:0] ifu_i0_fa_index;
  wire [15:0] ifu_i0_cinst;
  logic [31:1] expected_prediction_pc=0;
  wire [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] expected_index;
  wire [pt.BTB_BTAG_SIZE-1:0] expected_tag;
  el2_ifu_aln_ctl #(.pt(pt)) dut(.*);
  el2_btb_addr_hash #(.pt(pt)) index_api(
    .pc(expected_prediction_pc[pt.BTB_INDEX3_HI:pt.BTB_INDEX1_LO]),.hash(expected_index));
  el2_btb_tag_hash #(.pt(pt)) tag_api(
    .pc(expected_prediction_pc[pt.BTB_ADDR_HI+3*pt.BTB_BTAG_SIZE:pt.BTB_ADDR_HI+1]),.hash(expected_tag));
  int observed=0, clocks=0;
  int consume_counts[3]='{0,0,0};
  task automatic tick;
    #4; clk=1; #4; clk=0; #1; clocks++;
  endtask
  task automatic fetch(input logic [31:0] data,input logic [1:0] valid,
      input logic [31:1] pc,input logic [1:0] hist0,input logic [1:0] hist1,
      input logic [1:0] predvalid,input logic [1:0] predpc4,input logic [1:0] way);
    ifu_fetch_data_f=data; ifu_fetch_val=valid; ifu_fetch_pc=pc;
    ifu_bp_hist0_f=hist0; ifu_bp_hist1_f=hist1; ifu_bp_valid_f=predvalid;
    ifu_bp_pc4_f=predpc4; ifu_bp_way_f=way;
    tick(); ifu_fetch_val=0;
  endtask
  task automatic check_payload(input logic [31:0] instruction,input logic [31:1] pc,
      input logic pc4,input logic [1:0] hist,input logic way);
    if (ifu_i0_instr!==instruction || ifu_i0_pc!==pc || ifu_i0_pc4!==pc4)
      $fatal(1,"ALIGNMENT_FUNCTION_MISMATCH instruction/PC association expected=%h/%h actual=%h/%h",instruction,pc,ifu_i0_instr,ifu_i0_pc);
    if (!i0_brp.valid || i0_brp.hist!==hist)
      $fatal(1,"ALIGNMENT_FUNCTION_MISMATCH ending-halfword history expected=%h actual=%h",hist,i0_brp.hist);
    if (i0_brp.way!==way || ifu_i0_bp_index!==expected_index || ifu_i0_bp_btag!==expected_tag)
      $fatal(1,"ALIGNMENT_FUNCTION_MISMATCH prediction identity expected index/tag=%h/%h actual=%h/%h",expected_index,expected_tag,ifu_i0_bp_index,ifu_i0_bp_btag);
  endtask
  task automatic consume(input logic [31:0] instruction,input logic [31:1] pc,
      input logic pc4,input logic [1:0] hist,input logic way,
      input logic [31:1] prediction_pc,input int emptied);
    int waited;
    waited=0;
    while (!ifu_i0_valid && waited<16) begin tick(); waited++; end
    if (!ifu_i0_valid) $fatal(1,"instruction did not become valid");
    expected_prediction_pc=prediction_pc; #1;
    check_payload(instruction,pc,pc4,hist,way);
    // The consumer can remain stalled; valid instruction data must remain available.
    tick(); tick();
    if (!ifu_i0_valid)
      $fatal(1,"ALIGNMENT_FUNCTION_MISMATCH instruction was not retained during a decode stall");
    check_payload(instruction,pc,pc4,hist,way);
    dec_i0_decode_d=1; #1;
    if (ifu_fb_consume1!==(emptied==1) || ifu_fb_consume2!==(emptied==2))
      $fatal(1,"ALIGNMENT_FUNCTION_MISMATCH fetch-buffer accounting expected=%0d actual=%b%b",emptied,ifu_fb_consume2,ifu_fb_consume1);
    tick(); dec_i0_decode_d=0; observed++; consume_counts[emptied]++;
  endtask
  initial begin
    if (!pt.BTB_ENABLE || pt.BTB_FULLYA || pt.BTB_BTAG_FOLD)
      $fatal(1,"this directed fixture requires the selected default prediction configuration");
    repeat(3) tick(); rst_l=1; tick();
    // Three fetch buffers: one whole instruction, then a compressed instruction
    // followed by the first half of a word, then the word's final halfword.
    fetch(32'h00000463,2'b11,31'h40000800,2'b10,2'b00,2'b10,2'b10,2'b10);
    fetch(32'h04630001,2'b11,31'h40000802,2'b01,2'b00,2'b01,2'b00,2'b00);
    fetch(32'h00000000,2'b01,31'h40000804,2'b00,2'b01,2'b01,2'b01,2'b01);
    consume(32'h00000463,31'h40000800,1,2'b01,1,31'h40000801,1);
    consume(32'h00000013,31'h40000802,0,2'b01,0,31'h40000802,0);
    consume(32'h00000463,31'h40000803,1,2'b10,1,31'h40000804,2);
    repeat(3) tick();
    if (ifu_i0_valid) $fatal(1,"ALIGNMENT_FUNCTION_MISMATCH consumed instruction remained valid");
    // Flush discards an unconsumed buffer. A subsequent fetch starts a new stream.
    fetch(32'h00000001,2'b01,31'h40000900,2'b01,2'b00,2'b01,2'b00,2'b00);
    exu_flush_final=1; tick(); exu_flush_final=0; tick(); tick();
    if (ifu_i0_valid) $fatal(1,"ALIGNMENT_FUNCTION_MISMATCH flushed instruction remained valid");
    // A legal 16-bit-aligned fetch may start in the upper half of a word.
    // The next halfword's PC must carry into the next word.
    fetch(32'h00010001,2'b11,31'h40000a01,2'b11,2'b00,2'b11,2'b00,2'b00);
    consume(32'h00000013,31'h40000a01,0,2'b01,0,31'h40000a01,0);
    consume(32'h00000013,31'h40000a02,0,2'b01,0,31'h40000a02,1);
    // A word starting at byte offset six spans two 64-bit memory beats.
    // The fetch bypass reports a bus error on the second halfword with mask 10.
    ic_access_fault_f=2'b10;
    fetch(32'h00000463,2'b11,31'h40000b03,2'b00,2'b00,2'b00,2'b00,2'b00);
    ic_access_fault_f=0;
    for (int waited=0; !ifu_i0_valid && waited<16; waited++) tick();
    if (ifu_i0_valid!==1'b1 || ifu_i0_pc!==31'h40000b03 ||
        ifu_i0_icaf!==1'b1 || ifu_i0_icaf_second!==1'b1 ||
        ifu_i0_dbecc!==1'b0 || ifu_i0_icaf_type!==2'b00)
      $fatal(1,"ALIGNMENT_FUNCTION_MISMATCH second-halfword bus fault valid=%b pc=%h access=%b second=%b ecc=%b type=%b",
             ifu_i0_valid,ifu_i0_pc,ifu_i0_icaf,ifu_i0_icaf_second,ifu_i0_dbecc,ifu_i0_icaf_type);
    $display("PASS alignment public ports observations=%0d clocks=%0d consume0=%0d consume1=%0d consume2=%0d flush_discard=1 second_halfword_fault=1",
      observed,clocks,consume_counts[0],consume_counts[1],consume_counts[2]);
    $finish;
  end
endmodule
