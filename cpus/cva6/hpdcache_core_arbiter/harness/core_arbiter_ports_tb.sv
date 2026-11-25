// SPDX-License-Identifier: Apache-2.0
`include "hpdcache_typedef.svh"

module core_arbiter_ports_tb;
    import hpdcache_pkg::*;

    localparam int Requesters = 5;
    localparam int LoadPort = 1;
    localparam int StorePort = 3;
    // The HPDcache configuration and request types that cv32a60x instantiates.
    function automatic hpdcache_cfg_t test_config();
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
    localparam hpdcache_cfg_t Cfg = test_config();
    `HPDCACHE_TYPEDEF_REQ_ATTR_T(offset_t, word_t, word_be_t, data_t, be_t, sid_t, tid_t, tag_t, Cfg);
    `HPDCACHE_TYPEDEF_REQ_T(req_t, offset_t, data_t, be_t, sid_t, tid_t, tag_t);
    `HPDCACHE_TYPEDEF_RSP_T(rsp_t, data_t, sid_t, tid_t);

    bit clk = 0, reset_n = 0, downstream_ready = 0;
    bit [Requesters-1:0] active = '0;
    logic load_uncacheable = 0;
    logic request_valid [Requesters], request_ready [Requesters], abort_request [Requesters];
    req_t requests [Requesters];
    tag_t tags [Requesters];
    hpdcache_pma_t pmas [Requesters];
    req_t granted;
    logic granted_valid;
    hpdcache_pma_t granted_pma;

    always_comb begin
        for (int port_index = 0; port_index < Requesters; port_index++) begin
            request_valid[port_index] = active[port_index];
            requests[port_index] = '0;
            requests[port_index].sid = sid_t'(port_index);
            requests[port_index].op = (port_index == StorePort) ? HPDCACHE_REQ_STORE : HPDCACHE_REQ_LOAD;
            requests[port_index].phys_indexed = port_index == StorePort;
            requests[port_index].be = '1;
            requests[port_index].size = 3'd2;
            tags[port_index] = tag_t'(port_index);
            abort_request[port_index] = 0;
            pmas[port_index] = '0;
            pmas[port_index].wr_policy_hint = HPDCACHE_WR_POLICY_AUTO;
        end
        pmas[LoadPort].uncacheable = load_uncacheable;
    end

    hpdcache_core_arbiter #(.HPDcacheCfg(Cfg), .hpdcache_tag_t(tag_t),
        .hpdcache_req_t(req_t), .hpdcache_rsp_t(rsp_t)) dut (
        .clk_i(clk), .rst_ni(reset_n), .core_req_valid_i(request_valid), .core_req_ready_o(request_ready),
        .core_req_i(requests), .core_req_abort_i(abort_request), .core_req_tag_i(tags), .core_req_pma_i(pmas),
        .core_rsp_valid_i(1'b0), .core_rsp_i('0), .core_rsp_valid_o(), .core_rsp_o(),
        .arb_req_valid_o(granted_valid), .arb_req_ready_i(downstream_ready), .arb_req_o(granted),
        .arb_abort_o(), .arb_tag_o(), .arb_pma_o(granted_pma));

    bit failed = 0;

    task automatic tick;
        #1; clk = 1;
        #1; clk = 0;
        #1;
    endtask

    task automatic clear_requests;
        reset_n = 0;
        active = '0;
        downstream_ready = 0;
        load_uncacheable = 0;
        tick();
        reset_n = 1;
    endtask

    initial begin
        clear_requests();
        active[StorePort] = 1;
        tick();
        active[LoadPort] = 1;
        #1;
        $display("CORE_ARB_STALL observed_sid=%0d", granted.sid);
        if (!granted_valid || granted !== requests[StorePort]) begin
            failed = 1;
            $display("CORE_ARB_MISMATCH stalled_store");
        end

        clear_requests();
        downstream_ready = 1;
        active[LoadPort] = 1;
        #1;
        if (!request_ready[LoadPort] || !granted_valid) begin
            failed = 1;
            $display("CORE_ARB_MISMATCH no_load_acceptance");
        end
        tick();
        active[LoadPort] = 0;
        active[StorePort] = 1;
        load_uncacheable = 1;
        #1;
        $display("CORE_ARB_PMA current_sid=%0d uncacheable=%0d", granted.sid, granted_pma.uncacheable);
        if (!granted_valid || granted.sid != sid_t'(StorePort) || granted_pma.uncacheable !== 1'b1) begin
            failed = 1;
            $display("CORE_ARB_MISMATCH previous_load_pma");
        end

        if (failed) $display("CORE_ARB_PORTS_FAIL");
        else $display("CORE_ARB_PORTS_PASS");
        $finish;
    end
endmodule
