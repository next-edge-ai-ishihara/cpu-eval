`include "hpdcache_typedef.svh"
module tb;
  import hpdcache_pkg::*;
  import hwpf_stride_pkg::*;
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
  `HPDCACHE_TYPEDEF_REQ_ATTR_T(offset_t,word_t,word_be_t,data_t,be_t,sid_t,tid_t,tag_t,C);
  typedef logic [C.setWidth-1:0] set_t;
  typedef logic [C.nlineWidth-1:0] nline_t;
  `HPDCACHE_TYPEDEF_REQ_T(req_t,offset_t,data_t,be_t,sid_t,tid_t,tag_t);
  `HPDCACHE_TYPEDEF_RSP_T(rsp_t,data_t,sid_t,tid_t);
  logic clk=0,rst=0,bs=0,ps=0,ts=0,snoop=0,ready=1,rv=0,busy,valid;
  hwpf_stride_base_t bi='0,bo;
  hwpf_stride_param_t pi='0,po;
  hwpf_stride_throttle_t ti='0,to;
  req_t req,held;
  rsp_t rsp='0;
  nline_t sn;
  logic hold_pending=0;
  int stall_left=6;
  int cycle=0,sent=0,acked=0,due[32],line_deltas[5]='{1,2,4,5,6};
  int base_line;
  int wait_cycles, inflight_limit, previous_accept;
  logic [33:0] snoop_address;
  bit unrelated_snoop;
`ifdef TEST_WRAPPER
  hwpf_stride_status_t status;
  logic abort_o;
  tag_t tag_o;
  hpdcache_pma_t pma_o;
  hwpf_stride_wrapper #(.HPDcacheCfg(C),.NUM_HW_PREFETCH(4),.NUM_SNOOP_PORTS(2),
    .hpdcache_tag_t(tag_t),.hpdcache_req_offset_t(offset_t),.hpdcache_req_data_t(data_t),
    .hpdcache_req_be_t(be_t),.hpdcache_req_sid_t(sid_t),.hpdcache_req_tid_t(tid_t),
    .hpdcache_req_t(req_t),.hpdcache_rsp_t(rsp_t)) dut(
    .clk_i(clk),.rst_ni(rst),.hwpf_stride_base_set_i(bs),.hwpf_stride_base_i(bi),
    .hwpf_stride_base_o(bo),.hwpf_stride_param_set_i(ps),.hwpf_stride_param_i(pi),
    .hwpf_stride_param_o(po),.hwpf_stride_throttle_set_i(ts),.hwpf_stride_throttle_i(ti),
    .hwpf_stride_throttle_o(to),.hwpf_stride_status_o(status),
    .snoop_valid_i(snoop),.snoop_abort_i(1'b0),.snoop_addr_offset_i(offset_t'(snoop_address)),
    .snoop_addr_tag_i(tag_t'(snoop_address >> 10)),.snoop_phys_indexed_i(1'b1),
    .hpdcache_req_sid_i(sid_t'(3)),.hpdcache_req_valid_o(valid),
    .hpdcache_req_ready_i(ready),.hpdcache_req_o(req),.hpdcache_req_abort_o(abort_o),
    .hpdcache_req_tag_o(tag_o),.hpdcache_req_pma_o(pma_o),.hpdcache_rsp_valid_i(rv),
    .hpdcache_rsp_i(rsp));
  assign busy=status.busy[32];
`else
  hwpf_stride #(.HPDcacheCfg(C),.hpdcache_nline_t(nline_t),.hpdcache_tag_t(tag_t),
    .hpdcache_set_t(set_t),.hpdcache_req_t(req_t),.hpdcache_rsp_t(rsp_t)) dut(
    .clk_i(clk),.rst_ni(rst),.csr_base_set_i(bs),.csr_base_i(bi),
    .csr_param_set_i(ps),.csr_param_i(pi),.csr_throttle_set_i(ts),.csr_throttle_i(ti),
    .csr_base_o(bo),.csr_param_o(po),.csr_throttle_o(to),.busy_o(busy),
    .snoop_nline_o(sn),.snoop_match_i(snoop),.hpdcache_req_valid_o(valid),
    .hpdcache_req_ready_i(ready),.hpdcache_req_o(req),.hpdcache_rsp_valid_i(rv),
    .hpdcache_rsp_i(rsp));
