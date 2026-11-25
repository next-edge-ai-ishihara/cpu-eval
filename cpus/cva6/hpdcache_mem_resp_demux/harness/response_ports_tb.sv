module tb;
    typedef logic [3:0] id_t;
    typedef struct packed {
        logic [1:0] mem_resp_r_error;
        id_t mem_resp_r_id;
        logic [63:0] mem_resp_r_data;
        logic mem_resp_r_last;
    } response_t;
    typedef id_t [15:0] routing_table_t;

    logic clk_i = 0, rst_ni = 0;
    logic mem_resp_valid_i = 0;
    id_t mem_resp_id_i = 0;
    response_t mem_resp_i = '0;
    routing_table_t mem_resp_rt_i = '0;
    logic [1:0] ready_mask = 0;
    wire mem_resp_ready_i [1:0];
    wire mem_resp_valid_o [1:0];
    wire response_t mem_resp_o [1:0];
    wire mem_resp_ready_o;
    int failures = 0;

    for (genvar output_port = 0; output_port < 2; output_port++) begin : gen_ready
        assign mem_resp_ready_i[output_port] = ready_mask[output_port];
    end

    // cv32a60x instantiates the read-response demultiplexer with N=2 and this response layout.
    hpdcache_mem_resp_demux #(.N(2), .resp_t(response_t), .resp_id_t(id_t)) dut (.*);

    task automatic expect_response(input int selected, input logic ready);
        logic [1:0] valid_mask;
        for (int output_port = 0; output_port < 2; output_port++) begin
            valid_mask[output_port] = mem_resp_valid_o[output_port];
        end
        $display("OBS id=%0d port=%0d ready=%b valid=%b pay=%h", mem_resp_id_i, selected,
                 mem_resp_ready_o, valid_mask, mem_resp_o[selected]);
        if (valid_mask !== (2'b01 << selected)) begin
            $display("MISMATCH routing id=%0d", mem_resp_id_i);
            failures++;
        end
        if (mem_resp_ready_o !== ready) begin
            $display("MISMATCH ready id=%0d", mem_resp_id_i);
            failures++;
        end
        if (mem_resp_o[selected] !== mem_resp_i) begin
            $display("MISMATCH payload id=%0d", mem_resp_id_i);
            failures++;
        end
    endtask

    task automatic transfer(input id_t id, input int selected, input logic [63:0] data, input logic [1:0] error);
        mem_resp_valid_i = 1;
        mem_resp_id_i = id;
        mem_resp_i = '{mem_resp_r_error: error, mem_resp_r_id: id, mem_resp_r_data: data, mem_resp_r_last: 1'b1};
        ready_mask = ~(2'b01 << selected);
        #1;
        expect_response(selected, 0);
        clk_i = 1;
        #1;
        clk_i = 0;
        ready_mask = 2'b01 << selected;
        #1;
        expect_response(selected, 1);
        clk_i = 1;
        #1;
        clk_i = 0;
    endtask

    initial begin
        #1;
        clk_i = 1;
        #1;
        clk_i = 0;
        rst_ni = 1;
        mem_resp_rt_i[4'd1] = 4'd1;
        mem_resp_rt_i[4'd4] = 4'd0;
        mem_resp_rt_i[4'd8] = 4'd1;
        mem_resp_rt_i[4'd15] = 4'd0;
        transfer(4'd1, 1, 64'h8001_7ffe_0123_4567, 2'b00);
        transfer(4'd4, 0, 64'h1357_9bdf_eca8_6420, 2'b01);
        transfer(4'd8, 1, 64'hf04a_0fb5_a5a5_5a5a, 2'b10);
        transfer(4'd15, 0, 64'h6080_9f7f_ffff_0000, 2'b00);

        mem_resp_valid_i = 0;
        #1;
        for (int output_port = 0; output_port < 2; output_port++) begin
            if (mem_resp_valid_o[output_port] !== 1'b0) begin
                $display("MISMATCH invalid port=%0d", output_port);
                failures++;
            end
        end
        if (failures == 0) $display("MEM_RESP_PORTS_PASS");
        else $display("MEM_RESP_PORTS_FAIL mismatches=%0d", failures);
        $finish;
    end
endmodule
