// SPDX-License-Identifier: Apache-2.0
module testbench;
    // Both cv32a60x LSU instances carry valid, a 2-bit ID, a 32-bit
    // result and a 133-bit exception record at Depth=0.
    typedef logic [167:0] lsu_result_t;
    logic clk_i = 0;
    logic rst_ni = 1;
    lsu_result_t d_i = '0, d_o;
    int comparisons = 0;
    int mismatches = 0;

    shift_reg #(.dtype(lsu_result_t), .Depth(0)) dut (.clk_i, .rst_ni, .d_i, .d_o);

    task automatic compare_output(input string condition_name);
        #1;
        $display("OBSERVATION check=%0d %s clk=%b reset_n=%b input=%h output=%h",
                 comparisons, condition_name, clk_i, rst_ni, d_i, d_o);
        if (d_o !== d_i) begin
            $display("MISMATCH check=%0d %s", comparisons, condition_name);
            mismatches++;
        end
        comparisons++;
    endtask

    initial begin
        d_i = 168'h80_00000000_00000000_00000000_00000000_00000001;
        compare_output("low-clock");
        clk_i = 1;
        compare_output("rising-clock");
        d_i = ~d_i;
        compare_output("input-change-while-clock-high");
        rst_ni = 0;
        compare_output("reset-assertion");
        d_i = 168'h80_01234567_89abcde0_12345678_9abcdef0_22446688;
        compare_output("input-change-during-reset");
        clk_i = 0;
        rst_ni = 1;
        compare_output("reset-release");
        $display("SUMMARY comparisons=%0d mismatches=%0d", comparisons, mismatches);
        $finish;
    end
endmodule
