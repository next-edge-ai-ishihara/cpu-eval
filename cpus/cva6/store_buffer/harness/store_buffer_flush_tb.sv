// SPDX-License-Identifier: Apache-2.0
module store_buffer_flush_tb;
  import ariane_pkg::*;
  localparam config_pkg::cva6_cfg_t CVA6Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  `include "parent_types.svh"

  typedef logic [CVA6Cfg.PLEN-1:0] address_t;
  localparam address_t First = address_t'(32'h80000030);
  localparam address_t Speculative = address_t'(32'h80000058);
  logic clk = 0, reset_n = 0, flush = 0;
  logic valid = 0, commit = 0;
  logic ready, commit_ready, no_pending, empty;
  address_t address = '0;
  logic [31:0] data = '0;
  dcache_req_o_t from_cache = '0;
  dcache_req_i_t to_cache;

  store_buffer #(
      .CVA6Cfg(CVA6Cfg), .dcache_req_i_t(dcache_req_i_t), .dcache_req_o_t(dcache_req_o_t),
      .cbo_t(cbo_t)
  ) dut (
      .clk_i(clk), .rst_ni(reset_n), .flush_i(flush), .stall_st_pending_i(1'b0),
      .no_st_pending_o(no_pending), .store_buffer_empty_o(empty),
      .page_offset_i('0), .page_offset_matches_o(),
      .commit_i(commit), .commit_ready_o(commit_ready), .ready_o(ready),
      .valid_i(valid), .valid_without_flush_i(valid),
      .paddr_i(address), .rvfi_mem_paddr_o(), .data_i(data), .be_i(4'b1111), .data_size_i(2'b10),
      .cbo_op_i(cbo_t'(CBO_NONE)), .req_port_i(from_cache), .req_port_o(to_cache)
  );

  always #5 clk = ~clk;

  task automatic tick();
    @(negedge clk);
  endtask

  task automatic check(input logic condition, input string description);
    if (condition !== 1'b1) begin
      $display("FAIL: %s", description);
      $fatal(1, "Store-buffer port check failed");
    end
  endtask

  task automatic enqueue(input address_t store_address, input logic [31:0] store_data);
    #1;
    check(ready, "store buffer did not accept a store with space available");
    address = store_address;
    data = store_data;
    valid = 1;
    tick();
    valid = 0;
  endtask

  task automatic retire_store();
    #1;
    check(commit_ready, "store buffer did not accept a commit with space available");
    commit = 1;
    tick();
    commit = 0;
  endtask

  task automatic accept_cache_store(input address_t expected_address, input logic [31:0] expected_data);
    #1;
    for (int cycle = 0; cycle < 8 && !to_cache.data_req; cycle++) begin
      tick();
      #1;
    end
    check(to_cache.data_req, "no committed store was presented to the cache");
    check({to_cache.address_tag, to_cache.address_index} == expected_address &&
          to_cache.data_wdata == expected_data && to_cache.data_be == 4'b1111 &&
          to_cache.data_size == 2'b10 && to_cache.data_we && !to_cache.kill_req,
          "cache received the wrong committed store");
    $display("OBS accepted_store address=%08h data=%08h", expected_address, expected_data);
    from_cache.data_gnt = 1;
    tick();
    from_cache.data_gnt = 0;
  endtask

  initial begin
    tick();
    reset_n = 1;
    enqueue(First, 32'h11223344);
    retire_store();
    enqueue(Speculative, 32'h99887766);
    #1;
    check(!no_pending && !empty, "committed store was lost before flush");
    flush = 1;
    tick();
    flush = 0;
    #1;
    check(!no_pending, "flush discarded a committed store awaiting cache grant");
    accept_cache_store(First, 32'h11223344);
    #1;
    check(no_pending && empty, "a speculative store survived the flush");
    $display("PASS: flush discards speculative stores and preserves committed stores");
    $finish;
  end
endmodule