`endif
  task automatic tick;
    clk=0;rv=(acked<sent && due[acked]==cycle);ready=!(sent==1 && stall_left>0);if(sent==1 && stall_left>0)stall_left--;#5;
    if(hold_pending && (!valid || req!==held)) begin
      $display("FAIL: pending request changed");$finish;return;
    end
    hold_pending=valid && !ready;held=req;
    if(valid && ready) begin
      if(unrelated_snoop) begin
        $display("FAIL: prefetch before matching snoop cycle=%0d snoop_address=%h request_address=%h",
                 cycle,snoop_address,{req.addr_tag,req.addr_offset});
        $finish;
        return;
      end
      if(sent>=5 || req.op!=HPDCACHE_REQ_CMO_PREFETCH ||
         {req.addr_tag,req.addr_offset}!==(34'(base_line+line_deltas[sent])<<4)) begin
        $display("FAIL: request index=%0d address=%h operation=%0d",sent,
                 {req.addr_tag,req.addr_offset},req.op);$finish;return;
      end
      // The documented limit is Ninflight; the pinned engine issues one more before it stalls.
      if(inflight_limit>0 && sent-acked-int'(rv)>inflight_limit) begin
        $display("FAIL: outstanding request limit count=%0d limit=%0d cycle=%0d",
                 sent-acked-int'(rv)+1,inflight_limit+1,cycle);
        $finish;
        return;
      end
      // The documented interval is Nwait+1 cycles; the pinned engine uses Nwait+2.
      if(wait_cycles>0 && sent>0 &&
         (cycle-previous_accept<wait_cycles+1 || cycle-previous_accept>wait_cycles+2)) begin
        $display("FAIL: request interval expected=%0d..%0d actual=%0d cycle=%0d",
                 wait_cycles+1,wait_cycles+2,cycle-previous_accept,cycle);
        $finish;
        return;
      end
      previous_accept=cycle;
      due[sent]=cycle+10;sent++;
      $display("ACCEPT cycle=%0d count=%0d address=%h",cycle,sent,{req.addr_tag,req.addr_offset});
    end
    if(rv) acked++;
    clk=1;#5;cycle++;
  endtask
  task automatic run_sequence(input int start_line, input int idle_cycles,
                              input int limit, input int stalls, output bit completed);
    completed=0;
    base_line=start_line;
    wait_cycles=idle_cycles;
    inflight_limit=limit;
    previous_accept=0;
    $display("START base_line=%0d nwait=%0d ninflight=%0d",base_line,wait_cycles,inflight_limit);
    rst=0; snoop=0; bs=0; ps=0; ts=0; bi='0; pi='0; ti='0;
    rv=0; ready=1; hold_pending=0; stall_left=stalls; sent=0; acked=0; cycle=0;
    repeat(2) begin clk=0; #5; clk=1; #5; cycle++; end
    rst=1;tick();
    bi.base_cline=base_line;bi.enable=0;pi.nlines=2;pi.nblocks=1;pi.stride=3;
    ti.nwait=16'(wait_cycles);ti.ninflight=16'(inflight_limit);bs=1;ps=1;ts=1;tick();bs=0;ps=0;ts=0;tick();
    bi.enable=1;bs=1;tick();bs=0;repeat(3)tick();
`ifdef TEST_WRAPPER
    unrelated_snoop=1;
    snoop_address=34'(base_line+300)<<4;
    snoop=1;tick();snoop=0;repeat(16)tick();
    unrelated_snoop=0;
`endif
    snoop_address=34'(base_line)<<4;
    snoop=1;tick();snoop=0;
    repeat(4000)begin
      tick();
      if(sent==5 && acked==5 && !busy)begin
        completed=1;
        $display("COMPLETE base_line=%0d requests=%0d acknowledgements=%0d",base_line,sent,acked);
        return;
      end
    end
    $display("FAIL: incomplete external transfer observation requests=%0d acknowledgements=%0d",sent,acked);
    $finish;
  endtask
  initial begin
    bit completed;
    completed=1;
`ifdef TEST_WRAPPER
    // The pinned wrapper matches a snoop to the engine base only at line 0 in this geometry.
    run_sequence(0,0,0,6,completed);
`else
    run_sequence(100,0,0,6,completed);
    if(completed) run_sequence(200,2,0,0,completed);
    if(completed) run_sequence(300,0,1,0,completed);
`endif
    if(completed) $display("PASS: external sequence and pending-request stability");
    $finish;
  end
endmodule
