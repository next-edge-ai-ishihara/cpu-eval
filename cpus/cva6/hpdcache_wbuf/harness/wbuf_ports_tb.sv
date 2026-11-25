// SPDX-License-Identifier: Apache-2.0
module testbench;
    import hpdcache_pkg::*;
    `include "hpdcache_typedef.svh"

    // The HPDcache configuration that cv32a60x instantiates.
    function automatic hpdcache_cfg_t configuration();
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

    localparam hpdcache_cfg_t C = configuration();
    typedef logic [3:0] id_t;
    typedef logic [33:0] address_t;
    `HPDCACHE_TYPEDEF_MEM_REQ_T(req_t, logic[63:0], id_t);
    `HPDCACHE_TYPEDEF_MEM_REQ_W_T(data_t, logic[63:0], logic[7:0]);
    `HPDCACHE_TYPEDEF_MEM_RESP_W_T(rsp_t, id_t);

    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0, empty, write_valid = 0, write_ready;
    address_t address = '0;
    logic [31:0] word = '0;
    logic [3:0] mask = '0;
    logic req_ready = 0, req_valid, data_ready = 0, data_valid, rsp_ready, rsp_valid = 0;
    req_t req;
    data_t data;
    rsp_t rsp = '0;

    hpdcache_wbuf #(
        .HPDcacheCfg(C), .wbuf_addr_t(address_t), .wbuf_timecnt_t(logic[2:0]),
        .hpdcache_mem_id_t(id_t), .hpdcache_mem_req_t(req_t),
        .hpdcache_mem_req_w_t(data_t), .hpdcache_mem_resp_w_t(rsp_t)
    ) dut (
        .clk_i(clk), .rst_ni(rst_n), .empty_o(empty), .full_o(), .flush_all_i(1'b0),
        .cfg_threshold_i(3'd2), .cfg_reset_timecnt_on_write_i(1'b1),
        .cfg_sequential_waw_i(1'b0), .cfg_inhibit_write_coalescing_i(1'b0),
        .write_i(write_valid), .write_ready_o(write_ready), .write_addr_i(address),
        .write_data_i(word), .write_be_i(mask), .write_uc_i(1'b0),
        .read_addr_i('0), .read_hit_o(), .read_flush_hit_i(1'b0),
        .replay_addr_i('0), .replay_is_read_i(1'b1), .replay_open_hit_o(),
        .replay_pend_hit_o(), .replay_sent_hit_o(), .replay_not_ready_o(),
        .mem_req_write_ready_i(req_ready), .mem_req_write_valid_o(req_valid), .mem_req_write_o(req),
        .mem_req_write_data_ready_i(data_ready), .mem_req_write_data_valid_o(data_valid),
        .mem_req_write_data_o(data), .mem_resp_write_ready_o(rsp_ready),
        .mem_resp_write_valid_i(rsp_valid), .mem_resp_write_i(rsp)
    );

    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    task automatic check(input string phase, input string name, input logic condition);
        $display("OBS %s %s %0d", phase, name, condition);
        if (condition !== 1'b1) begin
            $display("MISMATCH %s %s", phase, name);
            $finish;
            #1;
        end
    endtask

    task automatic put(input address_t a, input logic [31:0] value, input logic [3:0] enables);
        @(negedge clk);
        address = a;
        word = value;
        mask = enables;
        write_valid = 1;
        #1;
        check("core", "store-accepted", write_ready);
        tick();
        @(negedge clk);
        write_valid = 0;
    endtask

    task automatic transfer(input address_t a);
        string phase;
        req_t original;
        logic [7:0] expected_mask;
        logic [31:0] selected_word;

        phase = a[2] ? "upper-word" : "lower-word";
        expected_mask = a[2] ? 8'hf0 : 8'h0f;
        put(a, 32'h11223344, 4'b0011);
        put(a, 32'haabbccdd, 4'b1100);
        for (int cycle = 0; cycle < 40 && !req_valid; ++cycle) tick();
        check(phase, "request-valid-without-ready", req_valid);
        original = req;
        check(phase, "request-address", req.mem_req_addr == a);
        check(phase, "request-command", req.mem_req_command == HPDCACHE_MEM_WRITE
              && req.mem_req_len == 0 && req.mem_req_size == 2 && req.mem_req_cacheable);
        repeat (2) tick();
        check(phase, "request-while-stalled", req_valid && req == original);
        @(negedge clk);
        req_ready = 1;
        tick();
        @(negedge clk);
        req_ready = 0;

        for (int cycle = 0; cycle < 40 && !data_valid; ++cycle) tick();
        check(phase, "data-valid-without-ready", data_valid);
        selected_word = a[2] ? data.mem_req_w_data[63:32] : data.mem_req_w_data[31:0];
        $display("PAYLOAD %s addr=%016h mask=%02h enabled=%08h", phase, original.mem_req_addr,
                 data.mem_req_w_be, selected_word);
        check(phase, "selected-byte-mask", data.mem_req_w_be == expected_mask);
        check(phase, "merged-enabled-bytes", selected_word == 32'haabb3344 && data.mem_req_w_last);
        repeat (2) tick();
        selected_word = a[2] ? data.mem_req_w_data[63:32] : data.mem_req_w_data[31:0];
        check(phase, "data-while-stalled", data_valid && !req_valid
              && data.mem_req_w_be == expected_mask && selected_word == 32'haabb3344 && data.mem_req_w_last);
        @(negedge clk);
        data_ready = 1;
        tick();
        @(negedge clk);
        data_ready = 0;
        check(phase, "one-transfer-per-channel", !req_valid && !data_valid && !empty);
        rsp.mem_resp_w_id = original.mem_req_id;
        rsp_valid = 1;
        #1;
        check(phase, "response-accepted", rsp_ready);
        tick();
        @(negedge clk);
        rsp_valid = 0;
        for (int cycle = 0; cycle < 30 && !empty; ++cycle) tick();
        check(phase, "response-releases-entry", empty);
    endtask

    initial begin
        tick();
        @(negedge clk);
        rst_n = 1;
        tick();
        check("core", "reset-empty", empty);
        transfer(34'h400);
        transfer(34'h404);
        $display("WBUF_PORT_TEST_COMPLETE");
        $finish;
    end
endmodule
