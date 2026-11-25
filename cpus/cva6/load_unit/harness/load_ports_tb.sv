// SPDX-License-Identifier: Apache-2.0
module testbench;
    import ariane_pkg::*;
    localparam config_pkg::cva6_cfg_t CVA6Cfg =
        build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
    typedef logic [7:0] cbo_t;
    `include "load_port_types.svh"

    logic clk_i = 0;
    always #5 clk_i = ~clk_i;
    logic rst_ni = 0;
    logic flush_i = 0;
    logic valid_i = 0;
    lsu_ctrl_t lsu_ctrl_i = '0;
    logic pop_ld_o, valid_o;
    logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_o;
    logic [CVA6Cfg.XLEN-1:0] result_o;
    exception_t ex_o;
    logic [CVA6Cfg.PLEN-1:0] paddr_i = '0;
    dcache_req_o_t req_port_i = '0;
    dcache_req_i_t req_port_o;
    int observations = 0;
    int mismatches = 0;

    load_unit #(.CVA6Cfg(CVA6Cfg), .lsu_ctrl_t(lsu_ctrl_t),
                .dcache_req_i_t(dcache_req_i_t), .dcache_req_o_t(dcache_req_o_t),
                .exception_t(exception_t)) dut (
        .clk_i, .rst_ni, .flush_i, .valid_i, .lsu_ctrl_i, .pop_ld_o,
        .valid_o, .trans_id_o, .result_o, .ex_o, .mbe_i(1'b0), .translation_req_o(),
        .vaddr_o(), .tinst_o(), .hs_ld_st_inst_o(), .hlvx_inst_o(),
        .paddr_i, .ex_i('0), .dtlb_hit_i(1'b1), .dtlb_ppn_i('0), .page_offset_o(),
        .page_offset_matches_i(1'b0), .store_buffer_empty_i(1'b1),
        .commit_tran_id_i('0), .req_port_i, .req_port_o, .dcache_wbuffer_not_ni_i(1'b1),
        .sdtrig_load_stall_i(1'b0), .sdtrig_load_cancel_i(1'b0), .sdtrig_load_action_i('0)
    );

    task automatic observe(input string name, input bit correct);
        $display("OBSERVATION check=%0d name=%s", observations, name);
        if (!correct) begin
            $display("MISMATCH check=%0d name=%s", observations, name);
            mismatches++;
        end
        observations++;
    endtask

    task automatic issue(input logic [CVA6Cfg.TRANS_ID_BITS-1:0] transaction,
                         output logic [CVA6Cfg.DcacheIdWidth-1:0] id,
                         output bit tag_sent);
        @(negedge clk_i);
        valid_i = 1;
        lsu_ctrl_i = '0;
        lsu_ctrl_i.valid = 1;
        lsu_ctrl_i.vaddr = 32'h80000004;
        lsu_ctrl_i.operation = LW;
        lsu_ctrl_i.fu = LOAD;
        lsu_ctrl_i.be = '1;
        lsu_ctrl_i.trans_id = transaction;
        req_port_i.data_gnt = 1;
        tag_sent = 0;
        id = 0;
        for (int attempt = 0; attempt < 8; attempt++) begin
            #1;
            if (req_port_o.data_req) begin
                id = req_port_o.data_id;
                @(posedge clk_i);
                paddr_i <= 32'h80000004;
                @(negedge clk_i);
                valid_i = 0;
                req_port_i.data_gnt = 0;
                #1;
                tag_sent = req_port_o.tag_valid && !req_port_o.kill_req;
                @(posedge clk_i);
                @(negedge clk_i);
                return;
            end
            if (pop_ld_o) begin
                @(negedge clk_i);
                valid_i = 0;
                continue;
            end
            @(negedge clk_i);
        end
        valid_i = 0;
        req_port_i.data_gnt = 0;
    endtask

    task automatic respond(input logic [CVA6Cfg.DcacheIdWidth-1:0] id,
                           input logic [CVA6Cfg.TRANS_ID_BITS-1:0] transaction,
                           input logic [31:0] data, input bit should_return,
                           input bit tag_sent, input string name);
        bit seen_completion;
        bit correct;
        seen_completion = 0;
        correct = 1;
        req_port_i.data_rid = id;
        req_port_i.data_rdata = data;
        req_port_i.data_rvalid = tag_sent;
        for (int cycle = 0; cycle < 4; cycle++) begin
            #1;
            if (valid_o) begin
                $display("COMPLETION check=%0d trans_id=%0d data=%08x exception=%b",
                         observations, trans_id_o, result_o, ex_o.valid);
                correct &= should_return && !seen_completion && trans_id_o == transaction &&
                           result_o == data && !ex_o.valid;
                seen_completion = 1;
            end
            @(posedge clk_i);
            @(negedge clk_i);
            req_port_i = '0;
        end
        observe(name, tag_sent && correct && (seen_completion == should_return));
    endtask

    initial begin
        logic [CVA6Cfg.DcacheIdWidth-1:0] id;
        bit tag_sent;
        repeat (2) @(negedge clk_i);
        rst_ni = 1;
        issue(0, id, tag_sent);
        respond(id, 0, 32'he217539a, 1, tag_sent, "completed-load");

        issue(1, id, tag_sent);
        flush_i = 1;
        @(posedge clk_i);
        @(negedge clk_i);
        flush_i = 0;
        repeat (2) @(negedge clk_i);
        respond(id, 1, 32'hc6ef3720, 0, tag_sent, "flushed-load");

        issue(2, id, tag_sent);
        respond(id, 2, 32'h9e3779b9, 1, tag_sent, "load-after-flush");
        $display("SUMMARY observations=%0d mismatches=%0d", observations, mismatches);
        $finish;
    end
endmodule
