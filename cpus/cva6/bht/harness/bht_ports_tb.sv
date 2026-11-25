// SPDX-License-Identifier: Apache-2.0
module testbench;
  localparam config_pkg::cva6_cfg_t Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  typedef struct packed {logic valid; logic [Cfg.VLEN-1:0] pc; logic taken;} update_t;
  bit clk, rst_n;
  logic [Cfg.VLEN-1:0] pc;
  update_t update;
  ariane_pkg::bht_prediction_t [Cfg.INSTR_PER_FETCH-1:0] prediction;
  bit valid[Cfg.BHTEntries];
  int counter[Cfg.BHTEntries];

  bht #(.CVA6Cfg(Cfg), .bht_update_t(update_t), .NR_ENTRIES(Cfg.BHTEntries)) dut (
    .clk_i(clk), .rst_ni(rst_n), .flush_bp_i(1'b0), .debug_mode_i(1'b0),
    .vpc_i(pc), .bht_update_i(update), .bht_prediction_o(prediction)
  );

  task automatic check_predictions(input int address_offset = 0);
    // A halfword-aligned fetch address selects the same row and slot order.
    for (int row = 0; row < Cfg.BHTEntries / Cfg.INSTR_PER_FETCH; row++) begin
      for (int halfword = 0; halfword < 4; halfword += 2) begin
        pc = address_offset + 4 * row + halfword;
        #1;
        for (int lane = 0; lane < Cfg.INSTR_PER_FETCH; lane++) begin
          int index = row * Cfg.INSTR_PER_FETCH + lane;
          if (prediction[lane].valid !== valid[index] ||
              (valid[index] && prediction[lane].taken !== (counter[index] >= 2)))
            $fatal(1, "FAIL: BHT fetch pc=%h slot=%0d expected valid=%b counter=%0d observed=%b",
                   pc, lane, valid[index], counter[index], prediction[lane]);
        end
      end
    end
  endtask

  initial begin
    update = '0;
    #1; clk = 1; #1; clk = 0;
    check_predictions();
    rst_n = 1;
    for (int pass = 0; pass < 10; pass++) begin
      for (int index = 0; index < Cfg.BHTEntries; index++) begin
        update = '{valid: 1'b1, pc: 2 * index, taken: pass < 5};
        #1; clk = 1; #1; clk = 0;
        valid[index] = 1;
        if (update.taken && counter[index] < 3) counter[index]++;
        if (!update.taken && counter[index] > 0) counter[index]--;
        check_predictions();
      end
      if (pass == 4) begin
        check_predictions(4 * (Cfg.BHTEntries / Cfg.INSTR_PER_FETCH));
      end
    end
    $display("PASS: both fetch slots and all branch counter states; high address aliases agree");
    $finish;
  end
endmodule
