// SPDX-License-Identifier: Apache-2.0
module observe_rvdff_fpga #(
    parameter WIDTH = 1,
    parameter SHORT = 0
) (
    input logic [WIDTH-1:0] din,
    input logic clk,
    input logic clken,
    input logic rawclk,
    input logic rst_l,
    input logic [WIDTH-1:0] dout
);
    if (SHORT == 0) begin : gen_storage
        logic [WIDTH-1:0] expected;
        int samples = 0;
        int transitions = 0;
        int closed_enable_transitions = 0;
        int mismatches = 0;

        always @(posedge clk or negedge rst_l) begin
            if (!rst_l)
                expected <= '0;
            else begin
                expected <= din;
                if (din != expected) begin
                    transitions <= transitions + 1;
                    if (!clken)
                        closed_enable_transitions <= closed_enable_transitions + 1;
                end
            end
        end

        always @(negedge rawclk) begin
            if (rst_l && (transitions > 0)) begin
                samples <= samples + 1;
                if (dout !== expected) begin
                    if (mismatches == 0)
                        $display("RVDFF_FPGA_FIRST_MISMATCH instance=%m t=%0t expected=%h actual=%h",
                                 $time, expected, dout);
                    mismatches <= mismatches + 1;
                end
            end
        end

        final
            $display("RVDFF_FPGA_STORAGE instance=%m samples=%0d transitions=%0d closed_enable_transitions=%0d mismatches=%0d",
                     samples, transitions, closed_enable_transitions, mismatches);
    end
endmodule

bind rvdff_fpga observe_rvdff_fpga #(.WIDTH(WIDTH), .SHORT(SHORT)) observe_rvdff_fpga_i (
    .din(din), .clk(clk), .clken(clken), .rawclk(rawclk), .rst_l(rst_l), .dout(dout)
);
