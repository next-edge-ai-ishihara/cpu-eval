// SPDX-License-Identifier: Apache-2.0
  logic clk = 0;
  logic rst_n = 0;
  dcache_req_i_t request;
  dcache_req_o_t response;
  logic cache_valid, cache_abort;

  cva6_hpdcache_if_adapter #(
      .CVA6Cfg(CVA6Cfg), .HPDcacheCfg(HPDcacheCfg),
      .hpdcache_tag_t(hpdcache_tag_t), .hpdcache_req_offset_t(hpdcache_req_offset_t),
      .hpdcache_req_sid_t(hpdcache_req_sid_t),
      .hpdcache_req_t(hpdcache_req_t), .hpdcache_rsp_t(hpdcache_rsp_t),
      .dcache_req_i_t(dcache_req_i_t), .dcache_req_o_t(dcache_req_o_t),
      .InvalidateOnFlush(1'b0), .IsLoadPort(1'b1)
  ) dut (
      .clk_i(clk), .rst_ni(rst_n), .hpdcache_req_sid_i(hpdcache_req_sid_t'(1)),
      .cva6_req_i(request), .cva6_req_o(response), .cva6_amo_req_i('0),
      .cva6_amo_resp_o(), .cva6_dcache_flush_i(1'b0), .cva6_dcache_flush_ack_o(),
      .hpdcache_req_valid_o(cache_valid), .hpdcache_req_ready_i(1'b1),
      .hpdcache_req_o(), .hpdcache_req_abort_o(cache_abort),
      .hpdcache_req_tag_o(), .hpdcache_req_pma_o(),
      .hpdcache_rsp_valid_i(1'b0), .hpdcache_rsp_i('0)
  );

  task automatic tick();
    #1 clk = 1;
    #1 clk = 0;
  endtask

  // $finish ends the run only at the end of the time step; stop this process here.
  task automatic fail(input string reason);
    $display("CVA6_LOAD_CANCEL_FAIL: %s", reason);
    $finish;
    wait (0);
  endtask

  initial begin
    request = '0;
    request.cbo_op = ariane_pkg::CBO_NONE;
    tick();
    rst_n = 1;
    request.data_req = 1;
    request.address_index = 'h100;
    request.data_size = 2;
    request.data_be = '1;
    #1;
    if (!cache_valid || !response.data_gnt || cache_abort)
      fail("load request did not start normally");
    tick();

    // An accepted request reaches WAIT_FLUSH when the pipeline is flushed.
    request.data_req = 0;
    request.tag_valid = 1;
    request.address_tag = hpdcache_tag_t'(32'h80000000 >> CVA6Cfg.DCACHE_INDEX_WIDTH);
    request.kill_req = 1;
    #1;
    if (!cache_abort)
      fail($sformatf("load cancellation expected abort=1, got %0b", cache_abort));
    tick();

    request.tag_valid = 0;
    request.kill_req = 0;
    #1;
    if (cache_abort)
      fail("cache abort remained set after cancellation");
    $display("CVA6_LOAD_CANCEL_PASS");
    $finish;
  end
endmodule
