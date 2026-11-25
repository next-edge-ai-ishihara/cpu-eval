// SPDX-License-Identifier: Apache-2.0

module cpu_eval_cache_bank_enable #(parameter int WAYS = 2) (
  input logic active_clk,
  input logic rst_l,
  input logic ic_debug_rd_en,
  input logic ic_debug_wr_en,
  input logic [WAYS-1:0] ic_rd_hit,
  input logic [1:0] ic_rd_bank_check_en
);
  int unsigned hits = 0;
  int unsigned lower_missing = 0;
  int unsigned upper_enabled = 0;

  always @(posedge active_clk) begin
    if (rst_l && !ic_debug_rd_en && !ic_debug_wr_en && (|ic_rd_hit)) begin
      hits++;
      if (!ic_rd_bank_check_en[0])
        lower_missing++;
      if (ic_rd_bank_check_en[1])
        upper_enabled++;
    end
  end

  final begin
    $display("CPU_EVAL_ICACHE_BANK_ENABLE hits=%0d lower_missing=%0d upper_enabled=%0d",
             hits, lower_missing, upper_enabled);
  end
endmodule

bind el2_ifu_ic_mem cpu_eval_cache_bank_enable #(.WAYS(pt.ICACHE_NUM_WAYS)) cpu_eval_icache_banks (
  .active_clk(active_clk),
  .rst_l(rst_l),
  .ic_debug_rd_en(ic_debug_rd_en),
  .ic_debug_wr_en(ic_debug_wr_en),
  .ic_rd_hit(ic_rd_hit),
  .ic_rd_bank_check_en(ic_rd_bank_check_en)
);
