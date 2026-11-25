module testbench;
    import ariane_pkg::*;
    localparam config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

    typedef struct packed {
        cf_t cf;
        logic [Cfg.VLEN-1:0] predict_address;
    } prediction_t;
    typedef struct packed {
        logic [Cfg.XLEN-1:0] cause, tval;
        logic [Cfg.GPLEN-1:0] tval2;
        logic [31:0] tinst;
        logic gva, valid, timing;
    } exception_t;
    typedef struct packed {
        logic [Cfg.VLEN-1:0] address;
        logic [31:0] instruction;
        prediction_t branch_predict;
        exception_t ex;
    } entry_t;

    logic clk = 0, rst_n = 0, flush = 0;
    logic [1:0][31:0] instruction = '0;
    logic [1:0][Cfg.VLEN-1:0] address = '0;
    logic [1:0] valid = 0, consumed;
    logic ready, output_ready = 0, output_valid, replay;
    logic [Cfg.VLEN-1:0] replay_address;
    entry_t entry;
    int mismatches = 0;

    instr_queue #(.CVA6Cfg(Cfg), .fetch_entry_t(entry_t)) dut (
        .clk_i(clk), .rst_ni(rst_n), .flush_i(flush), .instr_i(instruction), .addr_i(address),
        .valid_i(valid), .ready_o(ready), .consumed_o(consumed),
        .exception_i(FE_NONE), .exception_addr_i('0), .exception_gpaddr_i('0),
        .exception_tinst_i('0), .exception_gva_i(1'b0), .predict_address_i('0),
        .cf_type_i({NoCF, NoCF}), .replay_o(replay), .replay_addr_o(replay_address),
        .fetch_entry_o(entry), .fetch_entry_valid_o(output_valid), .fetch_entry_ready_i(output_ready)
    );

    task automatic tick;
        #5 clk = 1;
        #5 clk = 0;
    endtask

    task automatic check_mask(input int id, input logic [1:0] expected);
        #1;
        $display("MASK check=%0d valid=%b consumed=%b expected=%b", id, valid, consumed, expected);
        if (consumed !== expected) begin
            mismatches++;
            $display("MISMATCH check=%0d reason=consumed", id);
        end
    endtask

    task automatic take(input int id, input logic [31:0] expected_word, input logic [Cfg.VLEN-1:0] expected_pc);
        #1;
        for (int cycles = 0; cycles < 64 && output_valid !== 1'b1; cycles++) tick();
        $display("ENTRY check=%0d valid=%b pc=%h instr=%08h", id, output_valid, entry.address, entry.instruction);
        if (output_valid !== 1'b1 || entry.address !== expected_pc || entry.instruction !== expected_word) begin
            mismatches++;
            $display("MISMATCH check=%0d reason=instruction_or_address", id);
        end
        output_ready = 1;
        tick();
        output_ready = 0;
    endtask

    initial begin
        tick();
        rst_n = 1;
        address[0] = 32'h80000000;
        address[1] = 32'h80000002;
        instruction[0] = 32'h00000405; // c.addi s0, 1
        instruction[1] = 32'h00000485; // c.addi s1, 1
        valid = 2'b11;
        check_mask(0, 2'b11);
        tick();
        valid = 2'b00;
        check_mask(1, 2'b00);
        tick();
        take(2, 32'h00000405, 32'h80000000);
        take(3, 32'h00000485, 32'h80000002);
        address[0] = 32'h80000004;
        instruction[0] = 32'h001a0a13; // addi s4, s4, 1
        valid = 2'b01;
        check_mask(4, 2'b01);
        tick();
        valid = 2'b00;
        take(5, 32'h001a0a13, 32'h80000004);
        $display("SUMMARY observations=6 mismatches=%0d", mismatches);
        $finish;
    end
endmodule
