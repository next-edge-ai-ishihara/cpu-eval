// SPDX-License-Identifier: Apache-2.0
module onehot_width_test #(
    parameter int unsigned N = 1,
    localparam int unsigned Width = N > 1 ? $clog2(N) : 1
) (
    output bit done,
    output bit failed
);
    logic [N-1:0] val;
    logic [Width-1:0] index;

    hpdcache_1hot_to_binary #(.N(N)) dut (.val_i(val), .val_o(index));

    task automatic check(input logic [N-1:0] vector, input logic [Width-1:0] expected);
        val = vector;
        #1;
        $display("ONEHOT width=%0d input=%0h expected=%0d observed=%0d", N, vector, expected, index);
        if (index !== expected) failed = 1;
    endtask

    initial begin
        check('0, '0);
        for (int unsigned i = 0; i < N; i++) begin
            check(N'(1) << i, Width'(i));
        end
        done = 1;
    end
endmodule

module onehot_ports_tb;
    wire [1:0] done;
    wire [1:0] failed;
    // cv32a60x instantiates N=2 (ways, arbiters) and N=8 (write-buffer entries).
    onehot_width_test #(.N(2)) n2(done[0], failed[0]);
    onehot_width_test #(.N(8)) n8(done[1], failed[1]);

    initial begin
        wait (&done);
        if (|failed) $display("ONEHOT_PORTS_FAIL");
        else $display("ONEHOT_PORTS_PASS");
        $finish;
    end
endmodule
