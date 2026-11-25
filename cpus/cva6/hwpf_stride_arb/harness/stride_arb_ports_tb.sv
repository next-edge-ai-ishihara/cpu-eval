`include "hpdcache_typedef.svh"
module tb;
  import hpdcache_pkg::*;
  // The HPDcache configuration and request types that cv32a60x instantiates.
  function automatic hpdcache_cfg_t cfg();
    hpdcache_user_cfg_t u;
    u.nRequesters = 5; u.paWidth = 34; u.wordWidth = 32; u.sets = 64; u.ways = 2; u.clWords = 4;
    u.reqWords = 1; u.reqTransIdWidth = 1; u.reqSrcIdWidth = 3;
    u.victimSel = HPDCACHE_VICTIM_RANDOM; u.dataWaysPerRamWord = 2; u.dataSetsPerRam = 64;
    u.dataRamByteEnable = 1; u.accessWords = 2; u.mshrSets = 1; u.mshrWays = 2;
    u.mshrWaysPerRamWord = 2; u.mshrSetsPerRam = 1; u.mshrRamByteEnable = 1;
    u.mshrUseRegbank = 1; u.cbufEntries = 8; u.refillCoreRspFeedthrough = 1;
    u.refillFifoDepth = 4; u.wbufDirEntries = 8; u.wbufDataEntries = 8; u.wbufWords = 1;
    u.wbufTimecntWidth = 3; u.rtabEntries = 4; u.flushEntries = 8; u.flushFifoDepth = 8;
    u.memAddrWidth = 64; u.memIdWidth = 4; u.memDataWidth = 64; u.wtEn = 1; u.wbEn = 0;
    u.lowLatency = 1; u.eccEn = 0; u.eccScrubberEn = 0;
    return hpdcacheBuildConfig(u);
  endfunction
  localparam hpdcache_cfg_t C=cfg();
  `HPDCACHE_TYPEDEF_REQ_ATTR_T(offset_t, word_t, word_be_t, data_t, be_t, sid_t, tid_t, tag_t, C);
  `HPDCACHE_TYPEDEF_REQ_T(req_t, offset_t, data_t, be_t, sid_t, tid_t, tag_t);
  `HPDCACHE_TYPEDEF_RSP_T(rsp_t, data_t, sid_t, tid_t);
  logic clk=0, rst=0;
  logic [3:0] iv=0, ir, rv;
  req_t [3:0] req;
  rsp_t [3:0] rsp;
  logic ov, ready=0, response_valid=0;
  req_t out_req;
  rsp_t response;
  hwpf_stride_arb #(.NUM_HW_PREFETCH(4), .hpdcache_req_t(req_t), .hpdcache_rsp_t(rsp_t)) dut(
    .clk_i(clk), .rst_ni(rst), .hwpf_stride_req_valid_i(iv),
    .hwpf_stride_req_ready_o(ir), .hwpf_stride_req_i(req),
    .hwpf_stride_rsp_valid_o(rv), .hwpf_stride_rsp_o(rsp),
    .hpdcache_req_valid_o(ov), .hpdcache_req_ready_i(ready),
    .hpdcache_req_o(out_req), .hpdcache_rsp_valid_i(response_valid), .hpdcache_rsp_i(response));
  int sent[4], emitted[4], goals[4], total=0, phase=0, cycle=0;
  req_t expected[4][256], held_output;
  req_t [3:0] held_input;
  logic [3:0] input_stalled=0;
  bit output_stalled=0;
  logic [3:0] observed_sources=0;
  int rotation_checks=0;
  int rotation[4], rotation_count=0, phase_outputs=0, activations[4];
  logic [3:0] previous_valid=0;
  int response_owner=-1, response_count=0, input_hold_checks=0, output_hold_checks=0;

  task automatic fail(input string reason);
    $display("MISMATCH cycle=%0d phase=%0d reason=%s", cycle, phase, reason);
    $fatal(1);
  endtask
  function automatic req_t payload(input int s, input int q);
    req_t p;
    p='0;
    p.addr_offset=offset_t'(((phase+s+q)%64)<<4);
    // The tag marks the source; the one-bit tid is truncated as in the wrapper.
    p.addr_tag=tag_t'(s);
    p.op=HPDCACHE_REQ_CMO_PREFETCH;
    p.be='1;
    p.size='0;
    p.sid=3;
    p.tid=tid_t'(s);
    p.need_rsp=1;
    p.phys_indexed=1;
    return p;
  endfunction

  task automatic tick;
    int s;
    clk=0;
    #5;
    for (int i=0;i<4;i++) begin
      if (input_stalled[i]) begin
        input_hold_checks++;
        if (!iv[i] || req[i]!==held_input[i]) begin
          $display("INVALID producer_withdrew_stalled_request source=%0d",i);
          $finish;
        end
      end
    end
    if (output_stalled) begin
      output_hold_checks++;
      if (!ov || out_req!==held_output) fail("output_stall_changed");
    end
    for (int i=0;i<4;i++) begin
      if (iv[i] && ir[i]) begin
        if (sent[i]>=goals[i]) fail("unexpected_input_acceptance");
        expected[i][sent[i]]=req[i];
        sent[i]++;
      end
    end
    if (ov && ready) begin
      s=int'(out_req.addr_tag);
      if (s<0 || s>=4) fail("invalid_request_owner");
      if (emitted[s]>=sent[s]) fail("output_without_accepted_request");
      if (out_req!==expected[s][emitted[s]]) fail("request_payload_or_source_order");
      emitted[s]++;
      if (phase==0 || phase==1) begin
        if (observed_sources==(phase==0?4'b1111:4'b0101) &&
            iv==(phase==0?4'b1111:4'b0101)) begin
          if(rotation_count<(phase==0?4:2)) begin
            for(int j=0;j<rotation_count;j++) if(rotation[j]==s) fail("round_robin_repeated_after_observed_sources");
            rotation[rotation_count]=s;
            rotation_count++;
          end else begin
            if(s!=rotation[rotation_checks%(phase==0?4:2)]) fail("round_robin_rotation_changed");
            rotation_checks++;
          end
        end
        observed_sources[s]=1;
      end
      phase_outputs++;
      total++;
      $display("TRANSFER cycle=%0d phase=%0d source=%0d sequence=%0d",cycle,phase,s,emitted[s]-1);
    end
    if (!$onehot0(rv)) fail("multiple_response_owners");
    for(int i=0;i<4;i++) if(rv[i]) begin
      if(i!=response_owner || response_count!=0) fail("response_owner_or_duplicate");
      response_count++;
      $display("RESPONSE cycle=%0d source=%0d",cycle,i);
    end
    input_stalled=iv & ~ir;
    for(int i=0;i<4;i++) if(iv[i] && !previous_valid[i]) activations[i]++;
    previous_valid=iv;
    held_input=req;
    output_stalled=ov && !ready;
    held_output=out_req;
    $display("OBS cycle=%0d phase=%0d iv=%h ir=%h ov=%b ready=%b rv=%h",cycle,phase,iv,ir,ov,ready,rv);
    clk=1;
    #5;
    cycle++;
  endtask

  task automatic run_phase(input int p);
    bit complete;
    int wave;
    phase=p;
    phase_outputs=0;
    rotation_count=0;
    observed_sources=0; rotation_checks=0;
    for(int s=0;s<4;s++) begin
      sent[s]=0; emitted[s]=0; activations[s]=0;
      goals[s]=(p==0?128:(p==1?(s==0||s==2?64:0):8));
    end
    for(int c=0;c<4000;c++) begin
      ready=(c%17>=6);
      response_valid=0;
      wave=emitted[0];
      for(int s=1;s<4;s++) if(emitted[s]<wave) wave=emitted[s];
      for(int s=0;s<4;s++) begin
        if(!input_stalled[s]) begin
          iv[s]=(sent[s]<goals[s]) && (p!=2 || (sent[s]<=wave && c>=wave*20+s*3));
          if(iv[s]) req[s]=payload(s,sent[s]);
        end
      end
      tick();
      complete=1;
      for(int s=0;s<4;s++) complete &= sent[s]==goals[s] && emitted[s]==goals[s];
      if(complete) begin
        if(p<2 && rotation_checks<(p==0?64:32)) begin
          fail($sformatf("incomplete_rotation_observation comparisons=%0d",rotation_checks));
        end
        if(p<2) $display("ROTATION_OBSERVED phase=%0d comparisons=%0d",p,rotation_checks);
        iv=0; ready=1;

        repeat(8) tick();
        for(int s=0;s<4;s++) begin
          if(p==2 && activations[s]!=8) begin
            fail($sformatf("incomplete_intermittent_coverage source=%0d activations=%0d",s,activations[s]));
          end
          $display("SOURCE_PROGRESS phase=%0d source=%0d accepted=%0d emitted=%0d activations=%0d",p,s,sent[s],emitted[s],activations[s]);
        end
        $display("PHASE_COMPLETE phase=%0d transfers=%0d",p,phase_outputs);
        return;
      end
    end
    fail("incomplete_request_progress");
  endtask

  initial begin
    req='0; response='0;
    // No transfer or output requirement is imposed while reset is active.
    #1; clk=1; #5; clk=0; #5; clk=1; #5; clk=0; rst=1;
    for(int p=0;p<3;p++) run_phase(p);
    phase=3;
    // A one-bit tid can address engines 0 and 1 only.
    for(int r=0;r<16;r++) begin
      response_owner=r%2;
      response_count=0;
      response='0;
      response.tid=tid_t'(response_owner);
      response.rdata=32'h12340000+r;
      response.sid=sid_t'(r);
      response.error=r%2;
      response.aborted=(r/2)%2;
      response_valid=1;
      tick();
      response_valid=0;
      for(int c=0;c<100 && response_count==0;c++) tick();
      if(response_count!=1) begin
        fail($sformatf("incomplete_response_progress owner=%0d",response_owner));
      end
      repeat(8) tick();
    end
    if(input_hold_checks==0 || output_hold_checks==0) begin
      fail($sformatf("incomplete_stall_coverage input=%0d output=%0d",input_hold_checks,output_hold_checks));
    end
    $display("SUMMARY requests=%0d responses=16 input_hold_checks=%0d output_hold_checks=%0d errors=0",total,input_hold_checks,output_hold_checks);
    $display("STRIDE_ARB_PORT_TEST_COMPLETE");
    $finish;
  end
endmodule
