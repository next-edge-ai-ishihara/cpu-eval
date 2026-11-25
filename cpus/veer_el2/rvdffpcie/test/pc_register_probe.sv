// SPDX-License-Identifier: Apache-2.0
module pc_register_probe;
    logic clk = 0;
    logic rst_l = 1;
    logic en = 0;
    logic scan_mode = 0;
    logic [30:0] din = 0;
    logic [30:0] dout;
    int passed = 0;
    int failed = 0;

    rvdffpcie dut (.*);

    task automatic check(input string step, input logic [30:0] expected);
        if (dout === expected) begin
            $display("PC_REGISTER_OK %s", step);
            passed++;
        end else begin
            $display("PC_REGISTER_MISMATCH %s expected=%08h actual=%08h", step, expected, dout);
            failed++;
        end
    endtask

    initial begin
        #2 rst_l = 0;
        #2 clk = 1;
        #2 clk = 0;
        #2 rst_l = 1;
        en = 1;
        din = 31'h7ffff001;
        #2 check("before_capture", 0);
        clk = 1;
        #2 check("capture", 31'h7ffff001);
        clk = 0;
        en = 0;
        din = 31'h00000ffe;
        #2 clk = 1;
        #2 check("hold", 31'h7ffff001);
        rst_l = 0;
        #2 check("reset_without_clock_edge", 0);
        clk = 0;
        #2 rst_l = 1;
        en = 1;
        #2 clk = 1;
        #2 check("capture_after_reset", 31'h00000ffe);
        $display("PC_REGISTER_DONE passed=%0d failed=%0d", passed, failed);
        $finish;
    end
endmodule
