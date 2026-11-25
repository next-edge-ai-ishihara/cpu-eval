// SPDX-License-Identifier: Apache-2.0
module clock_gate_probe;
    logic din = 1'b1;
    logic en = 1'b0;
    logic clear = 1'b0;
    logic clk = 1'b0;
    logic clken = 1'b0;
    logic rawclk = 1'b0;
    logic rst_l = 1'b1;
    logic dout;

    rvdffsc_fpga #(.WIDTH(1), .SHORT(0)) dut (.*);

    task automatic rawclock_edge();
        #1 rawclk = 1'b1;
        #1 rawclk = 1'b0;
    endtask

    initial begin
        #1 rst_l = 1'b0;
        #1 rst_l = 1'b1;
        en = 1'b1;
        rawclock_edge();
        $display("CLOCK_GATE_OBSERVED: pending enable clken=0 dout=%0b", dout);
        if (dout != 1'b0) begin
            $display("CLOCK_GATE_MISMATCH: disabled DMA clock must retain an empty buffer");
        end else begin
            clken = 1'b1;
            rawclock_edge();
            $display("CLOCK_GATE_OBSERVED: pending enable clken=1 dout=%0b", dout);
            if (dout != 1'b1)
                $display("CLOCK_GATE_MISMATCH: enabled DMA clock must mark the buffer valid");
            else
                $display("CLOCK_GATE_PASS");
        end
        $finish;
    end
endmodule
