// SPDX-License-Identifier: Apache-2.0
module upsize_ports_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic reset_n = 0, write = 0, read = 0, last = 0;
    logic write_ready, read_ready;
    logic [63:0] input_data = 0;
    logic [127:0] output_data;
    localparam logic [63:0] First = 64'h1020304050607080;
    localparam logic [63:0] Second = 64'h9aabbccddeeff011;

    // cv32a60x instruction-cache refill instance: AXI64 to line128, DEPTH=1.
    hpdcache_data_upsize #(.WR_WIDTH(64), .RD_WIDTH(128), .DEPTH(1)) dut (
        .clk_i(clk), .rst_ni(reset_n), .w_i(write), .wok_o(write_ready),
        .wdata_i(input_data), .wlast_i(last), .r_i(read), .rok_o(read_ready), .rdata_o(output_data)
    );

    // $finish ends the run only at the end of the time step; stop this process here.
    task automatic check(input logic condition, input string message);
        if (!condition) begin
            $display("FAIL: %s", message);
            $finish;
            wait (0);
        end
    endtask

    task automatic put(input logic [63:0] data, input logic end_of_burst);
        @(negedge clk);
        check(write_ready, "the incomplete output must accept another beat");
        write = 1;
        input_data = data;
        last = end_of_burst;
        @(negedge clk);
        write = 0;
        #1;
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset_n = 1;
        put(First, 0);
        check(!read_ready, "one beat did not complete a two-beat output");
        put(Second, 1);
        $display("full_line=%032x expected=%032x read_ready=%0d", output_data, {Second, First}, read_ready);
        check(read_ready && output_data === {Second, First}, "packed line differs");

        @(negedge clk);
        read = 1;
        @(negedge clk);
        read = 0;
        put(Second, 1);
        $display("single_beat=%016x expected=%016x read_ready=%0d", output_data[63:0], Second, read_ready);
        check(read_ready && output_data[63:0] === Second, "early last did not complete the low beat");
        $display("PASS: two accepted beats and one early-last beat are ordered");
        $finish;
    end
endmodule
