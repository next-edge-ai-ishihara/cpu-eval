// SPDX-License-Identifier: Apache-2.0
`include "hpdcache_typedef.svh"

module cmo_flush_ports_tb;
    import hpdcache_pkg::*;

    // The HPDcache configuration and types of cv64a6_imafdc_sv39_hpdcache_wb.
    function automatic hpdcache_cfg_t config_for_test();
        hpdcache_user_cfg_t u;
        u.nRequesters = 5; u.paWidth = 56; u.wordWidth = 64; u.sets = 256; u.ways = 8;
        u.clWords = 2; u.reqWords = 1; u.reqTransIdWidth = 3; u.reqSrcIdWidth = 3;
        u.victimSel = HPDCACHE_VICTIM_RANDOM; u.dataWaysPerRamWord = 2; u.dataSetsPerRam = 256;
        u.dataRamByteEnable = 1; u.accessWords = 1; u.mshrSets = 1; u.mshrWays = 8;
        u.mshrWaysPerRamWord = 8; u.mshrSetsPerRam = 1; u.mshrRamByteEnable = 1;
        u.mshrUseRegbank = 1; u.cbufEntries = 7; u.refillCoreRspFeedthrough = 1;
        u.refillFifoDepth = 4; u.wbufDirEntries = 7; u.wbufDataEntries = 7; u.wbufWords = 1;
        u.wbufTimecntWidth = 3; u.rtabEntries = 4; u.flushEntries = 7; u.flushFifoDepth = 7;
        u.memAddrWidth = 64; u.memIdWidth = 4; u.memDataWidth = 64; u.wtEn = 0; u.wbEn = 1;
        u.lowLatency = 1; u.eccEn = 0; u.eccScrubberEn = 0;
        return hpdcacheBuildConfig(u);
    endfunction
    localparam hpdcache_cfg_t Cfg = config_for_test();
    `HPDCACHE_TYPEDEF_REQ_ATTR_T(offset_t, word_t, word_be_t, data_t, be_t, sid_t, tid_t, tag_t, Cfg);
    `HPDCACHE_TYPEDEF_RSP_T(rsp_t, data_t, sid_t, tid_t);
    typedef logic [Cfg.nlineWidth-1:0] nline_t;
    typedef logic [Cfg.setWidth-1:0] set_t;
    typedef logic [Cfg.u.ways-1:0] way_t;

    logic clk = 0;
    logic reset_n = 0;
    logic req_valid = 0;
    logic req_ready, check_entry, check_dirty, update_entry;
    logic allocation, allocation_ready = 0, flush_empty = 1;
    logic response_valid;
    way_t check_way, allocated_way, updated_way;
    set_t checked_set, updated_set;
    tag_t check_tag = '0;
    nline_t allocated_line;
    rsp_t response;
    hpdcache_cmoh_op_t operation;

    hpdcache_cmo #(.HPDcacheCfg(Cfg), .hpdcache_nline_t(nline_t),
        .hpdcache_tag_t(tag_t), .hpdcache_set_t(set_t), .hpdcache_data_word_t(word_t),
        .hpdcache_way_vector_t(way_t), .hpdcache_rsp_t(rsp_t), .hpdcache_req_addr_t(logic [Cfg.u.paWidth-1:0]),
        .hpdcache_req_tid_t(tid_t), .hpdcache_req_sid_t(sid_t), .hpdcache_req_data_t(data_t)) dut (
        .clk_i(clk), .rst_ni(reset_n), .req_valid_i(req_valid), .req_ready_o(req_ready),
        .req_op_i(operation), .req_addr_i('0), .req_sid_i(sid_t'(2)), .req_tid_i(tid_t'(0)),
        .req_need_rsp_i(1'b1), .dirty_set_en_i(1'b1), .dirty_min_set_i('0), .dirty_max_set_i('0),
        .valid_set_en_i(1'b1), .valid_min_set_i('0), .valid_max_set_i('0),
        .flush_all_o(), .inval_all_o(), .core_rsp_ready_i(1'b1), .core_rsp_valid_o(response_valid),
        .core_rsp_o(response), .dir_check_entry_o(check_entry), .dir_check_entry_set_o(checked_set),
        .dir_check_entry_way_o(check_way), .dir_check_entry_valid_i(1'b1),
        .dir_check_entry_wback_i(1'b1), .dir_check_entry_dirty_i(check_dirty), .dir_check_entry_tag_i(check_tag),
        .dir_updt_o(update_entry), .dir_updt_set_o(updated_set), .dir_updt_way_o(updated_way),
        .dir_updt_valid_o(), .dir_updt_wback_o(), .dir_updt_dirty_o(), .dir_updt_fetch_o(), .dir_updt_tag_o(),
        .flush_empty_i(flush_empty), .flush_alloc_o(allocation), .flush_alloc_ready_i(allocation_ready),
        .flush_alloc_nline_o(allocated_line), .flush_alloc_way_o(allocated_way));

    way_t dirty = 8'h81;
    way_t accepted = '0;
    int pending = 0;
    bit finished = 0;

    task automatic tick;
        #1; clk = 1;
        #1; clk = 0;
        #1;
    endtask

    task automatic fail(input string reason);
        if (!finished) begin
            finished = 1;
            $display("CMO_PORTS_FAIL %s accepted=%02h pending=%0d", reason, accepted, pending);
            $finish;
        end
    endtask

    // Only set 0 holds dirty lines, as dirty_min_set_i = dirty_max_set_i = 0 states.
    always @(posedge clk) if (reset_n) begin
        if (check_entry) begin
            check_dirty <= checked_set == 0 && |(dirty & check_way);
            check_tag <= check_way[7] ? tag_t'(9) : tag_t'(3);
        end
        if (update_entry && updated_set == 0) dirty = dirty & ~updated_way;
        if (allocation && allocation_ready) begin
            if (!((allocated_way == 8'h01 && allocated_line == nline_t'(768)) ||
                  (allocated_way == 8'h80 && allocated_line == nline_t'(2304)))) fail("writeback identity");
            else if (|(accepted & allocated_way)) fail("duplicate writeback");
            else begin
                accepted |= allocated_way;
                pending = 5;
                $display("CMO_WRITEBACK way=%02h line=%0d", allocated_way, allocated_line);
            end
        end else if (pending > 0) begin
            pending--;
        end
        flush_empty <= pending == 0;
        if (response_valid && !finished) begin
            if (accepted != 8'h81 || pending != 0 || !flush_empty || allocation) fail("early response");
            else if (response.sid != sid_t'(2) || response.tid != tid_t'(0) || response.error || response.aborted)
                fail("response identity");
            else begin
                finished = 1;
                $display("CMO_PORTS_PASS accepted=%02h sid=%0d tid=%0d", accepted, response.sid, response.tid);
                $finish;
            end
        end
    end

    initial begin
        operation = '0;
        operation.is_flush_all = 1;
        tick();
        tick();
        reset_n = 1;
        req_valid = 1;
        #1;
        for (int attempt = 0; !req_ready && attempt < 32; attempt++) tick();
        if (!req_ready) fail("request not accepted");
        tick();
        req_valid = 0;
        repeat (12) tick();
        allocation_ready = 1;
        // A scan of all 256 sets x 8 ways also completes within this bound.
        repeat (5000) tick();
        fail("no completion");
    end
endmodule
