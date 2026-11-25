// SPDX-License-Identifier: Apache-2.0
// N=2 and the memory request layout that cv32a60x instantiates.
module tb;
    typedef struct packed {
        logic [63:0] mem_req_addr;
        logic [7:0] mem_req_len;
        logic [2:0] mem_req_size;
        logic [3:0] mem_req_id;
        logic [1:0] mem_req_command;
        logic [3:0] mem_req_atomic;
        logic mem_req_cacheable;
    } request_t;

    logic clk = 0;
    logic reset_n = 0;
    logic [1:0] request_valid = '0;
    logic [1:0] request_ready;
    request_t [1:0] requests;
    logic output_ready = 0;
    logic output_valid;
    request_t output_request;
    logic [0:0] grant_index;
    int checks = 0;
    int errors = 0;

    hpdcache_mem_req_read_arbiter #(.N(2), .hpdcache_mem_req_t(request_t)) dut (
        .clk_i(clk), .rst_ni(reset_n),
        .mem_req_read_ready_o(request_ready), .mem_req_read_valid_i(request_valid),
        .mem_req_read_i(requests), .mem_req_read_ready_i(output_ready),
        .mem_req_read_valid_o(output_valid), .mem_req_read_o(output_request),
        .gnt_index_o(grant_index)
    );

    task automatic advance();
        #1 clk = 1;
        #1 clk = 0;
    endtask

    task automatic check_ports(input string stage, input int selected);
        logic [1:0] expected_ready;
        #1;
        expected_ready = '0;
        if (selected >= 0 && output_ready)
            expected_ready[selected] = 1'b1;
        checks++;
        if (request_ready !== expected_ready || output_valid !== (selected >= 0)) begin
            errors++;
            $display("MISMATCH %s ready=%b expected_ready=%b valid=%b expected_valid=%b",
                     stage, request_ready, expected_ready, output_valid, selected >= 0);
        end
        if (selected >= 0 &&
            (grant_index !== 1'(selected) || output_request !== requests[selected])) begin
            errors++;
            $display("MISMATCH %s index=%0d expected_index=%0d request=%h expected_request=%h",
                     stage, grant_index, selected, output_request, requests[selected]);
        end
        advance();
    endtask

    initial begin
        requests[0] = '{64'h0000_0000_1020_3040, 8'h01, 3'h4, 4'h1, 2'h0, 4'h0, 1'b1};
        requests[1] = '{64'h0000_0000_5060_7080, 8'h00, 3'h3, 4'hc, 2'h0, 4'h0, 1'b0};
        advance();
        reset_n = 1;
        output_ready = 1;
        check_ports("idle", -1);
        request_valid = 2'b10;
        check_ports("requester 1", 1);
        request_valid = 2'b11;
        check_ports("requesters 0 and 1", 0);
        request_valid = 2'b10;
        output_ready = 0;
        check_ports("stall requester 1", 1);
        request_valid = 2'b11;
        check_ports("new requester 0 during stall", 1);
        output_ready = 1;
        check_ports("accept requester 1", 1);
        request_valid = 2'b01;
        check_ports("accept waiting requester 0", 0);
        request_valid = '0;
        check_ports("idle after acceptance", -1);
        $display("SUMMARY checks=%0d errors=%0d", checks, errors);
        $display("READ_ARBITER_PORT_TEST_COMPLETE");
        $finish;
    end
endmodule
