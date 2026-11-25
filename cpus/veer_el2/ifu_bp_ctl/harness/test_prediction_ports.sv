module cpu_eval_prediction_ports
import el2_pkg::*;
#(
`include "el2_param.vh"
);
  logic clk=0, rst_l=0, scan_mode=0, ic_hit_f=0, ifc_fetch_req_f=0;
  logic [31:1] ifc_fetch_addr_f=0, training_pc=0;
  logic [pt.BHT_GHR_SIZE-1:0] exu_i0_br_fghr_r=0, exu_mp_eghr=0, exu_mp_fghr=0;
  wire [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] exu_mp_index;
  logic [pt.BTB_ADDR_HI:pt.BTB_ADDR_LO] exu_i0_br_index_r=0;
  wire [pt.BTB_BTAG_SIZE-1:0] exu_mp_btag;
  logic [$clog2(pt.BTB_SIZE)-1:0] dec_fa_error_index=0;
  logic dec_tlu_flush_lower_wb=0, dec_tlu_flush_leak_one_wb=0;
  logic dec_tlu_bpred_disable=0, exu_flush_final=0;
  el2_br_tlu_pkt_t dec_tlu_br0_r_pkt='0;
  el2_predict_pkt_t exu_mp_pkt='0;
  wire ifu_bp_hit_taken_f, ifu_bp_inst_mask_f;
  wire [31:1] ifu_bp_btb_target_f;
  wire [pt.BHT_GHR_SIZE-1:0] ifu_bp_fghr_f;
  wire [1:0] ifu_bp_way_f, ifu_bp_ret_f, ifu_bp_hist1_f, ifu_bp_hist0_f;
  wire [1:0] ifu_bp_pc4_f, ifu_bp_valid_f;
  wire [11:0] ifu_bp_poffset_f;
  wire [1:0][$clog2(pt.BTB_SIZE)-1:0] ifu_bp_fa_index_f;
  el2_ifu_bp_ctl #(.pt(pt)) dut(.*);
  el2_btb_addr_hash #(.pt(pt)) index_api(
    .pc(training_pc[pt.BTB_INDEX3_HI:pt.BTB_INDEX1_LO]), .hash(exu_mp_index));
  el2_btb_tag_hash #(.pt(pt)) tag_api(
    .pc(training_pc[pt.BTB_ADDR_HI+3*pt.BTB_BTAG_SIZE:pt.BTB_ADDR_HI+1]), .hash(exu_mp_btag));
  int clocks=0, observed=0;
  logic learned_way;
  task automatic tick;
    #4; clk=1; #4; clk=0; #1; clocks++;
  endtask
  task automatic train(input logic [31:1] pc, input logic pc4);
    ifc_fetch_addr_f=pc; ifc_fetch_req_f=1; ic_hit_f=1; #2;
    learned_way=ifu_bp_way_f[pc4];
    ifc_fetch_req_f=0; ic_hit_f=0; training_pc=pc;
    exu_mp_pkt='0; exu_mp_pkt.misp=1; exu_mp_pkt.ataken=1;
    exu_mp_pkt.way=learned_way;
    exu_mp_pkt.hist=2'b10; exu_mp_pkt.pc4=pc4; exu_mp_pkt.toffset=12'd4;
    tick(); exu_mp_pkt='0;
  endtask
  task automatic lookup(input logic [31:1] pc, input logic pc4);
    ifc_fetch_addr_f=pc; ifc_fetch_req_f=1; ic_hit_f=1; #2;
    // Update acceptance has no ready/ack port. Poll without consuming a fetch.
    for(int wait_cycles=0; wait_cycles<8 &&
        (!ifu_bp_valid_f[pc4] || ifu_bp_hist1_f[pc4]!==1 || ifu_bp_hist0_f[pc4]!==0);
        wait_cycles++) begin
      ifc_fetch_req_f=0; ic_hit_f=0; tick();
      ifc_fetch_req_f=1; ic_hit_f=1; #2;
    end
    if (!ifu_bp_valid_f[pc4] || ifu_bp_hist1_f[pc4]!==1 || ifu_bp_hist0_f[pc4]!==0)
      $fatal(1,"learned lookup was not observed within diagnostic budget");
    if (ifu_bp_valid_f!==(pc4 ? 2'b10 : 2'b01) ||
        ifu_bp_pc4_f!==(pc4 ? 2'b10 : 2'b00) ||
        ifu_bp_poffset_f!==12'd4 || !ifu_bp_hit_taken_f ||
        ifu_bp_btb_target_f!==pc+31'd4 || ifu_bp_inst_mask_f!==pc4)
      $fatal(1,"PREDICTION_FUNCTION_MISMATCH learned branch identity or target");
    if (ifu_bp_hist1_f[pc4]!==1 || ifu_bp_hist0_f[pc4]!==0)
      $fatal(1,"PREDICTION_FUNCTION_MISMATCH supplied direction history");
    observed++;
    learned_way=ifu_bp_way_f[pc4];
  endtask
  task automatic restore_history;
    ifc_fetch_req_f=0; ic_hit_f=0; exu_flush_final=1; exu_mp_fghr=0;
    // The reference restores in 2 clocks; the budget is 10 times that.
    tick(); exu_flush_final=0; repeat(19) tick();
    if (ifu_bp_fghr_f!==0) $fatal(1,"history restoration was not observed within diagnostic budget");
    observed++;
  endtask
  initial begin
    if (!pt.BTB_ENABLE || pt.BTB_FULLYA || pt.BTB_BTAG_FOLD)
      $fatal(1,"this directed fixture requires default prediction configuration");
    repeat(3) tick(); rst_l=1; tick();
    ifc_fetch_req_f=1; ic_hit_f=1; #2;
    if (ifu_bp_hit_taken_f || ifu_bp_valid_f!==0)
      $fatal(1,"PREDICTION_FUNCTION_MISMATCH reset exposed a learned branch");
    observed++;
    ifc_fetch_req_f=0; ic_hit_f=0;
    train(31'h40000800,0);
    lookup(31'h40000800,0);
    ic_hit_f=0;
    tick();
    if (ifu_bp_fghr_f!==0)
      $fatal(1,"PREDICTION_FUNCTION_MISMATCH cache miss advanced fetch history");
    observed++;
    ic_hit_f=1;
    tick();
    if (ifu_bp_fghr_f!==1)
      $fatal(1,"PREDICTION_FUNCTION_MISMATCH single predicted branch history");
    observed++;
    dec_tlu_bpred_disable=1; #2;
    if (ifu_bp_hit_taken_f || ifu_bp_valid_f!==0)
      $fatal(1,"PREDICTION_FUNCTION_MISMATCH prediction disable");
    observed++; ifc_fetch_req_f=0; dec_tlu_bpred_disable=0;
    restore_history();
    dec_tlu_br0_r_pkt.br_error=1; dec_tlu_br0_r_pkt.way=learned_way;
    exu_i0_br_index_r=exu_mp_index; tick(); dec_tlu_br0_r_pkt='0;
    ifc_fetch_req_f=1; #2;
    for(int wait_cycles=0; wait_cycles<8 && (ifu_bp_valid_f!==0 || ifu_bp_hit_taken_f);
        wait_cycles++) begin
      ifc_fetch_req_f=0; ic_hit_f=0; tick();
      ifc_fetch_req_f=1; ic_hit_f=1; #2;
    end
    if (ifu_bp_valid_f!==0 || ifu_bp_hit_taken_f)
      $fatal(1,"retired branch repair was not observed within diagnostic budget");
    observed++; ifc_fetch_req_f=0;
    train(31'h40000820,1);
    lookup(31'h40000820,1);
    $display("PASS prediction public ports observations=%0d clocks=%0d",observed,clocks);
    $finish;
  end
endmodule
