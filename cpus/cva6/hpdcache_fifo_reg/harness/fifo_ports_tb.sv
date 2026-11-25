module tb;
    localparam int CONFIGS = 5;
    logic clk_i = 0, rst_ni = 0;
    logic [CONFIGS-1:0] w, r, wok, rok, write_accepted;
    logic [CONFIGS-1:0][63:0] wd, rd;
    logic [63:0] queue_data [CONFIGS][10000];
    int head [CONFIGS], tail [CONFIGS], count [CONFIGS];
    // FIFO_DEPTH, FEEDTHROUGH and data widths of the hpdcache_fifo_reg instances in cv32a60x.
    localparam int WIDTHS[CONFIGS] = '{4, 38, 3, 64, 35};
    function automatic int depth(input int setting);
        case (setting)
            0, 1: return 1;
            2: return 2;
            3: return 4;
            default: return 8;
        endcase
    endfunction
    function automatic bit feedthrough(input int setting);
        return setting == 1;
    endfunction
    function automatic logic [63:0] mask(input int setting);
        return {64{1'b1}} >> (64 - WIDTHS[setting]);
    endfunction
    for (genvar setting = 0; setting < CONFIGS; setting++) begin : g
        wire [WIDTHS[setting]-1:0] result;
        hpdcache_fifo_reg #(.FIFO_DEPTH(depth(setting)),
            .FEEDTHROUGH(feedthrough(setting)), .fifo_data_t(logic [WIDTHS[setting]-1:0])) dut
            (.clk_i, .rst_ni, .w_i(w[setting]), .wok_o(wok[setting]),
             .wdata_i(wd[setting][WIDTHS[setting]-1:0]), .r_i(r[setting]), .rok_o(rok[setting]),
             .rdata_o(result));
        assign rd[setting] = 64'(result);
    end
    task automatic mismatch(input int setting, input int cycle, input string reason);
        $display("MISMATCH config=%0d cycle=%0d reason=%s", setting, cycle, reason);
        $fatal(1, "FIFO external transfer mismatch");
    endtask
    task automatic reset_queue();
        w=0; r=0; rst_ni=0;
        #2;
        for (int setting=0; setting<CONFIGS; setting++) begin
            head[setting]=0; tail[setting]=0; count[setting]=0;
            if (rok[setting] !== 1'b0 || wok[setting] !== 1'b1)
                mismatch(setting, -1, "reset flags");
        end
        rst_ni=1;
    endtask
    initial begin
        w=0; r=0;
        for (int setting=0; setting<CONFIGS; setting++) begin
            head[setting]=0; tail[setting]=0; count[setting]=0;
            wd[setting]=(64'h10000000+64'(setting)) & mask(setting);
        end
        #2; clk_i=1; #2; clk_i=0;
        reset_queue();
        for (int cycle=0; cycle<2500; cycle++) begin
            if (cycle==1011 || cycle==2011) reset_queue();
            for (int setting=0; setting<CONFIGS; setting++) begin
                if (!w[setting]) w[setting]=cycle%40<20 || cycle%7!=0;
                if (cycle%40<12) r[setting]=0;
                else if (cycle%40<24) r[setting]=1;
                else r[setting]=cycle%3!=0;
                if (depth(setting)==1 && feedthrough(setting) && cycle%40==0) r[setting]=1;
            end
            #2;
            for (int setting=0; setting<CONFIGS; setting++) begin
                int d;
                bit f, expected_wok, expected_rok, pop, push, full_choice;
                d=depth(setting); f=feedthrough(setting);
                expected_wok=count[setting]<d || (d==1 && f && r[setting]);
                expected_rok=count[setting]!=0 || (f && w[setting]);
                full_choice=f && count[setting]==d && r[setting];
                $display("OBS config=%0d cycle=%0d reset=%0b w=%0b r=%0b wd=%h wok=%0b rok=%0b rd=%h queued=%0d",
                    setting,cycle,rst_ni,w[setting],r[setting],wd[setting],
                    wok[setting],rok[setting],rd[setting],count[setting]);
                if ((!full_choice && wok[setting] !== expected_wok) ||
                    rok[setting] !== expected_rok)
                    mismatch(setting,cycle,"ready or valid flags");
                if (rok[setting]) begin
                    if (count[setting]>0) begin
                        if (rd[setting] !== queue_data[setting][head[setting]])
                            mismatch(setting,cycle,"accepted word order");
                    end else if (rd[setting] !== wd[setting])
                        mismatch(setting,cycle,"direct transfer");
                end
                push=w[setting]&&wok[setting]; pop=r[setting]&&rok[setting];
                write_accepted[setting]=push;
                if (!(count[setting]==0 && push && pop)) begin
                    if (pop) begin head[setting]++; count[setting]--; end
                    if (push) begin
                        queue_data[setting][tail[setting]]=wd[setting];
                        tail[setting]++; count[setting]++;
                    end
                end
                if (count[setting]<0 || count[setting]>d)
                    mismatch(setting,cycle,"capacity");
            end
            clk_i=1; #2; clk_i=0;
            for (int setting=0; setting<CONFIGS; setting++)
                if (write_accepted[setting]) begin
                    w[setting]=0; wd[setting]=(wd[setting]+64'h9e3779b97f4a7c15) & mask(setting);
                end
        end
        $display("SUMMARY configurations=5 cycles=2500 observations=12500 errors=0");
        $display("FIFO_PORT_TEST_COMPLETE");
        $finish;
    end
endmodule
