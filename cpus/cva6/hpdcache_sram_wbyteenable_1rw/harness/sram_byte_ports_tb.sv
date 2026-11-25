// SPDX-License-Identifier: Apache-2.0
// The data RAM geometry of cv32a60x.
module tb;
    logic clk = 0, rst_n = 1, cs = 0, we = 0;
    logic [6:0] addr = '0;
    logic [1:0][31:0] wdata = '0, rdata;
    logic [1:0][3:0] wbyteenable = '0;
    int errors = 0;

    hpdcache_sram_wbyteenable_1rw #(
        .ADDR_SIZE(7), .DATA_SIZE(32), .DEPTH(128), .NDATA(2)
    ) dut (.clk, .rst_n, .cs, .we, .addr, .wdata, .wbyteenable, .rdata);

    task automatic tick;
        #5 clk = 1;
        #5 clk = 0;
    endtask

    task automatic drive_write(input logic selected, input logic [6:0] a,
                               input logic [63:0] data, input logic [7:0] mask);
        cs = selected;
        we = 1;
        addr = a;
        wdata = data;
        wbyteenable = mask;
        tick();
    endtask

    task automatic observe(input string name, input logic [63:0] expected);
        $display("OBS %s expected=%016h actual=%016h", name, expected, rdata);
        if (rdata !== expected) begin
            errors++;
            $display("MISMATCH %s", name);
        end
    endtask

    initial begin
        drive_write(1, 0, 64'h01234567_89abcdef, 8'hff);
        drive_write(1, 127, 64'hfedcba98_76543210, 8'hff);
        we = 0;
        addr = 0;
        tick();
        observe("initial-read", 64'h01234567_89abcdef);

        addr = 127;
        #1;
        observe("before-read-edge", 64'h01234567_89abcdef);
        tick();
        observe("after-read-edge", 64'hfedcba98_76543210);

        drive_write(1, 0, 64'ha1b2c3d4_a1b2c3d4, 8'h50);
        drive_write(1, 0, 64'hf0e1d2c3_f0e1d2c3, 8'h02);
        drive_write(0, 127, 64'h0, 8'hff);

        cs = 1;
        we = 0;
        addr = 0;
        tick();
        observe("separate-byte-masks", 64'h01b245d4_89abd2ef);
        addr = 127;
        tick();
        observe("deselected-write-keeps-memory", 64'hfedcba98_76543210);
        $display("SUMMARY observations=5 mismatches=%0d", errors);
        $finish;
    end
endmodule
