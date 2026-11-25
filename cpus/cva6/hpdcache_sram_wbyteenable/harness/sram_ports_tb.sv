// The data RAM geometry of cv32a60x, which has ECC disabled.
module tb;
    logic clk = 0, rst_n = 0, cs = 0, we = 0;
    logic [6:0] addr = '0;
    logic [1:0][31:0] wdata = '0;
    logic [1:0][3:0] wbyteenable = '0;
    logic [1:0][31:0] rdata;
    logic [1:0] err_cor, err_unc;
    int mismatches = 0;

    hpdcache_sram_wbyteenable #(
        .ADDR_SIZE(7), .DATA_SIZE(32), .DEPTH(128), .NDATA(2), .ECC_EN(1'b0)
    ) dut (
        .clk, .rst_n, .cs, .we, .addr, .wdata, .wbyteenable, .rdata,
        .err_inj_i(1'b0), .err_inj_msk_i('0), .err_cor_o(err_cor), .err_unc_o(err_unc)
    );

    task automatic tick;
        #5 clk = 1;
        #5 clk = 0;
    endtask

    task automatic store(input logic [6:0] a, input logic [63:0] data, input logic [7:0] mask);
        cs = 1;
        we = 1;
        addr = a;
        wdata = data;
        wbyteenable = mask;
        tick();
    endtask

    task automatic expect_read(input int check_id, input logic [6:0] a, input logic [63:0] expected);
        we = 0;
        addr = a;
        tick();
        $display("OBS check=%0d ecc=0 address=%0d expected=%016h actual=%016h corrected=%0h uncorrectable=%0h",
            check_id, a, expected, rdata, err_cor, err_unc);
        if ({rdata, err_cor, err_unc} !== {expected, 4'b0}) begin
            mismatches++;
            $display("MISMATCH check=%0d ecc=0", check_id);
        end
    endtask

    initial begin
        tick();
        rst_n = 1;
        store(0, 64'h01234567_89abcdef, 8'hff);
        store(64, 64'h0f1e2d3c_4b5a6978, 8'hff);
        store(127, 64'hfedcba98_76543210, 8'hff);
        store(0, 64'ha1b2c3d4_f0e1d2c3, 8'h0f);
        store(64, 64'h11223344_55667788, 8'h5a);
        store(127, 64'ha1b2c3d4_f0e1d2c3, 8'hf0);
        expect_read(0, 0, 64'h01234567_f0e1d2c3);
        expect_read(1, 64, 64'h0f222d44_555a7778);
        expect_read(2, 127, 64'ha1b2c3d4_76543210);
        $display("SUMMARY observations=3 mismatches=%0d", mismatches);
        $finish;
    end
endmodule
