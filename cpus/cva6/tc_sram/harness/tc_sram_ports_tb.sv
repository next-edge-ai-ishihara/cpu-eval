// SPDX-License-Identifier: Apache-2.0
// The two single-port geometries that the cv32a60x instruction cache instantiates.
module testbench;
    typedef logic [255:0] word_t;
    bit clk_i;
    bit rst_ni;
    logic req_i = 1'b0, we_i = 1'b0;
    logic [5:0] addr_i = '0;
    word_t wdata_i = '0;
    logic [31:0] be_i = '0;
    logic [0:0][24:0] tag_rdata;
    logic [0:0][255:0] data_rdata;
    int comparisons = 0;
    int mismatches = 0;

    tc_sram #(.NumWords(64), .DataWidth(25), .ByteWidth(8), .NumPorts(1),
              .Latency(1), .SimInit("none")) tag_ram (
        .clk_i, .rst_ni, .req_i, .we_i, .addr_i, .wdata_i(wdata_i[24:0]), .be_i(be_i[3:0]),
        .rdata_o(tag_rdata)
    );
    tc_sram #(.NumWords(64), .DataWidth(256), .ByteWidth(8), .NumPorts(1),
              .Latency(1), .SimInit("none")) data_ram (
        .clk_i, .rst_ni, .req_i, .we_i, .addr_i, .wdata_i, .be_i, .rdata_o(data_rdata)
    );

    task automatic tick;
        #1;
        clk_i = 1;
        #1;
        clk_i = 0;
        #1;
    endtask

    task automatic access(input logic write, input logic [5:0] address, input word_t data,
                          input logic [31:0] enables);
        req_i = 1'b1;
        we_i = write;
        addr_i = address;
        wdata_i = data;
        be_i = enables;
        tick();
    endtask

    task automatic observe(input string operation, input word_t expected);
        $display("OBSERVATION check=%0d %s width=25 expected=%07h actual=%07h",
                 comparisons, operation, expected[24:0], tag_rdata[0]);
        if (tag_rdata[0] !== expected[24:0]) begin
            $display("MISMATCH check=%0d %s", comparisons, operation);
            mismatches++;
        end
        comparisons++;
        $display("OBSERVATION check=%0d %s width=256 expected=%064h actual=%064h",
                 comparisons, operation, expected, data_rdata[0]);
        if (data_rdata[0] !== expected) begin
            $display("MISMATCH check=%0d %s", comparisons, operation);
            mismatches++;
        end
        comparisons++;
    endtask

    function automatic word_t merge(input word_t previous, input word_t data, input logic [31:0] enables);
        for (int i = 0; i < 32; i++) if (enables[i]) previous[8*i +: 8] = data[8*i +: 8];
        return previous;
    endfunction

    localparam word_t First = 256'hd23f0824128b2f330c5c7fd0a6a3a4506513270e269e0d37f2a74de452e6b438;
    localparam word_t Second = 256'h36f675cc81e74ef5e8e25d940ed904759531985d5d9dc9f81818e811892f902b;
    localparam word_t Third = 256'h8d116ece1738f7d93d9c172411e20b8f6b0d549b6f03675a1600a35a099950d8;
    localparam logic [31:0] Mask = 32'ha5c3_5a0a;

    initial begin
        tick();
        rst_ni = 1;
        access(1'b1, 6'd1, First, '1);
        access(1'b1, 6'd63, Second, '1);
        access(1'b0, 6'd1, '0, '0);
        observe("full-write", First);
        access(1'b1, 6'd1, Third, Mask);
        access(1'b0, 6'd1, '0, '0);
        observe("masked-write", merge(First, Third, Mask));
        access(1'b0, 6'd63, '0, '0);
        observe("other-address", Second);
        req_i = 1'b0;
        rst_ni = 0;
        tick();
        rst_ni = 1;
        access(1'b0, 6'd1, '0, '0);
        observe("read-after-reset", merge(First, Third, Mask));
        $display("SUMMARY comparisons=%0d mismatches=%0d", comparisons, mismatches);
        $finish;
    end
endmodule
